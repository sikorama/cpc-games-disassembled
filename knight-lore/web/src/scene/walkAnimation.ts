// Compteur de phase du cycle de marche, partagé joueur / garde.
//
// CONFIRMÉ (fn_player_walk_animation_cycle #2214,
// asm/code/doors_and_player_logic.asm:493-503) : le cycle vit dans les 3
// BITS BAS DE L'OCTET DE TYPE de l'entité, et compte 0..5 --
// `inc a / and #07 / cp #06 / jr nz / xor a`. Les valeurs 6 et 7 sont donc
// inatteignables par ce cycle.
//
// Il n'y a PAS de tableau d'ordre à tenir ici : l'aller-retour est déjà
// dans tbl_sprite_dispatch. Les 6 phases des jambes pointent vers
// feet1,2,3,4,3,2 (types 0x10-0x15) et celles du corps vers
// hero_up9,10,8,4,8,10 (0x20-0x25) -- 4 dessins parcourus en ping-pong,
// encodés dans la table elle-même. Indexer la table par le type suffit.
//
// fn_guard_legs_logic (#0FD8) appelle le MÊME recycleur (`call #2231`,
// asm/code/entity_logic_mechanical.asm:36) : garde et joueur partagent la
// mécanique entière, pas seulement les sprites.
export const WALK_PHASE_COUNT = 6;

// DETTE (voir web/DEVIATIONS.md) : l'original n'a pas de durée en
// secondes -- il avance d'une phase par FRAME DE LOGIQUE, sur la cadence
// fixe du CPC. Cette constante est un pis-aller en attendant la conversion
// du portage en pas fixe ; elle disparaîtra alors.
export const WALK_FRAME_DURATION = 0.12;

export interface WalkAnimState {
  phase: number;
  timer: number;
}

export function createWalkAnimState(): WalkAnimState {
  return { phase: 0, timer: 0 };
}

/**
 * Avance le cycle seulement si `moving`.
 *
 * À l'arrêt on CONSERVE la phase courante -- le personnage gèle au milieu
 * de sa foulée. C'est le comportement de l'original : le cycle n'avance
 * que si le bit « avance » est posé (doors_and_player_logic.asm:478-480),
 * et il n'existe AUCUNE pose de repos dans la ROM. Les slots 6/7 de chaque
 * groupe (0x26/0x27, 0x2E/0x2F) ne sont pas des poses immobiles : ce sont
 * des poses alternatives rares tirées au hasard par
 * fn_entity_materialize_pick_subtype (#26C3) et tenues 8 frames -- pas
 * encore implémentées (dette). Les jambes n'ont même pas de slot 6/7 :
 * 0x16/0x17 sont la statue de crapaud et le tapis à clous.
 */
export function advanceWalkAnim(state: WalkAnimState, moving: boolean, dt: number): void {
  if (!moving) {
    state.timer = 0;
    return;
  }
  state.timer += dt;
  while (state.timer >= WALK_FRAME_DURATION) {
    state.timer -= WALK_FRAME_DURATION;
    state.phase = (state.phase + 1) % WALK_PHASE_COUNT;
  }
}
