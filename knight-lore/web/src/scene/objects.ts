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
import { OBJECT_TYPE_BASE, OBJECT_TYPE_COUNT } from "../game/objectCatalog";
import type { PlacedObject } from "../game/objectCatalog";

/** Sprite d'un type d'objet, chargé d'avance. */
export interface ObjectSprite {
  texture: WebGLTexture;
  width: number;
  height: number;
  hflipState: boolean;
}

/** Les 8 sprites 0x60-0x67, chargés UNE fois pour toutes.
 *
 * Pourquoi tous, et pas seulement ceux de la salle : utiliser un objet en
 * repose un autre à sa place, d'un type quelconque, et ça se produit dans un
 * tick de logique. Charger à ce moment-là voudrait dire attendre un `fetch` au
 * milieu de la boucle. Huit sprites tiennent en mémoire sans discussion. */
export type ObjectSprites = Map<number, ObjectSprite>;

/** Objet présent dans la salle. Le sprite n'est PAS figé dedans : il est
 * relu depuis `ObjectSprites` au moment du rendu, parce que le type d'une
 * même instance change quand on y repose autre chose. */
export interface RoomObject {
  placed: PlacedObject;
}

/** Charge les 8 sprites d'objets d'un coup, au démarrage. */
export async function loadObjectSprites(
  gl: WebGL2RenderingContext,
  spriteIndex: SpriteIndex,
): Promise<ObjectSprites> {
  const sprites: ObjectSprites = new Map();
  for (let type = OBJECT_TYPE_BASE; type < OBJECT_TYPE_BASE + OBJECT_TYPE_COUNT; type++) {
    const sprite = spriteIndex.get(type);
    if (!sprite) throw new Error(`objet : sprite manquant pour le type 0x${type.toString(16)}`);
    sprites.set(type, {
      texture: await getTexture(gl, sprite.url),
      width: sprite.width,
      height: sprite.height,
      hflipState: sprite.hflipState,
    });
  }
  return sprites;
}

/**
 * Objets d'une salle. Zéro ou un en pratique -- les 32 emplacements sont dans
 * 32 salles distinctes -- mais on garde une liste, parce que c'est une
 * propriété des DONNÉES et non une garantie du code (voir game/objectCatalog.ts).
 */
export function createRoomObjects(placed: readonly PlacedObject[]): RoomObject[] {
  return placed.map((p) => ({ placed: { ...p } }));
}

/** Draw calls des objets de la salle. Même formule que le décor
 * (scene/room.ts) : projection, calibration par type, miroir effectif, clé de
 * tri -- les objets ne sont pas un cas particulier de rendu. */
export function objectDrawCalls(
  objects: readonly RoomObject[],
  sprites: ObjectSprites,
  view: ViewAngle,
): SpriteDrawCall[] {
  const calls: SpriteDrawCall[] = [];
  for (const o of objects) {
    const { gridX, gridY, gridZ, type } = o.placed;
    const sprite = sprites.get(type);
    if (!sprite) continue;
    const [rx, ry] = rotateGrid(gridX, gridY, view);
    calls.push({
      texture: sprite.texture,
      worldPos: [rx, gridZ, ry],
      size: [sprite.width, sprite.height],
      projOffset: getProjOffset(type, 0) ?? [0, 0],
      flipX: sprite.hflipState !== viewNeedsFlip(view),
      sortKey: -rx + ry - gridZ,
    });
  }
  return calls;
}
