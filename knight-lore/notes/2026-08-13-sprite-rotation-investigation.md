# Enquête sur la rotation 90° des sprites — nouvelle preuve, contradiction non résolue

Reprise du mystère laissé ouvert depuis le 2026-08-10 (`docs/SESSION_SUMMARY.md`
§15, `tools/sprite_dump.py`) : le bitmap décodé selon le format confirmé
(en-tête 3 octets, `row_bytes=V` directement, 2 bits/pixel) apparaît
"couché sur le côté" tant qu'on ne lui applique pas une rotation de
90° après coup — cause jamais tracée.

## Nouvelle preuve empirique (2026-08-13) : le blit lui-même ne transpose RIEN

Trace live directe (breakpoint sur `#30AD`, la fin de boucle partagée
de la variante "alignée" de `fn_blit_masked`, atteinte une fois par
ligne de sprite dessinée, sans filtrer par entité — capturé sur
l'entité joueur en cours de jeu réel) :

```
IX=00D7 BC=A82A DE=6E27
IX=00D7 BC=A86A DE=6E2D   (+64, +6)
IX=00D7 BC=A8AA DE=6E33   (+64, +6)
IX=00D7 BC=A8EA DE=6E39   (+64, +6)
...
```

**`BC` (pointeur buffer/destination) avance EXACTEMENT de `+64` par
ligne — la stride de ligne du buffer intermédiaire déjà documentée.
`DE` (pointeur source/forme) avance EXACTEMENT de `+6` par ligne — la
largeur (`V=6`) de cette forme.** Aucune des deux progressions ne
trahit de transposition : la boucle interne (confirmée par
désassemblage direct, `#30E3-#30F6`) avance `BC` de `+1` par octet
source consommé (donc V fois par ligne, horizontalement), la boucle
externe partagée (`#30AD-#30BA`) fait le reste du saut jusqu'à `+64`
au total — un saut de ligne à ligne PARFAITEMENT CONSTANT et
indépendant de `V`, exactement ce qu'on attend d'un buffer rangé en
mode ligne normale (row-major), sans rotation.

Vérifié aussi statiquement : `fn_buffer_addr_from_vram` (`#3186`)
calcule `buffer_addr = #9000 + 64*screen_y + screen_x/4` (division par
4 via 2 rotations 16 bits) — encore une fois une adressage row-major
tout à fait standard, `screen_y` multipliant par la stride de ligne,
`screen_x` donnant la position fine dans la ligne. Et
`fn_blit_copy_line` (`#2EC0`, buffer→VRAM) ne fait qu'un décalage
Y (entrelacement CRTC `+#0800`/`+#C050`, source qui recule de `-64`
par ligne pour le flip vertical) — encore aucune transposition
ligne/colonne là non plus.

**Conclusion de cette partie : la chaîne complète (forme→buffer,
buffer→VRAM) est, à chaque étape vérifiée aujourd'hui, un simple
adressage ligne-majeure standard, SANS transposition.** Ceci contredit
directement la conclusion du 2026-08-10 ("le bitmap construit tel
quel... ne l'est PAS visuellement" à l'endroit sans rotation).

## Vérification visuelle directe — la rotation ET son sens sont CONFIRMÉS (pas remis en cause)

Capture d'écran réelle obtenue (salle `#00`, slot 2, bouteille) avec
`(ix+16)`/`(ix+17)` vérifiés non-nuls (`screen_x=#04`, `screen_y=#54`)
avant la capture — contrairement à un essai précédent dans la même
session où ces champs étaient encore à `#00` (entité pas encore dans
le buffer de rendu, culling normal). Crop pixel-exact de la bouteille
dans cette capture : goulot/bouchon sombre en haut, corps arrondi,
fenêtre/étiquette centrée.

**Tentative d'inverser le sens de rotation (`ROTATE_270` au lieu de
`ROTATE_90`), testée puis REJETÉE** : un script de test ponctuel
comparant les deux sens sur la seule bouteille a d'abord semblé
suggérer que `ROTATE_270` était le bon sens — mais en régénérant le
jeu COMPLET des 103 sprites avec ce changement, le résultat général
(planche de contact) était nettement MOINS reconnaissable que
l'original (formes allongées/méconnaissables au lieu des silhouettes
nettes déjà documentées). Vérification décisive : comparaison de hash
MD5 du rendu du rubis (`#4687`) régénéré avec `ROTATE_90` (inchangé)
contre le fichier historique déjà nommé "ruby" en 2026-08-10 —
**identique bit à bit**, et visuellement un diamant/gemme net et
reconnaissable. Le fichier bouteille régénéré avec `ROTATE_90` montre
lui aussi une forme cohérente avec une bouteille (bouchon sombre,
corps, fenêtre, reflet clair sur le côté). **Conclusion : le script de
test ponctuel avait un bug (probablement une confusion dans l'ordre
d'application resize/rotation, pas identifiée précisément) qui donnait
l'impression trompeuse que `ROTATE_270` était meilleur — `ROTATE_90`
(le code existant, inchangé) est bien le sens correct.**
`tools/sprite_dump.py` n'a donc PAS été modifié sur ce point (le
docstring de `shape_to_image()` documente maintenant cette tentative
rejetée, pour ne pas la retenter sans repartir de ce constat).

