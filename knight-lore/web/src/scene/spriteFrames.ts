// Chargement de frames par TYPE D'ENTITÉ ROM, partagé joueur / garde.
//
// Le portage n'écrit plus de tableaux d'URL de sprites à la main : il
// indexe le SpriteIndex (data/spriteManifest.ts), qui est déjà la copie
// extraite de `tbl_sprite_dispatch` (#429E). Chaque tableau transcrit à la
// main était une occasion de se tromper indépendamment des autres -- c'est
// exactement ce qui avait produit le bug d'orientation des jambes du
// joueur (un seul jeu de dessins recopié, là où la ROM en a deux).

import type { SpriteIndex } from "../data/spriteManifest";
import { getTexture } from "./room";

/** Une frame chargée : texture GPU, dimensions logiques, et le bit6 de
 * l'octet de forme AU MOMENT DE LA CAPTURE (voir SpriteInfo.hflipState).
 * Ce dernier est indispensable au rendu : le miroir effectif est le XOR de
 * ce bit avec le bit6 de `flags` de l'entité, pas l'un des deux seul. */
export interface LoadedFrame {
  texture: WebGLTexture;
  width: number;
  height: number;
  hflipState: boolean;
}

/** Charge les frames des types donnés, dans l'ordre. Passe par le cache de
 * textures partagé (scene/room.ts::getTexture) : les sprites de jambes
 * `feet1-8`, communs au joueur et au garde (mêmes adresses ROM), ne sont
 * donc chargés qu'une fois. */
export async function loadFramesByType(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
  types: readonly number[],
  who: string,
): Promise<LoadedFrame[]> {
  return Promise.all(
    types.map(async (type): Promise<LoadedFrame> => {
      const sprite = spriteIndex.get(type);
      if (!sprite) {
        throw new Error(`${who}: sprite manquant pour le type 0x${type.toString(16)}`);
      }
      return {
        texture: await getTexture(gl, sprite.url),
        width: sprite.width,
        height: sprite.height,
        hflipState: sprite.hflipState,
      };
    }),
  );
}
