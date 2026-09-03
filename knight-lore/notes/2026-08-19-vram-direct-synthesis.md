# Synthèse — journée du 2026-08-19, branche `vram-direct-experiment`

Récit chronologique et détail des correctifs :
`notes/2026-08-18-vram-direct-patch-plan.md`. Ce fichier ne garde que
**les observations et les conclusions**, y compris celles qui invalident des
hypothèses antérieures.

## 1. État atteint

Le décor, les entités, le texte de menu, les compteurs HUD et les écrans de
game over sont dessinés **directement en VRAM**, écrêtés aux rectangles
sales. Aucun glitch visuel constaté après le dernier correctif. Le buffer
intermédiaire `#9000-#BFFF` n'est plus ni lu ni écrit (0 octet non nul dans
le `.sna`, plus une seule référence à `BUF_PRERENDER_BASE` dans `asm/code/`)
et héberge désormais le code neuf. La pile est sortie de `#8100`.

**Verdict de performance : toujours plus lent que l'original**, après
écrêtage puis re-déroulement des boucles de colonne. C'est le résultat
principal de la journée, et il est instructif — voir §3.

## 2. Découvertes sur le moteur (indépendantes de la migration)

- **Une entité n'est PAS redessinée à chaque frame.** Deux bits de
  `off_flags` pilotent le rendu : **bit 4** = « à redessiner » (filtre de
  `fn_cull_entities`, consommé par `res 4` dans
  `fn_sprite_pipeline_setup`), **bit 5** = « effacer l'ancienne position »
  (consommé par la passe 1 de `fn_render_entities`). Les deux sont posés
  ensemble par `loc_1F7B` (`or #30`), qui enchaîne sur
  `fn_entity_fall_and_mark_overlap` (`#25FF`) : celle-ci pose bit 4 sur
  toutes les entités dont l'empreinte **écran** chevauche le rectangle sale
  de l'appelant. C'est le seul mécanisme qui fait réapparaître un décor
  effacé par le passage d'un mobile.
- **Le décor d'une salle est un maillage connexe.** Sols, murs et
  plateformes se touchent tous — la fermeture transitive du chevauchement
  écran est donc la salle entière. Mesuré en jeu, pas déduit.
- **`fn_buffer_addr_from_vram` (`#3186`) portait un nom trompeur** : son
  entrée n'est pas une adresse VRAM mais un couple `H=screen_y / L=screen_x`,
  et sa sortie était `#9000 + y*64 + x/4`. Donc **le buffer n'a pas l'axe Y
  inversé** ; l'inversion apparente venait de la routine de copie.
- **Le mapping buffer→VRAM du jeu est exactement
  `fn_screen_addr_from_bc(y, colonne*4)`**, décalage `+8` de colonne inclus.
  Démontré par une constante du jeu : la copie plein écran appariait buffer
  `#BFC0` et VRAM `#C008`, et `#BFC0 = #9000 + 191*64 + 0`, tandis que
  `fn_screen_addr_from_bc(191, 0)` rend `#C008`.
- **`screen_y` croît vers le HAUT de l'écran** et repère le **bas** du
  sprite, qui s'étend vers le haut. Confirmé par l'arithmétique : l'original
  pokait `64 - w` dans l'opérande `#30AF`, soit `+64` par ligne dans un
  buffer d'adresse `#9000 + y*64`.
- **Les deux `and #FF` de `fn_menu_glyph_unpack` sont l'octet d'attribut de
  couleur**, poké à l'exécution en `#172C`/`#173C` par quatre appelants. Le
  `#FF` de l'image n'est qu'une valeur au repos.
- **`tbl_collision_pending` (`#28AF`) fait 8 octets et `loc_284D` y ajoute
  sans contrôle de borne.** Au-delà de 7 reports simultanés du tri en
  profondeur, l'écriture du sentinelle déborde sur `#28B7`, les premiers
  octets de `fn_read_input`. **Bug latent du moteur d'origine**, indépendant
  de toute migration ; profil compatible avec un ordre de dessin qui casse
  « pas systématiquement » sur une scène chargée.
- **`STACK_LOW_WATERMARK = #8010` (240 octets) ne mesurait pas
  l'imbrication d'appels** : `fn_stage_blit_and_clear` empilait `BC/DE/HL`
  par entité sale (40 × 6 = exactement 240). **La pile servait de file
  d'attente de blits différés.**
- **Le blit à décalage sub-octet a deux largeurs distinctes** : `w` octets
  de données par ligne, `w+1` octets d'étendue écran (chaque colonne de
  données écrit 2 octets adjacents). La variante alignée les rend égales.

## 3. Pourquoi le buffer intermédiaire d'origine était un BON choix

C'est la conclusion la plus utile de la journée, et elle contredit le
postulat de départ de la piste 3 (« le buffer est un gaspillage de 12 Ko »).

Le buffer ne servait pas seulement à composer l'image. La copie différée ne
publiant que les **rectangles sales**, il était aussi une **fenêtre de
publication**. Et c'est ce second rôle qui compte :

> **Le buffer avait le droit d'être localement FAUX.** L'invariant à tenir
> n'était pas « le plan de composition est correct » mais « le plan de
> composition est correct **dans les zones qu'on est sur le point de
> publier** ». Une zone corrompue hors rectangle sale ne se voyait pas, et
> se réparait toute seule : dès qu'elle redevenait sale, tout ce qui la
> chevauche était remarqué et redessiné dans le bon ordre de profondeur
> avant publication.

