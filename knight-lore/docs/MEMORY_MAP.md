# Memory Map — état des connaissances

Convention : adresses en hex, 4 chiffres, vue CPU (`view=cpu`, banking
appliqué — c'est ce que voit le Z80). Statut : `confirmed` (vérifié par
désassemblage + exécution observée), `hypothesis` (déduit, pas encore
vérifié), `unknown`.

**Ce document couvre les toutes premières sessions d'investigation.
`docs/SYMBOLS.md` est désormais la source de vérité tenue à jour ; en
cas de désaccord entre les deux, `docs/SYMBOLS.md` a priorité.** Les
statuts encore marqués `hypothesis`/`unknown` ci-dessous ont été
revérifiés le 2026-08-14 : ceux qui étaient en réalité déjà résolus
ailleurs ont été corrigés directement (avec renvoi vers l'entrée
`docs/SYMBOLS.md` correspondante), les autres restent authentiquement
ouverts.

## Modèle de découpage mémoire global (observation grossière, confirmée par codemap sur le "code vs données")

Le jeu montre grosso modo 4 zones de mémoire cohérentes avec un rendu en
deux temps hérité du portage ZX Spectrum (mode "texte" du Speccy, absent
nativement du CPC, simulé via un buffer intermédiaire avant la vraie
VRAM). **Ce n'est PAS un découpage strict en 4 blocs de 16K nets** — le
buffer intermédiaire occupe cependant bien la totalité de son intervalle
apparent (`0x9000-0xBFFF`, confirmé par `fn_clear_intermediate_buffer`
qui l'efface intégralement, voir `docs/SYMBOLS.md` `0x2DB7`) :

```
0x0000-0x4000  CODE          — seule zone où le Z80 exécute des instructions
                                (confirmé : 0 exécution ailleurs sur 3s de jeu)
0x4000-0x8000  RESSOURCES    — sprites, catalogue d'objets, tables de room
0x8000-0x9000  PILE + TABLES — CONFIRMÉ (2026-08-09, vérif. live + désassemblage),
                                NE PAS confondre avec la ligne suivante :
                                pile Z80 active 0x80D6-0x8100 (SP init #8100),
                                puis 0x8100-0x8FFF = 15 tables de 256 octets
                                CALCULÉES AU BOOT (une seule fois, jamais
                                réécrites en jeu) par fn_build_pixel_bitscatter_tables
                                (#0829, code déjà présent en 0x0000-0x3FFF) —
                                tables masque/couleur consommées par fn_blit_masked
                                (rôle confirmé pour 14 des 15 tables, voir
                                docs/SYMBOLS.md #0829/#2F8D)
0x9000-0xC000  BUFFER TEXTE  — couche intermédiaire héritée du Speccy, CONFIRMÉ
                                à partir de 0x9000 (image pré-rendue de la
                                salle, largeur 64 octets — voir section 2 ci-après)
0xC000-0xFFFF  VRAM          — écran physique CPC (confirmé via CRTC R12/R13)
```

## Synthèse — pipeline de rendu (confirmé, voir détails ci-dessous)

Vue d'ensemble du moteur de rendu, une frame de jeu :

```
0x05AE  boucle "update" sur les 128 entités (tableau base 0x00D7, pas 0x1C=28 octets)
          ├─ sauvegarde position courante → "précédente" (+14..17 → +18..1B)
          └─ RST 28 (table 0x0676) : dispatch logique/IA par type d'entité
0x26F7  culling : filtre 40 entités (type≠0 ET flag actif) → buffer 0x2720 (par frame)
0x2DE2  boucle de rendu, pour chaque entité du buffer filtré :
          ├─ 0x2C22 : résout index → pointeur structure (28 octets/entité)
          ├─ bounding box écran (deux calculs symétriques, champs +14..1B)
          ├─ 0x3195 : (ligne,colonne) → adresse écran réelle (table 0x31B9)
          ├─ 0x1DC1 : efface l'ancienne empreinte (remplissage, loop unrolling)
          └─ [second mini-passage, mêmes adresses dépilées] :
               0x2EDC : PROJECTION ISOMÉTRIQUE (x+y, (y-x)/2) — CONFIRMÉ
               0x2F02 : résout (ix+00) → forme via table 0x429E
               0x31E9 : flip/miroir en place si orientation a changé
               0x2F17+ : sélection dynamique de variante de blit (patch de code)
               0x2F8D+ : BLIT MASQUÉ "mask-then-or" (écran = fond&masque | couleur)
               0x2EC0  : copie ligne par ligne vers l'écran (LDIR + entrelacement CRTC)
```

Détails, statuts et vérifications numériques/comportementales de chaque
étape dans les sections ci-dessous et dans
`notes/2026-08-06-rendering-engine.md`. Pièces encore manquantes :
contenu exact du template de `0x1188`, détail du dispatch logique/IA
(table `0x0676`, une seule entrée désassemblée pour l'instant : ce sera
la prochaine étape après avoir bouclé le rendu).

## Vecteurs / zone basse

| Range | Statut | Description |
|---|---|---|
| 0x0049–0x0054 | **RÉSOLU (2026-08-07, complété 2026-08-10)** | `fn_gate_array_config_stream` (voir `docs/SYMBOLS.md`) — écrit en boucle un flux d'octets (pointé par HL) vers le port Gate Array 0x7F00 jusqu'à un octet 0xFF, probable script de configuration GA. PAS lié à l'IM1 (celui-ci est désormais `fn_im1_interrupt_handler`, 0x0038, désassemblage complet disponible). Source des données (HL) RÉSOLUE 2026-08-10 : `fn_gate_array_palette_cycle` (#07EE, découverte en confirmant l'extent de `tbl_entity_logic_dispatch`) sélectionne un des 4 flux de `tbl_palette_stream_ptrs` (#07FD) selon `var_sparkle_and_jingle_phase` (#0073) et y saute. |

## Variables / RAM basse (zero-page-like, sous 0x0100)

| Addr | Statut | Description |
|---|---|---|
| 0x008C (word) | confirmed | Base d'une table de fonte/bitmap : utilisée dans la routine 0x170D comme `(0x008C) + a*8` pour indexer 8 octets par glyphe (`a` = code caractère/chiffre). Voir routine ci-dessous. |
| 0x007C | confirmed | Écrit par la routine 0x175F–0x1786 (copie depuis `(de)` avant chaque incrément `de`) — probablement le caractère courant en cours de traitement dans la boucle des 6 items du menu. |
| 0x007E | confirmed | Lu par la routine 0x175F juste après la boucle de 6 itérations ; si non-nul, `ret` immédiat (sélection déjà validée). Flag d'état du menu. |

## Routines identifiées

### 0x170D–0x174E — Déballage d'un glyphe (nibble source → octet 2bpp destination)

**Statut : confirmed — CORRIGÉ (2026-08-14) : réutilisé EN JEU aussi, pas
"menu uniquement" comme précédemment affirmé.** `fn_menu_glyph_unpack`
(0x170D) est bien le moteur de rendu de texte du menu, mais
`fn_hud_render_minifont_message` (0x158D, HUD en jeu) réutilise la même
queue de rendu (`JP #16F1`) en changeant juste la police active
(`var_glyph_table_base`) — donc la routine EST partagée entre menu et
HUD de jeu, l'ancien test négatif (breakpoint jamais déclenché en
bougeant le personnage) ne portait simplement pas sur le bon déclencheur.
Voir `docs/SYMBOLS.md` (`0x170D`, `0x158D`).

