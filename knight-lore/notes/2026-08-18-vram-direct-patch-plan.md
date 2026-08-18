# Piste 3 (dessin direct VRAM) — plan et état d'avancement

Branche : `vram-direct-experiment`. Objectif : `docs/OPTIMISATION.md` §4
(piste 3) — supprimer le buffer intermédiaire `#9000-#BFFF` pour libérer
cette zone à du code neuf. `asm/` sur `main` reste la désassemblage fidèle
intacte ; cette branche est l'espace d'expérimentation.

## Découverte clé : un seul point de rendu partagé

`fn_sprite_pipeline_setup` (`#2F17`) + `fn_blit_masked` (`#2F8D`) sont **le
seul** chemin de dessin de sprite/icône dans tout le jeu — pas seulement
les entités. Les points d'entrée alternatifs suivants y retombent tous
(entrée `#2F2B`, après la projection isométrique) :

- Entités : `fn_check_collisions` → `fn_sprite_pipeline_setup` (`#2F17`)
- HUD jour/nuit : `fn_hud_day_night_cycle` (`code/pickups_and_transform.asm:411,417,420`)
- HUD bonus vie + icône jour/nuit (partagées) : `fn_hud_icon_redraw_8x4`
  (`code/pickups_and_transform.asm:457`)
- Notification slot objet : `fn_hud_slot_notification`
  (`code/menu_and_materialize.asm:195`, appelle `#2F2B` en `:238`)

Donc migrer `fn_sprite_pipeline_setup`/`fn_blit_masked` migre TOUS ces
appelants d'un coup — pas besoin de traiter chaque fichier séparément pour
le dessin lui-même. Reste spécifique à chaque appelant : le **clear**
(`fn_fill_rect`) et la **copie différée** (`fn_blit_copy_line`), chacun
avec ses propres call sites (4 groupes, voir grep ci-dessous).

Call sites bruts (`fn_fill_rect` / `fn_buffer_addr_from_vram` /
`fn_blit_copy_line`) :
- `rendering_pipeline.asm:231,239,267,413` (entités + sprite_pipeline_setup)
- `menu_and_materialize.asm:229,232,247,252` (`fn_hud_slot_notification`)
- `pickups_and_transform.asm:410,427,460,466,468` (HUD jour/nuit + icône partagée)
- `entity_logic_mechanical.asm:1070,1092` (à identifier — pas encore lu en détail)

## Piège générique rencontré (à noter dans METHODOLOGY.md si confirmé récurrent)

