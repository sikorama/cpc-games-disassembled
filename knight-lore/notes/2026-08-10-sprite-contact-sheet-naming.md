# Session 2026-08-10 — Nomenclature officielle des sprites (planche de contact)

## Contexte

L'utilisateur a extrait et décodé intégralement (ou quasi) le
catalogue de sprites du jeu via `tools/sprite_dump.py`
(`tools/sprite_dump_out/manifest.json`, 103 formes décodées sur 104
pointeurs uniques de `tbl_sprite_dispatch`), puis renommé chaque
fichier PNG en y ajoutant le nom officiel de la forme représentée,
d'après sa propre connaissance du jeu (planche de contact visuelle).
Convention : `sprite_<nom>_<adresse>_w<largeur>_h<hauteur>.png`.

Le manifest associe déjà chaque adresse de forme aux types d'entité
(octet `(ix+00)`) qui la référencent via `tbl_sprite_dispatch`
(0x429E) — ce qui permet de recouper directement nom officiel ↔
type(s) d'entité ↔ statut existant dans `docs/SYMBOLS.md`.

**Note** : la numérotation des noms (`hero_up1`, `feet3`, etc.) suit
l'ordre de découverte/dump de l'utilisateur, PAS l'ordre des adresses
mémoire ni un ordre d'animation garanti — à ne pas sur-interpréter.
Deux coquilles de frappe dans les noms de fichiers d'origine :
`sprite_caludron_down` (chaudron) et `sprite_firebuigs2` (firebugs).

## Table complète adresse ↔ nom ↔ type(s) d'entité

