// État et logique du garde (ennemi patrouilleur) -- premier ennemi du
// portage. Implémentation propre INSPIRÉE de fn_guard_patrol_logic
// (#1280) / fn_resolve_patrol_vector (#12A5-#12FA,
// asm/code/entity_logic_mechanical.asm), pas un portage littéral.
//
// Confirmé par désassemblage : purement réactif à la collision, AUCUNE
// conscience du joueur (contrairement à fn_hostile_patrol_logic
// 0x83-0x85 et fn_ball_chase_flee_logic 0xB6/0xB7 dans le même fichier,
// qui eux traquent/fuient -- hors sujet ici). Cycle de 4 directions,
// tourne (+1 mod 4) uniquement quand un déplacement est bloqué sur l'axe
// courant, sinon continue tout droit.
//
// Contrairement au joueur (entité native du portage), le garde est une
// VRAIE paire d'entités ROM (corps 0x1E/0x1F/0x9E/0x9F + jambes
// 0x90-0x9D, web/CONTEXT.md "Personnage en deux entités") -- il réutilise
// donc render/isoOffsets.ts (calibration réelle) et le SpriteIndex/cache
// de texture existants, sans rien hardcoder.
//
// Simplifications assumées pour ce MVP (voir le plan) : pas de gravité
// (gridZ fixe), pas de collision avec le joueur (mort au contact =
// chantier "état de jeu" séparé, plus tard).
//
// Animation de marche : les 3 bits bas du type portent la phase 0-5
// (fn_guard_legs_logic #0FD8 appelle le MÊME recycleur que le joueur,
// `call #2231`, asm/code/entity_logic_mechanical.asm:36), et l'aller-retour
// sur 4 dessins est déjà encodé dans tbl_sprite_dispatch -- voir
// scene/walkAnimation.ts.
//
// Orientation : AUCUN état stocké. fn_guard_legs_logic la RECALCULE chaque
// frame depuis le vecteur de déplacement (axe dominant, puis signe), avec
// `set`/`res` et jamais une bascule -- entity_logic_mechanical.asm:29-60.
// C'est la différence de fond avec le joueur, qui porte son orientation
// comme un état persistant (voir scene/orientation.ts). Le corps du garde
// suit la même règle mais loge son bit de jeu de sprites dans type.bit0 et
// non type.bit3 (fn_guard_walk_animation_toggle #1055, :107-130) : c'est ce
// qui explique les paires 0x1E/0x1F et 0x9E/0x9F -- deux orientations d'un
// même personnage, pas deux personnages.
import { getProjOffset } from "../render/isoOffsets";
import { rotateGrid, viewNeedsFlip, type ViewAngle } from "../render/isoMath";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import type { SpriteIndex } from "../data/spriteManifest";
import type { GuardSpawn } from "../data/types";
import { loadFramesByType, type LoadedFrame } from "./spriteFrames";
import { ROOM_EDGE_MIN, ROOM_EDGE_MAX } from "./roomTransition";
import { createWalkAnimState, advanceWalkAnim, WALK_PHASE_COUNT, type WalkAnimState } from "./walkAnimation";
import {
  orientationFromVector,
  orientationFlip,
  orientationSpriteSetBit,
  type Orientation,
} from "./orientation";

/** Type ROM des jambes pour une orientation et une phase données :
 * `base | (bit << 3) | phase`. base = 0x90 (garde). bit=0 -> feet1-4,
 * bit=1 -> feet5-8 : deux jeux de dessins DISTINCTS, pas un miroir. */
function legsTypeFor(base: number, bit: number, phase: number): number {
  return base | (bit << 3) | phase;
}

// Amplitude ±2 unités de grille CONFIRMÉE par désassemblage
// (tbl_guard_patrol_vector_dispatch), traduite ici en vitesse continue --
// valeur de départ à ajuster, pas un fait établi (comme PLAYER_SPEED).
export const GUARD_SPEED = 40;
const GUARD_HALF_EXTENT = 6;
const GUARD_HEIGHT = 24;

export type GuardDirection = 0 | 1 | 2 | 3;

