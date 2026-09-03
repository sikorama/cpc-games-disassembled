# Session 2026-08-07 (suite 10) — Ennemi "poussoir" identifié : même sprite/famille que le mystérieux 0x83-0x85

Suite de `notes/2026-08-07-entity-logic-bouncing-ball.md`. Nouvelle
salle (0x5E, thème forêt). L'utilisateur décrit : "2 portes, 8 blocs en
bois, et 1 [ennemi] au milieu, avec la même animation que le joueur
apparaît/disparaît, et qui a la particularité d'être attiré par le
joueur pour le pousser (son contact n'est pas dangereux)".

## Room 0x5E — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4,5 / 6,7 | 0x04/0x05 | 2 portes (thème arbre) | "2 portes" ✓ |
| 22-29 | 0x06 (×8) | 8 blocs en bois | "8 blocs en bois" ✓ EXACT |
| **30** | **0xA6** | **L'ennemi "poussoir"**, position centrale-ish | "1 [ennemi] au milieu [...] attiré par le joueur pour le pousser" ✓ |
| 8-21 | 0x80 | Murs (segments, déjà connus) | (murs de la salle, non commentés) |

## DÉCOUVERTE MAJEURE : ce type partage son sprite avec le mystérieux 0x83-0x85

**Table de dispatch, groupe cohérent découvert** :

```
type 0xA0-0xA3  logique 0x11B9  sprites [0x52B1, 0x521E, 0x518B, 0x521E]  (état "repos"/transition ?)
type 0xA4-0xA7  logique 0x1209  sprites [0x52B1, 0x521E, 0x518B, 0x521E]  (MÊMES 4 sprites -- "attiré/en approche")
type 0xA8-0xAB  logique 0x1200  sprites [0x4687, 0x4600, 0x446B, 0x4702] (transition/état distinct)
```

**Correspondance frappante avec `fn_hostile_patrol_logic`
(0x0E4A, notes/2026-08-07-death-mechanism-partial.md)** : le type
`0x85` (dans le groupe 0x82-0x85 qui restait non identifié
visuellement) utilise le sprite **`0x518B`** — **EXACTEMENT le même
pointeur de sprite** que le type `0xA6` observé ici (poussoir attiré
par le joueur) et que `0xA2` (groupe "repos"). **Ceci suggère
fortement que 0x83-0x85 et 0xA0-0xA7 sont deux VARIANTES DE LOGIQUE
(agressive/mortelle vs poussoir/inoffensive) PARTAGEANT LA MÊME
FAMILLE VISUELLE** — probablement le même personnage/créature du jeu,
mais avec un comportement différent selon la salle ou le contexte
(peut-être une différence de "sous-espèce" ou d'état, à l'image du
gardien qui a plusieurs sprites pour ses différentes parties). **Point
à garder à l'esprit** : ne pas conclure que 0x83-0x85 EST le poussoir
observé ici — leur logique diffère significativement (l'un tue par
proximité via `fn_player_proximity_death`, l'autre pousse sans
dégâts) — mais leur parenté visuelle est maintenant établie sans
ambiguïté par le partage exact du pointeur de sprite.

## Type 0xA6 (et famille 0xA4-0xA7) — `fn_pusher_enemy_logic` (confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x1209).

```
1209  CALL 1D84               ; calibration projection
120C  LD A,(IX+08) / CP 88 / JR Z,121F   ; teste room_number == 0x88 (cas spécial, voir plus bas)
1213  LD A,(00DE) / BIT 0,A / JR Z,121F  ; teste bit 0 de (0x00DE) -- flag encore non identifié
121A  LD BC,0101               ; si les deux tests passent : throttle "vite" (1 frame)
121D  JR 1222
121F  LD BC,0404               ; sinon : throttle normal (4 frames)
1222  CALL 1240                ; RÉSOUT LE VECTEUR VERS LE JOUEUR (voir ci-dessous)
1225  RST 10                   ; applique le déplacement -- SE DÉPLACE VERS LE JOUEUR
1226  CALL 1267                ; avance l'animation (cycle 4 phases, comme fn_animation_cycle_4)
1229  LD A,(IX+08) / CP 88 / JR NZ,123D   ; encore le test room==0x88
1230  LD A,(00D7) / SUB 10 / CP 40 / JR C,123D   ; test sur (0x00D7) -- PROCHE du garde de mort
                                ;   du joueur (fn_player_door_transition, (type-0x10)>=0x40) mais
                                ;   PAS identique (ici c'est une comparaison LT, pas GE, et sur
                                ;   (0x00D7) pas (ix+00) -- à vérifier si (0x00D7) est un
                                ;   miroir/cache du type joueur)
1239  LD (IX+00),01            ; réinitialise le type à 0x01 (état neutre, déjà vu ailleurs)
123D  JP 0x1AD2                ; sous-routine finale non explorée
```

### `0x1240` — `fn_vector_toward_player` (confirmed, PRIMITIVE GÉNÉRIQUE probable)

```
1240  LD HL,00D8              ; position joueur en cache, axe X (déjà connu, fn_player_proximity_death
                                ;   utilise la MÊME paire 0x00D8/0x00D9)
1243  LD A,(IX+01) / SUB (HL) ; distance entité->joueur, axe X
1246  ... valeur absolue ...
124E  LD (IX+09),A             ; stocke dans le champ vecteur (consommé par RST 10 ensuite)
1251  LD A,(IX+02) / SUB (HL+1)  ; idem axe Y
...
125C  LD (IX+0A),A
125F  RET
```

**Interprétation confirmée** : cette routine calcule un vecteur
UNITAIRE (±1 sur chaque axe selon le signe de la distance, pas la
distance elle-même) vers la position du joueur — exactement la
primitive "aller vers le joueur" nécessaire pour un ennemi attiré.
**Réutilise `(0x00D8)/(0x00D9)`**, la même paire de variables déjà
identifiée dans `fn_player_proximity_death` (0x0EA0) comme position du
joueur mise en cache — confirme que ces deux octets sont bien une
primitive GLOBALE de position joueur, recalculée une fois par frame et
consultée par plusieurs types d'entités différents (poussoir,
ennemi(s) hostile(s)).

