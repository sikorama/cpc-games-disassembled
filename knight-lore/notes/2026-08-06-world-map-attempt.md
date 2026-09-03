# Session — Tentative de décodage de la carte du monde (0x33DD/0x33D4)

## Contexte

Suite à la découverte du mécanisme de transition de salle
(`notes/2026-08-06-room-navigation.md`), tentative de dumper et décoder
`tbl_room_master_index` (0x33DD) et `tbl_room_master_coords` (0x33D4)
pour extraire directement la carte complète du monde sans navigation
manuelle — dans l'esprit de l'outil de cartographie automatique
envisagé par l'utilisateur.

## Ce qui est confirmé

**Format d'entrée de `tbl_room_master_index` (0x33DD)** : `[room_id: u8]
[skip_len: u8] [payload: skip_len octets]`, consommé par
`fn_load_room_data` (0x2C3A) via une recherche linéaire (compare
`room_id` à `(ix+08)`, sinon avance de `skip_len` octets via `RST 08`).

**Vérifié par parsing complet** : 128 entrées, consomment EXACTEMENT
tout l'espace disponible entre `0x33DD` et la limite `0x3D5D` codée en
dur dans la routine (`LD BC,3D5D`) — aucun octet de reste, forte
confirmation que le format `[room_id][skip_len][payload]` est correct.

**IDs de room** : 128 valeurs uniques, dispersées dans la plage 0-255
(pas contiguës) — cohérent avec un identifiant de room sur un octet
plein, où seules 128 valeurs sont effectivement utilisées par le jeu.

**Structure du payload** : premier octet = `field_byte`, dont les bits
3-7 (`field_byte >> 3`) indexent `tbl_room_master_coords` (0x33D4, 3
entrées de 3 octets seulement — donc index 0/1/2, jamais plus, vérifié
sur les 128 entrées). Le reste du payload contient une sous-liste
d'octets jusqu'à un `0xFF`, puis une suite après ce `0xFF` (non
entièrement désassemblée — la routine continue après `0x2C90` vers une
table `0x3E6E`, jamais explorée).

## Tentative infructueuse : interpréter la sous-liste comme un graphe de voisinage

**Hypothèse testée** : les octets entre le `field_byte` et le `0xFF`
sont des `room_id` de salles adjacentes (un graphe de connexions
directes).

**Test de cohérence effectué** (pas de vision requise — uniquement du
traitement de données) :
- Extraction du graphe dirigé pour les 128 rooms.
- **Test de symétrie** : si la salle A liste B comme "avant FF", B
  devrait généralement lister A en retour (relation de porte/passage
  bidirectionnelle, cohérent avec la mécanique de `fn_room_transition`
  qui permet d'aller et venir entre salles voisines). Résultat : **sur
  360 arêtes dirigées, seulement ~2.2% sont symétriques** — écart
  massif par rapport à ce qu'on attendrait d'un vrai graphe de voisinage
  physique.
- **Test de connectivité** (parcours en largeur depuis la room 0) :
  seulement **6 salles sur 128 sont atteignables** depuis la room 0 en
  suivant ces arêtes — très loin de la centaine de salles qu'on
  attendrait d'un monde jouable cohérent (avec 40 "jours" de jeu et une
  progression linéaire ou semi-linéaire, on s'attendrait à un graphe
  bien plus connecté).

**Conclusion honnête : l'hypothèse "avant_FF = liste de voisins directs"
est probablement FAUSSE**, ou à tout le moins incomplète. Le fichier
`/tmp/room_graph.json` généré est un artefact de test, **PAS une carte
valide du jeu** — à ne pas réutiliser tel quel.

## Pistes pour la suite

1. **Désassembler la suite de `fn_load_room_data` après 0x2C90**
   (`0x2C92+`, table `0x3E6E`) — c'est très probablement là que se
   trouve la vraie logique d'interprétation du payload après le `0xFF`,
   qu'on n'a pas encore vue. Le graphe de connexions réel est peut-être
   encodé différemment (ex: par direction explicite N/S/E/O plutôt que
   par simple liste, ou nécessitant une résolution supplémentaire via
   `0x3E6E`).
2. **Revoir `tbl_room_connections` (0x0147)**, peuplée dynamiquement à
   l'entrée dans chaque room — dumper son contenu EN JEU (pas
   statiquement) pour une salle donnée, et comparer avec les octets du
   payload trouvé pour cette même room dans `0x33DD`. Ça permettra de
   voir la correspondance exacte entre "table statique brute" et "table
   de connexions active", actuellement seulement supposée.
3. **Ne pas conclure trop vite** : le format à 3 valeurs de coordonnées
   (`idx=0/1/2`, seulement 3 combinaisons observées) suggère que
   `tbl_room_master_coords` encode peut-être un **type de zone/secteur**
   plutôt que des coordonnées X/Y précises par salle — à netoyer/vérifier
   une fois le format complet compris.
4. Une fois le format vraiment compris, régénérer le graphe et refaire
   les mêmes tests de cohérence (symétrie, connectivité) avant de le
   considérer fiable — ne jamais publier une carte non vérifiée par ce
   type de test croisé.

## RÉSOLU (partiellement) : le vrai mécanisme de connexion (0x2C92-0x2D5B)

**Statut : confirmed** sur la structure de flux (désassemblage direct),
**hypothesis** sur le calcul exact des champs de sortie — la sous-liste
"before_ff" que j'avais essayé de lire directement comme des `room_id`
(tentative invalidée ci-dessus) est en réalité une **liste d'INDEX vers
une troisième table (`0x3D5D`)**, chaque index désignant une entrée de
connexion détaillée (pas un simple ID de salle voisine).

```
2CBA  05         dec    b
2CBB  FDE5       push   iy
2CBD  D5         push   de
2CBE  FDE1       pop    iy          ; IY = curseur d'écriture dans tbl_room_connections (0x0147)
2CC0  7E         ld     a,(hl)      ; lit l'octet courant de la sous-liste (avant 0xFF)
2CC1  E607       and    07
2CC3  3C         inc    a
2CC4  4F         ld     c,a         ; C = compteur (valeur du champ +1, 1 à 8)
2CC5  7E         ld     a,(hl)
2CC6  23         inc    hl
2CC7  05         dec    b
2CC8  56         ld     d,(hl)
2CC9  23         inc    hl
2CCA  E5         push   hl
2CCB  0F         rrca
2CCC  0F         rrca
2CCD  E63E       and    3E          ; masque -> index PAIR (table de pointeurs word)
2CCF  215D3D     ld     hl,3D5D     ; <-- LA table qu'on cherchait (limite haute de
                                    ;     tbl_room_master_index -- adjacente, même
                                    ;     motif que tbl_object_catalog/tbl_sprite_dispatch)
