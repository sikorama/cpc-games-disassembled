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
// a pas » plutôt qu'une adresse ROM. Une seule constante à changer si le jeu
// paraît trop rapide : 50 -> 25.
export const TICK_HZ = 50;
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
