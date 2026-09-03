# Session 2026-08-10 — Résolution de la mutation de `tbl_init_entities_template` (checkpoint de porte)

## Contexte / point de départ

Piste choisie explicitement par l'utilisateur parmi les pistes ouvertes
de fin de session précédente : `tbl_init_entities_template` (`#29EB`,
56 octets) était documentée "confirmed" comme un simple template ROM
figé (2×28 octets, joueur + entité "jambes"), copié vers
`struct_entities_base` à l'init de room — mais une observation directe
(comparaison de deux dumps RAM à des instants différents de la même
partie) avait montré que ses octets CHANGENT en cours de jeu, ce qui
est incompatible avec "template fixe". Piste laissée ouverte sans
being creusée (voir `docs/SESSION_SUMMARY.md` §14, `asm/README.md`
"Limites connues").

## Méthode

1. Recherche binaire statique : extraction de la RAM live (0-0x3FFF)
   et recherche de tous les octets `EB 29` / `07 2A` / etc. (adresses
   little-endian de la table et de ses champs +8/+0x10) dans le code —
   pas seulement dans les deux sites déjà connus
   (`fn_init_room_entities` 0x29B4, `fn_init_room_selection` 0x2A33).
   A révélé un TROISIÈME site, à `#2386-#239F`, jamais documenté.
2. Émulateur : le process AMSpiriT-Lite déjà lancé par l'utilisateur
   sur le port 8765 avait disparu en cours d'investigation (fermé
   côté utilisateur, sans rapport avec cette session). Relancé une
   instance dédiée (`QT_QPA_PLATFORM=offscreen`, snapshot
   `snapshot_20260807_160826_Knight_Lore.sna`) sur le même port pour
   pouvoir réutiliser `tools/gen_asm.py`/`tools/disasm.py` tels quels
   (BASE hardcodée sur 8765).
3. Désassemblage complet de la zone `#233B-#23F6` (jusque-là défb
   bruts) via `tools/disasm.py`, en repérant la table de dispatch à
   4 entrées (`#2344`) et les 4 branches par axe/sens.
4. Ajout des symboles correspondants à `asm/symbols.json`
   (`tbl_door_direction_dispatch`, `fn_door_cross_x_min/x_max`,
   `fn_door_cross_y_max/y_min`), régénération via `tools/gen_asm.py` et
   splice manuel dans `asm/code/doors_and_player_logic.asm` (le reste
   du fichier, non désassemblé, est resté intact).
5. Validation croisée : réassemblage complet (`rasm`) + comparaison
   octet-à-octet du binaire obtenu contre la RAM live sur la plage
   `#2322-#240A` — **0 différence**.

## Résultat

`fn_player_door_transition` (`#2322`) dispatche déjà connu vers 4
gestionnaires par axe/sens (nouvellement nommés `fn_door_cross_x_min`
`#234C`, `fn_door_cross_x_max` `#23A5`, `fn_door_cross_y_max` `#23C0`,
`fn_door_cross_y_min` `#23DB`), qui convergent tous vers une queue
commune (dans le corps de `fn_door_cross_x_min`, `#2360-#23A2`) :

1. Ajuste `(ix+08)` (room_number) par nibble (±1 axe X, ±0x10 axe Y) —
   déjà confirmé les sessions précédentes.
2. Arme les bits 4-5 de `(ix+0C)`.
3. **Nouveau** : si `(ix+00)` (type de l'entité) ∈ `[0x10,0x4F]`
   (TOUJOURS vrai pour le joueur vivant, hero ou loup-garou — ancienne
   lecture du garde INVERSÉE, voir correction ci-dessous) :
   - `LDIR` 56 octets de `struct_entities_base` (position/état RÉELS
     du joueur ET de l'entité "jambes") **VERS** `tbl_init_entities_template`
     (`#29EB`) — **résout la mutation observée** : ce n'est pas un bug
     ni une zone de travail annexe, c'est un **checkpoint explicite**
     écrit à CHAQUE porte franchie.
   - Force l'octet type des deux copies template à `#78` (sentinelle
     de matérialisation, même famille que `#70-#7F`).
   - `jp #05A5` — relance `fn_init_room` SEUL (PAS
     `fn_init_room_entities`, en `#05A2`, qui est sauté) : donc SANS
     décrémenter `var_life_counter`.

**Correction d'une lecture précédente (2026-08-07)** : la note
`notes/2026-08-07-death-mechanism-resolved.md` avait interprété ce
même garde (`#2377`) comme "si `(type-0x10) >= 0x40` → reset", en le
qualifiant de mécanisme de "mort douce". La relecture précise de
l'opcode (`sub #10 / cp #40 / ret nc`) montre que c'est l'INVERSE : le
reset se déclenche quand `(type-0x10) < 0x40`, donc pour `type ∈
[0x10,0x4F]` — qui est le range de TOUS les types normaux du joueur,
pas une anomalie. Autrement dit, **ce chemin s'exécute à CHAQUE porte
franchie en jeu normal**, pas seulement à la mort. La mort réelle
observée le 2026-08-07 (room 0x43) reste un fait empirique confirmé,
mais sa description causale ("ce garde EST le mécanisme de mort") est
probablement fausse ou incomplète — soit la mort emprunte ce même
chemin normal (et "mourir" = franchir une porte pendant qu'une autre
condition, non localisée, était armée), soit un chemin distinct existe
encore ailleurs. **Non tranché cette session.**

## Piste ouverte proposée (non vérifiée)

Puisque ce chemin NE décrémente PAS `var_life_counter` (contrairement
au chemin de boot `#05A2`→`#05A5` qui, lui, appelle
`fn_init_room_entities` et décrémente la vie), une hypothèse naturelle
est que le checkpoint écrit ici serve de position de réapparition pour
la PROCHAINE vraie mort : si le joueur meurt peu après avoir franchi
une porte, il réapparaîtrait à la position de cette porte plutôt qu'au
template de démarrage figé d'origine — cohérent avec le comportement
"checkpoint" de beaucoup de jeux de plateforme de l'époque. **Hypothèse
plausible construite sur la seule lecture du désassemblage, PAS testée
empiriquement** (il faudrait provoquer une mort après avoir franchi
plusieurs portes et vérifier la position de réapparition). À faire en
priorité si cette piste est reprise.

## Fichiers modifiés

- `asm/symbols.json` : 5 nouveaux symboles (`tbl_door_direction_dispatch`,
  `fn_door_cross_x_min/x_max`, `fn_door_cross_y_max/y_min`).
- `asm/code/doors_and_player_logic.asm` : régénéré (via
  `tools/gen_asm.py` + splice manuel) sur `#2322-#240A` — le reste du
  fichier n'a pas été touché.
- `docs/SYMBOLS.md` : entrées `0x2322`, `0x2322 (extension)`, `0x29EB`
  révisées.