2CD2  CF         rst    08          ; HL = 0x3D5D + index -> pointeur vers l'entrée
2CD3  7E         ld     a,(hl)
2CD4  23         inc    hl
2CD5  66         ld     h,(hl)
2CD6  6F         ld     l,a         ; HL = déréférence le pointeur lu (word, LE)
2CD7  E5         push   hl
2CD8  7E         ld     a,(hl)
2CD9  23         inc    hl
2CDA  FD7700     ld     (iy+00),a   ; copie le champ +00 vers tbl_room_connections
2CDD..2CEE : copie aussi +04, +05, +06, +07 (mêmes offsets que tbl_room_connections)
2CF1  DD7E08     ld     a,(ix+08)
2CF4  FD7708     ld     (iy+08),a   ; +08 = room_id COURANT (pas la cible)
2CF7..2D2E : calcule (iy+01), (iy+02) [code de direction, cf. constantes 0xC8/
             0x51/0xAE/0x37 de fn_room_transition] et (iy+03) [NOUVEAU NUMÉRO
             DE ROOM CIBLE, = (0x0074) + terme dérivé -- même offset que celui
             lu par fn_resolve_neighbor_room, 0x2C16]
2D31  C5         push   bc
2D32  010900     ld     bc,0009
2D35  FD09       add    iy,bc       ; IY += 9 -- INCOHÉRENCE avec les 0x38=56
                                    ; octets/entrée lus par fn_resolve_neighbor_room :
                                    ; soit plusieurs sous-enregistrements de 9 octets
                                    ; composent une entrée de 56, soit une des deux
                                    ; tailles est mal interprétée -- À RÉSOUDRE
