; ============================================================
; entity_types.equ.asm -- types d'entite (valeurs du champ off_type),
; PAS des adresses. Prefixe type_ pour eviter toute confusion avec les
; labels fn_/tbl_/var_/struct_ (qui designent des adresses memoire).
; Source : docs/SYMBOLS.md, section "Constantes / valeurs speciales
; connues". Statut de confiance repris en commentaire.
; ============================================================

; --- Joueur ---
type_player_initial            equ     #12     ; confirmed -- valeur vue sur l'entite 0 en debut de partie
type_player_day                equ     #14     ; confirmed -- forme stable "jour" (explorateur)
type_player_werewolf           equ     #34     ; confirmed -- forme stable "nuit" (loup-garou), = type_player_day XOR #20
type_player_transform_base     equ     #5C     ; confirmed -- 4 types transitoires #5C-#5F (transformation jour/nuit)
type_player_jump_transition_base equ   #30     ; confirmed (partiel) -- famille #30-#3D, phases de saut/deplacement vertical
type_player_materialize_base   equ     #70     ; confirmed -- 16 etapes #70-#7F, sequence de (de)materialisation
type_player_materialize_pivot  equ     #77     ; confirmed -- bascule entre les deux moities de la sequence
type_player_materialize_end    equ     #7F     ; confirmed -- fin de sequence, restaure le type stable

; --- Portes ---
type_door_post_a               equ     #02     ; confirmed -- montant de porte, variante A
type_door_post_b               equ     #03     ; confirmed -- montant de porte, variante B
type_door_post_tree_a          equ     #04     ; confirmed -- meme logique que type_door_post_a, theme "arbre"
type_door_post_tree_b          equ     #05     ; confirmed -- meme logique que type_door_post_b, theme "arbre"

; --- Decor statique ---
type_wood_block                equ     #06     ; hypothesis -- "bloc en bois", decoratif
type_static_block               equ     #07     ; confirmed -- bloc decoratif statique, sprite #59DB
type_wall_static_a              equ     #0A     ; hypothesis (renforcee) -- famille "murs" (sous-groupe A, +0x0D)
type_wall_static_b              equ     #0B     ; hypothesis (renforcee) -- famille "murs" (sous-groupe B, +0x0E)
type_wall_static_c              equ     #0C     ; hypothesis (renforcee) -- famille "murs" (sous-groupe C, +0x0F)
type_wall_segment               equ     #80     ; confirmed -- segment de mur generique (empile en plusieurs entites), logique = fn_static_calib_vector_table (#1D7F)
type_toad_statue                equ     #16     ; confirmed -- statue de crapaud, decoratif
type_dormant_block              equ     #8F     ; confirmed -- bloc "dormant", indiscernable d'un bloc statique
type_dormant_block_awake_base   equ     #B8     ; confirmed -- sequence d'eveil du bloc dormant (2 etapes seulement, #B8->#B9, s'arrete puis idle -- voir fn_pickup_catalog_ptr_clear_and_idle #17F4)

; --- Mecanismes ---
type_moving_grate               equ     #09     ; confirmed -- grille mobile (monte/descend)
type_floor_spike                equ     #17     ; confirmed -- piques au sol
type_ceiling_spike_ball          equ     #3F     ; confirmed -- boule a pics au plafond
type_pushable_block             equ     #3E     ; confirmed -- bloc poussable
type_pushable_table             equ     #54     ; confirmed -- table poussable (arret net)
type_sliding_chest              equ     #55     ; confirmed -- coffre glissant (pas d'arret net)
type_sinking_cube               equ     #5B     ; confirmed -- cube qui descend sous le poids du joueur

; --- Gardien ---
type_guard_patrol                equ     #1E     ; confirmed -- corps du gardien en patrouille (marche, bit0=anim)
type_guard_walk_alt              equ     #1F     ; confirmed -- 2e phase de marche (bascule avec #1E)
type_guard_legs_base             equ     #90     ; confirmed -- jambes du gardien (10 valeurs #90-#9D), sauf #96/#97
type_unidentified_90_range_a     equ     #96     ; unknown -- exception non identifiee dans la plage jambes
type_unidentified_90_range_b     equ     #97     ; unknown -- exception non identifiee dans la plage jambes

; --- Ennemis mobiles ---
type_ghost_base                  equ     #50     ; confirmed -- fantome, deplacement aleatoire (#50-#53)
type_will_o_wisp_alt             equ     #56     ; confirmed -- feu follet, logique differente de #B4
type_bouncing_ball_base          equ     #B2     ; confirmed -- balle rebondissante mortelle (#B2/#B3)
type_will_o_wisp_base            equ     #B4     ; confirmed -- feu follet (oscillation Y + rebond)
type_ball_chase_flee             equ     #B6     ; confirmed -- boule dont le sens depend de la forme jour/nuit du joueur
type_hostile_patrol_base         equ     #83     ; confirmed -- patrouille + mort au contact (#83-#85), visuel = famille sprite POLTERGEIST (meme famille que #A0-#AB), confirme en direct 2026-08-14 (declenchement force du puzzle de Melkhior)
type_pusher_idle_base            equ     #A0     ; confirmed (partiel) -- famille poussoir au repos (#A0-#A3)
type_pusher_enemy_base           equ     #A4     ; confirmed -- poussoir actif, attire vers le joueur (#A4-#A7)
type_pusher_transition_base      equ     #A8     ; confirmed (partiel) -- transition poussoir (#A8-#AB)
type_moving_block_variant_a      equ     #36     ; confirmed -- "bloc mobile" variante A (meme logique que #37, param different)
type_moving_block_variant_b      equ     #37     ; confirmed -- "bloc mobile" variante B

; --- Objets a ramasser (famille boule de cristal, rotation #60-#67) ---
type_pickup_diamond              equ     #60     ; confirmed -- "diamant"
type_pickup_unknown_61           equ     #61     ; unknown -- non identifie visuellement
type_pickup_unknown_62           equ     #62     ; unknown -- non identifie visuellement
type_pickup_unknown_63           equ     #63     ; unknown -- non identifie visuellement
type_pickup_cup                  equ     #64     ; confirmed -- "tasse"
type_pickup_bottle               equ     #65     ; confirmed -- "bouteille"
type_pickup_crystal_ball         equ     #66     ; confirmed -- "boule de cristal"
type_pickup_bonus_life            equ     #67     ; confirmed -- vie supplementaire cachee (fn_bonus_life_pickup_logic)
type_treasure_sequence_base      equ     #68     ; confirmed -- memes sprites que #60-#66 +8 (bit3 du type) ; cree par fn_player_use_held_object (#18AA) en deposant l'objet tenu salle #88 (chaudron) avec grid_z>=#98 -- voir #1A93/#18AA

; --- Effet de collision generique ---
type_collision_transformed       equ     #BB     ; confirmed -- resultat de fn_collision_effect sur un objet ramasse (#60-#67) ; logique = fn_pickup_catalog_ptr_clear_and_idle (#17F4), efface son pointeur tbl_object_catalog puis idle

; --- Le Magicien (salle #88 uniquement) ---
type_wizard_boss_base            equ     #9E     ; confirmed -- le Magicien (reutilise fn_guard_patrol_logic)
type_wizard_cauldron             equ     #8D     ; confirmed -- le chaudron (statique)
type_wizard_cloud_indicator      equ     #8E     ; confirmed (hypothesis mecanisme icone) -- indicateur flottant au-dessus du chaudron
