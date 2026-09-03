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
// (gridZ fixe), pas d'animation de marche des jambes, pas de flip visuel
// selon la direction, pas de collision avec le joueur (mort au contact =
// chantier "état de jeu" séparé, plus tard).

import { getProjOffset } from "../render/isoOffsets";
import { rotateGrid, type ViewAngle } from "../render/isoMath";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import type { SpriteIndex } from "../data/spriteManifest";
import type { GuardSpawn } from "../data/types";
import { getTexture } from "./room";
import { ROOM_EDGE_MIN, ROOM_EDGE_MAX } from "./roomTransition";

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
  bodyTexture: WebGLTexture;
  bodyWidth: number;
  bodyHeight: number;
  bodyType: number;
  legsTexture: WebGLTexture;
  legsWidth: number;
  legsHeight: number;
  legsType: number;
}

export async function createGuardState(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
  spawn: GuardSpawn,
): Promise<GuardState> {
  const bodySprite = spriteIndex.get(spawn.bodyType);
  const legsSprite = spriteIndex.get(spawn.legsType);
  if (!bodySprite || !legsSprite) {
    throw new Error(
      `garde: sprite manquant pour type 0x${spawn.bodyType.toString(16)}/0x${spawn.legsType.toString(16)}`,
    );
  }
  const [bodyTexture, legsTexture] = await Promise.all([
    getTexture(gl, bodySprite.url),
    getTexture(gl, legsSprite.url),
  ]);
  return {
    gridX: spawn.gridX,
    gridY: spawn.gridY,
    gridZ: spawn.gridZ,
    direction: 0,
    bodyTexture,
    bodyWidth: bodySprite.width,
    bodyHeight: bodySprite.height,
    bodyType: spawn.bodyType,
    legsTexture,
    legsWidth: legsSprite.width,
    legsHeight: legsSprite.height,
    legsType: spawn.legsType,
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
  const bodyOffset = getProjOffset(guard.bodyType, 0) ?? [0, 0];
  const legsOffset = getProjOffset(guard.legsType, 0) ?? [0, 0];
  const sortKey = -rx + ry - guard.gridZ;
  return [
    {
      texture: guard.bodyTexture,
      worldPos: [rx, guard.gridZ, ry],
      size: [guard.bodyWidth, guard.bodyHeight],
      projOffset: bodyOffset,
      flipX: false,
      sortKey,
    },
    {
      texture: guard.legsTexture,
      worldPos: [rx, guard.gridZ, ry],
      size: [guard.legsWidth, guard.legsHeight],
      projOffset: legsOffset,
      flipX: false,
      sortKey,
    },
  ];
}
