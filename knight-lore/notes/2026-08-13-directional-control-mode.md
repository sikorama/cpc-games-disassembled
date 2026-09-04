# Session 2026-08-13 (suite) — Mode "3 DIRECTIONAL CONTROL" et fn_player_read_input

## Contexte

Reprise après un `/clear` : l'utilisateur avait activé au menu l'option
**3 DIRECTIONAL CONTROL** puis relancé une partie, et pilotait en direct
(clavier/joystick réel dans le navigateur AMSpiriT-Lite) pendant que
l'accès API était utilisé en parallèle, en lecture seule, pour observer.

Définition donnée par l'utilisateur (à retenir, pas dans le désassemblage
lui-même) :
- **directional control** = le personnage se déplace selon la direction
  du joystick.
- **mode normal** (1 KEYBOARD / 2 JOYSTICK) = le personnage tourne
  d'abord, puis n'avance que dans sa direction courante.

## Accès direct à l'API de l'émulateur (sans MCP)

`http://127.0.0.1:8765` — endpoints utiles découverts/confirmés cette
session (au-delà de ceux déjà documentés dans `docs/METHODOLOGY.md`/
`tools/room_map/teleport.py`) :

- `GET /api/keymatrix` → `{"matrix": [10 octets]}`, matrice clavier CPC
  brute (bit=0 = touche/ligne joystick active). Lecture seule dans l'UI
  web, mais utile pour vérifier à quelle ligne/bit correspond une touche.
