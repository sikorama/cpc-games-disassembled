import { createProgram } from "./shader";
import type { Mat4 } from "../render/mat4";

const VERTEX_SRC = `#version 300 es
// Billboard : le centre de l'entité passe par la matrice vue (déplacement
// dans le monde, rotation de caméra le cas échéant), puis le décalage du
// coin du quad est appliqué DIRECTEMENT en espace vue -- c'est ce qui
// garde le sprite "toujours face caméra" quel que soit le mode caméra
// (classic ou orbit), voir render/camera.ts.
uniform mat4 u_view;
uniform mat4 u_proj;
uniform vec3 u_worldPos;    // (gridX, height, gridY)
uniform vec2 u_size;        // (largeur, hauteur) sprite, en unités "pixel classique"
uniform vec2 u_anchor;      // 0..1, point d'ancrage dans le sprite (0.5,1 = bas-centre)
uniform vec2 u_projOffset;  // proj_offset_x/y du type (render/isoOffsets.ts), MÊMES
                            // unités que u_size -- ajouté directement, comme dans la
                            // formule originale (docs/RENDERING_PIPELINE.md §5).
uniform float u_flipX;      // bit6 de off_flags ("orientation courante") -- déclenche le
                            // miroir horizontal du sprite dans le jeu original
                            // (fn_flip_sprite_shape, docs/RENDERING_PIPELINE.md §6).
                            // Mute la TEXTURE échantillonnée, pas la position du quad.

in vec2 a_corner; // quad unitaire [0,1]x[0,1]

out vec2 v_uv;

void main() {
  vec4 viewPos = u_view * vec4(u_worldPos, 1.0);
  viewPos.xy += u_projOffset;
  vec2 offset = (a_corner - u_anchor) * u_size;
  // a_corner.y=1 (bas du sprite dans son adressage image) doit descendre à
  // l'écran, donc DIMINUER viewPos.y dans la convention vue "+Y = haut".
  //
  // Cet espace vue est le MIROIR VERTICAL de l'espace écran du jeu (où
  // screen_y croît vers le bas, asm/code/rendering_pipeline.asm:295). Ce n'est
  // pas un bug : les PNG de tools/sprite_dump_out/ sont eux-mêmes des images
  // MIROIR du rendu réel (voir le dé-pivotement plus bas), et les deux miroirs
  // se composent en une image correcte. Tenté le 2026-08-15 de "corriger"
  // l'agencement seul pour le remettre dans le sens de la ROM : ça casse tout
  // (murs tête en bas, portes déplacées, cubes mal empilés) -- c'est un
  // système cohérent, on ne peut pas en retourner une moitié.
  viewPos.x += offset.x;
  viewPos.y -= offset.y;
  gl_Position = u_proj * viewPos;
  // Dé-pivotement des PNG de tools/sprite_dump_out/, qui sont stockés tournés
  // (sprite_dump.py applique un ROTATE_90 en fin de génération) et mis à
  // l'échelle de façon non uniforme (x12 sur un axe, x6 sur l'autre).
  //
  // Expression VALIDÉE CONTRE UNE CAPTURE DU JEU RÉEL (salle 0x00, fournie par
  // l'utilisateur le 2026-08-15) -- c'est la seule méthode qui ait tenu. Deux
  // tentatives précédentes ont échoué, et leur mode d'échec vaut avertissement :
  //
  //   - juger "à l'œil" si un sprite isolé est à l'endroit : un cube reste
  //     plausible sous plusieurs transformations, j'ai conclu deux fois de
  //     travers ;
  //   - "prouver" numériquement l'expression en la comparant pixel à pixel à
  //     un dé-pivotement de référence : la mesure était exacte (écart 0) mais
  //     visait la mauvaise CIBLE (ROT90 pur), donc elle a validé une
  //     expression fausse avec beaucoup d'assurance. Une mesure ne vaut que ce
  //     que vaut sa référence.
  //
  // Le juge fiable est un détail que seul l'assemblage révèle : les DEUX
  // moitiés d'une porte (0x02+0x03, entités distinctes et adjacentes) doivent
  // se rejoindre en une arche ∩ avec clé de voûte. Sous la mauvaise
  // orientation elles s'écartent en "V" -- immédiatement visible, contrairement
  // à l'orientation d'un sprite pris isolément.
  //
  // Le dé-pivotement correct des PNG de tools/sprite_dump_out/ est donc une
  // rotation SUIVIE D'UN MIROIR (déterminant -1), pas une rotation pure : le
  // PNG stocké est l'image miroir de ce qu'affiche le jeu. Cause non tracée
  // côté sprite_dump.py, cf. notes/2026-08-13-sprite-rotation-investigation.md.
  //
  // u_flipX agit sur la composante t (et non s) car, après ce dé-pivotement,
  // c'est la LIGNE du PNG qui porte l'axe horizontal du sprite.
  float mirroredX = u_flipX > 0.5 ? 1.0 - a_corner.x : a_corner.x;
  v_uv = vec2(1.0 - a_corner.y, mirroredX);
}
`;

