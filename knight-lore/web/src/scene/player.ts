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
import type { KeyboardState } from "../input/keyboard";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { SpriteIndex } from "../data/spriteManifest";
import { rotateGrid, viewNeedsFlip, type ViewAngle } from "../render/isoMath";
import { getProjOffset } from "../render/isoOffsets";
import { loadFramesByType, type LoadedFrame } from "./spriteFrames";
import { createWalkAnimState, advanceWalkAnim, WALK_PHASE_COUNT, type WalkAnimState } from "./walkAnimation";
import { orientationFromVector, orientationFlip, orientationSpriteSetBit, type Orientation } from "./orientation";

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

/** Base des types jambes du joueur (jour) : 0x10-0x15 = feet1-4 en
 * aller-retour, 0x18-0x1D = feet5-8. Le loup-garou (nuit) a sa propre base
 * 0x30 -- pas encore implémenté (dette, voir web/DEVIATIONS.md). */
const PLAYER_LEGS_BASE = 0x10;

/** Base des types corps du joueur (jour) : `jambes + 0x10`, exactement la
 * relation qu'applique la ROM. */
const PLAYER_BODY_BASE = 0x20;

/** Élévation du corps au-dessus des jambes, en unités de grille Z.
 * CONFIRMÉ : `+0x0C` posé par fn_entity_materialize_dispatch_a
 * (asm/code/doors_and_player_logic.asm:1370-1372). C'est une grandeur du
 * MONDE, pas de l'écran -- la projection la convertit, donc l'empilement
 * reste correct dans les vues tournées, ce qu'un offset écran ne
 * permettait pas. Même pas d'empilement que les blocs
 * (physics/obstacles.ts BLOCK_HEIGHT, gridZ 0x80 -> 0x8C -> 0x98). */
const BODY_Z_OFFSET = 0x0c;

function legsTypeFor(bit: number, phase: number): number {
  return PLAYER_LEGS_BASE | (bit << 3) | phase;
}

function bodyTypeFor(bit: number, phase: number): number {
  return PLAYER_BODY_BASE | (bit << 3) | phase;
}

// Constantes de gameplay -- valeurs de DÉPART à ajuster en jouant, PAS des
// faits établis. DETTE (web/DEVIATIONS.md) : l'original ne connaît pas de
// vitesse en unités/seconde, il fait ±3 unités par FRAME DE LOGIQUE sur un
// seul axe (tbl_player_forward_vector_dispatch #22E4). La conversion du
// portage en pas fixe est un chantier à part.
export const PLAYER_SPEED = 60;
export const GRAVITY = -300;
export const JUMP_VELOCITY = 120;

// Boîte de collision du joueur -- approximation, cohérente en échelle
// avec les footprints de physics/obstacles.ts.
const PLAYER_HALF_EXTENT = 6;
const PLAYER_HEIGHT = 24;

/** Frames indexées [bit de jeu de sprites][phase 0-5]. */
type FrameSets = [LoadedFrame[], LoadedFrame[]];

export interface PlayerState {
  gridX: number;
  gridY: number;
  gridZ: number;
  velX: number;
  velY: number;
  velZ: number;
  airborne: boolean;
  bodyFrames: FrameSets;
  legsFrames: FrameSets;
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
}

/** Charge les deux jeux de marche du corps et des jambes (2 x 6 phases
 * chacun) via le SpriteIndex. Le cache de textures partagé évite de
 * recharger feet1-8, déjà utilisés par le garde -- ce sont littéralement
 * les mêmes adresses ROM. */
export async function loadPlayerFrames(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
): Promise<{ bodyFrames: FrameSets; legsFrames: FrameSets }> {
  const phases = Array.from({ length: WALK_PHASE_COUNT }, (_, i) => i);
  const [body0, body1, legs0, legs1] = await Promise.all([
    loadFramesByType(gl, spriteIndex, phases.map((ph) => bodyTypeFor(0, ph)), "joueur (corps)"),
    loadFramesByType(gl, spriteIndex, phases.map((ph) => bodyTypeFor(1, ph)), "joueur (corps)"),
    loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(0, ph)), "joueur (jambes)"),
    loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(1, ph)), "joueur (jambes)"),
  ]);
  return { bodyFrames: [body0, body1], legsFrames: [legs0, legs1] };
}

