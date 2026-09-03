# Session 2026-08-07 (suite 12) — Test 3 : sauter sur la table, élévation confirmée

Suite de `notes/2026-08-07-entity-logic-pushable-table.md`. L'utilisateur
a sauté sur la table (room 0x6D), avec un test refait une seconde fois
après un premier essai raté (saut déclenché avant le début du
polling).

## Résultat empirique

**Premier essai (raté)** : polling démarré après le saut, position
(`grid_x/y/z`) restée figée à `(0x58, 0xB8, 0x8C)` tout du long —
confirme que **`grid_z_or_offset` (+03) est bien le champ affecté par
le fait d'être sur la table** (0x8C au lieu de 0x80, la valeur au sol),
mais la fenêtre de capture n'a saisi aucune transition car le
changement avait déjà eu lieu avant le lancement du script.

**Second essai (redescente puis re-saut)** : capturé avec succès —

```
t=0.0s   type=0x34 grid=(0x58,0xb8,0x8c)   -- déjà sur la table au début du poll
t=13.4s  type=0x31 grid=(0x49,0xba,0x86)   -- DESCEND : grid_z 0x8c -> 0x86 -> 0x80
t=13.6s  type=0x32 grid=(0x49,0xba,0x80)   -- au sol, grid_z=0x80 stable
...
t=18.9s  type=0x3c grid=(0x56,0xba,0x8c)   -- REMONTE : grid_z 0x80 -> 0x8c -> 0x90 (pic) -> 0x8c
t=19.1s  type=0x38 grid=(0x5c,0xba,0x90)   -- point culminant du saut, grid_z=0x90
t=19.3s  type=0x39 grid=(0x5f,0xba,0x8f)   -- redescend progressivement
t=19.9s  type=0x3c grid=(0x65,0xba,0x8c)   -- se stabilise sur la table, grid_z=0x8c
```

## Découvertes confirmées

1. **`grid_z_or_offset` (+0x03) EST bien le champ d'élévation** —
   confirmé sans ambiguïté : `0x80` = au sol, `0x8C` = sur la table
   (élévation de +0x0C = 12 unités, cohérent avec une table d'une
   hauteur raisonnable), et un pic transitoire à `0x90` observé pendant
   le mouvement de saut (probablement l'apex de la trajectoire, avant
   de retomber sur la table à 0x8C).

2. **Nouvelle famille de types découverte : 0x30-0x3D** (au moins,
   peut-être plus large) — cycle d'animation observé pendant les
   phases de saut/déplacement vertical, distinct du cycle stable
   normal (0x14/0x34 jour/nuit) et des familles déjà connues
   (0x5C-0x5F transformation, 0x70-0x7F matérialisation). Pattern
   d'incrémentation similaire aux autres familles animées déjà
   rencontrées (probablement un cycle à 4 ou 8 phases selon le nibble
   bas du type, jamais désassemblé formellement cette session — piste
   ouverte).

3. **Confirmation indirecte du mécanisme de collision par élévation** :
   le fait que `grid_z_or_offset` change automatiquement de 0x80 à
   0x8C en marchant simplement vers la table (sans action de saut
   explicite dans certains logs, ex. juste "monter dessus" en avançant)
   suggère que le jeu détecte automatiquement la présence d'un support
   sous les pieds du joueur et ajuste son élévation en conséquence —
   cohérent avec un système de collision 3D complet (AABB déjà
   confirmé), pas seulement un test 2D.

## Prochaines étapes

1. Désassembler la famille de types 0x30-0x3D (logique associée,
   jamais tracée) — probablement liée à l'animation de saut/chute du
   joueur.
2. **Test 4 — bloquer le gardien avec la table** — reste à faire,
   piste la plus prometteuse restante de cette série de tests.
3. Vérifier si le mécanisme d'élévation (`grid_z_or_offset`
   automatique selon le support) est géré par la même primitive
   `rst_apply_movement_vector`/collision AABB déjà connue, ou par une
   routine dédiée au joueur spécifiquement (probablement dans
   `fn_player_logic`, zone encore peu explorée en détail).
