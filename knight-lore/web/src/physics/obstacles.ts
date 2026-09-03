// Construit la liste d'obstacles statiques d'une salle pour le solveur
// AABB (physics/aabb.ts), à partir des entités déjà chargées
// (data/roomManifest.ts). Utilise les VRAIES demi-étendues bbox_w/h/d
// quand elles sont disponibles (murs/portes -- extraites de la table ROM
// statique tbl_room_connection_detail_*, voir
// tools/room_map/enrich_bbox.py et docs/SYMBOLS.md +0x04-06). Pour le
// décor SANS bbox connue (ex. blocs intérieurs placés salle par salle,
// hors table de jonction), retombe sur un footprint approximatif par
// catégorie -- ce repli est resté correct pour les blocs une fois vérifié
// contre la vraie table (0x07 : bbox réelle (8,8,12), identique à la
// valeur devinée ci-dessous).

import type { RoomEntity } from "../data/types";
import type { Box3 } from "./aabb";
import { ROOM_EDGE_MIN, ROOM_EDGE_MAX } from "../scene/roomTransition";

export interface Obstacle {
  box: Box3;
  /** Catégorie d'origine -- uniquement pour le débogage visuel (voir
   * debug/topView.ts), sans effet sur la résolution physique elle-même. */
  kind: "wall" | "block" | "floor";
}

// Repli si bbox_w/h/d absentes (murs) : boîte fixe centrée sur le point
// d'ancrage -- seulement pour un mur qui ne serait pas couvert par la
// table de jonction (ne devrait normalement pas arriver, tous les murs
// observés jusqu'ici l'ont été).
const WALL_HALF_EXTENT = 8;
const WALL_HEIGHT = 44;

// Repli si bbox_w/h/d absentes (décor solide, is_decor=true hors murs) :
// blocs empilables, statues, etc. Le pas de hauteur 12 correspond à
// l'empilement observé des blocs (ex. gridZ 0x80 -> 0x8C -> 0x98) --
// confirmé identique à la vraie bbox du type 0x07 (8,8,12).
const BLOCK_HALF_EXTENT = 8;
const BLOCK_HEIGHT = 12;

// Plan de sol synthétique : aucune entité du manifest ne représente le
// sol -- sans lui, rien n'existe pour que la gravité fasse atterrir le
// joueur. BUG TROUVÉ EN TESTANT (2026-09-04) : l'étendue était dérivée de
// la boîte englobante des entités de la salle -- pour une salle "étroite"
// (ex. 0x2e, entités seulement entre Y=99 et Y=160 alors que la vraie
// salle va de 59 à 196), le sol s'arrêtait bien avant le vrai bord, d'où
// une chute en s'approchant d'un côté sans mur. Corrigé : étendue fixée
// aux constantes UNIVERSELLES de bord de salle (scene/roomTransition.ts,
// vérifiées identiques sur un échantillon de salles), pas une
// approximation par salle.
const FLOOR_TOP_Z = 0x80;
const FLOOR_THICKNESS = 16;

/** Boîte d'une entité de décor : vraies demi-étendues bbox_w/h/d (X/Y) et
 * hauteur (Z) quand les TROIS sont présentes (toujours ensemble ou
 * aucune, voir data/types.ts), sinon les valeurs de repli approximatives
 * passées en paramètre. Un bbox à 0 sur un axe (mur fin, orienté selon
 * son sens) est une vraie donnée, pas un bug. */
function entityBox(
  entity: RoomEntity,
  fallbackHalfX: number,
  fallbackHalfY: number,
  fallbackHeight: number,
): Box3 {
  const hasRealBbox = entity.bboxW !== undefined && entity.bboxH !== undefined && entity.bboxD !== undefined;
  const halfX = hasRealBbox ? entity.bboxW! : fallbackHalfX;
  const halfY = hasRealBbox ? entity.bboxH! : fallbackHalfY;
  const height = hasRealBbox ? entity.bboxD! : fallbackHeight;
  return {
    minX: entity.gridX - halfX,
    maxX: entity.gridX + halfX,
    minY: entity.gridY - halfY,
    maxY: entity.gridY + halfY,
    minZ: entity.gridZ,
    maxZ: entity.gridZ + height,
  };
}

/**
 * IMPORTANT (vérifié sur les données réelles, contraire à l'intuition du
 * nom) : `isDecor` marque le décor D'ENVIRONNEMENT SOLIDE (murs, blocs
 * empilés) -- PAS l'inverse. Les éléments interactifs non-solides
 * (montants de porte 0x02/0x03, pickups) ont `isDecor=false` dans le
 * manifest. Conséquence pratique : les montants de porte sont exclus des
 * obstacles automatiquement, sans exception à coder -- traversables pour
 * l'instant, en attendant les transitions de salle.
 */
// Note validée en testant (2026-09-04) : les montants de porte
// (isDecor=false, exclus des obstacles ci-dessous) laissent PASSER --
// c'est voulu (pas encore de vraie contrainte physique de porte), pas un
// trou dans un mur. Confirmé : là où il n'y a pas de porte, la couverture
// des murs reste continue et bloque bien. Reste à traiter plus tard : la
// HAUTEUR de la porte pour l'entrée/sortie (ex. ne pas pouvoir sauter
// par-dessus une porte basse) -- hors sujet ici, la règle de base
// "porte=passable, mur=bloqué" est respectée.
export function buildObstacles(entities: RoomEntity[]): Obstacle[] {
  const obstacles: Obstacle[] = [];

  for (const entity of entities) {
    if (entity.isWall) {
      obstacles.push({ kind: "wall", box: entityBox(entity, WALL_HALF_EXTENT, WALL_HALF_EXTENT, WALL_HEIGHT) });
    } else if (entity.isDecor) {
      obstacles.push({ kind: "block", box: entityBox(entity, BLOCK_HALF_EXTENT, BLOCK_HALF_EXTENT, BLOCK_HEIGHT) });
    }
  }

  obstacles.push({
    kind: "floor",
    box: {
      minX: ROOM_EDGE_MIN,
      maxX: ROOM_EDGE_MAX,
      minY: ROOM_EDGE_MIN,
      maxY: ROOM_EDGE_MAX,
      minZ: FLOOR_TOP_Z - FLOOR_THICKNESS,
      maxZ: FLOOR_TOP_Z,
    },
  });

  return obstacles;
}
