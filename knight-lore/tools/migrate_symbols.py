#!/usr/bin/env python3
"""Migration ponctuelle de asm/symbols.json vers le nouveau schema
(sans narration d'investigation) + generation de asm/labels.txt.

Ancien schema par symbole : addr, name, kind(fn/tbl), status, desc (prose
libre avec dates/renvois/narration).
Nouveau schema par symbole : addr, name, type(code/data), status, short,
long, + champs techniques inchanges (count, elem_size, literal_bytes,
literal_words, decode_full_range).

Usage : python3 tools/migrate_symbols.py [--apply]
Sans --apply : affiche un rapport (nombre d'entrees, echantillon) sans
rien ecrire. Avec --apply : ecrit asm/symbols.json (nouveau schema) et
asm/labels.txt.
"""
import json
import re
import sys

sys.path.insert(0, "tools")
from clean_symbols_desc import clean, make_short  # noqa: E402
from extract_symbols_md import extract as extract_symbols_md  # noqa: E402

SYMBOLS_MD_DESC = extract_symbols_md()

SPRITE_RE = re.compile(
    r"largeur V=(\d+) octets/ligne, hauteur H=(\d+) lignes.*?"
    r"bitmap (\d+) octets.*?"
    r'"([^"(]+)"(?:\s*\(corrige\s*:\s*"([^"]+)"\))?.*?'
    r"associe\(s\) via tbl_sprite_dispatch\s*:\s*([0-9A-Fa-f,\s]+)\.",
    re.DOTALL,
)

JUNCTION_LONG = (
    "Template d'entite de decor de jonction entre 2 salles (poteau de "
    "porte type #02/#03, ou segment de mur #0A-#0F, etc.), copie via "
    "tbl_room_connections dans le tableau d'entites actives par "
    "fn_instantiate_room_objects. Format : octet0=type d'entite, "
    "octet1=grid_x, octet2=grid_y, octet3=#80 constant (grid_z_or_offset, "
    "PAS un numero de room), octets4-6=bbox/autres champs, octet7=flags "
    "(egal au champ flags de l'entite reelle), octet8=numero de room "
    "courant."
)
JUNCTION_SHORT = "Template de decor de jonction (porte/mur) entre 2 salles."

CONNDETAIL_LONG = (
    "Template d'entite de decor de jonction entre 2 salles : 8 octets "
    "copies tels quels dans tbl_room_connections (sans calcul), "
    "correspondant exactement aux 8 premiers offsets de "
    "struct_entities_base (+0=type, +1=grid_x, +2=grid_y, "
    "+3=grid_z_or_offset, +4=bbox_w, +5=bbox_h, +6=bbox_d, +7=flags). Le "
    "numero de room (+8 de l'entite) est ajoute separement par "
    "fn_load_room_data. N chunks concatenes par bloc, termine par un "
    "chunk dont le 1er octet est #00 (non copie)."
)
CONNDETAIL_SHORT = "Chunk de decor de jonction (8 octets, copie directe)."

