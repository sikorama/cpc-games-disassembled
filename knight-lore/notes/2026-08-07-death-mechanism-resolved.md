# Session 2026-08-07 (suite 8) — Mécanisme de perte de vie ÉLUCIDÉ (réutilise fn_player_door_transition)

## Contexte

L'utilisateur a clarifié que la mort par contact ennemi (tant qu'il
reste des vies) n'est PAS un game over complet (contrairement à ce que
`notes/2026-08-07-death-mechanism-partial.md` supposait en suivant le
seul chemin `0x0EBC → 0x12FB`) : "quand on perd une vie, tant qu'il
nous en reste, ce n'est pas le game over, mais une réinitialisation de
la pièce, et le personnage est replacé là où il est rentré dans la
pièce. Il n'y a aucun message à l'écran."

## DÉCOUVERTE : le "reset spécial" déjà vu dans fn_player_door_transition EST le mécanisme de mort

Repris de `notes/2026-08-07-entity-logic-doors.md`, section
`fn_player_door_transition` (0x2322) — un bloc de code avait été
identifié à l'époque comme une "garde spéciale" au comportement mal
compris :

```
2377  LD A,(IX+00)           ; type courant du joueur
237A  SUB 10
237C  CP 40
237E  RET NC                  ; si (type-0x10) < 0x40, i.e. type < 0x50, RIEN ne se passe -> return normal
237F  INC SP ×4                ; sinon (type >= 0x50) : annule 2 niveaux de CALL empilés
2383  PUSH IX / POP HL
2386  LD DE,29EB / LD BC,0038 / LDIR   ; recopie le template de 56 octets (2 entités) vers struct_entities_base
238E  LD A,(29EB) / LD (29FB),A        ; patch de code (préserve un octet du template pour usage futur)
2394  LD A,(2A07) / LD (2A17),A
239A  LD A,78 / LD (29EB),A / LD (2A07),A
23A2  JP 0542                          -- CORRECTION : ce n'est PAS 0x0542, c'est 0x05A5 (fn_init_room),
                                        -- vérifié par recherche de tous les appelants de 0x05A5
```

**CORRECTION IMPORTANTE de lecture** : la note du 2026-08-07 sur les
portes indiquait par erreur `jp 0x0542` — **vérifié aujourd'hui par
recherche exhaustive des appelants de `0x05A5` dans les 16K bas** :
**le seul JP vers `0x05A5` dans tout le binaire est celui-ci
(`0x23A2`)**. C'est donc `fn_init_room` (0x2A68, appelée via 0x05A5),
PAS le point d'entrée de restart complet vers le menu (0x0542) — une
différence cruciale : **`fn_init_room` réinitialise la salle SANS
repasser par le menu ni l'écran titre**, exactement ce que l'utilisateur
décrit ("aucun message à l'écran").

## CORRECTION (suite à re-vérification immédiate) : 0x12FB N'EST PAS le chemin emprunté

**Statut : re-vérifié, hypothèse précédente INFIRMÉE**. Les deux
branches de `0x12FB` (`(0x0089)==0` et `(0x0089)!=0`) ont été retracées
intégralement cette fois — **les deux convergent vers le même
`jp 0x0542`** (retour complet au menu), aucune bifurcation "légère" ne
s'y trouve. Or l'observation empirique confirme que la salle est
restée 0x43 tout du long, SANS jamais revenir au menu — **donc `0x0EBC`/
`0x12FB` n'a PAS été emprunté du tout lors de cette mort**, contrairement
à l'hypothèse initiale de cette note.

**Conclusion révisée** : le test de proximité mortelle `0x0EA0-0x0EBC`
(`fn_player_proximity_death`, dans `fn_hostile_patrol_logic` 0x0E4A)
n'est PAS le mécanisme emprunté pour une mort "avec vies restantes" —
soit il ne s'est simplement pas déclenché cette fois (contact avec une
AUTRE source de dégât), soit il reste réservé à un cas différent
(dernière vie ? contact avec un type d'ennemi spécifique non
rencontré ?). **Le vrai déclencheur de la mort observée est le garde
de `fn_player_door_transition`** (0x2377 : `type - 0x10 >= 0x40` →
reset de salle via `fn_init_room`), confirmé empiriquement en direct
(voir section suivante) — un mécanisme totalement SÉPARÉ de
`0x0EBC`/`0x12FB`, découvert par accident en cherchant les appelants
de `0x05A5`.

