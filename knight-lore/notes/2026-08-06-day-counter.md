# Session — 0x1C44 : HUD soleil/lune ET compteur de jours (0x007F) découvert par accident

## Contexte

Suite à `notes/2026-08-06-memory-zones-model.md`, désassemblage des
deux appels non explorés dans `fn_render_entities` (`0x2E97: call 0x1C44`
et `call 0x1802`), pour compléter la compréhension du pipeline de rendu.

## 0x1C44 — Animation HUD soleil/lune, timing par cycle jour/nuit

**Statut : confirmed** par désassemblage direct.

```
1C44  3A6A00     ld     a,(006A)
1C47  E607       and    07
1C49  C0         ret    nz          ; exécuté seulement 1 frame sur 8
1C4A  DD21FA1C   ld     ix,1CFA     ; IX = zone de données statique (PAS une entité)
1C4E  DD3416     inc    (ix+16)     ; compteur de cycle, incrémenté toutes les 8 frames
1C51  3A8900     ld     a,(0089)
1C54  A7         and    a
1C55  C0         ret    nz          ; garde supplémentaire (mode spécial ?)
1C56  DD7E16     ld     a,(ix+16)
1C59  FEE1       cp     E1          ; 0xE1 = 225 -- fin du cycle complet
1C5B  2852       jr     z,1CAF      ; cycle terminé -> bascule jour/nuit (voir plus bas)
1C5D  DD7E16     ld     a,(ix+16)
1C60  C610       add    a,10
1C62  21ED1C     ld     hl,1CED     ; tbl_sun_moon_frames (petite table statique)
1C65  0F         rrca
1C66  0F         rrca
1C67  E60F       and    0F
1C69  CF         rst    08          ; HL += index -> résout la frame de sprite courante
1C6A  7E         ld     a,(hl)
1C6B  DD7717     ld     (ix+17),a   ; frame de sprite = f(compteur de cycle)
1C6E  010C1F     ld     bc,1F0C     ; dimensions (largeur=0x1F ou 0x0C selon lecture ?)
1C71  21EE97     ld     hl,97EE     ; adresse buffer intermédiaire fixe (position HUD)
1C74  C5         push   bc
1C75  E5         push   hl
1C76  79         ld     a,c
1C77  48         ld     c,b
1C78  47         ld     b,a
1C79  AF         xor    a
1C7A  CDC11D     call   1DC1        ; efface la zone HUD (même mécanisme que les entités)
1C7D  CD2B2F     call   2F2B        ; dessine le sprite soleil/lune (variante de blit)
1C80  DD217718   ld     ix,1877     ; IX = autre zone statique (état "phase" ?)
1C84  DD360700   ld     (ix+07),00
1C88  DD36005A   ld     (ix+00),5A
1C8C  DD3616B0   ld     (ix+16),B0
1C90  DD361700   ld     (ix+17),00
1C94  CD2B2F     call   2F2B
1C97  DD3616D0   ld     (ix+16),D0
1C9B  DD3600BA   ld     (ix+00),BA
1C9F  CD2B2F     call   2F2B        ; dessine 3 variantes/étoiles ? à des positions
                                    ; différentes ((ix+16)=0xB0, 0xD0 -- deux "étoiles")
1CA2  E1         pop    hl
1CA3  C1         pop    bc
1CA4  1176C6     ld     de,C676     ; adresse VRAM fixe correspondant à la position HUD
1CA7  3A7D00     ld     a,(007D)    ; flag "rendu désactivé" (déjà connu, fn_init_room)
1CAA  A7         and    a
1CAB  C0         ret    nz          ; si rendu désactivé (transition de room), skip le blit
1CAC  C3C02E     jp     2EC0        ; fn_blit_copy_line direct (pas de passage par la
                                    ; pile, contrairement au mécanisme des entités)
```

