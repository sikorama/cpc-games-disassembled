// Constantes de calibration de projection (proj_offset_x/proj_offset_y,
// voir docs/RENDERING_PIPELINE.md §5).
//
// SOURCE REMONTÉE À LA ROM (2026-08-15) : ces valeurs venaient d'une lecture
// RAM live (2026-08-14), utile mais forcément partielle -- elles sont
// maintenant retrouvées UNE PAR UNE dans la table de calibration statique du
// jeu, `fn_static_calib_vector_table` (asm/code/objects_and_rooms_setup.asm:95,
// #1D7F..#1DBC) : 13 mini-routines `LD HL,nn / JR #1D8C` dont la queue commune
// écrit L dans proj_offset_x et H dans proj_offset_y (#1FEB, partagée avec les
// montants de porte). Chaque valeur lue en direct correspond exactement à une
// entrée -- les deux méthodes se confirment mutuellement.
//
//   #1D7F (-8,-2)   #1D84 (-12,-4)  #1D89 (-12,-6)  #1D8F (-16,-8)
//   #1D94 (-20,-1)  #1D99 (-12,-2)  #1D9E (-8,-4)   #1DA3 (-12,-8)
//   #1DA8 (-12,-7)  #1DAD (-12,-12) #1DB2 (-16,-12) #1DB7 (-12,+7)
//   #1DBC (-12,+3)
//
// La table entière est donc connue ; ce qui reste incomplet, c'est la
// correspondance type d'entité -> entrée, qui demande de suivre le dispatch de
// chaque type (voir getProjOffset). Les types non couverts retombent sur
// [0,0] plutôt que sur une valeur inventée.
//
// À noter : proj_offset_x vaut exactement -largeur/2 pour tous les types
// centrés sur leur case -- c'est une des preuves que l'ancre du sprite est son
// coin haut-gauche (voir render/isoMath.ts).
//
// Les octets sont des entiers SIGNÉS (petits ajustements).

function signed8(byte: number): number {
  return byte >= 128 ? byte - 256 : byte;
}

function offset(x: number, y: number): [number, number] {
  return [signed8(x), signed8(y)];
}

// Blocs statiques et famille partageant sa calibration (0x07/0x36/0x37/
// 0x3E/0x5B/0x8F, voir docs/SYMBOLS.md) -- entrée ROM #1D8F, confirmée en
// direct (slots 21-36, salle 0x00) quel que soit `flags`.
const BLOCK_OFFSET = offset(240, 248);

// Murs -- entrées ROM #1D94 / #1D99 / #1D9E. Confirmé en direct (salle 0x00) :
// 0x0A et 0x0B ont chacun leur PROPRE calibration, 0x0C/0x0D/0x0E/0x0F
// PARTAGENT la même (contrairement au groupement "0x0A/0x0D, 0x0B/0x0E,
// 0x0C/0x0F" qu'on aurait déduit du désassemblage statique).
const WALL_A_OFFSET = offset(236, 255);
const WALL_B_OFFSET = offset(244, 254);
const WALL_CDEF_OFFSET = offset(248, 252);

// Montants de porte -- calibration dépendante de l'ORIENTATION (bit6 de
// off_flags), confirmé en direct (salle 0x00, 4 instances, 2 orientations
// par type) :
const DOOR_A_DEFAULT = offset(249, 253); // flags bit6=0 (slot 6, salle 0x00)
const DOOR_A_ORIENTED = offset(239, 254); // flags bit6=1 (slot 4, salle 0x00)
const DOOR_B_DEFAULT = offset(247, 253); // flags bit6=0 (slot 7, salle 0x00)
const DOOR_B_ORIENTED = offset(249, 254); // flags bit6=1 (slot 5, salle 0x00)

// Statue de crapaud (0x16) -- entrée ROM #1DA8, confirmée en direct
// (salle 0x01, 4 instances).
const TOAD_STATUE_OFFSET = offset(244, 249);

// Boule à pics au plafond (0x3F) -- confirmé en direct (salle 0x03, 4
// instances) : même valeur que les blocs, donc entrée ROM #1D8F. À
// re-vérifier visuellement : c'est un objet SUSPENDU, donc un de ceux que le
// bug d'axe vertical décalait le plus (voir render/isoMath.ts).
const CEILING_SPIKE_BALL_OFFSET = offset(240, 248);

// Personnages (chevalier 0x1E, Melkhior 0x9E qui réutilise la même
// logique/calibration, voir docs/SYMBOLS.md) -- entrée ROM #1DBC, atteinte via
// le `call #1DBC` en tête de fn_guard_patrol_logic
// (asm/code/entity_logic_mechanical.asm:527).
//
// Le `+3` (vers le BAS) surprend pour un "corps" et avait fait soupçonner une
// valeur mal relevée -- la ROM tranche : elle est juste. Avec les deux moitiés
// (#1DBC à +3, hauteur 23 ; #1D89 à -6, hauteur 16) la figure occupe 32 px
// d'un seul tenant, avec 7 px de recouvrement -- cohérente. C'est donc bien le
// LABEL qui est trompeur (la moitié dite "corps" est la partie BASSE), pas la
// calibration. "Le haut du corps à la place des pieds" (signalé par
// l'utilisateur) venait du retournement vertical de la scène, qui inversait
// l'empilement des deux moitiés.
const GUARD_OR_WIZARD_BODY_OFFSET = offset(244, 3);