Cet invariant **faible** fait disparaître deux problèmes durs :

1. **Aucune fermeture transitive du marquage à calculer.** Mesuré : elle
   cascade jusqu'à toute la salle (décor connexe), donc elle est
   inutilisable.
2. **Aucun écrêtage dans le blit.** La copie écrête gratuitement, et elle le
   fait avec un `LDIR` — la primitive de publication la moins chère du Z80
   (21 cycles/octet, aucune logique par pixel).

Le buffer coûte 12 Ko de RAM et un `LDIR` par rectangle sale. En échange il
supprime deux problèmes algorithmiques. Sur un Z80 à 4 MHz, **c'est un bon
marché** — et notre mesure le confirme : la version directe, écrêtée **et**
déroulée reste plus lente que l'original.

Autrement dit : le buffer n'était pas de la RAM gaspillée, c'était de la RAM
échangée contre de la simplicité algorithmique. La piste 3 ne « supprime » pas
un coût, elle **déplace** un coût de la RAM vers le CPU.

## 4. Et sur ZX Spectrum ?

Question ouverte par l'utilisateur. Ce qui est certain relève de
l'arithmétique des plateformes, pas de Knight Lore :

| | ZX Spectrum | CPC mode 1 |
|---|---|---|
| écran | 6 912 o (6 144 bitmap + 768 attributs) | 16 384 o |
| profondeur | 1 bit/pixel | 2 bits/pixel |
| couleur | par cellule 8×8, plan séparé | dans les bits de pixel |
| décalage sub-octet d'un sprite | une rotation (`RR`) | **table précalculée** |

Deux conséquences directes :

- Un plan de composition hors écran coûte ~6 Ko sur Spectrum contre ~12 Ko
  sur CPC pour la même zone de jeu. Le même choix d'architecture y est donc
  bien plus confortable.
- Surtout : en mode 1, les bits d'un octet écran ne sont pas les pixels
  consécutifs mais des plans entrelacés. Décaler un sprite d'un ou deux
  pixels n'est pas une rotation — d'où les **14 tables de 256 octets**
  (`#8200-#8FFF`) construites au boot par
  `fn_build_pixel_bitscatter_tables`, et les 4 accès mémoire par octet écran
  dans `fn_blit_masked`. Sur Spectrum, le même décalage est quelques `RR`.

Le blit du Spectrum est donc structurellement bien moins cher, et toute
l'architecture y a beaucoup plus de marge. **Hypothèse non vérifiée** : la
version Spectrum peut très bien redessiner la salle entière à chaque frame
(le scintillement caractéristique des jeux Filmation sur Spectrum est
compatible), le système de rectangles sales du CPC étant alors une
adaptation spécifique à la plateforme. À vérifier par la méthode du jeu
sœur (`docs/METHODOLOGY.md` §21) plutôt que par supposition.

## 5. Pistes d'accélération identifiées

Détail et chiffrage dans `docs/OPTIMISATION.md`. Par gain attendu
décroissant :

1. **Supprimer le test de fenêtre Y par ligne.** Aujourd'hui `clip_blit`
   balaie les `clip_h` lignes du sprite et teste chacune contre
   `[rect_ymin, rect_ymax]`. Le driver connaît déjà tout : il peut calculer
   la première ligne dans la fenêtre, l'adresse VRAM correspondante
   (`fn_screen_addr_from_bc`) et le pointeur de forme (`payload + k*w`, une
   multiplication), puis lancer une boucle de `rows` lignes **sans aucun
   test**. Les lignes hors fenêtre deviennent gratuites au lieu de coûter
   ~30 cycles chacune.
2. **Fusionner les rectangles sales avant la passe de dessin.** Une entité
   chevauchant `k` rectangles est aujourd'hui mise en place et balayée `k`
   fois. Fusionner les rectangles qui se recouvrent ou se touchent réduit
   `k`, et le blit masqué étant idempotent, une fenêtre trop large ne
   produit aucune erreur — seulement du travail en plus, qu'on cherche
   justement à réduire.
3. **Sprites pré-retournés en RAM** (idée de l'utilisateur, déjà piste 1 du
   document d'optimisation). `fn_flip_sprite_shape` (`#3200`) mute le bitmap
   **en place** quand l'orientation demandée diffère de celle stockée dans
   l'octet 0 de la forme : une entité qui alterne d'orientation d'une frame
   à l'autre paie un retournement complet à chaque fois (échange de lignes,
   et pour l'axe horizontal un `fn_mirror_byte_bits` par nibble).
   Pré-stocker les orientations supprime ce coût entièrement. C'est
   exactement l'usage « stockage passif » pour lequel la RAM banquée du 6128
   est adaptée. **À mesurer avant d'implémenter** : compter les
   retournements par frame en jeu réel.
4. **Alléger le va-et-vient sur `H` dans le corps de colonne décalé.** Trois
   `dec h` par colonne servent uniquement à revenir à la page de base après
   les 4 accès aux tables. Une réorganisation de l'indexation des tables
   pourrait les éviter.

## 6. Décision en cours

Tant que la version directe n'est pas plus rapide que l'original, **ne pas
aller plus loin** (double buffer, banking). Le montage 6128 est conçu et
documenté (`docs/OPTIMISATION.md` §2bis, configs 1 et 3), il attend.
