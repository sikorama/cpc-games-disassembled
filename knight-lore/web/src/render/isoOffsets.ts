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
// CORRESPONDANCE TYPE -> ENTRÉE : complétée le 2026-09-04 en suivant, pour
// chaque type, `tbl_entity_logic_dispatch` (#0676) jusqu'à sa routine de
// logique, dont le `CALL`/`JP` de tête vise l'un de ces stubs. Avant ça, 32
// des 56 types présents dans les salles n'avaient AUCUNE entrée et
// retombaient silencieusement sur [0,0] -- 1053 instances mal placées,
// dont les 290 plaques à pics (0x17) et les 324 segments de mur (0x80)
// signalés par l'utilisateur.
//
// Trois types ne passent PAS par un stub : les montants de porte, qui
// portent leur valeur en clair et la choisissent selon l'orientation, et
// l'icône de chaudron 0x8E. Voir plus bas.
//
// Recoupement : les valeurs des montants de porte dérivées du désassemblage
// coïncident EXACTEMENT avec celles relevées en RAM live le 2026-08-14 --
// deux méthodes indépendantes, même résultat.
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


// --- Les 13 stubs de fn_static_calib_vector_table (#1D7F..#1DBC) -------------
// Nommés par leur adresse ROM : c'est ce qui rend chaque ligne du tableau
// ci-dessous vérifiable sans quitter le fichier.
const S_1D7F = offset(248, 254); // (-8,-2)
const S_1D84 = offset(244, 252); // (-12,-4)
const S_1D89 = offset(244, 250); // (-12,-6)
const S_1D8F = offset(240, 248); // (-16,-8)
const S_1D94 = offset(236, 255); // (-20,-1)
const S_1D99 = offset(244, 254); // (-12,-2)
const S_1D9E = offset(248, 252); // (-8,-4)
const S_1DA3 = offset(244, 248); // (-12,-8)
const S_1DA8 = offset(244, 249); // (-12,-7)
const S_1DAD = offset(244, 244); // (-12,-12)
const S_1DB2 = offset(240, 244); // (-16,-12)
const S_1DB7 = offset(244, 7); //  (-12,+7)
const S_1DBC = offset(244, 3); //  (-12,+3)

// --- Types dont la calibration NE PASSE PAS par un stub ---------------------

// Montants de porte : `fn_door_post_type_A` (#1FFC) et `fn_door_post_type_B`
// (#1FE2) chargent HL en clair puis rejoignent la queue d'écriture commune
// #1FEB. Le choix dépend du bit6 de `off_flags`
// (asm/code/doors_and_player_logic.asm:15-16 et :44-45), et pour le type A
// aussi du type lui-même (`cp #04`, :46-48).
const DOOR_A_DEFAULT = offset(249, 253); //  0x02, bit6=0 -> (-7,-3)
const DOOR_A_ORIENTED = offset(239, 254); // 0x02/0x04, bit6=1 -> (-17,-2)
const DOOR_A_FOREST_DEFAULT = offset(1, 253); // 0x04, bit6=0 -> (+1,-3)
const DOOR_B_DEFAULT = offset(247, 253); //  0x03/0x05, bit6=0 -> (-9,-3)
const DOOR_B_ORIENTED = offset(249, 254); // 0x03/0x05, bit6=1 -> (-7,-2)

// Icône de chaudron (0x8E) : `fn_cauldron_icon_logic` (#127A) charge une
// valeur qui n'est aucun des 13 stubs
// (asm/code/entity_logic_mechanical.asm:518).
const CAULDRON_ICON_OFFSET = offset(232, 12); // (-24,+12)

const FLAG_ORIENTATION_BIT = 0x40;

// --- Correspondance type -> stub -------------------------------------------

const BY_TYPE = new Map<number, [number, number]>();
function put(types: readonly number[], value: [number, number]): void {
  for (const t of types) BY_TYPE.set(t, value);
}
function range(lo: number, hi: number): number[] {
  const out: number[] = [];
  for (let t = lo; t <= hi; t++) out.push(t);
  return out;
}

// Décor statique : blocs (0x06/0x07) et murs. Pour 0x06/0x07/0x0A-0x0F et
// 0x80, l'entrée de dispatch EST le stub -- ces entités n'ont aucune logique
// par frame, elles ne font que se recalibrer.
put([0x06, 0x07], S_1D8F);
put([0x0a], S_1D94);
put([0x0b], S_1D99);
put(range(0x0c, 0x0f), S_1D9E);
put([0x80], S_1D7F); // segment de mur -- le type le plus fréquent du jeu

