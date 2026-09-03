# Session 2026-08-07 (suite 7) — Mécanisme de mort par contact ennemi : partiellement tracé, PAS lié aux statues de crapaud

## Contexte

L'utilisateur a été tué en sautant pour sortir de la salle 0x6F,
touchant un "crapaud" au passage. Recherche du mécanisme de mort par
contact ennemi (jamais tracé jusqu'ici, cf. pistes ouvertes de
`docs/SESSION_SUMMARY.md`).

**IMPORTANT — clarifications de l'utilisateur, à ne pas oublier** :
1. **Après une mort normale en jeu, le joueur reste dans la MÊME
   salle** — pas de téléportation. Le cas de téléportation observé
   précédemment (`notes/2026-08-07-room-mapping-tool-failure.md`)
   était un artefact de la manipulation forcée pour la tentative de
   cartographie automatique (spawn au centre de la salle avec un
   ennemi déjà présent), **pas un comportement normal du jeu**.
2. **Les statues de crapaud (type 0x16) sont bien statiques,
   confirmé** — la routine de mort trouvée ci-dessous n'est PAS liée à
   ce type. Association initiale erronée de ma part, corrigée.

## Recherche du point d'entrée du game over (0x12FB)

Recherche de tous les sauts (conditionnels et inconditionnels) vers
`0x12FB` (déjà connu : `fn_game_over_or_daycycle_end`, point de sortie
commun jour-40 et room-countdown-négatif) :

```
0x1CD0  JP Z,12FB   -- déjà connu (jour 40, fn_hud_day_night_cycle)
0x29CA  JP M,12FB   -- déjà connu (room_countdown négatif, fn_init_room_entities)
0x0EBC  JP C,12FB   -- NOUVEAU, jamais exploré jusqu'ici
```

## `0x0EBC` — test de proximité mortelle (confirmed, désassemblage), type d'entité PAS ENCORE IDENTIFIÉ VISUELLEMENT

**Statut : confirmed** sur le désassemblage, **hypothesis** sur le
type d'entité réel qui l'utilise (voir mise en garde ci-dessous).

```
0EA0  LD A,(00D8)              ; position joueur, axe 1 (var probable "player_grid_x_cached")
0EA3  SUB (IX+01)               ; distance à l'entité courante (axe 1)
0EA6  JP P,0EAB / NEG           ; valeur absolue
0EAB  CP 06 / JR NC,0EBF        ; si distance axe1 >= 6, PAS de contact -> continue normalement
0EAF  LD A,(00D9)               ; position joueur, axe 2 ("player_grid_y_cached")
0EB2  SUB (IX+02)
0EB5  JP P,0EBA / NEG           ; valeur absolue
0EBA  CP 06                     ; distance axe2 < 6 ?
0EBC  JP C,12FB                 ; SI LES DEUX DISTANCES < 6 -> GAME OVER / MORT (0x12FB)
```

**Interprétation** : test de proximité 2D (pas 3D comme la collision
AABB générique de `fn_check_collisions`) entre le joueur et l'entité
qui exécute ce code, avec un seuil fixe de 6 unités sur chaque axe —
si le joueur est suffisamment proche, saut direct vers le point de
sortie commun `0x12FB`. **Nouvelles variables candidates** :
`(0x00D8)`/`(0x00D9)` semblent être une position du joueur mise en
cache (peut-être recalculée une fois par frame plutôt que relue depuis
l'entité 0 à chaque test — économie de calcul si plusieurs entités font
ce test la même frame), à confirmer.

