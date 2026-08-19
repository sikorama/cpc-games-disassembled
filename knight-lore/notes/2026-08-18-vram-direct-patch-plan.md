# Piste 3 (dessin direct VRAM) — plan et état d'avancement

Branche : `vram-direct-experiment`. Objectif : `docs/OPTIMISATION.md` §4
(piste 3) — supprimer le buffer intermédiaire `#9000-#BFFF` pour libérer
cette zone à du code neuf. `asm/` sur `main` reste la désassemblage fidèle
intacte ; cette branche est l'espace d'expérimentation.

## Découverte clé : un seul point de rendu partagé

`fn_sprite_pipeline_setup` (`#2F17`) + `fn_blit_masked` (`#2F8D`) sont **le
seul** chemin de dessin de sprite/icône dans tout le jeu — pas seulement
les entités. Les points d'entrée alternatifs suivants y retombent tous
(entrée `#2F2B`, après la projection isométrique) :

- Entités : `fn_check_collisions` → `fn_sprite_pipeline_setup` (`#2F17`)
- HUD jour/nuit : `fn_hud_day_night_cycle` (`code/pickups_and_transform.asm:411,417,420`)
- HUD bonus vie + icône jour/nuit (partagées) : `fn_hud_icon_redraw_8x4`
  (`code/pickups_and_transform.asm:457`)
- Notification slot objet : `fn_hud_slot_notification`
  (`code/menu_and_materialize.asm:195`, appelle `#2F2B` en `:238`)

Donc migrer `fn_sprite_pipeline_setup`/`fn_blit_masked` migre TOUS ces
appelants d'un coup — pas besoin de traiter chaque fichier séparément pour
le dessin lui-même. Reste spécifique à chaque appelant : le **clear**
(`fn_fill_rect`) et la **copie différée** (`fn_blit_copy_line`), chacun
avec ses propres call sites (4 groupes, voir grep ci-dessous).

Call sites bruts (`fn_fill_rect` / `fn_buffer_addr_from_vram` /
`fn_blit_copy_line`) :
- `rendering_pipeline.asm:231,239,267,413` (entités + sprite_pipeline_setup)
- `menu_and_materialize.asm:229,232,247,252` (`fn_hud_slot_notification`)
- `pickups_and_transform.asm:410,427,460,466,468` (HUD jour/nuit + icône partagée)
- `entity_logic_mechanical.asm:1070,1092` (à identifier — pas encore lu en détail)

## Piège générique rencontré (à noter dans METHODOLOGY.md si confirmé récurrent)

