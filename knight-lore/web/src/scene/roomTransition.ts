// Franchissement de bord de salle -> salle voisine. Logique pure, sans
// chargement (voir main.ts pour l'orchestration async) -- cohérent avec
// scene/player.ts.
//
// Mécanique confirmée par désassemblage (implémentation propre, PAS un
// portage littéral) : la salle voisine est une pure arithmétique sur
// l'ID de salle (nibble bas = colonne, nibble haut = ligne d'une grille
// monde 16x16), PAS une table de correspondance -- `tbl_room_connections`
// (0x0147) a été vérifié n'être QUE du décor de jonction (portes/murs
// affichés à la frontière), jamais lu pour résoudre la salle cible (voir
// docs/SYMBOLS.md:215, notes/2026-08-13-hypothesis-cross-reference-audit.md).
// Le vrai mécanisme (fn_player_door_transition,
// asm/code/doors_and_player_logic.asm:674-831) modifie directement
// off_room_number (+0x08) : Est/Ouest = ±1 sur le nibble bas (wrap mod
// 16), Nord/Sud = ±0x10 sur l'octet entier. Confirmé indépendamment par
// tools/room_map/stitch.py (même formule).
//
// Seuils de bord : vérifiés empiriquement sur un échantillon aléatoire de
// salles -- les montants de porte (types 0x02/0x03) n'apparaissent
// JAMAIS qu'à exactement 4 valeurs de coordonnée : 0x3B, 0x73, 0x8D,
// 0xC4. Les deux extrêmes (0x3B/0xC4) sont des constantes UNIVERSELLES de
// bord de salle (contrairement à l'étendue des murs eux-mêmes, qui varie
// selon la salle). Comme les murs bloquent déjà tout le reste
// (physics/obstacles.ts) et que certains côtés de salle n'ont même aucun
// mur ("boîte ouverte"), détecter le franchissement via ces deux
// constantes suffit -- pas besoin d'identifier individuellement chaque
// porte ni sa cible (que la donnée ne contient de toute façon pas :
// vérifié, le champ `room` d'une porte vaut sa PROPRE salle, jamais une
// destination).

import type { PlayerState } from "./player";

export const ROOM_EDGE_MIN = 0x3b;
export const ROOM_EDGE_MAX = 0xc4;
// Marge d'entrée dans la salle voisine -- assez grande pour qu'un pas de
// mouvement normal ne re-déclenche pas immédiatement une transition dans
// l'autre sens.
const ENTRY_MARGIN = 10;

export type EdgeAxis = "x" | "y";
export type EdgeSide = "min" | "max";

export interface EdgeCrossing {
  axis: EdgeAxis;
  side: EdgeSide;
}

/** Premier axe/côté dépassé (X avant Y, arbitraire mais déterministe --
 * un franchissement en coin ne doit déclencher qu'UNE transition). */
export function detectEdgeCrossing(player: PlayerState): EdgeCrossing | null {
  if (player.gridX < ROOM_EDGE_MIN) return { axis: "x", side: "min" };
  if (player.gridX > ROOM_EDGE_MAX) return { axis: "x", side: "max" };
  if (player.gridY < ROOM_EDGE_MIN) return { axis: "y", side: "min" };
  if (player.gridY > ROOM_EDGE_MAX) return { axis: "y", side: "max" };
  return null;
}

/** ID de salle voisine -- nibble bas (colonne) pour X, octet entier
 * (pas de nibble) pour Y puisque ±0x10 ne touche jamais le nibble bas. */
export function neighborRoomId(roomId: number, crossing: EdgeCrossing): number {
  if (crossing.axis === "x") {
    const lowNibble = crossing.side === "max" ? (roomId + 1) & 0x0f : (roomId - 1) & 0x0f;
    return (roomId & 0xf0) | lowNibble;
  }
  const delta = crossing.side === "max" ? 0x10 : -0x10;
  return (roomId + delta) & 0xff;
}

/** Place le joueur juste à l'intérieur du bord opposé sur l'axe franchi,
 * CONSERVE l'autre coordonnée telle quelle (pas de reflet façon ROM --
 * plus simple, et ça fait apparaître le joueur au bon endroit
 * perpendiculaire dans la salle suivante). Atterrissage par défaut dans
 * la nouvelle salle : gridZ au sol, vitesse verticale nulle. */
export function repositionForEntry(player: PlayerState, crossing: EdgeCrossing): void {
  const entryCoord = crossing.side === "max" ? ROOM_EDGE_MIN + ENTRY_MARGIN : ROOM_EDGE_MAX - ENTRY_MARGIN;
  if (crossing.axis === "x") {
    player.gridX = entryCoord;
  } else {
    player.gridY = entryCoord;
  }
  player.gridZ = 0x80;
  player.velZ = 0;
  player.airborne = false;
}

/** Bloque le joueur pile au bord si la salle voisine calculée n'existe
 * pas (bord du monde, ou case de la grille 16x16 inutilisée) -- traité
 * comme un mur plutôt que de charger une salle inexistante. */
export function clampToEdge(player: PlayerState, crossing: EdgeCrossing): void {
  const edgeCoord = crossing.side === "max" ? ROOM_EDGE_MAX : ROOM_EDGE_MIN;
  if (crossing.axis === "x") {
    player.gridX = edgeCoord;
  } else {
    player.gridY = edgeCoord;
  }
}
