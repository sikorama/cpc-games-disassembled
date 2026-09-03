# Méthodologie de rétro-ingénierie Z80/CPC via émulateur piloté

Stratégies génériques, réutilisables pour n'importe quel jeu CPC/Z80
analysé via un émulateur pilotable par API (MCP ou HTTP direct). Document
autonome : pas de prérequis externe au-delà d'un émulateur exposant
lecture/écriture RAM, breakpoints, et l'état CPU/GA/CRTC.

## 0. Identification du jeu (sans ressource externe)

- Dump RAM complet, recherche de runs ASCII imprimables (regex
  `[\x20-\x7e]{4,}` ou plus long) — les mentions copyright/année/société
  apparaissent souvent en clair même dans un binaire compilé. Filtrer sur
  les runs contenant plusieurs lettres majuscules consécutives pour
  éliminer le bruit (opcodes qui matchent la plage ASCII par hasard).
- Confirmer visuellement le titre auprès de l'utilisateur plutôt que
  d'aller chercher des ressources externes.

## 1. Cartographie mémoire de base

- Bank RAM par région 16K, pour confirmer la config banking.
- Croiser avec l'état CRTC (registres R12/R13) pour déduire la base
  d'adresse écran réelle (`R12<<8 | R13` puis décoder les bits hauts de
  R12 → 0x0000/0x4000/0x8000/0xC000). **Demander/vérifier cette valeur
  plutôt que la supposer** — elle change selon le jeu.
- Mode + palette GA active — indispensable pour interpréter correctement
  tout ce qui touche à l'affichage (bpp, nombre de pens actifs).

## 2. Codemap dynamique >> analyse statique linéaire

**Leçon clé** : une marche statique (suivre jp/jr/call/djnz/rst depuis un
point d'entrée) échoue silencieusement dès que le code utilise des sauts
calculés/indirects (`JP (HL)`, tables de dispatch) — très fréquent dans
les moteurs de jeu. Résultat : quelques dizaines d'octets couverts sur
64K, aucune alerte d'échec.

**Toujours préférer la codemap dynamique** (laisser tourner l'émulateur
en enregistrant chaque adresse exécutée, puis relever) : capture tout ce
qui s'exécute réellement, y compris via dispatch indirect. Comparer deux
relevés (avant/après une action) pour isoler les adresses nouvellement
activées par cette action précise — bien plus ciblé qu'un relevé unique.

## 3. Retrouver l'appelant d'une routine : la bonne méthode

**Piège** : lire `SP` au moment d'un breakpoint et supposer que `(SP)`
contient l'adresse de retour. Ça casse dès qu'on n'est pas exactement à
l'entrée de la fonction avant tout `PUSH`, ou si d'autres données
transitent par la pile à ce moment — donne des adresses de retour qui
tombent dans des zones de DONNÉES (signal d'alerte à ne pas ignorer : si
l'"adresse de retour" désassemble en `00 00 00...`, c'est presque
toujours un faux positif).

**Méthode fiable** : poser le breakpoint sur la routine cible, laisser
tourner jusqu'au hit, puis lire l'historique d'exécution de l'émulateur
(trace des dernières instructions) — l'entrée juste avant celle où
`pc == <adresse cible>` est la vraie instruction appelante (site du
`CALL`/`JP`), avec les vrais registres à cet instant.

Pour capturer les *arguments* d'appel (pas juste le site d'appel), lire
les registres immédiatement après le hit du breakpoint (avant tout autre
pas) — ils reflètent l'état à l'entrée de la routine.

## 4. Format des breakpoints — piège classique

Une adresse de breakpoint donnée sans préfixe hexa peut être interprétée
comme **décimal** par certains outils. Toujours écrire le préfixe hex
explicitement. Un breakpoint qui ne se déclenche jamais alors qu'on est
sûr que le code s'exécute est le symptôme n°1 de cette erreur — vérifier
ça avant de creuser plus loin.

## 5. Désassemblage : séparer code et données mentalement

Un désassembleur linéaire ne sait pas où s'arrête le code et où
commencent les données — une table de constantes juste après une
routine sera "désassemblée" en instructions absurdes si on ne fait pas
attention. Symptômes qui doivent alerter :
- séquences de `nop`/valeurs répétitives improbables pour du vrai code ;
- des `ret`/`jr`/`jp` qui pointent hors de toute zone plausible ;
- des motifs très réguliers (arithmétique) qui ressemblent plus à une
  table qu'à des instructions.

Dans ces cas, relire la même zone en hexadécimal brut et interpréter à
la main (souvent des mots 16-bit little-endian, des tables de lookup, ou
des structures de données répétées à taille fixe).

## 6. Reconstituer une fonction complète : remonter depuis un point connu

Une fois une instruction ou un fragment de routine identifié (via
breakpoint/historique), remonter en arrière dans le désassemblage
jusqu'à trouver un `RET` (ou un saut inconditionnel externe) qui marque
vraisemblablement la fin de la fonction précédente — le vrai début de la
fonction qui nous intéresse est juste après. Ne pas se fier uniquement
au point d'entrée trouvé par le breakpoint : il peut être au milieu
d'une fonction plus large avec plusieurs points d'entrée/sortie.

## 7. Vérifier les hypothèses par le calcul, pas par la lecture seule

Quand une routine calcule une adresse/valeur à partir de registres, ne
pas se contenter de lire le désassemblage — **vérifier avec les vraies
valeurs observées**. Exemple : une routine fait `HL = (HL>>2) + 0x9000` ;
avec `HL=0x9F58` en entrée observé via breakpoint, calculer à la main
`(0x9F58>>2)+0x9000 = 0xB7D6` et comparer à la valeur réellement obtenue
(via un second breakpoint juste après le `RET`, ou en relisant le
registre après l'appel). Un calcul qui ne colle pas révèle une erreur de
lecture du désassemblage (ordre des opérandes, portée d'un registre,
etc.).

**Piège fréquent lors de ces vérifications manuelles : les offsets
`(ix+NN)` affichés par le désassembleur sont en HEXADÉCIMAL.**
`(ix+12)` désigne l'offset `0x12` (18 décimal), pas 12. Confondre les
deux donne un résultat de calcul qui ne correspond pas à la valeur
observée, et peut faire croire à tort que l'hypothèse de lecture est
fausse alors que c'est juste une erreur de conversion. Toujours
convertir explicitement l'offset affiché en décimal avant tout calcul à
la main (ou mieux : faire le calcul en Python avec les valeurs en hex
directement, `0x12` plutôt que `12`).

## 7bis. Vérification comportementale par écriture ciblée (le test le plus fort)

Une fois qu'un calcul est vérifié numériquement (section 7), le test
ultime consiste à **modifier une valeur en RAM live pendant que son
effet est observable à l'écran**, puis comparer une capture avant/après
(diff d'image pour localiser la zone changée, puis inspection zoomée sur
cette zone précise pour caractériser le changement). Pour une hypothèse
de "coordonnée de grille isométrique" : modifier un seul des deux champs
combinés et vérifier que le déplacement apparent à l'écran combine bien
les deux axes (jamais un déplacement purement horizontal ou vertical) —
c'est la signature comportementale d'une vraie projection isométrique,
impossible à obtenir par erreur. Ce type de test tranche définitivement
entre plusieurs hypothèses concurrentes qu'un désassemblage seul ne peut
pas départager.

## 7ter. Une "liste" peut être un buffer reconstruit chaque frame, pas une table statique

Ne pas supposer qu'une liste consommée par la boucle de rendu (terminée
par 0xFF, cf. section 9) est une donnée de niveau figée. Dumper son
contenu à plusieurs instants et après une action : si le contenu change
(même légèrement, ex: un bit de flag sur le premier octet), c'est un
**buffer de travail reconstruit dynamiquement** (probablement par une
passe de culling/visibilité en amont, décidant quelles entités sont dans
le champ de la caméra avant de les passer à la boucle de rendu) — pas
une table de niveau. Chercher alors la routine qui l'écrit, pas
seulement celle qui la lit.

## 8. Distinguer données statiques vs état mutable

Pour une zone mémoire dont le rôle est ambigu (buffer de travail ? table
statique ?) : dumper N octets, déclencher une action qui devrait la
modifier si elle est mutable (mouvement du personnage, changement de
salle...), redumper, comparer. Aucun changement = table statique
(données de niveau/room précalculées). Changement localisé = état
dynamique (position, animation, compteur...).

## 8bis. Une zone "assets fixes" qui diffère entre deux captures n'est pas forcément un buffer de travail

