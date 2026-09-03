# Session 2026-08-07 (suite 11) — La table poussable (0x54/0x55), test de collision en direct

Suite de `notes/2026-08-07-entity-logic-pusher.md`. Nouvelle salle
(0x6D, thème forêt). L'utilisateur décrit un élément nouveau et très
riche : "une table — on peut la pousser, sauter dessus, bloquer le
gardien avec".

## Room 0x6D — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4-7 | 0x04/0x05 | 2 portes | "2 portes" ✓ |
| 8-21 | 0x80 | 2 grands murs (arbres) | "2 grands murs" ✓ |
| 22-29 | 0x06 (×8) | 8 blocs en bois | "8 blocs bois" ✓ EXACT |
| 30-31 | 0x16 (×2) | 2 statues de crapaud | "2 statues crapauds" ✓ EXACT |
| 2 | 0x66 | Boule de cristal | "1 boule de cristal à ramasser" ✓ |
| 33-34 | 0x97/0x9D | Le gardien (corps+jambes, famille 0x90-0x9D déjà connue) | "un gardien qui fait des allers-retours selon l'axe X" ✓ |
| **32** | **0x54** | **LA TABLE** (nouveau type) | "1 table [...] on peut la pousser, sauter dessus, bloquer le gardien avec" ✓ |

## Type 0x54/0x55 — `fn_pushable_table_logic` (confirmed)

**Statut : confirmed** par désassemblage + test empirique en direct.

```
0x54 -> logique 0x1D71 (variante "poussée active" ?)
0x55 -> logique 0x1D66 (variante voisine, quasi-identique)
```

```
1D66  CALL 1D8F              ; calibration projection
1D69  RST 10                  ; applique le déplacement courant (rst_apply_movement_vector)
1D6A  CALL 1A40 / RET Z        ; teste si le vecteur de déplacement est nul -> si oui, RET direct
1D6E  JP 1AD2                  ; sinon, finalise (voir plus bas)

1D71  CALL 1D8F
1D74  RST 10
1D75  CALL 1A40 / RET Z
1D79  CALL 22A5                ; ANNULE le vecteur de déplacement ((ix+09)/(ix+0A) = 0)
1D7C  JP 1AD2
```

**Interprétation** : la table applique un déplacement (`RST 10`)
EXACTEMENT COMME toute entité mobile générique — **elle n'a pas de
logique de poussée propre**, elle se contente de suivre le vecteur
déjà stocké dans ses champs `+09/+0A` au moment où `fn_check_collisions`
(le moteur de collision générique) l'a rempli suite à un contact avec
le joueur. Autrement dit : **c'est le moteur de collision GÉNÉRIQUE qui
gère la poussée**, pas une routine dédiée à la table — la table est un
simple objet mobile comme un autre, poussable parce que sa bbox
participe au système de collision standard, pas parce qu'elle a un
comportement spécial.

**Différence 0x54 vs 0x55** : `0x54` annule le vecteur après
utilisation (`CALL 22A5`), `0x55` ne le fait pas — cohérent avec deux
micro-états ("en cours de poussée" vs "immobile après poussée"),
probablement liés à la même logique de flip/bascule déjà vue ailleurs
(un bit de `(ix+00)` ou `(ix+07)`, pas creusé plus avant cette
session).

## Test empirique en direct : mouvement de la table sous poussée du joueur

**Protocole** : poll RAM du slot de la table (32) à haute fréquence
(0.08s/échantillon) sur 55 secondes pendant que l'utilisateur pousse la
table dans différentes directions.

**Résultat** : mouvement confirmé sur les deux axes, PAR PAS DISCRETS
(pas un glissement continu à chaque frame) :

```
grid_x: 0x58 -> 0x76 -> 0x79 -> 0x7A -> ... -> 0x62 -> 0x59  (va-et-vient sur X)
grid_y: 0x58 (fixe longtemps) -> 0x5B -> 0x5E -> 0x61        (puis mouvement sur Y)
```

Le déplacement se fait par petits sauts de quelques unités à la fois
(observé : sauts de 1 à 3 unités entre deux échantillons distincts),
cohérent avec le mécanisme de collision standard qui pousse l'objet
d'une quantité liée à la vitesse de déplacement du joueur au moment du
contact — PAS un glissement fluide indépendant.

