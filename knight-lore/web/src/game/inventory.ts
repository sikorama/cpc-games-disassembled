// Inventaire d'objets et action « utiliser ».
//
// UNE SEULE ACTION EXISTE dans le jeu, et « utiliser » la résume : on prend
// l'objet à portée, toute la pile se décale d'un cran, et celui qui sort par le
// bout est POSÉ. Il n'y a pas de ramassage séparé, pas de bouton « lâcher »,
// pas d'usage d'objet. Le contact, lui, ne ramasse rien — il POUSSE, les
// objets portant le bit poussable comme les meubles.
//
// STRUCTURE ROM : une pile de 4 enregistrements de 4 octets en RAM basse.
//
//     #00A7  objet EN MAIN      (type, flags, pointeur catalogue sur 2 octets)
//     #00AB  emplacement 1  ]
//     #00AF  emplacement 2   }- les 3 icônes affichées au HUD
//     #00B3  emplacement 3  ]
//
// `fn_player_use_held_object` (#18AA) fait le décalage avec UNE instruction :
// `ld hl,#00B2 / ld de,#00B6 / ld bc,#000C / lddr` -- une copie descendante de
// 12 octets, soit 3 enregistrements, qui pousse tout d'un cran vers le fond et
// écrase celui de #00B3. Le nouvel objet est écrit en #00A7 et les 4 octets de
// tête sont remis à zéro quand la pile était vide.
//
// C'est pour ça que l'objet sortant est posé AU MÊME ENDROIT que celui qu'on
// vient de prendre : juste avant le décalage, la routine écrit son type dans le
// slot d'entité qu'on est en train de libérer (`ld (iy+off_type),a`). Un seul
// slot sert aux deux, donc l'échange est nécessairement sur place.

/** Un enregistrement d'inventaire. Le pointeur catalogue est conservé parce
 * que la ROM le conserve : c'est par lui que l'entrée du catalogue est
 * invalidée au ramassage (`ld (de),a` avec un zéro), et il faudra le même
 * chemin pour reposer l'objet dans le monde. */
export interface HeldObject {
  type: number;
  flags: number;
  /** Index de l'emplacement du catalogue d'où vient l'objet, ou `null` si
   * l'objet n'en vient pas. Remplace le pointeur 16 bits de la ROM : le
   * portage adresse le catalogue par index, pas par adresse mémoire. */
  catalogSlot: number | null;
}

/** Emplacements affichés au HUD, hors objet en main. `fn_hud_slot_notification`
 * (#1802) en redessine exactement 3, en lisant #00AB par pas de 4. */
export const INVENTORY_SLOTS = 3;

/** Seuls 0x60-0x66 sont préhensibles : `ld a,(iy+off_type) / sub #60 / cp #07 /
 * ret nc`. La vie bonus 0x67 en est donc EXCLUE -- elle se ramasse toute seule
 * par proximité et ne se conserve pas, ce que l'utilisateur avait déjà observé
 * en jeu bien avant qu'on lise ce test. */
export function isGraspable(type: number): boolean {
  return type - 0x60 < 0x07 && type >= 0x60;
}

/**
 * La pile complète : l'objet en main plus les 3 emplacements.
 *
 * Modélisée comme un seul tableau de 4 cases, comme en RAM, plutôt qu'un
 * « objet tenu » séparé d'une « liste ». Le `lddr` de la ROM traite les quatre
 * d'un bloc, et les séparer obligerait à réécrire le décalage en deux temps --
 * l'occasion parfaite d'introduire un écart d'une case.
 */
export interface InventoryState {
  /** Index 0 = en main, 1..3 = les emplacements affichés. `null` = vide. */
  records: (HeldObject | null)[];
}

export function createInventoryState(): InventoryState {
  return { records: Array<HeldObject | null>(INVENTORY_SLOTS + 1).fill(null) };
}

/** Ce que le HUD affiche : les 3 emplacements, sans l'objet en main. */
export function displayedSlots(inv: InventoryState): (HeldObject | null)[] {
  return inv.records.slice(1);
}

/** L'objet en main, celui qu'on vient de prendre. */
export function heldObject(inv: InventoryState): HeldObject | null {
  return inv.records[0] ?? null;
}

/**
 * Prend `picked` et décale la pile d'un cran.
 *
 * Renvoie l'objet CHASSÉ du dernier emplacement, que l'appelant doit poser dans
 * le monde -- ou `null` si la pile n'était pas pleine. C'est exactement ce que
 * fait le `lddr` : il n'y a pas de test de saturation, l'enregistrement du
 * fond est écrasé, et s'il valait zéro rien n'est posé.
 *
 * Ne prend AUCUNE décision de gameplay : ni la portée, ni le droit d'agir, ni
 * l'endroit où poser. La ROM non plus -- tout ça est décidé avant l'appel.
 */
export function useAndRotate(inv: InventoryState, picked: HeldObject): HeldObject | null {
  const evicted = inv.records[INVENTORY_SLOTS] ?? null;
  for (let i = INVENTORY_SLOTS; i > 0; i--) {
    inv.records[i] = inv.records[i - 1] ?? null;
  }
  inv.records[0] = picked;
  return evicted;
}

/** Noms officiels des 8 objets, tels qu'établis par le désassemblage des
 * sprites (docs/SYMBOLS.md 0x60-0x67). 0x67 n'est jamais dans l'inventaire --
 * il n'est pas préhensible -- mais figure ici pour que la table reste complète
 * et corresponde au catalogue. */
const OBJECT_NAMES: Record<number, string> = {
  0x60: "rubis",
  0x61: "poison",
  0x62: "botte",
  0x63: "calice",
  0x64: "tasse",
  0x65: "bouteille",
  0x66: "boule de cristal",
  0x67: "vie bonus",
};

export function objectName(type: number): string {
  return OBJECT_NAMES[type] ?? `0x${type.toString(16)}`;
}