| Adresse forme | Nom sprite (utilisateur) | Types d'entité associés | Largeur | Hauteur |
|---|---|---|---|---|
| 0x4424 | `life` | 67,8C,AF | 16 | 17 |
| 0x446B | `boot` | 62,6A,AA | 24 | 21 |
| 0x44EC | `crystall_ball` | 66,6E,AE | 24 | 21 |
| 0x456D | `bottle` | 65,6D,AD | 24 | 24 |
| 0x4600 | `poison` | 61,69,A9 | 24 | 22 |
| 0x4687 | `ruby` | 60,68,A8 | 24 | 20 |
| 0x4702 | `chalice` | 63,6B,AB | 24 | 24 |
| 0x4795 | `cup` | 64,6C,AC | 24 | 18 |
| 0x4804 | `ghost1` | 50 | 24 | 20 |
| 0x487F | `ghost3` | 51 | 24 | 19 |
| 0x48F4 | `ghost4` | 52 | 24 | 20 |
| 0x496F | `ghost2` | 53 | 24 | 20 |
| 0x49EA | `melkhior_up2` | 9F | 24 | 39 |
| 0x4AD7 | `melkhior_up1` | 9E | 24 | 33 |
| 0x4BA0 | `knight_up1` | 1E,96 | 24 | 23 |
| 0x4C2D | `knight_up2` | 1F,97 | 24 | 23 |
| 0x4CBA | `transform1` | 5C | 24 | 32 |
| 0x4D7D | `transform2` | 5D | 24 | 33 |
| 0x4E46 | `transform3` | 5E | 24 | 38 |
| 0x4F2D | `transform4` | 5F | 24 | 35 |
| 0x5002 | `poltergeist6` | 77,78 | 24 | 20 |
| 0x507D | `poltergeist4` | 76,79 | 24 | 21 |
| 0x50FE | `poltergeist1` | 75,7A | 24 | 23 |
| 0x518B | `poltergeist2` | 74,7B,85,A2,A6 | 24 | 24 |
| 0x521E | `poltergeist5` | 71,73,7C,7E,84,A1,A3,A5,A7,B9 | 24 | 24 |
| 0x52B1 | `poltergeist3` | 6F,70,72,7D,7F,83,A0,A4,B8,BB | 24 | 24 |
| 0x5344 | `caludron_down` (sic, "cauldron") | 8D | 32 | 33 |
| 0x544F | `cauldron_up` | 8E | 32 | 11 |
| 0x54AA | `chest` | 55 | 32 | 29 |
| 0x5595 | `nail_mat` | 17 | 32 | 28 |
| 0x5678 | `wood_block` | 06 | 32 | 29 |
| 0x5763 | `firebugs1` | 56,B0,B4 | 16 | 15 |
| 0x57A2 | `firebuigs2` (sic, "firebugs") | 57,B1,B5 | 16 | 16 |
| 0x57E5 | `hud_day_right` | 5A | 32 | 31 |
| 0x58E0 | `hud_day_left` | BA | 32 | 31 |
| 0x59DB | `small_block` | 07,36,37,3E,5B,8F,BC,BD,BE,BF | 32 | 29 |
| 0x5AC6 | `door2` | 02 | 24 | 52 |
| 0x5C01 | `door1` | 03 | 16 | 35 |
| 0x5C90 | `wall1` | 0D | 16 | 47 |
| 0x5D4F | `wall2` | 0E | 16 | 48 |
| 0x5E12 | `wall3` | 0F | 16 | 48 |
| 0x5ED5 | `wall4` | 0A | 40 | 25 |
| 0x5FD2 | `wall5` | 0B | 24 | 24 |
| 0x6065 | `wall6` | 0C | 24 | 18 |
| 0x60D4 | `wood_wall` | 80 | 16 | 48 |
| 0x6197 | `wood_door2` | 04 | 16 | 59 |
| 0x6286 | `wood_door1` | 05 | 16 | 48 |
| 0x6349 | `hud2` | 86 | 16 | 8 |
| 0x636C | `scroll2` | 88 | 16 | 16 |
| 0x63AF | `hud1` | 87 | 16 | 10 |
| 0x63DA | `menu4` | C0 | 16 | 1 |
| 0x63E1 | `scroll1` | C1 | 16 | 18 |
| 0x642C | `hero_up8` | 22,24 | 24 | 24 |
| 0x64BF | `hero_up3` | 29,2D | 24 | 25 |
| 0x6558 | `hero_up6` | 26 | 24 | 25 |
| 0x65F1 | `hero_up4` | 23 | 24 | 24 |
| 0x6684 | `hero_up9` | 20 | 24 | 24 |
| 0x6717 | `hero_up10` | 21,25 | 24 | 24 |
| 0x67AA | `conkers2` | 58 | 16 | 16 |
| 0x67ED | `sphere` | 59 | 16 | 16 |
| 0x6830 | `hero_up11` | 28 | 24 | 25 |
| 0x68C9 | `hero_up5` | 2B | 24 | 25 |
| 0x6962 | `hero_up12` | 2A,2C | 24 | 25 |
| 0x69FB | `hero_up7` | 27 | 24 | 24 |
| 0x6A8E | `hero_up1` | 2F | 24 | 25 |
| 0x6B27 | `hero_up2` | 2E | 24 | 25 |
| 0x6BC0 | `feet1` | 10,90 | 24 | 16 |
| 0x6C23 | `feet2` | 11,15,91,95 | 24 | 16 |
| 0x6C86 | `feet3` | 12,14,92,94 | 24 | 16 |
| 0x6CE9 | `feet4` | 13,93 | 24 | 16 |
| 0x6D4C | `feet5` | 18,98 | 24 | 17 |
| 0x6DB5 | `feet6` | 19,1D,99,9D | 24 | 17 |
| 0x6E1E | `feet7` | 1A,1C,9A,9C | 24 | 17 |
| 0x6E87 | `feet8` | 1B,9B | 24 | 17 |
| 0x6EF0 | `menu1` | 8B | 8 | 24 |
| 0x6F23 | `menu3` | 8A | 24 | 1 |
| 0x6F2C | `menu2` | 89 | 32 | 30 |
| 0x701F | `werewulf_up6` | 40 | 24 | 29 |
| 0x70D0 | `werewulf1` | 41,45 | 24 | 29 |
| 0x7181 | `werewulf_up2` | 42,44 | 24 | 29 |
| 0x7232 | `werewulf_up8` | 43 | 24 | 29 |
| 0x72E3 | `werewulf_up3` | 4B | 24 | 30 |
| 0x739A | `werewulf_up7` | 4A,4C | 24 | 30 |
| 0x7451 | `werewulf_up9` | 49,4D | 24 | 30 |
| 0x7508 | `werewulf_up10` | 48 | 24 | 30 |
| 0x75BF | `werewulf_up4` | 46 | 24 | 29 |
| 0x7670 | `werewulf_up11` | 47 | 24 | 29 |
| 0x7721 | `werewulf_up12` | 4E | 24 | 30 |
| 0x77D8 | `werewulf_up5` | 4F | 24 | 30 |
| 0x788F | `werewulf_feet8` | 30 | 24 | 16 |
| 0x78F2 | `werewulf_feet6` | 31,35 | 24 | 16 |
| 0x7955 | `werewulf_feet8` (2e occurrence, doublon de nom — probablement `feet9`) | 32,34 | 24 | 16 |
| 0x79B8 | `werewulf_feet7` | 33 | 24 | 16 |
| 0x7A1B | `werewulf_feet1` | 38 | 24 | 18 |
| 0x7A8A | `werewulf_feet2` | 39,3D | 24 | 18 |
| 0x7AF9 | `werewulf_feet4` | 3A,3C | 24 | 18 |
| 0x7B68 | `werewulf_feet5` | 3B | 24 | 18 |
| 0x7BD7 | `herse` | 08,09 | 24 | 42 |
| 0x7CD6 | `table` | 54 | 32 | 28 |
| 0x7DB9 | `frog_status` (probable coquille pour "frog_statue") | 16 | 24 | 24 |
| 0x7E4C | `conkers1` | 3F | 32 | 25 |
| 0x7F17 | `volcanic_bubble2` | B2,B6 | 24 | 19 |
| 0x7F8C | `volcanic_bubble1` | B3,B7 | 24 | 18 |

