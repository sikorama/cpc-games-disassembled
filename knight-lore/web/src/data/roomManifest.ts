import { parseHexByte, type GuardSpawn, type RawRoomManifest, type RoomEntity } from "./types";

// Types "garde" (corps 0x1E/0x1F/0x9E/0x9F -- Melkhior réutilise la même
// entité, cf. web/CONTEXT.md "Personnage en deux entités" -- et jambes
// 0x90-0x9D) : entités ROM réelles, simulées dynamiquement (scene/guard.ts)
// plutôt qu'affichées en décor figé -- voir aussi isExcludedFromStaticRender.
function isGuardBodyType(type: number): boolean {
  return type === 0x1e || type === 0x1f || type === 0x9e || type === 0x9f;
}
function isGuardLegsType(type: number): boolean {
  return type >= 0x90 && type <= 0x9d;
}

// Types à exclure du rendu statique de cette première étape (voir plan) :
// joueur (slots 0/1, filtrés séparément), famille pickup 0x60-0x67 (le
// TYPE tourne aléatoirement par partie, fn_catalog_randomize_types —
// non pertinent pour un rendu de décor), famille "offrande"/transitoire
// 0x68-0x6E et 0xB8/0xB9/0xBB (états intermédiaires, pas des entités de
// décor stables), garde (corps+jambes -- simulé dynamiquement, pas du décor).
function isExcludedFromStaticRender(type: number): boolean {
  if (type === 0) return true;
  if (type >= 0x60 && type <= 0x6e) return true;
  if (type === 0xb8 || type === 0xb9 || type === 0xbb) return true;
  if (isGuardBodyType(type) || isGuardLegsType(type)) return true;
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
      slot: e.slot,
      gridX: parseHexByte(e.grid[0]),
      gridY: parseHexByte(e.grid[1]),
      gridZ: parseHexByte(e.grid[2]),
      flags: parseHexByte(e.flags),
      isWall: e.is_wall,
      isDecor: e.is_decor,
      bboxW: e.bbox_w !== undefined ? parseHexByte(e.bbox_w) : undefined,
      bboxH: e.bbox_h !== undefined ? parseHexByte(e.bbox_h) : undefined,
      bboxD: e.bbox_d !== undefined ? parseHexByte(e.bbox_d) : undefined,
    }))
    .filter((e) => !isExcludedFromStaticRender(e.type));
}

/** Appareille chaque entité "corps" de garde avec l'entité "jambes" à la
 * MÊME position de grille exacte (vérifié sur toutes les instances
 * réelles trouvées dans le manifest, ex. salle 0x2e slots 30/31). Un
 * corps sans jambes correspondantes (ne devrait pas arriver, mais pas de
 * garde à moitié rendu) est ignoré plutôt que de planter. */
export async function loadGuardSpawns(roomId: number): Promise<GuardSpawn[]> {
  const manifest = await fetchManifest();

  const key = `0x${roomId.toString(16).padStart(2, "0")}`;
  const room = manifest[key];
  if (!room) {
    throw new Error(`room ${key} not found in rooms_manifest.json`);
  }

  const bodies = room.entities.filter((e) => isGuardBodyType(parseHexByte(e.type)));
  const legs = room.entities.filter((e) => isGuardLegsType(parseHexByte(e.type)));

  const spawns: GuardSpawn[] = [];
  for (const body of bodies) {
    const gridX = parseHexByte(body.grid[0]);
    const gridY = parseHexByte(body.grid[1]);
    const gridZ = parseHexByte(body.grid[2]);
    const matchingLegs = legs.find((l) => parseHexByte(l.grid[0]) === gridX && parseHexByte(l.grid[1]) === gridY);
    if (!matchingLegs) continue;
    spawns.push({
      gridX,
      gridY,
      gridZ,
      bodyType: parseHexByte(body.type),
      legsType: parseHexByte(matchingLegs.type),
    });
  }
  return spawns;
}
