// Construit la liste d'obstacles statiques d'une salle pour le solveur
// AABB (physics/aabb.ts), à partir des entités déjà chargées
// (data/roomManifest.ts). Aucune vraie bbox_w/h/d n'est disponible dans
// le manifest actuel (absente de rooms_manifest.json) -- footprints
// approximatifs par catégorie, assumés comme tels (voir le plan et
// web/CONTEXT.md). À ajuster empiriquement, pas des valeurs de RE.

import type { RoomEntity } from "../data/types";
import type { Box3 } from "./aabb";

export interface Obstacle {
  box: Box3;
  /** Catégorie d'origine -- uniquement pour le débogage visuel (voir
   * debug/topView.ts), sans effet sur la résolution physique elle-même. */
  kind: "wall" | "block" | "floor";
}

// Murs (is_wall=true) : aucune largeur/orientation par segment connue --
// boîte fixe centrée sur le point d'ancrage (décision actée : pas de
// tentative de deviner l'orientation du mur).
const WALL_HALF_EXTENT = 8;
const WALL_HEIGHT = 44;

// Décor solide (is_decor=true, hors murs) : blocs empilables, statues,
// etc. Le pas de hauteur 12 correspond à l'empilement observé des blocs
// (ex. gridZ 0x80 -> 0x8C -> 0x98).
const BLOCK_HALF_EXTENT = 8;
const BLOCK_HEIGHT = 12;

// Plan de sol synthétique : aucune entité du manifest ne représente le
// sol -- sans lui, rien n'existe pour que la gravité fasse atterrir le
// joueur. Étendue dérivée de la boîte englobante des entités de la salle.
const FLOOR_TOP_Z = 0x80;
const FLOOR_THICKNESS = 16;
const FLOOR_MARGIN = 16;

/**
 * IMPORTANT (vérifié sur les données réelles, contraire à l'intuition du
 * nom) : `isDecor` marque le décor D'ENVIRONNEMENT SOLIDE (murs, blocs
 * empilés) -- PAS l'inverse. Les éléments interactifs non-solides
 * (montants de porte 0x02/0x03, pickups) ont `isDecor=false` dans le
 * manifest. Conséquence pratique : les montants de porte sont exclus des
 * obstacles automatiquement, sans exception à coder -- traversables pour
 * l'instant, en attendant les transitions de salle.
 */
export function buildObstacles(entities: RoomEntity[]): Obstacle[] {
  const obstacles: Obstacle[] = [];

  let minX = Infinity;
  let maxX = -Infinity;
  let minY = Infinity;
  let maxY = -Infinity;

  for (const entity of entities) {
    minX = Math.min(minX, entity.gridX);
    maxX = Math.max(maxX, entity.gridX);
    minY = Math.min(minY, entity.gridY);
    maxY = Math.max(maxY, entity.gridY);

    if (entity.isWall) {
      obstacles.push({
        kind: "wall",
        box: {
          minX: entity.gridX - WALL_HALF_EXTENT,
          maxX: entity.gridX + WALL_HALF_EXTENT,
          minY: entity.gridY - WALL_HALF_EXTENT,
          maxY: entity.gridY + WALL_HALF_EXTENT,
          minZ: entity.gridZ,
          maxZ: entity.gridZ + WALL_HEIGHT,
        },
      });
    } else if (entity.isDecor) {
      obstacles.push({
        kind: "block",
        box: {
          minX: entity.gridX - BLOCK_HALF_EXTENT,
          maxX: entity.gridX + BLOCK_HALF_EXTENT,
          minY: entity.gridY - BLOCK_HALF_EXTENT,
          maxY: entity.gridY + BLOCK_HALF_EXTENT,
          minZ: entity.gridZ,
          maxZ: entity.gridZ + BLOCK_HEIGHT,
        },
      });
    }
  }

  if (minX <= maxX) {
    obstacles.push({
      kind: "floor",
      box: {
        minX: minX - FLOOR_MARGIN,
        maxX: maxX + FLOOR_MARGIN,
        minY: minY - FLOOR_MARGIN,
        maxY: maxY + FLOOR_MARGIN,
        minZ: FLOOR_TOP_Z - FLOOR_THICKNESS,
        maxZ: FLOOR_TOP_Z,
      },
    });
  }

  return obstacles;
}
