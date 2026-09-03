# 2026-08-14 — Déclenchement en direct de la fin du puzzle de Melkhior

## Objectif

L'utilisateur n'a jamais vu, en jeu, l'effet de la complétion du puzzle
de collecte ordonnée (`fn_treasure_settle_and_sequence_check` #1A93,
14e succès -> `fn_pickup_sequence_complete_transform` #1B76). Le
désassemblage seul décrivait les octets modifiés mais pas leur
conséquence visuelle/gameplay réelle. Objectif de session : aller en
salle 0x88 (chaudron de Melkhior), forcer artificiellement la
complétion, poser un point d'arrêt sur `fn_pickup_sequence_complete_transform`
et observer/capturer ce qui se passe.

## Méthode (déclenchement forcé, PAS le mécanisme naturel)

Le mécanisme naturel de création d'une entité de la famille 0x68-0x6E
(objet effectivement déposé dans le chaudron) reste NON localisé (voir
docs/SYMBOLS.md, entrée 0x1A93) — pas résolu cette session, contourné
délibérément :

1. Téléportation en salle 0x88 via `tools/room_map/teleport.py`
   (technique déjà validée, réutilisée telle quelle).
2. Lecture de `tbl_pickup_sequence_order` (0x1B1D, 14 octets) et
   `var_pickup_sequence_counter` (0x0081) pour connaître la valeur
   attendue au 14e rang (`order[13]`).
3. Une entité de décor existante (montant de porte, slot 4) est
   directement patchée en mémoire : type = `0x68 + order[13]`,
   position pré-réglée à `grid_x=grid_y=grid_z=0x80` (évite d'attendre
   la convergence normale — voir piège ci-dessous), flags=0.
4. `var_pickup_sequence_counter` préréglé à 13 (juste avant le seuil).
5. Point d'arrêt Z80 sur `0x1B76`, reprise de l'exécution.

## Piège rencontré : l'émulateur headless tourne très lentement

Premier essai (sans pré-positionnement) : timeout, le point d'arrêt
n'a jamais été atteint en 6s. Diagnostic par polling direct de
l'entité : elle progressait bien (dispatch confirmé atteint via un
point d'arrêt sur `0x1A93` lui-même, IX correct), mais `grid_y`
converge d'exactement ±1 par frame RÉELLE vers 0x80, et l'instance
`amspirit-lite --web-server` tournant en arrière-plan (rendu logiciel,
`LIBGL_ALWAYS_SOFTWARE=1`) ne tourne qu'à ~1-2 fps réels — la
convergence depuis un point de départ éloigné (delta ~0x44) aurait pris
plusieurs dizaines de secondes. Corrigé en pré-positionnant l'entité
exactement à la cible avant de patcher son type, rendant la
convergence quasi instantanée. **Généralisable** : toute expérience
similaire nécessitant une convergence multi-frames doit soit tolérer
un timeout long, soit pré-positionner l'état pour éviter d'attendre la
simulation réelle image par image.

## Effet secondaire découvert : joueur figé en pleine transformation

En arrivant, le joueur (slot 0) avait `off_type=0x5C` (état transitoire
de la séquence jour/nuit 0x5C-0x5F), pas un type stable — probablement
parce que les mises en pause fréquentes entre appels HTTP ont figé
l'animation en plein milieu (elle n'avance que d'une étape toutes les
~2 frames réelles, et très peu de frames réelles s'étaient écoulées).
Corrigé en forçant `off_type=0x14` (jour/explorateur stable) pour un
rendu propre. Non lié à la question de la fin du jeu, mais bon rappel
méthodologique : après une longue séquence de pauses/lectures, vérifier
l'état du joueur avant de conclure quoi que ce soit sur le rendu.

## Résultat observé (CONFIRMÉ EN DIRECT)

Au point d'arrêt (`0x1B76`, `var_pickup_sequence_counter`=14 confirmé) :
comportement identique à la lecture statique (voir docs/SYMBOLS.md
0x1B76/0x1BAF) — `var_special_input_mode_1`(0x0089)=1, slots 3-13
forcés à type=0x01, slots 29-36 (les 8 blocs statiques 0x07 de la
salle) convertis en type=0x83.

**Nouveau (pas visible depuis le désassemblage seul)**, en laissant
tourner quelques frames réelles supplémentaires :
- Slots 12/13 (le corps et les jambes de Melkhior, dans la plage
  3-13) : type=0x01 puis, quelques frames plus tard, **type=0x00** —
  Melkhior est entièrement désactivé/disparu de la salle.
- Slots 29-36 (ex-blocs statiques) : cyclent réellement entre 0x83/0x84
  (et probablement 0x85), leur `grid_x`/`grid_y` CHANGE réellement
  frame après frame — ils patrouillent activement, ce ne sont plus des
  blocs immobiles.
- Capture d'écran : le magicien a disparu, la salle autour du chaudron
  est remplie d'étincelles jaunes scintillantes (voir
  `tbl_sprite_dispatch[0x83]`=`sprite_poltergeist3_52B1`,
  `[0x84]`=`sprite_poltergeist5_521E` — famille POLTERGEIST déjà
  identifiée pour 0xA0-0xAB, PAS un sprite à part comme le
  désassemblage seul le laissait supposer ("visuel non identifié")).

**Interprétation** : ce n'est PAS un écran de victoire/générique
séparé. La boucle de jeu continue normalement (`jp #1239`). L'effet
observable de la complétion du puzzle est : le magicien disparaît, et
la salle qui l'abritait devient un piège actif (poltergeists mortels
au contact, `fn_player_proximity_death` toujours testée dans
`fn_hostile_patrol_logic`). Cohérent avec une lecture "on lève la
malédiction du magicien mais son antre se retourne contre vous."