**Le flag `(ix+07)` oscille rapidement** entre plusieurs valeurs
(`0x04`, `0x14`, `0x34`) — cohérent avec le mécanisme déjà connu de
rendu ("à retraiter"/"en cours de traitement", bits 4-5) plutôt qu'un
signal spécifique à la poussée.

## Test 2 — coincer la table contre un mur (Y+), résultat empirique

**Protocole** : poll RAM à haute fréquence (0.06-0.1s/échantillon) du
slot de la table pendant que l'utilisateur la pousse contre le mur du
côté Y+ de la salle.

**Résultat** :
- `grid_y` progresse régulièrement de `0x58` à `0xB5` sous la poussée
  continue du joueur, PUIS **se fige exactement à `0xB5`** — plus
  aucun mouvement enregistré malgré la poussée du joueur qui continue
  (sa propre position `grid_y` monte encore un peu après l'arrêt de la
  table) — confirme sans ambiguïté que la table a atteint une BUTÉE
  fixe (le mur).
- **Signal de blocage identifié** : le champ `(ix+0C)` de la table,
  qui alternait presque exclusivement entre `0x04` et `0x14`/`0x34`
  pendant le mouvement normal, se met à alterner fréquemment avec
  `0x06` une fois la table bloquée contre le mur — **candidat fort
  pour un bit "collision fixe/butée détectée"**, jamais observé aussi
  clairement avant ce test. Rôle exact du bit 1 de `(ix+0C)` (valeur
  `0x02`, présente dans `0x06=0x04|0x02` mais pas dans `0x04` seul) à
  confirmer par désassemblage — piste concrète pour la prochaine
  session : chercher où ce bit est lu/testé dans le code (recherche
  `BIT 1,(IX+0C)` ou motif équivalent).

**Implication pour le mystère du gardien** : ce même champ `(ix+0C)`
est déjà connu comme testé par plusieurs entités mobiles (`bit 2,(ix+0C)`
dans la balle rebondissante et les piques, `bit 2,(ix+07)` ailleurs) —
**hypothèse à tester en priorité la prochaine fois qu'un gardien est
observable** : peut-être que le bit 1 (pas bit 2) de ce même octet
`(ix+0C)` est CELUI qui, une fois détecté par `fn_guard_patrol_logic`
(0x1280), déclenche le changement de direction — cohérent avec
l'observation de l'utilisateur ("le gardien tourne après une collision").
Reste à vérifier par désassemblage direct de `0x1280`/`0x12A5` avec
cette hypothèse précise en tête (chercher un test sur bit 1, pas
seulement bit 2 comme cherché initialement).

## Type 0x55 — CONFIRMÉ comme "coffre glissant" (différent de la table 0x54)

**Statut : confirmed** — corrélation directe entre le désassemblage
déjà fait et l'observation utilisateur (room 0x6C, "8 coffres [...]
peuvent être poussés, et ils glissent tout seuls quand on les pousse,
à la différence des tables").

Rappel du désassemblage (déjà présent plus haut dans ce fichier) :

```
0x54 (table)  -> logique 0x1D71 : RST 10 puis, si vecteur non nul,
                 CALL 0x22A5 (annule IMMÉDIATEMENT le vecteur après
                 UN SEUL pas de déplacement) -> la table s'arrête dès
                 que le contact avec le joueur cesse.

0x55 (coffre) -> logique 0x1D66 : RST 10 SANS jamais appeler 0x22A5
                 -> le vecteur de déplacement N'EST PAS remis à zéro
                 après application -> le coffre CONTINUE à appliquer
                 le même vecteur à CHAQUE frame suivante, même une
                 fois le contact avec le joueur terminé -> IL GLISSE
                 (le mouvement continue jusqu'à ce qu'un autre
                 mécanisme, probablement une friction/décrément du
                 vecteur ou une nouvelle collision, l'arrête).
```

