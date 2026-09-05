// Construit la liste d'obstacles statiques d'une salle pour le solveur
// AABB (physics/aabb.ts), à partir des entités déjà chargées
// (data/roomManifest.ts). Utilise les VRAIES demi-étendues bbox_w/h
// (X/Y) quand elles sont disponibles (murs/portes -- extraites de la
// table ROM statique tbl_room_connection_detail_*, voir
// tools/room_map/enrich_bbox.py et docs/SYMBOLS.md +0x04-06). Pour le
// décor SANS bbox connue (ex. blocs intérieurs placés salle par salle,
// hors table de jonction), retombe sur un footprint approximatif par
// catégorie -- ce repli est resté correct pour les blocs une fois vérifié
// contre la vraie table (0x07 : bbox réelle (8,8,12), identique à la
// valeur devinée ci-dessous). Hauteur (Z) : `bbox_d` est utilisée pour
// les BLOCS (on peut sauter dessus/dessous), mais PAS pour les murs, qui
// bloquent à toute hauteur -- voir buildSideWalls().

import type { RoomEntity } from "../data/types";
import { isSolidType, pushPolicyFor } from "./solidTypes";
import type { Box3 } from "./aabb";
import { ROOM_EDGE_MIN, ROOM_EDGE_MAX, DOOR_TYPES, DOOR_GAP_HALF_WIDTH } from "../scene/roomTransition";

/** Ce qu'un obstacle expose quand le heurter doit le DÉPLACER.
 *
 * FAIT ROM : `fn_entity_collide_axis_x`/`_y` (#244C/#249B) recopient le vecteur
 * en attente du mobile dans celui de l'entité heurtée quand elle porte le bit 2
 * de `flags` -- voir physics/solidTypes.ts. Décrit ici en interface minimale
 * (et non par un import de scene/pushables.ts) pour que la physique ne dépende
 * pas de la scène : c'est la scène qui vient s'y brancher. */
export interface PushTarget {
  /** Reçoit le pas ENTIER du mobile sur cet axe (pas le reliquat rogné --
   * la ROM recopie `(ix+09)`, l'octet de structure, pas le registre de
   * travail). */
  receivePush(axis: "x" | "y", delta: number): void;
}

export interface Obstacle {
  box: Box3;
  /** Catégorie d'origine -- uniquement pour le débogage visuel (voir
   * debug/topView.ts), sans effet sur la résolution physique elle-même. */
  kind: "wall" | "block" | "floor";
  /** Présent seulement sur les obstacles qui sont des corps mobiles poussables
   * (scene/pushables.ts). `undefined` = décor inerte. */
  pushTarget?: PushTarget;
}

// Repli si bbox_w/h absentes (murs) : demi-étendue X/Y fixe centrée sur
// le point d'ancrage -- seulement pour un mur qui ne serait pas couvert
// par la table de jonction (ne devrait normalement pas arriver, tous les
// murs observés jusqu'ici l'ont été).
const WALL_HALF_EXTENT = 8;

// RÈGLE CONFIRMÉE PAR L'UTILISATEUR EN TESTANT (2026-09-04) : un mur est
// infranchissable QUELLE QUE SOIT LA HAUTEUR du personnage -- seule une
// porte permet de passer (à n'importe quelle hauteur). `bbox_d` (hauteur
// réelle par entité) NE DOIT DONC PAS être utilisé pour les murs : un
// mur enregistré haut dans la pile (ex. salle 0xf1, type 0x08 à
// gridZ=160, une des couches empilées formant un mur complet) laissait
// traverser en dessous puisque sa boîte ne couvrait que sa propre tranche
// de hauteur. Un mur ignore sa propre position/hauteur Z enregistrée et
// couvre systématiquement toute la hauteur praticable de la salle.
const WALL_MIN_Z = 0x00;
const WALL_MAX_Z = 0xff;

// Type 0x08 ("small_block/herse" partagé) : tenté comme mur solide
// (2026-09-04) après une observation en salle 0xf1, REVENU EN ARRIÈRE
// le jour même -- ça bloquait les portes, parce que ce type est en
// réalité positionné dans le COULOIR de la porte (son étendue Y
// correspond presque exactement à l'écart entre les deux montants),
// cohérent avec la HERSE (grille mobile, `fn_moving_grate_logic`) et pas
// un mur : elle avait été capturée LEVÉE (ouverte) dans cette salle, d'où
// le passage possible en dessous -- fidèle à cet instant précis du jeu
// réel, pas un bug. Pas de simulation du cycle monter/descendre pour
// l'instant (chantier à part) : `is_wall` vaut `false` et isSolidType()
// rend `false` pour
// ce type, donc non-solide, comme avant.

// Repli si bbox_w/h/d absentes (décor solide, isSolidType() hors murs) :
// blocs empilables, statues, etc. Le pas de hauteur 12 correspond à
// l'empilement observé des blocs (ex. gridZ 0x80 -> 0x8C -> 0x98) --
// confirmé identique à la vraie bbox du type 0x07 (8,8,12).
export const BLOCK_HALF_EXTENT = 8;
export const BLOCK_HEIGHT = 12;

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

