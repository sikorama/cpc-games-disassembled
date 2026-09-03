# Session 2026-08-07 (suite) — Le son de l'animation de transformation : moteur d'effets sonores identifié

Suite immédiate de `2026-08-07-transformation-animation.md` : l'utilisateur
a rappelé que l'animation de transformation jour/nuit s'accompagne d'un
son — piste laissée ouverte ("rôle exact du buffer 0x0A6E->0x00A3 non
élucidé"). Résolu par désassemblage : c'est un **moteur d'effets sonores
PSG à 3 canaux**, pas un simple buffer graphique.

## Découverte : moteur son 3 canaux (base 0x009B)

`0x08BE`/`0x08C3` (déjà repérées comme "LDIR 4 octets", rôle non
élucidé) sont en fait les points d'entrée pour **armer un canal de
son** : elles copient un descripteur de 4 octets (pointeur vers une
séquence de commandes son + état) vers un slot fixe :

```
0x009B  canal 0 (slot A, 4 octets)
0x009F  canal 1 (slot B, 4 octets)   -- déduit par calcul d'offset, non vérifié séparément
0x00A3  canal 2 (slot C, 4 octets)   -- CONFIRMÉ : celui utilisé par la transformation
```

`0x08BE` (DE=0x00A3, donc canal 2) / `0x08C3` (DE=0x009B, canal 0) font
`LDIR BC=4` depuis `HL` (le descripteur son passé par l'appelant) vers
le slot. **C'est exactement l'appel fait par `fn_player_transform_tick`
(0x1BFC) : `LD HL,0x0A6E / CALL 0x08BE`** — arme le canal 2 avec la
séquence sonore commençant à `0x0A6E`, rejoué à chaque tick de
l'animation (throttlé 1 frame/4, comme le reste de l'effet visuel).

### `0x08CC`-`0x08E7` — Boucle de tick des 3 canaux, appelée PAR L'INTERRUPTION VSYNC

**Découverte clé** : cette boucle n'est PAS appelée depuis la boucle de
jeu (0x05AE) mais **depuis le handler d'interruption IM1** (`0x0038`,
vecteur RST 0x38 standard Z80/CPC, déclenché à 300Hz par le Gate
Array — 6 fois par frame vidéo) :

```
0038  PUSH AF/BC/DE/HL/IY
003E  CALL 08CC     ; <<< tick du moteur son, ICI, indépendant du framerate logique
0041+ POP IY/HL/DE/BC/AF ; EI ; RET
```

```
08CC  LD IY,009B          ; canal 0
08D0  LD L,(IY+00)        ; octet 0 du slot = index/état courant
08D3  LD BC,08E8          ; table de dispatch (0x08E8, 8 entrées word)
08D6  RST 28              ; HL = table[L], JP (HL) -- dispatch par état du canal
08D7  LD DE,0004
08DA  ADD IY,DE           ; canal suivant (+4 octets)
08DF  LD DE,00A7          ; borne de fin = juste après le 3e slot (0x00A3+4)
08E2  SBC HL,DE ; JR C,08D0  ; boucle sur les 3 canaux (0x9B, 0x9F, 0xA3)
```

**`tbl_sound_dispatch` (0x08E8)**, 8 entrées word, indexée par l'octet 0
de chaque slot canal (état du canal : 0=idle, 1..7=étapes de lecture de
la séquence) :

| Index | Cible | Rôle (désassemblage direct) |
|---|---|---|
| 0 | 0x0895 | `RET` — canal idle, rien à faire |
| 1 | 0x0992 | Étape complexe : avance la lecture de la séquence (`0x094E`/`0x090B`), calcule une durée/enveloppe, écrit un registre PSG |
| 2 | 0x09B0 | Avance canal (`0x0908`), résout une fréquence via table `HL=(a<<1)+0x0100` (`0x0A7B`) |
| 3 | 0x09CB | Similaire, avec lecture d'un octet supplémentaire depuis `(0x00D8)` |
| 4 | 0x0A33 | Avance canal, lit `(iy+03)` comme index direct de fréquence |
| 5 | 0x0A5E | Avance canal, `RLCA×2` puis `XOR 0xA0` — variante de calcul de fréquence |
| 6 | 0x0A72 | Avance canal, `RLCA×4` — encore une variante (glissando/vibrato ?) |
| 7 | 0x0A4B | Avance canal, combine `(iy+02)` et `(iy+03)` comme word — fréquence 16 bits directe |

