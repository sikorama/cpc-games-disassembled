; ============================================================
; ports.equ.asm -- ports d'E/S CPC references par le code (PSG).
; Source : docs/SYMBOLS.md (fn_psg_write_period_low/full), notes/
; 2026-08-07-transformation-sound.md. Memes ports reutilises par le scan
; clavier (multiplexage classique CPC).
; ============================================================

PORT_PSG_SELECT equ     #F700   ; selection du registre PSG courant
PORT_PSG_DATA   equ     #F400   ; ecriture de la donnee du registre selectionne
PORT_PSG_LATCH  equ     #F600   ; latch/octet haut (utilise pour la frequence)
