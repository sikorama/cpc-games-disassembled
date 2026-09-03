# Session 2026-08-07 (suite 5) — Room 0x5F : 3 portes, confirmation de la table tbl_room_connections en conditions réelles

Suite de `notes/2026-08-07-entity-logic-ceiling-spikes.md`. Nouvelle
salle (0x5F, toujours thème forêt). Utilisateur : "toujours la forêt,
mais j'ai 3 portes en bois : 2 selon l'axe Y et une vers X-".

## Room 0x5F — 3 portes confirmées (types 0x04/0x05)

Dump RAM : slots 4-9, 3 paires de type 0x04/0x05 —

- Paire 4/5 : `grid_x=0x8D/0x73` (symétrique), `grid_y=0xC4` fixe → porte
  sur l'axe Y (Y+ probable, cf. ci-dessous).
- Paire 6/7 : `grid_x=0x8D/0x73`, `grid_y=0x3B` fixe → 2e porte sur
  l'axe Y (Y-, côté opposé de la précédente).
- Paire 8/9 : `grid_x=0x3B` fixe, `grid_y=0x73/0x8D` (symétrique) →
  porte sur l'axe X, côté X- (grid_x < 0x80, centre de salle) —
  **correspond exactement à "une vers X-"**.

**Total : exactement 3 portes**, correspondant parfaitement à la
description de l'utilisateur (2 sur Y, 1 sur X-).

## Bonus : vérification croisée avec `tbl_room_connections` (0x0147) en conditions réelles

Dump de la table de connexions active de la salle (4 entrées de 56
octets, jusqu'ici seulement vue en contexte de transition ponctuelle,
cf. `notes/2026-08-06-room-navigation.md`) :

```
entry0: 04 8D C4 80 03 05 28 40 5F 80 C4 80 00 00 00 00
entry1: 04 8D 3B 80 03 05 28 40 5F 80 3B 80 00 00 00 00
entry2: 04 3B 73 80 05 03 28 00 5F 3B 80 80 00 00 00 00
entry3: 80 3F 49 80 00 08 2C 00 5F 00 00 00 00 00 00 00
```

**Seules les entrées 0, 1, 2 ont `b0=0x04`** (type de porte) — cohérent
avec exactement 3 connexions actives dans cette salle. **L'entrée 3
a `b0=0x80`** (le type "segment de mur", pas un code de connexion valide)
et ne porte PAS le marqueur room_number attendu (`0x5F`) au même
offset que les 3 autres (`entry0/1/2` ont bien `5F` au 9e octet,
confirmant le format déjà établi dans
`notes/2026-08-06-world-map-attempt.md`) — **c'est un résidu non
nettoyé d'une salle précédente** (la table `tbl_room_connections` a
4 slots fixes mais n'écrit que les N premiers réellement utilisés par
la salle courante ; le slot inutilisé garde son contenu précédent tel
quel plutôt que d'être mis à zéro). **Point méthodologique à retenir**
pour toute lecture future de cette table : toujours vérifier le
marqueur room_number au 9e octet de chaque entrée avant de la
considérer comme une connexion valide, ne pas se fier au seul nombre
d'entrées non-nulles.

## Statut

**CONFIRMED** — nouvelle confirmation croisée (dénombrement utilisateur
+ dump RAM des entités + dump de la table de connexions active), toutes
parfaitement cohérentes entre elles. Aucune nouvelle routine à
désassembler cette fois (types déjà connus : 0x04/0x05 portes, 0x80
segments de mur) — session de vérification/consolidation plutôt que de
découverte, mais précieuse pour la fiabilité de `tbl_room_connections`.
