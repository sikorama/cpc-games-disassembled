# Écarts du portage web par rapport au jeu d'origine

Le portage vise la **fidélité** : la ROM fait autorité, et en cas de doute
c'est le jeu d'origine qui tranche. Ce fichier est donc une **liste
fermée** — un écart qui n'y figure pas est un bug, pas une liberté.

Chaque entrée porte un **fait ROM de référence** (routine, adresse,
fichier:ligne) ou, explicitement, « pas encore désassemblé ». Une entrée
sans fait de référence est un aveu, pas une case à laisser vide : c'est ce
champ qui empêche d'inscrire comme « écart assumé » un comportement qu'on
n'a simplement pas encore cherché. Deux entrées supposées ont déjà été
retirées de cette liste après lecture du désassemblage (voir *Écarts
retirés* en fin de fichier).

Distinguer les deux sections : un **écart assumé** est une décision qu'on
garde ; une **dette** est un état provisoire qu'on compte résorber.

---

## Écarts assumés

### Diagonales tenues au clavier
Le portage autorise deux axes simultanés et normalise le vecteur.

*Fait ROM* : `tbl_player_forward_vector_dispatch` (#22E4,
`asm/code/doors_and_player_logic.asm:615-650`) n'a que 4 entrées, ±3 sur
**un seul** axe, jamais deux. Une diagonale n'y a aucune représentation.

*Justification* : confort de pilotage au clavier.

*Réalisation (tranchée au passage au pas fixe)* : l'axe parcouru **alterne à
chaque tick**. La trajectoire est diagonale, la vitesse identique aux
directions cardinales, et il n'y a ni vecteur diagonal ni vitesse en racine
de deux à inventer — les deux seules autres options, toutes deux sans
référence ROM. L'orientation reste sur l'axe primaire : aucune règle ROM ne
couvre le regard pendant une diagonale tenue, et le faire alterner à 50 Hz
scintillerait.

*Ne pas confondre* avec les diagonales **émergentes** de l'original : en
mode directional, un demi-tour maintenu sur HAUT avance sur l'ancien axe
puis sur le nouveau, produisant une trajectoire diagonale sur 2 frames.
C'est un transitoire de rotation, pas une direction tenue — ça ne couvre
pas l'écart ci-dessus.

### Cadence de la boucle de logique (25 Hz)
Le portage tourne à pas fixe, 25 ticks/seconde (`web/src/game/tick.ts`).

