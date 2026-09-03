# Session 2026-08-07 (suite 17) — Randomiseur d'objets à ramasser ÉLUCIDÉ + découverte d'un bonus de vie caché

## Contexte

Reprise du fil ouvert depuis plusieurs sessions (`docs/SESSION_SUMMARY.md`
§7 point 9) : "la position des objets à ramasser diffère à chaque
partie", jamais désassemblé, seulement supposé lié à
`var_pseudo_random_acc` (0x006D) et/ou au registre R.

Méthode : recherche statique de toute instruction référençant l'adresse
de `tbl_object_catalog` (0x417E-0x429E) dans toute la zone de code
(0x0000-0x3FFF), via un petit script Python autonome réutilisant
`z80dis.py` (le désassembleur MCP) directement contre l'API web
(`127.0.0.1:8765/api/ram`), sans passer par le serveur MCP stdio — voir
section "Outils" en fin de note.

## DÉCOUVERTE 1 : `fn_catalog_randomize_types` (0x1D27) — le vrai randomiseur

**Statut : CONFIRMED** par désassemblage + vérification croisée avec la
RAM live d'une partie en cours (jour 2, room 0x8D).

```
1D27  LD HL,417E        ; HL = tbl_object_catalog (1re entrée)
1D2A  LD A,(0068)       ; A = var_room_or_state_selector (LE MÊME octet
                         ;     que fn_init_room_selection/0x2A33 !)
1D2D  LD E,A
1D2E  LD A,R            ; A = registre R du Z80 (compteur de rafraîchissement
                         ;     mémoire, source pseudo-aléatoire classique)
1D30  ADD A,E           ; A = R + (0068)
1D31  LD E,A            ; E = graine combinée, conservée intacte
1D32  LD A,E            ; <- POINT DE RENTRÉE DE BOUCLE (pas 0x1D27 !)
1D33  AND 07            ; garde 3 bits -> 0..7
1D35  OR 60             ; -> valeur dans 0x60-0x67
1D37  LD (HL),A         ; écrit le TYPE de l'entrée courante du catalogue
1D38  INC HL
1D39  INC E             ; graine += 1 pour l'entrée suivante (rotation, pas un
                         ;     nouveau tirage R à chaque entrée)
1D3A  PUSH DE
1D3B  EX DE,HL
1D3C  LD HL,0004
1D3F  ADD HL,DE
1D40  EX DE,HL
1D41  LD BC,0004
1D44  LDIR             ; copie catalogue[+1..+4] -> catalogue[+5..+8]
1D46  EX DE,HL
1D47  PUSH HL
1D48  LD BC,429E        ; fin de tbl_object_catalog (frontière déjà connue,
                         ;     partagée avec tbl_sprite_dispatch)
1D4B  AND A
1D4C  SBC HL,BC
1D4E  POP HL
1D4F  POP DE
1D50  JR C,1D32         ; boucle sur les 32 entrées (9 octets chacune)
1D52  RET
```

**Layout réel d'une entrée de `tbl_object_catalog` (9 octets), révisé** :

| Offset | Rôle |
|---|---|
| +0 | TYPE, réécrit CHAQUE PARTIE par cette routine — valeur 0x60-0x67 |
| +1 | grid_x (template FIXE, jamais modifié par cette routine) |
| +2 | grid_y (template FIXE) |
| +3 | grid_z_or_offset (template FIXE) |
| +4 | room_number (template FIXE) |
| +5 | grid_x — copie de travail, RÉÉCRITE depuis +1 chaque partie |
| +6 | grid_y — copie de travail, depuis +2 |
| +7 | grid_z_or_offset — copie de travail, depuis +3 |
| +8 | room_number — copie de travail, depuis +4 (LU par
       `fn_instantiate_room_objects`, 0x1DFB, pour filtrer par salle) |

**Confirmation croisée avec la RAM live** (partie en cours, jour 2,
salle 0x8D, AVANT toute action de cette session) — dump complet des 32
entrées :