2D37  0613       ld     b,13
2D39  FD360000   ld     (iy+00),00
2D3D  FD23       inc    iy
2D3F  10F8       djnz   2D39        ; efface 0x13=19 octets après chaque entrée
2D41  C1         pop    bc
2D42  7E         ld     a,(hl)      ; teste l'octet suivant du pointeur déréférencé
2D43  A7         and    a
2D44  2092       jr     nz,2CD8     ; non-nul -> une entrée liée supplémentaire suit
2D46  D1         pop    de
2D47  E1         pop    hl
2D48  05         dec    b
2D49  280B       jr     z,2D56      ; toutes les valeurs de C consommées -> fin
2D4B  0D         dec    c
2D4C  CAC02C     jp     z,2CC0      ; sinon, octet suivant de la sous-liste
2D4F  7E         ld     a,(hl)
2D50  23         inc    hl
2D51  E5         push   hl
2D52  EB         ex     de,hl
2D53  57         ld     d,a
2D54  1881       jr     2CD7        ; itère sur plusieurs entrées liées
2D56  FDE5       push   iy
2D58  D1         pop    de
2D59  FDE1       pop    iy
2D5B  C3542C     jp     2C54        ; retour à fn_load_room_data
```

**Confirmation de la bonne intuition sur le test de cohérence** : le
test de symétrie/connectivité de la section précédente avait
correctement détecté que l'hypothèse "before_ff = room_id direct" était
fausse — la vraie relation demande un niveau d'indirection
supplémentaire (index → pointeur → entrée déréférencée) qu'une lecture
statique linéaire ne révèle pas facilement.

## CORRECTION IMPORTANTE : le test `JR Z` était mal interprété

**Erreur trouvée et corrigée** grâce à un test empirique réel (transition
de salle observée en jeu, room 0x44→0x43 confirmée par
`(ix+08)` avant/après un déplacement par vrais appuis de touches — PAS
par `ram_write`, qui avait précédemment corrompu l'état d'une entité).

```
2C8C  7E         ld     a,(hl)
2C8D  23         inc    hl
2C8E  FEFF       cp     FF
2C90  2828       jr     z,2CBA      ; saute à 0x2CBA SI L'OCTET LU EST 0xFF
```
**J'avais inversé cette condition dans la note précédente** — le chemin
`0x2CBA+` (résolution via `tbl_room_connection_ptrs`, 0x3D5D) ne
s'exécute QUE quand un `0xFF` est rencontré dans le payload. **Le chemin
`0x2C92+` (que j'avais classé à tort comme "cas spécial secondaire") est
en réalité le chemin par défaut**, utilisé pour chaque octet normal du
payload — confirmé par le cas réel observé : la room `0x44` (celle
quittée lors de la transition testée) a un payload `04 00 01 02 03 0C`
**sans aucun `0xFF`**, donc entièrement traité par `0x2C92+`.

## Le vrai mécanisme (corrigé) : 0x2C92-0x2CB7, chemin principal

**Statut : confirmed** par désassemblage direct + cas réel observé.

```
2C92  C5         push   bc
2C93  E5         push   hl
2C94  6F         ld     l,a         ; A = octet du payload (ex: 0x00, 0x01, 0x02...)
2C95  2600       ld     h,00
2C97  29         add    hl,hl       ; HL = A×2 (index word)
2C98  016E3E     ld     bc,3E6E     ; <-- NOUVELLE TABLE (différente de 0x3D5D !)
2C9B  09         add    hl,bc       ; HL = 0x3E6E + A×2
2C9C  7E         ld     a,(hl)
2C9D  23         inc    hl
2C9E  66         ld     h,(hl)
2C9F  6F         ld     l,a         ; HL = pointeur lu (déréférence word LE)
2CA0  010800     ld     bc,0008
2CA3  EDB0       ldir                ; copie 8 octets HL->DE (DE = curseur dans
                                     ; tbl_room_connections 0x0147, hérité de
                                     ; fn_load_room_data)
