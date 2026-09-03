# Session 2026-08-07 (suite 15) — Fantôme identifié : déplacement aléatoire confirmé (fn_ghost_wander_logic)

Suite de `notes/2026-08-07-entity-logic-will-o-wisp.md`. Nouvelle
salle (0x8E, thème pierre). L'utilisateur décrit : "2 tables, 2
portes, 2 blocs, et un fantôme" — complète enfin la 3e catégorie de la
taxonomie des ennemis mobiles proposée en tout début de cette série de
sessions ("les fantômes, qui ont un déplacement aléatoire").

## Room 0x8E — inventaire live, corrélé à l'observation utilisateur

| Slots | Type | Rôle | Confirmation utilisateur |
|---|---|---|---|
| 4-7 | 0x02/0x03 | 2 portes | "2 portes" ✓ |
| 8,9 | 0x07 (×2) | 2 blocs | "2 blocs" ✓ EXACT |
| 24,25 | 0x54 (×2) | 2 tables (déjà connues) | "2 tables" ✓ EXACT |
| **26** | **0x52** | **LE FANTÔME** | "un fantôme" ✓ |

## Type 0x50-0x53 — `fn_ghost_wander_logic` (confirmed)

**Statut : confirmed** par désassemblage direct (0x0676 → 0x1EA1,
4 sprites distincts partageant la même logique — probablement des
variantes de couleur/apparence du même monstre, ou un cycle
d'animation à 4 phases distinctes du mécanisme habituel).

```
1EA1  CALL 1D89              ; calibration projection
1EA4  RST 10                 ; applique le déplacement courant (rst_apply_movement_vector)
1EA5  LD A,(IX+09) / OR (IX+0A) / JR Z,1EB4
                              ; si le vecteur de déplacement est NUL (arrivé à destination
                              ; ou jamais initialisé) -> va calculer un nouveau vecteur aléatoire
1EAD  LD A,(IX+0C) / AND 03 / JR Z,1ED4
                              ; sinon, si AUCUNE collision détectée sur les 2 axes -> continue
                              ; sur le même vecteur (skip le recalcul aléatoire)
                              ; (implicite : si collision détectée -> tombe dans le recalcul
                              ; aléatoire ci-dessous, PAS de simple rebond comme la balle/feu follet)

; --- RECALCUL D'UN NOUVEAU VECTEUR ALÉATOIRE ---
1EB4  LD A,(006D) / AND 03 / ADD A,04 / CALL 1F1C / LD (IX+09),A
                              ; var_pseudo_random_acc (0x006D), masqué sur 2 bits (0-3),
                              ; +4, puis converti via une table (0x1F1C) -> vecteur X
1EC1  LD A,(006A) / AND 03 / ADD A,04 / CALL 1F1C / LD (IX+0A),A
                              ; var_frame_counter (0x006A) -- PAS le même compteur que pour X --
                              ; même traitement -> vecteur Y
1ECE  CALL 1EDA               ; ajuste le signe du vecteur (probablement selon la position
                              ; actuelle par rapport aux limites de la salle, pas encore
                              ; entièrement tracé)
1ED1  CALL 0A07               ; test générique (somme grid_x+grid_y+grid_z)
1ED4  CALL 1260                ; cycle d'animation 4 phases (fn_animation_cycle_4)
1ED7  JP 1139                  ; force redessin
```

**Interprétation confirmée** : le fantôme se déplace par à-coups dans
une direction ALÉATOIRE (X depuis `var_pseudo_random_acc`, Y depuis
`var_frame_counter` — DEUX sources différentes, probablement pour
éviter une corrélation trop visible entre les deux axes), maintient
cette direction jusqu'à ce que le vecteur "s'épuise" (mécanisme de
`0x1EDA` pas encore entièrement clair — potentiellement une distance
de trajet fixe par mouvement, ou un compte à rebours) OU jusqu'à une
collision, moment auquel un NOUVEAU vecteur aléatoire est tiré.

**Différence structurelle avec les autres entités mobiles déjà
tracées** : contrairement à la balle rebondissante / au feu follet
(qui INVERSENT leur direction actuelle lors d'une collision, un
comportement prévisible) et au gardien (qui incrémente sa direction
de manière cyclique et déterministe), le fantôme **retire une
direction totalement nouvelle et imprévisible** à chaque
recalcul — c'est la vraie distinction comportementale qui justifie de
le classer dans une catégorie séparée ("déplacement aléatoire") comme
proposé initialement par l'utilisateur, même si le déclenchement du
recalcul (vecteur épuisé OU collision) réutilise la même
infrastructure `(ix+0C)`/`(ix+09..0B)` que toutes les autres entités
mobiles de cette session.

## Bonus : confirmation de `var_frame_counter` (0x006A) comme source pseudo-aléatoire secondaire

Le fait que le calcul de Y utilise `(0x006A)` (déjà connu comme
compteur de frames général, utilisé pour du throttle ailleurs dans le
jeu) plutôt que `(0x006D)` (le vrai générateur pseudo-aléatoire déjà
identifié) est un classique "détournement" d'un compteur cyclique
comme source d'aléa bon marché — cohérent avec les contraintes de
performance d'un jeu Z80 8-bit de 1984, où un vrai générateur
pseudo-aléatoire de qualité serait trop coûteux à appeler à chaque
frame pour chaque entité.