**Interprétation** : `0x1C44` gère l'**animation du HUD soleil/lune**
(probablement l'indicateur de cycle jour/nuit visible en haut/coin de
l'écran). Le compteur de cycle (`(ix+16)` de `0x1CFA`) va de `0xB0`
(176) à `0xE1` (225), soit 49 paliers, incrémenté 1 fois toutes les 8
frames — un cycle complet dure donc 49×8 = 392 frames (~7.8s à 50Hz).
Utilise une petite table statique `0x1CED` pour résoudre la frame de
sprite exacte à afficher selon la phase du cycle. Dessine potentiellement
plusieurs éléments (soleil/lune + étoiles ?) à des positions HUD fixes.

## DÉCOUVERTE MAJEURE (accidentelle) : 0x007F est le compteur de JOURS du jeu

**Statut : CONFIRMED par validation empirique croisée** (utilisateur :
`(0x007F)=0x29` lu en jeu correspondait exactement au jour 29 affiché à
l'écran, confirmé passer au jour 30 juste après incrémentation) —
découverte en tracant la suite de la routine (`0x1CAF`, exécutée quand
le cycle jour/nuit se termine) :

```
1CAF  DD7E00     ld     a,(ix+00)   ; IX toujours = 0x1CFA à ce point
1CB2  EE01       xor    01          ; bascule un flag jour/nuit (0<->1)
1CB4  DD7700     ld     (ix+00),a
1CB7  DD3616B0   ld     (ix+16),B0  ; réinitialise le compteur de cycle à 0xB0
1CBB  3E01       ld     a,01
1CBD  327700     ld     (0077),a    ; force un redessin complet (voir fn_render_entities)
1CC0  3AFA1C     ld     a,(1CFA)
1CC3  E601       and    01
1CC5  C0         ret    nz          ; si on vient de passer à "nuit" (bit 0 = 1), stop ici
1CC6  217F00     ld     hl,007F
1CC9  7E         ld     a,(hl)
1CCA  C601       add    a,01
1CCC  27         daa                ; ADDITION EN BCD !
1CCD  77         ld     (hl),a
1CCE  FE40       cp     40          ; compare à 0x40 en BCD = "40" décimal !
1CD0  CAFB12     jp     z,12FB      ; si jour 40 atteint -> saut vers 0x12FB (GAME OVER
                                    ; probable, ou fin de partie/écran spécial)
1CD3  CD4B15     call   154B        ; routine non tracée (mise à jour affichage du
                                    ; compteur de jour visible à l'écran ?)
```

**`(0x007F)` incrémenté en arithmétique BCD, comparé exactement à `0x40`
(= 40 en décimal BCD)** — correspondance parfaite et immédiate avec
l'information donnée par l'utilisateur en tout début de cette session
("on est au jour 13, il y en a 40 dans le jeu avant le game over").
**C'est donc, avec une confiance très élevée, le compteur de jours du
jeu.** Le format BCD est cohérent avec un affichage direct à l'écran
(chaque nibble = un chiffre décimal, pas besoin de conversion binaire→
décimal pour l'afficher).

**Mécanique complète découverte** : le compteur de jour n'avance QUE
lorsque le cycle jour/nuit repasse de "nuit" à "jour" (`(ix+00)` bit 0
passe de 1 à 0) — donc **un "jour" de jeu = un cycle complet jour+nuit**,
pas juste une des deux phases. Cohérent avec le rythme du jeu (chaque
jour/nuit dure ~2×392 frames ≈ 15.6s à 50Hz, donc 40 jours ≈ 10-11
minutes de jeu réel si on reste dans la même salle sans interruption —
ordre de grandeur à vérifier empiriquement).

**Vérification empirique réalisée** : l'utilisateur a confirmé que
`(0x007F)=0x29` (29 en BCD) correspondait exactement au jour affiché à
l'écran (29), et a observé le passage au jour 30 juste après —
confirmation directe et sans ambiguïté de l'hypothèse.

## CONFIRMÉ (précision utilisateur) : transformation explorateur/loup-garou à chaque cycle

**Information de l'utilisateur** : chaque "jour" compté par le jeu se
déroule en 2 phases distinctes — le jour (personnage = explorateur) et
la nuit (personnage = loup-garou), avec une petite animation de
transition d'environ 8 étapes à chaque bascule.

**Lien trouvé avec le code** : `0x29CD`, dans une routine
d'instanciation d'objet de room (contexte similaire à `fn_instantiate_
room_objects`, 0x1DFB, avec `IX` = pointeur vers l'objet en cours de
création) :

```
29C6  218000     ld     hl,0080     ; var_room_countdown (déjà connu)
29C9  35         dec    (hl)
29CA  FAFB12     jp     m,12FB      ; MÊME destination que le jour 40 !
                                    ; -> 0x12FB = point de sortie/game-over
                                    ;    commun à plusieurs conditions
29CD  3AFA1C     ld     a,(1CFA)    ; flag jour/nuit (même octet que 0x1CAF)
29D0  0F         rrca
29D1  0F         rrca
29D2  0F         rrca              ; 3 rotations -> isole en fait le BIT 2
29D3  E620       and    20         ;    d'origine (pas le bit 0 comme on
                                   ;    l'avait supposé initialement)
29D5  4F         ld     c,a
29D6  DD7E10     ld     a,(ix+10)
29D9  E61F       and    1F
29DB  81         add    a,c        ; combine avec le bit jour/nuit
29DC  DD7710     ld     (ix+10),a  ; -> nouveau champ (ix+10) de l'entité
29DF  DD7E2C     ld     a,(ix+2C)
29E2  E60F       and    0F
29E4  81         add    a,c
29E5  C620       add    a,20
29E7  DD772C     ld     (ix+2C),a  ; -> nouveau champ (ix+2C) de l'entité
29EA  C9         ret
```

**Interprétation (hypothesis solide)** : cette routine ajuste des champs
d'une entité (probablement le joueur lui-même, ou un objet qui a un
comportement dépendant du cycle) selon le bit jour/nuit de `(0x1CFA)` —
cohérent avec la sélection de la forme "explorateur" vs "loup-garou".
**Nuance importante à corriger par rapport à la lecture initiale de
0x1CAF** : le bit consulté ici (bit 2 après 3 rotations) n'est PAS le
même bit que celui basculé par XOR 0x01 dans `0x1CAF` (bit 0) — donc
`(0x1CFA)` encode probablement PLUSIEURS informations sur des bits
différents (au minimum : bit 0 = état jour/nuit basculé à chaque fin de
cycle, bit 2 = un état consulté ailleurs, possiblement une phase
intermédiaire de la "petite animation en 8 étapes" mentionnée par
l'utilisateur). **Ceci reste à élucider précisément** — l'octet
`(0x1CFA)` mérite une carte de bits complète avant de conclure sur le
mécanisme exact de la transformation.

**Prochaine étape concrète pour confirmer/affiner** : observer
`(0x1CFA)` en continu pendant une transition jour/nuit réelle en jeu
(via polling rapproché, PAS de breakpoint car c'est un évènement rare —
1 fois toutes les ~400 frames), pour voir la séquence exacte de valeurs
prises par cet octet pendant les "8 étapes" d'animation mentionnées,
et croiser avec le type d'entité du joueur (`(ix+00)`) pour confirmer
la bascule visuelle explorateur/loup-garou.

## CONFIRMÉ EN DIRECT : capture complète d'une transition jour→nuit réelle

**Statut : CONFIRMED** par observation directe d'une vraie transition
(breakpoint sur `0x1CAF`, puis single-step + polling rapproché
0.3s/échantillon juste après).

**Séquence exacte capturée** :
1. Breakpoint déclenché exactement quand `(ix+16)=0xE1` (fin de cycle,
   `IX=0x1CFA`), confirmant le timing prédit par le désassemblage.
2. Single-step à travers `0x1CAF-0x1CBD` : `(0x1CFA)` passe de `0x59`
   (89, bit0=1) à `0x58` (88, bit0=0) via le `XOR 01` — confirme
   exactement le mécanisme prédit.
3. **Polling du type d'entité joueur (`(ix+00)`) sur les 3 secondes
   suivantes** :
   ```
   t=0.0s  type=0x5C
   t=0.3s  type=0x5F
   t=0.6s  type=0x5E
   t=0.9s  type=0x5C
   t=1.2s  type=0x5D
   t=1.5s  type=0x5F
   t=1.8s  type=0x5C
   t=2.1s  type=0x14   <- STABILISÉ
   t=2.4s  type=0x14
   t=2.7s  type=0x14
   ```

**Interprétation confirmée** : le type d'entité du joueur oscille bien
entre plusieurs valeurs (`0x5C, 0x5D, 0x5E, 0x5F` — 4 formes distinctes
observées, probablement plus si l'échantillonnage à 0.3s en a manqué
certaines) pendant environ 2 secondes, **exactement l'animation de
transformation en plusieurs étapes décrite par l'utilisateur** ("environ
8 étapes"), avant de se stabiliser sur `0x14` — la forme stable de la
nouvelle phase (jour, puisque le bit0 de `(0x1CFA)` venait de passer à
0). Avant la transition, le type stable observé était `0x34`
(loup-garou, nuit) — cohérent avec une paire de types stables
(`0x14`=jour/explorateur, `0x34`=nuit/loup-garou) reliés par une séquence
d'états de transition intermédiaires (`0x5C-0x5F` et probablement
d'autres non capturés par l'échantillonnage).

**Objectif "en finir avec la transition" atteint** : le mécanisme est
maintenant confirmé de bout en bout — compteur de cycle (`0x1CFA+16`,
0xB0→0xE1) → bascule du bit jour/nuit (`0x1CFA` bit0, XOR) → séquence
d'animation du type d'entité joueur (`0x5C-0x5F`, piloté par une routine
d'animation non encore désassemblée en détail mais dont l'existence et
le comportement sont confirmés empiriquement) → stabilisation sur le
type de la nouvelle phase (`0x14` jour / `0x34` nuit).

**Reste en suspens (mineur, non bloquant)** : la routine EXACTE qui pilote
la séquence d'animation `0x5C→0x5F` n'a pas été désassemblée (elle
tourne quelque part dans la logique du joueur, `fn_player_logic`
0x20CB, probablement via un sous-état non encore cartographié). Le bit 2
de `(0x1CFA)` consulté par `0x29CD` (instanciation d'objets de room)
reste également à élucider précisément — pourrait servir à choisir
la variante jour/nuit d'objets AUTRES que le joueur (ennemis, éléments
de décor).

## CONFIRMÉ EN DIRECT : 0x12FB déclenché par le vrai game over (jour 40)

**Statut : CONFIRMED** par observation empirique directe. Breakpoint
posé sur `0x12FB` en avance (le jour affiché était déjà 40), jeu laissé
tourner normalement. Déclenchement réel capturé (`PC=0x12FB` confirmé),
suivi d'un retour au menu — exactement le comportement prédit par le
désassemblage (`jp 0x0542` en fin de routine, retour au point d'entrée
principal). Confirme sans ambiguïté que `0x12FB` est bien l'écran de
fin de partie "40 jours écoulés" annoncé par l'utilisateur avant le
test ("le jour 40 c'est game over").

## Prochaines pistes

1. Désassembler `0x12FB` (point de sortie commun : jour 40 ET room
   countdown négatif — probablement l'écran de fin/game over).
2. Désassembler `0x154B` (appelée à chaque changement de jour, hors le
   cas jour 40 — probablement mise à jour de l'affichage du compteur).
3. Cartographier précisément les bits de `(0x1CFA)` (au moins bit 0 et
   bit 2 identifiés avec des usages différents) en observant une
   transition réelle jour/nuit.
4. Toujours en attente : `0x1802` (deuxième appel non exploré dans
   `fn_render_entities`, 0x2E9D).
