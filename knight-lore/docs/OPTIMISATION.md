# Pistes d'optimisation et d'évolution du moteur de rendu (CPC 6128 / 128K)

Ce document rassemble des pistes de travail **prospectives**, discutées mais
pas encore implémentées, pour faire évoluer le moteur de rendu au-delà d'une
simple désassemblage fidèle — en s'autorisant à sortir du cadre 64K du jeu
original (CPC 464/664) pour exploiter les 128K du CPC 6128. À reprendre plus
tard. Statut : idées de conception, rien n'a été codé.

Contexte technique de référence : `docs/RENDERING_PIPELINE.md` (algorithme de
rendu complet), `docs/MEMORY_MAP.md` (occupation RAM actuelle).

## 1. Constat de départ sur le moteur actuel

- Le jeu original tourne en 64K, sans banking mémoire (aucun `OUT` vers un
  port de sélection de RAM additionnelle trouvé ; seule écriture connue vers
  `0x7F00` = configuration palette du gate array, `fn_gate_array_config_stream`
  `0x0049`).
- Le rendu n'est **pas** un redraw complet par frame : c'est un système à
  **rectangles sales** (`docs/RENDERING_PIPELINE.md` §10, pseudocode
  lignes 382-421). Chaque entité garde sa bbox écran de la frame précédente
  (champ `+18..1B` = `*_prev`). À chaque frame, seule l'union de l'ancienne
  et de la nouvelle bbox est effacée puis redessinée dans le buffer
  intermédiaire (`fn_stage_blit_and_clear` `0x2E6C` → `fn_fill_rect`
  `0x1DC1`), et seuls ces rectangles sales sont recopiés en VRAM
  (`fn_blit_copy_line` `0x2EC0`, §8.2). Le buffer intermédiaire est donc
  **persistant** d'une frame à l'autre : le coût par frame est proportionnel
  au nombre/taille des entités qui bougent, pas à la taille de l'écran.
- Le rendu tourne en boucle logicielle (`fn_main_loop` `0x05AE`), synchronisé
  par une variable de synchro interruption existante
  (`var_interrupt_sync_flag` `0x006F`, `fn_wait_keyboard_sync`,
  `fn_arm_interrupt_flag`) — pas d'IRQ vidéo dédiée. L'IM1 matériel
  (`0x0038`, ~300Hz) ne sert qu'au moteur son (`fn_sound_engine_tick`).
- Le blit masqué utilise déjà un pattern de précalcul poussé : 14 LUT de
  256 octets (`0x8200-0x8FFF`), construites une fois au boot par
  `fn_build_pixel_bitscatter_tables` (`0x0829`), combinées à un dispatch par
  **JP auto-modifiant** vers deux familles de boucles (alignée/décalée).
- Le retournement de sprite (`fn_flip_sprite_shape` `0x31E9`,
  `fn_mirror_byte_bits` `0x3265`) mute le bitmap **en place** à chaque
  changement d'orientation (pas de précalcul des deux variantes en RAM) —
  coût CPU réel mais uniquement au changement d'orientation, pas à chaque
  frame.
- Couleur des sprites : le bitmap source est **monochrome**. La couleur est
  appliquée globalement au blit via une seule paire masque/couleur par appel
  (table `#8200-#8FFF`, `écran = (écran AND masque) OR couleur`) —
  équivalent fonctionnel de l'attribut Spectrum ink-par-8x8, hérité du
  portage. Aucune donnée couleur par pixel dans les ressources sprite
  actuelles (`0x4000-0x8000`).
- Carte mémoire actuelle (`docs/MEMORY_MAP.md`) : `0x0000-0x4000` code,
  `0x4000-0x8000` ressources, `0x8000-0x9000` pile + tables 256o,
  `0x9000-0xC000` buffer intermédiaire (12K), `0xC000-0xFFFF` VRAM — aucune
  zone franchement libre signalée en 64K.

## 2. Piste 1 — Exploiter les 128K du CPC 6128 (banking)

