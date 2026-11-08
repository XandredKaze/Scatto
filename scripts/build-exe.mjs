// Crea un eseguibile autonomo (Node "Single Executable Application") per il sistema corrente.
// Su Windows produce release/waveobs.exe: chi lo usa non deve installare Node.js.
import { execFileSync } from "node:child_process";
import { copyFileSync, cpSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";

const win = process.platform === "win32";
const run = (cmd, args) => execFileSync(cmd, args, { stdio: "inherit", shell: win });

rmSync("build", { recursive: true, force: true });
rmSync("release", { recursive: true, force: true });
mkdirSync("build");
mkdirSync("release");

// 1. Un unico file JavaScript con tutte le dipendenze.
run("npx", [
  "esbuild", "src/index.ts", "--bundle", "--platform=node", "--format=cjs", "--target=node22",
  "--outfile=build/waveobs.cjs", "--external:bufferutil", "--external:utf-8-validate", "--log-level=warning",
]);

// 2. Blob SEA e copia dell'eseguibile di Node.
run(process.execPath, ["--experimental-sea-config", "sea-config.json"]);
const exe = join("release", win ? "waveobs.exe" : "waveobs");
copyFileSync(process.execPath, exe);

// 3. Rimuove la firma di node.exe (verrebbe invalidata) e inietta il blob.
if (win) {
  try {
    run("signtool", ["remove", "/s", exe]);
  } catch {
    console.warn("signtool non trovato: firma lasciata (l'exe funziona comunque)");
  }
}
const postjectArgs = [exe, "NODE_SEA_BLOB", "build/sea-prep.blob", "--sentinel-fuse", "NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2"];
if (process.platform === "darwin") postjectArgs.push("--macho-segment-name", "NODE_SEA");
run("npx", ["postject", ...postjectArgs]);
if (process.platform === "darwin") run("codesign", ["--sign", "-", exe]);

// 4. File da distribuire insieme all'exe.
cpSync("obs/waveobs.lua", "release/waveobs.lua");
cpSync("config.example.json", "release/config.example.json");
cpSync("LEGGIMI.txt", "release/LEGGIMI.txt");
console.log(`\nPronto: ${exe}`);