export function createPlayerState(
  frames: { bodyFrames: FrameSets; legsFrames: FrameSets },
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
    bodyFrames: frames.bodyFrames,
    legsFrames: frames.legsFrames,
    anim: createWalkAnimState(),
    orientation: 1,
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
 * Avance la simulation du joueur d'un pas `dt` (secondes). Mutation en
 * place, cohérent avec le style mutable déjà utilisé pour AppState
 * (main.ts). Ordre de résolution des axes : Z PUIS X PUIS Y -- comme le
 * solveur du jeu original (asm/code/doors_and_player_logic.asm), pour que
 * le déplacement horizontal de la même frame voie déjà la hauteur
 * corrigée (évite de "rentrer" dans le dessus d'un bloc qu'on vient de
 * heurter par en dessous).
 */
export function updatePlayer(player: PlayerState, input: KeyboardState, obstacles: Obstacle[], dt: number): void {
  let dx = 0;
  let dy = 0;
  if (input.isDown("a") || input.isDown("arrowleft")) dx -= 1;
  if (input.isDown("d") || input.isDown("arrowright")) dx += 1;
  if (input.isDown("w") || input.isDown("arrowup")) dy -= 1;
  if (input.isDown("s") || input.isDown("arrowdown")) dy += 1;
  const len = Math.hypot(dx, dy);

  // Orientation depuis l'axe dominant de l'input BRUT (avant
  // normalisation). Persiste sans input. Voir la dette notée sur
  // PlayerState.orientation : la ROM converge par bascule de bit, elle
  // n'assigne pas.
  if (len > 0) {
    player.orientation = orientationFromVector(dx, dy);
  }

  if (len > 0) {
    dx /= len;
    dy /= len;
  }
  player.velX = dx * PLAYER_SPEED;
  player.velY = dy * PLAYER_SPEED;

  // Le cycle de marche n'avance que sur un déplacement HORIZONTAL
  // effectif (comme l'original, voir walkAnimation.ts) -- pas pendant un
  // saut/chute pur sans input directionnel.
  advanceWalkAnim(player.anim, len > 0, dt);

  // Gravité continue (pas seulement pendant un arc de saut) : sans appui
  // sur rien, le joueur tombe toujours.
  player.velZ += GRAVITY * dt;
  if (input.consumeJustPressed(" ") && !player.airborne) {
    player.velZ = JUMP_VELOCITY;
    player.airborne = true;
  }

  const obstacleBoxes = obstacles.map((o) => o.box);
  const dz = player.velZ * dt;

  const zRes = resolveAxis(playerBox(player), dz, "z", obstacleBoxes);
  player.gridZ += zRes.delta;
  if (zRes.blocked) {
    player.velZ = 0;
    // "Atterri" seulement si le blocage vient d'un déplacement vers le
    // BAS (dz<=0) -- un blocage vers le haut (plafond/dessous d'un bloc)
    // laisse le joueur en l'air, il retombera dès la prochaine frame.
    if (dz <= 0) player.airborne = false;
  } else {
    player.airborne = true;
  }

  const dxDelta = player.velX * dt;
  const xRes = resolveAxis(playerBox(player), dxDelta, "x", obstacleBoxes);
  player.gridX += xRes.delta;

  const dyDelta = player.velY * dt;
  const yRes = resolveAxis(playerBox(player), dyDelta, "y", obstacleBoxes);
  player.gridY += yRes.delta;
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
export function playerDrawCalls(player: PlayerState, view: ViewAngle): [SpriteDrawCall, SpriteDrawCall] {
  const [rx, ry] = rotateGrid(player.gridX, player.gridY, view);
  const bit = orientationSpriteSetBit(player.orientation);
  const phase = player.anim.phase;

  const bodyFrame = player.bodyFrames[bit === 0 ? 0 : 1][phase]!;
  const legsFrame = player.legsFrames[bit === 0 ? 0 : 1][phase]!;

  // Miroir effectif = XOR de trois choses, comme scene/room.ts:96 : le bit6
  // capturé DANS le sprite (le jeu mute ce bit en place, ce n'est pas un
  // état neutre), le bit6 de `flags` de l'entité -- ici orientationFlip() --
  // et le retournement propre à la vue. Chaque frame a son propre bit
  // capturé, d'où le calcul par sprite et non une valeur commune.
  const orientFlip = orientationFlip(player.orientation);
  const viewFlip = viewNeedsFlip(view);
  const bodyFlip = bodyFrame.hflipState !== orientFlip !== viewFlip;
  const legsFlipX = legsFrame.hflipState !== orientFlip !== viewFlip;

  // Calibration ROM réelle : jambes 0x10-0x1D -> #1D89 (-12,-6), corps
  // 0x20-0x2F -> #1DA3 (-12,-8). Aucun de ces types ne fait dépendre son
  // offset de l'orientation (vérifié 2026-09-04), d'où `flags` à 0.
  const legsOffset = getProjOffset(legsTypeFor(bit, phase), 0) ?? [0, 0];
  const bodyOffset = getProjOffset(bodyTypeFor(bit, phase), 0) ?? [0, 0];

  // Même formule de tri que scene/room.ts -- limite connue : un empilement
  // de blocs peut s'afficher devant le joueur dans certaines positions
  // (clé scalaire unique insuffisante). Différé, voir
  // docs/SESSION_SUMMARY.md §12bis. Corps et jambes partagent la clé des
  // JAMBES : ils forment une seule figure, il ne faut pas qu'un décor
  // puisse s'intercaler entre les deux moitiés.
  const sortKey = -rx + ry - player.gridZ;

  return [
    {
      texture: bodyFrame.texture,
      worldPos: [rx, player.gridZ + BODY_Z_OFFSET, ry],
      size: [bodyFrame.width, bodyFrame.height],
      projOffset: bodyOffset,
      flipX: bodyFlip,
      sortKey,
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
