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

import { loadTexture } from "../gl/texture";
import type { Box3 } from "../physics/aabb";
import { resolveAxis } from "../physics/aabb";
import type { Obstacle } from "../physics/obstacles";
import type { KeyboardState } from "../input/keyboard";

// Sprite fixe unique pour ce MVP -- le perso en deux parties (corps +
// jambes, cf. web/CONTEXT.md "Personnage en deux entités") est différé,
// pas nécessaire pour un joueur qui marche/saute.
//
// Nom de fichier CANONIQUE (adresse ROM, `sprite_<ptr>_w_h.png`) --
// PAS "sprite_hero_up1_...", une copie renommée à la main, ponctuelle,
// hors de tools/sprite_dump.py (qui ne nomme JAMAIS ses sorties par un
// nom "amical" : voir sprite_dump.py::main(), fname = f"sprite_{ptr:04X}_...").
// Cette copie n'est donc régénérée par rien -- restée figée en niveaux de
// gris après le passage aux couleurs (2026-09-04), elle a fait planter le
// chargement de texture. Toujours référencer le fichier canonique.
const PLAYER_SPRITE_URL = "/sprites/sprite_6A8E_w24_h25.png";
const PLAYER_SPRITE_WIDTH = 24;
const PLAYER_SPRITE_HEIGHT = 25;

// L'ancre du sprite est son coin BAS-GAUCHE (u_anchor=(0,1), voir
// gl/spriteBatch.ts) -- sans rattrapage, le sprite apparaît décalé d'une
// demi-largeur vers la droite de sa vraie position de grille. C'est une
// règle GÉOMÉTRIQUE générale du système d'ancrage (isoOffsets.ts :
// "proj_offset_x vaut exactement -largeur/2 pour tous les types centrés
// sur leur case"), pas une donnée ROM -- applicable ici sans passer par
// isoOffsets.ts (réservée aux types ROM réels, le joueur n'en est pas
// un). Pas de rattrapage vertical pour ce MVP : l'ancre bas = pieds au
// niveau du sol, cohérent visuellement sans calibration supplémentaire.
export const PLAYER_PROJ_OFFSET: [number, number] = [-PLAYER_SPRITE_WIDTH / 2, 0];

// Constantes de gameplay -- valeurs de DÉPART à ajuster en jouant, PAS
// des faits établis par désassemblage (voir le plan, section "Notes de
// fidélité"). Unités de grille par seconde (ou par seconde², pour
// GRAVITY).
export const PLAYER_SPEED = 60;
export const GRAVITY = -300;
export const JUMP_VELOCITY = 120;

// Boîte de collision du joueur -- approximation, cohérente en échelle
// avec les footprints de physics/obstacles.ts.
const PLAYER_HALF_EXTENT = 6;
const PLAYER_HEIGHT = 24;

export interface PlayerState {
  gridX: number;
  gridY: number;
  gridZ: number;
  velX: number;
  velY: number;
  velZ: number;
  airborne: boolean;
  texture: WebGLTexture;
  width: number;
  height: number;
}

export async function loadPlayerTexture(
  gl: WebGL2RenderingContext,
): Promise<{ texture: WebGLTexture; width: number; height: number }> {
  const texture = await loadTexture(gl, PLAYER_SPRITE_URL);
  return { texture, width: PLAYER_SPRITE_WIDTH, height: PLAYER_SPRITE_HEIGHT };
}

export function createPlayerState(
  texture: WebGLTexture,
  width: number,
  height: number,
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
    texture,
    width,
    height,
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
  if (len > 0) {
    dx /= len;
    dy /= len;
  }
  player.velX = dx * PLAYER_SPEED;
  player.velY = dy * PLAYER_SPEED;

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
