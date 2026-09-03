// Vue de dessus (plan X/Y BRUT, coordonnées de grille NON tournées) --
// aucun rapport avec le rendu isométrique : c'est exactement l'espace où
// vit physics/aabb.ts (voir web/CONTEXT.md, "Modèle physique de grille").
// But : rendre visible/mesurable un décalage entre le sprite (rendu
// isométrique projeté, ancré différemment) et la vraie boîte de collision
// -- imperceptible en vue iso, immédiat ici.

import type { Obstacle } from "../physics/obstacles";
import { playerBox, type PlayerState } from "../scene/player";
import { guardBox, type GuardState } from "../scene/guard";

// Les coordonnées de grille observées dans les salles restent dans
// 0..255 (un octet) -- échelle fixe plutôt que recalculée par salle, pour
// que la vue ne "saute" pas visuellement en changeant de salle.
const GRID_RANGE = 256;

export function drawTopView(
  ctx: CanvasRenderingContext2D,
  size: number,
  obstacles: Obstacle[],
  player: PlayerState,
  guards: GuardState[],
): void {
  const scale = size / GRID_RANGE;
  ctx.clearRect(0, 0, size, size);
  ctx.fillStyle = "#111";
  ctx.fillRect(0, 0, size, size);

  // Largeur/hauteur minimales à l'écran : un mur avec une vraie bbox nulle
  // sur un axe (bande fine orientée selon son sens, voir
  // physics/obstacles.ts) donnerait un fillRect de largeur/hauteur EXACTEMENT
  // nulle -- invisible sur un canvas 2D (pas un bug de collision, juste un
  // bug d'affichage du débogueur qui empêchait de vérifier visuellement que
  // ces murs sont bien là). Bug trouvé en testant, 2026-09-04.
  const MIN_VISIBLE_PX = 1.5;
  for (const obstacle of obstacles) {
    // Le sol synthétique couvre toute la salle -- l'afficher masquerait
    // les vrais obstacles, pas utile ici.
    if (obstacle.kind === "floor") continue;
    const { minX, maxX, minY, maxY } = obstacle.box;
    ctx.fillStyle = obstacle.kind === "wall" ? "rgba(224,90,90,0.8)" : "rgba(90,150,224,0.8)";
    const w = Math.max(MIN_VISIBLE_PX, (maxX - minX) * scale);
    const h = Math.max(MIN_VISIBLE_PX, (maxY - minY) * scale);
    // Centré sur la vraie boîte plutôt qu'ancré à son coin, pour qu'un
    // agrandissement forcé (largeur/hauteur nulle) reste centré sur la
    // vraie position au lieu de déborder d'un seul côté.
    ctx.fillRect(minX * scale - (w - (maxX - minX) * scale) / 2, minY * scale - (h - (maxY - minY) * scale) / 2, w, h);
  }

  ctx.fillStyle = "#e08a3a";
  for (const guard of guards) {
    const box = guardBox(guard);
    ctx.fillRect(box.minX * scale, box.minY * scale, (box.maxX - box.minX) * scale, (box.maxY - box.minY) * scale);
  }

  const box = playerBox(player);
  ctx.fillStyle = "#e0c93a";
  ctx.fillRect(box.minX * scale, box.minY * scale, (box.maxX - box.minX) * scale, (box.maxY - box.minY) * scale);

  ctx.strokeStyle = "#555";
  ctx.strokeRect(0.5, 0.5, size - 1, size - 1);

  ctx.fillStyle = "#aaa";
  ctx.font = "9px monospace";
  ctx.fillText("+X →", size - 34, size - 4);
  ctx.save();
  ctx.translate(8, size - 8);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText("+Y →", 0, 0);
  ctx.restore();
}