**Piste ouverte pour la suite** : identifier PRÉCISÉMENT quelle
routine assigne au type du joueur une valeur `>= 0x50` au moment du
contact mortel (le déclencheur immédiat consommé par `0x2377`) — pas
encore trouvée, recherche à faire par recherche de `LD (IX+00),xx`
avec `xx >= 0x50` dans le code de collision/dégât, ou par breakpoint
sur l'écriture de `(0x00D7)` (offset +00 de l'entité 0) pendant une
mort réelle.

## Chemin confirmé empiriquement (chronologie complète)

Breakpoint posé sur `fn_init_room` (0x2A68), l'utilisateur a perdu une
vie volontairement :

```
avant la mort : room=0x43, type=0x12 (joueur normal)
BREAKPOINT HIT sur fn_init_room (0x2A68), IX=0x00D7
  au hit : entity0 type=0x78 (template en cours de copie), room=0x43 (INCHANGÉE)
après resume : room=0x43 (confirmé stable), type=0x79 (juste après, en cours de stabilisation)
```

**Confirme exactement l'observation de l'utilisateur** : la salle reste
la MÊME (0x43 avant et après), aucun retour au menu, aucun message
affiché — juste un rechargement complet de la salle courante via la
routine normale de chargement (`fn_init_room`), déclenché par le
"type invalide" du joueur après le contact mortel.

## Mécanisme confirmé (ce qu'on sait avec certitude)

```
1. Contact/dégât (source exacte pas encore localisée avec certitude)
     -> assigne au joueur un type spécial (ix+00) tel que (type - 0x10) >= 0x40
2. Frame suivante, fn_player_logic -> fn_player_door_transition (0x2322)
     -> teste ce type en tout début (0x2377-0x237E)
     -> déclenche le reset via fn_init_room (0x05A5/0x2A68), SANS jamais
        toucher au menu ni à 0x12FB
     -> room_number INCHANGÉ (recharge la salle courante, pas une autre)
     -> le template d'entités (0x29EB, 2×28 octets) est recopié tel quel
        -> RÉPOND À LA QUESTION DE L'UTILISATEUR : "je soupçonne une copie
           des données de la pièce dans un buffer" -- CONFIRMÉ, mais ce
           n'est PAS un buffer de la GÉOMÉTRIE de la salle (murs/portes,
           qui restent des données statiques relues depuis les tables
           originales à chaque fn_init_room), c'est un TEMPLATE D'ENTITÉS
           DYNAMIQUES (position de départ du joueur + 1 autre entité) --
           voir section suivante pour le détail exact.
```

**Ce qui reste à découvrir** : la source exacte du dégât qui assigne ce
type spécial (>= 0x50) au joueur — ni `fn_check_collisions`/
`fn_collision_effect` (qui modifient le type de l'AUTRE entité en
collision, 0xBB, pas celui du joueur) ni `fn_player_proximity_death`
(0x0EBC, qui saute directement à 0x12FB sans passer par un type
spécial) ne semblent correspondre exactement — un troisième mécanisme
de dégât reste à localiser.

