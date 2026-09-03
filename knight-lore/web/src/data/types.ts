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
}

export function parseHexByte(hex: string): number {
  return parseInt(hex, 16) & 0xff;
}