Idée : utiliser la RAM additionnelle (banking via gate array) pour stocker
des tables précalculées supplémentaires, des variantes de sprites
pré-retournées, ou des ressources étendues — sans avoir à comprimer le code
existant dans 64K.

Points de vigilance :
- Le rendu n'a pas de contrainte de fenêtre VBL stricte (boucle logicielle),
  donc pas d'urgence cycle-à-cycle pour placer un `OUT` de bascule de
  banque — mais il faut basculer **en dehors** des séquences qui réutilisent
  la pile à `0x8100` et le buffer intermédiaire `0x9000-0xBFFF`, pour ne pas
  corrompre pile/buffer pendant qu'une banque étrangère est mappée.
- Usage recommandé : réserver la RAM banquée à du **stockage passif**
  (sprites étendus, tables précalculées, variantes pré-flippées) rapatrié
  par bloc avant utilisation, pas à une bascule pixel-par-pixel pendant le
  rendu lui-même.

### 2bis. Le montage concret pour un double buffer sur 6128 (configs 1 et 3)

**MISE À JOUR 2026-08-19.** Une analyse menée pendant la piste 3 avait
conclu que le double buffer « ne rentre pas » : code 16 454 + ressources
sprites 16 314 + tables masque/couleur 3 584 = 36 352 octets à placer dans
les 32 Ko qui restent quand deux pages de 16 Ko sont réservées. **Ce calcul
suppose une machine 64K et ne s'applique pas au 6128.** Avec le banking il
rentre, et confortablement.

#### La contrainte réelle

Le CRTC lit toujours la vidéo dans les **64 Ko de base** (banques
physiques 0-3), quelle que soit la configuration vue par le CPU ; la page
affichée est choisie par les bits de page de R12. **Les deux pages d'un
double buffer doivent donc être des banques de base.** Le banking ne sert
pas à héberger un écran, il sert à **libérer de la RAM de base** pour en
héberger un second.

Rappel de la table des 8 configurations du gate array (blocs CPU `#0000`,
`#4000`, `#8000`, `#C000` ; 0-3 = banques de base, 4-7 = extension) :

| Config | #0000 | #4000 | #8000 | #C000 |
|---|---|---|---|---|
| 0 | 0 | 1 | 2 | 3 |
| 1 | 0 | **1** | 2 | **7** |
| 2 | 4 | 5 | 6 | 7 |
| 3 | 0 | **3** | 2 | **7** |
| 4-7 | 0 | 4-7 | 2 | 3 |

#### La paire utile : configs 1 et 3

Les configs 1 et 3 diffèrent **uniquement** par la banque de base présentée
en `#4000-#7FFF` : la banque 1 pour l'une, la banque 3 pour l'autre. Toutes
deux laissent la banque d'extension 7 en `#C000-#FFFF`. D'où le montage :

| Zone CPU | Contenu | Config 1 | Config 3 |
|---|---|---|---|
| `#0000-#3FFF` | code | banque 0 | banque 0 |
| `#4000-#7FFF` | **page en cours de dessin** | banque 1 | banque 3 |
| `#8000-#BFFF` | tables masque/couleur, données de salle, code neuf | banque 2 | banque 2 |
| `#C000-#FFFF` | ressources sprites | extension 7 | extension 7 |

Le CRTC affiche la banque de base *que le CPU ne voit pas* (page 3 en
config 1, page 1 en config 3). Basculer de page = **un `OUT` de
configuration + les bits de page de R12**, une fois par frame.

Propriété décisive : **la cible de dessin est toujours en `#4000-#7FFF` et
les données de sprites toujours en `#C000-#FFFF`.** Le code de rendu n'a
donc aucune arithmétique d'adresse à changer entre les deux pages, et
aucune bascule de banque pendant le blit — c'est ce qui rend ce montage
praticable, contrairement à un schéma où sprites et écran se disputent la
fenêtre `#4000-#7FFF` (configs 4-7) et imposeraient de recopier chaque
sprite dans un tampon avant de le dessiner.

#### Budget

