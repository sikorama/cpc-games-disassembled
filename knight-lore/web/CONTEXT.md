# Glossaire — portage web Knight Lore

## Vue canonique
La vue isométrique unique, fixe, correspondant à l'angle du jeu CPC
d'origine (touche `C` dans le portage web : "vue d'origine"). C'est la vue
pour laquelle tout le pipeline de rendu (tri peintre, ancres de sprite,
table de calibration `proj_offset_x/y`, mirroir de sprite) a été calibré
empiriquement. Toutes les données extraites (sprites, offsets) sont
correctes *pour cette vue seulement*.

## Portage iso-2D à 4 vues
Tentative de proposer 4 orientations isométriques discrètes en tournant
les **données de grille** (`rotateGrid()`) plutôt que la caméra — la
projection reste une fonction pure de `(grid_x, grid_y, grid_z)` calibrée
pour la [[Vue canonique]]. Distinct d'une vraie caméra 3D libre : aucun
modèle 3D, toujours des sprites 2D pré-rendus. Un mode "orbite" (caméra
libre, vraie 3D) a été tenté puis retiré : il casse le tri peintre
(calibré pour un seul angle) et suppose une projection orthonormée que la
projection isométrique 2:1 du jeu n'est pas.

Statut : implémenté, mais avec des défauts non résolus propres aux vues
1/2/3 (pièces asymétriques sans table de remap connue, murs de devant
manquants). Une session entière a été perdue sur une fausse piste de
correction de signe d'axe pendant ce travail (voir
`notes/2026-08-15-web-axis-convention-and-4-views.md`) — le code final
n'a pas de bug lié à cette fausse piste, mais l'épisode illustre la
difficulté à généraliser la vue.

## Modèle physique de grille
Le jeu d'origine représente déjà le monde en coordonnées 3D abstraites
(`grid_x`/`grid_y`/`grid_z_or_offset` par entité), et sa routine de
collision (AABB 3D, `0x2750-0x27F7`) opère sur ces coordonnées, pas sur
des coordonnées écran/projetées — la projection isométrique
(`screen_x = grid_x + grid_y - 0x80 + proj_offset_x`, etc.) est une
fonction séparée, appliquée en aval, uniquement pour l'affichage. Le
code Z80 original mélange les deux dans la même boucle (raison
historique : mémoire/vitesse sur CPU 8 bits), mais le **modèle de
données**, lui, sépare déjà physique et rendu. Conséquence pour le
portage : on peut réutiliser le [[Modèle physique de grille]] comme
moteur physique indépendant du renderer, sans que ça implique de passer
en [[Remake 3D]] — la 3D reste une question de couche de rendu, pas de
modèle de données.

**Confirmé** : le jeu d'origine n'a aucune collision fine par forme —
tout passe par le même mécanisme générique (`fn_check_collisions`,
dispatch `0x27FE`, champ `(ix+0C)` bits 0/1), y compris pour des entités
visuellement rondes (balle rebondissante 0xB2/0xB3, cf.
`notes/2026-08-07-entity-logic-bouncing-ball.md`). Décision pour le
portage : étendre le [[Modèle physique de grille]] avec des **formes de
collision simples** par entité (sphère pour les ennemis ronds, boîte
pour le reste), en plus de l'AABB générique hérité du jeu original — un
raffinement de fidélité, pas une nécessité du jeu d'origine. Ça reste
une couche purement physique, indépendante du rendu : ne justifie PAS
de passer au [[Remake 3D]] visuel.

C'est un **écart assumé** vis-à-vis de l'original, pas de la fidélité —
l'original n'a rien de tel. Inscrit comme tel dans `web/DEVIATIONS.md`.

## Remake 3D
Option future distincte du [[Portage iso-2D à 4 vues]] : recréer des
assets 3D complets (modèles, textures) pour le jeu, potentiellement avec
caméra libre. N'a pas commencé — à ne documenter en détail que si cette
piste est effectivement engagée.

## Miroir de sprite (double-miroir)
Les sprites extraits de la ROM (`tools/sprite_dump_out/`) sont des images
miroir du rendu réel, à cause d'un `ROTATE_90` non expliqué dans
`tools/sprite_dump.py`. Le portage compense actuellement en appliquant un
second miroir qui annule le premier — un système cohérent mais fragile
(une correction partielle casse tout). Cause profonde du miroir non
identifiée (hypothèse non vérifiée : sprites *authored* pré-pivotés en
1984 pour une raison de pipeline de production perdue).

