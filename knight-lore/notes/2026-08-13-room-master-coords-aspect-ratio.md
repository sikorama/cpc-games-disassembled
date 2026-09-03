# `tbl_room_master_coords` (`#33D4`) — résolu : calibration de la caméra selon le ratio d'aspect de la salle

Suite directe du travail sur `#33DD-#417E` (voir
`notes/2026-08-13-room-connection-detail-zone.md`). Cette table (3
entrées de 3 octets seulement) était documentée `hypothesis`
("partiellement invalidée") : l'ancienne piste "coordonnées X/Y par
salle" avait déjà été écartée (une seule des 3 valeurs revenait
identique pour la majorité des 128 salles), remplacée par une
supposition non vérifiée ("peut-être un type de zone/secteur").

## Ce qu'on savait déjà (statique)

Dans `fn_load_room_data` (`#2C3A`, désassemblée en détail le
2026-08-13) : le 1er octet du payload de `tbl_room_master_index`
(`field_byte`) est transformé en index `(field_byte>>3)&0x1F` (0-2 sur
les 128 salles réelles), qui sélectionne une des 3 entrées de
`tbl_room_master_coords`, copiées vers `var_camera_reference`/
`var_camera_reference_y` (`#0071`/`#0072`, déjà nommées "confirmed"
dans une session antérieure) et `var_room_data_field_2` (`#0074`).

Contenu réel des 3 entrées :
```
0: #40 #40 #80   (défaut)
1: #20 #40 #80   (X divisé par 2)
2: #40 #20 #80   (Y divisé par 2)
```

## Validation empirique

Hypothèse formée en lisant ces 3 valeurs : si `var_camera_reference`
(X) et `var_camera_reference_y` (Y) servent de point de référence pour
le cadrage caméra/vue (déjà leur rôle documenté via
`fn_player_in_view_bounds`/`fn_room_transition`), diviser par 2 l'un
des deux axes serait cohérent avec une salle dont l'extension
spatiale est nettement asymétrique sur cet axe (compense pour recentrer
la vue).

Testé via `tools/room_map/teleport.py` (instance dédiée, port 8799 —
jamais la session live de l'utilisateur), en mesurant l'étalement réel
(min/max `grid_x`/`grid_y`) des entités mur/porte de plusieurs salles
déjà identifiées par index :

| Salle | index | étalement X | étalement Y | ratio X:Y |
|---|---|---|---|---|
| `#44` | 0 (défaut) | 137 | 137 | 1:1 — carré |
| `#34` | 1 (X÷2) | 62 | 120 | ≈1:2 — plus haute que large |
| `#01`/`#03`/`#0E` | 2 (Y÷2) | 137 | 61 | ≈2:1 — plus large que haute |

**Conforme dans les 3 catégories.** Le 3e octet (`#80`, constant sur
les 3 entrées) correspond à la valeur `grid_z_or_offset` "au sol"
déjà observée sur toutes les entités de décor de jonction
(`tbl_room_connection_detail_*`/`tbl_room_junction_entity_template_*`)
— cohérent avec une référence de hauteur par défaut, pas une
coordonnée de secteur.

## Résultat

`tbl_room_master_coords` renommée en statut `confirmed` : sélectionne,
par salle, un point de référence caméra calibré sur son ratio
d'aspect (carrée / plus haute que large / plus large que haute) — pas
un "type de zone" comme précédemment supposé. Aucun octet de code
modifié (mise à jour de description uniquement) ; vérifié identique
octet pour octet, boot réel re-testé.

## Reste ouvert

- Le mécanisme fin par lequel `fn_player_in_view_bounds`/
  `fn_room_transition` utilisent concrètement ce point de référence
  (au-delà du fait qu'il existe et qu'il varie selon le ratio d'aspect)
  n'est pas retracé plus loin.
- Seulement 3 catégories pour 128 salles — pourrait indiquer que les
  salles du jeu n'ont que 3 "gabarits" de taille réels, ou que les cas
  plus extrêmes n'existent simplement pas dans le level design (pas
  vérifié systématiquement sur les 128 salles, seulement un échantillon
  de 5).
