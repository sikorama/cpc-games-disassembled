; ============================================================
; resources_zone.asm -- genere par tools/gen_asm.py, plage #4046-#8000
; Genere mecaniquement depuis la RAM live + asm/symbols.json.
; Ne pas editer les blocs de code a la main : relancer le generateur.
; ============================================================
        org #4046
tbl_room_connection_detail_4046:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #0D,#5F,#B8,#80,#00,#08,#28,#10,#0E,#67,#C0,#80,#08,#00,#28,#10
        defb #0F,#5F,#48,#80,#00,#08,#2C,#10,#0F,#9D,#C0,#80,#08,#00,#2C,#50
        defb #0D,#5F,#B8,#A8,#00,#08,#28,#10,#0E,#67,#C0,#A8,#08,#00,#28,#10
        defb #0F,#5F,#48,#AC,#00,#08,#2C,#10,#0F,#9D,#C0,#AC,#08,#00,#2C,#50
        defb #0F,#5F,#48,#D0,#00,#08,#2C,#10,#0A,#5F,#90,#80,#00,#14,#14,#10
        defb #0A,#84,#C0,#B0,#14,#00,#14,#50,#0B,#5F,#60,#90,#00,#0C,#14,#10
        defb #0A,#5F,#68,#B8,#00,#14,#14,#10,#0C,#5F,#A0,#B0,#00,#0C,#0C,#10
        defb #00
tbl_room_connection_detail_40B7:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#3F,#49,#80,#00,#08,#2C,#10,#80,#3F,#58,#80,#00,#08,#2C,#D0
        defb #80,#3F,#68,#80,#00,#08,#2C,#10,#80,#3F,#98,#80,#00,#08,#2C,#D0
        defb #80,#3F,#A8,#80,#00,#08,#2C,#10,#80,#3F,#B8,#80,#00,#08,#2C,#D0
        defb #80,#48,#C0,#80,#08,#00,#2C,#50,#80,#58,#C0,#80,#08,#00,#2C,#90
        defb #80,#68,#C0,#80,#08,#00,#2C,#50,#80,#98,#C0,#80,#08,#00,#2C,#90
        defb #80,#A8,#C0,#80,#08,#00,#2C,#50,#80,#B8,#C0,#80,#08,#00,#2C,#90
        defb #00
tbl_room_connection_detail_4118:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#3F,#78,#80,#00,#08,#2C,#10,#80,#3F,#88,#80,#00,#08,#2C,#D0
        defb #00
tbl_room_connection_detail_4129:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #80,#78,#C0,#80,#08,#00,#2C,#50,#80,#88,#C0,#80,#08,#00,#2C,#90
        defb #00
tbl_room_connection_detail_413A:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #9E,#98,#68,#80,#05,#05,#18,#10,#90,#A0,#60,#80,#05,#05,#00,#12
        defb #00
tbl_room_connection_detail_414B:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #8D,#80,#80,#80,#0A,#0A,#18,#10,#8E,#80,#88,#80,#00,#00,#00,#12
        defb #00
tbl_room_connection_detail_415C:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #07,#C8,#78,#A4,#08,#08,#0C,#10,#07,#C8,#88,#A4,#08,#08,#0C,#10
        defb #00
