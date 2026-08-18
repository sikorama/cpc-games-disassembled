; ============================================================
; objects_and_rooms_setup.asm -- genere par tools/gen_asm.py, plage #1D27-#1FE2
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #1D27
fn_catalog_randomize_types:
        ; LE VRAI randomiseur d'objets à ramasser (piste ouverte depuis plusieurs
        ; sessions). Pour chacune des 32 entrées de tbl_object_catalog: réécrit le
        ; TYPE (+0) avec 0x60 \| ((R + (0x0068) + i) & 7) (i = index d'entrée,
        ; rotation continue, pas un nouveau tirage R par entrée), PUIS copie le
        ; template figé (+1..+4: grid_x/y/z/room) vers la copie de travail
        ; (+5..+8, celle lue par fn_instantiate_room_objects). Appelée UNE FOIS
        ; par partie, juste après fn_init_room_selection (séquence de restart
        ; 0x0599-0x05A5).
        ld    hl,tbl_object_catalog
        ld    a,(var_newgame_random_seed)
        ld    e,a
        ld    a,r
        add    a,e
        ld    e,a
loc_1D32:
        ld    a,e
        and    #07
        or    #60
        ld    (hl),a
        inc    hl
        inc    e
        push    de
        ex    de,hl
        ld    hl,#0004
        add    hl,de
        ex    de,hl
        ld    bc,#0004
        ldir
        ex    de,hl
        push    hl
        ld    bc,tbl_sprite_dispatch
        and    a
        sbc    hl,bc
        pop    hl
        pop    de
        jr    c,loc_1D32
        ret