Une comparaison octet-à-octet entre une transcription figée et une
lecture RAM fraîche peut révéler des milliers d'octets de différence sur
une zone documentée comme "assets fixes, jamais exécutés" — signal en
apparence alarmant. La conclusion intuitive ("c'est donc une zone de
travail repeuplée dynamiquement") peut être fausse : le vrai mécanisme
peut être une mutation EN PLACE par un algorithme déjà identifié ailleurs
(ex : flip/miroir de sprite déclenché par changement d'orientation d'une
entité) — le contenu change, mais de façon entièrement prévisible, pas
aléatoire ni "vidé".

**Méthode pour trancher sans test destructif** (mettre des zéros et voir
si le jeu tourne encore est valide mais coûteux et parfois ambigu —
préférer d'abord la preuve statique) : si une routine déjà comprise
manipule EN PLACE la zone qui diffère, **réimplémenter fidèlement cet
algorithme dans un petit script** (inutile de réexécuter le Z80) et
l'appliquer aux octets figés de la transcription — si le résultat
reproduit la RAM fraîche **bit pour bit**, la question est tranchée par
preuve directe : la zone est bien un asset réel, simplement mutable par
un mécanisme identifié, pas un scratch buffer sans contenu significatif.
Tester sur PLUSIEURS instances indépendantes de la même structure avant
de généraliser la conclusion à toute la zone — un seul exemple qui
matche pourrait être une coïncidence sur une structure simple.

## 9. Identifier des primitives génériques par leur signature

Certaines routines se reconnaissent par leur **forme**, indépendamment du
contexte d'appel :
- **Boucle avec `LD (HL),X / INC HL` répétée N fois + `DJNZ`** = routine
  de remplissage/effacement rectangulaire (blitting), souvent avec
  ajustement dynamique de largeur par auto-modification du point d'entrée
  dans la séquence déroulée (loop unrolling).
- **`RST n` avec un corps très court (quelques instructions)** = primitive
  arithmétique manquante sur Z80, invoquée très fréquemment (le coût
  1-octet du RST vs 3-octets du CALL le justifie). Exemple : `HL += A`
  (le Z80 n'a pas d'addition 16-bit+8-bit native). **Toujours désassembler
  le vecteur RST correspondant** dès qu'on le rencontre dans une trace —
  c'est presque toujours une primitive-clé réutilisée partout.
- **Table de constantes en progression arithmétique régulière** (pas
  constant entre entrées) = très probablement une table de correspondance
  ligne-écran/colonne-écran (l'espacement correspond à la largeur d'une
  ligne en octets pour le mode graphique courant).
- **Liste d'IDs/pointeurs terminée par 0xFF (ou 0x00)** = liste d'entités
  à itérer — pattern universel de "table à terminateur" en 8-bit.
- **`LD (adresse_fixe),A` où adresse_fixe tombe au milieu d'une routine
  proche** (pas une variable/structure) = code auto-modifiant, patchant
  un opérande immédiat ou une cible de saut. Très courant dans les
  routines de blit optimisées par taille (évite de tester la largeur en
  boucle interne — on patche directement le point d'entrée ou l'opérande
  correspondant à la taille voulue). Ne pas essayer de comprendre le
  patch seul : il faut désassembler la zone patchée pour voir ce qui
  change de sens selon la valeur écrite.
- **`somme` de deux coordonnées pour un axe écran + `différence/2` pour
  l'autre axe** = signature quasi-certaine d'une **projection
  isométrique** (X_écran = X+Y, Y_écran = (Y-X)/2, à des offsets/échelles
  constantes près). Reconnaître ce motif permet d'identifier direct la
  routine de projection sans avoir à deviner à partir du nom des variables
  (qu'on n'a pas).
- **Deux champs de structure combinés par indexation ×N + base fixe, N
  étant une puissance de 2 combinée à ses moitiés/quarts (ex: ×8+×16,
  ou ×8+×4)** = calcul de taille de structure (voir section 6bis
  ci-dessous) — le nombre obtenu (24, 28...) est la taille réelle en
  octets d'un enregistrement dans un tableau.
- **Boucle `LD A,(DE) / LD C,(HL) / LD (HL),A / LD A,C / LD (DE),A` avec
  `DEC HL`/`DEC DE` convergents** = échange de paires d'octets en place,
  signature d'un **flip/miroir de sprite calculé une fois et réutilisé**
  (au lieu de stocker deux orientations séparées en mémoire). Le premier
  octet de la donnée pointée sert souvent de marqueur d'état (quelle
  orientation est actuellement stockée), comparé à un flag d'entité pour
  décider si un nouveau flip est nécessaire — évite de re-flipper à
  chaque frame si l'orientation n'a pas changé.
- **`LD A,(écran) / AND (HL) / INC H / OR (HL) / INC H / LD (écran),A`**
  = technique universelle **"mask-then-or"** de sprite avec transparence
  sur fond 8-bit : `résultat = (fond AND masque) OR couleur`. `HL` pointe
  successivement vers un plan masque puis un plan couleur (souvent deux
  pages mémoire adjacentes, `INC H` sans toucher `L`). Dès qu'on voit ce
  motif exact (AND puis OR sur deux lectures indirectes consécutives),
  c'est presque certainement le cœur du blit de sprite avec transparence
  — le signal le plus fiable qu'on a trouvé la vraie routine de dessin
  (pas juste un calcul d'adresse ou un effacement).

## 6bis. Confirmer la taille d'une structure par le calcul d'indexation

Dès qu'on voit une routine qui prend un ID/index en entrée et produit une
adresse via une suite d'`ADD HL,HL` (doublements) combinés avec des
`ADD HL,BC` (ajouts de multiples précédents) puis un ajout de constante
finale — c'est un calcul `adresse = base + index × taille_structure`.
Défaire la suite d'opérations à la main donne `taille_structure` exacte,
qui doit être cohérente avec le plus grand offset `(ix+n)` observé
ailleurs dans le code utilisant cette même table (si `taille_structure=28`
et qu'on voit `(ix+1B)` utilisé ailleurs, 0x1B=27 < 28, cohérent — sinon
il y a une erreur d'interprétation à corriger).

## 6ter. Reconnaître un pipeline en deux passes imbriquées dans une seule boucle

Piège potentiel : une fonction peut sembler ne faire "qu'une chose" (ex:
effacer) alors qu'elle empile en réalité des valeurs (adresses calculées,
paramètres) à chaque itération d'une boucle, PUIS les redépile dans un
second mini-passage à la fin de la même invocation, pour faire une
deuxième chose (ex: dessiner) avec les mêmes valeurs déjà calculées —
sans reparcourir toute la liste d'entités une seconde fois. Repérer ce
pattern : des `PUSH` juste avant l'incrément d'un compteur en fin de
boucle principale, suivis (après la sortie de cette boucle) d'un second
petit bloc qui `POP` et utilise un compteur décroissant pour savoir
combien de fois dépiler. Ne pas conclure trop vite qu'une fonction "ne
fait que X" sans avoir vérifié ce qui se passe après la sortie de la
boucle principale mais avant le `RET` final de la fonction englobante.

## 6quater. Sentinelle de table par adjacence mémoire

Deux tables voisines en mémoire peuvent se servir mutuellement de borne
de fin : si une routine de parcours compare son pointeur courant à
l'adresse de départ d'une AUTRE table déjà identifiée plutôt qu'à une
constante numérique arbitraire, c'est un signal fort que les deux tables
ont été placées consécutivement à dessein par les développeurs
originaux. Ça permet de déduire la taille exacte d'une table (nombre
d'entrées × taille d'entrée = distance entre les deux bornes) sans avoir
à trouver un terminateur explicite dans les données elles-mêmes.

## 6quinquies. Recherche linéaire dans une petite table (motif de code)

Motif classique : `LD B,<N> / <lire un champ> / CP <valeur> / JR Z,<trouvé>
/ ADD <registre paire>,<pas fixe> / DJNZ <boucle>`. C'est une recherche
linéaire bornée (au plus N entrées, chacune de taille fixe). Si aucune
entrée ne correspond après N essais, la routine renvoie généralement un
statut d'échec silencieux (juste un `RET`) plutôt qu'une erreur — très
courant pour des tables de relations peu peuplées (ex: connexions
possibles entre salles voisines dans un monde en grille).

## 7quater. Valider un décodage de table de données par des propriétés structurelles objectives

Pour une table de données complexe (pas une simple constante), ne pas se
contenter de "ça semble cohérent visuellement" — calculer une propriété
structurelle objective attendue et la vérifier avant de considérer le
format acquis. Exemples :
- **Couverture complète d'un buffer** : si le format supposé (ex:
  `[clé][longueur][payload]`) parcourt exactement tout l'espace alloué à
  la table sans reste ni dépassement, c'est un bon signe (mais pas une
  preuve suffisante à lui seul).
- **Symétrie attendue** : pour un graphe qui devrait être non-orienté
  (ex: connexions bidirectionnelles entre salles voisines), vérifier
  qu'une écrasante majorité des relations sont bien réciproques. Un taux
  de symétrie proche de 0% après décodage est un signal fort que
  l'hypothèse de format est fausse, même si chaque octet individuel
  "semble" plausible (ex: être une valeur dans la plage attendue).
- **Connectivité attendue** : pour un graphe qui devrait connecter la
  quasi-totalité des nœuds (un monde de jeu jouable, pas des îlots
  isolés), un parcours en largeur qui n'atteint qu'une poignée de nœuds
  révèle immédiatement un problème de décodage.

