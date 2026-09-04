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
 * comme un bloc statique en attendant (pousser, enfoncer, glisser : un
 * chantier de gameplay séparé). Volontairement plus large que la
 * classification cartographique. */
const SOLID_WITH_PENDING_BEHAVIOR = new Set<number>([
  0x16, // statue de crapaud
  0x36, // bloc mobile A
  0x37, // bloc mobile B
  0x3e, // bloc poussable
  0x54, // table poussable (s'arrete net a la fin du contact)
  0x55, // coffre glissant (continue apres la poussee)
  0x5b, // cube qui s'enfonce
  0x8f, // bloc dormant
]);

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
