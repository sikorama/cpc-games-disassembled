// Ce qui est décidé au LANCEMENT d'une partie, et uniquement là.
//
// Deux décisions, et la ROM les prend au même endroit à partir du MÊME octet :
// `var_room_or_state_selector` (#0068), qui accumule le compteur de frames au
// moment du restart (`(0068) += (006A)`, #0574). Cet octet dépend donc du
// nombre de frames écoulées avant que le joueur n'appuie -- c'est-à-dire du
// moment exact où il a lancé la partie, et de rien d'autre.
//
// Les regrouper ici plutôt que de les disperser reproduit cette structure :
// une partie de Knight Lore, c'est un octet. Voir game/random.ts pour
// l'adaptation du tirage lui-même (qui n'est pas un écart).

import { Rng, newGameSeed } from "./random";
import { randomizeCatalog, type PlacedObject } from "./objectCatalog";

/**
 * Les 4 salles de départ possibles.
 *
 * FAIT ROM, relu octet par octet dans `extra/dump_ref.bin` :
 * `2A64: 2F 44 B3 8F`, et `fn_init_room_selection` (#2A33) fait
 * `ld a,(#0068) / and #03` pour indexer cette table. Deux bits, quatre
 * salles -- le joueur ne commence jamais ailleurs.
 */
export const START_ROOMS: readonly number[] = [0x2f, 0x44, 0xb3, 0x8f];

export interface NewGame {
  /** La graine dont tout découle, exposée pour pouvoir rejouer une partie
   * identique (voir game/random.ts). */
  seed: number;
  startRoom: number;
  catalog: PlacedObject[];
}

/**
 * Prépare une partie.
 *
 * L'ordre et les masques sont ceux de la ROM : 2 bits pour la salle de départ,
 * 3 bits pour la rotation du catalogue. Deux tirages distincts, parce que la
 * ROM ajoute le registre `R` avant le second (#1D2E) et pas avant le premier
 * -- salle de départ et catalogue ne sont donc PAS corrélés dans le jeu, et il
 * ne faut pas les corréler ici en les dérivant du même octet.
 */
export function startNewGame(seed: number = newGameSeed()): NewGame {
  const rng = new Rng(seed);
  const startRoom = START_ROOMS[rng.nextByte() & 0x03]!;
  const catalog = randomizeCatalog(rng.nextByte() & 0x07);
  return { seed, startRoom, catalog };
}
