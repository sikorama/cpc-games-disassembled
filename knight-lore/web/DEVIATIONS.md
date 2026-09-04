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

### Cadence de la boucle de logique (50 Hz)
Le portage tourne à pas fixe, 50 ticks/seconde (`web/src/game/tick.ts`).

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
pas » plutôt qu'une adresse. Une seule constante à changer (`TICK_HZ`) si le
jeu paraît trop rapide.

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

*Fait ROM* : **pas encore désassemblé** — la logique de saut n'a pas été
tracée. Les valeurs actuelles sont les anciennes constantes en unités/seconde
converties à 50 Hz, pour que le passage au pas fixe ne change pas le ressenti.

### Mode de contrôle « rotation » non appliqué
La structure est en place — le mode est un **pilote d'entrée**
(`input/controlMode.ts`) qui produit une intention, et le pilote « rotation »
existe déjà et renvoie `turn` / `advance`. Ce qui manque est la règle côté
`scene/player.ts`, qui ne consomme aujourd'hui que `targets` (directional).
Le cooldown de rotation de 2 ticks est déjà modélisé
(`PlayerState.turnCooldown`) et restera inerte jusque-là, puisque le chemin
directional le court-circuite dans l'original aussi.

### Poses alternatives aléatoires
Les slots 6/7 de chaque groupe de types (0x26/0x27, 0x2E/0x2F → `hero_up6`,
`hero_up7`, `hero_up2`, `hero_up1`) sont des poses rares tirées au hasard
par `fn_entity_materialize_pick_subtype` (#26C3,
`asm/code/doors_and_player_logic.asm:1353-1401`) et tenues 8 frames.
Bloqué : le comportement de `var_pseudo_random_acc` (cadence de ré-tirage,
source de l'aléa) **n'est pas encore désassemblé**.

### Transformation jour/nuit (loup-garou)
Un simple `XOR #20` sur le type dans l'original
(`asm/code/pickups_and_transform.asm:355-359`, 0x14 jour ↔ 0x34 nuit). Les
plages sont connues (jambes 0x30-0x3D, corps 0x40-0x4F) et leur calibration
de projection est identifiée (#1DA8 et #1DAD).

**Contradiction à régler d'abord** : la table de dispatch de logique donne
0x30-0x3D au joueur de nuit, mais 0x36/0x37 sont documentés par ailleurs
comme des blocs mobiles partageant le sprite du petit bloc 0x59DB
(`docs/SYMBOLS.md:320`, `tools/room_map/teleport.py`). Un octet de type ne
peut pas être les deux — une des deux lectures est fausse. Les plages nuit
sont donc volontairement absentes de `render/isoOffsets.ts`.

### Comportements dynamiques des blocs
Bloc mobile (0x36/0x37), poussable (0x3E), cube qui s'enfonce (0x5B), bloc
dormant (0x8F), table poussable (0x54), coffre glissant (0x55) sont traités
comme des blocs statiques solides (`physics/solidTypes.ts`). Leur logique
est désassemblée (`fn_pushable_block_logic` #1D53,
`fn_pushable_table_logic` #1D71, `fn_sliding_chest_logic` #1D66) — c'est
l'implémentation qui manque, pas le fait.

### Contrainte physique des portes
Les montants (0x02/0x03) sont traversables. Reste à traiter la **hauteur**
de porte (ne pas pouvoir sauter par-dessus une porte basse).

### État de jeu
Pas de mort au contact, pas de vies, pas d'objets ramassables, pas de cycle
jour/nuit.

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
