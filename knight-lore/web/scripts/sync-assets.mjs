#!/usr/bin/env node
// Copie les sorties déjà générées des outils de RE (tools/sprite_dump_out,
// src/data/assets/rooms_manifest.json) vers public/, où Vite peut les
// servir. Ne JAMAIS éditer public/ à la main : ce script fait le pont,
// régénéré à la demande (npm run sync-assets), même philosophie que
// tools/gen_asm.py pour asm/code/ — une source générée, pas une source
// de vérité.
//
// rooms_manifest.json vient d'une COPIE STABLE dans src/data/assets/,
// PAS directement de tools/room_map/out/ : ce dernier est écrasé (pas
// fusionné) à chaque exécution de teleport.py, y compris pour une seule
// salle -- une invocation ponctuelle pendant une session de debug live
// effaçait silencieusement les 127 autres salles pour ce portage web
// (vécu deux fois). La copie stable n'est mise à jour qu'à la main,
// volontairement, après un balayage complet vérifié (`teleport.py --all
// --restore`) :
//   cp tools/room_map/out/rooms_manifest.json web/src/data/assets/rooms_manifest.json
import { cp, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

// `webRoot` = web/ (le portage JS) ; `repoRoot` = la racine du dépôt de RE.
// Les deux sont distincts depuis que le portage a été déplacé dans web/ :
// tools/ reste à la racine (c'est un outil de RE, pas un asset web), alors
// que la copie stable de rooms_manifest.json vit dans le portage.
const webRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const repoRoot = path.dirname(webRoot);

const SPRITE_SRC = path.join(repoRoot, "tools/sprite_dump_out");
const ROOMS_SRC = path.join(webRoot, "src/data/assets/rooms_manifest.json");
const PUBLIC_DIR = path.join(webRoot, "public");

async function main() {
  await rm(path.join(PUBLIC_DIR, "sprites"), { recursive: true, force: true });
  await mkdir(path.join(PUBLIC_DIR, "sprites"), { recursive: true });
  await cp(SPRITE_SRC, path.join(PUBLIC_DIR, "sprites"), {
    recursive: true,
    filter: (src) => !src.endsWith("contact_sheet.png"),
  });

  await mkdir(path.join(PUBLIC_DIR, "rooms"), { recursive: true });
  await cp(ROOMS_SRC, path.join(PUBLIC_DIR, "rooms", "rooms_manifest.json"));

  console.log("assets synced: public/sprites, public/rooms");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
