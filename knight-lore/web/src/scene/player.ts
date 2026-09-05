// État et logique du joueur -- MVP : joueur pilotable + gravité/collision
// dans une salle (voir le plan). Volontairement DÉCOUPLÉ du rendu : ce
// module ne connaît que des coordonnées de grille NON tournées (voir
// web/CONTEXT.md, "Modèle physique de grille"), c'est main.ts qui
// applique rotateGrid() pour construire le SpriteDrawCall à l'affichage.
//
// Ne réutilise PAS les lignes joueur du manifest (slots 0/1, types
// 0x12/0x22) : leur champ grid_z_or_offset a une valeur incohérente avec
// le reste des entités (14/26 quand le décor est à 128, voir
// notes/2026-08-15-web-axis-convention-and-4-views.md) -- un mystère de
// RE non résolu, pas nécessaire à trancher pour ce MVP. Le joueur est ici
// un objet natif du portage, pas une entité ROM.

import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import type { MoveIntent } from "../input/controlMode";
import { TICK_HZ } from "../game/tick";
import type { DayNightState } from "../game/dayNight";
import { gameplayRng } from "../game/random";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { SpriteIndex } from "../data/spriteManifest";
import { rotateGrid, viewNeedsFlip, type ViewAngle } from "../render/isoMath";
import { getProjOffset } from "../render/isoOffsets";
import { loadFramesByType, type LoadedFrame } from "./spriteFrames";
import { createWalkAnimState, advanceWalkAnim, WALK_PHASE_COUNT, type WalkAnimState } from "./walkAnimation";
import {
  orientationFlip,
  orientationSpriteSetBit,
  rotateToward,
  orientationVector,
  type Orientation,
} from "./orientation";

// PERSONNAGE EN DEUX ENTITÉS (voir web/CONTEXT.md) -- et, côté ROM, ce
// n'est pas une paire symétrique : l'entité JAMBES est la maîtresse, le
// CORPS en est entièrement dérivé.
//
// Confirmé (asm/code/dispatch_and_sound.asm:39-52 et :55-70) : les types
// jambes 0x10-0x1D dispatchent vers fn_player_logic (#20CB), les types
// corps 0x20-0x2F vers fn_entity_materialize_dispatch_a (#2689). Cette
// dernière, CHAQUE FRAME, recopie grid_x..flags depuis le slot précédent
// puis pose `corps.type = jambes.type + 0x10`
// (asm/code/doors_and_player_logic.asm:1337-1344, :1364-1367). Le corps ne
// porte donc ni phase d'animation ni orientation propres.
//
// D'où la forme du modèle ici : UN SEUL état -- (phase 0-5, bit de jeu de
// sprites) -- dont les deux sprites sont dérivés. Corps et jambes ne
// peuvent pas se désynchroniser par construction. C'était la vraie cause
// du bug d'orientation des pieds (2026-09-04) : deux sélections de sprite
// indépendantes là où la ROM n'en a qu'une.
//
// Le joueur reste un objet NATIF DU PORTAGE (pas une paire d'entités
// simulée), mais il adresse désormais ses sprites par TYPE ROM via le
// SpriteIndex -- plus aucun tableau d'URL écrit à la main.

/** Base des types jambes du joueur, JOUR : 0x10-0x15 = feet1-4 en
 * aller-retour, 0x18-0x1D = feet5-8. */
export const LEGS_BASE_DAY = 0x10;

/** Base des types jambes, NUIT (loup-garou) : la même structure décalée de
 * `FORM_XOR`, trous compris. Les slots 6/7 (0x36/0x37) ne sont PAS des jambes
 * -- ce sont les blocs mobiles ; côté jour, ce sont la statue de crapaud et le
 * tapis à clous (0x16/0x17). Voir docs/METHODOLOGY.md §25bis : ces quatre
 * codes par bloc de 16 sont inatteignables par le cycle de marche (6 phases
 * seulement) et le jeu les a tous recyclés. */
export const LEGS_BASE_NIGHT = 0x30;

/** La transformation jour/nuit est un `XOR #20` sur le type
 * (`fn_player_transform_complete` #1C24). Pas une table, pas un état séparé :
 * un seul bit du type porte la forme, ce qui est aussi pourquoi les deux
 * plages ont exactement la même structure. */
const FORM_XOR = 0x20;

/** Le corps est toujours `jambes + 0x10` -- écrit tel quel par la ROM, à deux
 * endroits qui doivent rester d'accord : chaque frame par
 * `fn_entity_materialize_dispatch_a` et une fois en fin de transformation
 * (`add a,#10 / ld (ix+off_type_mirror_plus_10),a`, #1C24). Jour 0x10 -> 0x20,
 * nuit 0x30 -> 0x40. */
const BODY_FROM_LEGS = 0x10;

/** Les 4 types transitoires affichés PENDANT la transformation
 * (`fn_player_transform_tick`, #1BE1). */
const TRANSFORM_TYPE_BASE = 0x5c;
const TRANSFORM_TYPE_COUNT = 4;

/** Sous-étapes de la transformation : `(ix+off_transform_step_counter) = 8`
 * au déclenchement, décrémenté 1 frame sur 4 -- soit **32 ticks** en tout. */
