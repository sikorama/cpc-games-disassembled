// Cadence de la boucle de logique.
//
// L'original n'en a PAS. Vérifié sur le désassemblage (2026-09-04) :
// fn_main_loop (#05AE) est une boucle libre -- aucun HALT, aucune lecture du
// port PPI B, aucune synchronisation vidéo, et l'IM 1 à 300 Hz ne sert qu'au
// moteur de son sans rien signaler à la boucle. `var_frame_counter` (#006A)
// est incrémenté par la boucle elle-même : il compte des frames de LOGIQUE.
// Une passe dure donc ce que coûte son travail (40 dispatches d'entités +
// cull + rendu par rectangles sales), régulée seulement par une
// contre-réaction (fn_render_workload_pacing_delay #0618, `B = 6 - charge`)
// qui ralentit les frames légères sans accélérer les lourdes.
//
// Conséquence : le jeu d'origine ralentit dans les salles chargées. C'est un
// comportement réel, mais une CONTRAINTE MATÉRIELLE, pas une intention de
// game design -- décision 2026-09-04 de ne pas le reproduire.
//
// La cadence ci-dessous est donc un ÉCART ASSUMÉ (voir web/DEVIATIONS.md),
// et le seul de tout le portage dont le fait de référence soit « le jeu n'en
// a pas » plutôt qu'une adresse ROM.
//
// RÉGLÉE À 25 Hz (2026-09-05, jugé « un peu rapide » à 50). Les vitesses
// tirées de la ROM sont exprimées en unités PAR TICK -- pas du joueur de ±3
// (tbl_player_forward_vector_dispatch #22E4), pas du garde de ±2
// (fn_resolve_patrol_vector #12A5), une phase de marche par tick de
// déplacement -- donc baisser la cadence les ralentit toutes ensemble, dans le
// même rapport, sans toucher à une seule d'entre elles.
//
// Ce qui NE doit pas suivre : la gravité et la vitesse de saut. Ce sont les
// deux seules grandeurs du portage qui ne viennent pas de la ROM (le saut n'est
// pas désassemblé, voir web/DEVIATIONS.md) et elles sont réglées en TEMPS RÉEL,
// pas en ticks. Elles sont donc dérivées de TICK_HZ dans scene/player.ts plutôt
// que réécrites à la main : la hauteur de saut en unités de grille -- qui, elle,
// est du gameplay, il faut pouvoir monter sur un bloc à +0x0C -- reste alors
// identique quelle que soit la cadence. C'est la seule dépendance à cette
// constante en dehors de la boucle ; changer 25 ici suffit.
export const TICK_HZ = 25;
export const TICK_SECONDS = 1 / TICK_HZ;

// Plafond de rattrapage : après un onglet en arrière-plan ou un à-coup, on
// rejoue au plus ce nombre de ticks pour la frame écoulée, plutôt que de
// tenter de rattraper des minutes de retard d'un coup (spirale de la mort).
// Le temps en trop est abandonné, pas accumulé.
const MAX_TICKS_PER_FRAME = 5;

/** Accumulateur de pas fixe : convertit un temps réel écoulé en un nombre
 * entier de ticks de logique. */
export class TickAccumulator {
  private carry = 0;

  /** Nombre de ticks à jouer pour `dtSeconds` de temps réel. */
  take(dtSeconds: number): number {
    this.carry += dtSeconds;
    let ticks = 0;
    while (this.carry >= TICK_SECONDS && ticks < MAX_TICKS_PER_FRAME) {
      this.carry -= TICK_SECONDS;
      ticks++;
    }
    if (this.carry > TICK_SECONDS * MAX_TICKS_PER_FRAME) this.carry = 0;
    return ticks;
  }
}
