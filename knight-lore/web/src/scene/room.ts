import { loadTexture } from "../gl/texture";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { OrthoBounds } from "../render/camera";
import { classicYRoundingCorrection, projectClassic, rotateGrid, viewNeedsFlip, type ViewAngle } from "../render/isoMath";
import { getProjOffset } from "../render/isoOffsets";
import { loadRoomEntities } from "../data/roomManifest";
import { loadSpriteIndex, type SpriteIndex } from "../data/spriteManifest";
import type { RoomEntity } from "../data/types";

/** Entité résolue (texture chargée), indépendante de l'angle de vue --
 * séparée des draw calls pour que changer d'angle soit un simple recalcul
 * géométrique, sans re-résoudre ni recharger la moindre texture. */
interface ResolvedEntity {
  entity: RoomEntity;
  texture: WebGLTexture;
  width: number;
  height: number;
  hflipState: boolean;
  isWall: boolean;
}

export interface RoomView {
  drawCalls: SpriteDrawCall[];
  /** Boîte englobante en espace écran du jeu (+Y vers le bas), pour
   * auto-cadrer la caméra -- aucune donnée de var_camera_reference n'est
   * extraite actuellement. */
  bounds: OrthoBounds;
}

export class LoadedRoom {
  constructor(private readonly entities: ResolvedEntity[]) {}

  /** Entités brutes (coordonnées de grille non tournées), pour construire
   * les obstacles physiques (physics/obstacles.ts) sans re-fetcher le
   * manifest -- voir main.ts. */
  getEntities(): RoomEntity[] {
    return this.entities.map((e) => e.entity);
  }

  /**
   * Construit les draw calls pour un angle de vue donné. Toute la logique
   * des 4 angles tient ici : on tourne les COORDONNÉES DE GRILLE avant
   * projection (isoMath.rotateGrid) et on laisse la projection isométrique
   * du jeu, elle, rigoureusement inchangée.
   *
   * `hideWalls` : les salles ne contiennent des murs que sur DEUX côtés (la
   * "boîte ouverte" du Filmation -- salle 0x00 : tout est à grid_x=0x3F ou
   * grid_y=0xC0, les côtés 0xC0/0x3F sont vides). Sous les vues 1/2/3 ces
   * murs basculent donc DEVANT la scène et la masquent. Les masquer est la
   * parade honnête en attendant la table de remap des pièces de mur : ça
   * n'invente aucune donnée absente de la ROM.
   */
  build(view: ViewAngle, hideWalls: boolean): RoomView {
    const drawCalls: SpriteDrawCall[] = [];
    let minX = Infinity;
    let maxX = -Infinity;
    let minY = Infinity;
    let maxY = -Infinity;

    for (const { entity, texture, width, height, hflipState, isWall } of this.entities) {
      if (hideWalls && isWall) continue;

      const projected = projectClassic(entity.gridX, entity.gridY, entity.gridZ, view);
      // render/isoOffsets.ts : calibration par type (proj_offset_x/y), ajoutée
      // telle quelle -- MÊME espace et MÊME signe que dans la formule originale
      // (asm/code/rendering_pipeline.asm:301/309), maintenant que le pipeline
      // travaille bien en espace écran du jeu (+Y vers le bas).
      const rawProjOffset = getProjOffset(entity.type, entity.flags) ?? [0, 0];
      const projOffset: [number, number] = [
        rawProjOffset[0],
        // Compense l'écart d'un demi-pixel de la matrice caméra (linéaire) face
        // au `srl a` du Z80 -- voir classicYRoundingCorrection.
        rawProjOffset[1] + classicYRoundingCorrection(entity.gridX, entity.gridY, view),
      ];

      // Ancre = coin BAS-gauche dans l'espace projeté (+Y vers le haut) : le
      // sprite s'étend vers la droite et vers le haut (voir gl/spriteBatch.ts).
      minX = Math.min(minX, projected.x + projOffset[0]);
      maxX = Math.max(maxX, projected.x + projOffset[0] + width);
      minY = Math.min(minY, projected.y + projOffset[1]);
      maxY = Math.max(maxY, projected.y + projOffset[1] + height);

      const [rgx, rgy] = rotateGrid(entity.gridX, entity.gridY, view);

      drawCalls.push({
        texture,
        worldPos: [rgx, entity.gridZ, rgy],
        size: [width, height],
        projOffset,
        // Le sprite est MUTÉ EN PLACE dans le jeu original
        // (docs/RENDERING_PIPELINE.md §6) : le PNG capturé est un INSTANTANÉ de
        // ce bit, pas un état neutre -- le miroir à appliquer est le XOR de
        // l'état capturé et du bit6 de l'entité, pas l'un des deux seul.
        // Troisième terme : un quart de tour de caméra équivaut à un miroir
        // horizontal pour un objet à symétrie miroir (voir viewNeedsFlip).
        flipX: hflipState !== ((entity.flags & 0x40) !== 0) !== viewNeedsFlip(view),
        // Peintre : profondeur dérivée géométriquement (produit vectoriel des
        // deux axes écran), et recalculée sur les coordonnées TOURNÉES -- c'est
        // ce qui fait que le tri reste juste aux 4 angles sans rien réécrire.
        sortKey: -rgx + rgy - entity.gridZ,
      });
    }

    const margin = 20;
    const bounds: OrthoBounds =
      drawCalls.length > 0
        ? { minX: minX - margin, maxX: maxX + margin, minY: minY - margin, maxY: maxY + margin }
        : { minX: -100, maxX: 100, minY: -100, maxY: 100 };

    return { drawCalls, bounds };
  }
}

