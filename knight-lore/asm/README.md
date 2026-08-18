# Knight Lore CPC — premier essai de source ASM réassemblable

Ceci est le **premier essai** du livrable central du projet (objectif
n°3, `README.md` racine) : un désassemblage annoté, découpé en
plusieurs fichiers, **réassemblable**. Point d'entrée : `knight_lore.asm`.

## Comment c'est produit

Contrairement au reste du projet (notes/docs manuscrites), le contenu
de `code/*.asm` et `data/*.asm` est **généré mécaniquement** par
`tools/gen_asm.py` à partir de :
- `asm/symbols.json` — table de symboles machine-readable, **REFONTE
  2026-08-14** : ne contient plus aucune narration d'investigation
  (dates, renvois `voir notes/...md`, statut de découverte) — chaque
  symbole porte `addr`, `name`, `type` (`code`/`data`), `status`
  (`confirmed`/`hypothesis`/`unknown`), `short` (résumé une ligne) et
  `long` (explication complète, insérée telle quelle en commentaire
  d'en-tête dans le source généré), plus les quelques champs purement
  techniques nécessaires à la génération (`count`, `elem_size`,
  `literal_bytes`/`literal_words`, `decode_full_range`). C'est
  maintenant la table de référence à jour ; `docs/SYMBOLS.md` reste le
  journal d'investigation détaillé (dates, méthode, hypothèses
  successives) mais peut être en retard sur `symbols.json` pour un
  symbole donné — `tools/migrate_symbols.py` documente comment les deux
  ont été réconciliés lors de la refonte ;
- une lecture RAM live de l'émulateur (`127.0.0.1:8765/api/ram`, même
  API que `tools/disasm.py`).

`asm/labels.txt` est une projection minimale de `symbols.json` (une
ligne par symbole : `ADRESSE NOM`, ordre croissant, aucune autre
information) — pensée pour être réutilisable par n'importe quel autre
désassembleur, indépendamment de ce projet. Régénéré automatiquement à
chaque migration, jamais édité à la main.

**Le source généré ne porte plus l'adresse ni les octets machine à
chaque ligne** (cette information reste dans `symbols.json`/
`labels.txt` si besoin) — chaque bloc ne montre que le label et un
commentaire explicatif (`short`+`long` du symbole), suivi des
instructions/données réelles.

**Aucune instruction ni aucun octet n'est inventé** : tout ce qui
apparaît dans `code/*.asm` vient d'une lecture RAM réelle. Pour
régénérer un fichier après une mise à jour de `symbols.json` :

```
python3 tools/gen_asm.py <debut_hex> <fin_hex> > asm/code/mon_fichier.asm
```
(voir l'en-tête de chaque fichier généré pour sa plage exacte, et
`knight_lore.asm` pour l'ordre d'assemblage). Ne pas éditer les blocs de
code générés à la main — l'édition manuelle serait écrasée à la
prochaine régénération ; corriger plutôt `symbols.json`/`docs/SYMBOLS.md`.

## Conventions

- **Hex : préfixe `#`** partout (`#0537`, jamais `0x0537` ni `&0537`) —
  décision explicite de l'utilisateur, voir `docs/METHODOLOGY.md` §-1.
- Labels d'adresse repris tels quels de `docs/SYMBOLS.md`
  (`fn_`/`tbl_`/`var_`/`struct_`).
- Constantes de **type d'entité** (valeurs, pas adresses) : préfixe
  `type_` (`include/entity_types.equ.asm`).
- **Offsets de champ** de la structure d'entité : préfixe `off_`
  (`include/entity_struct.equ.asm`), substitués automatiquement dans
  les opérandes `(ix+NN)`/`(iy+NN)` par le générateur.
- Chaque label porte en commentaire son explication complète (`long` de
  `asm/symbols.json`, ou `short` si `long` est vide) — un statut
  `[hypothesis]`/`[unknown]` n'est affiché QUE si différent de
  `confirmed`, pour ne pas alourdir le cas normal. Une routine
  `hypothesis`/`unknown` n'a JAMAIS de code inventé : seulement un label
  + son commentaire, suivi des octets réels en `defb` commentés "non
  désassemblé".
- Tout octet non couvert par un symbole connu (trou entre deux
  routines, table de taille inconnue) : `defb` réel, 16 par ligne,
  commenté `; non désassemblé` — jamais un simple trou d'adresse.