```
entry 0 @417E: 61 88 80 a4 6d 88 80 a4 6d
entry 1 @4187: 62 80 80 8c 27 80 80 8c 27
entry 2 @4190: 63 88 78 b0 d0 88 78 b0 d0
entry 3 @4199: 64 78 88 80 0a 78 88 80 0a
entry 4 @41A2: 65 78 88 80 ba 78 88 80 ba
entry 5 @41AB: 66 88 78 b0 42 88 78 b0 42
entry 6 @41B4: 67 88 b8 bc 8d 88 b8 bc 8d   <- room=0x8D = SALLE COURANTE
entry 7 @41BD: 60 a8 a8 80 ff a8 a8 80 ff
... (motif +1 mod 8, |0x60, exactement comme prédit par le code : la
    graine de cette partie vaut (R+0x0068) ≡ 1 (mod 8) au moment de
    l'exécution — chaque octet +1..+4 est bien identique à +5..+8, comme
    prédit par le LDIR)
```

**Chaque entrée a bien `[+5..+8] == [+1..+4]`** dans les 32 entrées —
confirme sans ambiguïté le décodage du LDIR. Le TYPE suit une rotation
`0x60 | ((graine+i) & 7)` pour i=0..31 — ici la séquence observée
(61,62,63,64,65,66,67,60,61,...) confirme graine≡1 (mod 8) pour cette
partie précise.

**Vérification supplémentaire** : l'entrée 6 (room=0x8D, type=0x67) a un
homologue RÉEL dans la table d'entités de la partie en cours :

```
entity slot 2 @ 0x010F: type=0x67 grid_x=0x88 grid_y=0xB8 grid_z=0xBC room=0x8D
```

Position, room et type correspondent EXACTEMENT à l'entrée 6 du
catalogue — confirme que `fn_instantiate_room_objects` (0x1DFB, déjà
documenté) a bien consommé cette entrée randomisée sans erreur.

## Où `fn_catalog_randomize_types` est appelée — séquence de restart complète

**Statut : CONFIRMED**, unique appelant trouvé par recherche statique
exhaustive de toute la zone de code (0x0000-0x3FFF) :

```
0574  LD HL,0068
0577  LD A,(006A)        ; var_frame_counter
057A  ADD A,(HL)          ; (0068) += frame_counter -- déjà documenté
057B  LD (HL),A           ;   (notes/2026-08-07-start-room-randomizer.md)
...
0599  CALL 2A33   ; fn_init_room_selection (SALLE de départ, (0068)&3)
059C  CALL 1D16   ; reset day/night init (voir section suivante)
059F  CALL 1D27   ; fn_catalog_randomize_types  <-- NOTRE DÉCOUVERTE
05A2  CALL 29B4   ; fn_init_room_entities
05A5  CALL 2A68   ; fn_init_room
```