## Vérification : comportement identique jour/nuit (question de l'utilisateur)

**Statut : CONFIRMED — aucune différence de comportement selon la
forme du joueur (explorateur/jour vs loup-garou/nuit)**.

1. **Vérification par désassemblage** : recherche exhaustive de toute
   référence à `(0x1CFA)` (var_day_night_flag) ou `(0x00D7)`
   (type du joueur) dans le corps de `fn_ghost_wander_logic`
   (0x1EA1-0x1EFF, ~90 octets) — **aucun résultat**. Le code de la
   routine ne consulte JAMAIS l'état jour/nuit ni le type du joueur.
2. **Vérification empirique croisée** : poll RAM du fantôme sur ~10s
   sous forme JOUR (joueur type=0x12) — vecteur observé :
   `(3,4)→(-3,-4)→(4,4)→(-4,4)→(4,3)→(-3,3)→(4,-3)→...`, cycle de
   sprite 0x50-0x53. Puis poll RAM identique sur ~10s sous forme NUIT
   (joueur type=0x32, transformation survenue naturellement entre les
   deux mesures) — vecteur observé : `(4,-3)→(-3,3)→(-3,-3)→(4,3)→
   (-4,4)→(3,-4)→...`, MÊME cycle de sprite 0x50-0x53, MÊME cadence de
   déplacement, MÊME caractère aléatoire.

**Conclusion** : le comportement du fantôme (déplacement aléatoire,
cadence, apparence) est **strictement indépendant du cycle jour/nuit**
et de la forme du joueur — confirmé à la fois par l'absence de toute
référence dans le code désassemblé et par deux observations
empiriques directement comparables. Cohérent avec le principe déjà
établi que les entités "décor/piège/ennemi" (portes, murs, piques,
balle, feu follet, gardien) ne consultent généralement PAS l'état de
transformation du joueur dans leur logique de mouvement propre — seule
la logique DU JOUEUR lui-même (fn_player_transform_trigger, etc.)
gère cette bascule.

## Prochaines étapes

1. ~~Observer le fantôme en direct (poll RAM) pour confirmer
   visuellement le comportement erratique décrit~~ **FAIT ET
   CONFIRMÉ** : poll RAM sur ~10s, vecteur de déplacement `(ix+09,
   ix+0A)` changeant fréquemment et sans motif cyclique perceptible —
   `(3,4) → (-3,-4) → (4,4) → (-4,4) → (4,3) → (-3,3) → (4,-3) → ...` —
   contrairement au gardien (cycle déterministe +1 mod 4) ou à la
   balle/feu follet (simple inversion de signe). Confirme sans
   ambiguïté le caractère ALÉATOIRE annoncé par l'utilisateur dès la
   proposition initiale de la taxonomie.
2. Désassembler `0x1EDA` en détail (ajustement de signe du vecteur) —
   pourrait révéler une logique de limite de salle (le fantôme
   rebrousse chemin s'il approche trop d'un bord) plutôt qu'un pur
   hasard.
3. Vérifier si les 4 sprites (0x50-0x53) sont vraiment interchangeables
   (variante purement visuelle) ou encodent un état/une phase
   particulière du fantôme.

## Bilan de la taxonomie des ennemis mobiles (proposée par l'utilisateur en tout début de cette série)

Toutes les catégories proposées sont maintenant couvertes par au moins
un exemple confirmé :

1. **Mouvement régulier/mécanique** : grille mobile (0x09), balle
   rebondissante (0xB2/0xB3), feu follet (0xB4) — rebond déterministe
   par inversion de sens.
2. **Objets qui tombent puis s'arrêtent** : boules à pics au plafond
   (0x3F).
3. **Ennemis avec routine de comportement + collision** : gardien
   (0x1E, tourne après collision — mécanisme déterministe/cyclique) ;
   **fantôme (0x50-0x53, déplacement ALÉATOIRE — mécanisme
   stochastique)** — deux sous-catégories bien distinctes au sein du
   "comportement + collision", confirmées par le désassemblage.

Chantier de taxonomie initial CLOS avec un exemple concret et
désassemblé pour chaque catégorie.

## Piste ouverte signalée par l'utilisateur (2026-08-07, à traiter plus tard) : le Magicien (boss final)

L'utilisateur a signalé qu'il reste un personnage majeur non encore
rencontré cette session : **le Magicien**, décrit comme le boss final
du jeu, qui "tourne autour d'un chaudron". Salle exacte inconnue de
l'utilisateur pour l'instant — **mise en pause volontaire** de cette
piste (pas de recherche systématique à l'aveugle dans les 128 salles,
jugée non prioritaire tant qu'aucun indice de localisation n'est
disponible). À reprendre dès que l'utilisateur retrouve/atteint cette
salle en jouant normalement — probablement une bonne opportunité pour
étudier une éventuelle "logique de boss" avec un pattern d'attaque
plus élaboré que le reste du bestiaire déjà tracé (portes, murs,
piques, balle, feu follet, gardien, fantôme, table/coffre poussables).
Chercher aussi un éventuel objet "chaudron" (type d'entité dédié,
probablement statique ou avec un effet visuel spécial) au moment de la
rencontre.
