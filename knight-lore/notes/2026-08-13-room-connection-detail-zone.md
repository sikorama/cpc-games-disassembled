# Résolution complète de la zone `#4000-#417D` (et de `#3E9E-#4000`)

Suite de l'axe 1 (finir le désassemblage, données bien découpées),
après la segmentation des sprites. Cible demandée par l'utilisateur :
la zone `#4000-#417D`, jusqu'ici des octets bruts sans structure
identifiée.

## Méthode

1. **Fausse piste écartée rapidement** : un balayage naïf de
   désassemblage linéaire de tout `#0000-#3FFF` à la recherche d'une
   instruction chargeant une adresse immédiate dans `#4000-#417D` ne
   donne quasi rien (1 seul faux positif, un `DJNZ` décodé à partir
   d'octets de DONNÉES d'une table voisine — la zone CODE contient de
   nombreuses tables statiques imbriquées, un simple balayage linéaire
   dérive dès qu'il traverse l'une d'elles). Abandonné pour une méthode
   dirigée par les tables déjà connues.
2. **Piste retenue** : `tbl_room_index_ptrs` (`#3E6E`) était déjà
   documentée ("table de pointeurs word, extent non confirmée") et un
   coup d'œil à ses premières valeurs montrait déjà des mots comme
   `#4046`/`#40B7` — dans la zone cible.
3. Désassemblage direct de `fn_load_room_data` (`#2C3A`, jusque-là
   `hypothesis`, jamais réellement lu instruction par instruction)
   avec `z80dis` sur le binaire déjà validé (pas besoin de l'émulateur
   pour ça) : révèle la mécanique exacte —
   - Format d'entrée de `tbl_room_master_index` (`#33DD`) confirmé
     directement par calcul : `[room_id:1][skip_len:1][payload]`, où
     la longueur TOTALE de l'entrée est `1+skip_len` (pas `2+skip_len`
     comme une première tentative l'avait supposé) — vérifié en
     parsant les 128 entrées et en constatant qu'elles consomment
     EXACTEMENT `#33DD-#3D5D` sans reste.
   - Un octet du payload (après le `field_byte`) sert d'index
     `#3E6E + 2*index` dans `tbl_room_index_ptrs` → lit un pointeur
     word → **`LD BC,0008 ; LDIR`** copie exactement 8 octets depuis ce
     pointeur vers `tbl_room_connections` (`#0147`) — confirmé
     directement dans le désassemblage (`#2CA0-#2CA3`).
   - Boucle répétée (`#2CAF-#2CB1`) : après chaque copie de 8 octets,
     `LD A,(HL)` relit le PROCHAIN octet SANS avancer HL au-delà (le
     `LDIR` a déjà positionné HL juste après les 8 octets copiés) — si
     non-nul, recommence un nouveau cycle LDIR(8) à partir de cette
     position (donc ce "prochain octet" devient en fait le 1er octet
     du chunk suivant, sans séparateur dédié) ; si nul, arrête (ce
     chunk-là, commençant par `#00`, n'est PAS copié).
4. **Format déduit et vérifié empiriquement** : chaque bloc pointé par
   `tbl_room_index_ptrs` est une suite de N chunks de 8 octets
   concaténés, terminée par 1 octet `#00` (le début d'un chunk
   fantôme qui n'est jamais copié). Extent totale = `8*N + 1`.
5. **Vérification décisive** : décodage des 24 pointeurs uniques de
   `tbl_room_index_ptrs` (entrées 0-23 — au-delà, index 24+, les mots
   décodés perdent tout sens, confirmant l'extent réelle de la table
   elle-même à 24 entrées/48 octets), calcul de l'extent de chaque
   bloc, tri par adresse : **les 24 blocs s'enchaînent PARFAITEMENT,
   sans le moindre octet de trou ni chevauchement, de `#3E9E`
   jusqu'à... `#417E` exactement — le début de `tbl_object_catalog`,
   déjà confirmé depuis longtemps.** Résout donc d'un coup `#4000-#417D`
   ET le "trou" adjacent `#3E9E-#3FFF` qui n'était même pas identifié
   comme un problème séparé auparavant.

## Résultat

- `tbl_room_index_ptrs` (`#3E6E`) : extent CONFIRMÉE à 24 entrées
  (48 octets), auparavant "non confirmée".
- 24 nouveaux symboles `tbl_room_connection_detail_XXXX` (statut
  `confirmed`), couvrant `#3E9E-#417E` sans aucun octet restant en
  "non désassemblé".
- **Bonus non cherché** : le premier octet de chaque chunk de 8 octets
  ressemble fortement à un TYPE D'ENTITÉ déjà catalogué (murs
  `#0A-#0F`, `wood_wall` `#80`, Melkhior `#9E`/`#90`, cauldron
  `#8D`/`#8E`, `small_block`/herse `#07`/`#08`) — cohérent avec
  l'hypothèse que ces blocs servent à instancier les éléments de décor
  fixes visibles À LA JONCTION entre deux salles (portes, murs,
  chaudron...) au moment d'une transition. Les 7 octets suivants
  (position ? offset ? orientation ?) ne sont PAS désassemblés dans
  cette session — reste `hypothesis` pour une prochaine passe.
- **Fichiers touchés** : `asm/code/screen_addressing_and_tables.asm`
  (désormais `#3186-#4045`, le split de fichier ne coïncide plus
  pile avec `#4000` car `tbl_room_connection_detail_3FD5` chevauche
  cette frontière — accepté comme un cas normal de "découpage par
  plage d'adresse, pas par symbole", déjà la convention du projet) et
  `asm/data/resources_zone.asm` (désormais `#4046-#7FFF`).
- **Validation** : binaire réassemblé identique octet pour octet
  (`cmp`) à la version d'avant cette session, PUIS re-testé au boot
  réel (`.sna` généré, chargé, menu affiché correctement) — cette
  passe n'a fait que ré-étiqueter des octets déjà réels.

## Suite (même jour) : `tbl_room_connection_ptrs` (`#3D5D`) — correction d'une hypothèse et extent confirmée

En poursuivant la lecture de `fn_load_room_data` juste après le point
où la boucle d'index directs (`tbl_room_index_ptrs`) rencontre l'octet
`#FF`, découverte que la documentation existante était **subtilement
fausse** : `tbl_room_connection_ptrs` n'est PAS un "chemin alternatif"
rarement déclenché par un `#FF` dans le payload — désassemblage direct
de `#2CBA` à `#2D0D` montre que c'est en réalité une **phase 2,
TOUJOURS exécutée**, du traitement du payload, juste après la phase 1
(la liste d'index directs qui se termine PAR ce `#FF`, pas qui en
dépend). L'octet du payload situé juste après le `#FF` encode à la
fois un compteur (bits0-2, +1) et, après rotation/masquage
(`rrca,rrca ; and #3E`), l'index×2 dans `tbl_room_connection_ptrs`.

**Extent confirmée par la même méthode** (contiguïté des pointeurs
uniques triés) : exactement 29 entrées (`#3D5D-#3D97`, 58 octets) —
les 29 cibles uniques s'enchaînent PARFAITEMENT jusqu'à
`tbl_room_index_ptrs` (`#3E6E`), 27 enregistrements de 7 octets + 2 de
13 octets (structure légèrement différente, cause non tracée).
Résout donc AUSSI `#3D97-#3E9E`, laissé entièrement en `hypothesis`
jusqu'ici.

**Format des enregistrements** : partiellement désassemblé
(`#2CD3-#2D0D`) — 5 octets copiés directement dans
`tbl_room_connections` (offsets `+0/+4/+5/+6/+7`), puis 2 octets
supplémentaires combinés par rotation avec l'octet-compteur du
payload pour calculer les champs `+1/+2/+3` (code de direction +
numéro de room cible — déjà repéré structurellement dans
`notes/2026-08-06-world-map-attempt.md`, mais jamais désassemblé
directement jusqu'à cette session). **Le détail bit-à-bit exact
de ces 2 derniers octets reste `hypothesis`** — nécessiterait une
validation empirique sur une vraie transition (breakpoint + comparaison
avec le contenu réel de `tbl_room_connections`), pas fait cette
session (travail purement statique).

Symboles ajoutés : `tbl_room_connection_ptrs` (extent 29×2 octets,
`confirmed`) et 29 `tbl_room_direction_record_XXXX` (`confirmed` pour
l'extent, `hypothesis` documentée en commentaire pour le détail des
2 derniers octets). Même validation : binaire identique octet pour
octet, boot réel re-testé, toujours fonctionnel.

**Bilan de la journée** : `#33DD` à `#417E` (1953 octets, soit toute
la zone historiquement documentée `hypothesis`/"extent non confirmée"
autour de la navigation entre salles) est désormais intégralement
segmentée avec des extents CONFIRMÉES de bout en bout — zéro octet
restant en "non désassemblé" sur cette plage. Seul reste `hypothesis`
le contenu SÉMANTIQUE fin de certains champs (le payload détaillé de
`tbl_room_master_index`, les 2 derniers octets de chaque
`tbl_room_direction_record_XXXX`, les 7 octets suivant le type
d'entité dans chaque chunk de `tbl_room_connection_detail_XXXX`) —
tous des candidats naturels pour une prochaine session avec validation
empirique en direct (breakpoints sur une vraie transition de salle).

## Suite (2026-08-13, demande explicite : "vas-y pour la validation empirique des codes de direction")

L'hypothèse "codes de direction + numéro de room cible" pour les 2
derniers octets de chaque `tbl_room_direction_record_XXXX` (formulée
plus haut) a été testée empiriquement — **et infirmée**.

### Méthode

`tools/room_map/teleport.py` dump déjà `tbl_room_connections` (`#0147`)
en brut au moment exact où `fn_load_room_data` vient de la peupler
(`CONNECTIONS_ADDR`/`CONNECTIONS_LEN`, jamais exploité jusqu'ici — le
fichier le note lui-même : "le mapping champ->room voisine n'est PAS
encore décodé"). Réutilisé directement (import du module, `Client`
pointé sur une instance dédiée lancée sur le port 8799 — **jamais la
session live 8765 de l'utilisateur**), téléporté sur 4 salles
(`#44`, `#34`, `#8D`, `#2F`, dont 3 avec des voisins déjà confirmés
empiriquement en 2026-08-06/07), et comparé le contenu brut de
`tbl_room_connections` avec les entités RÉELLEMENT présentes dans le
tableau d'entités actives (même appel `teleport()`, champ `entities`).

**Interruption utilisateur en cours de test** ("recommence, j'ai
perturbé ton test") — sans conséquence : `teleport()` recharge l'état
de zéro à chaque appel (pas d'état à préserver entre deux tentatives),
donc un simple relancement de l'instance + nouvel appel a suffi, et a
reproduit EXACTEMENT les mêmes octets qu'avant l'interruption
(confirmant que ce n'était pas un artefact de la perturbation).

### Résultat

Pour la salle `#44` (4 entrées non vides dans `tbl_room_connections`) :

```
entry 0: 02 8D C4 80 03 05 28 50 44 ...
entry 1: 02 C4 73 80 05 03 28 10 44 ...
entry 2: 02 8D 3B 80 03 05 28 50 44 ...
entry 3: 02 3B 73 80 05 03 28 10 44 ...
```

Entités réellement instanciées dans le tableau actif, MÊME salle :

```
slot 4: type=0x02 grid=[0x8d,0xc4,0x80] flags=0x50 room=0x44
slot 5: type=0x03 grid=[0x73,0xc4,0x80] flags=0x50 room=0x44
slot 6: type=0x02 grid=[0xc4,0x73,0x80] flags=0x10 room=0x44
slot 7: type=0x03 grid=[0xc4,0x8d,0x80] flags=0x10 room=0x44
slot 8: type=0x02 grid=[0x8d,0x3b,0x80] flags=0x50 room=0x44
slot 9: type=0x03 grid=[0x73,0x3b,0x80] flags=0x50 room=0x44
slot 10: type=0x02 grid=[0x3b,0x73,0x80] flags=0x10 room=0x44
slot 11: type=0x03 grid=[0x3b,0x8d,0x80] flags=0x10 room=0x44
```

Correspondance directe, octet pour octet : `octet0=type`,
`octet1=grid_x`, `octet2=grid_y`, `octet3=#80` (CONSTANT sur toutes
les entrées, toutes salles testées — pas un numéro de room cible),
`octet7=flags` (identique au champ réel de l'entité). **Ce sont des
templates d'entité de décor de jonction (poteaux de porte `#02`/`#03`,
murs `#0A-#0F` observés dans d'autres salles), pas des codes de
direction.**

Reproduit à l'identique sur `#34`, `#8D` et `#2F` (voir aussi des
entrées type `#0D`/`#0F` — mur — dans ces salles, cohérent avec
`tbl_room_connection_detail_XXXX` de la veille qui montrait le même
type d'octet0).

**Conclusion** : l'hypothèse de `notes/2026-08-06-world-map-attempt.md`
("(iy+01)/(iy+02) = code de direction, (iy+03) = room cible") ne
tenait pas — c'était une lecture plausible mais jamais vérifiée des
offsets, et le mécanisme réel de résolution de voisinage (comparaison
de la position du JOUEUR aux bords de la salle avec les constantes
`#AE`/`#37`/`#51`/`#C8`, voir section 5 de `docs/SESSION_SUMMARY.md`)
est entièrement indépendant de `tbl_room_connections` — il ne lit
jamais ces octets. **`tbl_room_connections` sert uniquement à
instancier le DÉCOR visuel de la jonction (portes/murs), pas à
résoudre QUELLE salle est voisine.**

Renommage : `tbl_room_direction_record_XXXX` → 
`tbl_room_junction_entity_template_XXXX` (29 symboles dans
`symbols.json`, régénéré, vérifié identique octet pour octet au
binaire précédent, boot réel re-testé).

**Reste ouvert** : le mécanisme RÉEL qui résout "quelle salle est
voisine dans telle direction" à partir de `tbl_room_master_index` n'a
toujours pas de lien établi avec cette famille de tables — la formule
empirique déjà connue (room_number = coordonnées de grille encodées,
section 6 de `docs/SESSION_SUMMARY.md`) reste la seule piste
opérationnelle pour ça, indépendante de tout ce travail de la journée.

## Suite immédiate : le format `tbl_room_connection_detail_XXXX` confirmé de la même façon

Pour clore la journée, même vérification sur les chunks de 8 octets
(`tbl_room_connection_detail_XXXX`, `#3E9E-#417E`, jusqu'ici marqués
"rôle des 7 derniers octets = hypothesis") : téléportation sur la salle
`#34`, comparaison des entrées `tbl_room_connections` de type mur
(`#0D`/`#0F`) avec les entités mur réellement instanciées (slots 8-21).
Correspondance exacte : `slot 8 : type=#0D grid=[#5F,#B8,#80] flags=#10
room=#34` == `chunk : 0D,5F,B8,80,00,08,28,10,34`. Contrairement à
`tbl_room_junction_entity_template_XXXX` (5 octets directs + 2
calculés), ici les 8 octets sont copiés TELS QUELS, correspondant
directement aux 8 premiers offsets de `struct_entities_base`
(`+0`=type, `+1`=grid_x, `+2`=grid_y, `+3`=grid_z_or_offset,
`+4`=bbox_w, `+5`=bbox_h, `+6`=bbox_d, `+7`=flags) — plus aucun octet
`hypothesis` restant sur cette table non plus. `symbols.json` mis à
jour (24 symboles, statut `confirmed`), régénéré, vérifié identique
octet pour octet (à l'exception, toujours, du même octet dynamique
déjà noté plus bas près de `sprite_transform3_4E46` — sans rapport),
boot réel re-testé une dernière fois.

## Découverte annexe (hors scope, notée pour plus tard)

En comparant deux lectures RAM live de DEUX lancements différents du
même snapshot de référence (à des instants réels différents après
chargement), un octet dans la zone nominalement "sprite statique"
(`sprite_transform3_4E46`, autour de `#4E46`) diffère — alors que dans
une MÊME session, 3 lectures consécutives de cette adresse sont
identiques. Ceci suggère qu'au moins une partie de cette zone n'est
PAS purement statique/disque comme supposé pour toute la zone
RESSOURCES, mais est réécrite en cours de partie (candidat probable :
zone de travail/scratch pendant l'animation de transformation
jour/nuit, vu le nom du sprite concerné) — **piste ouverte, pas
creusée cette session**, sans impact sur le boot ni sur la
segmentation des sprites elle-même (qui ne dépend que des BORNES, pas
du contenu exact d'un octet).