/** Boîte d'une entité de décor (bloc, PAS un mur -- voir buildSideWalls) : vraies
 * demi-étendues bbox_w/h/d (X/Y/Z) quand les TROIS sont présentes
 * (toujours ensemble ou aucune, voir data/types.ts), sinon les valeurs de
 * repli approximatives passées en paramètre. */
export function entityBox(
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

// BUG TROUVÉ EN TESTANT (2026-09-04) : un obstacle par segment de mur
// individuel laisse de VRAIS trous entre segments (données réelles mais
// imparfaites -- rien ne garantit que les segments réutilisés couvrent
// tout le côté d'une salle sans interruption), permettant de se glisser
// jusqu'à la ligne de bord sans passer par une porte. Corrigé en
// construisant, PAR CÔTÉ DE SALLE (X min/max, Y min/max), UNE barrière
// continue couvrant tout `[ROOM_EDGE_MIN, ROOM_EDGE_MAX]`, découpée
// uniquement aux emplacements réels des portes -- plutôt que de corriger
// les trous segment par segment. Un côté sans la moindre entité `isWall`
// reste entièrement ouvert (la "boîte ouverte" du moteur original, voir
// scene/room.ts) : rien n'y est ajouté.
// Repli seulement (bbox absente) : proximité de coordonnée.
const SIDE_TOLERANCE = 15;

type SideAxis = "x" | "y";
interface RoomSide {
  axis: SideAxis;
  edge: number;
}
const ROOM_SIDES: RoomSide[] = [
  { axis: "x", edge: ROOM_EDGE_MIN },
  { axis: "x", edge: ROOM_EDGE_MAX },
  { axis: "y", edge: ROOM_EDGE_MIN },
  { axis: "y", edge: ROOM_EDGE_MAX },
];

/**
 * BUG TROUVÉ EN TESTANT (2026-09-04) : classer un mur par simple
 * PROXIMITÉ DE COORDONNÉE à un bord est ambigu dans les coins -- un
 * segment du mur NORD (fin en Y, bbox_h=0) dont le gridX est fortuitement
 * proche du bord EST (coin de la salle) se faisait classer à tort comme
 * mur du côté EST, créant un faux mur là où le côté est censé rester
 * ouvert (porte franchissable sur toute sa largeur au lieu de seulement
 * au droit de la porte). Corrigé : utiliser la VRAIE géométrie de
 * l'entité (quel axe a une demi-étendue nulle -- bbox_w=0 = mur fin en X,
 * orienté est/ouest ; bbox_h=0 = mur fin en Y, orienté nord/sud) plutôt
 * qu'une distance -- sans ambiguïté possible, contrairement à une
 * coordonnée seule. La proximité de coordonnée ne sert plus que de repli
 * quand la vraie bbox est absente.
 */
function classifyWallSide(wall: RoomEntity): RoomSide | null {
  const hasRealBbox = wall.bboxW !== undefined && wall.bboxH !== undefined;
  if (hasRealBbox) {
    const isXOriented = wall.bboxW === 0 && wall.bboxH !== 0;
    const isYOriented = wall.bboxH === 0 && wall.bboxW !== 0;
    if (isXOriented) {
      const edge = Math.abs(wall.gridX - ROOM_EDGE_MIN) <= Math.abs(wall.gridX - ROOM_EDGE_MAX) ? ROOM_EDGE_MIN : ROOM_EDGE_MAX;
      return { axis: "x", edge };
    }
    if (isYOriented) {
      const edge = Math.abs(wall.gridY - ROOM_EDGE_MIN) <= Math.abs(wall.gridY - ROOM_EDGE_MAX) ? ROOM_EDGE_MIN : ROOM_EDGE_MAX;
      return { axis: "y", edge };
    }
    // ni l'un ni l'autre nul (rare, mur "plein" sans orientation claire) :
    // retombe sur la proximité ci-dessous.
  }
  if (Math.abs(wall.gridX - ROOM_EDGE_MIN) <= SIDE_TOLERANCE) return { axis: "x", edge: ROOM_EDGE_MIN };
  if (Math.abs(wall.gridX - ROOM_EDGE_MAX) <= SIDE_TOLERANCE) return { axis: "x", edge: ROOM_EDGE_MAX };
  if (Math.abs(wall.gridY - ROOM_EDGE_MIN) <= SIDE_TOLERANCE) return { axis: "y", edge: ROOM_EDGE_MIN };
  if (Math.abs(wall.gridY - ROOM_EDGE_MAX) <= SIDE_TOLERANCE) return { axis: "y", edge: ROOM_EDGE_MAX };
  return null;
}

/** Soustrait une liste d'intervalles "trou" (les portes) d'un intervalle
 * [min,max], retourne les segments restants (fermés, bloquants). */
function subtractGaps(min: number, max: number, gaps: [number, number][]): [number, number][] {
  let intervals: [number, number][] = [[min, max]];
  for (const [gMin, gMax] of gaps) {
    const next: [number, number][] = [];
    for (const [a, b] of intervals) {
      if (gMax <= a || gMin >= b) {
        next.push([a, b]); // pas de recouvrement avec ce trou
        continue;
      }
      if (gMin > a) next.push([a, gMin]);
      if (gMax < b) next.push([gMax, b]);
    }
    intervals = next;
  }
  return intervals;
}

/** Valeur la plus fréquente parmi les entités mur d'un côté -- la ligne
 * du mur (normalement identique pour toutes, ex. X=0x3F pour un côté
 * ouest), avec un repli raisonnable si jamais aucune ne concorde. */
function modeCoordinate(values: number[], fallback: number): number {
  if (values.length === 0) return fallback;
  const counts = new Map<number, number>();
  for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
  let best = values[0]!;
  let bestCount = 0;
  for (const [v, c] of counts) {
    if (c > bestCount) {
      best = v;
      bestCount = c;
    }
  }
  return best;
}

function buildSideWalls(entities: RoomEntity[], doors: RoomEntity[]): Obstacle[] {
  const wallEntities = entities.filter((e) => e.isWall);
  const obstacles: Obstacle[] = [];

  for (const side of ROOM_SIDES) {
    const onSide = wallEntities.filter((w) => {
      const classified = classifyWallSide(w);
      return classified !== null && classified.axis === side.axis && classified.edge === side.edge;
    });
    if (onSide.length === 0) continue; // côté ouvert par conception, aucun mur -- rien à ajouter

    const runCoord = modeCoordinate(
      onSide.map((w) => (side.axis === "x" ? w.gridX : w.gridY)),
      side.edge,
    );

    const doorsOnSide = doors.filter((d) => (side.axis === "x" ? d.gridX === side.edge : d.gridY === side.edge));
    const gaps: [number, number][] = doorsOnSide.map((d) => {
      const perp = side.axis === "x" ? d.gridY : d.gridX;
      return [perp - DOOR_GAP_HALF_WIDTH, perp + DOOR_GAP_HALF_WIDTH];
    });

    for (const [a, b] of subtractGaps(ROOM_EDGE_MIN, ROOM_EDGE_MAX, gaps)) {
      if (b <= a) continue;
      const box: Box3 =
        side.axis === "x"
          ? {
              minX: runCoord - WALL_HALF_EXTENT,
              maxX: runCoord + WALL_HALF_EXTENT,
              minY: a,
              maxY: b,
              minZ: WALL_MIN_Z,
              maxZ: WALL_MAX_Z,
            }
          : {
              minX: a,
              maxX: b,
              minY: runCoord - WALL_HALF_EXTENT,
              maxY: runCoord + WALL_HALF_EXTENT,
              minZ: WALL_MIN_Z,
              maxZ: WALL_MAX_Z,
            };
      obstacles.push({ kind: "wall", box });
    }
  }

  return obstacles;
}

/**
 * La solidité vient de `isSolidType()` (physics/solidTypes.ts), une
 * politique du PORTAGE indexée par type ROM -- PAS d'un champ du manifest.
 * L'outil d'extraction n'exporte que des faits observés (type, position,
 * bbox) ; c'est ici qu'on décide ce qui bloque.
 *
 * Les éléments interactifs non-solides (montants de porte 0x02/0x03,
 * pickups) ne sont donc jamais des obstacles, sans exception à coder --
 * traversables pour l'instant.
 *
 * BUG TROUVÉ EN TESTANT (2026-09-04) : plusieurs types ROM différents
 * (bloc mobile 0x36/0x37, poussable 0x3E, cube qui s'enfonce 0x5B, bloc
 * dormant 0x8F) partagent le MÊME sprite qu'un bloc statique solide (0x07,
 * sprite_small_block_59DB) mais manquaient à la classification physique --
 * des cubes visuellement identiques étaient tantôt solides, tantôt
 * traversables. Cause profonde : la solidité était lue dans `DECOR_TYPES`
 * (tools/room_map/teleport.py), une classification écrite pour produire
 * une CARTE lisible, réutilisée telle quelle comme vérité physique. Voir
 * physics/solidTypes.ts pour le détail et la règle générale.
 *
 * Note validée en testant (2026-09-04) : les montants de porte laissent
 * PASSER -- c'est voulu (pas encore de contrainte physique de porte), pas
 * un trou dans un mur ; là où il n'y a pas de porte la couverture des murs
 * reste continue et bloque bien. Reste à traiter : la HAUTEUR de la porte
 * (ex. ne pas pouvoir sauter par-dessus une porte basse).
 */
export function buildObstacles(entities: RoomEntity[]): Obstacle[] {
  const doors = entities.filter((e) => DOOR_TYPES.has(e.type));
  const obstacles: Obstacle[] = buildSideWalls(entities, doors);

  for (const entity of entities) {
    // Les corps mobiles (table/coffre/bloc poussable) sont exclus du décor
    // statique : ils fournissent leur propre obstacle à leur position
    // COURANTE (scene/pushables.ts, mergeObstacles ci-dessous). Les inclure
    // ici laisserait un obstacle fantôme à leur position de départ.
    if (pushPolicyFor(entity.type, entity.flags) !== null) continue;
    if (isSolidType(entity.type) && !entity.isWall) {
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
