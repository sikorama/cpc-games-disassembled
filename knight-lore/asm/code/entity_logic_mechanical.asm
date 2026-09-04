; ============================================================
; entity_logic_mechanical.asm -- genere par tools/gen_asm.py, plage #0FD8-#170D
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #0FD8
fn_guard_legs_logic:
        ; (était "fn_guard_weapon_logic", hypothèse d'arme infirmée — le gardien
        ; observé n'a ni arme ni compagnon). Logique partagée par les types
        ; 0x90-0x9D (~10 valeurs, tous dispatchés ici) — position de grille suit
        ; celle du gardien (0x1E/0x1F) avec un léger décalage temporel. Très
        ; probablement la SECONDE MOITIÉ du sprite visuel du gardien (jambes,
        ; animées séparément du torse pour l'animation de marche) plutôt qu'une
        ; entité distincte.
        call    #1D89
        ld    a,(ix+#09)
        or    (ix+#0A)
        ret    z
        ld    a,(var_frame_counter)
        rrca
        rrca
        and    #47
        add    a,#40
        ld    l,a
        ld    h,#01
        call    #0A14
        ld    a,(ix+#09)
        cp    (ix+#0A)
        jr    c,fn_guard_legs_branch_carry
        bit    7,a
        jr    nz,fn_guard_legs_branch_reset_type
        set    3,(ix+off_type)
loc_1001:
        res    6,(ix+off_flags)
loc_1005:
        call    #2231
        jp    #1F7B
fn_guard_legs_branch_reset_type:
        ; Cible de "jr nz,#100B" (#0FFB) dans fn_guard_legs_logic: RES
        ; 3,(ix+off_type) puis JR #1001 -- rejoint la queue commune (res bit6
        ; flags, call #2231, jp #1F7B). Branche "bit7 de a pose" (jambe dans
        ; l'autre sens).
        res    3,(ix+off_type)
        jr    loc_1001
fn_guard_legs_branch_carry:
        ; Cible de "jr c,#1011" (#0FF7) dans fn_guard_legs_logic: teste BIT
        ; 7,(ix+0A), branche vers fn_guard_legs_branch_carry_reset (#1021) si Z,
        ; sinon SET 3,(ix+off_type) / SET 6,(ix+off_flags) puis JR #1005 (queue
        ; commune call #2231/jp #1F7B).
        bit    7,(ix+#0A)
        jr    z,fn_guard_legs_branch_carry_reset
        set    3,(ix+off_type)
loc_101B:
        set    6,(ix+off_flags)
        jr    loc_1005
fn_guard_legs_branch_carry_reset:
        ; Cible de "jr z,#1021" depuis fn_guard_legs_branch_carry (#1015): RES
        ; 3,(ix+off_type) puis JR #101B (rejoint SET 6,(ix+off_flags)/JR #1005 de
        ; fn_guard_legs_branch_carry).
        res    3,(ix+off_type)
        jr    loc_101B
fn_guard_legs_logic_alt:
        ; Second point d'entree complet dans la logique jambes (types 0x90-0x9D),
        ; jamais atteint par le flux interne de fn_guard_legs_logic -- tres
        ; probablement une entree de dispatch dediee a une jambe/sous-type
        ; different (gauche/droite ?) partageant le meme corps. CALL #1DB7
        ; (calibration), teste bit0,(ix+off_state_flags_2) pour choisir le signe
        ; (NEG ou non) du vecteur ecrit dans (ix+09)/(ix+25) (mirroir), CALL
        ; fn_guard_walk_animation_toggle (#1055), RST 10 (application vecteur),
        ; teste bit0,(ix+off_cooldown_or_collision_flags) pour basculer bit0 de
        ; state_flags_2 (toggle direction), puis copie grid_x->pending_grid_x et
        ; JP #1139 (queue partagee, meme cible que fn_guard_patrol_logic #12A2).
        call    #1DB7
        bit    0,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,loc_1034
        neg
loc_1034:
        ld    (ix+#09),a
        ld    (ix+#25),a
        call    fn_guard_walk_animation_toggle
        rst    #10
        bit    0,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_104C
        ld    a,(ix+off_state_flags_2)
        xor    #01
        ld    (ix+off_state_flags_2),a
loc_104C:
        ld    a,(ix+off_grid_x)
        ld    (ix+off_pending_grid_x),a
        jp    loc_1139
fn_guard_walk_animation_toggle:
        ; Pose le bit 0 du type (0x1E<->0x1F) ET le bit 6 des flags selon l'axe
        ; DOMINANT du vecteur de déplacement (ix+09)/(ix+0A) puis son signe.
        ; CORRIGÉ 2026-09-04 : ce n'est PAS un "battement de marche 2 phases"
        ; comme le disait ce commentaire -- les deux bits sont dérivés du signe
        ; du vecteur, donc c'est un CODE D'ORIENTATION, la même grandeur que
        ; (flags.bit6 << 1) | type.bit3 chez le joueur (fn_get_orientation_code
        ; #22D0), au bit près : le corps du garde loge son sélecteur de dessin
        ; en type.bit0 et non type.bit3. Les "4 combinaisons visuelles" sont
        ; les 4 orientations, pas 2 phases x 2 miroirs. Même structure que
        ; fn_guard_legs_logic (#0FD8) ci-dessus. La phase de marche, elle, vit
        ; dans les 3 bits bas du type et est avancée par le recycleur #2231.
        ld    a,(ix+#09)
        or    (ix+#0A)
        ret    z
        ld    a,(ix+#09)
        cp    (ix+#0A)
        jr    c,fn_guard_walk_animation_toggle_branch_a
        bit    7,a
        jr    nz,fn_guard_walk_animation_toggle_branch_b
        set    0,(ix+off_type)
loc_106C:
        res    6,(ix+off_flags)
        ret
fn_guard_walk_animation_toggle_branch_b:
        ; Cible de "jr nz,#1071" (#1066): RES 0,(ix+off_type) puis JR #106C --
        ; rejoint la queue commune (res bit6 flags, ret).
        res    0,(ix+off_type)
        jr    loc_106C
fn_guard_walk_animation_toggle_branch_a:
        ; Cible de "jr c,#1077" (#1062): teste BIT 7,(ix+0A), branche vers
        ; fn_guard_walk_animation_toggle_branch_a_reset (#1086) si Z, sinon SET
        ; 0,(ix+off_type) / SET 6,(ix+off_flags) / RET.
        bit    7,(ix+#0A)
        jr    z,fn_guard_walk_animation_toggle_branch_a_reset
        set    0,(ix+off_type)
loc_1081:
        set    6,(ix+off_flags)
        ret
fn_guard_walk_animation_toggle_branch_a_reset:
        ; Cible de "jr z,#1086" depuis fn_guard_walk_animation_toggle_branch_a
        ; (#107B): RES 0,(ix+off_type) puis JR #1081 (rejoint SET
        ; 6,(ix+off_flags)/RET).
        res    0,(ix+off_type)
        jr    loc_1081
fn_toad_statue_logic:
        ; Logique du type d'entité 0x16 (statue de crapaud) — calibration de
        ; projection seule, purement décoratif/statique. Superposé (même grid_x/y,
        ; field3 différent) aux blocs en bois (0x06) qu'il surmonte.
        call    fn_entity_apply_decor_state_flags
        jp    #1DA8
fn_ceiling_spike_ball_logic:
        ; Logique du type d'entité 0x3F (boules à pics au plafond) — teste
        ; var_pseudo_random_acc (0x006D) < 0x10 pour se déclencher (piège pseudo-
        ; aléatoire, ~6%/tick), verrouille var_room_reset_flag_4 (0x0085) pour
        ; garantir une seule boule active à la fois par salle, applique la chute
        ; via RST 10. 12 occurrences dans la table d'entités correspondant
        ; exactement aux "boules à pics au plafond" (11 comptées visuellement + 1
        ; masquée, comme soupçonné). Bonus: sur collision (bit2 de (ix+0C)) après
        ; la chute, arme fn_sound_arm_position_pitch_ch1 (0x0A22, via 0x10BD) —
        ; clic d'impact dont la hauteur dépend de grid_z
        call    fn_entity_apply_decor_state_flags
        call    #1D8F
        ld    a,(var_room_reset_flag_5)
        and    a
        ret    nz
        bit    2,(ix+off_state_flags_2)
        jr    nz,fn_ceiling_spike_ball_logic_tail
        ld    hl,var_room_reset_flag_4
        ld    a,(hl)
        and    a
        ret    nz
        ld    a,(var_pseudo_random_acc)
        cp    #10
        ret    nc
        set    2,(ix+off_state_flags_2)
        ld    (hl),#01
        ret
fn_ceiling_spike_ball_logic_tail:
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    nz,fn_ceiling_spike_ball_logic_tail_reset
        call    fn_sound_arm_position_pitch_ch1
loc_10C0:
        jp    #1F7B
fn_ceiling_spike_ball_logic_tail_reset:
        ; Cible de "jr nz,#10C3" depuis fn_ceiling_spike_ball_logic_tail (#10BB):
        ; RES 2,(ix+off_state_flags_2), remet var_room_reset_flag_4 (#0085) a 0,
        ; puis JR vers le JP #1F7B de fn_ceiling_spike_ball_logic_tail.
        res    2,(ix+off_state_flags_2)
        ld    hl,var_room_reset_flag_4
        ld    (hl),#00
        jr    loc_10C0
fn_spike_logic:
        ; Logique du type d'entité 0x17 (piques au sol) — oscillation périodique
        ; (throttle 2 frames) avec variation pseudo-aléatoire (XOR avec
        ; var_pseudo_random_acc bit 6), cycle d'animation 4 phases via
        ; fn_animation_cycle_4 (0x1260).
        call    fn_entity_apply_decor_state_flags
        jp    #1D8F
fn_spike_logic_tail:
        ; Suite de fn_spike_logic (apres le CALL #113F/JP #1D8F initial): CALL
        ; #1D9E (calibration, meme famille que will-o-wisp/bouncing-ball), LD
        ; (ix+0B),1, teste bit0,(ix+off_state_flags_2) pour choisir le signe du
        ; vecteur ecrit dans (ix+09), CALL fn_position_pitch_sound_arm (#0A07),
        ; RST 10, teste bit0,(ix+off_cooldown_or_collision_flags), puis JR #1112
        ; -- rejoint en plein milieu de fn_will_o_wisp_logic (partage la meme
        ; queue "cooldown -> toggle -> animation -> tail").
        call    #1D9E
        ld    (ix+#0B),#01
        bit    0,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,loc_10E5
        neg
loc_10E5:
        ld    (ix+#09),a
        call    fn_position_pitch_sound_arm
        rst    #10
        bit    0,(ix+off_cooldown_or_collision_flags)
        ld    a,#01
        jr    loc_1112
fn_will_o_wisp_logic:
        ; Logique du type d'entité 0xB4 (feu follet) — oscille UNIQUEMENT sur
        ; l'axe Y (le champ (ix+09), composante X, n'est jamais écrit), rebond par
        ; collision selon le même schéma que fn_bouncing_ball_logic et
        ; fn_resolve_patrol_vector (test bit 1 de (ix+0C), bascule bit 1 de
        ; (ix+0D)), joue le même son de rebond générique (0x09A6/0x09AC) que la
        ; balle rebondissante. "2 feux follets, qui se déplacent selon Y et qui
        ; sont en hauteur" — grid_z=0xA4 (nettement au-dessus des blocs),
        ; mouvement Y confirmé par poll RAM (grid_x rigoureusement fixe). Variante
        ; 0x1122 (probable type 0xB5): scintillement pseudo-aléatoire du flag de
        ; rendu selon var_pseudo_random_acc.
        call    #1D9E
        ld    (ix+#0B),#01
        bit    1,(ix+off_state_flags_2)
        ld    a,#02
        jr    nz,loc_1105
        neg
loc_1105:
        ld    (ix+#0A),a
        call    fn_position_pitch_sound_arm
        rst    #10
        bit    1,(ix+off_cooldown_or_collision_flags)
        ld    a,#02
loc_1112:
        jr    z,loc_111D
        xor    (ix+off_state_flags_2)
        ld    (ix+off_state_flags_2),a
        call    fn_sound_trigger_bounce
loc_111D:
        call    fn_animation_cycle_4
        jr    loc_1139
fn_will_o_wisp_logic_tail:
        ; Suite de fn_will_o_wisp_logic (apres "jr #1139", #1120): CALL #1D9E,
        ; teste bit0 de var_entity_update_counter (#0082, RET Z si impair --
        ; execute 1 frame sur 2), sinon melange bit6 de var_pseudo_random_acc
        ; (#006D) dans off_flags (scintillement pseudo-aleatoire), CALL
        ; fn_animation_cycle_4 (#1260), puis CALL #113F
        ; (fn_entity_apply_decor_state_flags) et JP #1F7B.
        call    #1D9E
        ld    a,(var_entity_update_counter)
        and    #01
        ret    z
        ld    a,(var_pseudo_random_acc)
        and    #40
        xor    (ix+off_flags)
        ld    (ix+off_flags),a
        call    fn_animation_cycle_4
loc_1139:
        call    fn_entity_apply_decor_state_flags
        jp    #1F7B
fn_entity_apply_decor_state_flags:
        ; Petit helper partage: LD A,(ix+off_state_flags_2) / OR #A0 (pose bits 5
        ; et 7) / LD (ix+off_state_flags_2),A / RET. Appele (via "call #113F") par
        ; fn_toad_statue_logic (#108C), fn_ceiling_spike_ball_logic (#1092) et
        ; fn_spike_logic (#10CE) -- role exact des bits 5/7 non confirme
        ; (hypothese: marqueur "entite decorative calibree/reglee"), mais la
        ; structure et les 3 appelants sont confirmes par desassemblage direct.
        ld    a,(ix+off_state_flags_2)
        or    #A0
        ld    (ix+off_state_flags_2),a
        ret
fn_bouncing_ball_logic:
        ; Logique des types d'entité 0xB2/0xB3 (balle rebondissante) — oscille
        ; verticalement entre deux bornes (haute = grid_z_initial+0x20, basse =
        ; grid_z_initial, via var_room_reset_flag_3 0x0083), déplacement appliqué
        ; par RST 10, joue un son de rebond à chaque changement de sens
        ; (fn_sound_arm_channel_0, séquence 0x09AC). "la balle rebondit en
        ; continu, son contact fait perdre une vie". Prototype de la catégorie
        ; "mouvement régulier/mécanique".
        call    #1D9E
        ld    a,(var_room_reset_flag_3)
        and    a
        jr    nz,loc_1159
        ld    a,(ix+off_grid_z_or_offset)
        add    a,#20
        ld    (var_room_reset_flag_3),a
loc_1159:
        call    fn_animation_cycle_4
        call    fn_position_pitch_sound_arm
        bit    2,(ix+off_state_flags_2)
        jr    nz,fn_bouncing_ball_logic_tail
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_1173
        set    2,(ix+off_state_flags_2)
        call    fn_sound_trigger_bounce
loc_1173:
        jr    loc_1139
fn_bouncing_ball_logic_tail:
        ; Cible de "jr nz,#1175" (#1163) dans fn_bouncing_ball_logic: LD
        ; (ix+0B),3, RST 10 (chute plus ample), compare var_room_reset_flag_3
        ; (#0083) a off_grid_z_or_offset; si NC, JR #1173 (rejoint le CALL
        ; fn_sound_trigger_bounce/exit); sinon RES 2,(ix+off_state_flags_2) puis
        ; JR #1173 (meme cible, sans le son).
        ld    (ix+#0B),#03
        rst    #10
        ld    a,(var_room_reset_flag_3)
        cp    (ix+off_grid_z_or_offset)
        jr    nc,loc_1173
        res    2,(ix+off_state_flags_2)
        jr    loc_1173
fn_melkhior_room_spawn_check:
        ; Appelée chaque frame depuis fn_arm_room_transition_flag_and_wait, mais
        ; RET immédiat sauf cas précis: si la room courante est #88 (salle de
        ; Melkhior) ET le slot3 (#012B) est vide ET var_special_input_mode_1 est
        ; nul, copie un template fixe de 18 octets (#11A7: type #A0 = poltergeist
        ; au repos, position centrale [#80,#80,#80], bbox [5,5,#0C]) dans le slot3
        ; — spawn conditionnel d'un poltergeist dans la salle de Melkhior. Détail
        ; non expliqué: le champ room du template vaut #B4, pas #88 — piste
        ; ouverte, lien avec le sprite jamais confirmé visuellement 0x96/0x97 pas
        ; établi avec certitude
        ld    a,(var_player_room_number)
        cp    #88
        ret    nz
        ld    de,#012B
        ld    a,(de)
        and    a
        ret    nz
        ld    a,(var_special_input_mode_1)
        and    a
        ret    nz
        ld    hl,tbl_melkhior_spawn_template
        ld    bc,#0012
        push    de
        pop    ix
        ldir
        jp    #1D84
tbl_melkhior_spawn_template:
        ; Template fixe de 18 octets copie par fn_melkhior_room_spawn_check
        ; (#1188, LDIR depuis cette adresse) dans le slot3 -- type=#A0
        ; (poltergeist au repos), grid=[#80,#80,#80], bbox=[5,5,#0C], flags=#10,
        ; room=#B4 (anomalie deja notee: pas #88), puis 4 octets a 0,
        ; type_mirror_plus_10=#A0, 4 octets a 0. Deja decrit en prose dans le
        ; commentaire existant de fn_melkhior_room_spawn_check -- adresse et
        ; extent desormais formalisees.
        defb #A0,#80,#80,#80,#05,#05,#0C,#10,#B4,#00,#00,#00,#00,#A0,#00,#00
        defb #00,#00
fn_poltergeist_logic:
        ; Logique par-frame du type d'entite #A0 (poltergeist, voir
        ; tbl_melkhior_spawn_template #11A7), placee juste apres son template de
        ; spawn -- meme convention de colocation que les autres paires
        ; spawn/logique du fichier. CALL #1D84 (calibration), teste (#010F, slot
        ; d'entite 2): si occupe, JP NZ vers la queue de
        ; fn_pusher_enemy_logic_tail (#1239, partage le meme code de
        ; transformation de fin de vecteur); sinon SET 1,(ix+off_flags), RST 10
        ; (application vecteur), CALL fn_animation_cycle_4_tail, compare
        ; off_grid_z_or_offset a #A0 pour choisir (ix+0B)=1 ou 2, teste un seuil
        ; derive de (#00D7) et la phase d'animation (ix+00)&3 pour eventuellement
        ; CALL #1B14 (hors-perimetre) et recombiner le type via OR #A8, sinon
        ; branche vers fn_poltergeist_logic_branch_a (#11F6) ou
        ; fn_poltergeist_logic_branch_b (#1200).
        call    #1D84
        ld    a,(#010F)
        and    a
        jp    nz,loc_1239
        set    1,(ix+off_flags)
        rst    #10
        call    fn_animation_cycle_4_tail
        ld    a,(ix+off_grid_z_or_offset)
        cp    #A0
        ld    (ix+#0B),#02
        jr    c,loc_11F3
        ld    (ix+#0B),#01
        ld    a,(struct_entities_base)
        sub    #30
        cp    #10
        jr    c,fn_poltergeist_logic_branch_a
        ld    a,(ix+off_type)
        and    #03
        jr    nz,loc_11F3
        call    fn_pickup_sequence_lookup
        ld    a,(hl)
        or    #A8
        ld    (ix+off_type),a
loc_11F3:
        jp    #1F7B
fn_poltergeist_logic_branch_a:
        ; Cible de "jr c,#11F6" dans fn_poltergeist_logic (#11E1): SET
        ; 2,(ix+off_type), RES 1,(ix+off_flags), puis JR #11F3 (rejoint le JP
        ; #1F7B de fn_poltergeist_logic).
        set    2,(ix+off_type)
        res    1,(ix+off_flags)
        jr    loc_11F3
fn_poltergeist_logic_branch_b:
        ; Bloc final de fn_poltergeist_logic (apres RES 1,(ix+off_flags)/JR #11FE
        ; de fn_poltergeist_logic_branch_a): CALL #1D84 (recalibration), LD
        ; (ix+off_type),#A0 (retour a l'etat de repos), JR #11F3 -- remet le
        ; poltergeist a son type de base.
        call    #1D84
        ld    (ix+off_type),#A0
        jr    loc_11F3
fn_pusher_enemy_logic:
        ; Logique des types d'entité 0xA4-0xA7 (ennemi "poussoir", inoffensif) —
        ; calcule un vecteur unitaire vers la position du joueur en cache
        ; ((0x00D8)/(0x00D9), fn_vector_toward_player 0x1240) et s'y déplace via
        ; RST 10. "attiré par le joueur pour le pousser, son contact n'est pas
        ; dangereux". Partage le pointeur de sprite 0x518B avec le type 0x85 de
        ; fn_hostile_patrol_logic (0x0E4A, jusqu'ici jamais identifié
        ; visuellement) — même famille visuelle, logiques de comportement
        ; différentes (poussoir vs agressif/mortel). États voisins: 0xA0-0xA3
        ; (logique 0x11B9, "repos"), 0xA8-0xAF. MAJEURE: ces 8 types pointent,
        ; dans tbl_sprite_dispatch, EXACTEMENT vers les 8 sprites du catalogue
        ; d'objets, DANS L'ORDRE — 0xA8=rubis (#4687), 0xA9=poison (#4600),
        ; 0xAA=botte (#446B), 0xAB=calice (#4702), 0xAC=tasse (#4795),
        ; 0xAD=bouteille (#456D), 0xAE=boule de cristal (#44EC), 0xAF=vie bonus
        ; (#4424). CE N'EST PAS UNE "TRANSITION" MAIS L'AFFICHAGE D'INDICE DU
        ; PUZZLE DE MELKHIOR: ce poltergeist (voir fn_melkhior_room_spawn_check
        ; #1188) affiche brièvement le sprite de l'objet à déposer ensuite dans le
        ; chaudron, avant que le handler 0x1200 (calibration + force retour à
        ; (ix+00)=0xA0) ne le remette à l'état de repos — CONFIRMÉ EMPIRIQUEMENT
        ; ("le poltergeist indique quel objet déposer ensuite" quand on entre en
        ; salle 0x88 en forme explorateur). Ceci relie très probablement ce
        ; mécanisme au puzzle de collecte en ordre déjà documenté
        ; (fn_treasure_settle_and_sequence_check #1A93, tbl_pickup_sequence_order
        ; #1B1D) — le dépôt d'un objet dans le chaudron de Melkhior est
        ; vraisemblablement le déclencheur (jusqu'ici non localisé) qui crée une
        ; entité de la famille 0x68-0x6E "jamais rencontrée en jeu" — À VÉRIFIER.
        call    #1D84
        ld    a,(ix+off_room_number)
        cp    #88
        jr    z,fn_pusher_enemy_logic_tail
        ld    a,(#00DE)
        bit    0,a
        jr    z,fn_pusher_enemy_logic_tail
        ld    bc,#0101
        jr    loc_1222
fn_pusher_enemy_logic_tail:
        ; Cible de "jr nz,#121F"/"jr z,#121F" (#1211/#1218) dans
        ; fn_pusher_enemy_logic: LD BC,#0404 (vecteur plus large que le cas #121A
        ; ld bc,#0101), CALL fn_vector_toward_player (#1240), RST 10, CALL
        ; fn_animation_cycle_4 (via #1267, queue de fn_animation_cycle_4 --
        ; confirme que ce sous-bloc EST partage), teste room_number==#88 (salle de
        ; Melkhior) et un seuil sur var_newgame_random_seed-derive (0x00D7) pour
        ; forcer (ix+off_type)=1 (transformation ?), puis JP #1AD2 (non identifiee
        ; dans ce fichier, hors-perimetre).
        ld    bc,#0404
loc_1222:
        call    fn_vector_toward_player
        rst    #10
        call    fn_animation_cycle_4_tail
        ld    a,(ix+off_room_number)
        cp    #88
        jr    nz,loc_123D
        ld    a,(struct_entities_base)
        sub    #10
        cp    #40
        jr    c,loc_123D
loc_1239:
        ld    (ix+off_type),#01
loc_123D:
        jp    #1AD2
fn_vector_toward_player:
        ; Calcule un vecteur unitaire (±1 par axe) vers la position du joueur en
        ; cache (0x00D8)/(0x00D9) — même paire de variables utilisée par
        ; fn_player_proximity_death (0x0EA0), confirmant qu'il s'agit d'une
        ; primitive de position joueur globale, recalculée une fois par frame et
        ; consultée par plusieurs types d'entités.
        ld    hl,#00D8
        ld    a,(ix+off_grid_x)
        sub    (hl)
        inc    hl
        ld    a,c
        jp    m,loc_124E
        neg
loc_124E:
        ld    (ix+#09),a
        ld    a,(ix+off_grid_y)
        sub    (hl)
        inc    hl
        ld    a,b
        jp    m,loc_125C
        neg
loc_125C:
        ld    (ix+#0A),a
        ret
fn_animation_cycle_4:
        ; Pattern générique: nouveau type = (type & 0xFC) \| ((type+1) & 0x03) —
        ; cycle d'animation à 4 phases encodées dans les 2 bits bas du type.
        ; Potentiellement réutilisé par d'autres entités animées
        ld    a,(ix+off_type)
        xor    #01
        jr    loc_1273
fn_animation_cycle_4_tail:
        ; Cible de "jr #1273" (#1265) dans fn_animation_cycle_4: calcule et stocke
        ; (ix+off_type)=(type&0xFC)|((type+1)&3) -- la combinaison finale du cycle
        ; 4 phases -- puis RET. Egalement atteint directement via CALL #1267
        ; depuis fn_pusher_enemy_logic_tail (#1226).
        ld    a,(ix+off_type)
        ld    c,a
        and    #FC
        ld    b,a
        ld    a,c
        inc    a
        and    #03
        or    b
loc_1273:
        ld    (ix+off_type),a
        ret
fn_cauldron_logic:
        jp    #1DB2
fn_cauldron_icon_logic:
        ; Desassemblage direct confirme l'adresse exacte. #0CE8 tombe dans la zone
        ; des programmes sonores (voisine de #0C36-#0C55 deja documentes) --
        ; hypothese: selectionne/prepare l'icone affichee (crane='poison' observe)
        ; via un mecanisme encore non identifie, PAS confirme.
        ld    hl,#0CE8
        jp    #1FEB
fn_guard_patrol_logic:
        ; Logique du type d'entité 0x1E (gardien en patrouille) — résout un
        ; vecteur de déplacement (±2 sur un axe) selon une direction 0-3 stockée
        ; dans (ix+0D)&3 via fn_resolve_patrol_vector (0x12A5), l'applique via RST
        ; 10, appelle fn_guard_walk_animation_toggle (0x1055), puis sauvegarde
        ; position dans pending_grid_x/y (+1D/+1E, mêmes champs que
        ; fn_room_transition). Le gardien change de direction 4 fois par ronde
        ; complète. ET CONFIRMÉ AU MAXIMUM: le changement de direction est bien
        ; déclenché PAR COLLISION (bit 0/1 de (ix+0C)) — confirmé par
        ; désassemblage + test empirique isolé (table contre un mur) + test
        ; empirique combiné (impact gardien/table synchronisé, table poussée d'un
        ; cran à chaque demi-tour du gardien).
        call    #1DBC
        rst    #10
        call    fn_resolve_patrol_vector
        ld    (ix+#09),l
        ld    (ix+#25),l
        ld    (ix+#0A),h
        ld    (ix+#26),h
        ld    a,(ix+off_grid_x)
        ld    (ix+off_pending_grid_x),a
        ld    a,(ix+off_grid_y)
        ld    (ix+off_pending_grid_y),a
        call    fn_guard_walk_animation_toggle
        jp    loc_1139
fn_resolve_patrol_vector:
        ; RST 28 dispatch (table 0x12B1, 4 entrées) sur direction (ix+0D)&3 ->
        ; vecteur fixe (±2,0) ou (0,±2) selon l'axe. Chaque entrée teste AUSSI un
        ; bit de collision sur (ix+0C) (bit 0 pour les directions 0/2, bit 1 pour
        ; les directions 1/3) — si le bit est posé (collision détectée sur cet
        ; axe), incrémente la direction de 1 (mod 4) AVANT de résoudre le vecteur;
        ; sinon continue tout droit. C'est LE mécanisme "le gardien tourne après
        ; une collision" décrit.
        ld    bc,tbl_guard_patrol_vector_dispatch
        ld    a,(ix+off_state_flags_2)
        and    #03
        ld    l,a
        jp    rst_dispatch_table
tbl_guard_patrol_vector_dispatch:
        ; 4 pointeurs word (index = code d'orientation 0-3, bits0-1 de
        ; off_state_flags_2), vers fn_guard_patrol_vector_o0..o3 -- meme motif RST
        ; 28 (rst_dispatch_table #0028) que tbl_player_forward_vector_dispatch
        ; (#22E4, asm/code/doors_and_player_logic.asm), utilise par
        ; fn_resolve_patrol_vector (#12A5). Resout le vecteur de patrouille par
        ; defaut ET, sur collision, le vecteur de demi-tour + la rotation de
        ; state_flags_2.
        defw #12B9
        defw #12D4
        defw #12E1
        defw #12EE
fn_guard_patrol_vector_o0:
        ; Entree 0 de tbl_guard_patrol_vector_dispatch : vecteur fixe (+2,0) ou
        ; (0,+2) selon l'axe associe a cette orientation.
        ld    hl,#00FE
        bit    0,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#0200
loc_12C4:
        ld    a,(ix+off_state_flags_2)
        ld    c,a
        inc    a
        and    #03
        ld    b,a
        ld    a,c
        and    #FC
        or    b
        ld    (ix+off_state_flags_2),a
        ret
fn_guard_patrol_vector_o1:
        ; Entree 1 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#0200
        bit    1,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#0002
        jr    loc_12C4
fn_guard_patrol_vector_o2:
        ; Entree 2 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#0002
        bit    0,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#FE00
        jr    loc_12C4
fn_guard_patrol_vector_o3:
        ; Entree 3 de tbl_guard_patrol_vector_dispatch : vecteur fixe pour cette
        ; orientation.
        ld    hl,#FE00
        bit    1,(ix+off_cooldown_or_collision_flags)
        ret    z
        ld    hl,#00FE
        jr    loc_12C4
fn_game_over_or_daycycle_end:
        ; Point de sortie commun atteint par 2 chemins: jour 40 (var_day_counter)
        ; ET var_life_counter négatif (0x29CA, ex-"var_room_countdown"). Écran de
        ; fin de partie
        ld    a,(var_special_input_mode_1)
        and    a
        jp    nz,fn_game_over_screen_sequence
loc_1302:
        call    fn_clear_intermediate_buffer
        call    fn_clear_screen
        ld    de,#1431
        exx
        ld    hl,#1437
        ld    de,#1443
        ld    b,#06
        call    #176B
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    de,var_pickup_sequence_counter
        ld    a,(de)
        sub    #0A
        jr    c,loc_132A
        or    #10
        ld    (de),a
loc_132A:
        ld    hl,#A3EE
        ld    b,#01
        call    fn_hud_render_bcd_digits
        ld    hl,#AFDE
        ld    de,var_day_counter
        ld    b,#01
        call    fn_hud_render_bcd_digits
        call    fn_pickup_progress_display_calc
        ld    a,(#008B)
        rlca
        and    #C0
        ld    c,a
        ld    a,(var_special_input_mode_1)
        and    #01
        or    c
        rlca
        rlca
        rlca
        and    #0E
        ld    l,a
        ld    h,#00
        ld    bc,tbl_game_over_screen_message_ptrs
        add    hl,bc
        ld    e,(hl)
        inc    hl
        ld    d,(hl)
        ld    hl,#2758
        call    fn_menu_draw_string_de_attribute
        call    fn_game_over_border_draw
        call    fn_copy_screen_rect
loc_1368:
        xor    a
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        jr    nz,loc_1368
        ld    hl,tbl_sound_program_ptrs_gameover
        call    fn_sound_program_play_blocking
        call    fn_wait_input_release_with_timeout
        jp    fn_restart_from_menu
fn_wait_input_release_with_timeout:
        ; Boucle avec compteur HL=#2000 decroissant, appelle
        ; fn_read_joystick_table (HL=tbl_wait_any_key_all_rows) a chaque iteration
        ; et sort par RET NZ si une touche/direction est active, sinon decremente
        ; HL et boucle jusqu'a expiration. Utilisee aussi comme entree alternative
        ; directe via un jump qui saute cette attente.
        ld    hl,#2000
loc_1380:
        push    hl
        ld    hl,tbl_wait_any_key_all_rows
        call    fn_read_joystick_table
        pop    hl
        ret    nz
        dec    hl
        ld    a,h
        or    l
        jr    nz,loc_1380
        ret
fn_game_over_screen_sequence:
        ; Corps principal de l'ecran de fin de partie/bilan de journee (suite de
        ; fn_game_over_or_daycycle_end): efface le buffer intermediaire et l'ecran
        ; (fn_clear_intermediate_buffer/fn_clear_screen), CALL #2B3B, prepare 3
        ; paires de pointeurs (DE=#13B7 via echange EXX, HL=#13BD, DE=#13C9 --
        ; voir tbl_game_over_screen_strings_a) et B=6, CALL #176B (hors-perimetre,
        ; non desassemble ici), remet a #FF deux compteurs d'animation
        ; (#172C/#173C), met a jour var_pickup_sequence_counter (#0081, plafonne a
        ; 9 puis pose bit4), affiche 2 compteurs BCD via fn_hud_render_bcd_digits
        ; (#1571: var_pickup_sequence_counter puis var_day_counter), CALL
        ; fn_pickup_progress_display_calc (#14F5), calcule un index 0-14 combinant
        ; (008B)/var_special_input_mode_1 pour choisir un pointeur dans
        ; tbl_game_over_screen_message_ptrs (#149C), affiche le message choisi via
        ; fn_menu_draw_string_reset_font (#16EA, HL=#2758), CALL #2B3B,
        ; fn_copy_screen_rect, boucle d'attente input (fn_read_joystick_table),
        ; joue le jingle de fin (#0C49, fn_sound_program_play_blocking), rappelle
        ; fn_wait_input_release_with_timeout (#137D) puis JP fn_restart_from_menu.
        call    fn_clear_intermediate_buffer
        call    fn_clear_screen
        call    fn_game_over_border_draw
        ld    de,tbl_game_over_screen_strings_a
        exx
        ld    hl,#13BD
        ld    de,#13C9
        ld    b,#06
        xor    a
        ld    (#007E),a
        call    #176B
        ld    hl,tbl_sound_program_ptrs_unused_b
        call    fn_sound_program_channel_setup
        call    fn_wait_input_release_with_timeout
        jp    loc_1302
tbl_game_over_screen_strings_a:
        ; [hypothesis] Bloc de donnees encodees (PAS du code -- desassemblage
        ; lineaire y produit des instructions absurdes/incoherentes, signal
        ; classique de donnees, cf. DE=#13B7, HL=#13BD, DE=#13C9, ces 3 adresses
        ; tombent bien a l'interieur de ce bloc). Structure CONFIRMEE: suite de
        ; segments termines par un octet >=0x80 (meme convention que
        ; fn_menu_draw_string "terminateur bit7"), valeurs de contenu
        ; majoritairement dans 0x0A-0x26 (indices de glyphes, PAS de l'ASCII brut)
        ; avec l'octet 0x26 tres frequent (probable separateur/espace) et quelques
        ; runs de 0x0F/0xFF/0xF0 (probables separateurs visuels entre messages,
        ; pas du texte). HYPOTHESE (non decodee caractere par caractere, aucune
        ; table glyphe->caractere confirmee dans ce projet): messages de l'ecran
        ; de fin de partie/bilan de journee (rendus via
        ; fn_menu_draw_string_reset_font #16DA avec tbl_menu_font #3294, asm).
        ; Extent CONFIRMEE par adjacence: se termine exactement ou commence
        ; tbl_game_over_screen_message_ptrs (#149C).
        defb #0F,#0F,#F0,#F0,#FF,#FF,#40,#87,#40,#77,#30,#67,#30,#57,#50,#47
        defb #30,#37,#1D,#11,#0E,#26,#19,#18,#1D,#12,#18,#17,#26,#0C,#0A,#1C
        defb #1D,#9C,#12,#1D,#1C,#26,#16,#0A,#10,#12,#0C,#26,#1C,#1D,#1B,#18
        defb #17,#90,#0A,#15,#15,#26,#0E,#1F,#12,#15,#26,#16,#1E,#1C,#1D,#26
        defb #0B,#0E,#20,#0A,#1B,#8E,#1D,#11,#0E,#26,#1C,#19,#0E,#15,#15,#26
        defb #11,#0A,#1C,#26,#0B,#1B,#18,#14,#0E,#97,#22,#18,#1E,#26,#0A,#1B
        defb #0E,#26,#0F,#1B,#0E,#8E,#10,#18,#26,#0F,#18,#1B,#1D,#11,#26,#1D
        defb #18,#26,#16,#12,#1B,#0E,#16,#0A,#1B,#8E,#0F,#FF,#FF,#FF,#FF,#0F
        defb #58,#9F,#50,#7F,#30,#6F,#40,#5F,#30,#4F,#48,#37,#10,#0A,#16,#0E
        defb #26,#26,#18,#1F,#0E,#9B,#1D,#12,#16,#0E,#26,#26,#26,#26,#0D,#0A
        defb #22,#9C,#19,#0E,#1B,#0C,#0E,#17,#1D,#0A,#10,#0E,#26,#18,#0F,#26
        defb #1A,#1E,#0E,#1C,#9D,#0C,#18,#16,#19,#15,#0E,#1D,#0E,#0D,#26,#26
        defb #26,#26,#26,#A7,#0C,#11,#0A,#1B,#16,#1C,#26,#0C,#18,#15,#15,#0E
        defb #0C,#1D,#0E,#0D,#26,#26,#A6,#18,#1F,#0E,#1B,#0A,#15,#15,#26,#1B
        defb #0A,#1D,#12,#17,#90
tbl_game_over_screen_message_ptrs:
        ; Index 0-14 pair calcule par fn_game_over_screen_sequence a partir de
        ; var_special_input_mode_1 et d'un compteur. Les 8 valeurs tombent
        ; exactement sur les frontieres de segment (terminateur bit7) de
        ; tbl_game_over_screen_strings_b.
        defw #14AC
        defw #14B4
        defw #14BD
        defw #14C5
        defw #14CD
        defw #14D7
        defw #14E2
        defw #14EA
tbl_game_over_screen_strings_b:
        ; [hypothesis] 8 messages encodes (meme encodage/convention que
        ; tbl_game_over_screen_strings_a), pointes individuellement par les 8
        ; entrees de tbl_game_over_screen_message_ptrs (#149C) -- selection
        ; confirmee par calcul (voir cette table). Segmentation bit7 CONFIRMEE en
        ; exactement 8 segments correspondant aux 8 pointeurs. Semantique (quel
        ; message precis) NON decodee -- hypothese seulement: variantes du message
        ; de fin de partie/bilan selon (008B) (jour/nuit ?) et
        ; var_special_input_mode_1 (mode de controle ?).
        defb #0F,#26,#26,#26,#19,#18,#18,#9B,#0F,#26,#0A,#1F,#0E,#1B,#0A,#10
        defb #8E,#0F,#26,#26,#26,#0F,#0A,#12,#9B,#0F,#26,#26,#26,#10,#18,#18
        defb #8D,#0F,#0E,#21,#0C,#0E,#15,#15,#0E,#17,#9D,#0F,#16,#0A,#1B,#1F
        defb #0E,#15,#15,#18,#1E,#9C,#0F,#26,#26,#26,#11,#0E,#1B,#98,#0F,#0A
        defb #0D,#1F,#0E,#17,#1D,#1E,#1B,#0E,#9B
fn_pickup_progress_display_calc:
        ; CALL cible de fn_game_over_screen_sequence. Compte les bits a 1 sur 32
        ; octets/256 bits a partir de (#00B7=var_room_visited_bitmap), combine ce
        ; compte avec var_pickup_sequence_counter (#0081, SLA puis ADD), puis
        ; calcule 2 octets BCD (via ADD HL,BC repete + ADC/DAA, BC=#A41A puis
        ; +#0028) ecrits a (#008F)/(#008E). HYPOTHESE sur le role exact (nom
        ; provisoire): tally de progression du puzzle de collecte affiche sur
        ; l'ecran de fin de partie -- structure de calcul confirmee par
        ; desassemblage direct, semantique non verifiee par test comportemental.
        ld    e,#00
        ld    bc,#0820
        ld    hl,var_room_visited_bitmap
loc_14FD:
        push    bc
        ld    a,(hl)
        inc    hl
loc_1500:
        rrca
        jr    nc,loc_1504
        inc    e
loc_1504:
        djnz    loc_1500
        pop    bc
        dec    c
        jr    nz,loc_14FD
        ld    a,e
        dec    a
        ld    (#008B),a
        ld    a,(var_pickup_sequence_counter)
        sla    a
        add    a,e
        ld    e,a
        ld    bc,#A41A
        ld    hl,fn_cold_boot_entry
        xor    a
loc_151D:
        add    hl,bc
        adc    a,#00
        daa
        dec    e
        jr    nz,loc_151D
        ld    bc,rst_dispatch_table
        add    hl,bc
        adc    a,#00
        daa
        ld    (#008F),a
        ld    a,#00
        adc    a,#00
        daa
        ld    (#008E),a
        ld    hl,#A7E6
        ld    de,#008E
        ld    b,#01
        ld    a,(de)
        and    a
        jr    z,fn_pickup_progress_display_calc_zero_case
        inc    b
        jp    loc_1583
fn_pickup_progress_display_calc_zero_case:
        ; Cible de "jr z,#1546" (#1540) dans fn_pickup_progress_display_calc: cas
        ; ou le compte de bits est nul -- INC HL / INC DE puis JP
        ; fn_hud_render_bcd_digits (#1571), sans passer par l'increment de
        ; compteur B fait dans le cas general.
        inc    hl
        inc    de
        jp    fn_hud_render_bcd_digits
fn_hud_render_day_counter:
        ; Arme (#172C)/(#173C)=#FF (compteurs d'animation, meme paire que
        ; fn_game_over_screen_sequence), DE=var_day_counter (#007F), B=1, HL=#91DE
        ; (position ecran), puis JP fn_hud_render_bcd_digits.
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    hl,#91DE
        ld    de,var_day_counter
        ld    b,#01
        jp    fn_hud_render_bcd_digits
fn_hud_render_secondary_counter:
        ; Meme structure que fn_hud_render_day_counter mais DE=#0080 (variable non
        ; nommee, valeur initialisee a 5 au boot d'apres fn_boot_init_and_new_game
        ; -- hypothese: compteur de vies) et HL=#99C8 (autre position ecran).
        ; Semantique de (#0080) non confirmee ici.
        ld    a,#FF
        ld    (#172C),a
        ld    (#173C),a
        ld    de,var_life_counter
        ld    b,#01
        ld    hl,#99C8
        jp    fn_hud_render_bcd_digits
fn_hud_render_bcd_digits:
        ; Helper partage: force (#008C)=tbl_menu_font (#3294), puis pour B
        ; iterations lit un octet a (DE), affiche son nibble haut PUIS son nibble
        ; bas via fn_menu_glyph_unpack (#170D) a la position HL courante
        ; (incrementee par le glyph-unpack lui-meme), avance DE. Rend un octet
        ; comme 2 chiffres/glyphes -- routine d'affichage BCD generique. Appelants
        ; CONFIRMES: fn_game_over_or_daycycle_end (#132F avec
        ; var_pickup_sequence_counter, #133A avec var_day_counter -- code deja
        ; existant dans ce fichier), fn_pickup_progress_display_calc_zero_case
        ; (#1546), fn_hud_render_day_counter (#154B),
        ; fn_hud_render_secondary_counter (#155E).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
        pop    hl
loc_1579:
        ld    a,(de)
        rrca
        rrca
        rrca
        rrca
        and    #0F
        call    fn_menu_glyph_unpack
loc_1583:
        ld    a,(de)
        and    #0F
        call    fn_menu_glyph_unpack
        inc    de
        djnz    loc_1579
        ret
fn_hud_render_minifont_message:
        ; Force (#008C)=tbl_hud_minifont_glyphs (#15A2, police locale dediee, PAS
        ; tbl_menu_font), DE=tbl_hud_minifont_message_text (#159D, chaine fixe de
        ; 5 octets), HL=#0F70 (position ecran), PUSH HL puis JP #16F1 (entre au
        ; milieu de la queue de rendu partagee fn_menu_draw_string_reset_font, en
        ; reutilisant la police deja posee au lieu de la reinitialiser a
        ; tbl_menu_font). Role exact du message affiche non confirme (chaine tres
        ; courte).
        ld    hl,tbl_hud_minifont_glyphs
        ld    (var_glyph_table_base),hl
        ld    de,tbl_hud_minifont_message_text
        ld    hl,#0F70
        push    hl
        jp    loc_16F1
tbl_hud_minifont_message_text:
        ; [hypothesis] Chaine fixe de 5 octets (#FF,#00,#01,#02,#83) terminee par
        ; un octet bit7 (#83, meme convention que tbl_game_over_screen_strings_a),
        ; source de fn_hud_render_minifont_message (#158D). Contenu tres court
        ; (2-3 glyphes utiles) -- hypothese: un statut/indicateur numerique court
        ; plutot qu'un vrai mot, semantique non confirmee.
        defb #FF,#00,#01,#02,#83
tbl_hud_minifont_glyphs:
        ; [hypothesis] 32 octets poses comme police locale (#008C) par
        ; fn_hud_render_minifont_message (#158D) -- distincte de tbl_menu_font
        ; (#3294). Contenu (07,06,06,06,0F,00,01,82,C6,64,6C,6D,C6,C8,C6,E1,60,60,
        ; E0,64,63,60,60,60,E0,60,40,C0,80,...) compatible avec un en-tete de
        ; dimensions (largeur/hauteur) suivi de lignes de bitmap (motifs
        ; 0x60/0xC0/0xE0 typiques de segments de trait), mais format exact et jeu
        ; de glyphes couverts NON confirmes (aucun mecanisme de rendu de police
        ; alternative documente ailleurs dans ce projet pour verifier le
        ; decoupage).
        defb #06,#07,#06,#06,#06,#06,#06,#0F,#00,#01,#82,#C6,#64,#6C,#6D,#C6
        defb #C8,#C6,#E1,#60,#60,#E0,#64,#63,#60,#60,#60,#E0,#60,#40,#C0,#80
fn_control_mode_menu:
        ; Efface buffer/ecran, remplit #167C-167E via
        ; fn_control_mode_menu_palette_indicator_update, configure le Gate Array
        ; (fn_gate_array_config_stream, HL=#0055), joue un jingle
        ; (fn_sound_program_play_blocking). Lit les lignes clavier 7 et 8 pour
        ; mettre a jour bit1 et bit3 de var_input_mode_flag (mode
        ; clavier/joystick). Boucle sur la lecture clavier ligne 4 (validation) et
        ; var_newgame_random_seed (pour l'animation) avant de relancer la boucle.
        xor    a
        ld    (#007E),a
        ld    hl,#167C
        ld    b,#03
loc_15CB:
        ld    (hl),#0F
        inc    hl
        djnz    loc_15CB
        call    fn_clear_intermediate_buffer
        call    fn_game_over_border_draw
        call    fn_control_mode_menu_palette_indicator_update
        ld    hl,tbl_ga_config_stream_boot
        call    fn_gate_array_config_stream
        call    #175F
        ld    hl,tbl_sound_program_ptrs_control_menu
        call    fn_sound_program_play_blocking
loc_15E8:
        ld    hl,tbl_ga_config_stream_boot
        call    fn_gate_array_config_stream
        call    #175F
        ld    a,#08
        call    fn_read_keyboard_line
        ld    e,a
        ld    a,(var_input_mode_flag)
        ld    (#006E),a
        bit    0,e
        jr    z,loc_1603
        res    1,a
loc_1603:
        bit    1,e
        jr    z,loc_1609
        or    #02
loc_1609:
        ld    (var_input_mode_flag),a
        ld    a,#07
        call    fn_read_keyboard_line
        ld    hl,#0096
        bit    1,a
        jr    z,fn_control_mode_menu_branch_a
        bit    0,(hl)
        jr    nz,loc_1626
        set    0,(hl)
        ld    a,(var_input_mode_flag)
        xor    #08
        ld    (var_input_mode_flag),a
loc_1626:
        ld    a,(var_input_mode_flag)
        ld    hl,#006E
        cp    (hl)
        jr    z,loc_1639
        xor    a
        ld    (#007E),a
        ld    hl,tbl_sound_program_ptrs_unused_c
        call    fn_sound_program_channel_setup
loc_1639:
        ld    a,#04
        call    fn_read_keyboard_line
        bit    0,a
        ret    nz
        ld    hl,var_newgame_random_seed
        inc    (hl)
        ld    a,(hl)
        and    #07
        jr    nz,loc_1654
        ld    hl,#005F
        ld    a,(hl)
        cp    #4B
        jr    nz,fn_control_mode_menu_branch_b
        ld    (hl),#55
loc_1654:
        call    fn_control_mode_menu_palette_indicator_update
        jp    loc_15E8
fn_control_mode_menu_branch_a:
        ; Cible de "jr z,#165A" (#1616) dans fn_control_mode_menu: RES 0,(HL)
        ; (HL=#0096) puis JR #1626 -- rejoint la comparaison (#006C) vs (#006E).
        res    0,(hl)
        jr    loc_1626
fn_control_mode_menu_branch_b:
        ; Cible de "jr nz,#165E" (#1650) dans fn_control_mode_menu: LD (HL),#4B
        ; (HL=#005F) puis JR #1654 -- rejoint le CALL
        ; fn_control_mode_menu_palette_indicator_update / JP #15E8.
        ld    (hl),#4B
        jr    loc_1654
fn_control_mode_menu_palette_indicator_update:
        ; CALL cible de fn_control_mode_menu (#15D6, #1654). Ecrit #0F (par
        ; defaut) puis, si bit3 de var_input_mode_flag (#006C) pose, #FF, dans
        ; l'octet a (#167C) -- octet qui se trouve au milieu de
        ; tbl_menu_or_status_data (#167B), voir cette entree pour la remarque sur
        ; ce chevauchement variable-mutable/donnee-statique. Appelle aussi #174F
        ; (hors-perimetre, corps de fn_menu_glyph_unpack #170D probablement).
        ld    hl,#167C
        ld    a,(var_input_mode_flag)
        rrca
        and    #01
        ld    b,#02
        call    #174F
        ld    (hl),#0F
        ld    a,(var_input_mode_flag)
        and    #08
        ret    z
        ld    (hl),#FF
        ret
tbl_menu_or_status_data:
        ; [hypothesis] Desassemblage lineaire incoherent (valeurs 0x0A-0x26
        ; dominantes, 0x26 frequent, segments termines par un octet >=0x80) --
        ; signature de donnees, pas de code. L'octet a #167C (2e octet du bloc)
        ; est aussi reutilise comme variable mutable par
        ; fn_control_mode_menu_palette_indicator_update (valeurs #0F/#FF).
        ; Hypothese sur le contenu : messages courts du menu, meme encodage que
        ; tbl_game_over_screen_strings_a. Extent confirmee par adjacence avec
        ; fn_menu_draw_string_reset_font.
        defb #F0,#FF,#0F,#0F,#0F,#0F,#58,#9F,#30,#87,#30,#77,#30,#5F,#30,#3F
        defb #50,#27,#14,#17,#12,#10,#11,#1D,#26,#15,#18,#1B,#8E,#01,#26,#14
        defb #0E,#22,#0B,#18,#0A,#1B,#8D,#02,#26,#13,#18,#22,#1C,#1D,#12,#0C
        defb #94,#03,#26,#0D,#12,#1B,#0E,#0C,#1D,#12,#18,#17,#0A,#15,#26,#0C
        defb #18,#17,#1D,#1B,#18,#95,#00,#26,#1C,#1D,#0A,#1B,#1D,#26,#10,#0A
        defb #16,#8E,#25,#26,#01,#09,#08,#04,#26,#0A,#24,#0C,#24,#10,#A4
fn_menu_draw_string_reset_font:
        ; Variante de fn_menu_draw_string (#16E5): force explicitement
        ; (#008C)=tbl_menu_font (#3294) et calcule l'adresse ecran via
        ; fn_buffer_addr_from_vram (#3186), PUIS tombe (fall-through, pas de saut)
        ; dans le corps propre de fn_menu_draw_string a #16E5 -- donc DE (pointeur
        ; chaine) doit deja etre pose par l'appelant, et l'octet d'attribut vient
        ; de (#007C) comme dans fn_menu_draw_string. Distinct de
        ; fn_menu_draw_string_de_attribute (#16EA), qui prend son octet d'attribut
        ; directement dans la chaine (DE) plutot que dans (#007C).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
        pop    hl
        call    fn_buffer_addr_from_vram
fn_menu_draw_string:
        ; Menu seulement: affiche une chaîne (terminateur bit7) via
        ; fn_menu_glyph_unpack
        ld    a,(#007C)
        jr    loc_16F7
fn_menu_draw_string_de_attribute:
        ; CALL cible CONFIRMEE, deja presente dans le code existant de
        ; fn_game_over_screen_sequence (#135F, "call #16EA") -- desassemblage
        ; direct resout cette citation. Variante de fn_menu_draw_string (#16E5):
        ; force (#008C)=tbl_menu_font (#3294), calcule l'adresse ecran
        ; (fn_buffer_addr_from_vram #3186), puis lit le PREMIER octet de la chaine
        ; (DE) comme octet d'attribut (stocke dans #172C/#173C, meme paire de
        ; compteurs d'animation que fn_hud_render_day_counter), avant de boucler
        ; sur les caracteres suivants (bit7 = terminateur, rendu via
        ; fn_menu_glyph_unpack #170D) -- rejoint le meme point de sortie que
        ; fn_menu_draw_string (#170A/#170D).
        push    hl
        ld    hl,tbl_menu_font
        ld    (var_glyph_table_base),hl
loc_16F1:
        pop    hl
        call    fn_buffer_addr_from_vram
        ld    a,(de)
        inc    de
loc_16F7:
        ld    (#172C),a
        ld    (#173C),a
loc_16FD:
        ld    a,(de)
        inc    de
        bit    7,a
        jr    nz,fn_menu_draw_string_de_attribute_last_char
        call    fn_menu_glyph_unpack
        jr    loc_16FD
fn_menu_draw_string_de_attribute_last_char:
        ; Cible de "jr nz,#1708" (#1701) dans fn_menu_draw_string_de_attribute:
        ; dernier caractere de la chaine (bit7 pose) -- AND #7F (masque le bit7)
        ; puis JP fn_menu_glyph_unpack (#170D), tail-call qui rend le dernier
        ; glyphe et retourne directement chez l'appelant original.
        and    #7F
        jp    fn_menu_glyph_unpack