*Fait ROM* : **il n'y en a pas, et c'est vérifié**. `fn_main_loop` (#05AE) est
une boucle libre : aucun `HALT`, aucune lecture du port PPI B, aucune
synchronisation vidéo, et l'IM 1 à 300 Hz ne sert qu'au moteur de son sans
rien signaler à la boucle (`asm/code/low_ram_and_boot.asm:78-94`, :224-259).
`var_frame_counter` (#006A) compte des frames de LOGIQUE, pas des frames
vidéo. Le seul régulateur est une contre-réaction sur la charge
(`fn_render_workload_pacing_delay` #0618, `B = 6 - charge`) qui ralentit les
frames légères sans accélérer les lourdes.

*Justification* : l'original ralentit donc dans les salles chargées. C'est un
comportement réel mais une contrainte matérielle, pas une intention de game
design — décision de ne pas le reproduire. La cadence choisie est le seul
écart du portage dont la case « fait de référence » dise « le jeu n'en a
pas » plutôt qu'une adresse.

*Réglage* : 50 Hz au passage au pas fixe, ramené à **25 Hz le 2026-09-05**, le
personnage et ses animations étant jugés trop rapides. Toutes les vitesses
tirées de la ROM sont exprimées par TICK (pas du joueur ±3, pas du garde ±2,
une phase de marche par tick de déplacement) : la cadence les gouverne donc
toutes ensemble, dans le même rapport.

*Piège à ne pas rouvrir* : « une seule constante à changer » n'est vrai que
parce que la gravité et la vitesse de saut sont **dérivées** de `TICK_HZ`
(`scene/player.ts`) et non écrites en dur. Ce sont les deux seules grandeurs
réglées en temps réel et non par tick ; laissées telles quelles, le passage de
50 à 25 Hz aurait **doublé la hauteur de saut** — or cette hauteur est du
gameplay, il faut pouvoir monter sur un bloc à `+0x0C`. La formule
`V²/(2A)` étant indépendante de la cadence, la hauteur et la durée du saut
restent identiques à n'importe quelle fréquence.

### Mode de contrôle découplé du périphérique
Le portage propose (à terme) les deux modes quel que soit le périphérique.

*Fait ROM* : `var_input_mode_flag` (#006C) porte bit1 = clavier/joystick et
bit3 = DIRECTIONAL CONTROL, et le chemin directional exige **bit1 ET bit3**
(`asm/code/doors_and_player_logic.asm:280-285`). Au clavier, l'original est
donc **toujours** en mode rotation.

*Justification* : le couplage est un artefact du menu de 1984 — le même
octet sert de sélecteur de périphérique et de sélecteur de mode, au point
que `fn_read_use_object_button` doit re-décaler ses bits selon le
périphérique (`asm/code/menu_and_materialize.asm:322-328`). Ce n'est pas
une décision de gameplay.

*Conséquence à assumer* : le portage étant piloté au clavier, livrer
directional par défaut donne le mode qui n'est **pas** celui du clavier
d'origine.

### Formes de collision par entité (sphère pour les ennemis ronds)
Prévu, pas encore implémenté.

*Fait ROM* : aucune collision fine par forme. Tout passe par le même
mécanisme générique (`fn_check_collisions`, dispatch #27FE, champ
`(ix+0C)` bits 0/1), y compris pour la balle rebondissante 0xB2/0xB3 —
confirmé, voir `notes/2026-08-07-entity-logic-bouncing-ball.md`.

*Justification* : raffinement de fidélité **visuelle** (un objet rond qui
rebondit comme une boîte se voit). Écart délibéré vers plus de précision
que l'original, à ne pas confondre avec de la fidélité.

---

## Dette

Provisoire, à résorber. Ordre indicatif de traitement.

### Gravité et saut
`GRAVITY` et `JUMP_VELOCITY` (`scene/player.ts`) sont des valeurs de réglage.

*Fait ROM, PRÉCISÉ 2026-09-05* : le **déclencheur** de saut est désassemblé,
contrairement à ce que disait cette entrée. `fn_player_jump_trigger` (#21F0,
`asm/code/doors_and_player_logic.asm:445-462`) exige la touche, un cooldown à
zéro, l'absence du drapeau de saut, et un compteur `(ix+0B)` non négatif ;
il pose alors ce drapeau (bit 3 de `+0x0C`) et `(ix+0B) = +8`. Deux de ces
éléments sont maintenant portés parce que la transformation en dépend : le
drapeau (`PlayerState.jumping`) et le cooldown (`transformCooldown`).

Ce qui reste non tracé est la **courbe** : `fn_player_gravity_and_door_dispatch`
(#2253) fait converger `(ix+0B)` vers 0 par pas de 1-2, et personne n'a
reconstitué la hauteur ni la durée qui en résultent. `GRAVITY` et
`JUMP_VELOCITY` restent donc des valeurs de réglage, en unités/seconde
(`-300 u/s²`, `120 u/s`) converties par `TICK_HZ` : les seules grandeurs du
portage réglées en temps réel, précisément parce qu'aucune valeur ROM ne les
fixe encore. Voir *Cadence de la boucle de logique*.

### Mode de contrôle « rotation » non appliqué
La structure est en place — le mode est un **pilote d'entrée**
(`input/controlMode.ts`) qui produit une intention, et le pilote « rotation »
existe déjà et renvoie `turn` / `advance`. Ce qui manque est la règle côté
`scene/player.ts`, qui ne consomme aujourd'hui que `targets` (directional).
Le cooldown de rotation de 2 ticks est déjà modélisé
(`PlayerState.turnCooldown`) et restera inerte jusque-là, puisque le chemin
directional le court-circuite dans l'original aussi.

### Poses alternatives aléatoires
Les codes 6/7 de chaque demi-jeu de la famille CORPS (0x26/0x27, 0x2E/0x2F →
`hero_up6`, `hero_up7`, `hero_up2`, `hero_up1`) sont des poses rares, tirées
par `fn_entity_materialize_pick_subtype` (#26C3) et tenues 8 frames. Pas
implémentées.

*Fait ROM* : entièrement désassemblé. Ce ne sont pas des poses arbitraires
mais les **codes libres** de la famille — l'encodage `base | (bit<<3) | phase`
n'a que 6 phases, et la routine force explicitement les 3 bits bas à 6 ou 7
(`(iy+off_type) & #F8 | #06`, puis `+#10`). Seuils : `var_pseudo_random_acc`
`< 0x02` → pose 6, `>= 0xFE` → pose 7, soit ~0,8 % chacune. Voir
`docs/METHODOLOGY.md` §25bis.

*Rien ne bloque* : c'est du travail restant, pas une information manquante.
La source du tirage, elle, n'est pas un écart -- voir `game/random.ts`.

### Comportements dynamiques des blocs — RÉVISÉ 2026-09-04

La poussée est implémentée (`scene/pushables.ts`) : table 0x54, coffre 0x55
et bloc 0x3E sont des corps mobiles vivants. Ce qui reste ci-dessous est ce
que cette entrée regroupait à tort.

*Fait ROM qui a redécoupé l'entrée* : « poussable » n'est PAS un type, c'est
le **bit 2 de `flags`** (+0x07) de l'instance. `fn_entity_collide_axis_x/_y`
(#244C/#249B, `asm/code/doors_and_player_logic.asm:895-990`) recopient le
vecteur en attente du mobile dans celui de l'entité heurtée dès que ce bit y
est posé. Vérifié aussi sur les données : dans les 128 salles du manifest, le
bit n'est posé que sur 0x3E, 0x54, 0x55, 0x60-0x67 et les personnages — et
sur **aucune** instance de 0x36, 0x37, 0x5B, 0x8F, 0x07, 0x16.

Ce qui reste, et n'a rien à voir avec la poussée :

- **0x36/0x37, blocs mobiles** — mouvement autonome, pas une réaction au
  joueur. Traités comme des blocs statiques solides pour l'instant, mais
  **plus rien ne bloque depuis le 2026-09-05**. Les « deux constantes en code
  auto-modifiant » (#0FBF/#0FD0) ne sont pas des constantes : ce sont les
  **octets de déplacement** de deux `(ix+dd)`, vérifiés dans le dump
  (`0FBD: dd 7e 01`, `0FCE: dd 77 09`). **0x36 oscille en X, 0x37 en Y** —
  même routine, même amplitude, seul l'axe change. Cible :
  `f(var_frame_counter + bit de l'adresse du slot)` repliée par bit4,
  comparée à `(coord + 8) & 0x0F`, pas de ±1 ; le bit de l'adresse du slot
  déphase les blocs d'une même salle entre eux.
- **0x5B, cube qui s'enfonce** — **RÉSOLU 2026-09-05, la piste est fermée.**
  La descente n'était ni dans `fn_sinking_cube_logic` (#0F67) ni dans le
  système de collision : le cube écrit `(ix+0B)=0` juste avant `RST 10`, dont
  le prélude fait `dec (ix+0B)` — l'octet vaut donc -1 quand la primitive le
  relit comme composante Z. **Une unité de grille par déclenchement**
  (bit3 de `state_flags_2`, consommé). Preuve croisée : le bloc mobile écrit
  `1` au même endroit pour obtenir 0 après décrément, donc aucun mouvement
  vertical. Implémentable tel quel.

**Retiré de la liste** : *0x8F, bloc dormant*. Ce n'était pas un écart.
`fn_dormant_block_transform` (#0F84) le laisse indiscernable d'un bloc
statique tant que le bit3 de `state_flags_2` n'est pas posé ; une fois
déclenché il devient 0xB8 puis 0xB9, dont la logique retombe en idle statique
(`docs/SYMBOLS.md` 0xB8). Un bloc solide immobile est donc la simulation
**fidèle** de 0x8F.

### Bloc poussable 0x3E immobile
Le portage lui donne la politique de vecteur de sa routine ROM, qui le rend
immobile. Poussé, il reçoit bien le vecteur et ne bouge pas.

*Fait ROM* : `fn_pushable_block_logic` (#1D53) fait `CALL #22A5` (remise à
zéro du vecteur en attente) **avant** le `RST 10` qui l'applique — l'inverse
de `fn_pushable_table_logic` (#1D71), qui applique puis efface. Octets relus
directement dans `extra/dump_ref.bin` pour écarter une erreur de
transcription : `1D53: CD 8F 1D CD A5 22 D7 …`. Et le joueur est le slot 0
d'une table dispatchée en ordre croissant (`fn_main_loop` #05AE,
`asm/code/low_ram_and_boot.asm:224-252`), donc la poussée est écrite dans le
bloc avant son propre tick, qui l'efface aussitôt.

*Statut* : ce n'est pas une décision du portage, c'est une conséquence du
code encodé tel quel. La note d'origine
(`notes/2026-08-07-room-bb-diamond-and-pushable-block.md`) lisait ce `CALL
#22A5` comme « exactement le même appel que 0x54 » sans relever qu'il tombe
de l'autre côté du `RST 10`, et aucune poussée de 0x3E n'y a jamais été
observée en jeu — seulement le sprite. **À trancher par trace live** :
placer le joueur contre un 0x3E (salle 0xBB, 0x08, 0x58 ou 0xC7) et regarder
si `grid_x`/`grid_y` du bloc bougent. Si oui, une seule valeur d'énumération
change dans `physics/solidTypes.ts`.

### Corps poussables sans gravité
Table, coffre et bloc gardent leur `grid_z` de manifest ; poussés dans le
vide, ils ne tombent pas.

*Fait ROM* : **pas encore désassemblé** pour ces types. `RST 10` fait bien un
`dec (ix+0B)` avant de résoudre, mais aucune chute n'a été tracée pour eux —
et les données vont dans l'autre sens : plusieurs instances sont capturées
stables à `0x8C` ou `0x98` sans rien en dessous (salles 0x08, 0x40, 0x58).
Les faire tomber serait inventer une mécanique.

### Contrainte physique des portes
Les montants (0x02/0x03) sont traversables. Reste à traiter la **hauteur**
de porte (ne pas pouvoir sauter par-dessus une porte basse).

### État de jeu
Pas de mort au contact, pas de vies, pas d'objets ramassables. Le cycle
jour/nuit et la transformation, eux, sont implémentés — voir plus haut.

---

## Écarts retirés après vérification

Gardés ici parce qu'une piste morte documentée vaut mieux qu'une piste
effacée : sans ça, la même supposition se réinstalle.

- **« Déplacement continu à 4 directions = modernisation »** — faux.
  L'original a deux modes de contrôle, et « DIRECTIONAL CONTROL » fait
  exactement ça (#006C bit3). Seules les diagonales *tenues* restent un
  écart.
- **« Rotation d'un bit par tick, donc diagonales émergentes tenues »** —
  faux. Les deux bits sont écrits dans la même frame
  (`asm/code/doors_and_player_logic.asm:421` puis `:425`), sans état
  intermédiaire observable ; seul un demi-tour prend 2 frames.