const textureCache = new Map<string, Promise<WebGLTexture>>();

/** Exporté pour scene/guard.ts : le garde réutilise le MÊME cache de
 * textures (par URL) que les entités de décor, plutôt qu'un nouveau
 * chargement -- c'est une vraie entité ROM, indexée par
 * data/spriteManifest.ts comme n'importe quelle autre. */
export function getTexture(gl: WebGL2RenderingContext, url: string): Promise<WebGLTexture> {
  let cached = textureCache.get(url);
  if (!cached) {
    cached = loadTexture(gl, url);
    textureCache.set(url, cached);
  }
  return cached;
}

/** Types de mur, TOUS THÈMES -- utilisés pour pouvoir les masquer sous les
 * vues tournées, voir LoadedRoom.build().
 *
 * Doit rester ALIGNÉ sur `WALL_TYPES` de tools/room_map/teleport.py, d'où
 * vient le champ `is_wall` du manifest que consomme la physique
 * (physics/obstacles.ts) : les deux définitions avaient divergé, celle-ci
 * ayant oublié 0x80. Résultat, dans les 24 salles "forêt" -- dont tous les
 * murs sont des 0x80 et aucun 0x0A-0x0F -- le rendu ne reconnaissait aucun
 * mur, alors que la physique en voyait partout. Deux définitions du même
 * concept, c'est une de trop : si l'une bouge, l'autre doit suivre. */
function isWallType(type: number): boolean {
  return type === 0x80 || (type >= 0x0a && type <= 0x0f);
}

export async function loadRoom(gl: WebGL2RenderingContext, roomId: number): Promise<LoadedRoom> {
  const [entities, spriteIndex]: [RoomEntity[], SpriteIndex] = await Promise.all([
    loadRoomEntities(roomId),
    loadSpriteIndex(),
  ]);

  const resolved: ResolvedEntity[] = [];
  const missingTypes = new Set<number>();
  // Types sans calibration de projection : ils retombent sur [0,0], donc
  // s'affichent DÉCALÉS sans rien signaler. C'est ce silence qui avait laissé
  // 32 types (1053 instances) mal placés jusqu'au 2026-09-04 -- on avertit
  // désormais, comme pour les types sans sprite.
  const missingOffsets = new Set<number>();

  for (const entity of entities) {
    const sprite = spriteIndex.get(entity.type);
    if (!sprite) {
      missingTypes.add(entity.type);
      continue;
    }
    // Les PNG de tools/sprite_dump_out/ sont des silhouettes en niveaux de
    // gris (forme du sprite), PAS les couleurs CPC réelles : le mapping
    // pen/encre -> couleur n'a jamais été décodé (docs/RENDERING_PIPELINE.md
    // §9). Chantier séparé.
    if (getProjOffset(entity.type, entity.flags) === null) {
      missingOffsets.add(entity.type);
    }
    const texture = await getTexture(gl, sprite.url);
    resolved.push({
      entity,
      texture,
      width: sprite.width,
      height: sprite.height,
      hflipState: sprite.hflipState,
      isWall: isWallType(entity.type),
    });
  }

  if (missingOffsets.size > 0) {
    console.warn(
      `room 0x${roomId.toString(16)}: types SANS calibration de projection ` +
        `(affichés à [0,0], donc décalés):`,
      [...missingOffsets].map((t) => `0x${t.toString(16)}`),
    );
  }

  if (missingTypes.size > 0) {
    console.warn(
      `room 0x${roomId.toString(16)}: types sans sprite connu (ignorés):`,
      [...missingTypes].map((t) => `0x${t.toString(16)}`),
    );
  }

  return new LoadedRoom(resolved);
}
