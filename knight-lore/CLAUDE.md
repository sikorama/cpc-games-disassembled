
Ce projet a DEUX objectifs, pas un seul :

1. Désassembler intégralement le jeu Knight Lore sur Amstrad CPC (livrable concret : `/asm`).
2. **Objectif transversal, au-delà de Knight Lore** : établir et documenter une méthodologie générale de rétro-ingénierie de code Z80/Amstrad CPC, réutilisable sur d'autres jeux/projets similaires. C'est `docs/METHODOLOGY.md` qui porte cet objectif — chaque technique/piège générique découvert en travaillant sur Knight Lore doit y être noté, indépendamment de la spécificité du jeu. Ne pas perdre de vue cet objectif même quand le travail du moment est très spécifique à Knight Lore : se demander systématiquement "est-ce que cette astuce/ce piège se généralise à n'importe quel jeu CPC ?" avant de la laisser seulement dans une note de session.

Le fichier README.md donne un bon apercu du projet, et les documents dans le répertoire docs sont les plus importants:

docs/METHODOLOGY.md : les points importants dans la démarche de reverse engeneering
docs/MEMORY_MAP.md
docs/SYMBOLS.md : les symboles du source assembleur
docs/SESSION_SUMMARY.md
docs/RENDERING_PIPELINE.md : l'algorithme de rendu isométrique complet, indépendant de l'implémentation Z80 -- référence pour une future réécriture dans un autre langage

Le code désassemblé (en cours) est dans /asm
Les tools dans /tools servent à générer la map, ou encore désassembler une partie de la ram du jeu quand il est en cours d'execution dans l'émulateur amspirit

Le répertoire notes contient des informations à prendre avec des pincettes, car il y a dedans des hypotheses de travail pas toujours vérifiées, donc à consulter en dernier recours si les documents précédents ne contiennet pas les information recherchées