const TRANSFORM_STEPS = 8;
const TRANSFORM_THROTTLE = 4;

/** Ticks pendant lesquels une transformation est refusée après un
 * franchissement de porte. FAIT ROM : la transition de salle fait `or #30` sur
 * le quartet HAUT de `cooldown_or_collision_flags` (+0x0C,
 * asm/code/doors_and_player_logic.asm:761-763), et le corps de la logique
 * joueur lui retire 0x10 par frame en saturant à zéro (:230-233). Trois
 * frames, donc -- et le déclencheur exige ce quartet nul (`and #F0 / ret nz`). */
const TRANSFORM_COOLDOWN_ON_DOOR = 3;

// ---------------------------------------------------------------------------
// (DÉ)MATÉRIALISATION -- types 0x70-0x7F
// ---------------------------------------------------------------------------
//
// L'animation de désintégration/réapparition, celle qu'on voit à la mort ET au
// lancement de la partie. Structure lue dans la table de dispatch, et elle est
// ASYMÉTRIQUE :
//
//   0x70-0x76  -> #17DC : `inc (ix+00)` à CHAQUE frame        (disparition rapide)
//   0x77       -> #17FC : pose `type = 0x01`, le slot INACTIF (le joueur s'éteint)
//   0x78-0x7E  -> #17A7 : `inc (ix+00)` 1 frame sur 2          (réapparition lente)
//   0x7F       -> #17BC : fin -- `ld a,(ix+10) / ld (ix+00),a`
//
// Deux conséquences qu'on ne devinerait pas :
//
// 1. La réapparition est DEUX FOIS PLUS LENTE que la disparition. Ce n'est pas
//    un effet de mise en scène ajouté ici, c'est deux routines différentes.
// 2. Le type final n'est pas recalculé : il est LU dans `+0x10`, que
//    `fn_init_room_entities` a rempli avec la forme correspondant au cycle
//    jour/nuit courant. C'est ce qui fait qu'on peut mourir loup-garou et
//    réapparaître chevalier -- et ça résout au passage l'usage de ce champ,
//    resté ouvert jusqu'au 2026-09-05.
//
// Le `0x78` que le checkpoint de porte écrit dans le template n'est donc pas
// une sentinelle arbitraire : c'est la PREMIÈRE IMAGE de la moitié
// « réapparition », choisie pour que la salle rechargée fasse réapparaître le
// joueur sans rejouer la désintégration.
const MATERIALIZE_FIRST = 0x70;
/** Dernière image de la disparition : la ROM y éteint l'entité. */
const MATERIALIZE_PIVOT = 0x77;
/** Première image de la réapparition -- la valeur du checkpoint. */
const MATERIALIZE_REAPPEAR = 0x78;
const MATERIALIZE_LAST = 0x7f;
/** Sous-cadence de la seconde moitié seulement (`and #01` sur le compteur). */
const MATERIALIZE_SLOW_THROTTLE = 2;

/** Animation de (dé)matérialisation en cours. */
export interface MaterializeState {
  /** Type ROM courant, 0x70-0x7F. */
  type: number;
  throttle: number;
}

/** Élévation du corps au-dessus des jambes, en unités de grille Z.
 * CONFIRMÉ : `+0x0C` posé par fn_entity_materialize_dispatch_a
 * (asm/code/doors_and_player_logic.asm:1370-1372). C'est une grandeur du
 * MONDE, pas de l'écran -- la projection la convertit, donc l'empilement
 * reste correct dans les vues tournées, ce qu'un offset écran ne
 * permettait pas. Même pas d'empilement que les blocs
 * (physics/obstacles.ts BLOCK_HEIGHT, gridZ 0x80 -> 0x8C -> 0x98). */
const BODY_Z_OFFSET = 0x0c;

function legsTypeFor(legsBase: number, bit: number, phase: number): number {
  return legsBase | (bit << 3) | phase;
}

function bodyTypeFor(legsBase: number, bit: number, phase: number): number {
  return (legsBase + BODY_FROM_LEGS) | (bit << 3) | phase;
}

/** Pas du joueur, en unités de grille par TICK, sur UN SEUL axe.
 * FAIT ROM confirmé : tbl_player_forward_vector_dispatch (#22E4,
 * asm/code/doors_and_player_logic.asm:615-650) applique ±3 sur x ou y,
 * jamais sur les deux. */
export const PLAYER_STEP = 3;

// Gravité et saut : PAS des faits ROM (le désassemblage du saut n'a pas été
// mené, voir web/DEVIATIONS.md). Ce sont des valeurs de réglage, et les seules
// grandeurs du portage réglées en TEMPS RÉEL et non par tick -- d'où la
// dérivation depuis TICK_HZ plutôt que deux nombres écrits en dur.
//
// Ce que ça préserve, et pourquoi ça compte : la HAUTEUR de saut en unités de
// grille vaut `JUMP_VELOCITY² / (2·|GRAVITY|)`, soit `(V/f)² / (2·A/f²)` =
// `V²/(2A)` -- indépendante de la cadence. Or cette hauteur est du gameplay :
// il faut pouvoir monter sur un bloc à +0x0C. Deux constantes par tick écrites
// à la main auraient doublé la hauteur de saut en passant de 50 à 25 Hz, un
// changement que personne n'aurait demandé.
//
// Les vitesses HORIZONTALES, elles, sont bien par tick (PLAYER_STEP ci-dessus,
// fait ROM) : elles ralentissent avec la cadence, et c'est exactement l'effet
// recherché.
const GRAVITY_PER_SECOND2 = -300;
const JUMP_VELOCITY_PER_SECOND = 120;
export const GRAVITY = GRAVITY_PER_SECOND2 / (TICK_HZ * TICK_HZ);
export const JUMP_VELOCITY = JUMP_VELOCITY_PER_SECOND / TICK_HZ;