## Personnage en deux entités
Les personnages (joueur, garou, garde, etc.) sont rendus comme deux
entités indépendantes empilées à l'exécution — un "corps" et des
"jambes" — chacune avec son propre sprite et son propre offset de
calibration ROM. Ce n'est pas un artefact du portage web : c'est le
mécanisme du moteur d'origine.

**Garde/Melkhior** : plages confirmées — corps 0x1E/0x1F/0x9E/0x9F,
jambes 0x90-0x9D.

**Loup-garou (nuit)** : plages confirmées — corps 0x40-0x4F
(`sprite_werewulf_up...`), jambes 0x30-0x3D (`sprite_werewulf_feet...`).

**Joueur (jour)** : plages CONFIRMÉES (2026-09-04, `tbl_sprite_dispatch`
#429E) — jambes 0x10-0x15 (`feet1-4`) et 0x18-0x1D (`feet5-8`), corps
0x20-0x25 et 0x28-0x2D (`hero_up...`). L'ancienne hypothèse « 0x10-0x1D =
jambes, non vérifiée » est tranchée, et l'attribution empirique du portage
est remplacée.

**Hiérarchie jambes → corps** : ce n'est pas une paire symétrique. L'entité
JAMBES porte la position, la phase d'animation et l'orientation ; le CORPS
en est entièrement dérivé, recalculé chaque frame (`corps.type =
jambes.type + 0x10`, position recopiée, élévation `+0x0C` en Z). Le corps ne
possède aucun état propre. Conséquence pour le portage : un seul état
d'animation, dont les deux sprites sont dérivés — deux sélections
indépendantes rendent la désynchronisation possible, et c'est exactement ce
qui a produit le bug d'orientation des pieds.

**Pas de pose de repos** : il n'existe aucun sprite « debout immobile ». Le
cycle n'avance que si le personnage se déplace, donc à l'arrêt il **gèle sur
la phase courante**. Les images hors cycle (une par jeu de sprites) ne sont
pas des poses de repos : ce sont des poses alternatives rares tirées au
hasard et tenues quelques frames.

**Garde, corps** : loge son bit de jeu de sprites dans `type` bit0 et non
bit3 — d'où les paires 0x1E/0x1F (chevalier) et 0x9E/0x9F (Melkhior), qui
sont **deux orientations d'un même personnage**, pas deux personnages.

## Code d'orientation
Grandeur du moteur d'origine valant 0-3 (`0=-X, 1=+X, 2=+Y, 3=-Y`),
composée de deux bits qui ne jouent PAS le même rôle : l'un sélectionne un
**jeu de sprites entièrement différent** (deux dessins distincts, pas un
miroir), l'autre déclenche un **miroir horizontal au rendu**, appliqué
par-dessus le sprite déjà choisi. Utiliser le premier comme un flip donne un
résultat correct dans exactement une direction sur quatre.

Le joueur et le garde ne l'obtiennent pas de la même façon, et c'est
structurel : le joueur le **porte comme un état persistant** basculé par
l'input (il peut donc regarder quelque part sans bouger — le mode de
contrôle « rotation » en dépend) ; le garde n'en stocke aucun et le
**recalcule chaque frame depuis son vecteur de déplacement**. Ne pas unifier
les deux.

À ne pas confondre avec la **direction de patrouille** du garde, un entier
0-3 séparé qui suit un cycle géométrique (`-X, +Y, +X, -Y`) et non la
numérotation ci-dessus.

