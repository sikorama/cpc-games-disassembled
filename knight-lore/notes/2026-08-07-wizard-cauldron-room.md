# Session 2026-08-07 (suite 22) — Salle du Magicien (0x88) : rôles des 3 types identifiés

## Contexte

Suite à `notes/2026-08-07-full-sweep-entity-identification.md` (le
Magicien trouvé, salle 0x88, 3 types 0x8D/0x8E/0x9E jamais séparés).
Investigation en direct (lecture RAM répétée + capture d'écran pendant
une pause légitime de l'utilisateur, aucune interférence) pour assigner
précisément chaque type à son rôle visuel.

## Répartition des rôles (confirmed, désassemblage + capture d'écran + observations utilisateur)

| Type(s) | Rôle | Preuve |
|---|---|---|
| **0x9E/0x9F** (+ paire "jambes" 0x90-0x9D, ex. 0x9A/0x9B/0x92 observés) | **Le magicien** (chapeau pointu visible sur capture d'écran, à gauche de la salle) | `tbl_entity_logic_dispatch[0x9E]` = **0x1280, EXACTEMENT `fn_guard_patrol_logic`** (la routine de patrouille du gardien normal, type 0x1E) — réutilisée ici pour le déplacement circulaire du magicien. 0x9E/0x9F partagent cette même logique avec des sprites différents (cycle d'animation de marche, comme le gardien). Toujours vu en paire avec un type de la famille "jambes" (0x90-0x9D) à la MÊME position exacte (même motif corps+jambes que le gardien standard) |
| **0x8D** | **Le chaudron (le pot lui-même)**, statique | Position fixe (0x80,0x80,0x80) sur tous les relevés, jamais bougé. Logique = simple stub de calibration (`JP 1DB2`, 3 octets) — aucun comportement |
| **0x8E** | **L'élément flottant au-dessus du chaudron** — "le nuage" décrit par l'utilisateur — indique l'objet attendu par une icône (crâne = poison observé) | Position fixe (0x80,0x88,0x80), juste au-dessus de 0x8D sur la capture d'écran. Logique = stub de calibration similaire (`LD HL,0CE8 / JP 1FEB`) — PAS de comportement de poursuite visible dans cette routine précise |

**Capture d'écran confirmée** (jour 16, joueur en forme explorateur,
0 vie — voir avertissement ci-dessous) : chapeau pointu à gauche
(magicien), chaudron au centre avec un tourbillon/icône flottant
au-dessus montrant un crâne. Cohérent avec la description utilisateur
"le nuage montre une bouteille de poison" — le crâne est probablement
l'icône de cet objet précis (poison), pas un objet du bestiaire déjà
catalogué.

## Mise à jour — comportement de poursuite précisé par l'utilisateur (observation en direct)

Observation supplémentaire de l'utilisateur, en jeu réel, salle 0x88 :
**le tourbillon ne poursuit PAS le joueur tant qu'il reste en forme
explorateur** (confirmé par nos relevés RAM répétés : 0x8D/0x8E
strictement statiques pendant toute une séquence en forme explorateur).
**Dès le passage en forme loup-garou, il se met à poursuivre** — MAIS,
point clé : **la poursuite CONTINUE même après un retour en forme
explorateur** — ce n'est donc pas un test "à chaque frame, la forme
actuelle est-elle loup-garou ?" mais un **déclenchement UNIQUE et
PERMANENT** à la première transformation en loup-garou dans cette
salle.

**Hypothèse révisée** : cohérent avec le motif déjà observé ailleurs
dans le jeu (bit de flag consommé une fois -> le type de l'entité MUTE
définitivement, cf. 0x8F qui devient 0xB8 lors de son déclenchement) —
le tourbillon, une fois le loup-garou détecté, change probablement de
TYPE (donc de logique) de façon permanente, passant d'un stub statique
(0x8E) à une entité avec une vraie IA de poursuite. **Pas encore
capturé empiriquement** : la partie s'est terminée en game over (0
vie) avant qu'on puisse relever le type exact pendant la poursuite
réelle — à refaire dans une future partie si l'occasion se présente.

## Point NON résolu : le mécanisme de poursuite en forme loup-garou

Ni 0x8D ni 0x8E n'ont de logique de déplacement (juste des stubs de
calibration statique) — **ce n'est donc probablement PAS l'un de ces
deux types qui "poursuit le joueur"** comme décrit par l'utilisateur.
Hypothèse la plus probable : c'est le MAGICIEN (0x9E/0x9F) lui-même
qui, en forme loup-garou, redirige sa "patrouille" vers le joueur au
lieu de tourner autour du chaudron — mais `fn_guard_patrol_logic`
(0x1280) ne montre pas de test de forme joueur dans ce qu'on a lu
jusqu'ici (peut-être ailleurs dans la routine, ou dans
`fn_resolve_patrol_vector`/0x12A5 qu'elle appelle — pas revérifié avec
ce test précis en tête). **Question ouverte posée à l'utilisateur** :
lors de l'attaque, quel élément visuel s'est déplacé vers lui — le
chapeau (magicien) ou le tourbillon/chaudron ?

## Objet indiqué : "bouteille de poison" — nouveau, pas encore catalogué formellement

L'utilisateur rapporte un objet "bouteille de poison" affiché par le
nuage — à ne pas confondre avec les objets de la famille
"boule de cristal" déjà cataloguée (0x60-0x66, diamant/tasse/bouteille/
boule). Pourrait être :
- un item DISTINCT (pas dans cette famille) spécifique au puzzle du
  chaudron, ou
- une icône symbolique (crâne = "poison" comme concept) plutôt qu'un
  objet physique à proprement ramasser.
Pas encore désassemblé — piste ouverte, probablement liée à
`notes/2026-08-07-pickup-sequence-hypothesis.md` (le puzzle de collecte
ordonnée jamais confirmé en direct, types 0x68-0x6E jamais trouvés
dans les 128 salles du balayage statique — pourraient être générés
DYNAMIQUEMENT par le magicien plutôt que placés dans le décor, ce qui
expliquerait leur absence des données statiques).

## ⚠️ Alerte vies

Capture d'écran montre **vies = 0** au moment de l'observation — cohérent
avec le message utilisateur "je ne pouvais rester à cause de l'ennemi qui
fonce sur moi". Signalé à l'utilisateur, aucune action prise côté outils
(pas de sauvegarde d'état ni d'intervention).

## Prochaines étapes

1. Confirmer quel élément (magicien vs chaudron/nuage) se déplace
   effectivement vers le joueur en forme loup-garou.
2. Désassembler `fn_resolve_patrol_vector` (0x12A5) tel qu'appelé
   depuis 0x9E, en cherchant spécifiquement un test de forme joueur
   qui redirigerait la cible de patrouille.
3. Identifier le mécanisme précis d'affichage de l'icône (crâne) sur
   0x8E — sprite dynamiquement réécrit, ou cycle de types ?
4. Reprendre `notes/2026-08-07-pickup-sequence-hypothesis.md` à la
   lumière de cette salle — le magicien/chaudron est le candidat le
   plus probable pour l'usage réel du puzzle de collecte à 14 étapes.