| Poste | Taille | Emplacement |
|---|---|---|
| code | 16 454 o | banque 0 (16 384) — **70 octets de trop** |
| ressources sprites | 16 314 o | extension 7 (16 384) — 70 octets de marge |
| tables masque/couleur | 3 584 o | banque 2, inchangées à `#8200-#8FFF` |
| pile, code neuf, données de salle | | banque 2, ~12 Ko de reste |

Les 70 octets de code en trop sont sans difficulté : la migration de la
piste 3 a rendu mort un volume bien supérieur (`fn_fill_rect`, le corps de
`fn_sprite_pipeline_setup` `#2F2E-#2F8A`, les familles de `fn_blit_masked`,
`fn_blit_copy_line`, `fn_copy_screen_rect`). Remarque agréable : les tables
masque/couleur peuvent rester **exactement** où elles sont, et la pile
pourrait revenir en `#8000-#80FF`.

#### Piège d'implémentation : le test de franchissement de bande

Déplacer la cible de dessin de `#C000-#FFFF` vers `#4000-#7FFF` casse
silencieusement les détections de franchissement de bande CRTC qui reposent
sur le **débordement 16 bits**. `fn_vram_advance_line` (`+#0800`, correction
si carry) et `fn_clear_screen` fonctionnent parce que l'écran est en haut de
l'espace d'adressage : `#F800 + #0800` déborde. En `#4000-#7FFF`,
`#7800 + #0800 = #8000` ne déborde pas — aucune correction ne serait
appliquée.

La forme robuste est de tester les **bits de page** de l'octet haut, pas la
retenue. `blit_row_end` et `clip_next_row` le font déjà (`bit 6,b` pour
détecter le passage sous `#C0`) et **ce test fonctionne tel quel en
`#4000-#7FFF`** : `#40-#7F` ont le bit 6 posé, `#38` ne l'a pas. À
convertir sur le même modèle : `fn_vram_advance_line`,
`fn_vram_clear_playfield`, `fn_clear_screen`, et le `or #C0` de
`fn_screen_addr_from_bc` (qui devient `or #40`).

#### Ce que la piste 3 apporte au double buffer

L'écrêtage aux rectangles sales construit pour la piste 3 **reste
nécessaire** avec un double buffer : le problème qu'il résout (un sprite
redessiné publie toute son étendue et écrase une entité voisine qui n'est
pas redessinée) existe à l'identique page par page. Combiné à l'historique
de bbox **par page** décrit en piste 4, c'est exactement l'outillage requis.
L'alternative — tout redessiner dans la page arrière à chaque frame, sans
écrêtage ni rectangles sales — est trivialement correcte et sans glitch,
mais coûte 4 à 8 fois le travail de blit (mesuré, voir
`notes/2026-08-18-vram-direct-patch-plan.md`).

## 3. Piste 2 — Sprites plus colorés (exploiter les 4 couleurs du mode 1)

Constat : la limite n'est pas dans le moteur de blit (qui supporte déjà
plusieurs couleurs *si on l'appelle plusieurs fois par sprite* avec des
masques différents par zone) mais dans le **format des données** — le
bitmap sprite actuel ne porte aucune info couleur par pixel/zone.

Conséquence : ajouter de vraies teintes multi-couleurs mode 1 est un projet
de **refonte d'assets + format**, pas un simple patch moteur :
- redessiner les sprites en zones colorées ;
- étendre le format de ressource pour porter cette info (ex. plusieurs
  passes de blit par sprite, chacune avec son propre masque/couleur, sur
  des sous-régions du bitmap) ;
- modifier le blit existant pour accepter plusieurs paires masque/couleur
  par sprite au lieu d'une seule par appel.