## Miroir effectif
Le retournement horizontal réellement appliqué à un sprite n'est jamais un
seul bit : c'est le XOR du bit de miroir **capturé dans les données du
sprite** (le jeu mute ce bit en place — ce n'est pas un état neutre), du bit
d'orientation de l'entité, et du retournement propre à la vue affichée.
N'en utiliser qu'un seul donne un résultat correct par accident.

## Grille monde 16×16
Le numéro de salle encode directement sa position dans une grille monde
16×16 : nibble bas = colonne, nibble haut = ligne (confirmé par
désassemblage, `fn_player_door_transition`, et indépendamment par
`tools/room_map/stitch.py`). La salle voisine dans une direction donnée
est une pure arithmétique sur ce numéro (±1 sur le nibble bas pour
Est/Ouest, ±0x10 pour Nord/Sud) — PAS une table de correspondance :
`tbl_room_connections` (0x0147), un temps soupçonnée de jouer ce rôle,
s'est avérée n'être que du décor de jonction (entités porte/mur affichées
à la frontière), jamais lue pour résoudre la salle cible.

## Franchissement de bord de salle
Le passage d'une salle à l'autre en marchant (voir [[Grille monde 16×16]])
se détecte par la position du joueur contre deux constantes universelles
de bord (`0x3B`/`0xC4`), vérifiées identiques sur un échantillon aléatoire
de salles — indépendantes de l'étendue réelle des murs, qui elle varie
par salle. Une entité porte (types 0x02/0x03) ne connaît jamais sa salle
cible (son champ `room` vaut sa propre salle) : c'est un pur repère visuel
de jonction, pas une donnée de navigation.

## Hypothèse de palette pen→encre — TENTÉE PUIS ANNULÉE (2026-09-04)
Le jeu tourne en Gate Array Mode 1 (2 bits/pixel, 4 pens 0-3, confirmé).
`tools/sprite_dump.py` calcule déjà la valeur de pen par pixel mais la
correspondance pen→encre CPC réellement utilisée **en salle** n'a jamais
été confirmée par trace live — point ouvert explicite (`docs/SYMBOLS.md`
#2F02 : "la couleur exacte ... reste à trancher").

Une palette dérivée de `tbl_ga_config_stream_boot` (#0055, chargée au
démarrage du **menu**, jamais confirmée active en salle) a été
implémentée puis **annulée le jour même** : elle donnait la MÊME encre
aux pens 2 et 3, aplatissant deux niveaux distincts — confirmé
visuellement (rendu à seulement deux teintes fluo, cyan/vert citron, jugé
pire que les silhouettes grises précédentes) et confirmé par
l'utilisateur ("il y a moins d'encres qu'avant"). Retour aux silhouettes
grises (`git checkout` sur `tools/sprite_dump.py` et
`web/src/gl/spriteBatch.ts`, régénération des PNG) — rien de ce chantier
n'a été committé. Le point ouvert reste entier ; toute future tentative
devra vérifier par trace live que les 4 pens donnent bien 4 encres
distinctes AVANT de régénérer quoi que ce soit, pas après coup.

## Bbox réelle (murs/portes)
Dimensions AABB réelles par entité (`bbox_w`/`bbox_h`/`bbox_d`,
`docs/SYMBOLS.md` +0x04-06), extraites de la table ROM statique
`tbl_room_connection_detail_*` (`tools/room_map/enrich_bbox.py`, sans
émulateur live) et jointes dans `rooms_manifest.json`. Couvre le décor de
jonction (murs, portes) — PAS le décor placé salle par salle (ex. blocs
intérieurs), qui garde un footprint deviné (confirmé correct pour les
blocs : (8,8,12), identique à la valeur approximative précédente). Une
bbox nulle sur un axe (mur = bande fine orientée selon son sens) est une
vraie donnée, pas un bug — a nécessité un correctif d'affichage dans
`debug/topView.ts` (un rectangle de largeur nulle est invisible sur un
canvas 2D).

## Famille de sprite (plusieurs types ROM, un seul sprite)
Un même graphisme ROM (ex. `sprite_small_block_59DB`, "petit bloc") peut
être réutilisé par plusieurs **types d'entité** distincts ayant des
comportements de jeu différents — ex. bloc statique (0x07), bloc mobile
(0x36/0x37), bloc poussable (0x3E), cube qui s'enfonce (0x5B), bloc
dormant (0x8F). Visuellement identiques, ce sont des objets ROM
différents : classer leur solidité par sprite serait une erreur, il faut
classer par type.

**Classification cartographique vs solidité physique** (résolu
2026-09-04) : « décor » est un concept **cartographique** — quoi masquer
pour produire une carte lisible — et n'est PAS une source de vérité
physique. Il l'a pourtant été un temps, provoquant exactement le bug
ci-dessus. La solidité physique est désormais une **politique du portage**,
décidée du côté qui la consomme et non exportée par l'outil d'extraction ;
elle est délibérément plus large, incluant les types à comportement
dynamique pas encore implémenté, traités comme un bloc statique en
attendant. Ne jamais refondre les deux.

Règle générale qui en découle : un outil d'extraction exporte des **faits
observés** (type, position, bbox), jamais une politique de gameplay — une
politique expédiée depuis là devient invisible et se fait réutiliser comme
vérité par un consommateur que personne n'avait prévu.

## Table de remap (pièces asymétriques)
Correspondance `(type de tuile, flip) → (type de tuile, flip)` nécessaire
pour afficher correctement les pièces asymétriques (murs 0x0A-0x0F,
coins, montants de porte) sous une vue tournée — un simple miroir
géométrique ne suffit pas pour ces tuiles. Inconnue à ce jour ; il n'est
pas établi que l'ensemble des tuiles de pièce soit *fermé* par rotation
de 90° (le jeu original n'ayant besoin que de 2 directions de mur).
