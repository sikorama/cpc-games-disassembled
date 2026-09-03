# 2026-08-15 — Portage web : déplacement dans web/, mode orbite retiré, 4 angles, et une fausse piste coûteuse

## Résumé exécutif

- **Livré** : portage déplacé dans `web/` ; mode orbite retiré ; 4 angles
  isométriques par rotation de grille ; `tools/render_ref.py` (rendu de
  référence hors navigateur).
- **Fausse piste, une session perdue** : j'ai cru identifier un bug de
  convention d'axe vertical dans le portage, en m'appuyant sur le
  désassemblage. Le désassemblage était bien lu, mais **le portage n'avait pas
  ce bug** et ma « correction » l'a cassé. Tout est revenu à l'état d'origine.
  Généralisé dans `docs/METHODOLOGY.md` §20-21.
- **Toujours ouvert** : les deux défauts signalés au départ (personnages en
  deux parties, boules à pics) ne sont PAS corrigés — je ne les ai jamais
  attaqués, ayant passé la session sur la fausse piste.

## 1. Déplacement du portage

Le projet JS était à la racine du dépôt, déplacé dans `web/` (src, public,
scripts, dist, node_modules, configs). `web/scripts/sync-assets.mjs` distingue
maintenant `webRoot` de `repoRoot` (`tools/` reste à la racine : c'est un outil
de RE, pas un asset web). `.gitignore` et `README.md` mis à jour.
`npm run build` et `tsc --noEmit` passent depuis `web/`.

## 2. La fausse piste — à lire avant de retoucher au rendu

Le raisonnement, en apparence solide :

1. `asm/code/rendering_pipeline.asm:295` dit sans ambiguïté que `screen_y`
   croît vers le BAS et désigne la ligne du HAUT du sprite (culling `cp #C0`
   contre la hauteur d'écran ; clipping sur `screen_y + screen_h`) ;
2. le portage travaille en +Y vers le HAUT avec une ancre bas-gauche ;
3. donc le portage a un bug de signe.

**L'étape 3 est fausse.** Le portage rend l'image correcte parce que les PNG de
`tools/sprite_dump_out/` sont eux-mêmes des images MIROIR du rendu réel
(conséquence du `ROTATE_90` non expliqué en fin de `sprite_dump.py`, cf.
`notes/2026-08-13-sprite-rotation-investigation.md`). Le miroir est appliqué
deux fois et se compose. En retourner une seule moitié casse tout : murs tête
en bas, portes déplacées, cubes mal empilés — constaté par l'utilisateur.

Ce que j'avais pris pour « trois compensations empiriques d'un même bug »
(tri en profondeur inversé, ancre bas-gauche, UV retournées) est en réalité un
système cohérent. **Tout a été restauré** : `camera.ts` (ortho non retournée),
`spriteBatch.ts` (ancre `(0,1)`, `viewPos.y -= offset.y`, UV d'origine),
`room.ts`, `isoMath.ts`. Des avertissements ont été posés à chaque endroit
concerné, ainsi que dans `docs/RENDERING_PIPELINE.md` §5.

Trois méthodes ont échoué à établir l'orientation par le raisonnement, chacune
avec assurance : déduction depuis le désassemblage ; jugement à l'œil d'un
sprite isolé (un cube reste plausible retourné — faux deux fois) ; comparaison
numérique pixel à pixel (écart de 0, mais contre la mauvaise CIBLE). Seule une
**capture du jeu réel**, fournie par l'utilisateur, a tranché.

Bon critère de contrôle pour la suite, parce qu'il ne dépend pas d'un sprite
isolé : les deux moitiés d'une porte (types 0x02+0x03, entités distinctes)
doivent se rejoindre en une arche avec clé de voûte ; sous toute autre
orientation elles s'écartent en « V ».

## 3. Acquis annexe : la table de calibration ROM

Retrouvé `fn_static_calib_vector_table` (`objects_and_rooms_setup.asm:95`,
`#1D7F..#1DBC`) : 13 stubs `LD HL,nn / JR #1D8C`, queue commune écrivant `L`
dans `proj_offset_x` et `H` dans `proj_offset_y` (`#1FEB`, partagée avec les
montants de porte).

    #1D7F (-8,-2)   #1D84 (-12,-4)  #1D89 (-12,-6)  #1D8F (-16,-8)
    #1D94 (-20,-1)  #1D99 (-12,-2)  #1D9E (-8,-4)   #1DA3 (-12,-8)
    #1DA8 (-12,-7)  #1DAD (-12,-12) #1DB2 (-16,-12) #1DB7 (-12,+7)
    #1DBC (-12,+3)

**Toutes** les valeurs relevées en RAM live le 2026-08-14 correspondent à une
entrée : les deux méthodes se confirment. La table est connue en entier ; reste
partielle la correspondance type → entrée (à compléter en suivant les `call`).
Ce point-là est solide et indépendant de la fausse piste.

## 4. Mode orbite retiré

Supprimé : `CameraMode`, yaw/pitch, `orbitViewMatrix`, `worldCenter`, et les
helpers `multiply`/`rotateX`/`rotateY`/`translate` de `mat4.ts`. Le mode
cassait le tri peintre (calibré pour un seul angle) et changeait de projection
au premier pixel de glissé. Le glissé souris fait maintenant un pan.

## 5. Les 4 angles isométriques

La projection étant une fonction pure de `(grid_x, grid_y, grid_z)`, tourner la
vue = tourner ses **entrées** : `rotateGrid()` applique un quart de tour dans
le plan du sol autour de `0x80`, `grid_z` intact. `sortKey`, recalculé sur les
coordonnées tournées, reste juste sans rien réécrire. Un quart de tour équivaut
à un **miroir horizontal** pour un objet à symétrie miroir (`viewNeedsFlip`),
XORé avec le miroir existant — gratuit, et c'est le mécanisme du jeu original.

Touches : `R`/Maj+`R` tourner, `W` murs, `C` vue d'origine, flèches/glissé pan,
molette zoom.

### Restent faux sous les vues 1/2/3

1. **Pièces asymétriques** (murs `0x0A-0x0F`, coins, portes) : un miroir ne
   suffit pas, il faut une table de remap `(type, flip) → (type, flip)`.
   Inconnue à lever : le jeu n'ayant besoin que de 2 directions de mur,
   l'ensemble des pièces n'est peut-être pas *fermé* par rotation de 90°.
2. **Murs de devant** : les salles n'ont de murs que sur DEUX côtés (salle
   0x00 : tout est à `grid_x=0x3F` ou `grid_y=0xC0`). Tournée, la salle se
   retrouve murée côté caméra. Parade actuelle : touche `W`. L'alternative
   (dupliquer les murs sur les côtés lointains) serait de la donnée
   **synthétisée**, à marquer comme telle.

## 6. À reprendre — les vrais sujets, jamais traités

- **Personnages en deux parties** : « seul le haut visible, au niveau des
  pieds ». Les deux moitiés (0x1E/0x1F et 0x90-0x9D) ont des grid IDENTIQUES
  (salle 0x2E : `(0x78,0x88,0x80)` pour les deux) — tout l'écart vertical vient
  donc des `proj_offset_y` (+3 et -6, tous deux confirmés dans la table ROM).
  À reprendre en comparant à une capture, avec `tools/render_ref.py`.
- **Boules à pics** (0x3F) mal placées.
- **Entité joueur** (0x12/0x22) : `grid_z_or_offset` = 14 et 26 là où le décor
  est à 128 — pour ce slot le champ n'est pas une position de même nature.
  À élucider avant d'afficher le joueur.