// Boîte de collision du joueur -- approximation, cohérente en échelle
// avec les footprints de physics/obstacles.ts.
const PLAYER_HALF_EXTENT = 6;
const PLAYER_HEIGHT = 24;

/** Frames indexées [bit de jeu de sprites][phase 0-5]. */
type FrameSets = [LoadedFrame[], LoadedFrame[]];

/** Les deux moitiés d'UNE forme (jour ou nuit). Les deux formes ont exactement
 * la même structure -- c'est la conséquence directe du `XOR #20` : il n'y a
 * qu'un jeu de règles, appliqué à deux jeux de dessins. */
interface FormFrames {
  bodyFrames: FrameSets;
  legsFrames: FrameSets;
}

export interface PlayerFrames {
  day: FormFrames;
  night: FormFrames;
  /** Les 4 types transitoires 0x5C-0x5F, affichés pendant la transformation.
   * Un seul sprite, pas une paire corps/jambes -- voir `TransformState`. */
  transform: LoadedFrame[];
  /** Les 16 images 0x70-0x7F de la (dé)matérialisation. Leurs hauteurs
   * décroissent jusqu'au pivot puis remontent (24..20..24) : le sprite raconte
   * déjà la disparition, il n'y a aucun effet à ajouter. */
  materialize: LoadedFrame[];
}

/**
 * Transformation en cours.
 *
 * PENDANT la transformation, le joueur n'est PAS un personnage en deux
 * moitiés : `fn_player_transform_trigger` écrit `type = 0x01` dans le slot
 * compagnon (`ld de,#001C / add ix,de / ld (ix+off_type),#01`), c'est-à-dire
 * qu'il ÉTEINT le corps. Ce qui reste à l'écran est une figure unique, tirée
 * des 4 types transitoires. C'est pour ça que cet état porte un seul type et
 * pas un couple.
 */
export interface TransformState {
  /** Sous-étapes restantes, de 8 à 0. */
  stepsLeft: number;
  /** Sous-cadence : une étape consommée toutes les 4. */
  throttle: number;
  /** Type transitoire courant, 0x5C-0x5F. */
  type: number;
  /** Forme visée, retenue au déclenchement. La ROM la garde dans
   * `var_transform_flag_and_saved_type` (#0077) sous la forme du type
   * d'AVANT, et applique le `XOR #20` seulement à la complétion. */
  targetLegsBase: number;
}

export interface PlayerState {
  gridX: number;
  gridY: number;
  gridZ: number;
  velX: number;
  velY: number;
  velZ: number;
  airborne: boolean;
  /** Saut en cours -- DISTINCT de `airborne`, et la distinction vient de la
   * ROM. Le drapeau est le bit 3 de `cooldown_or_collision_flags` (+0x0C),
   * posé UNIQUEMENT par `fn_player_jump_trigger` (#21F0) et effacé à
   * l'atterrissage en descente (#22A1). Marcher dans le vide depuis un rebord
   * ne le pose donc jamais : on est `airborne` sans être `jumping`. La
   * différence est observable, parce que le déclencheur de transformation
   * teste ce bit-là et pas « en l'air ». */
  jumping: boolean;
  frames: PlayerFrames;
  /** Forme courante : `LEGS_BASE_DAY` ou `LEGS_BASE_NIGHT`. C'est le seul
   * état de forme -- corps et sprites en sont dérivés, comme en ROM où tout
   * tient dans l'octet de type. */
  legsBase: number;
  /** Transformation en cours, ou `null`. */
  transform: TransformState | null;
  /** (Dé)matérialisation en cours, ou `null`. Prioritaire sur tout le reste :
   * pendant cette animation la ROM ne fait tourner ni entrée, ni saut, ni
   * gravité, ni collision pour le joueur -- sa logique EST l'animation, via la
   * table de dispatch sur son type. */
  materialize: MaterializeState | null;
  /** Quartet haut de `cooldown_or_collision_flags` (+0x0C), en ticks.
   * Bloque la transformation juste après un franchissement de porte. */
  transformCooldown: number;
  anim: WalkAnimState;
  /** Code d'orientation 0-3 (scene/orientation.ts). Contrairement au garde,
   * le joueur PORTE son orientation : elle persiste entre les frames sans
   * input, comme `off_flags`/`off_type` en ROM. Ne pas unifier avec la
   * règle dérivée-du-vecteur du garde -- le mode de contrôle « rotation »
   * de l'original en dépend (regarder sans bouger).
   *
   * DETTE (web/DEVIATIONS.md) : elle est ici ASSIGNÉE depuis l'axe dominant
   * de l'input, alors que la ROM ne la change que par bascule de bit
   * (`xor #08` / `xor #40`, jamais un rangement direct) -- convergence en
   * 1 frame à 90°, 2 frames à 180°. Le modèle convergent arrive avec le
   * chantier « pas fixe ». */
  orientation: Orientation;
  /** Cooldown de rotation, en ticks. FAIT ROM : 2 ticks, armé par `or #02`
   * sur off_state_flags_2 (asm/code/doors_and_player_logic.asm:410-412) --
   * et court-circuité par le chemin directional, qui entre dans la bascule
   * APRÈS l'armement. Donc inerte tant que le mode rotation n'est pas
   * actif ; présent dès maintenant parce que l'ajouter après coup
   * demanderait de reprendre la boucle. */
  turnCooldown: number;
  /** Alternance d'axe pour une diagonale tenue -- voir updatePlayer. */
  diagonalToggle: number;
}

