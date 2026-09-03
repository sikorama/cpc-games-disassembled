// Projection isométrique du jeu original.
//
// SOURCE FAISANT FOI : asm/code/rendering_pipeline.asm:295 (fn_isometric_project),
// pas une transcription de doc -- la formule de docs/RENDERING_PIPELINE.md §5
// avait déjà été prise en défaut une fois sur sa constante fixe, donc elle est
// re-vérifiée ici contre le désassemblage lui-même :
//
//   screen_x = grid_x + grid_y - 0x80 + proj_offset_x
//   screen_y = (grid_y - grid_x + 0x80) / 2 + grid_z_or_offset - 0x68 + proj_offset_y
//                                     ^^^ srl a = division ENTIÈRE (floor)
//                                                 ^^^ ADDITION (add a,(ix+off_grid_z_or_offset))
//
// ORIENTATION DE L'AXE Y -- ATTENTION, PIÈGE COÛTEUX (perdu une session le
// 2026-08-15 à "corriger" ce qui marchait). Dans la ROM, `screen_y` croît vers
// le BAS et désigne la ligne du HAUT du sprite : le culling `cp #C0`
// (rendering_pipeline.asm:311) le compare à une hauteur d'écran, et le blit
// ajuste sur `screen_y + screen_h` (docs/RENDERING_PIPELINE.md §7).
//
// Ce portage travaille pourtant dans l'espace MIROIR de celui-là : +Y vers le
// HAUT, ancre bas-gauche. Et c'est CORRECT, parce que le miroir est appliqué
// DEUX FOIS et se compose :
//
//   1. les PNG de tools/sprite_dump_out/ sont des images MIROIR du rendu réel
//      (conséquence du ROTATE_90 non expliqué de sprite_dump.py, cf.
//      notes/2026-08-13-sprite-rotation-investigation.md) ;
//   2. l'agencement ci-dessous est le miroir vertical de celui de la ROM.
//
// Retourner UNE SEULE des deux moitiés casse tout (murs tête en bas, portes
// déplacées, cubes mal empilés) -- vérifié en le faisant. Ce qui ressemble à
// "trois compensations empiriques d'un même bug" (tri en profondeur, ancre,
// UV) est en réalité un système cohérent. Le vrai correctif, s'il en faut un,
// est côté sprite_dump.py, et les notes déconseillent d'y toucher sans refaire
// les contrôles visuels qui y sont décrits.
//
// La constante fixe (-0x80 / -0x68) est absorbée par le centrage automatique de
// la caméra sur la salle (scene/room.ts), donc omise ici : seuls les
// COEFFICIENTS comptent pour render/camera.ts.

/** Coefficients de la projection, en unités de grille. Espace de sortie :
 * +X vers la droite, **+Y vers le HAUT** -- soit le miroir vertical de
 * l'espace écran de la ROM, cf. l'avertissement en tête de fichier. */
export const CLASSIC_PROJECTION = {
  // screen_x = gridX * X_FROM_X + gridY * X_FROM_Y
  X_FROM_X: 1,
  X_FROM_Y: 1,
  // screen_y = gridX * Y_FROM_X + gridY * Y_FROM_Y + gridZ * Y_FROM_Z
  Y_FROM_X: -0.5,
  Y_FROM_Y: 0.5,
  // `add a,(ix+off_grid_z_or_offset)` : addition, dans un espace Y-vers-le-bas.
  // Le champ est bien nommé `grid_z_or_offset` et pas `height` : c'est un
  // décalage écran additionnel, pas une altitude (une valeur PLUS GRANDE
  // descend à l'écran).
  Y_FROM_Z: 1,
} as const;

/** Une des 4 orientations de caméra isométriques (rotations de 90° dans le
 * plan du sol). 0 = l'orientation du jeu original. */
export type ViewAngle = 0 | 1 | 2 | 3;