**MISE EN GARDE IMPORTANTE (suite à la correction de l'utilisateur)** :
ce test de mort est exécuté par la routine `0x0E4A`
(`tbl_entity_logic_dispatch` → types `0x83/0x84/0x85` observés dans la
table, sprite pointeurs différents de 0x16/statue de crapaud) — **le
lien entre ce type 0x83-0x85 et un élément visuel réellement rencontré
en jeu n'a PAS été confirmé par l'utilisateur** (contrairement à ma
tentative initiale erronée de l'associer aux statues de crapaud,
explicitement infirmée). **Statut réel : routine confirmée par
désassemblage, mais SON TYPE D'ENTITÉ RÉEL RESTE À IDENTIFIER
VISUELLEMENT** — ne pas supposer qu'il s'agit forcément d'un ennemi
mobile animé tant que ce n'est pas corrélé à une observation utilisateur
en jeu. Prochaine étape naturelle : demander à l'utilisateur, la
prochaine fois qu'il rencontre un vrai ennemi mobile qui peut le tuer
par contact, de vérifier le type de l'entité correspondante dans le
dump RAM au moment du contact.

## `0x0E4A` — logique complète de l'entité concernée (désassemblage, sans confirmation visuelle)

```
0E4A  CALL 1D84                ; calibration projection
0E4D  LD A,(IX+03) / CP A4 / JR NC,0EA0   ; si grid_z >= 0xA4, saute direct au test de mort (0EA0)
                                ;   -- sinon (grid_z < 0xA4), fait un mouvement d'abord :
0E54  LD (IX+0B),03
0E58  ... calcule un quadrant (2 bits) depuis la position propre de l'entité (ix+01)/(ix+02)
0E69  LD BC,0E6F / JP 0028      ; RST 28-like dispatch sur ce quadrant (table 0x0E6F, 4 entrées)
0E7D  LD (IX+0A),H              ; stocke un vecteur de déplacement
0E80  LD A,(006D) / AND 03 / [+1 si 0] / ADD 82   ; variante pseudo-aléatoire du type (0x82-0x85)
0E8A  LD (IX+00),A
0E8D  RST 10                    ; applique le déplacement (rst_apply_movement_vector)
0E8E  JP 1F7B                   ; force redessin
```

**Interprétation (hypothesis, pas confirmée visuellement)** : si
`grid_z_or_offset < 0xA4`, l'entité se déplace selon un vecteur dérivé
de sa propre position (mouvement de patrouille simple, comme le
gardien déjà tracé) ET teste la mort du joueur si suffisamment proche ;
si `grid_z_or_offset >= 0xA4`, elle saute directement au test de mort
sans bouger (immobile au-delà d'une certaine hauteur/profondeur ?).
Type de base observé dans la table : `0x82` (logique différente,
`0x0895` — probablement l'état "au repos"/inactif) et `0x83-0x85`
(logique `0x0E4A`, mobile + dangereux).

## Statut d'ensemble

**CONFIRMED (désassemblage)** : mécanisme de mort par proximité au
joueur (`0x0EBC`, seuil 6 unités sur 2 axes), déclenché par une entité
de type `0x83-0x85` dont l'apparence réelle en jeu reste à
identifier. **CONFIRMED (utilisateur)** : après une mort normale, le
joueur reste dans la même salle (pas de téléportation) — corrige une
conclusion prématurée d'une session précédente basée sur un artefact
de manipulation forcée. **CONFIRMED (utilisateur)** : les statues de
crapaud (0x16) sont bien immobiles, PAS liées à ce mécanisme de mort.

## Prochaines étapes

1. **Identifier visuellement le vrai type d'ennemi mobile 0x83-0x85**
   la prochaine fois que l'utilisateur en rencontre un — corréler avec
   le dump RAM au moment du contact mortel pour confirmer sans
   ambiguïté (comme fait avec succès pour toutes les autres entités
   cette session).
2. Comprendre le vrai mécanisme "perte de vie SANS changement de
   salle" — voir si `0x12FB` a un chemin différent de celui du "game
   over définitif" (jour 40), ou si le comptage de vies/réapparition
   dans la même salle est géré par une autre routine non encore
   localisée (compteur de vies mentionné par l'utilisateur, "valeur
   pleine 4" — toujours pas trouvé dans le désassemblage).
3. Corriger si besoin `notes/2026-08-07-room-mapping-tool-failure.md`
   pour clarifier que la téléportation observée était bien un artefact
   de la manipulation forcée (spawn au centre avec ennemi déjà
   présent), pas un comportement de mort normal du jeu — déjà en fait
   cohérent avec ce que ce fichier documentait, mais bon de le
   recouper explicitement ici.
