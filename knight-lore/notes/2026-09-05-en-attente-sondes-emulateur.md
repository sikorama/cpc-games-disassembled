# En attente — sondes émulateur et chantiers bloqués (2026-09-05)

Inventaire de tout ce qui est en suspens à la fin de la session du 2026-09-05,
classé par ce qu'il faut pour le débloquer. Écrit à la demande de
l'utilisateur, qui reprendra avec l'émulateur.

Branche : `main` (le portage web + le désassemblage). L'expérimentation VRAM
reste sur `vram-direct-experiment` et n'a pas vocation à être fusionnée.

---

## 1. Sondes émulateur — les quatre choses qui débloquent le reste

Trois des quatre relèvent du même angle mort : **une écriture faite à travers
un pointeur en registre**, que le balayage d'octets ne peut pas trouver. Un
point d'arrêt en écriture les donne en une fois.

### 1.1 Bbox du joueur — la plus facile, à faire en premier

**Geste** : lire `(#00D7 + 4)`, `(+5)`, `(+6)` — soit `bbox_w`, `bbox_h`,
`bbox_d` de l'entité 0. **À l'arrêt, sans provoquer le moindre événement.**

**Pourquoi** : le portage approxime la demi-étendue du joueur à **6**, valeur
posée au tout début et jamais vérifiée. Elle n'est pas lisible statiquement :
le template d'entités (`tbl_init_entities_template`, #29EB) est réécrit à
l'exécution et vaut zéro dans `extra/dump_ref.bin`. Le manifest ne la porte pas
non plus — `enrich_bbox.py` ne relève les bbox que pour le décor de jonction.

**Ce que ça corrige** : la marge visuelle contre les murs signalée le
2026-09-05 (« dans le coin, il reste une petite marge sur les 2 axes ; la vue
de dessus est bien collée, pas le rendu »). Attention, une correction faite à
l'œil se paierait ailleurs — le passage dans les portes, la portée de
préhension et le contact mortel dépendent tous de cette même boîte.

**Repère utile** : la vraie bbox des OBJETS est connue, elle, et vaut
`(5, 5, 12)` — écrite en clair par la ROM au moment de reposer un objet
(`loc_19A5`). L'ordre de grandeur du joueur devrait s'en rapprocher.

### 1.2 Déclencheur de perte de vie

**Geste** : point d'arrêt en **écriture** sur `#0080` (`var_life_counter`),
puis mourir une fois. Noter l'adresse qui écrit.

**Ce qu'on sait déjà** : le décrément lui-même est localisé —
`fn_init_room_entities` (#29B4), `dec (hl)` puis `jp m` vers la fin de partie.
C'est l'unique `dec` de #0080 du binaire.

**Ce qui manque** : comment on y arrive en cours de partie. Vérifié par
balayage des 16K bas : **aucun `JP`/`CALL` direct** ne vise #05A2 ni aucune
entrée antérieure de la séquence de démarrage. Les deux seules entrées
existantes sont #05A5 (depuis #23A2, le checkpoint de porte, qui saute donc
précisément le décrément) et #0542, qui réécrit `vies = 5` en #056F et
constitue un nouveau départ complet. Le chemin est donc forcément indirect.

**Ce que ça débloque** : l'entrée `web/DEVIATIONS.md` « condition de mort tirée
de l'observation ». Aujourd'hui la règle appliquée (tout contact avec un ennemi
ou un piège coûte une vie) vient de l'observation en jeu, pas du code — la ROM
impose peut-être des conditions qu'aucune observation ne révèle : invulnérabi-
lité après réapparition, marge de tolérance, types exclus.

### 1.3 Poseur du bit 6 de `state_flags_2` sur le joueur

**Geste** : point d'arrêt en écriture sur `#00E4` (= `#00D7 + 0x0D`,
`state_flags_2` de l'entité 0), pendant une mort réelle.

