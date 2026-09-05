import { loadTexture } from "../gl/texture";
import type { SpriteDrawCall } from "../gl/spriteBatch";
import type { OrthoBounds } from "../render/camera";
import { classicYRoundingCorrection, projectClassic, rotateGrid, viewNeedsFlip, type ViewAngle } from "../render/isoMath";
import { getProjOffset } from "../render/isoOffsets";
import { loadRoomEntities } from "../data/roomManifest";
import { loadSpriteIndex, type SpriteIndex } from "../data/spriteManifest";
import type { RoomEntity } from "../data/types";
import { pushPolicyFor } from "../physics/solidTypes";
import { OBJECT_TYPE_BASE, OBJECT_TYPE_COUNT } from "../game/objectCatalog";

/** Entité résolue (texture chargée), indépendante de l'angle de vue --
 * séparée des draw calls pour que changer d'angle soit un simple recalcul
 * géométrique, sans re-résoudre ni recharger la moindre texture. */
export interface ResolvedEntity {
  entity: RoomEntity;
  texture: WebGLTexture;
  width: number;
  height: number;
  hflipState: boolean;
  isWall: boolean;
  /** Corps mobile (table/coffre/bloc poussable) : sorti du rendu STATIQUE et
   * redessiné chaque frame à sa position courante par scene/pushables.ts. */
  isMovable: boolean;
  /** Objet à ramasser (0x60-0x67). SORTI DU RENDU, et pas pour une raison de
   * mise en scène : ces instances-là ne sont PAS des données de salle. Le
   * manifest a été capturé sur une partie en cours, et le jeu réattribue les
   * types d'objets À CHAQUE LANCEMENT (`fn_catalog_randomize_types` #1D27).
   * Les afficher tels quels figerait le portage sur la partie qui a servi à
   * l'extraction -- vérifié : ses 32 objets correspondent exactement à la
   * rotation 1. C'est game/objectCatalog.ts qui décide, et scene/objects.ts
   * qui dessine. */
  isCatalogObject: boolean;
}

/**
 * Draw call d'une entité de décor à une position de grille DONNÉE plutôt qu'à
 * celle du manifest -- unique source de vérité de la formule (projection,
 * offset de calibration, miroir effectif, clé de tri).
 *
 * Elle prend la position en paramètre précisément pour qu'un corps mobile
 * (scene/pushables.ts) n'ait pas à en recopier une variante : deux copies de
 * cette formule dériveraient, et l'écart ne se verrait que sur l'objet en
 * mouvement, c'est-à-dire au pire endroit.
 */
export function entityDrawCall(
  resolved: ResolvedEntity,
  gridX: number,
  gridY: number,
  gridZ: number,
  view: ViewAngle,
): SpriteDrawCall {
  const { entity, texture, width, height, hflipState } = resolved;
  // render/isoOffsets.ts : calibration par type (proj_offset_x/y), ajoutée
  // telle quelle -- MÊME espace et MÊME signe que dans la formule originale
  // (asm/code/rendering_pipeline.asm:301/309).
  const rawProjOffset = getProjOffset(entity.type, entity.flags) ?? [0, 0];
  const projOffset: [number, number] = [
    rawProjOffset[0],
    // Compense l'écart d'un demi-pixel de la matrice caméra (linéaire) face
    // au `srl a` du Z80 -- voir classicYRoundingCorrection.
    rawProjOffset[1] + classicYRoundingCorrection(gridX, gridY, view),
  ];
  const [rgx, rgy] = rotateGrid(gridX, gridY, view);
  return {
    texture,
    worldPos: [rgx, gridZ, rgy],
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
    sortKey: -rgx + rgy - gridZ,
  };
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

  /** Entités résolues des corps mobiles (table/coffre/bloc poussable) --
   * sprite déjà chargé, pour que scene/pushables.ts les redessine à leur
   * position courante sans repasser par le SpriteIndex. */
  getMovableEntities(): ResolvedEntity[] {
    return this.entities.filter((e) => e.isMovable);
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

    for (const resolved of this.entities) {
      const { entity, width, height, isWall, isMovable, isCatalogObject } = resolved;
      if (hideWalls && isWall) continue;
      // Les objets ne participent même pas au cadrage : leur emplacement du
      // manifest appartient à une autre partie que celle qui se joue.
      if (isCatalogObject) continue;

      const call = entityDrawCall(resolved, entity.gridX, entity.gridY, entity.gridZ, view);

      // Le CADRAGE tient compte des corps mobiles à leur position de départ
      // (sinon la caméra sauterait quand on pousse une table hors du cadre
      // initial), mais leur DRAW CALL vient de scene/pushables.ts, à leur
      // position courante.
      const projected = projectClassic(entity.gridX, entity.gridY, entity.gridZ, view);
      // Ancre = coin BAS-gauche dans l'espace projeté (+Y vers le haut) : le
      // sprite s'étend vers la droite et vers le haut (voir gl/spriteBatch.ts).
      minX = Math.min(minX, projected.x + call.projOffset[0]);
      maxX = Math.max(maxX, projected.x + call.projOffset[0] + width);
      minY = Math.min(minY, projected.y + call.projOffset[1]);
      maxY = Math.max(maxY, projected.y + call.projOffset[1] + height);

      if (isMovable) continue;
      drawCalls.push(call);
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
/** Objets à ramasser : la plage entière 0x60-0x67, telle que la produit
 * `A & 7 | 0x60` dans le randomiseur -- donc close par construction. */
function isCatalogObjectType(type: number): boolean {
  return type >= OBJECT_TYPE_BASE && type < OBJECT_TYPE_BASE + OBJECT_TYPE_COUNT;
}

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
      isMovable: pushPolicyFor(entity.type, entity.flags) !== null,
      isCatalogObject: isCatalogObjectType(entity.type),
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
