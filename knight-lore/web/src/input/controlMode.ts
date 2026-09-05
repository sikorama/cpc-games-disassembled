// Modes de contrôle et pilotes d'entrée.
//
// L'original en a DEUX, sélectionnés au menu de démarrage via
// `var_input_mode_flag` (#006C) : bit1 = clavier/joystick, bit3 = DIRECTIONAL
// CONTROL. Le chemin directional exige bit1 ET bit3
// (asm/code/doors_and_player_logic.asm:280-285), donc au clavier l'original
// est TOUJOURS en mode rotation.
//
// ÉCART ASSUMÉ (web/DEVIATIONS.md) : le portage découple le mode du
// périphérique. Le couplage d'origine est un artefact du menu de 1984 -- le
// même octet sert de sélecteur de périphérique et de sélecteur de mode, au
// point que fn_read_use_object_button doit re-décaler ses bits selon le
// périphérique -- pas une décision de gameplay.
//
// Le mode est un PILOTE D'ENTRÉE : il ne fait que produire une intention, il
// ne touche pas à l'état du joueur. C'est ce qui permettra d'ajouter le mode
// rotation sans réécrire la boucle (voir scene/player.ts, qui applique les
// règles ROM sur l'intention).

import type { KeyboardState } from "./keyboard";
import type { Orientation } from "../scene/orientation";

export type ControlMode = "directional" | "rotation";

export interface MoveIntent {
  /** Orientations demandées, par ordre de priorité. Vide si rien n'est
   * pressé ; deux entrées si deux axes sont tenus (diagonale). Mode
   * directional uniquement. */
  targets: Orientation[];
  /** Rotation RELATIVE demandée : -1 (gauche), 0, +1 (droite). Mode rotation
   * uniquement. */
  turn: -1 | 0 | 1;
  /** Avancer dans l'orientation courante. Mode rotation uniquement : en
   * directional, avancer est impliqué par `targets` et soumis aux règles
   * d'alignement de la ROM. */
  advance: boolean;
  jump: boolean;
}

const EMPTY: MoveIntent = { targets: [], turn: 0, advance: false, jump: false };

/** Mode "DIRECTIONAL CONTROL" : chaque direction demande une orientation.
 * Priorité à l'axe dominant, comme fn_player_read_input qui teste ses bits
 * dans un ordre fixe. */
function directionalIntent(input: KeyboardState): MoveIntent {
  let dx = 0;
  let dy = 0;
  // `dx`/`dy` sont des intentions d'axe MONDE, pas écran -- c'est ce qui rend
  // les quatre lignes lisibles ensemble et ce qui fixe le sens des deux
  // ternaires plus bas.
  //
  // L'axe Y était branché à l'envers (corrigé 2026-09-05, signalé en jouant) :
  // « haut » produisait -Y. Les deux touches verticales sont donc échangées.
  // Ce n'est pas un fait ROM mais un choix d'affectation de touches -- le jeu
  // d'origine mappe des directions de joystick, et quelle touche du clavier
  // porte quelle direction du monde est une question de portage.
  if (input.isDown("a") || input.isDown("arrowleft")) dx -= 1;
  if (input.isDown("d") || input.isDown("arrowright")) dx += 1;
  if (input.isDown("w") || input.isDown("arrowup")) dy += 1;
  if (input.isDown("s") || input.isDown("arrowdown")) dy -= 1;

  const targets: Orientation[] = [];
  if (dx !== 0) targets.push(dx < 0 ? 0 : 1);
  if (dy !== 0) targets.push(dy > 0 ? 2 : 3);

  return { targets, turn: 0, advance: false, jump: false };
}

/** Mode rotation (celui du clavier d'origine) : gauche/droite tournent,
 * une touche distincte avance. PAS ENCORE ACTIF -- voir web/DEVIATIONS.md.
 * Présent pour que le modèle d'orientation soit dimensionné pour lui dès
 * maintenant plutôt que réécrit après coup. */
function rotationIntent(input: KeyboardState): MoveIntent {
  const left = input.isDown("a") || input.isDown("arrowleft");
  const right = input.isDown("d") || input.isDown("arrowright");
  const forward = input.isDown("w") || input.isDown("arrowup");
  return {
    targets: [],
    turn: left && !right ? -1 : right && !left ? 1 : 0,
    advance: forward,
    jump: false,
  };
}

export function readIntent(mode: ControlMode, input: KeyboardState): MoveIntent {
  const base = mode === "directional" ? directionalIntent(input) : rotationIntent(input);
  return { ...EMPTY, ...base, jump: input.consumeJustPressed(" ") };
}
