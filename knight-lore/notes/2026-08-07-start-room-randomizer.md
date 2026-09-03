# Session 2026-08-07 (suite 16) — Randomiseur de salle de départ ÉLUCIDÉ

## Contexte

L'utilisateur a proposé : "le randomiseur doit être au lancement de
chaque partie. D'ailleurs la pièce de démarrage est aléatoire (parmi
une sélection)". Vérifié immédiatement par désassemblage du chemin de
restart (0x0542).

## DÉCOUVERTE : fn_init_room_selection (0x2A33) — sélection parmi 4 salles fixes

**Statut : CONFIRMED** par désassemblage direct.

```
2A33  LDIR (copie le template "type 0x12" statique, 8 octets, vers 0x29EB)
2A3E  LDIR (copie un 2e bloc statique vers 0x2A07)
2A46  LD A,12 / LD (29FB),A       ; type par défaut = 0x12 (joueur, forme jour)
2A4B  LD A,22 / LD (2A17),A       ; 2e valeur par défaut

2A50  LD A,(0068)                 ; lit le compteur "accumulateur pseudo-aléatoire léger"
2A53  AND 03                      ; garde seulement 2 bits -> index 0-3
2A55  LD L,A / LD H,00
2A58  LD BC,2A64                  ; base de la table des 4 salles de départ possibles
2A5B  ADD HL,BC
2A5C  LD A,(HL)                   ; lit la salle choisie
2A5D  LD (29F3),A                 ; écrit dans le champ room du template joueur (entité 0)
2A60  LD (2A0F),A                 ; écrit AUSSI dans le champ room du 2e template (entité double)
2A63  RET
```

**Table des 4 salles de départ possibles (0x2A64)** :

```
0x2A64: 0x2F
0x2A65: 0x44
0x2A66: 0xB3
0x2A67: 0x8F
```

**Confirmation immédiate** : ces 4 valeurs correspondent EXACTEMENT à
des salles déjà rencontrées comme "salle de départ" au fil des
sessions précédentes (0x2F et 0x8F en particulier, mentionnées dans
`docs/SESSION_SUMMARY.md` comme rooms de test récurrentes après un
restart de partie) — confirme que cette table est bien la bonne, sans
ambiguïté.

## Source du "hasard" : `(0x0068)` — un compteur de TIMING, pas un vrai RNG dédié

Retracé jusqu'à `0x0574` (dans la séquence de restart 0x0542) :

```
0574  LD HL,0068
0577  LD A,(006A)        ; var_frame_counter (compteur de frames incrémenté en continu)
057A  ADD A,(HL)          ; (0x0068) += (0x006A)
057B  LD (HL),A
```

**Interprétation** : `(0x0068)` accumule la valeur du compteur de
frames `(0x006A)` à un moment précis de la séquence de restart. Comme
`(0x006A)` dépend du nombre exact de frames écoulées depuis le
lancement de l'émulateur/la console (donc du TIMING PRÉCIS auquel le
joueur appuie sur "0" pour démarrer), la valeur résultante de
`(0x0068)&3` est en pratique imprévisible pour un joueur humain, sans
être un générateur pseudo-aléatoire dédié comme `var_pseudo_random_acc`
(0x006D, qui lui est réellement conçu comme tel et utilisé par les
ennemis). **C'est un classique "hasard par timing humain"**, pas un
vrai RNG — cohérent avec les contraintes d'un Z80 8-bit de 1984.

**Conséquence pratique pour une future cartographie/reproductibilité** :
la salle de départ N'EST PAS vraiment aléatoire au sens strict — un
outil externe pourrait en théorie la prédire/forcer en contrôlant le
nombre exact de frames écoulées avant d'envoyer la touche "0", ou plus
simplement en patchant directement `(0x0068)` avant l'appel à
`fn_init_room_selection` (0x2A33) pour choisir la salle de départ à
volonté parmi les 4 options — utile si on reprend un jour la
cartographie automatique évoquée `notes/2026-08-07-room-mapping-tool-failure.md`.

## Réponse partielle à "le randomiseur d'objets" (chantier ouvert depuis plusieurs sessions)

**Cette découverte concerne UNIQUEMENT la salle de départ du joueur,
PAS le placement des objets à ramasser dans les salles** (boules de
cristal, etc.) — ce dernier randomiseur (mentionné comme piste ouverte
depuis `notes/2026-08-07-room-mapping-tool-failure.md`) reste À
LOCALISER séparément. Cependant, cette découverte donne une piste
méthodologique forte : chercher d'autres usages de `(0x0068)&3` (ou
d'un compteur similaire dérivé du timing) ailleurs dans le code
d'initialisation de partie, potentiellement dans `fn_init_room_entities`
(0x29B4) ou dans les données statiques des salles elles-mêmes — reste
à vérifier.

## Prochaines étapes

1. Vérifier si `(0x0068)` (ou une valeur dérivée) est réutilisé
   ailleurs dans la séquence de démarrage de partie pour influencer le
   placement d'objets ramassables (pas seulement la salle de départ).
2. Confirmer empiriquement en relançant plusieurs parties et en
   observant si la salle de départ varie effectivement entre les 4
   valeurs de la table (0x2F/0x44/0xB3/0x8F) — pas encore testé en
   direct cette session, seulement confirmé par désassemblage +
   recoupement avec l'historique des salles de départ déjà observées.
3. Si utile un jour pour la cartographie automatique : patcher
   `(0x0068)` directement avant `fn_init_room_selection` pour choisir
   la salle de départ à volonté (voir section "conséquence pratique"
   ci-dessus).