Ce type de test ne demande aucune capacité de vision — un graphe ou une
table de données se valide par du calcul, pas par inspection visuelle.
**Ne jamais documenter un décodage de données comme confirmé sur la
seule base qu'il "a l'air plausible"** — chercher une propriété
vérifiable et la tester, quitte à découvrir (et documenter honnêtement)
que l'hypothèse était fausse.

## 7quinquies. Ne jamais neutraliser une fonction entière par patch RET sans vérifier ses effets de bord

Tentation courante : pour désactiver un comportement gênant (ex: les
collisions, pour explorer librement), patcher le premier octet d'une
fonction par `RET`. **Risque réel** : une fonction identifiée comme
"test de collision" peut avoir des effets de bord préalables (remise à
zéro d'un accumulateur partagé, mise à jour d'un état global lu ailleurs
dans la frame) qui sont nécessaires même quand le test lui-même ne
produit rien ce tour-ci. Sauter toute la fonction prive le reste du jeu
de ces effets de bord, avec des conséquences étendues et pas forcément
prévisibles (rendu cassé, entités qui disparaissent) — bien au-delà du
comportement qu'on visait à neutraliser.

**Approche plus sûre** : identifier précisément l'instruction ou le
petit bloc qui produit l'EFFET gênant (ex: le test conditionnel qui
bloque le mouvement), et neutraliser seulement CE point (par exemple en
forçant un flag/registre juste après le test, ou en sautant uniquement
la branche de blocage) plutôt que la fonction englobante entière. Si le
patch cause un effet visible plus large que prévu (graphismes cassés,
entités qui disparaissent), c'est le signal immédiat que la fonction
patchée a d'autres responsabilités que celle identifiée — annuler le
patch tout de suite plutôt que d'essayer de "réparer autour".

## 9bis. Forcer l'exécution d'une routine arbitraire sans API d'écriture de registres

Certaines API d'émulateur ne permettent d'écrire QUE la RAM et de
rediriger `PC` — aucune route ne permet de poser directement
`IX`/`DE`/`HL`/etc. **Piège** : si la routine cible lit un registre
(typiquement `IX` pour indexer une structure) qui n'est PAS mis en place
par le simple fait de sauter à son adresse (ex: sauter au MILIEU d'une
séquence d'init qui suppose `IX` déjà positionné par l'appelant naturel),
le registre contient une valeur RÉSIDUELLE arbitraire (celle du contexte
interrompu) — symptôme : le résultat obtenu correspond à des données
cohérentes mais pour la MAUVAISE entité/salle/structure (pas une erreur
franche, donc facile à ne pas remarquer sans vérification croisée).
**Solution générique** : injecter un mini-trampoline exécutable (quelques
octets) dans une zone RAM sans conséquence (ex: une zone de travail qui
va être réécrite de toute façon par ce qu'on s'apprête à déclencher), qui
pose explicitement le(s) registre(s) requis puis `JP`/`CALL` vers la
vraie cible — écriture RAM avec exécution immédiate à l'adresse du
trampoline.

**Corollaire découvert en chaînant plusieurs injections consécutives**
(pas visible sur un seul essai isolé) :
- **Une seule écriture RAM active à la fois côté serveur** (pas une
  file) : deux écritures séparées envoyées à la suite (ex: une pour une
  donnée, une pour le trampoline+exec) peuvent se "coalescer" — la
  seconde écrase la première avant qu'aucune des deux n'ait été
  appliquée, silencieusement (pas d'erreur, juste une donnée jamais
  écrite). **Toujours regrouper toute donnée nécessaire DANS le
  trampoline lui-même** (ex: `LD A,valeur / LD (adresse),A / ...`) plutôt
  que de compter sur deux écritures séparées.
- **Vérifier-et-réessayer plutôt que faire confiance à un seul essai**,
  même une fois la technique "validée" : en rejouant la même séquence
  plusieurs fois de suite, une race intermittente peut apparaître (ex :
  1 essai sur 2-3 retombe sur le point d'arrêt avec des données périmées
  de l'exécution précédente, sans erreur visible) — un délai fixe entre
  tentatives ne suffit pas toujours à la faire disparaître. Plutôt que de
  chercher à tout prix la cause racine exacte côté émulateur, vérifier le
  résultat obtenu (relire l'octet qui devait changer) et réessayer
  automatiquement quelques fois est une solution pragmatique et peu
  coûteuse quand l'opération est rapide.

## 10. Capture visuelle sans capacité de vision native

Pour un assistant sans capacité de vision sur les images, deux
contournements complémentaires :
- **Downsampling grayscale → ASCII-art** (redimensionnement + mapping
  luminosité→caractère) : rapide, suffisant pour distinguer grossièrement
  "il y a du texte" / "il y a une scène graphique" / "rien n'a changé".
  Perd toute info de couleur, résolution insuffisante pour lire du texte
  fin ou comparer un sprite pixel-exact.
- **Quantification pixel-exacte sur la palette GA active** : convertit
  chaque pixel en index de pen (0-3 en Mode 1, etc.) via la vraie palette
  RGB lue dans l'état GA de l'émulateur, avec détection automatique du
  doublement de pixel horizontal propre à certains modes CPC. Donne une
  grille de chiffres directement comparable à un sprite décodé depuis la
  RAM — c'est l'outil à utiliser dès qu'on veut vérifier qu'un décodage
  de sprite/tuile correspond bien au rendu réel.
- **Diff de captures d'écran** (différence d'image + bounding box) :
  localise rapidement où un changement s'est produit à l'écran suite à
  une action (mouvement, animation), sans avoir à "voir" l'image — donne
  juste une zone rectangulaire à investiguer plus finement.

## 11. Ordre d'investigation recommandé pour un nouveau moteur de jeu

1. **Capturer une petite collection de dumps RAM/snapshots à des moments
   clés, AVANT de commencer à désassembler** : (a) juste après le tout
   premier boot, au menu, avant toute nouvelle partie ; (b) juste après
   le début d'une partie (première salle/niveau chargé) ; (c) à un moment
   avancé d'une partie déjà bien entamée (plusieurs zones visitées,
   plusieurs entités ayant bougé/interagi). Comparer ces captures ENTRE
   ELLES (section 8) révèle immédiatement quelles zones sont réellement
   statiques (identiques dans toutes les captures — code, assets figés)
   et lesquelles sont mutables (état de partie, randomisation,
   orientation d'entités) AVANT même d'avoir désassemblé la moindre
   routine — évite de transcrire par erreur un état transitoire comme
   s'il était définitif. **Encore plus important pour un jeu qui fait des
   accès disque en cours de partie** (chargement de niveau/asset depuis
   le support plutôt que tout tenir en RAM dès le boot) : une capture
   unique risque de rater des données qui n'existent qu'après un accès
   disque précis, faisant passer à tort pour "non pertinente" ou
   "toujours à zéro" une zone qui ne se remplit qu'à un moment donné.
2. Identifier le jeu (chaînes ASCII), confirmer avec l'utilisateur.
3. Cartographier mémoire (banking, CRTC→base écran, mode GA/palette).
4. Codemap au menu (souvent plus simple, bon terrain d'entraînement pour
   la méthode avant d'attaquer le jeu réel).
5. Une fois en jeu : codemap avec/sans input, comparer pour isoler ce qui
   tourne en continu (souvent le rendu/la physique) de ce qui ne tourne
   qu'en réaction à une touche (input/collision ponctuelle).
6. Pour toute routine trouvée via codemap : breakpoint + historique
   d'exécution pour trouver le(s) vrai(s) appelant(s), désassembler le
   contexte large autour, remonter jusqu'au vrai début de fonction.
7. Confirmer chaque hypothèse par le calcul (valeurs réelles observées)
   et/ou par un test de mutabilité (dump avant/après action).
8. Consigner au fur et à mesure avec un statut explicite : confirmé
   (désassemblage + vérification numérique/comportementale) vs
   hypothèse (désassemblage seul, pas encore vérifié) — ne jamais
   présenter une hypothèse comme un fait établi.

## 12. Confirmer par recoupement, pas par balayage un par un

Quand le nombre d'entrées encore hypothétiques devient grand, les
revérifier une par une par breakpoint est lent et redondant : beaucoup
sont déjà effectivement résolues par du travail fait ailleurs, juste
jamais reporté sur leur propre entrée. Avant de lancer une nouvelle
session de breakpoints, faire une passe de recoupement pur (texte contre
texte, aucun outil requis) :

- **Callee confirmé → caller hypothèse** : si une routine encore
  hypothétique n'est qu'un dispatcher/orchestrateur qui appelle
  exclusivement des routines déjà confirmées, le désassemblage seul
  (même statique, sans test comportemental) suffit souvent à la
  confirmer — son "rôle" est simplement la somme de rôles déjà établis.
- **Donnée hypothétique référencée par plusieurs routines confirmées** :
  chercher, dans les descriptions déjà écrites des routines confirmées,
  des mentions implicites du symbole encore incertain (souvent une
  phrase du type "voir adresse X" ou "consulté par..."). Si plusieurs
  entrées confirmées décrivent déjà exactement le rôle d'une variable
  encore marquée incertaine, c'est un oubli de synchronisation de
  statut, pas une vraie incertitude — corriger directement.
- **Table à statut mixte** (confirmée pour une partie, incertaine pour
  une autre) : revérifier si une découverte ULTÉRIEURE sur une table
  voisine (même mécanisme, section 6quater) n'a pas déjà, incidemment,
  désassemblé/expliqué la partie incertaine sans jamais remonter mettre
  à jour le statut de la table d'origine.
- **Priorisation par effet de levier** : quand plusieurs hypothèses
  restent réellement ouvertes (pas de recoupement possible), prioriser
  celles référencées par le plus grand nombre de routines déjà
  confirmées, et celles qui, une fois résolues, éclaircissent plusieurs
  autres entrées d'un coup.

**Désassemblage statique hors-ligne, sans émulateur, en comportement PAR
DÉFAUT** : maintenir un dump RAM complet pris après boot comme source de
repli. La pratique consiste à centraliser la résolution de la source RAM
dans un petit module partagé par tous les outils de désassemblage/génération
de source : émulateur live si accessible, sinon repli automatique et
silencieux (juste un message sur stderr) sur le dump statique — aucun
flag à passer, aucune distinction d'usage entre les deux modes. Si NI
l'émulateur NI le dump ne sont disponibles, message d'erreur explicite
qui explique comment recapturer un dump depuis l'émulateur live (une
capture ponctuelle, à lancer une fois puis oublier). Cette approche
permet de désassembler/vérifier n'importe quelle zone encore non
transcrite, et de générer directement le source annoté, SANS avoir
besoin de l'émulateur lancé pour l'essentiel du travail — utile pour de
la vérification ou de la préparation entre deux sessions avec émulateur.

Limite à garder en tête : le dump est une PHOTO figée d'un instant —
invalide pour tout ce qui dépend d'un état runtime (RAM haute mutable,
VRAM, I/O, variables de partie en cours) ; uniquement fiable pour du
code/des tables statiques. S'il devient trop périmé pour une zone qu'on
veut étudier, le régénérer plutôt que de conclure à tort que la zone est
vide/invariante.