(Sprite manquant du dump : `sprite_bottle_456D` — présent dans les
fichiers de l'utilisateur mais initialement omis de ma transcription,
recoupé après coup avec le manifest.)

## Enseignements marquants (au-delà de la simple nomenclature)

1. **Catalogue de trésors 0x60-0x67 enfin complet** : rubis (0x60,
   PAS "diamant" comme précédemment nommé — voir
   `notes/2026-08-07-room-bb-diamond-and-pushable-block.md`), poison
   (0x61), botte (0x62), calice (0x63), tasse (0x64), bouteille
   (0x65), boule de cristal (0x66), vie bonus (0x67). Les 4 derniers
   inconnus (0x61/0x62/0x63) sont résolus par simple lecture du nom
   de sprite — cohérent avec la famille "objet ramassable, même
   `fn_crystal_ball_logic`" déjà établie.

2. **Melkhior** — le magicien de la salle 0x88 (`docs/SYMBOLS.md`
   0x9E/0x9F) a un nom officiel : Melkhior. Cohérent avec la
   nomenclature du jeu original (le sorcier qui demande au joueur de
   lui apporter des objets).

3. **Le Chevalier (Knight)** — le "gardien en patrouille" (0x1E,
   `fn_guard_patrol_logic`) est en réalité LE CHEVALIER, l'ennemi
   éponyme du titre "Knight Lore". Renommage à propager dans les
   futurs commentaires ASM si pertinent.

4. **Poltergeist** — la famille visuelle jusqu'ici décrite comme
   "poussoir" (0xA4-0xA7, `fn_pusher_enemy_logic`) partagée avec
   "patrouille hostile non identifiée visuellement" (0x85,
   `fn_hostile_patrol_logic`) a un nom officiel unique : Poltergeist.
   Les mêmes sprites (`sprite_poltergeist1..6`) sont aussi ceux de la
   séquence de (dé)matérialisation du joueur (0x70-0x7F) — réutilisation
   d'assets, pas un lien logique entre les deux mécanismes.

5. **Bulle volcanique (volcanic bubble)** — la "balle rebondissante
   mortelle" (0xB2/0xB3, `fn_bouncing_ball_logic`,
   `notes/2026-08-07-entity-logic-bouncing-ball.md`) et l'"ennemi
   boule chasse/fuite selon forme du joueur" (0xB6/0xB7,
   `fn_ball_chase_flee_logic`) partagent EXACTEMENT le même sprite —
   nom officiel unique "bulle volcanique" pour les deux logiques.
   Auparavant documentées comme deux familles visuelles distinctes.

6. **Firebug** — le "feu follet" (nom donné par l'utilisateur en
   session précédente) a un nom officiel anglais : firebug. S'applique
   aux deux logiques distinctes 0x56/0x57 (`notes/...ghost.md`? non —
   voir `fn_...`, logique 0x10D4) et 0xB4/0xB5
   (`fn_will_o_wisp_logic`, 0x10F4), qui partagent le même sprite.

7. **Mystère résolu : 0x30-0x3D n'est PAS une animation de saut du
   joueur.** L'ancienne hypothèse (`notes/2026-08-07-jump-on-table.md`)
   supposait une famille liée aux phases de saut/déplacement vertical.
   Le sprite (`sprite_werewulf_feet*`) révèle qu'il s'agit en fait des
   jambes du LOUP-GAROU (forme nuit du joueur) — le pendant nocturne
   exact de la famille "jambes" 0x90-0x9D du chevalier (même principe :
   torse et jambes animés séparément). Par symétrie, 0x40-0x4F
   (`sprite_werewulf_up*`) est le torse/corps loup-garou, et 0x20-0x2F
   (`sprite_hero_up*`) le torse/corps héros — le pendant "jambes" du
   héros étant justement 0x10-0x1D (voir point 8 ci-dessous, RÉVISÉ
   après remarque utilisateur : jambes génériques partagées héros/
   chevalier/Melkhior, pas un second chevalier). Aucune de ces plages
   n'était documentée comme telle avant cette session — logique
   interne non désassemblée, piste ouverte.

