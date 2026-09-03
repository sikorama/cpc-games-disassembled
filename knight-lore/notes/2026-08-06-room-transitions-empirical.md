# Session — Cartographie empirique des transitions de salle (données réelles)

## Contexte

Suite à `notes/2026-08-06-world-map-attempt.md`. Collecte de transitions
réelles en jeu, via breakpoint sur `fn_resolve_neighbor_room` (0x2BF9) et
déplacement manuel du joueur par l'utilisateur (méthode fiable : jeu non
corrompu, contrairement à la tentative précédente par `ram_write`).

## Convention de nommage des axes (établie avec l'utilisateur)

Le jeu a deux modes de déplacement : un mode "rotation + avance devant
soi" (touches W/X pour tourner, S pour avancer) et un mode directionnel
classique. Les noms de direction sont donc définis par rapport aux
**coordonnées RAM**, pas par rapport à l'écran ou à l'orientation du
personnage :

- **`grid_x`** = `(ix+01)` de la structure d'entité
- **`grid_y`** = `(ix+02)` de la structure d'entité

## Tableau des 4 codes de direction (CONFIRMÉ empiriquement, 6 transitions observées)

| Code C | Axe de sortie | Valeur observée à l'arrivée | Adresse dans fn_room_transition |
|---|---|---|---|
| `0xAE` | grid_x | max (0xFF) | 0x2BDC |
| `0x37` | grid_x | min (0x00) | 0x2BEC |
| `0x51` | grid_y | min (0x00) | 0x2BCF |
| `0xC8` | grid_y | max (0xFF) | 0x2BAC |

**Statut : CONFIRMED** — chaque code observé au moins une fois avec la
coordonnée attendue à l'arrivée (l'axe qui N'A PAS bougé reste identique
avant/après ; l'axe qui a servi de sortie atteint son extrême opposé dans
la nouvelle salle, cohérent avec le calcul de repositionnement de
`fn_room_transition` déjà désassemblé).

## Transitions réelles observées (room de départ → room d'arrivée)

Toutes vérifiées par lecture directe de `(ix+08)` avant/après + `z80`
au moment du breakpoint sur `fn_resolve_neighbor_room` :

| # | Départ | Arrivée | Code C | Coords à l'arrivée (x,y,z) |
|---|---|---|---|---|
| 1 | 0x43 | 0x44 | 0xAE | ff 80 80 |
| 2 | 0x44 | 0x45 | 0xAE | ff 80 80 |
| 3 | 0x45 | 0x44 | 0x37 | 00 80 80 |
| 4 | 0x44 | 0x34 | 0x51 | 80 00 80 |
| 5 | 0x34 | 0x44 | 0xC8 | 80 ff 80 |
| 6 | 0x44 | 0x54 | 0xC8 | 80 ff 80 |

## Carte locale déduite (autour de la room 0x44)

```
                0x34
                 |  (C=0x51 pour sortir vers 0x34,
                 |   C=0xC8 pour en revenir)
0x43 -- 0x44 -- 0x45
 (C=0x37)  (C=0xAE)
                 |
                0x54
                 (C=0xC8 pour y aller, cohérent avec 0x34->0x44)
```

**Observation importante (cohérence confirmée)** : le code de direction
`C` semble être **stable et indépendant de la room de départ** — sortir
par "grid_y max" donne toujours `C=0xC8`, que ce soit depuis `0x34` (pour
revenir vers `0x44`) ou depuis `0x44` (pour aller vers `0x54`), tant
qu'on sort par le même côté physique de la salle. C'est cohérent avec
l'hypothèse que `C` encode une direction absolue (probablement liée à
l'orientation de la grille du monde), pas une relation spécifique à une
paire de salles.

**Limite à garder en tête** : on n'a pas encore vérifié si le code `C`
change selon la TAILLE de la salle (une grande salle a peut-être
plusieurs "portes" sur le même bord, donc plusieurs codes possibles pour
le même axe/sens) — nos données actuelles sont cohérentes avec un
"1 seul voisin par côté" mais ce n'est pas prouvé pour toutes les salles.

## Tentative infructueuse : désactiver les collisions par patch RET

**Statut : ÉCHEC documenté, patch annulé et confirmé restauré par l'utilisateur.**

Idée : patcher le premier octet de `fn_check_collisions` (0x2750, `XOR A`
= 0xAF) par `0xC9` (`RET`) pour neutraliser toute la fonction et permettre
de traverser les obstacles librement (objectif : faciliter l'exploration
de la carte pour l'outil de cartographie automatique).

**Résultat observé** : après le patch, des rectangles noirs sont apparus
à l'écran (une partie du décor rendu incorrectement) et le personnage
n'était plus visible ni contrôlable. Patch annulé immédiatement (octet
restauré à `0xAF`), état du jeu confirmé rétabli par l'utilisateur.

**Conclusion** : `fn_check_collisions` n'est PAS une simple routine de
test de collision isolée — son exécution complète a un effet de bord
plus large que prévu sur l'état du jeu (probablement lié au fait qu'elle
remet à zéro un accumulateur partagé `(0x0084)` en tout début, qui est
peut-être lu ailleurs dans la frame même si la collision elle-même n'a
pas d'effet ce tour-ci — sauter toute la fonction prive ce nettoyage
d'avoir lieu). **Ne pas neutraliser des fonctions entières par patch RET
sans avoir d'abord vérifié précisément TOUS les effets de bord en début
de fonction** (ici : `xor a` / `ld (0084),a` en tout début, qu'on avait
déjà documenté mais dont on a sous-estimé l'importance pour d'autres
lecteurs de `(0x0084)` dans la frame).

**Piste alternative plus sûre pour désactiver seulement le BLOCAGE (pas
toute la fonction)** : identifier précisément quel test/quelle
instruction produit le blocage physique du joueur (probablement pas
dans `fn_check_collisions` elle-même, qui semble être de la collision
entité-entité, mais dans une routine géométrique séparée liée au
terrain/aux murs — non encore localisée). Chercher plutôt cette routine
spécifique et neutraliser SEULEMENT le test qui bloque le mouvement
(ex: forcer le flag de résultat à "pas de collision" juste après le
test, plutôt que sauter toute la fonction englobante).