// Herse (0x08) et grille mobile (0x09).
put([0x08, 0x09], S_1D89);

// Joueur, jour : jambes puis corps. 0x16/0x17 ne sont PAS des jambes (statue
// de crapaud, tapis à clous) -- ils occupent les slots 6/7 de la plage.
put([...range(0x10, 0x15), ...range(0x18, 0x1d)], S_1D89);
put(range(0x20, 0x2f), S_1DA3);

// Joueur, nuit (loup-garou) : MÊME structure, décalée de +0x20 -- et la même
// exception aux slots 6/7, occupés par les blocs mobiles 0x36/0x37. C'est ce
// qui explique la contradiction apparente relevée le 2026-09-04 : la plage
// 0x30-0x3D n'est pas homogène, les deux lectures étaient justes.
put([...range(0x30, 0x35), ...range(0x38, 0x3d)], S_1DA8);
put(range(0x40, 0x4f), S_1DAD);

// Statue de crapaud, tapis à clous, boule à pics au plafond.
put([0x16], S_1DA8);
put([0x17], S_1D8F);
put([0x3f], S_1D8F);

// Famille du petit bloc 0x59DB : mobile, poussable, s'enfonce, dormant --
// tous sur la calibration du bloc statique, comme leur sprite.
put([0x36, 0x37, 0x3e, 0x5b, 0x8f], S_1D8F);
// Table poussable et coffre glissant : même calibration.
put([0x54, 0x55], S_1D8F);

// Fantômes.
put(range(0x50, 0x53), S_1D89);
// Variante de pointes (0x56).
put([0x56], S_1D9E);
// Étapes de transformation du joueur.
put(range(0x5c, 0x5f), S_1D99);
// Les 16 images de la (dé)matérialisation du joueur -- celles de la mort et du
// lancement de partie. Les CINQ routines qui animent cette plage appellent le
// même stub, vérifié octet par octet : #17A7, #17BC, #17D6, #17DC et #17FC
// font toutes `call #1D84`. La plage est donc homogène, sans le trou aux
// slots 6/7 qu'ont les familles de marche (ce ne sont pas des phases
// d'animation encodées dans les bits bas, mais 16 images consécutives).
put(range(0x70, 0x7f), S_1D84);
// Objets ramassables. 0x67 (vie bonus) a sa propre routine et son propre stub.
put(range(0x60, 0x66), S_1D84);
put([0x67], S_1D7F);

// Chaudron.
put([0x8d], S_1DB2);

// Chevalier / Melkhior : corps, jambes, et la variante ALT des jambes
// (0x96/0x97 passent par fn_guard_legs_logic_alt -> #1DB7, 13 px plus bas).
put([0x1e, 0x1f, 0x9e, 0x9f], S_1DBC);
put([...range(0x90, 0x95), ...range(0x98, 0x9d)], S_1D89);
put([0x96, 0x97], S_1DB7);

// Pousseur.
put(range(0xa4, 0xa7), S_1D84);
// Balle rebondissante, feu follet, balle qui traque/fuit.
put([0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7], S_1D9E);

// Icône de chaudron -- valeur en clair, pas un stub.
put([0x8e], CAULDRON_ICON_OFFSET);

/**
 * Renvoie [offsetX, offsetY] pour un type/flags d'entité, ou `null` si le type
 * n'a pas de calibration connue.
 *
 * `null` ne veut plus dire « pas encore extrait » : la correspondance est
 * complète pour les 188 types de `tbl_entity_logic_dispatch` (#00-#BB)
 * rencontrés en salle. Un `null` signale donc soit un type hors table
 * (0xBC-0xBF n'ont AUCUNE entrée de dispatch -- la table s'arrête à 0xBB),
 * soit un type réellement inconnu qui mérite une investigation. Les appelants
 * doivent le signaler, pas l'avaler en silence : c'est ce silence qui a laissé
 * 1053 entités mal placées pendant des semaines.
 */
export function getProjOffset(type: number, flags: number): [number, number] | null {
  const oriented = (flags & FLAG_ORIENTATION_BIT) !== 0;
  switch (type) {
    case 0x02:
      return oriented ? DOOR_A_ORIENTED : DOOR_A_DEFAULT;
    case 0x04:
      return oriented ? DOOR_A_ORIENTED : DOOR_A_FOREST_DEFAULT;
    case 0x03:
    case 0x05:
      return oriented ? DOOR_B_ORIENTED : DOOR_B_DEFAULT;
    default:
      return BY_TYPE.get(type) ?? null;
  }
}
