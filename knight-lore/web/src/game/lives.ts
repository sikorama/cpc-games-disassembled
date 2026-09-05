// Compteur de vies et fins de partie.
//
// FAIT ROM CENTRAL : le décrément n'est PAS dans une routine de dégâts, il est
// dans `fn_init_room_entities` (#29B4) -- la routine qui réinstalle le joueur
// depuis son template. Perdre une vie et réapparaître sont donc UN SEUL
// geste dans le jeu d'origine, et le portage garde cette structure : il n'y a
// pas de « perdre une vie » séparé de « réapparaître ».
//
//     ld   hl,var_life_counter
//     dec  (hl)
//     jp   m,fn_game_over_or_daycycle_end
//
// DEUX CONSÉQUENCES QUI SE VOIENT :
//
// 1. La fin de partie survient quand le compteur devient NÉGATIF, pas nul
//    (`jp m` teste le signe). Un compteur à zéro laisse donc encore jouer.
// 2. La routine tourne AUSSI au lancement de la partie -- son unique appelant
//    est la séquence de démarrage (#05A2). Le compteur part de 5 et vaut donc
//    déjà 4 quand la première image s'affiche. Ce n'est pas une erreur à
//    corriger : c'est ce qui fait qu'on meurt cinq fois, la cinquième étant
//    fatale.
//
// CE QUI RESTE NON DÉSASSEMBLÉ, et qui n'est pas dans ce fichier : le
// DÉCLENCHEUR. Aucun `JP`/`CALL` direct des 16K bas n'atteint #05A2 -- le
// chemin de mort en jeu est forcément indirect (voir docs/SYMBOLS.md #29B4).
// La RÈGLE appliquée par le portage — tout contact avec un ennemi ou un piège
// coûte une vie — vient de l'observation en jeu de l'utilisateur, pas du
// désassemblage. C'est une source légitime (docs/METHODOLOGY.md §32) mais il
// faut savoir laquelle est laquelle : l'EFFET est lu dans la ROM, la CONDITION
// est observée.

/** `ld a,#05 / ld (var_life_counter),a` en #056F, sur le chemin de restart. */
export const INITIAL_LIVES = 5;

/** Pourquoi la partie s'est terminée. Les deux causes existent bel et bien
 * dans le jeu et n'ont rien à voir l'une avec l'autre : l'une vient du
 * compteur de vies, l'autre du compteur de JOURS qui atteint 40
 * (game/dayNight.ts). Les distinguer permet de le dire au joueur. */
export type GameOverCause = "no-lives" | "days-exhausted";

export interface LivesState {
  /** Valeur brute du compteur, telle que la ROM la tient -- donc déjà
   * décrémentée une fois au lancement. */
  counter: number;
}

export function createLivesState(): LivesState {
  // Le décrément de lancement est appliqué tout de suite : la séquence de
  // démarrage appelle fn_init_room_entities avant la première frame.
  return { counter: INITIAL_LIVES - 1 };
}

/**
 * Consomme une vie. Renvoie `true` si la partie est terminée.
 *
 * L'ordre est celui de la ROM -- décrémenter D'ABORD, tester le signe
 * ENSUITE. Tester avant décrémenterait une fois de trop ou de trop peu selon
 * la convention choisie, et c'est exactement le genre d'écart d'une unité que
 * personne ne remarque avant d'avoir compté ses morts.
 */
export function loseLife(state: LivesState): boolean {
  state.counter -= 1;
  return state.counter < 0;
}

/** Vies restantes à afficher : le compteur est un « combien il m'en reste
 * APRÈS celle en cours », d'où le +1 pour un affichage naturel. */
export function livesRemaining(state: LivesState): number {
  return Math.max(0, state.counter + 1);
}

/** Vie bonus (objet 0x67) : `INC (0x0080)` dans `fn_bonus_life_pickup_logic`
 * (#1A4A). Pas encore atteignable — le ramassage n'est pas implémenté — mais
 * la fonction vit ici pour que l'incrément et le décrément restent au même
 * endroit. */
export function gainLife(state: LivesState): void {
  state.counter += 1;
}
