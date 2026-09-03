// Charge public/sprites/manifest.json (copie de tools/sprite_dump_out/,
// voir scripts/sync-assets.mjs) et construit l'index type d'entité -> sprite.

interface SpriteShapeEntry {
  types: string[]; // ex ["67","8C","AF"] -- hex 2 chiffres, sans préfixe
  width: number;
  height: number;
  file: string;
  hflip_state: boolean;
  vflip_state: boolean;
}

interface RawSpriteManifest {
  tbl_sprite_dispatch_base: string;
  count: number;
  shapes: Record<string, SpriteShapeEntry>;
}

export interface SpriteInfo {
  url: string;
  width: number;
  height: number;
  /** bit6 de l'octet0 de forme AU MOMENT de la capture (voir
   * tools/sprite_dump.py -- nommé "vflip_state" côté outil Python, mais
   * c'est bien CE bit, pas hflip_state, qui varie réellement dans les
   * données : hflip_state est quasi toujours False (2/103 sprites),
   * vflip_state varie (39/103) -- cohérent avec le mécanisme de
   * bascule décrit dans docs/RENDERING_PIPELINE.md §6). Le jeu original
   * MUTE ce bit EN PLACE dans le sprite partagé -- ce n'est donc PAS un
   * état "neutre" fixe, juste un instantané. Pour reproduire le miroir
   * correctement pour une entité donnée, comparer ce champ (XOR) au
   * bit6 de ses off_flags, PAS utiliser l'un ou l'autre seul -- voir
   * scene/room.ts. */
  hflipState: boolean;
}

/** Index direct type d'entité (0-255) -> info sprite. Types sans forme
 * connue (sentinelle #00, non décodés) sont simplement absents. */
export type SpriteIndex = Map<number, SpriteInfo>;

export async function loadSpriteIndex(): Promise<SpriteIndex> {
  const res = await fetch("/sprites/manifest.json");
  const manifest: RawSpriteManifest = await res.json();

  const index: SpriteIndex = new Map();
  for (const shape of Object.values(manifest.shapes)) {
    const info: SpriteInfo = {
      url: `/sprites/${shape.file}`,
      // Vérifié en direct 2026-08-14 (screen_w/screen_h réels lus en RAM,
      // ex. type 0x07 : screen_wh=(8,29) -> pixels (8*4,29)=(32,29),
      // EXACTEMENT égal à manifest.width/height tels quels, sans
      // inversion) : PAS de swap ici, malgré la rotation interne de
      // tools/sprite_dump.py -- cette rotation ne change pas le sens
      // logique width/height du manifest, seulement l'orientation du
      // contenu texture (compensée dans le shader, voir gl/spriteBatch.ts).
      width: shape.width,
      height: shape.height,
      hflipState: shape.vflip_state,
    };
    for (const typeHex of shape.types) {
      index.set(parseInt(typeHex, 16), info);
    }
  }
  return index;
}
