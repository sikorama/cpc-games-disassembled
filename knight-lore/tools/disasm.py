#!/usr/bin/env python3
"""Standalone disassembler CLI for Knight Lore RE.

Reuses amspirit-lite's z80dis.py (the same disassembler the MCP server's
disassemble/disassemble_range/analyze_code_zones tools wrap). RAM source
is resolved automatically by tools/ram_source.py: the live emulator's
debug web API (127.0.0.1:8765/api/ram) if running, otherwise the static
snapshot extra/dump_ref.bin (see docs/METHODOLOGY.md section 12) — no flag
needed, a message on stderr says which one was actually used. Much
lighter to call in a throwaway script than driving the MCP stdio server,
e.g. for a bulk/exhaustive static search ("which instruction anywhere in
0x0000-0x3FFF references address X", used to find
fn_catalog_randomize_types — see
notes/2026-08-07-object-catalog-randomizer.md).

Usage:
    disasm.py <start_addr_hex> [count]           # linear disasm
    disasm.py <start_addr_hex> - <end_addr_hex>   # range disasm
    disasm.py --raw <addr_hex> <len_dec>          # raw hex dump
"""
import sys, os

sys.path.insert(0, "/var/home/siko/Code/Amspirit/amspirit-lite/tools/mcp-emulator")
import z80dis
from ram_source import fetch_ram


def main():
    args = sys.argv[1:]
    if args and args[0] == "--raw":
        addr = int(args[1], 16)
        length = int(args[2])
        mem = fetch_ram(addr, length)
        chunk = bytes(mem[addr + i] for i in range(length))
        print(chunk.hex())
        return

    start = int(args[0], 16)
    if len(args) >= 3 and args[1] == "-":
        end = int(args[2], 16)
        mem = fetch_ram(0, 65536)
        pc = start
        while pc < end:
            mnem, ops, size = z80dis.decode(mem, pc)
            opcode_hex = bytes(mem[(pc + i) & 0xFFFF] for i in range(size)).hex().upper()
            print(f"{pc:04X}  {opcode_hex:<10} {mnem:<6} {ops}")
            pc += size
        return

    count = int(args[1]) if len(args) > 1 else 32
    mem = fetch_ram(0, 65536)
    pc = start
    for _ in range(count):
        mnem, ops, size = z80dis.decode(mem, pc)
        opcode_hex = bytes(mem[(pc + i) & 0xFFFF] for i in range(size)).hex().upper()
        print(f"{pc:04X}  {opcode_hex:<10} {mnem:<6} {ops}")
        pc += size


if __name__ == "__main__":
    main()
