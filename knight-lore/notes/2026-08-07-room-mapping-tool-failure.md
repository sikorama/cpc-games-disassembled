# Session 2026-08-07 (suite) — Tentative d'outil de cartographie automatique : ÉCHEC, mis de côté

## Contexte

Suite à la résolution complète de la transformation jour/nuit et de son
son (voir `2026-08-07-transformation-animation.md` et
`2026-08-07-transformation-sound.md`), tentative de construire un outil
de capture automatique des 128 salles (`tools/room_map/dump_rooms.py`)
pour à la fois dresser la carte du monde ET repérer visuellement tous
les sprites d'objets/ennemis par salle.

## Méthode testée

1. Retour au menu (forçage `PC=0x0542`, le point d'entrée de restart).
2. Breakpoint sur `fn_init_room` (0x2A68), **DEUX** appuis sur "0"
   (confirmé par l'utilisateur : le premier "0" ne fait qu'une étape
   intermédiaire — probablement sélection de méthode de contrôle — le
   second déclenche réellement le chargement de partie).
3. Au breakpoint, `IX` pointe sur `struct_entities_base` (0x00D7) juste
   après la copie du template ; patch de `(ix+08)` = `(0x00DF)` avec le
   `room_id` voulu, AVANT que `fn_init_room` ne s'en serve pour peupler
   les connexions/objets de la salle.
4. Resume, attendre **~5 secondes réelles** (jingle + dessin du décor —
   confirmé par l'utilisateur, 0.6s était très insuffisant, capturait
   un écran encore au menu ou à moitié dessiné).
5. Screenshot + dump de la table d'entités vivantes (128×28 octets)
   pour repérer les sprites non-joueur instanciés.

## Deux problèmes bloquants découverts (par l'utilisateur, en observant
## l'émulateur tourner pendant les tests)

### 1. Le joueur apparaît AU CENTRE de la salle injectée, parfois sur un ennemi

`fn_init_room`/`fn_init_room_entities` positionne le joueur à une
coordonnée de grille par défaut (centre de la salle, cf. `(ix+01)/
(ix+02)` du template `tbl_init_entities_template` à 0x29EB) — **pas à
une entrée logique** (porte, bord). Si un ennemi occupe déjà cette
position (ou une position immédiatement adjacente) dans la salle
injectée, une collision réelle se déclenche dès les premières frames,
pouvant tuer le joueur.

**Conséquence observée concrètement** : sur plusieurs salles testées en
série, le personnage est mort au moins une fois pendant la fenêtre de
5s d'attente. Sur mort, le jeu déclenche apparemment une téléportation
(probablement vers un point de réapparition fixe, ou la salle
précédente/salle de départ — mécanisme pas encore désassemblé) — **le
screenshot capturé dans ce cas montre la MAUVAISE salle** (celle de la
téléportation, pas celle injectée), sans qu'aucun signal d'erreur ne le
révèle (le champ `room` de l'entité 0 après coup semble cohérent avec
CETTE nouvelle salle, pas avec un échec détectable facilement sans
vérification supplémentaire du compteur de vies).

**Angle de résolution proposé par l'utilisateur, à explorer dans une
session future** : garantir que le compteur de vies reste stable à sa
valeur pleine (l'utilisateur mentionne "4" comme référence) avant de
valider une capture — ou, mieux, neutraliser complètement les
collisions/la possibilité de mourir pendant la capture (rendre le
joueur invulnérable ou invisible/non interactif), plutôt que de
compter sur la chance qu'aucun ennemi ne soit positionné au centre.
**Attention** : `docs/METHODOLOGY.md` §7quinquies documente déjà un
échec similaire (patcher `fn_check_collisions` par un `RET` complet a
eu des effets de bord non désirés) — toute neutralisation partielle des
collisions devra être testée avec cette leçon en tête (ne patcher que
l'effet précis voulu, pas la fonction entière).

### 2. Un randomiseur place les objets à ramasser différemment à chaque partie

Observation de l'utilisateur, plus fondamentale : **la position des
objets/items à ramasser dans les salles n'est PAS fixe d'une partie à
l'autre** — un mécanisme de randomisation (jamais identifié dans le
désassemblage jusqu'ici) redistribue ces objets à chaque nouvelle
partie. Conséquence directe : **une seule capture de la table d'entités
par salle, obtenue lors d'un unique restart, ne peut PAS servir de
référence fiable "quels objets sont dans quelle salle"** — le résultat
changerait à chaque exécution du script. L'outil tel que conçu (un seul
restart, capture séquentielle salle par salle) est donc **structurellement
inadapté** à cet objectif, indépendamment du problème de mort/téléportation
ci-dessus : même sans lui, la carte produite ne représenterait qu'un tirage
aléatoire parmi d'autres, pas la vérité de base du jeu.

**Piste non résolue à explorer avant de reprendre ce chantier** :
identifier la routine responsable de cette randomisation (probablement
quelque part dans l'init de partie, avant ou pendant
`fn_init_room_entities`/`fn_instantiate_room_objects`, potentiellement
liée à l'accumulateur pseudo-aléatoire déjà repéré `var_pseudo_random_acc`
0x006D) — et voir s'il est possible de la geler/rendre déterministe (fixer
la graine) pour obtenir des captures reproductibles, PLUTÔT que de
compter sur un seul tirage.

## Décision : mise de côté de l'outil de cartographie automatique

**Sur proposition de l'utilisateur** : ce chantier est mis en pause tant
que le moteur de jeu (logique du joueur, collisions, randomisation des
objets, mécanisme de mort/réapparition) n'est pas mieux compris dans son
ensemble. L'utilisateur est convaincu qu'il sera possible, une fois ces
mécanismes maîtrisés, de **changer de salle SANS faire apparaître le
personnage du tout** (le rendre invisible/non traité par la boucle de
jeu) **et sans repasser par le menu à chaque fois** (donc sans les
2×"0" + 5s d'attente à chaque salle, bien plus rapide) — hypothèse
plausible mais non encore vérifiée, à concrétiser dans une session
future une fois ces prérequis résolus.

## État du code laissé sur disque

`tools/room_map/dump_rooms.py` reste dans le dépôt (fonctionnel pour ce
qu'il fait — restart + injection de room_id + capture), mais **NE PAS
L'UTILISER EN L'ÉTAT pour produire une carte de référence** : les deux
problèmes ci-dessus le rendent non fiable pour cet usage tant qu'ils ne
sont pas résolus. Le garder comme brouillon/base de travail pour la
prochaine tentative, une fois :
1. un moyen fiable de neutraliser la mort du joueur pendant la capture
   (invulnérabilité ciblée, pas neutralisation aveugle d'une fonction
   entière) ;
2. le mécanisme de randomisation des objets identifié et rendu
   déterministe (ou contourné autrement, ex: lire directement les
   données STATIQUES avant randomisation plutôt que l'état runtime
   post-randomisation).

## Pistes ouvertes ajoutées pour la suite

1. **Identifier la routine de randomisation des objets** — probablement
   near `fn_instantiate_room_objects` (0x1DFB) ou l'init de partie
   (0x2A68+), à corréler avec `var_pseudo_random_acc` (0x006D) et le
   registre R (déjà connu comme source d'aléa 8-bit, cf.
   `fn_player_transform_tick`).
2. **Comprendre le mécanisme de mort/réapparition du joueur** (jamais
   désassemblé jusqu'ici) — nécessaire à la fois pour stabiliser une
   future capture ET comme sujet d'intérêt propre (compteur de vies
   mentionné par l'utilisateur, valeur pleine "4").
3. **Explorer un mode "spectateur"** (joueur non instancié/non rendu,
   caméra seule positionnée sur une salle) comme alternative radicale à
   l'approche "faire apparaître un vrai joueur" — évite les deux
   problèmes ci-dessus à la racine si réalisable proprement.