## Suite — mécanisme naturel RÉSOLU (même session, après le déclenchement forcé)

L'utilisateur a confirmé sa compréhension du jeu : "le déclencheur,
c'est quand on dépose tous les objets 'demandés' dans le chaudron".
Sur cette base, désassemblage direct de la queue de dépôt de
`fn_player_use_held_object` (#1951-#19DD, jusque-là seulement
partiellement comprise) : la branche "déposer l'objet tenu" teste
`(ix+08)==0x88` (salle de Melkhior) ET `(ix+03)>=0x98` (hauteur du
joueur) — si les deux sont vrais, `SET 3,(iy+00)` pose le bit3 du type
de l'objet tenu (0x60-0x66), ce qui l'incrémente arithmétiquement de
+8 (0x68-0x6E). **Ceci résout le mécanisme de création d'entité
0x68-0x6E**, non localisé depuis plusieurs sessions. Concrètement :
déposer un objet en étant en hauteur (le pédestal/rebord du chaudron)
dans la salle 0x88 le transforme en sa variante "offrande" — qui
retombe alors sous `fn_treasure_settle_and_sequence_check` (#1A93),
exactement le chemin simulé artificiellement plus haut dans cette
note. Voir docs/SYMBOLS.md, entrées 0x18AA et 0x1A93.

## Vérification en direct du mécanisme naturel (même session)

L'utilisateur ne voulait pas rejouer toute la partie pour collecter les
14 objets légitimement — deux options proposées : "soit j'ai tous les
objets... soit on dépose uniquement le dernier". Choix du second, avec
l'état "tient déjà l'objet" simulé (plutôt que le ramassage réel, qui
s'est avéré fragile lors d'un essai précédent — voir ci-dessous) :

- Premier essai avorté (salle 0x0xBA, objet réel à ramasser) : la
  séquence habituelle de téléportation + retries automatiques (le
  joueur avait "spike-death respawn" une fois) a fini par CORROMPRE
  l'entrée du catalogue correspondante (son type est tombé à `0x00`
  au lieu de rester `0x66` ou passer à `0xBB`) — cause exacte non
  élucidée (probable interaction entre nos écritures RAM directes et
  `fn_object_catalog_writeback`/`fn_instantiate_room_objects`
  s'exécutant en parallèle). Abandonné sans conséquence grave (juste
  un objet perdu sur les 32 du catalogue de cette partie).
- Repli : simulation propre de l'état "tient un objet" en écrivant
  directement le petit tampon `0x00B3-0x00B6` (`type=0x66`, `flags`,
  pointeur catalogue vers une entrée intacte) + un marqueur "occupé"
  dans le slot 3 (`0x012B`) — sans passer par le vrai ramassage.
  Joueur téléporté salle 0x88, positionné en hauteur (`grid_z=0x98`),
  gardes `(0x0097)`/`(0x0079)`/`cooldown_or_collision_flags` forcés
  pour ne pas bloquer la routine sur des préconditions non testées.
  Point d'arrêt posé sur `0x1973` (l'instruction `SET 3,(iy+00)`
  elle-même).
- L'utilisateur a appuyé UNE FOIS sur le vrai bouton d'action. Le point
  d'arrêt s'est déclenché immédiatement (`PC=0x1973`, `IX`=joueur,
  `IY=0x010F`). Single-step de cette seule instruction :
  `(iy+00)` passe de `0x66` à `0x6E`, capturé avant/après.
- Point d'arrêt déplacé sur `0x1B76` (`fn_pickup_sequence_complete_transform`)
  et exécution reprise : atteint quelques frames plus tard,
  `var_pickup_sequence_counter`=14 confirmé — la chaîne complète (dépôt
  réel → conversion de type → règlement de position →
  `fn_treasure_settle_and_sequence_check` → complétion) s'enchaîne
  exactement comme prévu par le désassemblage, à partir d'un vrai
  geste utilisateur.

**Conclusion** : le mécanisme de dépôt (`SET 3,(iy+00)` conditionné à
salle 0x88 + hauteur) n'est plus seulement une lecture de
désassemblage — il est confirmé par exécution réelle déclenchée par
l'utilisateur.

## Limites / ce qui reste ouvert

- La partie "ramassage" du geste naturel (marcher jusqu'à l'objet et
  appuyer sur le bouton pour le prendre) n'a PAS été revérifiée en
  direct suite à l'incident de corruption du catalogue en salle 0xBA —
  seul le DÉPÔT (avec un objet tenu simulé) a été testé. Le code de
  ramassage lui-même (#190E-#1919, #19E0+) reste confirmé par
  désassemblage seul.
- Pas vérifié si une transformation ADDITIONNELLE existe plus loin
  dans la partie (ex. un vrai écran de fin déclenché ailleurs par la
  disparition de Melkhior) — seules les ~20 frames suivant le point
  d'arrêt ont été observées.
- La session live du joueur (partie en cours, day 33, 4 vies) a été
  directement modifiée par ces patches. Effet attendu réversible :
  les entités de salle 0x88 ne font pas partie du catalogue persistant
  (`tbl_object_catalog`), donc quitter puis revenir devrait les
  réinitialiser depuis le template normal au prochain chargement de
  salle — non vérifié explicitement en fin de session.

## Captures

Screenshots sauvegardés dans le répertoire scratchpad de la session
(non versionnés — à re-générer si besoin en rejouant la séquence
ci-dessus) : avant/juste-après le point d'arrêt (salle identique,
magicien encore visible) et après ~4s/17 frames réelles supplémentaires
(magicien disparu, blocs transformés en étincelles).