// Cycle CONFIRMÉ par désassemblage (vecteurs HL bruts de la table de
// dispatch : #00FE, #0200, #0002, #FE00, L->pending_x, H->pending_y) :
// 0=-X, 1=+Y, 2=+X, 3=-Y. Un seul axe bouge à la fois.
const DIRECTION_STEP: Record<GuardDirection, 1 | -1> = { 0: -1, 1: 1, 2: 1, 3: -1 };
const DIRECTION_AXIS: Record<GuardDirection, "x" | "y"> = { 0: "x", 1: "y", 2: "x", 3: "y" };

export interface GuardState {
  gridX: number;
  gridY: number;
  gridZ: number;
  direction: GuardDirection;
  /** Corps indexé par le bit de jeu de sprites (type.bit0) : 2 dessins. */
  bodyFrames: [LoadedFrame, LoadedFrame];
  bodyBase: number;
  /** Jambes indexées [bit de jeu (type.bit3)][phase 0-5]. */
  legsFrames: [LoadedFrame[], LoadedFrame[]];
  legsBase: number;
  anim: WalkAnimState;
  /** Recalculée chaque frame depuis le vecteur, jamais persistée comme
   * une décision (voir la note d'orientation en tête de fichier). */
  orientation: Orientation;
}

export async function createGuardState(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
  spawn: GuardSpawn,
): Promise<GuardState> {
  // Le spawn donne UN type de corps et UN type de jambes ; ce sont les
  // variantes d'orientation 0 de leur famille. On remonte à la base et on
  // charge les deux jeux complets -- le corps a 2 dessins (type.bit0), les
  // jambes 2 x 6 phases (type.bit3 + les 3 bits bas).
  const bodyBase = spawn.bodyType & ~0x01;
  const legsBase = spawn.legsType & 0xf0;

  const phases = Array.from({ length: WALK_PHASE_COUNT }, (_, i) => i);
  const [bodyFrames, legsSet0, legsSet1] = await Promise.all([
    loadFramesByType(gl, spriteIndex, [bodyBase, bodyBase | 0x01], "garde (corps)"),
    loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(legsBase, 0, ph)), "garde (jambes)"),
    loadFramesByType(gl, spriteIndex, phases.map((ph) => legsTypeFor(legsBase, 1, ph)), "garde (jambes)"),
  ]);

  return {
    gridX: spawn.gridX,
    gridY: spawn.gridY,
    gridZ: spawn.gridZ,
    direction: 0,
    bodyFrames: [bodyFrames[0]!, bodyFrames[1]!],
    bodyBase,
    legsFrames: [legsSet0, legsSet1],
    legsBase,
    anim: createWalkAnimState(),
    orientation: 0,
  };
}

/** Boîte de collision réelle du garde -- même échelle que
 * scene/player.ts::playerBox, exportée pour le débogage visuel
 * (debug/topView.ts). */
export function guardBox(guard: GuardState): Box3 {
  return {
    minX: guard.gridX - GUARD_HALF_EXTENT,
    maxX: guard.gridX + GUARD_HALF_EXTENT,
    minY: guard.gridY - GUARD_HALF_EXTENT,
    maxY: guard.gridY + GUARD_HALF_EXTENT,
    minZ: guard.gridZ,
    maxZ: guard.gridZ + GUARD_HEIGHT,
  };
}

/** Avance la patrouille d'un pas `dt`. Mutation en place, cohérent avec
 * scene/player.ts. Ne teste QUE l'axe de déplacement courant (le garde
 * ne bouge jamais en diagonale) -- si le déplacement est bloqué, tourne
 * pour LA FRAME SUIVANTE (léger décalage d'un frame par rapport au
 * timing exact de la ROM, sans effet visible en continu).
 *
 * Les salles n'ont de murs que sur DEUX côtés ("boîte ouverte", voir
 * scene/room.ts) -- sans mur d'un côté donné, rien n'arrêterait le garde
 * dans `obstacles` et il sortirait indéfiniment de la salle (constaté).
 * Contrairement au joueur, qui franchit ces bords pour changer de salle
 * (scene/roomTransition.ts), le garde reste confiné : on réutilise les
 * MÊMES constantes de bord (`ROOM_EDGE_MIN`/`MAX`) comme un mur invisible.
 * Approximation reconnue : ce bord peut être nettement décalé des boîtes
 * de mur (`physics/obstacles.ts`, par point d'ancrage) -- deux mécanismes
 * distincts, sans lien géométrique entre eux. Acceptable tant que le
 * garde reste dans la salle (confirmé) ; à resserrer si le décalage
 * visuel gêne. */
