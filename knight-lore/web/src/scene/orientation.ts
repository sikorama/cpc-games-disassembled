// Encodage d'orientation du moteur d'origine, partagé joueur / garde.
//
// CONFIRMÉ par désassemblage (fn_get_orientation_code #22D0,
// asm/code/doors_and_player_logic.asm:600-614) :
//
//     code = (flags.bit6 << 1) | type.bit3        0=-X  1=+X  2=+Y  3=-Y
//
// (Attention en relisant l'assembleur : le commentaire du source parle de
// « bit4 de (ix+07) », mais le `rrca / rrca / and #10` sélectionne le bit6
// D'ORIGINE -- bit4 est sa position APRÈS décalage. Corrigé côté asm.)
//
// Confirmé par tbl_player_forward_vector_dispatch (#22E4,
// doors_and_player_logic.asm:615-650) : o0 fait -3 sur X, o1 +3 sur X,
// o2 +3 sur Y, o3 -3 sur Y.
//
// Les deux bits ne jouent PAS le même rôle au rendu :
// - type.bit3 (bit 0 du code) sélectionne un JEU DE SPRITES entièrement
//   différent via tbl_sprite_dispatch (ex. jambes : feet1-4 contre
//   feet5-8) -- ce ne sont pas deux fois le même dessin ;
// - flags.bit6 (bit 1 du code) déclenche un vrai miroir horizontal au
//   rendu (fn_flip_sprite_shape, docs/RENDERING_PIPELINE.md §6), appliqué
//   PAR-DESSUS le sprite déjà choisi.
// Confondre les deux (utiliser bit3 comme un flip) donne un résultat
// correct dans exactement une direction sur quatre.
export type Orientation = 0 | 1 | 2 | 3;

/** Miroir horizontal au rendu (flags.bit6). */
export function orientationFlip(orientation: Orientation): boolean {
  return (orientation & 2) !== 0;
}

/** Sélecteur de jeu de sprites (type.bit3 pour les jambes et le corps du
 * joueur, type.bit0 pour le corps du garde -- même valeur, position
 * différente dans l'octet de type). */
export function orientationSpriteSetBit(orientation: Orientation): number {
  return orientation & 1;
}

/**
 * Orientation dérivée d'un vecteur de déplacement -- règle du GARDE.
 *
 * CONFIRMÉ (fn_guard_legs_logic #0FD8,
 * asm/code/entity_logic_mechanical.asm:29-60) : axe dominant d'abord, puis
 * signe, et le résultat est écrit avec `set`/`res` -- jamais une bascule.
 * Le garde n'a donc AUCUN état d'orientation : il la recalcule chaque
 * frame. C'est la différence de fond avec le joueur, qui lui porte son
 * orientation comme un état persistant basculé par l'input (et peut donc
 * regarder quelque part sans bouger). Ne pas unifier les deux : le mode
 * de contrôle « rotation » du joueur en dépend.
 *
 * L'original compare dx et dy en NON SIGNÉ (`cp (ix+#0A)` sur des octets),
 * ce qui n'a de sens que parce qu'un seul axe bouge à la fois -- les
 * vecteurs de patrouille sont (±2,0) ou (0,±2). On reproduit donc la règle
 * sous cette hypothèse, qui est celle du jeu.
 */
export function orientationFromVector(dx: number, dy: number): Orientation {
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx >= 0 ? 1 : 0;
  }
  return dy >= 0 ? 2 : 3;
}

/**
 * UN pas de rotation vers `target`, tel que le fait la ROM.
 *
 * L'original ne RANGE jamais une orientation : il bascule des bits
 * (`xor #08` sur le type, `xor #40` sur les flags,
 * asm/code/doors_and_player_logic.asm:419-425) -- vérifié, il n'existe aucun
 * stockage direct sur le chemin joueur. Deux moitiés inverses de la bascule
 * sont choisies par un test, et le mécanisme est le suivant :
 *
 *   flags.bit6 bascule TOUJOURS ; type.bit3 ne bascule que si flags.bit6
 *   valait 0 (moitié directe) ou 1 (moitié miroir).
 *
 * Ce qui donne deux cycles inverses : 0->3->1->2->0 et 0->2->1->3->0.
 *
 * Conséquence observable, et c'est tout l'intérêt de le reproduire : un
 * quart de tour aboutit en UN tick, un demi-tour en DEUX, avec une
 * orientation intermédiaire réellement affichée. Un demi-tour maintenu en
 * avançant produit donc une trajectoire coudée -- les "diagonales" de
 * l'original, qui sont un transitoire de rotation et non une direction
 * tenue.
 *
 * Le choix de la moitié vient d'une fonction de la cible et de l'orientation
 * courante (`cpl / and #01` selon la branche, :316-356), reproduite ici.
 */
export function rotateToward(current: Orientation, target: Orientation): Orientation {
  if (current === target) return current;
  // Moitié miroir ? Les branches des cibles +X et +Y testent le complément
  // du bit bas du code courant, celles de -X et -Y le bit lui-même.
  const low = current & 1;
  const mirror = target === 1 || target === 2 ? low === 0 : low === 1;

  const b6 = (current >> 1) & 1;
  const t3 = low;
  const nextT3 = (mirror ? b6 === 1 : b6 === 0) ? 1 - t3 : t3;
  const nextB6 = 1 - b6;
  return (((nextB6 << 1) | nextT3) as Orientation);
}

/** Vecteur unitaire d'une orientation, dans le repère de grille NON tourné.
 * Signes confirmés par tbl_player_forward_vector_dispatch (#22E4) :
 * o0 -X, o1 +X, o2 +Y, o3 -Y. */
export function orientationVector(orientation: Orientation): [number, number] {
  switch (orientation) {
    case 0:
      return [-1, 0];
    case 1:
      return [1, 0];
    case 2:
      return [0, 1];
    default:
      return [0, -1];
  }
}
