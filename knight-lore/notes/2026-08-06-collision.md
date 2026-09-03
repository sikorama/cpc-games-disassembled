# Session — Analyse de la collision (0x2750)

## Contexte

Routine de collision entre entités, déjà repérée dans une session
précédente (`notes/2026-08-06-rendering-engine.md`) mais pas
complètement désassemblée. Reprise ici en entier
(`0x2750` à `0x2892`).

## Structure d'ensemble

**Statut : confirmed** (désassemblage direct complet).

```
2750  AF         xor    a
2751  328400     ld     (0084),a    ; accumulateur remis à 0 (compteur de collisions ?)
2754  DDE5       push   ix
2756  FDE5       push   iy
2758  112027     ld     de,2720     ; DE = curseur externe dans le buffer d'entités
                                    ; (RÉUTILISE 0x2720, le même buffer par-frame
                                    ; que le culling de rendu -- confirme que la
                                    ; collision ne teste QUE les entités déjà
                                    ; retenues comme visibles/actives ce tour)
; --- boucle externe : IX parcourt les entités ---
275B  1A         ld     a,(de)
275C  13         inc    de
275D  FEFF       cp     FF
275F  CAAA28     jp     z,28AA      ; fin de liste -> sortie globale
2762  CB7F       bit    7,a
2764  20F5       jr     nz,275B     ; bit 7 posé -> entité ignorée (déjà traitée ?)
2766  CD222C     call   2C22        ; résout index -> pointeur structure (IX)
2769  ED539200   ld     (0092),de   ; sauvegarde le curseur externe
276D  E5         push   hl
276E  DDE1       pop    ix

; --- boucle interne : IY parcourt les entités RESTANTES (à partir d'où IX est) ---
2770  1A         ld     a,(de)
2771  13         inc    de
2772  FEFF       cp     FF
2774  CA9528     jp     z,2895      ; fin de liste interne -> passe à l'entité IX suivante
2777  CB7F       bit    7,a
2779  20F5       jr     nz,2770
277B  CD222C     call   2C22        ; résout index -> pointeur structure (IY)
277E  ED539400   ld     (0094),de
2782  E5         push   hl
2783  FDE1       pop    iy

2785  DDE5       push   ix
2787  C1         pop    bc
2788  A7         and    a
2789  ED42       sbc    hl,bc       ; teste si IX == IY (même entité)
278B  28E3       jr     z,2770      ; oui -> ignore, entité suivante interne
```

## Calcul du code de collision AABB 3D (0x278D-0x27F7)

**Statut : confirmed** par désassemblage direct, **hypothesis** sur
l'interprétation précise des axes.

Teste le chevauchement des bounding boxes de IX et IY sur (au moins) 3
paires de champs : `(±03,±06)`, `(±02,±05)`, `(±01,±04)` — cohérent avec
une bounding box 3D définie par 3 paires (position, taille) par axe :
`(ix+01)/(ix+04)`, `(ix+02)/(ix+05)`, `(ix+03)/(ix+06)`.

```
278D  0E00       ld     c,00        ; C = code de collision (accumulateur)

; --- Axe "03" (probablement Z / hauteur ?) ---
278F  FD7E03     ld     a,(iy+03)
2792  FD8606     add    a,(iy+06)   ; (iy+03)+(iy+06) = bord max de IY
2795  6F         ld     l,a
2796  DD7E03     ld     a,(ix+03)
2799  95         sub    l           ; (ix+03) - bord_max_iy
279A  300F       jr     nc,27AB     ; si >= 0 (pas de chevauchement par ce côté) -> suite
279C  DD7E03     ld     a,(ix+03)
279F  DD8606     add    a,(ix+06)   ; bord max de IX
27A2  6F         ld     l,a
27A3  FD7E03     ld     a,(iy+03)
27A6  95         sub    l           ; (iy+03) - bord_max_ix
27A7  3801       jr     c,27AA      ; si < 0 -> chevauchement confirmé sur cet axe
27A9  0C         inc    c
27AA  0C         inc    c           ; incrémente C (poids différent selon le sens)

; --- Axe "02" (probablement Y) --- (même schéma, poids ±3)
27AB..27D0: compare (iy+02)+(iy+05) vs (ix+02)-(ix+05), ajuste C de ±3

; --- Axe "01" (probablement X) --- (même schéma, poids ±9)
27D1..27F6: compare (iy+01)+(iy+04) vs (ix+01)-(ix+04), ajuste C de ±9

27F7  69         ld     l,c         ; L = code final de collision (0-~29)
27F8  01FE27     ld     bc,27FE     ; table de dispatch, base 0x27FE
27FB  C32800     jp     0028        ; RST 28 générique : HL=L*2+BC puis JP (HL)
```

