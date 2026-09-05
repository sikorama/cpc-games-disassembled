// Solidité physique par TYPE d'entité ROM -- politique du PORTAGE, pas une
// donnée extraite.
//
// Pourquoi ici et pas dans le manifest : cette classification est une
// décision de gameplay, et la table `DECOR_TYPES` de
// tools/room_map/teleport.py (dont elle a été extraite le 2026-09-04) est
// une classification CARTOGRAPHIQUE -- « quoi masquer pour produire une
// carte lisible ». Réutiliser la seconde comme source de vérité pour la
// première a produit le bug « certains cubes visuellement identiques
// traversent, d'autres pas ». Les deux ne doivent jamais être refondues :
// l'outil exporte des faits observés (type, position, bbox), le portage
// décide des règles.
//
// Deuxième raison, décisive à terme : les types à comportement dynamique
// ci-dessous auront une solidité VARIABLE DANS LE TEMPS (un cube qui
// s'enfonce, un bloc poussé) -- ce qu'un booléen figé dans un JSON généré
// ne pourra jamais porter, et qui exigeait sinon de relancer l'émulateur
// pour changer une règle de jeu.
//
// FAMILLE DE SPRITE (voir web/CONTEXT.md) : plusieurs types ROM distincts
// partagent le même graphisme -- ex. sprite_small_block_59DB est utilisé
// par 0x07 (bloc statique), 0x36/0x37 (mobile), 0x3E (poussable), 0x5B
// (s'enfonce) et 0x8F (dormant). Classer la solidité par SPRITE serait
// donc faux : c'est le type qui porte le comportement.

/** Murs de bord de salle et décor statique (identique à `DECOR_TYPES` côté
 * outil, d'où la classification vient) : 0x80, 0x0A-0x0F, 0x06, 0x07. */
const STATIC_DECOR = new Set<number>([0x80, 0x06, 0x07, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f]);

/** Types solides à comportement dynamique PAS ENCORE IMPLÉMENTÉ -- traités
 * comme un bloc statique en attendant. Volontairement plus large que la
 * classification cartographique.
 *
 * AUCUN de ces types n'est poussable (bit 2 de `flags` absent sur toutes leurs
 * instances des 128 salles -- voir plus bas) : leur comportement est autonome,
 * pas une réaction au joueur.
 *
 * 0x8F (bloc dormant) mérite une mention : ce n'est PAS une dette. Sa logique
 * (`fn_dormant_block_transform` #0F84) le laisse indiscernable d'un bloc
 * statique tant que le bit 3 de `state_flags_2` n'est pas posé, et une fois
 * déclenché il devient 0xB8 puis 0xB9, dont la logique retombe en idle
 * statique. Un bloc solide immobile est donc la simulation FIDÈLE de 0x8F,
 * pas un pis-aller.
 *
 * Les types poussables (0x3E/0x54/0x55) ne sont plus ici : ce sont désormais
 * des corps mobiles vivants (scene/pushables.ts), qui fournissent eux-mêmes
 * leur obstacle à leur position courante. Les laisser aussi dans la liste
 * statique les figerait à leur position de départ. */
const SOLID_WITH_PENDING_BEHAVIOR = new Set<number>([
  0x16, // statue de crapaud
  0x8f, // bloc dormant -- voir ci-dessus, fidèle en l'état
]);

// RETIRÉS de cette liste le 2026-09-05, parce qu'ils ne sont plus « en
// attente » : 0x36/0x37 (blocs mobiles, un axe chacun) et 0x5B (cube qui
// s'enfonce) sont désormais des corps VIVANTS, gérés par
// scene/autonomousBlocks.ts, qui fournissent leur obstacle à leur position
// courante. Les laisser ici les figerait à leur position de départ -- le même
// piège que pour les corps poussables.

// EXCLUS volontairement, et pourquoi :
// - dangers qui ne bloquent pas le déplacement dans l'original : pointes au
//   sol (0x17, au ras du sol, on marche dessus), boule à pointes au plafond
//   (0x3F, on passe dessous) ;
// - personnages et dangers mobiles avec leur propre IA : fantôme
//   (0x50-0x53), feu follet (0xB4/0xB5), balle rebondissante (0xB2/0xB3),
//   pousseur (0xA4-0xA7), sorcier/chaudron (0x8D/0x8E) -- chantiers
//   gameplay/IA, pas de la collision statique ;
// - montants de porte (0x02/0x03) : traversables pour l'instant. La HAUTEUR
//   de porte (ne pas pouvoir sauter par-dessus une porte basse) reste à
//   traiter.
//
// À AUDITER à chaque nouveau type de bloc rencontré -- cette liste n'est pas
// supposée exhaustive par défaut. Dernier audit : 2026-09-04, contre tous
// les types effectivement observés dans les 128 salles.

/** `true` si ce type d'entité doit être un obstacle solide (voir
 * physics/obstacles.ts). */
export function isSolidType(type: number): boolean {
  return STATIC_DECOR.has(type) || SOLID_WITH_PENDING_BEHAVIOR.has(type);
}