Un vrai désassemblage direct reste plus fiable qu'une transcription
manuelle antérieure, même déjà relue plusieurs fois — un octet mal
transcrit à la main peut survivre longtemps sans être détecté jusqu'à ce
qu'on redésassemble mécaniquement la zone.

## 13. Cycle recommandé : dégrossir hors-ligne, puis confirmer en session live

Le déroulement le plus efficace n'est PAS d'alterner constamment entre
lecture de code et tests par breakpoint, mais d'enchaîner deux phases
nettement séparées :

1. **Phase hors-ligne (dégrossir)** — sans émulateur, via les outils de
   désassemblage/génération avec repli automatique sur le dump statique
   (section 12). Résoudre tout ce qui est mécaniquement déductible du
   seul désassemblage : compléter les zones encore non transcrites,
   recouper les statuts hypothétiques contre ce qui est déjà confirmé
   ailleurs, nommer les routines dont le rôle se déduit de leurs
   callers/callees déjà connus. Rapide (pas d'aller-retour
   réseau/émulateur), sans risque pour une partie en cours, et productif
   même quand l'émulateur n'est pas disponible.
2. **Phase live (confirmer)** — une fois la phase 1 épuisée (tout ce qui
   est déductible statiquement l'a été), basculer sur une VRAIE session
   de jeu avec breakpoints ciblés pour les questions qui ne se tranchent
   QUE par l'observation d'un état runtime : valeur exacte d'une formule
   (vérification numérique, section 7), existence ou non d'un chemin
   d'exécution (ex : "ce mécanisme se déclenche-t-il jamais en usage
   normal ?"), comportement observable qu'aucune lecture de code ne peut
   remplacer (ex : "faut-il un bouton pour ramasser un objet, ou le
   simple contact suffit ?" — tranché en quelques secondes par un test
   direct, aurait pu prendre des heures à déduire du seul
   désassemblage).

**Pourquoi cet ordre et pas l'inverse** : chaque question résolue
hors-ligne réduit le nombre de breakpoints à poser en session live
(ressource plus coûteuse : dépend de la disponibilité de l'émulateur ET
de l'utilisateur en train de jouer). Arriver en session live avec une
liste précise de questions RÉELLEMENT indécidables statiquement (pas
simplement "pas encore regardé") rend chaque minute de jeu beaucoup plus
productive. Exemple de question qui ne se tranche QUE en live : le
FORMAT d'une donnée peut être entièrement déduit du désassemblage, mais
SEUL un test live (ex : marcher sur un objet sans bouton) peut trancher
si un chemin de code passif existe — l'absence d'un chemin de code n'est
prouvable qu'en épuisant TOUTES les références statiques à une adresse,
mais la confirmation comportementale finale reste le test décisif.

## 14. Piloter l'émulateur sans MCP : l'API HTTP directe

Tout ce que les sections précédentes décrivent via des outils MCP (état
émulateur, breakpoints, lecture/écriture RAM, désassemblage, historique
d'exécution...) est généralement accessible de façon équivalente via
l'API HTTP brute de l'émulateur, sans serveur MCP configuré — utile en
environnement sans MCP disponible ou pour scripter rapidement en
ligne de commande. Endpoints à chercher/confirmer pour un nouvel
émulateur :

- Lecture de l'état complet : registres Z80, GA, CRTC.
- Capture d'écran (PNG), directement lisible par un outil de vision (pas
  besoin de downsampling ASCII-art si l'environnement a une vraie
  capacité de vision — section 10 reste valable sinon).
- Simulation de touche : **piège classique** — un événement de touche
  sans distinction press/release est parfois un simple "tap" (pressée
  PUIS relâchée immédiatement), y compris pour un test qui a besoin d'un
  état "touche pressée" stable sur plusieurs frames. Vérifier que l'API
  permet de maintenir explicitement une touche enfoncée puis de la
  relâcher séparément.
- Lecture de la matrice clavier brute (bit=0 = ligne/touche active).
  Lecture seule, mais permet de **confirmer empiriquement** quelle
  ligne/bit de la matrice correspond à quelle touche virtuelle — croiser
  avec les tables de lecture clavier déjà désassemblées pour vérifier
  qu'une touche testée active bien la ligne attendue par le code.
- Table touches-caractères → code virtuel (utile pour retrouver le code
  d'une touche à partir de son caractère, mais ne couvre généralement PAS
  les touches spéciales type flèches/F-keys, à découvrir par essai
  direct).

Cette API est en général un simple serveur HTTP local : n'importe quel
outil shell suffit, aucune dépendance MCP n'est nécessaire pour appliquer
intégralement la méthode décrite dans ce document.

**Corollaire (piège rencontré en pratique, 2026-08-17)** : ne jamais
conclure "aucun émulateur disponible" sur la seule base d'une recherche
d'outils MCP infructueuse. Un outil de recherche d'outils ne connaît que
les outils explicitement enregistrés dans l'environnement — il ne sonde
pas le réseau local. Avant de basculer sur le repli statique (sections
12/13), toujours tenter au moins une requête HTTP directe sur le port
par défaut connu du projet (`curl http://localhost:PORT/api/ping` ou
équivalent) : l'émulateur peut très bien tourner sans qu'aucun outil
MCP ne le signale.

## 15. Piège critique : une connexion live qui répond n'est pas forcément une connexion PERTINENTE

Un outil qui privilégie automatiquement la RAM live dès que l'émulateur
répond ne vérifie généralement PAS que le programme attendu (le jeu) est
effectivement chargé et en cours d'exécution — il vérifie seulement que
la requête HTTP réussit. Si l'émulateur est resté allumé mais est revenu
à l'invite BASIC/firmware (reset, sortie du jeu, rechargement en
cours...), les lectures RAM réussissent quand même et renvoient des
octets réels — juste ceux du firmware, pas ceux du jeu — et rien ne le
signale (pas d'erreur, pas d'avertissement). Symptôme observé : un
désassemblage qui, à une adresse pourtant déjà confirmée par une session
précédente, ne redonne soudain plus les mêmes octets.

**Toujours vérifier le contenu avant de faire confiance à une source
"live"** : comparer quelques octets déjà connus/confirmés (ex. le tout
premier octet d'une routine déjà désassemblée) contre ce que renvoie la
lecture RAM maintenant. Un moyen rapide et fiable : une capture d'écran —
un écran d'invite firmware au lieu du jeu est un diagnostic immédiat et
sans ambiguïté.

**Si la source live n'est pas fiable pour la session en cours**, forcer
le repli sur le dump statique plutôt que d'attendre que l'utilisateur
recharge le jeu : remplacer la fonction de lecture RAM par une version
qui lit directement le dump statique, en sautant l'appel HTTP — attention
si cette fonction est importée par nom (`from module import fetch_ram`)
dans un autre module : patcher le module d'origine après coup ne suffit
pas, il faut aussi réaffecter le nom localement importé dans chaque
module qui l'utilise déjà. Toujours valider ce contournement par un
round-trip (vérifier qu'il reproduit exactement les octets déjà
confirmés) avant de s'en servir pour du nouveau travail.

## 16. Finaliser mécaniquement un désassemblage : symboles + régénération incrémentale, jamais la régénération totale

Un générateur mécanique de source annoté (qui désassemble linéairement
depuis chaque symbole confirmé, s'arrête au premier saut/retour
inconditionnel, et bascule en octets bruts non désassemblés pour tout
octet non couvert par un symbole) souffre du MÊME angle mort que la
codemap dynamique (section 2) : il ne suit jamais un saut calculé/indirect
NI un saut conditionnel dont la cible n'a pas déjà son propre symbole —
sauf qu'ici la solution n'est PAS l'exécution réelle (comme pour la
codemap), mais l'enregistrement manuel/assisté du bon point d'entrée dans
la table de symboles, ce qui permet de travailler entièrement hors-ligne
sur un dump statique (section 12/13).

**Méthode qui converge systématiquement** :
1. Repérer un bloc d'octets non désassemblés, identifier son adresse de
   début.
2. Chercher, DANS le désassemblage déjà confirmé du reste du fichier
   (souvent la routine juste avant), un `jr`/`jp` conditionnel qui pointe
   exactement vers cette adresse — c'est la preuve que ce bloc EST du
   code réellement atteint, juste jamais désassemblé parce que le
   parcours linéaire s'était arrêté avant (au premier saut/retour
   inconditionnel rencontré).
