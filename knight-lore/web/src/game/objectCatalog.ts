// Catalogue des objets à ramasser, et sa randomisation de début de partie.
//
// LE FAIT CENTRAL, ET IL EST CONTRE-INTUITIF : la randomisation ne déplace
// RIEN. Les 32 emplacements (position + salle) sont un template fixe, gravé
// dans les données ; ce qui change d'une partie à l'autre est uniquement
// QUEL TYPE D'OBJET se trouve à chaque emplacement.
//
// Et même ça n'est pas 32 tirages indépendants. `fn_catalog_randomize_types`
// (#1D27) prend UNE graine, puis parcourt les entrées en incrémentant cette
// graine d'un cran à chaque fois :
//
//     E = R + (0068)              ; graine, tirée UNE fois
//     boucle sur les 32 entrées :
//       A = E & 7 | 0x60          ; type de l'entrée courante
//       E = E + 1                 ; rotation, PAS un nouveau tirage
//
// Autrement dit le catalogue est une **rotation** des 8 types sur 32
// emplacements : chaque type apparaît exactement 4 fois, dans le même ordre
// cyclique, et seul le décalage de départ change. Il n'existe donc que
// **8 catalogues possibles** dans tout le jeu -- et pas 8^32. C'est une
// contrainte de conception forte (aucune partie ne peut manquer d'un objet),
// et l'ignorer en tirant 32 types au hasard produirait des parties
// injouables que l'original ne peut pas produire.

import objectCatalogData from "../data/assets/object_catalog.json";

/** Plage des types d'objets ramassables. `A & 7 | 0x60` par construction. */
export const OBJECT_TYPE_BASE = 0x60;
export const OBJECT_TYPE_COUNT = 8;

/** Un emplacement du catalogue : la partie FIXE, telle qu'extraite du dump
 * par `tools/object_catalog.py`. Le type n'y est pas -- il est attribué par
 * `randomizeCatalog()`. */
interface CatalogSlot {
  index: number;
  grid_x: number;
  grid_y: number;
  grid_z: number;
  room: number;
}

/** Un objet placé, une fois la rotation appliquée. */
export interface PlacedObject {
  type: number;
  gridX: number;
  gridY: number;
  gridZ: number;
  room: number;
}

const SLOTS: readonly CatalogSlot[] = objectCatalogData.entries;

/**
 * Applique la rotation de début de partie.
 *
 * `rotation` correspond au `E & 7` initial de la ROM : seuls ses 3 bits bas
 * comptent, ce qui est exactement pourquoi il n'y a que 8 catalogues
 * possibles. On prend un entier quelconque et on le masque ici plutôt que
 * d'exiger 0-7 de l'appelant : c'est la ROM qui masque, pas son appelant.
 */
export function randomizeCatalog(rotation: number): PlacedObject[] {
  return SLOTS.map((slot, i) => ({
    type: OBJECT_TYPE_BASE | ((rotation + i) & (OBJECT_TYPE_COUNT - 1)),
    gridX: slot.grid_x,
    gridY: slot.grid_y,
    gridZ: slot.grid_z,
    room: slot.room,
  }));
}

/**
 * Objets d'une salle donnée.
 *
 * Les 32 emplacements sont dans 32 salles DISTINCTES (vérifié sur les
 * données : aucun doublon, et les 32 salles existent toutes dans le manifest),
 * donc ceci renvoie zéro ou un objet. On garde quand même une liste : c'est le
 * filtrage par `room_number` que fait `fn_instantiate_room_objects` (#1DFB),
 * et rien dans le code de la ROM ne garantit l'unicité -- elle est vraie dans
 * les données, ce qui n'est pas la même chose.
 */
export function objectsInRoom(catalog: readonly PlacedObject[], room: number): PlacedObject[] {
  return catalog.filter((o) => o.room === room);
}