tbl_room_connection_detail_416D:
        ; Template d'entite de decor de jonction entre 2 salles : 8 octets copies
        ; tels quels dans tbl_room_connections (sans calcul), correspondant
        ; exactement aux 8 premiers offsets de struct_entities_base (+0=type,
        ; +1=grid_x, +2=grid_y, +3=grid_z_or_offset, +4=bbox_w, +5=bbox_h,
        ; +6=bbox_d, +7=flags). Le numero de room (+8 de l'entite) est ajoute
        ; separement par fn_load_room_data. N chunks concatenes par bloc, termine
        ; par un chunk dont le 1er octet est #00 (non copie).
        defb #07,#78,#38,#A4,#08,#08,#0C,#10,#07,#88,#38,#A4,#08,#08,#0C,#10
        defb #00
tbl_object_catalog:
        ; 32 entrées de 9 octets (0x417E-0x429E exactement). Layout réel: +0=TYPE
        ; (RÉÉCRIT chaque partie par fn_catalog_randomize_types, valeur
        ; 0x60-0x67), +1..+4=template FIXE (grid_x/y/z/room, jamais modifié),
        ; +5..+8=copie de travail (RÉÉCRITE depuis +1..+4 chaque partie, lue par
        ; fn_instantiate_room_objects).
        defb #60,#88,#80,#A4,#6D,#88,#80,#A4,#6D,#61,#80,#80,#8C,#27,#80,#80
        defb #8C,#27,#62,#88,#78,#B0,#D0,#88,#78,#B0,#D0,#63,#78,#88,#80,#0A
        defb #78,#88,#80,#0A,#64,#78,#88,#80,#BA,#78,#88,#80,#BA,#65,#88,#78
        defb #B0,#42,#88,#78,#B0,#42,#66,#88,#B8,#BC,#8D,#88,#B8,#BC,#8D,#67
        defb #A8,#A8,#80,#FF,#A8,#A8,#80,#FF,#60,#80,#80,#80,#87,#80,#80,#80
        defb #87,#61,#78,#B8,#80,#F3,#78,#B8,#80,#F3,#62,#A8,#68,#B0,#A8,#A8
        defb #68,#B0,#A8,#63,#B8,#48,#B0,#D2,#B8,#48,#B0,#D2,#64,#48,#48,#80
        defb #00,#48,#48,#80,#00,#65,#88,#B8,#80,#22,#88,#B8,#80,#22,#66,#B8
        defb #B8,#B0,#7A,#B8,#B8,#B0,#7A,#67,#B8,#B8,#80,#F9,#B8,#B8,#80,#F9
        defb #60,#88,#98,#B0,#D6,#88,#98,#B0,#D6,#61,#78,#88,#B0,#E8,#78,#88
        defb #B0,#E8,#62,#78,#78,#B0,#F6,#78,#78,#B0,#F6,#63,#88,#78,#8C,#0F
        defb #88,#78,#8C,#0F,#64,#B8,#B8,#80,#6F,#B8,#B8,#80,#6F,#65,#48,#B8
        defb #A4,#FD,#48,#B8,#A4,#FD,#66,#78,#78,#B0,#08,#78,#78,#B0,#08,#67
        defb #88,#88,#A4,#BB,#88,#88,#A4,#BB,#60,#78,#78,#B0,#DF,#78,#78,#B0
        defb #DF,#61,#80,#80,#80,#5E,#80,#80,#80,#5E,#62,#78,#88,#B0,#B4,#78
        defb #88,#B0,#B4,#63,#78,#78,#B0,#04,#78,#78,#B0,#04,#64,#48,#B8,#80
        defb #74,#48,#B8,#80,#74,#65,#80,#80,#80,#40,#80,#80,#80,#40,#66,#68
        defb #78,#B0,#38,#68,#78,#B0,#38,#67,#48,#B8,#98,#F0,#48,#B8,#98,#F0
tbl_sprite_dispatch:
        ; Table de pointeurs word vers les données de forme, indexée par (ix+00).
        ; EXTENT CONFIRMÉE: exactement 194 entrées (#429E-#4421, types #00-#C1) —
        ; même méthode que pour tbl_entity_logic_dispatch (vérification que chaque
        ; mot pointe dans la zone RESSOURCES #4000-#7FFF; l'entrée 194 sort de
        ; cette plage, ET l'entrée 0 pointe exactement sur #4422, l'octet qui suit
        ; la dernière entrée valide — double confirmation). Légèrement plus large
        ; que tbl_entity_logic_dispatch (188 entrées, types #00-#BB), cohérent
        ; avec quelques types render-only sans logique IA dédiée (#BC-#C1)
        defw #4422
        defw #4422
        defw #5AC6
        defw #5C01
        defw #6197
        defw #6286
        defw #5678
        defw #59DB
        defw #7BD7
        defw #7BD7
        defw #5ED5
        defw #5FD2
        defw #6065
        defw #5C90
        defw #5D4F
        defw #5E12
        defw #6BC0
        defw #6C23
        defw #6C86
        defw #6CE9
        defw #6C86
        defw #6C23
        defw #7DB9
        defw #5595
        defw #6D4C
        defw #6DB5
        defw #6E1E
        defw #6E87
        defw #6E1E
        defw #6DB5
        defw #4BA0
        defw #4C2D
        defw #6684
        defw #6717
        defw #642C
        defw #65F1
        defw #642C
        defw #6717
        defw #6558
        defw #69FB
        defw #6830
        defw #64BF
        defw #6962
        defw #68C9
        defw #6962
        defw #64BF
        defw #6B27
        defw #6A8E
        defw #788F
        defw #78F2
        defw #7955
        defw #79B8
        defw #7955
        defw #78F2
        defw #59DB
        defw #59DB
        defw #7A1B
        defw #7A8A
        defw #7AF9
        defw #7B68
        defw #7AF9
        defw #7A8A
        defw #59DB
        defw #7E4C
        defw #701F
        defw #70D0
        defw #7181
        defw #7232
        defw #7181
        defw #70D0
        defw #75BF
        defw #7670
        defw #7508
        defw #7451
        defw #739A
        defw #72E3
        defw #739A
        defw #7451
        defw #7721
        defw #77D8
        defw #4804
        defw #487F
        defw #48F4
        defw #496F
        defw #7CD6
        defw #54AA
        defw #5763
        defw #57A2
        defw #67AA
        defw #67ED
        defw #57E5
        defw #59DB
        defw #4CBA
        defw #4D7D
        defw #4E46
        defw #4F2D
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #4424
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #52B1
        defw #52B1
        defw #521E
        defw #52B1
        defw #521E
        defw #518B
        defw #50FE
        defw #507D
        defw #5002
        defw #5002
        defw #507D
        defw #50FE
        defw #518B
        defw #521E
        defw #52B1
        defw #521E
        defw #52B1
        defw #60D4
        defw #4422
        defw #4422
        defw #52B1
        defw #521E
        defw #518B
        defw #6349
        defw #63AF
        defw #636C
        defw #6F2C
        defw #6F23
        defw #6EF0
        defw #4424
        defw #5344
        defw #544F
        defw #59DB
        defw #6BC0
        defw #6C23
        defw #6C86
        defw #6CE9
        defw #6C86
        defw #6C23
        defw #4BA0
        defw #4C2D
        defw #6D4C
        defw #6DB5
        defw #6E1E
        defw #6E87
        defw #6E1E
        defw #6DB5
        defw #4AD7
        defw #49EA
        defw #52B1
        defw #521E
        defw #518B
        defw #521E
        defw #52B1
        defw #521E
        defw #518B
        defw #521E
        defw #4687
        defw #4600
        defw #446B
        defw #4702
        defw #4795
        defw #456D
        defw #44EC
        defw #4424
        defw #5763
        defw #57A2
        defw #7F17
        defw #7F8C
        defw #5763
        defw #57A2
        defw #7F17
        defw #7F8C
        defw #52B1
        defw #521E
        defw #58E0
        defw #52B1
        defw #59DB
        defw #59DB
        defw #59DB
        defw #59DB
        defw #63DA
        defw #63E1
sprite_shape_none:
        ; Octet #00, teste par fn_resolve_sprite_shape qui fait un double RET
        ; (rien a dessiner). Pointeur par defaut de tbl_sprite_dispatch pour les
        ; types non implementes/reserves.
        defb #00
        ; non désassemblé
        defb #00
sprite_life_4424:
        ; Sprite "life" (4x17 octets/ligne, 68 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 67,8C,AF.
        defb #04,#11,#00,#00,#EE,#33,#88,#11,#F1,#74,#C4,#11,#F4,#F8,#C4,#00
        defb #FA,#F8,#88,#00,#74,#F9,#00,#00,#FC,#F1,#88,#11,#F2,#F0,#C4,#11
        defb #F2,#F0,#C4,#11,#F2,#F0,#C4,#11,#F2,#F0,#C4,#11,#F1,#FC,#C4,#00
        defb #FA,#F2,#88,#00,#75,#F1,#00,#00,#75,#F1,#00,#00,#75,#F1,#00,#00
        defb #32,#EA,#00,#00,#11,#CC,#00
sprite_boot_446B:
        ; Sprite "boot" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 62,6A,AA.
        defb #06,#15,#00,#00,#33,#EE,#00,#00,#00,#00,#47,#1F,#00,#00,#00,#00
        defb #8F,#0F,#88,#00,#00,#11,#3F,#EF,#4C,#00,#00,#11,#7C,#F1,#AE,#77
        defb #00,#11,#F8,#F0,#D7,#8F,#88,#11,#F0,#F0,#E3,#0F,#4C,#11,#F6,#F0
        defb #F1,#EF,#4C,#11,#F3,#F1,#F0,#F1,#4C,#00,#F9,#F2,#F0,#F8,#88,#00
        defb #74,#F4,#F4,#F4,#C4,#00,#33,#BA,#F0,#F4,#88,#00,#00,#11,#F4,#F2
        defb #88,#00,#00,#11,#F0,#F1,#00,#00,#00,#11,#F4,#F1,#00,#00,#00,#11
        defb #F3,#FE,#88,#00,#00,#32,#F7,#FF,#C4,#00,#00,#32,#FF,#FF,#C4,#00
        defb #00,#11,#F7,#FC,#88,#00,#00,#00,#F8,#F3,#00,#00,#00,#00,#77,#CC
        defb #00
sprite_crystal_ball_44EC:
        ; Sprite "crystal_ball" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 66,6E,AE.
        defb #06,#15,#00,#00,#00,#FF,#FF,#00,#00,#00,#33,#0F,#0F,#CC,#00,#00
        defb #47,#0F,#0F,#2E,#00,#00,#8F,#7F,#EF,#1F,#00,#11,#1F,#F8,#F1,#8F
        defb #88,#00,#BE,#F0,#F0,#D7,#00,#00,#74,#F0,#F0,#E2,#00,#00,#F8,#F0
        defb #F0,#F1,#00,#00,#F8,#F0,#F0,#F1,#00,#11,#F0,#F0,#F0,#F0,#88,#11
        defb #F0,#F0,#F0,#F0,#88,#11,#F0,#F0,#F0,#F0,#88,#11,#F3,#F8,#F0,#F0
        defb #88,#11,#F3,#F8,#F0,#F0,#88,#11,#F3,#FC,#F0,#F0,#88,#11,#F9,#FF
        defb #F0,#F1,#00,#00,#F8,#FF,#F0,#F1,#00,#00,#74,#F7,#F0,#E2,#00,#00
        defb #32,#F0,#F0,#C4,#00,#00,#11,#F8,#F1,#88,#00,#00,#00,#77,#EE,#00
        defb #00
sprite_bottle_456D:
        ; Sprite "bottle" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 65,6D,AD.
        defb #06,#18,#00,#00,#00,#FF,#EE,#00,#00,#00,#33,#F0,#F1,#88,#00,#00
        defb #75,#F0,#F0,#C4,#00,#00,#FB,#FF,#FC,#E2,#00,#00,#FB,#F0,#F4,#E2
        defb #00,#00,#FF,#F0,#F4,#E2,#00,#00,#FB,#F0,#F4,#E2,#00,#00,#FB,#F0
        defb #F4,#E2,#00,#00,#FB,#F0,#F4,#E2,#00,#00,#FB,#FF,#FC,#E2,#00,#00
        defb #FB,#F0,#F0,#E2,#00,#00,#FD,#F0,#F0,#E2,#00,#00,#F9,#F0,#F0,#E2
        defb #00,#00,#74,#F8,#F0,#C4,#00,#00,#74,#F4,#F0,#C4,#00,#00,#32,#F4
        defb #F0,#88,#00,#00,#11,#F2,#F1,#00,#00,#00,#00,#FA,#E2,#00,#00,#00
        defb #00,#FA,#E2,#00,#00,#00,#00,#FB,#EA,#00,#00,#00,#11,#C7,#7D,#00
        defb #00,#00,#00,#8F,#2E,#00,#00,#00,#00,#47,#4C,#00,#00,#00,#00,#33
        defb #88,#00,#00
sprite_poison_4600:
        ; Sprite "poison" (6x22 octets/ligne, 132 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 61,69,A9.
        defb #06,#16,#00,#00,#00,#FF,#FF,#00,#00,#00,#77,#F0,#F0,#EE,#00,#11
        defb #F8,#F0,#F0,#F1,#88,#32,#E1,#78,#E1,#78,#C4,#74,#E1,#96,#96,#78
        defb #E2,#74,#F0,#E1,#78,#F0,#E2,#F8,#F0,#96,#96,#F0,#F1,#F8,#E1,#69
        defb #69,#78,#F1,#F8,#E1,#69,#69,#78,#F1,#F8,#F0,#C3,#3C,#F0,#F1,#74
        defb #F0,#C3,#3C,#F0,#E2,#74,#F1,#E1,#78,#F8,#E2,#32,#F0,#F8,#F1,#F0
        defb #C4,#11,#F8,#F8,#F1,#F1,#88,#00,#77,#F8,#F1,#EE,#00,#00,#00,#F8
        defb #F1,#00,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#FB,#FD,#00,#00,#00
        defb #11,#F4,#F2,#88,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#FC,#E2,#00
        defb #00,#00,#00,#33,#CC,#00,#00
sprite_ruby_4687:
        ; Sprite "ruby" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 60,68,A8.
        defb #06,#14,#00,#00,#00,#00,#88,#00,#00,#00,#00,#77,#FF,#00,#00,#00
        defb #00,#FA,#F2,#88,#00,#00,#11,#F2,#F2,#C4,#00,#00,#32,#F4,#F1,#E2
        defb #00,#00,#32,#F4,#F1,#E2,#00,#00,#74,#F8,#F0,#F9,#00,#00,#F8,#F8
        defb #F0,#F8,#88,#00,#F9,#F0,#F0,#F4,#88,#11,#F1,#F0,#F0,#F4,#C4,#32
        defb #F2,#FF,#FF,#FA,#E2,#32,#F5,#F0,#F0,#F5,#E2,#74,#F8,#F8,#F0,#F8
        defb #F9,#75,#F0,#F8,#F0,#F8,#F5,#32,#F1,#F7,#FF,#F4,#E2,#11,#F2,#F0
        defb #F0,#F2,#C4,#00,#FC,#F0,#F0,#F1,#88,#00,#32,#F0,#F0,#E2,#00,#00
        defb #11,#F0,#F0,#C4,#00,#00,#00,#FF,#FF,#88,#00
sprite_chalice_4702:
        ; Sprite "chalice" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 63,6B,AB.
        defb #06,#18,#00,#00,#00,#77,#EE,#00,#00,#00,#33,#F8,#F1,#CC,#00,#00
        defb #76,#F0,#F0,#E2,#00,#00,#FE,#F1,#F8,#F1,#00,#11,#F3,#F2,#F4,#F0
        defb #88,#00,#F9,#FC,#F2,#F1,#00,#00,#74,#F7,#FE,#E2,#00,#00,#33,#FF
        defb #FF,#CC,#00,#00,#33,#FA,#F1,#CC,#00,#00,#32,#F4,#F0,#C4,#00,#00
        defb #74,#F8,#F0,#E2,#00,#00,#F9,#FF,#FF,#F1,#00,#11,#F7,#F0,#F0,#FE
        defb #88,#11,#FA,#F0,#F0,#F1,#88,#11,#F6,#FF,#FF,#F0,#CC,#32,#F7,#F0
        defb #F0,#FE,#C4,#32,#F8,#FF,#FF,#F1,#C4,#33,#F7,#FF,#FF,#FE,#CC,#32
        defb #FF,#FF,#FF,#FF,#C4,#32,#FF,#FF,#FF,#FF,#C4,#11,#F7,#FF,#FF,#FE
        defb #88,#00,#F8,#FF,#FF,#F1,#00,#00,#77,#F0,#F0,#EE,#00,#00,#00,#FF
        defb #FF,#00,#00
sprite_cup_4795:
        ; Sprite "cup" (6x18 octets/ligne, 108 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 64,6C,AC.
        defb #06,#12,#00,#00,#77,#FF,#CC,#00,#00,#00,#F8,#F0,#E2,#00,#00,#11
        defb #F8,#FF,#F1,#00,#00,#11,#F6,#F0,#FD,#00,#00,#00,#F8,#F0,#F3,#FF
        defb #88,#11,#F0,#F0,#F1,#F0,#C4,#32,#F0,#F0,#F0,#F8,#E2,#74,#F0,#F0
        defb #F0,#F7,#E2,#74,#F1,#FF,#F0,#F7,#F9,#F8,#FE,#F0,#FE,#F3,#F9,#FB
        defb #F1,#FF,#F1,#FB,#F9,#FC,#FF,#FF,#FE,#F7,#F9,#FB,#FF,#FF,#FF,#FA
        defb #E2,#FB,#FF,#FF,#FF,#FA,#C4,#74,#FF,#FF,#FE,#D5,#88,#33,#F1,#FF
        defb #F1,#88,#00,#00,#FE,#F0,#EE,#00,#00,#00,#11,#FF,#00,#00,#00
sprite_ghost1_4804:
        ; Sprite "ghost1" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 50.
        defb #06,#14,#00,#00,#00,#11,#EE,#00,#00,#00,#00,#23,#1F,#00,#00,#00
        defb #11,#CF,#0F,#88,#00,#00,#23,#0F,#0F,#88,#00,#00,#23,#0F,#1F,#EE
        defb #66,#77,#CF,#0F,#0F,#9F,#9F,#8F,#0F,#0F,#0F,#0F,#1F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#2E,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#1F,#8F,#0F,#4C,#00,#8F,#FF,#4F,#0F,#88,#00,#9F,#6F,#4F,#0F
        defb #88,#00,#57,#3F,#8F,#1F,#00,#00,#47,#CF,#0F,#1F,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_ghost3_487F:
        ; Sprite "ghost3" (6x19 octets/ligne, 114 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 51.
        defb #06,#13,#00,#00,#00,#11,#CC,#00,#00,#00,#00,#23,#2E,#00,#00,#00
        defb #77,#23,#1F,#33,#88,#00,#8F,#CF,#0F,#CF,#4C,#11,#0F,#0F,#0F,#0F
        defb #4C,#00,#8F,#0F,#0F,#0F,#6E,#77,#8F,#0F,#0F,#0F,#1F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#0F,#0F,#0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#2E,#23
        defb #0F,#1F,#8F,#0F,#4C,#11,#0F,#FF,#4F,#0F,#4C,#00,#9F,#6F,#4F,#0F
        defb #88,#00,#9F,#3F,#8F,#0F,#88,#00,#8F,#CF,#0F,#0F,#88,#00,#47,#0F
        defb #0F,#1F,#00,#00,#23,#0F,#0F,#6E,#00,#00,#11,#CF,#3F,#88,#00,#00
        defb #00,#33,#CC,#00,#00
sprite_ghost4_48F4:
        ; Sprite "ghost4" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 52.
        defb #06,#14,#00,#00,#00,#00,#66,#00,#00,#00,#33,#11,#9F,#00,#00,#00
        defb #47,#EF,#0F,#FF,#00,#00,#8F,#0F,#0F,#0F,#88,#33,#0F,#0F,#0F,#0F
        defb #88,#47,#0F,#0F,#0F,#0F,#CC,#8F,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#0F,#0F,#0F,#4C,#00,#8F,#0F,#0F,#9F,#4C,#00,#8F,#0F,#0F,#AF
        defb #88,#00,#47,#0F,#0F,#DF,#00,#00,#47,#0F,#0F,#DF,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_ghost2_496F:
        ; Sprite "ghost2" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 53.
        defb #06,#14,#00,#00,#00,#11,#EE,#00,#00,#00,#00,#23,#1F,#00,#00,#11
        defb #EE,#47,#0F,#FF,#00,#23,#1F,#47,#0F,#CF,#88,#11,#0F,#CF,#0F,#0F
        defb #4C,#33,#0F,#0F,#0F,#0F,#4C,#47,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F,#2E,#11
        defb #0F,#0F,#0F,#0F,#4C,#00,#8F,#0F,#0F,#6F,#4C,#00,#8F,#0F,#0F,#AF
        defb #88,#00,#47,#0F,#0F,#DF,#00,#00,#47,#0F,#0F,#DF,#00,#00,#23,#0F
        defb #0F,#2E,#00,#00,#23,#0F,#0F,#4C,#00,#00,#11,#0F,#0F,#88,#00,#00
        defb #00,#CF,#3F,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_melkhior_up2_49EA:
        ; Sprite "melkhior_up2" (6x39 octets/ligne, 234 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 9F.
        defb #06,#27,#00,#00,#00,#88,#00,#00,#00,#00,#11,#4C,#00,#00,#00,#00
        defb #23,#4C,#00,#00,#44,#00,#57,#4C,#00,#00,#AE,#00,#9F,#4C,#00,#00
        defb #AE,#00,#9F,#4C,#00,#11,#5F,#11,#1F,#BF,#FF,#11,#5F,#11,#3F,#AF
        defb #0F,#AB,#5F,#11,#3F,#AF,#0F,#6F,#DF,#11,#3F,#AF,#0F,#4F,#DF,#23
        defb #1F,#AF,#0F,#4F,#DF,#23,#1F,#4F,#2F,#4F,#DF,#23,#0F,#8F,#5F,#4F
        defb #DF,#23,#1F,#0F,#DF,#4F,#DF,#23,#1F,#1F,#5F,#4F,#2E,#23,#1F,#3F
        defb #5F,#0F,#4C,#11,#0F,#5F,#0F,#8F,#88,#11,#0F,#5F,#0F,#9F,#00,#00
        defb #8F,#4F,#0F,#9F,#00,#00,#47,#4F,#0F,#EE,#00,#00,#23,#8F,#0F,#EA
        defb #00,#00,#75,#9F,#BF,#7D,#00,#00,#75,#BF,#FF,#FD,#00,#00,#75,#EF
        defb #4F,#FD,#00,#00,#74,#DF,#FF,#7D,#00,#00,#74,#F3,#FF,#EA,#00,#00
        defb #74,#F0,#F0,#C4,#00,#00,#74,#F0,#F0,#88,#00,#00,#74,#F7,#F0,#88
        defb #00,#00,#74,#FE,#F9,#00,#00,#00,#74,#FC,#E2,#00,#00,#00,#32,#F8
        defb #C4,#00,#00,#00,#32,#F8,#88,#00,#00,#00,#32,#F0,#88,#00,#00,#00
        defb #32,#F1,#00,#00,#00,#00,#32,#E2,#00,#00,#00,#00,#32,#C4,#00,#00
        defb #00,#00,#32,#88,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_melkhior_up1_4AD7:
        ; Sprite "melkhior_up1" (6x33 octets/ligne, 198 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 9E.
        defb #06,#21,#00,#22,#00,#00,#00,#00,#00,#57,#00,#00,#00,#00,#00,#47
        defb #88,#00,#00,#00,#00,#47,#4C,#77,#FF,#11,#00,#47,#2E,#8F,#0F,#AB
        defb #88,#47,#1F,#0F,#0F,#4F,#88,#8F,#0F,#8F,#0F,#4F,#4C,#8F,#0F,#4F
        defb #0F,#4F,#4C,#8F,#0F,#2F,#0F,#4F,#2E,#8F,#0F,#2F,#0F,#8F,#2E,#8F
        defb #0F,#1F,#0F,#8F,#2E,#8F,#0F,#0F,#0F,#0F,#2E,#8F,#0F,#0F,#0F,#0F
        defb #4C,#77,#8F,#0F,#0F,#0F,#88,#00,#67,#0F,#0F,#1F,#00,#00,#11,#8F
        defb #3F,#EE,#00,#00,#00,#CF,#FC,#F1,#00,#00,#11,#3F,#F0,#F0,#88,#00
        defb #11,#3E,#F0,#F0,#88,#00,#00,#FC,#F1,#F8,#88,#00,#00,#74,#F3,#F0
        defb #88,#00,#00,#F8,#F6,#F0,#C4,#00,#00,#F8,#F6,#F0,#C4,#00,#00,#F8
        defb #F7,#F0,#C4,#00,#00,#F8,#F7,#F0,#C4,#00,#00,#74,#F3,#F8,#E2,#00
        defb #00,#33,#F0,#F0,#E2,#00,#00,#00,#FC,#F0,#E2,#00,#00,#00,#33,#F0
        defb #E2,#00,#00,#00,#00,#FC,#F1,#00,#00,#00,#00,#33,#F1,#00,#00,#00
        defb #00,#00,#FD,#00,#00,#00,#00,#00,#22
sprite_knight_up1_4BA0:
        ; Sprite "knight_up1" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1E,96.
        defb #06,#17,#00,#00,#11,#88,#00,#00,#00,#00,#23,#7F,#FF,#00,#00,#00
        defb #47,#4F,#0F,#EE,#00,#00,#CF,#8F,#0F,#1F,#00,#11,#4F,#8F,#0F,#0F
        defb #88,#11,#4F,#4F,#0F,#0F,#88,#00,#AF,#4F,#0F,#1F,#00,#00,#AF,#7F
        defb #EF,#1F,#00,#00,#77,#F8,#F1,#AE,#00,#00,#FE,#F0,#F0,#C4,#00,#11
        defb #3E,#F3,#FD,#EA,#00,#11,#3E,#F4,#F3,#F9,#00,#11,#3E,#F4,#F1,#FD
        defb #00,#00,#BE,#F4,#F1,#FB,#00,#00,#74,#F4,#F3,#F1,#00,#00,#F8,#F8
        defb #F3,#E2,#00,#00,#F9,#F0,#F3,#E2,#00,#00,#76,#F0,#F2,#C4,#00,#00
        defb #32,#F0,#F6,#C4,#00,#00,#11,#F0,#F4,#88,#00,#00,#00,#F8,#F9,#00
        defb #00,#00,#00,#74,#E6,#00,#00,#00,#00,#33,#88,#00,#00
sprite_knight_up2_4C2D:
        ; Sprite "knight_up2" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1F,97.
        defb #06,#17,#00,#00,#33,#77,#FF,#00,#00,#00,#47,#CF,#0F,#EE,#00,#00
        defb #8F,#8F,#0F,#1F,#00,#00,#CF,#8F,#0F,#0F,#88,#11,#4F,#8F,#0F,#0F
        defb #88,#11,#4F,#8F,#0F,#1F,#00,#00,#AF,#FF,#EF,#1F,#00,#00,#9F,#F9
        defb #FF,#DF,#00,#00,#BE,#F0,#FF,#FF,#00,#00,#74,#F4,#FF,#3F,#88,#00
        defb #74,#FC,#DF,#3F,#C4,#00,#F9,#F4,#C7,#DF,#C4,#00,#FA,#FA,#F3,#9F
        defb #C4,#00,#74,#FD,#F0,#F6,#88,#00,#74,#FC,#FC,#F0,#88,#00,#74,#FC
        defb #F3,#F9,#00,#00,#32,#F4,#F0,#F5,#00,#00,#32,#F6,#F0,#E2,#00,#00
        defb #11,#F2,#F0,#E2,#00,#00,#00,#F9,#F0,#C4,#00,#00,#00,#74,#F8,#88
        defb #00,#00,#00,#32,#F3,#00,#00,#00,#00,#11,#CC,#00,#00
sprite_transform1_4CBA:
        ; Sprite "transform1" (6x32 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5C.
        defb #06,#20,#00,#00,#00,#00,#00,#00,#22,#44,#00,#00,#00,#00,#DF,#BF
        defb #00,#00,#00,#33,#1F,#8F,#CC,#00,#00,#CF,#1F,#8F,#3F,#00,#11,#0F
        defb #6E,#47,#0F,#88,#11,#1F,#88,#33,#0F,#88,#11,#9F,#00,#00,#9F,#E6
        defb #76,#8F,#88,#11,#1F,#F1,#F8,#CF,#88,#11,#3E,#F0,#F0,#E7,#4C,#23
        defb #3E,#F0,#F0,#C7,#4C,#23,#7C,#F0,#F0,#E3,#4C,#23,#7C,#F0,#F0,#F3
        defb #88,#11,#FC,#FF,#FF,#E2,#00,#11,#3F,#8F,#0F,#CC,#00,#11,#1F,#8F
        defb #0F,#4C,#66,#23,#2F,#4F,#0F,#4C,#9F,#23,#2F,#0F,#0F,#4C,#9F,#47
        defb #6F,#0F,#0F,#2E,#9F,#47,#AB,#3F,#CF,#1F,#1F,#8F,#AB,#CF,#3F,#1F
        defb #2E,#9F,#33,#0F,#0F,#DF,#2E,#66,#47,#0F,#0F,#2F,#2E,#00,#8F,#7F
        defb #EF,#1F,#2E,#11,#1F,#8F,#1F,#8F,#CC,#11,#2F,#4F,#2F,#4F,#88,#11
        defb #2F,#4F,#2F,#4F,#88,#00,#AF,#4F,#2F,#5F,#00,#00,#57,#2F,#4F,#AE
        defb #00,#00,#22,#AF,#5F,#44,#00,#00,#00,#57,#AE,#00,#00,#00,#00,#33
        defb #CC,#00,#00
sprite_transform2_4D7D:
        ; Sprite "transform2" (6x33 octets/ligne, 198 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5D.
        defb #46,#21,#00,#00,#FF,#EE,#00,#00,#00,#11,#0F,#1F,#00,#11,#88,#11
        defb #0F,#3F,#00,#23,#4C,#23,#3F,#FF,#EE,#47,#4C,#23,#3F,#AB,#1F,#8F
        defb #88,#47,#FF,#F7,#0F,#8F,#88,#77,#F1,#F0,#CF,#1F,#00,#F8,#F1,#F0
        defb #F3,#2E,#CC,#F8,#F0,#F0,#C4,#DD,#2E,#74,#F0,#F0,#C4,#23,#1F,#BE
        defb #F0,#F0,#88,#47,#5F,#57,#F0,#F3,#5D,#8F,#AA,#23,#F8,#CF,#6F,#4F
        defb #88,#47,#FB,#0F,#4F,#2F,#88,#47,#CF,#0F,#0F,#1F,#00,#9F,#8F,#0F
        defb #0F,#1F,#00,#9F,#CF,#0F,#0F,#2E,#00,#9F,#2F,#0F,#EF,#4C,#00,#9F
        defb #0F,#7F,#FF,#CC,#00,#AF,#1F,#FF,#3F,#2E,#00,#67,#3F,#CF,#1F,#DF
        defb #00,#11,#DF,#0F,#BF,#DF,#00,#00,#BF,#3F,#FF,#DF,#00,#00,#BF,#EF
        defb #FF,#DF,#00,#11,#7F,#3F,#3F,#DF,#00,#11,#7F,#1F,#3F,#AE,#00,#11
        defb #7F,#1F,#FF,#2E,#00,#11,#7F,#FF,#EF,#AE,#00,#11,#7F,#FF,#9F,#2E
        defb #00,#00,#9F,#8F,#6F,#4C,#00,#00,#67,#5F,#8F,#88,#00,#00,#11,#EF
        defb #0F,#00,#00,#00,#00,#11,#EE,#00,#00
sprite_transform3_4E46:
        ; Sprite "transform3" (6x38 octets/ligne, 228 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5E.
        defb #46,#26,#00,#00,#77,#EE,#00,#00,#00,#00,#8F,#1F,#55,#EE,#00,#00
        defb #77,#2E,#AF,#9F,#00,#00,#23,#2E,#BF,#0F,#88,#00,#CF,#4C,#3F,#2F
        defb #88,#11,#0F,#88,#6F,#1F,#00,#11,#1F,#00,#4F,#1F,#00,#00,#AF,#88
        defb #0F,#0F,#88,#00,#CF,#6F,#9F,#2F,#88,#11,#0F,#4F,#1F,#9F,#00,#11
        defb #0F,#4F,#0F,#1F,#00,#00,#8F,#2F,#0F,#1F,#00,#00,#47,#1F,#0F,#1F
        defb #00,#00,#23,#1F,#0F,#0F,#88,#00,#47,#0F,#9F,#CF,#88,#00,#8F,#0F
        defb #1F,#3F,#00,#00,#8F,#0F,#5F,#0F,#88,#11,#0F,#0F,#5F,#1F,#4C,#00
        defb #CF,#0F,#7F,#2E,#4C,#11,#F3,#8F,#4C,#AF,#4C,#32,#F0,#F7,#88,#67
        defb #4C,#32,#F0,#F0,#88,#23,#4C,#74,#F0,#F0,#C4,#23,#4C,#F8,#F0,#F4
        defb #C4,#11,#88,#F8,#F0,#F4,#E2,#CC,#00,#76,#F0,#F8,#F3,#3F,#00,#11
        defb #FC,#F8,#F7,#0F,#CC,#11,#3F,#F9,#AF,#0F,#2E,#11,#1F,#EF,#0F,#8F
        defb #1F,#11,#0F,#FF,#0F,#EF,#1F,#00,#8F,#7F,#FF,#11,#EE,#00,#47,#4F
        defb #CC,#00,#00,#00,#33,#CF,#4C,#00,#00,#00,#00,#23,#4C,#00,#00,#00
        defb #00,#23,#2E,#00,#00,#00,#00,#11,#2E,#00,#00,#00,#00,#11,#2E,#00
        defb #00,#00,#00,#00,#CC,#00,#00
sprite_transform4_4F2D:
        ; Sprite "transform4" (6x35 octets/ligne, 210 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 5F.
        defb #06,#23,#00,#00,#33,#00,#00,#CC,#00,#00,#CF,#88,#11,#3F,#00,#33
        defb #0F,#4C,#11,#0F,#CC,#47,#0F,#88,#00,#8F,#2E,#8F,#3F,#00,#00,#67
        defb #1F,#8F,#CC,#00,#00,#33,#1F,#47,#3F,#00,#00,#CF,#1F,#23,#0F,#BB
        defb #33,#0F,#6E,#11,#0F,#FC,#FC,#DF,#88,#00,#DF,#F0,#F8,#F3,#00,#00
        defb #32,#F0,#F8,#F0,#88,#00,#74,#F0,#F0,#F0,#88,#00,#74,#F0,#F0,#F1
        defb #00,#00,#32,#F0,#F0,#E2,#00,#00,#11,#FF,#F0,#C4,#00,#00,#11,#0F
        defb #FF,#88,#00,#00,#11,#0F,#0F,#88,#00,#00,#23,#0F,#0F,#88,#00,#00
        defb #23,#0F,#0F,#88,#00,#00,#67,#0F,#0F,#88,#00,#00,#8F,#0F,#0F,#4C
        defb #00,#11,#0F,#3F,#8F,#3F,#00,#23,#8F,#4F,#4F,#0F,#88,#57,#CF,#CF
        defb #2F,#1F,#00,#AF,#7F,#0F,#1F,#2F,#88,#AF,#0F,#0F,#1F,#AF,#4C,#BF
        defb #8F,#8F,#1F,#47,#2E,#9F,#FF,#0F,#1F,#33,#2E,#9F,#4F,#0F,#1F,#99
        defb #2E,#77,#0F,#4F,#3F,#5D,#2E,#23,#0F,#CF,#1F,#5D,#2E,#23,#8F,#1F
        defb #1F,#2E,#CC,#11,#3F,#EE,#9F,#1F,#00,#00,#CC,#00,#57,#EE,#00,#00
        defb #00,#00,#22,#00,#00
sprite_poltergeist6_5002:
        ; Sprite "poltergeist6" (6x20 octets/ligne, 120 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 77,78.
        defb #06,#14,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #88,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88,#00,#00,#00
        defb #00,#00,#00,#00,#00,#22,#00,#00,#00,#00,#00,#75,#00,#00,#00,#00
        defb #00,#22,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11
        defb #00,#00,#00,#00,#00,#32,#88,#00,#00,#88,#00,#11,#00,#11,#11,#C4
        defb #00,#00,#00,#32,#88,#88,#00,#00,#00,#74,#C4,#00,#00,#00,#00,#32
        defb #88,#00,#00,#00,#00,#11,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00
        defb #32,#88,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_poltergeist4_507D:
        ; Sprite "poltergeist4" (6x21 octets/ligne, 126 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 76,79.
        defb #06,#15,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#11
        defb #C4,#00,#00,#00,#00,#32,#E2,#00,#00,#00,#00,#11,#C4,#00,#88,#22
        defb #00,#00,#88,#11,#C4,#75,#00,#00,#00,#32,#E2,#F8,#88,#00,#11,#11
        defb #C4,#75,#00,#00,#32,#88,#88,#22,#00,#11,#11,#00,#00,#00,#00,#32
        defb #88,#00,#00,#88,#00,#74,#C4,#11,#11,#C4,#00,#32,#88,#32,#BA,#E2
        defb #00,#11,#00,#74,#D5,#C4,#00,#00,#00,#F8,#E2,#88,#00,#00,#00,#74
        defb #C4,#00,#00,#00,#11,#32,#88,#00,#00,#00,#32,#99,#00,#00,#00,#00
        defb #74,#C4,#00,#00,#00,#00,#32,#88,#00,#00,#00,#00,#11,#00,#00,#00
        defb #00
sprite_poltergeist1_50FE:
        ; Sprite "poltergeist1" (6x23 octets/ligne, 138 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 75,7A.
        defb #06,#17,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #88,#00,#00,#00,#00,#11,#C4,#00,#88,#00,#00,#00,#88,#11,#C4,#00
        defb #00,#00,#00,#32,#E2,#22,#00,#00,#11,#74,#F1,#75,#00,#00,#32,#BA
        defb #E2,#22,#00,#11,#74,#D5,#C4,#00,#00,#32,#BA,#88,#88,#88,#00,#74
        defb #D5,#11,#11,#C4,#00,#F8,#E2,#32,#BA,#E2,#00,#74,#C4,#74,#F4,#F1
        defb #00,#32,#88,#F8,#F2,#E2,#00,#11,#11,#F0,#F1,#C4,#00,#00,#00,#F8
        defb #E2,#88,#00,#00,#00,#74,#C4,#00,#00,#00,#11,#32,#88,#00,#00,#00
        defb #32,#99,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#00,#00,#00,#88
        defb #00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88,#00
sprite_poltergeist2_518B:
        ; Sprite "poltergeist2" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 74,7B,85,A2,A6.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#11
        defb #C4,#00,#88,#00,#00,#32,#E2,#11,#C4,#00,#00,#11,#C4,#32,#E2,#22
        defb #00,#00,#99,#74,#F1,#75,#00,#00,#32,#F8,#F0,#F8,#88,#11,#74,#F4
        defb #F1,#75,#00,#32,#F8,#F2,#E2,#22,#00,#74,#F4,#D5,#C4,#00,#00,#F8
        defb #F2,#88,#88,#88,#00,#F0,#F1,#00,#11,#C4,#00,#F8,#E2,#11,#32,#E2
        defb #00,#74,#C4,#32,#99,#C4,#88,#32,#88,#74,#C4,#99,#C4,#11,#00,#32
        defb #88,#00,#88,#00,#11,#11,#00,#00,#00,#00,#32,#88,#00,#00,#00,#00
        defb #74,#C4,#00,#00,#00,#00,#32,#88,#00,#88,#00,#00,#11,#00,#99,#C4
        defb #00,#00,#00,#11,#F6,#E2,#00,#00,#00,#00,#99,#C4,#00,#00,#00,#00
        defb #00,#88,#00
sprite_poltergeist5_521E:
        ; Sprite "poltergeist5" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 71,73,7C,7E,84,A1,A3,A5,A7,B9.
        defb #06,#18,#00,#00,#88,#75,#00,#00,#00,#11,#C4,#F8,#88,#00,#88,#32
        defb #F3,#F0,#C4,#33,#C4,#74,#F9,#F8,#88,#75,#88,#32,#E2,#75,#88,#F8
        defb #88,#11,#C4,#33,#D5,#F0,#C4,#00,#88,#32,#F2,#F0,#E2,#00,#11,#11
        defb #D5,#F0,#C4,#11,#32,#CC,#88,#F8,#88,#32,#99,#EA,#00,#75,#00,#74
        defb #C4,#55,#00,#22,#00,#F8,#E2,#32,#88,#88,#00,#74,#F5,#74,#D5,#C4
        defb #88,#32,#AA,#F8,#E2,#99,#C4,#11,#11,#F0,#F1,#32,#E2,#00,#11,#F8
        defb #F3,#11,#C4,#00,#32,#FC,#F6,#88,#88,#00,#74,#F6,#99,#00,#00,#00
        defb #F8,#F3,#00,#88,#00,#00,#74,#C4,#11,#C4,#00,#00,#32,#88,#BA,#E2
        defb #00,#00,#11,#11,#F4,#F1,#00,#00,#00,#00,#BA,#E2,#00,#00,#00,#00
        defb #11,#C4,#00
sprite_poltergeist3_52B1:
        ; Sprite "poltergeist3" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 6F,70,72,7D,7F,83,A0,A4,B8,BB.
        defb #06,#18,#00,#11,#C4,#00,#00,#00,#88,#32,#E2,#22,#00,#11,#C4,#74
        defb #F1,#75,#88,#32,#E2,#F8,#F0,#BB,#C4,#11,#C4,#74,#F1,#32,#E2,#22
        defb #88,#32,#F3,#74,#F1,#75,#00,#11,#F6,#F8,#F0,#F8,#88,#00,#FC,#F4
        defb #F1,#75,#00,#00,#F8,#F2,#E2,#AA,#00,#00,#74,#D5,#D5,#C4,#00,#11
        defb #32,#88,#BA,#E2,#00,#32,#BB,#00,#74,#F1,#88,#11,#75,#11,#32,#F3
        defb #C4,#00,#F8,#BA,#99,#F6,#E2,#00,#75,#74,#D5,#FC,#F1,#00,#32,#BA
        defb #BA,#BA,#E2,#00,#74,#D5,#74,#D5,#C4,#00,#F8,#E2,#32,#88,#88,#11
        defb #F0,#F1,#99,#00,#00,#00,#F8,#F3,#C4,#88,#00,#00,#74,#F6,#F3,#C4
        defb #00,#00,#32,#FC,#F0,#E2,#00,#00,#11,#32,#F3,#C4,#00,#00,#00,#11
        defb #C4,#88,#00
sprite_cauldron_down_5344:
        ; Sprite "cauldron_down" (8x33 octets/ligne, 264 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 8D.
        defb #08,#21,#00,#00,#11,#CC,#00,#00,#00,#00,#00,#00,#32,#E2,#11,#CC
        defb #00,#00,#00,#00,#74,#F1,#32,#E2,#77,#00,#00,#00,#74,#F1,#FC,#E2
        defb #F8,#99,#88,#00,#32,#F2,#FC,#F3,#F0,#F6,#C4,#33,#BA,#FE,#F8,#FA
        defb #F0,#F4,#E2,#74,#F7,#F6,#F7,#F5,#F8,#F8,#E2,#F8,#F3,#FA,#FE,#BF
        defb #FD,#F4,#E6,#F8,#F1,#FF,#FF,#FF,#FA,#F9,#FD,#74,#F7,#8F,#0F,#0F
        defb #1F,#FF,#F1,#75,#CF,#0F,#0F,#0F,#0F,#3F,#F1,#33,#0F,#0F,#0F,#0F
        defb #0F,#0F,#F9,#23,#0F,#EF,#0F,#0F,#0F,#0F,#6E,#47,#1F,#EF,#0F,#0F
        defb #0F,#0F,#2E,#47,#3F,#CF,#0F,#0F,#0F,#0F,#2E,#8F,#3F,#8F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#7F,#8F,#0F,#0F,#0F,#0F,#1F,#8F,#7F,#0F,#0F,#0F
        defb #0F,#0F,#1F,#8F,#7F,#0F,#0F,#0F,#0F,#0F,#1F,#47,#7F,#0F,#0F,#1F
        defb #FF,#CF,#2E,#47,#7F,#8F,#0F,#EF,#0F,#3F,#2E,#23,#3F,#8F,#3F,#0F
        defb #0F,#0F,#CC,#23,#1F,#8F,#4F,#0F,#0F,#0F,#2E,#11,#0F,#0F,#8F,#0F
        defb #0F,#0F,#AE,#00,#8F,#1F,#0F,#0F,#0F,#1F,#57,#00,#47,#2F,#0F,#0F
        defb #0F,#2E,#57,#00,#47,#6F,#0F,#0F,#0F,#2E,#57,#00,#47,#6F,#0F,#0F
        defb #0F,#2E,#57,#00,#47,#0F,#00,#00,#0F,#2E,#AE,#00,#8F,#00,#00,#00
        defb #00,#1F,#AE,#11,#0C,#00,#00,#00,#00,#03,#4C,#11,#08,#00,#00,#00
        defb #00,#01,#88,#11,#00,#00,#00,#00,#00,#00,#88
sprite_cauldron_up_544F:
        ; Sprite "cauldron_up" (8x11 octets/ligne, 88 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 8E.
        defb #08,#0B,#00,#00,#00,#00,#FF,#FF,#00,#00,#00,#00,#00,#FF,#AF,#AF
        defb #FF,#00,#00,#00,#33,#9F,#3F,#DF,#EF,#CC,#00,#00,#57,#6F,#DF,#6F
        defb #EF,#6E,#00,#00,#8F,#0F,#2F,#AF,#EF,#9F,#00,#11,#2F,#CF,#AF,#1F
        defb #FF,#0F,#88,#00,#9F,#0F,#4F,#8F,#7F,#9F,#00,#00,#47,#2F,#2F,#0F
        defb #7F,#2E,#00,#00,#33,#0F,#0F,#0F,#0F,#CC,#00,#00,#00,#FF,#0F,#0F
        defb #FF,#00,#00,#00,#00,#00,#FF,#FF,#00,#00,#00
sprite_chest_54AA:
        ; Sprite "chest" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 55.
        defb #08,#1D,#00,#00,#00,#00,#00,#33,#88,#00,#00,#00,#00,#00,#00,#CF
        defb #6E,#00,#00,#00,#00,#00,#33,#2D,#5B,#88,#00,#00,#00,#00,#CF,#A5
        defb #87,#6E,#00,#00,#00,#33,#0F,#78,#0F,#1F,#88,#00,#00,#CF,#C3,#2F
        defb #0F,#0F,#6E,#00,#33,#0F,#C3,#2F,#0F,#0F,#97,#00,#CF,#0F,#C3,#2F
        defb #0F,#0F,#5B,#33,#2D,#0F,#C3,#2F,#0F,#0F,#3D,#47,#69,#0F,#C3,#2F
        defb #0F,#0F,#1F,#AD,#69,#0F,#C3,#2F,#0F,#0F,#1F,#AD,#69,#4F,#C3,#2F
        defb #0F,#0F,#1F,#CB,#69,#6F,#C3,#FF,#8F,#0F,#1F,#8F,#69,#EF,#3F,#4F
        defb #6F,#0F,#1F,#8F,#69,#8F,#CF,#4F,#1F,#8F,#1F,#8F,#69,#3F,#0F,#2F
        defb #0F,#6F,#1F,#8F,#4B,#CF,#C3,#6F,#0F,#1F,#9F,#8F,#3F,#0F,#F1,#9F
        defb #0F,#0F,#5F,#8F,#CF,#0F,#6F,#3F,#8F,#0F,#1F,#BF,#2D,#1F,#F8,#CF
        defb #6F,#0F,#2E,#CF,#78,#6F,#3F,#8F,#1F,#CF,#CC,#47,#3D,#0F,#DE,#C3
        defb #0F,#3F,#00,#47,#7E,#F3,#0F,#F0,#0F,#CC,#00,#23,#9E,#CF,#0F,#3C
        defb #B7,#00,#00,#23,#3F,#E1,#0F,#0F,#CC,#00,#00,#11,#4F,#78,#87,#3F
        defb #00,#00,#00,#00,#8F,#1E,#C3,#CC,#00,#00,#00,#00,#67,#0F,#3F,#00
        defb #00,#00,#00,#00,#11,#FF,#CC,#00,#00,#00,#00
sprite_nail_mat_5595:
        ; Sprite "nail_mat" (8x28 octets/ligne, 224 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 17.
        defb #08,#1C,#00,#00,#00,#00,#11,#88,#00,#00,#00,#00,#00,#00,#67,#6E
        defb #00,#00,#00,#00,#00,#11,#8F,#1F,#88,#00,#00,#00,#00,#67,#1F,#8F
        defb #6E,#00,#00,#00,#11,#8F,#6F,#6F,#1F,#88,#00,#00,#67,#1F,#8F,#1F
        defb #8F,#6E,#00,#11,#8F,#6F,#3E,#C3,#6F,#1F,#88,#67,#1F,#8F,#3E,#C7
        defb #1F,#8F,#6E,#8F,#6F,#79,#3E,#D7,#E3,#6F,#1F,#9F,#8F,#F9,#3E,#D7
        defb #E3,#1F,#9F,#EF,#0F,#F9,#3E,#D7,#E3,#0F,#7F,#8F,#0F,#7D,#3E,#9F
        defb #C7,#0F,#1F,#BE,#E3,#7D,#3E,#9F,#C7,#7C,#D7,#76,#E3,#2F,#3E,#9F
        defb #C7,#7C,#E6,#11,#E3,#0F,#3E,#8F,#8F,#7C,#C4,#11,#E3,#F9,#1F,#0F
        defb #1F,#7C,#C4,#11,#E3,#F9,#0F,#0F,#F9,#7C,#88,#11,#D5,#F9,#3E,#C7
        defb #F9,#FC,#88,#11,#C4,#F9,#3E,#C7,#F9,#32,#88,#11,#C4,#F9,#BE,#D7
        defb #F9,#32,#88,#11,#C4,#EA,#76,#EA,#F9,#32,#88,#11,#C4,#EA,#32,#C4
        defb #75,#11,#00,#00,#88,#EA,#11,#C4,#75,#00,#00,#00,#00,#EA,#11,#C4
        defb #75,#00,#00,#00,#00,#44,#11,#C4,#22,#00,#00,#00,#00,#00,#11,#C4
        defb #00,#00,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#00,#00,#88
        defb #00,#00,#00
sprite_wood_block_5678:
        ; Sprite "wood_block" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 06.
        defb #08,#1D,#00,#00,#00,#33,#88,#77,#00,#00,#00,#00,#00,#47,#7F,#8F
        defb #CC,#00,#00,#00,#00,#FF,#BF,#1F,#66,#00,#00,#00,#11,#7F,#8F,#3F
        defb #1F,#00,#00,#00,#11,#1F,#8F,#3F,#1F,#88,#00,#00,#23,#BF,#8F,#3F
        defb #1F,#6E,#00,#00,#67,#9F,#9F,#EF,#5F,#9F,#88,#33,#9F,#9F,#9F,#EF
        defb #4F,#8F,#4C,#47,#3F,#CF,#DF,#CF,#2F,#CF,#2E,#67,#DF,#8F,#CF,#CF
        defb #3F,#CF,#2E,#9F,#DF,#1F,#8F,#EF,#3F,#CF,#DF,#9F,#DF,#9F,#2F,#EF
        defb #1F,#CF,#DF,#8F,#9F,#BF,#2F,#2F,#1F,#CF,#DF,#DF,#BF,#BF,#0F,#0F
        defb #1F,#9F,#9F,#9F,#3F,#8F,#0F,#0F,#1F,#9F,#9F,#9F,#3F,#0F,#0F,#0F
        defb #0F,#9F,#AE,#8F,#DF,#0F,#0F,#0F,#0F,#1F,#AE,#8F,#CF,#0F,#0F,#0F
        defb #0F,#0F,#AE,#8F,#0F,#0F,#0F,#0F,#0F,#0F,#5F,#47,#0F,#0F,#0F,#0F
        defb #0F,#0F,#1F,#47,#0F,#0F,#0F,#0F,#0F,#0F,#1F,#23,#0F,#0F,#0F,#0F
        defb #0F,#0F,#2E,#11,#0F,#0F,#0F,#0F,#0F,#0F,#2E,#00,#8F,#0F,#0F,#0F
        defb #0F,#0F,#4C,#00,#47,#8F,#0F,#0F,#0F,#1F,#88,#00,#33,#8F,#0F,#0F
        defb #0F,#EE,#00,#00,#00,#47,#8F,#0F,#1F,#00,#00,#00,#00,#33,#47,#3F
        defb #EE,#00,#00,#00,#00,#00,#33,#CC,#00,#00,#00
sprite_firebug1_5763:
        ; Sprite "firebug1" (4x15 octets/ligne, 60 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 56,B0,B4.
        defb #04,#0F,#00,#00,#33,#FF,#00,#00,#47,#C3,#88,#00,#CB,#0F,#4C,#11
        defb #87,#9E,#2E,#33,#97,#1E,#A6,#75,#6B,#CB,#E2,#75,#6B,#F9,#E2,#57
        defb #EB,#BD,#C4,#23,#EB,#F9,#C4,#23,#31,#7B,#AE,#11,#31,#7E,#CC,#11
        defb #F7,#7E,#88,#11,#D5,#DF,#00,#00,#BA,#DF,#00,#00,#11,#22,#00
sprite_firebug2_57A2:
        ; Sprite "firebug2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 57,B1,B5.
        defb #04,#10,#00,#00,#33,#CC,#00,#00,#47,#3F,#88,#00,#8F,#87,#4C,#00
        defb #AF,#4B,#2E,#11,#3F,#E3,#2E,#55,#3F,#E7,#2E,#FB,#5D,#D5,#6E,#EA
        defb #FB,#D5,#FB,#AE,#EA,#DF,#F9,#57,#F1,#17,#E2,#33,#F1,#17,#E2,#23
        defb #F9,#17,#EA,#23,#FD,#17,#EA,#23,#FD,#AE,#75,#11,#7E,#AE,#75,#00
        defb #99,#44,#22
sprite_hud_day_right_57E5:
        ; Sprite "hud_day_right" (8x31 octets/ligne, 248 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 5A.
        defb #08,#1F,#00,#FF,#FF,#EF,#0F,#FF,#FF,#FF,#FF,#FF,#FF,#CF,#EF,#3F
        defb #FF,#FF,#FF,#FF,#FF,#DF,#0F,#0F,#FF,#FF,#FF,#FF,#FF,#CF,#8F,#0F
        defb #1F,#FF,#FF,#FF,#FF,#EF,#0F,#CF,#0F,#1F,#FF,#FF,#FF,#FF,#8F,#BB
        defb #0F,#0F,#0F,#FF,#FF,#FF,#8F,#88,#CF,#0F,#0F,#FF,#FF,#FF,#8F,#88
        defb #33,#CF,#0F,#FF,#FF,#FF,#8F,#88,#00,#33,#FF,#FF,#FF,#FF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#2F,#88,#00,#00,#00,#FF,#FF,#CF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#DF,#8F,#88,#00,#00,#00,#FF,#FF,#FF,#8F,#88
        defb #00,#00,#00,#FF,#FF,#DF,#8F,#88,#00,#00,#00,#FF,#FF,#CF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#2F,#88,#00,#00,#00,#FF,#FF,#FF,#0F,#88
        defb #00,#00,#00,#FF,#FF,#FF,#8F,#88,#00,#00,#00,#FF,#FF,#FF,#8F,#88
        defb #00,#00,#00,#FF,#FF,#EF,#0F,#88,#00,#00,#00,#FF,#FF,#CF,#CF,#88
        defb #00,#00,#00,#FF,#FF,#DF,#0F,#88,#00,#00,#00,#FF,#FF,#CF,#8F,#CC
        defb #00,#00,#00,#00,#00,#01,#6F,#3F,#00,#00,#00,#00,#00,#00,#0F,#0F
        defb #EE,#00,#00,#00,#00,#00,#03,#0F,#1F,#EE,#00,#00,#00,#00,#00,#0F
        defb #0F,#1F,#FF,#00,#00,#00,#00,#01,#0F,#0F,#0F,#00,#00,#00,#00,#00
        defb #03,#0F,#0F,#00,#00,#00,#00,#00,#00,#03,#0F
sprite_hud_day_left_58E0:
        ; Sprite "hud_day_left" (8x31 octets/ligne, 248 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : BA.
        defb #08,#1F,#00,#FF,#FF,#FF,#FF,#0F,#7F,#FF,#FF,#FF,#FF,#FF,#CF,#7F
        defb #3F,#FF,#FF,#FF,#FF,#FF,#0F,#0F,#BF,#FF,#FF,#FF,#FF,#8F,#0F,#1F
        defb #3F,#FF,#FF,#FF,#8F,#0F,#3F,#0F,#7F,#FF,#FF,#0F,#0F,#0F,#DD,#1F
        defb #FF,#FF,#FF,#0F,#0F,#3F,#11,#1F,#FF,#FF,#FF,#0F,#3F,#CC,#11,#1F
        defb #FF,#FF,#FF,#FF,#CC,#00,#11,#1F,#FF,#FF,#FF,#00,#00,#00,#11,#0F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#2F,#7F,#FF,#FF,#00,#00,#00,#11,#0F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#1F,#BF,#FF,#FF,#00,#00,#00,#11,#1F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#1F,#BF,#FF,#FF,#00,#00,#00,#11,#0F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#2F,#7F,#FF,#FF,#00,#00,#00,#11,#0F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#1F,#FF,#FF,#FF,#00,#00,#00,#11,#1F
        defb #FF,#FF,#FF,#00,#00,#00,#11,#0F,#7F,#FF,#FF,#00,#00,#00,#11,#3F
        defb #3F,#FF,#FF,#00,#00,#00,#11,#0F,#BF,#FF,#FF,#00,#00,#00,#33,#1F
        defb #3F,#FF,#FF,#00,#00,#00,#CF,#6F,#08,#00,#00,#00,#00,#77,#0F,#0F
        defb #00,#00,#00,#00,#77,#8F,#0F,#0C,#00,#00,#00,#FF,#8F,#0F,#0F,#00
        defb #00,#00,#00,#0F,#0F,#0F,#08,#00,#00,#00,#00,#0F,#0F,#0C,#00,#00
        defb #00,#00,#00,#0F,#0C,#00,#00,#00,#00,#00,#00
sprite_small_block_59DB:
        ; Sprite "small_block" (8x29 octets/ligne, 232 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch :
        ; 07,36,37,3E,5B,8F,BC,BD,BE,BF.
        defb #08,#1D,#00,#00,#00,#00,#11,#88,#00,#00,#00,#00,#00,#00,#76,#E6
        defb #00,#00,#00,#00,#00,#11,#BD,#F1,#88,#00,#00,#00,#00,#76,#5B,#F0
        defb #E6,#00,#00,#00,#11,#AD,#B5,#F0,#F1,#88,#00,#00,#76,#5A,#5B,#F0
        defb #F0,#E6,#00,#11,#AD,#A5,#B5,#F0,#F0,#F1,#88,#76,#5A,#5A,#5B,#F0
        defb #F0,#F0,#E6,#AD,#A5,#A5,#B5,#F0,#F0,#F0,#F1,#DA,#5A,#5A,#5B,#F0
        defb #F0,#F0,#F1,#AD,#A5,#A5,#B5,#F0,#F0,#F0,#F1,#DA,#5A,#5A,#5B,#F0
        defb #F0,#F0,#F1,#AD,#A5,#A5,#B5,#F8,#F0,#F0,#F1,#DA,#5A,#5A,#6F,#7E
        defb #F0,#F0,#F1,#AD,#A5,#B5,#8F,#1F,#F8,#F0,#F1,#DA,#5A,#6F,#0F,#0F
        defb #7E,#F0,#F1,#AD,#B5,#8F,#0F,#0F,#1F,#F8,#F1,#DA,#6F,#0F,#0F,#0F
        defb #0F,#7E,#F1,#BD,#8F,#0F,#0F,#0F,#0F,#1F,#F9,#EF,#0F,#0F,#0F,#0F
        defb #0F,#0F,#7F,#8F,#0F,#0F,#0F,#0F,#0F,#0F,#1F,#67,#0F,#0F,#0F,#0F
        defb #0F,#0F,#6E,#11,#8F,#0F,#0F,#0F,#0F,#1F,#88,#00,#67,#0F,#0F,#0F
        defb #0F,#6E,#00,#00,#11,#8F,#0F,#0F,#1F,#88,#00,#00,#00,#67,#0F,#0F
        defb #6E,#00,#00,#00,#00,#11,#8F,#1F,#88,#00,#00,#00,#00,#00,#67,#6E
        defb #00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
sprite_door2_5AC6:
        ; Sprite "door2" (6x52 octets/ligne, 312 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 02.
        defb #06,#34,#00,#00,#11,#3F,#00,#00,#00,#00,#76,#8F,#88,#00,#00,#11
        defb #F8,#8F,#4C,#00,#00,#76,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F1,#CF
        defb #4C,#00,#00,#F8,#F6,#BF,#4C,#00,#00,#F9,#F8,#8F,#CC,#00,#00,#FE
        defb #F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F1,#8F,#4C,#00,#00,#F8,#F6,#CF
        defb #CC,#00,#00,#F9,#F8,#8F,#4C,#00,#00,#FE,#F0,#8F,#4C,#00,#00,#F8
        defb #F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00,#00,#F8,#F0,#8F,#4C,#00
        defb #00,#F8,#F0,#EF,#4C,#00,#00,#F8,#F3,#D7,#CC,#00,#00,#F8,#FC,#C7
        defb #2E,#00,#00,#77,#F0,#C7,#2E,#00,#00,#74,#F0,#C7,#2E,#00,#00,#74
        defb #F0,#C7,#1F,#00,#00,#74,#F0,#E3,#1F,#00,#00,#74,#F0,#F7,#FF,#00
        defb #00,#74,#F1,#EB,#0F,#88,#00,#32,#F6,#F1,#0F,#88,#00,#33,#F8,#F1
        defb #0F,#88,#00,#32,#F0,#F1,#0F,#4C,#00,#11,#F0,#F0,#8F,#4C,#00,#11
        defb #F0,#F0,#8F,#EE,#00,#11,#F0,#F0,#F7,#1F,#00,#00,#F8,#F0,#CF,#1F
        defb #00,#00,#F8,#F3,#E3,#0F,#88,#00,#74,#FC,#F1,#0F,#4C,#00,#77,#F0
        defb #F1,#0F,#AE,#00,#32,#F0,#F0,#9F,#2E,#00,#11,#F0,#F0,#E7,#1F,#00
        defb #11,#F0,#F1,#EB,#0F,#00,#00,#F8,#F6,#F1,#0F,#00,#00,#75,#F8,#F0
        defb #8F,#00,#00,#32,#F0,#F0,#C7,#00,#00,#11,#F0,#F0,#E3,#00,#00,#00
        defb #F8,#F0,#F7,#00,#00,#00,#74,#F1,#FC,#00,#00,#00,#32,#F7,#F3,#00
        defb #00,#00,#11,#FC,#CC,#00,#00,#00,#00,#33,#00
sprite_door1_5C01:
        ; Sprite "door1" (4x35 octets/ligne, 140 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 03.
        defb #04,#23,#00,#00,#00,#33,#CC,#00,#00,#FD,#6E,#00,#33,#F1,#1F,#00
        defb #FC,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F1,#1F,#11
        defb #F0,#F1,#1F,#11,#F0,#F3,#DF,#11,#F0,#FD,#3F,#11,#F3,#F1,#1F,#11
        defb #FC,#F1,#1F,#11,#F0,#F1,#1F,#11,#F0,#F3,#DF,#11,#F0,#FD,#3F,#11
        defb #F3,#F1,#1F,#11,#FC,#F1,#1F,#11,#F0,#F1,#9F,#11,#F0,#EF,#7F,#11
        defb #F3,#E3,#1F,#11,#FC,#E3,#2E,#32,#F0,#C7,#2E,#32,#F0,#FF,#2E,#32
        defb #F3,#8F,#CC,#74,#FC,#8F,#4C,#77,#F1,#0F,#88,#F8,#F3,#0F,#88,#F8
        defb #CF,#9F,#00,#F3,#0F,#6E,#00,#CF,#8F,#4C,#00,#8F,#8F,#88,#00,#8F
        defb #5F,#00,#00,#8F,#6E,#00,#00,#9F,#88,#00,#00,#EE,#00,#00,#00
sprite_wall1_5C90:
        ; Sprite "wall1" (4x47 octets/ligne, 188 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0D.
        defb #04,#2F,#00,#44,#00,#00,#00,#BF,#00,#00,#00,#8F,#CC,#00,#00,#8F
        defb #2E,#00,#00,#8F,#1F,#CC,#00,#8F,#1F,#3F,#00,#8F,#1F,#0F,#CC,#8F
        defb #1F,#0F,#3F,#47,#9F,#0F,#1F,#33,#77,#0F,#1F,#00,#9F,#CF,#1F,#00
        defb #8F,#7F,#1F,#00,#8F,#1F,#DF,#00,#47,#0F,#7F,#00,#47,#0F,#1F,#00
        defb #47,#0F,#0F,#00,#47,#0F,#0F,#00,#8F,#0F,#0F,#00,#8F,#0F,#0F,#00
        defb #8F,#0F,#0F,#66,#67,#0F,#0F,#9F,#99,#8F,#0F,#8F,#6E,#EF,#0F,#8F
        defb #1F,#9F,#8F,#8F,#1F,#0F,#7F,#67,#1F,#0F,#1F,#11,#9F,#0F,#1F,#00
        defb #77,#0F,#1F,#00,#11,#0F,#1F,#00,#00,#0F,#1F,#00,#66,#77,#1F,#00
        defb #9F,#47,#FF,#11,#1F,#CF,#3F,#11,#0F,#6F,#1F,#00,#8F,#1F,#9F,#00
        defb #67,#0F,#7F,#00,#57,#8F,#0F,#00,#47,#6F,#0F,#00,#47,#1F,#8F,#00
        defb #23,#0F,#6F,#00,#33,#0F,#1F,#00,#47,#CF,#0F,#00,#47,#3F,#0F,#00
        defb #47,#0F,#8F,#00,#33,#0F,#8F,#00,#00,#CF,#CF,#00,#00,#33,#BB
sprite_wall2_5D4F:
        ; Sprite "wall2" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0E.
        defb #04,#30,#00,#00,#00,#00,#22,#00,#00,#00,#DF,#00,#00,#11,#1F,#00
        defb #00,#FF,#1F,#00,#33,#2F,#1F,#00,#CF,#2F,#1F,#33,#0F,#2F,#1F,#CF
        defb #0F,#2F,#6E,#0F,#0F,#1F,#88,#0F,#0F,#2E,#00,#0F,#0F,#CC,#00,#0F
        defb #3F,#2E,#00,#0F,#CF,#2E,#CC,#3F,#0F,#7F,#2E,#CF,#0F,#CF,#2E,#8F
        defb #3F,#0F,#2E,#8F,#CF,#0F,#2E,#BF,#0F,#0F,#CC,#CF,#0F,#3F,#00,#8F
        defb #0F,#CC,#00,#8F,#3F,#4C,#00,#8F,#CF,#4C,#00,#BF,#0F,#4C,#00,#CF
        defb #0F,#88,#00,#8F,#3F,#00,#22,#0F,#4F,#88,#DF,#1F,#8F,#7F,#1F,#6F
        defb #0F,#4F,#1F,#8F,#0F,#4F,#2E,#0F,#0F,#4F,#CC,#0F,#0F,#7F,#00,#0F
        defb #0F,#CF,#88,#0F,#3F,#8F,#4C,#0F,#EF,#0F,#4C,#BF,#6F,#0F,#4C,#CF
        defb #2F,#0F,#88,#8F,#2F,#1F,#00,#8F,#2F,#7F,#00,#8F,#3F,#DF,#00,#8F
        defb #7F,#0F,#88,#8F,#CF,#0F,#88,#BF,#0F,#0F,#88,#CF,#0F,#0F,#00,#8F
        defb #0F,#1F,#00,#8F,#1F,#6E,#00,#8F,#6E,#88,#00,#9F,#88,#00,#00,#66
        defb #00,#00,#00
sprite_wall3_5E12:
        ; Sprite "wall3" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0F.
        defb #44,#30,#00,#00,#00,#00,#33,#00,#00,#00,#CF,#00,#00,#33,#0F,#00
        defb #00,#CF,#0F,#00,#33,#0F,#0F,#00,#CF,#0F,#0F,#33,#0F,#0F,#0F,#47
        defb #0F,#0F,#0F,#8F,#0F,#0F,#3F,#8F,#0F,#0F,#CF,#8F,#0F,#3F,#8F,#8F
        defb #0F,#CF,#8F,#47,#3F,#0F,#8F,#47,#CF,#0F,#8F,#33,#8F,#0F,#FF,#00
        defb #8F,#1F,#9F,#00,#8F,#6F,#0F,#00,#9F,#8F,#0F,#00,#67,#0F,#0F,#00
        defb #8F,#0F,#0F,#11,#0F,#0F,#0F,#11,#0F,#0F,#0F,#11,#0F,#0F,#0F,#11
        defb #0F,#0F,#1F,#11,#0F,#0F,#7F,#11,#0F,#1F,#9F,#23,#0F,#6F,#1F,#47
        defb #1F,#8F,#1F,#47,#7F,#0F,#1F,#57,#99,#0F,#7F,#22,#11,#1F,#8F,#00
        defb #11,#6F,#0F,#00,#00,#8F,#0F,#00,#77,#0F,#0F,#11,#AF,#0F,#0F,#23
        defb #2F,#0F,#0F,#47,#4F,#0F,#3F,#47,#4F,#0F,#CF,#47,#4F,#3F,#0F,#8F
        defb #4F,#CF,#0F,#8F,#7F,#0F,#0F,#8F,#99,#0F,#0F,#BF,#11,#0F,#0F,#44
        defb #11,#0F,#0F,#00,#11,#0F,#3F,#00,#11,#0F,#CC,#00,#11,#3F,#00,#00
        defb #00,#CC,#00
sprite_wall4_5ED5:
        ; Sprite "wall4" (10x25 octets/ligne, 250 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0A.
        defb #4A,#19,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #00,#00,#11,#88,#CF,#88,#00,#00,#00,#00,#00,#00,#67,#5D,#0F,#88
        defb #00,#00,#00,#00,#00,#11,#8F,#6F,#0F,#88,#00,#00,#00,#00,#66,#67
        defb #0F,#6F,#0F,#88,#00,#00,#00,#11,#9F,#8F,#1F,#EF,#0F,#88,#EE,#00
        defb #00,#67,#1F,#0F,#6F,#6F,#0F,#BB,#1F,#00,#11,#8F,#1F,#1F,#8F,#2F
        defb #0F,#CF,#1F,#00,#67,#0F,#1F,#6F,#0F,#2F,#3F,#0F,#1F,#11,#8F,#0F
        defb #1F,#8F,#0F,#2F,#CF,#0F,#1F,#67,#0F,#0F,#6F,#0F,#0F,#3F,#0F,#0F
        defb #2E,#8F,#0F,#1F,#CF,#0F,#0F,#CF,#0F,#0F,#CC,#8F,#0F,#6F,#8F,#0F
        defb #3F,#0F,#0F,#3F,#00,#8F,#1F,#8F,#8F,#0F,#EF,#0F,#0F,#CC,#00,#8F
        defb #6F,#0F,#8F,#3F,#23,#0F,#3F,#00,#00,#9F,#CF,#0F,#8F,#CC,#23,#0F
        defb #DF,#00,#00,#66,#47,#0F,#BF,#00,#23,#3F,#1F,#00,#00,#00,#47,#0F
        defb #CC,#00,#23,#CF,#1F,#00,#00,#00,#47,#0F,#88,#00,#33,#0F,#2E,#00
        defb #00,#00,#47,#0F,#88,#00,#CF,#0F,#CC,#00,#00,#00,#47,#1F,#00,#11
        defb #0F,#3F,#00,#00,#00,#00,#47,#6E,#00,#23,#0F,#CC,#00,#00,#00,#00
        defb #57,#88,#00,#23,#3F,#00,#00,#00,#00,#00,#22,#00,#00,#23,#CC,#00
        defb #00,#00,#00,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00
sprite_wall5_5FD2:
        ; Sprite "wall5" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0B.
        defb #06,#18,#00,#00,#11,#88,#00,#00,#00,#00,#23,#6E,#00,#00,#00,#00
        defb #23,#1F,#88,#00,#00,#00,#23,#0F,#6E,#00,#00,#00,#11,#0F,#1F,#88
        defb #00,#00,#00,#8F,#0F,#4C,#00,#00,#88,#8F,#0F,#6E,#00,#11,#6E,#47
        defb #0F,#5F,#88,#23,#1F,#CF,#0F,#4F,#4C,#23,#0F,#4F,#0F,#4F,#4C,#11
        defb #0F,#4F,#0F,#4F,#4C,#11,#0F,#6F,#0F,#4F,#4C,#77,#0F,#5F,#8F,#6F
        defb #4C,#9F,#8F,#4F,#6F,#5D,#88,#8F,#6F,#4F,#1F,#CC,#00,#8F,#1F,#CF
        defb #0F,#6E,#00,#47,#0F,#6F,#0F,#1F,#88,#33,#0F,#1F,#8F,#0F,#6E,#00
        defb #CF,#0F,#6F,#0F,#1F,#00,#33,#0F,#2F,#0F,#1F,#00,#00,#CF,#2F,#0F
        defb #1F,#00,#00,#33,#3F,#8F,#1F,#00,#00,#00,#CC,#67,#2E,#00,#00,#00
        defb #00,#11,#CC
sprite_wall6_6065:
        ; Sprite "wall6" (6x18 octets/ligne, 108 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 0C.
        defb #06,#12,#00,#44,#00,#00,#00,#00,#00,#BF,#00,#00,#00,#00,#00,#8F
        defb #CC,#00,#00,#00,#00,#8F,#3F,#00,#00,#00,#00,#8F,#0F,#CC,#33,#00
        defb #00,#8F,#0F,#3F,#47,#CC,#00,#47,#CF,#0F,#CF,#3F,#00,#23,#BF,#0F
        defb #4F,#0F,#CC,#11,#8F,#CF,#4F,#0F,#2E,#00,#8F,#3F,#4F,#0F,#1F,#00
        defb #8F,#0F,#CF,#0F,#1F,#00,#67,#0F,#3F,#0F,#1F,#00,#11,#8F,#0F,#CF
        defb #1F,#00,#00,#67,#0F,#3F,#1F,#00,#00,#11,#8F,#1F,#DF,#00,#00,#00
        defb #67,#1F,#22,#00,#00,#00,#11,#9F,#00,#00,#00,#00,#00,#66,#00
sprite_wood_wall_60D4:
        ; Sprite "wood_wall" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 80.
        defb #04,#30,#00,#FF,#CC,#00,#00,#8F,#2E,#00,#00,#8F,#1F,#77,#00,#CF
        defb #2F,#8F,#88,#CF,#3F,#4F,#CC,#CF,#3F,#CF,#2E,#CF,#2F,#EF,#5F,#EF
        defb #2F,#EF,#4F,#EF,#2F,#EF,#7F,#EF,#2F,#CF,#7F,#EF,#2F,#CF,#3F,#EF
        defb #6F,#4F,#FF,#CF,#6F,#4F,#FF,#CF,#EF,#5F,#FF,#8F,#EF,#0F,#FF,#8F
        defb #FF,#0F,#FF,#8F,#FF,#0F,#FF,#8F,#7F,#0F,#DF,#9F,#3F,#8F,#EF,#8F
        defb #BF,#AF,#6F,#8F,#DF,#8F,#AF,#CF,#6F,#8F,#EF,#CF,#6F,#5F,#DF,#CF
        defb #6F,#3F,#DF,#CF,#7F,#3F,#BF,#CF,#3F,#1F,#BF,#CF,#3F,#1F,#9F,#CF
        defb #3F,#1F,#9F,#EF,#3F,#9F,#9F,#EF,#3F,#8F,#DF,#EF,#1F,#8F,#DF,#FF
        defb #1F,#CF,#DF,#FF,#1F,#CF,#DF,#FF,#1F,#CF,#5F,#FF,#1F,#EF,#5F,#FF
        defb #1F,#6F,#6F,#FF,#3F,#AF,#6F,#FF,#3F,#AF,#7F,#EF,#7F,#BF,#7F,#EF
        defb #7F,#9F,#3F,#EF,#FF,#3F,#BF,#EF,#EF,#7F,#BF,#EF,#EF,#7F,#BF,#DF
        defb #CF,#FF,#BF,#DF,#CF,#FF,#DF,#FF,#DF,#FF,#DF,#FF,#DF,#FF,#DF,#FF
        defb #FF,#FF,#DF
sprite_wood_door2_6197:
        ; Sprite "wood_door2" (4x59 octets/ligne, 236 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 04.
        defb #04,#3B,#00,#CC,#00,#00,#00,#3F,#00,#00,#00,#0F,#88,#00,#00,#1F
        defb #00,#00,#00,#AE,#00,#00,#00,#9F,#00,#00,#00,#9F,#00,#00,#00,#9F
        defb #00,#00,#00,#8F,#88,#00,#00,#CF,#88,#00,#00,#CF,#88,#00,#00,#8F
        defb #88,#00,#00,#9F,#00,#00,#00,#9F,#00,#00,#00,#2E,#00,#00,#00,#2E
        defb #00,#00,#00,#2E,#00,#00,#00,#1F,#00,#00,#00,#8F,#88,#00,#00,#8F
        defb #88,#00,#00,#8F,#4C,#00,#00,#4F,#4C,#00,#00,#4F,#4C,#00,#00,#4F
        defb #4C,#00,#00,#23,#4C,#00,#00,#23,#4C,#00,#00,#23,#4C,#00,#00,#33
        defb #4C,#00,#00,#33,#2E,#00,#00,#23,#2E,#00,#00,#23,#2E,#00,#00,#23
        defb #4C,#00,#00,#47,#6E,#00,#00,#AF,#1F,#00,#00,#BF,#0F,#4C,#00,#9F
        defb #8F,#6E,#00,#9F,#CF,#5F,#00,#8F,#8F,#DF,#00,#0F,#8F,#CF,#88,#9F
        defb #0F,#EF,#5D,#9F,#0F,#EF,#3F,#AF,#1F,#BF,#1F,#AF,#1F,#BF,#9F,#AF
        defb #3F,#9F,#9F,#AF,#3F,#DF,#CF,#BF,#3F,#CF,#CF,#57,#3F,#EF,#EF,#57
        defb #3F,#EF,#7F,#57,#3F,#CF,#EF,#57,#BF,#CF,#EF,#33,#BF,#47,#FF,#11
        defb #AE,#47,#FF,#00,#AE,#57,#BB,#00,#66,#57,#BB,#00,#00,#57,#99,#00
        defb #00,#23,#88,#00,#00,#23,#88,#00,#00,#23,#88,#00,#00,#11,#00
sprite_wood_door1_6286:
        ; Sprite "wood_door1" (4x48 octets/ligne, 192 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 05.
        defb #04,#30,#00,#00,#00,#66,#00,#00,#00,#9F,#88,#00,#33,#2F,#6E,#00
        defb #CF,#8F,#1F,#11,#3F,#3F,#2F,#11,#5F,#7F,#2F,#11,#5F,#3F,#AF,#11
        defb #6F,#3F,#4F,#11,#6F,#1F,#CF,#11,#2F,#5F,#9F,#00,#AF,#5F,#9F,#00
        defb #BF,#5F,#3F,#11,#7F,#5F,#9F,#11,#3F,#1F,#DF,#00,#AF,#1F,#5F,#00
        defb #AF,#1F,#5F,#11,#3F,#1F,#4F,#11,#3F,#9F,#6F,#11,#1F,#AF,#5F,#11
        defb #3F,#2F,#9F,#11,#2F,#5F,#9F,#11,#2F,#AF,#9F,#23,#2F,#6F,#9F,#23
        defb #6F,#5F,#1F,#23,#CF,#DF,#1F,#57,#9F,#BF,#9F,#BF,#3F,#7F,#9F,#7F
        defb #6F,#7F,#9F,#EF,#CF,#FF,#1F,#9F,#8F,#FF,#1F,#3F,#9F,#FF,#1F,#3F
        defb #1F,#FF,#2E,#7F,#1F,#BF,#2E,#7F,#1F,#BF,#1F,#7F,#1F,#BF,#1F,#7F
        defb #1F,#9F,#9F,#7F,#1F,#9F,#9F,#7F,#1F,#8F,#DF,#7F,#0F,#CF,#DF,#3F
        defb #8F,#EF,#5F,#3F,#8F,#6F,#5F,#BF,#47,#6F,#6F,#9F,#22,#3F,#4C,#DF
        defb #11,#3F,#4C,#77,#00,#BF,#4C,#22,#00,#57,#4C,#00,#00,#33,#4C,#00
        defb #00,#00,#88
sprite_hud2_6349:
        ; Sprite "hud2" (4x8 octets/ligne, 32 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 86.
        defb #44,#08,#01,#0C,#00,#00,#00,#03,#00,#00,#00,#00,#0C,#00,#00,#00
        defb #03,#00,#00,#00,#00,#0C,#00,#00,#00,#03,#00,#00,#00,#00,#0C,#00
        defb #00,#00,#03
sprite_scroll2_636C:
        ; Sprite "scroll2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 88.
        defb #44,#10,#01,#0C,#03,#0C,#00,#03,#04,#02,#00,#00,#08,#01,#00,#00
        defb #08,#01,#00,#00,#08,#02,#00,#00,#09,#0E,#00,#00,#0E,#0B,#00,#00
        defb #08,#09,#00,#00,#08,#09,#00,#00,#07,#09,#00,#00,#00,#02,#00,#00
        defb #00,#04,#00,#00,#01,#08,#00,#00,#0E,#00,#00,#03,#00,#00,#00,#0C
        defb #00,#00,#00
sprite_hud1_63AF:
        ; Sprite "hud1" (4x10 octets/ligne, 40 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 87.
        defb #44,#0A,#01,#00,#0F,#0E,#01,#03,#00,#01,#0A,#04,#00,#00,#04,#08
        defb #00,#00,#02,#08,#00,#00,#02,#08,#00,#00,#02,#08,#00,#00,#02,#04
        defb #00,#00,#04,#04,#00,#00,#04,#04,#00,#00,#04
sprite_menu4_63DA:
        ; Sprite "menu4" (4x1 octets/ligne, 4 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : C0.
        defb #44,#01,#01,#02,#00,#00,#08
sprite_scroll1_63E1:
        ; Sprite "scroll1" (4x18 octets/ligne, 72 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : C1.
        defb #44,#12,#01,#02,#00,#00,#04,#04,#00,#00,#04,#04,#00,#00,#04,#04
        defb #00,#00,#04,#04,#00,#00,#02,#04,#01,#0E,#02,#04,#0F,#01,#0A,#09
        defb #01,#00,#06,#0A,#01,#00,#02,#0C,#01,#00,#02,#08,#01,#00,#04,#08
        defb #01,#01,#08,#08,#01,#0E,#00,#08,#00,#00,#03,#04,#00,#00,#06,#02
        defb #00,#00,#08,#01,#08,#07,#00,#00,#07,#08,#00
sprite_hero_up8_642C:
        ; Sprite "hero_up8" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 22,24.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#EE,#00
        defb #00,#00,#EE,#33,#1F,#DF,#88,#33,#1F,#CF,#0F,#4F,#4C,#47,#2F,#2F
        defb #0F,#7F,#4C,#8F,#4F,#2F,#0F,#2F,#88,#9F,#CF,#0F,#0F,#0F,#4C,#66
        defb #23,#0F,#0F,#7F,#88,#00,#11,#0F,#3F,#F8,#88,#00,#00,#8F,#FC,#F0
        defb #C4,#00,#11,#3F,#F0,#F0,#E2,#00,#11,#3E,#F0,#F7,#E2,#00,#00,#FC
        defb #F1,#F8,#C4,#00,#00,#F8,#F6,#F8,#88,#00,#11,#F0,#F8,#F4,#C4,#00
        defb #32,#F1,#F8,#F4,#88,#00,#32,#F1,#F4,#F5,#88,#00,#11,#F1,#F3,#FA
        defb #88,#00,#00,#F9,#F0,#F5,#00,#00,#00,#66,#F8,#EE,#00,#00,#00,#00
        defb #77,#00,#00
sprite_hero_up3_64BF:
        ; Sprite "hero_up3" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 29,2D.
        defb #06,#19,#00,#00,#33,#00,#00,#00,#00,#00,#47,#88,#00,#00,#00,#00
        defb #8F,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #44,#11,#1F,#CF,#7F,#00,#AE,#23,#7F,#0F,#0F,#99,#1F,#23,#8F,#8F
        defb #0F,#EF,#2E,#11,#0F,#8F,#1F,#1F,#4C,#11,#0F,#0F,#1F,#1F,#88,#00
        defb #8F,#0F,#0F,#2E,#00,#00,#47,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up6_6558:
        ; Sprite "hero_up6" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 26.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#FF,#00,#EE,#22
        defb #00,#33,#0F,#BB,#1F,#DF,#00,#47,#1F,#4F,#0F,#5F,#00,#47,#AF,#2F
        defb #0F,#4F,#88,#33,#CF,#2F,#0F,#3F,#4C,#00,#47,#0F,#0F,#0F,#88,#00
        defb #33,#0F,#0F,#0F,#88,#00,#11,#CF,#0F,#1F,#CC,#00,#23,#3F,#8F,#7E
        defb #E2,#00,#23,#4F,#FF,#F8,#F1,#00,#11,#8F,#FE,#F0,#F1,#00,#00,#9F
        defb #F8,#F3,#EA,#00,#00,#76,#F1,#FC,#C4,#00,#00,#F8,#F6,#F4,#E2,#00
        defb #11,#F0,#F8,#F4,#E2,#00,#32,#F1,#F4,#F4,#C4,#00,#32,#F2,#F3,#F2
        defb #C4,#00,#11,#F2,#F1,#FA,#88,#00,#00,#FE,#F0,#F5,#00,#00,#00,#11
        defb #F8,#E2,#00,#00,#00,#00,#77,#CC,#00
sprite_hero_up4_65F1:
        ; Sprite "hero_up4" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 23.
        defb #46,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#33,#88,#00,#00,#00,#00,#47,#6E,#77,#00,#00
        defb #00,#47,#1F,#8F,#EE,#11,#88,#67,#AF,#0F,#1F,#AB,#4C,#57,#EF,#0F
        defb #2F,#4F,#4C,#23,#4F,#0F,#4F,#2F,#2E,#23,#0F,#0F,#0F,#1F,#2E,#11
        defb #EF,#0F,#0F,#2E,#9F,#11,#F1,#CF,#0F,#4C,#9F,#32,#F0,#F3,#1F,#88
        defb #66,#74,#F0,#F0,#CF,#88,#00,#74,#FE,#F0,#C7,#88,#00,#32,#F1,#F8
        defb #F3,#00,#00,#11,#F1,#F6,#F1,#00,#00,#32,#F2,#F1,#F0,#88,#00,#11
        defb #F2,#F1,#F8,#C4,#00,#11,#FA,#F2,#F8,#C4,#00,#11,#F5,#FC,#F8,#88
        defb #00,#00,#FA,#F0,#F9,#00,#00,#00,#77,#F1,#66,#00,#00,#00,#00,#EE
        defb #00,#00,#00
sprite_hero_up9_6684:
        ; Sprite "hero_up9" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 20.
        defb #46,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#11,#CC,#00,#00,#00,#77,#23,#3F
        defb #00,#00,#11,#8F,#EF,#0F,#88,#00,#23,#0F,#9F,#CF,#4C,#00,#47,#0F
        defb #8F,#7F,#4C,#00,#8F,#0F,#8F,#4C,#88,#00,#8F,#0F,#0F,#88,#00,#00
        defb #EF,#0F,#0F,#88,#00,#11,#F1,#CF,#1F,#00,#00,#32,#F0,#F3,#1F,#00
        defb #00,#74,#F0,#F0,#CF,#88,#00,#74,#FE,#F0,#C7,#88,#00,#32,#F1,#F8
        defb #F3,#00,#00,#11,#F1,#F6,#F1,#00,#00,#32,#F2,#F1,#F0,#88,#00,#11
        defb #F2,#F1,#F8,#C4,#00,#11,#FA,#F2,#F8,#C4,#00,#11,#F5,#FC,#F8,#88
        defb #00,#00,#FA,#F0,#F9,#00,#00,#00,#77,#F1,#66,#00,#00,#00,#00,#EE
        defb #00,#00,#00
sprite_hero_up10_6717:
        ; Sprite "hero_up10" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 21,25.
        defb #46,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#66,#77,#00,#EE
        defb #00,#00,#9F,#8F,#BB,#1F,#88,#00,#AF,#0F,#5F,#8F,#4C,#11,#6F,#0F
        defb #4F,#6F,#2E,#00,#8F,#0F,#4F,#3F,#AE,#11,#0F,#0F,#0F,#4C,#44,#00
        defb #EF,#0F,#0F,#88,#00,#11,#F1,#CF,#0F,#88,#00,#32,#F0,#F3,#1F,#00
        defb #00,#74,#F0,#F0,#CF,#88,#00,#74,#FE,#F0,#C7,#88,#00,#32,#F1,#F8
        defb #F3,#00,#00,#11,#F1,#F6,#F1,#00,#00,#32,#F2,#F1,#F0,#88,#00,#11
        defb #F2,#F1,#F8,#C4,#00,#11,#FA,#F2,#F8,#C4,#00,#11,#F5,#FC,#F8,#88
        defb #00,#00,#FA,#F0,#F9,#00,#00,#00,#77,#F1,#66,#00,#00,#00,#00,#EE
        defb #00,#00,#00
sprite_conkers2_67AA:
        ; Sprite "conkers2" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 58.
        defb #04,#10,#00,#00,#32,#88,#00,#22,#32,#88,#44,#75,#77,#CC,#EA,#32
        defb #FC,#F3,#C4,#11,#F8,#F1,#88,#11,#F0,#F0,#88,#32,#F0,#F0,#F7,#FE
        defb #F0,#F0,#F4,#F2,#F0,#F0,#F7,#FE,#F0,#F0,#C4,#33,#F0,#F0,#88,#11
        defb #F8,#F1,#88,#32,#FC,#F3,#C4,#75,#33,#CC,#EA,#22,#11,#C4,#44,#00
        defb #11,#C4,#00
sprite_sphere_67ED:
        ; Sprite "sphere" (4x16 octets/ligne, 64 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 59.
        defb #04,#10,#00,#00,#33,#CC,#00,#00,#FC,#F3,#00,#11,#F0,#F2,#88,#32
        defb #F0,#FC,#C4,#74,#F1,#F0,#E2,#74,#F2,#F0,#E2,#F8,#F1,#FC,#F1,#F8
        defb #F0,#F4,#F1,#F8,#F0,#F4,#F1,#F8,#F1,#F8,#F1,#74,#FA,#F1,#E2,#74
        defb #FD,#F3,#E2,#32,#F1,#F0,#C4,#11,#F0,#FC,#88,#00,#FC,#F3,#00,#00
        defb #33,#CC,#00
sprite_hero_up11_6830:
        ; Sprite "hero_up11" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 28.
        defb #06,#19,#00,#00,#11,#CC,#00,#00,#00,#00,#23,#2E,#00,#00,#00,#00
        defb #47,#4C,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#00,#8F,#BB,#88,#00
        defb #00,#11,#0F,#CF,#7F,#00,#88,#11,#3F,#8F,#0F,#99,#4C,#00,#CF,#4F
        defb #0F,#AB,#2E,#11,#0F,#4F,#1F,#4F,#4C,#11,#0F,#0F,#1F,#2F,#88,#00
        defb #8F,#0F,#0F,#3F,#00,#00,#47,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up5_68C9:
        ; Sprite "hero_up5" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2B.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #CC,#00,#00,#00,#00,#11,#2E,#00,#00,#00,#66,#23,#2E,#33,#88,#00
        defb #9F,#23,#6E,#CF,#7F,#33,#1F,#47,#7F,#0F,#0F,#CF,#2E,#47,#8F,#0F
        defb #0F,#AF,#4C,#57,#0F,#8F,#1F,#1F,#88,#23,#0F,#0F,#1F,#0F,#88,#23
        defb #0F,#0F,#0F,#1F,#00,#11,#8F,#0F,#EF,#2E,#00,#00,#4F,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up12_6962:
        ; Sprite "hero_up12" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2A,2C.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#66,#00,#00,#00,#00,#00
        defb #9F,#00,#00,#00,#00,#11,#1F,#00,#00,#00,#66,#23,#2E,#33,#88,#11
        defb #9F,#23,#2E,#CF,#7F,#23,#1F,#23,#7F,#0F,#0F,#CF,#1F,#47,#9F,#0F
        defb #0F,#AF,#6E,#33,#0F,#8F,#1F,#1F,#88,#23,#0F,#0F,#1F,#0F,#88,#11
        defb #0F,#0F,#0F,#1F,#00,#00,#8F,#0F,#EF,#2E,#00,#00,#EB,#3F,#FF,#C4
        defb #00,#11,#F7,#BF,#9F,#EA,#00,#11,#F7,#FF,#9F,#FD,#00,#00,#FB,#EF
        defb #AF,#FE,#88,#00,#75,#EF,#4F,#FF,#C4,#00,#FA,#F7,#FF,#FF,#C4,#00
        defb #F9,#F9,#FF,#FC,#88,#00,#75,#F6,#F0,#F3,#00,#00,#75,#F1,#FF,#CC
        defb #00,#00,#32,#F8,#F8,#88,#00,#00,#11,#F5,#F1,#00,#00,#00,#00,#FA
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_hero_up7_69FB:
        ; Sprite "hero_up7" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 27.
        defb #06,#18,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#EE,#22
        defb #00,#00,#EE,#33,#1F,#DF,#88,#33,#1F,#CF,#0F,#4F,#4C,#47,#2F,#2F
        defb #0F,#7F,#4C,#8F,#4F,#2F,#0F,#2F,#88,#9F,#CF,#3F,#CF,#0F,#4C,#66
        defb #23,#7F,#FF,#CF,#88,#00,#11,#F8,#F0,#D7,#00,#00,#11,#F3,#F8,#E2
        defb #00,#00,#11,#F4,#FE,#F1,#00,#00,#11,#F8,#F9,#F0,#88,#00,#11,#F1
        defb #F0,#F8,#C4,#00,#11,#F2,#F1,#F4,#C4,#00,#11,#F2,#F2,#F4,#E2,#00
        defb #11,#F0,#F4,#F2,#E2,#00,#00,#FA,#F8,#F2,#E2,#00,#00,#FB,#F1,#F2
        defb #E2,#00,#00,#75,#F6,#FC,#C4,#00,#00,#32,#F1,#F0,#88,#00,#00,#11
        defb #FF,#FF,#00
sprite_hero_up1_6A8E:
        ; Sprite "hero_up1" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2F.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #47,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #44,#11,#1F,#CF,#7F,#00,#AE,#23,#7F,#0F,#0F,#99,#1F,#23,#8F,#8F
        defb #0F,#EF,#2E,#11,#0F,#8F,#1F,#1F,#4C,#11,#0F,#0F,#1F,#1F,#88,#00
        defb #8F,#0F,#0F,#3F,#00,#00,#47,#0F,#EF,#3E,#88,#00,#EB,#3F,#FF,#7E
        defb #88,#11,#F7,#FF,#FF,#FE,#88,#32,#FF,#7F,#FF,#FD,#00,#75,#DF,#5F
        defb #FF,#FA,#88,#75,#CF,#9F,#FF,#F4,#88,#75,#FF,#FF,#FC,#F8,#88,#32
        defb #FF,#FE,#F3,#F4,#88,#11,#F0,#F1,#FC,#F5,#00,#00,#FD,#FE,#F2,#EA
        defb #00,#00,#32,#F3,#F1,#C4,#00,#00,#11,#F0,#FC,#88,#00,#00,#00,#FC
        defb #F2,#00,#00,#00,#00,#33,#CC,#00,#00
sprite_hero_up2_6B27:
        ; Sprite "hero_up2" (6x25 octets/ligne, 150 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 2E.
        defb #06,#19,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #47,#88,#00,#00,#00,#00,#8F,#88,#00,#00,#00,#11,#1F,#33,#88,#00
        defb #00,#23,#1F,#CF,#7F,#11,#88,#23,#EF,#8F,#0F,#EF,#4C,#33,#0F,#8F
        defb #0F,#8F,#2E,#23,#0F,#4F,#1F,#4F,#4C,#11,#0F,#0F,#1F,#3F,#88,#00
        defb #CF,#0F,#0F,#2E,#00,#11,#E7,#0F,#EF,#4C,#00,#11,#F7,#0F,#FF,#CC
        defb #00,#00,#FB,#9F,#FF,#FF,#00,#00,#75,#FF,#FF,#8F,#88,#00,#FA,#FF
        defb #FF,#4F,#88,#00,#F9,#F3,#FF,#3F,#C4,#00,#F8,#FC,#F7,#FF,#C4,#00
        defb #F8,#F3,#F8,#F7,#C4,#00,#75,#F1,#F7,#F8,#88,#00,#75,#F2,#F2,#F7
        defb #00,#00,#32,#FA,#FC,#88,#00,#00,#11,#F7,#F1,#00,#00,#00,#00,#F8
        defb #E6,#00,#00,#00,#00,#77,#88,#00,#00
sprite_feet1_6BC0:
        ; Sprite "feet1" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 10,90.
        defb #46,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #77,#00,#00,#00,#00,#00,#8F,#CC,#00,#00,#00,#00,#8F,#3F,#00,#66
        defb #00,#00,#8F,#0F,#88,#9F,#CC,#00,#FF,#8F,#99,#0F,#2E,#00,#47,#4F
        defb #99,#0F,#1F,#00,#23,#7F,#CC,#EF,#1F,#00,#11,#DD,#E2,#9F,#2E,#00
        defb #76,#F2,#F1,#9F,#CC,#00,#F8,#F4,#F0,#9F,#00,#00,#F8,#F8,#F0,#D7
        defb #00,#00,#74,#F8,#F0,#A6,#00,#00,#74,#F0,#F0,#CC,#00,#00,#74,#80
        defb #F3,#00,#00
sprite_feet2_6C23:
        ; Sprite "feet2" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 11,15,91,95.
        defb #46,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#33,#00,#00,#00,#11,#CC,#47,#EE,#00,#00,#23,#3F,#8F,#1F
        defb #00,#00,#23,#0F,#8F,#0F,#88,#00,#23,#0F,#7F,#0F,#88,#00,#11,#1F
        defb #4F,#9F,#00,#00,#11,#7E,#CF,#EE,#00,#00,#11,#FC,#C7,#88,#00,#00
        defb #32,#F4,#E3,#88,#00,#00,#74,#F8,#F1,#88,#00,#00,#74,#F8,#F0,#C4
        defb #00,#00,#74,#F8,#F0,#88,#00,#00,#74,#F0,#F1,#00,#00,#00,#74,#80
        defb #E2,#00,#00
sprite_feet3_6C86:
        ; Sprite "feet3" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 12,14,92,94.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
        defb #00,#EF,#4C,#00,#00,#00,#11,#0F,#2E,#00,#00,#00,#23,#0F,#2E,#00
        defb #00,#00,#23,#1F,#DF,#00,#00,#00,#11,#2F,#5F,#00,#00,#00,#11,#CF
        defb #9F,#00,#00,#00,#23,#9F,#EE,#00,#00,#00,#23,#BF,#F1,#88,#00,#00
        defb #11,#FC,#F0,#CC,#00,#00,#11,#F8,#F0,#EA,#00,#00,#11,#F0,#F0,#EA
        defb #00,#00,#00,#F8,#F0,#EA,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #10,#E2,#00
sprite_feet4_6CE9:
        ; Sprite "feet4" (6x16 octets/ligne, 96 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 13,93.
        defb #46,#10,#00,#00,#00,#66,#00,#00,#00,#00,#00,#9F,#88,#00,#00,#00
        defb #11,#0F,#6E,#00,#00,#00,#11,#2F,#1F,#00,#00,#00,#00,#FF,#1F,#00
        defb #00,#00,#00,#9F,#EE,#00,#00,#00,#00,#47,#FF,#00,#00,#00,#00,#23
        defb #4F,#CC,#00,#00,#00,#FF,#4F,#2E,#00,#00,#11,#F1,#EF,#2E,#00,#00
        defb #33,#F0,#D7,#CC,#00,#00,#75,#F0,#E3,#88,#00,#00,#75,#F0,#E1,#88
        defb #00,#00,#75,#F0,#F1,#C4,#00,#00,#76,#F0,#F1,#C4,#00,#00,#74,#80
        defb #F2,#88,#00
sprite_feet5_6D4C:
        ; Sprite "feet5" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 18,98.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#33,#88,#00,#00,#00,#00,#CF,#4C,#00,#77,#00,#33,#0F
        defb #4C,#11,#8F,#88,#47,#0F,#4C,#23,#0F,#88,#8F,#2F,#88,#47,#1F,#00
        defb #47,#DD,#00,#8F,#FF,#00,#23,#4C,#00,#9F,#0F,#EE,#FF,#2E,#00,#67
        defb #3F,#F9,#F1,#DF,#00,#11,#FC,#F1,#F0,#E2,#00,#11,#F0,#F0,#F8,#E2
        defb #00,#00,#F8,#F0,#F8,#C4,#00,#00,#F8,#F0,#F8,#C4,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet6_6DB5:
        ; Sprite "feet6" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 19,1D,99,9D.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#EE,#00,#EE,#00,#00,#33,#1F,#33,#1F
        defb #00,#00,#47,#1F,#CF,#1F,#00,#00,#8F,#3F,#0F,#1F,#00,#11,#0F,#DD
        defb #0F,#EE,#00,#11,#3F,#88,#FF,#00,#00,#00,#CF,#7F,#9F,#00,#00,#00
        defb #23,#FC,#FE,#88,#00,#00,#77,#F0,#F8,#C4,#00,#00,#F8,#F0,#F8,#C4
        defb #00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet7_6E1E:
        ; Sprite "feet7" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1A,1C,9A,9C.
        defb #06,#11,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#33,#00,#00,#00,#00,#00,#CF,#88,#00,#00,#00,#33,#0F,#7F,#88
        defb #00,#00,#47,#0F,#4F,#4C,#00,#00,#47,#3F,#8F,#4C,#00,#00,#57,#CF
        defb #2F,#4C,#00,#00,#23,#4F,#7F,#88,#00,#00,#23,#7F,#AE,#00,#00,#00
        defb #11,#FC,#EE,#00,#00,#00,#32,#F0,#F9,#00,#00,#00,#74,#F0,#F9,#00
        defb #00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_feet8_6E87:
        ; Sprite "feet8" (6x17 octets/ligne, 102 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 1B,9B.
        defb #06,#11,#00,#00,#00,#00,#66,#00,#00,#00,#00,#11,#9F,#00,#00,#00
        defb #00,#67,#0F,#88,#00,#00,#00,#8F,#0F,#88,#00,#00,#11,#0F,#1F,#00
        defb #00,#00,#11,#1F,#EE,#00,#00,#00,#00,#AF,#88,#00,#00,#00,#33,#4F
        defb #4C,#00,#00,#00,#47,#2F,#4C,#00,#00,#00,#47,#FF,#2E,#00,#00,#00
        defb #57,#F0,#CC,#00,#00,#00,#32,#F0,#E2,#00,#00,#00,#32,#F0,#F5,#00
        defb #00,#00,#74,#F0,#F5,#00,#00,#00,#74,#F0,#F8,#88,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#32,#C0,#70,#88,#00
sprite_menu1_6EF0:
        ; Sprite "menu1" (2x24 octets/ligne, 48 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 8B.
        defb #02,#18,#00,#00,#00,#00,#00,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#00
        defb #00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#0F,#00
        defb #00,#00,#00
sprite_menu3_6F23:
        ; Sprite "menu3" (6x1 octets/ligne, 6 octets de bitmap). Type(s) d'entite
        ; associe(s) via tbl_sprite_dispatch : 8A.
        defb #06,#01,#00,#03,#0C,#00,#00,#03,#0C
sprite_menu2_6F2C:
        ; Sprite "menu2" (8x30 octets/ligne, 240 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 89.
        defb #88,#1E,#00,#00,#00,#01,#0F,#00,#00,#00,#03,#00,#00,#03,#0F,#08
        defb #00,#00,#07,#00,#00,#07,#0F,#0C,#00,#00,#0F,#00,#00,#0F,#0B,#0E
        defb #00,#01,#0F,#00,#01,#0F,#01,#0F,#00,#03,#0E,#00,#03,#0E,#00,#0F
        defb #08,#07,#0C,#00,#07,#0C,#00,#07,#0C,#0F,#08,#00,#0F,#08,#00,#03
        defb #0D,#0F,#00,#01,#0F,#00,#00,#01,#0B,#0E,#00,#03,#0E,#00,#00,#00
        defb #07,#0C,#00,#03,#0C,#00,#00,#00,#0F,#08,#00,#03,#08,#00,#00,#01
        defb #0F,#06,#00,#03,#0C,#00,#00,#03,#0E,#0F,#00,#03,#0E,#00,#00,#07
        defb #0C,#0F,#08,#01,#0F,#00,#00,#0F,#08,#07,#0C,#00,#0F,#08,#01,#0F
        defb #00,#03,#0E,#00,#07,#0C,#03,#0E,#00,#01,#0F,#00,#03,#0E,#07,#0C
        defb #00,#00,#0F,#00,#01,#0F,#07,#08,#00,#00,#07,#00,#00,#0F,#0B,#00
        defb #00,#00,#03,#00,#00,#07,#0C,#00,#00,#00,#00,#00,#00,#03,#0E,#00
        defb #00,#00,#00,#00,#00,#0D,#0F,#00,#00,#00,#00,#00,#01,#0E,#0F,#08
        defb #00,#00,#00,#00,#03,#0E,#07,#0C,#00,#00,#00,#00,#07,#0C,#03,#0E
        defb #00,#00,#00,#00,#0F,#08,#01,#0F,#00,#00,#00,#01,#0F,#00,#00,#0F
        defb #08,#00,#00,#03,#0E,#00,#00,#07,#0C,#00,#00,#03,#0C,#00,#00,#03
        defb #0C,#00,#00
sprite_werewulf_up6_701F:
        ; Sprite "werewulf_up6" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 40.
        defb #06,#1D,#00,#00,#00,#11,#88,#00,#00,#00,#00,#32,#C4,#00,#00,#00
        defb #00,#74,#EA,#00,#00,#00,#00,#75,#44,#00,#00,#00,#00,#F9,#00,#00
        defb #00,#00,#00,#F8,#88,#00,#00,#00,#00,#F8,#88,#00,#00,#00,#00,#74
        defb #C4,#00,#00,#00,#00,#74,#E2,#00,#00,#00,#00,#32,#F2,#E2,#00,#00
        defb #00,#74,#F2,#E2,#00,#00,#00,#F8,#F4,#E2,#00,#00,#11,#F0,#F8,#F3
        defb #00,#00,#11,#F1,#F0,#F2,#00,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf1_70D0:
        ; Sprite "werewulf1" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 41,45.
        defb #06,#1D,#00,#00,#00,#33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00
        defb #00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00,#00,#11,#F1,#00,#00
        defb #00,#00,#11,#F1,#00,#00,#00,#00,#11,#F0,#88,#00,#00,#00,#00,#F8
        defb #88,#00,#00,#00,#00,#F8,#C4,#00,#00,#00,#00,#F8,#F4,#E2,#00,#00
        defb #00,#F8,#F4,#F3,#00,#00,#00,#F8,#F8,#F2,#88,#00,#11,#F1,#F0,#F2
        defb #88,#00,#11,#F0,#F0,#F2,#C4,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up2_7181:
        ; Sprite "werewulf_up2" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 42,44.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #74,#88,#00,#00,#00,#00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00
        defb #00,#00,#F9,#00,#00,#00,#00,#00,#F8,#CC,#00,#00,#00,#00,#74,#E2
        defb #00,#00,#00,#00,#32,#F1,#00,#00,#00,#00,#11,#F0,#F8,#F2,#88,#00
        defb #11,#F0,#F8,#F2,#C4,#00,#11,#F1,#F0,#F2,#C4,#00,#11,#F1,#F0,#F2
        defb #C4,#00,#11,#F0,#F0,#F1,#C4,#00,#32,#F0,#F0,#F0,#C4,#00,#32,#F0
        defb #F0,#F0,#C4,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up8_7232:
        ; Sprite "werewulf_up8" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 43.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#32,#88,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#F9,#CC,#00,#00,#00,#00,#F8,#F3,#CC
        defb #00,#00,#CC,#74,#F0,#E2,#00,#11,#E2,#33,#F0,#F1,#F0,#F2,#F1,#00
        defb #FE,#F1,#F0,#F2,#F9,#00,#32,#F2,#F0,#F3,#F9,#00,#32,#F2,#F0,#F1
        defb #F1,#00,#32,#F0,#F0,#F1,#E2,#00,#32,#F0,#F0,#F0,#E2,#00,#33,#F0
        defb #F0,#F0,#E2,#00,#11,#F8,#F0,#F0,#C4,#00,#11,#F7,#F0,#F1,#88,#00
        defb #11,#F6,#F0,#F0,#88,#00,#32,#F0,#F8,#F0,#88,#00,#32,#F2,#F8,#F0
        defb #88,#00,#11,#F4,#F4,#F0,#88,#00,#00,#F8,#F4,#F0,#88,#00,#00,#F8
        defb #F8,#F0,#88,#00,#11,#F1,#F0,#F1,#00,#00,#11,#E2,#FF,#F1,#00,#00
        defb #00,#CC,#11,#E2,#00,#00,#00,#00,#11,#C4,#00,#00,#00,#00,#00,#88
        defb #00
sprite_werewulf_up3_72E3:
        ; Sprite "werewulf_up3" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4B.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#22,#00,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#FC,#88,#00
        defb #00,#00,#11,#F0,#88,#00,#00,#00,#32,#F1,#00,#11,#00,#00,#74,#E2
        defb #00,#32,#88,#00,#F8,#C4,#00,#32,#C4,#11,#F0,#F8,#F0,#F6,#C4,#11
        defb #F0,#F8,#F0,#F4,#C4,#11,#F0,#F8,#F0,#F4,#88,#00,#F8,#F8,#F0,#F5
        defb #00,#00,#F8,#F8,#F0,#E6,#00,#00,#F8,#F0,#F1,#CC,#00,#00,#F8,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up7_739A:
        ; Sprite "werewulf_up7" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4A,4C.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00
        defb #11,#C4,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#F9,#00,#00
        defb #00,#00,#11,#F1,#00,#00,#00,#00,#76,#E2,#00,#11,#00,#00,#F8,#C4
        defb #00,#32,#88,#11,#F0,#88,#00,#33,#C4,#32,#F1,#F0,#F0,#F7,#E2,#74
        defb #F1,#F0,#F0,#F6,#E2,#32,#F1,#F0,#F0,#F4,#C4,#32,#F0,#F8,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F7,#00,#11,#F0,#F0,#F1,#CC,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#11,#F0,#F1,#F5,#E6,#00,#00,#F9,#FE,#F5,#FD,#00,#00
        defb #76,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up9_7451:
        ; Sprite "werewulf_up9" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 49,4D.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#32,#C4,#00,#00
        defb #00,#00,#32,#C4,#00,#00,#88,#00,#32,#C4,#00,#11,#C4,#00,#74,#C4
        defb #00,#00,#EA,#00,#F8,#88,#00,#00,#EA,#11,#F1,#F0,#F0,#F7,#E2,#32
        defb #F3,#F0,#F0,#F4,#E2,#74,#F3,#F0,#F0,#F4,#C4,#74,#F1,#F8,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F7,#00,#32,#F0,#F0,#F1,#CC,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up10_7508:
        ; Sprite "werewulf_up10" (6x30 octets/ligne, 180 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 48.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#66,#00,#00,#00,#CC,#00,#F9,#00,#00,#11
        defb #E2,#00,#74,#88,#00,#00,#F9,#00,#74,#88,#00,#00,#F9,#00,#74,#88
        defb #00,#11,#F1,#00,#F9,#00,#00,#32,#E2,#00,#F9,#F0,#F0,#F4,#C4,#11
        defb #F2,#F0,#F0,#F4,#C4,#11,#F2,#F0,#F0,#F4,#88,#32,#F1,#F0,#F0,#F4
        defb #88,#32,#F0,#F8,#F0,#F4,#88,#32,#F0,#F0,#F1,#FD,#00,#11,#F0,#F0
        defb #FE,#E2,#00,#00,#F8,#F1,#F5,#E6,#00,#00,#75,#FE,#F5,#FD,#00,#00
        defb #32,#F0,#F4,#F1,#00,#00,#32,#F0,#F9,#F5,#00,#00,#32,#F0,#F0,#F1
        defb #00,#00,#32,#F8,#F0,#E2,#00,#00,#11,#F0,#F8,#EA,#00,#00,#11,#F0
        defb #FD,#F9,#00,#00,#32,#F0,#F0,#F2,#88,#00,#32,#F0,#F0,#F4,#88,#00
        defb #74,#F2,#F0,#F8,#88,#00,#74,#DD,#FF,#74,#88,#00,#FB,#00,#00,#33
        defb #C4,#00,#44,#00,#00,#00,#88
sprite_werewulf_up4_75BF:
        ; Sprite "werewulf_up4" (6x29 octets/ligne, 174 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 46.
        defb #46,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#CC,#00,#00
        defb #00,#00,#11,#E2,#00,#00,#00,#00,#32,#F9,#00,#00,#00,#00,#11,#F9
        defb #00,#00,#00,#00,#11,#F9,#00,#00,#00,#00,#76,#E2,#00,#00,#00,#00
        defb #F8,#C4,#00,#00,#00,#11,#F0,#88,#00,#00,#FC,#F1,#F1,#00,#00,#11
        defb #F4,#F1,#F1,#00,#00,#11,#F4,#F1,#F0,#88,#00,#32,#F4,#F1,#F0,#88
        defb #00,#32,#F8,#F0,#F0,#88,#00,#32,#F0,#F0,#F0,#88,#00,#32,#F0,#F0
        defb #F0,#CC,#00,#11,#F0,#F0,#F3,#E2,#00,#00,#FC,#F0,#F0,#E2,#00,#00
        defb #F8,#F0,#F3,#EE,#00,#00,#F8,#F0,#F1,#75,#00,#00,#F8,#F0,#F8,#F9
        defb #00,#00,#F8,#F0,#F4,#F0,#88,#00,#F8,#F0,#F4,#F2,#88,#00,#F8,#F0
        defb #F3,#F9,#00,#00,#74,#F0,#E2,#66,#00,#00,#32,#F3,#E2,#00,#00,#00
        defb #32,#E2,#EA,#00,#00,#00,#11,#E2,#44,#00,#00,#00,#00,#CC,#00,#00
        defb #00
sprite_werewulf_up11_7670:
        ; Sprite "werewulf_up11" (6x29 octets/ligne, 174 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 47.
        defb #06,#1D,#00,#00,#00,#00,#00,#00,#00,#00,#33,#00,#00,#00,#00,#00
        defb #74,#88,#00,#00,#00,#00,#F9,#C4,#00,#00,#00,#00,#F9,#88,#00,#00
        defb #00,#00,#F9,#00,#00,#00,#00,#00,#F9,#00,#00,#00,#00,#00,#F8,#88
        defb #00,#00,#00,#00,#F8,#C4,#00,#00,#00,#00,#74,#F2,#F0,#F2,#88,#00
        defb #32,#F2,#F0,#F2,#C4,#00,#32,#F2,#F0,#F2,#C4,#00,#32,#F2,#F0,#F2
        defb #E2,#00,#32,#F2,#F0,#F0,#E2,#00,#32,#F0,#F0,#F0,#E2,#00,#11,#F0
        defb #F0,#F0,#E2,#00,#11,#F0,#F0,#F0,#C4,#00,#00,#FE,#F0,#F1,#CC,#00
        defb #00,#74,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74,#F0,#F0
        defb #E6,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74,#F0,#F0,#F1,#00,#00,#74
        defb #F0,#F0,#E6,#00,#00,#74,#F0,#F0,#88,#00,#00,#74,#7F,#F8,#88,#00
        defb #00,#32,#C4,#F8,#88,#00,#00,#11,#C4,#75,#00,#00,#00,#00,#88,#11
        defb #00
sprite_werewulf_up12_7721:
        ; Sprite "werewulf_up12" (6x30 octets/ligne, 180 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 4E.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#22,#00,#00,#00,#00
        defb #00,#75,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#FC,#88,#00
        defb #00,#00,#11,#F0,#88,#00,#00,#00,#32,#F1,#00,#11,#00,#00,#74,#E2
        defb #00,#32,#88,#00,#F8,#C4,#00,#32,#C4,#11,#F0,#F8,#F0,#F6,#C4,#11
        defb #F0,#F8,#F0,#F4,#C4,#11,#F0,#F8,#F0,#F4,#88,#00,#F8,#F8,#F0,#F1
        defb #00,#00,#F8,#F0,#F0,#F1,#00,#00,#74,#F0,#F0,#F7,#CC,#00,#74,#F0
        defb #F0,#F8,#E2,#00,#74,#F0,#F3,#F3,#EE,#00,#32,#FF,#FC,#F6,#FD,#00
        defb #11,#F0,#F0,#F6,#FD,#00,#11,#F0,#F1,#F8,#F1,#00,#11,#F0,#F0,#F1
        defb #F5,#00,#11,#F0,#F0,#F0,#E2,#00,#00,#F8,#F2,#F0,#CC,#00,#00,#F8
        defb #F3,#F5,#00,#00,#11,#F0,#F0,#F1,#00,#00,#11,#F0,#F0,#F1,#00,#00
        defb #11,#F0,#F8,#F1,#00,#00,#11,#F1,#FF,#F1,#00,#00,#32,#E6,#00,#FC
        defb #88,#00,#11,#88,#00,#33,#00
sprite_werewulf_up5_77D8:
        ; Sprite "werewulf_up5" (6x30 octets/ligne, 180 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 4F.
        defb #06,#1E,#00,#00,#00,#00,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00
        defb #11,#C4,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#EA,#00,#00
        defb #00,#00,#11,#E2,#00,#00,#00,#00,#32,#E2,#00,#11,#00,#00,#74,#C4
        defb #00,#32,#88,#00,#F8,#88,#00,#32,#C4,#11,#F1,#F0,#F0,#F2,#C4,#11
        defb #F1,#F0,#F0,#F2,#C4,#11,#F1,#F0,#F0,#F2,#C4,#32,#F1,#F0,#F0,#F4
        defb #C4,#32,#F0,#F0,#F0,#F0,#C4,#32,#F0,#FC,#F0,#F0,#88,#32,#F3,#F3
        defb #F0,#F0,#88,#11,#F5,#FE,#FB,#F1,#00,#00,#FC,#F0,#FC,#EE,#00,#00
        defb #74,#F0,#F4,#E2,#00,#00,#74,#FA,#F0,#E2,#00,#00,#32,#F0,#F0,#E2
        defb #00,#00,#32,#F0,#F0,#E2,#00,#00,#11,#F4,#F4,#E2,#00,#00,#11,#F6
        defb #FC,#E2,#00,#00,#11,#F0,#F0,#C4,#00,#00,#32,#F0,#F0,#E2,#00,#00
        defb #32,#F0,#F0,#E2,#00,#00,#32,#F1,#FE,#E2,#00,#00,#32,#E6,#11,#F9
        defb #00,#00,#11,#88,#00,#66,#00
sprite_werewulf_feet8_788F:
        ; Sprite "werewulf_feet8" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 30.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#66,#00,#00,#00,#00,#99,#F9,#00,#00,#33,#11,#F6,#F0
        defb #88,#22,#74,#99,#F0,#F0,#88,#75,#F8,#C4,#F8,#F9,#00,#74,#F0,#C4
        defb #77,#F1,#00,#74,#F2,#C4,#11,#E2,#00,#32,#F4,#88,#DD,#E2,#00,#11
        defb #FC,#BB,#F2,#E2,#00,#00,#74,#FC,#F1,#F1,#00,#00,#74,#F0,#F0,#F8
        defb #88,#00,#32,#F0,#F0,#F8,#88,#00,#11,#F8,#F0,#F1,#00,#00,#00,#74
        defb #F0,#F1,#00
sprite_werewulf_feet6_78F2:
        ; Sprite "werewulf_feet6" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 31,35.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#CC,#00,#00,#00,#00,#99,#E2,#33,#88,#00,#11,#F6,#F1,#FC,#C4
        defb #00,#11,#F0,#F1,#F0,#C4,#00,#11,#F0,#FA,#F0,#C4,#00,#00,#F9,#F2
        defb #F6,#88,#00,#00,#77,#F3,#FC,#88,#00,#00,#11,#F0,#F4,#88,#00,#00
        defb #11,#F0,#F2,#C4,#00,#00,#11,#F0,#F1,#E2,#00,#00,#11,#F0,#F1,#E2
        defb #00,#00,#00,#F8,#F1,#E2,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #F0,#E2,#00
sprite_werewulf_feet9_7955:
        ; Sprite "werewulf_feet9" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 32,34.
        defb #06,#10,#00,#00,#00,#00,#00,#00,#00,#00,#00,#11,#88,#00,#00,#00
        defb #11,#32,#C4,#00,#00,#00,#32,#FC,#E2,#00,#00,#00,#32,#F0,#E2,#00
        defb #00,#00,#32,#F1,#E2,#00,#00,#00,#11,#F2,#F5,#00,#00,#00,#32,#FC
        defb #F9,#00,#00,#00,#32,#F4,#EA,#00,#00,#00,#32,#F8,#F5,#00,#00,#00
        defb #11,#F8,#F3,#00,#00,#00,#00,#F8,#F1,#00,#00,#00,#00,#74,#F0,#CC
        defb #00,#00,#00,#F8,#F0,#EA,#00,#00,#00,#F8,#F0,#E2,#00,#00,#00,#74
        defb #F0,#E2,#00
sprite_werewulf_feet7_79B8:
        ; Sprite "werewulf_feet7" (6x16 octets/ligne, 96 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 33.
        defb #06,#10,#00,#00,#00,#00,#66,#00,#00,#00,#00,#55,#F9,#00,#00,#00
        defb #00,#FA,#F0,#88,#00,#00,#00,#F8,#F4,#88,#00,#00,#00,#74,#F8,#88
        defb #00,#00,#22,#77,#F9,#00,#00,#00,#75,#F9,#F1,#00,#00,#00,#74,#F1
        defb #E2,#00,#00,#00,#74,#F2,#E2,#00,#00,#00,#33,#FA,#F1,#00,#00,#00
        defb #00,#FA,#F0,#88,#00,#00,#11,#F2,#F0,#88,#00,#00,#11,#F4,#F0,#C4
        defb #00,#00,#32,#F4,#F0,#C4,#00,#00,#32,#F4,#F0,#C4,#00,#00,#11,#F4
        defb #F0,#C4,#00
sprite_werewulf_feet1_7A1B:
        ; Sprite "werewulf_feet1" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 38.
        defb #06,#12,#00,#00,#00,#00,#11,#00,#00,#00,#00,#00,#76,#88,#00,#00
        defb #00,#11,#F8,#88,#00,#00,#00,#76,#F0,#00,#00,#00,#00,#F8,#F3,#00
        defb #00,#00,#11,#F0,#CC,#00,#00,#00,#00,#F9,#EA,#00,#00,#00,#00,#F8
        defb #EA,#00,#00,#00,#33,#F4,#C4,#00,#00,#00,#74,#F4,#E2,#00,#00,#00
        defb #74,#F8,#E2,#00,#00,#00,#75,#F0,#E2,#00,#00,#00,#32,#F0,#F5,#00
        defb #00,#00,#74,#F0,#F5,#00,#00,#00,#74,#F0,#F9,#00,#00,#00,#74,#F0
        defb #F0,#88,#00,#00,#74,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet2_7A8A:
        ; Sprite "werewulf_feet2" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 39,3D.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#88,#00,#00,#00,#00,#33,#C4,#88,#00,#00,#00,#FC,#F7,#C4
        defb #00,#00,#33,#F0,#F4,#C4,#00,#00,#74,#F0,#F8,#C4,#00,#00,#F8,#F3
        defb #F1,#88,#00,#00,#74,#FC,#E2,#00,#00,#00,#74,#F4,#C4,#00,#00,#00
        defb #32,#F2,#C4,#00,#00,#00,#32,#F1,#E2,#00,#00,#00,#11,#F1,#F1,#00
        defb #00,#00,#11,#F0,#F8,#88,#00,#00,#32,#F0,#F8,#88,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet4_7AF9:
        ; Sprite "werewulf_feet4" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 3A,3C.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#00,#00,#00,#22,#00,#22,#00,#00,#00,#FD,#11,#FD
        defb #00,#00,#33,#F1,#76,#F1,#00,#00,#FC,#F1,#F8,#F1,#00,#11,#F0,#F2
        defb #F0,#E6,#00,#32,#F0,#FE,#F1,#88,#00,#11,#F1,#99,#E2,#00,#00,#00
        defb #F8,#F7,#F1,#00,#00,#00,#76,#F1,#F0,#88,#00,#00,#11,#F0,#F8,#88
        defb #00,#00,#11,#F0,#F8,#C4,#00,#00,#32,#F0,#F8,#C4,#00,#00,#32,#F0
        defb #F0,#88,#00,#00,#32,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_werewulf_feet5_7B68:
        ; Sprite "werewulf_feet5" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : 3B.
        defb #06,#12,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00
        defb #00,#00,#00,#00,#88,#00,#00,#00,#00,#33,#C4,#00,#11,#00,#00,#FC
        defb #C4,#00,#76,#88,#33,#F0,#C4,#11,#F8,#88,#74,#F1,#88,#32,#F0,#88
        defb #F8,#E6,#00,#74,#F3,#00,#74,#88,#00,#F8,#FF,#00,#32,#C4,#00,#F8
        defb #F0,#88,#32,#E2,#00,#74,#F0,#C4,#74,#E2,#00,#33,#F8,#E2,#F8,#E2
        defb #00,#00,#74,#F1,#F0,#E2,#00,#00,#74,#F1,#F0,#C4,#00,#00,#74,#F0
        defb #F0,#C4,#00,#00,#74,#F0,#F0,#88,#00,#00,#32,#F0,#F0,#88,#00
sprite_herse_7BD7:
        ; Sprite "herse" (6x42 octets/ligne, 252 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 08,09.
        defb #06,#2A,#00,#33,#00,#00,#00,#00,#00,#74,#88,#00,#00,#00,#00,#F8
        defb #88,#00,#00,#00,#00,#76,#C4,#CC,#00,#00,#00,#75,#99,#E2,#00,#00
        defb #00,#74,#BA,#E2,#00,#00,#00,#F8,#99,#F9,#33,#00,#00,#F8,#F7,#E6
        defb #74,#88,#00,#74,#F1,#E2,#F8,#88,#00,#74,#F8,#E2,#76,#C4,#CC,#74
        defb #FE,#F1,#FD,#99,#E2,#F8,#99,#F0,#F4,#BA,#E2,#F8,#F7,#F2,#F0,#99
        defb #F9,#74,#F1,#F3,#F8,#F7,#E6,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1
        defb #FC,#F8,#E2,#F8,#99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74
        defb #F1,#F3,#F8,#F7,#E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8
        defb #E2,#F8,#99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74,#F1,#F3
        defb #F8,#F7,#E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8,#E2,#F8
        defb #99,#F0,#F4,#FE,#F1,#F8,#F7,#F2,#F0,#99,#F1,#74,#F1,#F3,#F8,#F7
        defb #E2,#74,#F8,#E2,#74,#F1,#E2,#74,#FE,#F1,#FC,#F8,#E2,#74,#99,#F0
        defb #F4,#FE,#F1,#32,#11,#F2,#F0,#99,#F1,#11,#11,#F3,#F8,#F7,#E2,#00
        defb #00,#E2,#74,#F1,#E2,#00,#00,#E6,#74,#F8,#E2,#00,#00,#44,#74,#FE
        defb #F1,#00,#00,#00,#74,#99,#F1,#00,#00,#00,#32,#99,#E2,#00,#00,#00
        defb #11,#11,#E2,#00,#00,#00,#00,#00,#EA,#00,#00,#00,#00,#00,#88
sprite_table_7CD6:
        ; Sprite "table" (8x28 octets/ligne, 224 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 54.
        defb #08,#1C,#00,#00,#00,#00,#CC,#00,#00,#00,#00,#00,#00,#11,#E2,#00
        defb #00,#00,#00,#00,#00,#32,#EA,#00,#00,#00,#00,#00,#00,#32,#EA,#00
        defb #00,#00,#00,#00,#CC,#32,#EA,#00,#00,#00,#00,#11,#E2,#32,#EA,#00
        defb #00,#00,#00,#32,#EA,#32,#EA,#00,#00,#33,#00,#32,#EA,#32,#EA,#00
        defb #00,#74,#88,#32,#EA,#32,#EA,#00,#00,#75,#C4,#32,#EA,#33,#EA,#00
        defb #00,#75,#C4,#32,#EA,#67,#6E,#11,#88,#75,#C4,#32,#FB,#9F,#9F,#BA
        defb #C4,#75,#C4,#32,#EF,#6F,#6F,#7F,#C4,#75,#C4,#33,#9F,#8F,#1F,#9F
        defb #CC,#75,#C4,#67,#6F,#0F,#0F,#6F,#6E,#75,#C4,#9F,#8F,#0F,#0F,#1F
        defb #9F,#FD,#C4,#AF,#0F,#0F,#0F,#0F,#6F,#7F,#C4,#8F,#0F,#0F,#0F,#0F
        defb #1F,#9F,#CC,#67,#0F,#0F,#0F,#0F,#0F,#6F,#6E,#11,#8F,#0F,#0F,#0F
        defb #0F,#1F,#9F,#00,#67,#0F,#0F,#0F,#0F,#0F,#5F,#00,#11,#8F,#0F,#0F
        defb #0F,#0F,#1F,#00,#00,#67,#0F,#0F,#0F,#0F,#6E,#00,#00,#11,#8F,#0F
        defb #0F,#1F,#88,#00,#00,#00,#67,#0F,#0F,#6E,#00,#00,#00,#00,#11,#8F
        defb #1F,#88,#00,#00,#00,#00,#00,#67,#6E,#00,#00,#00,#00,#00,#00,#11
        defb #88,#00,#00
sprite_frog_statue_7DB9:
        ; Sprite "frog_statue" (6x24 octets/ligne, 144 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 16.
        defb #06,#18,#00,#00,#00,#11,#00,#00,#00,#00,#00,#76,#CC,#00,#00,#00
        defb #11,#F8,#F3,#00,#00,#00,#76,#F0,#F0,#CC,#00,#11,#F8,#F1,#F8,#F3
        defb #00,#76,#F0,#F6,#F6,#F0,#CC,#F8,#F1,#F9,#FF,#F8,#E2,#74,#F6,#E7
        defb #3F,#FE,#F1,#33,#F8,#8F,#4F,#7D,#EA,#11,#F1,#0F,#8F,#7C,#CC,#00
        defb #FB,#0F,#3F,#F9,#00,#00,#47,#CF,#1F,#E6,#00,#00,#8F,#2F,#1F,#CC
        defb #00,#00,#8F,#0F,#2F,#2E,#00,#00,#47,#0F,#8F,#9F,#00,#00,#33,#0F
        defb #3F,#5F,#00,#00,#00,#CF,#7F,#6F,#88,#00,#00,#47,#8F,#0F,#88,#00
        defb #00,#47,#0F,#1F,#00,#00,#00,#47,#CF,#2E,#00,#00,#00,#8F,#CF,#4C
        defb #00,#00,#00,#8F,#0F,#2E,#00,#00,#00,#9F,#EF,#2E,#00,#00,#00,#66
        defb #11,#CC,#00
sprite_conkers1_7E4C:
        ; Sprite "conkers1" (8x25 octets/ligne, 200 octets de bitmap). Type(s)
        ; d'entite associe(s) via tbl_sprite_dispatch : 3F.
        defb #08,#19,#00,#00,#00,#00,#00,#88,#00,#00,#00,#00,#00,#00,#11,#C4
        defb #00,#00,#00,#00,#00,#00,#77,#E6,#22,#00,#00,#00,#00,#33,#8F,#1F
        defb #75,#00,#00,#00,#33,#75,#0F,#0F,#FB,#00,#00,#00,#74,#FE,#CF,#0F
        defb #EA,#00,#00,#00,#32,#9F,#E3,#1F,#D7,#00,#00,#00,#11,#1F,#E3,#0F
        defb #8F,#88,#00,#00,#11,#0F,#CF,#0F,#0F,#EE,#00,#00,#FF,#8F,#0F,#0F
        defb #3F,#F9,#00,#11,#F0,#C7,#0F,#0F,#7C,#E6,#00,#00,#FF,#8F,#3F,#0F
        defb #F9,#CC,#00,#00,#23,#0F,#7C,#0F,#6F,#7F,#00,#00,#23,#0F,#3F,#0F
        defb #0F,#78,#88,#00,#67,#0F,#0F,#0F,#0F,#7F,#00,#00,#F9,#0F,#0F,#0F
        defb #8F,#88,#00,#11,#F7,#3F,#0F,#1F,#C7,#88,#00,#00,#88,#FC,#8F,#0F
        defb #FB,#00,#00,#00,#00,#F9,#0F,#0F,#7D,#00,#00,#00,#11,#E7,#1F,#0F
        defb #7E,#88,#00,#00,#00,#99,#BE,#9F,#99,#00,#00,#00,#00,#11,#F6,#FE
        defb #88,#00,#00,#00,#00,#11,#F6,#99,#C4,#00,#00,#00,#00,#00,#BA,#88
        defb #88,#00,#00,#00,#00,#00,#11,#00,#00,#00,#00
sprite_volcanic_bubble2_7F17:
        ; Sprite "volcanic_bubble2" (6x19 octets/ligne, 114 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : B2,B6.
        defb #06,#13,#00,#00,#00,#33,#EE,#00,#00,#00,#00,#FC,#F1,#88,#00,#00
        defb #11,#F0,#F0,#C4,#00,#00,#32,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1
        defb #00,#00,#F8,#F0,#F0,#F0,#88,#00,#F8,#F0,#F0,#F0,#88,#11,#F0,#F0
        defb #F0,#F0,#C4,#11,#F0,#F0,#F0,#F0,#C4,#11,#F3,#F0,#F0,#F0,#C4,#11
        defb #F3,#F0,#F0,#F0,#C4,#11,#F3,#F8,#F0,#F0,#C4,#00,#F9,#FC,#F0,#F0
        defb #88,#00,#F8,#FE,#F0,#F0,#88,#00,#74,#F7,#F8,#F1,#00,#00,#32,#F3
        defb #F8,#E2,#00,#00,#11,#F0,#F0,#C4,#00,#00,#00,#FC,#F1,#88,#00,#00
        defb #00,#33,#EE,#00,#00
sprite_volcanic_bubble1_7F8C:
        ; Sprite "volcanic_bubble1" (6x18 octets/ligne, 108 octets de bitmap).
        ; Type(s) d'entite associe(s) via tbl_sprite_dispatch : B3,B7.
        defb #06,#12,#00,#00,#00,#33,#EE,#00,#00,#00,#11,#FC,#F1,#CC,#00,#00
        defb #32,#F0,#F0,#E2,#00,#00,#74,#F0,#F0,#F1,#00,#00,#F8,#F0,#F0,#F0
        defb #88,#11,#F0,#F0,#F0,#F0,#C4,#11,#F0,#F0,#F0,#F0,#C4,#32,#F0,#F0
        defb #F0,#F0,#E2,#32,#F6,#F0,#F0,#F0,#E2,#32,#F6,#F0,#F0,#F0,#E2,#32
        defb #F3,#F0,#F0,#F0,#E2,#11,#F3,#F8,#F0,#F0,#C4,#11,#F1,#FC,#F0,#F0
        defb #C4,#00,#F8,#FF,#F8,#F0,#88,#00,#74,#F3,#F8,#F1,#00,#00,#32,#F0
        defb #F0,#E2,#00,#00,#11,#FC,#F1,#CC,#00,#00,#00,#33,#EE,#00,#00
        ; non désassemblé
        defb #00,#00,#00,#00,#00