**Raccourcir/allonger une routine décale tout ce qui suit dans le même
fichier jusqu'au prochain `org` explicite.** Dans ce projet, chaque fichier
`asm/code/*.asm` généré par `gen_asm.py` porte un seul `org` en tête et
couvre une plage large (`rendering_pipeline.asm` = `#2D5E-#3185`, onze
routines) — modifier UNE routine au milieu déplace toutes les suivantes
dans le même fichier. Inoffensif pour les références symboliques (labels,
recalculées automatiquement par l'assembleur), **mais casse silencieusement
les adresses littérales codées en dur** utilisées par le jeu pour du code
auto-modifiant (ex. `ld (#30AF),a`, `#2F8B`, `#311F` dans
`fn_sprite_pipeline_setup`/`fn_blit_masked`) — l'assembleur ne signale
aucune erreur, le jeu plante/corrompt silencieusement à l'exécution.

Vérifié concrètement ici : remplacer le bloc inline de `fn_blit_copy_line`
(10 octets) par un `call fn_vram_advance_line` (5 octets) a décalé
`fn_isometric_project` de `#2EDC` à `#2ED6` (confirmé par export symboles
`rasm -s`), ce qui aurait décalé aussi `fn_sprite_pipeline_setup`/
`fn_blit_masked` et rendu caduques leurs pokes littéraux. **Solution
appliquée** : `nop`-padding pour préserver la longueur exacte tant que la
routine n'est pas complètement relocalisée. Solution définitive pour toute
routine qu'on veut vraiment raccourcir : soit compléter par du padding,
soit **relocaliser entièrement la routine (et tous ses appelants) dans la
zone `#9000+` libérée**, ce qui élimine le problème puisque le code
original reste inchangé sur place (mort mais inoffensif) et le nouveau
code vit dans un fichier `org`é indépendamment.

## Fait à ce stade (commit sur cette branche)

- `asm/code/vram_direct_rendering.asm` (NEUF, `org #9000`) :
  - `fn_vram_advance_line` : avance CRTC-aware (+0x0800, correction +0xC050
    sur carry — mécanisme déjà utilisé identiquement par `fn_clear_screen`
    ET l'ancien `fn_blit_copy_line`, donc **confirmé**, pas une hypothèse).
  - `fn_vram_fill_rect` : variante de `fn_fill_rect` opérant directement en
    VRAM au lieu du buffer. **PAS ENCORE BRANCHÉE** — voir point ouvert
    ci-dessous.
- `fn_blit_copy_line` (`rendering_pipeline.asm`) refactorisée pour appeler
  `fn_vram_advance_line` au lieu de dupliquer le calcul inline —
  comportement inchangé, vérifié par diff mémoire complet (rasm `-oi`
  avant/après, 65536 octets comparés octet-à-octet) : seuls
  `#2EC8-#2ED2` (le corps de la routine elle-même) et `#9000-#9041` (code
  neuf, pas encore atteignable) diffèrent. Tout le reste du jeu est
  byte-identique.

## Point ouvert — bloquant avant de brancher `fn_vram_fill_rect`

`fn_stage_blit_and_clear` (`#2E6C`) calcule une adresse VRAM via
`fn_screen_addr_from_bc` puis la pousse pour la copie différée finale. Pas
réussi à déterminer par lecture statique seule si cette adresse correspond
au coin **haut** ou **bas** du rectangle sale (l'arithmétique de bbox en
amont dans `fn_render_entities`, #2DF5-#2E97, mélange plusieurs
ajustements +L-1/clipping qui rendent la direction ambiguë sans trace
live). Nécessaire avant de brancher `fn_vram_fill_rect` : une trace live
(lire BC/DE à l'entrée de `fn_stage_blit_and_clear` et juste après
`fn_screen_addr_from_bc`, comparer à la position connue d'une entité à
l'écran) pour confirmer le sens d'avance (vers le bas = OK direct avec
`fn_vram_advance_line` tel qu'écrit ; vers le haut = il faudra une variante
"avance vers le haut", pas encore écrite).

## Tentative de branchement (2026-08-18, après-midi) — ÉCHEC, révélateur

Branché `fn_vram_fill_rect` dans `fn_stage_blit_and_clear` via
`fn_stage_clear_vram_and_buffer_addr` (clear direct VRAM AJOUTÉ en plus du
chemin buffer existant, censé être inoffensif/redondant — voir raisonnement
initial ci-dessus). **Plante en jeu réel** : trace live après chargement
d'une salle montre le CPU tournant en boucle entre `#0039` (handler IM1) et
`#90A0`-ish, et une lecture RAM de `#9000+` montre du contenu qui n'a plus
aucun rapport avec le code assemblé (`00 ff ee 11 00...`) — nos routines à
`#9000` ont été **écrasées**.

**Cause identifiée, pas une hypothèse** : `fn_clear_intermediate_buffer`
(`code/rendering_pipeline.asm`, appelée par `fn_init_room` à CHAQUE
chargement de salle) fait `ld bc,#3000 / ld hl,#9000 / jr fn_mem_fill_simple`
— un remplissage inconditionnel de **tout** `#9000-#BFFF` à zéro, qui
écrase donc n'importe quel code qu'on y aurait posé, indépendamment de
savoir si `fn_blit_masked` écrit aussi par-dessus dynamiquement (lui aussi
vrai, mais même sans lui ce clear seul suffit à tout détruire).

**Conclusion qui invalide le plan de migration incrémentale envisagé plus
haut** : il n'existe **aucune sous-partie sûre** de `#9000-#BFFF` où loger
du code neuf tant que `fn_clear_intermediate_buffer` ET `fn_blit_masked`
(adressage dynamique, peut cibler n'importe quel octet de la zone selon la
position à l'écran) n'ont pas TOUS LES DEUX cessé d'utiliser cette zone
comme buffer. Pas de "on migre le clear, on teste, puis on migre le dessin" :
le clear seul du prochain chargement de salle détruit tout ce qu'on a posé
avant même d'avoir pu tester quoi que ce soit. **Piège générique à noter
dans `docs/METHODOLOGY.md`** : avant de réutiliser une zone RAM libérée
pour du code neuf, vérifier qu'AUCUN écrivain (même partiel/occasionnel,
même juste un memset au chargement) ne cible encore cette zone comme
donnée — un seul écrivain restant suffit à rendre TOUTE la zone inutilisable
pour du code, pas seulement la portion qu'il touche effectivement.

**Reverté** (branchement dans `fn_stage_blit_and_clear` annulé, code de
`fn_vram_fill_rect`/`fn_vram_advance_line`/`fn_stage_clear_vram_and_buffer_addr`
conservé mais non appelé) pour ne pas laisser la branche dans un état qui
plante. Prochaine étape réaliste : migrer `fn_clear_intermediate_buffer`
ET `fn_blit_masked`/`fn_sprite_pipeline_setup` (tous les appelants, voir
"découverte clé" plus haut) dans le MÊME changement atomique avant de
pouvoir poser quoi que ce soit à `#9000+` -- pas de raccourci possible.

## Prochaines étapes

1. Trace live pour lever l'ambiguïté ci-dessus (nécessite émulateur).
2. Une fois confirmé : brancher `fn_vram_fill_rect` dans
   `fn_stage_blit_and_clear` (clear direct, plus besoin de calculer/pousser
   l'adresse buffer pour le clear).
3. Migrer `fn_sprite_pipeline_setup`/`fn_blit_masked` (adressage direct VRAM
   + avance CRTC-aware dans les ~18 entrées de dispatch par largeur) — le
   plus gros morceau, migre tous les appelants HUD/entités d'un coup (voir
   section "découverte clé").
4. Supprimer la mécanique de pile différée (`var_blit_stack_counter`,
   `fn_blit_copy_line`, les push/pop BC/DE/HL) une fois clear+draw
   entièrement directs — plus aucun appelant n'en aura besoin.
5. Mettre à jour `docs/MEMORY_MAP.md`/`RENDERING_PIPELINE.md` pour refléter
   le nouveau pipeline, une fois validé en jeu.
