# Session 2026-08-07 — Routine d'animation de transformation joueur (0x5C-0x5F) RÉSOLUE

Piste #2 de `docs/SESSION_SUMMARY.md` §7 : "Routine d'animation de
transformation joueur (`0x5C-0x5F`) — existence confirmée, mécanisme
exact pas encore désassemblé." **Résolu ce jour**, par désassemblage
statique pur (pas eu besoin de nouvelle capture empirique : la
structure retrouvée colle exactement à la trace déjà capturée dans
`notes/2026-08-06-day-counter.md`, section "CONFIRMÉ EN DIRECT").

## Méthode

1. Dump de `tbl_entity_logic_dispatch` (0x0676) et lookup direct des
   pointeurs pour les types déjà connus (0x12, 0x14, 0x34, 0x5C-0x5F,
   0x60-0x61) : **0x5C, 0x5D, 0x5E, 0x5F pointent tous vers la même
   adresse, 0x1BE1**. Type 0x12/0x14 (joueur jour) → 0x20CB
   (`fn_player_logic`), type 0x34 (loup-garou nuit) → 0x20D0 (même
   routine, entrée alternative).
2. Désassemblage de 0x1BE1 et remontée vers 0x1BB0 (routine appelée
   depuis `fn_player_logic`, avant 0x1BE1 dans le binaire, contenant du
   code partagé/tail-call avec 0x1BE1).
3. Recherche des sites d'appel de 0x1BB0 (`CD B0 1B`) : un seul,
   `0x20E6`, dans `fn_player_logic` (0x20CB) juste après la convergence
   des deux entrées jour/nuit (0x20CB/0x20D0 → 0x20D3 → 0x20E6).

## Mécanisme complet

### `0x0077` — double rôle (flag ET stockage temporaire)

