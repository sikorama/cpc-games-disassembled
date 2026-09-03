// Types miroirs de asm/include/entity_struct.equ.asm et
// asm/include/entity_types.equ.asm — traduction directe des structures
// désassemblées, pas de logique de jeu ici.

/** Entrée brute d'une salle telle qu'exportée par
 * tools/room_map/teleport.py dans rooms_manifest.json. */
export interface RawRoomEntity {
  slot: number;
  type: string; // "0x1e" style
  label: string;
  grid: [string, string, string]; // grid_x, grid_y, grid_z_or_offset (hex strings)
  flags: string;
  room: string;
  is_decor: boolean;
  is_wall: boolean;
  /** Dimensions AABB réelles (docs/SYMBOLS.md +0x04-06), extraites de la
   * table ROM statique tbl_room_connection_detail_* par
   * tools/room_map/enrich_bbox.py -- absentes pour tout ce qui n'est pas
   * du décor de jonction (murs/portes), voir physics/obstacles.ts pour
   * le repli sur une valeur approximative dans ce cas. */
  bbox_w?: string;
  bbox_h?: string;
  bbox_d?: string;
}

export interface RawRoomManifest {
  [roomId: string]: {
    verified: boolean;
    entities: RawRoomEntity[];
  };
}

/** Entité de décor décodée, prête pour le rendu. Coordonnées en unités
 * de grille brutes (0-255), PAS converties en pixels écran — voir
 * render/isoMath.ts, c'est la caméra qui projette. */
export interface RoomEntity {
  type: number;
  gridX: number;
  gridY: number;
  gridZ: number;
  flags: number;
  /** Pass-through direct de RawRoomEntity.is_wall/is_decor -- voir
   * physics/obstacles.ts. Attention : `isDecor` marque le décor
   * D'ENVIRONNEMENT SOLIDE (murs, blocs empilés), PAS l'inverse -- les
   * éléments interactifs non-solides (montants de porte, pickups) ont
   * isDecor=false, vérifié sur les données réelles du manifest. */
  isWall: boolean;
  isDecor: boolean;
  /** Demi-étendues X/Y et hauteur Z RÉELLES (voir RawRoomEntity), absentes
   * pour le décor hors table de jonction (ex. blocs intérieurs placés
   * salle par salle) -- toujours les trois ensemble ou aucune. */
  bboxW?: number;
  bboxH?: number;
  bboxD?: number;
}

export function parseHexByte(hex: string): number {
  return parseInt(hex, 16) & 0xff;
}

/** Position de spawn d'un garde, appariée corps+jambes (voir
 * data/roomManifest.ts::loadGuardSpawns et scene/guard.ts) -- deux vraies
 * entités ROM à la MÊME position de grille, PAS une entité inventée pour
 * le portage (contrairement au joueur). */
export interface GuardSpawn {
  gridX: number;
  gridY: number;
  gridZ: number;
  bodyType: number;
  legsType: number;
}
