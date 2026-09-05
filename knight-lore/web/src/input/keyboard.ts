// État clavier "maintenu", pour un mouvement continu -- distinct des
// handlers keydown one-shot existants dans main.ts (r/w/c, déclenchés une
// fois par appui, laissés tels quels). Les touches suivies ici ont
// preventDefault() (évite par ex. le scroll de page sur Espace/flèches) ;
// les autres touches ne sont pas interceptées, pour ne pas gêner les
// handlers one-shot.

const TRACKED_KEYS = new Set([
  "w", "a", "s", "d",
  "arrowup", "arrowdown", "arrowleft", "arrowright",
  " ", // Espace (e.key === " ")
  // Touche ACTION. Pas Ctrl : `Ctrl+W` ferme l'onglet et n'est PAS annulable
  // par preventDefault() -- or W est la touche « haut ». Idem Ctrl+T/Ctrl+N.
  // "e" n'a aucun raccourci navigateur et tombe sous la main gauche en WASD ;
  // "enter" sert d'alias pour qui joue aux flèches.
  "e", "enter",
]);

export interface KeyboardState {
  isDown(key: string): boolean;
  /** "Vient d'être pressée" : ne renvoie true qu'une fois par appui, même
   * si la touche reste enfoncée -- nécessaire pour le saut (une pression
   * = une impulsion, pas un saut en continu tant que la touche est
   * tenue). */
  consumeJustPressed(key: string): boolean;
}

export function createKeyboardState(target: EventTarget): KeyboardState {
  const held = new Set<string>();
  const justPressed = new Set<string>();

  target.addEventListener("keydown", (e) => {
    const event = e as KeyboardEvent;
    const key = event.key.toLowerCase();
    if (!TRACKED_KEYS.has(key)) return;
    event.preventDefault();
    if (!held.has(key)) justPressed.add(key);
    held.add(key);
  });
  target.addEventListener("keyup", (e) => {
    const event = e as KeyboardEvent;
    const key = event.key.toLowerCase();
    if (!TRACKED_KEYS.has(key)) return;
    held.delete(key);
  });

  return {
    isDown(key: string): boolean {
      return held.has(key);
    },
    consumeJustPressed(key: string): boolean {
      const was = justPressed.has(key);
      justPressed.delete(key);
      return was;
    },
  };
}