3. Ajouter un nouveau symbole confirmé à cette adresse dans la table de
   symboles, avec un nom et une description qui citent explicitement
   d'où vient l'appel (quelle instruction saute ici).
4. Régénérer UNIQUEMENT la plage concernée et relire où s'arrête le
   nouveau bloc désassemblé — s'il reste des octets non couverts après,
   répéter l'étape 2 à partir de ce nouveau point (plusieurs symboles
   successifs sont souvent nécessaires pour un seul "trou", chaque saut
   conditionnel/inconditionnel interne devenant potentiellement une
   nouvelle frontière de symbole).
5. Pour une table de données (pas du code) : donner un type "table" avec
   une extent explicite (nombre d'entrées × taille d'entrée, ou octets
   littéraux si courte) — déterminer l'extent exact en cherchant le
   symbole SUIVANT déjà connu en mémoire et en vérifiant que la table
   s'arrête pile à sa frontière (même principe que la sentinelle par
   adjacence, section 6quater).

**Ne jamais régénérer et écraser un fichier source complet une fois qu'il
a reçu une passe de reformatage manuel** (ex. de longs commentaires
initialement générés sur une seule ligne, ensuite repliés à la main sur
plusieurs lignes pour la lisibilité) — le générateur mécanique ne sait
pas reproduire ce reformatage et l'écraserait pour un gain nul. Toujours
régénérer une PLAGE ciblée, puis reporter le delta dans le fichier
existant par un remplacement chirurgical (édition de texte classique,
pas une réécriture complète).

**Vérification finale obligatoire** (ne pas se fier à la seule absence
d'octets non désassemblés) : comparer, adresse par adresse, les octets
d'opcode (PAS le texte du commentaire, qui peut légitimement différer
par le retour à la ligne) entre une régénération indépendante de la
plage et le fichier final édité — un script court qui extrait
`(adresse, octets_hexa)` de chaque ligne d'instruction des deux côtés et
diff les deux dictionnaires suffit, et ne nécessite aucune capacité de
vision.

## 16bis. Un `ret`/`jp` inconditionnel rencontré en cours de désassemblage linéaire n'est PAS toujours la fin de la routine

La méthode de la section 16 (ajouter un nouveau symbole à chaque
saut/retour rencontré) suppose implicitement qu'un `ret`/`jp`
inconditionnel marque TOUJOURS soit la vraie fin d'une routine, soit une
table de données — jamais un simple embranchement de sortie précoce à
L'INTÉRIEUR de la MÊME routine logique. Or les deux cas se produisent,
avec des conséquences opposées si on les confond :

