# Session — 0x1802 : HUD conditionnel (probable notification d'objet collecté)

## Contexte

Dernier appel non exploré de `fn_render_entities` (0x2E9D: call 0x1802).

## 0x1802 — Affichage conditionnel de 3 slots depuis une petite table

**Statut : hypothesis sur le rôle métier, confirmed sur le désassemblage brut**

```
1802  3A7A00     ld     a,(007A)
1805  A7         and    a
1806  C8         ret    z           ; ne fait RIEN si (0x007A) == 0
1807  AF         xor    a
1808  327A00     ld     (007A),a    ; consomme le flag (remis à 0 immédiatement)
180B  DDE5       push   ix
180D  DD217718   ld     ix,1877     ; MÊME zone statique que 0x1C80 (HUD soleil/lune)
1811  0603       ld     b,03        ; boucle sur 3 slots
1813  21AB00     ld     hl,00AB     ; tbl_hud_slot_icons (3 octets, un par slot)
1816  C5         push   bc
1817  E5         push   hl
1818  78         ld     a,b
1819  ED44       neg
181B  C603       add    a,03
181D  CB27       sla    a
181F  CB27       sla    a
1821  CB27       sla    a
1823  4F         ld     c,a
1824  CB27       sla    a
1826  81         add    a,c         ; calcule une position X (slot × largeur fixe,
                                    ;  motif classique n*8 + n*16 = n*24)
1827  C610       add    a,10
1829  DD7716     ld     (ix+16),a   ; position X du slot HUD
182C  DD361700   ld     (ix+17),00  ; position Y fixe (ligne HUD)
1830  E5         push   hl
1831  DD6E16     ld     l,(ix+16)
1834  DD7E17     ld     a,(ix+17)
1837  C617       add    a,17
1839  67         ld     h,a
183A  CD8631     call   3186        ; calcule adresse buffer intermédiaire
183D  011806     ld     bc,0618
1840  AF         xor    a
1841  CDC11D     call   1DC1        ; efface l'ancien contenu du slot
1844  E1         pop    hl
1845  7E         ld     a,(hl)      ; lit l'icône du slot (0 = vide/rien à afficher)
1846  A7         and    a
1847  2806       jr     z,184F      ; slot vide -> skip le dessin
1849  DD7700     ld     (ix+00),a   ; type de sprite = icône du slot
184C  CD2B2F     call   2F2B        ; dessine l'icône (variante de blit du HUD)
184F  DD4E16     ld     c,(ix+16)
1852  DD7E17     ld     a,(ix+17)
1855  C617       add    a,17
1857  47         ld     b,a
1858  CD9531     call   3195        ; adresse VRAM réelle
185B  69         ld     l,c
185C  60         ld     h,b
185D  CD8631     call   3186        ; adresse buffer intermédiaire (redondant avec
                                    ;  1839, recalculé pour le blit final)
1860  010618     ld     bc,1806
1863  3A7D00     ld     a,(007D)    ; var_render_disabled_flag (déjà connu)
1866  A7         and    a
1867  2003       jr     nz,186C     ; si rendu désactivé, skip le blit final
1869  CDC02E     call   2EC0        ; fn_blit_copy_line direct
186C  E1         pop    hl
186D  C1         pop    bc
186E  23         inc    hl
186F  23         inc    hl          ; avance hl de 2 (probablement pointeur dans
                                    ;  tbl_hud_slot_icons, 1 octet lu + 1 saut)
```

**État observé en jeu** : `(0x007A) = 0`, `tbl_hud_slot_icons` (0x00AB-
0x00AD) = `00 00 00` — la routine ne s'exécute pas dans les conditions
actuelles (pas d'objet récemment collecté).

**Interprétation (hypothesis)** : cette routine affiche jusqu'à 3
"slots" de HUD (probablement une rangée d'icônes d'objets/indices
possédés par le joueur), mais SEULEMENT quand `(0x007A)` est non-nul
(probablement positionné ailleurs, par la logique de collision/collecte
d'objet, au moment où le joueur ramasse quelque chose). Le flag est
consommé immédiatement (remis à 0), suggérant un mécanisme "affiche une
fois puis arrête" plutôt qu'un HUD permanent — cohérent avec une
notification transitoire ("objet obtenu !") plutôt qu'un inventaire
affiché en continu.

**Reste à élucider** :
1. Où `(0x007A)` est positionné à une valeur non-nulle (probablement
   dans la logique de collision `fn_check_collisions`/gestionnaires
   `0x2835-0x2892`, ou l'instanciation d'objets `0x1DFB`/`0x29CD`).
2. Le rôle exact de `tbl_hud_slot_icons` (0x00AB) — table de 3 octets,
   à observer en jeu au moment de la collecte d'un objet pour confirmer
   le contenu réel affiché.
3. Provoquer une collecte d'objet en jeu et observer `(0x007A)` +
   `tbl_hud_slot_icons` pour valider empiriquement cette hypothèse (même
   méthode que pour le compteur de jours : lire avant/après un
   évènement connu, comparer à l'affichage réel).