/** Charge les deux jeux de marche du corps et des jambes (2 x 6 phases
 * chacun) via le SpriteIndex. Le cache de textures partagé évite de
 * recharger feet1-8, déjà utilisés par le garde -- ce sont littéralement
 * les mêmes adresses ROM. */
export async function loadPlayerFrames(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
): Promise<PlayerFrames> {
  const phases = Array.from({ length: WALK_PHASE_COUNT }, (_, i) => i);

  /** Les deux moitiés d'une forme. La fonction ne connaît que la base des
   * jambes : tout le reste (corps, bit de jeu, phase) en découle par les
   * mêmes règles pour le jour et pour la nuit. */
  async function loadForm(legsBase: number, who: string): Promise<FormFrames> {
    const [body0, body1, legs0, legs1] = await Promise.all([
      loadFramesByType(gl, spriteIndex, phases.map((ph) => bodyTypeFor(legsBase, 0, ph)), `${who} (corps)`),
      loadFramesByType(gl, spriteIndex, phases.map((ph) => bodyTypeFor(legsBase, 1, ph)), `${who} (corps)`),
      loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(legsBase, 0, ph)), `${who} (jambes)`),
      loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(legsBase, 1, ph)), `${who} (jambes)`),
    ]);
    return { bodyFrames: [body0, body1], legsFrames: [legs0, legs1] };
  }

  // Les deux formes ET les étapes de transformation sont chargées d'avance :
  // la transformation dure 32 ticks et ne peut pas attendre un `fetch`. Le
  // cache de textures partagé rend le coût négligeable de toute façon.
  const transformTypes = Array.from({ length: TRANSFORM_TYPE_COUNT }, (_, i) => TRANSFORM_TYPE_BASE + i);
  const materializeTypes = Array.from(
    { length: MATERIALIZE_LAST - MATERIALIZE_FIRST + 1 },
    (_, i) => MATERIALIZE_FIRST + i,
  );
  const [day, night, transform, materialize] = await Promise.all([
    loadForm(LEGS_BASE_DAY, "joueur"),
    loadForm(LEGS_BASE_NIGHT, "loup-garou"),
    loadFramesByType(gl, spriteIndex, transformTypes, "transformation"),
    loadFramesByType(gl, spriteIndex, materializeTypes, "matérialisation"),
  ]);
  return { day, night, transform, materialize };
}

export function createPlayerState(
  frames: PlayerFrames,
  spawn: { gridX: number; gridY: number; gridZ: number },
): PlayerState {
  return {
    gridX: spawn.gridX,
    gridY: spawn.gridY,
    gridZ: spawn.gridZ,
    velX: 0,
    velY: 0,
    velZ: 0,
    airborne: true, // résolu dès la première frame par la gravité/le sol
    jumping: false,
    frames,
    // Le jeu démarre de JOUR (game/dayNight.ts) : forme humaine.
    legsBase: LEGS_BASE_DAY,
    transform: null,
    // Le jeu commence par la réapparition du joueur au centre de la salle de
    // départ -- même animation qu'après une mort, seconde moitié seulement.
    materialize: { type: MATERIALIZE_REAPPEAR, throttle: 0 },
    transformCooldown: 0,
    anim: createWalkAnimState(),
    orientation: 1,
    turnCooldown: 0,
    diagonalToggle: 0,
  };
}

/** Boîte de collision réelle du joueur -- exportée pour le débogage
 * visuel (debug/topView.ts), doit rester la SEULE source de vérité pour
 * cette boîte (pas de copie approximative ailleurs). */
export function playerBox(player: PlayerState): Box3 {
  return {
    minX: player.gridX - PLAYER_HALF_EXTENT,
    maxX: player.gridX + PLAYER_HALF_EXTENT,
    minY: player.gridY - PLAYER_HALF_EXTENT,
    maxY: player.gridY + PLAYER_HALF_EXTENT,
    minZ: player.gridZ,
    maxZ: player.gridZ + PLAYER_HEIGHT,
  };
}

