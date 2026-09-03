# Session 2026-08-14 — Captures d'écran périmées dans teleport.py : root-cause et correctif

## Symptôme de départ

`tools/room_map/teleport.py` avance un nombre fixe de frames
(`--settle-frames`, défaut 10) après le chargement d'une salle avant de
prendre une capture d'écran, dans l'hypothèse que le décor serait
"suffisamment dessiné" après un délai fixe. Comparaison des MD5 des PNG
produits (`tools/room_map/out/`) contre la table d'entités du manifeste
(`rooms_manifest.json`, elle correcte) a montré plusieurs groupes de
salles CONSÉCUTIVES et DIFFÉRENTES (murs/objets distincts confirmés par
le manifeste) produisant des PNG **octet pour octet identiques** :
`0x44`/`0x45`/`0x46` (MD5 `d98445ad...`), `0xab`/`0xaf`/`0xb3`/`0xb4`
(MD5 `a74970bc...`), `0x97`/`0x98` (MD5 `471e429...`), `0xc3`/`0xc7`
(MD5 `1a46dc8...`) — tandis que d'autres paires consécutives (0x47/0x48)
produisaient bien des PNG distincts et corrects. Donc : bug intermittent,
pas "toujours en retard d'une salle".

## Piste de départ (voir docs/SYMBOLS.md avant cette session)

