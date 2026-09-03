# Session 2026-08-10 (3e passe) — Format complet du programme sonore (jingle de fin de partie)

## Contexte

Suite directe de la correction du même jour
(`notes/2026-08-10-object-catalog-writeback-and-psg-keyboard.md`,
addendum) : `fn_sound_program_play_blocking` (`#0A97`) avait été identifiée
mais laissée `hypothesis` faute d'avoir décodé le bytecode et les tables
qu'elle consomme. Demande explicite de l'utilisateur : "décode le format
pour l'audio". Méthode : lecture directe du contenu RAM live des tables
(pas seulement du code qui les indexe), recoupée avec un calcul de
fréquence pour valider l'hypothèse "table de hauteurs".

## Vue d'ensemble

`fn_sound_program_play_blocking` interprète un **bytecode 1 octet/pas**,
3 canaux en parallèle (round-robin), pour jouer un jingle PSG bloquant
(busy-wait, `DI`, pas d'IM1). Chaque canal a un slot de 7 octets à
`#1877` (+7×index) :

```
+0/+1  pointeur programme courant (avance à chaque pas)
+2/+3  compteur de durée courant (décompté à chaque tour de la boucle
       round-robin ; un "tick" = un tour complet sur les 3 canaux)
+4     mode de volume/instrument courant (posé par une commande #00-#03)
+5/+6  pointeur de DÉPART (copie du pointeur initial, pour la commande LOOP)
```

## Format d'un octet de programme

```
octet < 8   -> COMMANDE (voir tableau ci-dessous)
octet >= 8  -> NOTE :
    bits 7-6 = index de DURÉE (0-3)   -> tbl_sound_note_durations (#0B90)
    bits 5-0 = index de HAUTEUR (0-63, valide 0-55) -> tbl_sound_chromatic_periods (#0BA8)
```

L'extraction des bits se fait par rotation (`RLCA` ×N + `AND`) plutôt que
par masque+shift direct — probablement pour la vitesse (1 cycle/RLCA) —
mais revient exactement à :

- durée = `(octet >> 6) & 3`
- hauteur = `octet & 0x3F`

### Table des durées (`tbl_sound_note_durations`, `#0B90`, confirmed)

| index | valeur (compteur) |
|---|---|
| 0 | `#0400` (1024) |
| 1 | `#0800` (2048) |
| 2 | `#0C00` (3072) |
| 3 | `#1000` (4096) |

Progression linéaire simple (×1, ×2, ×3, ×4 d'une unité de base) — pas de
rythme pointé/triolet, juste 4 longueurs de note.

### Table des hauteurs (`tbl_sound_chromatic_periods`, `#0BA8`, confirmed)

56 périodes PSG 16 bits, **gamme chromatique confirmée par calcul** :
ratio quasi exact `2^(1/12)` entre entrées consécutives, du `#0353`
(851, le plus grave) au `#0024` (36, le plus aigu). Avec une horloge PSG
CPC ≈ 1 MHz (`freq = 1000000 / (16 × période)`) :

| index | période | fréq. (Hz) | note |
|---|---|---|---|
| 0 | 851 | 73.44 | D2 |
| 8 | 536 | 116.60 | A#2 |
| 16 | 338 | 184.91 | F#3 |
| 24 | 213 | 293.43 | D4 |
| 32 | 134 | 466.42 | A#4 |
| 40 | 84 | 744.05 | F#5 |
| 48 | 53 | 1179.25 | D6 |
| 55 | 36 | 1736.11 | A6 |

(table complète : 56 entrées, D2→A6, chaque demi-ton présent — voir
`asm/code/dispatch_and_sound.asm` pour les 56 valeurs brutes en `defw`).
Erreur résiduelle < 0.2 demi-ton sur toute la table (arrondi 8 bits),
cohérente avec une table générée une fois pour toutes par l'auteur
original plutôt que calculée en jeu.

**Octets de hauteur invalides** : `#38-#3F` (et leurs alias `#78-#7F`,
`#B8-#BF`, `#F8-#FF`, mêmes 6 bits bas) donneraient un index 56-63, qui
tombe dans le CODE des gestionnaires de commande (`#0C18+`) plutôt que
dans la table — jamais utilisé par les données réelles du jeu (vérifié :
aucune des 5 séquences de canal examinées ne les emploie).

### Table des commandes (`tbl_sound_opcode_dispatch`, `#0B98`, confirmed)

| octet | nom | effet |
|---|---|---|
| `#00`-`#05` | `fn_sound_cmd_store_param` | stocke la valeur brute (0-5) dans `+4` (mode de volume courant, appliqué à la PROCHAINE note) |
| `#06` | `fn_sound_cmd_loop` | `+0/+1 = +5/+6` (relance le programme du canal depuis le début — boucle infinie) |
| `#07` | `fn_sound_cmd_end` | coupe le mixer PSG (registre 7=`#3F`, tons+bruit off) + volumes A/B/C=0, puis **`RET` jusqu'à l'appelant ORIGINAL de `fn_sound_program_play_blocking`** — termine TOUT le jingle dès qu'UN SEUL canal l'atteint, pas seulement ce canal |

### Table des modes de volume (`tbl_sound_volume_mode_dispatch`, `#0B5D`, confirmed)

Consultée juste après avoir écrit la période d'une note, indexée par la
valeur courante du champ `+4` :

| valeur `+4` | nom | effet |
|---|---|---|
| 0 | `fn_sound_volume_mute` | volume = 0 (silence) |
| 1 | `fn_sound_volume_mid` | volume = 7 (fixe, moyen) |
| 2 | `fn_sound_volume_max` | volume = `#0F`=15 (fixe, max) |
| 3 | `fn_sound_volume_envelope` | volume = `#10` (bit4=1, mode enveloppe matérielle) + registre de forme d'enveloppe (13) remis à 0 |

**Seules 4 entrées existent** — bien que `fn_sound_cmd_store_param`
accepte sans broncher n'importe quelle valeur 0-5 dans `+4`, une valeur
4 ou 5 ferait sauter la note suivante vers une adresse invalide
(`#0011`, en plein milieu de `rst_apply_movement_vector`) : un vrai piège
du format, jamais déclenché par les données réelles (seules 0-3 sont
utilisées dans les 5 séquences examinées).

## Registres PSG écrits

Le canal (1, 2 ou 3, compté depuis le compteur de boucle round-robin)
sélectionne les registres AY-3-8912 :
- période fine/coarse : `(canal-1)×2` et `(canal-1)×2+1` (0/1=A, 2/3=B, 4/5=C)
- volume : `canal+7` (8/9/10 = volume A/B/C)

Via `fn_psg_write_period_low`/`fn_psg_write_period_full` (`#0D8C`/`#0DA7`)
— **précision apportée cette session** : ces deux routines ne sont PAS
spécifiques à "écrire une période". Ce sont des primitives PSG
génériques : `fn_psg_write_period_low(E=registre)` = SÉLECTIONNE le
registre E (fonction PPI Port C = 11, données = E) ; `fn_psg_write_period_full(E=valeur)`
= ÉCRIT E dans le registre actuellement sélectionné (fonction = 10).
Utilisées en paire (select registre N, write valeur) pour n'importe
quel registre PSG, pas seulement les périodes — confirmé ici par leur
usage pour écrire les VOLUMES (registres 8-10) et le mixer (registre 7)
via `fn_psg_register_init_stream`, en plus des périodes.

## Exemple décodé — jingle de game-over (`HL=#0C49`, appelé depuis `#1374`)

3 pointeurs de canal : ch1=`#0D5B`, ch2=`#0D2D`, ch3=`#0D0B`.

**Canal 1** (`#0D5B`: `00 C0 06`) : commande 0 (volume=0, silence) ; note
`#C0` = durée3(4096)+hauteur0(D2) ; commande 6 (LOOP). **Un canal muet en
boucle** — sert probablement de "canal de réserve" inutilisé pour ce
jingle précis.

**Canal 2** (`#0D2D`: `02 CB CB CD CD CF CF CF CF 07`) : commande 2
(volume=15, max) ; notes `CB,CB` (durée3+hauteur11=C#3) ×2 ; `CD,CD`
(durée3+hauteur13=D#3) ×2 ; `CF,CF,CF,CF` (durée3+hauteur15=F3) ×4 ;
commande 7 (FIN). **Mélodie principale** : C#3-C#3-D#3-D#3-F3-F3-F3-F3,
notes longues, volume fixe max — motif ascendant simple, typique d'un
petit "stinger" de fin de partie. C'est ce canal qui détermine la durée
totale du jingle (sa commande FIN arrête tout).

**Canal 3** (`#0D0B`: `03 2E 17 27 17 2E 17 27 17 ...`) : commande 3
(mode enveloppe) ; puis alternance rapide `2E`(durée0+hauteur46=C6),
`17`(durée0+hauteur23=C#4), `27`(durée0+hauteur39=F5), `17`(C#4à nouveau),
répétée. **Arpège décoratif rapide** (durée la plus courte, 1024) en
mode enveloppe (déclin percussif naturel) — un effet "scintillement" en
fond pendant que le canal 2 joue la mélodie.

Décodage cohérent de bout en bout : silence + mélodie lente + arpège
rapide décoratif, exactement la texture attendue d'un petit jingle de
game-over 3 canaux.

## Ce qui reste ouvert

- Le lien précis entre le test clavier (`fn_read_keyboard_row_raw`,
  ligne sondée = valeur de `var #0099`, toujours 1 au moment de l'appel)
  et le test joystick immédiatement après (`fn_read_joystick_table`) —
  le résultat du test clavier semble lu puis jamais explicitement
  combiné au flag `Z`/`NZ` testé ensuite ; articulation exacte non
  tracée (détail mineur, n'affecte pas le format du bytecode lui-même).
- 6 octets non expliqués à `#0C43-#0C48` (`5B 0D 01 0D F5 0C`, un
  triplet de pointeurs de canal qui RESSEMBLE à un 3e jeu de données
  jamais référencé par aucun site d'appel trouvé) — possible reliquat
  inutilisé, non vérifié plus avant.
- Second point d'entrée du flag `var #0099` (`#0A9B`, `XOR A` au lieu de
  `LD A,1`) : aucun appelant trouvé par recherche statique — code mort,
  ou point d'entrée réservé pour un futur appelant jamais écrit.

## Validation

Toutes les valeurs de table citées ci-dessus proviennent d'une lecture
RAM live directe (`GET /api/ram`), pas d'une supposition. Symboles
ajoutés à `asm/symbols.json`, régénération de
`asm/code/dispatch_and_sound.asm` (plage `#0A97-#0D66`), réassemblage
`rasm` + comparaison octet-à-octet contre la RAM live : **0 différence**
sur toute la plage décodée. Voir `docs/SYMBOLS.md` (`#0A97`, `#0AF3`,
`#0B1F`, `#0B5D`, `#0B65`, `#0B77`, `#0B7C`, `#0B81`, `#0B98`, `#0BA8`,
`#0C18`, `#0C1F`, `#0C26`) pour les entrées machine-readable
correspondantes.