8. **Découverte structurelle : décalage +0x80 — RÉVISÉ après remarque
   utilisateur (2026-08-10, suite).** La plage 0x10-0x1D (jusqu'ici
   jamais isolée dans `docs/SYMBOLS.md`) utilise EXACTEMENT les mêmes
   sprites "jambes" que 0x90-0x9D (0x10-0x1D + 0x80 = 0x90-0x9D terme
   à terme). Hypothèse initiale ("second chevalier complet") **jugée
   moins probable** que la proposition de l'utilisateur : *les jambes
   du héros, du chevalier ET de Melkhior sont le même sprite*. Preuve
   dans les données elles-mêmes : la plage 0x10-0x1D contient 0x12 et
   0x14, déjà documentés comme types du JOUEUR (`0x12` "type d'entité
   0 (joueur)", `0x14` "jour/explorateur" dans le cycle jour/nuit) —
   pas des types de chevalier. Explication retenue : 0x10-0x1D = les
   jambes du HÉROS (entité compagne du corps joueur, même schéma
   corps+jambes que le chevalier 0x1E+0x90-0x9D et Melkhior
   0x9E+0x90-0x9D, déjà noté dans `notes/2026-08-07-wizard-cauldron-room.md`
   — "toujours accompagné d'une entité jambes"). Le sprite "jambes" est
   un asset GÉNÉRIQUE réutilisé pour les 3 bipèdes (héros/chevalier/
   Melkhior), le +0x80 servant seulement à donner un index de type
   distinct par propriétaire, pas à dédoubler un chevalier. Le mystère
   0x96/0x97 (sprite du CORPS du chevalier, pas des jambes) reste une
   piste À PART, non expliquée par cette révision — voir l'entrée
   `docs/SYMBOLS.md` correspondante. Logique de dispatch exacte de
   0x10-0x1D non vérifiée par désassemblage direct (piste ouverte :
   est-ce `fn_guard_legs_logic`/0x0FD8 réutilisée telle quelle, ou une
   variante propre au héros ?).

9. **Petits blocs faits maison identifiés** : sprites `wood_block`
   (0x06), `wood_door1`/`wood_door2` (0x05/0x04), `wood_wall` (0x80)
   confirment par le nom officiel les hypothèses "thème bois/forêt"
   déjà posées empiriquement dans
   `notes/2026-08-07-entity-logic-forest-room.md` (room 0x3F).
   `small_block` (0x59DB) confirme le nom pour toute la famille de
   blocs statiques/poussables/dormants/sinking (0x07, 0x36, 0x37,
   0x3E, 0x5B, 0x8F, 0xBC-0xBF).

10. **Herse (0x08/0x09)** : le sprite `sprite_herse_7BD7` est
    partagé par DEUX types d'entité (0x08 ET 0x09), alors que seul
    0x09 était documenté (`fn_moving_grate_logic`). 0x08 n'avait
    jamais été isolé — probablement un second segment/pilier de la
    même herse, logique non tracée.

11. **Deux types jamais rencontrés en jeu, maintenant nommés sans
    logique connue** : `conkers2` (0x58, variante de la boule à pics
    "conkers" 0x3F) et `sphere` (0x59). Purement des noms de sprite
    à ce stade — pas de désassemblage de logique associée.

## Pistes ouvertes laissées par cette session

- Confirmer visuellement en salle l'hypothèse "second chevalier"
  (0x10-0x1D/0x96-0x97 ↔ 0x90-0x9D/0x1E-0x1F, décalage +0x80).
- Désassembler la logique de 0x58 (`conkers2`) et 0x59 (`sphere`) si
  elles sont un jour rencontrées en jeu (jamais vues jusqu'ici selon
  `docs/SESSION_SUMMARY.md`/notes précédentes).
- Vérifier si 0x08 (second sprite de herse) a une logique propre ou
  est un simple doublon statique du pilier 0x09.
- Clarifier si `hud_day_left`/`hud_day_right` (0x57E5/0x58E0, types
  0x5A/0xBA) et les sprites `menu*`/`hud1`/`hud2`/`scroll*` sont
  dispatchés via `tbl_entity_logic_dispatch` comme de vraies entités
  ou seulement via `tbl_sprite_dispatch` (rendu direct hors moteur
  d'entités) — non vérifié dans cette session, purement une question
  de nomenclature de sprite pour l'instant.

Voir `docs/SYMBOLS.md` (table des types d'entité) pour les entrées
mises à jour en conséquence.