```
entrée: A = code caractère, index dans la police
util.: (0x008C) = base table source (fixée à 0x3294 par l'appelant menu)
       0x3186 calcule l'adresse destination = (source>>2) + 0x9000, dans
       le buffer de travail RAM bank 2 (0x8000-0xBFFF, hors écran)
sortie: 8 octets 2bpp écrits dans le buffer de travail (pas directement
        à l'écran)
```

### 0x3186 — Calcul d'adresse générique (HL>>2 + 0x9000)

**Statut : confirmed** (`fn_buffer_addr_from_vram`), rôle générique
confirmé : convertit une adresse VRAM en pointeur dans le buffer
intermédiaire de pré-rendu (`0x9000-0xBFFF`), utilitaire réutilisé dans
tout le pipeline de rendu. **CORRECTION (2026-08-14)** : la zone
`0x9000+` n'est PAS une table de données de room précalculées — c'est le
buffer de pré-rendu de la salle courante, reconstruit CHAQUE FRAME par
le pipeline de rendu (voir `docs/RENDERING_PIPELINE.md` et
`docs/SYMBOLS.md` section rendu). L'ancien test "256 octets identiques
avant/après un mouvement" était un faux négatif (fenêtre d'observation
trop courte/mal ciblée), pas une preuve de contenu figé.

