# Session 2026-08-10 (4e passe) — Format complet du moteur d'effets sonores tické par IM1

## Contexte

Suite de la demande "vas y pour les interruptions" : décodage du moteur
d'effets sonores **tické par l'interruption IM1** (`fn_sound_engine_tick`
`#08CC`, `tbl_sound_dispatch` `#08E8`), système **entièrement séparé** du
lecteur de jingle bloquant décodé dans la passe précédente
(`notes/2026-08-10-sound-program-bytecode-format.md`) — point 8 de
`docs/SESSION_SUMMARY.md`, ouvert depuis 2026-08-07 (un seul exemple
connu : le son de transformation jour/nuit, `#0A6E`).

**Incident d'environnement en cours de session** (sans rapport avec le
code) : l'émulateur, lancé sous X11 en partageant le bureau réel de
l'utilisateur, a reçu un événement "File dropped" inattendu (chargement
d'un `Intro.dsk` étranger au projet + hard reset) — repéré immédiatement
via des octets incohérents en RAM, corrigé en relançant une instance
propre avant de continuer. Aucune donnée de ce dépôt n'a été affectée ;
mentionné ici pour la prochaine session au cas où le même environnement
soit réutilisé.

## Vue d'ensemble

`fn_sound_engine_tick` (`#08CC`) tourne 6× par frame vidéo (300Hz,
appelée depuis `fn_im1_interrupt_handler` `#0038`), balaie 3 slots de 4
octets (`struct_sound_channel_slot`, `#009B`/`#009F`/`#00A3`) :

```
+0  état courant (0-7, index dans tbl_sound_dispatch #08E8)
+1  compteur de durée restante
+2  paramètre A (selon l'état : octet haut d'une période, ou inutilisé)
+3  paramètre B (selon l'état : octet bas d'une période, ou inutilisé)
```

