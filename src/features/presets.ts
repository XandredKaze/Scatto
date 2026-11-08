import type { Preset } from "../config.js";
import { logger } from "../log.js";
import { findChannel, findMix } from "../util/match.js";
import { pctToMul } from "../util/volume.js";
import type { Ctx } from "./context.js";

const log = logger("preset");

/** Applica un preset. Gli errori sui singoli elementi vengono registrati ma non interrompono il resto. */
export async function applyPreset(ctx: Ctx, preset: Preset, label: string): Promise<void> {
  const { wl, obs } = ctx;
  const tasks: Array<Promise<void>> = [];
  const run = (what: string, p: () => Promise<unknown>) =>
    tasks.push(
      p().then(
        () => log.debug(`${label}: ${what}`),
        (err: Error) => log.warn(`${label}: ${what} fallito: ${err.message}`),
      ),
    );

  if (wl.connected) {
    const channels = wl.channels();
    const mixes = wl.mixes();
    for (const [chRef, perMix] of Object.entries(preset.channels)) {
      const ch = findChannel(channels, chRef);
      if (!ch) {
        log.warn(`${label}: canale Wave Link "${chRef}" non trovato (usa "waveobs list" per vedere i nomi)`);
        continue;
      }
      for (const [mixRef, patch] of Object.entries(perMix)) {
        if (mixRef === "*") {
          for (const m of mixes) run(`${ch.name}/${m.name} ${fmt(patch)}`, () => wl.setChannel(ch.id, m.id, patch));
        } else if (mixRef.toLowerCase() === "global") {
          run(`${ch.name} ${fmt(patch)}`, () => wl.setChannel(ch.id, null, patch));
        } else {
          const m = findMix(mixes, mixRef);
          if (!m) {
            log.warn(`${label}: mix "${mixRef}" non trovato`);
            continue;
          }
          run(`${ch.name}/${m.name} ${fmt(patch)}`, () => wl.setChannel(ch.id, m.id, patch));
        }
      }
    }
    for (const [mixRef, patch] of Object.entries(preset.mixes)) {
      const m = findMix(mixes, mixRef);
      if (!m) {
        log.warn(`${label}: mix "${mixRef}" non trovato`);
        continue;
      }
      run(`mix ${m.name} ${fmt(patch)}`, () => wl.setMix(m.id, patch));
    }
  } else if (Object.keys(preset.channels).length || Object.keys(preset.mixes).length) {
    log.warn(`${label}: Wave Link non connesso, parte Wave Link del preset saltata`);
  }

  if (obs.connected) {
    for (const [inputName, p] of Object.entries(preset.obs)) {
      if (p.muted !== undefined) {
        run(`OBS ${inputName} muted=${p.muted}`, () => obs.call("SetInputMute", { inputName, inputMuted: p.muted! }));
      }
      if (p.volume !== undefined) {
        run(`OBS ${inputName} volume=${p.volume}`, () =>
          obs.call("SetInputVolume", { inputName, inputVolumeMul: pctToMul(p.volume!) }),
        );
      }
    }
  }

  await Promise.all(tasks);
  log.info(`applicato preset "${label}"`);
}

function fmt(p: { level?: number; muted?: boolean }): string {
  return [p.level !== undefined ? `level=${p.level}` : "", p.muted !== undefined ? `muted=${p.muted}` : ""]
    .filter(Boolean)
    .join(" ");
}
