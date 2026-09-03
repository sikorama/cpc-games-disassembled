# Session 2026-08-07 (suite 21) — Balayage complet des 128 salles + identification d'entités, dont LE MAGICIEN

## Contexte

Premier balayage complet et fiable des 128 salles via
`tools/room_map/teleport.py --all` (voir
`notes/2026-08-07-room-teleport-tool-validated.md` pour les correctifs
qui l'ont rendu fiable : vérification complète par salle + passe de
rattrapage). 128/128 salles vérifiées, ~31 secondes, partie de
l'utilisateur restaurée intacte.

11 types d'entités non identifiés trouvés (hors joueur/compagnon).
L'utilisateur a visité les 9 salles candidates et identifié
visuellement chacun — avec une hypothèse clé confirmée en cours de
route : **plusieurs types partagent le même sprite mais ont une
logique différente** (déjà observé pour la famille "diamant/bouteille"
0x60-0x66 vs 0x68-0x6E ; ici confirmé pour plusieurs nouvelles familles).

## DÉCOUVERTE MAJEURE : Le Magicien et le chaudron — salle 0x88 trouvée

**Statut : CONFIRMED empiriquement (utilisateur).** Piste ouverte
depuis plusieurs sessions (`notes/2026-08-07-entity-logic-ghost.md`,
mentionnée aussi dans `docs/SESSION_SUMMARY.md` comme "non rencontrée,
salle inconnue, mise en pause") — **RÉSOLUE** : la salle est **0x88**.

Trois types y coexistent, jamais séparés dans aucune autre salle du
jeu (128 salles balayées, aucune autre salle ne contient un seul de ces
trois types) :

| Type | Logique | Sprite | Rôle (utilisateur) |
|---|---|---|---|
| 0x8D | 0x1277 | 0x5344 | le magicien qui tourne autour du chaudron (ou le chaudron lui-même) |
| 0x8E | 0x127A | 0x544F | idem — les 3 rôles pas encore assignés précisément à un type unique |
| 0x9E | 0x1280 | 0x4AD7 | élément d'animation au-dessus du chaudron |

Les logiques de 0x8D et 0x8E sont à seulement 3 octets d'écart
(0x1277/0x127A) — cohérent avec deux entités étroitement liées
(probablement le magicien mobile + le chaudron statique, une paire
utilisant des routines voisines). 0x9E (0x1280) est un peu plus loin
mais dans la même zone de code. **Non encore désassemblé en détail** —
piste ouverte pour une session future si on veut confirmer précisément
qui est qui (le mouvement circulaire du magicien devrait être visible
en pollant grid_x/grid_y sur plusieurs frames).

## Familles "même sprite, logique différente" confirmées

Comme anticipé par l'utilisateur ("peut-être que certains types ont le
même sprite, mais un comportement différent") — vérifié pour chaque
type via `tbl_entity_logic_dispatch` ET `tbl_sprite_dispatch` :

### Famille "bloc" (sprite 0x59DB, partagé avec 0x07 bloc statique et 0x3E bloc poussable)

| Type | Logique | Rôle (utilisateur/désassemblage) |
|---|---|---|
| 0x07 | 0x1D8F | bloc statique (déjà confirmé) |
| 0x3E | 0x1D53 | bloc poussable (déjà confirmé) |
| **0x36** | **0x0F98** | **bloc mobile** — salle 0x2D, "même chose qu'en 0x1D mais avec un autre déplacement" |
| **0x37** | **0x0F93** | **bloc mobile** — salle 0x1D. Partage la MÊME routine que 0x36 (`JR` vers 0x0F9B), seule différence : une paire de paramètres HL patchée différemment (0x36 = `HL=0109`, 0x37 = `HL=020A`) — confirme exactement l'observation "même chose, autre déplacement" : un seul mécanisme, deux jeux de paramètres de vitesse/motif |
| **0x8F** | **0x0F84** | Bloc "dormant" (`bit 3,(ix+0D)` → si 0, RET immédiat = strictement statique, indiscernable d'un 0x07 normal — cohérent avec "rien de nouveau" côté utilisateur). Si le flag est posé : `(ix+00)=0xB8` puis saute dans la logique de 0xB8 — DÉCLENCHE UNE SÉQUENCE D'ANIMATION (voir section suivante) |
| **0x5B** | **0x0F67** | Bloc "dormant" similaire à 0x8F (même test de bit3, RET si clair) mais sans la transformation — juste `RES 3,(ix+0D)` (consomme le flag sans effet visible connu). **Voir "point ouvert" ci-dessous — l'identification "bouteille" de l'utilisateur ne colle pas au sprite (bloc, pas bouteille)** |

**Piste bonus découverte en creusant 0x8F** : le type 0xB8 (déclenché par
0x8F) arme un son (`fn_sound_arm_channel_0`, séquence 0x098E) puis
**incrémente son propre type à chaque frame** (0xB8→0xB9→0xBA→...),
armant un son différent à chaque étape — signature d'une **séquence
d'animation/transformation par étapes**, jamais rencontrée en jeu. Rôle
final non déterminé (où s'arrête la séquence ? quel est l'effet final ?)
— piste ouverte.

### Famille "feu follet" (sprite 0x5763, partagé avec 0xB4)

| Type | Logique | Rôle |
|---|---|---|
| 0xB4 | 0x10F4 | feu follet (déjà confirmé, oscillation Y, rebond par collision) |
| **0x56** | **0x10D4** | **feu follet** — salle 0x93, confirmé visuellement par l'utilisateur. Logique DIFFÉRENTE de 0x10F4 — comportement exact non encore désassemblé, mais partage le sprite donc visuellement identique à 0xB4/0xB5 |

## DÉCOUVERTE : `fn_ball_chase_flee_logic` (0x0EE5), type 0xB6 — IA dépendante de la forme du joueur (NOUVEAU, jamais vu)

**Statut : confirmed (désassemblage + confirmation utilisateur
concordante).** Salle 0x08 : "un ennemi 'boule' avec un bloc par-dessus
lui, qui se déplace vers le joueur s'il est loup-garou et le fuit
sinon."

Désassemblage complet (0x0EE5-0x0F65) :

```
0EE5  CALL 1D9E          ; calibration
0EE8  applique le vecteur de déplacement courant (RST 10)
0EFD  LD A,(00D7)         ; lit le TYPE DU JOUEUR (entité 0)
0F00  SUB 10 / CP 20       ; teste si (type_joueur - 0x10) >= 0x20
0F04  LD A,30              ; A = 0x30 = opcode "JR NC,d"
0F06  JR NC,0F0A            ; si type_joueur en forme "loup" (>=0x30) -> garde 0x30
0F08  ADD A,08               ; sinon (forme jour, <0x30) -> A = 0x38 = opcode "JR C,d"
0F0A  LD (0F41),A            ; PATCHE L'OPCODE d'un saut conditionnel plus loin dans LA MÊME fonction
0F0D  LD (0F5A),A            ; PATCHE UN SECOND saut conditionnel identique (branche X, branche Y)
   ... (choix aléatoire axe X ou Y via registre R) ...
0F39  LD A,(00D9)            ; position Y du joueur (cache)
0F3C  CP (IX+02)              ; compare à sa propre position Y
0F41  JR NC/C,0F45  <- OPCODE AUTO-MODIFIÉ ICI (NC = fuite, C = chasse, ou l'inverse selon calibration exacte)
0F43  NEG                      ; inverse le signe du pas si besoin
0F45  LD (IX+0A),A              ; fixe le vecteur Y (±2)
0F48  LD (IX+09),00              ; vecteur X = 0 (déplacement mono-axe, comme le feu follet/boule rebondissante)
```

**Mécanisme confirmé** : la routine patche littéralement l'OPCODE d'un
saut conditionnel (`JR NC` ↔ `JR C`, un seul octet différent) selon que
le type du joueur (lu directement à `0x00D7`) est ≥0x30 (formes
nocturnes/loup-garou) ou <0x30 (formes diurnes) — inversant ainsi le
sens de la comparaison de position qui décide si l'entité se déplace
VERS ou À L'OPPOSÉ du joueur. Un tirage aléatoire (registre R) choisit
à chaque activation si le déplacement se fait sur l'axe X ou Y (mono-
axe, jamais diagonal). **Premier exemple trouvé dans ce jeu d'une IA
d'ennemi dont le comportement dépend explicitement de la forme
jour/nuit du joueur** — jusqu'ici, seul le mécanisme jour/nuit du
JOUEUR lui-même (transformation, apparence) avait été exploré ; aucune
entité ennemie n'était connue pour réagir différemment selon cette
forme.

## Point ouvert 1 — RÉSOLU : type 0x5B = cube qui descend sous le poids du joueur ("piège à pression")

Clarifié par l'utilisateur après coup : la salle 0x00 contient EN FAIT
DEUX objets distincts — un vrai objet à ramasser (voir "tasse"
ci-dessous, déposé là par l'utilisateur pendant les tests) ET, à part,
"un cube qui descend quand on va dessus" — c'est ce second objet qui
est le type 0x5B, pas "la bouteille" comme d'abord rapporté (confusion
entre les deux objets présents dans la même salle).

**`fn_sinking_cube_logic` (0x0F67), type 0x5B — confirmed (utilisateur :
comportement) + hypothesis (mécanisme exact du désassemblage).**
Désassemblage complet :

```
0F67  CALL 1D8F           ; calibration de projection (même stub que les blocs statiques)
0F6A  BIT 3,(IX+0D)         ; teste un flag "déclenché" (bit3 de state_flags_2)
0F6E  RET Z                  ; si pas déclenché -> idle, ne fait rien
0F6F  RES 3,(IX+0D)           ; consomme le flag (déclenchement UNE FOIS, pas en continu)
0F73  LD (IX+0B),00            ; met le vecteur Z à 0
0F77  RST 10                    ; applique le vecteur (donc AUCUN mouvement avec vecteur=0 !)
0F78  BIT 2,(IX+0C)              ; teste un flag de collision
0F7C  JR NZ,0F81                  ; si posé -> tail direct
0F7E  CALL 0A22                    ; arme un son dont la hauteur dépend de la position
                                    ; (même famille que fn_position_pitch_sound_arm/0x0A07)
0F81  JP 1F7B                       ; tail idle
```

**Écart entre le désassemblage et le comportement observé** : cette
routine confirme bien un mécanisme "déclenché une fois puis
consommé" (cohérent avec un piège à pression) et un son associé, mais
**ne montre PAS explicitement où `grid_z` (ix+03) diminue** — le
vecteur appliqué par RST 10 est mis à 0 juste avant. La "descente"
visuelle observée par l'utilisateur doit donc être implémentée
AILLEURS (probablement dans le système de collision générique qui
positionne le flag bit3 en premier lieu, pas encore tracé) — piste
ouverte si on veut le mécanisme complet, mais le RÔLE de l'entité est
désormais confirmé sans ambiguïté.

## Point ouvert 2 : types 0x96/0x97 — non identifiés, à chercher plus attentivement

Salle 0x01 : l'utilisateur rapporte "rien de nouveau : 4 crapauds, 4
blocs, 2 portes, 1 gardien, un fantôme". Mais 0x96 (et son jumeau
0x97, jamais rencontré dans les 128 salles) ont une logique (0x1027) et
un sprite (0x4BA0/0x4C2D) **totalement distincts** de la famille
"jambes du gardien" (0x90-0x9D, logique 0x0FD8) dans laquelle leur
valeur numérique tombe par coïncidence — **CE NE SONT PAS les jambes du
gardien** malgré l'apparence de plage contiguë. Vérifié précisément :
sur 0x90-0x9D, SEULS 0x96 et 0x97 dévient (tout le reste = jambes du
gardien confirmées). Donc quelque chose de nouveau existe bel et bien
dans cette salle, probablement discret/petit ou confondu visuellement
avec un élément déjà connu (peut-être un accessoire du gardien, une
ombre, ou un détail dans le décor). **À rechercher plus attentivement**
en salle 0x01.

