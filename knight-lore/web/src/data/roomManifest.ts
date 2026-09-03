import { parseHexByte, type RawRoomManifest, type RoomEntity } from "./types";

// Types à exclure du rendu statique de cette première étape (voir plan) :
// joueur (slots 0/1, filtrés séparément), famille pickup 0x60-0x67 (le
// TYPE tourne aléatoirement par partie, fn_catalog_randomize_types —
// non pertinent pour un rendu de décor), famille "offrande"/transitoire
// 0x68-0x6E et 0xB8/0xB9/0xBB (états intermédiaires, pas des entités de
// décor stables).
function isExcludedFromStaticRender(type: number): boolean {
  if (type === 0) return true;
  if (type >= 0x60 && type <= 0x6e) return true;
  if (type === 0xb8 || type === 0xb9 || type === 0xbb) return true;
  return false;
}

let manifestPromise: Promise<RawRoomManifest> | null = null;

function fetchManifest(): Promise<RawRoomManifest> {
  if (!manifestPromise) {
    manifestPromise = fetch("/rooms/rooms_manifest.json").then((res) => res.json());
  }
  return manifestPromise;
}

/** Liste des room_id disponibles dans rooms_manifest.json, triés --
 * pour peupler le sélecteur de salle (voir main.ts). */
export async function listRoomIds(): Promise<number[]> {
  const manifest = await fetchManifest();
  return Object.keys(manifest)
    .map((key) => parseHexByte(key))
    .sort((a, b) => a - b);
}

export async function loadRoomEntities(roomId: number): Promise<RoomEntity[]> {
  const manifest = await fetchManifest();

  const key = `0x${roomId.toString(16).padStart(2, "0")}`;
  const room = manifest[key];
  if (!room) {
    throw new Error(`room ${key} not found in rooms_manifest.json`);
  }

  return room.entities
    .filter((e) => e.slot !== 0 && e.slot !== 1)
    .map((e) => ({
      type: parseHexByte(e.type),
      gridX: parseHexByte(e.grid[0]),
      gridY: parseHexByte(e.grid[1]),
      gridZ: parseHexByte(e.grid[2]),
      flags: parseHexByte(e.flags),
      isWall: e.is_wall,
      isDecor: e.is_decor,
    }))
    .filter((e) => !isExcludedFromStaticRender(e.type));
}