/**
 * Avance la (dé)matérialisation d'un tick.
 *
 * Les deux moitiés n'ont pas la même cadence, et c'est un fait ROM, pas un
 * réglage : la première avance à chaque frame (#17DC), la seconde une frame
 * sur deux (#17A7). La disparition est donc brutale et le retour posé.
 *
 * Deux fins distinctes, selon la moitié :
 * - au pivot 0x77, la ROM éteint l'entité (`type = 0x01`). Ici l'animation se
 *   termine simplement, et c'est à l'appelant de faire ce que la ROM enchaîne
 *   -- perdre une vie, recharger la salle, replacer le joueur ;
 * - à 0x7F, le joueur reprend sa forme. La ROM la lit dans `+0x10` ; le
 *   portage la tient dans `legsBase`, déjà positionné par l'appelant.
 */
function advanceMaterialize(player: PlayerState): void {
  const m = player.materialize!;

  if (m.type >= MATERIALIZE_REAPPEAR) {
    m.throttle = (m.throttle + 1) % MATERIALIZE_SLOW_THROTTLE;
    if (m.throttle !== 0) return;
  }

  if (m.type === MATERIALIZE_PIVOT || m.type === MATERIALIZE_LAST) {
    player.materialize = null;
    return;
  }
  m.type += 1;
}

/** Le joueur se désintègre sur place (0x70). L'animation se termine quand il a
 * disparu -- l'appelant enchaîne alors sur la perte de vie et le rechargement
 * de la salle, comme la ROM. */
export function startDematerialize(player: PlayerState): void {
  player.materialize = { type: MATERIALIZE_FIRST, throttle: 0 };
  player.transform = null;
  player.velX = 0;
  player.velY = 0;
  player.velZ = 0;
}

/** Le joueur réapparaît (0x78) -- la valeur même que le checkpoint de porte
 * écrit dans le template, donc la moitié « réapparition » seule. */
export function startMaterialize(player: PlayerState): void {
  player.materialize = { type: MATERIALIZE_REAPPEAR, throttle: 0 };
}

/**
 * Tire le type transitoire de l'étape suivante, 0x5C-0x5F.
 *
 * FAIT ROM (`loc_1C04`) : `A = (var_pseudo_random_acc + R) & 3 | 0x5C`, puis
 * `cp (ix+off_type) / jr nz / xor #01` -- soit « jamais deux fois le même
 * d'affilée », obtenu en basculant le bit 0 si le tirage retombe sur le type
 * courant. C'est cette dernière règle qui fait l'effet visuel (ça tremble) ;
 * le tirage lui-même est de l'aléa.
 *
 * La SOURCE du tirage est celle du portage (`game/random.ts`) et non celle du
 * Z80 : ce n'est pas un écart, c'est une adaptation d'implémentation -- la
 * séquence d'octets du registre `R` n'est pas un comportement observable du
 * jeu. La règle d'anti-répétition, elle, l'est : c'est elle qui produit le
 * tremblement, et elle est reproduite exactement.
 */
function pickTransformType(current: number): number {
  const draw = TRANSFORM_TYPE_BASE | (gameplayRng.nextByte() & 0x03);
  return draw === current ? draw ^ 0x01 : draw;
}

/**
 * Le déclencheur peut-il partir ce tick ?
 *
 * Les deux refus viennent de `fn_player_transform_trigger` (#1BB0) et sont
 * testés dans cet ordre :
 * - `and #F0 / ret nz` -- le quartet haut du cooldown doit être nul, ce qui
 *   décale la transformation de 3 ticks après un franchissement de porte ;
 * - `bit 3,(ix+0C) / ret nz` -- pas de transformation PENDANT UN SAUT. Le bit
 *   n'est posé que par le saut, donc tomber d'un rebord ne l'empêche pas :
 *   c'est bien `jumping` qu'on teste ici, pas `airborne`.
 *
 * La demande, elle, n'expire pas : elle reste en attente jusqu'à ce qu'elle
 * puisse être servie (`var_transform_flag_and_saved_type` n'est remis à zéro
 * que par la complétion, #1C24, ou par l'init de salle).
 */
function transformGateOpen(player: PlayerState): boolean {
  return player.transformCooldown === 0 && !player.jumping;
}

/** Démarre la transformation et consomme la demande. */
function startTransform(player: PlayerState, dayNight: DayNightState): void {
  dayNight.transformRequested = false;
  player.transform = {
    stepsLeft: TRANSFORM_STEPS,
    // Le tick de déclenchement tire DÉJÀ un type sans consommer d'étape : la
    // ROM saute (`jr loc_1C04`) par-dessus la sous-cadence ET par-dessus le
    // `dec` du compteur. La première étape n'est donc consommée que 4 ticks
    // plus tard, et la transformation dure bien 8x4 ticks après ce tick-ci.
    throttle: 0,
    type: pickTransformType(-1),
    targetLegsBase: player.legsBase ^ FORM_XOR,
  };
  // Le personnage est FIGÉ pendant toute la transformation, et ce n'est pas
  // une simplification : la logique des types transitoires (#1BE1) n'appelle
  // ni la lecture d'entrée, ni le saut, ni la gravité, ni le déplacement.
  // Elle ne fait que cycler un sprite. On coupe donc aussi la vitesse, pour
  // que le tick de reprise ne rejoue pas un pas vieux de 32 ticks.
  player.velX = 0;
  player.velY = 0;
  player.velZ = 0;
}