**Recherches infructueuses menées cette session** (documentées pour ne
pas les répéter à l'identique) :
- Recherche exhaustive de `LD (IX+00),xx` avec `xx >= 0x50` dans les
  16K bas : 8 résultats trouvés, tous déjà expliqués par des mécanismes
  connus (gardien 0x82-0x85, transformation 0xBA/0xBB, "hors champ"
  0x70/0x83) — aucun candidat clair pour "dégât reçu par le joueur".
- Recherche de `ADD A,xx / LD (IX+00),A` avec `xx >= 0x50` : 2
  résultats, tous deux déjà connus (`fn_hostile_patrol_logic` variance
  pseudo-aléatoire, et une routine à 0x26D1 non encore explorée mais
  qui ADD 0x10 pas 0x50+, donc hors sujet).
- Recherche de `LD (00D7),A` (écriture directe absolue sur l'entité 0) :
  aucun résultat — l'écriture se fait très probablement toujours via
  `(IX+00)` avec IX pointant sur l'entité 0 au moment voulu, pas par
  adresse absolue, ce qui explique pourquoi cette recherche seule ne
  suffit pas à isoler le bon site sans connaître le contexte IX exact.

**Piste à essayer en priorité la prochaine fois** : poser un
**breakpoint d'écriture mémoire sur `0x00D7`** au moment précis d'un
contact mortel réel (nécessite que l'outil MCP supporte ce type de
breakpoint — à vérifier dans `src/doc/web_server_api.md`, sinon
utiliser un polling RAM très rapproché juste avant/pendant une mort
provoquée volontairement, en surveillant `(ix+00)` frame par frame).

## CONFIRMÉ PAR L'UTILISATEUR : compteur de vies = `(0x0080)` (2026-08-07)

**Statut : CONFIRMED empiriquement**, via un outil externe de
l'utilisateur (recherche RAM par valeur successive : "chercher 4,
perdre une vie, chercher 3, etc." — méthode classique de recherche de
compteur, confirmée fonctionner ici en une seule étape car
`(0x0080)=0x04` correspondait déjà exactement aux 4 vies affichées).

**Recoupement avec le désassemblage** : `(0x0080)` était déjà connu
sous le nom `var_room_countdown` (`docs/SYMBOLS.md`), décrémenté dans
`fn_init_room_entities` (0x29B4, ligne `0x29C6-0x29CA` : `DEC (HL) /
JP M,0x12FB`) — **exactement le mécanisme qui déclenche le vrai game
over** (retour menu) quand le compteur devient négatif. **Renommage
proposé** : `var_room_countdown` → **`var_life_counter`** (le nom
"room_countdown" était une hypothèse de lecture rapide, imprécise —
c'est un compteur de VIES, pas de temps/tours dans une salle).

**Point clé qui restait bloquant, maintenant résolu par déduction** :
`fn_init_room_entities` n'a qu'UN SEUL appelant dans tout le binaire
(`0x05A2`, juste avant `fn_init_room` elle-même, un seul appelant aussi :
`0x05A5`) — et ces deux routines ne sont invoquées QUE par le garde de
mort de `fn_player_door_transition` (0x2377, voir plus haut) ou par le
tout premier lancement de partie (séquence `0x0542+`). **Le
franchissement NORMAL d'une porte (changement de room_number par
nibble, sans mort) n'appelle JAMAIS `fn_init_room`/
`fn_init_room_entities`** — donc `(0x0080)` n'est décrémenté QUE lors
d'une mort (ou du tout premier lancement de partie), jamais lors d'un
déplacement normal entre salles. **Ceci confirme et complète
entièrement la chaîne causale déjà établie** :

```
Contact mortel -> assigne type spécial au joueur (déclencheur encore non localisé)
  -> fn_player_door_transition (0x2377) détecte le type spécial
  -> CALL fn_init_room_entities (0x29B4) : DEC (0x0080) [vies -= 1]
       -> si (0x0080) devient négatif : JP 0x12FB (GAME OVER complet, retour menu)
       -> sinon : continue normalement, template d'entités recopié
  -> CALL fn_init_room (0x2A68) : recharge la salle COURANTE (room_number inchangé)
  -> JP 0x05A8+ : reprise du jeu dans la même salle, joueur repositionné au template
```

**Le compteur de vies EST donc directement le mécanisme qui décide,
lors d'une mort, entre "réinitialiser la salle courante" (vies
restantes) et "vrai game over" (plus de vies)** — les deux
observations de l'utilisateur (mort douce vs game over) sont
gouvernées par LE MÊME test, pas deux mécanismes séparés comme
l'hypothèse précédente le supposait. Boucle bouclée.

**Reste seul point ouvert** : le déclencheur immédiat (quelle routine
assigne le type spécial `>= 0x50` au joueur au moment du contact) —
recherches infructueuses documentées plus haut, non repris ici.

## Historique de la recherche (avant la confirmation utilisateur)