Cette piste consomme de la RAM (résolue par la piste 1 / 128K) et du temps
de blit (plusieurs passes par sprite au lieu d'une) — à quantifier une fois
le format défini. À traiter comme un chantier distinct du reste (choix
artistique + format), à maquetter sur 1-2 sprites avant de généraliser.

## 4. Piste 3 — Dessiner directement en VRAM (supprimer le buffer intermédiaire)

Idée : au lieu de dessiner dans le buffer intermédiaire `0x9000-0xBFFF` puis
recopier les rectangles sales vers la VRAM (`fn_blit_copy_line`), dessiner
directement dans la VRAM cible.

Ce que ça change réellement :
- La correction d'adressage CRTC entrelacé (`+0x0800` tous les 8 lignes,
  correction `+0xC050`) actuellement faite pendant la copie
  (`fn_blit_copy_line`, §8.2) ne disparaît pas : elle se **déplace** vers la
  phase de dessin. Chaque avance de ligne dans le blit/fill devra gérer le
  saut CRTC au lieu d'un simple incrément linéaire.
- Le flip Y actuel (artefact du portage Spectrum, source `-= 64`) n'a plus
  de raison d'être si on dessine "à l'endroit" directement en VRAM — donc
  simplification possible en plus du gain.
- Le vrai gain : élimination de la passe de recopie pleine page (LDIR par
  rectangle), qui ne fait aujourd'hui aucun travail utile en soi (juste
  transposer un buffer déjà correct). Gain net, pas un compromis, **si**
  l'adressage CRTC est bien intégré au blit.

Routines à modifier :
- `fn_fill_rect` (`0x1DC1`) et `fn_stage_blit_and_clear` (`0x2E6C`) :
  remplacer l'incrément de ligne plat par la logique d'avance CRTC
  actuellement dans `fn_blit_copy_line` — factoriser cette macro d'avance de
  ligne pour qu'elle soit partagée entre fill/blit/copy plutôt que dupliquée
  ou existant seulement dans la copie.
- Le blit masqué principal (dispatch JP auto-modifiant, §7 de
  `RENDERING_PIPELINE.md`) : même chose, l'avance colonne-à-colonne devient
  CRTC-aware.

## 5. Piste 4 — Double buffer vidéo (éviter le tearing)