- `POST /api/keypress {"vk": <code>, "down": true|false}` — **maintient**
  la touche enfoncée (contrairement à l'usage par défaut dans l'UI, qui
  ne fait qu'un tap bref). Sans `"down"`, la touche est relâchée avant
  qu'on ait le temps de relire la matrice (vérifié empiriquement : lecture
  immédiate après un `keypress` sans `down` redonne l'état de repos).
- VK des flèches (utilisées comme codes "core virtual key", même famille
  que les touches F0-F9/ESC déjà vues dans le JS servi) : UP=0x99,
  LEFT=0x98, RIGHT=0x9A, DOWN=0x9B, DEL=0x9C. **Confirmé par test** :
  UP (0x99) active bit2 de la ligne 9 de la matrice — cohérent avec le
  partage matériel CPC clavier/joystick 1 sur la ligne 9, déjà déduit du
  désassemblage de `fn_read_input` (lignes 6 et 9 lues directement en
  mode joystick, `#28CD-#28D7`).
- ATTENTION : si quelqu'un pilote en direct dans le navigateur pendant
  qu'on utilise l'API, la matrice observée mélange les deux sources — ne
  PAS supposer qu'un `POST /api/keypress` isolé donne un résultat propre
  si l'utilisateur est simultanément aux commandes.

## fn_player_read_input (#2147) — désassemblage complet

Les octets `defb` restants de cette routine (#2175-#21EF) ont été
intégralement désassemblés cette session (voir `asm/symbols.json` pour
les 9 nouveaux symboles `fn_player_orient_dispatch_bit0/1/2/4`,
`fn_player_orient_aligned_exit`, `fn_player_rotate_or_advance_tail`,
`fn_player_rotate_apply`, `fn_player_rotate_toggle_mirror`, et
`docs/SYMBOLS.md` pour la description synthétique). Bytes vérifiés
identiques entre `asm/` et la RAM live avant édition.

Structure logique confirmée : `var_input_mode_flag` (#006C) bit1 ET bit3
actifs ensemble → chemin "aligné" qui, si la direction pressée diffère de
l'orientation courante, **court-circuite** le cooldown de rotation
dédié (`state_flags_2` ix+0D) et le re-gate sur `cooldown_or_collision_flags`
(ix+0C) que le chemin bypass (bit1 ou bit3 à 0) applique lui
systématiquement. C'est un candidat solide pour expliquer la différence
directional-control vs normal.

## Test empirique réalisé (partiel)

Capture RAM synchronisée (struct joueur `#00D7`, ~30 échantillons à
60-80ms d'intervalle) pendant que l'utilisateur pressait une direction
différente de l'orientation courante, **en mode 3 confirmé actif**
(`var_input_mode_flag`=0x0A, bit1=bit3=1) :

- `type` (base hors bits d'animation) passe de `0x38` à `0x30` en
  4 frames, PENDANT que la position bouge déjà en diagonal (x+3,y-3) —
  puis la marche continue en ligne droite (`type` cycle 0x30-0x35,
  x-=3/frame, y constant).
- Interprétation : réorientation quasi-immédiate suivie d'une avance
  fluide, cohérent avec le chemin "aligné" décrit ci-dessus.

**Un deuxième essai** (position complètement figée pendant ~2.5s alors
que `type` cyclait 0x30-0x35) est probablement un cas de collision
(personnage bloqué contre un obstacle/mur), pas représentatif — à
refaire dans un couloir dégagé si on veut un second échantillon propre.

## Comparaison A/B — RÉSOLU (même session)

L'utilisateur a relancé une partie en mode **2 JOYSTICK** (sans
directional control) et refait le même geste (direction différente de
l'orientation courante), pendant que l'accès API restait en lecture
seule.

- `var_input_mode_flag` = `0x02` → bit1=1 (joystick), **bit3=0**
  (confirme que bit3 est bien indépendant de bit1, et correspond au
  sélecteur directional control).
- Capture RAM synchronisée (même méthode, 40 échantillons ~60ms) :
  `grid_x`/`grid_y` **parfaitement figés** (0x70,0x7d) pendant plus de
  4.5s, `type` oscillant UNIQUEMENT entre `0x12` et `0x1A` (juste le
  bit3, le "toggle orientation" de `fn_player_rotate_apply`/
  `fn_player_rotate_toggle_mirror`), sans jamais atteindre le cycle
  d'animation de marche (0x30-0x35 vu en mode 3). Le personnage tourne
  sur place indéfiniment sans avancer.

**Conclusion confirmée** : bit1+bit3=1 (menu "3 DIRECTIONAL CONTROL") →
chemin "aligné" (`fn_player_orient_dispatch_*`), tourne-et-avance en un
seul geste fluide dès que la direction pressée correspond à
l'orientation calculée. bit1=1/bit3=0 (menu "2 JOYSTICK") → chemin
bypass (`fn_player_rotate_or_advance_tail`/`fn_player_rotate_apply`),
rotation et avance strictement découplées : le personnage tourne tant
que l'orientation ne correspond pas à la direction pressée, sans jamais
avancer entre-temps. Correspond exactement à la définition donnée par
l'utilisateur en début de session. `docs/SYMBOLS.md` mis à jour en
conséquence (entrée `0x2147`).

## Point ouvert pour une session future — RÉSOLU 2026-09-04 (piste morte)

**Conservé tel quel ci-dessous, parce que la question elle-même était le
bug.** Ce point n'a jamais existé : il n'y a pas de bit manquant, donc pas
de routine à trouver.

`fn_get_orientation_code` (#22D0,
`asm/code/doors_and_player_logic.asm:600-614`) fait
`ld a,(ix+off_flags) / rrca / rrca / and #10`. Les deux `rrca` amènent le
bit6 d'origine en position 4 : le `and #10` sélectionne donc **bit6**, pas
bit4. Le commentaire du source disait « Combine bit4 de (ix+07) », en
nommant la position du bit APRÈS décalage — c'est ce commentaire qui a
envoyé chercher un écrivain pour un bit inexistant. Corrigé dans
`asm/code/doors_and_player_logic.asm` le 2026-09-04.

Et bit6 est bien écrit, sans mystère : `xor #40` dans
`fn_player_rotate_apply` (`:423-425`), dans les deux moitiés de la bascule.
Le retournement complet supposé problématique n'en est pas un : un
demi-tour bascule les deux bits sur **deux frames** consécutives (90° en une
frame, 180° en deux), avec une orientation intermédiaire observable — ce qui
explique aussi la trajectoire diagonale relevée plus haut dans cette note
(`x+3, y-3` pendant la convergence du type) : la frame 1 avance sur l'ancien
axe, la frame 2 sur le nouveau. Aucun pas n'est jamais diagonal.

Le piège générique est noté dans `docs/METHODOLOGY.md`.

---

### Texte original de 2026-08-13 (faux, gardé pour mémoire)

Reste à vérifier : comment le bit "manquant" de l'orientation complète
(bit4 de `flags`, utilisé par `fn_get_orientation_code` #22D0 en plus du
bit3 de `type`) est mis à jour — `fn_player_rotate_apply`/
`fn_player_rotate_toggle_mirror` ne touchent jamais ce bit4, donc un
retournement complet (170°/270°, changement de "quadrant") doit passer
par une autre routine non encore identifiée. À chercher empiriquement
en mode 2, en faisant tourner le personnage sur les 8 directions
successives et en surveillant bit4 de `flags` (offset +0x07).