Pour chaque canal, dispatch par `+0` (`RST 28`) vers un gestionnaire
d'état. Chaque gestionnaire (sauf l'état 0, idle) **décrémente `+1`
lui-même à chaque appel** (`fn_sound_tick_channel` `#0908`, ou
directement à partir de `#090B` pour l'état 1) : si le compteur n'est
pas épuisé, il écrit les registres PSG appropriés pour ce tick puis
`RET` ; s'il atteint 0, il coupe le volume (silence), signale la fin
dans `var_sound_mixer_mask` (`#0098`) et remet l'état à 0 (idle) — un
**double-`RET`** (`INC SP` ×2) fait sortir directement jusqu'à
l'appelant de `fn_sound_engine_tick`, sans exécuter le reste du
gestionnaire d'état.

Un canal est armé par une routine appelante via `fn_sound_arm_channel_0`/
`_1`/`_2` (`#08C3`/`#08B9`/`#08BE` — **le canal 1 n'avait jamais été
repéré avant cette session**, seuls 0 et 2 étaient documentés) : `LDIR`
4 octets depuis un **descripteur** `[état][compteur initial][param A][param B]`
vers le slot.

## Les 8 états (`tbl_sound_dispatch`, `#08E8`)

| État | Adresse | Nom | Effet |
|---|---|---|---|
| 0 | `#0895` | `fn_sound_state_idle` | rien (canal inactif) |
| 1 | `#0992` | `fn_sound_effect_noise_decay` | **bruit à volume ET hauteur décroissants** — impact/thud |
| 2 | `#09B0` | `fn_sound_effect_sweep_linear` | glissando linéaire, volume fixe max — "boing" |
| 3 | `#09CB` | `fn_sound_effect_click_positional` | clic, volume dépendant de la position joueur, hauteur dans une petite palette |
| 4 | `#0A33` | `fn_sound_effect_note_fixed_decay` | note à hauteur fixe, volume décroissant |
| 5 | `#0A5E` | `fn_sound_effect_sweep_scrambled` | glissando "brouillé" (XOR), volume fixe max |
| 6 | `#0A72` | `fn_sound_effect_sweep_nibble_swap` | glissando par échange de nibbles, partage la queue de l'état 5 |
| 7 | `#0A4B` | `fn_sound_effect_tone_fixed` | ton à période 16 bits fixe (exacte), volume fixe max |

### État 1 — bruit décroissant (impact)

Bascule un bit du mixer (bruit ON pour ce canal), décrémente le
compteur ; si non nul : `volume = compteur/2`, `période de bruit =
complément(compteur) & #1F` — le bruit change de "grain" en même temps
que le volume baisse. Descripteur connu : `#098E` (compteur initial
`#1F`=31), armé par `fn_player_materialize_anim` (`#17D6`, séquence de
(dé)matérialisation du joueur) et par une 2e routine non identifiée
(`#1F44`).

### État 2 — glissando linéaire ("boing")

`période = #0100 + compteur×2` (décroît linéairement), volume fixe 15.
Descripteur `#09AC`, armé par `fn_sound_trigger_bounce` (`#09A6`) —
**LE son de rebond**, confirmé empiriquement par l'utilisateur pour
`fn_bouncing_ball_logic` (`#1148`/`#1170`) ; 2 autres appelants non
identifiés (`#0F30`, `#111A`, même famille "rebond/renversement de
direction").

### État 3 — clic positionnel

`volume = ((var_00D8>>1) + (-var_00D9)>>1) rotate 5, &7, +8` — dépend de
la position du joueur en cache. `hauteur` = un index pris dans
`tbl_sound_click_pitch_palette` (`#09FF`, 8 octets : `#25 #27 #28 #2A
#28 #27 #25 #23`, un petit vibrato montant-descendant), lui-même un
INDEX vers **`tbl_sound_chromatic_periods` (`#0BA8`) — la même table de
56 hauteurs chromatiques que le lecteur de jingle bloquant**
(`#0A97`/`notes/2026-08-10-sound-program-bytecode-format.md`) : les deux
moteurs son du jeu partagent cette table. Index choisi via
`var_sound_click_pitch_index` (`#009A`), incrémenté à chaque
déclenchement par `fn_sound_trigger_click_and_advance` (`#09BD`,
descripteur `#09C7`) — appelé depuis du code de collision générique non
identifié précisément (`#21B9`, `#222D`).

### État 4 — note fixe décroissante

`hauteur` = valeur fixe lue dans le descripteur (`param B`), `volume =
rotation-droite(compteur) & #0F` (décroissant). Descripteur `#0A2F`
(compteur `#1F`), armé par `fn_sound_arm_position_pitch_ch1` (`#0A22`,
utilise `complément((ix+03))` de l'entité comme hauteur) — appelants non
identifiés (`#0F7E`, `#10BD`).

### État 5/6 — glissandos "glitch"

État 5 : `période = ROL2(compteur) XOR #A0`, volume fixe 15 — aucun
armement direct trouvé cette session (peut-être atteint uniquement via
l'état 6). État 6 : `période = ROL4(compteur)` (échange de nibbles) PUIS
tombe directement dans le corps de l'état 5 (même écriture période +
volume). Descripteur `#0A6E` (compteur `#1F`), armé par
`fn_player_transform_tick` (`#1BFC`) — **LE son de l'animation de
transformation jour/nuit**, confirmé empiriquement par l'utilisateur
depuis 2026-08-07 (`notes/2026-08-07-transformation-sound.md`).

### État 7 — ton fixe exact

`période` = valeur 16 bits lue directement dans le descripteur (`param
A`/`param B`), volume fixe 15 — pas de calcul, fréquence exacte
imposée par l'appelant. Descripteur `#0A47` (compteur `#07`, court —
un blip répété plutôt qu'une note longue), armé par
`fn_position_pitch_sound_arm` (`#0A07`, précisée cette session : utilise
`complément(grid_x+grid_y+grid_z)` de l'entité comme hauteur) — déjà
documentée comme le "son de déplacement à hauteur dépendant de la
position" de `fn_pushable_block_logic`.

## Registres PSG écrits

Canal (1,2,3, via `fn_sound_channel_index` `#08F8` = `(IY-#009B)/4+1`) :
- période fine/coarse : `(canal-1)×2` / `+1` (via `fn_sound_write_period_hl`
  `#0A7B`, réutilise `fn_psg_write_period_low`/`full` comme
  select-registre/écrit-valeur génériques, déjà précisé dans
  `notes/2026-08-10-sound-program-bytecode-format.md`)
- volume : `canal+7` (via `fn_sound_write_volume` `#097D`)
- bruit : registre 6, **partagé par les 3 canaux** (pas par canal, un
  seul générateur de bruit sur la puce) — écrit par `fn_sound_write_noise_period`
  (`#0942`), utilisé seulement par l'état 1
- mixer (registre 7) : chaque canal bascule SON PROPRE bit (tons/bruit)
  dans `var_sound_mixer_mask` (`#0098`, accumulateur partagé) via
  `fn_sound_toggle_mixer_bit_a`/`_b` (`#094E`/`#096B`, deux variantes
  quasi-identiques) — permet à 3 canaux indépendants de modifier le même
  registre mixer sans s'écraser mutuellement

## Addendum (même session, poursuite immédiate) — callers identifiés

En reprenant la recherche statique avec les adresses de symboles
existantes comme point de départ (au lieu de s'arrêter au "previous
symbol" trop éloigné), les 4 des 6 callers non identifiés sont résolus :

- **`#0F30`** (état 2, rebond) → **`fn_ball_chase_flee_logic`** (`#0EE5`,
  déjà confirmée en prose depuis 2026-08-07 pour les types `#B6`/`#B7`
  "bulle volcanique", mais jamais formalisée en symbole/asm avant cette
  session — fait maintenant, avec `fn_sinking_cube_logic` (`#0F67`, type
  `#5B`) et la transformation du bloc dormant (`fn_dormant_block_transform`
  `#0F84`, type `#8F`) et `fn_moving_block_logic`/`_type37` (`#0F98`/`#0F93`,
  types `#36`/`#37`) — 4 routines qui existaient déjà en prose dans
  `docs/SYMBOLS.md` depuis 2026-08-07 mais n'étaient jamais entrées dans
  `symbols.json`/générées en asm.
- **`#111A`** (état 2, rebond) → **`fn_will_o_wisp_logic`** (`#10F4`,
  déjà documentée comme rebondissant "selon le même schéma que la
  balle" — confirme maintenant qu'elle joue EXACTEMENT le même son).
  Bonus non cherché : `fn_will_o_wisp_logic` utilise AUSSI
  `fn_position_pitch_sound_arm` (`#0A07`, état 7) juste avant, jamais
  noté précédemment.
- **`#0F7E`** (état 4) → **`fn_sinking_cube_logic`** (`#0F67`, type
  `#5B` "cube-piège") — le clic de descente a une hauteur qui dépend de
  `grid_z` de l'entité.
- **`#10BD`** (état 4) → **`fn_ceiling_spike_ball_logic`** (`#1092`,
  déjà confirmée) — clic de contact des pics.
- Bonus supplémentaire : l'état 5 (`fn_sound_effect_sweep_scrambled`),
  qui n'avait AUCUN armeur direct trouvé, en a maintenant un :
  descripteur `#0A5A` (compteur `#1F`), armé directement à `#220C` par
  une routine de réaction de collision générique — voir ci-dessous.

**Restent non identifiées précisément** : la routine contenant `#21B9`/
`#222D`/`#220C` (état 3 + état 5, dans une zone de code entre
`fn_player_read_input` `#2147` et `fn_get_orientation_code` `#22D0`,
jamais nommée — teste des bits de collision génériques `(ix+0C)`/`c`,
pose `bit3,(ix+0C)` + `(ix+0B)=8` avant d'armer l'état 5, ce qui
ressemble à un mécanisme "objet qui s'immobilise/s'encastre au contact"
mais le type d'entité exact n'a pas été tracé). Candidate solide pour
une prochaine session, idéalement avec identification empirique en jeu
(breakpoint sur `#220C`, observer quel type d'entité est `IX` à ce
moment).

## Validation

Toutes les valeurs citées viennent d'une lecture RAM live directe.
Symboles ajoutés à `asm/symbols.json` (16 nouvelles routines + 1 table +
2 variables), formalisation au passage de `fn_pixel_bit_scatter_lo`/`_hi`
(`#0896`/`#08A9`, déjà décrites en prose depuis 2026-08-09 mais jamais
ajoutées comme symboles). Régénération de `asm/code/dispatch_and_sound.asm`
sur la plage `#0895-#0D66`. Réassemblage `rasm` + comparaison
octet-à-octet contre la RAM live sur toute la plage éditée : **0
différence**. Voir `docs/SYMBOLS.md` pour les entrées détaillées et
`docs/SESSION_SUMMARY.md` point 8 (mis à jour, résolu).