Problème identifié : le système de rectangles sales actuel repose sur le
fait qu'il n'existe qu'**une seule copie persistante** de l'état affiché
(le buffer intermédiaire, unique). Si on dessine directement dans une VRAM
à page unique (piste 3 seule), on prend un risque de tearing visuel sur les
zones en cours de mise à jour pendant l'affichage — probablement négligeable
vu que ce sont de petites zones (silhouettes d'entités), pas le plein écran.

Si on veut éliminer ce risque avec un vrai double buffer (page A affichée
pendant qu'on dessine dans B, puis flip via CRTC R12/R13 ou bascule de
banque, synchronisé sur `var_interrupt_sync_flag` existant) :

**Le piège** : une page n'est retouchée qu'une frame sur deux → son contenu
reflète l'état d'il y a **2 frames**, pas 1. Comparer contre la bbox
précédente "globale" (partagée entre les deux pages) casserait
l'effacement des fantômes dès qu'une entité a bougé entre les deux frames.

**Solution retenue (à implémenter)** : suivre l'historique de bbox
**par page**, pas par entité globalement. Chaque entité stocke deux bbox
précédentes, une par page (`bbox_prev_A`, `bbox_prev_B`), et à chaque frame
on n'efface/compare que par rapport à la bbox précédente **de la page qu'on
est en train de redessiner** :

```
frame courante, page_cible = back_buffer_actuel (A ou B, alterne à chaque frame)

pour chaque entité à retraiter:
    rect = union(entité.bbox_prev[page_cible], entité.bbox_courante)
    effacer(page_cible, rect)
    dessiner(page_cible, entité, bbox_courante)
    entité.bbox_prev[page_cible] = entité.bbox_courante
```

Propriétés :
- **Une seule page est touchée par frame**, exactement comme aujourd'hui —
  pas de doublement du travail total, juste 4 octets de plus par entité
  (max 40 entités = 160 octets, négligeable même en 64K, trivial en 128K).
- Une entité statique reste "gratuite" exactement comme aujourd'hui : son
  empreinte est déjà présente sur les deux pages depuis son apparition, pas
  besoin d'y retoucher tant qu'elle ne bouge pas.

Cas particuliers à traiter à l'implémentation :
- **Init** : la première fois qu'une page reçoit une entité,
  `bbox_prev[page]` doit être initialisée à la bbox courante (sinon l'union
  avec une valeur garbage/zéro fausse le rectangle sale) — vérifier comment
  le code actuel initialise `*_prev` à l'apparition d'une entité et
  généraliser aux deux slots.
- **Disparition/culling** : une entité qui sort du champ doit encore
  déclencher un effacement (sans redessin) sur la page cible tant que sa
  `bbox_prev[page]` n'est pas vide — sinon un fantôme reste visible une
  frame de plus sur chaque page.

Sélection de la base d'adresse VRAM par page : soit deux offsets fixes si on
reste en RAM linéaire au-delà de 64K via banking (piste 1), soit un simple
registre de base ajouté à chaque calcul d'adresse dans les routines de la
piste 3.

## 5bis. BILAN MESURÉ de la piste 3 (2026-08-19) — le buffer n'était pas un gaspillage

La piste 3 partait du postulat « le buffer intermédiaire occupe 12 Ko pour
rien, le dessin direct sera plus rapide ». **Implémentée jusqu'au bout, elle
reste plus lente que l'original.** Voici pourquoi, parce que c'est utile pour
toute autre optimisation de ce moteur.

### Le buffer était aussi une fenêtre de publication

La copie différée ne publiait que les **rectangles sales**. Le buffer avait
donc le droit d'être **localement faux** : l'invariant à tenir n'était pas
« le plan de composition est correct » mais « il est correct dans les zones
qu'on est sur le point de publier ». Une zone corrompue hors rectangle ne se
voyait pas, et se réparait d'elle-même dès qu'elle redevenait sale.

Cet invariant **faible** fait disparaître deux problèmes durs :

1. **Pas de fermeture transitive du marquage « à redessiner ».** Sans
   fenêtre de publication, un bloc de décor redessiné écrase l'objet devant
   lui, donc il faut aussi redessiner cet objet, donc ses voisins, etc.
   **Mesuré : ça cascade jusqu'à toute la salle**, parce que le décor d'une
   salle est un maillage connexe. Inutilisable.
2. **Pas d'écrêtage dans le blit.** La copie écrête gratuitement, avec un
   `LDIR` — la primitive de publication la moins chère du Z80, 21
   cycles/octet et aucune logique par pixel.

Coût du buffer : 12 Ko de RAM + un `LDIR` par rectangle sale. En échange, deux
problèmes algorithmiques supprimés. **Sur un Z80 à 4 MHz c'est un bon
marché.** La piste 3 ne supprime pas un coût : elle le déplace de la RAM vers
le CPU.

### Ce que la piste 3 apporte quand même

- `#9000-#BFFF` (12 Ko) réellement libres, et `#8000-#80FF` libéré de la
  pile — ce qui compte pour le montage 6128 (§2bis) et pour du stockage
  passif (§2).
- Une passe de copie supprimée du cycle de frame.
- L'écrêtage aux rectangles sales, **qui reste nécessaire avec un double
  buffer** (le problème se pose à l'identique page par page).
- Un `fn_blit_masked` restructuré : début et longueur de ligne variables,
  ce que les familles déroulées d'origine interdisaient.

### Pistes d'accélération, par gain attendu décroissant

1. **Supprimer le test de fenêtre Y par ligne.** `clip_blit` balaie
   aujourd'hui les `clip_h` lignes du sprite et teste chacune contre
   `[rect_ymin, rect_ymax]` (~30 cycles par ligne, y compris les lignes
   sautées). Le driver a tout ce qu'il faut pour calculer directement la
   première ligne dans la fenêtre, son adresse VRAM
   (`fn_screen_addr_from_bc`) et le pointeur de forme (`payload + k*w`, une
   multiplication par `fn_mul8x16`), puis lancer une boucle de `rows` lignes
   **sans aucun test**. Les lignes hors fenêtre deviennent gratuites.
2. **Fusionner les rectangles sales avant la passe de dessin.** Une entité
   chevauchant `k` rectangles est mise en place et balayée `k` fois. Le blit
   masqué étant **idempotent**, une fenêtre trop large ne produit aucune
   erreur — seulement du travail. Fusionner les rectangles qui se recouvrent
   ou se touchent réduit `k` sans risque de régression visuelle.
3. **Sprites pré-retournés en RAM banquée.** `fn_flip_sprite_shape`
   (`#3200`) mute le bitmap **en place** quand l'orientation demandée diffère
   de celle mémorisée dans l'octet 0 de la forme. Une entité qui alterne
   d'orientation d'une frame à l'autre paie donc un retournement complet à
   chaque frame : échange de lignes entières pour l'axe vertical, et pour
   l'axe horizontal un `fn_mirror_byte_bits` par nibble. Pré-stocker les
   orientations supprime ce coût. C'est l'usage « stockage passif » pour
   lequel la RAM banquée est faite (§2). **À mesurer d'abord** : compter les
   retournements par frame en jeu réel — le gain dépend entièrement de leur
   fréquence.
4. **Alléger le va-et-vient sur `H`.** Le corps de colonne décalé fait 3
   `dec h` par colonne uniquement pour revenir à la page de base après ses 4
   accès aux tables masque/couleur. Une réorganisation de l'indexation des
   tables pourrait les éviter (~12 cycles/colonne).

### Pourquoi c'était plus confortable sur ZX Spectrum

Arithmétique des plateformes, indépendante de Knight Lore :

| | ZX Spectrum | CPC mode 1 |
|---|---|---|
| écran | 6 912 o (6 144 bitmap + 768 attributs) | 16 384 o |
| profondeur | 1 bit/pixel | 2 bits/pixel |
| couleur | cellule 8×8, plan séparé | dans les bits de pixel |
| décalage sub-octet | une rotation (`RR`) | **table précalculée** |

Deux conséquences. D'abord un plan de composition hors écran coûte ~6 Ko sur
Spectrum contre ~12 Ko sur CPC pour la même zone de jeu. Ensuite, et
surtout : en mode 1 les bits d'un octet écran ne sont pas des pixels
consécutifs mais des plans entrelacés, donc décaler un sprite d'un ou deux
pixels n'est **pas** une rotation. D'où les 14 tables de 256 octets
(`#8200-#8FFF`) construites au boot par `fn_build_pixel_bitscatter_tables`,
et les 4 accès mémoire par octet écran dans `fn_blit_masked`. Sur Spectrum le
même décalage est quelques `RR`.

Le blit du Spectrum est donc structurellement bien moins cher, et toute
l'architecture y a beaucoup plus de marge. **Hypothèse non vérifiée** : la
version Spectrum redessine peut-être la salle entière à chaque frame (le
scintillement caractéristique des Filmation sur Spectrum est compatible), le
système de rectangles sales du CPC étant alors une adaptation spécifique. À
trancher par la méthode du jeu sœur (`docs/METHODOLOGY.md` §21), pas par
supposition.

## 6. Ordre de traitement suggéré

1. Piste 3 (dessin direct en VRAM, page unique, sans double buffer) —
   gain net immédiat, réutilise 100% du système de rectangles sales
   existant, pas de changement de structure entité.
2. Piste 4 (double buffer + historique de bbox par page) — une fois la
   piste 3 validée, ajoute la structure à deux slots et le flip
   synchronisé.
3. Piste 1 (banking 128K) — en parallèle ou juste avant la piste 2/3 selon
   les besoins RAM concrets (sprites étendus, double buffer si en RAM
   banquée plutôt qu'en VRAM linéaire 64K).
4. Piste 2 (sprites multi-couleurs) — chantier séparé (assets + format),
   à maquetter indépendamment une fois le moteur de blit stabilisé par les
   pistes 1/3/4.