export function updateGuard(guard: GuardState, obstacles: Obstacle[], dt: number): void {
  const axis = DIRECTION_AXIS[guard.direction];
  const step = DIRECTION_STEP[guard.direction];
  const delta = step * GUARD_SPEED * dt;
  const obstacleBoxes = obstacles.map((o) => o.box);

  const res = resolveAxis(guardBox(guard), delta, axis, obstacleBoxes);
  let blocked = res.blocked;
  const coordAfter = (axis === "x" ? guard.gridX : guard.gridY) + res.delta;

  if (axis === "x") {
    guard.gridX = Math.min(Math.max(coordAfter, ROOM_EDGE_MIN), ROOM_EDGE_MAX);
  } else {
    guard.gridY = Math.min(Math.max(coordAfter, ROOM_EDGE_MIN), ROOM_EDGE_MAX);
  }
  if (coordAfter < ROOM_EDGE_MIN || coordAfter > ROOM_EDGE_MAX) blocked = true;

  // Orientation dérivée du vecteur VOULU, pas du déplacement effectivement
  // appliqué : une frame bloquée a un delta nul, et la règle ROM y
  // retomberait sur +X (le `cp` non signé compare alors 0 à 0) -- le garde
  // ferait un quart de tour parasite devant chaque mur. La ROM ne voit pas
  // ce cas parce que son handler de patrouille substitue le vecteur de la
  // direction SUIVANTE avant que la logique des jambes ne tourne
  // (entity_logic_mechanical.asm:572-582).
  guard.orientation = orientationFromVector(
    axis === "x" ? step : 0,
    axis === "y" ? step : 0,
  );

  advanceWalkAnim(guard.anim, res.delta !== 0, dt);

  if (blocked) {
    guard.direction = ((guard.direction + 1) % 4) as GuardDirection;
  }
}

/** Draw calls corps+jambes -- réutilise getProjOffset() (calibration ROM
 * réelle), contrairement à scene/player.ts qui doit hardcoder son
 * décalage (entité native du portage, pas dans isoOffsets.ts). Pas de
 * classicYRoundingCorrection : cette correction cible la parité de
 * coordonnées de grille ENTIÈRES du Z80, qui ne s'applique pas
 * proprement à une position continue en virgule flottante -- même choix
 * que pour le joueur. */
export function guardDrawCalls(guard: GuardState, view: ViewAngle): [SpriteDrawCall, SpriteDrawCall] {
  const [rx, ry] = rotateGrid(guard.gridX, guard.gridY, view);
  const bit = orientationSpriteSetBit(guard.orientation);

  const bodyFrame = guard.bodyFrames[bit === 0 ? 0 : 1];
  const legsFrame = guard.legsFrames[bit === 0 ? 0 : 1][guard.anim.phase]!;
  const bodyType = guard.bodyBase | bit;
  const legsType = legsTypeFor(guard.legsBase, bit, guard.anim.phase);

  // Calibration ROM réelle. Confirmé (2026-09-04) qu'aucun de ces types ne
  // fait dépendre son offset de l'orientation (contrairement aux montants
  // de porte 0x02/0x03) : passer `flags` à 0 est donc exact, pas un repli.
  const bodyOffset = getProjOffset(bodyType, 0) ?? [0, 0];
  const legsOffset = getProjOffset(legsType, 0) ?? [0, 0];
  const sortKey = -rx + ry - guard.gridZ;

  // Miroir effectif : XOR bit capturé / bit6 de flags / retournement de vue
  // -- même règle que scene/room.ts:96 et scene/player.ts.
  const orientFlip = orientationFlip(guard.orientation);
  const viewFlip = viewNeedsFlip(view);
  const bodyFlip = bodyFrame.hflipState !== orientFlip !== viewFlip;
  const legsFlip = legsFrame.hflipState !== orientFlip !== viewFlip;

  return [
    {
      texture: bodyFrame.texture,
      worldPos: [rx, guard.gridZ, ry],
      size: [bodyFrame.width, bodyFrame.height],
      projOffset: bodyOffset,
      flipX: bodyFlip,
      sortKey,
    },
    {
      texture: legsFrame.texture,
      worldPos: [rx, guard.gridZ, ry],
      size: [legsFrame.width, legsFrame.height],
      projOffset: legsOffset,
      flipX: legsFlip,
      sortKey,
    },
  ];
}
