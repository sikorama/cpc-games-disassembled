; ============================================================
; screen_addressing_and_tables.asm -- genere par tools/gen_asm.py, plage #3186-#4046
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #3186
fn_vram_addr_from_yx:
        ; EX-fn_buffer_addr_from_vram (nom d'origine trompeur : son entree
        ; n'est PAS une adresse VRAM mais un couple de coordonnees ecran
        ; H=screen_y / L=screen_x, et sa sortie etait
        ; #9000 + y*64 + x/4, soit un pointeur dans le BUFFER).
        ;
        ; [vram-direct 2026-08-19] Produit desormais l'adresse VRAM REELLE
        ; du meme point, en deleguant a fn_screen_addr_from_bc juste
        ; en-dessous. C'est la derniere ecriture vers #9000-#BFFF qui est
        ; ainsi supprimee : tout le chemin glyphes (texte de menu / game
        ; over, compteurs HUD, notification de slot) passait par ici.
        ;
        ; La correspondance est EXACTE, pas une approximation : la copie
        ; plein ecran d'origine appariait buffer #BFC0 avec VRAM #C008, et
        ; #BFC0 = #9000 + 191*64 + 0 soit (y=191, colonne 0) ; or
        ; fn_screen_addr_from_bc(B=191, C=0) donne bien #C008 (bande
        ; 191>>3 = 23, tbl_screen_line_base[23] = #0000, +8 de decalage de
        ; colonne). Le mapping buffer->VRAM du jeu EST donc
        ; fn_screen_addr_from_bc(y, colonne*4), decalage +8 inclus.
        ;
        ; IN  : H=screen_y, L=screen_x. OUT : HL=adresse VRAM.
        ; Preserve BC/DE. 4 nop pour conserver les 15 octets d'origine
        ; (fn_screen_addr_from_bc doit rester a #3195).
        push    bc
        push    de
        ld    b,h
        ld    c,l
        call    fn_screen_addr_from_bc
        ex    de,hl
        pop    de
        pop    bc
        ret
        nop
        nop
        nop
        nop
fn_screen_addr_from_bc:
        ; (B,C) -> adresse VRAM CPC complète (table de correspondance ligne +
        ; calcul colonne)
        push    hl
        ld    a,b
        rrca
        rrca
        and    #3E
        ld    hl,tbl_screen_line_base
        rst    #08
        ld    a,(hl)
        inc    hl
        ld    h,(hl)
        ld    l,a
        ld    a,b
        cpl
        rlca
        rlca
        rlca
        and    #38
        or    h
        or    #C0
        ld    h,a
        ld    a,c
        srl    a
        srl    a
        add    a,#08
        rst    #08
        ex    de,hl
        pop    hl
        ret
tbl_screen_line_base:
        ; 24 entrées word, base d'adresse écran par bande de 8 lignes (pas -0x50)
        defw #0730
        defw #06E0
        defw #0690
        defw #0640
        defw #05F0
        defw #05A0
        defw #0550
        defw #0500
        defw #04B0
        defw #0460
        defw #0410
        defw #03C0
        defw #0370
        defw #0320
        defw #02D0
        defw #0280
        defw #0230
        defw #01E0
        defw #0190
        defw #0140
        defw #00F0
        defw #00A0
        defw #0050
        defw #0000
fn_flip_sprite_shape:
        ; Bit7 = flip VERTICAL (echange de lignes entieres du bitmap) ; bit6 =
        ; flip HORIZONTAL reel (echange d'octets + fn_mirror_byte_bits par
        ; nibble). Si le bit teste differe de l'orientation courante (marqueur
        ; stocke dans l'octet0 de la forme), inverse ce bit ET mute le bitmap en
        ; place -- economie de memoire cle, une seule forme de base par sprite.
        push    de
        ld    a,(de)
        xor    (ix+off_flags)
        and    #80
        jr    z,loc_3220
        ld    a,(de)
        xor    #80
        ld    (de),a
        and    #3F
        ld    b,a
        inc    de
        ld    a,(de)
        ld    c,a
        inc    de
        inc    de
        push    de
        ld    e,b
        ld    d,#00
        call    fn_mul8x16
        pop    de
        add    hl,de
        ex    de,hl
        ld    a,b
        rst    #08
        dec    de
        dec    hl
        srl    c
loc_320E:
        push    bc
loc_320F:
        ld    a,(de)
        ld    c,(hl)
        ld    (hl),a
        ld    a,c
        ld    (de),a
        dec    hl
        dec    de
        djnz    loc_320F
        pop    bc
        ld    a,b
        sla    a
        rst    #08
        dec    c
        jr    nz,loc_320E
loc_3220:
        pop    de
        push    de
        ld    a,(de)
        xor    (ix+off_flags)
        and    #40
        jr    z,loc_3263
        ld    a,(de)
        xor    #40
        ld    (de),a
        inc    de
        and    #3F
        ld    (#3259),a
        ld    l,a
        ld    h,#00
        add    hl,de
        inc    hl
        inc    a
        srl    a
        ld    b,a
        ld    a,(de)
        inc    de
        inc    de
        ld    c,a
loc_3241:
        push    bc
        push    de
        push    hl
loc_3244:
        push    bc
        ld    a,(de)
        ld    b,a
        call    fn_mirror_byte_bits
        ld    b,(hl)
        ld    (hl),a
        ld    a,b
        call    fn_mirror_byte_bits
        ld    (de),a
        inc    de
        dec    hl
        pop    bc
        djnz    loc_3244
        pop    hl
        pop    de
        ld    bc,#0006
        add    hl,bc
        ex    de,hl
        add    hl,bc
        ex    de,hl
        pop    bc
        dec    c
        jr    nz,loc_3241
loc_3263:
        pop    de
        ret
fn_mirror_byte_bits:
        ; (etait en defb, jamais nommee malgre la mention 'fn_bit_rotate' dans la
        ; desc de fn_flip_sprite_shape qui l'appelle 2x, #3247/#324D): inverse
        ; l'ordre des 8 bits d'un octet (A/B en entree, A en sortie) par 4 paires
        ; rotate+AND+OR sur les nibbles (masques #11/#88 puis #22/#44) -- utilisee
        ; pour le flip HORIZONTAL des sprites (miroir bit a bit d'une ligne de
        ; pixels 1bpp). Verifie octet par octet contre la RAM live. Se termine
        ; juste avant la chaine ASCII 'COPYRIGHT 1984 A.C.G.' -- explique enfin
        ; les quelques octets de code qui la precedaient et n'avaient jamais ete
        ; rattaches a une routine nommee.
        rrca
        rrca
        rrca
        and    #11
        ld    c,a
        ld    a,b
        rlca
        rlca
        rlca
        and    #88
        or    c
        ld    c,a
        ld    a,b
        rrca
        and    #22
        or    c
        ld    c,a
        ld    a,b
        rlca
        and    #44
        or    c
        ret
str_copyright_notice:
        ; Chaine ASCII 'COPYRIGHT 1984 A.C.G.' (21 octets, pas de terminateur
        ; explicite -- tbl_menu_font suit immediatement a #3294). Deja identifiee
        ; via recherche de chaine en RAM (premiere identification du jeu), jamais
        ; donnee de symbole propre jusqu'ici.
        defb #43,#4F,#50,#59,#52,#49,#47,#48,#54,#20,#31,#39,#38,#34,#20,#41
        defb #2E,#43,#2E,#47,#2E
tbl_menu_font:
        ; Police de caractères 4bpp du menu (utilisée par fn_menu_glyph_unpack)
        defb #38,#6C,#D6,#D6,#D6,#D6,#6C,#38,#18,#38,#58,#18,#18,#18,#18,#7C
        defb #38,#4C,#0C,#3C,#60,#C2,#C2,#FE,#38,#4C,#0C,#3C,#0E,#86,#86,#FC
        defb #18,#38,#58,#9A,#FE,#1A,#18,#7C,#FE,#C2,#C0,#FC,#06,#06,#86,#7C
        defb #1E,#32,#60,#7C,#C6,#C6,#C6,#7C,#7E,#46,#4C,#0C,#18,#18,#30,#F8
        defb #38,#6C,#6C,#7C,#FE,#C6,#C6,#7C,#7C,#C6,#C6,#C6,#7C,#0C,#98,#F0
        defb #0C,#1C,#2E,#66,#46,#CE,#DB,#66,#F8,#6C,#6C,#78,#6C,#66,#66,#FC
        defb #0E,#32,#60,#40,#C0,#C2,#E6,#7C,#60,#70,#68,#6C,#66,#66,#66,#FC
        defb #FE,#60,#64,#7C,#64,#60,#7A,#C6,#C6,#7A,#60,#64,#7C,#64,#60,#60
        defb #0E,#30,#60,#C6,#CE,#F6,#66,#0E,#EE,#C6,#C6,#FE,#C6,#C6,#C6,#EE
        defb #7C,#18,#18,#18,#18,#18,#18,#7C,#1E,#06,#06,#86,#86,#C6,#7E,#1C
        defb #E4,#68,#70,#78,#6C,#64,#64,#F6,#E0,#60,#60,#60,#60,#60,#62,#FE
        defb #C6,#EE,#EE,#D6,#D6,#D6,#C6,#EE,#CC,#D6,#D6,#E6,#E4,#C4,#C8,#DE
        defb #38,#6C,#C6,#C6,#C6,#C6,#6C,#38,#F8,#6C,#66,#76,#6E,#60,#60,#F0
        defb #38,#6C,#C6,#C6,#C6,#D6,#6C,#3A,#F8,#6C,#66,#76,#7E,#78,#6C,#E6
        defb #38,#64,#60,#3C,#06,#86,#C6,#7C,#FE,#9A,#98,#18,#18,#18,#18,#18
        defb #F6,#26,#46,#4E,#CE,#D6,#D6,#66,#E2,#62,#64,#64,#68,#68,#70,#60
        defb #EE,#C6,#D6,#D6,#D6,#EE,#EE,#C6,#C6,#C6,#6C,#38,#38,#6C,#C6,#C6
        defb #86,#66,#16,#0E,#06,#04,#4C,#38,#7E,#46,#0C,#18,#30,#62,#C2,#FE
        defb #00,#00,#00,#00,#00,#18,#18,#00,#3C,#42,#99,#A1,#A1,#99,#42,#3C
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#62,#64,#08,#10,#26,#46,#00
tbl_room_master_coords:
        ; Selectionnees par field_byte>>3&0x1F (1er octet du payload de
        ; tbl_room_master_index) dans fn_load_room_data, copiees vers
        ; var_camera_reference/var_camera_reference_y (#0071/#0072) +
        ; var_room_data_field_2 (#0074). Entree 0 = (#40,#40,#80)
        ; defaut/symetrique ; entree 1 = (#20,#40,#80) ref. X divisee par 2,
        ; salles plus hautes que larges ; entree 2 = (#40,#20,#80) ref. Y divisee
        ; par 2, salles plus larges que hautes. Le 3e octet (#80, constant)
        ; correspond a grid_z_or_offset 'au sol'.
        defb #40,#40,#80,#20,#40,#80,#40,#20,#80
tbl_room_master_index:
        ; 128 entrées [room_id][skip_len][payload], couvre EXACTEMENT
        ; 0x33DD-0x3D5D sans reste. Longueur totale d'une entrée = 1+skip_len.
        ; Payload = field_byte puis liste d'octets. Chaque octet non-0xFF est un
        ; index DIRECT vers tbl_room_index_ptrs (0x3E6E) — chemin par défaut. Un
        ; octet 0xFF déclenche le chemin alternatif via tbl_room_connection_ptrs
        ; (0x3D5D). Vérifié empiriquement sur transition réelle 0x44→0x43, mais le
        ; champ exact de destination dans l'entrée résolue reste à identifier
        defb #00,#19,#03,#00,#01,#0C,#FF,#07,#10,#50,#90,#11,#51,#91,#0A,#4A
        defb #06,#8A,#02,#42,#82,#C8,#C1,#C0,#A8,#C9,#01,#14,#14,#01,#03,#0D
        defb #FF,#03,#2B,#2C,#13,#14,#23,#6B,#6C,#53,#54,#40,#1C,#48,#28,#02
        defb #06,#03,#00,#01,#03,#0C,#03,#1A,#16,#01,#03,#0D,#FF,#03,#22,#1A
        defb #25,#1D,#2B,#23,#1B,#24,#1C,#93,#2B,#2C,#13,#14,#B3,#63,#64,#5B
        defb #5C,#04,#13,#05,#00,#03,#0C,#FF,#2B,#23,#1A,#1C,#13,#B2,#5A,#5C
        defb #53,#02,#63,#9B,#DB,#08,#1A,#03,#04,#05,#0F,#10,#FF,#1B,#1B,#5B
        defb #9B,#DB,#2B,#23,#1A,#1C,#13,#93,#63,#5A,#5C,#53,#B8,#09,#80,#49
        defb #09,#0B,#06,#05,#07,#0F,#11,#09,#0B,#FF,#48,#23,#0A,#19,#03,#05
        defb #07,#0F,#11,#FF,#1D,#22,#62,#A2,#24,#64,#A4,#2F,#2A,#2B,#6B,#2C
        defb #1A,#1B,#5B,#1C,#38,#0E,#0B,#06,#06,#05,#07,#0F,#11,#0C,#17,#03
        defb #05,#07,#0F,#11,#FF,#2F,#3D,#32,#28,#2C,#2F,#22,#1C,#10,#2B,#12
        defb #17,#0D,#04,#B8,#24,#0D,#06,#04,#00,#01,#03,#0C,#0E,#0B,#15,#01
        defb #03,#0D,#FF,#53,#12,#1D,#2C,#23,#0F,#1C,#04,#00,#03,#0C,#FF,#07
        defb #23,#25,#13,#15,#63,#64,#65,#5B,#04,#5D,#53,#54,#55,#1C,#9B,#A4
        defb #9B,#9D,#94,#B0,#9C,#10,#18,#0D,#00,#15,#17,#0E,#FF,#01,#C3,#C4
        defb #5B,#05,#0C,#0B,#0A,#9B,#45,#4C,#4B,#4A,#A8,#C2,#50,#5A,#12,#18
        defb #0C,#00,#02,#0E,#FF,#97,#FA,#FD,#F3,#F4,#EB,#EC,#E3,#E4,#97,#DB
        defb #DC,#D3,#D4,#CB,#CC,#C2,#C5,#14,#1A,#0E,#00,#15,#17,#0E,#FF,#01
        defb #C3,#C4,#AD,#C2,#CA,#D2,#DA,#DB,#DC,#AC,#DD,#E5,#AD,#75,#3D,#29
        defb #0B,#0C,#18,#11,#0D,#00,#02,#0E,#FF,#2F,#2A,#2B,#2C,#2D,#12,#13
        defb #14,#15,#B8,#1B,#1D,#1B,#0E,#00,#15,#17,#0E,#FF,#07,#C3,#C4,#0C
        defb #4C,#8C,#CC,#24,#64,#02,#2C,#6C,#34,#29,#14,#1C,#58,#0C,#78,#54
        defb #1F,#17,#0B,#00,#02,#0E,#FF,#03,#12,#15,#2A,#2D,#2F,#52,#13,#14
        defb #55,#6A,#2B,#2C,#6D,#E1,#93,#6B,#20,#12,#03,#00,#01,#15,#17,#0C
        defb #FF,#02,#18,#C3,#C4,#AA,#50,#88,#C0,#28,#02,#21,#1C,#16,#14,#16
        defb #03,#0D,#FF,#07,#21,#61,#A2,#A3,#24,#64,#25,#65,#03,#26,#66,#E7
        defb #DF,#29,#A4,#A6,#30,#E2,#C0,#A5,#22,#1A,#03,#02,#03,#0C,#FF,#03
        defb #30,#78,#B9,#FA,#2F,#39,#3A,#3D,#3E,#3F,#33,#2B,#23,#2A,#34,#2C
        defb #24,#A8,#FB,#24,#18,#03,#00,#02,#0C,#FF,#2F,#02,#05,#0A,#0F,#10
        defb #15,#19,#1B,#2F,#1C,#1F,#28,#2A,#2C,#2E,#3A,#3D,#27,#0F,#06,#00
        defb #0C,#FF,#03,#1B,#1C,#23,#24,#4B,#12,#15,#2A,#2D,#28,#10,#0E,#00
        defb #15,#0E,#17,#FF,#39,#23,#63,#29,#0B,#0C,#01,#C3,#C4,#2D,#17,#04
        defb #14,#02,#16,#0C,#FF,#07,#DF,#E7,#13,#1B,#23,#5B,#63,#A3,#2B,#1E
        defb #26,#22,#24,#70,#E3,#2E,#11,#15,#01,#03,#0D,#FF,#2F,#2B,#2C,#22
        defb #25,#1A,#1D,#13,#14,#68,#23,#2F,#06,#04,#00,#02,#03,#0C,#30,#16
        defb #0D,#00,#02,#0E,#FF,#2F,#33,#34,#2A,#2D,#22,#25,#1A,#1D,#2B,#12
        defb #15,#0B,#0C,#B8,#1B,#34,#18,#0E,#00,#02,#0E,#FF,#3F,#1A,#1B,#1C
        defb #1D,#5A,#5B,#5C,#5D,#97,#9A,#9B,#9C,#9D,#DA,#DB,#DC,#DD,#37,#0D
        defb #0D,#00,#02,#0E,#FF,#78,#14,#00,#2C,#49,#25,#1A,#38,#19,#0B,#00
        defb #15,#17,#0E,#FF,#05,#7A,#F2,#DA,#C2,#C3,#C4,#B3,#EA,#E2,#D2,#CA
        defb #2C,#2A,#22,#1A,#12,#0A,#3F,#19,#03,#04,#06,#0F,#10,#FF,#1F,#18
        defb #19,#1A,#5A,#1D,#5D,#1E,#1F,#2D,#58,#59,#9A,#9D,#5E,#5F,#D0,#1B
        defb #40,#13,#06,#14,#15,#16,#17,#0C,#FF,#05,#3F,#06,#C3,#C4,#DF,#E7
        defb #68,#38,#80,#B8,#41,#17,#14,#01,#03,#0D,#FF,#05,#12,#14,#16,#2A
        defb #2C,#2E,#25,#52,#54,#56,#6A,#6C,#6E,#51,#15,#2B,#42,#15,#05,#01
        defb #03,#0C,#FF,#01,#1B,#DC,#A9,#63,#A4,#2F,#12,#1A,#22,#2B,#2C,#25
        defb #1D,#14,#43,#1B,#16,#01,#03,#0D,#FF,#07,#1E,#26,#5D,#65,#19,#21
        defb #5A,#62,#03,#2B,#2C,#13,#14,#2B,#6B,#6C,#53,#54,#60,#1B,#44,#07
        defb #04,#00,#01,#02,#03,#0C,#45,#1D,#05,#01,#03,#0C,#FF,#07,#23,#25
        defb #13,#15,#63,#64,#65,#5B,#03,#5D,#53,#54,#55,#9B,#A4,#9B,#9D,#94
        defb #B0,#9C,#28,#1C,#46,#1C,#16,#01,#03,#0D,#FF,#07,#23,#1B,#2C,#6C
        defb #14,#54,#25,#1D,#23,#65,#5D,#63,#5B,#91,#24,#1C,#B3,#A4,#E4,#9C
        defb #DC,#47,#06,#03,#00,#02,#03,#0C,#48,#17,#0E,#00,#15,#17,#0E,#FF
        defb #07,#C3,#C4,#CC,#2C,#2D,#25,#6C,#6D,#00,#AC,#29,#0B,#14,#78,#8C
        defb #4F,#15,#06,#04,#06,#0F,#10,#FF,#9F,#D8,#D9,#DA,#DB,#DC,#DD,#DE
        defb #DF,#9B,#C3,#C4,#FB,#FC,#54,#16,#0D,#00,#02,#0E,#FF,#01,#0C,#33
        defb #2B,#1A,#5A,#25,#65,#93,#13,#0B,#2C,#24,#79,#14,#23,#57,#14,#0D
        defb #00,#02,#0E,#FF,#07,#2D,#6D,#AD,#24,#64,#A4,#1B,#5B,#03,#9B,#12
        defb #52,#92,#58,#0B,#0D,#00,#15,#17,#0E,#FF,#48,#1D,#80,#5D,#5E,#12
        defb #06,#04,#05,#0F,#10,#FF,#1F,#32,#35,#29,#2E,#11,#16,#0A,#0D,#C8
        defb #2D,#5F,#06,#03,#04,#06,#07,#0F,#64,#12,#0E,#00,#15,#17,#0E,#FF
        defb #07,#03,#04,#0B,#0C,#23,#24,#2B,#2C,#30,#63,#67,#12,#0C,#00,#02
        defb #0E,#FF,#01,#2A,#2D,#2B,#6A,#6D,#1A,#1D,#D0,#2B,#68,#25,#68,#19
        defb #0B,#00,#02,#0E,#FF,#07,#3A,#7A,#BA,#FA,#3D,#7D,#BD,#FD,#03,#32
        defb #33,#34,#35,#29,#72,#75,#60,#A3,#6A,#05,#06,#00,#01,#0C,#6B,#11
        defb #14,#14,#03,#16,#0D,#FF,#05,#24,#1C,#64,#5C,#E7,#DF,#51,#D6,#ED
        defb #6C,#18,#13,#01,#03,#0D,#FF,#37,#2B,#23,#1B,#13,#6B,#63,#5B,#53
        defb #9F,#AB,#A3,#9B,#93,#EB,#E3,#DB,#D3,#6D,#17,#06,#05,#07,#0F,#11
        defb #FF,#1F,#14,#2C,#54,#6C,#94,#9C,#A4,#AC,#21,#D4,#EC,#38,#09,#40
        defb #1E,#6E,#07,#03,#05,#06,#07,#0F,#11,#6F,#14,#06,#06,#07,#0F,#11
        defb #FF,#1A,#2D,#2E,#2F,#22,#6D,#6E,#6F,#9B,#3D,#35,#7D,#75,#74,#18
        defb #04,#01,#02,#0C,#FF,#2A,#39,#30,#31,#07,#3A,#7A,#32,#72,#28,#68
        defb #29,#69,#B3,#B8,#B9,#B0,#B1,#75,#0E,#13,#01,#03,#0D,#FF,#01,#23
        defb #1C,#29,#24,#1B,#C8,#2B,#76,#16,#16,#14,#03,#16,#0D,#FF,#06,#DF
        defb #E7,#EF,#AE,#6D,#2C,#D7,#2D,#16,#1E,#26,#15,#1D,#25,#77,#07,#03
        defb #00,#01,#02,#03,#0C,#78,#19,#04,#00,#01,#02,#03,#0C,#FF,#2F,#39
        defb #3F,#35,#28,#2C,#2F,#23,#1D,#2C,#11,#13,#0A,#0D,#0E,#68,#17,#79
        defb #16,#13,#01,#03,#0D,#FF,#B3,#22,#1A,#25,#1D,#2F,#2B,#2C,#23,#24
        defb #1B,#1C,#13,#14,#60,#DB,#7A,#16,#05,#02,#03,#0C,#FF,#04,#28,#70
        defb #B8,#B9,#FF,#2D,#BA,#BC,#BE,#37,#2F,#27,#A9,#FB,#FD,#83,#05,#06
        defb #00,#01,#0C,#84,#17,#15,#01,#03,#0D,#FF,#07,#2A,#6A,#2D,#6D,#12
        defb #52,#15,#55,#23,#AA,#AD,#92,#95,#11,#1D,#9A,#85,#19,#14,#14,#03
        defb #16,#0D,#FF,#05,#28,#69,#AA,#EB,#E7,#DF,#2F,#1B,#23,#1C,#24,#1D
        defb #25,#1E,#26,#78,#DB,#86,#0B,#13,#14,#03,#16,#0D,#FF,#80,#63,#B8
        defb #23,#87,#18,#05,#00,#01,#02,#03,#0C,#FF,#03,#2A,#2D,#12,#15,#2B
        defb #6A,#6D,#52,#55,#D1,#2B,#13,#D9,#1A,#1D,#88,#13,#06,#00,#01,#02
        defb #03,#12,#13,#0C,#FF,#07,#32,#29,#35,#2E,#16,#0D,#11,#0A,#89,#14
        defb #15,#01,#03,#0D,#FF,#07,#2C,#6C,#AC,#24,#1C,#14,#54,#94,#21,#EC
        defb #D4,#50,#64,#8A,#18,#13,#01,#03,#0D,#FF,#5F,#2A,#22,#1A,#12,#2D
        defb #25,#1D,#15,#97,#EA,#E2,#DA,#D2,#ED,#E5,#DD,#D5,#8B,#06,#05,#00
        defb #01,#03,#0C,#8C,#19,#14,#01,#03,#0D,#FF,#07,#2A,#6A,#2D,#6D,#12
        defb #52,#15,#55,#2B,#AA,#AD,#92,#95,#D9,#1A,#1D,#40,#1B,#8D,#1A,#05
        defb #01,#03,#0C,#FF,#07,#34,#74,#6C,#B4,#BC,#FB,#FD,#F3,#03,#FC,#F5
        defb #EB,#ED,#58,#3C,#28,#24,#10,#E4,#8E,#0C,#13,#14,#03,#16,#0D,#FF
        defb #39,#23,#63,#48,#2B,#8F,#05,#06,#00,#03,#0C,#93,#14,#0C,#00,#02
        defb #0E,#FF,#07,#1A,#1B,#1C,#1D,#5A,#9A,#5D,#9D,#21,#DA,#DD,#A0,#5B
        defb #97,#10,#0C,#00,#02,#0E,#FF,#03,#1A,#1B,#1C,#1D,#23,#5A,#5B,#5C
        defb #5D,#98,#1A,#0B,#00,#02,#0E,#FF,#01,#33,#0C,#A9,#6B,#54,#2F,#22
        defb #23,#24,#25,#1A,#1B,#1C,#1D,#B3,#A3,#A4,#9B,#9C,#9B,#17,#0B,#00
        defb #15,#17,#0E,#FF,#07,#3D,#7D,#35,#75,#B5,#F5,#C3,#C4,#78,#DD,#70
        defb #DB,#29,#1C,#1D,#9F,#18,#0D,#00,#02,#0E,#FF,#07,#1A,#1B,#1C,#1D
        defb #5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#2A,#DB,#DC,#DD,#A3,#1C,#0B
        defb #00,#15,#17,#0E,#FF,#05,#3D,#7D,#34,#74,#C3,#C4,#2B,#12,#14,#23
        defb #25,#93,#52,#54,#63,#65,#B8,#35,#80,#75,#A7,#05,#03,#00,#02,#0C
        defb #A8,#18,#06,#02,#0C,#FF,#07,#2A,#6A,#32,#72,#B2,#F2,#36,#76,#05
        defb #B6,#F6,#16,#56,#96,#D6,#29,#35,#1E,#AA,#18,#03,#00,#01,#0C,#FF
        defb #07,#00,#48,#90,#18,#58,#98,#D8,#21,#02,#61,#28,#68,#29,#A8,#A1
        defb #A8,#E0,#AB,#06,#04,#00,#02,#03,#0C,#AF,#0E,#0C,#00,#15,#17,#0E
        defb #FF,#03,#1B,#1C,#33,#34,#30,#74,#B3,#06,#06,#00,#01,#02,#0C,#B4
        defb #13,#04,#03,#0C,#FF,#07,#13,#14,#15,#1B,#23,#63,#A3,#E3,#30,#55
        defb #39,#2E,#6E,#B7,#0E,#0C,#00,#02,#0E,#FF,#03,#33,#34,#0B,#0C,#49
        defb #23,#1C,#BA,#19,#05,#01,#02,#0C,#FF,#05,#2B,#6B,#AB,#1B,#5B,#9B
        defb #2F,#2A,#22,#62,#A2,#1A,#2C,#24,#64,#29,#A4,#1C,#BB,#0B,#06,#02
        defb #03,#0C,#FF,#48,#24,#81,#64,#A4,#BF,#1D,#03,#00,#15,#17,#0C,#FF
        defb #04,#3D,#7E,#BE,#C3,#C4,#2F,#3F,#37,#2F,#2E,#2D,#25,#1D,#15,#29
        defb #14,#0C,#B8,#7F,#80,#BF,#C3,#14,#0B,#00,#02,#0E,#FF,#07,#1A,#1B
        defb #1C,#1D,#5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#C7,#0B,#05,#00,#15
        defb #17,#0C,#FF,#80,#5B,#48,#1B,#CF,#0A,#0C,#00,#02,#08,#0A,#0E,#FF
        defb #48,#1C,#D0,#19,#05,#00,#01,#0C,#FF,#07,#03,#42,#81,#C0,#C8,#D0
        defb #D8,#E0,#03,#1C,#5C,#9C,#DC,#2B,#1B,#24,#1D,#14,#D1,#11,#14,#01
        defb #03,#0D,#FF,#68,#16,#2F,#1E,#26,#1B,#1C,#23,#24,#19,#21,#D2,#15
        defb #05,#00,#03,#0C,#FF,#07,#03,#27,#44,#5F,#85,#97,#C6,#CF,#01,#CE
        defb #C7,#99,#0F,#06,#D3,#12,#0D,#00,#02,#0E,#FF,#01,#2A,#2D,#2B,#6A
        defb #6D,#1A,#1D,#D0,#2B,#68,#25,#D6,#15,#06,#04,#05,#0F,#10,#FF,#1F
        defb #2C,#6C,#AC,#EC,#24,#1C,#14,#54,#18,#94,#11,#5D,#1B,#D7,#0E,#03
        defb #04,#05,#06,#07,#0F,#FF,#51,#1B,#24,#A1,#23,#1C,#D8,#06,#03,#04
        defb #05,#07,#0F,#D9,#05,#06,#04,#07,#0F,#DD,#14,#06,#00,#14,#16,#0C
        defb #FF,#01,#E7,#DF,#5B,#2F,#26,#1E,#17,#3B,#1A,#5A,#9A,#DA,#DE,#05
        defb #13,#01,#03,#0D,#DF,#16,#06,#00,#02,#03,#0C,#FF,#04,#1B,#5B,#9B
        defb #DB,#E2,#2B,#13,#1C,#23,#1A,#B2,#12,#54,#A4,#E0,#11,#0E,#00,#02
        defb #0E,#FF,#2F,#3A,#3D,#2B,#2C,#13,#14,#02,#05,#C8,#24,#E2,#16,#0E
        defb #00,#02,#0E,#FF,#97,#05,#0A,#0C,#13,#15,#1A,#1C,#23,#95,#25,#2A
        defb #2C,#33,#35,#3A,#E3,#1B,#0E,#00,#02,#0E,#FF,#AF,#02,#05,#4A,#4D
        defb #92,#95,#AA,#AD,#AB,#72,#75,#3A,#3D,#B3,#DA,#DD,#E2,#E5,#60,#1B
        defb #E6,#07,#03,#04,#05,#06,#0F,#10,#E7,#11,#06,#04,#05,#06,#07,#0F
        defb #FF,#2F,#33,#34,#21,#19,#26,#1E,#0B,#0C,#E8,#16,#06,#04,#05,#06
        defb #07,#0F,#FF,#1F,#33,#21,#23,#63,#A3,#E3,#25,#13,#2B,#2B,#24,#1B
        defb #22,#E9,#06,#03,#04,#06,#07,#0F,#ED,#14,#0C,#00,#02,#0E,#FF,#07
        defb #1A,#1B,#1C,#1D,#5A,#5B,#5C,#5D,#03,#9A,#9B,#9C,#9D,#EF,#05,#0D
        defb #00,#02,#0E,#F0,#1B,#05,#14,#15,#16,#17,#0C,#FF,#07,#DF,#E7,#FF
        defb #FE,#78,#A8,#D0,#C0,#03,#C1,#C2,#C3,#C4,#29,#39,#3B,#70,#FB,#F1
        defb #0A,#13,#01,#03,#09,#0B,#0D,#FF,#B8,#23,#F2,#06,#05,#01,#02,#03
        defb #0C,#F3,#17,#03,#02,#03,#0C,#FF,#07,#32,#3A,#72,#7A,#34,#3C,#74
        defb #7C,#01,#B3,#BB,#48,#33,#31,#2B,#6B,#F6,#13,#06,#05,#06,#0F,#10
        defb #11,#FF,#1B,#1B,#5B,#9B,#DB,#B0,#1C,#30,#12,#38,#34,#F7,#15,#03
        defb #05,#06,#07,#0F,#11,#FF,#1F,#22,#23,#24,#1A,#1C,#12,#13,#14,#B8
        defb #1B,#30,#5B,#F8,#07,#03,#05,#06,#07,#0F,#11,#F9,#13,#06,#06,#07
        defb #0F,#11,#FF,#9F,#FF,#FE,#F6,#F7,#FD,#EF,#C3,#C4,#99,#D8,#E0,#FD
        defb #11,#06,#01,#02,#0C,#FF,#07,#28,#29,#2A,#32,#3A,#70,#71,#79,#00
        defb #B8,#FE,#12,#13,#01,#03,#0D,#FF,#2B,#25,#1D,#22,#1A,#23,#2B,#2C
        defb #13,#14,#60,#5B,#FF,#0B,#06,#02,#03,#0C,#FF,#2B,#2E,#35,#37,#3E
tbl_room_connection_ptrs:
        ; Table de pointeurs word. Ce n'est PAS un chemin alternatif rarement
        ; déclenché par un octet 0xFF comme précédemment documenté — désassemblage
        ; direct de fn_load_room_data (0x2CBA-0x2D0D) montre que c'est la PHASE 2,
        ; TOUJOURS exécutée, du traitement du payload, juste après la phase 1
        ; (liste d'index directs vers tbl_room_index_ptrs, qui se TERMINE par 0xFF
        ; — le 0xFF n'active rien d'"alternatif", il marque simplement la fin de
        ; la phase 1). L'octet du payload juste après le 0xFF encode un compteur
        ; (bits0-2, +1) ET, après rotation/masquage (rrca,rrca; and 0x3E),
        ; l'index×2 dans cette table. EXTENT CONFIRMÉE: exactement 29 entrées
        ; (0x3D5D-0x3D97, 58 octets) — les 29 pointeurs uniques, triés,
        ; s'enchaînent PARFAITEMENT jusqu'à tbl_room_index_ptrs (0x3E6E). Chaque
        ; pointeur mène à un tbl_room_junction_entity_template_XXXX (voir ci-
        ; dessous).
        defw #3D97
        defw #3DC8
        defw #3DCF
        defw #3DF2
        defw #3DF9
        defw #3E00
        defw #3E1C
        defw #3E23
        defw #3E2A
        defw #3E44
        defw #3E4B
        defw #3D9E
        defw #3DD6
        defw #3E37
        defw #3DA5
        defw #3DAC
        defw #3DB3
        defw #3E07
        defw #3E0E
        defw #3E15
        defw #3E52
        defw #3DBA
        defw #3DC1
        defw #3DEB
        defw #3DDD
        defw #3E59
        defw #3E60
        defw #3E67
        defw #3DE4
tbl_room_junction_entity_template_3D97:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #07,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3D9E:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #07,#08,#08,#0C,#10,#30,#00
tbl_room_junction_entity_template_3DA5:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #36,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DAC:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #37,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DB3:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3E,#08,#08,#0C,#14,#00,#00
tbl_room_junction_entity_template_3DBA:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #5B,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DC1:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #8F,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DC8:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B0,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DCF:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#02,#00
tbl_room_junction_entity_template_3DD6:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#03,#00
tbl_room_junction_entity_template_3DDD:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DE4:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B2,#07,#07,#0C,#10,#01,#00
tbl_room_junction_entity_template_3DEB:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B6,#07,#07,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DF2:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #06,#08,#08,#0C,#10,#00,#00
tbl_room_junction_entity_template_3DF9:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #16,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E00:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #17,#06,#06,#0C,#50,#00,#00
tbl_room_junction_entity_template_3E07:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #17,#06,#06,#0C,#50,#30,#00
tbl_room_junction_entity_template_3E0E:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3F,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E15:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #3F,#06,#06,#0C,#10,#30,#00
tbl_room_junction_entity_template_3E1C:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #55,#09,#06,#0C,#14,#00,#00
tbl_room_junction_entity_template_3E23:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #54,#06,#0A,#0C,#14,#00,#00
tbl_room_junction_entity_template_3E2A:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #96,#06,#06,#18,#10,#02,#90,#06,#06,#00,#12,#02,#00
tbl_room_junction_entity_template_3E37:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #1E,#06,#06,#18,#10,#00,#90,#06,#06,#00,#12,#00,#00
tbl_room_junction_entity_template_3E44:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #52,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E4B:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #B5,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E52:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #56,#06,#06,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E59:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #A4,#05,#05,#0C,#10,#00,#00
tbl_room_junction_entity_template_3E60:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #08,#0C,#01,#20,#50,#01,#00
tbl_room_junction_entity_template_3E67:
        ; Template d'entite de decor de jonction entre 2 salles (poteau de porte
        ; type #02/#03, ou segment de mur #0A-#0F, etc.), copie via
        ; tbl_room_connections dans le tableau d'entites actives par
        ; fn_instantiate_room_objects. Format : octet0=type d'entite,
        ; octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, PAS
        ; un numero de room), octets4-6=bbox/autres champs, octet7=flags (egal au
        ; champ flags de l'entite reelle), octet8=numero de room courant.
        defb #08,#01,#0C,#20,#10,#02,#00
tbl_room_index_ptrs:
        ; Table de pointeurs word, indexée DIRECTEMENT par l'octet du payload de
        ; tbl_room_master_index (chemin par défaut). EXTENT CONFIRMÉE: exactement
        ; 24 entrées (0x3E6E-0x3E9E, 48 octets) — au-delà, les mots décodés
        ; cessent de ressembler à des pointeurs plausibles. Chaque pointeur mène à
        ; un bloc tbl_room_connection_detail_XXXX (voir ci-dessous)
        defw #3E9E
        defw #3EAF
        defw #3ED1
        defw #3EF3
        defw #3F04
        defw #3F15
        defw #3F26
        defw #3F37
        defw #3F48
        defw #3F51
        defw #3F5A
        defw #3F63
        defw #3F6C
        defw #3FD5
        defw #4046
        defw #40B7
        defw #4118
        defw #4129
        defw #413A
        defw #414B
        defw #3EC0
        defw #3EE2
        defw #415C
        defw #416D
tbl_room_connection_detail_3E9E:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#C4,#80,#03,#05,#28,#50,#03,#73,#C4,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EAF:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#C4,#73,#80,#05,#03,#28,#10,#03,#C4,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3EC0:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#C4,#73,#B0,#05,#03,#28,#10,#03,#C4,#8D,#B0,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3ED1:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#3B,#80,#03,#05,#28,#50,#03,#73,#3B,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EE2:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#8D,#3B,#B0,#03,#05,#28,#50,#03,#73,#3B,#B0,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3EF3:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #02,#3B,#73,#80,#05,#03,#28,#10,#03,#3B,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F04:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#8D,#C4,#80,#03,#05,#28,#50,#05,#73,#C4,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3F15:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#C4,#73,#80,#05,#03,#28,#10,#05,#C4,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F26:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#8D,#3B,#80,#03,#05,#28,#50,#05,#73,#3B,#80,#03,#05,#28,#50
        defb #00
tbl_room_connection_detail_3F37:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #04,#3B,#73,#80,#05,#03,#28,#10,#05,#3B,#8D,#80,#05,#03,#28,#10
        defb #00
tbl_room_connection_detail_3F48:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#80,#BE,#A0,#0C,#01,#20,#50,#00
tbl_room_connection_detail_3F51:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#BE,#80,#A0,#01,#0C,#20,#10,#00
tbl_room_connection_detail_3F5A:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#80,#41,#A0,#0C,#01,#20,#50,#00
tbl_room_connection_detail_3F63:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #08,#41,#80,#A0,#01,#0C,#20,#10,#00
tbl_room_connection_detail_3F6C:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#3F,#B8,#80,#00,#08,#28,#10,#0E,#47,#C0,#80,#08,#00,#28,#10
        defb #0F,#3F,#49,#80,#00,#08,#2C,#10,#0F,#B8,#C0,#80,#08,#00,#2C,#50
        defb #0F,#3F,#49,#AC,#00,#08,#2C,#10,#0F,#B8,#C0,#AC,#08,#00,#2C,#50
        defb #0A,#5C,#C0,#80,#14,#00,#14,#50,#0B,#3F,#5C,#96,#00,#0C,#14,#10
        defb #0C,#3F,#9C,#96,#00,#0C,#0C,#10,#0B,#A4,#C0,#96,#0C,#00,#14,#50
        defb #0A,#3F,#6D,#B1,#00,#14,#14,#10,#0C,#60,#C0,#A0,#0C,#00,#0C,#50
        defb #0A,#90,#C0,#B0,#14,#00,#14,#50,#00
tbl_room_connection_detail_3FD5:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#3F,#98,#80,#00,#08,#28,#10,#0E,#47,#A0,#80,#08,#00,#28,#10
        defb #0F,#3F,#63,#80,#00,#08,#2C,#10,#0F,#B8,#A0,#80,#08,#00,#2C,#50
        defb #0F,#3F,#63,#AC,#00,#08,#2C,#10,#0F,#B8,#A0,#AC,#08,#00,#2C,#50
        defb #0D,#3F,#98,#A8,#00,#08,#28,#10,#0E,#47,#A0,#A8,#08,#00,#28,#10
        defb #0F,#B8,#A0,#D0,#08,#00,#2C,#50,#0A,#80,#A0,#80,#14,#00,#14,#50
        defb #0A,#3F,#7E,#B0,#00,#14,#14,#10,#0B,#60,#A0,#90,#0C,#00,#14,#50
        defb #0A,#60,#A0,#B8,#14,#00,#14,#50,#0C,#A0,#A0,#B0,#0C,#00,#0C,#50
        defb #00
