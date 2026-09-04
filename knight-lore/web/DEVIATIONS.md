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

*Justification* : confort de pilotage au clavier. **À trancher** : la
vitesse diagonale (√2 fois plus rapide, ou normalisée) n'a aucune référence
ROM — il faudra choisir explicitement.

*Ne pas confondre* avec les diagonales **émergentes** de l'original : en
mode directional, un demi-tour maintenu sur HAUT avance sur l'ancien axe
puis sur le nouveau, produisant une trajectoire diagonale sur 2 frames.
C'est un transitoire de rotation, pas une direction tenue — ça ne couvre
pas l'écart ci-dessus.

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

### Boucle en `dt` continu au lieu du pas fixe
`PLAYER_SPEED`, `GUARD_SPEED` et `WALK_FRAME_DURATION` sont en unités par
seconde, réglées à l'œil. L'original ne connaît que le **pas par frame de
logique** : ±3 unités sur un axe pour le joueur (#22E4), ±2 pour le garde
(`tbl_guard_patrol_vector_dispatch` #12B1), et une phase d'animation par
frame. Chantier : convertir la boucle en pas fixe, rendu à l'état du tick
sans interpolation.

### Orientation assignée au lieu de convergente
`updatePlayer()` range directement `player.orientation`. L'original ne
range **jamais** l'orientation : il bascule `type` bit3 (`xor #08`) et
`flags` bit6 (`xor #40`) — `asm/code/doors_and_player_logic.asm:419-425`.
Un virage à 90° converge en 1 frame, un demi-tour en 2, avec une
orientation intermédiaire observable. Dépend du pas fixe.

### Cooldown de rotation non implémenté
2 frames de logique en mode rotation, armé par `or #02` sur
`off_state_flags_2` (`:410-412`), et court-circuité en mode directional.

### Asymétrie du mode directional non reproduite
Trois directions sur quatre coûtent une frame de rotation avant d'avancer ;
la quatrième — HAUT, portée par le bit qui est aussi le bit « avance » —
tourne et avance dans la même frame (`:291-303`, unique `set 2,c` en
`:362`).

### Mode de contrôle « rotation » non implémenté
Seul le mode directional existe côté portage. Structure à prévoir : le
mode de contrôle est un **pilote d'entrée** produisant des événements
(`turnTo`, `stepForward`), pas une branche dans la boucle.

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