**Cette différence d'UNE SEULE instruction (`CALL 0x22A5` présent ou
absent) explique entièrement le comportement observé** : la table
s'arrête net dès qu'on ne la touche plus (poussée "collée" au joueur),
le coffre continue sur sa lancée (poussée "avec inertie/glissement").
Élégant exemple de réutilisation de code avec un seul point de
divergence pour deux comportements de gameplay différents.

**Room 0x6C confirmée** : 8 boules à pics (0x3F, déjà connues,
observées au sol après leur chute — tombées avant le début du
monitoring cette fois, chute non re-capturée mais comportement déjà
bien établi les sessions précédentes) + 8 coffres (0x55) — inventaire
exact confirmé par dump RAM, correspondant parfaitement à la
description de l'utilisateur.

## Test empirique — coffre poussé jusqu'au mur (confirmation du glissement + de l'arrêt par collision)

**Protocole** : dump complet de la room 0x6C avant/après que l'utilisateur
pousse 4 coffres, suivi d'un monitoring de 55s.

**Résultat** :
- Les 4 coffres poussés (slots 23, 24, 27, 28) sont passés de
  `grid_x=0x78` à `grid_x=0x4A` — un déplacement de 0x2E (46 unités),
  bien plus qu'un "pas" de poussée typique, cohérent avec un
  glissement continu sur toute la largeur de la salle jusqu'au mur.
- Une fois arrivés à `grid_x=0x4A`, leur position est restée
  **parfaitement stable** pendant toute la fenêtre d'observation de
  55 secondes — confirme que le coffre bloqué par une collision
  s'IMMOBILISE (ne rebondit pas, ne continue pas dans une autre
  direction), contrairement à ce qu'on aurait pu craindre vu que
  `fn_sliding_chest_logic` n'annule jamais explicitement son propre
  vecteur.

**Explication du mécanisme d'arrêt** : le coffre n'a pas besoin
d'annuler son propre vecteur pour s'arrêter — c'est le moteur de
collision GÉNÉRIQUE qui, en détectant le contact avec le mur,
neutralise ou inverse le déplacement au niveau de la primitive
`rst_apply_movement_vector`/collision AABB (déjà connue), EXACTEMENT
comme il le fait pour tout objet mobile heurtant un obstacle fixe
(cf. le test de la table contre un mur, où le signal de collision
`(ix+0C)` bit 1 avait été observé). Confirme que le glissement du
coffre n'est PAS une "vraie" physique avec inertie séparée du système
de collision — c'est le MÊME système générique, juste sans l'étape
d'auto-arrêt volontaire (`0x22A5`) que la table applique par
elle-même dès la fin du contact avec le joueur.

**Correction de compréhension importante** : l'observation initiale
de l'utilisateur ("ils glissent tout seuls [...] il ne s'arrêtera que
quand il sera contre le mur") est donc plus précise que la première
hypothèse du désassemblage seul ne le suggérait — le coffre continue
de glisser non pas indéfiniment par manque de friction, mais
JUSQU'AU PREMIER OBSTACLE rencontré (mur, autre entité solide), où le
moteur de collision commun l'arrête comme n'importe quel objet mobile.

## Prochaines étapes (tests suggérés à l'utilisateur, restant à faire)

1. ~~Test 2 — coincer la table contre un mur~~ **FAIT**, voir section
   ci-dessus.
2. **Test 3 — sauter sur la table** : vérifier si `grid_z_or_offset`
   (+03) ou un champ de collision spécifique change pour indiquer que
   le joueur est "dessus" (élévation) plutôt qu'à côté.
3. **Test 4 — bloquer le gardien avec la table** : observer la
   réaction du gardien (arrêt, changement de direction via
   `(ix+0D)`, poussée de la table lui-même) — pourrait enfin révéler
   le mécanisme de "changement de direction par collision".
4. Désassembler `0x1AD2` en détail (appelé par la table ET par le
   poussoir 0xA0-0xAB) — semble être une routine de finalisation
   générique post-déplacement, jamais entièrement tracée.
5. **Nouvelle piste prioritaire** : vérifier par désassemblage si
   `BIT 1,(IX+0C)` (ou motif équivalent) est testé dans
   `fn_guard_patrol_logic`/`fn_resolve_patrol_vector` — pourrait enfin
   expliquer le changement de direction du gardien par collision.