// Autre moitié du chevalier/Melkhior (famille 0x90-0x9D, asset générique
// partagé -- voir docs/SYMBOLS.md) -- entrée ROM #1D89, atteinte via le
// `call #1D89` en tête de fn_guard_legs_logic
// (asm/code/entity_logic_mechanical.asm:15). Confirmée en direct (salle 0x2E).
const GUARD_LEGS_OFFSET = offset(244, 250);

// Moitié BASSE du joueur (jambes, 0x10-0x1D) -- entrée ROM #1D89, la MÊME
// que celle du garde (`call #1D89` en tête de fn_player_logic,
// asm/code/doors_and_player_logic.asm:184). Attendu, puisque les deux
// plages pointent aussi vers les mêmes sprites (feet1-8), mais confirmé
// par le désassemblage, pas supposé.
const PLAYER_LEGS_OFFSET = offset(244, 250);

// Moitié HAUTE du joueur (corps, 0x20-0x2F) -- entrée ROM #1DA3, via le
// `call #1DA3` en tête de fn_entity_materialize_dispatch_a
// (asm/code/doors_and_player_logic.asm:1312). Noter que le corps du joueur
// et celui du garde n'ont PAS la même calibration (#1DA3 contre #1DBC) :
// ce sont deux personnages différents, seules les jambes sont partagées.
const PLAYER_BODY_OFFSET = offset(244, 248);

// Joueur de NUIT (loup-garou) -- NON AJOUTÉ ICI, et pas par oubli.
//
// La lecture de la table de dispatch de logique donne jambes 0x30-0x3D via
// #20D0 fn_player_logic_night (-> #1DA8) et corps 0x40-0x4F via #268E
// fn_entity_materialize_dispatch_b (-> #1DAD). Mais 0x36/0x37 sont déjà
// documentés ailleurs comme des BLOCS MOBILES partageant le sprite du
// petit bloc 0x59DB (docs/SYMBOLS.md:320, tools/room_map/teleport.py), et
// mappés sur BLOCK_OFFSET ci-dessus. Un octet de type ne peut pas être les
// deux : une des deux lectures est fausse, et ce n'est pas tranché.
// À régler avec le chantier jour/nuit (voir web/DEVIATIONS.md).

// Variante ALT des jambes de garde (0x96/0x97 seulement) -- ces deux types
// dispatchent vers #1027 fn_guard_legs_logic_alt, qui appelle #1DB7 et NON
// #1D89 (asm/code/entity_logic_mechanical.asm:73). 13 px d'écart vertical
// avec les autres jambes : ils étaient repliés à tort sur GUARD_LEGS_OFFSET
// ici avant 2026-09-04.
const GUARD_LEGS_ALT_OFFSET = offset(244, 7);

const FLAG_ORIENTATION_BIT = 0x40;

/**
 * Renvoie [offsetX, offsetY] pour un type/flags d'entité, ou null si la
 * calibration de ce type n'a pas encore été désassemblée (voir le
 * plan -- extraction volontairement limitée aux types déjà rencontrés
 * en salle 0x00/0x8D plutôt qu'exhaustive dès cette étape).
 */
export function getProjOffset(type: number, flags: number): [number, number] | null {
  const oriented = (flags & FLAG_ORIENTATION_BIT) !== 0;
  switch (type) {
    case 0x07:
    case 0x36:
    case 0x37:
    case 0x3e:
    case 0x5b:
    case 0x8f:
      return BLOCK_OFFSET;
    case 0x0a:
      return WALL_A_OFFSET;
    case 0x0b:
      return WALL_B_OFFSET;
    case 0x0c:
    case 0x0d:
    case 0x0e:
    case 0x0f:
      return WALL_CDEF_OFFSET;
    case 0x02:
      return oriented ? DOOR_A_ORIENTED : DOOR_A_DEFAULT;
    case 0x03:
      return oriented ? DOOR_B_ORIENTED : DOOR_B_DEFAULT;
    case 0x16:
      return TOAD_STATUE_OFFSET;
    case 0x3f:
      return CEILING_SPIKE_BALL_OFFSET;
    case 0x1e:
    case 0x1f:
    case 0x9e:
    case 0x9f:
      return GUARD_OR_WIZARD_BODY_OFFSET;
    case 0x90:
    case 0x91:
    case 0x92:
    case 0x93:
    case 0x94:
    case 0x95:
    case 0x98:
    case 0x99:
    case 0x9a:
    case 0x9b:
    case 0x9c:
    case 0x9d:
      return GUARD_LEGS_OFFSET;
    case 0x96:
    case 0x97:
      return GUARD_LEGS_ALT_OFFSET;
    case 0x10:
    case 0x11:
    case 0x12:
    case 0x13:
    case 0x14:
    case 0x15:
    case 0x18:
    case 0x19:
    case 0x1a:
    case 0x1b:
    case 0x1c:
    case 0x1d:
      return PLAYER_LEGS_OFFSET;
    case 0x20:
    case 0x21:
    case 0x22:
    case 0x23:
    case 0x24:
    case 0x25:
    case 0x26:
    case 0x27:
    case 0x28:
    case 0x29:
    case 0x2a:
    case 0x2b:
    case 0x2c:
    case 0x2d:
    case 0x2e:
    case 0x2f:
      return PLAYER_BODY_OFFSET;
    default:
      return null;
  }
}
