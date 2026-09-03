// Solveur AABB en coordonnées de grille NON tournées -- indépendant du
// rendu (voir web/CONTEXT.md, "Modèle physique de grille") : c'est
// render/isoMath.ts qui tourne les coordonnées pour l'affichage, jamais
// ce module. Implémentation propre, INSPIRÉE du solveur par axe du jeu
// original (fn_entity_movement_vector_resolve/fn_entity_collide_axis_*,
// asm/code/doors_and_player_logic.asm) -- pas un portage littéral du Z80.

export interface Box3 {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
  minZ: number;
  maxZ: number;
}

export type Axis = "x" | "y" | "z";

function axisRange(box: Box3, axis: Axis): [number, number] {
  if (axis === "x") return [box.minX, box.maxX];
  if (axis === "y") return [box.minY, box.maxY];
  return [box.minZ, box.maxZ];
}

/** Chevauchement sur les deux axes AUTRES que `axis` -- condition pour
 * qu'un obstacle soit pertinent pour le déplacement testé sur `axis`. */
function overlapsOtherAxes(a: Box3, b: Box3, axis: Axis): boolean {
  const xOverlap = a.minX < b.maxX && a.maxX > b.minX;
  const yOverlap = a.minY < b.maxY && a.maxY > b.minY;
  const zOverlap = a.minZ < b.maxZ && a.maxZ > b.minZ;
  if (axis === "x") return yOverlap && zOverlap;
  if (axis === "y") return xOverlap && zOverlap;
  return xOverlap && yOverlap;
}

export interface AxisResolution {
  /** Déplacement réellement permis sur cet axe (peut être réduit par un
   * obstacle, jamais agrandi). */
  delta: number;
  /** Un obstacle a réduit le déplacement -- pour Z, c'est le signal
   * "atterri"/"a heurté un plafond" (voir scene/player.ts). */
  blocked: boolean;
}

/**
 * Résout un déplacement proposé sur UN axe contre une liste d'obstacles.
 * `box` est la boîte du mobile À SA POSITION ACTUELLE (avant ce
 * déplacement) -- appeler séquentiellement axe par axe (Z puis X puis Y,
 * voir scene/player.ts) en reconstruisant `box` avec la position mise à
 * jour entre chaque appel, pour que chaque axe voie l'effet du précédent.
 *
 * Les obstacles déjà en chevauchement sur l'axe testé sont ignorés
 * (pas de "poussée" hors obstacle) -- un choix MVP simple, honnête sur ses
 * limites plutôt que de deviner une résolution de pénétration.
 */
export function resolveAxis(box: Box3, delta: number, axis: Axis, obstacles: Box3[]): AxisResolution {
  if (delta === 0) return { delta: 0, blocked: false };

  let allowed = delta;
  let blocked = false;
  const [boxMin, boxMax] = axisRange(box, axis);

  for (const obstacle of obstacles) {
    if (!overlapsOtherAxes(box, obstacle, axis)) continue;
    const [obsMin, obsMax] = axisRange(obstacle, axis);

    if (delta > 0) {
      if (obsMin < boxMax) continue; // déjà chevauché ou derrière : ignoré
      const gap = obsMin - boxMax;
      if (gap < allowed) {
        allowed = gap;
        blocked = true;
      }
    } else {
      if (obsMax > boxMin) continue;
      const gap = obsMax - boxMin; // négatif
      if (gap > allowed) {
        allowed = gap;
        blocked = true;
      }
    }
  }

  return { delta: allowed, blocked };
}