/** Avance la transformation d'un tick. Rien d'autre ne se produit ce tick. */
function advanceTransform(player: PlayerState): void {
  const t = player.transform!;
  t.throttle = (t.throttle + 1) % TRANSFORM_THROTTLE;
  if (t.throttle !== 0) return;

  t.stepsLeft--;
  if (t.stepsLeft <= 0) {
    // COMPLÉTION (#1C24) : `type_final = sauvegardé XOR #20`. Le corps suit
    // tout seul, puisqu'il est dérivé (`+0x10`).
    player.legsBase = t.targetLegsBase;
    player.transform = null;
    return;
  }
  t.type = pickTransformType(t.type);
}

/**
 * Avance la simulation du joueur d'UN TICK de logique (pas fixe, voir
 * game/tick.ts). Mutation en place, cohérent avec le style mutable déjà
 * utilisé pour AppState (main.ts). Ordre de résolution des axes : Z PUIS X
 * PUIS Y -- comme le solveur du jeu original
 * (asm/code/doors_and_player_logic.asm), pour que le déplacement horizontal
 * du même tick voie déjà la hauteur corrigée (évite de "rentrer" dans le
 * dessus d'un bloc qu'on vient de heurter par en dessous).
 *
 * RÈGLES D'ORIENTATION ET D'AVANCE, mode directional -- toutes confirmées
 * (asm/code/doors_and_player_logic.asm:286-365) :
 *
 * - une direction pressée qui ne correspond pas à l'orientation courante
 *   déclenche une ROTATION, et le tick n'avance PAS ;
 * - sauf pour la direction +Y, portée par le bit qui sert AUSSI de drapeau
 *   « avance » (unique `set 2,c` en :362, unique `res 2,c` en :302) : là,
 *   la rotation et le pas de ±3 ont lieu dans le MÊME tick. Trois
 *   directions sur quatre coûtent donc un tick de rotation, la quatrième
 *   est gratuite. C'est un artefact du partage d'un bit, pas un choix de
 *   design -- mais il est observable, donc reproduit ;
 * - une fois aligné, chaque tick avance de PLAYER_STEP sur un seul axe ;
 * - aucun cooldown sur ce chemin : le chemin directional entre dans la
 *   bascule APRÈS l'armement du compteur (:410-412 sautées).
 *
 * DIAGONALE TENUE (écart assumé, web/DEVIATIONS.md) : l'original n'en a
 * pas -- ses diagonales sont un transitoire de demi-tour. Le portage
 * alterne donc l'axe parcouru à chaque tick, ce qui donne une trajectoire
 * diagonale à la MÊME vitesse que les directions cardinales, sans avoir à
 * inventer un vecteur diagonal ni une vitesse en racine de deux.
 * L'orientation, elle, reste sur l'axe primaire : il n'existe aucune règle
 * ROM d'orientation pour une diagonale tenue, et faire alterner le regard
 * à 50 Hz scintillerait.
 */