## Corrélation avec l'observation "même animation que le joueur" — test empirique partiel

**Test effectué** : poll RAM du type de l'entité (slot 30, room 0x5E)
sur ~4.5 secondes (0.15s/échantillon) : le type oscille uniquement
entre **0xA4, 0xA5, 0xA6, 0xA7** (jamais 0x70-0x7F observé dans cette
fenêtre), position de grille restée figée à `(0x46, 0x46)` tout du
long — donc PAS de déplacement notable observé dans cette courte
fenêtre (peut-être hors de portée d'attraction du joueur au moment du
test, ou throttle "lent" 0x0404 actif car les gardes room==0x88/bit0
de (0x00DE) n'étaient pas remplies).

**Conclusion provisoire** : le cycle 0xA4-0xA7 EST bien un cycle
d'animation à 4 phases (comme 0x70-0x7F pour le joueur), mais **ce
n'est PAS littéralement la même plage de types ni le même code** —
l'observation de l'utilisateur ("même animation que le joueur
apparaît/disparaît") fait donc plus probablement référence à une
**similarité visuelle du PATTERN d'animation** (un effet de
scintillement/dissolution similaire à l'œil) plutôt qu'à une
réutilisation littérale de la séquence 0x70-0x7F. **Pas de contradiction
avec le désassemblage, juste une clarification** : chaque "famille"
d'entité (joueur, poussoir) a sa PROPRE séquence de types dédiée à son
animation de matérialisation, mais suivant un pattern de conception
similaire (incrémenter le type toutes les N frames jusqu'à une valeur
de fin) — cohérent avec la découverte plus générale de cette session
que le jeu réutilise des PATTERNS de logique (pas toujours le même
code exact) à travers différents types d'entités.

## Prochaines étapes

1. Vérifier le lien exact entre cet ennemi et la séquence 0x70-0x7F
   (observation empirique du type au moment de son apparition dans la
   salle).
2. Désassembler `0x1AD2` (sous-routine finale, appelée par les 3
   variantes 0xA0-0xAB) — pourrait contenir la logique de poussée
   effective du joueur.
3. Élucider `(0x00DE)` (bit 0 testé ici) et le rôle du cas spécial
   room==0x88 — deux nouvelles pistes ouvertes par cette routine.
4. Continuer à chercher le VRAI comportement mortel de 0x83-0x85 dans
   une salle où il apparaît sous sa forme hostile — la parenté
   visuelle avec 0xA0-0xA7 est confirmée, mais son apparence RÉELLE
   dans une salle où il est dangereux reste à observer.