**Interprétation** : c'est un test de collision **AABB 3D** classique
(comparaison des 6 faces de deux boîtes alignées sur les axes), avec un
**codage composite du résultat** en un seul nombre (poids ±1 pour l'axe
"03", ±3 pour l'axe "02", ±9 pour l'axe "01" — base 3 déguisée,
`1+3+9=13`, cohérent avec un système à 3 états par axe : "avant/dedans/
après" façon ternaire). Ce code sert ensuite d'index dans une table de
dispatch (`RST 28`), donc chaque combinaison possible de
chevauchement/non-chevauchement sur les 3 axes a son propre traitement.

## Table de dispatch (0x27FE-0x2833) — ~30 entrées

**Statut : confirmed** par désassemblage direct. Table de `JR Z,<cible>`
compactée (chaque entrée fait 2 octets, `28 XX`), pointant vers un petit
nombre de gestionnaires distincts partagés entre plusieurs codes :
`0x2835`, `0x2837`, `0x283A`, `0x283D`, `0x2841`, `0x2843`, `0x2845`,
`0x2847`, `0x284A`, `0x284C`, `0x2851`, `0x2852`, `0x2855`, `0x2857`,
`0x2859`, `0x285C`, `0x285D`, `0x285E`, `0x2862`, `0x2863`, `0x2864`,
`0x2865`, `0x2867`, `0x288F`. Beaucoup de codes partagent la même
destination — cohérent avec le fait que plusieurs combinaisons d'axes
donnent le même verdict final ("pas de collision" vs "collision
détectée, traiter").

## Gestionnaires de collision (0x2835-0x2892)

**Statut : confirmed** par désassemblage direct, **hypothesis** sur le
sens métier.

```
2835  70         ld     (hl),b
2836  27         daa            ; séquence bizarre (DAA après LD (HL),B) --
                                ; probablement pas du vrai code, artefact
                                ; de lecture linéaire à la frontière
                                ; table-de-sauts/code réel -- À VÉRIFIER,
                                ; ne pas prendre pour argent comptant
2837  C37027     jp     2770    ; "pas de collision" -> continue la boucle interne

283A  2A9400     ld     hl,(0094)   ; relit le pointeur IY sauvegardé
283D  2B         dec    hl
283E  4E         ld     c,(hl)      ; C = octet juste avant la structure IY
                                    ; (l'INDEX de l'entité IY dans la liste, pas
                                    ; son pointeur -- car 0x2C22 avance le curseur
                                    ; après avoir lu l'index)
283F  11AF28     ld     de,28AF     ; table de "paires déjà traitées"
2842  1A         ld     a,(de)
2843  FEFF       cp     FF
2845  2806       jr     z,284D      ; case vide trouvée -> enregistre
2847  B9         cp     c
2848  2819       jr     z,2863      ; déjà enregistré -> traite la collision (2863)
284A  13         inc    de
284B  18F5       jr     2842        ; sinon continue à chercher dans la table

284D  79         ld     a,c
284E  12         ld     (de),a      ; enregistre l'index de IY comme "en attente"
284F  13         inc    de
2850  3EFF       ld     a,FF
2852  12         ld     (de),a      ; marqueur de fin après l'entrée ajoutée
2853  FDE5       push   iy
2855  DDE1       pop    ix          ; IX <- IY (bascule de rôle ?)
2857  2A9400     ld     hl,(0094)
285A  229200     ld     (0092),hl   ; le curseur externe reprend là où était IY
285D  112027     ld     de,2720
2860  C37027     jp     2770        ; relance la boucle interne depuis le début
                                    ; de la liste, avec ce nouveau "IX"

2863  212027     ld     hl,2720     ; --- collision confirmée deux fois : traite ---
2866  7E         ld     a,(hl)
2867  23         inc    hl
2868  FEFF       cp     FF
286A  CA5827     jp     z,2758      ; parcourt la liste pour retrouver IY par son index
286D  B9         cp     c
286E  20F6       jr     nz,2866
2870  FDE5       push   iy
2872  DDE1       pop    ix          ; IX <- IY (l'entité trouvée devient le "IX" courant)
2874  1822       jr     2898        ; (adresse non désassemblée ici -- à explorer)

2876  DD7E00     ld     a,(ix+00)   ; --- gestionnaire de collision "effective" ---
2879  D660       sub    60
287B  FE07       cp     07
287D  3006       jr     nc,2885
287F  DD3600BB   ld     (ix+00),BB  ; si (ix+00)-0x60 < 7 : remplace le TYPE par 0xBB
2883  180D       jr     2892
2885  FD7E00     ld     a,(iy+00)   ; sinon teste IY de la même façon
2888  D660       sub    60
288A  FE07       cp     07
288C  3004       jr     nc,2892
288E  FD3600BB   ld     (iy+00),BB  ; remplace le type de IY par 0xBB
2892  C37027     jp     2770        ; continue la boucle interne
```

**Interprétation d'ensemble (hypothesis raisonnable)** :

- La collision détectée une PREMIÈRE fois enregistre la paire comme "en
  attente" (table `0x28AF`, terminée par 0xFF) et échange les rôles
  IX/IY pour continuer le parcours — probablement pour laisser à
  d'autres entités la chance d'interagir avec IY avant de "committer" la
  collision.
- Si la MÊME paire est détectée une deuxième fois (rencontrée à nouveau
  dans une itération ultérieure), la collision est **traitée pour de
  bon** — passage à `0x2863` puis probablement `0x2876`.
- **`0x2876` est le gestionnaire d'effet de collision** : teste si
  `(type - 0x60) < 7` (donc un type dans la plage `0x60-0x66`, 7 valeurs
  — cohérent avec 7 variantes d'un même objet, ex: un bloc empilable sur
  7 hauteurs) et si oui, **remplace le type par `0xBB`** — transformation
  d'état classique en cas de collision (ex: un bloc qui "se casse", un
  objet ramassé qui disparaît/change d'apparence, ou un mécanisme de
  poussée de bloc typique de Knight Lore).

**Cohérence avec le jeu réel** : Knight Lore a des mécaniques de blocs
empilables/poussables et d'objets à ramasser — un système "7 variantes
d'un type → transformation en 0xBB au contact" est tout à fait cohérent
avec un bloc qui change de hauteur/état quand on marche dessus, ou un
piège qui se déclenche.

## Prochaines pistes

1. **Vérifier empiriquement** : positionner deux entités (le joueur et
   un bloc de type 0x60-0x66) pour qu'elles se chevauchent (via
   `ram_write` sur leurs coordonnées), observer si le type du bloc
   devient bien `0xBB` et si un changement visuel apparaît à l'écran.
2. **Désassembler 0x2898** (suite du gestionnaire après `0x2874`, pas
   encore vue).
3. **Identifier ce qu'est le type `0xBB`** — dumper sa forme via la
   table `0x429E` et comparer visuellement.
4. Clarifier le motif bizarre en `0x2835-0x2836` (`LD (HL),B` / `DAA`)
   — probablement une fausse lecture de frontière code/table, à
   revérifier avec `disassemble` isolé sur cette toute petite plage.

## Outils / méthode

- Désassemblage direct large (`disassemble_range` sur toute la routine
  d'un coup) plutôt que par petits bouts — a permis de voir la structure
  complète (boucle imbriquée + calcul de code + dispatch + gestionnaires)
  en une seule passe, cohérent avec la méthodologie ("remonter jusqu'au
  vrai début, désassembler large").
