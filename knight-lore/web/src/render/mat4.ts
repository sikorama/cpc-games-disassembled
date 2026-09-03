// Petit utilitaire mat4 colonne-major (convention WebGL), volontairement
// minimal -- pas de dépendance externe (choix "WebGL2 brut" du plan).
export type Mat4 = Float32Array;

export function identity(): Mat4 {
  // prettier-ignore
  return new Float32Array([
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);
}

/** Projection orthographique classique, sortie en NDC [-1,1]. Passer
 * `bottom` > `top` retourne l'axe Y -- c'est ainsi que Camera.getProjection()
 * convertit l'espace écran du jeu (+Y vers le bas) vers le NDC de WebGL. */
export function ortho(
  left: number,
  right: number,
  bottom: number,
  top: number,
  near: number,
  far: number,
): Mat4 {
  const lr = 1 / (left - right);
  const bt = 1 / (bottom - top);
  const nf = 1 / (near - far);
  const out = identity();
  out[0] = -2 * lr;
  out[5] = -2 * bt;
  out[10] = 2 * nf;
  out[12] = (left + right) * lr;
  out[13] = (top + bottom) * bt;
  out[14] = (far + near) * nf;
  return out;
}

// Les helpers de rotation/translation 3D (rotateX/rotateY/translate/multiply)
// ont été retirés avec le mode caméra "orbit" : les 4 angles isométriques
// s'obtiennent en tournant les coordonnées de grille AVANT projection
// (render/isoMath.ts), pas en tournant la caméra -- une caméra tournée ne
// reproduit pas le ratio 2:1 du jeu et cassait le tri peintre.
