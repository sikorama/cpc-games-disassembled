# Segmentation complète des 104 formes de sprite (`#4422-#7FFF`)

Reprise du chantier "axe 1" (finir le désassemblage, avoir des données
bien découpées) après la résolution du boot réel (2026-08-12). Cible
choisie : le plus gros morceau de données encore non segmenté — le
blob `#4422-#7FFF` (~14 Ko) pointé par `tbl_sprite_dispatch`, jusqu'ici
transcrit en octets réels mais comme un unique bloc opaque.

## Méthode

Le format de `struct_sprite_shape` était déjà entièrement confirmé
depuis le 2026-08-10 (voir `docs/SYMBOLS.md` `#2F02`) : en-tête 3
octets (largeur `V` = octets/ligne directement, hauteur `H`, 1 octet
inutilisé), puis bitmap `V*H` octets. Il ne restait donc "que" à
calculer, pour chacun des pointeurs de `tbl_sprite_dispatch`, l'extent
exacte `3 + V*H` et à vérifier que ça produit un découpage cohérent
(sans trou ni chevauchement) plutôt que de le supposer.

1. Réassemblé le binaire courant (déjà correct et validé la veille),
   extrait les 194 pointeurs de `tbl_sprite_dispatch` (`#429E-#4421`) →
   104 adresses uniques (90 alias partagés entre plusieurs types
   d'entité).
2. Pour chaque adresse unique, décodé l'en-tête et calculé l'extent.
3. Trié les 104 adresses et vérifié : `adresse[i] + extent[i] ==
   adresse[i+1]` pour i=0..102. **Résultat : 103/104 exactement
   contigus**, un seul écart d'1 octet (juste après la sentinelle
   `#4422`) — et 5 octets isolés en toute fin de zone (`#7FFB-#7FFF`).
   Les deux écarts sont des `#00`, cohérent avec du simple padding
   d'alignement, pas des données manquantes.
4. Recoupé les 104 adresses avec `notes/2026-08-10-sprite-contact-sheet-naming.md`
   (planche de contact déjà nommée visuellement par l'utilisateur en
   session précédente, 103 formes + la sentinelle) : **correspondance
   EXACTE, aucun orphelin des deux côtés** — ce manifest existant a pu
   être réutilisé directement comme source des noms officiels, sans
   deviner de nomenclature.
5. Généré 104 entrées dans `asm/symbols.json` (`kind: tbl`, `status:
   confirmed`, `count` = extent réelle, pas de `literal_bytes` — le
   générateur lit les octets réels depuis la RAM live à chaque
   régénération, comme pour `tbl_object_catalog`/`tbl_sprite_dispatch`).
   Nom : `sprite_<nom_officiel>_<adresse>` (6 coquilles de frappe du
   nommage d'origine corrigées au passage : `crystall_ball`→
   `crystal_ball`, `caludron_down`→`cauldron_down`, `firebugs1/2`→
   `firebug1/2`, le doublon `werewulf_feet8` (2e occurrence) →
   `werewulf_feet9` (suggestion déjà notée par l'utilisateur), `frog_status`→
   `frog_statue`).
6. Régénéré `asm/data/resources_zone.asm` via `tools/gen_asm.py` sur la
   plage complète `#4000-#8000`.
7. **Validation** : réassemblé le `.sna` avant/après cette
   régénération, comparaison binaire complète (`cmp`) — **identique
   octet pour octet**. Confirme que cette passe n'a fait QUE
   re-étiqueter des octets déjà réels et déjà validés (boot réel
   toujours fonctionnel après, re-testé pour être sûr).

## Résultat

`asm/data/resources_zone.asm` ne contient plus un unique blob opaque
de 14 Ko : 104 symboles nommés et bornés (`sprite_ruby_4687`,
`sprite_melkhior_up1_4AD7`, `sprite_knight_up1_4BA0`, etc.), chacun
avec sa largeur/hauteur réelle en commentaire et le(s) type(s)
d'entité qui le référencent. Reste hors scope de cette passe (axes
ouverts pour la suite) :
- la zone `#4000-#417D` (toujours des octets bruts sans structure
  identifiée) ;
- la rotation 90° du bitmap au rendu (mystère non résolu depuis
  2026-08-10) ;
- la logique (pas juste le sprite) de plusieurs types jamais
  désassemblés (`conkers2` 0x58, `sphere` 0x59, second segment de
  herse 0x08, etc. — voir la liste "Pistes ouvertes" de
  `notes/2026-08-10-sprite-contact-sheet-naming.md`).
