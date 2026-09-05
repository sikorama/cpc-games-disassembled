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

export interface AxisResolution<T> {
  /** Déplacement réellement permis sur cet axe (peut être réduit par un
   * obstacle, jamais agrandi). */
  delta: number;
  /** Un obstacle a réduit le déplacement -- pour Z, c'est le signal
   * "atterri"/"a heurté un plafond" (voir scene/player.ts). */
  blocked: boolean;
  /** L'obstacle qui a le plus réduit le déplacement, ou `null` si aucun.
   *
   * FAIT ROM : le scan de collision par axe du jeu d'origine ne se contente
   * pas de bloquer, il AGIT sur l'entité heurtée -- `fn_entity_collide_axis_x`
   * (#244C, asm/code/doors_and_player_logic.asm:895-936) teste
   * `bit 2,(iy+off_flags)` et, si le bit est posé, recopie le vecteur en
   * attente du mobile dans celui de l'entité heurtée. Rendre l'obstacle
   * bloquant est donc une nécessité, pas un confort : sans lui il n'y a
   * personne à pousser. */
  blocker: T | null;
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
export function resolveAxis<T extends { box: Box3 }>(
  box: Box3,
  delta: number,
  axis: Axis,
  obstacles: readonly T[],
): AxisResolution<T> {
  if (delta === 0) return { delta: 0, blocked: false, blocker: null };

  let allowed = delta;
  let blocked = false;
  let blocker: T | null = null;
  const [boxMin, boxMax] = axisRange(box, axis);

  for (const candidate of obstacles) {
    const obstacle = candidate.box;
    if (!overlapsOtherAxes(box, obstacle, axis)) continue;
    const [obsMin, obsMax] = axisRange(obstacle, axis);

    if (delta > 0) {
      if (obsMin < boxMax) continue; // déjà chevauché ou derrière : ignoré
      const gap = obsMin - boxMax;
      if (gap < allowed) {
        allowed = gap;
        blocked = true;
        blocker = candidate;
      }
    } else {
      if (obsMax > boxMin) continue;
      const gap = obsMax - boxMin; // négatif
      if (gap > allowed) {
        allowed = gap;
        blocked = true;
        blocker = candidate;
      }
    }
  }

  return { delta: allowed, blocked, blocker };
}
