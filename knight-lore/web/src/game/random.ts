// Tirage pseudo-aléatoire du portage.
//
// CE N'EST PAS UN ÉCART (décision 2026-09-05). Le jeu d'origine tire « du
// pseudo-aléatoire avec telle distribution » ; le portage fait exactement la
// même chose. La séquence d'octets précise n'est pas un comportement
// observable du jeu -- personne ne peut la montrer à l'écran, ni la prédire en
// jouant. Ce fichier est donc une ADAPTATION D'IMPLÉMENTATION, au même titre
// que « le portage dessine avec WebGL et pas avec les rectangles sales du
// CPC », et il n'a rien à faire dans web/DEVIATIONS.md.
//
// Ce qui EST un fait de jeu, et qui doit être reproduit exactement, ce sont
// les RÈGLES autour du tirage : combien de bits sont gardés, quels seuils, et
// surtout ce que le jeu fait du résultat. Ces règles vivent chez les
// appelants, pas ici.
//
// ---------------------------------------------------------------------------
// CE QUE FAIT LA ROM, pour mémoire
// ---------------------------------------------------------------------------
//
// Deux sources distinctes, à ne pas confondre :
//
// 1. `var_pseudo_random_acc` (#006D) -- accumulateur PERMANENT, mélangé deux
//    fois par tour de boucle principale : une fois par entité dispatchée
//    (`acc += R`, le registre de rafraîchissement du Z80) et une fois par
//    frame (`acc += mem[var_frame_counter] + bas + haut`, qui traite la valeur
//    du compteur de frames comme une ADRESSE et lit l'octet qui s'y trouve --
//    asm/code/low_ram_and_boot.asm:246-272). Consommé en cours de partie :
//    types transitoires de la transformation, poses alternatives rares.
//
// 2. `var_room_or_state_selector` (#0068) -- graine de DÉBUT DE PARTIE, qui
//    accumule `var_frame_counter` au moment du restart
//    (`(0068) += (006A)`, #0574). Elle dépend donc du nombre de frames
//    écoulées avant que le joueur ne lance la partie -- autrement dit du
//    moment exact où il a appuyé. Consommée par la sélection de salle de
//    départ et par le catalogue d'objets, qui partagent ainsi la MÊME graine.
//
// Ni le registre `R` ni la lecture d'un octet à une adresse arbitraire n'ont
// d'équivalent ici, et les émuler exigerait de reproduire la disposition
// mémoire du CPC -- ce qui n'est pas le projet.

/**
 * Générateur à graine explicite (xorshift32).
 *
 * Pourquoi une graine explicite plutôt que `Math.random()` : les deux gros
 * consommateurs sont des décisions de DÉBUT DE PARTIE (salle de départ,
 * distribution des objets). Pouvoir rejouer une partie identique en notant un
 * seul nombre vaut largement le coût du générateur -- pour tester, pour
 * reproduire un bug, et parce que c'est aussi ce que fait l'original, dont
 * toute la partie découle d'un unique octet (#0068).
 */
export class Rng {
  private state: number;

  constructor(seed: number) {
    // xorshift32 boucle sur 0 : toute graine nulle donnerait une suite
    // constante. On la remplace plutôt que de l'interdire, pour qu'une graine
    // de 0 reste une graine valide côté appelant.
    this.state = seed >>> 0 || 0x9e3779b9;
  }

  /** Entier non signé sur 32 bits. */
  nextUint32(): number {
    let x = this.state;
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    this.state = x >>> 0;
    return this.state;
  }

  /**
   * Octet 0-255. C'est la primitive qui correspond à ce que lit la ROM : tous
   * ses consommateurs lisent un OCTET puis le masquent ou le comparent à un
   * seuil. Passer par ici plutôt que par un flottant garde les seuils du jeu
   * (`< 0x02`, `>= 0xFE`, `& 0x07`) lisibles tels quels chez l'appelant.
   */
  nextByte(): number {
    // Les bits de poids fort d'un xorshift sont mieux distribués que les
    // faibles.
    return this.nextUint32() >>> 24;
  }

  /** Entier dans [0, bound). */
  nextBelow(bound: number): number {
    return this.nextUint32() % bound;
  }
}

/**
 * Graine de début de partie.
 *
 * Reproduit l'ESPRIT de `(0068) += (006A)` : la graine dépend du moment où le
 * joueur lance la partie, pas d'un état de jeu. Une horloge à haute résolution
 * est l'équivalent le plus direct du compteur de frames du CPC.
 */
export function newGameSeed(): number {
  return (Date.now() ^ (performance.now() * 1000)) >>> 0;
}

/** Générateur partagé pour les tirages EN COURS DE PARTIE (l'équivalent de
 * `var_pseudo_random_acc`), distinct de la graine de début de partie. */
export const gameplayRng = new Rng(newGameSeed());
