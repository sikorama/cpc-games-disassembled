# Les 2 blocs de 13 octets de `tbl_room_junction_entity_template_*` — décodés (nouvel indice sur le mystère 0x96)

Suite du travail sur `#33DD-#417E` (voir
`notes/2026-08-13-room-connection-detail-zone.md`). Parmi les 29 blocs
pointés par `tbl_room_connection_ptrs` (`#3D5D`), 27 font 7 octets et
2 en font 13 : `#3E2A` et `#3E37`. Cible de cette session : comprendre
ce qui diffère.

## Structure décodée

Octets bruts :
```
#3E2A: 96 06 06 18 10 02 90 06 06 00 12 02 00
#3E37: 1E 06 06 18 10 00 90 06 06 00 12 00 00
```

Ce n'est pas un simple champ supplémentaire : ce sont littéralement
**DEUX sous-templates d'entité concaténés** (5+1+5+2 octets), chacun
avec la même forme que le format 7 octets standard (type + 4 octets +
2 octets de calcul partagés) :
```
[type1][b1][b2][b3][b4] [octet milieu] [type2][b1][b2][b3][b4] [2 octets calcul]
```

- `#3E2A` : type1=`#96` (**jamais identifié visuellement**, voir
  point 8 de `notes/2026-08-10-sprite-contact-sheet-naming.md` :
  "le mystère 0x96/0x97... reste une piste à part"), type2=`#90`
  (`guard_legs`, jambes génériques déjà confirmées).
- `#3E37` : type1=`#1E` (`fn_guard_patrol_logic`, LE CHEVALIER,
  confirmé), type2=`#90` (`guard_legs`, MÊME type que ci-dessus).

## L'indice sur `0x96`

Le Chevalier confirmé (`#1E`) et le mystérieux `#96` sont associés à
**exactement les mêmes jambes génériques** (`#90`). Sachant que le
schéma corps+jambes séparés est déjà établi pour le héros, le Chevalier
et Melkhior (voir point 8 de la même note de 2026-08-10), cette
coïncidence suggère fortement que **`#96` est une AUTRE VARIANTE du
corps du Chevalier** (pose ou état différent — immobile ? une autre
direction de patrouille ? un état de garde statique à un poste précis,
par opposition à `#1E` qui patrouille ?), pas un personnage totalement
distinct.

## Ce qui n'a PAS été confirmé cette session

Tentative de trouver, par téléportation réelle
(`tools/room_map/teleport.py`, instance dédiée port 8799), quelle
salle déclenche chacun de ces 2 blocs — pour voir en jeu si un
Chevalier statique apparaît effectivement à une jonction précise.

Méthode : recalculé, pour les 128 salles, l'octet situé juste après le
premier `#FF` du payload de `tbl_room_master_index`, appliqué la
formule de rotation/masquage déjà confirmée (`(cnt_byte>>2)&0x1F`×2)
pour retrouver l'index dans `tbl_room_connection_ptrs`, et cherché
quelles salles pointent vers l'index de `#3E2A` (21) ou `#3E37` (22).
Résultat : salles `#E3` et `#79` respectivement — mais téléportation
réelle sur ces 2 salles, **aucune entité de type `#96`/`#1E`/`#90`/`#91`
trouvée** dans le tableau d'entités actives, ni dans le buffer de
staging `tbl_room_connections` (qui ne montrait que les 4 dernières
entrées écrites — walls/portes classiques, pas le couple garde+jambes).

Deux explications possibles, non tranchées :
1. La formule d'index (dérivée pour les blocs de 7 octets) ne
   généralise pas correctement à un payload qui, pour CES salles
   précises, aurait une structure différente (plusieurs groupes
   séparés par plusieurs `#FF`, ou un octet-compteur à une position
   différente) — mon script ne prend que le TOUT PREMIER `#FF`.
2. Le buffer de staging `tbl_room_connections` n'a que 4 emplacements
   (`ENTITY` non, littéralement 4×56 octets) — si le couple garde+jambes
   est traité AVANT d'autres décorations dans la même salle, il peut
   avoir été écrasé avant ma lecture, même si l'entité active
   correspondante avait bien été copiée entre-temps (mécanisme de
   copie exact non retracé cette session — on sait seulement, par les
   salles `#44`/`#34` de la veille, que BEAUCOUP plus d'entités actives
   que de slots de staging existent au final, donc une copie
   incrémentale doit avoir lieu, mais son déclenchement précis pour
   CHAQUE entrée n'a pas été vérifié).

**Piste concrète pour la prochaine session** : retracer précisément,
dans `fn_load_room_data`, à quel moment et comment chaque entrée
`tbl_room_connections` fraîchement peuplée est copiée vers un slot
LIBRE du tableau d'entités actives (pas juste supposé par analogie
avec les salles `#44`/`#34`) — puis, si la formule d'index a besoin
d'être corrigée pour gérer plusieurs groupes `#FF` par payload, la
revoir avant de refaire le test de téléportation.

## Ce qui reste solide malgré tout

La structure DOUBLE (5+1+5+2) et l'association `#96`↔`#90` /
`#1E`↔`#90` sont lues DIRECTEMENT dans les octets bruts, indépendamment
de toute question de "quelle salle" — ce n'est pas remis en cause par
l'échec de la vérification en jeu. `symbols.json` mis à jour en
conséquence (statut `confirmed` pour la structure, hypothèse explicite
pour l'identité de `#96` en attendant une confirmation visuelle
directe). Vérifié identique octet pour octet au binaire précédent
(description uniquement, aucun octet de code changé), boot réel
re-testé.