```
HL = (HL >> 2) + 0x9000
```

### RST 08 (0x0008) — Addition 16-bit HL += A

**Statut : confirmed** par désassemblage direct.

```
0008  85         add    a,l
0009  6F         ld     l,a
000A  7C         ld     a,h
000B  CE00       adc    a,00
000D  67         ld     h,a
000E  C9         ret
```
Comble l'absence d'addition directe 16-bit+8-bit sur Z80. Choisi comme
`RST` (1 octet, rapide) plutôt que `CALL` car très fréquemment invoqué —
utilisé notamment dans 0x3195 pour l'indexation de table avec offset
variable. Les slots RST bas sont réutilisés par le jeu (pas par le
firmware CPC).

### 0x3195 — Calcul d'adresse écran CPC à partir de coordonnées (B,C)

**Statut : confirmed** par désassemblage direct + vérification de la
table de données en lecture RAM brute.

```
entrée: B = coordonnée ligne/Y (probable), C = coordonnée colonne/X (probable)
sortie: HL = adresse écran complète (dans 0xC000-0xFFFF)
```
Utilise une table de 24 entrées word à `0x31B9` :
`0x0730, 0x06E0, 0x0690, 0x0640, 0x05F0, 0x05A0, 0x0550, 0x0500, 0x04B0,
0x0460, 0x0410, 0x03C0, 0x0370, 0x0320, 0x02D0, 0x0280, 0x0230, 0x01E0,
0x0190, 0x0140, 0x00F0, 0x00A0, 0x0050, 0x0000` — progression exacte par
pas de 0x50 (80 décimal = largeur d'une ligne de caractère en Mode 1 CPC),
combinée avec l'octet haut `0xC0` pour retomber dans la zone écran (base
0xC000, confirmée par l'utilisateur via CRTC R12/R13). Le composant X
(paramètre C) est calculé directement (`C>>2 + 8`) sans table. Utilise
`RST 08` (= `rst_add_hl_a`, HL+=A, voir section dédiée ci-dessous).

### 0x2EDC-0x2F01 — Projection isométrique (coordonnées monde → écran)

**Statut : CONFIRMED (double vérification : calcul numérique exact +
test comportemental via ram_write, voir `notes/2026-08-06-rendering-engine.md`
section "CONFIRMÉ NUMÉRIQUEMENT ET VISUELLEMENT")**.

```
entrée: (ix+01), (ix+02) = coordonnées de grille (2 axes), (ix+03) =
        offset additif, (ix+12)/(ix+13) = offsets de calibration
sortie: (ix+16) = (ix+01)+(ix+02)-0x80+(ix+12)
        (ix+17) = ((ix+02)-(ix+01)+0x80)/2 + (ix+03)-0x68+(ix+13)
        carry set si (ix+17) < 0xC0 (visible/dans le champ)
```
Vérifié : valeurs réelles de l'entité 0 (joueur) — `(ix+01)=0x6E`,
`(ix+02)=0x80`, `(ix+12)=0xF4`, `(ix+13)=0xF9` → calcul donne exactement
`(ix+16)=0x62`, `(ix+17)=0x5A` (valeurs observées en RAM). Test
comportemental : `ram_write` sur `(ix+01)` (+0x10) pendant que le
personnage est visible → déplacement diagonal observé à l'écran (jamais
un axe pur) — signature caractéristique d'une vraie projection
isométrique. **Entité ID=0 identifiée comme le joueur** (liste `0x2720`
change de contenu selon l'input, bit 7 du premier octet = flag actif).

### Structure d'entité — dump complet vérifié (entité 0 = joueur, base 0x00D7)

| Offset | Valeur observée | Rôle |
|---|---|---|
| +00 | 0x32 | Type/ID de sprite (indexe la table 0x429E) |
| +01 | 0x6E | Coordonnée de grille A (axe combiné par somme) |
| +02 | 0x80 | Coordonnée de grille B (axe combiné par somme/diff) |
| +03 | 0x80 | Offset additif du 2e axe projeté |
| +07 | 0x0C | Flags (bit 5 = "à effacer/dessiner ce tour", bit 4 = autre) |
| +12 (0x12) | 0xF4 | Offset de calibration, axe 1 |
| +13 (0x13) | 0xF9 | Offset de calibration, axe 2 |
| +14 (0x14) | — | Bounding box courante, dimension 1 |
| +15 (0x15) | — | Bounding box courante, dimension 2 |
| +16 (0x16) | 0x62 | Position écran projetée, axe 1 (résultat 0x2EDC) |
| +17 (0x17) | 0x5A | Position écran projetée, axe 2 (résultat 0x2EDC) |
| +18-1B (0x18-0x1B) | = copie de +14-17 | Valeurs de la frame précédente (pour effacement) |

**Rappel important** : ces offsets sont en HEXADÉCIMAL (`+12` = 0x12 =
18 décimal), piège rencontré et corrigé pendant la vérification.

### 0x2720 — Buffer d'entités PAR FRAME (pas une liste statique de niveau)

**Statut : confirmed.** Contenu change avec l'input (bit 7 du premier
octet) — c'est un buffer de travail reconstruit chaque frame par
`fn_cull_entities` (0x26F7, voir section dédiée ci-dessous), pas une
table figée de niveau.