export function updatePlayer(
  player: PlayerState,
  intent: MoveIntent,
  obstacles: Obstacle[],
  dayNight: DayNightState,
): void {
  // ORDRE REPRIS DE LA ROM, et il compte. `fn_player_transform_trigger` est le
  // TOUT PREMIER appel du corps de la logique joueur
  // (asm/code/doors_and_player_logic.asm:463), et quand il part il saute le
  // reste de la frame (`inc sp` x2 pour avaler le RET de l'appelant). D'où les
  // deux sorties anticipées ci-dessous : pendant une transformation, il ne se
  // passe littéralement rien d'autre.
  // La (dé)matérialisation passe AVANT tout, y compris la transformation : sa
  // logique remplace entièrement celle du joueur dans la ROM, puisque c'est le
  // TYPE de l'entité qui décide de la routine dispatchée.
  if (player.materialize) {
    advanceMaterialize(player);
    return;
  }
  if (player.transform) {
    advanceTransform(player);
    return;
  }
  if (dayNight.transformRequested && transformGateOpen(player)) {
    startTransform(player, dayNight);
    return;
  }

  if (player.turnCooldown > 0) player.turnCooldown--;

  const [primary, secondary] = intent.targets;
  let stepOrientation: Orientation | null = null;

  if (primary !== undefined) {
    if (player.orientation !== primary) {
      // Non aligné : on tourne. Le tick n'avance que si la direction
      // demandée est celle qui porte le drapeau d'avance (+Y).
      player.orientation = rotateToward(player.orientation, primary);
      if (primary === 2) stepOrientation = player.orientation;
    } else if (secondary !== undefined) {
      // Diagonale tenue : on alterne l'axe parcouru, orientation inchangée.
      stepOrientation = player.diagonalToggle % 2 === 0 ? primary : secondary;
      player.diagonalToggle++;
    } else {
      stepOrientation = primary;
      player.diagonalToggle = 0;
    }
  } else {
    player.diagonalToggle = 0;
  }

  const [ux, uy] = stepOrientation === null ? [0, 0] : orientationVector(stepOrientation);
  player.velX = ux * PLAYER_STEP;
  player.velY = uy * PLAYER_STEP;

  // Le cycle de marche n'avance que sur un déplacement HORIZONTAL effectif
  // (comme l'original, voir walkAnimation.ts) -- ni pendant un tick de pure
  // rotation, ni pendant un saut sans direction tenue.
  advanceWalkAnim(player.anim, stepOrientation !== null);

  // Gravité continue (pas seulement pendant un arc de saut) : sans appui
  // sur rien, le joueur tombe toujours.
  player.velZ += GRAVITY;
  if (intent.jump && !player.airborne) {
    player.velZ = JUMP_VELOCITY;
    player.airborne = true;
    // `set 3,(ix+off_cooldown_or_collision_flags)` -- le drapeau « saut en
    // cours » de fn_player_jump_trigger (#21F0). Il ne sert pas à la physique
    // du portage (c'est `airborne` qui la porte) mais il gate la
    // transformation, donc il doit être posé ici et nulle part ailleurs.
    player.jumping = true;
  }

  const dz = player.velZ;

  const zRes = resolveAxis(playerBox(player), dz, "z", obstacles);
  player.gridZ += zRes.delta;
  if (zRes.blocked) {
    player.velZ = 0;
    // "Atterri" seulement si le blocage vient d'un déplacement vers le BAS
    // (dz<=0) -- un blocage vers le haut (plafond/dessous d'un bloc) laisse
    // le joueur en l'air, il retombera dès le tick suivant.
    if (dz <= 0) {
      player.airborne = false;
      // `res 3,(ix+off_cooldown_or_collision_flags)` (#22A1) : le drapeau de
      // saut n'est effacé qu'en touchant le sol EN DESCENTE -- exactement la
      // même condition que celle qui vient d'être testée.
      player.jumping = false;
    }
  } else {
    player.airborne = true;
  }

  // POUSSÉE. Le joueur ne connaît aucun type poussable : il rend simplement
  // son pas à l'obstacle qui l'a bloqué, et c'est l'obstacle qui sait s'il est
  // un corps mobile (physics/obstacles.ts `PushTarget`, scene/pushables.ts).
  // C'est la structure de la ROM elle-même : le scan par axe
  // (fn_entity_collide_axis_x/_y, #244C/#249B) fait `bit 2,(iy+off_flags)` sur
  // l'entité HEURTÉE, jamais un test sur le mobile.
  //
  // On transmet `player.velX`, le pas voulu, et non `xRes.delta`, le reliquat
  // autorisé : la ROM recopie `(ix+09)`, l'octet de structure, encore intact à
  // ce moment (il n'est réécrit rogné qu'en fin de résolution, #23F7
  // loc_243E). Un joueur bloqué net contre une table lui transmet donc quand
  // même un pas plein -- c'est ce qui fait qu'elle avance alors que lui non.
  const xRes = resolveAxis(playerBox(player), player.velX, "x", obstacles);
  xRes.blocker?.pushTarget?.receivePush("x", player.velX);
  player.gridX += xRes.delta;

  const yRes = resolveAxis(playerBox(player), player.velY, "y", obstacles);
  yRes.blocker?.pushTarget?.receivePush("y", player.velY);
  player.gridY += yRes.delta;

  // EN FIN DE CORPS, pas au début : la ROM fait `(ix+0C) -= #10` tout à la
  // fin de fn_player_logic_active_body (:230-233), donc APRÈS la gravité et
  // seulement sur les frames où ce corps s'exécute réellement. Un tick de
  // transformation ou de déclenchement sort avant et ne décrémente rien --
  // c'est pour ça que ce n'est pas en tête de fonction.
  if (player.transformCooldown > 0) player.transformCooldown--;
}

/** Arme le refus de transformation qui suit un franchissement de porte
 * (`or #30`). Appelé par le portage au moment où il replace le joueur dans la
 * salle voisine, là où la ROM le fait dans `fn_player_door_transition`. */
export function armTransformCooldownAfterDoor(player: PlayerState): void {
  player.transformCooldown = TRANSFORM_COOLDOWN_ON_DOOR;
}

/** Draw calls corps+jambes. Le corps est dessiné `BODY_Z_OFFSET` plus haut
 * que les jambes (fait ROM, voir la constante) -- c'est ce qui les empile
 * au lieu de les superposer.
 *
 * Les deux sprites viennent du MÊME couple (phase, bit) : le bit choisit un
 * jeu de dessins entièrement différent (type.bit3) et `orientationFlip()`
 * applique par-dessus le miroir de rendu (flags.bit6). Les deux moitiés
 * reçoivent le même bit et le même flip -- il n'y a plus de place pour la
 * divergence qui causait le bug des pieds.
 *
 * À l'arrêt, on affiche la phase gelée : la ROM n'a pas de pose de repos
 * (voir walkAnimation.ts). */