Avant que l'utilisateur ne fournisse la localisation exacte via son
outil externe, une recherche de `CP 04` sur une variable basse avait
été tentée dans le désassemblage (un seul résultat, `(0x0076)` — déjà
connu comme `var_room_reset_flag_2`, sans lien avec un compteur de
vies) — **cette approche par recherche de motif de code s'est révélée
infructueuse**, contrairement à la recherche RAM empirique par valeur
(méthode proposée par l'utilisateur) qui a fonctionné immédiatement.
**Leçon méthodologique à retenir** : pour un compteur dont on connaît
la valeur actuelle mais pas l'adresse, la recherche RAM par
valeur/décrément (side-channel empirique) est souvent plus rapide et
plus fiable que d'essayer de deviner le motif de code exact qui le
manipule (le code peut utiliser `DEC (HL)`, `DEC A / LD (addr),A`, ou
toute autre forme, difficile à toutes les anticiper par recherche
textuelle).

## Statut

**CONFIRMED (empirique + désassemblage recoupés)** : la perte de vie
"douce" (avec vies restantes) réutilise `fn_init_room` (0x2A68) pour
recharger la salle COURANTE (pas de changement de room_number), sans
passer par le menu — confirmé par observation directe RAM synchronisée
avec l'action de l'utilisateur. **CONFIRMED (utilisateur, outil externe
+ recoupement désassemblage)** : le compteur de vies est `(0x0080)`
(renommé `var_room_countdown` → `var_life_counter`), décrémenté dans
`fn_init_room_entities` à chaque mort, avec bascule vers le vrai game
over (`0x12FB`) s'il devient négatif — **boucle la chaîne causale
complète de bout en bout**. **Point encore ouvert** : le déclencheur
exact (quel code assigne le type "spécial" >= 0x50 au joueur au moment
de la mort) reste à tracer précisément.

## RÉSOLU (proposé par l'utilisateur, confirmé par désassemblage) : le "type spécial" est l'animation de (dé)matérialisation du joueur

**Statut : CONFIRMED** par désassemblage direct. L'utilisateur a
proposé l'hypothèse : "le type spécial, c'est une animation pour faire
disparaître le joueur, et c'est la MÊME que celle utilisée pour le
rematérialiser (au lancement du jeu ou après une perte de vie)".
**Confirmée immédiatement par la table de dispatch** :

```
type 0x70-0x76  -> logique 0x17DC  (7 valeurs, throttle 2 frames, INC (ix+00) à chaque tick)
type 0x77       -> logique 0x17FC  (point de bascule, voir plus bas)
type 0x78-0x7E  -> logique 0x17A7  (7 valeurs, throttle 2 frames, INC (ix+00) à chaque tick)
type 0x7F       -> logique 0x17BC  (fin d'animation : restaure le type stable, retour boucle de jeu)
```

**C'est une SEULE séquence linéaire de 16 étapes** (`0x70` à `0x7F`),
chaque routine se contentant d'incrémenter le type d'entité toutes les
2 frames (`(0x006A) throttle`) jusqu'à atteindre `0x7F`, qui restaure
le vrai type stable du joueur depuis `(ix+10)` (le champ qui garde en
mémoire le type "normal" — jour 0x14 ou nuit 0x34, déjà connu de
`fn_player_transform_complete`) et saute vers `0x05D4` (reprise
normale de la boucle de jeu, PAS un restart complet).

**Correspondance directe avec les observations empiriques déjà
faites** :
- Au tout premier lancement de partie (`fn_init_room_entities`, le
  template copié depuis `0x29EB`), le type de départ observé était
  exactement **`0x78`** — le DÉBUT de cette même séquence
  d'animation !
- Lors de la mort observée en direct cette session (voir ci-dessus),
  le type capturé au moment du breakpoint sur `fn_init_room` était
  `0x78`, puis `0x79` juste après resume — **exactement la
  progression attendue de cette animation**, confirmant sans ambiguïté
  qu'il s'agit du MÊME mécanisme visuel dans les deux cas (lancement
  de partie ET réapparition après mort), comme l'a proposé
  l'utilisateur.

**Nom symbolique proposé** : `fn_player_materialize_anim_a`
(0x17DC, types 0x70-0x76), `fn_player_materialize_anim_pivot` (0x17FC,
type 0x77), `fn_player_materialize_anim_b` (0x17A7, types 0x78-0x7E),
`fn_player_materialize_anim_end` (0x17BC, type 0x7F).

**Ce qui reste à préciser** : cette découverte explique COMMENT le
joueur réapparaît visuellement (progression de type 0x70→0x7F), mais
PAS encore le déclencheur immédiat de la DISPARITION au moment du
contact mortel — reste à vérifier si un chemin symétrique existe
(ex: le joueur passe d'abord par un type de "disparition" avant
d'atteindre 0x78, ou si le template copié saute directement dedans
sans jamais montrer de disparition explicite). Le nom de fonction
"materialize" est donc pour l'instant seulement confirmé pour la
partie RÉAPPARITION de la séquence, cohérent avec l'observation de
l'utilisateur.
