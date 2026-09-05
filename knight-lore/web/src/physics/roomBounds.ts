// Limite de salle appliquée au DÉPLACEMENT, et non au décor.
//
// LE FAIT QUI CHANGE TOUT : ce ne sont pas les murs qui empêchent de sortir
// d'une salle. Les salles de Knight Lore n'ont de murs que sur DEUX côtés (la
// « boîte ouverte » du Filmation, voir scene/room.ts) -- sur les deux autres,
// il n'y a rien du tout. Ce qui retient les entités est un CLAMP dans la
// primitive de déplacement générique : `fn_entity_clamp_pending_x/_y`
// (#258F/#25BA), appelées par `fn_entity_movement_vector_resolve` (#23F7).
//
// Étant dans la primitive générique, ce clamp s'applique à TOUT ce qui bouge --
// joueur, gardes, coffres poussés. C'est pour ça qu'un coffre poussé vers un
// côté sans mur s'arrête dans l'original au lieu de partir hors de l'écran.
//
// LA FORME DU TEST, reprise telle quelle (loc_259E) :
//
//     |coord + delta - 0x80| + demi_étendue  <  borne
//
// C'est un RAYON autour du centre de salle, pas un rectangle de murs -- d'où
// le `sub #80` suivi d'un `neg` conditionnel (valeur absolue) dans la ROM. Si
// le test échoue, le delta est réduit d'exactement 1 vers zéro
// (`fn_step_toward_zero` #233B) et le test recommence, jusqu'à ce que ça passe
// ou que le delta soit nul.
//
// LES DEUX INHIBITIONS de la ROM, et pourquoi elles ne sont pas ici :
// `and #F0 / ret nz` (cooldown) et `bit 0,(ix+off_flags) / ret nz` (« porte
// franchie »). La seconde est ce qui autorise le JOUEUR à sortir par une
// porte -- le portage modélise ça autrement, par sa détection de
// franchissement de bord (scene/roomTransition.ts), donc ce module ne
// s'applique pas au joueur. Les corps poussés et les gardes, eux, ne portent
// jamais ce bit : pour eux le clamp est inconditionnel.

import roomBoundsData from "../data/assets/room_bounds.json";

/** Centre de salle, et centre du clamp (`sub #80`). */
export const ROOM_CENTER = 0x80;

export interface RoomBound {
  x: number;
  y: number;
  z: number;
}

/** Repli si une salle n'a pas d'entrée -- l'entrée 0 est la calibration
 * « salle carrée », de loin la plus fréquente (70 salles sur 128). Ne devrait
 * jamais servir : la couverture est vérifiée exacte (128/128, aucune salle du
 * manifest sans borne et réciproquement). */
const DEFAULT_BOUND: RoomBound = { x: 0x40, y: 0x40, z: 0x80 };

/**
 * Bornes d'une salle.
 *
 * Trois calibrations seulement, choisies par le RATIO D'ASPECT de la salle
 * (`tbl_room_master_coords` : carrée, plus haute que large, plus large que
 * haute). Une salle « écrasée » a donc une borne deux fois plus serrée sur son
 * axe court -- ignorer l'index et prendre 0x40 partout laisserait les objets
 * glisser deux fois trop loin dans 58 salles sur 128.
 */
export function boundsForRoom(roomId: number): RoomBound {
  const key = `0x${roomId.toString(16).padStart(2, "0")}`;
  const index = (roomBoundsData.by_room as Record<string, number>)[key];
  if (index === undefined) return DEFAULT_BOUND;
  return roomBoundsData.bounds[index] ?? DEFAULT_BOUND;
}

/** `fn_step_toward_zero` (#233B) : réduit de 1 vers zéro, exactement. */
function stepTowardZero(value: number): number {
  if (value === 0) return 0;
  return value > 0 ? value - 1 : value + 1;
}

/**
 * Réduit `delta` jusqu'à ce que la position résultante tienne dans la salle.
 *
 * Renvoie le delta autorisé (éventuellement 0). Une entité DÉJÀ hors bornes ne
 * sera pas ramenée à l'intérieur -- le clamp empêche de sortir, il ne corrige
 * pas ; la ROM ne fait pas autre chose (la boucle s'arrête dès que le delta est
 * nul, sans jamais toucher à la position).
 */
export function clampDeltaToRoom(
  coord: number,
  delta: number,
  halfExtent: number,
  bound: number,
): number {
  let d = delta;
  while (d !== 0 && Math.abs(coord + d - ROOM_CENTER) + halfExtent >= bound) {
    d = stepTowardZero(d);
  }
  return d;
}