**Raccourcir/allonger une routine décale tout ce qui suit dans le même
fichier jusqu'au prochain `org` explicite.** Dans ce projet, chaque fichier
`asm/code/*.asm` généré par `gen_asm.py` porte un seul `org` en tête et
couvre une plage large (`rendering_pipeline.asm` = `#2D5E-#3185`, onze
routines) — modifier UNE routine au milieu déplace toutes les suivantes
dans le même fichier. Inoffensif pour les références symboliques (labels,
recalculées automatiquement par l'assembleur), **mais casse silencieusement
les adresses littérales codées en dur** utilisées par le jeu pour du code
auto-modifiant (ex. `ld (#30AF),a`, `#2F8B`, `#311F` dans
`fn_sprite_pipeline_setup`/`fn_blit_masked`) — l'assembleur ne signale
aucune erreur, le jeu plante/corrompt silencieusement à l'exécution.

Vérifié concrètement ici : remplacer le bloc inline de `fn_blit_copy_line`
(10 octets) par un `call fn_vram_advance_line` (5 octets) a décalé
`fn_isometric_project` de `#2EDC` à `#2ED6` (confirmé par export symboles
`rasm -s`), ce qui aurait décalé aussi `fn_sprite_pipeline_setup`/
`fn_blit_masked` et rendu caduques leurs pokes littéraux. **Solution
appliquée** : `nop`-padding pour préserver la longueur exacte tant que la
routine n'est pas complètement relocalisée. Solution définitive pour toute
routine qu'on veut vraiment raccourcir : soit compléter par du padding,
soit **relocaliser entièrement la routine (et tous ses appelants) dans la
zone `#9000+` libérée**, ce qui élimine le problème puisque le code
original reste inchangé sur place (mort mais inoffensif) et le nouveau
code vit dans un fichier `org`é indépendamment.

## Fait à ce stade (commit sur cette branche)

- `asm/code/vram_direct_rendering.asm` (NEUF, `org #9000`) :
  - `fn_vram_advance_line` : avance CRTC-aware (+0x0800, correction +0xC050
    sur carry — mécanisme déjà utilisé identiquement par `fn_clear_screen`
    ET l'ancien `fn_blit_copy_line`, donc **confirmé**, pas une hypothèse).
  - `fn_vram_fill_rect` : variante de `fn_fill_rect` opérant directement en
    VRAM au lieu du buffer. **PAS ENCORE BRANCHÉE** — voir point ouvert
    ci-dessous.
- `fn_blit_copy_line` (`rendering_pipeline.asm`) refactorisée pour appeler
  `fn_vram_advance_line` au lieu de dupliquer le calcul inline —
  comportement inchangé, vérifié par diff mémoire complet (rasm `-oi`
  avant/après, 65536 octets comparés octet-à-octet) : seuls
  `#2EC8-#2ED2` (le corps de la routine elle-même) et `#9000-#9041` (code
  neuf, pas encore atteignable) diffèrent. Tout le reste du jeu est
  byte-identique.

## Point ouvert — bloquant avant de brancher `fn_vram_fill_rect`

`fn_stage_blit_and_clear` (`#2E6C`) calcule une adresse VRAM via
`fn_screen_addr_from_bc` puis la pousse pour la copie différée finale. Pas
réussi à déterminer par lecture statique seule si cette adresse correspond
au coin **haut** ou **bas** du rectangle sale (l'arithmétique de bbox en
amont dans `fn_render_entities`, #2DF5-#2E97, mélange plusieurs
ajustements +L-1/clipping qui rendent la direction ambiguë sans trace
live). Nécessaire avant de brancher `fn_vram_fill_rect` : une trace live
(lire BC/DE à l'entrée de `fn_stage_blit_and_clear` et juste après
`fn_screen_addr_from_bc`, comparer à la position connue d'une entité à
l'écran) pour confirmer le sens d'avance (vers le bas = OK direct avec
`fn_vram_advance_line` tel qu'écrit ; vers le haut = il faudra une variante
"avance vers le haut", pas encore écrite).

## Tentative de branchement (2026-08-18, après-midi) — ÉCHEC, révélateur

Branché `fn_vram_fill_rect` dans `fn_stage_blit_and_clear` via
`fn_stage_clear_vram_and_buffer_addr` (clear direct VRAM AJOUTÉ en plus du
chemin buffer existant, censé être inoffensif/redondant — voir raisonnement
initial ci-dessus). **Plante en jeu réel** : trace live après chargement
d'une salle montre le CPU tournant en boucle entre `#0039` (handler IM1) et
`#90A0`-ish, et une lecture RAM de `#9000+` montre du contenu qui n'a plus
aucun rapport avec le code assemblé (`00 ff ee 11 00...`) — nos routines à
`#9000` ont été **écrasées**.

**Cause identifiée, pas une hypothèse** : `fn_clear_intermediate_buffer`
(`code/rendering_pipeline.asm`, appelée par `fn_init_room` à CHAQUE
chargement de salle) fait `ld bc,#3000 / ld hl,#9000 / jr fn_mem_fill_simple`
— un remplissage inconditionnel de **tout** `#9000-#BFFF` à zéro, qui
écrase donc n'importe quel code qu'on y aurait posé, indépendamment de
savoir si `fn_blit_masked` écrit aussi par-dessus dynamiquement (lui aussi
vrai, mais même sans lui ce clear seul suffit à tout détruire).

**Conclusion qui invalide le plan de migration incrémentale envisagé plus
haut** : il n'existe **aucune sous-partie sûre** de `#9000-#BFFF` où loger
du code neuf tant que `fn_clear_intermediate_buffer` ET `fn_blit_masked`
(adressage dynamique, peut cibler n'importe quel octet de la zone selon la
position à l'écran) n'ont pas TOUS LES DEUX cessé d'utiliser cette zone
comme buffer. Pas de "on migre le clear, on teste, puis on migre le dessin" :
le clear seul du prochain chargement de salle détruit tout ce qu'on a posé
avant même d'avoir pu tester quoi que ce soit. **Piège générique à noter
dans `docs/METHODOLOGY.md`** : avant de réutiliser une zone RAM libérée
pour du code neuf, vérifier qu'AUCUN écrivain (même partiel/occasionnel,
même juste un memset au chargement) ne cible encore cette zone comme
donnée — un seul écrivain restant suffit à rendre TOUTE la zone inutilisable
pour du code, pas seulement la portion qu'il touche effectivement.

**Reverté** (branchement dans `fn_stage_blit_and_clear` annulé, code de
`fn_vram_fill_rect`/`fn_vram_advance_line`/`fn_stage_clear_vram_and_buffer_addr`
conservé mais non appelé) pour ne pas laisser la branche dans un état qui
plante. Prochaine étape réaliste : migrer `fn_clear_intermediate_buffer`
ET `fn_blit_masked`/`fn_sprite_pipeline_setup` (tous les appelants, voir
"découverte clé" plus haut) dans le MÊME changement atomique avant de
pouvoir poser quoi que ce soit à `#9000+` -- pas de raccourci possible.

## Deuxième tentative (2026-08-18, fin d'après-midi) — RÉUSSIE

`#9000+` a été abandonné comme emplacement pour le code neuf (voir échec
ci-dessus). Nouvel emplacement : **`#8100-#81FF`**, la table "nibble
dupliqué" construite au boot par `fn_build_pixel_bitscatter_tables`
(`code/dispatch_and_sound.asm`, bloc de 26 octets `#0854-#086E`) —
confirmée sans aucun lecteur dans tout le jeu (voir `docs/SYMBOLS.md`
`#0829`/`#2F8D`). Ce bloc de construction a été neutralisé en `nop` (26
octets remplacés par 26 `nop`, longueur identique, aucun décalage
d'adresse). Contrairement à `#9000-#BFFF`, rien n'écrit plus jamais dans
cette zone une fois le boot terminé — donc contrairement à la tentative
précédente, le code y reste intact en permanence, y compris à travers les
chargements de salle.

Bug trouvé et corrigé pendant la validation : direction d'avance de
`fn_vram_fill_rect` inversée (calcul à la main erroné — voir commentaires
dans `code/vram_direct_rendering.asm`). Après correction (réutiliser
directement le coin BAS déjà calculé par l'appelant, comme le fait déjà
`fn_blit_copy_line`, plutôt que recalculer un coin haut), **validé en jeu
réel** : rectangles sales correctement positionnés, plus de plantage.
Confirmé aussi que `#8100-#81FF` n'est pas de la zone sprite (sprites en
`#4000-#8000` par `docs/MEMORY_MAP.md`) — le défaut d'affichage HUD
constaté n'est probablement pas lié à cet emplacement.

**Statut actuel (committé par l'utilisateur)** : le clear direct VRAM
fonctionne et est validé, mais reste redondant — `fn_blit_masked` dessine
toujours dans le buffer intermédiaire, et `fn_blit_copy_line` copie
toujours ce buffer vers la VRAM à chaque frame (confirmé par heatmap
d'écriture RAM côté utilisateur : trafic constant sur `#9000-#BFFF`).
Aucun gain de performance ni de RAM encore obtenu — cette étape ne
validait que la mécanique d'adressage VRAM directe.

## Prochaine étape (pas commencée) — migrer fn_blit_masked

C'est le morceau qui reste pour vraiment supprimer le buffer et libérer
`#9000-#BFFF` en entier (nécessaire aussi pour loger plus de code que les
256 octets de `#8100-#81FF`, ex. le double buffer piste 4 plus tard).

`fn_blit_masked` (`#2F8D`, ~600 lignes de source) : deux familles
d'entrées dispatchées par largeur (décalage sub-octet, 18 octets/entrée,
`#2F8D-#30BA` ; alignée-octet, 10 octets/entrée, `#30BB-#31E8`), chacune
un déroulement "duff device" par largeur (pas de boucle runtime sur les
colonnes, l'entrée est choisie par adresse calculée). Point commun trouvé
mais PAS ENCORE COMPRIS : `loc_30AD` (partagé par les deux familles) fait
la boucle sur les LIGNES (compteur dans `AF'`, décrémenté, `jp nz` vers
`loc_2F89` qui redispatche vers la même entrée de largeur) et avance `BC`
de **`#3A` (58)** entre deux lignes.

**Incohérence trouvée avec `docs/SYMBOLS.md`** (entrée `#2F8D`) : ce
document dit `+0x36 (54)`, le code réellement généré (donc lu depuis une
RAM réelle) dit `#3A (58)`. Ni l'un ni l'autre ne correspond à la largeur
de ligne du buffer (64) — accroche encore non comprise, à investiguer
avant de toucher quoi que ce soit ici (probablement lié à l'axe diagonal
de la projection isométrique, pas un simple stride horizontal). **Ne pas
corriger `docs/SYMBOLS.md` avant d'avoir compris pourquoi**, seulement
noter l'écart pour l'instant.

**Décision d'architecture (2026-08-18, suite à discussion)** : migrer
`fn_blit_masked` vers `#9000+` supposerait la zone déjà libre -- or elle
ne l'est que si `fn_blit_masked` a déjà été migré (œuf et poule, cf.
l'échec de la tentative n°1 avec le clear). Solution retenue : **réécrire
les 32 entrées déroulées (16 largeurs × 2 familles, "duff device", ~448
octets) en deux vraies boucles runtime paramétrées par la largeur,
EN PLACE** (mêmes adresses `#2F8D-#31E8`, pas de relocalisation). Une
boucle est mécaniquement bien plus petite que son déroulement -- la place
récupérée sur place suffit à ajouter la logique d'avance CRTC-aware, sans
toucher à `#9000` du tout. Coût accepté : plus lent (overhead de boucle
par colonne) qu'un déroulement, mais correct et non bloqué -- ré-enroulable
plus tard comme passe d'optimisation séparée une fois le moteur
direct-VRAM stable partout.

Avant de patcher : comprendre precisement à quoi correspond ce `#3A`,
idéalement par trace live (comparer l'adresse BC avant/après un passage
par `loc_30AD` pour une entité de largeur/hauteur connues, comme on l'a
fait pour `fn_stage_blit_and_clear`) plutôt que par calcul à la main
seul — deux erreurs de calcul à la main ont déjà été commises cette
session (direction d'avance, et l'hypothèse initiale sur la zone #9000).

## Prochaines étapes (plan général, inchangé)

1. Trace live pour lever l'ambiguïté ci-dessus (nécessite émulateur).
2. Une fois confirmé : brancher `fn_vram_fill_rect` dans
   `fn_stage_blit_and_clear` (clear direct, plus besoin de calculer/pousser
   l'adresse buffer pour le clear).
3. Migrer `fn_sprite_pipeline_setup`/`fn_blit_masked` (adressage direct VRAM
   + avance CRTC-aware dans les ~18 entrées de dispatch par largeur) — le
   plus gros morceau, migre tous les appelants HUD/entités d'un coup (voir
   section "découverte clé").
4. Supprimer la mécanique de pile différée (`var_blit_stack_counter`,
   `fn_blit_copy_line`, les push/pop BC/DE/HL) une fois clear+draw
   entièrement directs — plus aucun appelant n'en aura besoin.
5. Mettre à jour `docs/MEMORY_MAP.md`/`RENDERING_PIPELINE.md` pour refléter
   le nouveau pipeline, une fois validé en jeu.

## RÉSOLU (2026-08-19) — le `#3A` n'est pas une constante

Le "stride" de `loc_30AD` est un **opérande auto-modifiant**, réécrit à
chaque appel. Vérifié sur le binaire réassemblé (`rasm -s`, dump des
octets), pas par calcul à la main :

```
#30AD..#30BA : 79  C6 3A  4F  78  CE 00  47  08  3D  C2 89 2F  C9
               ↑   ↑  ↑
          ld a,c    |  +-- #30AF = OPERANDE de ce add
                    +----- add a,imm8
```

et `ld (#30AF),a` se trouve à `#2F34` (recherche d'octets `32 AF 30`
dans le binaire, occurrence unique sur `#2F00-#3200`).

Valeur pokée (`fn_sprite_pipeline_setup`, juste après
`fn_resolve_sprite_shape`) : `ld a,(de) / and #3F / cpl / add a,#41`
= `320 - w` mod 256 = **`64 - w`**, avec `w = (octet_forme & 0x3F)`.

Chaque unité déroulée contient exactement UN `inc c` (vérifié sur les
deux familles : 18 o/unité et 10 o/unité). Le nombre d'unités exécutées
vaut `w` (point d'entrée = base + taille_unité × ((-w) & 15)). Donc par
ligne : `BC += w` (colonnes) puis `BC += 64 - w` (loc_30AD)
= **64 exactement**, la largeur de ligne du buffer intermédiaire.

Les deux valeurs "contradictoires" étaient deux photos de la même
variable : `#3A`=58 -> w=6 ; `0x36`=54 (docs/SYMBOLS.md) -> w=10.
**Aucun des deux documents n'avait tort** — `docs/SYMBOLS.md` est à
reformuler (dire "stride auto-modifié = 64-largeur", pas une constante),
pas à "corriger".

**Piège générique pour `docs/METHODOLOGY.md`** : un octet lu dans un dump
RAM qui tombe dans le CHAMP OPÉRANDE d'une instruction peut être une
variable et non une constante. Deux dumps qui semblent se contredire sur
une telle valeur en sont le symptôme, pas une erreur de lecture : avant
de trancher, chercher un `ld (adresse_de_l_operande),a` ailleurs dans le
code (recherche d'octets `32 lo hi`).

### Conséquence : la "décision d'architecture" du 2026-08-18 tombe

Réécrire les 32 entrées déroulées en boucles runtime n'est PLUS
nécessaire pour faire de la place :

- horizontalement la VRAM CPC est linéaire, `inc c` fonctionne à
  l'identique -> **les 32 blocs déroulés restent inchangés** ;
- le SEUL endroit qui doit devenir CRTC-aware est `loc_30AD`
  (`#30AD-#30BA`, 14 octets), **partagé par les deux familles** — le poke
  de `#2F34` a lieu AVANT le `jp z,loc_30BB`, donc il sert bien les deux
  (le commentaire source "utilisé par la variante aligné-octet" est
  imprécis, à corriger) ;
- remplacer `BC += (64-w)` par "reculer BC de w, puis avance CRTC-aware"
  tient dans 14 octets via un `call` (3 o) vers `#8100+` — aucun
  déplacement de code, donc aucun poke littéral invalidé ;
- le sens concorde : `+64` dans le buffer = vers le HAUT à l'écran (flip
  Y, `RENDERING_PIPELINE.md` §8.2) et `fn_vram_advance_line` (+0x800)
  monte aussi.

Reste à faire côté appelant : ne plus convertir l'adresse VRAM en
adresse buffer (`call fn_buffer_addr_from_vram` à `#2F7C` dans
`fn_sprite_pipeline_setup`) et passer directement l'adresse VRAM dans
BC. `H` (page de table `#82`-`#8C`) n'est pas concerné.

## Validation du point 2 (2026-08-19) — adresse d'entrée de fn_blit_masked

Méthode : réimplémentation de `fn_screen_addr_from_bc` (#3195) +
`tbl_screen_line_base` en Python, puis vérification exhaustive — pas de
calcul à la main (c'est ce qui manquait aux deux erreurs de direction).

**Contrôle de la réimplémentation** : elle reproduit EXACTEMENT les deux
valeurs relevées en jeu réel le 2026-08-18 (`#FB45` pour B=104, `#F345`
pour B=105, avec C=116). La dérivation statique est donc fiable.

Résultats :

1. **`screen_y` est un axe BAS->HAUT** : `y=0` donne `#FF30`, soit la
   ligne raster **191** (le bas de l'écran) ; `y=191` donne le haut.
   C'est la raison d'être du `cpl` dans `fn_screen_addr_from_bc` et du
   tableau `tbl_screen_line_base` décroissant. Ce n'est donc PAS un
   "flip Y du buffer" : l'inversion est dans la convention de
   coordonnées elle-même.
2. **`y -> y+1` vaut `-0x800`** (168 cas) **ou `+0x37B0`** (23 cas, aux
   franchissements de bande de 8 lignes). Vérifié sur les 191 lignes.
3. `fn_vram_advance_line` (+0x800 / +0xC050) réalise **`addr(y) ->
   addr(y-1)`** — vérifié sur les 191 lignes. C'est le bon sens pour
   `fn_vram_fill_rect` (qui part du coin `y+h-1` calculé par
   `fn_stage_blit_and_clear` et descend), ce qui explique pourquoi le
   clear direct fonctionne en jeu.

**Conséquence — le blit a besoin du sens INVERSE.** À l'entrée de
`fn_blit_masked`, `BC` = `fn_buffer_addr_from_vram(L=screen_x,
H=screen_y)` = `#9000 + screen_y*64 + screen_x/4`, calculé depuis le
`screen_y` BRUT (pas `y+h-1`, contrairement au clear). Et `loc_30AD`
fait `BC += 64` par ligne, soit `screen_y + 1`. En VRAM cela correspond
donc à `-0x800`, PAS à `+0x800`.

Réutiliser `fn_vram_advance_line` tel quel dans `loc_30AD` aurait été la
TROISIÈME erreur de direction de cette série. Variante inverse
nécessaire, vérifiée exhaustivement (191 lignes × toutes les colonnes) :

```asm
fn_vram_retreat_line:   ; addr(y) -> addr(y+1)
        ld    de,#F800
        add   hl,de
        bit   6,h       ; adresse VRAM valide => H >= #C0 ; bit 6 tombe
        ret   nz        ; si on a franchi une bande vers le bas
        ld    de,#3FB0  ; = 0x37B0 + 0x800, corrige le -0x800 en +0x37B0
        add   hl,de
        ret
```

Attention : `CARRY` n'est PAS utilisable comme test ici (contrairement au
sens direct) — `add hl,#F800` met la retenue dans TOUS les cas puisque
`H >= #C0`. D'où le test `bit 6,h`. **Piège générique** : l'idiome CPC
"ligne suivante" (+0x800 / test carry) n'a pas de symétrique évident ;
sa réciproque demande un autre discriminant.

Restant à confirmer avant de patcher : le sens de parcours des LIGNES du
sprite dans les données de forme (le blit part de `screen_y` et monte en
`screen_y`, donc descend l'écran) — sans importance pour le patch tant
qu'on conserve l'ordre existant, mais à garder en tête si un décalage
vertical d'une hauteur de sprite apparaît en jeu.

## Patch appliqué (2026-08-19) — fn_blit_masked dessine en VRAM directe

Quatre modifications, toutes à **longueur strictement préservée** (aucun
`org` déplacé, donc aucun poke littéral invalidé) :

| Adresse | Avant | Après |
|---|---|---|
| `#2F31` (3 o) | `cpl / add a,#41` (poke `64-w`) | `neg / nop` (poke `-w`) |
| `#2F76` (11 o) | calcul adresse buffer | `call fn_vram_sprite_addr` + 8 `nop` |
| `#30AD` (14 o) | `BC += (64-w)` puis boucle | `BC -= w` puis `jp fn_vram_next_row` |
| `#2EC0` (1 o) | `push bc` | `ret` — copie différée neutralisée |

Nouveau code (`code/vram_direct_rendering.asm`, `#8159-#817E`, 38 o —
la zone `#8100-#81FF` reste occupée jusqu'à `#817F` seulement) :
`fn_vram_sprite_addr` et `fn_vram_next_row`.

`#30AF` reste bien l'opérande auto-modifié visé par le poke de `#2F34`
(vérifié dans le binaire : `#2F31` = `ED 44 00 32 AF 30`).

**Vérification (assembleur + diff mémoire, PAS testé en jeu)** :
- export symboles avant/après : les seules différences sont les 4
  symboles NEUFS. **Aucun symbole existant n'a bougé.**
- diff octet à octet des 65536 octets : **61 octets sur 5 plages**,
  exactement les 5 plages voulues (`#2EC0`, `#2F31-#2F33`,
  `#2F76-#2F80`, `#30AF-#30BA`, `#8159-#817E`). Rien d'autre dans tout
  le jeu n'a changé.
- octets de `loc_30AD` relus : `79 C6 00 4F 78 CE FF 47 C3 69 81 00 00
  00` = 14 o, et `loc_30BB` démarre bien à `#30BB` sur `C6 02`.

### PAS ENCORE TESTÉ EN JEU — points de vigilance attendus

1. **HUD** : les effacements HUD passent encore par `fn_fill_rect` vers
   le BUFFER (`pickups_and_transform.asm:410,427,460,466,468`,
   `menu_and_materialize.asm:229,232,247,252`), alors que la copie est
   maintenant neutralisée. Les sprites HUD se dessineront (chemin
   partagé migré) mais leur effacement n'atteindra plus la VRAM :
   **traînées/rémanence attendues sur le HUD**, pas de plantage. À
   migrer ensuite vers `fn_vram_fill_rect`.
2. `entity_logic_mechanical.asm:1070,1092` : call sites toujours pas
   identifiés, même risque.
3. **Débordement horizontal** : ligne buffer = 64 o, ligne VRAM = 80 o.
   Index de colonne max = `(255>>2)+8` = 71, plus une largeur de sprite
   jusqu'à 16 o -> 87 > 80, donc débordement possible sur la zone
   raster adjacente au bord droit. Le défaut existait déjà sous une
   autre forme (débordement sur la ligne suivante du buffer), mais il se
   manifestera différemment.
4. Les entités elles-mêmes devraient être correctes : leur clear atteint
   déjà la VRAM (travail commité le 2026-08-18), et l'ordre du pipeline
   (tous les clears en passe 1, tous les dessins en passe 2) reste
   valide en dessin direct.
5. `fn_clear_intermediate_buffer` memset toujours `#9000-#BFFF` à chaque
   chargement de salle : désormais inutile mais inoffensif. La zone
   n'est libérable qu'une fois le point 1 réglé.

## Test en jeu (2026-08-19) — la zone #8100-#81FF N'EST PAS LIBRE

Symptôme rapporté : au menu le contour se dessine puis s'efface (le texte
reste) ; dans une salle le décor s'affiche puis s'efface, seul le
personnage continue de se redessiner.

### Constat direct, non spéculatif

Comparaison de la RAM live (`/api/ram`) avec le binaire assemblé, sur
`#8100-#81FF`, pendant une partie : **68 octets écrasés**, sur 4 plages
(`#8100-#8115`, `#8127-#8139`, `#814B-#815D`, `#81F1-#81FF`).
`fn_vram_sprite_addr` (`#8159`) et une partie de `fn_vram_fill_rect`
étaient DÉTRUITES. Une mesure antérieure montrait aussi `#8180-#81A0`
mis à ZÉRO (un logger qu'on y avait placé), donc au moins deux écrivains
distincts (données type sprite d'un côté, remplissage à zéro de l'autre),
et les plages touchées CHANGENT d'une observation à l'autre.

**La conclusion du 2026-08-18 ("`#8100-#81FF` : rien n'y écrit plus une
fois le boot terminé") est donc FAUSSE.** Elle avait été établie en
cherchant les lecteurs/écrivains *intentionnels* de cette table. Mais
l'écriture constatée est un **débordement accidentel** depuis une zone
voisine — qu'aucune analyse des écrivains intentionnels ne peut révéler.

**Piège générique pour `docs/METHODOLOGY.md`** : "aucun code n'écrit ici
volontairement" n'implique PAS "rien n'écrit ici". Avant de réutiliser
une zone RAM pour du code, la seule preuve valable est empirique :
y écrire un motif témoin, faire tourner le jeu longuement dans des
situations variées, et RELIRE. C'est la 2e fois que cette zone piège le
projet (cf. `#9000-#BFFF` plus haut) — mais cette fois le raisonnement
statique était en cause, pas seulement un oubli.

### Le code neuf est hors de cause (vérifié)

Simulation exhaustive de `fn_vram_next_row` et `fn_vram_advance_line`
depuis TOUS les états de départ possibles (B = `#C0`-`#FF`, plusieurs C),
300 itérations chacun : la plage atteinte est `#C000-#FFAF` et
`#C050-#FFFF` respectivement, **zéro sortie de la VRAM**. Ni le blit ni
le clear ne peuvent donc écrire hors de l'écran. L'arithmétique
d'adressage du patch est saine ; c'est bien l'EMPLACEMENT du code qui
est en défaut.

### Non établi

L'identité de l'écrivain. Une tentative d'ablation (`ret` sur
`fn_fill_rect` `#1DC1` et `fn_clear_intermediate_buffer` `#2DB7`) a fait
**planter le jeu** (PC=`#CE6F`, exécution dans la VRAM) — le test est
donc contaminé, on ne peut pas conclure de l'arrêt de la corruption
observé juste après. `fn_fill_rect` descend bien de ~64 octets/ligne
(`ld d,#FF` confirmé dans le source) mais ne peut déborder que d'une
ligne sous `#9000` (soit `#8FC0`), pas jusqu'à `#8100`.

L'API du débogueur AMSpiriT n'expose pas de point d'arrêt en écriture
mémoire (`/api/raster_bp` et `/api/basic_bp` seulement), ce qui rend
l'identification directe coûteuse.

### Conséquence pour la suite

Trouver un emplacement RÉELLEMENT sûr est maintenant le préalable, avant
toute autre mise au point. Options, par ordre de solidité :

1. **Dérouler-en-boucle les 32 entrées de `fn_blit_masked`** (le plan
   d'origine du 2026-08-18) : libère ~448 octets DANS la zone de code,
   qu'aucune donnée ne peut atteindre par débordement. Plus lent, mais
   c'est le seul emplacement dont la sûreté ne repose pas sur une
   hypothèse.
2. Finir la migration des clears (`fn_fill_rect` -> `fn_vram_fill_rect`
   sur tous les call sites) pour libérer vraiment `#9000-#BFFF`, puis y
   loger le code. Plus de place, mais suppose que plus rien n'y écrit —
   exactement le type d'hypothèse qui vient d'échouer deux fois : à
   valider empiriquement par motif témoin, pas par lecture de code.

## Option 1 réalisée (2026-08-19) — fn_blit_masked mis en boucles

### Ce qui change

Les deux familles « duff device » (16 entrées déroulées de 18 o et de
10 o) sont remplacées par, pour chacune : **16 stubs de 4 octets**
(`ld a,<largeur> / jr <corps>`) suivis d'**un seul corps de boucle**.

Le mécanisme de dispatch d'origine est **conservé tel quel** (JP
auto-modifié en `#2F8A`, adresse = base + index × taille_unité) — seule
la taille d'unité passe de 18/10 à 4, ajustée dans les deux
multiplicateurs de `fn_sprite_pipeline_setup` (`×18` et `×10` → `×4`,
avec padding `nop` côté famille décalée pour préserver `#2F8B`).

Corollaires :
- le poke auto-modifiant `#30AF` **disparaît** : la largeur est portée
  par `var_blit_width`, posé par le stub. Les 9 octets qui le
  calculaient sont neutralisés en `nop`.
- `fn_vram_next_row` disparaît, fusionnée dans `blit_row_end`.
- `inc c` → `inc bc` dans les corps de boucle (voir "bug latent" plus bas).

### Nouvelle implantation

| Symbole | Adresse |
|---|---|
| `fn_blit_masked` (stubs décalés) | `#2F8D` |
| `loc_30BB` (mise en place alignée) | `#2FF1` |
| `blit_aligned` (stubs alignés) | `#3015` |
| `blit_row_end` | `#3071` |
| `var_blit_cols` / `var_blit_width` | `#3092` / `#3093` |
| `blit_vram_free` = code VRAM-direct | `#3094`-`#30FD` |

**137 octets restent libres** (`#30FE`-`#3185`). `#8100-#81FF` est
totalement abandonné, et la construction de la table « nibble dupliqué »
(`#0854-#086E`, 26 o) est **restaurée** — on n'a plus aucune raison de
priver le jeu de cette table, dont le rôle n'avait jamais été tracé.

### Vérifications (assembleur + simulation, PAS testé en jeu)

1. Assemblage propre. `#3186` et au-delà **byte-identiques** au build de
   référence — `screen_addressing_and_tables.asm` intact.
2. Diff mémoire complet : 646 octets sur 10 plages, toutes attendues
   (restauration table, opérandes de `call` dont la cible a bougé,
   neutralisations, zone blit réécrite, `#8100` libéré).
3. `#2F8A` = `C3` avec opérande en `#2F8B` : le JP auto-modifié est
   intact. Les 32 stubs vérifiés un à un (`ld a,16-j` à `base + 4j`).
4. **Simulation des OCTETS ASSEMBLÉS** (mini-interpréteur Z80 du
   sous-ensemble utilisé), ancienne version déroulée contre nouvelle,
   même état initial, sur les **32 cas** (2 familles × 16 largeurs) :
   séquences d'écriture **identiques en adresses ET en valeurs**, BC et
   DE finaux identiques.
5. `blit_row_end` vérifié sur ses octets réels : **12224 combinaisons**
   (y=0..190 × x × w) donnent toutes exactement `addr(y+1, x)`.

### Bug latent de l'original corrigé au passage

Les corps déroulés utilisaient `inc c` (sans propagation de retenue dans
B) sauf sur la dernière colonne. Quand une ligne franchit une frontière
de page de 256 octets, l'écriture **se replie au début de la page** :
vérifié par simulation, pour `BC=#C1F0, w=16` l'original écrit
`#C100-#C1FF` au lieu de `#C1F0-#C200`. Inoffensif ou non dans le buffer,
c'est faux en VRAM où les débuts de ligne ne sont pas alignés. Les
boucles utilisent `inc bc`, ce qui corrige le repli (avance nette
inchangée : +1/colonne).

### Reste à faire (option 2, différée)

Les effacements HUD passent toujours par `fn_fill_rect` vers le buffer
alors que la copie est neutralisée : **traînées HUD attendues**. Migrer
les call sites (`pickups_and_transform.asm`, `menu_and_materialize.asm`,
`entity_logic_mechanical.asm`) vers `fn_vram_fill_rect` libérera aussi
`#9000-#BFFF` pour de bon.

## RÉSOLU (2026-08-19) — "le décor s'affiche puis s'efface" = fn_copy_screen_rect

### Diagnostic, par mesure

Rechargement de salle forcé (trampoline de
`notes/2026-08-07-room-teleport-tool-validated.md`), en comptant les
octets VRAM non nuls toutes les 130 ms :

```
t+0.13s   601        <- debut du dessin de la salle
t+0.52s  1968
t+0.79s  3099        <- salle entierement dessinee
t+0.92s   104        <- EFFONDREMENT en une frame
t+1.84s   381        <- seuls le personnage et le HUD se redessinent
```

Un effondrement quasi total en une frame : ce n'est pas le mécanisme de
rectangles sales, c'est un effacement plein écran. **Ablation
discriminante** : avec `fn_vram_fill_rect` neutralisée (`ret`), la courbe
est IDENTIQUE (3030 -> 605) — le clear VRAM direct est donc hors de
cause.

Coupable : **`fn_copy_screen_rect` (`#2DBF`)**, dont le nom
("copie rectangulaire écran→écran") masquait le rôle réel. Le code dit
autre chose : `ld hl,#BFC0 / ld de,#C008 / ld b,#C0` puis 192 itérations
de `LDIR` de 64 octets avec `source -= 64` et avance VRAM CRTC-aware.
C'est la **copie EN BLOC du buffer intermédiaire vers la VRAM**, le
pendant plein écran de `fn_blit_copy_line`. Appelée au chargement de
salle et pendant la matérialisation (`low_ram_and_boot.asm:321`,
`menu_and_materialize.asm:102`, `entity_logic_mechanical.asm:662`).

Le décor étant désormais dessiné directement en VRAM, cette copie
écrasait tout l'écran avec le buffer devenu vide, juste après le dessin.

**Vérifié en jeu** : avec `#2DBF` = `C9`, la courbe monte à 3190 et reste
stable ; capture d'écran = salle complète et correcte (murs, arches,
personnage, HUD entier avec piliers, corde, compteurs et icône
jour/nuit).

### Correctif

`fn_copy_screen_rect` neutralisée (`ret` + 2 `nop`, 3 octets, longueur
préservée). Diff vs build précédent : 3 octets, aucun symbole déplacé.

### Piège générique pour docs/METHODOLOGY.md

**Un symbole nommé lors d'une passe antérieure peut induire en erreur.**
`fn_copy_screen_rect` / "copie rectangulaire écran→écran" laissait croire
à une opération interne à la VRAM, sans rapport avec le buffer. La
source (`#BFC0` -> `#C008`) dit l'inverse. Lors d'une migration, ne pas
se fier aux noms attribués : **re-lire le corps de toute routine qui
touche la zone qu'on migre**, et chercher les copies EN BLOC autant que
les copies incrémentales — c'est la copie plein écran, appelée une seule
fois par chargement, qui a été oubliée alors que son équivalent
par-rectangle (`fn_blit_copy_line`) avait bien été traité.

### État du pipeline après ce correctif

Chemin buffer restant (à migrer, option 2) :
- `fn_fill_rect` (`#1DC1`) : effacements HUD vers le buffer, sans effet
  visible maintenant que plus rien ne recopie -> **traînées HUD
  attendues** quand un compteur/icône change.
- `fn_clear_intermediate_buffer` (`#2DB7`) : memset `#9000-#BFFF` au
  chargement de salle, désormais inutile.
Ces deux-là éliminés, `#9000-#BFFF` (12 Ko) sera libre pour de bon.

À revérifier aussi : la séquence de **matérialisation** et les écrans de
**menu / game over**, qui appelaient `fn_copy_screen_rect` et dessinent
possiblement encore dans le buffer. Le contour de menu qui "s'affichait
puis s'effaçait" au début de la session relevait du même mécanisme et
devrait être corrigé par ce changement — à confirmer en jeu.

## RÉGRESSION puis CORRECTIF (2026-08-19, soir) — `fn_copy_screen_rect` avait TROIS rôles

Symptômes rapportés après la neutralisation du matin (`ret` + 2 `nop`) :

1. En jeu : le décor ne s'efface plus **du tout**, y compris au
   changement de salle — l'ancienne salle reste à l'écran sous la
   nouvelle.
2. Au menu (`.sna` réassemblé) : **on ne voit que le décor, plus le
   texte** (exactement l'inverse du symptôme du matin, où le contour
   s'effaçait et le texte restait).

### Les deux symptômes, une seule cause

`fn_copy_screen_rect` (`#2DBF`) n'était pas *une* copie mais **trois
rôles superposés**, dont un seul avait été analysé :

- **(a) le dessin** : pousser le décor pré-rendu du buffer vers la VRAM.
  Seul rôle identifié le matin, et le seul qui soit devenu nuisible avec
  le dessin direct (il écrasait le décor à peine dessiné, parce qu'il est
  appelé **après** `fn_render_entities` dans `fn_main_loop` —
  `low_ram_and_boot.asm`, `fn_render_disabled_one_time_setup` `#062F`).
- **(b) l'effacement plein écran** : comme le buffer venait d'être remis
  à zéro par `fn_clear_intermediate_buffer` au chargement de salle, la
  copie en bloc effaçait *de fait* toute la zone de jeu. Personne
  d'autre ne le faisait. → symptôme 1.
- **(c) la composition texte/HUD** : tout ce qui se dessine via
  `fn_buffer_addr_from_vram` — texte de menu et de game over
  (`fn_menu_draw_string_reset_font` `#16DA` /
  `fn_menu_draw_string_de_attribute` `#16EA` → `fn_menu_glyph_unpack`),
  compteurs HUD — écrit dans le buffer et **n'atteignait la VRAM que par
  cette copie**. → symptôme 2. Le contour du menu, lui, passe par le
  pipeline sprite (déjà migré), d'où « seul le décor reste ».

### Correctif : séparer les rôles et les remettre au bon moment

Rôle (a) supprimé ; (b) et (c) rétablis séparément, à longueur d'octets
constante (`#2DB7`, `#2DBF`, `#2DE2` vérifiés inchangés par réassemblage,
code neuf `#30FD`-`#3150`, marge 54 octets avant `#3186`) :

- **(b)** `fn_vram_clear_playfield` +
  `fn_vram_clear_playfield_and_buffer` (`code/vram_direct_rendering.asm`),
  branchées dans le corps de `fn_clear_intermediate_buffer` (`jp` + 5
  `nop` = les 8 octets d'origine). Même ancre `#C008`, même 192 × 64,
  même parcours raster `+0x800` / `+0xC050` sur carry que la copie
  remplacée : couverture identique. Point clé — c'est appelé **avant**
  `fn_load_room_data` / `fn_render_entities`, pas après le dessin.
  Le memset `#9000-#BFFF` est conservé car le buffer reste le plan du
  texte/HUD (voir (c)), et un buffer non effacé ferait réapparaître le
  texte de la salle précédente à la fusion suivante.
- **(c)** `fn_vram_merge_buffer_to_screen`, branchée dans les 3 premiers
  octets de `fn_copy_screen_rect` (`jp`, exactement les 3 octets du
  `ld hl,#BFC0` d'origine). Même parcours que l'original, **une seule
  différence : un octet nul du buffer n'est pas écrit**. Le décor VRAM
  survit, le texte s'ajoute. Granularité l'octet (4 pixels en mode 1) et
  non le pixel — mais l'original écrasait l'octet entier de toute façon,
  donc aucune régression, et les écrans de menu / game over dessinent
  leur texte sur du noir.

### À vérifier en jeu

- changement de salle : l'ancien décor disparaît, le nouveau reste ;
- menu et écran de game over : décor **et** texte ;
- HUD au chargement de salle (il passe par la fusion) ;
- HUD **en cours de partie** : toujours attendu défaillant (traînées /
  compteurs figés), le chemin `fn_fill_rect` → buffer n'est pas migré et
  la fusion n'a lieu qu'une fois par chargement. C'est le point 1 de
  « État du pipeline » ci-dessus, inchangé par ce correctif.

### Leçon (générique, versée dans `docs/METHODOLOGY.md`)

Une routine peut porter **plusieurs rôles non nommés** que seul son
*contexte d'appel* révèle. Ici l'effacement plein écran était un **effet
de bord d'un buffer vide**, invisible dans le corps de la routine : rien
dans `fn_copy_screen_rect` ne ressemble à un `clear`. Avant de neutraliser
une routine lors d'une migration, inventorier ce qui **cesse d'arriver** :
pour chaque appelant, quel état visible cette routine était-elle seule à
produire ? La question « qu'est-ce qui devient mort ? » ne suffit pas, il
faut aussi « qu'est-ce qui n'est plus fait par personne ? ».

Corollaire d'ordonnancement : une même opération peut être correcte ou
destructrice **selon sa position dans la frame**. L'effacement plein
écran était juste ; c'est son placement après le dessin qui était faux.
Un « clear » qui apparaît après un « draw » dans la boucle est le signe
d'un double-buffer implicite — le supprimer casse le clear, le déplacer
en amont le préserve.

## 2026-08-19 (3) — traînée soleil/lune, et déplacement de la pile hors de #8000

État rapporté avant cette passe : « le menu apparaît bien, les salles sont
correctes », mais (a) des écritures subsistent vers `#9100-`, (b) le
soleil/la lune laisse une **traînée**.

### (a)+(b) : même cause, l'effacement de l'arc soleil/lune

`loc_1C6E` (`pickups_and_transform.asm`) effaçait son rectangle dans le
**buffer** (`fn_fill_rect` sur `#97EE`) alors que l'icône se dessine
maintenant directement en VRAM. D'où la traînée.

Et les écritures observées en `#9100-` sont bien celles-là :
`fn_buffer_addr_from_vram` calcule `#9000 + screen_y*64 + screen_x/4`
(donc **axe Y non inversé**, contrairement à ce que la lecture rapide de
`fn_blit_copy_line` suggérait), `#97EE` = `y=31, x=184`, et `fn_fill_rect`
descend à `-64`/ligne jusqu'à `y=1` → la plage écrite est `#902E-#97F9`,
qui couvre `#9100`.

**Correctif** : `loc_1C6E` appelle `fn_vram_fill_rect` sur `#C676` —
l'adresse VRAM que le code d'origine appariait déjà avec `#97EE` pour
`fn_blit_copy_line` (dernier `ld de,#C676` de la routine), donc pas un
calcul nouveau. Les 3 instructions d'échange `B<->C` disparaissent
(`fn_vram_fill_rect` a déjà la convention `B`=largeur / `C`=hauteur, on
charge `#0C1F` directement), 3 `nop` conservent les 15 octets. Adresses
`#1C6E` / `#1CAF` / `#1CDF` / `#1CED` vérifiées inchangées.

### Déplacement de la pile : 71 octets fabriqués à #2D9B-#2DE1

Objectif utilisateur : libérer tout `#8000-#BFFF` pour un double buffer,
ce qui suppose d'abord sortir la pile de `#8100`.

Il n'existait **aucun** bloc libre de 64 octets sous `#8000` (le
`ds #0030` de `buf_visible_entities` et le `ds #001C` de la pseudo-entité
HUD sont vivants ; la zone ressources se termine pile à `#7FFF` avec 5
octets nuls). Les 71 octets ont donc été **fabriqués** en `#2D9B-#2DE1`,
juste sous `fn_render_entities` (`#2DE2`), en récupérant :

- `fn_clear_screen` (28 o) — encore vivante, **relogée telle quelle** dans
  `code/vram_direct_rendering.asm` (`#3150`). Ses 3 appelants la
  référencent par symbole : rien à changer chez eux.
- `fn_clear_intermediate_buffer` (8 o) et `fn_copy_screen_rect` (35 o) —
  réduits à des `jp` de redirection depuis le correctif précédent. Leurs 7
  sites d'appel pointent désormais directement sur
  `fn_vram_clear_playfield_and_buffer` / `fn_vram_merge_buffer_to_screen`
  (même longueur d'instruction), les tremplins disparaissent.

`zone_stack: ds #0047` fait exactement 71 octets, donc
`fn_render_entities` reste à `#2DE2` et l'opérande auto-modifié `#2F8B`
n'est pas décalé. `STACK_TOP_INIT` devient le **label** `zone_stack_top`
(la valeur suit le découpage, pas de littéral à maintenir). Vérifié dans
le `.sna` : `#0000 = F3 31 E2 2D` (`DI` / `LD SP,#2DE2`) et `#05B2 = 31 E2
2D` (le reset par entité).

L'ancien `ld de,STACK_TOP_INIT` de `fn_build_pixel_bitscatter_tables`
utilisait `#8100` comme **adresse de données** (base des tables) et non
comme pile : il reçoit son propre symbole `TBL_BITSCATTER_BASE`. Piège de
nommage classique — un EQU partagé par deux rôles indépendants qui ne
diverge qu'au moment où l'un des deux bouge.

### Ce qui rend 71 octets suffisants : suppression de la file de blits différés

`STACK_LOW_WATERMARK = #8010` (240 octets) n'était pas une mesure de
l'imbrication d'appels : `fn_stage_blit_and_clear` empilait `BC/DE/HL` par
entité sale (jusqu'à 40 × 6 = **exactement 240**) et la boucle `loc_2EAA`
les dépilait pour appeler `fn_blit_copy_line`. **La pile servait de file
d'attente de blits différés.** C'était le seul consommateur de pile non
borné du jeu.

Cette file est entièrement supprimée (le blit différé est mort, le dessin
va directement en VRAM) :
- les 7 octets `push bc / push de / push hl / xor a / call fn_fill_rect` →
  7 `nop` (le `call fn_fill_rect` effaçait le rectangle dans le buffer,
  déjà fait en VRAM par `fn_stage_clear_vram_and_buffer_addr`) ;
- les 50 octets `#2EAA-#2EDB` (boucle 19 o + sortie 3 o +
  `fn_blit_copy_line` 28 o) → `pop ix / ret` (3 o) +
  `fn_blit_copy_line: ret` (1 o, pour que ses appelants restants restent
  assemblables) + **46 octets libres** (`zone_free_2EAE`).

`var_blit_stack_counter` continue d'être incrémenté : c'est la mesure de
charge lue par `fn_render_workload_pacing_delay`, le calage de frame est
donc inchangé.

Reste de pile : imbrication d'appels + `push` des routines, très
en-dessous de 71 (l'usage observé de 42 octets sur `main` incluait déjà
~5 entrées de file, soit ~30 octets). **À vérifier empiriquement**
quand même : remplir `zone_stack` d'un motif témoin au boot et relire la
borne basse atteinte après quelques minutes de jeu.

### Bilan mémoire sous #8000 après cette passe

| Zone | Taille | Usage |
|---|---|---|
| `zone_stack` `#2D9B-#2DE1` | 71 o | pile |
| `zone_free_2EAE` `#2EAE-#2EDB` | 46 o | libre |
| `#316D-#3185` | 25 o | libre (queue de la zone de code) |

### BLOQUANT restant pour libérer #8000-#BFFF en entier

La pile n'était que le petit morceau. Il reste dans le segment :

- `#8100-#8FFF` : **15 tables de 256 octets** (`TBL_BITSCATTER_BASE`),
  paires masque/couleur lues par `fn_blit_masked` à *chaque octet de
  forme*, adressées par `H` ∈ {`#82`,`#84`,`#88`,`#8C`} et `L` = octet de
  forme — donc **alignement page 256 obligatoire** et pages consécutives
  par famille de décalage. 3840 octets à reloger, contre 71+46+25 = 142
  octets libres sous `#8000`. Impossible en l'état.
- `#9000-#BFFF` : le buffer intermédiaire, lui, est en voie d'être
  réellement libre (il ne reste que le chemin glyphes, ci-dessous).

Deux pistes, à trancher avant d'aller plus loin :

1. **Double buffer en `#4000-#7FFF`** et déplacement des ressources
   sprites (`#4046-#7FFF`) vers le `#9000-#BFFF` libéré. Échange de deux
   blocs de ~16 Ko, sans contrainte d'alignement pour les sprites (ils
   sont adressés par pointeurs dans `tbl_sprite_dispatch`), mais tous les
   pointeurs de la table doivent être rebasés.
2. **Reconstruire les tables bitscatter dans `#4000+`** en récupérant de
   la place dans la zone ressources — plus contraint (alignement page) et
   il faut trouver 3840 octets contigus.

### Chemin buffer encore non migré (indépendant de ce qui précède)

`fn_buffer_addr_from_vram` (`#3186`) → `fn_menu_glyph_unpack` : texte de
menu / game over et compteurs HUD (jour `#91DE`, secondaire `#99C8`).
Fonctionne grâce à `fn_vram_merge_buffer_to_screen`, mais **seulement aux
moments où cette fusion est appelée** (chargement de salle, menu, game
over) — un compteur qui change en cours de partie ne se met donc pas à
jour. Migrer ce chemin demande de traiter l'avance de ligne du
glyph-unpack : le buffer est linéaire (`+64`/ligne), la VRAM est
entrelacée (`+0x800` avec repli) — c'est le vrai travail, pas le calcul
d'adresse.

## 2026-08-19 (4) — migration du chemin glyphes : #9000-#BFFF enfin vide

Constat utilisateur : le texte du menu apparaît dans `#9000-#BFFF`, donc il
reste des écritures là-bas **et** une recopie vers `#C000`. Exact — c'était
le dernier chemin non migré, et la « fusion transparente » posée le matin
en dépendait par construction.

### Le nom trompeur, encore : `fn_buffer_addr_from_vram`

Son entrée n'est **pas** une adresse VRAM : c'est un couple de coordonnées
`H=screen_y / L=screen_x`, et sa sortie était `#9000 + y*64 + x/4`. Donc
**le buffer n'a pas l'axe Y inversé** — l'inversion apparente venait de la
copie, pas du buffer. (La lecture rapide de `fn_blit_copy_line`, qui
descend le buffer à `-64`/ligne, avait fait conclure l'inverse.)

Renommée `fn_vram_addr_from_yx`, elle délègue maintenant à
`fn_screen_addr_from_bc` (11 octets + 4 `nop` = les 15 d'origine, donc
`fn_screen_addr_from_bc` reste à `#3195`). Tous ses appelants passent d'un
coup au dessin direct : texte de menu et de game over, notification de
slot, compteurs HUD.

**La correspondance est prouvée, pas supposée** : la copie plein écran
d'origine appariait buffer `#BFC0` avec VRAM `#C008` ; or
`#BFC0 = #9000 + 191*64 + 0`, soit `(y=191, colonne 0)`, et
`fn_screen_addr_from_bc(B=191, C=0)` rend bien `#C008` (bande `191>>3 = 23`,
`tbl_screen_line_base[23] = #0000`, `+8` de décalage de colonne). Le
mapping buffer→VRAM du jeu **est** `fn_screen_addr_from_bc(y, colonne*4)`.
Ce contrôle a servi de test de la formule avant de convertir quoi que ce
soit.

### `fn_menu_glyph_unpack` (#170D, 66 octets à préserver)

Deux changements de fond seulement :

1. **L'avance de ligne.** Le buffer est linéaire (`#9000 + y*64`), donc
   `-64 = y-1`. La VRAM est entrelacée : `y-1 = +#0800`, correction
   `+#C050` au franchissement de bande. Impossible d'appeler
   `fn_vram_advance_line` ici — elle passe par `DE`, qui porte le pointeur
   de données du glyphe, vivant. Calcul inline via `BC`, déjà
   sauvegardé/restauré à cet endroit dans le code d'origine.
2. **Le retour à `HL+2`** (contrat vis-à-vis des appelants, inchangé).
   L'original y arrivait par arithmétique (`8 × -64` puis `+#0202`) ; en
   VRAM l'avance n'est pas linéaire, donc l'adresse de départ est empilée
   et redépilée.

Budget des 66 octets : `dec hl` de fin de ligne supprimé (l'avance part de
`HL+1` avec `#07FF` au lieu de `HL` avec `#0800` — même somme, même carry),
les deux `and #FF` sans effet retirés, et le calcul de nibbles réordonné
(masque d'abord, rotation ensuite : `and #F0 / ld c,a / rrca×4 / or c` au
lieu de `rrca×4 / and #0F / ld c,a / ld a,(de) / and #F0 / or c`) —
résultat strictement identique, 3 octets de moins par moitié. Total 61,
complété par 5 `nop`. `#174F`, `#175F`, `#176B`, `#178D` sont appelés par
adresse littérale depuis d'autres fichiers : vérifiés inchangés.

### Adresses buffer codées en dur des compteurs HUD

`fn_hud_render_bcd_digits` reçoit `HL` **déjà** sous forme d'adresse
buffer — ces sites ne passent pas par `fn_vram_addr_from_yx`. Converties
avec la formule validée ci-dessus :

| ex-buffer | y | colonne | VRAM | site |
|---|---|---|---|---|
| `#91DE` | 7 | 30 | `#C756` | compteur de jours (HUD) |
| `#99C8` | 39 | 8 | `#C600` | compteur de vies (HUD) |
| `#A3EE` | 79 | 46 | `#C496` | game over, compteur de collecte |
| `#AFDE` | 127 | 30 | `#C2A6` | game over, compteur de jours |

Signal de cohérence : les quatre ont `y ≡ 7 (mod 8)`, donc le terme
`(7-(y&7))<<3` s'annule — elles sont toutes alignées en haut d'une bande
CRTC, ce qui est cohérent avec des cellules de glyphes de 8 lignes.

Ces compteurs se mettent donc à jour **en cours de partie** maintenant
(ils ne pouvaient plus l'être depuis le matin), sans traînée : un glyphe
écrit ses 2 octets inconditionnellement, il recouvre le précédent.

### Nettoyages rendus possibles

- `call fn_fill_rect` de la notification de slot → `call fn_vram_fill_rect`
  (même longueur, même sens de parcours `y-1`).
- `fn_vram_clear_playfield_and_buffer` : le memset `#9000-#BFFF` **supprimé**
  (12 Ko à chaque chargement de salle).
- `fn_vram_merge_buffer_to_screen` : réduite à `ret`. C'était la dernière
  recopie `#9000 → #C000`. Gardée comme stub pour ne pas toucher ses 3
  appelants.
- `fn_stage_clear_vram_and_buffer_addr` : queue supprimée (elle calculait
  encore l'adresse buffer du rectangle pour la file de blits différés, elle
  aussi supprimée). Une routine et un `call` de moins par rectangle sale et
  par frame.
- `fn_fill_rect` (`#1DC1`) n'a plus aucun appelant → ~50 octets récupérables.

### Vérification

Plus une seule occurrence de `BUF_PRERENDER_BASE` ni de `#9000` dans
`asm/code/*.asm` (seule reste la définition de l'EQU). Le `.sna`
réassemblé contient **0 octet non nul** dans `#9000-#BFFF`. Adresses
littérales vérifiées inchangées : `#170D`, `#1571`, `#1752`, `#176B`,
`#178D`, `#1DC1`, `#2DE2`, `#2EDC`, `#2F17`, `#2F8D`, `#3186`, `#3195`.

Espace libre sous `#8000` : `zone_free_2EAE` 46 o + `#3132-#3185` 84 o.

### Le double buffer ne rentre pas : le compte à faire avant d'aller plus loin

`#9000-#BFFF` (12 Ko) est maintenant réellement libre, et la pile est
sortie. Mais un vrai double buffer matériel CPC demande **deux pages de
16 Ko** (le CRTC ne choisit la base d'écran que parmi
`#0000/#4000/#8000/#C000`). Il faut donc que tout le reste tienne dans
32 Ko :

| Poste | Taille |
|---|---|
| code `#0000-#4045` | 16 454 o |
| ressources sprites `#4046-#7FFF` | 16 314 o |
| tables masque/couleur `#8200-#8FFF` | 3 584 o |
| **total** | **36 352 o** |

contre 32 768 disponibles : **3,6 Ko de trop**. Les tables sont contraintes
à l'alignement page 256 (`H` ∈ `#82/#84/#88/#8C`, `L` = octet de forme) et
lues par `fn_blit_masked` à chaque octet dessiné — pas déplaçables
n'importe où, ni recalculables à la volée sans coût de rendu.

Pistes réelles, à trancher avant de coder quoi que ce soit :

1. **Réduire les tables.** 14 pages = 4 décalages sub-octet × (masque,
   couleur) × 2 octets écran, plus la paire alignée. Vérifier si certaines
   sont dérivables l'une de l'autre par une rotation faite dans la boucle
   (coût CPU contre 1 à 2 Ko).
2. **Comprimer / élaguer les ressources sprites.** 16,3 Ko dont l'extent
   réel n'est pas entièrement confirmé (voir `asm/README.md`) — mesurer ce
   qui est vraiment atteint par `tbl_sprite_dispatch` avant de conclure.
3. **Renoncer au double buffer matériel** : le rendu est déjà en
   dirty-rect direct VRAM, le scintillement résiduel ne concerne que les
   rectangles réellement redessinés. Un simple calage sur le balayage
   (attente VSYNC avant la passe de clear) coûte 0 octet de RAM et traite
   le même symptôme.

Note de méthode : ce calcul aurait dû précéder le travail sur la pile.
Déplacer la pile était nécessaire mais ce n'était pas le poste
dimensionnant — 64 octets contre 3,6 Ko manquants. **Faire le budget
mémoire complet AVANT de libérer le premier octet.**

### CORRECTIF immédiat — les deux `and #FF` de `fn_menu_glyph_unpack` ne sont PAS des no-op

Symptôme rapporté juste après la migration : menu cassé, « une trace en
diagonale vers la gauche, comme un passage à la ligne de 64 octets au lieu
de 80 ».

Diagnostic. J'avais retiré les deux `and #FF` du corps du glyphe en les
prenant pour des instructions sans effet. Ce sont **les octets d'attribut
de couleur**, écrasés à l'exécution : `#172C` et `#173C` sont les
*opérandes* de ces deux `and`, et quatre appelants y pokent l'attribut
(`fn_menu_draw_string`, `fn_hud_render_day_counter`,
`fn_hud_render_secondary_counter`, `fn_game_over_or_daycycle_end`). Le
`#FF` visible dans l'image n'est qu'une valeur au repos.

Conséquence exacte du bug : dans la nouvelle disposition, `#173C` tombait
sur le **déplacement du `jr nc`** de l'avance de ligne. À chaque appel,
l'attribut écrasait ce déplacement → saut vers une adresse arbitraire au
milieu du corps. Et la diagonale décrite est la signature parfaite d'un pas
de +64 en VRAM : depuis `#C008`, `+64` fait passer `#C048` → `#C088` →
`#C0C8`, soit une ligne caractère plus bas et 16 octets plus à gauche à
chaque fois. Le diagnostic de l'utilisateur pointait la bonne mécanique.

Correctif : les deux `and` sont restaurés, et **les quatre paires de pokes
passent de l'adresse littérale à deux labels** (`glyph_attr_mask_left` /
`glyph_attr_mask_right`, définis par `equ $-1` sur l'opérande). Toute
réécriture future de la routine est désormais suivie automatiquement par
l'assembleur. Un `ASSERT $ - fn_menu_glyph_unpack == #42` garde la
longueur de 66 octets. Vérifié dans le `.sna` : les pokes visent bien
`#172A` / `#1737`, `#174F` / `#1752` / `#176B` / `#178D` intacts.

### Audit systématique fait à cette occasion

Recensement de TOUS les pokes du jeu (`ld (#nnnn),a|hl|bc|de`) : `#0A32`,
`#0A49`, `#0A4A`, `#0F41`, `#0F5A`, `#0FBF`, `#0FD0`, `#172C`, `#173C`,
`#1DD6`, `#29F3`, `#29F7`, `#29FB`, `#2A07`, `#2A0F`, `#2A17`, `#2AB6`,
`#2F8B`, `#3259` (le reste vise la RAM basse). Croisés avec toutes les
régions modifiées dans la session : `#172C`/`#173C` étaient la **seule**
collision. `#1DD6` (déplacement auto-modifié de `fn_fill_rect`) et `#2F8B`
(sélecteur de variante de `fn_blit_masked`) sont hors des zones réécrites.

## OUVERT (2026-08-19) — boules à pics au plafond non redessinées après passage du joueur

Symptôme : dans une salle à boules à pics au plafond (type `0x3F`, voir
`notes/2026-08-07-entity-logic-ceiling-spikes.md` — 12 exemplaires en room
`0x4F`), passer sous une boule l'efface et laisse voir le mur derrière.

### Comment le moteur est censé gérer ça (établi ici)

Point important pour la suite, il n'était pas documenté : **une entité
n'est PAS redessinée à chaque frame**. Le pipeline est piloté par deux
bits de `off_flags` :

- **bit 4 = « à redessiner »**. `fn_cull_entities` (`#26F7`) ne met dans
  `buf_visible_entities` que les entités dont bit4 est posé, et
  `fn_sprite_pipeline_setup` fait `res 4` en dessinant (consommation).
- **bit 5 = « effacer l'ancienne position »**. Consommé par `res 5` dans
  la passe 1 de `fn_render_entities`.

Les deux sont posés ensemble par `loc_1F7B`
(`objects_and_rooms_setup.asm` : `ld a,(ix+off_flags) / or #30 / ...`),
qui enchaîne sur `fn_entity_fall_and_mark_overlap` (`#25FF`) — laquelle
scanne les 40 entités et pose **bit4 sur toutes celles dont l'empreinte
ÉCRAN chevauche le rectangle sale de l'appelant** (union bbox
précédente ∪ courante). C'est ce mécanisme, et lui seul, qui fait
réapparaître un décor ou une entité statique dont les pixels viennent
d'être effacés par le passage d'une entité mobile.

Une boule statique ne se re-flague jamais elle-même : sa logique sort par
`RET` tant qu'elle n'est pas déclenchée. Elle dépend donc entièrement du
marquage par chevauchement.

### Ce qui a été vérifié et écarté

- **Géométrie du clear** : la passe 1 passe `B = b+l-1` (haut du rect) à
  `fn_screen_addr_from_bc`, et `fn_vram_fill_rect` avance en `+#0800`
  (= `screen_y - 1`, vers le bas de l'écran) — exactement le sens et le
  rectangle de l'ancien `fn_fill_rect` sur le buffer (`-64`/ligne, même
  largeur/hauteur, même limitation `w > 16` héritée). Écrêtage `y ≥ 192`
  de la passe 1 conservé.
- **Sens de parcours du blit** : l'original avance de `w` par ligne via
  les `inc c` puis poke `64 - w` dans l'opérande `#30AF`, soit **+64 par
  ligne = `screen_y + 1`** (vers le haut de l'écran). `blit_row_end` fait
  bien `BC -= w` puis `-#0800`, avec correction `+#3FB0` détectée par
  `bit 6,b` (passage sous `#C000`) — arithmétique revérifiée sur la
  géométrie CPC (`#C000 + ligne*#800 + rang*80 + col`).
- **Dispatch de largeur** : `×4` dans les deux familles (décalée et
  alignée), index `j = (-w) & 15`, largeur portée par `var_blit_width`
  = `16 - j` = `w` pour `w` de 1 à 16 — identique aux entrées déroulées.
- **Registres du corps de blit** : `#2F89 = ex af,af'` remet le compteur
  de lignes dans `AF'` avant chaque ligne, donc le `ld a,#nn` des stubs
  est inoffensif ; `H` (page de table masque/couleur) posé en `#2F85` et
  restauré par les `dec h` du corps.
- **Écrêtage de hauteur au plafond** (`ld (ix+off_screen_h),a` puis
  `add a,(ix+off_screen_y) / sub #C0`) : inchangé.
- **Logique des flags** : aucune ligne modifiée dans `fn_cull_entities`,
  `fn_entity_fall_and_mark_overlap`, `loc_1F7B`, ni dans la passe 1.

### Les deux hypothèses restantes

1. **Le bit4 de la boule n'est pas posé** → problème en amont du dessin.
   Deviendrait visible maintenant alors qu'il était masqué avant.
2. **Le bit4 est posé mais le dessin ne sort pas au bon endroit** →
   problème dans le chemin VRAM direct pour les `screen_y` élevés
   (plafond), donc autour de l'écrêtage ou de `fn_vram_sprite_addr`.

### Test discriminant proposé

Observer `off_flags` d'un slot de boule (22-33 en room `0x4F`) pendant que
le joueur passe dessous : bit4 posé ou non. Alternative en une ligne de
code : appeler `fn_reset_all_entity_processing_flag` (`#0668`) à chaque
frame — tout est alors redessiné chaque frame ; si les boules
réapparaissent, c'est l'hypothèse 1, sinon la 2. Build lent mais
concluant.

### Suite (room 0x4F confirmée) — build diagnostic à effacement coloré

Précisions utilisateur : la boule est bien dessinée à l'entrée dans la
salle ; le rectangle sale est visible au passage ; après éloignement la
boule ne revient jamais et on voit le mur du fond. Idem pour toutes les
boules. Phénomène apparenté aperçu ailleurs sur des cubes empilés (ceux
du dessous dessinés après ceux du dessus), **non systématique**.

#### Ce que le tri en profondeur fait, et ce qu'il ne fait pas

Vérifié intact (aucun octet touché) : `tbl_collision_dispatch` (`#27FE`,
27 mots indexés par le code d'overlap AABB 0-26), les 3 handlers
(`#2834`/`#2837` = pas de réordonnancement, `#283A` = report), le
marquage `set 7,(hl)` dans `buf_visible_entities`, et la remise à `#FF`
du sentinel de `tbl_collision_pending` à chaque entité dessinée.

Point à retenir : **le tri ne compare que les paires qui se chevauchent
en 3D**. Pour deux entités qui ne se touchent pas, l'ordre de dessin est
simplement l'ordre des slots (`fn_cull_entities` balaie 0→39). Le moteur
s'appuie donc sur l'ordre d'instanciation comme ordre de profondeur par
défaut.

**Limite dure repérée au passage** (bug latent du moteur d'origine, pas
une régression) : `tbl_collision_pending` fait **8 octets** (`#28AF-#28B6`)
et `loc_284D` y ajoute **sans contrôle de borne**. Au-delà de 7 reports
simultanés, l'écriture du sentinel déborde sur `#28B7`, soit les premiers
octets de `fn_read_input`. Un ordre de dessin qui casse « pas
systématiquement » sur une scène chargée correspond exactement à ce
profil. À garder en tête pour l'observation sur les cubes.

#### Le raisonnement qui gêne l'hypothèse « ordre » pour les boules

Les sprites s'étendent **vers le haut** depuis `screen_y` (confirmé :
avance `+64`/ligne dans le buffer, `screen_y + 1` = vers le haut de
l'écran). Donc `screen_y` d'une boule au plafond est le BAS de son
sprite, au-dessus du joueur.

Or `fn_entity_fall_and_mark_overlap` et la passe 1 de
`fn_render_entities` dérivent leur rectangle de la MÊME formule (union
bbox précédente ∪ courante, mêmes champs). Si le rectangle du joueur
atteint les pixels de la boule, alors le test de chevauchement devrait
la marquer ; s'il ne l'atteint pas, l'effacement ne devrait pas la
manger. Les deux observations (rectangle visible + boule mangée) ne sont
donc cohérentes que si l'effacement et le test de marquage ne portent
PAS sur le même rectangle.

La seule divergence connue entre les deux va dans le bon sens : la passe
1 écrête le rectangle à `y < 192` (donc plus PETIT au plafond), le test
de marquage non. Il reste donc quelque chose à trouver.

#### Build diagnostic posé

`fn_stage_clear_vram_and_buffer_addr` peint les rectangles sales en
`#FF` (couleur 3) au lieu de les effacer. Lecture du résultat :

| Observation dans la zone de la boule | Conclusion |
|---|---|
| reste COLORÉE | la boule n'est jamais redessinée → problème de marquage bit4, en amont du dessin |
| montre le MUR | le mur est bien redessiné par-dessus → problème d'ordre d'affichage |
| jamais colorée alors que la boule disparaît | ce n'est pas cet effacement qui la mange → chercher ailleurs |

Revert : remplacer `ld a,#FF` par `xor a` dans
`code/vram_direct_rendering.asm` (bloc marqué DIAGNOSTIC TEMPORAIRE).

## RÉSOLU (diagnostic, 2026-08-19) — le buffer intermédiaire servait aussi de FENÊTRE DE PUBLICATION

Résultat du build diagnostic : la zone de la boule **montre le mur**, donc
le mur est bel et bien redessiné par-dessus. Et c'est **dépendant du sens
de déplacement** : vers le haut les boules survivent, vers le bas elles
sont mangées par le mur.

### La bonne question : « pourquoi ça changerait, l'ordre ne change pas ? »

L'ordre ne change effectivement pas. Ce qui change, c'est **la PORTÉE des
écritures publiées à l'écran**.

Dans le pipeline d'origine, le dessin d'une entité allait dans le buffer
**en entier**, mais seul le **rectangle sale** était recopié vers la VRAM
(`fn_blit_copy_line`, boucle différée). Le buffer était donc à la fois le
plan de composition **et une fenêtre de publication** : rien de ce qu'une
entité écrivait hors des rectangles sales n'atteignait l'écran.

Conséquence essentielle, et c'est le point qui manquait : **le buffer
avait le droit d'être localement FAUX hors des rectangles sales.** Quand
un bloc de mur était remarqué et redessiné, il écrasait dans le buffer les
pixels de la boule située devant lui — y compris loin du rectangle sale.
Invisible, puisque cette zone n'était pas publiée. Et auto-réparé : dès
que cette zone redevenait sale, tout ce qui la chevauche était remarqué et
redessiné dans le bon ordre de profondeur avant publication. Un schéma
**paresseux**, qui tolère une corruption locale du plan de composition.

Le dessin direct en VRAM supprime cette tolérance : il n'y a plus de
fenêtre de publication, chaque sprite redessiné publie **tout** son
étendue immédiatement. La corruption devient visible sur le champ.

### Pourquoi le sens de déplacement décide

Les sprites s'étendent vers le HAUT depuis `screen_y`. Le rectangle sale
est l'union bbox précédente ∪ courante, donc il s'étend dans le sens du
déplacement.

- **Joueur vers le bas** : le rectangle sale descend. La boule, au-dessus,
  ne le chevauche pas → pas de bit4 → pas redessinée. Le bloc de mur
  derrière le joueur, lui, chevauche → remarqué → redessiné **en entier**,
  donc par-dessus la boule. La boule disparaît.
- **Joueur vers le haut** : le rectangle sale monte et atteint la boule →
  bit4 posé → la boule est redessinée, après le mur (ordre de profondeur
  correct). Tout va bien.

Ça explique aussi les cubes empilés « pas systématiquement » : même
mécanisme, selon que le cube du dessous tombe ou non dans le rectangle
sale du mouvement.

### Ce qui est donc requis, et ne l'était pas avant

Invariant d'origine : *VRAM = buffer, restreint aux rectangles sales* — il
suffisait que le composite soit juste DANS ces rectangles.

Invariant nécessaire en dessin direct : **si une entité E est redessinée,
toute entité devant E qui chevauche E doit l'être aussi**, transitivement,
dans l'ordre de profondeur. Le marquage actuel
(`fn_entity_fall_and_mark_overlap`) ne fait que le premier anneau, à
partir du rectangle sale du seul mobile.

### Trois options

1. **Fermeture du marquage (recommandé).** Après la passe 1, itérer : pour
   chaque entité portant bit4, remarquer celles qui chevauchent SA bbox
   écran, jusqu'à point fixe. Conserve l'optimisation par rectangles
   sales ; l'ensemble redessiné est exactement celui qui était corrompu,
   donc minimal et correct. Coût : quelques balayages de 40 entités par
   frame (~1600 cycles par entité marquée) + les sprites supplémentaires
   réellement nécessaires.
2. **Tout redessiner chaque frame.** Neutraliser le `res 4` de
   `fn_sprite_pipeline_setup` (4 octets → 4 `nop`). Correct et trivial :
   avec tous les sprites repeints dans l'ordre de profondeur, le composite
   est globalement juste, et les rectangles sales continuent d'effacer les
   anciennes positions. Mais 4 à 8× le travail de blit — c'est renoncer à
   l'optimisation même que le moteur implémente.
3. **Écrêter le blit aux rectangles sales.** Le plus fidèle (aucun sprite
   supplémentaire), mais il faut découper chaque ligne de sprite contre N
   rectangles à l'intérieur de `fn_blit_masked`, la boucle la plus chaude
   du jeu.

### Leçon générique (versée dans docs/METHODOLOGY.md)

Un buffer intermédiaire peut remplir **deux rôles distincts** : plan de
composition ET fenêtre de publication. Le second est invisible dans le
code du buffer — il vit dans la routine de copie, sous la forme du
rectangle qu'elle recopie. Supprimer le buffer supprime aussi cette
fenêtre, et **durcit des invariants qui étaient jusque-là seulement
paresseux** : ce qui n'était qu'une corruption locale tolérée devient un
défaut visible. Avant de supprimer un buffer, se demander non pas « qui
écrit dedans ? » mais « qu'est-ce que sa copie partielle CACHAIT ? ».

### Correctif implémenté — fermeture du marquage (option 1)

`fn_mark_closure_then_cull` (`code/vram_direct_rendering.asm`, `#3132-#3176`)
+ `fn_mark_count` (`code/rendering_pipeline.asm`, `#2EAE-#2ECA`, dans les
octets libérés par l'ex-boucle de blits différés).

Algorithme : tant que le nombre d'entités portant bit4 augmente, pour
chaque entité marquée, remarquer celles qui chevauchent sa bbox écran.
Le marquage ne fait qu'AJOUTER des bits, donc le compte est monotone et
son invariance détecte le point fixe — pas besoin d'un drapeau
« modifié ».

**Réutilise `fn_entity_fall_and_mark_overlap` (`#25FF`) sans la modifier.**
Elle convient telle quelle : pour une entité statique, bbox précédente ==
courante, donc l'union qu'elle calcule EST sa bbox ; et son
`fn_entity_recompute_screen_bbox` (`#25E5`) est pur (reprojection +
`screen_w`/`screen_h`) et fournit la hauteur **non écrêtée**, exactement
ce qu'il faut pour un test de chevauchement — la valeur stockée par le
blit est écrêtée à `y < 192`, donc trop petite au plafond.

Vérifié au passage que le `fn_resolve_sprite_shape` appelé en dessous
fait un **double RET** quand la forme est vide : il dépile le retour dans
`fn_entity_recompute_screen_bbox` puis celui dans
`fn_entity_fall_and_mark_overlap`, donc l'exécution reprend dans la boucle
de marquage avec les `w/h` précédents. Pas de déséquilibre de pile, et
c'est le chemin qu'emprunte déjà `loc_1F7B`.

Détails :
- **Placement dans la frame** : AVANT `fn_cull_entities`, qui fige
  `buf_visible_entities` pour la frame. Le point d'appel de
  `fn_arm_room_transition_flag_and_wait` passe de `call fn_cull_entities`
  à `call fn_mark_closure_then_cull`, qui enchaîne par tail-call — même
  longueur d'instruction, aucun décalage (`#060F = CD 32 31`, suivi de
  `CD E2 2D` inchangé).
- **Seul bit4 est posé**, jamais bit5 : ces entités n'ont pas bougé, il
  n'y a pas d'ancienne position à effacer.
- **Borne de 4 passes.** La convergence naturelle demande 2 à 3 passes
  (un anneau de sprites de taille comparable). Faute de place sous `#8000`
  pour un marqueur « déjà étendu » (40 octets), une entité marquée est
  ré-étendue à chaque passe : sans effet (ses voisines portent déjà bit4)
  mais au prix d'un balayage de 40 entités.
- **Coût à vide** : 2 balayages de 40 entités (~2000 cycles), négligeable.

Adresses littérales vérifiées inchangées : `#062F`, `#0654`, `#170D`,
`#25FF`, `#26F7`, `#2DE2`, `#2EDC`, `#2F8D`, `#3186`. Marge restante sous
`#8000` : 15 octets (`#3177-#3185`) + 17 octets (`#2ECB-#2EDB`).

**À surveiller en jeu** : plus d'entités redessinées = plus de paires
traitées par le tri en profondeur, donc plus de pression sur
`tbl_collision_pending` (`#28AF`, 8 octets, débordement **sans contrôle
de borne** au-delà de 7 reports simultanés — bug latent du moteur
d'origine). Si des défauts d'ordre persistent sur les scènes chargées
(cubes empilés), c'est le suspect n°1, et il est indépendant de la
migration VRAM.

### Mesure : l'option 1 cascade — DÉBRANCHÉE

Constat en jeu : extrêmement lent. La fermeture propage les zones sales
jusqu'à **quasiment toute la scène dès qu'un seul rectangle sale existe**.

Cause, et c'est une propriété de la scène, pas de l'implémentation : **le
décor d'une salle est un maillage CONNEXE.** Les blocs de sol, de mur et
les plateformes se touchent tous. La fermeture transitive du chevauchement
écran d'un ensemble connexe, c'est l'ensemble entier. On retombe donc sur
« tout redessiner chaque frame » (option 2), avec en plus le coût des
balayages de marquage.

Le code (`fn_mark_closure_then_cull`, `fn_mark_count`) est conservé mais
**débranché** (`call fn_cull_entities` restauré à l'identique en `#0612`),
avec un en-tête expliquant le résultat. L'analyse qui l'a motivé reste
juste ; c'est la géométrie de la scène qui la rend inutilisable.

### Conséquence : seule l'option 3 (écrêter le blit) peut marcher

Les trois options se réduisent en fait à une. Récapitulatif de ce que la
mesure a éliminé :

| Option | Verdict |
|---|---|
| 1. fermeture du marquage | **éliminée** — cascade sur décor connexe, mesurée |
| 2. tout redessiner | correcte mais 4 à 8× le blit ; c'est ce que l'option 1 produit en pratique |
| 3. écrêter le blit aux rectangles sales | **seule voie viable** |

Et aucune variante bon marché n'existe : étendre l'effacement à ce qui sera
repeint ramène à la cascade ; écrêter à l'union des rectangles laisse la
corruption **à l'intérieur de l'union mais hors des rectangles** (donc
faux) ; n'écrêter qu'en Y réduit sans supprimer. Le raisonnement est
fermé : il faut écrêter en 2D, rectangle par rectangle.

### Conception de l'option 3

Point favorable inattendu : **la réécriture de `fn_blit_masked` en vraies
boucles (faite ce matin pour libérer de la place) est précisément ce qui
rend l'écrêtage possible.** Les familles déroulées d'origine encodaient la
largeur dans le point d'entrée — impossible d'y faire varier début et
longueur par ligne. La version en boucle porte déjà la largeur dans
`var_blit_width`/`var_blit_cols`.

Autre point favorable : le blit masqué est **idempotent** (`ecran =
ecran & masque | couleur`, masque et couleur ne dépendent que de l'octet
de forme). Dessiner une entité écrêtée au rectangle R1 puis au rectangle
R2 donne donc le même résultat qu'un écrêtage à R1 ∪ R2, sans se soucier
des recouvrements. **Un écrêtage à UN seul rectangle à la fois suffit** —
beaucoup plus simple qu'un découpage contre N rectangles par ligne.

Trois pièces :

1. **Liste des rectangles sales.** L'original la portait sur la PILE (les
   `push bc/de/hl` de `fn_stage_blit_and_clear`, dépilés par la boucle
   différée) — c'est justement ce que j'ai neutralisé. La reconstituer
   comme une table de 4 octets par rectangle (`y0`, hauteur, `x0` en
   colonnes, largeur), comptée par `var_blit_stack_counter` qui est déjà
   incrémenté. 40 rectangles max = 160 octets, à loger dans `#9000+`
   (libre).
2. **`fn_sprite_pipeline_setup`** : au lieu de dessiner une fois, boucler
   sur la table et dessiner une fois par rectangle réellement chevauché,
   en posant la fenêtre d'écrêtage. C'est le bon endroit : appelée une
   fois par entité, elle contient déjà tout le calcul de forme.
3. **Boucle de ligne de `fn_blit_masked`** : sauter les lignes hors
   `[y0, y0+h)` ; pour les autres, avancer `DE` (données de forme) et `BC`
   (écran) de `c0` colonnes, dessiner `n` colonnes, puis repartir du début
   de ligne sauvegardé.

Coût attendu : par ligne de sprite, un test de rectangle (~20 cycles)
contre ~960 cycles de blit pour une ligne pleine de 16 colonnes. Les
lignes entièrement écrêtées ne coûtent plus que le test. Le résultat
devrait être **plus rapide que l'état actuel**, et probablement plus
rapide que l'original puisqu'il n'y a plus de passe de copie du tout.

### Décision à prendre avant de coder

C'est le plus gros morceau de la branche, et il touche la boucle la plus
chaude du jeu. Or le gain de la piste 3 s'est réduit en route : le double
buffer matériel **ne rentre pas** (36 352 octets à placer dans 32 768, voir
plus haut), donc libérer `#9000-#BFFF` ne sert plus cet objectif — il reste
12 Ko libres pour autre chose, et l'économie de la passe de copie.
À arbitrer : implémenter l'écrêtage, ou refermer la piste 3 en documentant
que le buffer intermédiaire n'est pas un gaspillage mais **la fenêtre de
publication du rendu par rectangles sales**, ce qui est en soi une
conclusion utile pour `docs/OPTIMISATION.md`.

## Option 3 IMPLÉMENTÉE (2026-08-19) — écrêtage du blit aux rectangles sales

Nouveau fichier `asm/code/vram_clip_rendering.asm`, `org #9000`
(`#9000-#92E6`, 743 octets). `#9000+` est maintenant un emplacement
légitime pour du code neuf : la migration du chemin glyphes a supprimé la
dernière référence à `BUF_PRERENDER_BASE`, et le `.sna` réassemblé ne
contient plus un octet non nul dans `#9000-#BFFF`. Le commentaire de
`knight_lore.asm` qui interdisait cette zone a été mis à jour.

### Ce qui a rendu ça faisable, et simple

- **Faisable** : la réécriture de `fn_blit_masked` en vraies boucles ce
  matin. Les familles déroulées encodaient la largeur dans le point
  d'entrée — début et longueur variables par ligne étaient hors de portée.
- **Simple** : le blit masqué est **idempotent** (`écran = écran & masque |
  couleur`, masque et couleur ne dépendant que de l'octet de forme).
  Écrêter à R1 puis à R2 équivaut donc à écrêter à R1 ∪ R2 : on écrête à
  **un seul rectangle à la fois** et les recouvrements sont sans effet.
  Pas de découpage d'intervalles contre N rectangles par ligne.

### Les trois pièces

1. **`tbl_dirty_rects`** (`#9000`, 40 × 4 octets : ytop, hauteur, colonne,
   largeur). C'est la liste que l'original portait **sur la pile** — les
   `push bc/de/hl` de `fn_stage_blit_and_clear`, dépilés par la boucle de
   blits différés, exactement ce que la migration avait neutralisé.
   Remplie par `fn_dirty_rect_store`, branchée dans les `nop` de bourrage
   de `fn_stage_blit_and_clear` (`#2E76 = CD BA 90`), avant l'incrément de
   `var_blit_stack_counter` qui sert donc d'index.
2. **`fn_blit_clip_driver`** (`#90FD`), branchée à `#2F2B` (`C3 FD 90`).
   `#2F2B` est aussi le **point d'entrée alternatif** du pipeline sprite
   (HUD, bordures : ils posent `screen_x/y` à la main et sautent
   projection et culling) ; les 3 octets `call fn_resolve_sprite_shape`
   deviennent un `jp` vers le driver, qui commence par ce même appel. Le
   driver calcule la géométrie du sprite, puis boucle sur les rectangles
   avec un rejet rapide en Y, calcule l'intersection en colonnes et
   dessine une fois par rectangle réellement chevauché. Tout le corps
   `#2F2E-#2F8A` devient mort (laissé en place : longueur contrainte).
3. **`clip_blit`** — deux boucles complètes (décalée / alignée, corps de
   colonne repris à l'identique de l'original avec le `inc bc` au lieu de
   `inc c`). Par ligne : test contre `[rect_ymin, rect_ymax]`, saut de
   ligne si dehors, sinon décalage de `DE`/`BC` de `col_skip`, `n`
   colonnes, puis retour au début de ligne sauvegardé. Comme `screen_y`
   croît d'une ligne à l'autre, **sortie anticipée** dès qu'on dépasse
   `rect_ymax`.

### Périmètre de l'écrêtage : drapeau explicite, pas d'heuristique

L'écrêtage est actif **uniquement** pendant la passe de dessin des
entités, via `fn_collide_clipped` posée à la place de
`call fn_check_collisions` (`#2E97 = CD F0 90`, même longueur).

Une première version testait `var_blit_stack_counter != 0` comme
heuristique — **faux** : ce compteur n'est remis à zéro qu'à l'entrée de
`fn_render_entities`, il porte donc encore le compte de la frame quand
`fn_render_disabled_one_time_setup`, les écrans de menu et de game over
dessinent via `#2F2B` **après** la passe entités. Ces dessins auraient été
écrêtés aux rectangles des entités et auraient disparu — exactement la
famille de bug rencontrée trois fois dans cette session. Le drapeau
explicite ferme la question.

Les routines HUD (jour/nuit, notification de slot) gèrent leur propre
effacement hors du mécanisme de rectangles sales : elles restent donc
appelées directement, en dessin complet.

### Deux gardes ajoutées au passage

- `w == 0` (octet de forme dégénéré, possible si le bit de flip est posé
  avec une largeur nulle) → 16 colonnes, ce que faisait l'entrée 0 du
  déroulement d'origine. Sans ça, le compteur de colonnes bouclerait 256
  fois.
- `screen_y > 192` → sortie. Atteignable par `#2F2B`, qui saute le
  culling ; l'original y calculait une hauteur écrêtée négative et
  dessinait du bruit.

### Vérifications

Adresses littérales inchangées : `#170D`, `#1752`, `#176B`, `#2750`,
`#26F7`, `#2DE2`, `#2E6C`, `#2EDC`, `#2F17`, `#2F8D`. `#8000-#8FFF`
toujours vide (la pile est en `#2D9B`). Build propre, `ASSERT` de
`fn_menu_glyph_unpack` satisfait.

### À évaluer en jeu

1. **Correction** : boules à pics de la room `0x4F` en descendant, cubes
   empilés, HUD, menu, game over, matérialisation.
2. **Vitesse.** Deux effets opposés : beaucoup moins de pixels écrits
   (c'est le but), mais la boucle de colonne coûte ~40 cycles de
   compteur par colonne là où le déroulement d'origine n'en coûtait
   aucun — dette contractée ce matin en remplaçant les familles déroulées
   pour libérer de la place. Si le résultat est correct mais lent, le
   remède est net : **re-dérouler la boucle de colonne**, ce qui est
   maintenant possible sans contrainte puisqu'il reste ~11 Ko libres en
   `#9000+`. C'est une passe d'optimisation séparée, sans risque de
   régression fonctionnelle.

### Correctif — deux largeurs confondues (colonnes ÉCRAN vs colonnes de DONNÉES)

Symptômes rapportés : certains sprites (décor, personnages) incorrects, et
« l'impression d'un décalage vers la droite, comme si on dessinait des
zones trop larges ». Les boules de la room `0x4F` étaient correctes et la
vitesse était revenue — donc l'écrêtage fonctionne, le défaut était dans
la géométrie.

Cause : **la variante à décalage sub-octet écrit DEUX octets écran adjacents
par colonne de DONNÉES** (`col0+i` et `col0+i+1`). Son étendue écran vaut
donc `w+1`, alors que les données de forme font toujours `w` octets par
ligne. J'utilisais la même variable (`clip_cols` = `w+1`) pour les deux
rôles — d'où un pas de ligne d'un octet de trop dans les données de forme,
qui décale chaque ligne d'un cran vers la droite et cumule. Exactement le
symptôme décrit, et il ne touche que les sprites dont `screen_x & 3 != 0`,
donc en apparence « certains sprites ».

Quatre endroits corrigés :
1. `clip_draw_whole` (dessin complet : HUD, menu, game over,
   matérialisation) posait `clip_col_n = clip_cols` → une colonne de trop.
2. Le saut de ligne hors fenêtre avançait `DE` de `clip_cols`.
3. `clip_col_after` était calculé depuis `clip_cols`.
4. L'intersection en colonnes travaillait en colonnes écran. Elle passe
   maintenant en colonnes de données : la colonne `i` intersecte la fenêtre
   si `col0+i <= c_end` **et** `col0+i+1 >= c_start`, d'où un `-1` sur le
   début (variante décalée seulement) et un plafonnement à `w-1` sur la
   fin. `n_data >= 1` est garanti dans tous les cas (démonstration par cas
   dans le commentaire du fichier).

Au passage : deux `jr z,clip_draw_whole` sont devenus hors de portée après
l'insertion, passés en `jp`. **Le build avait signalé « 2 errors » et le
`.sna` n'avait donc pas été régénéré** — piège à retenir, `rasm` écrit son
message d'erreur puis rend un code de sortie qu'un `grep` sur la sortie
peut masquer. Toujours lire la queue complète de la sortie.

### Résidu connu, non corrigé

Variante à décalage sub-octet uniquement : une colonne de données écrivant
2 octets écran, la colonne de bord de fenêtre déborde d'un octet
(4 pixels) à gauche et/ou à droite du rectangle sale. Cela ne concerne que
les sprites qui **chevauchent un bord** de rectangle (un sprite entièrement
contenu n'est pas écrêté du tout, cas courant). Suppression possible via un
corps de colonne « premier octet seulement » pour la dernière colonne — à
faire seulement si c'est visible en jeu.

Vérifications : `#2F2B = C3 FD 90`, `#2E76 = CD BA 90`,
`#2E97 = CD F0 90`. Adresses littérales inchangées (`#170D`, `#1752`,
`#176B`, `#2750`, `#26F7`, `#2DE2`, `#2E6C`, `#2EDC`, `#2F17`, `#2F8D`).
Code neuf `#9000-#92FF`.

### Écrêtage exact de la variante décalée — résidu supprimé

Confirmé en jeu : liseré de 4 pixels à droite du rectangle sale du joueur,
sur le cube voisin. Exactement le débordement prévu.

Cause : une colonne de données de la variante décalée écrit **2 octets
écran adjacents** (`col0+i` et `col0+i+1`). Les colonnes de bord de fenêtre
en débordent donc d'un octet. Les colonnes de bord ont maintenant leur
propre corps :

- **1re colonne rognée à gauche** → 2e octet seulement (pages `H+2`/`H+3`,
  masque 2 / couleur 2). Le `inc bc` passe devant l'écriture.
- **dernière colonne rognée à droite** → 1er octet seulement (pages
  `H`/`H+1`), le 2e est supprimé.

Les deux drapeaux (`clip_trim_first` / `clip_trim_last`) sont calculés dans
le driver. Ils ne peuvent pas être demandés simultanément sur une colonne
unique : le rognage gauche implique `col0+d_last+1 = c_start <= c_end`,
donc pas de rognage droit — vérifié par cas, noté dans le fichier.

La variante alignée écrit 1 octet par colonne : son écrêtage était déjà
exact, elle n'est pas touchée.

Piège rencontré deux fois de suite : **`rasm` refuse les `jr` hors de
portée et n'écrit alors PAS le `.sna`**, tout en laissant un `.sna`
précédent en place. Un `grep` sur la sortie qui rate la ligne d'erreur fait
croire à un build réussi et on teste l'ancien binaire. Cinq `jr` sont
passés en `jp` au fil des insertions. **Lire la queue complète de la sortie
de `rasm`, systématiquement.**

État : `#2F2B = C3 00 91`, `#2E76 = CD BD 90`, `#2E97 = CD F3 90`.
Adresses littérales inchangées. Code neuf `#9000-#9365`.

## Déroulement des boucles de colonne (2026-08-19) — dette du matin remboursée

Retour utilisateur : plus aucun glitch visuel, un peu plus lent qu'avant la
migration. La cause est identifiée depuis ce matin : les familles déroulées
d'origine avaient été remplacées par de vraies boucles pour libérer de la
place, ce qui ajoute ~42 cycles de compteur par colonne sur ~103 cycles de
corps utile.

Les deux corps de colonne sont donc re-déroulés à 16 unités, dans `#9000+`
où la place ne contraint plus rien :

- `clip_shift_unroll` : 16 × 18 octets = 288 (`ASSERT` dans le source) ;
- `clip_aligned_unroll` : 16 × 10 octets = 160 (`ASSERT`).

L'unité assemblée est **octet pour octet celle de l'original**, au
`inc bc`/`inc c` près (la retenue non propagée de l'original est fausse en
VRAM, où les débuts de ligne ne sont pas alignés sur une page).

### Le mécanisme d'entrée, et ce qui change par rapport à l'original

Même principe « duff device » : `jp` en tête de ligne dont l'opérande est
poké, entrée = `base + (16 - m) * taille_unité`. Deux différences :

- l'index vient du nombre de colonnes **écrêtées** `m`, pas de la largeur du
  sprite — donc un seul bloc déroulé au lieu d'un par largeur ;
- l'opérande est pokée **une fois par (entité, rectangle)** par
  `clip_setup_unroll`, jamais par ligne.

`m` = `clip_col_n` moins les colonnes de bord rognées, qui ont leur propre
corps hors du bloc. Pour `m = 0` (toutes les colonnes de la fenêtre sont des
bords rognés) l'entrée tombe pile sur la fin du bloc, qui est donc sauté —
aucun cas particulier à écrire.

`m <= 16` est un invariant du moteur : les familles d'origine avaient
exactement 16 entrées et `fn_entity_recompute_screen_bbox` masque la largeur
par `#0F`. Hors invariant, on retombe sur l'entrée 16 colonnes (comportement
de l'original, qui faisait `(-w) & 15`).

Vérifié dans le `.sna` : `#92E0 = C3 E3 92`, `#9455 = C3 58 94`, tailles de
bloc 288 et 160, unité décalée
`1A 13 6F 0A A6 24 B6 24 02 03 0A A6 24 B6 02 25 25 25`. Adresses
littérales inchangées. **Cinq `jr` supplémentaires** sont passés en `jp` au
fil des insertions (portée dépassée) — toujours lire la queue complète de la
sortie de `rasm`.