fn_pushable_block_logic:
        ; (salle 0xBB): logique du type d'entité 0x3E — "bloc poussable".
        ; Réutilise la calibration de projection du bloc statique 0x1D8F (même
        ; sprite EXACT que le type 0x07, 0x59DB), applique le vecteur de
        ; déplacement (RST 10) après avoir appelé 0x22A5 (arrêt net dès la fin du
        ; contact — même mécanisme que fn_pushable_table_logic/0x54), arme un son
        ; dont la hauteur dépend de la position (fn_position_pitch_sound_arm
        ; 0x0A07) si un vecteur est en cours. Confirmé visuellement ("blocs", 2
        ; instances empilées — delta grid_z=+0x0C, exactement l'élévation "sur la
        ; table" déjà confirmée ailleurs).
        call    loc_1D8F
        call    #22A5
        rst    #10
        call    fn_pending_vector_zero_test
        jp    z,loc_1F7B
        call    fn_position_pitch_sound_arm
        jp    loc_1F7B
fn_sliding_chest_logic:
        ; Logique des types d'entité 0x54 (table) et 0x55 (coffre) — TOUTES DEUX
        ; appliquent le déplacement courant via RST 10 SANS résoudre elles-mêmes
        ; un vecteur (le vecteur est rempli par le moteur de collision GÉNÉRIQUE
        ; suite à un contact avec le joueur). DIFFÉRENCE CLÉ (confirmée
        ; empiriquement room 0x6C): 0x54 (table) appelle ENSUITE CALL 0x22A5 qui
        ; annule immédiatement le vecteur — la table s'arrête dès que le contact
        ; cesse. 0x55 (coffre) N'appelle PAS 0x22A5 — le vecteur persiste, le
        ; coffre CONTINUE à glisser après la poussée, exactement "ils glissent
        ; tout seuls quand on les pousse, à la différence des tables". Une seule
        ; instruction de différence explique tout le comportement observé.
        call    loc_1D8F
        rst    #10
        call    fn_pending_vector_zero_test
        ret    z
        jp    #1AD2
fn_pushable_table_logic:
        ; Logique des types d'entité 0x54 (table) et 0x55 (coffre) — TOUTES DEUX
        ; appliquent le déplacement courant via RST 10 SANS résoudre elles-mêmes
        ; un vecteur (le vecteur est rempli par le moteur de collision GÉNÉRIQUE
        ; suite à un contact avec le joueur). DIFFÉRENCE CLÉ (confirmée
        ; empiriquement room 0x6C): 0x54 (table) appelle ENSUITE CALL 0x22A5 qui
        ; annule immédiatement le vecteur — la table s'arrête dès que le contact
        ; cesse. 0x55 (coffre) N'appelle PAS 0x22A5 — le vecteur persiste, le
        ; coffre CONTINUE à glisser après la poussée, exactement "ils glissent
        ; tout seuls quand on les pousse, à la différence des tables". Une seule
        ; instruction de différence explique tout le comportement observé.
        call    loc_1D8F
        rst    #10
        call    fn_pending_vector_zero_test
        ret    z
        call    #22A5
        jp    #1AD2
fn_static_calib_vector_table:
        ; RESOUT le dernier type sans logique tracee de tbl_entity_logic_dispatch
        ; (audit complet 2026-08-14 des 188 entrees). 13 mini-routines
        ; consecutives de forme LD HL,nn / JR #1D8C (le tail commun, qui ecrit HL
        ; dans off_proj_offset_x/off_proj_offset_y via la meme queue que
        ; fn_door_post_type_A/B, #1FEB) -- exactement le meme mecanisme de
        ; calibration statique deja identifie pour les portes et les blocs. Type
        ; 0x80 (type_wall_segment) dispatche sur la toute PREMIERE entree (#1D7F
        ; elle-meme) ; les entrees suivantes (#1D84..#1DBC) sont reutilisees par
        ; d'autres dispatchs deja nommes ailleurs (blocs statiques 0x0A-0x0F,
        ; blocs poussables/table via #1D8F, etc.) OU par le HUD jour/nuit (voir
        ; #1DB2, meme table, 11e entree). Se termine juste avant fn_fill_rect
        ; (#1DC1).
        ld    hl,#FEF8
        jr    loc_1D8C
        ld    hl,#FCF4
        jr    loc_1D8C
loc_1D89:
        ld    hl,#FAF4
loc_1D8C:
        jp    #1FEB
loc_1D8F:
        ld    hl,#F8F0
        jr    loc_1D8C
        ld    hl,#FFEC
        jr    loc_1D8C
        ld    hl,#FEF4
        jr    loc_1D8C
        ld    hl,#FCF8
        jr    loc_1D8C
        ld    hl,#F8F4
        jr    loc_1D8C
        ld    hl,#F9F4
        jr    loc_1D8C
        ld    hl,#F4F4
        jr    loc_1D8C
        ld    hl,#F4F0
        jr    loc_1D8C
        ld    hl,#07F4
        jr    loc_1D8C
        ld    hl,#03F4
        jr    loc_1D8C
fn_fill_rect:
        ; Effacement/remplissage rectangulaire par loop unrolling
        push    af
        ld    a,b
        neg
        and    #0F
        add    a,a
        ld    (#1DD6),a
        ld    a,#40
        add    a,b
        neg
        ld    e,a
        ld    d,#FF
        ld    b,c
        pop    af
loc_1DD5:
        jr    loc_1DE9
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
loc_1DE9:
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        ld    (hl),a
        inc    hl
        add    hl,de
        djnz    loc_1DD5
        ret
fn_instantiate_room_objects:
        ; (était hypothesis): scanne tbl_object_catalog (32 entrées), instancie
        ; dans les slots d'entité 2 et 3 (0x010F/0x012B, juste après les 2
        ; templates joueur/compagnon) chaque entrée dont le champ room (+8, copie
        ; de travail) correspond à la salle courante. Au plus 2 objets par salle
        ; (place limitée entre 0x010F et 0x0147 = tbl_room_connections).
        ld    de,#010F
        exx
        ld    iy,tbl_object_catalog
        ld    b,(ix+off_room_number)
loc_1E06:
        ld    a,(iy+off_type)
        and    a
        jr    z,loc_1E48
        ld    a,(iy+off_room_number)
        cp    b
        jr    nz,loc_1E48
        push    iy
        exx
        pop    hl
        push    hl
        ld    a,(hl)
        inc    hl
        ld    (de),a
        inc    de
        inc    hl
        inc    hl
        inc    hl
        inc    hl
        ld    bc,#0003
        ldir
        ex    de,hl
        ld    (hl),#05
        inc    hl
        ld    (hl),#05
        inc    hl
        ld    (hl),#0C
        inc    hl
        ld    (hl),#14
        inc    hl
        ex    de,hl
        ld    a,(hl)
        inc    hl
        ld    (de),a
        inc    de
        ld    b,#07
        call    fn_zero_fill_de
        pop    bc
        ld    a,c
        ld    (de),a
        inc    de
        ld    a,b
        ld    (de),a
        inc    de
        ld    b,#0A
        call    fn_zero_fill_de
        exx
loc_1E48:
        ld    de,#0009
        add    iy,de
        push    iy
        pop    hl
        ld    de,tbl_sprite_dispatch
        and    a
        sbc    hl,de
        jr    c,loc_1E06
        exx
loc_1E59:
        ld    hl,tbl_room_connections
        and    a
        sbc    hl,de
        ret    z
        ld    b,#1C
        call    fn_zero_fill_de
        jr    loc_1E59
fn_object_catalog_writeback:
        ; Appelée depuis fn_init_room (#2A68) UNIQUEMENT si
        ; var_room_transition_flag (#0078) != 0 (donc jamais au tout premier
        ; lancement, seulement lors d'une transition/réinit de salle). Parcourt
        ; les slots d'entité 2 et 3 (#010F/#012B): si le type courant (iy+00) est
        ; dans [#60,#66] (famille pickup "boule de cristal", PAS #BB collecté ni
        ; #67 bonus vie), écrit en retour, via le pointeur (iy+10)/(iy+11) — qui
        ; pour CES slots contient l'adresse de LEUR PROPRE entrée dans
        ; tbl_object_catalog, posée par fn_instantiate_room_objects (#1DFB,
        ; #1E3B-#1E41) — le type courant (offset+0), puis grid_x/grid_y/grid_z
        ; courants (iy+1..3 → catalogue+5..7), puis le champ room (iy+08 →
        ; catalogue+8). Effet: si l'objet est TOUJOURS non ramassé au moment de
        ; quitter la salle, son état courant est resynchronisé dans la copie de
        ; travail du catalogue; s'il est déjà ramassé (type devenu #BB via
        ; fn_collision_effect), il est SAUTÉ — donc le catalogue garde le dernier
        ; état synchronisé AVANT ramassage, pas après. Conséquence testable non
        ; vérifiée en jeu: revisiter une salle après avoir ramassé un objet
        ; #60-#66 ferait probablement réapparaître l'objet (aucune écriture ne
        ; persiste l'état "ramassé" vers le catalogue) — hypothèse dérivée de ce
        ; désassemblage, pas encore confirmée empiriquement. Confirme au passage
        ; le double rôle de off_transform_step_counter (+0x10/+0x11): pour
        ; l'entité 0 (joueur), compteur de sous-étapes de transformation; pour les
        ; entités objets (slots 2/3), pointeur 16 bits vers leur propre entrée
        ; tbl_object_catalog. Voir include/entity_struct.equ.asm.
        ld    iy,#010F
loc_1E6B:
        ld    a,(iy+off_type)
        sub    #60
        cp    #07
        jr    nc,loc_1E90
        ld    e,(iy+off_transform_step_counter)
        ld    d,(iy+#11)
        ld    a,(iy+off_type)
        ld    (de),a
        inc    de
        inc    de
        inc    de
        inc    de
        inc    de
        push    iy
        pop    hl
        inc    hl
        ld    bc,#0003
        ldir
        ld    a,(iy+off_room_number)
        ld    (de),a
loc_1E90:
        ld    bc,#001C
        add    iy,bc
        push    iy
        pop    hl
        ld    bc,tbl_room_connections
        and    a
        sbc    hl,bc
        jr    c,loc_1E6B
        ret
fn_ghost_wander_logic:
        ; Logique des types d'entité 0x50-0x53 (fantôme) — déplacement ALÉATOIRE
        ; (PAS un rebond déterministe comme les autres entités mobiles): quand le
        ; vecteur (ix+09)/(ix+0A) est épuisé OU qu'une collision est détectée sur
        ; (ix+0C)&3, tire un NOUVEAU vecteur aléatoire, puis appelle
        ; fn_ghost_orientation_toggle. "un fantôme" avec déplacement erratique
        ; observé par poll RAM (changements de vecteur fréquents et
        ; imprévisibles). DU CYCLE JOUR/NUIT: aucune référence à (0x1CFA) ou
        ; (0x00D7) dans le code de la routine, ET comportement/cadence/apparence
        ; identiques observés sous forme jour (joueur type 0x12) et nuit (type
        ; 0x32). Complète la taxonomie des ennemis mobiles (3e catégorie:
        ; "déplacement aléatoire").
        call    loc_1D89
        rst    #10
        ld    a,(ix+#09)
        or    (ix+#0A)
        jr    z,loc_1EB4
        ld    a,(ix+off_cooldown_or_collision_flags)
        and    #03
        jr    z,loc_1ED4
loc_1EB4:
        ld    a,(var_pseudo_random_acc)
        and    #03
        add    a,#04
        call    fn_signed_step_lookup
        ld    (ix+#09),a
        ld    a,(var_frame_counter)
        and    #03
        add    a,#04
        call    fn_signed_step_lookup
        ld    (ix+#0A),a
        call    fn_ghost_orientation_toggle
        call    fn_position_pitch_sound_arm
loc_1ED4:
        call    fn_animation_cycle_4
        jp    #1139
fn_ghost_orientation_toggle:
        ; Appelee par fn_ghost_wander_logic (#1ECE). Compare |vecteur X| et
        ; |vecteur Y| (ix+09/0A), prend l'axe dominant, et selon son signe bascule
        ; bit1 du type (0x50<->0x51 ou 0x52<->0x53) ET bit6 des flags
        ; (orientation, voir fn_get_orientation_code) -- oriente visuellement le
        ; fantome selon sa direction de deplacement aleatoire.
        ld    a,(ix+#09)
        and    a
        jp    p,loc_1EE3
        neg
loc_1EE3:
        ld    c,a
        ld    a,(ix+#0A)
        and    a
        jp    p,loc_1EED
        neg
loc_1EED:
        cp    c
        jr    nc,fn_ghost_orientation_toggle_y
        ld    a,(ix+#09)
        and    a
        jp    m,fn_ghost_orientation_toggle_negx
        res    1,(ix+off_type)
loc_1EFB:
        set    6,(ix+off_flags)
        ret
fn_ghost_orientation_toggle_negx:
        ; Branche axe X dominant et negatif de fn_ghost_orientation_toggle
        ; (#1EDA): SET bit1 du type, rejoint la queue commune (#1EFB, SET bit6 des
        ; flags).
        set    1,(ix+off_type)
        jr    loc_1EFB
fn_ghost_orientation_toggle_y:
        ; Branche axe Y dominant de fn_ghost_orientation_toggle (#1EDA): selon le
        ; signe, SET ou RES bit1 du type, rejoint la queue commune RES bit6 des
        ; flags (#1F11).
        ld    a,(ix+#0A)
        and    a
        jp    m,fn_ghost_orientation_toggle_negy
        set    1,(ix+off_type)
loc_1F11:
        res    6,(ix+off_flags)
        ret
fn_ghost_orientation_toggle_negy:
        ; Sous-branche negative de fn_ghost_orientation_toggle_y (#1F06): RES bit1
        ; du type, rejoint la queue RES bit6 des flags (#1F11).
        res    1,(ix+off_type)
        jr    loc_1F11
fn_signed_step_lookup:
        ; BC=tbl_signed_step_pairs (#1F25), HL=BC+A, retourne (HL) -- petit helper
        ; de lookup, utilise par fn_ghost_wander_logic pour convertir
        ; (pseudo_random_acc&3)+4 ou (frame_counter&3)+4 en une valeur signee via
        ; la table adjacente.
        ld    bc,tbl_signed_step_pairs
        ld    l,a
        ld    h,#00
        add    hl,bc
        ld    a,(hl)
        ret
tbl_signed_step_pairs:
        ; 8 paires de vecteurs signes (dx,dy), indexees par fn_signed_step_lookup
        ; pour un deplacement aleatoire (fantomes).
        defb #FF,#01,#FE,#02,#FD,#03,#FC,#04,#FB,#05,#FA,#06,#F9,#07,#F8,#08
fn_herse_type08_logic:
        ; RÉSOUT le type d'entité 0x08, qui partage le sprite de la herse 0x09
        ; mais dont la logique n'avait jamais été localisée avant. Calibration
        ; puis, si un flag de collision est posé, nettoie
        ; cooldown_or_collision_flags et arme un son (fn_sound_arm_channel_0).
        ; Puis piège à déclenchement pseudo-aléatoire (~3%/tick, même famille que
        ; fn_ceiling_spike_ball_logic) verrouillé par var_room_reset_flag_1 ("un
        ; seul à la fois", même rôle que var_room_reset_flag_4 pour les boules à
        ; pics): selon que l'entité est proche du sol ou nettement au-dessus,
        ; déclenche directement (fn_herse_type08_ground_trigger #1F96) ou accumule
        ; dans var_room_reset_flag_2 (comparé à 4) avant de tirer. Au succès: bit0
        ; du type posé, (ix+0B) = direction de "chute" (±1), bits4/5 des flags
        ; posés, verrou var_room_reset_flag_1 incrémenté, puis JP #25FF
        ; (mouvement/animation, hors zone). Fn_herse_trigger_other (#1F86) permet
        ; de déclencher cet effet sur une entité IY différente de l'entité
        ; courante.
        call    loc_1D89
        ld    a,(ix+off_cooldown_or_collision_flags)
        bit    2,a
        jr    z,loc_1F4A
        and    #F8
        ld    (ix+off_cooldown_or_collision_flags),a
        ld    hl,tbl_sound_descriptor_noise_decay
        call    fn_sound_arm_channel_0
loc_1F4A:
        ld    hl,var_room_reset_flag_1
        ld    a,(hl)
        and    a
        ret    nz
        ld    a,(var_room_data_field_2)
        cp    (ix+off_grid_z_or_offset)
        jr    z,fn_herse_type08_ground_trigger
        add    a,#1F
        cp    (ix+off_grid_z_or_offset)
        jr    nc,fn_herse_type08_ground_trigger
        ld    a,(var_room_reset_flag_2)
        cp    #04
        jr    c,loc_1F6E
        ld    a,(var_pseudo_random_acc)
        and    #1F
        ret    nz
        or    #80
loc_1F6E:
        inc    a
        ld    (var_room_reset_flag_2),a
        set    0,(ix+off_type)
        ld    (ix+#0B),#FF
loc_1F7A:
        inc    (hl)
loc_1F7B:
        ld    a,(ix+off_flags)
        or    #30
        ld    (ix+off_flags),a
        jp    fn_entity_fall_and_mark_overlap
fn_herse_trigger_other:
        ; Echange IX/IY (IY devient la cible), CALL #1F7B (queue commune de
        ; declenchement de chute de fn_herse_type08_logic), restaure IX/IY --
        ; permet a une autre routine de declencher l'effet de chute sur une ENTITE
        ; DIFFERENTE de celle courante (IY), sans dupliquer le code.
        push    iy
        push    ix
        push    iy
        pop    ix
        call    loc_1F7B
        pop    ix
        pop    iy
        ret
fn_herse_type08_ground_trigger:
        ; Branche 'pres du sol' de fn_herse_type08_logic (#1F35, atteinte via jr
        ; z/jr nc depuis #1F56/#1F5D): tire immediatement (1/32 via
        ; var_pseudo_random_acc&0x1F, sans passer par le compteur
        ; var_room_reset_flag_2); au succes, (ix+0B)=1 (chute vers le HAUT, signe
        ; oppose de la branche #1F6E qui utilise 0xFF) puis rejoint la queue
        ; commune #1F7A.
        ld    a,(var_pseudo_random_acc)
        and    #1F
        ret    nz
        set    0,(ix+off_type)
        ld    (ix+#0B),#01
        jr    loc_1F7A
fn_moving_grate_logic:
        ; Logique du type d'entité 0x09 (grille mobile qui monte/descend) —
        ; oscille via un compteur de phase (ix+0B) signé (positif/négatif),
        ; déplacement appliqué par RST 10 (rst_apply_movement_vector). Bornes de
        ; l'oscillation déterminées par (0x0074)+0x1F comparé à grid_z_or_offset
        ; (ix+03). "une grille au milieu qui monte et descend".
        call    loc_1D89
        set    7,(ix+off_state_flags_2)
        ld    a,(#00E3)
        and    #F0
        ret    nz
        ld    a,(ix+#0B)
        and    a
        jp    p,loc_1FCE
        dec    (ix+#0B)
        rst    #10
        bit    2,(ix+off_cooldown_or_collision_flags)
        jr    z,loc_1F7B
loc_1FC4:
        xor    a
        ld    (var_room_reset_flag_1),a
        res    0,(ix+off_type)
        jr    loc_1F7B
loc_1FCE:
        ld    (ix+#0B),#02
        call    fn_position_pitch_sound_arm
        rst    #10
        ld    a,(var_room_data_field_2)
        add    a,#1F
        cp    (ix+off_grid_z_or_offset)
        jr    nc,loc_1F7B
        jr    loc_1FC4