**Conclusion méthodologique importante** : les DEUX randomiseurs (salle
de départ ET type des objets à ramasser) consomment le MÊME octet
`(0x0068)` (accumulé par timing humain), mais `fn_catalog_randomize_types`
y ADDITIONNE en plus le registre R du Z80 — une source d'entropie
supplémentaire nettement plus instable (change à CHAQUE cycle
d'instruction exécuté, donc très sensible au nombre exact d'instructions
exécutées entre le calcul de (0068) et l'exécution de 0x1D27, y compris
via l'appel intermédiaire à fn_init_room_selection et fn_1D16). C'est
pourquoi les deux tirages, bien que dérivés d'une seule graine commune,
ne sont PAS trivialement corrélés en pratique.

**Renommage proposé** : `var_room_or_state_selector` (0x0068) devient
`var_newgame_random_seed` — les deux usages connus sont désormais des
randomiseurs de LANCEMENT DE PARTIE (salle de départ, rotation des types
d'objets), pas un "sélecteur de salle/état" générique comme le nom
précédent le suggérait. Voir `docs/SYMBOLS.md` (révisé).

## DÉCOUVERTE 2 (bonus, non cherchée) : type 0x67 = objet "vie
supplémentaire" caché, PAS un simple objet décoratif

En creusant la sémantique des 8 types 0x60-0x67 pour caractériser
correctement la randomisation, dispatch table lookup révèle :

| Type | `tbl_entity_logic_dispatch` | `tbl_sprite_dispatch` |
|---|---|---|
| 0x60-0x66 (7 valeurs) | **0x1B2B** (`fn_crystal_ball_logic`, déjà connu) | 7 pointeurs de forme DIFFÉRENTS |
| 0x67 | **0x1A4A** (nouvelle routine, JAMAIS vue) | pointeur de forme différent des 7 autres |

Donc les 7 types 0x60-0x66 sont bien 7 variantes VISUELLES d'un même
objet "à ramasser" décoratif/interactif (poussable, son au contact —
comportement déjà décrit pour 0x66 dans
`notes/2026-08-07-entity-logic-crystal-ball.md`, maintenant confirmé
partagé par 6 sprites frères). Le 8e type, 0x67, a une logique
ENTIÈREMENT DIFFÉRENTE.

### `fn_bonus_life_pickup_logic` (0x1A4A) — désassemblage complet

**Statut : confirmed (désassemblage), hypothesis forte sur l'effet exact
"vie supplémentaire"** (pas encore observé déclenché en direct cette
session — nécessiterait de faire toucher l'objet par le joueur, ce qui
n'a pas été fait pour ne pas perturber la partie en cours de
l'utilisateur, day 2 / 4 vies).

```
1A4A  CALL 1D7F           ; sélectionne une constante de calibration (table
                          ;   d'offsets 0x1D7F-0x1DBF, déjà connue ailleurs)
1A4D  PUSH IX / POP IY    ; IY = entité courante (l'objet 0x67)
1A51  LD IX,00D7          ; IX = struct_entities_base (le JOUEUR, en dur —
                          ;   même garde IY/IX fixe que fn_door_proximity_test)
1A55  INC (IX+04)         ; élargit temporairement la bbox_w du JOUEUR
1A58  INC (IX+05)         ; élargit temporairement la bbox_h du JOUEUR
1A5B  CALL 1A19           ; fn_pickup_proximity_test (voir ci-dessous)
1A5E  DEC (IX+04)         ; restaure
1A61  DEC (IX+05)         ; restaure
1A64  PUSH IY / POP IX    ; IX = redevient l'objet 0x67
1A68  JR NC,1A90          ; si le joueur n'est PAS assez proche -> idle
                          ; (jp 1D74, tail de calibration partagé)
      ; --- si contact confirmé ---
1A6A  SET 3,(IX+00)       ; positionne le bit 3 du type de l'objet
1A6E  CALL 1D84           ; encore une constante de calibration
1A71  LD L,(IX+10) / LD H,(IX+11)   ; HL = pointeur stocké dans l'entité
1A77  LD (HL),00          ; efface un flag/état pointé indirectement
1A79  LD HL,0080
1A7C  INC (HL)            ; *** var_life_counter (0x0080) += 1 ***
1A7D  XOR A
1A7E  LD (0086),A         ; remet à 0 var_room_reset_flag_5
1A81  LD HL,0040
1A84  CALL 0A14           ; arme le moteur son avec la séquence 0x0040
                          ;   (NOUVELLE séquence, jamais rencontrée —
                          ;   confirmé même mécanisme que
                          ;   fn_sound_arm_channel_0/2, tail commun 0x08B9)
1A87  CALL 155E           ; affiche un MESSAGE via le moteur de texte du
                          ;   MENU (fn_menu_draw_string/0x170D) — confirmé :
                          ;   patch (0x008C)=0x3294 (tbl_menu_font), même
                          ;   séquence d'instructions que le menu principal
1A8A  LD BC,2720          ; buf_visible_entities
1A8D  CALL 1CDF           ; force un blit immédiat (CALL 3195/3186, JP 2EC0
                          ;   = fn_blit_copy_line) — rafraîchit une petite
                          ;   zone d'écran tout de suite (probablement là où
                          ;   le message vient d'être dessiné)
1A90  JP 1D74             ; tail commun (idle)
```

`fn_pickup_proximity_test` (0x1A19) : test AABB 3 axes classique (mêmes
primitives 0x254F/0x2564/0x2579 que le moteur de collision générique),
avec une tolérance Z ajustée de ±4 autour de l'appel — retourne carry si
contact.

### CONFIRMATION EMPIRIQUE (utilisateur, même session, salle 0x8D)

Sans faire redémarrer la partie ni reprendre le contrôle du personnage :
**l'utilisateur a lui-même touché l'objet 0x67 en jeu**, dans la salle où
la partie se trouvait déjà (0x8D), et confirme :

- C'est effectivement **une "vie"** qui se ramasse.
- **Elle ne reste PAS dans l'inventaire d'objets** (contrairement aux
  objets de la famille "boule de cristal" 0x60-0x66, dont
  `notes/2026-08-07-entity-logic-crystal-ball.md` avait déjà noté qu'ils
  passent dans l'inventaire) — **correspond exactement** au
  désassemblage : `fn_bonus_life_pickup_logic` (0x1A4A) n'écrit JAMAIS
  `var_object_notify_flag` (0x007A) ni `tbl_hud_slot_icons` (0x00AB), à
  la différence du chemin normal de ramassage d'objet.

**`fn_bonus_life_pickup_logic` (0x1A4A) passe donc de "hypothesis forte"
à CONFIRMED EMPIRIQUEMENT** pour son effet observable (gain d'une vie,
pas d'entrée en inventaire). Seuls le contenu exact du message HUD et le
détail de la séquence sonore 0x0040 restent non décodés (le fait qu'un
son et un message s'affichent bien n'a pas été vérifié séparément par
l'utilisateur, seule la mécanique globale "vie gagnée, pas gardée" est
confirmée).

Un dump en lecture seule de la table d'entités (0x00D7, 128 slots) au
moment de cette confirmation montre le contenu complet de la salle 0x8D
(36 entités actives, id 0-35) et recoupe **exactement** la description
de l'utilisateur ("des blocs, des pics, 2 portes, une boule mobile, les
2 murs, une vie") :

| Description utilisateur | ID(s) | Type(s) | Statut |
|---|---|---|---|
| une vie | id 2 | 0x67 | notre découverte, confirmée ci-dessus |
| 2 portes | id 4-7 (2 paires) | 0x02/0x03 | déjà confirmé (fn_door_post_type_A/B) |
| des blocs | id 21-33 (13x) | **0x07** (NOUVEAU) | voir ci-dessous |
| les 2 murs | id 8-20 (13x, 5 sous-types) | 0x0A-0x0F | hypothesis renforcée (voir ci-dessous) |
| des pics | id 34 | 0x17 | déjà confirmé (fn_spike_logic) |
| une boule mobile | id 35 | 0xB2 | déjà confirmé (fn_bouncing_ball_logic) |

**Type 0x07 (NOUVEAU, "blocs")** : `tbl_entity_logic_dispatch[0x07]` =
**0x1D8F** — EXACTEMENT la même routine que le type 0x06 déjà documenté
("wood block (decor)", calibration de projection seule, purement
statique). Donc 0x07 est un variant visuel frère de 0x06, même famille
"bloc décoratif immobile", juste un sprite différent
(`tbl_sprite_dispatch[0x07]` distinct). Confirmé visuellement par
l'utilisateur comme "des blocs" dans cette salle.

**Types 0x0A-0x0F ("murs")** : dispatch logique = 0x1D94/0x1D99/0x1D9E
selon le sous-type — CES TROIS ROUTINES, comme 0x1D8F pour 0x06/0x07,
ne font QUE charger une constante de calibration fixe puis `JP 0x1D8C`
(tail commun) → `JP 0x1FEB` : même motif "décor statique, aucun
comportement". Renforce (sans encore prouver au sens strict "structure
figée de mur") l'hypothèse déjà posée dans `SYMBOLS.md` — confirmée
visuellement par l'utilisateur comme correspondant aux "2 murs" de cette
salle.

### Interprétation

**C'est un mécanisme de "vie bonus cachée" jamais documenté** : parmi les
8 variantes de type tirées par `fn_catalog_randomize_types`, EXACTEMENT
1/8 (donc 4 des 32 emplacements fixes du catalogue, sur une partie
donnée) sera un objet spécial qui, une fois touché par le joueur,
incrémente le compteur de vies (`var_life_counter`, déjà confirmé ailleurs
comme le compteur de vies restantes, plein = 4), joue un son dédié, et
affiche un message textuel réutilisant le moteur de rendu de texte du
menu.

**Ceci résout ET reformule la question initiale** : ce n'est pas
vraiment "la position des objets à ramasser" qui change — les 32
positions/salles du catalogue sont ENTIÈREMENT FIXES (template
+1..+4 jamais modifié). Ce qui change à chaque partie, c'est **QUEL type
d'objet occupe QUEL emplacement fixe** (rotation par graine
`R + (0x0068)`), incluant, crucialement, **QUEL(S) emplacement(s) sur les
32 est/sont le bonus de vie caché** (4 des 32, à des positions qui
tournent d'une partie à l'autre). Vu du joueur, qui ne peut pas
distinguer un emplacement "normal" d'un emplacement "à moitié
vie-bonus" avant de s'en approcher, cela correspond exactement à
l'observation empirique originale ("la position des objets diffère à
chaque partie").

## Prochaines étapes

1. ~~**Confirmer en direct** l'effet exact de type 0x67~~ — **FAIT**,
   voir section "CONFIRMATION EMPIRIQUE" ci-dessus : l'utilisateur a
   ramassé l'objet dans sa partie en cours (salle 0x8D), confirme "une
   vie, mais qui ne reste pas dans l'inventaire". Reste ouvert : le
   contenu exact du message HUD et le détail sonore (points 2/3
   ci-dessous), non vérifiés séparément.
2. Décoder le contenu exact du message texte affiché par `CALL 155E`
   (quelle chaîne ? pointeur source non encore tracé).
3. Identifier la NOUVELLE séquence sonore 0x0040 (comparer au format déjà
   décodé pour 0x0A6E dans `notes/2026-08-07-transformation-sound.md`).
4. Vérifier s'il existe un plafond au compteur de vies (`var_life_counter`
   peut-il dépasser 4 ?) — pourrait affecter le HUD ou l'affichage du
   score.
5. Confirmer si un JOUR (ou une salle) donné peut avoir plus d'un
   candidat 0x67 simultanément (probable si deux entrées du catalogue de
   la MÊME salle tombent sur la phase 0x67 de la rotation — improbable
   arithmétiquement pour la plupart des graines mais pas structurellement
   impossible, à vérifier avec plusieurs graines différentes si on
   redémarre une partie un jour).

## Outils / méthode

- **Script autonome de désassemblage statique par recherche d'opérande**
  (nouveau, `disasm.py` dans le scratchpad de session) : réutilise
  `z80dis.py` (le même module que le serveur MCP) directement contre
  l'API web REST de l'émulateur (`127.0.0.1:8765/api/ram`), sans passer
  par le protocole stdio MCP — plus simple à driver depuis un script
  Python autonome. A permis une recherche EXHAUSTIVE de tout opérande
  16 bits dans la plage 0x0000-0x3FFF référençant `tbl_object_catalog`
  (0x417E-0x429E), révélant l'unique routine qui y ÉCRIT (0x1D27) en
  quelques secondes — bien plus rapide qu'une exploration par
  breakpoint/history pour ce genre de question ("qui écrit dans cette
  table ?").
- **Vérification croisée disassemblage statique <-> RAM live** : la
  partie de l'utilisateur était déjà en cours (jour 2, salle 0x8D) au
  début de cette session — dump non-invasif (lecture seule) de la table
  d'entités en cours a permis de confirmer immédiatement, SANS toucher à
  la partie, que l'entrée de catalogue décodée statiquement correspond
  exactement à l'entité réellement instanciée dans la salle courante.
  Aucune pause/reset/touche n'a été nécessaire pour cette confirmation.
- **Prudence délibérée** : aucune tentative de faire toucher l'objet
  0x67 par le joueur (aurait nécessité de reprendre le contrôle du
  personnage ou de redémarrer la partie) — la partie en cours appartient
  à l'utilisateur, effet non trivialement réversible (vies/progression),
  donc laissé en hypothèse forte plutôt que confirmé empiriquement.