### 0x2EC0 — Routine de dessin (blit par copie LDIR)

**Statut : confirmed.** Contrairement à 0x1DC1 (remplissage constant),
copie un bloc source→écran via `LDIR`, avec la même gestion
d'entrelacement CRTC (+0x0800/+0xC050). Appelée dans un second
mini-passage après la boucle d'effacement principale, en réutilisant les
adresses déjà calculées (empilées via PUSH pendant le premier passage) —
optimisation évitant un second parcours complet de la liste d'entités.

### 0x2C22 — Indexation dans le tableau d'entités (CONFIRME 28 octets/structure)

**Statut : confirmed** par calcul. `HL = (ID & 0x7F) × 28 + 0x00D7`.
Défait comme `×8, ×16(+×8=×24), ×4(+×24=×28), +0x00D7`. Cohérent avec le
plus grand offset observé (+1B = 27 < 28).

### 0x2F02 — Résolution de forme (table de dispatch par type de sprite)

**Statut : confirmed** par désassemblage direct. `(ix+00)` = type/ID,
indexe une table de pointeurs word à `0x429E` (un pointeur par type
d'entité : joueur, blocs, objets...). Plusieurs entrées consécutives
partagent le même pointeur ou pointent vers des zones voisines
(0x6C86,0x6CE9,0x6C86,0x6C23 — motif quasi-symétrique) — cohérent avec
la logique de flip décrite ci-dessous : les "variantes" ne sont pas
toujours des sprites indépendants, mais des orientations d'une même forme.

### 0x31E9 — Flip/miroir de sprite en place (économie de stockage)

**Statut : confirmed — désassemblage intégral, mécanisme et sens des
deux bits vérifiés.** Bit 7 = flip VERTICAL (échange de lignes entières
du bitmap) ; bit 6 = flip HORIZONTAL réel (échange d'octets + miroir
bit-à-bit par nibble via `fn_mirror_byte_bits`, 0x3265). Si le bit
testé diffère du marqueur d'orientation stocké dans le premier octet de
la forme, inverse ce bit ET mute le bitmap en place. **Confirmé le
2026-08-14 par reproduction bit-exacte** : l'algorithme réimplémenté et
appliqué à une forme figée reproduit exactement le contenu RAM d'un
sprite ayant réellement été flippé en jeu. **Économie de mémoire clé** :
le jeu ne stocke qu'une forme de base par sprite et la flippe en place
selon l'orientation requise, plutôt que de dupliquer les données pour
chaque orientation — explique les motifs de pointeurs répétés/voisins
dans la table 0x429E. Voir `docs/SYMBOLS.md` (`0x31E9`, `0x3265`).

### RST 28 (0x0028) — Dispatch générique par table (JP indirect calculé)

**Statut : confirmed** par désassemblage direct.

```
HL = L×2 + BC (BC = base de table, passée par l'appelant)
JP (HL)  (lit un pointeur dans la table et y saute)
```
Primitive de dispatch générique — même forme que `0x2F02` mais avec la
base de table en paramètre. Utilisée depuis la boucle principale de
frame avec `BC=0x0676` (table de LOGIQUE/IA par type d'entité, pendant
de la table de RENDU `0x429E`) et `L=(ix+00)` (type de l'entité).

### 0x26F7 — Passe de culling/filtrage (remplit le buffer 0x2720)

**Statut : confirmed** par désassemblage direct. Parcourt les 40
premières entités du tableau (sur 128 au total), retient celles dont
`(ix+00)≠0` (type non-nul) ET bit 4 de `(ix+07)` actif (flag de
visibilité/appartenance à la room courante), écrit leurs index dans le
buffer `0x2720` terminé par `0xFF`. Ce buffer est ensuite consommé par
la boucle de rendu `0x2DE2` — **reconstruit chaque frame**, pas une liste
statique de niveau.

### Boucle principale de frame (0x05AE-0x0620) — structure globale confirmée

**Statut : confirmed** par désassemblage direct, contexte le plus large
obtenu. Ordre des opérations par frame :
1. Pour chaque entité (40 slots réels, tableau base 0x00D7, pas 28 octets) :
   sauvegarde position courante → "précédente" (+14..17 → +18..1B),
   dispatch logique/IA via `RST 28` (table 0x0676 selon le type),
   mise à jour d'un accumulateur pseudo-aléatoire basé sur le registre R
   (technique 8-bit classique pour du hasard sans générateur matériel).
2. Incrément d'un compteur global de frame `(0x006A)`.
3. `fn_arm_interrupt_flag` (0x0D79), `fn_wait_keyboard_sync` (0x2D6D),
   `fn_melkhior_room_spawn_check` (0x1188) — tous confirmés, voir
   `docs/SYMBOLS.md`.
4. Culling (`0x26F7`) → remplit `0x2720`.
5. Rendu (`0x2DE2`) → efface + dessine chaque entité filtrée.

Structure de boucle de jeu classique (update logique → culling → rendu).

## COLLISION — 0x2750, boucle imbriquée AABB 3D + dispatch

**Statut : confirmed**, structure ET interprétation métier des
gestionnaires — désassemblage intégral, y compris la table de dispatch
elle-même (transcrite le 2026-08-14, 27 entrées, pas ~30).

- **Boucle imbriquée** sur le buffer `0x2720` (le MÊME buffer par-frame
  que le culling de rendu — la collision ne teste que les entités déjà
  filtrées comme actives/visibles ce tour). IX = entité externe, IY =
  entité interne, skip si IX==IY.
- **Calcul d'un code de collision AABB 3D** (`0x278D-0x27F7`) : compare
  les bounding boxes sur 3 paires de champs `(ix+01)/(ix+04)`,
  `(ix+02)/(ix+05)`, `(ix+03)/(ix+06)` — poids ±1/±3/±9 (base 3).
- **`tbl_collision_dispatch`** (`0x27FE`, via `RST 28`, 27 entrées) → 3
  gestionnaires partagés (`0x2834`/`0x2837`/`0x283A`).
- **Mécanisme "détection deux fois avant traitement"** : première
  détection → enregistre la paire dans `tbl_collision_pending` (`0x28AF`,
  terminée par 0xFF) et échange IX/IY pour continuer ; deuxième
  détection de la même paire → traite la collision pour de bon
  (`0x2863`), rebranche sur dessin (`0x2898`) ou fin de buffer (`0x2758`).
- **`0x2876` (`fn_collision_effect`)** : si `(type-0x60) < 7` (7
  variantes de pickup 0x60-0x66), force le type à `0xBB` (ramassé) puis
  reprend directement le corps de boucle (`jp #2770`) — CONFIRMÉ, pas
  une hypothèse.

Voir `docs/SYMBOLS.md` (`0x2750`, `0x27FE`, `0x2834`, `0x2876`,
`0x28AF`) pour le détail complet.

## INIT ROOM/NIVEAU — 0x29B4-0x2A97

**Statut : confirmed**, désassemblage ET rôle métier — `fn_init_room`
(0x2A68) et son écosystème complet (`fn_load_room_data`,
`fn_instantiate_room_objects`, `fn_room_transition`,
`fn_init_room_mark_room_visited`) sont intégralement désassemblés et
documentés.

- **`0x29B4`** (`fn_init_room_entities`) : copie un template de 56 octets
  (`tbl_init_entities_template`, 0x29EB, 2×28 = 2 structures d'entité)
  vers la base du tableau `0x00D7` — réinitialise joueur + compagnon.
- **`0x2A68`** (`fn_init_room`) : si transition en cours, resynchronise
  le catalogue d'objets ; efface le buffer intermédiaire ; charge la
  salle ; instancie objets + jonctions porte/mur ; remet les flags de
  reset à 0 ; **positionne `var_render_disabled_flag` (0x007D) = 1**
  (désactive le rendu pendant la (re)matérialisation — réactivé par
  `fn_render_disabled_one_time_setup`, 0x062F, une fois par frame de
  matérialisation) ; marque la salle courante visitée dans
  `var_room_visited_bitmap`.

Voir `docs/SYMBOLS.md` (`0x2A68`, `0x29B4`, `0x062F`, `0x00B7`) pour le
détail complet.

## LOGIQUE DU JOUEUR — 0x20CB (`fn_player_logic`, types 0x12/0x14)

**Statut : confirmed** — désassemblage intégral et rôle métier de
`fn_player_logic` et de tout son écosystème direct
(`fn_read_input`/0x28B7, `fn_player_use_held_object`/0x18AA,
`fn_player_jump_trigger`/0x21F0, `fn_player_walk_animation_cycle`/0x2214,
`fn_player_gravity_and_door_dispatch`/0x2253, `fn_get_orientation_code`/
0x22D0, `fn_player_in_view_bounds`/0x2122).

- **`0x2122`** (`fn_player_in_view_bounds`) : test des limites visibles.
- **Origine de la direction saisie** : `fn_read_input` (0x28B7) lit 3
  lignes de la matrice clavier CPC via `fn_read_keyboard_line` (0x0ED3)
  en mode clavier, ou 5 tables de masques (lignes+bits) en mode joystick
  via `fn_read_joystick_table` (0x2946) — les deux convergent vers le
  même résultat stocké à `var_input_result` (0x007B).
- **`0x22D0`** (`fn_get_orientation_code`) : résout un code d'orientation
  2 bits en combinant le bit 4 de `(ix+07)` ET le bit 3 de `(ix+00)` —
  l'orientation du personnage est bien encodée à cheval sur deux champs
  distincts (type de sprite + flag), pas un seul octet dédié.

Voir `docs/SYMBOLS.md` (`0x20CB`, `0x28B7`, `0x22D0`) pour le détail
complet.

### 0x1DC1 — Effacement rectangulaire par déroulage de boucle

**Statut : confirmed** par désassemblage direct intégral, y compris le
mécanisme d'auto-modification de l'opérande de déroulage (0x1DD6).

```
entrée: A = octet à écrire, B = hauteur (lignes), C = largeur effective,
        HL = adresse de départ
```
Remplit un rectangle jusqu'à 12 octets de large par ligne (séquence
`LD (HL),A / INC HL` répétée 12×, avec un saut d'entrée dans la séquence
ajusté dynamiquement selon B pour gérer des largeurs < 12 sans dupliquer
le code), `DE` = pas entre lignes (dépend de B), boucle sur B lignes via
`DJNZ`. Technique de blitting 8-bit classique (loop unrolling + entrée
variable), cohérente avec un portage assez fidèle du code ZX Spectrum
d'origine.

### 0x16E5–0x170D — Afficheur de chaîne de caractères

**Statut : confirmed.**

```
entrée: DE = pointeur vers une chaîne de caractères, terminée par un
             octet dont le bit 7 est positionné (convention ZX Spectrum)
boucle: lit un octet ; si bit7=0, CALL 0x170D (rend le glyphe), continue ;
        si bit7=1, AND 0x7F puis rend le dernier glyphe et sort (RET,
        implicite en fin de 0x170D)
```
Chaque appel à 0x170D fixe d'abord `(0x008C)=0x3294` (base police) et
calcule l'adresse destination via `CALL 0x3186` avant de déballer le
glyphe.

### 0x3186 — Calcul d'adresse destination (buffer de travail)

**Statut : confirmed** (désassemblage direct, vérifié par calcul :
0x9F58 → 0xB7D6).

```
HL = (HL >> 2) + 0x9000
```
Divise par 4 l'adresse source pour obtenir l'adresse dans le buffer de
travail (cohérent avec un ratio 4:1 entre l'espace source 4bpp/nibble et
la destination 2bpp).

### 0x174F–0x175E — Remplissage conditionnel (curseur / surbrillance ?)

```
entrée: A (si 0 → remplit HL avec 0xFF ; sinon boucle A fois en remplissant
        avec 0x0F puis en décrémentant A, avec inc HL à chaque tour)
```
Hypothèse : dessine un curseur/barre de sélection plein (0xFF) ou dégradé/
pointillé (0x0F répété) — cohérent avec un menu qui met en surbrillance
l'option sélectionnée.

### 0x175F–0x1786 — Boucle des 6 options du menu

**Statut : confirmed** — désassemblage direct intégral (fonction sans
nom individuel, entre `fn_control_mode_menu_palette_indicator_update`
0x1662 et `fn_menu_draw_string_reset_font` 0x16DA). `B=6` : boucle sur 6
icônes de méthode de contrôle, lit une table de pointeurs (avec
indirection `PUSH/POP HL` pour dérouler un pointeur de pointeur — pattern
confirmé, pas une erreur de lecture) et appelle `fn_menu_draw_string_reset_font`
pour chacune. `(0x007E)` non-nul en sortie de boucle = sélection déjà
validée (RET immédiat). Seul point encore ouvert : le contenu texte exact
de `tbl_menu_or_status_data` (0x167B, référencée juste avant cette
boucle) — le glyphe→caractère de ces messages n'est pas décodé. Voir
`docs/SYMBOLS.md` (`0x167B`, `0x1662`).

## Zones de code détectées dynamiquement (codemap, pendant l'attente au menu)

**Toutes les grappes listées ici à l'origine (`0x0049-0x0054`,
`0x0D84-0x0DE1`, `0x0ED3-0x0EE5`, `0x15E8-0x1786`, `0x3186-0x3195`) sont
désormais intégralement désassemblées et nommées** — voir
`docs/SYMBOLS.md`. Cette section n'a plus d'usage propre, conservée pour
mémoire de la méthode (codemap dynamique pendant l'attente au menu comme
premier terrain d'exploration).

## À faire ensuite

Toutes les actions listées ici à l'origine sont résolues et documentées
dans `docs/SYMBOLS.md`/`docs/SESSION_SUMMARY.md`. Pour la suite des
travaux, voir `docs/SESSION_SUMMARY.md` section "Pistes ouvertes pour la
prochaine session".