// ---------------------------------------------------------------------------
// POUSSÉE
// ---------------------------------------------------------------------------
//
// FAIT ROM CENTRAL (désassemblage 2026-09-04) : « poussable » N'EST PAS UNE
// PROPRIÉTÉ DE TYPE. C'est le BIT 2 DE `flags` (+0x07) de l'INSTANCE.
// `fn_entity_collide_axis_x` (#244C) et `fn_entity_collide_axis_y` (#249B,
// asm/code/doors_and_player_logic.asm:895-936 et :946-990) font, une fois le
// blocage constaté :
//
//     bit  2,(iy+off_flags)      ; l'entité HEURTÉE est-elle poussable ?
//     jr   z,...
//     ld   a,(ix+#09)            ; vecteur en attente du MOBILE
//     ld   (iy+#09),a            ; ... recopié dans celui de la heurtée
//
// Le mobile, lui, est quand même arrêté (fn_step_toward_zero réduit son
// propre delta jusqu'à ce qu'il tienne) : le pousseur ne traverse pas, il
// reste d'un tick derrière l'objet poussé. C'est le ressenti d'origine.
//
// Le vecteur recopié est `(ix+09)`, l'octet de la STRUCTURE, pas le registre
// de travail déjà rogné -- il n'est réécrit qu'à la toute fin
// (`fn_entity_movement_vector_resolve` #23F7, loc_243E). L'objet poussé reçoit
// donc le pas ENTIER (±3), pas le reliquat.
//
// VÉRIFIÉ SUR LES DONNÉES, pas seulement sur le code : dans les 128 salles du
// manifest, le bit 2 de `flags` est posé sur exactement 0x3E, 0x54, 0x55,
// 0x60-0x67 (objets ramassables) et les types de personnage -- et sur AUCUNE
// instance de 0x07, 0x16, 0x36, 0x37, 0x5B, 0x8F. Les quatre derniers, qu'on
// croyait « blocs dynamiques poussables », ne sont donc pas poussables du
// tout : ils ont leur propre logique autonome (voir web/DEVIATIONS.md).

/** Bit 2 de `flags` (+0x07) : l'entité reçoit le vecteur de déplacement de ce
 * qui la heurte. Seule et unique condition de poussée dans la ROM. */
export const FLAG_PUSHABLE = 0x04;

/**
 * Ce qu'une entité poussée fait de son vecteur autour de l'application du
 * déplacement (`RST 10`). Les trois routines de logique ne diffèrent QUE par
 * la place du `CALL #22A5` (`xor a / ld (ix+09),a / ld (ix+0A),a` -- remise à
 * zéro du vecteur en attente) autour de ce `RST 10`. Octets relus directement
 * dans `extra/dump_ref.bin` pour lever tout doute de transcription.
 *
 * - `"apply-then-clear"` -- `fn_pushable_table_logic` (#1D71, type 0x54) :
 *   `RST 10` puis `CALL #22A5`. La table avance du pas reçu ce tick puis oublie
 *   son vecteur : elle s'arrête net dès que le contact cesse.
 * - `"apply-and-keep"` -- `fn_sliding_chest_logic` (#1D66, type 0x55) : `RST 10`
 *   sans le `CALL #22A5`. Le vecteur persiste, le coffre continue de glisser
 *   après la poussée jusqu'au premier obstacle (confirmé empiriquement salle
 *   0x6C : poussé sur 46 unités jusqu'au mur, puis parfaitement stable).
 * - `"clear-then-apply"` -- `fn_pushable_block_logic` (#1D53, type 0x3E) :
 *   `CALL #22A5` AVANT le `RST 10`. Voir ci-dessous.
 *
 * ANOMALIE 0x3E, ASSUMÉE TELLE QUELLE : l'ordre inverse rend le bloc IMMOBILE.
 * Le joueur est le slot 0 de la table d'entités et `fn_main_loop` dispatche les
 * slots en ordre CROISSANT (#05AE, `add ix,#001C`,
 * asm/code/low_ram_and_boot.asm:224-252) -- la poussée est donc écrite dans le
 * bloc AVANT que le bloc ne joue son tick, et son `CALL #22A5` l'efface dans le
 * même tick, avant de l'appliquer. Le bloc porte le bit poussable, reçoit le
 * vecteur, et ne bouge pas.
 *
 * On ne « corrige » pas : la politique est encodée telle que la ROM la décrit,
 * et l'immobilité de 0x3E en est une CONSÉQUENCE, pas une décision. Si une
 * trace live prouve un jour le contraire, c'est une valeur d'énumération à
 * changer ici, rien d'autre. (La note d'origine,
 * `notes/2026-08-07-room-bb-diamond-and-pushable-block.md`, lisait ce `CALL
 * #22A5` comme « exactement le même appel que 0x54 » sans relever qu'il tombe
 * de l'autre côté du `RST 10` -- et aucune poussée de 0x3E n'y a jamais été
 * observée en jeu, seulement le sprite.)
 */
export type PushPolicy = "apply-then-clear" | "apply-and-keep" | "clear-then-apply";

const PUSH_POLICY_BY_TYPE = new Map<number, PushPolicy>([
  [0x3e, "clear-then-apply"], // bloc poussable  -- fn_pushable_block_logic #1D53
  [0x54, "apply-then-clear"], // table poussable -- fn_pushable_table_logic #1D71
  [0x55, "apply-and-keep"], //  coffre glissant -- fn_sliding_chest_logic  #1D66
]);

/**
 * Politique de vecteur d'une entité, ou `null` si elle n'est pas un corps
 * mobile du portage.
 *
 * Les DEUX conditions comptent, et pour des raisons différentes : le bit de
 * `flags` dit si la ROM lui envoie une poussée (fait d'instance), la table de
 * types dit ce que sa routine de logique en fait (fait de code). Un type
 * poussable dont la logique n'est pas désassemblée n'a rien à faire ici -- il
 * reste un obstacle statique, ce qui est l'état actuel et un état honnête.
 *
 * Les objets ramassables 0x60-0x67 portent eux aussi le bit (leur logique est
 * `fn_crystal_ball_logic`, une routine différente) : ils sont volontairement
 * absents de la table, le ramassage étant un chantier séparé.
 */
export function pushPolicyFor(type: number, flags: number): PushPolicy | null {
  if ((flags & FLAG_PUSHABLE) === 0) return null;
  return PUSH_POLICY_BY_TYPE.get(type) ?? null;
}