**Pourquoi** : ce bit déclenche la désintégration
(`fn_player_dematerialize_start` #17CC, atteint depuis #20D3). On sait ce qu'il
FAIT, pas qui le POSE — `grep` ne trouve qu'un `set 6,(ix+#29)`, qui vise
l'entité compagne, pas le joueur.

**Probablement la même réponse que 1.2** : la mort et la désintégration
partagent vraisemblablement leur déclencheur. Faire les deux sondes dans la
même partie.

### 1.4 Bloc poussable 0x3E — immobile ou non ?

**Geste** : placer le joueur contre un 0x3E (**salles 0xBB, 0x08, 0x58 ou
0xC7**), pousser, et regarder si `grid_x`/`grid_y` du bloc bougent.

**Ce qu'on sait** : `fn_pushable_block_logic` (#1D53) fait `CALL #22A5`
(remise à zéro du vecteur) **avant** le `RST 10` qui l'applique — l'inverse de
la table 0x54. Octets relus : `1D53: CD 8F 1D CD A5 22 D7 …`. Le joueur étant
le slot 0 d'une table dispatchée en ordre croissant, la poussée est écrite dans
le bloc avant son propre tick, qui l'efface aussitôt. **Conclusion statique :
le bloc reçoit le vecteur et ne bouge pas.**

**Si la trace dit le contraire** : une seule valeur d'énumération change dans
`web/src/physics/solidTypes.ts` (`PUSH_POLICY_BY_TYPE`, 0x3E). Rien d'autre.

---

## 2. Chantiers bloqués en attendant ces sondes

- **Marge contre les murs** (1.1). Le correctif d'épaisseur réelle des murs
  livré le 2026-09-05 (`e2cef2b`) est un vrai défaut corrigé, mais il ne peut
  PAS être la cause de la marge : une barrière trop mince laisse aller trop
  loin, pas trop court.
- **Condition de mort** (1.2/1.3) — voir l'entrée de `web/DEVIATIONS.md`.
- **Politique du bloc 0x3E** (1.4).

---

## 3. Dette du portage, non bloquée par l'émulateur

Faisable sans rien mesurer, par pur désassemblage ou par implémentation.

- **Courbe de gravité et de saut** — `fn_player_jump_trigger` (#21F0) est
  désassemblé (il pose le drapeau de saut et `(ix+0B) = +8`), mais la COURBE
  ne l'est pas : `fn_player_gravity_and_door_dispatch` (#2253) fait converger
  ce compteur vers 0 par pas de 1-2, et personne n'a reconstitué la hauteur ni
  la durée qui en résultent. `GRAVITY`/`JUMP_VELOCITY` restent des réglages.
- **Mode de contrôle « rotation »** — le pilote d'entrée existe
  (`input/controlMode.ts`), la règle côté `scene/player.ts` manque. Le cooldown
  de 2 ticks est déjà modélisé et restera inerte jusque-là.
- **Poses alternatives rares** — codes libres de la famille corps (0x26/0x27,
  0x2E/0x2F), entièrement désassemblés (seuils `< 0x02` et `>= 0xFE` sur
  `var_pseudo_random_acc`, soit ~0,8 % chacune). Du travail restant, pas une
  information manquante.
- **Sauter par-dessus une porte basse** — la hauteur propre du montant
  (`bbox_d = 0x28`, uniforme sur les 572) n'est pas appliquée au solveur. Les
  montants restent traversables.
- **Autres dangers non implémentés** — fantômes, balles, poussoirs. Seuls les
  gardes et les boules à pics sont mortels aujourd'hui, parce que ce sont les
  seuls dont la logique est portée. La règle n'est pas restreinte, le portage
  est jeune.
- **Son** — rien n'est implémenté. Le format du moteur est pourtant documenté
  (`notes/2026-08-10-interrupt-sound-engine-format.md`,
  `notes/2026-08-10-sound-program-bytecode-format.md`).

---

## 4. Dette d'outillage et de désassemblage

- **`tools/regen_all.py --apply` reste INTERDIT** tant que ceci n'est pas
  réglé : sur `main`, la régénération de `asm/code/objects_and_rooms_setup.asm`
  **perd du vrai code** (une séquence `ld (hl),a / inc hl` et le label
  `loc_1DE9`). Cause à instruire : le générateur s'arrête plus tôt que le
  fichier commité.
- Deux autres écarts de régénération, bénins mais à connaître :
  - `doors_and_player_logic.asm` : 5 lignes de commentaire écrites à la main
    sur `fn_get_orientation_code` (le « `and #10` teste bit4 APRÈS les deux
    `rrca` »), non reproductibles depuis `symbols.json` — à remonter dans le
    champ `long` du symbole ;
  - `collision_and_input.asm` : 3 lignes de `defb` qui diffèrent, parce que
    c'est de l'**état d'exécution** (`tbl_room_connections`) et que la RAM live
    d'origine n'est pas `extra/dump_ref.bin`.
- **Piège à ne pas rouvrir** : `status` dans `asm/symbols.json` est un JETON,
  pas de la prose. `gen_asm.py` fait `if status != "confirmed"` en égalité
  stricte, et un statut enrichi dé-désassemble la routine. La richesse va dans
  `long`. (Bug introduit puis corrigé le 2026-09-05.)
- **`migrate_symbols.py` ne doit plus être relancé** : c'est une migration
  ponctuelle déjà appliquée, qui lit des clés de l'ancien schéma.

---

## 5. Vérifications en jeu, sans émulateur

Rapides, et chacune tranche une hypothèse écrite mais non confirmée.

- **Objet posé, position** — le portage le dépose aux coordonnées exactes du
  joueur (la ROM y recopie ses `grid_x/y/z` par un `ldir` de 3 octets), donc
  SOUS lui. Cohérent avec « on peut grimper sur un objet », à confirmer d'un
  coup d'œil.
- **Objet ramassé puis salle quittée et reprise** — le portage invalide
  l'entrée de catalogue au ramassage, donc l'objet ne doit PAS réapparaître.
  Symétriquement, un objet POSÉ doit persister là où on l'a laissé
  (`fn_object_catalog_writeback` #1E67 resynchronise en quittant la salle).
  Hypothèse dérivée du désassemblage, jamais vérifiée en jeu.
- **Salle contenant déjà deux objets** — poser doit être REFUSÉ (la ROM ne
  balaie que les slots d'entité 2 et 3). Et un seul emplacement dans la
  **salle 0x88**, unique cas particulier du jeu.
- **Portes d'étage** — salles 0x10, 0x14, 0x1D et 0x20 (bord y-min). Confirmé
  fonctionnel en 0x1D le 2026-09-05.
- **Cube qui s'enfonce** — il ne remonte jamais. Une salle où l'on s'attarde
  dessus se dégrade jusqu'à ce qu'on en sorte : c'est fidèle, pas un bug.

---

## 6. Hors code

- Sur GitHub, `origin/HEAD` pointe encore sur `vram-direct-experiment` : un
  visiteur atterrit donc sur la branche modifiée plutôt que sur le
  désassemblage de référence. Ça se change dans les réglages du dépôt, pas
  depuis git.