export function playerDrawCalls(player: PlayerState, view: ViewAngle): SpriteDrawCall[] {
  const [rx, ry] = rotateGrid(player.gridX, player.gridY, view);
  // Clé de tri commune aux deux cas -- même formule que scene/room.ts.
  const sortKey = -rx + ry - player.gridZ;

  // PENDANT LA TRANSFORMATION : une figure UNIQUE, pas une paire. Le corps a
  // été éteint par le déclencheur (type du slot compagnon forcé à 0x01), il
  // n'y a donc rien à empiler et rien à départager.
  if (player.materialize) {
    const frame = player.frames.materialize[player.materialize.type - MATERIALIZE_FIRST]!;
    const offset = getProjOffset(player.materialize.type, 0) ?? [0, 0];
    return [
      {
        texture: frame.texture,
        worldPos: [rx, player.gridZ, ry],
        size: [frame.width, frame.height],
        projOffset: offset,
        flipX: frame.hflipState !== viewNeedsFlip(view),
        sortKey,
      },
    ];
  }

  if (player.transform) {
    const frame = player.frames.transform[player.transform.type - TRANSFORM_TYPE_BASE]!;
    const offset = getProjOffset(player.transform.type, 0) ?? [0, 0];
    return [
      {
        texture: frame.texture,
        worldPos: [rx, player.gridZ, ry],
        size: [frame.width, frame.height],
        projOffset: offset,
        // Pas de miroir d'orientation ici : les types transitoires ne sont pas
        // orientés (ils n'ont pas de jeu gauche/droite), seul le retournement
        // propre à la vue s'applique par-dessus le bit capturé du sprite.
        flipX: frame.hflipState !== viewNeedsFlip(view),
        sortKey,
      },
    ];
  }

  const form = player.legsBase === LEGS_BASE_DAY ? player.frames.day : player.frames.night;
  const bit = orientationSpriteSetBit(player.orientation);
  const phase = player.anim.phase;

  const bodyFrame = form.bodyFrames[bit === 0 ? 0 : 1][phase]!;
  const legsFrame = form.legsFrames[bit === 0 ? 0 : 1][phase]!;

  // Miroir effectif = XOR de trois choses, comme scene/room.ts:96 : le bit6
  // capturé DANS le sprite (le jeu mute ce bit en place, ce n'est pas un
  // état neutre), le bit6 de `flags` de l'entité -- ici orientationFlip() --
  // et le retournement propre à la vue. Chaque frame a son propre bit
  // capturé, d'où le calcul par sprite et non une valeur commune.
  const orientFlip = orientationFlip(player.orientation);
  const viewFlip = viewNeedsFlip(view);
  const bodyFlip = bodyFrame.hflipState !== orientFlip !== viewFlip;
  const legsFlipX = legsFrame.hflipState !== orientFlip !== viewFlip;

  // Calibration ROM réelle, et elle DIFFÈRE entre les deux formes -- c'est
  // même la seule chose qui distingue fn_player_logic de sa jumelle nocturne :
  // jambes jour -> #1D89 (-12,-6), jambes nuit -> #1DA8 (-12,-7), corps jour
  // -> #1DA3 (-12,-8), corps nuit -> #1DAD (-12,-12). Le loup-garou est donc
  // dessiné plus haut que le chevalier, ce qui est cohérent avec le
  // `dec (ix+off_proj_offset_y)` que la complétion applique à la forme nuit
  // (#1C3D). Rien à écrire ici : l'appel par TYPE va chercher la bonne valeur
  // tout seul, précisément parce que la forme est dans le type.
  const legsOffset = getProjOffset(legsTypeFor(player.legsBase, bit, phase), 0) ?? [0, 0];
  const bodyOffset = getProjOffset(bodyTypeFor(player.legsBase, bit, phase), 0) ?? [0, 0];

  // Même formule de tri que scene/room.ts -- limite connue : un empilement
  // de blocs peut s'afficher devant le joueur dans certaines positions
  // (clé scalaire unique insuffisante). Différé, voir
  // docs/SESSION_SUMMARY.md §12bis. Corps et jambes partagent la clé des
  // JAMBES : ils forment une seule figure, il ne faut pas qu'un décor
  // puisse s'intercaler entre les deux moitiés.
  // ORDRE DE DESSIN des deux moitiés. Le tri est DÉCROISSANT par sortKey
  // (gl/spriteBatch.ts:189), donc la plus PETITE clé est peinte en dernier,
  // donc DEVANT. Les deux moitiés étant à la même case, leur clé est
  // identique par construction : sans départage explicite, c'est l'ordre du
  // tableau qui décide -- et il mettait les jambes devant, dont les rangées
  // hautes effaçaient les hanches du torse (signalé par l'utilisateur :
  // "le bas apparaît par-dessus le haut", "il n'a pas de short").
  //
  // Le torse passe donc devant, par un décalage d'UN DEMI point : assez pour
  // départager la paire, trop peu pour qu'un décor (clés entières, voir
  // scene/room.ts) puisse s'intercaler entre les deux moitiés d'une même
  // figure.
  const bodySortKey = sortKey - 0.5;

  return [
    {
      texture: bodyFrame.texture,
      worldPos: [rx, player.gridZ + BODY_Z_OFFSET, ry],
      size: [bodyFrame.width, bodyFrame.height],
      projOffset: bodyOffset,
      flipX: bodyFlip,
      sortKey: bodySortKey,
    },
    {
      texture: legsFrame.texture,
      worldPos: [rx, player.gridZ, ry],
      size: [legsFrame.width, legsFrame.height],
      projOffset: legsOffset,
      flipX: legsFlipX,
      sortKey,
    },
  ];
}
