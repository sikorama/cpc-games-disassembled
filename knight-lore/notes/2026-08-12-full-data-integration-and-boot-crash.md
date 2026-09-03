# Intégration complète des données (#4000-#7FFF) et premier essai de lancement réel

Demande explicite de l'utilisateur : que `asm/knight_lore.asm` intègre
TOUTES les données nécessaires pour être réassemblé ET réellement lancé
(pas seulement comparé octet-à-octet à une RAM live), le jeu actuel
crashant "à moins que le point d'entrée ne soit pas correct".

## 1. Intégration des données (#4000-#7FFF) -- FAIT

Avant cette session, `asm/data/resources_zone.asm` ne transcrivait que
`tbl_object_catalog` (#417E-#429E) et `tbl_sprite_dispatch`
(#429E-#4421) : tout le reste (#4000-#417D, et surtout #4422-#7FFF --
les données de forme de tous les sprites, plusieurs Ko) n'était qu'un
label + commentaire, donc ABSENT du binaire réassemblé. C'est très
probablement la cause du crash initial signalé par l'utilisateur : le
jeu tente de dessiner des sprites (menu, decor, joueur) dès les
premières frames en lisant des adresses qui n'existaient pas dans le
binaire.

Méthode : émulateur relancé headless (voir §3 pour la procédure qui
fonctionne sur cette machine), snapshot `snapshot_20260807_160826_Knight_Lore.sna`
chargé (partie déjà en cours, day 11, RAM confirmée = jeu réel).
`tools/gen_asm.py` invoqué directement (en monkey-patchant `BASE` pour
viser le port choisi, cf. §3) sur la plage `#4000-#8000` entière :
produit désormais un dump `defb` réel et continu de TOUTE la zone
RESSOURCES, remplaçant l'ancien fichier. Réassemblage `rasm` : succès,
binaire de 32768 octets (#0000-#7FFF) obtenu sans erreur.

**Point relevé en passant** : les 32 octets de TYPE de
`tbl_object_catalog` diffèrent de l'ancienne transcription -- confirme
la rotation pseudo-aléatoire déjà documentée (`fn_catalog_randomize_types`,
notes/2026-08-07-object-catalog-randomizer.md), pas un bug. Commentaire
ajouté en tête de fichier pour que ça ne soit pas repris à tort comme
une régression lors d'une prochaine régénération.

`asm/README.md` à mettre à jour en conséquence (portée : #4000-#7FFF
désormais intégral, plus de trou "label seul").

## 2. Premier essai de lancement réel -- crash reproduit et localisé précisément

Contrairement aux sessions précédentes (qui ne faisaient QUE comparer
le binaire réassemblé à un dump RAM live, jamais l'exécuter), cette
session a réellement injecté le binaire de 32 Ko en RAM (adresse #0000,
écrasant l'état de partie en cours) puis forcé `PC=#0000` pour simuler
un boot froid, via l'API web de debug (`POST /api/ram` avec
`exec:true, entry:0`).

**Résultat : ça ne boote pas jusqu'au menu.** Le crash est
reproductible et précisément localisé par bissection de breakpoints
(`POST /api/z80_bp` + `POST /api/config {paused:false}` +
polling `GET /api/state` jusqu'à `paused && PC==cible`) :

- `#0000` (`fn_cold_boot_entry`) -> `#0537` (`fn_boot_init_and_new_game`) :
  **OK**, atteint exactement.
- `#0537` -> `#057F` (juste avant `call fn_build_pixel_bitscatter_tables`) :
  **OK**.
- `#057F` -> `#0582` -> `#058D` (`call #15C2`) : **OK**, atteint
  exactement à chaque fois (reproductible sur plusieurs tentatives
  propres).
- `#058D` (`call #15C2`) -> `#0593` (l'instruction juste APRES ce call,
  donc le retour attendu) : **JAMAIS ATTEINT**. Le CPU part dans
  `#15C2` et n'en revient jamais proprement : quelques dizaines
  d'instructions plus tard, PC se retrouve dans la zone
  `#B940-#B950` (zone `BUF_PRERENDER_BASE`/VRAM, RAM d'exécution pure,
  jamais du code réel -- voir `docs/MEMORY_MAP.md`), exécutant cette
  donnée comme si c'était du code, dans une boucle qui ne s'arrête plus
  (`SP` explose de `#8100` initial à `#BFE8`+, `IFF1/IFF2=0`, valeurs de
  registres incohérentes avec un flux de code réel) -- signature
  classique d'un "saut dans les mauvaises herbes", pas d'un ralentissement
  normal.

**`#15C2` est un point d'entrée jamais identifié avant cette session**
(absent de `docs/SYMBOLS.md`/`asm/symbols.json`) -- ce qui explique
pourquoi ce chemin n'avait jamais été vérifié empiriquement : les
sessions précédentes ne faisaient que lire/comparer des snapshots
DEJA en cours de partie (donc après que ce code se soit déjà exécuté
avec succès sur le vrai hardware), jamais retracé son exécution
elle-même. Désassemblage statique (avec `z80dis`, directement sur le
binaire réassemblé, sans dépendre de l'émulateur) du début de cette
routine :

```
15C2: xor a                    ; AF
15C3: ld (#007E),a             ; 32 7E 00
15C6: ld hl,#167C               ; 21 7C 16
15C9: ld b,#03                  ; 06 03
15CB: ld (hl),#0F               ; 36 0F
15CD: inc hl                    ; 23
15CE: djnz #15CB                ; 10 FB
15D0: call #2DB7
15D3: call #2B3B
15D6: call #1662
15D9: ld hl,#0055
15DC: call #0049               ; fn_gate_array_config_stream (confirmed)
15DF: call #175F
15E2: ld hl,#0C55
15E5: call #0A97               ; fn_sound_program_play_blocking (confirmed)
15E8: ld hl,#0055
15EB: call #0049
15EE: call #175F
15F1: ld a,#08
15F3: call #0ED3               ; fn_read_keyboard_line (confirmed)
15F6: ld e,a
...
```

Les octets sont réels (lus en direct sur le binaire réassemblé, pas
inventés) et forment une séquence plausible (init d'une zone de 3
octets à #167C-#167E, armement palette GA, lecture d'un programme
sonore bloquant -- probablement le jingle d'intro du menu --, scan
clavier). **Ce n'est donc a priori PAS un octet corrompu dans notre
transcription** (les bytes de `#0FD8-#3FFF` sont déjà intégralement
transcrits et validés octet-à-octet dans les sessions précédentes) --
mais un des 4 appels non identifiés (`#2DB7`, `#2B3B`, `#1662`,
`#175F`), ou la fin de cette même routine après `#0ED3`, contient le
point de divergence réel. Aucun des 4 n'a de symbole dans
`docs/SYMBOLS.md`/`asm/symbols.json` -- prochaine étape naturelle :
les désassembler/tracer un par un (breakpoints sur chacun, dans
l'ordre, pour isoler lequel des 4 est le premier à ne jamais retourner
proprement).

**Hypothèse alternative à ne pas écarter** : cette session simule un
"boot froid" en écrasant la RAM d'une partie DEJA EN COURS puis en
forçant PC=0, plutôt qu'un vrai boot disquette. Si une de ces routines
dépend d'un état matériel (FDC, registres CRTC/GA) que seul un VRAI
reset matériel initialise correctement -- et que notre injection RAM
ne réplique pas -- le crash pourrait être un artefact de la méthode de
test, pas un bug du binaire. À trancher en testant depuis un VRAI reset
CPC (`--reset`) avec le binaire chargé en `.bin`/`.dsk` plutôt que par
injection RAM sur une instance déjà démarrée.

## 2bis. Suite (même jour) : les 3 des 4 appels non identifiés sont innocentés, le 4e (`#175F`) mène à un comportement non-déterministe

Poursuite de la piste : tracer `#2DB7`, `#2B3B`, `#1662`, `#175F` (les 4
appels effectués par `#15C2` avant d'atteindre les routines déjà
confirmées) un par un, par bissection de breakpoints sur chaque adresse
de retour (`#15D3`, `#15D6`, `#15D9`, `#15E2`).

**Résultat : les 3 premiers reviennent correctement.** `#2DB7`, `#2B3B`
et `#1662` sont donc innocentés — ce ne sont pas eux qui font dérailler
le boot. Le 4e, `call #175F` (à `#15DF`), est le point où le
retour attendu à `#15E2` échoue.

**Mais `#175F` a un flux de sortie à DEUX branches, pas un simple
défaut de RET** — désassemblage statique (`z80dis` directement sur le
binaire réassemblé, sans dépendance à l'émulateur) :

```
175F: ld de,#167B
1762: exx
1763: ld hl,#1681
1766: ld de,#168D
1769: ld b,#06
176B: exx
176C: ld a,(de) / ld (#007C),a / inc de / exx / push bc / ...
      ... boucle DJNZ vers #176B (6 iterations), appelle #16DA a chaque tour
177F: djnz #176B
1781: ld a,(#007E)
1784: and a
1785: ret nz                  ; <-- sortie normale SI (#007E) != 0
1786: inc a
1787: ld (#007E),a
178A: jp #2DBF                ; <-- sinon, JP (pas CALL) vers #2DBF
...
2DBF: (blit complet buffer->VRAM, boucle 192x64 octets via LDIR,
       gestion de l'entrelacement CPC #C050) ... ret a #2DE1
```

`#007E` est justement remis à zéro juste avant (`#15C3`, dans le
prologue de `#15C2`) — donc au tout premier passage (boot froid), la
branche prise est `jp #2DBF` : la routine "s'échappe" volontairement
dans le pipeline de rendu au lieu de faire un simple RET, et c'est le
`ret` de `#2DBF` (à `#2DE1`) qui doit ramener à `#15E2` (puisque le
`call #175F` original a poussé cette adresse de retour, et que le `jp`
ne pousse rien de nouveau — un "tail-call via JP" classique). Ce n'est
donc **pas un bug en soi** : la routine est conçue pour ça.

**Malgré ça, le crash persiste, et de façon NON-DETERMINISTE** : sur
plusieurs tentatives strictement identiques (même binaire, même
séquence d'écriture/vérification, même breakpoints), le point exact où
`PC` part dans `#9000+` varie — parfois dès `#176C` (avant même la
boucle DJNZ), parfois seulement après `#178A`/le blit. C'est la
signature d'une dépendance au timing d'une interruption (IM1 est armé
tôt, `#0566`/`#054B` via `fn_arm_interrupt_flag`, donc des interruptions
peuvent survenir n'importe quand pendant cette séquence) plutôt qu'un
octet fixe incorrect à un endroit précis.

**Piste testée et NON concluante** : patch à la volée (uniquement sur
la copie RAM live, pas dans le source) de l'unique `EI` de
`fn_arm_interrupt_flag` (`#0D79`, `FB`->`#00`) — routine partagée par
les 2 seuls points d'armement connus (`#054B` boot, `#05B5` boucle
principale). Le crash persiste identique (`IFF1=1` observé dans l'état
plante ensuite, ce qui montre qu'au moins un AUTRE `EI` existe ailleurs
dans le code et s'exécute avant qu'on n'atteigne le crash — pas
localisé). Un balayage statique naïf des octets `#FB` dans
`#0000-#3FFF` remonte ~20 candidats, mais la plupart sont des FAUX
POSITIFS (`#FB` comme octet de DONNEE d'une autre instruction, ex.
déplacement négatif d'un `DJNZ` comme à `#15CF`) — nécessiterait un
désassemblage linéaire complet pour lister les VRAIS `EI`, pas fait
cette session (budget temps).

**Hypothèse alternative non testée non plus** (déjà notée en fin de
§2) : la méthode de test elle-même (injection RAM sur une instance déjà
démarrée + `PC` forcé) pourrait ne pas répliquer parfaitement un vrai
reset matériel (état CRTC/GA/FDC, compteurs internes de l'émulateur),
et le comportement non-déterministe observé pourrait être un artefact
de CETTE méthode plutôt qu'un bug du binaire réassemblé lui-même.

**État à date** : 3 des 4 appels innocentés ; le 4e (`#175F`) a un
design de sortie compris et documenté (pas un bug de transcription
visible), mais le crash lui survit, de façon non-reproductible à
l'instruction — donc soit une interruption qui déraille (cause exacte
non localisée), soit un artefact de méthode de test. Nécessite un
traçage instruction-par-instruction SANS aller-retour réseau (donc
sans la latence/variance qui pourrait elle-même expliquer la
non-reproductibilité) pour trancher — voir §3 pour les limites
concrètes de l'outillage actuel rencontrées en essayant.

## 2ter. Suite (même jour) : méthode de test bien plus fiable via `.sna` généré par `rasm` -- le crash est CONFIRMÉ réel, pas un artefact de méthode

Proposition de l'utilisateur, bien meilleure que l'injection RAM sur
une instance déjà démarrée (§2/§2bis) : faire produire par `rasm`
lui-même un vrai fichier `.sna` (registres + RAM complets), chargeable
directement au lancement de l'émulateur ou via son API média — plus
besoin de l'API web fragile (`POST /api/ram`, voir §4) pour injecter
quoi que ce soit.

**Ajouts en tête de `knight_lore.asm`** :
```
        BANKSET 0
        BUILDSNA V2
        RUN #0000
        snaset GA_ROMCFG,#8C
        snaset ROM_UP,#FF
```
- `BANKSET 0` (suggéré par l'utilisateur) : sans lui, `rasm` refuse
  («`BANK is too big!!!`») car en mode `BUILDSNA` il découpe la RAM en
  banques de 16 Ko par défaut (`bank 0`=`#0000-#3FFF`, `bank
  1`=`#4000-#7FFF`, etc.) — notre source traverse plusieurs banques
  sans jamais déclarer de `bank N`. `BANKSET 0` traite les 64 Ko comme
  un seul bloc plat, ce qui correspond exactement à notre modèle
  mémoire (pas de pagination).
- `RUN #0000` : fixe `PC` au vrai point d'entrée (`fn_cold_boot_entry`).
  Confirmé par l'utilisateur : "run 0 c'est le crash assuré" — attendu,
  c'est justement le chemin qu'on veut observer.
- **`snaset GA_ROMCFG`/`ROM_UP` — étape cruciale NON anticipée** :
  sans eux, le `.sna` généré démarre avec la configuration Gate Array
  par défaut (ROM basse ACTIVE), donc `PC=#0000` exécute en réalité la
  ROM firmware CPC, pas notre code — confirmé en obtenant l'écran de
  boot BASIC standard ("Amstrad 128K Microcomputer... Ready") au lieu
  du jeu. Sur un vrai boot disquette, c'est le LOADER de boot (jamais
  désassemblé dans ce projet, hors RAM #0000-#7FFF) qui désactive la
  ROM basse (et haute) via le port Gate Array AVANT de sauter à
  `#0000` — notre binaire n'inclut jamais cette instruction `OUT`
  puisqu'elle appartient au chargeur, pas au jeu lui-même. Valeurs
  trouvées par test empirique (mini-programme de 10 octets écrivant en
  VRAM puis `HALT`, vérifié par lecture RAM+PC après boot — voir
  `mini5.asm` dans le scratchpad de session, non versionné) :
  `GA_ROMCFG=#8C`, `ROM_UP=#FF` — confirmées suffisantes (le mini-programme
  s'exécute bien depuis la RAM, VRAM modifiée comme prévu, `PC` s'arrête
  exactement sur le `HALT`).

**Résultat sur le binaire complet, avec cette méthode propre (aucune
injection RAM, aucune course avec l'API) : LE CRASH SE REPRODUIT À
L'IDENTIQUE.** Sur ~700 frames observées après boot, `PC` oscille de
façon répétée entre du code légitime (`#1BCx-#1E9x`, zone
`entity_logic_mechanical.asm`/`pickups_and_transform.asm`) et la zone
`#9000+`/`#B940+` (buffer de pré-rendu, jamais du code réel) — jamais
bloqué indéfiniment, mais jamais stable non plus. **Ceci répond
définitivement à l'hypothèse ouverte en fin de §2bis** : ce n'est PAS
un artefact de la méthode d'injection RAM (celle-ci a été totalement
abandonnée pour ce test) — c'est un comportement réel et reproductible
du binaire réassemblé.

**Nouvelle piste, plus prometteuse que le fil `#15C2`/`#175F` de §2bis** :
l'oscillation régulière entre du code légitime et le buffer de
pré-rendu, PENDANT des centaines de frames sans jamais se bloquer
définitivement, ressemble moins à un boot qui déraille une fois pour
toutes qu'à une boucle de jeu qui tourne réellement (dispatch d'entité
par frame, `RST 28` -> `tbl_entity_logic_dispatch`) et qui, pour UNE
entité en particulier (peut-être un slot du tableau d'entités resté à
un état incohérent après un boot froid jamais testé avant cette
session), calcule occasionnellement une adresse de saut invalide qui
tombe dans le buffer. À investiguer en priorité la prochaine fois :
poser un breakpoint sur `fn_main_loop_entity_dispatch` (`#05D4`, le
`RST 28`) et inspecter `(ix+off_type)` à chaque itération pendant
quelques frames, pour repérer si un type d'entité précis coïncide avec
chaque bascule vers `#9000+`.

## 2quater. RÉSOLU (même jour) : le bug réel identifié et corrigé — 4 octets manquants à `#005E-#0061`

Suite à la correction de l'utilisateur sur `#0542` (voir en tête de ce
fichier de conversation) : plutôt que de continuer à bissectionner sur
`RUN #0000` avec un `.sna` entièrement synthétique (méthode jugée
biaisée par l'utilisateur — à raison), nouvelle méthode en deux temps :

**Test 1 — patcher UNIQUEMENT le code réassemblé dans un vrai SNA de
référence** (`snapshot_20260807_160826_Knight_Lore.sna`, partie
réellement en cours), en laissant tout le reste (pile, tables, zero-page,
VRAM, **et surtout les 3 zones `reserved_ram_regions` de
`symbols.json`** — zero-page `#0055-00D7`, table d'entités `#00D7-0537`,
`buf_visible_entities` `#2720-2750`) strictement intact. Entrée forcée à
`#0542` (`fn_restart_from_menu`).

- **Première tentative, ratée par ma propre erreur** : j'ai écrasé TOUT
  `#0000-#7FFF` en bloc, y compris ces 3 zones réservées (qui sont DANS
  cette plage) avec le contenu de notre binaire — qui les traite comme
  `ds` (zéro). Résultat : crash identique à avant (`#B943`). Piège
  méthodologique découvert et documenté ici pour ne pas le répéter :
  "patcher le code" veut dire patcher le CODE, pas bêtement toute la
  plage d'adresses qui le contient.
- **Deuxième tentative, en excluant explicitement les 3 zones
  réservées du patch** : **SUCCÈS TOTAL**. Tout le chemin
  `#058D->#176C->#1781->#178A->#2DBF->#2DE1->#15E2` passe sans accroc,
  et l'écran de MENU RÉEL de Knight Lore s'affiche
  ("KNIGHT LORE / 1 KEYBOARD / 2 JOYSTICK / 3 DIRECTIONAL CONTROL /
  0 START GAME / © 1984 A.C.G."), capture d'écran à l'appui. **Ceci
  confirme que le code réassemblé lui-même est CORRECT** — le crash
  n'était jamais dans notre transcription du code, mais dans l'absence
  de données réelles dans une zone qu'on croyait être de l'état runtime
  pur.

**Test 2 — isoler PRÉCISÉMENT quel sous-ensemble de ces zones réservées
est réellement nécessaire**, par bissection sur un `.sna` sinon
entièrement synthétique (base = notre propre `.sna` généré par
`BUILDSNA`, donc tout `#0000-#7FFF` = notre code réel, tout le reste =
zéro) :

| Hypothèse testée | Résultat |
|---|---|
| Aucune zone réservée réelle (tout synthétique) | **CRASH** (comme depuis le début) |
| `#0055-00D7` (zero-page) réel + `#2720-2750` synthétique | **OK**, menu affiché |
| `#0055-00D7` synthétique + `#2720-2750` (buf_visible_entities) réel | **CRASH** |
| → conclusion : le fautif est dans `#0055-00D7`, pas dans `buf_visible_entities` (cohérent avec la doc existante : reconstruit chaque frame, jamais lu avant `fn_cull_entities`) |
| `#0055-005D` (9 octets) réels seuls | **CRASH** |
| `#005E-0066` (9 octets) réels seuls | **OK** |
| `#005E-0061` (4 octets) réels seuls | **OK** |
| → **isolé à exactement 4 octets : `#005E`,`#005F`,`#0060`,`#0061`** | valeur réelle observée : `#03,#55,#FF,#00` |

**Ces 4 octets ne sont PAS de l'état de partie** (contrairement à ce
qui était documenté pour toute la zone `#0055-00D7` dans
`symbols.json`) : sur un vrai boot, `fn_mem_fill_simple` (appelé à
`#053D`/`#0548`, remplissage par `#00` littéral, confirmé par
désassemblage — voir `code/rendering_pipeline.asm:24`) ne touche que
`#0068-#0536` (démarrage cold boot) ou `#0070-#0536` (démarrage
menu) — **jamais `#0055-#0067`**. Ces 18 octets sont donc censés
persister d'un boot à l'autre / d'une partie à l'autre sur le vrai
hardware — mais parmi eux, seuls 4 (`#005E-#0061`) se sont révélés
réellement lus par le chemin critique avant `fn_main_loop`. Rôle exact
non identifié (pas encore désassemblé les lecteurs de ces 4 octets
précisément) — ajoutés à `symbols.json`/régénérés dans
`code/low_ram_and_boot.asm` comme `unk_005E` (kind `tbl`, status
`unknown`, `literal_bytes` réels).

**Correctif appliqué** : `symbols.json` — la région réservée
`zone_var_ram_basse` (`#0055-00D7`) scindée en 3 : `#0055-005E` (ds,
inchangé), `#005E-0062` (nouveau symbole `unk_005E`, 4 octets réels
fixes), `#0062-00D7` (ds, inchangé, renommé `zone_var_ram_basse` pour
la partie restante). Régénéré `code/low_ram_and_boot.asm` via
`tools/gen_asm.py` (RAM live de la même instance de référence).

**Résultat final, validé deux fois** : le `.sna` produit UNIQUEMENT à
partir du source (`BANKSET 0`/`BUILDSNA V2`/`snaset GA_ROMCFG,ROM_UP`,
plus ces 4 octets désormais réels) **boote jusqu'au menu, sans AUCUNE
dépendance à un SNA de référence externe** — testé avec `RUN #0542`
ET avec `RUN #0000` (les deux fonctionnent identiquement, confirmant
que le choix de point d'entrée n'était jamais le vrai problème — la
donnée manquante l'était). `RUN #0000` conservé dans
`knight_lore.asm` (point d'entrée canonique, cohérent avec
`fn_cold_boot_entry`).

**Point cosmétique -- RÉSOLU dans la foulée (retour utilisateur : "le
cpc était en mode 0")** : explique tout d'un coup. `#0055-#0060` (12
des 13 octets qu'on venait d'isoler) est en réalité le SCRIPT DE
CONFIG GATE ARRAY (mode écran + encres) que `fn_gate_array_config_stream`
(`#0049`) écrit au port `#7F00`, terminé par le `#FF` à `#0060` --
appelé 2 fois depuis le menu (`#15DC`/`#15EB`, dans `#15C2`). Mon
premier correctif (§2quater ci-dessus) n'incluait QUE les 4 derniers
octets (`#005E-#0061` = `03,55,FF,00`) -- juste assez pour que le
terminateur `#FF` soit présent et que la boucle d'écriture du flux GA
se termine normalement (ce qui évitait le blocage), mais avec des
ZÉROS à la place des 9 premiers octets réels (`8D,10,54,00,54,01,4A,02,55`)
-- d'où un mode/palette GA erroné (mode 0 au lieu de 1) mais un boot
qui ne plante plus. Élargi `unk_005E` (4 octets, role inconnu) en
`tbl_ga_config_stream_boot` (13 octets, `#0055-#0061`, status
`confirmed`) avec les VRAIS 13 octets. Rebuild + reboot :
**`ga.mode` passe de `0` à `1`, capture d'écran identique pixel pour
pixel au menu Knight Lore attendu** (jaune/bleu net sur fond noir).
Ce chantier "lancement réel" est maintenant clos.

**Leçon méthodologique clé de cette session** : l'hypothèse initiale
("il faut chercher du côté du menu, pas `#0000`") était une fausse
piste utile — elle a motivé le changement de méthode de test qui a
RÉVÉLÉ le vrai bug (données manquantes), mais le point d'entrée en
lui-même n'était jamais le problème. Le vrai gain n'est pas venu de
changer l'adresse `RUN`, mais de changer la façon de peupler la RAM
avant de sauter — remplacer `RUN #0000` sur un état totalement
synthétique par un test qui isole précisément CE qui, dans l'état
"non-code", doit être réel.

## 3. Procédure de lancement headless qui fonctionne sur cette machine (mise à jour)

En complément de `notes/2026-08-10-object-catalog-writeback-and-psg-keyboard.md`
(qui documentait déjà `SDL_VIDEODRIVER=x11` + `SDL_AUDIODRIVER=dummy`
sur le `:0` existant) :

- **Toujours lancer sur un port web DIFFERENT de 8765**
  (`--web-port 8799` par exemple) : une session AMSpiriT-Lite Qt de
  l'utilisateur tourne déjà sur 8765 en tâche de fond (vue en direct
  cette session -- PAS Knight Lore, un autre programme) ; ne jamais
  écrire dans sa RAM.
- Lancer via l'outil Bash en **`run_in_background: true`** (un simple
  `&`/`nohup` en arrière-plan de la commande a échoué de façon
  intermittente dans cet environnement -- le process ne survivait pas
  au retour de l'appel shell).
- `POST /api/ram` sur un GROS payload (32 Ko) **n'aboutit pas toujours
  du premier coup** même avec `paused` confirmé (`GET /api/state` ->
  `emu.paused==true` stable sur plusieurs lectures) -- **toujours
  relire (`GET /api/ram`) pour vérifier que l'écriture a bien pris**
  avant d'enchaîner sur un `exec`, avec quelques tentatives si besoin.
  Ne JAMAIS supposer qu'un `POST` répondant `{"ok":true}` a réellement
  appliqué le contenu.
- Une fois qu'une instance a exécuté du code dans une boucle infinie
  errante (le crash lui-même, #B940+), elle devient **durablement peu
  fiable** pour de nouvelles écritures RAM (plusieurs tentatives de
  réécriture ont ensuite échoué à répétition sur la MEME instance) --
  **relancer une instance fraîche** plutôt que de réutiliser une
  instance qui vient de planter.
- **`pkill -f` est sensible à la casse** : le process réel une fois
  l'AppImage extraite s'appelle `amspirit-lite-sdl` (minuscules), PAS
  `Amspirit-Lite-SDL` (le nom de l'AppImage elle-même). Un
  `pkill -f "Amspirit-Lite-SDL"` ne tue RIEN de réel — piège rencontré
  plusieurs fois cette session : je croyais relancer une instance
  fraîche alors que l'ancienne (déjà plantée) tournait toujours et
  répondait sur le même port, rendant tous les tests suivants inutiles
  jusqu'à ce que `ss -ltnp | grep <port>` révèle le vrai PID. Toujours
  vérifier ainsi avant de conclure qu'une relance a eu lieu.
- Bissection de breakpoints validée comme fiable SI et seulement si :
  (1) écriture confirmée relue avant tout `exec`, (2) `paused`
  confirmé stable avant d'armer un breakpoint, (3) un seul breakpoint
  actif à la fois, (4) `wait_paused_at` re-vérifié à chaque étape
  (`emu.paused AND PC==cible`, pas PC seul -- une instance qui tourne
  librement peut traverser une adresse sans jamais s'y arrêter).