Déjà documenté comme `var_object_notify_flag`... non — **erreur de
nommage à corriger dans SYMBOLS.md** : `0x0077` était déjà repéré
(section "variables basses", "Remis à 0 par fn_init_room_entities") et
aussi comme le flag "force redraw" écrit par `fn_hud_day_night_cycle`
(voir day-counter.md 0x1CBD `ld a,01 / ld (0077),a`). Le désassemblage
d'aujourd'hui révèle qu'il a en fait un **double usage successif** :
- **Phase 1 (déclenchement)** : mis à `1` par `0x1CBD` à la fin de
  chaque cycle jour/nuit complet ("demande de transformation en
  attente").
- **Phase 2 (stockage)** : au moment où `fn_player_transform_trigger`
  (0x1BB0) accepte la demande, il **réutilise le même octet** pour y
  sauvegarder le type COURANT (jour ou nuit, avant transformation) —
  `LD A,(IX+00) / LD (0077),A` (0x1BC2-0x1BC5). Ce type sauvegardé sert
  plus tard à calculer le type final stable (voir phase de complétion).
- Remis à `0` (idle) à la fin de la transformation (0x1C32) ET à l'init
  de room (`fn_init_room_entities`, 0x29B4).

Nom proposé : `var_transform_flag_and_saved_type` (remplace
l'interprétation précédente, trop étroite).

### `0x1BB0` — `fn_player_transform_trigger` (confirmed)

Appelée à chaque frame depuis `fn_player_logic` (0x20E6), pour le
joueur en forme stable (jour ou nuit) :

```
1BB0  LD A,(0077)
1BB3  AND A
1BB4  RET Z                  ; pas de transformation en attente -> rien à faire
1BB5  LD A,(IX+0C)           ; cooldown_timer (déjà connu, decrémenté par pas de 0x10 ailleurs)
1BB8  AND F0
1BBA  RET NZ                 ; cooldown pas encore écoulé (nibble haut non-nul) -> attendre
1BBB  BIT 3,(IX+0C)
1BBF  RET NZ                 ; garde supplémentaire sur le même octet -> attendre
1BC0  INC SP
1BC1  INC SP                 ; ASTUCE : dépile l'adresse de retour du CALL 1BB0 (2 octets)
                              ; -> ne revient PAS à l'appelant (fn_player_logic) cette frame ;
                              ;    la suite du code enchaîne directement l'animation.
1BC2  LD A,(IX+00)           ; type courant (jour=0x14 ou nuit=0x34)
1BC5  LD (0077),A            ; sauvegarde ce type dans 0x0077 (réutilisation, voir ci-dessus)
1BC8  LD (IX+10),08          ; compteur de sous-étapes = 8 (confirme "~8 étapes" utilisateur)
1BCC  PUSH IX
1BCE  LD DE,001C
1BD1  ADD IX,DE              ; IX -> entité + 0x1C (vue comme sous-structure)
1BD3  LD (IX+00),01          ; (entité+0x1C) = 1 -- marqueur "transformation en cours"
1BD7  CALL 1F7B              ; (ix+07) |= 0x30 -- force le redessin de l'entité
1BDA  POP IX                 ; IX restauré (base entité)
1BDC  CALL 1D99              ; recalcule les offsets de calibration projection (ix+12/13)
1BDF  JR 1C04                ; tombe dans le tail partagé avec 0x1BE1 (voir plus bas)
```

### `0x1BE1` — `fn_player_transform_tick` (confirmed), dispatch pour types 0x5C-0x5F

Appelée chaque frame TANT QUE le type de l'entité est l'un des 4 types
transitoires (0x5C-0x5F) — c'est-à-dire pendant toute la durée de
l'animation :

```
1BE1  CALL 1D99              ; recalibre offsets (même appel qu'au déclenchement)
1BE4  BIT 6,(IX+0D)
1BE8  JR Z,1BF3              ; bit non posé -> chemin normal (ci-dessous)
                              ; bit posé -> chemin alternatif (0x17CC, cas spécial
                              ;   "capturé/mangé" probable, hors-sujet transformation)
1BF3  LD A,(006A)            ; var_frame_counter
1BF6  AND 03
1BF8  RET NZ                 ; throttle : n'agit qu'une frame sur 4
1BF9  LD HL,0A6E
1BFC  CALL 08BE              ; LDIR 4 octets depuis 0x0A6E vers 0x00A3 (buffer fixe) —
                              ;   rôle exact non élucidé (hypothesis: petit effet visuel
                              ;   annexe, ex. clignotement ; 0x00A3 vide au repos)
1BFF  DEC (IX+10)             ; décrémente le compteur de sous-étapes (initialisé à 8)
1C02  JR Z,1C24               ; compteur épuisé -> COMPLÉTION (voir plus bas)
1C04  LD A,R                  ; registre R (source de hasard 8-bit classique)
1C06  LD C,A
1C07  LD A,(006D)             ; var_pseudo_random_acc
1C0A  ADD A,C
1C0B  AND 03                  ; -> 0-3
1C0D  OR 5C                   ; -> 0x5C/0x5D/0x5E/0x5F (un des 4 sprites transitoires)
1C0F  CP (IX+00)              ; si identique au type courant...
1C12  JR NZ,1C16
1C14  XOR 01                  ; ...force un type DIFFÉRENT (jamais 2 fois le même de suite)
1C16  LD (IX+00),A            ; nouveau type transitoire
1C19  LD A,(IX+07)
1C1C  XOR 40                  ; bascule le bit 6 des flags (orientation/mirroir) à chaque
                              ;   étape -> effet visuel de "tremblement/oscillation"
1C1E  LD (IX+07),A
1C21  JP 1F7B                 ; force le redessin
```

**Confirme exactement la trace empirique** de day-counter.md (types
observés 0x5C→0x5F→0x5E→0x5C→0x5D→0x5F→0x5C, non séquentiels — cohérent
avec une sélection pseudo-aléatoire `AND 3 | 0x5C`, pas un cycle fixe).

### `0x1C24` — complétion de la transformation (confirmed)

Atteint quand le compteur de sous-étapes (`ix+10`) tombe à 0 (8 ticks
throttlés à 1 frame sur 4, soit ~32 frames ≈ 0.64s à 50Hz — un peu plus
court que les ~2s observées empiriquement dans day-counter.md, qui
incluait probablement le délai de cooldown avant déclenchement +
l'échantillonnage à 0.3s qui a pu sous-estimer le nombre d'étapes
distinctes réellement vues) :

```
1C24  LD A,(0077)            ; récupère le type PRÉ-transformation sauvegardé
1C27  XOR 20                 ; bascule le bit 5 : 0x14 XOR 0x20 = 0x34, et réciproquement
                              ; -- CONFIRME NUMÉRIQUEMENT la bascule jour(0x14)<->nuit(0x34)
1C29  LD (IX+00),A           ; type final stable
1C2C  ADD A,10
1C2E  LD (IX+1C),A           ; entité+0x1C = type_final + 0x10 (champ SYMBOLS.md "unknown"
                              ;   -> résolu : miroir du type courant, pas un marqueur figé)
1C31  XOR A
1C32  LD (0077),A            ; flag remis à 0 -> idle, prêt pour le prochain cycle
1C35  CALL 1D89              ; recalibre offsets projection (variante différente de 1D99)
1C38  BIT 5,(IX+00)
1C3C  JR Z,1C41
1C3E  DEC (IX+13)            ; ajustement fin d'un offset de calibration si bit5 posé
                              ; (asymétrie mineure jour/nuit du point d'ancrage sprite)
1C41  JP 1F7B                ; force le redessin final
```

**Vérification numérique** : `0x14 XOR 0x20 = 0x34` et `0x34 XOR 0x20 =
0x14` — exactement les deux types stables confirmés empiriquement
(jour/explorateur et nuit/loup-garou). Cette bascule est directionnelle
et déterministe une fois le type de départ connu (sauvegardé dans
`0x0077` au déclenchement) — pas un simple flag externe comme le bit 0
de `var_day_night_flag` (0x1CFA), qui lui ne fait que PROGRAMMER la
transformation (poser le flag à 1) sans en piloter le résultat exact.

## Bilan — chaîne causale complète, de bout en bout

```
fn_hud_day_night_cycle (0x1CAF, fin de cycle 49 paliers x8 frames)
  -> XOR 1CFA bit0 (jour/nuit "officiel")
  -> (0077) = 1 (DEMANDE de transformation)
       |
       v (frame suivante, dans fn_player_logic, via 0x1BB0)
fn_player_transform_trigger (0x1BB0)
  -> attend fin de cooldown_timer (ix+0C)
  -> sauvegarde type courant dans (0077) [réutilisation]
  -> (ix+10) = 8 (compteur d'étapes)
  -> tombe directement dans le tail 0x1C04 (bypass return, INC SP astuce)
       |
       v (chaque frame suivante, dispatch direct type 0x5C-0x5F -> 0x1BE1)
fn_player_transform_tick (0x1BE1)
  -> throttle 1 frame/4
  -> choisit un type transitoire pseudo-aléatoire parmi 0x5C-0x5F
  -> bascule bit6 des flags (tremblement visuel)
  -> décrémente (ix+10) ; à 0 -> COMPLÉTION (0x1C24)
       |
       v
0x1C24 : type_final = type_sauvegardé XOR 0x20  (0x14<->0x34)
  -> (0077) = 0 (idle, cycle terminé)
```

## Statut final

**CONFIRMED** — désassemblage complet et cohérent, structure validée
par calcul (`XOR 0x20` reproduit exactement 0x14↔0x34) ET par la trace
empirique déjà capturée en direct dans une session précédente (types
transitoires observés, ~8 étapes, throttling visible dans le rythme
d'échantillonnage). Aucune nouvelle capture live n'a été nécessaire —
tous les éléments recoupent parfaitement les observations antérieures.

## Point encore ouvert (mineur, non bloquant pour cette piste)

Le contenu exact copié depuis `0x0A6E` vers le buffer fixe `0x00A3`
(4 octets, `LDIR` via `0x08BE`) reste non élucidé — hypothesis : un
petit effet visuel annexe (scintillement ? overlay ?). `0x00A3` est lu
comme vide (`00 00 00 00...`) au repos (hors transformation), cohérent
avec un buffer de travail transitoire plutôt qu'une donnée statique.
Non prioritaire, à reprendre si une session future explore `0x08BE`/
`0x08CC` plus en détail (zone visitée seulement en marge).
