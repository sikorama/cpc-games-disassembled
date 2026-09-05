// Cycle jour/nuit et compteur de jours.
//
// Entièrement tiré de la ROM : `fn_hud_day_night_cycle` (#1C44) et sa fin de
// cycle `fn_hud_day_night_cycle_end` (#1CAF). Aucune valeur de réglage ici --
// si un nombre de ce fichier paraît arbitraire, c'est qu'il vient du jeu.
//
// LE CYCLE EST UNE ICÔNE QUI TRAVERSE L'ÉCRAN. Il n'y a pas de compteur de
// temps séparé dans l'original : le soleil/la lune EST l'horloge. La ROM
// traite l'icône comme une pseudo-entité (`var_day_night_flag` #1CFA réutilise
// intégralement le layout de struct d'entité) et avance sa position écran ;
// c'est en atteignant le bord que le demi-cycle se termine. On garde cette
// structure telle quelle plutôt que de la « simplifier » en un compteur de
// ticks : la position de l'icône est aussi ce qu'il faut afficher, et deux
// représentations du même temps finiraient par diverger.

/** Cadence : la routine ne fait rien 7 frames sur 8 (`and #07 / ret nz`). */
const CYCLE_THROTTLE = 8;

/** Position de départ de l'icône, `off_screen_x` = 0xB0
 * (`fn_hud_day_night_icon_init` #1D16). */
const ICON_X_START = 0xb0;

/** Fin de demi-cycle : `cp #E1` APRÈS l'incrément. De 0xB0 à 0xE1 il y a 49
 * incréments, à raison d'un tous les 8 ticks -- soit **392 ticks par
 * demi-cycle**, jour puis nuit. */
const ICON_X_END = 0xe1;

/** Fin de partie : `cp #40` sur le compteur BCD, donc 40 jours en décimal. */
const DAY_LIMIT_BCD = 0x40;

/** Type ROM de l'icône : 0x58 soleil (jour), 0x59 lune (nuit). La bascule est
 * un `xor #01` sur le type, et c'est CE bit que la ROM relit ensuite pour
 * décider d'incrémenter le compteur de jours -- d'où le fait qu'il n'y a pas
 * d'autre variable de phase dans le jeu que le type de l'icône. */
export const ICON_TYPE_SUN = 0x58;
export const ICON_TYPE_MOON = 0x59;

export type DayPhase = "day" | "night";

export interface DayNightState {
  phase: DayPhase;
  /** Position écran de l'icône, 0xB0..0xE1. Sert d'horloge ET d'affichage. */
  iconX: number;
  /** Sous-cadence locale, équivalente au `and #07` sur `var_frame_counter`. */
  throttle: number;
  /** Compteur de jours au format **BCD**, comme en ROM (`add a,#01 / daa`).
   * Conservé en BCD plutôt que converti : c'est ce format qui explique la
   * limite à `0x40`, et le HUD d'origine affiche les deux quartets tels
   * quels. Voir `dayCounterDecimal()`. */
  dayCounterBcd: number;
  /** `var_transform_flag_and_saved_type` (#0077) : demande de transformation
   * du joueur, posée en fin de demi-cycle et consommée par le joueur. La
   * demande n'est PAS la transformation -- le joueur la refuse tant que ses
   * propres conditions ne sont pas réunies (voir scene/player.ts). */
  transformRequested: boolean;
  /** Le compteur a atteint 40 jours (`jp z,fn_game_over_or_daycycle_end`).
   * Le portage n'a pas encore d'écran de fin : on lève le drapeau et on
   * s'arrête là, plutôt que d'inventer une fin. */
  daysExhausted: boolean;
}

export function createDayNightState(): DayNightState {
  return {
    // Le jeu démarre de JOUR : `fn_hud_day_night_icon_init` pose le type
    // 0x58 (soleil).
    phase: "day",
    iconX: ICON_X_START,
    throttle: 0,
    dayCounterBcd: 0,
    transformRequested: false,
    daysExhausted: false,
  };
}

/**
 * Annule une demande de transformation en attente -- ce que fait l'init de
 * salle.
 *
 * FAIT ROM : `fn_init_room_entities` (#29B4) remet
 * `var_transform_flag_and_saved_type` (#0077) à zéro. Entrer dans une salle
 * pendant qu'une demande attend la fait donc PERDRE, et le joueur garde sa
 * forme jusqu'au prochain basculement du cycle. C'est contre-intuitif, ça
 * ressemble à un oubli, et c'est pourtant ce que fait le jeu : le noter ici
 * évite qu'on « corrige » l'écart plus tard.
 *
 * Ne touche pas au cycle lui-même : l'icône, la phase et le compteur de jours
 * survivent aux changements de salle.
 */
export function cancelPendingTransform(state: DayNightState): void {
  state.transformRequested = false;
}

/** Type ROM de l'icône à afficher pour la phase courante. */
export function iconType(state: DayNightState): number {
  return state.phase === "day" ? ICON_TYPE_SUN : ICON_TYPE_MOON;
}

/** Progression du demi-cycle courant, 0..1 -- pour un affichage de portage
 * (barre, position). L'icône d'origine se déplace linéairement, donc c'est
 * exactement sa position rapportée à sa course. */
export function halfCycleProgress(state: DayNightState): number {
  return (state.iconX - ICON_X_START) / (ICON_X_END - ICON_X_START);
}

/**
 * Incrément BCD, exactement `add a,#01 / daa`.
 *
 * Ce n'est pas une coquetterie de fidélité : c'est le BCD qui rend la
 * comparaison `cp #40` équivalente à « 40 jours ». En binaire pur, 0x40
 * vaudrait 64 jours -- l'écart ne se verrait qu'au bout d'une heure de jeu,
 * c'est-à-dire jamais pendant un test.
 */
function bcdIncrement(value: number): number {
  let low = (value & 0x0f) + 1;
  let high = (value >> 4) & 0x0f;
  if (low > 9) {
    low = 0;
    high += 1;
  }
  if (high > 9) high = 0; // repli à 100 -- hors d'atteinte avant la limite
  return (high << 4) | low;
}

/** Compteur de jours en décimal, pour l'affichage. */
export function dayCounterDecimal(state: DayNightState): number {
  return ((state.dayCounterBcd >> 4) & 0x0f) * 10 + (state.dayCounterBcd & 0x0f);
}

/**
 * Avance le cycle d'UN TICK de logique.
 *
 * Ordre repris tel quel de `fn_hud_day_night_cycle_end` (#1CAF), parce qu'il
 * décide d'un comportement observable : la bascule de phase a lieu AVANT le
 * test qui incrémente le compteur de jours, et ce test relit la phase déjà
 * basculée. Le compteur avance donc au passage **nuit → jour** seulement, pas
 * à chaque demi-cycle. La demande de transformation, elle, est posée aux
 * DEUX transitions.
 */
export function updateDayNight(state: DayNightState): void {
  if (state.daysExhausted) return;

  state.throttle = (state.throttle + 1) % CYCLE_THROTTLE;
  if (state.throttle !== 0) return;

  state.iconX += 1;
  if (state.iconX !== ICON_X_END) return;

  state.phase = state.phase === "day" ? "night" : "day";
  state.iconX = ICON_X_START;
  state.transformRequested = true;

  if (state.phase === "day") {
    state.dayCounterBcd = bcdIncrement(state.dayCounterBcd);
    if (state.dayCounterBcd === DAY_LIMIT_BCD) state.daysExhausted = true;
  }
}
