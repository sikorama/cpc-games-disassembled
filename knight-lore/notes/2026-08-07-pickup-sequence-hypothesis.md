# Session 2026-08-07 (suite 19) — Piste ouverte : puzzle de collecte ordonnée (types 0x68-0x6E), JAMAIS rencontrée en jeu

## Contexte

En creusant l'identification du "diamant" (type 0x60, voir
`notes/2026-08-07-room-bb-diamond-and-pushable-block.md`), désassemblage
de la suite de `fn_crystal_ball_logic` (0x1B2B) au-delà de sa partie
"poussée" déjà documentée. Repéré un bloc de code (0x1AE9-0x1B14)
implémentant ce qui ressemble à un puzzle de collecte dans un ORDRE
PRÉCIS. **Hypothèse initiale erronée corrigée dans cette note** : ce
mécanisme n'est PAS déclenché par la famille "diamant/boule de cristal"
(0x60-0x67) comme supposé au premier abord — voir section "Correction"
ci-dessous. Statut global : **hypothesis (désassemblage uniquement),
famille de types concernée (0x68-0x6E) jamais rencontrée en jeu**.

## Test empirique NÉGATIF (utilisateur) — a évité une fausse piste

L'utilisateur a posé puis repris l'objet "diamant" (type 0x60) dans sa
partie en cours, avec des breakpoints armés sur 0x1AE9 et 0x1B02.
**Aucun des deux breakpoints ne s'est déclenché.** Ce résultat négatif a
permis de détecter que l'hypothèse initiale (attribuant ce code à
`fn_crystal_ball_logic`/famille 0x60-0x67) était fausse — voir
méthodologie section 7 ("vérifier par le calcul/test, pas la lecture
seule").

## Ce qui est confirmé par désassemblage (mais pas encore en direct)

**Le vrai point d'entrée est 0x1A93, dispatché par les types 0x68-0x6E
(7 valeurs), PAS par 0x60-0x67** — confirmé en scannant la table
`tbl_entity_logic_dispatch` (0x0676) entière pour tout pointeur dans la
plage 0x1A90-0x1B15 :

```
type 0x68 -> logic 0x1A93   type 0x69 -> logic 0x1A93
type 0x6A -> logic 0x1A93   type 0x6B -> logic 0x1A93
type 0x6C -> logic 0x1A93   type 0x6D -> logic 0x1A93
type 0x6E -> logic 0x1A93
type 0xC4 -> logic 0x1B08   type 0xC8 -> logic 0x1B08   (variante/sous-état ?)
```

**Ces 7 types partagent EXACTEMENT les mêmes 7 sprites que la famille
"diamant" (0x60-0x66), décalés de +8** :

```
0x68 -> sprite 0x4687  (= sprite de 0x60, "diamant")
0x69 -> sprite 0x4600  (= sprite de 0x61)
0x6A -> sprite 0x446B  (= sprite de 0x62)
0x6B -> sprite 0x4702  (= sprite de 0x63)
0x6C -> sprite 0x4795  (= sprite de 0x64)
0x6D -> sprite 0x456D  (= sprite de 0x65)
0x6E -> sprite 0x44EC  (= sprite de 0x66, "boule de cristal")
```

Donc 0x68-0x6E sont VISUELLEMENT IDENTIQUES à 0x60-0x66 — probablement
les mêmes objets dans un état/contexte différent, mais **le mécanisme
exact qui ferait passer un objet de 0x60-0x66 vers 0x68-0x6E n'est PAS
celui auquel on a pensé** (voir section suivante).

### Désassemblage de 0x1A93-0x1B14

```
1A93  CALL 1D84            ; calibration de projection
1A96..1AB8  calcule un pas unitaire (+1/0/-1) vers la position 0x80
            pour grid_x PUIS grid_y, écrit dans (ix+09)/(ix+0A)
            ("homing" vers le point 0x80,0x80 — pas encore confirmé
            si c'est le centre de la salle ou autre chose)
1AB8..1AD1  calcule un pas pour grid_z (borne 0x98), écrit (ix+0B)
1AD1  RST 10                ; applique le vecteur (déplace l'entité)
1AD2  CALL 0A07 / JP 1F7B    ; son positionnel + tail partagé (MÊME
                             ;   tail que fn_crystal_ball_logic après
                             ;   une poussée — explique pourquoi on
                             ;   avait initialement cru les deux
                             ;   fonctions liées : elles partagent
                             ;   juste ce fragment de code, pas plus)
1AD8  LD A,80 / CP (IX+03)   ; compare grid_z à 0x80 (sol)
1ADD  JR NC,1AE5             ; si grid_z <= 0x80 (posé au sol) -> 1AE5
1ADF  SET 1,(IX+07) / JR 1AD1  ; sinon (encore en l'air) -> boucle
1AE5  LD (IX+03),80          ; pose exactement au sol
1AE9  CALL 1B14              ; lit tbl_pickup_sequence_order[(0081)]
1AEC  LD A,(IX+00) / AND 07  ; type&7 de CET objet
1AF1  CP (HL)                 ; compare à la valeur attendue
1AF2  JR NZ,1B05               ; si ça ne correspond pas -> cleanup seul
1AF4  INC (0081)                ; **compteur de séquence += 1**
1AF8  CALL 1B43                ; joue un jingle (boucle PSG bloquante)
1AFB  CP 0E (=14)               ; 14 étapes au total
1B02  CALL 1B76 (si ==14)        ; déclenche la transformation finale
1B05  cleanup (efface un flag indirect), JP 1239 (idle générique)
```

`tbl_pickup_sequence_order` (0x1B1D, 14 octets exactement, `CP 0E`
confirme la longueur) :

```
01 02 04 00 01 02 03 04 05 06 03 05 00 06
```

Chacune des 7 valeurs (0-6, correspondant à `type&7` pour 0x68-0x6E)
apparaît EXACTEMENT deux fois — motif très probablement volontaire
("récolter chaque trésor deux fois, dans cet ordre précis").
`var_pickup_sequence_counter` (0x0081) est remis à zéro au lancement
d'une NOUVELLE PARTIE (dans la zone remplie par le fill générique
0x0068/0x0070→0x0537 de la séquence de restart) mais PAS à chaque
changement de salle — donc, si le mécanisme est bien ce qu'on pense,
c'est un puzzle qui s'étend sur TOUTE la partie, pas sur une seule
salle.