# Corrections ponctuelles pour les entrees ou le nettoyage automatique
# laisse un artefact (parenthese orpheline, date residuelle...) -- forcees
# a la main plutot que de complexifier le nettoyeur generique pour des cas
# uniques.
OVERRIDES = {
    "0055": (
        "13 octets (#0055-#0061), script de configuration Gate Array.",
        "13 octets (#0055-#0061) : #0055-#0060 (12 octets, termine par "
        "#FF a #0060) est le script de config Gate Array (mode ecran + "
        "encres) consomme par fn_gate_array_config_stream (#0049), "
        "appele 2 fois avec HL=#0055 depuis le code du menu (#15DC/#15EB). "
        "PAS de l'etat de partie (contrairement au reste de la zone "
        "#0055-00D6, ds/runtime) : fn_mem_fill_simple ne touche jamais "
        "#0055-#0067, donc rien ne le reinitialise. Sans ce terminateur, "
        "la boucle d'ecriture de fn_gate_array_config_stream ne s'arrete "
        "plus normalement. L'octet #0061 suit immediatement le "
        "terminateur ; role exact non trace.",
    ),
    "09BD": (
        "Sous-etape de fn_sound_effect_click_positional.",
        "Sous-etape de fn_sound_effect_click_positional : avance l'index "
        "de lecture dans tbl_sound_chromatic_periods et arme le canal "
        "suivant.",
    ),
    "0A97": (
        "Lecteur de programme sonore PSG 3 canaux, bloquant.",
        "Lecteur de programme sonore PSG 3 canaux, BLOQUANT (busy-wait, "
        "contrairement a fn_sound_engine_tick qui est tickee par IM1). "
        "Appelee pour jouer le jingle de fin de partie. Init : DI, "
        "fn_psg_register_init_stream (HL=#0C36), charge 3 canaux dans des "
        "slots de 7 octets a #1877 (+0/+1=pointeur programme, "
        "+2/+3=compteur de duree, +4=mode de volume courant, "
        "+5/+6=copie du pointeur de depart pour LOOP). Boucle round-robin "
        "sur les 3 canaux : decompte +2/+3, et a 0 appelle "
        "fn_sound_program_step.",
    ),
    "0A9B": (
        "Charge un canal du lecteur de jingle bloquant depuis un pointeur programme.",
        "Charge un canal du lecteur de jingle bloquant (slot de 7 octets "
        "a #1877 + offset canal) depuis un pointeur programme fourni par "
        "l'appelant.",
    ),
    "0AF3": (
        "Etape du lecteur de jingle bloquant : lit et dispatch l'octet de programme suivant.",
        "Appelee quand le compteur de duree d'un canal atteint 0. Sonde "
        "clavier (fn_read_keyboard_row_raw) + joystick "
        "(fn_read_joystick_table) pour permettre d'ecourter le jingle, "
        "lit l'octet suivant du programme du canal, dispatch commande "
        "(RST 28 via tbl_sound_opcode_dispatch) ou note "
        "(fn_sound_note_apply).",
    ),
    "0D80": (
        "Point d'entree alternatif de fn_arm_interrupt_flag : DI puis var_interrupt_sync_flag=0.",
        "Point d'entree alternatif partageant la queue de "
        "fn_arm_interrupt_flag (memes 2 derniers octets) : DI puis XOR A "
        "(au lieu de EI/LD A,1) avant de rejoindre var_interrupt_sync_flag=A ; "
        "RET -- donc var_interrupt_sync_flag=0 avec interruptions coupees, "
        "l'inverse exact de fn_arm_interrupt_flag. Seul appelant : "
        "fn_sound_program_play_blocking.",
    ),
    "0E77": (
        "Variante diagonale 0 de la logique de patrouille ennemie.",
        "Variante diagonale 0 de la logique de patrouille ennemie -- "
        "meme famille que fn_hostile_patrol_logic, direction fixee.",
    ),
    "12B9": (
        "Vecteur de patrouille fixe, orientation 0.",
        "Entree 0 de tbl_guard_patrol_vector_dispatch : vecteur fixe "
        "(+2,0) ou (0,+2) selon l'axe associe a cette orientation.",
    ),
    "12D4": (
        "Vecteur de patrouille fixe, orientation 1.",
        "Entree 1 de tbl_guard_patrol_vector_dispatch : vecteur fixe "
        "pour cette orientation.",
    ),
    "12E1": (
        "Vecteur de patrouille fixe, orientation 2.",
        "Entree 2 de tbl_guard_patrol_vector_dispatch : vecteur fixe "
        "pour cette orientation.",
    ),
    "12EE": (
        "Vecteur de patrouille fixe, orientation 3.",
        "Entree 3 de tbl_guard_patrol_vector_dispatch : vecteur fixe "
        "pour cette orientation.",
    ),
    "137D": (
        "Attend le relachement d'une touche/direction, ou un timeout.",
        "Boucle avec compteur HL=#2000 decroissant, appelle "
        "fn_read_joystick_table (HL=tbl_wait_any_key_all_rows) a chaque "
        "iteration et sort par RET NZ si une touche/direction est "
        "active, sinon decremente HL et boucle jusqu'a expiration. "
        "Utilisee aussi comme entree alternative directe via un jump qui "
        "saute cette attente.",
    ),
    "1802": (
        "Affiche une icone HUD dans un slot (objet ramasse).",
        "Si var_object_notify_flag (#007A) est nul, RET immediat. Sinon "
        "l'efface, et pour 3 slots HUD (tbl_hud_slot_icons a #1877) : "
        "calcule la position ecran du slot, efface l'ancienne icone dans "
        "le buffer intermediaire, dessine la nouvelle si un type est "
        "present dans le slot.",
    ),
    "18AA": (
        "Action \"utiliser l'objet tenu\" (bouton dedie).",
        "Teste var_transform_flag_and_saved_type puis "
        "fn_read_use_object_button ; si le bouton est presse et les "
        "gardes de collision/etat sont satisfaites, declenche l'usage de "
        "l'objet actuellement tenu (boost de hauteur ou depot, selon le "
        "contexte).",
    ),
    "1B43": (
        "Jingle de progression du puzzle de collecte.",
        "Joue le flash de couleur Gate Array synchronise avec le son via "
        "fn_gate_array_config_stream, appelee a chaque etape validee du "
        "puzzle de collecte.",
    ),
    "1F25": (
        "Table de vecteurs signes (paires dx/dy).",
        "8 paires de vecteurs signes (dx,dy), indexees par "
        "fn_signed_step_lookup pour un deplacement aleatoire (fantomes).",
    ),
    "1FF7": (
        "Variante de poteau de porte type A pour le type d'entite 4.",
        "Variante de fn_door_post_type_A specifique au type d'entite 4 "
        "(flag different pose sur l'entite).",
    ),
    "202C": (
        "Poteau de porte type A, variante flag.",
        "Variante de poteau de porte (type A) qui pose un flag "
        "different selon le contexte d'appel.",
    ),
    "2061": (
        "Table de dispatch pour l'ajustement fin de position pres d'une porte.",
        "4 entrees word, dispatch par axe/sens vers "
        "fn_door_fine_adjust_x/y.",
    ),
    "2069": (
        "Ajustement fin de la position Y pres d'une porte.",
        "Corrige la position Y de l'entite pour l'aligner avec le "
        "passage de porte avant le franchissement.",
    ),
    "207C": (
        "Ajustement fin de la position X pres d'une porte.",
        "Corrige la position X de l'entite pour l'aligner avec le "
        "passage de porte avant le franchissement.",
    ),
    "2147": (
        "Resout la direction demandee (input) en vecteur de deplacement joueur.",
        "Lit var_input_result (#007B), resout la direction en vecteur "
        "via un cooldown base sur cooldown_timer.",
    ),
    "22AD": (
        "Applique le vecteur d'avance en attente du joueur.",
        "(ix+09)+=(ix+0E), (ix+0A)+=(ix+0F) (applique un vecteur en "
        "attente), remet +0x0E/+0x0F a 0, puis dispatch (RST 28, table "
        "tbl_player_forward_vector_dispatch) selon fn_get_orientation_code "
        "un pas d'avance +-3 vers (ix+09)/(ix+0A). Meme motif que "
        "fn_resolve_patrol_vector mais pour le joueur, amplitude 3 au "
        "lieu de 2.",
    ),
    "22E4": (
        "Table de vecteurs d'avance fixes pour le joueur, par orientation.",
        "4 entrees, vecteur fixe (+-3,0) ou (0,+-3) selon l'orientation "
        "du joueur.",
    ),
    "2F02": (
        "Resout le pointeur de forme d'une entite et sa hauteur/largeur.",
        "(ix+00)*2 -> pointeur de forme via tbl_sprite_dispatch. Si "
        "premier octet de la forme == 0, double RET (rien a dessiner). "
        "Sinon saute dans fn_flip_sprite_shape. En-tete de "
        "struct_sprite_shape (3 octets) : octet 0 = #00 sentinelle OU "
        "bits0-5 = V (largeur en octets/ligne), bit6/bit7 = etat de "
        "flip ; octet 1 = hauteur en lignes ; octet 2 = non utilise "
        "comme pixel (peek pour un ajustement de decalage sub-octet). "
        "Le payload reel commence a addr+3. Bitmap : 2 bits/pixel, 4 "
        "pixels/octet, V octets/ligne (row_bytes = V directement).",
    ),
    "31E9": (
        "Flip/miroir de sprite en place selon l'orientation de l'entite.",
        "Bit7 = flip VERTICAL (echange de lignes entieres du bitmap) ; "
        "bit6 = flip HORIZONTAL reel (echange d'octets + "
        "fn_mirror_byte_bits par nibble). Si le bit teste differe de "
        "l'orientation courante (marqueur stocke dans l'octet0 de la "
        "forme), inverse ce bit ET mute le bitmap en place -- economie "
        "de memoire cle, une seule forme de base par sprite.",
    ),
    "1AE5": (
        "Avance le puzzle de collecte ordonnee (tresor pose au sol).",
        "Force grid_z=#80 (pose au sol), lit "
        "tbl_pickup_sequence_order[var_pickup_sequence_counter] via "
        "fn_pickup_sequence_lookup, compare a (off_type AND 7) ; si "
        "egal : var_pickup_sequence_counter+=1, joue "
        "fn_pickup_sequence_jingle, et si le compteur atteint 14 appelle "
        "fn_pickup_sequence_complete_transform. Dans tous les cas : "
        "remet var_special_input_mode_2=0, efface le pointeur catalogue "
        "objet, puis reprend l'idle generique.",
    ),
    "1BF3": (
        "Choisit le type transitoire pseudo-aleatoire pendant l'animation de transformation.",
        "Tire un type parmi 0x5C-0x5F pour l'etape courante de "
        "l'animation de transformation jour/nuit du joueur.",
    ),
    "0B98": (
        "8 gestionnaires de commande pour un octet de programme sonore <8.",
        "Octet de programme sonore <8 = commande (via fn_sound_program_step) : "
        "#00-#05 -> fn_sound_cmd_store_param (stocke la valeur brute 0-5 "
        "dans (iy+4) comme mode de volume courant, seuls 0-3 sont surs, "
        "voir tbl_sound_volume_mode_dispatch) ; #06 -> fn_sound_cmd_loop ; "
        "#07 -> fn_sound_cmd_end.",
    ),
    "0DE1": (
        "Sonde generique : une entite solide chevauche-t-elle la position/bbox de IX ?",
        "Reutilise les 3 primitives AABB de fn_check_collisions "
        "(#254F/#2564/#2579), boucle sur les 40 slots (filtre actif + pas "
        "soi-meme), retourne CARRY si trouve. Utilisee par "
        "fn_player_use_held_object (grid_z temporairement +0x0C) pour "
        "valider si un boost de hauteur atterrirait sur un support "
        "solide.",
    ),
    "149C": (
        "8 pointeurs word vers des messages de tbl_game_over_screen_strings_b.",
        "Index 0-14 pair calcule par fn_game_over_screen_sequence a "
        "partir de var_special_input_mode_1 et d'un compteur. Les 8 "
        "valeurs tombent exactement sur les frontieres de segment "
        "(terminateur bit7) de tbl_game_over_screen_strings_b.",
    ),
    "154B": (
        "Affiche le compteur de jour au HUD.",
        "Arme (#172C)/(#173C)=#FF (compteurs d'animation, meme paire que "
        "fn_game_over_screen_sequence), DE=var_day_counter (#007F), B=1, "
        "HL=#91DE (position ecran), puis JP fn_hud_render_bcd_digits.",
    ),
    "15C2": (
        "Ecran de selection du mode de controle (clavier/joystick).",
        "Efface buffer/ecran, remplit #167C-167E via "
        "fn_control_mode_menu_palette_indicator_update, configure le "
        "Gate Array (fn_gate_array_config_stream, HL=#0055), joue un "
        "jingle (fn_sound_program_play_blocking). Lit les lignes clavier "
        "7 et 8 pour mettre a jour bit1 et bit3 de var_input_mode_flag "
        "(mode clavier/joystick). Boucle sur la lecture clavier ligne 4 "
        "(validation) et var_newgame_random_seed (pour l'animation) "
        "avant de relancer la boucle.",
    ),
    "167B": (
        "Bloc de donnees (texte/messages courts du menu, encodage non decode).",
        "Desassemblage lineaire incoherent (valeurs 0x0A-0x26 dominantes, "
        "0x26 frequent, segments termines par un octet >=0x80) -- "
        "signature de donnees, pas de code. L'octet a #167C (2e octet du "
        "bloc) est aussi reutilise comme variable mutable par "
        "fn_control_mode_menu_palette_indicator_update (valeurs #0F/#FF). "
        "Hypothese sur le contenu : messages courts du menu, meme "
        "encodage que tbl_game_over_screen_strings_a. Extent confirmee "
        "par adjacence avec fn_menu_draw_string_reset_font.",
    ),
    "1B76": (
        "Complete la sequence de collecte (14 etapes) : convertit les blocs statiques en ennemis.",
        "Pose var_special_input_mode_1=1 (probable gel de la logique "
        "joueur/HUD), force les slots d'entite 3-13 a type=0x01, puis "
        "convertit tout slot de type 0x07 (bloc statique) en type=0x83 "
        "(fn_hostile_patrol_logic) parmi les slots 3-39 (borne #0537 = "
        "struct_entities_base + 40x28).",
    ),
    "2CBA": (
        "Phase 2 de fn_load_room_data : construit les entites de jonction calculees.",
        "Toujours executee. IY=DE (curseur d'ecriture dans "
        "tbl_room_connections, continue ou la phase 1 s'est arretee). "
        "C=((HL)&7)+1 (nombre d'entites de jonction pour cette "
        "connexion). Boucle : lit un index vers tbl_room_connection_ptrs, "
        "resout un pointeur vers un tbl_room_junction_entity_template_*, "
        "copie type/+4/+5/+6/flags (5 octets directs, PAS grid_x/y/z) "
        "vers l'entite, room_number courant -> +8 ; CALCULE (au lieu de "
        "copier) grid_x/grid_y/grid_z_or_offset a partir d'un 6e octet du "
        "template, du code de direction (registre D) et de "
        "var_room_data_field_2 (#0074) -- contrairement a la PHASE 1 "
        "(tbl_room_connection_detail_*, copie brute avec grid_z_or_offset "
        "constant #80), la phase 2 calcule ce champ. Avance IY de 9 puis "
        "zero-remplit 19 octets de plus (28 au total, meme taille de "
        "slot qu'en phase 1). Si le 7e octet du template (relu) est "
        "non-nul, reboucle pour un 2e sous-bloc de 6 octets dans le meme "
        "enregistrement (explique les templates de 13 octets = 7+6, vs 7 "
        "pour les autres). Puis decompte B (bloc de connexion suivant) "
        "et C (entite suivante de cette connexion).",
    ),
    "2EDC": (
        "Projection isometrique (grid_x,grid_y) -> (screen_x,screen_y).",
        "Projection isometrique (grid_x,grid_y) -> (screen_x,screen_y), "
        "verifiee par calcul numerique exact contre des valeurs reelles "
        "observees.",
    ),
    "33D4": (
        "3 entrees de 3 octets, calibration camera/vue selon le ratio d'aspect de la salle.",
        "Selectionnees par field_byte>>3&0x1F (1er octet du payload de "
        "tbl_room_master_index) dans fn_load_room_data, copiees vers "
        "var_camera_reference/var_camera_reference_y (#0071/#0072) + "
        "var_room_data_field_2 (#0074). Entree 0 = (#40,#40,#80) "
        "defaut/symetrique ; entree 1 = (#20,#40,#80) ref. X divisee par "
        "2, salles plus hautes que larges ; entree 2 = (#40,#20,#80) "
        "ref. Y divisee par 2, salles plus larges que hautes. Le 3e "
        "octet (#80, constant) correspond a grid_z_or_offset 'au sol'.",
    ),
}


