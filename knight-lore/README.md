# Knight Lore — Reverse Engineering

Rétro-ingénierie du portage CPC de **Knight Lore** (Ultimate Play The Game /
Ashby Computers and Graphics Ltd, © 1984), à partir d'un dump RAM 64K de la
version CPC tournant sous AMSpiriT-Lite.

## Contexte

- Le jeu est un portage ("speccy port") du ZX Spectrum vers le CPC : le code
  original a été porté avec une couche de compatibilité, sans exploiter les
  spécificités du CPC (Gate Array, CRTC...). Conséquences observées : le jeu
  est plus lent et visuellement moins abouti qu'un jeu nativement écrit pour
  CPC.
- Rendu isométrique ("Filmation engine" — nom donné après coup par la scène
  retro ; ici on (re)découvre son fonctionnement par nous-mêmes).
- Tout le jeu tient en RAM (pas de chargement additionnel depuis le menu),
  pas de données a priori décompressées à la volée (à vérifier/affiner).

## Règle du jeu (méthode)

**On désassemble et on comprend par nous-mêmes**, sans aller chercher de
désassemblage ZX Spectrum déjà publié ni de documentation externe sur le
moteur. Toutes les hypothèses ci-dessous viennent de l'observation directe
(RAM live, codemap d'exécution, désassemblage statique) via l'émulateur.
Cette regle sera levée pour les prochaines sessions sur d'autres jeux, ici 
on l'instaure pour pouvoir apprendre des méthodolofies

## Objectifs (par ordre croissant d'ambition)

1. **Cartographier** la mémoire : zones code vs données, tables, sprites,
   écran.
2. **Comprendre l'organisation** : boucle principale, gestion des acteurs/
   objets, moteur de rendu isométrique, gestion des collisions, IA basique.
3. **Objectif initial concret** : produire une **version annotée et
   commentée du code source du jeu, réassemblable** (désassemblage complet
   avec noms symboliques, commentaires, structure claire — pas juste des
   notes éparses). C'est un livrable central de ce projet, pas juste une
   étape intermédiaire.
4. Génerer une **carte du monde par capture d'écran** des 128 salles
5. **Identifier les pistes d'optimisation/amélioration** propres au CPC
   (Gate Array, palette, CRTC) que le portage n'exploite pas — permis
   par la disponibilité du source annoté (point 3).
6. réécrire le jeu (ou son moteur) en C/C++ ou JS, portable
   PC, à partir du source annoté produit au point 3.
7. ** Objectif ultime**: dégager une méthodologie d'analyse et reverse engeneering 
   plus générale,  applicable à d'autres jeux, en partant de jeux similaires 
   (meme moteur, meme principe), et en allant vers des jeux de plus en plus variés.
   Cela inclus la création d'outils efficaces.

## Outils

- **AMSpiriT-Lite** (`amspirit-lite/tools/mcp-emulator`), piloté via son API :
  lecture RAM live, désassembleur Z80 (`z80dis.py`, tools `disassemble` /
  `disassemble_range` / `analyze_code_zones`), codemap d'exécution dynamique,
  breakpoints, stepping, screenshots. Un serveur MCP existe, mais Claude Code 
  n'en n'a pas besoin et sait se servir de l'api 
- **`tools/pixel_quantize.py`** (ce dépôt) : capture d'écran → grille de
  pixels quantifiés sur la palette GA active (indices de pen 0-3 en Mode 1,
  0-15 en Mode 0, 0-1 en Mode 2). Sert de contournement du manque de vision 
  native sur les images dans cet environnement, d'autant plus qu'il faut 
  tenir compte de la facon dont les pixels sont encodés sur CPC.
  Détecte automatiquement le doublement de pixel horizontal du CPC.
- **`tools/disasm.py`** (ce dépôt) : désassembleur autonome en ligne de
  commande Utile pour une recherche statique exhaustive (ex :
  "quelle instruction référence l'adresse X ?") plus rapide à scripter
  qu'un aller-retour breakpoint/history — voir
  `notes/2026-08-07-object-catalog-randomizer.md` pour un exemple d'usage.

## Structure du dépôt

- `docs/SESSION_SUMMARY.md` — **synthèse globale à jour**, avec
  diagrammes de principe (pipeline de rendu, call graph, machine à
  états jour/nuit, graphe de navigation entre salles) et bilan par
  thème. **Point d'entrée recommandé pour reprendre le travail** dans
  une nouvelle session (le contexte de conversation ne persiste pas
  d'une session à l'autre, mais tous les fichiers de ce dépôt oui).
- `docs/SYMBOLS.md` — **table des symboles** : associe chaque adresse
  connue à un nom symbolique (`fn_`/`tbl_`/`var_`/`struct_`) et son
  statut de confiance. Référence centrale pour la génération du
  source annoté et la réécriture en C — à tenir à jour à chaque nouvelle
  routine/donnée identifiée, quitte à réviser un nom déjà posé si
  l'interprétation change.
- `docs/METHODOLOGY.md` — **stratégies de rétro-ingénierie génériques**,
  réutilisables pour tout autre jeu CPC/Z80 (pièges connus, techniques de
  désambiguïsation code/données, reconnaissance de primitives par leur
  forme, méthode fiable pour retrouver un appelant, etc.). À lire/enrichir
  en priorité avant de démarrer l'analyse d'un nouveau jeu.
- `docs/MEMORY_MAP.md` — cartographie mémoire, notes de conception du
  moteur, symboles nommés au fur et à mesure qu'on les identifie.
- `notes/` — journal de session brut (désassemblages annotés, hypothèses en
  cours de vérification, captures d'état).
- `tools/` — scripts d'aide spécifiques à ce projet (extraction de tables,
  dump de sprites, creation de la map du jeu, etc.)
- `web/` — portage/visualiseur JS (TypeScript + WebGL2) : rendu isométrique
  des salles à partir des données extraites par `tools/`. Projet npm autonome
  (`cd web && npm run dev`), volontairement isolé de la racine du dépôt de RE.
- `asm/` — source assembleur annoté, avec des symboles et des commentaires. 
   Peut etre réassemblé et utilisé pour verifier que le source est correct 
   en comparant avec la RAM ou un dump binaire
- `extra` : des ressources liées au jeu: fichiers DSKs, snapshots utiles, 
   documents divers

## État actuel

Voir `docs/SESSION_SUMMARY.md` pour la synthèse à jour et les pistes
ouvertes. 


