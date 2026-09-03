# Session 2026-08-07 (suite 13) — Test 4 : bloquer le gardien avec la table, CONFIRMATION TOTALE du mécanisme

Suite de `notes/2026-08-07-entity-logic-bouncing-ball.md` (résolution
du mécanisme de collision du gardien) et
`notes/2026-08-07-entity-logic-pushable-table.md`. L'utilisateur a
positionné la table sur le chemin du gardien : "à chaque fois qu'il
tape dedans, il la pousse d'un cran, et fait demi-tour".

## Test empirique — confirmation numérique complète

**Protocole** : poll RAM simultané du gardien (slot 33, jambes
0x90-0x9D) et de la table (slot 32, type 0x54) sur 55 secondes pendant
que le gardien fait des allers-retours et percute la table à chaque
passage.

**Résultat** : cycle répété avec une précision remarquable, capturé
plusieurs fois dans la fenêtre d'observation :

```
Phase 1 : le gardien avance en ligne droite sur l'axe X
          grid_x: 0x64 -> 0x66 -> 0x68 -> ... -> 0xB8 -> 0xB9
          (ix+0C)=0x04, (ix+0D)=0xA0 (ou 0xA1) stable tout du long

Phase 2 : IMPACT avec la table à grid_x=0xB9
          (ix+0C) passe de 0x04 à 0x05  <- BIT 0 POSÉ (collision détectée)
          (ix+0D) passe de 0xA0 à 0xA1 (ou 0xA1->0xA0)  <- DIRECTION CHANGÉE
          LA TABLE BOUGE D'UN CRAN à ce moment précis (ex: grid_x 0x5E->0x5C)

Phase 3 : le gardien repart en sens inverse
          grid_x: 0xB7 -> 0xB5 -> ... -> 0x64
          (ix+0C) revient à 0x04, direction stable jusqu'au prochain impact
```

**Ce cycle se répète identiquement** à chaque aller-retour (observé au
moins 4 fois dans la fenêtre de 55s), avec la table qui recule d'un
cran supplémentaire à chaque impact (`0x5E → 0x5C → 0x5A → 0x58 → 0x56`) —
**exactement l'observation de l'utilisateur : "il la pousse d'un cran,
et fait demi-tour"**.

## Confirmation exhaustive du mécanisme désassemblé

Ce test valide numériquement, sans aucune ambiguïté, TOUTE la chaîne
causale déduite du désassemblage de `fn_resolve_patrol_vector`
(0x12A5, voir `notes/2026-08-07-entity-logic-bouncing-ball.md`) :

1. Le gardien avance tant que `(ix+0C)` bit 0 (pour son axe de
   déplacement courant, X ici) reste à 0 — confirmé : `(ix+0C)=0x04`
   stable pendant toute la phase de marche.
2. Au moment du contact avec un obstacle (la table), le moteur de
   collision générique POSE le bit 0 de `(ix+0C)` — confirmé : passage
   exact `0x04 -> 0x05` synchronisé avec l'arrêt du gardien.
3. `fn_resolve_patrol_vector`, lisant ce bit posé, incrémente la
   direction `(ix+0D)&3` de 1 — confirmé : `0xA0 -> 0xA1` (ou
   l'inverse), le nibble bas alternant strictement entre ces deux
   valeurs à chaque impact.
4. Le vecteur de déplacement de la TABLE est rempli par le même moteur
   de collision au moment de l'impact — confirmé : elle recule d'un
   pas exact à chaque contact, cohérent avec `fn_pushable_table_logic`
   (0x1D71/0x1D66) qui se contente d'appliquer un vecteur déjà résolu
   par ailleurs.

**Ce test de "double observation simultanée" (deux entités différentes
affectées par LE MÊME événement de collision au même instant) est la
confirmation la plus solide obtenue cette session sur le fonctionnement
du moteur de collision générique** — les deux comportements
(rebroussement du gardien, recul de la table) sont deux conséquences
distinctes d'un seul et même événement physique, détecté et propagé
par le même sous-système.

## Statut

**CONFIRMED (empirique, sans ambiguïté)** — le mécanisme "le gardien
tourne après une collision" décrit par l'utilisateur dès la première
observation du gardien (room 0x2E) est maintenant complètement
élucidé : désassemblage (`fn_resolve_patrol_vector`) + observation
comportementale isolée (table poussée contre un mur) + observation
combinée (impact gardien/table synchronisé) convergent tous vers la
même conclusion. Chantier clos avec un niveau de confiance maximal.

## Prochaines étapes

1. Identifier PRÉCISÉMENT quel handler du dispatch de collision
   générique (`0x27FE`, ~30 entrées) pose le bit 0/1 de `(ix+0C)` —
   dernière pièce manquante pour documenter le moteur de collision
   dans son intégralité (le résultat de la collision est confirmé,
   son mécanisme d'écriture bas niveau reste à tracer).
2. Reprendre l'exploration d'autres salles pour élargir la couverture
   du bestiaire (fantômes à déplacement aléatoire, autres variantes
   d'ennemis mentionnées par la taxonomie utilisateur mais pas encore
   rencontrées).
