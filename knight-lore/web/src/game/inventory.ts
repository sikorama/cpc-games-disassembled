// Inventaire d'objets et action « utiliser ».
//
// UNE SEULE ACTION EXISTE dans le jeu, et « utiliser » la résume : ce qui est à
// portée entre dans l'inventaire, tout se décale d'un cran, et ce qui sort par
// le bout est POSÉ. Il n'y a pas de ramassage séparé, pas de bouton « lâcher »,
// pas d'usage d'objet. Le contact, lui, ne ramasse rien — il POUSSE, les objets
// portant le bit poussable comme les meubles.
//
// L'INVENTAIRE, C'EST TROIS EMPLACEMENTS. #00AB, #00AF et #00B3, ceux que le
// HUD affiche. #00A7 n'en fait PAS partie malgré les apparences : c'est un
// octet de travail. `fn_player_use_held_object` (#18AA) y écrit l'objet
// entrant, puis le `lddr` le décale immédiatement vers #00AB et la routine
// remet #00A7 à zéro. Il ne survit pas à l'opération, donc il n'y a pas
// d'« objet en main » distinct des trois emplacements -- première lecture
// corrigée le 2026-09-05.
//
// LE DÉCALAGE TIENT EN UNE INSTRUCTION :
//
//     ld hl,#00B2 / ld de,#00B6 / ld bc,#000C / lddr
//
// une copie descendante de 12 octets (3 enregistrements de 4) qui pousse tout
// vers le fond et écrase celui de #00B3. Elle est exécutée dans les DEUX cas --
// qu'on ait pris quelque chose ou non. Presser la touche sans rien à portée
// décale donc quand même, et pose ce qui sort : c'est ainsi qu'on se
// débarrasse d'un objet.

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

/** L'inventaire entier. `fn_hud_slot_notification` (#1802) en redessine
 * exactement 3, en lisant #00AB par pas de 4 -- et ces trois-là sont tout ce
 * que le joueur possède. */
export const INVENTORY_SLOTS = 3;

/** Demi-étendues et hauteur d'un objet posé, écrites en clair par la ROM au
 * moment de le reposer : `ld (iy+off_bbox_w),#05 / bbox_h,#05 / bbox_d,#0C`
 * (loc_19A5). Ce n'est donc plus une valeur inventée -- elle sert aussi de
 * boîte pour le test de portée. */
export const OBJECT_HALF_EXTENT = 5;
export const OBJECT_HEIGHT = 0x0c;

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
  /** Les 3 emplacements, du plus récent au plus ancien. `null` = vide. */
  records: (HeldObject | null)[];
}

export function createInventoryState(): InventoryState {
  return { records: Array<HeldObject | null>(INVENTORY_SLOTS).fill(null) };
}

/** Ce que le HUD affiche -- c'est-à-dire tout l'inventaire. */
export function displayedSlots(inv: InventoryState): (HeldObject | null)[] {
  return inv.records;
}

/**
 * Décale l'inventaire d'un cran et renvoie ce qui en SORT.
 *
 * `entering` vaut `null` quand rien n'était à portée : le décalage a lieu quand
 * même, l'emplacement de tête devient vide, et l'objet du fond ressort. C'est
 * le seul moyen de se débarrasser de quelque chose, et c'est pour ça que
 * presser la touche à mains vides n'est pas une opération neutre.
 *
 * L'objet renvoyé doit être POSÉ par l'appelant. Il n'y a pas de test de
 * saturation dans la ROM : le `lddr` écrase le dernier enregistrement, et s'il
 * était vide il ne sort rien.
 *
 * Ne prend aucune décision de gameplay -- ni la portée, ni le droit d'agir, ni
 * l'endroit où poser. La ROM non plus : tout ça est décidé avant.
 */
export function useAndRotate(
  inv: InventoryState,
  entering: HeldObject | null,
): HeldObject | null {
  const evicted = inv.records[INVENTORY_SLOTS - 1] ?? null;
  for (let i = INVENTORY_SLOTS - 1; i > 0; i--) {
    inv.records[i] = inv.records[i - 1] ?? null;
  }
  inv.records[0] = entering;
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
