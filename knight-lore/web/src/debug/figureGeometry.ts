// Sortie de débogage : géométrie verticale d'une figure en DEUX MOITIÉS
// (corps + jambes), pour diagnostiquer un défaut d'assemblage.
//
// Prend les SpriteDrawCall RÉELLEMENT produits par scene/guard.ts et
// scene/player.ts -- pas une reconstitution : si le calcul diverge du rendu,
// c'est que le défaut est en aval (shader, dé-pivotement, échelle), et s'il
// concorde avec un mauvais nombre, le défaut est en amont.
//
// Rappel des conventions vérifiées (2026-09-04) :
// - l'espace vue a +Y vers le HAUT (render/camera.ts, gl/spriteBatch.ts) ;
// - l'ancre du sprite est son coin BAS-GAUCHE (`uniform2f(uAnchor, 0, 1)`,
//   gl/spriteBatch.ts:179) : le sprite s'étend donc vers le HAUT depuis
//   l'ancre, sur `size[1]` unités ;
// - `projOffset` est ajouté à la position APRÈS la matrice de vue
//   (`viewPos.xy += u_projOffset`), dans les mêmes unités que `size`.
//
// Attendu pour le garde d'après la ROM : écart d'ancres 9, recouvrement des
// boîtes 7, hauteur totale 32 (torse #1DBC à +3 / hauteur 23, jambes #1D89 à
// -6 / hauteur 16).

import type { SpriteDrawCall } from "../gl/spriteBatch";
import { CLASSIC_PROJECTION } from "../render/isoMath";

/** Y de l'ancre dans l'espace vue -- reproduit la ligne `u_view * worldPos`
 * du vertex shader pour la seule composante Y, puis `+= projOffset.y`. */
function anchorY(call: SpriteDrawCall): number {
  const p = CLASSIC_PROJECTION;
  const [wx, wy, wz] = call.worldPos;
  return wx * p.Y_FROM_X + wy * p.Y_FROM_Z + wz * p.Y_FROM_Y + call.projOffset[1];
}

function describe(label: string, call: SpriteDrawCall): string {
  const a = anchorY(call);
  const h = call.size[1];
  return (
    `  ${label.padEnd(7)} worldPos=[${call.worldPos.map((v) => v.toFixed(1)).join(", ")}]` +
    ` size=${call.size[0]}x${h}` +
    ` projOffset=[${call.projOffset.join(", ")}]` +
    ` flipX=${call.flipX}` +
    ` -> ancreY=${a.toFixed(2)} etendue=[${a.toFixed(2)}, ${(a + h).toFixed(2)}]`
  );
}

/**
 * Imprime l'analyse verticale d'une figure en deux moitiés.
 * `[corps, jambes]` dans l'ordre renvoyé par guardDrawCalls/playerDrawCalls.
 */
export function dumpFigureGeometry(who: string, calls: [SpriteDrawCall, SpriteDrawCall]): void {
  const [body, legs] = calls;
  const bodyA = anchorY(body);
  const legsA = anchorY(legs);
  const bodyTop = bodyA + body.size[1];
  const legsTop = legsA + legs.size[1];

  const total = Math.max(bodyTop, legsTop) - Math.min(bodyA, legsA);
  const overlap = Math.min(bodyTop, legsTop) - Math.max(bodyA, legsA);

  const lines = [
    `[${who}] géométrie verticale`,
    describe("corps", body),
    describe("jambes", legs),
    `  écart des ancres  = ${(bodyA - legsA).toFixed(2)}   (attendu 9 pour le garde)`,
    `  hauteur totale    = ${total.toFixed(2)}   (attendu 32 pour le garde)`,
    overlap >= 0
      ? `  RECOUVREMENT      = ${overlap.toFixed(2)} px   (attendu 7 pour le garde)`
      : `  TROU              = ${(-overlap).toFixed(2)} px  <-- les deux moitiés ne se touchent pas`,
    `  moitié du haut    = ${bodyTop > legsTop ? "corps" : "jambes"}`,
  ];
  console.log(lines.join("\n"));
}