2CA5  DD7E08     ld     a,(ix+08)
2CA8  12         ld     (de),a       ; écrit le numéro de room COURANT après les 8 octets
2CA9  13         inc    de
2CAA  0613       ld     b,13
2CAC  CD3100     call   0031         ; efface 0x13=19 octets (portion non utilisée)
2CAF  7E         ld     a,(hl)       ; relit l'octet suivant DANS L'ENTRÉE DÉRÉFÉRENCÉE
2CB0  A7         and    a
2CB1  20ED       jr     nz,2CA0      ; non-nul -> une entrée liée suit (répète le LDIR)
2CB3  E1         pop    hl
2CB4  C1         pop    bc
2CB5  10D5       djnz   2C8C         ; octet SUIVANT du payload (B = compteur d'origine)
2CB7  C3542C     jp     2C54         ; retour à la boucle d'effacement initiale
```

**Interprétation confirmée** : `tbl_room_index_ptrs` (0x3E6E) est une
table de pointeurs indexée DIRECTEMENT par l'octet du payload (pas de
masquage bit à bit comme je l'avais supposé pour l'autre chemin) — bien
plus simple que le chemin `0x2CBA`. Chaque pointeur mène à une entrée
d'au moins 8 octets, copiée vers `tbl_room_connections` (0x0147), avec
le numéro de room courant ajouté en 9e position. Le format est cohérent
avec l'octet observé dans le payload de la room 0x44 : `00, 01, 02, 03`
— **probablement des index de DIRECTION fixes (0=Nord, 1=Est, 2=Sud,
3=Ouest, ou un ordre similaire)**, pas des IDs de salle ni des indices
arbitraires — hypothèse à vérifier en dumpant `0x3E6E` et en comparant à
la direction réelle empruntée (ici : le joueur a avancé selon un axe
précis, cf. `(ix+01)` uniquement modifié, donc une direction spécifique
correspond à l'un de ces 4 premiers index).

## Prochaine étape immédiate

Dumper `tbl_room_index_ptrs` (0x3E6E) et les entrées qu'elle pointe, pour
confirmer que index 0/1/2/3 correspondent aux 4 directions cardinales
(N/E/S/O ou équivalent), et que l'entrée réellement utilisée pour la
transition 0x44→0x43 observée pointe bien vers une structure contenant
0x43 comme nouveau numéro de room (même méthode de vérification
empirique que celle qui vient de payer : comparer calcul/table à un cas
réel observé, pas une supposition).

## Vérification empirique du contenu réel (résultat partiel, nouvelle clarification)

**Test effectué** : après la transition réelle 0x44→0x43 (confirmée par
`(ix+08)` avant/après un vrai déplacement au clavier), dump de
`tbl_room_index_ptrs[0]` (0x3E6E, premier octet du payload de la room
0x44 = `00`) → pointeur `0x3E9E` → entrée `02 8D C4 80 03 05 28 50 03`
(9 octets, mais SANS le `(ix+08)` ajouté qui vient après selon le
désassemblage).

**Dump de `tbl_room_connections` (0x0147) après la transition** :
`02 C4 73 80 05 03 28 00 43 ...` — **le `0x43` apparaît bien au 9e octet**,
confirmé être exactement `(ix+08)` (vérifié : `(ix+08)` vaut `0x43` au
moment du dump).

**Clarification importante** : le champ `+08` d'une entrée de
`tbl_room_connections` n'est PAS "le numéro de la salle cible d'une
connexion" comme documenté précédemment par erreur — **c'est le numéro
de la room COURANTE** (celle où l'entité qui vient d'entrer se trouve
maintenant), écrit après coup par `fn_load_room_data`. Donc
`tbl_room_connections` décrit des connexions **partant de** la room
actuelle (probablement une par direction), pas une carte de "quelle
salle mène à quelle salle" directement lisible dans ce seul champ.

**Ce qui reste à élucider** : quel champ de l'entrée de 8 octets
(`02 8D C4 80 03 05 28 50` ou sa version transformée `02 C4 73 80 05 03
28 00`) encode réellement **la salle de destination** — car ce n'est
visiblement pas un `room_id` brut à cet endroit (les valeurs ne
correspondent à aucun `room_id` valide de nos 128 entrées connues).
Cela nécessite soit de retracer `fn_resolve_neighbor_room` (0x2BF9) plus
finement avec les vraies valeurs de cette session (elle lit `(iy+03)`
d'une entrée de `tbl_room_connections`, donc il faut identifier quel
octet, après transformation par 0x2C92-0x2CB7, correspond à l'offset
+03 final), soit poser un breakpoint sur `fn_resolve_neighbor_room`
directement lors d'une prochaine transition et lire ses registres en
direct (méthode la plus fiable, déjà utilisée avec succès pour retrouver
`fn_read_input`).

**Statut d'ensemble sur la carte du monde : toujours NON extraite de
façon fiable.** Progrès net sur la compréhension du mécanisme (correction
de l'inversion JR Z, localisation de `tbl_room_index_ptrs`), mais le
champ exact contenant la destination reste à identifier avant de pouvoir
générer un graphe automatiquement pour les 128 rooms.

## Outils / méthode

- **Vérification de cohérence structurelle sans capacité de vision** :
  un graphe de données peut être validé par des propriétés objectives
  (symétrie attendue, connectivité, couverture complète d'un buffer)
  sans avoir besoin de "voir" quoi que ce soit — ces tests ont permis de
  détecter que l'hypothèse de décodage était fausse AVANT de la
  documenter comme un fait, exactement le type de garde-fou que la
  méthodologie du projet demande (section 7/7bis : vérifier par le
  calcul/comportement, pas seulement par la lecture).
- Prochaine fois qu'une hypothèse de format de données est testée,
  généraliser ce réflexe : calculer une propriété structurelle attendue
  (somme, symétrie, bornes, connectivité) et la vérifier avant de
  considérer le décodage acquis.