`fn_pickup_sequence_complete_transform` (0x1B76, si les 14 étapes sont
franchies dans l'ordre) : parcourt les slots d'entité 3 à 39 (jusqu'à
l'adresse 0x0537 — **confirme au passage que la table d'entités
"active" par salle est bornée à 40 slots, PAS 128** comme le suggérait
la formule d'indexation générale ×28, cohérent avec buf_visible_entities
40 max), force les slots 3-13 à `type=0x01`, puis convertit tout slot de
type `0x07` (bloc statique) en `type=0x83` (`fn_hostile_patrol_logic`,
ennemi hostile jamais identifié visuellement).

## Ce qui reste NON confirmé / inconnu

1. **Comment un objet de type 0x68-0x6E est-il créé ?** — PAS via
   `fn_catalog_randomize_types` (qui ne produit que 0x60-0x67). PAS via
   `fn_collision_effect` (qui transforme 0x60-0x66 en 0xBB, pas +8).
   Aucune instruction de code ne charge explicitement une constante
   0x68-0x6E ailleurs (les 3 correspondances trouvées par recherche
   statique tombent dans une zone de DONNÉES, tbl_room_master_index —
   donc probablement de simples octets de table mal interprétés comme
   instructions, pas une preuve de création dynamique). Hypothèse la
   plus probable : ces types sont placés directement en DONNÉES FIGÉES
   dans certaines salles spécifiques (comme les portes/murs/piques),
   pas générés par du code — reste à vérifier en explorant le jeu.
2. **Ni l'utilisateur ni moi n'avons jamais rencontré ces 7 types en
   jeu** — aucune salle visitée jusqu'ici n'en contenait. Sans exemple
   réel, impossible de confirmer le rôle exact (récipient/chaudron ?
   puzzle de combinaison ? autre chose ?) ni de tester les breakpoints
   correctement armés cette fois (0x1AE9/0x1AF4/0x1B02, sur le VRAI
   point d'entrée 0x1A93 si besoin).
3. Rôle de 0xC4/0xC8 (dispatch -> 0x1B08, une variante/sous-état proche)
   — pas examiné.

## Prochaines étapes

1. **Explorer le jeu normalement** jusqu'à tomber sur une salle
   contenant un type 0x68-0x6E (aucun raccourci trouvé pour la
   prédire) — à ce moment-là, re-armer des breakpoints sur 0x1A93 (vrai
   point d'entrée), 0x1AE9, 0x1AF4 (compteur), 0x1B02 (transformation
   finale) pour confirmer le mécanisme en direct.
2. En attendant, ne pas présenter ce mécanisme comme confirmé — statut
   strictement "hypothesis (désassemblage seul)".
