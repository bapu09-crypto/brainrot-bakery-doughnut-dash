// Entry program for the Brainrot Bakery place (Node 22, standard library only).
// The game is the Rojo project in this directory: build it first with
//   rojo build default.project.json --output game.rbxl
// then run this file. It hands the place in by copying game.rbxl, PLAY.json,
// src/ and screenshots/ into the output directory and writing dossier.json
// there, using the vendored make.fun library.
//
// The grader refuses any output name holding characters outside letters,
// digits, . _ and -, so dotted names (.gitkeep, .DS_Store, .git) are left
// out of src/ and screenshots/ at every depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const root = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// cpSync filter: skip any file or directory whose name starts with a dot.
function keepVisible(path: string): boolean {
  return !basename(path).startsWith('.');
}

function handIn(): void {
  mkdirSync(outputDir, { recursive: true });
  copyFileSync(join(root, 'game.rbxl'), join(outputDir, 'game.rbxl'));
  copyFileSync(join(root, 'PLAY.json'), join(outputDir, 'PLAY.json'));
  cpSync(join(root, 'src'), join(outputDir, 'src'), { recursive: true, filter: keepVisible });
  const shots = join(root, 'screenshots');
  if (existsSync(shots)) {
    cpSync(shots, join(outputDir, 'screenshots'), { recursive: true, filter: keepVisible });
  }
  // The caps mirror the scorer's gate: at most 4 screenshots, each at most
  // 256 KiB, at most 500000 instances, script sources under 8 MiB in all.
  const dossier = buildDossier(outputDir, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  });
  writeFileSync(join(outputDir, 'dossier.json'), dossier);
}

handIn();
