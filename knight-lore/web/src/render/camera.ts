import { CLASSIC_PROJECTION } from "./isoMath";
import { identity, ortho, type Mat4 } from "./mat4";

/** Boîte englobante dans l'espace projeté "classic" (+Y vers le HAUT, voir
 * isoMath.ts) : `maxY` est le haut de la salle à l'écran, `minY` son bas. */
export interface OrthoBounds {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

/**
 * Caméra orthographique à angle FIXE : elle reproduit exactement l'agencement
 * de la projection isométrique du jeu original (voir render/isoMath.ts). Ce
 * n'est pas une rotation 3D physique, et ça ne cherche pas à l'être : le ratio
 * de pixel 2:1 du jeu n'est pas atteignable par une caméra orthonormée tournée.
 *
 * L'ancien mode "orbit" (yaw/pitch libres à la souris) a été retiré : il
 * cassait le tri peintre, calibré pour ce seul angle, et faisait sauter la
 * projection dès le premier pixel de glissé. Les 4 orientations utiles sont
 * obtenues autrement, et exactement : en tournant les COORDONNÉES DE GRILLE
 * avant projection (isoMath.rotateGrid), ce qui garde une vraie projection
 * isométrique du jeu dans les 4 cas.
 *
 * view et projection sont exposées séparément (pas une seule matrice
 * combinée) : gl/spriteBatch.ts applique le décalage de coin de quad EN
 * ESPACE VUE, entre les deux.
 */
export class Camera {
  zoom = 1;
  bounds: OrthoBounds;
  /** Décalage fin manuel (mêmes unités que `bounds`), ajusté aux flèches --
   * pour recadrer et lire la valeur exacte dans le HUD (voir main.ts). */
  pan: [number, number] = [0, 0];

  constructor(bounds: OrthoBounds) {
    this.bounds = bounds;
  }

  /** Applique directement (gridX, gridZ, gridY, 1) -> (screen_x, screen_y, profondeur, 1),
   * en espace écran du jeu (+Y vers le bas). Colonne-major : m[col*4+row]. */
  getView(): Mat4 {
    const p = CLASSIC_PROJECTION;
    const m = identity();
    m[0] = p.X_FROM_X; // row0,col0
    m[4] = 0; // row0,col1 (gridZ ne contribue pas à screen_x)
    m[8] = p.X_FROM_Y; // row0,col2
    m[1] = p.Y_FROM_X; // row1,col0
    m[5] = p.Y_FROM_Z; // row1,col1
    m[9] = p.Y_FROM_Y; // row1,col2
    m[2] = 0;
    m[6] = 0;
    m[10] = 1;
    return m;
  }

  /**
   * aspect = largeur/hauteur du canvas -- élargit la boîte englobante pour ne
   * pas étirer la salle si le canvas n'est pas carré.
   *
   * Pas de retournement d'axe ici : l'espace projeté a déjà +Y vers le haut,
   * comme le NDC de WebGL. (Un retournement a été tenté le 2026-08-15, pour
   * aligner cet espace sur le screen_y de la ROM qui croît vers le bas : ça
   * casse le rendu, voir gl/spriteBatch.ts.)
   */
  getProjection(aspect: number): Mat4 {
    const b = this.bounds;
    const halfW = (b.maxX - b.minX) / 2;
    const halfH = (b.maxY - b.minY) / 2;
    const fitHalfW = Math.max(halfW, halfH * aspect) * this.zoom;
    const fitHalfH = Math.max(halfH, halfW / aspect) * this.zoom;
    const cx = (b.minX + b.maxX) / 2 + this.pan[0];
    const cy = (b.minY + b.maxY) / 2 + this.pan[1];
    return ortho(cx - fitHalfW, cx + fitHalfW, cy - fitHalfH, cy + fitHalfH, -1000, 1000);
  }
}