## État à la fin de cette session

La rotation de 90° (sens antihoraire, `ROTATE_90`) reste NÉCESSAIRE et
CONFIRMÉE dans le bon sens — aucune régression, `tools/sprite_dump.py`
inchangé sur ce point (seul un docstring obsolète en tête de fichier,
qui citait encore l'ancienne hypothèse "monochrome 1 bit/pixel" fausse
depuis 2026-08-10, a été corrigé).

**Ce qui est réellement nouveau et solide cette session** : la PREUVE
empirique directe (trace live, pas une inférence) que ni le blit
(`fn_blit_masked`), ni le calcul d'adresse buffer
(`fn_buffer_addr_from_vram`), ni le flush vers la VRAM
(`fn_blit_copy_line`) ne transposent quoi que ce soit — les trois
étapes sont un adressage ligne-majeure standard, bout en bout.

**Suite (même session) : `fn_isometric_project` (`#2EDC`) désassemblée
en entier — quatrième candidat éliminé.** Formule complète (confirmée
numériquement depuis une session antérieure, mais jamais recopiée
intégralement jusqu'ici) :
```
screen_x = grid_x + grid_y - #80 + proj_offset_x
screen_y = (grid_y - grid_x + #80)/2 + grid_z_or_offset - #68 + proj_offset_y
```
C'est très exactement la formule isométrique standard "somme
diagonale / différence diagonale" (le moteur "Filmation" bien connu de
cette génération de jeux Ultimate Play The Game) — `screen_x`/`screen_y`
qui en résultent sont de vraies coordonnées écran horizontale/verticale,
pas un repère interne pivoté. Aucune trace d'un axe échangé ici non
plus.

**Bilan : 4 candidats sur 4 examinés (projection, blit, adressage
buffer, flush VRAM) — tous confirmés sans transposition.** La cause
exacte de la nécessité de la rotation reste donc un mystère non résolu
après une recherche assez exhaustive dans le pipeline de rendu
lui-même. Meilleure hypothèse restante (non vérifiée) : la rotation ne
vient d'AUCUNE étape du pipeline, mais du CONTENU même des données de
forme dans la ROM — c'est-à-dire que l'artiste/l'outil de 1984 a
authored les bitmaps avec ses propres lignes/colonnes déjà pivotées de
90° par rapport à l'orientation finale à l'écran (pour une raison
interne à leur pipeline de production, jamais retraçable depuis le
binaire seul). Cohérent avec un indice déjà noté sans être exploité :
`fn_flip_sprite_shape` (`#31E9`) traite le bit7 de l'octet d'en-tête
comme un flip VERTICAL (échange de lignes) et le bit6 comme un flip
HORIZONTAL réel — si l'convention de stockage est bien pivotée de 90°
par rapport à l'écran, ces deux flips, vus depuis l'écran final,
échangeraient de rôle (un flip "vertical" en mémoire deviendrait un
flip horizontal à l'écran) ; piste non vérifiée empiriquement cette
session, mais cohérente avec tout ce qui a été confirmé aujourd'hui,
et bien plus tractable qu'une 5e relecture du pipeline de rendu :
comparer en jeu un sprite dont on observe un flip HORIZONTAL réel à
l'écran avec le bit effectivement modifié par `fn_flip_sprite_shape`
pour cette occurrence précise.