/** Centre de rotation : les coordonnées de grille d'une salle sont centrées
 * sur 0x80 (cf. le `-0x80` de la formule, et les données de salle : murs à
 * 0x3F et 0xC0, sol autour de 0x80). Tourner autour de cette valeur garde la
 * salle au même endroit, la caméra se recadre de toute façon ensuite. */
const GRID_CENTER = 0x80;

/**
 * Applique la rotation de vue AVANT projection. C'est tout ce qu'il faut pour
 * les 4 angles : la projection elle-même est une fonction pure de
 * (gridX, gridY, gridZ), donc la faire tourner revient à tourner ses entrées.
 * L'axe vertical (gridZ) n'est pas touché.
 */
export function rotateGrid(gridX: number, gridY: number, view: ViewAngle): [number, number] {
  const dx = gridX - GRID_CENTER;
  const dy = gridY - GRID_CENTER;
  // Rotation de +90° dans le plan du sol : (dx,dy) -> (dy,-dx).
  const [rx, ry] =
    view === 0 ? [dx, dy] : view === 1 ? [dy, -dx] : view === 2 ? [-dx, -dy] : [-dy, dx];
  return [GRID_CENTER + rx, GRID_CENTER + ry];
}

/**
 * Un quart de tour de la caméra autour de l'axe vertical équivaut, pour un
 * objet à symétrie miroir (cubes, blocs, la plupart des ramassables), à un
 * MIROIR HORIZONTAL de son sprite -- c'est ce qui rend les 4 angles jouables
 * sans le moindre sprite supplémentaire. Le jeu original s'appuie déjà sur ce
 * mécanisme (fn_flip_sprite_shape, docs/RENDERING_PIPELINE.md §6).
 *
 * NE VAUT PAS pour les pièces asymétriques (murs, coins, montants de porte) :
 * celles-ci demandent une table de remap type->type, pas un simple miroir --
 * chantier séparé, voir le plan. En attendant elles s'affichent miroitées,
 * donc fausses, sous les vues 1 et 3.
 */
export function viewNeedsFlip(view: ViewAngle): boolean {
  return view === 1 || view === 3;
}

/** Projection complète (rotation de vue incluse), dans l'espace projeté du
 * portage (+Y vers le haut), AVEC la division entière du Z80. Utilisée pour le
 * cadrage caméra et pour la correction d'arrondi ci-dessous. */
export function projectClassic(
  gridX: number,
  gridY: number,
  gridZ: number,
  view: ViewAngle = 0,
): { x: number; y: number } {
  const [gx, gy] = rotateGrid(gridX, gridY, view);
  const p = CLASSIC_PROJECTION;
  return {
    x: gx * p.X_FROM_X + gy * p.X_FROM_Y,
    y: Math.floor((gy - gx) / 2) + gridZ * p.Y_FROM_Z,
  };
}

/**
 * `render/camera.ts` calcule screen_y via une matrice LINÉAIRE, ce qui ne
 * reproduit PAS le `srl a` (division entière, donc floor) du Z80 quand
 * `gridY-gridX` est IMPAIR : décalage d'un demi-pixel selon la parité.
 * Repéré en comparant deux montants de porte côte à côte qui ne se
 * rejoignaient pas. Renvoie l'écart exact à réinjecter via proj_offset_y
 * (voir scene/room.ts) pour retomber pile sur le floor() réel.
 *
 * Ce correctif-ci n'était PAS un symptôme du bug d'axe : il reste nécessaire
 * après correction, une matrice linéaire ne pouvant pas exprimer un floor().
 */
export function classicYRoundingCorrection(gridX: number, gridY: number, view: ViewAngle = 0): number {
  const [gx, gy] = rotateGrid(gridX, gridY, view);
  const p = CLASSIC_PROJECTION;
  const exact = Math.floor((gy - gx) / 2);
  const linear = p.Y_FROM_X * gx + p.Y_FROM_Y * gy;
  return exact - linear;
}
