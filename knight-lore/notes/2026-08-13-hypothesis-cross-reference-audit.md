# Audit de recoupement des hypothèses (2026-08-13)

Contexte : trop d'entrées `hypothesis` pour les revérifier une par une par
breakpoint dans un temps raisonnable. Méthode utilisée (formalisée dans
`docs/METHODOLOGY.md` section 12) : recoupement pur (texte déjà écrit dans
`docs/SYMBOLS.md`) + désassemblage statique hors-ligne via
`extra/dump_ref.bin` (dump RAM complet #0000-#8FFF pris après boot, déjà
dans le dépôt) et `tools/gen_asm.py`/`tools/disasm.py`, qui basculent
désormais automatiquement sur ce dump quand l'émulateur n'est pas
accessible (`tools/ram_source.py`, comportement par défaut depuis cette
session). Validé par réassemblage réel (`rasm.exe`) + comparaison
octet-à-octet contre `extra/dump_ref.bin` sur toutes les plages modifiées :
0 écart.

## Fait cette session

**Désassemblage direct hors-ligne (nouvelle preuve) :**
- `fn_init_room` (#2A68) — corps principal désassemblé (#2A68-#2A99),
  hypothesis → confirmed. Suite (#2A9A-#2B8D, table décor/HUD) reste ouverte.
- `fn_load_room_data` (#2C3A) — intégralité #2C3A-#2D5D désassemblée,
  hypothesis → confirmed.
- `fn_clear_intermediate_buffer` (#2DB7, nouvelle) — efface le buffer
  0x9000-0xBFFF, appelée par `fn_init_room`.
- `fn_collision_effect` (#2876) — intégralité #2876-#28AE, hypothesis →
  confirmed. Révèle un détail manqué par l'ancienne hypothèse : teste LES
  DEUX côtés de la paire (ix ET iy), pas un seul.
- `fn_wait_keyboard_sync` (#2D6D) — intégralité #2D6D-#2D90, hypothesis →
  confirmed (mécanisme). Rôle exact (quelle touche, pourquoi par frame)
  reste ouvert.
- **Bonus** : octet `#2AB5` corrigé (`CB,C6`=`SET 0,(HL)`, pas `CB,E6`
  comme transcrit précédemment dans `asm/code/room_init_and_nav.asm`).

**Upgrades de statut par pur recoupement (zéro octet nouveau) :**
- `fn_instantiate_room_objects` (#1DFB) — doublon d'entrée dans
  `docs/SYMBOLS.md` resté à `hypothesis` alors que `asm/symbols.json` et
  une autre entrée du même fichier l'avaient déjà confirmée.
- `var_interrupt_sync_flag` (#006F) — déjà entièrement décrite par
  `fn_arm_interrupt_flag`/`fn_disarm_interrupt_flag`/`fn_check_interrupt_flag`
  (résolues 2026-08-10), juste jamais remonté sur sa propre ligne.
- `room_number` (+0x08, struct entité) — déjà décrit par
  `fn_player_door_transition` (encodage nibble bas=X/haut=Y, confirmé
  empiriquement), même désynchronisation.

## Deuxième passe (même session) : outillage rendu permanent + fn_player_logic

Suite à cette première passe, le repli hors-ligne a été rendu **permanent
et par défaut** : `tools/ram_source.py` centralise la résolution de source
RAM (émulateur live si accessible, sinon `extra/dump_ref.bin`
automatiquement) pour `tools/disasm.py` ET `tools/gen_asm.py` — plus besoin
d'un script séparé (`gen_asm_offline.py`, retiré). `tools/export_ram_dump.py`
permet de régénérer le dump ponctuellement si besoin. C'est la même
pratique que le travail manuel "à la main" des tout premiers jours du
projet (extraire un dump une fois, travailler dessus), désormais outillée.

Puis attaque de **`fn_player_logic`** (Tier 1 #1 ci-dessus), même méthode.
Désassemblage direct hors-ligne intégral de #20CB à #2321 (la plus grosse
zone `hypothesis` contiguë restante). Résultats :

- `fn_player_logic`, `fn_player_in_view_bounds`, `fn_player_read_input` :
  hypothesis → confirmed.
- **6 routines/tables nouvelles, jamais nommées avant** :
  `fn_player_logic_night` (0x20D0, second point d'entrée de
  `tbl_entity_logic_dispatch` pour les types nuit/loup-garou 0x32/0x34,
  vérifié par lecture directe de la table — même corps partagé que
  `fn_player_logic`), `fn_player_jump_trigger` (0x21F0, mécanisme de SAUT
  jamais identifié jusqu'ici), `fn_player_walk_animation_cycle` (0x2214,
  cycle d'animation de marche à 5 phases dans les bits bas du type — piste
  sérieuse pour résoudre les plages encore hypothesis 0x20-0x2F/0x40-0x4F,
  reste à confirmer empiriquement en dumpant le type pendant un
  déplacement), `fn_player_gravity_and_door_dispatch` (0x2253, orchestre
  gravité+porte — **confirme par désassemblage direct le site d'appel
  #228E de `fn_player_door_transition`**, jusqu'ici seulement documenté en
  prose), `fn_resolve_forward_vector` (0x22AD) et
  `tbl_player_forward_vector_dispatch` (0x22E4, même motif que
  `fn_resolve_patrol_vector` #12A5 mais amplitude 3 pour le joueur).
- Confirme numériquement le "piège potentiel" déjà noté pour
  `rst_apply_movement_vector` (double lecture de `(ix+0x0B)`, une fois
  décrémentée en prélude de RST 10, une fois relue comme compteur
  saut/chute par le joueur).
- Champs de structure `+0x09/+0x0A/+0x0B` résolus (étaient `unknown`
  depuis le début du projet), `+0x0E/+0x0F` et variable `(0087)`
  découverts.
- Résidus laissés ouverts (défb non désassemblés, faible priorité) :
  `#2246-#2252` (cas "joueur immobile" de `fn_player_walk_animation_cycle`,
  compris manuellement mais pas mécaniquement regénéré) et `#230C-#2321`
  (petit helper non identifié juste avant `fn_player_door_transition`,
  probablement lié à une convergence de hauteur vers le sol — piste
  ouverte mineure).
- Validé par réassemblage réel + comparaison octet-à-octet contre
  `extra/dump_ref.bin` sur toute la plage #20CB-#2321 : 0 écart.

## Hypothèses restantes, hiérarchisées

Classement par effet de levier (combien d'autres entrées seraient
éclaircies) et par voie de résolution la moins chère.

### Tier 1 — probablement résolubles hors-ligne (désassemblage statique seul, à tenter avant tout test live)

1. ~~**`fn_player_logic` (#20CB)** + **`fn_player_read_input` (#2147)** +
   **`fn_player_in_view_bounds` (#2122)**~~ — **FAIT** (voir section
   "Deuxième passe" ci-dessus). Résidus mineurs restants : `#2246-#2252`
   et `#230C-#2321`.
2. ~~**`bbox_w`/`bbox_h`/`bbox_d` (+04/+05/+06)**~~ — **FAIT** (voir
   section "Troisième passe" ci-dessus, via `fn_room_transition_edge_*` +
   `fn_check_collisions` déjà confirmée).
3. ~~**`pending_grid_x`/`pending_grid_y` (+1D/+1E)**, **`room_transition_extra`
   (+1F)**, **`busy_flag` (+23)**~~ — **FAIT** (voir section "Troisième
   passe"), avec une correction importante : `room_transition_extra` a vu
   son ancienne hypothèse ("nouveau numéro de room+0x0C") **invalidée** par
   le désassemblage direct — la source lue est une constante d'élévation
   0x80, pas un numéro de room. Nouvelle hypothèse (révisée, pas confirmée)
   à vérifier empiriquement.
4. **`var_room_reset_flag_1`/`var_room_reset_flag_2` (#0075/#0076)** —
   maintenant confirmés comme remis à 0 par `fn_init_room` (session
   précédente), mais qui les LIT reste à chercher (grep statique sur
   `#0075`/`#0076` dans le reste du binaire désassemblé).
5. **`room_transition_extra` (+0x1F), nouvelle hypothèse** — vérifier
   empiriquement (dump RAM live requis, PAS possible hors-ligne puisqu'il
   s'agit de confirmer une VALEUR RUNTIME, pas juste du désassemblage) que
   `(ix+0x1F)` vaut bien `0x8C` après un franchissement de bord réel (pas
   par une porte — un bord de salle, cf. `fn_room_transition`, mécanisme
   DISTINCT de `fn_player_door_transition`). Vérifier aussi, en cherchant
   qui LIT ce champ ensuite, à quoi il sert réellement (piste : référence
   d'élévation au moment du repositionnement).
6. **Question ouverte plus large** : `fn_room_transition` (sortie par un
   bord de coordonnées locales) et `fn_player_door_transition` (franchissement
   de porte, recalcul du `room_number` par nibble) semblent être DEUX
   mécanismes distincts de changement de salle/position, pas le même
   chemin décrit sous deux angles. Clarifier lequel est réellement
   emprunté quand (portes vs bords de salle sans porte explicite ? entités
   non-joueur qui sortent du cadre ?) — nécessite probablement un test
   comportemental (dump de callers réels via breakpoint+historique, pas
   faisable hors-ligne).

### Tier 2 — cluster à fort effet de levier, un seul test comportemental résout 3 entrées

5. **`fn_hud_slot_notification` (#1802)** + **`var_object_notify_flag`
   (#007A)** + **`tbl_hud_slot_icons` (#00AB)** — ramasser un objet en jeu
   et dumper ces 3 adresses avant/après confirme les trois en un coup
   (protocole déjà connu, section 7bis/8 de `docs/METHODOLOGY.md`). **PAS
   ENCORE FAIT** (nécessite d'être proche d'un objet ramassable en jeu).

### Tier 3 — variables à fort nombre de référents confirmés, test live bon marché

6. ~~**`var_frame_counter` (#006A)**~~ — **FAIT** (voir "Quatrième passe"
   ci-dessous) : confirmé 16 bits (pas 8), vérifié en direct.
7. ~~**`var_pseudo_random_acc` (#006D)**~~ — **FAIT** (voir "Quatrième
   passe" ci-dessous) : formule complète à 2 mélanges/frame, vérifiée
   exactement en direct par breakpoint+step.

## Quatrième passe (même session) : premiers tests LIVE avec émulateur

Contexte : l'émulateur AMSpiriT-Lite a été relancé par l'utilisateur avec
`--web-server` (le check initial montrait la ROM firmware bankée, PAS le
jeu — reconfirmé après chargement : `rom_bank=255` puis `ram_bank=0` une
fois Knight Lore réellement en cours). **Pas d'outils MCP chargés dans
cette session** — accès direct à l'API HTTP `127.0.0.1:8765` via `curl`
(les mêmes endpoints que `server.py` expose comme outils MCP :
`/api/state`, `/api/ram`, `/api/step`, `/api/z80_bp`, `/api/config`).
Piège rencontré et documenté : **le single-step interfère avec
l'interruption IM1** (son, ~300Hz) — plusieurs `/api/step` consécutifs
peuvent être "avalés" par l'exécution du handler d'interruption entre deux
instructions du chemin qu'on veut suivre, donnant l'impression que rien
n'avance. **Solution** : poser un breakpoint juste APRÈS la séquence à
vérifier et relancer l'exécution (`POST /api/config {"paused":false}`)
plutôt que d'essayer de step instruction par instruction à travers une
zone où les interruptions sont actives.

En désassemblant hors-ligne la fin de `fn_main_loop` restée en `defb`
(#05F7-#0675, jamais explorée), découverte des formules exactes de
`var_frame_counter` (16 bits) et `var_pseudo_random_acc` (2 mélanges par
frame) — vérifiées ensuite EN DIRECT :
- Mélange par-entité (#05DB, `acc += R`) : `A=0x33, C=0x69` capturés au
  breakpoint `#05E1`, valeur observée après step = `0x9C` = `0x33+0x69`
  exact.
- Mélange par-frame (#05FE-0604, `acc += MEM[frame_counter] += low
  += high`) : `acc=0x59, HL=frame_counter=0x04C5, MEM[HL]=0x00` capturés
  au breakpoint `#05FE`, valeur observée après continuation jusqu'à `#0607`
  = `0x22` = `(0x59+0x00+0xC5+0x04)&0xFF` exact.

5 nouvelles routines découvertes (`fn_frame_tick_and_mix`,
`fn_arm_room_transition_flag_and_wait`, `fn_render_workload_pacing_delay` —
mécanisme de calage de frame jamais documenté avant, dépendant de la
charge de rendu de la frame précédente, `fn_render_disabled_one_time_setup`,
`fn_frame_end_player_alive_check` — LE vrai point de boucle par frame,
distinct de la boucle par entité, `fn_reset_all_entity_processing_flag`).
`var_entity_update_counter` confirmé (désassemblage déjà présent, juste
jamais remonté), `var_room_transition_flag` précisé (posé inconditionnellement
chaque frame, pas seulement lors d'une transition). Validé par réassemblage
réel + comparaison octet-à-octet : 0 écart.

**Reste à faire en session live** (accès émulateur toujours nécessaire) :
- Tier 2 #5 (cluster HUD notification) — nécessite d'être en jeu près d'un
  objet ramassable.
- Item #5 ci-dessus (`room_transition_extra` = 0x8C ?) — nécessite de
  déclencher un franchissement de BORD de salle (pas une porte).
- Item #6 ci-dessus (relation `fn_room_transition` vs
  `fn_player_door_transition`) — nécessite breakpoint+historique sur les
  deux routines pour voir laquelle est réellement empruntée et quand.

### Tier 4 — pistes mortes ou secondaires (rôle exact incertain même après désassemblage, priorité basse)

8. `fn_treasure_settle_and_sequence_check` (#1A93) / `tbl_pickup_sequence_order`
   (#1B1D) / `fn_pickup_sequence_complete_transform` (#1B76) — types
   0x68-0x6E jamais rencontrés en jeu ; le mécanisme de CRÉATION de ces
   types reste non localisé (piste déjà documentée comme bloquée).
9. `var_entity_update_counter` (#0082), `var_special_input_mode_1/2`
   (#0089/#008A), `var_pickup_sequence_counter` (#0081),
   `tbl_joystick_mask_extra` (#2989) — référent unique ou usage mineur,
   faible effet de levier.

## Outillage laissé en place

Le repli hors-ligne est désormais le comportement PAR DÉFAUT de
`tools/disasm.py` et `tools/gen_asm.py` (via `tools/ram_source.py`) : ils
utilisent l'émulateur live si accessible, sinon `extra/dump_ref.bin`
automatiquement, sans flag à passer. `tools/export_ram_dump.py` régénère ce
dump (ponctuellement, émulateur requis pour cette seule étape) s'il est
absent ou trop périmé pour une zone donnée. Utilisable pour toute nouvelle
tentative sur les items Tier 1 ci-dessus sans avoir besoin d'AMSpiriT-Lite
lancé. Rappel de la limite du dump : figé, invalide pour tout ce qui
dépend d'un état runtime (RAM haute mutable, VRAM, I/O).

## Cinquième passe (même session) : découverte du mécanisme "utiliser l'objet tenu"

En posant un breakpoint sur `fn_hud_slot_notification` (#1802) pour le
Tier 2 #5 (cluster HUD), l'utilisateur a d'abord déclenché une action
différente de ce qui était visé : la touche "utiliser l'objet tenu" (pour
booster sa hauteur de saut et franchir un obstacle), PAS un ramassage.
Piège méthodologique noté : un breakpoint posé sur l'ADRESSE D'ENTRÉE
d'une routine appelée chaque frame (ici, `fn_hud_slot_notification` est
appelée par `fn_render_entities` à CHAQUE frame) se déclenche en boucle
même quand la condition qu'on veut observer (le flag non-nul) n'est pas
remplie — il faut breakpointer APRÈS le test de garde (ici `#1807`, juste
après le `RET Z`), pas sur l'entrée de la routine.

Ce qui semblait être une simple routine de notification s'est révélé être
l'entrée vers un sous-système entier jamais documenté : `fn_player_use_
held_object` (#18AA — RÉSOUT le "#18AA non identifiée" de `fn_player_
logic`), CONFIRMÉ EMPIRIQUEMENT par l'utilisateur en temps réel. Désassemblé
et confirmé : `fn_hud_slot_notification` (rôle révisé : redessin d'icônes
d'inventaire, pas "objet obtenu"), `fn_read_use_object_button` (#1897),
`fn_player_use_held_object` (squelette principal, #18AA-#1947). Révèle
`tbl_hud_slot_icons` comme 3 enregistrements de 4 octets (pas 3 octets),
et confirme un consommateur de `var_input_result`. Validé par réassemblage
réel : les seuls octets différant entre un `.sna` frais et
`extra/dump_ref.bin` dans toute la plage #1802-#1947 sont exactement la
zone scratch `#1877-#1896` que la routine utilise comme RAM de travail —
cohérent avec l'analyse, pas une erreur de transcription.

**Reste ouvert (piste pour une prochaine session)** : la queue d'absorption/
dépôt d'objet en inventaire (`#1948+`, `#19E0+`, nouvelles tables `#00A7`/
`#00B3`, variables `(0079)`/`(0097)`) — squelette compris mais détails fins
non résolus. C'est très probablement LE mécanisme qui permet, comme décrit
par l'utilisateur, de transporter un objet ramassé et de le "déposer" dans
une autre salle (la seule façon pour un objet de changer de salle, aucune
entité ne le fait jamais). Le site exact où un VRAI ramassage (pas
l'action "utiliser") pose `var_object_notify_flag` reste aussi à localiser
précisément (piste ouverte, probablement dans `fn_crystal_ball_logic` ou
`fn_collision_effect`, non encore re-vérifiée avec ce nouvel éclairage).

## Sixième passe (même session) : format complet de tbl_hud_slot_icons, correction d'une piste erronée

Après ramassage réel d'un 2e objet (poison) par l'utilisateur, lecture live
de `tbl_hud_slot_icons` (12 octets, PAS 3) : `[0x61,0x04,0x68,0x42]`
`[0x60,0x04,0x87,0x41]` `[vide]`. Les octets `+2/+3` de chaque
enregistrement, lus comme pointeur word LE, tombent EXACTEMENT dans
`tbl_object_catalog` (0x417E-0x429E) à des offsets multiples de 9 (entrées
réelles #26 et #1, vérifiées directement en RAM) — **format intégralement
résolu** : `+0`=type, `+2/+3`=pointeur catalogue. Les 2 entrées catalogue
pointées montrent leur propre type à `0x00` (marqueur "objet transporté
hors du monde").

**Erreur commise puis corrigée en cours de route** : en cherchant le site
d'écriture de ce pointeur-zéro pour un ramassage normal (rubis/poison),
j'ai d'abord cru que `fn_crystal_ball_logic` (#1B2B) menait, via `jp #1AD2`,
jusqu'au bloc `#1AE9-#1B02` (le mécanisme "puzzle de collecte en ordre"
déjà documenté comme réservé aux types jamais rencontrés 0x68-0x6E) — ce
qui aurait contredit un test négatif déjà enregistré par l'utilisateur
historiquement (breakpoint sur #1AE9 non déclenché pour un ramassage de
rubis réel). En retraçant le flot précisément : `#1AD2` fait seulement
`CALL #0A07 ; JP #1F7B` et SORT avant d'atteindre `#1AD8` — mon hypothèse
de "fallthrough" était fausse. **Le test négatif de l'utilisateur reste
donc valide**, `fn_crystal_ball_logic` ne mène jamais à cette zone.
Leçon méthodologique : sur un flot avec plusieurs `jp`/`jr` courts
consécutifs, toujours vérifier explicitement si une instruction SORT
(RET/JP inconditionnel) avant le point qu'on croit atteint, plutôt que de
supposer un fallthrough par simple proximité d'adresses.

Recherche par motif d'octets (`LD L,(ix+10);LD H,(ix+11);LD (HL),0`) sur
tout le binaire : 3 occurrences (`#17F4`, `#1A71`, `#1B09`). `#1B09`
appartient bien à la zone 0x68-0x6E (confirmée non atteinte en usage
normal). `#1A71` appartient en réalité à `fn_bonus_life_pickup_logic`
(#1A4A) — **nouvelle confirmation** : le bonus de vie zère aussi son propre
pointeur catalogue au ramassage (cohérent avec "pas conservé dans
l'inventaire"). `#17F4` semble être du code mort/inatteignable près de la
famille de matérialisation (aucun `CALL`/`JP` direct trouvé dessus dans
`#0000-#3FFF`) — pas d'attribution certaine.

**Reste ouvert** : le site exact qui zère le pointeur catalogue POUR UN
RAMASSAGE NORMAL (famille 0x60-0x66) n'est PAS localisé avec certitude —
doit forcément exister ailleurs (peut-être dans une zone encore non
désassemblée de `fn_crystal_ball_logic` au-delà de ce qui a été tracé, ou
appelée depuis `fn_collision_effect`/`fn_check_collisions`). Piste pour
une prochaine session : poser un breakpoint directement sur le pattern
d'écriture (ou sur `(0x417E)-(0x429E)` en surveillance mémoire si l'outil
le permet) au moment exact d'un ramassage réel de rubis/poison/etc.

**Confirmation gameplay de l'utilisateur** (importante pour la suite) :
aucune entité ne quitte jamais une salle ; les salles sont toujours
réintégralement réinitialisées à chaque entrée (ou perte de vie) ; seuls
les objets portés par le joueur peuvent changer de salle. Ceci renforce
la conclusion de la 3e passe : `fn_room_transition` (test de bord de
coordonnées brut) est vraisemblablement un mécanisme mort ou vestigial en
usage normal pour le joueur — confirmé par un test live négatif (breakpoint
jamais déclenché en longeant un mur jusqu'à un coin, la position
n'atteignant jamais le bord réel 0/0xFF).

## Septième passe (même session) : mécanisme de dépôt automatique + fermeture du dernier fil ouvert

**Dépôt automatique confirmé en direct.** En ramassant un 3e puis 4e objet
(boule de cristal), l'utilisateur avait prédit "le rubis du slot 3 va être
déposé" — confirmé exactement : le plus ancien objet porté (pointeur
catalogue `0x4187`, entrée #1) a été retiré de `tbl_hud_slot_icons` et
réinstancié comme VRAIE entité dans la salle courante (type `0x60`,
position réelle lue en RAM). Détail notable : le champ `type` de l'entrée
catalogue correspondante RESTE à `0x00` même après ce dépôt (le catalogue
ne sert qu'à l'initialisation de partie, jamais restauré ensuite — cohérent,
pas une contradiction).

**Dernier fil ouvert de la session, fermé par test live direct.** Question :
existe-t-il un ramassage PASSIF (par simple contact, sans bouton) en plus
de `fn_player_use_held_object` ? Protocole : point d'arrêt sur `#18E8`
(seule écriture de `var_object_notify_flag` dans tout `#0000-#3FFF`, vérifié
par désassemblage exhaustif de chaque instruction référençant `#007A`),
puis l'utilisateur marche sur un objet JAMAIS ramassé auparavant SANS
appuyer sur le bouton d'action. **Résultat, confirmé directement par
l'utilisateur depuis sa connaissance du jeu** : le bouton d'action est
OBLIGATOIRE pour ramasser — aucun ramassage passif n'existe. `fn_player_
use_held_object` est donc le point d'entrée UNIQUE pour ramasser, utiliser
(boost de saut) ET déposer un objet, sélectionné selon le contexte
(proximité d'un objet vs d'un mur, portefeuille plein ou non).

Piège rencontré en cours de route : un breakpoint posé sur `fn_collision_
effect` (#2876) pour tenter d'observer le contact se déclenche à CHAQUE
frame (collision joueur/entité-jambes, sans rapport) — beaucoup trop
bruyant pour isoler un événement rare. Retiré au profit du breakpoint
ciblé sur le site d'écriture exact (`#18E8`), bien plus efficace.

**Toutes les pistes ouvertes du Tier 2 et la question du mécanisme de
transport d'objet sont maintenant résolues.** Reste seulement, à très
faible priorité : le rôle exact de l'octet `+1` de chaque enregistrement
`tbl_hud_slot_icons` (valeur `0x04` sur les 3 exemples observés, jamais
vue varier).

## Huitième passe (même session) : #0DE1 et #1188 résolus hors-ligne

Sur demande explicite de l'utilisateur ("on peut attaquer DE1 et 1188"),
désassemblage hors-ligne (émulateur toujours accessible mais pas utilisé
pour cette passe — confirme une fois de plus que beaucoup reste
déductible sans lui) :

- **`fn_probe_solid_support` (#0DE1)** — RÉSOUT la sonde utilisée par
  `fn_player_use_held_object` pour valider le boost de hauteur : réutilise
  les 3 primitives AABB de `fn_check_collisions` pour tester si une entité
  quelconque chevauche la position (boostée) du joueur.
- **`fn_melkhior_room_spawn_check` (#1188)** — l'utilisateur avait
  remarqué qu'on y "passe à chaque frame" : confirmé, appelée depuis
  `fn_arm_room_transition_flag_and_wait`, mais elle ne fait quelque chose
  QUE dans la salle de Melkhior (#88) — spawn conditionnel d'un poltergeist
  au repos si le slot3 est libre. Détail non expliqué : le template
  contient un octet `room=#B4` qui ne correspond pas à la salle de
  déclenchement — piste ouverte mineure.
- **Bonus en remontant les appelants** : `fn_shuffle_pickup_sequence_order`
  (#0E28, appelée une fois au lancement de partie) — révèle que
  `tbl_pickup_sequence_order` est mélangée pseudo-aléatoirement à chaque
  partie, PAS fixe comme la transcription brute des 14 octets le
  suggérait. Et précision du test de démarrage exact de
  `fn_boot_init_and_new_game` (`#058D-#0596`), incluant un jingle de début
  de partie distinct des jingles de game-over déjà connus.

**Incident méthodologique et leçon retenue** : en splicant le nouveau code
dans `entity_logic_mechanical.asm`, une erreur d'indexation de ligne (off-
by-one) a fait disparaître 16 octets légitimes et sans rapport
(`#1175-#1184`). **Détecté immédiatement par la validation systématique
réassemblage+diff** (jamais sautée, même en fin de session) — corrigé sur
place. Confirme que cette étape de validation n'est pas une formalité :
elle a occasionnellement rattrapé une vraie erreur cette session (voir
aussi la correction du flot de `fn_crystal_ball_logic` en 6e passe, elle
détectée par relecture, pas par la validation octet-à-octet — deux
filets de sécurité complémentaires, pas redondants).

Validé par réassemblage réel + comparaison octet-à-octet sur toutes les
plages touchées : 0 écart (après correction de l'incident ci-dessus).

Les deux dernières routines "non identifiées" citées dans `fn_main_loop`/
`fn_arm_room_transition_flag_and_wait` sont maintenant résolues. Reste
ouvert, très faible priorité : anomalie `room=#B4` du template Melkhior,
octet `+1` de `tbl_hud_slot_icons`, famille 0x68-0x6E jamais rencontrée.

## Pistes suggérées par l'utilisateur pour une prochaine session live

Pas encore explorées, à garder pour la prochaine session avec émulateur :
- **Contrôle au joystick** (vs clavier) — `var_input_mode_flag` (#006C)
  déjà confirmé comme sélecteur, mais le comportement joystick lui-même
  jamais testé en direct.
- **Redéfinition des touches dans le menu** — mécanisme jamais localisé
  dans le désassemblage à ce jour.
- **Mode de pilotage "directionnel"** (aller directement dans une
  direction au lieu de tourner puis avancer) — si un tel mode alternatif
  existe réellement (à vérifier dans le menu/les options), il impliquerait
  très probablement un chemin de code distinct de l'état-machine de
  rotation déjà confirmée dans `fn_player_read_input` (#2147) — bon
  candidat pour une prochaine session hors-ligne (chercher un second
  point d'entrée alternatif) PUIS live (confirmer si activable et son
  effet).

## Neuvième passe (même session) : test live en salle 0x88, mode directionnel (partiel)

**Test en salle de Melkhior avec 3 objets portés** : confirme
`fn_melkhior_room_spawn_check` en conditions réelles — le poltergeist
spawné (visuellement : "sort du chaudron") porte bien `room_number=0xB4`
sur l'entité VIVANTE (pas juste dans le template statique), anomalie
confirmée persister sans effet de bord visible négatif. L'utilisateur
rapporte "affiche une bouteille par intermittence" — **résolu par lecture
directe des tables** (pas besoin de breakpoint) : le cycle passe
transitoirement par le type `0xAD`, qui partage son pointeur de sprite
(`#456D`) avec l'objet "bouteille" (0x65) — pure coïncidence de partage de
sprite entre deux familles sans rapport, PAS un déguisement délibéré.
Étend au passage la plage `0xA8-0xAB` (logique 0x1200) à `0xA8-0xAF`, et
corrige sa description ("transition" → en réalité un simple retour à
l'état de repos 0xA0).

**Mode "directionnel" (piste de l'utilisateur)** : recherche hors-ligne
des écritures de `var_input_mode_flag` (#006C) révèle l'écran de menu de
configuration des touches (#15C2, appelé depuis `fn_boot_init_and_new_game`
via `#058D`). Une option de ce menu (touche de la ligne clavier 7) bascule
**bit3** de `var_input_mode_flag` (distinct de bit1, déjà confirmé
clavier/joystick) — et bit3 EST exactement le bit testé en tête de
`fn_player_read_input` (#2147, avec bit1) pour décider si l'état-machine
de rotation s'exécute ou non. **Non résolu** : quand bit3 est à 0, la
routine sort immédiatement sans rien faire ; aucun chemin de code
alternatif de déplacement direct n'a été localisé ailleurs. Reste
possible que ce bit corresponde à autre chose (gel du contrôle, mode
debug) plutôt qu'à un vrai mode directionnel. **Piste concrète pour la
prochaine session live** : basculer cette option dans le menu et observer
directement si/comment le joueur peut encore bouger.

**Correction majeure suite à l'explication de l'utilisateur du puzzle du
chaudron** : l'observation "affiche une bouteille par intermittence"
n'est PAS une coïncidence de partage de sprite comme conclu trop vite —
vérification des 8 pointeurs `0xA8-0xAF` dans `tbl_sprite_dispatch` montre
qu'ils correspondent EXACTEMENT, dans l'ordre, aux 8 sprites du catalogue
d'objets. Le poltergeist de la salle de Melkhior est **l'indicateur
d'indice du puzzle de collecte en ordre** (`fn_treasure_settle_and_
sequence_check`), pas une entité "de repos" anodine. Ceci relie enfin ce
puzzle (famille 0x68-0x6E, "jamais rencontré en jeu" depuis 2026-08-07) à
un mécanisme réel et observable — le déclencheur de création d'entité
0x68-0x6E est probablement l'action de déposer un objet PRÈS DU CHAUDRON
spécifiquement (piste à vérifier en direct, le test négatif historique
avait reposé un objet ailleurs). Leçon méthodologique : une conclusion
"c'est juste une coïncidence" mérite d'être reconfirmée dès qu'une
nouvelle information contextuelle (ici, la règle de jeu expliquée par
l'utilisateur) la remet en question — ne pas s'y accrocher par inertie.