def migrate_sprite(desc):
    m = SPRITE_RE.search(desc)
    if not m:
        return None
    v, h, bitmap, name, corrected, types = m.groups()
    final_name = corrected or name
    types = ",".join(t.strip() for t in types.split(","))
    short = f'Sprite "{final_name}"'
    long_ = (
        f'Sprite "{final_name}" ({v}x{h} octets/ligne, {bitmap} octets de '
        f"bitmap). Type(s) d'entite associe(s) via tbl_sprite_dispatch : "
        f"{types}."
    )
    return short, long_


def migrate_one(s):
    addr = s["addr"]
    name = s["name"]
    if addr in OVERRIDES:
        return OVERRIDES[addr]
    if name == "sprite_shape_none":
        return (
            "Sentinelle \"pas de forme\".",
            "Octet #00, teste par fn_resolve_sprite_shape qui fait un "
            "double RET (rien a dessiner). Pointeur par defaut de "
            "tbl_sprite_dispatch pour les types non implementes/reserves.",
        )
    if name.startswith("sprite_"):
        r = migrate_sprite(s["desc"])
        if r:
            return r
    if name.startswith("tbl_room_junction_entity_template"):
        return (JUNCTION_SHORT, JUNCTION_LONG)
    if name.startswith("tbl_room_connection_detail"):
        return (CONNDETAIL_SHORT, CONNDETAIL_LONG)
    # docs/SYMBOLS.md est la source la plus riche/a jour quand elle existe
    # pour cette adresse (le desc de symbols.json y a parfois pris du
    # retard, ex. statut change sans que sa prose ne soit mise a jour) --
    # sinon repli sur le desc de symbols.json (seule source pour la
    # majorite des routines fines jamais montees dans docs/SYMBOLS.md).
    raw = SYMBOLS_MD_DESC.get(addr, s["desc"])
    long_ = clean(raw)
    short_ = make_short(long_)
    return short_, long_