## Corrections apportées à `tools/room_map/teleport.py`

- `KNOWN_TYPES` corrigé : ne plus supposer que TOUT `0x90-0x9D` est
  "guard_legs" (0x96/0x97 sont des exceptions confirmées) — labels
  précis ajoutés pour chaque type nouvellement identifié.
- Ajout des nouveaux types confirmés cette session (0x36, 0x37, 0x56,
  0x5B, 0x8D, 0x8E, 0x8F, 0x9E, 0xB6) avec labels descriptifs.

## Bonus : type 0x64 = "la tasse", 4e membre identifié de la famille "boule de cristal"

En vérifiant la salle 0x00 en direct (le joueur y était encore),
repéré un objet déposé par l'utilisateur pendant les tests (id 2,
`type=0x64`) — confirmé "la tasse". Complète la progression :
0x60=diamant, 0x64=tasse, 0x65=bouteille, 0x66=boule de cristal —
**4/7 membres de la famille identifiés**, seuls 0x61/0x62/0x63
restent inconnus.

## Prochaines étapes

1. Confirmer/clarifier le point ouvert 1 (0x5B vs vraie bouteille en
   salle 0x00).
2. Chercher 0x96/0x97 plus attentivement en salle 0x01 (point ouvert 2).
3. Désassembler plus finement 0x8D/0x8E/0x9E pour assigner précisément
   qui est le magicien mobile vs le chaudron statique vs l'animation —
   pollAndre grid_x/grid_y sur plusieurs frames en salle 0x88 pour voir
   lequel bouge en cercle.
4. Poursuivre la séquence de transformation 0xB8+ (déclenchée par
   0x8F) pour voir où elle mène (combien d'étapes, effet final).
5. Décoder le comportement exact de 0x56 (feu follet à logique
   différente de 0xB4) si intéressant.