const FRAGMENT_SRC = `#version 300 es
precision mediump float;
uniform sampler2D u_texture;
in vec2 v_uv;
out vec4 outColor;
void main() {
  vec4 c = texture(u_texture, v_uv);
  // tools/sprite_dump_out/*.png sont en niveaux de gris SANS canal alpha
  // (mode 'L' PIL, pas de transparence réelle à lire). Le fond réel est
  // BLANC (pen 0 du CPC = val 0 -> 255-0*85=255 dans le décodage de
  // tools/sprite_dump.py, shape_to_image), PAS noir comme supposé au
  // premier essai -- corrigé après retour utilisateur ("c'est du blanc
  // opaque là où ça devrait être transparent"). Clé de couleur sur le
  // blanc : discard, PAS un test d'alpha.
  if (c.r > 0.98 && c.g > 0.98 && c.b > 0.98) discard;
  outColor = c;
}
`;

export interface SpriteDrawCall {
  texture: WebGLTexture;
  worldPos: [number, number, number];
  size: [number, number];
  /** proj_offset_x/y du type (render/isoOffsets.ts), [0,0] si inconnu. */
  projOffset: [number, number];
  /** bit6 de off_flags -- voir u_flipX dans le vertex shader. */
  flipX: boolean;
  /** Ordre de dessin (peintre) -- voir scene/room.ts. Pas un vrai
   * test de profondeur GPU : les billboards isométriques classiques
   * se trient correctement par un simple tri CPU sur (gridX+gridY),
   * pas besoin d'un depth buffer pour cette première étape. */
  sortKey: number;
}

export class SpriteRenderer {
  private gl: WebGL2RenderingContext;
  private program: WebGLProgram;
  private vao: WebGLVertexArrayObject;
  private uView: WebGLUniformLocation;
  private uProj: WebGLUniformLocation;
  private uWorldPos: WebGLUniformLocation;
  private uSize: WebGLUniformLocation;
  private uAnchor: WebGLUniformLocation;
  private uProjOffset: WebGLUniformLocation;
  private uFlipX: WebGLUniformLocation;
  private uTexture: WebGLUniformLocation;

  constructor(gl: WebGL2RenderingContext) {
    this.gl = gl;
    this.program = createProgram(gl, VERTEX_SRC, FRAGMENT_SRC);

    const vao = gl.createVertexArray();
    if (!vao) throw new Error("createVertexArray a échoué");
    this.vao = vao;
    gl.bindVertexArray(vao);

    const quad = new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, quad, gl.STATIC_DRAW);
    const locCorner = gl.getAttribLocation(this.program, "a_corner");
    gl.enableVertexAttribArray(locCorner);
    gl.vertexAttribPointer(locCorner, 2, gl.FLOAT, false, 0, 0);

    gl.bindVertexArray(null);

    this.uView = this.mustGetUniform("u_view");
    this.uProj = this.mustGetUniform("u_proj");
    this.uWorldPos = this.mustGetUniform("u_worldPos");
    this.uSize = this.mustGetUniform("u_size");
    this.uAnchor = this.mustGetUniform("u_anchor");
    this.uProjOffset = this.mustGetUniform("u_projOffset");
    this.uFlipX = this.mustGetUniform("u_flipX");
    this.uTexture = this.mustGetUniform("u_texture");
  }

  private mustGetUniform(name: string): WebGLUniformLocation {
    const loc = this.gl.getUniformLocation(this.program, name);
    if (!loc) throw new Error(`uniform introuvable: ${name}`);
    return loc;
  }

  /** view et proj séparés (pas une seule viewProj) : le billboard a
   * besoin d'appliquer le décalage de coin de quad EN ESPACE VUE,
   * après la vue mais avant la projection -- voir le commentaire du
   * vertex shader. */
  draw(view: Mat4, proj: Mat4, calls: SpriteDrawCall[]): void {
    const gl = this.gl;
    gl.useProgram(this.program);
    gl.bindVertexArray(this.vao);
    gl.uniformMatrix4fv(this.uView, false, view);
    gl.uniformMatrix4fv(this.uProj, false, proj);
    // BAS-gauche. Le désassemblage dit que screen_y est la ligne du HAUT du
    // sprite (le blit descend depuis screen_y), et on pourrait donc croire
    // qu'il faut une ancre haut-gauche : essayé le 2026-08-15, ça CASSE le
    // rendu (murs tête en bas, portes déplacées). Raison : l'espace vue est le
    // miroir vertical de l'espace écran du jeu (voir le vertex shader), donc
    // le "haut" de la ROM est bien le bas ici. L'ancre bas-gauche est la
    // traduction correcte dans cet espace, pas une approximation.
    gl.uniform2f(this.uAnchor, 0.0, 1.0);
    gl.uniform1i(this.uTexture, 0);

    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    // Décroissant = du plus LOIN au plus PRÈS. Cet ordre avait été trouvé
    // empiriquement ("les objets qui devraient être derrière sont devant") ;
    // il est cette fois re-dérivé et confirmé sur les données de salle, donc
    // conservé tel quel malgré la correction d'axe : les murs de la salle 0x00
    // sont tous à grid_x=0x3F ou grid_y=0xC0, ce sont donc les faces LOINTAINES
    // -- "loin" = petit grid_x, grand grid_y, ce que sortKey mesure
    // (scene/room.ts).
    const sorted = [...calls].sort((a, b) => b.sortKey - a.sortKey);
    for (const call of sorted) {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, call.texture);
      gl.uniform3fv(this.uWorldPos, call.worldPos);
      gl.uniform2fv(this.uSize, call.size);
      gl.uniform2fv(this.uProjOffset, call.projOffset);
      gl.uniform1f(this.uFlipX, call.flipX ? 1.0 : 0.0);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
  }
}
