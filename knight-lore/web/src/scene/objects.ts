// Rendu des objets à ramasser présents dans la salle courante.
//
// POURQUOI UN MODULE À PART, et pas le rendu de décor. Les objets ne sont pas
// des données de salle : ils vivent dans un catalogue global de 32
// emplacements (game/objectCatalog.ts) que le jeu réattribue au lancement de
// chaque partie. Le manifest de salles, lui, a été capturé sur UNE partie en
// cours et contient donc ses objets à elle -- vérifié, ce sont exactement ceux
// de la rotation 1. Les prendre du manifest reviendrait à rejouer éternellement
// la partie qui a servi à l'extraction.
//
// Le sprite est donc adressé par le type que le CATALOGUE attribue, jamais par
// celui qui traîne dans le manifest. C'est toute la raison d'être de ce
// fichier.

import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { SpriteIndex } from "../data/spriteManifest";
import type { ViewAngle } from "../render/isoMath";
import { rotateGrid, viewNeedsFlip } from "../render/isoMath";
import { getProjOffset } from "../render/isoOffsets";
import { getTexture } from "./room";
import type { PlacedObject } from "../game/objectCatalog";

/** Objet résolu : sprite chargé pour le type que le catalogue lui a donné. */
export interface RoomObject {
  placed: PlacedObject;
  texture: WebGLTexture;
  width: number;
  height: number;
  hflipState: boolean;
}

/**
 * Charge les objets d'une salle. Zéro ou un en pratique -- les 32 emplacements
 * sont dans 32 salles distinctes -- mais on garde une liste, parce que c'est
 * une propriété des DONNÉES et non une garantie du code (voir
 * game/objectCatalog.ts).
 */
export async function loadRoomObjects(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
  placed: readonly PlacedObject[],
): Promise<RoomObject[]> {
  return Promise.all(
    placed.map(async (p): Promise<RoomObject> => {
      const sprite = spriteIndex.get(p.type);
      if (!sprite) throw new Error(`objet : sprite manquant pour le type 0x${p.type.toString(16)}`);
      return {
        placed: p,
        texture: await getTexture(gl, sprite.url),
        width: sprite.width,
        height: sprite.height,
        hflipState: sprite.hflipState,
      };
    }),
  );
}

/** Draw calls des objets de la salle. Même formule que le décor
 * (scene/room.ts) : projection, calibration par type, miroir effectif, clé de
 * tri -- les objets ne sont pas un cas particulier de rendu. */
export function objectDrawCalls(objects: readonly RoomObject[], view: ViewAngle): SpriteDrawCall[] {
  return objects.map((o) => {
    const { gridX, gridY, gridZ, type } = o.placed;
    const [rx, ry] = rotateGrid(gridX, gridY, view);
    return {
      texture: o.texture,
      worldPos: [rx, gridZ, ry] as [number, number, number],
      size: [o.width, o.height] as [number, number],
      projOffset: getProjOffset(type, 0) ?? [0, 0],
      flipX: o.hflipState !== viewNeedsFlip(view),
      sortKey: -rx + ry - gridZ,
    };
  });
}