def main():
    apply_ = "--apply" in sys.argv
    d = json.load(open("asm/symbols.json"))

    new_symbols = []
    for s in d["symbols"]:
        short_, long_ = migrate_one(s)
        entry = {
            "addr": s["addr"],
            "name": s["name"],
            "type": "code" if s["kind"] == "fn" else "data",
            "status": s["status"],
            "short": short_,
            "long": long_,
        }
        for k in ("count", "elem_size", "literal_bytes", "literal_words", "decode_full_range"):
            if k in s:
                entry[k] = s[k]
        new_symbols.append(entry)

    new_symbols.sort(key=lambda e: int(e["addr"], 16))

    new_reserved = []
    for r in d.get("reserved_ram_regions", []):
        c = clean(r["comment"])
        new_reserved.append(
            {
                "start": r["start"],
                "end": r["end"],
                "label": r["label"],
                "short": make_short(c),
            }
        )

    new_doc = {
        "hex_prefix": d["hex_prefix"],
        "code_zone_end": d["code_zone_end"],
        "operand_symbols": d["operand_symbols"],
        "reserved_ram_regions": new_reserved,
        "symbols": new_symbols,
    }

    if not apply_:
        print("Symbols:", len(new_symbols))
        import random

        for e in random.sample(new_symbols, 12):
            print("---", e["addr"], e["name"], e["type"], e["status"])
            print("SHORT:", e["short"])
            print("LONG: ", e["long"])
        return

    json.dump(new_doc, open("asm/symbols.json", "w"), indent=2, ensure_ascii=False)

    with open("asm/labels.txt", "w") as f:
        for e in new_symbols:
            f.write(f"{e['addr'].upper()} {e['name']}\n")

    print("Wrote asm/symbols.json (", len(new_symbols), "symbols) and asm/labels.txt")


if __name__ == "__main__":
    main()