Chaque variante finit par écrire dans les registres PSG via
**`0x0D8C`/`0x0DA7`** (deux routines quasi-identiques, l'une pour le
canal courant "fréquence fine", l'autre "fréquence + octave/volume") :

```
0D8C  LD BC,F700 / LD A,82 / OUT (C),A     ; sélectionne le registre PSG n°2 (période canal C, low)
      LD BC,F400 / OUT (C),E              ; écrit E dans le registre sélectionné (port data)
      LD BC,F600 / LD A,D / AND 3F / OR C0 / OUT (C),A  ; sélectionne reg 3 (période C, high)
      AND 3F / OUT (C),A                  ; écrit le nibble haut (D&0x3F) au port latch/select
      RET
```

**Ports `0xF400`/`0xF600`/`0xF700` = les trois ports d'accès au PSG
AY-3-8912 du CPC** (déjà connus comme `fn_psg_port_write_a/b`,
`fn_psg_select_and_read` dans `SYMBOLS.md`, jusqu'ici documentés
seulement pour le SCAN CLAVIER — nouvelle preuve qu'ils sont réutilisés
tels quels pour la MUSIQUE/SFX, cohérent avec le multiplexage
clavier/PSG classique du CPC via le même port de sélection).

## Séquence de données `0x0A6E` (rejouée par la transformation)

```
0A6E: 06 1F 00 00 CD 08 09 07 07 07 07 18 EA E5 CD F8
```
Décodage cohérent avec le format "programme" consommé par
`tbl_sound_dispatch` : `06 1F` = état initial du slot canal (octet 0 =
0x06 -> index 6 dans `tbl_sound_dispatch` = 0x0A72, l'entrée "RLCA×4" ;
octet 1 = 0x1F = compteur de répétition/durée initial pour
`0x090B`/`dec (iy+01)`). Les octets suivants ressemblent à du CODE Z80
valide (`CD 08 09` = `CALL 0908`, etc.) plutôt qu'à une table de
paramètres pure — **cohérent avec les autres entrées de la table
0x08E8 qui contiennent elles-mêmes du code exécutable inline** (voir
`0x09A6`/`0x09BD`, qui font `LD HL,<adresse suivante> / JP 0x08C3` —
un modèle de "programme sonore auto-avançant", où chaque commande finit
par ré-armer le canal avec le pointeur de la commande suivante).
**Hypothesis** : `0x0A6E` n'est pas juste "4 octets de descripteur"
mais le DÉBUT d'un petit programme sonore complet, dont seuls les 4
premiers octets sont copiés tels quels dans le slot (format slot =
`[état][compteur][ptr_lo][ptr_hi]` probablement), le reste (`0x0A72+`)
étant le code exécuté par le dispatch aux itérations suivantes une fois
l'état initialisé à 6.

## Statut

**CONFIRMED** : existence et mécanisme général du moteur son 3 canaux
piloté par interruption (fréquence de tick indépendante de la boucle de
jeu, 300Hz Z80/CPC standard mais throttlé en pratique par les
compteurs `(iy+01)` de chaque état), confirmé par désassemblage direct
+ traçage des ports PSG réels (`0xF400/0xF600/0xF700`, déjà connus du
scan clavier). **CONFIRMED** que la transformation arme le canal 2 avec
la séquence `0x0A6E` via `fn_player_transform_tick` (0x1BFC), rejouée
à chaque tick throttlé (1 frame/4) tant que l'animation dure — explique
directement le son entendu par l'utilisateur pendant la transformation
(un effet sonore répétitif type "trille/vibrato", cohérent avec
l'entrée `0x0A72` = "RLCA×4", une transformation de fréquence par
rotation de bits, technique 8-bit classique pour un glissando cheap).

**hypothesis (non vérifiée empiriquement par écoute/mesure PSG en
direct)** : le détail exact de la note/du timbre produit — nécessiterait
un test comportemental (poser un breakpoint sur `0x0D8C` pendant une
vraie transformation en jeu, lire E/D à chaque hit pour reconstituer la
fréquence PSG réelle jouée, cf. METHODOLOGY.md §7bis) — non fait cette
session, le désassemblage statique suffisant pour répondre à la
question posée ("d'où vient le son ?").

## Mise à jour SYMBOLS.md

Nouvelles entrées : `fn_sound_engine_tick` (0x08CC), `tbl_sound_dispatch`
(0x08E8), `fn_psg_write_period_low` / `fn_psg_write_period_full`
(0x0D8C / 0x0DA7 — précisent le rôle déjà connu de ces adresses),
`struct_sound_channel_slot` (base 0x009B, 3× 4 octets), et référence
croisée dans l'entrée `fn_player_transform_tick` (0x1BE1) pour signaler
qu'elle arme le canal 2 via `0x0A6E`/`0x08BE`.

## Prochaines pistes (son)

1. Vérifier si d'autres événements de jeu (collision, saut, ramassage
   d'objet) arment aussi un des 3 canaux — chercher tous les appelants
   de `0x08BE`/`0x08C3` (un seul trouvé pour l'instant : la
   transformation) et tous les `LD HL,0x....  / CALL 0x08BE`-like dans
   le reste du binaire.
2. Décoder complètement le format d'un "programme sonore" (voir
   hypothesis ci-dessus) en comparant plusieurs séquences connues côte
   à côte, une fois qu'on en aura identifié au moins 2-3 différentes.
3. Test comportemental optionnel : breakpoint sur `0x0D8C` pendant une
   transformation réelle pour capturer la fréquence PSG exacte jouée.