`fn_init_room` (#2A68) positionne `var_render_disabled_flag` (#007D) = 1
en fin d'exécution ; `fn_render_disabled_one_time_setup` (#062F) fait le
travail de matérialisation (HUD, `fn_copy_screen_rect`, cycle palette)
PUIS remet ce flag à 0. Hypothèse de travail à vérifier : ce hand-off
prendrait un nombre de frames variable, parfois > 10, selon la
complexité de la salle — d'où l'intermittence.

## Désassemblage : le mécanisme est bien celui-là, mais PAS variable

Lecture complète de `asm/code/low_ram_and_boot.asm` (#05AE-#0670) et
`asm/code/rendering_pipeline.asm` (#2DE2 `fn_render_entities`, #2DBF
`fn_copy_screen_rect`) :

- `fn_render_entities` teste `var_render_disabled_flag` en tout DÉBUT de
  fonction : si non-nul, saute intégralement sa passe "effacer ancienne
  position + empiler le blit VRAM différé" et saute directement à
  l'appel de `fn_check_collisions` (qui dessine quand même les entités
  actives dans le BUFFER INTERMÉDIAIRE, mais rien n'est copié vers la
  VRAM réelle ce tour-ci, faute de rectangles empilés).
- Plus loin dans le MÊME passage de `fn_main_loop`,
  `fn_render_workload_pacing_delay` (#0618, une simple boucle d'attente
  active bornée, PAS un skip de frame) tombe ensuite dans
  `fn_render_disabled_one_time_setup` (#062F), qui teste le même flag :
  si non-nul, fait `fn_copy_screen_rect` (#2DBF) — confirmé être le VRAI
  blit buffer intermédiaire (0x9000-0xBFFF, `BUF_PRERENDER_BASE`) → VRAM
  réelle (source `#BFC0` = fin du buffer intermédiaire, dest `#C008` =
  VRAM, boucle de 192 lignes) — puis remet le flag à 0.
- Tout ceci (test du flag dans `fn_render_entities`, puis le blit et le
  clear dans `fn_render_disabled_one_time_setup`) est en séquence directe
  dans LE MÊME appel de `fn_main_loop`, sans aucun retour anticipé ni
  branchement qui pourrait l'étaler sur plusieurs frames. Par
  désassemblage seul, la matérialisation devrait donc toujours se
  terminer en 1 frame réelle après `fn_init_room`, quelle que soit la
  salle.

Ce résultat contredisait l'hypothèse de départ ("délai variable selon la
salle") — direction prise : vérifier EN DIRECT plutôt que de supposer que
le désassemblage était incomplet.

## Vérification en direct : l'hypothèse "délai variable" est réfutée

Script de diagnostic : téléportation vers une salle connue comme buguée
(ex. `0x45`), lecture RAM de `var_render_disabled_flag` (#007D) ET de
`var_frame_counter` (#006A, 16 bits, incrémenté une fois par frame réelle
par `fn_frame_tick_and_mix`) EN BOUCLE, pendant une exécution NON pausée
(pas de breakpoint), avec un timeout de garde-fou.

Résultat sur toutes les salles testées (buguées : `0x44 0x45 0x46 0xab
0xaf 0xb3 0xb4 0x97 0x98 0xc3 0xc7` ; saines : `0x47 0x48`) : le flag
repasse TOUJOURS à 0 après **exactement 1** incrément de
`var_frame_counter`, sans aucune exception. L'hypothèse de départ (délai
variable selon la complexité de la salle) est donc **infirmée** — le jeu
ne met jamais plus d'une frame à matérialiser une salle, bonne ou
mauvaise.

## Le vrai coupable : la méthode de comptage de frames de l'outil lui-même

Si le jeu matérialise toujours en 1 frame, pourquoi l'ancien
`advance_frames()` (breakpoint sur `fn_main_loop` #05AE, resume ×10)
échouait-il parfois complètement (PNG identiques sur plusieurs salles) ?

Instrumentation croisée : poser SIMULTANÉMENT des breakpoints sur
`0x05AE` (sommet de boucle), `0x05A2` (reset complet d'urgence) ET
`0x062F` (le bloc de matérialisation lui-même), et comparer avec le
compteur `advance_frames()`-style qui ne pose QUE `0x05AE`. Résultat :
avec seulement `0x05AE` armé, une séquence de 10 "arrêts" comptés a pu
laisser `var_render_disabled_flag` bloqué à 1 pendant 3 "itérations"
comptées — alors que `var_frame_counter` (vérité terrain, lu au même
moment) ne progressait, lui, que d'une unité entre deux arrêts sur trois.
Autrement dit : **le breakpoint sur `0x05AE` a rapporté un "hit" sans que
le jeu ait réellement fait un tour complet de boucle entre deux de ces
hits** — un breakpoint réarmé sur SA PROPRE adresse d'arrêt peut mentir
sur le nombre de frames réellement écoulées (voir
`docs/METHODOLOGY.md` §19, nouvelle entrée générique ajoutée cette
session). C'est une variante du problème d'asynchronie déjà documenté
plusieurs fois dans `teleport.py` lui-même (écriture RAM non
synchrone, pause non synchrone, suppression de breakpoint sur l'adresse
courante) : l'API de contrôle de cet émulateur n'est fiable QUE pour "y
a-t-il eu au moins un arrêt à cette adresse", pas pour "combien de tours
de boucle se sont réellement écoulés entre deux arrêts consécutifs sur la
même adresse".

Avec un compteur de frames sous-évalué de façon aléatoire, un budget fixe
de 10 "frames comptées" pouvait, pour certaines salles/certains timings
réseau, correspondre à BEAUCOUP MOINS d'1 frame réelle de jeu — laissant
`var_render_disabled_flag` toujours à 1 et la VRAM dans l'état de la
salle PRÉCÉDENTE au moment de la capture d'écran. D'où les groupes de
PNG identiques sur des salles consécutives.

## Correctif appliqué (`tools/room_map/teleport.py`)

1. Nouvelle fonction `wait_render_enabled(client, timeout_s=2.0)` :
   efface les breakpoints, resume complètement (pas de breakpoint du
   tout), puis **poll directement `var_render_disabled_flag` (#007D) par
   lecture RAM** jusqu'à ce qu'il lise 0 (avec timeout de garde-fou, log
   d'avertissement si jamais atteint — pas censé arriver vu la mesure
   ci-dessus). Repause l'émulateur avant de rendre la main. C'est le
   signal réel demandé par le brief : plus de délai arbitraire.
2. `advance_frames(client, n)` réécrite pour ne plus utiliser de
   breakpoint du tout : poll de `var_frame_counter` (#006A) pendant une
   exécution non pausée jusqu'à ce qu'il ait avancé de `n`, avec timeout.
   Conservée uniquement pour le settle COSMÉTIQUE optionnel après coup
   (`--settle-frames`, toujours par défaut 10) — l'animation des entités
   (ex. boule à piques mobile) continue visiblement de bouger un peu
   après le point de correction, ce qui est normal/attendu, contrairement
   au bug de VRAM périmée qui lui était un vrai problème de correction.
3. `teleport()` appelle maintenant `wait_render_enabled()` (obligatoire,
   avec warning si timeout) AVANT le settle cosmétique optionnel.
4. Interface CLI inchangée (`--settle-frames` existe toujours, même
   défaut, sémantique légèrement précisée dans son `--help`).

## Revalidation

Re-téléportation ciblée vers les 11 salles connues comme buguées + 2
salles saines de contrôle (0x47/0x48) + 0x43 (salle avant le premier
groupe bugué) avec le correctif : **les 14 PNG produits ont maintenant
14 MD5 tous distincts** (vérifié explicitement), alors qu'avant le
correctif 0x44/0x45/0x46 partageaient un MD5 unique, de même pour
0xab/0xaf/0xb3/0xb4, 0x97/0x98 et 0xc3/0xc7. Sweep complet des 128 salles
connues (`--all --restore`) relancé pour vérifier l'absence de nouveau
doublon sur l'ensemble de la carte — voir la session pour le résultat
final (log complet conservé, statut à jour dans
`docs/SESSION_SUMMARY.md`).

## Leçon méthodologique (généralisée dans docs/METHODOLOGY.md §19)

Ne jamais utiliser "nombre de fois où un breakpoint sur une adresse
récurrente a été atteint" comme proxy fiable pour "nombre de frames
réellement écoulées", si l'API de breakpoint/pause de l'émulateur n'a pas
de garantie de synchronicité stricte avec sa propre boucle d'exécution
(et se méfier par défaut : la plupart des émulateurs pilotés par API HTTP/
web n'offrent PAS cette garantie). Préférer systématiquement interroger
DIRECTEMENT l'état réel visé (ici : un flag RAM) par polling pendant une
exécution non pausée, avec un timeout de garde-fou comme seul filet de
sécurité — jamais un délai ou un compte fixe non vérifié.