- **`#9000`+ (buffer de pré-rendu) et `#C000`+ (VRAM)** : **uniquement
  des `EQU`** de référence (`BUF_PRERENDER_BASE`, `VRAM_BASE`), jamais
  de `org`/données — ce sont des zones de RAM d'exécution pure
  (reconstruites chaque frame), pas du contenu chargé depuis le support
  d'origine. Demande explicite de l'utilisateur.
- **`#8000`-`#8FFF`** : omis de ce premier essai, **statut CONFIRMED
  (2026-08-09, vérification live + désassemblage)** : `#80D6`-`#8100`
  est la pile Z80 active (SP init `#8100`). `#8100`-`#8FFF` contient 15
  tables de 256 octets **calculées au boot** (une seule fois, jamais
  recalculées en jeu) par `fn_build_pixel_bitscatter_tables` (`#0829`,
  code déjà présent dans `#0000-#3FFF`) — donc correctement omis, mais
  pour la bonne raison (contenu reconstruit par du code qu'on a déjà,
  pas une donnée absente). Voir `notes/2026-08-09-zone-8000-9000-gap.md`.
- Les régions de **RAM de travail runtime** situées *à l'intérieur* de
  la zone code (`#0055-#00D6` variables zero-page, `#00D7-#0536`
  tableau d'entités actives, `#2720-#274F` buffer d'entités visibles)
  suivent le même principe : un `ds` (réservation), pas un dump des
  octets du instantané RAM au moment de la génération (qui ne
  représenterait qu'un état de partie, pas du contenu source).

## Portée de ce premier essai

- **`#0000`-`#3FFF`** (zone CODE, confirmée par codemap comme seule
  zone réellement exécutée) : couverture **intégrale et contiguë**,
  fichier par fichier (découpage par plage d'adresse, pas par thème
  pur — le code et les données y sont enchevêtrés dans le binaire
  d'origine, un découpage thématique strict aurait cassé la
  contiguïté).
- **`#4000`-`#7FFF`** (zone RESSOURCES, jamais exécutée) : **transcription
  intégrale en octets réels depuis 2026-08-12** (voir
  `notes/2026-08-12-full-data-integration-and-boot-crash.md`) —
  `tbl_object_catalog` (`#417E`-`#429E`) et `tbl_sprite_dispatch`
  (`#429E`-`#4421`) restent annotées comme avant ; le reste
  (`#4000`-`#417D` et surtout `#4422`-`#7FFF`, les données de forme de
  TOUS les sprites, plusieurs Ko) est désormais un dump `defb` réel
  (plus de trou "label seul") — nécessaire pour obtenir un binaire
  réassemblé complet sur `#0000`-`#7FFF`, condition requise pour
  espérer le lancer réellement (voir section suivante). Le
  découpage par sprite individuel reste non tracé (raison inchangée :
  pas de séparateur explicite entre formes).

## Découverte notable de cette passe : le point d'entrée

En préparant ce fichier, le point d'entrée du programme a été
désassemblé et documenté pour la première fois (voir `docs/SYMBOLS.md`,
entrées `fn_cold_boot_entry`/`fn_boot_init_and_new_game`/
`fn_restart_from_menu`/`fn_main_loop`/`fn_main_loop_entity_dispatch`) :
`#0000` → `#0537` (boot froid + init nouvelle partie, qui appelle le
menu à `#0829`, pas encore désassemblé) → boucle de jeu (`#05AE`). Le
retour au menu après un game over (`#0542`, `fn_restart_from_menu`)
rejoint exactement ce même code — confirmant l'hypothèse de l'utilisateur
("le point d'entrée, a priori c'est le menu du jeu, comme après un
game over"). Bonus : ceci a aussi résolu 3 zones auparavant non
désassemblées (`fn_zero_fill_de` #0031, `fn_im1_interrupt_handler`
#0038, `fn_gate_array_config_stream` #0049 — cette dernière RÉSOUT
l'ancienne entrée hypothesis de `docs/MEMORY_MAP.md` "#0049-#0054").

## Validation par réassemblage (`rasm`)

**MIS À JOUR 2026-08-10** — `asm/rasm.exe` (RASM v1.6) était déjà présent
sur cette machine (la mention précédente "aucun assembleur installé"
était erronée/obsolète). `knight_lore.asm` réassemble **sans erreur** :

```
cd asm && ./rasm.exe knight_lore.asm -ob /tmp/out.bin
```

**MIS À JOUR 2026-08-12** — `knight_lore.asm` contient maintenant en
tête `BANKSET 0` / `BUILDSNA V2` / `RUN #0000` / `snaset GA_ROMCFG,#8C`
/ `snaset ROM_UP,#FF` (voir "Lancement réel" plus bas) : `rasm` produit
donc directement un `.sna` complet, chargeable/exécutable tel quel.
**`-ob` est désormais ignoré** (silencieusement — `rasm` écrit un
`.sna` par défaut nommé `rasmoutput.sna` dans le répertoire courant à
la place). Pour choisir le nom du fichier `.sna` produit, utiliser
`-oi` :

```
cd asm && ./rasm.exe knight_lore.asm -oi /tmp/out.sna
```

Pour retrouver un binaire brut `#0000`-`#7FFF` comparable octet-à-octet
à un dump RAM live (la méthode de validation ci-dessous), commenter
temporairement ces 5 lignes d'en-tête avant de relancer avec `-ob`.

Méthode de validation croisée : dump RAM live de l'émulateur (headless,
`SDL_VIDEODRIVER=offscreen LIBGL_ALWAYS_SOFTWARE=1
./amspirit-lite-sdl --web-server <snapshot>.sna`, ROMs via un dossier
`ROMs/` relatif au cwd) comparé octet-à-octet au binaire réassemblé.
Résultat : **un vrai bug de transcription trouvé et corrigé** —
`fn_cold_boot_entry` (`#0000`) documentait un `NOP` (`0x00`) au lieu du
vrai octet `0xF3` (`DI`), vérifié identique sur les 8 snapshots `.sna`
du dépôt (pas un artefact d'un run particulier). Tous les autres écarts
résiduels s'expliquent par des causes déjà connues/attendues, pas des
bugs :
- code auto-modifiant confirmé (patch JP `fn_blit_masked` `#2F8B`,
  trampoline `#1D00-#1D15`, opérande d'unrolling `fn_fill_rect`
  `#1DD6`, cellule de stockage `#2AB6`) ;
- zone RESSOURCES encore non transcrite (`#4000-#417D`) ;
- rotation pseudo-aléatoire déjà documentée des types de
  `tbl_object_catalog` (les octets diffèrent d'une partie à l'autre par
  construction, voir `fn_catalog_randomize_types`).

**RÉSOLU le 2026-08-10** : `tbl_init_entities_template` (`#29EB`, 56
octets) montrait des octets qui **changent** entre deux instants d'une
même partie alors qu'elle était documentée comme un simple template
fixe recopié à l'init de room. Désassemblage complet de la zone
`#233B-#23F6` (jusque-là défb bruts, dans `fn_player_door_transition`) :
c'est bien une DESTINATION d'écriture, à chaque porte franchie — voir
`docs/SYMBOLS.md` (`#2322`, `#29EB`) et
`notes/2026-08-10-door-checkpoint-mechanism.md` pour le détail complet
(checkpoint de position + correction d'une lecture inversée du garde
de "mort douce" documentée le 2026-08-07).

## Lancement réel (pas seulement réassemblage) — RÉSOLU le 2026-08-12

**Depuis le 2026-08-12, le `.sna` produit par `rasm` à partir de ce
seul source BOOTE JUSQU'AU MENU RÉEL de Knight Lore**, pixel pour pixel
identique à l'original ("KNIGHT LORE / 1 KEYBOARD / 2 JOYSTICK /
3 DIRECTIONAL CONTROL / 0 START GAME / © 1984 A.C.G.", jaune/bleu sur
fond noir, capture d'écran validée), **sans dépendre d'aucun SNA de
référence externe**. Cause du long crash chassé toute la journée (voir
historique détaillé ci-dessous et dans
`notes/2026-08-12-full-data-integration-and-boot-crash.md`, §2quater) :
**13 octets manquants à `#0055-#0061`**, dans une zone jusque-là
entièrement traitée comme état runtime pur (`ds`, donc zéro dans le
binaire réassemblé) — alors que `fn_mem_fill_simple` (le memset de
boot) ne touche jamais `#0055-#0067`, et que ces 13 octets sont en
réalité le **script de configuration Gate Array** (mode écran +
encres, terminé par `#FF`) que `fn_gate_array_config_stream` (`#0049`)
écrit au port `#7F00`, appelé depuis le menu (`#15C2`). Sans eux :
zéros lus comme un flux GA sans terminateur valide -> boucle d'écriture
qui ne s'arrête jamais normalement (le blocage observé). Isolés par
bissection méthodique (voir §2quater des notes) et ajoutés au source
comme nouveau symbole `tbl_ga_config_stream_boot` (`kind: tbl`,
`status: confirmed`). **Le point d'entrée (`RUN #0000` vs `#0542`)
n'était PAS le problème** — corrigé sur une fausse piste initiale utile
(elle a motivé le changement de méthode de test qui a révélé le vrai
bug), les deux entrées fonctionnent identiquement une fois ces octets
présents.

### Historique de la chasse au bug (pour mémoire)

Jusqu'ici, la seule validation faite était une comparaison octet-à-octet
entre le binaire réassemblé et un dump RAM live — jamais une exécution
réelle du binaire. Le 2026-08-12, sur demande explicite de
l'utilisateur ("j'aimerais... pouvoir assembler et lancer le jeu"),
premier essai de boot réel : le binaire de 32 Ko (`#0000`-`#7FFF`,
désormais complet suite à l'intégration des données ci-dessus) a été
injecté en RAM d'une instance émulateur live puis `PC` forcé à `#0000`.

**Résultat : le jeu ne boote pas encore jusqu'au menu — crash localisé
précisément.** Le flux d'exécution est correct et confirmé jusqu'à
`call #15C2` (dans `fn_boot_init_and_new_game`, `#058D`) ; ce `call`
ne revient jamais (le CPU finit par exécuter la zone `BUF_PRERENDER_BASE`
(`#9000+`, pure RAM d'exécution) comme du code). `#15C2` est un point
d'entrée qui n'avait **jamais été identifié/tracé avant cette session**
(absent de `docs/SYMBOLS.md`) : les sessions précédentes ne
validaient que des snapshots DEJA en cours de partie, jamais ce chemin
de boot lui-même. Désassemblage statique de son début (probable
init menu/jingle : `#0049`/`#0A97`/`#0ED3` déjà confirmés parmi ses
appels) et détail complet de la bissection de breakpoints qui a permis
cette localisation : voir
`notes/2026-08-12-full-data-integration-and-boot-crash.md` (inclut
aussi la procédure de lancement headless qui fonctionne sur cette
machine, et les pièges du web API à éviter — écritures RAM qui
n'aboutissent pas toujours, instances qui deviennent peu fiables après
un crash).

**Suite (même jour)** : les 3 premiers appels (`#2DB7`, `#2B3B`,
`#1662`) sont innocentés (ils reviennent correctement) ; le 4e
(`#175F`) a un design de sortie compris (tail-call volontaire vers
`#2DBF`, pas un bug) mais le crash lui survit quand même.

**Changement de méthode de test, bien plus fiable (suggestion de
l'utilisateur)** : plutôt que d'injecter le binaire en RAM sur une
instance émulateur déjà démarrée (fragile, voir §"Lancement réel"
ci-dessus et les limites de l'API en §4 des notes), `knight_lore.asm`
génère désormais directement un `.sna` complet via `rasm`
(`BANKSET 0` / `BUILDSNA V2` / `RUN #0000`), chargeable tel quel au
lancement de l'émulateur — plus de comparaison octet-à-octet possible
avec cette méthode, mais un boot déterministe et fiable tant que l'API
web n'est pas corrigée. **Piège rencontré et résolu** : sans configurer
explicitement la Gate Array (`snaset GA_ROMCFG,#8C` / `snaset ROM_UP,#FF`),
le `.sna` démarre avec la ROM basse active, donc `PC=#0000` exécute la
ROM firmware (écran BASIC standard) et pas notre code — sur un vrai
boot disquette, c'est le loader (jamais désassemblé, hors scope de ce
projet) qui désactive la ROM avant de sauter à `#0000`.

**Avec cette méthode propre, le crash se reproduit à l'identique** —
confirme que ce n'est PAS un artefact de la méthode d'injection RAM
utilisée précédemment, c'est un comportement réel et reproductible du
binaire réassemblé. Détail complet (dont la nouvelle piste la plus
prometteuse : une possible entrée invalide dans
`tbl_entity_logic_dispatch` plutôt qu'un bug de boot figé) dans
`notes/2026-08-12-full-data-integration-and-boot-crash.md`, §2ter.

## Limites connues / pistes pour le prochain essai

- **RÉSOLU 2026-08-10** (5e passe du jour, sur demande "vas y pour les
  interruptions") : format complet du moteur d'effets sonores tické par
  IM1 (`fn_sound_engine_tick` `#08CC`, `tbl_sound_dispatch` `#08E8`) —
  8 gestionnaires d'état décodés (bruit décroissant, glissandos, notes
  fixes), tous partagés entre plusieurs déclencheurs de jeu (rebond,
  transformation, matérialisation, bloc poussable, collision générique).
  Confirme que `tbl_sound_chromatic_periods` (`#0BA8`) est PARTAGÉE
  entre ce moteur et le lecteur de jingle bloquant (`#0A97`). Voir
  `docs/SESSION_SUMMARY.md` point 18 et
  `notes/2026-08-10-interrupt-sound-engine-format.md`. Régénération de
  `asm/code/dispatch_and_sound.asm` sur `#0895-#0D66` ; validé par
  réassemblage `rasm` + comparaison octet-à-octet contre la RAM live : 0
  différence. Plusieurs points d'armement restent non identifiés
  précisément (`#0F30`, `#111A`, `#21B9`, `#222D`, `#0F7E`, `#10BD`) —
  candidats pour une identification empirique en jeu.
- **RÉSOLU 2026-08-10** (2e session du jour) : `#1E67` (`unknown`) et le
  cluster PSG/clavier `#0D79-#0DBD`/`#0EDD` (plusieurs entrées
  `hypothesis`, dont une routine ENTIÈREMENT non repérée, `#0D80`)
  désassemblés et confirmés — voir `docs/SYMBOLS.md` (`#1E67`, `#0078`,
  `#0D79`, `#0D80`, `#0D84`, `#0DBD`, `#0EDD`). `#1E67`
  (`fn_object_catalog_writeback`) révèle le mécanisme exact de
  (non-)persistance des objets `#60-#66` entre deux visites d'une salle
  (hypothèse dérivée, pas encore testée en jeu : un objet ramassé
  réapparaîtrait si on revisite la salle). Validé par réassemblage
  `rasm` + comparaison octet-à-octet contre la RAM live sur les deux
  plages éditées (`#0D79-#0EE5`, `#1E67-#1EA1`) : 0 différence.
- **RÉSOLU 2026-08-10** (3e passe du jour) : la zone `#0A90-#0B10`,
  repérée en bonus dans la passe précédente et supposée à tort être un
  "second chemin de scan clavier/joystick non documenté", est en
  réalité `fn_sound_program_play_blocking` (`#0A97`) — un lecteur de
  programme sonore PSG 3 canaux BLOQUANT (busy-wait, pas tické par IM1
  comme `fn_sound_engine_tick`), appelé par
  `fn_game_over_or_daycycle_end` (`#12FB`) pour jouer le jingle de fin de
  partie. Il ne sonde clavier/joystick que pour permettre d'écourter ce
  jingle, pas comme scan d'input générique — correction explicite de
  l'entrée précédente. Voir
  `notes/2026-08-10-object-catalog-writeback-and-psg-keyboard.md`
  (section "Cluster PSG/clavier", addendum de correction).
- **RÉSOLU 2026-08-10** (4e passe du jour, sur demande explicite de
  l'utilisateur "décode le format pour l'audio") : format bytecode
  COMPLET de `fn_sound_program_play_blocking` (`#0A97`, upgradée
  `hypothesis` → `confirmed`) décodé de bout en bout — commandes
  (silence/volume/enveloppe/LOOP/END, `tbl_sound_opcode_dispatch`
  `#0B98`), durées (`tbl_sound_note_durations` `#0B90`) et hauteurs
  (`tbl_sound_chromatic_periods` `#0BA8`, **56 entrées confirmées gamme
  chromatique D2→A6 par calcul de fréquence** — pas juste une lecture de
  code, une vraie preuve numérique). Bonus : précise que
  `fn_psg_write_period_low`/`full` (`#0D8C`/`#0DA7`) sont des primitives
  PSG génériques (select-registre / écrit-valeur), pas spécifiques aux
  périodes. Voir `docs/SESSION_SUMMARY.md` point 17,
  `docs/SYMBOLS.md` (`#0A97`, `#0AF3`, `#0B1F`, `#0B5D`, `#0B98`,
  `#0BA8`, `#0B90`) et `notes/2026-08-10-sound-program-bytecode-format.md`
  pour le format complet avec exemple décodé. Régénération de
  `asm/code/dispatch_and_sound.asm` sur la plage `#0A97-#0D66` ; validé
  par réassemblage `rasm` + comparaison octet-à-octet contre la RAM
  live : 0 différence. Le moteur d'effets SÉPARÉ tické par IM1 (point 8
  de `docs/SESSION_SUMMARY.md`) reste, lui, non décodé.
- ~~`#0829` (appelée au boot, probable boucle de menu) n'est pas encore
  désassemblée~~ — **DÉJÀ RÉSOLU** (2026-08-09, avant ce premier essai) :
  c'est `fn_build_pixel_bitscatter_tables`, voir `docs/SYMBOLS.md`. Cette
  puce était obsolète dès la première rédaction de ce fichier.
- ~~La table `tbl_entity_logic_dispatch` (`#0676`) et `tbl_sprite_dispatch`
  (`#429E`) ont une extent réelle non confirmée~~ — **RÉSOLU 2026-08-10** :
  188 entrées (`#0676-#07ED`, types `#00-#BB`) et 194 entrées
  (`#429E-#4421`, types `#00-#C1`) respectivement, désormais transcrites
  en `defw` structuré dans `code/dispatch_and_sound.asm` et
  `data/resources_zone.asm`. Bonus : la routine `fn_gate_array_palette_cycle`
  (`#07EE`), immédiatement adjacente à la fin de la première table, a été
  découverte et désassemblée au passage.
- Beaucoup de routines `hypothesis`/`unknown` du fichier
  `docs/SYMBOLS.md` restent des stubs (label + statut seulement) — le
  reste attend une prochaine passe d'investigation (pas une prochaine
  passe de génération : le générateur suivra automatiquement dès que
  `docs/SYMBOLS.md`/`symbols.json` seront mis à jour).
- ~~Le contenu pointé par `tbl_sprite_dispatch` (données de forme des
  sprites, `#4422`+) n'est pas transcrit individuellement~~ —
  **RÉSOLU le 2026-08-12 (axe 1, "données bien découpées")**. Format de
  `struct_sprite_shape` déjà CONFIRMÉ le 2026-08-10 (en-tête 3 octets :
  largeur `V`=octets/ligne DIRECTEMENT (bits0-5 de l'octet 0, pas
  `ceil((V+1)/8)`), hauteur `H`, 1 octet consommé mais inutilisé ; puis
  bitmap `V*H` octets, 2 bits/pixel, 4 pixels/octet, agencement CPC
  Mode 1). **Extent totale d'une forme = `3 + V*H`, calculée et
  VÉRIFIÉE le 2026-08-12** sur les 104 pointeurs uniques de
  `tbl_sprite_dispatch` (194 entrées, dont 90 alias) : chaque forme se
  termine EXACTEMENT où la suivante commence — 103/104 contigus
  parfaitement, seul le tout premier (sentinelle `#4422`) suivi d'un
  octet d'alignement isolé, et 5 octets de padding en toute fin de zone
  (`#7FFB-#7FFF`) — tous des `#00` incidentels, pas des données. Les 194
  pointeurs de `tbl_sprite_dispatch` et le manifest utilisateur déjà
  existant (`notes/2026-08-10-sprite-contact-sheet-naming.md`, 103
  formes déjà nommées visuellement par planche de contact) recoupent
  EXACTEMENT — aucun orphelin des deux côtés. Chacune des 104 formes
  porte désormais son propre label `sprite_<nom_officiel>_<adresse>`
  dans `data/resources_zone.asm` (généré par `tools/gen_asm.py` depuis
  `asm/symbols.json`, `kind: tbl`, `status: confirmed`, extent réelle en
  `count`). **Aucun octet n'a changé** — vérifié par comparaison
  binaire du `.sna` avant/après cette segmentation : identique octet
  pour octet, seul le découpage/l'étiquetage a changé. Reste ouvert
  (inchangé) : le bitmap doit être tourné de 90° pour apparaître à
  l'endroit une fois rendu (cause exacte non tracée, voir
  `tools/sprite_dump.py`). Voir `docs/SYMBOLS.md` (`#2F02`, `#31E9`)
  et `notes/2026-08-10-sprite-contact-sheet-naming.md` pour les noms
  officiels + enseignements sur le bestiaire (Poltergeist, Melkhior,
  Chevalier, bulle volcanique, firebug, etc.).
- ~~La zone `#4000-#417D` reste des octets bruts sans structure
  identifiée~~ — **RÉSOLU le 2026-08-13**, et déborde même sur
  `#3E9E-#3FFF` qui n'était pas identifiée comme un trou séparé.
  Désassemblage direct de `fn_load_room_data` (`#2C3A`, jusque-là
  `hypothesis`) : `tbl_room_index_ptrs` (`#3E6E`) a une extent
  CONFIRMÉE de 24 entrées (48 octets, pas "non confirmée" comme avant),
  chaque pointeur mène à un bloc de N chunks de 8 octets concaténés
  (copiés via `LDIR BC=8` dans `tbl_room_connections`), terminé par un
  octet `#00`. Les 24 blocs, une fois triés par adresse, s'enchaînent
  PARFAITEMENT sans le moindre octet de trou de `#3E9E` jusqu'à
  `#417E` (le début de `tbl_object_catalog`, déjà confirmé) — zéro
  octet non expliqué sur toute la plage. 24 nouveaux symboles
  `tbl_room_connection_detail_XXXX` (`status: confirmed`). Bonus non
  cherché : le premier octet de chaque chunk ressemble à un type
  d'entité déjà catalogué (murs, `wood_wall`, Melkhior, cauldron,
  `small_block`/herse) — cohérent avec des blocs de décor de jonction
  entre salles ; le rôle des 7 octets suivants reste `hypothesis`.
  Voir `notes/2026-08-13-room-connection-detail-zone.md` pour le détail
  complet de la méthode (dont la formule exacte `[room_id][skip_len]`
  de `tbl_room_master_index`, aussi précisée au passage : longueur
  totale d'entrée = `1+skip_len`, pas `2+skip_len`).
- ~~`tbl_room_connection_ptrs` (`#3D5D`) : "chemin alternatif si octet
  0xFF", extent non confirmée~~ — **RÉSOLU/CORRIGÉ le 2026-08-13**,
  même journée. Ce n'est pas un chemin alternatif rare : c'est la
  phase 2, TOUJOURS exécutée, du traitement du payload de
  `tbl_room_master_index`, immédiatement après la phase 1 (liste
  d'index directs qui se TERMINE par `#FF`, ne se déclenche pas
  "si" `#FF`). Extent CONFIRMÉE : 29 entrées (`#3D5D-#3D97`). Les 29
  cibles uniques triées s'enchaînent PARFAITEMENT jusqu'à
  `tbl_room_index_ptrs` (`#3E6E`) — 27 blocs de 7 octets + 2 de 13
  octets, résolvant au passage `#3D97-#3E6E`, laissé entièrement en
  `hypothesis` jusqu'ici.

  **Validation empirique demandée par l'utilisateur, même journée** :
  l'hypothèse "code de direction + room cible" pour ces blocs (nommés
  `tbl_room_direction_record_XXXX` à ce stade) était **FAUSSE**.
  Téléportation réelle sur 4 salles (`#44`/`#34`/`#8D`/`#2F`, via
  `tools/room_map/teleport.py` pointé sur une instance dédiée — jamais
  la session live de l'utilisateur) + comparaison directe avec les
  entités réellement instanciées : octet0=TYPE d'entité (poteau de
  porte `#02`/`#03`, mur `#0A-#0F`), octet1=grid_x, octet2=grid_y,
  octet3=`#80` CONSTANT (pas un numéro de room), octet7=flags (identique
  au champ réel de l'entité), octet8=room courante. **Renommés
  `tbl_room_junction_entity_template_XXXX`** — ce sont des templates
  d'entité de décor de jonction (portes/murs), PAS des codes de
  direction. Le vrai mécanisme de direction (`#AE`/`#37`/`#51`/`#C8`)
  compare la position du JOUEUR aux bords de la salle dans
  `fn_room_transition`, indépendamment de cette table. Même
  correction rétroactive pour `tbl_room_connection_detail_XXXX`
  (`#3E9E-#417E`, la veille) : même mécanisme, confirmé par la même
  téléportation (les murs `#0D`/`#0F` vus dans ces blocs sont
  effectivement instanciés).

  **Bilan** : `#33DD` à `#417E` (1953 octets, toute la zone historique
  "navigation entre salles, extent non confirmée") est désormais
  intégralement segmentée avec des extents CONFIRMÉES de bout en bout
  — zéro octet en "non désassemblé" sur cette plage — ET son rôle réel
  (templates de décor de jonction, pas résolution de voisinage) est
  maintenant validé empiriquement plutôt que supposé. Voir
  `notes/2026-08-13-room-connection-detail-zone.md`.

- **2026-08-14 — Correction d'un vrai bug de `tools/gen_asm.py` (pas de
  contenu inventé, mais un défaut d'outillage qui masquait plusieurs
  centaines d'octets déjà `confirmed`)** : le désassembleur linéaire du
  générateur s'arrêtait au premier `ret`/`jp` inconditionnel rencontré,
  même quand ce n'était que la sortie précoce d'une branche particulière
  (le reste de la routine, atteint par le chemin normal, restait alors
  affiché en `defb ... non désassemblé` malgré un statut `confirmed`).
  Ajout d'un opt-in explicite par symbole (`decode_full_range` dans
  `asm/symbols.json`), posé UNIQUEMENT après vérification manuelle
  (décodage linéaire complet, cohérence de bout en bout jusqu'au symbole
  suivant) sur `fn_sprite_pipeline_setup`, `fn_blit_masked`,
  `fn_menu_glyph_unpack`, `fn_pushable_table_logic`, `fn_fill_rect`,
  `fn_moving_grate_logic`, `fn_collision_effect`, `fn_read_input`,
  `fn_read_joystick_table`, `fn_stage_blit_and_clear`,
  `fn_player_materialize_anim_b/end/a/pivot`,
  `fn_read_use_object_button`, `fn_player_use_held_object` — voir
  `docs/METHODOLOGY.md` §16bis pour la méthode générale (et le piège
  symétrique : NE PAS l'activer quand ce qui suit un `ret`/`jp` est en
  fait une vraie table de données, ex. `tbl_collision_dispatch`
  ci-dessous). Corrige au passage un bug de frontière de fichier
  (dernier symbole d'une plage `gen_asm.py <start> <end>` traité comme
  "borne non fiable" même quand le symbole global suivant existe
  exactement à `end`).

  **Nouveaux symboles transcrits** (`fn_check_collisions`, table de
  dispatch RST 28 jusque-là intégralement en `defb`) :
  `tbl_collision_dispatch` (`#27FE`, **27 entrées word confirmées par
  lecture RAM directe — corrige "28 entrées" documenté depuis l'origine,
  jamais revérifié**) et `fn_collision_dispatch_handlers` (`#2834`, 3
  gestionnaires désassemblés en entier). Voir `docs/SYMBOLS.md` (`#2750`,
  `#27FE`, `#2834`).

  **Correction d'une frontière de table erronée** : `tbl_joystick_mask_4`
  était placée à `#2988`, coupant en deux les données réelles de
  `tbl_joystick_mask_3` (qui va en fait jusqu'à `#2992`) — trouvé en
  confrontant les adresses réellement appelées par `fn_read_input`
  (`ld hl,#2992`, jamais `#2988`) aux limites déclarées dans
  `symbols.json`. Bonus : bornes exactes précisées pour une table
  adjacente encore non identifiée (`#29A1-#29B4`, 19 octets, PAS
  référencée par `fn_read_input` — rôle toujours ouvert).

  **Bilan** : sur ~1195 octets `non désassemblé` recensés en début de
  session (toutes zones CODE confondues), il en reste **~68**,
  authentiquement irréductibles en l'état : un buffer HUD runtime
  mutable logé dans la zone CODE (`#1877-#1897`, déjà identifié comme
  état de partie, pas du contenu figé), la table `#29A1-#29B4` au rôle
  encore inconnu, un bloc de 16 octets `#2A23-#2A33` de nature non
  identifiée (aspect table de données, pas du code — décodage tenté et
  rejeté), et une poignée d'octets de bourrage isolés (1-5 octets)
  après des vecteurs RST fixes. Validé par réassemblage `rasm` complet
  (zéro erreur) et comparaison octet-à-octet contre un dump RAM live sur
  toute la zone CODE (`#0000-#3FFF`) : seuls des octets déjà documentés
  comme runtime/rotatifs (page zero, tables randomisées par nouvelle
  partie) diffèrent, zéro régression sur le code statique.