- **Cas A (sortie précoce, code réel après)** : une routine teste un cas
  particulier tôt (souvent une sentinelle, ex. "si type==1, tuer
  l'entité et sortir"), ce qui produit un `ret` qui termine SEULEMENT
  cette branche — le corps principal de la routine continue immédiatement
  après en mémoire, atteint par le chemin "sinon" (`jr nz,+N` qui saute
  PAR-DESSUS ce `ret`). Un désassembleur linéaire qui s'arrête au premier
  `ret` rencontré perd donc tout le reste d'une fonction par ailleurs
  entièrement réelle et cohérente.
- **Cas B (fin réelle, table de données après)** : une routine se
  termine authentiquement sur ce `ret`/`jp`, et les octets suivants sont
  une vraie table de données (souvent une table de dispatch, lue comme
  `HL=table[index]` puis `JP (HL)`) — désassembler ces octets comme s'ils
  étaient du code produit un résultat plausible en apparence mais
  entièrement FABRIQUÉ. Un cas rencontré : une table de dispatch
  documentée depuis longtemps avec un nombre d'entrées jamais revérifié
  s'est révélée en avoir une de moins que ce qui était écrit — la
  dernière "entrée" tombait en réalité sur le premier octet de code
  réel qui suit la table.

**Méthode pour trancher, sans deviner** : décoder manuellement et
LINÉAIREMENT (script jetable appelant le même désassembleur que le
générateur) depuis le symbole jusqu'à la borne du symbole SUIVANT déjà
connu, en ignorant volontairement l'arrêt au premier `ret`/`jp`, puis
lire le résultat :
- Si TOUT le flux jusqu'à cette borne se relit comme du code Z80
  cohérent (pas d'exception de décodage, pas de séquence absurde, les
  cibles de saut restent dans la plage plausible) ET que la borne
  suivante est atteinte pile — c'est le cas A : le contenu est réel, la
  routine a juste plusieurs sorties.
- Si le décodage devient incohérent après un certain point, ou si un
  saut inconditionnel connu (avec un index calculé juste avant) indique
  explicitement "ce qui suit est une table indexée" — c'est le cas B :
  garder l'arrêt, transcrire la suite comme une table, et vérifier sa
  taille exacte en relisant le nombre d'entrées réellement valides
  (compter à la main, sur le contenu RAM réel, combien de mots
  consécutifs tombent bien dans l'ensemble des adresses cible attendues
  avant de heurter du code visiblement incohérent).

**Traduction outillée** : plutôt que de fragmenter arbitrairement une
routine multi-sorties en plusieurs symboles artificiels (ce que ferait
un usage naïf de la section 16), donner au générateur mécanique un
mécanisme d'opt-in explicite PAR SYMBOLE qui désactive l'arrêt
automatique au premier `ret`/`jp` UNIQUEMENT pour les routines vérifiées
cas A — jamais activé par défaut, jamais sans avoir fait la vérification
manuelle ci-dessus en premier.

## 16ter. Séparer la table de symboles (portable) du journal d'investigation (narratif)

Une table de symboles qui alimente un générateur mécanique de source ASM
a tendance, dans une investigation qui s'étale sur de nombreuses
sessions, à accumuler aussi de la narration (quand un fait a été établi,
par quelle méthode, un renvoi vers telle note détaillée, un désaccord
avec une hypothèse antérieure). Le problème : ces deux usages sont
incompatibles dans le même champ texte. Le lecteur du SOURCE FINAL n'a
besoin que du fait technique ; le journal d'investigation, lui, a besoin
de dates/renvois pour qu'une session future retrouve le contexte. Les
mélanger produit soit un journal illisible comme documentation finale,
soit une doc finale polluée de récit.

**Séparer en artefacts distincts, chacun à vocation unique** :
1. **Un fichier labels minimal** : une ligne par symbole, `ADRESSE NOM`,
   triée par adresse croissante, RIEN d'autre — pas de commentaire, pas
   de statut, pas de type. Autoportant, réutilisable par n'importe quel
   autre outil (désassembleur générique, débogueur) sans connaître les
   conventions du projet. Toujours généré par projection mécanique de la
   table ci-dessous, jamais maintenu à la main séparément.
2. **Une table de symboles complète**, dédiée UNIQUEMENT à alimenter le
   générateur : par symbole, systématiquement les mêmes champs — plage
   d'adresse, type (code/donnée), statut de confiance, un résumé court
   (une ligne), une explication plus longue (le fait technique complet,
   insérée telle quelle en commentaire d'en-tête dans le source généré)
   — PLUS les quelques paramètres purement mécaniques nécessaires à la
   génération elle-même (taille d'une table, drapeau "cette routine a
   plusieurs points de sortie", etc., voir sections 16/16bis). Rien
   d'autre : ni date, ni renvoi vers un autre document, ni récit de
   comment le fait a été établi.
3. **Le journal d'investigation détaillé** (dates, méthode, hypothèses
   successives, désaccords) reste un document séparé, à vocation de
   mémoire de session — jamais consommé directement par le générateur,
   mais souvent la meilleure source quand on doit ENRICHIR l'explication
   longue d'un symbole (point 4 ci-dessous), car il est fréquemment plus
   à jour que la table elle-même sur un fait précis.

**Format du source ASM généré, une fois la table nettoyée** :
- Pas d'adresse ni d'octets machine à chaque ligne d'instruction — cette
  information vit dans la table/le fichier labels, pas dans le source
  lisible. Seul un marqueur d'origine (`org`) démarre chaque bloc
  contigu.
- Chaque label porte en commentaire d'en-tête l'explication longue du
  symbole (repliée sur plusieurs lignes à largeur fixe), précédée d'un
  tag de statut UNIQUEMENT s'il n'est pas confirmé — pour ne pas
  alourdir le cas normal, qui est la majorité une fois le travail
  avancé.
- Un symbole non confirmé n'a jamais de code inventé après son label :
  uniquement le label + son commentaire, suivi des octets réels bruts,
  jamais un trou d'adresse silencieux.
- Une zone de RAM de travail runtime (état de partie, pas du contenu
  figé) devient une simple réservation de taille, jamais un dump des
  octets observés au moment de la génération (qui ne représenterait
  qu'un instant, pas le contenu réel, cf. section 8).

**Migrer une table existante qui mélange narration et fait technique**
(cas fréquent quand elle a grossi organiquement pendant l'investigation)
— une passe automatisée est plus rentable qu'une reprise entièrement
manuelle :
1. **Nettoyer par script sur tout le corpus, pas entrée par entrée** :
   repérer les patterns récurrents de narration (dates isolées ou entre
   parenthèses, renvois vers un autre document, marqueurs de statut en
   tête de phrase type "RÉSOLU"/"CORRECTION"/"NOUVEAU", tournures de
   collaboration type "confirmé par X") et les retirer par expression
   régulière — en supprimant la CLAUSE entière quand elle est purement
   narrative (une clause qui ne contient qu'une date/un renvoi n'a
   presque jamais de fait technique à préserver), pas juste le mot isolé
   qui laisserait une clause orpheline grammaticalement cassée.
2. **Vérifier par détection automatique d'anomalies, pas par relecture
   intégrale** : parenthèses déséquilibrées, phrase commençant par une
   minuscule ou une ponctuation orpheline, mots de narration encore
   présents, résumé qui dépasse la longueur voulue. Ne relire à la main
   QUE les entrées effectivement signalées — sur un corpus de plusieurs
   centaines de symboles, ça réduit le travail manuel à une poignée de
   cas réellement problématiques plutôt qu'une relecture exhaustive.
3. **Repérer les familles très répétitives** (des dizaines d'entrées
   quasi identiques décrivant chacune un élément d'un même type de
   structure, avec seulement quelques valeurs qui changent) et leur
   appliquer un gabarit dédié plutôt que le nettoyeur générique — plus
   fiable qu'une regex générique sur un texte répétitif, et ça donne un
   résultat uniforme entre entrées de la même famille.
4. **Là où deux sources existent pour le même symbole** (la table
   elle-même, souvent la plus ancienne/la plus terse, et le journal
   d'investigation détaillé, souvent enrichi bien après coup sans jamais
   être resynchronisé) : préférer systématiquement la source la plus
   riche/la plus récente comme base du nettoyage — ne jamais supposer
   que la table est à jour simplement parce que c'est "la" source
   structurée.
5. **Dériver le résumé court automatiquement de l'explication longue**
   (première phrase, ou coupure au dernier point de ponctuation
   raisonnable avant une borne de longueur) plutôt que le réécrire à la
   main pour chaque entrée — mais ne jamais couper au milieu d'une
   parenthèse ouverte : un résumé un peu plus long, ou tronqué SANS
   points de suspension, reste plus propre qu'une coupure qui donne
   l'impression que la phrase continue.

## 17. Déléguer la finalisation à des agents : cadrer précisément, puis vérifier soi-même

Quand le volume de "trous" à combler dépasse ce qui est raisonnable à
traiter à la main dans une seule session, déléguer fichier par fichier à
un agent dédié est efficace — À CONDITION de :

- **Cadrer le prompt avec tout ce qui est DÉJÀ connu**, pas seulement
  "va désassembler ce fichier". Citer explicitement les notes existantes
  qui décrivent déjà en prose le rôle probable d'une zone (une hypothèse
  écrite après observation en jeu, par exemple) — l'agent doit vérifier
  cette hypothèse au niveau de l'octet, pas la redécouvrir de zéro à
  l'aveugle (risque de contredire un travail déjà fait, ou de perdre du
  temps à re-dériver quelque chose de déjà établi).
- **Exiger explicitement la discipline confirmé/hypothèse** et
  l'obligation de corriger toute prose existante qui s'avère fausse une
  fois les octets réellement lus (cas réel rencontré : une description
  de routine affirmait "modifie deux bits précis d'un flag" alors que le
  désassemblage montrait deux AUTRES bits — l'agent avait pourtant
  décodé les bons octets, seule la description résumait mal ce qu'il
  avait lui-même trouvé).
- **Ne jamais faire confiance au rapport final tel quel** : après coup,
  reproduire soi-même la vérification de la section 16 (régénération
  indépendante + diff octet par octet), vérifier que tout fichier de
  note attendu existe réellement, vérifier qu'aucun autre fichier n'a été
  touché par erreur, et si l'émulateur live est disponible et fiable
  (section 15), croiser quelques adresses au hasard contre lui en plus
  du dump statique déjà utilisé par l'agent. Un agent peut très bien
  produire un travail interne cohérent (0 octet inventé, diff propre)
  tout en résumant mal sa propre découverte dans son rapport texte — la
  vérification porte sur les FICHIERS produits, pas sur le récit qui les
  accompagne.

## 18. Test comportemental A/B par polling RAM synchronisé, pendant que l'utilisateur joue en direct

Complément à la section 7bis (écriture ciblée) pour le cas où on ne veut
PAS piloter l'émulateur soi-même mais observer un geste réel de
l'utilisateur : lancer une boucle de lecture RAM rapprochée (60-100ms
d'intervalle sur une structure d'intérêt, ex. l'entité joueur) pendant
que l'utilisateur exécute une action précise et convenue à l'avance (ex.
"appuyez sur une direction différente de votre orientation actuelle,
maintenant"), puis relire la séquence de valeurs capturées pour repérer
la transition. Deux précautions essentielles :

- **Coordonner explicitement le timing avec l'utilisateur** (poser la
  question "c'est fait ?" avant de lancer la capture, ou lancer la
  capture et demander confirmation immédiate de l'action) — sans ça, la
  fenêtre de capture rate l'événement ou le capture à moitié.
- **Ne jamais mélanger les sources d'input** : si l'utilisateur pilote
  en direct (clavier/joystick réel dans le navigateur), NE PAS envoyer
  soi-même des touches via l'API en parallèle (section 14) — les deux se
  mélangent dans la même matrice clavier côté émulateur, ce qui rend la
  capture ininterprétable. Demander explicitement à l'utilisateur s'il
  pilote en direct avant de choisir entre "j'observe seulement" et "je
  pilote moi-même via l'API".

Cette méthode permet de trancher définitivement, en une seule session,
entre deux chemins de code déjà identifiés par désassemblage mais dont
le comportement RESPECTIF ne pouvait être établi que par observation en
direct — une comparaison A/B propre (même geste, deux réglages
différents) vaut mieux qu'un seul essai isolé, car elle élimine la
possibilité que la différence observée vienne d'autre chose (position,
timing, etc.) que le réglage testé.

## 19. Un breakpoint réarmé sur SA PROPRE adresse d'arrêt peut mentir sur le nombre de frames réellement écoulées

**Piège générique, pas spécifique à Knight Lore.** Un outil qui a besoin
d'« avancer de N frames de façon déterministe » a souvent le réflexe de
poser un breakpoint sur une adresse connue pour s'exécuter une fois par
frame (typiquement le sommet de la boucle principale), puis de faire
resume/wait N fois de suite en comptant les arrêts. C'est le patron déjà
documenté ailleurs dans ce fichier (piloter l'émulateur via
resume+breakpoint plutôt qu'un délai wall-clock) — mais **compter les
arrêts sur cette même adresse n'est PAS équivalent à compter les frames
réellement exécutées**, si l'API de breakpoint/pause de l'émulateur n'est
pas garantie synchrone avec sa propre boucle d'exécution.

Découvert le 2026-08-14 sur `tools/room_map/teleport.py` : un outil
supposait qu'un flag de rendu du jeu pouvait mettre "jusqu'à 10 frames,
selon la complexité de la salle" à retomber à zéro après un chargement de
salle, et avançait donc un nombre fixe de frames via breakpoint+resume
avant de faire une capture d'écran. Le symptôme observé (plusieurs salles
consécutives, pourtant différentes d'après la table d'entités, produisant
des captures PNG octet-pour-octet identiques) faisait à première vue
penser à un vrai délai variable côté jeu. Une instrumentation directe —
poser SIMULTANÉMENT un breakpoint sur l'adresse de boucle ET sur une
adresse plus loin dans le corps de la même itération, et comparer avec un
compteur de frames tenu par le jeu lui-même (une variable RAM incrémentée
une fois par frame, indépendante de tout breakpoint) — a montré que :

1. Le compteur de frames RÉEL du jeu n'avançait JAMAIS de plus d'une
   unité entre le chargement de la salle et la fin du "vrai" travail de
   rendu, sur TOUTES les salles testées (bonnes et buguées) : l'hypothèse
   d'un délai variable dépendant de la salle était donc fausse.
2. Le breakpoint posé sur l'adresse de boucle, lui, pouvait déclencher un
   "arrêt" SANS que ce compteur de frames n'ait progressé entre deux
   arrêts consécutifs — i.e. le mécanisme de breakpoint/pause de
   l'émulateur peut rapporter un hit qui ne correspond pas à un tour réel
   de boucle (une variante du problème déjà documenté ailleurs dans ce
   fichier : la suppression du breakpoint sur l'adresse où l'on est
   actuellement arrêté, et plus généralement l'absence de garantie de
   synchronicité entre l'API de contrôle et la boucle d'exécution de
   l'émulateur). Un compteur "N breakpoints atteints" peut donc sous-
   compter (ou, plus rarement, sur-compter) le nombre de frames réelles
   écoulées, silencieusement, sans erreur réseau ni timeout.

**Leçon générale** : pour un besoin de type "attends que la condition X
soit vraie côté jeu" (ici : un flag de rendu revenu à 0), interroger
DIRECTEMENT cette condition par lecture RAM en boucle (polling, avec
timeout de garde-fou) pendant une exécution non pausée, plutôt que de
compter des arrêts de breakpoint comme proxy du nombre de frames
écoulées. Le polling RAM lit l'état réel du jeu sans dépendre de la
fiabilité temporelle de l'API de breakpoint ; un compteur de frames tenu
par le jeu lui-même (quand il existe) est également un bien meilleur
juge du temps écoulé qu'un comptage d'arrêts de breakpoint sur une
adresse récurrente. Réserver les breakpoints aux besoins de type "arrête-
toi à CETTE adresse précise, une fois" plutôt qu'à un comptage répété sur
la même adresse. Voir `notes/2026-08-14-render-disabled-flag-settle-
race.md` pour le cas complet (diagnostic, mesures, correctif).

## 20. Portage d'un moteur de rendu : les conventions vont par PAIRES

Le piège le plus coûteux rencontré sur ce projet, et il est contre-intuitif :
**une lecture correcte du désassemblage peut conduire à casser un portage qui
marchait.** Vécu le 2026-08-15, une session entière perdue.

Le raisonnement fautif, qui paraît irréprochable :

1. le désassemblage dit sans ambiguïté que `screen_y` croît vers le bas et
   désigne le haut du sprite (test de culling contre la hauteur d'écran, et
   clipping sur `screen_y + hauteur`) ;
2. le portage, lui, travaille en +Y vers le haut avec une ancre bas-gauche ;
3. donc le portage a un bug de signe — corrigeons-le.

L'étape 3 est fausse. Le portage rendait **l'image correcte**, parce que son
extracteur de sprites produisait déjà des images **miroir** du rendu réel (un
`ROTATE_90` mal expliqué en fin de chaîne d'extraction). Le pipeline
appliquait donc le miroir DEUX FOIS, et les deux se composaient. En corriger
une moitié — même la bonne, même pour la bonne raison — a tout cassé : murs
tête en bas, portes déplacées, empilements faux.

**La règle** : dans un portage, une convention n'est jamais seule. Elle forme
une paire avec l'orientation des ASSETS, et c'est seulement la composition des
deux qui est observable. Vérifier une moitié contre la ROM ne prouve
strictement rien sur le résultat. Corollaire pratique : avant de toucher à une
convention de rendu dans un portage **qui fonctionne**, exiger une vérité
terrain (capture du jeu réel) et savoir reproduire la sortie actuelle — sinon
on ne peut même pas constater la régression qu'on introduit.

Corollaire sur le diagnostic : une accumulation de réglages « posés à l'œil »
(tri en profondeur inversé, ancre déplacée, UV retournées) ressemble beaucoup
à plusieurs rustines sur une même erreur amont. **Ce n'est pas une preuve
qu'il y en a une.** Ce peut être un système cohérent qui compense une
transformation subie en amont par la chaîne d'assets. Les deux hypothèses se
départagent en reproduisant la sortie, pas en relisant la ROM.

## 20bis. Une famille de stubs `LD HL,nn / JR queue` = une table de constantes écrite en code

Motif Z80 fréquent, à reconnaître d'un coup d'œil : *n* mini-routines
consécutives, chacune chargeant une valeur immédiate puis sautant vers une
queue commune qui l'écrit dans un champ de structure. Ce n'est pas *n*
routines, c'est **une table de constantes indexée par adresse d'appel** — le
compilateur du pauvre, plus court qu'une table + un index quand chaque type
a déjà son entrée de dispatch.

Intérêt méthodologique : très rentable à désassembler.
- La **queue commune** dit à quoi sert la table (ici : écrire
  `proj_offset_x/y`), donc tous les appelants d'un coup.
- Les **appelants** donnent la correspondance type → constante gratuitement,
  chacun par son `call <adresse d'entrée>`.
- La table est **exhaustive par construction** (elle se termine où commence
  la routine suivante), là où un relevé de valeurs en RAM live ne couvre que
  les types rencontrés dans les salles visitées.

Corollaire sur la hiérarchie des preuves : le relevé live et la table ROM ne
sont pas de même rang. Le live est rapide et sert d'amorce, mais il est
partiel et ne dit pas *d'où vient* la valeur ; la table ROM est complète et
explique le mécanisme. Quand une valeur relevée en direct paraît aberrante,
la remonter à sa source dans la ROM **avant** de la corriger : dans ce
projet, une valeur « manifestement fausse » (décalage vers le bas pour ce
qu'on croyait être un torse) était exacte — c'était le *nom* donné à
l'entité, pas la donnée, qui était trompeur.

## 21. Établir une orientation de sprite : ce qui marche et ce qui ment

Quatre méthodes essayées sur la même question (dans quel sens redresser les
sprites extraits), trois ont échoué **avec assurance**. Le classement vaut
pour tout portage graphique :

| Méthode | Verdict |
|---|---|
| Déduire du désassemblage | Exact sur la ROM, **muet** sur le portage (voir §20) |
| Juger à l'œil un sprite ISOLÉ | Faux 2 fois — un cube reste plausible retourné |
| Comparer pixel à pixel à une référence | Mesure exacte (écart 0), **cible fausse** |
| Comparer à une capture du jeu réel | Tranché immédiatement |

Deux enseignements transposables :

1. **Une mesure ne vaut que ce que vaut sa référence.** Un écart de 0 contre
   la mauvaise cible produit une conclusion fausse *assortie d'une grande
   confiance* — bien pire qu'une incertitude assumée. Toujours se demander
   d'où vient la cible avant de se réjouir du score. De même, une métrique de
   similarité d'images qui classe les hypothèses à 4 % d'écart ne tranche
   rien : ne pas en désigner de gagnant.
2. **Choisir un critère d'ASSEMBLAGE, pas d'apparence.** Un objet isolé est
   souvent invariant, ou plausible, sous plusieurs transformations. Un critère
   qui met en jeu PLUSIEURS entités adjacentes ne l'est pas : ici, les deux
   moitiés d'une porte (deux entités distinctes) doivent se rejoindre en une
   arche avec clé de voûte ; sous toute autre orientation elles s'écartent en
   « V ». Chercher systématiquement ce genre de contrainte de raccord — deux
   moitiés d'un même objet, un motif continu à cheval sur deux tuiles.

## 21bis. Écrire un rendu de référence hors moteur

Quand le rendu d'un portage est faux, le retour disponible se limite souvent à
« ça ne ressemble à rien » : impossible de savoir si le fautif est la
projection, la calibration, le tri en profondeur, les UV ou l'échantillonnage,
puisqu'on n'observe que leur composition.

Un script de ~100 lignes qui réimplémente la même géométrie dans l'outil le
plus bête disponible (ici PIL, sans GPU ni shader) et produit une image
regardable règle ça. Il **isole les couches**, permet la comparaison A/B de
deux hypothèses côte à côte dans une même image, et se superpose à une capture
du jeu réel si on le fait rendre en coordonnées écran ABSOLUES.

**Point crucial, appris de travers** : si ce rendu sert d'ARBITRE, il doit
**transcrire l'implémentation en place**, pas re-dériver la géométrie depuis
la ROM. Une référence re-dérivée n'arbitre rien — elle ne fait qu'ajouter une
troisième opinion, et si elle se trompe elle valide des correctifs faux (cf.
§21, « cible fausse »). Transcrire le shader ligne à ligne, y compris ses
détails ingrats (l'inversion d'axe de texture au chargement, par exemple).

## 21. Jeu soeur du même moteur : porter un désassemblage déjà confirmé par comparaison binaire

Quand un second jeu partage le même moteur qu'un jeu déjà désassemblé
(même éditeur, même gamme, souvent sorti la même année ou l'année
suivante — ex : deux jeux Ultimate Play The Game sur le "moteur
Filmation"), une comparaison binaire directe entre les deux images RAM
(dump ou snapshot) accélère considérablement le démarrage, **en plus**
des techniques déjà décrites (elle ne les remplace pas).

**Méthode** :
1. Recaler les deux images à la même adresse CPU (0x0000-0xFFFF) — un
   snapshot `.sna` a un header fixe (0x100 octets pour la variante
   standard) suivi de la RAM vue par le Z80 ; un dump brut est déjà
   dans cette vue. Attention à ne comparer que des vues CPU équivalentes
   (même config banking/ROM si le jeu bascule des banques).
2. **Comparaison adresse-à-adresse brute** (octet identique à la même
   adresse dans les deux images) : donne un signal grossier, souvent
   dominé par du bruit dès que le code spécifique à chaque jeu diffère
   en taille (tout ce qui suit un point de divergence est décalé, donc
   retombe au niveau du hasard ~0.4%/octet). Utile surtout pour repérer
   de GROS runs identiques (des dizaines/centaines d'octets consécutifs)
   qui signalent : (a) du code moteur sans aucun opérande absolu
   (vecteurs RST, primitives pures), ou (b) des tables **calculées** au
   boot par le même algorithme (donc byte-identiques en sortie même si
   le code générateur est ailleurs en mémoire — cf. section 8bis,
   prudence : l'identité du résultat ne prouve pas encore l'identité du
   mécanisme, seulement une forte présomption).
3. **Signal le plus utile : squelette d'instructions identique avec
   seulement des opérandes numériques qui diffèrent**, à repérer POUR
   CHAQUE zone où la comparaison brute échoue mais où le code moteur est
   probablement quand même partagé (ex : la séquence de boot juste
   après le point d'entrée machine). Désassembler manuellement la même
   fenêtre d'adresses dans les deux jeux et comparer instruction par
   instruction plutôt qu'octet par octet : un `CALL`/`JP`/`LD nn` dont
   seul l'opérande diffère, entouré d'instructions strictement
   identiques des deux côtés, est une preuve directe que c'est LA MÊME
   routine moteur, juste recompilée avec des adresses/tailles propres à
   ce jeu (tables plus grandes pour un jeu sorti plus tard, layout
   mémoire légèrement décalé, etc.).
4. Chaque symbole ainsi identifié peut être porté dans la table de
   symboles du nouveau jeu avec un statut dédié (ex :
   `confirmed (cross-game)`) — distinct de `confirmed` (désassemblage +
   vérification indépendante sur CE jeu) et de `hypothesis` : le rôle
   est connu avec un haut degré de confiance (hérité du jeu de
   référence), mais **pas encore revérifié indépendamment** sur le
   nouveau jeu. Ne jamais présenter ce statut comme équivalent à
   `confirmed` plein — un jeu soeur peut diverger subtilement sur une
   routine en apparence identique (version du moteur différente, bug
   corrigé/introduit d'un jeu à l'autre).
5. Ce que cette méthode NE remplace PAS : le code réellement spécifique
   au nouveau jeu (logique de ses propres entités, disposition de ses
   salles) n'a pas d'équivalent dans le jeu de référence et doit être
   redécouvert avec les techniques habituelles (codemap dynamique,
   breakpoint+historique, etc.).

**Limite** : nécessite qu'un jeu de référence du même moteur ait déjà
été désassemblé et documenté avec le même niveau de rigueur
(confirmé/hypothèse) — sinon on ne fait que déplacer l'incertitude
d'un jeu vers l'autre sans jamais la résoudre.

**Corollaire (rencontré en portant l'outil de téléportation de salle
d'un jeu à l'autre, 2026-08-17)** : une adresse structurellement
analogue (même rôle apparent à un offset homologue) n'implique PAS
qu'elle se comporte identiquement. Exemple concret : `var_render_
disabled_flag` (Knight Lore, retombe à 0 en exactement 1 frame après
chargement de salle) a une adresse strictement identique chez le jeu
soeur, mais sondée en direct (polling RAM pendant 1s après une
téléportation) elle est restée bloquée à 1 en permanence — ce n'est
donc PAS le même mécanisme, juste la même adresse par coïncidence
structurelle (ou un rôle réellement différent dans cette version du
moteur). **Ne jamais réutiliser un signal de synchronisation "porté"
(délai de stabilisation, flag de fin de rendu, etc.) sans le valider
par polling direct d'abord** — en cas d'échec, un délai fixe généreux
(mesuré empiriquement en ralentissant jusqu'à ce que le symptôme
disparaisse) reste une solution pragmatique pour avancer, quitte à
perdre en vitesse d'exécution, plutôt que de bloquer sur l'identification
du vrai signal.

## 22. Une copie renommée à la main d'un artefact généré devient orpheline en silence

Un outil de RE qui régénère un artefact (ex. `tools/sprite_dump.py`,
sortie nommée uniquement par adresse ROM) ne connaît rien des copies
créées à côté, à la main, pour l'améliorer (ex. renommer
`sprite_6A8E_...` en `sprite_hero_up1_6A8E_...` pour aider la lecture
humaine pendant l'analyse). Une régénération ultérieure (ex. après un
changement de format de rendu) ne touche QUE ses propres noms de
fichiers — la copie renommée reste figée dans l'ANCIEN format,
silencieusement, sans erreur ni avertissement, jusqu'à ce qu'un code
consommateur pointe dessus par erreur et échoue sur un contenu périmé
(vécu : un portage web référençant la copie "amicale" a chargé un sprite
resté en niveaux de gris après le passage aux couleurs, provoquant un
plantage de chargement de texture le temps de comprendre que deux
fichiers distincts coexistaient pour la même donnée).

**Symptôme reconnaissable** : deux fichiers de tailles différentes pour
la même adresse/le même contenu logique, l'un à jour, l'autre pas —
souvent avec des dates de modification très éloignées (l'orphelin porte
la date de sa création, jamais mise à jour depuis).

**Parade** : si un nom "amical" est utile pour l'analyse humaine, le
garder comme métadonnée à côté du fichier canonique (nom du symbole dans
`symbols.json`, une étiquette dans un manifest) plutôt que comme un
DEUXIÈME FICHIER dupliqué — un seul artefact, généré et référencé par un
nom stable, pas deux dont un finit par mentir. Si des doublons "amicaux"
existent déjà, soit les régénérer dans le même passage que l'artefact
canonique, soit les supprimer une fois que le nom amical est retrouvable
autrement (ici : `asm/symbols.json` porte déjà chaque nom de sprite par
adresse, donc les copies PNG dupliquées ont été supprimées sans perte
d'information).

## Limites connues de cette méthode

- Le sondage par breakpoint + poll a un coût réel (chaque hit/step est
  un aller-retour réseau) — pour des routines appelées très fréquemment
  (plusieurs fois par frame), préférer laisser tourner plus longtemps
  entre deux vérifications plutôt que de step un par un.
- La codemap ne distingue pas *pourquoi* une adresse a été exécutée
  (juste qu'elle l'a été) — deux appelants différents d'une même routine
  ne se voient pas dans la codemap seule, il faut le breakpoint+historique
  pour ça.
- Le format de breakpoint bank-qualifié (`Cx:YYYY`) est à explorer si le
  jeu utilise du banking RAM étendu.
- **Le single-step en boucle ne scale pas pour traverser une routine qui
  elle-même boucle sur une attente matérielle** (ex: scan clavier/PSG
  avec DI/EI et polling de statut) — le nombre de pas nécessaires peut
  exploser sans jamais atteindre la cible si le chemin d'exécution
  repasse par une boucle d'attente matérielle qui boucle un nombre de
  fois variable selon l'état du hardware émulé. **Dans ce cas, préférer
  un breakpoint direct sur l'adresse cible précise** plutôt que de
  vouloir tracer tout le chemin instruction par instruction — et si même
  un breakpoint direct ne se déclenche pas malgré des actions répétées,
  c'est un signal que l'hypothèse sur "quand" la routine s'exécute est
  probablement fausse (garde non satisfaite, chemin d'exécution différent
  de celui supposé) plutôt qu'un problème d'outil. Accepter de
  documenter l'incertitude plutôt que de s'acharner sur une approche qui
  ne progresse pas.
