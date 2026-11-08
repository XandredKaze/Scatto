import { logger } from "../log.js";
import { channelState, findChannel } from "../util/match.js";
import type { Ctx } from "./context.js";

const log = logger("mic");

/**
 * Funzione 2: mostra/nasconde una fonte OBS (es. un'immagine "MIC MUTO")
 * in base allo stato di mute di un canale Wave Link.
 */
export function setupMicIndicators(ctx: Ctx): { refresh: () => Promise<void> } {
  const inds = ctx.cfg.micIndicators;
  const last = new Map<number, boolean>();
  const warned = new Set<string>();

  const warnOnce = (key: string, msg: string) => {
    if (warned.has(key)) return;
    warned.add(key);
    log.warn(msg);
  };

  const setVisible = async (idx: number, visible: boolean) => {
    const ind = inds[idx]!;
    const scenes = ind.scenes ?? (await ctx.obs.call("GetSceneList")).scenes.map((s) => String(s.sceneName));
    let hits = 0;
    await Promise.all(
      scenes.map(async (sceneName) => {
        try {
          const { sceneItemId } = await ctx.obs.call("GetSceneItemId", { sceneName, sourceName: ind.source });
          await ctx.obs.call("SetSceneItemEnabled", { sceneName, sceneItemId, sceneItemEnabled: visible });
          hits++;
        } catch {
          /* la fonte non è in questa scena */
        }
      }),
    );
    if (hits === 0) warnOnce(`src:${idx}`, `fonte OBS "${ind.source}" non trovata in nessuna scena`);
    else log.info(`"${ind.source}" ${visible ? "visibile" : "nascosta"} (${hits} scene)`);
  };

  const refresh = async (force = false) => {
    if (!ctx.wl.connected || !ctx.obs.connected) return;
    const channels = ctx.wl.channels();
    const mixes = ctx.wl.mixes();
    await Promise.all(
      inds.map(async (ind, idx) => {
        const ch = findChannel(channels, ind.channel);
        if (!ch) return warnOnce(`ch:${idx}`, `canale Wave Link "${ind.channel}" non trovato`);
        const st = channelState(ch, mixes, ind.mix);
        if (!st) return warnOnce(`mix:${idx}`, `mix "${ind.mix}" non trovato per "${ind.channel}"`);
        const visible = ind.showWhen === "muted" ? st.muted : !st.muted;
        if (!force && last.get(idx) === visible) return;
        last.set(idx, visible);
        try {
          await setVisible(idx, visible);
        } catch (err) {
          last.delete(idx);
          log.warn(`aggiornamento indicatore fallito: ${(err as Error).message}`);
        }
      }),
    );
  };

  if (inds.length) {
    ctx.wl.on("channelChanged", () => void refresh());
    ctx.wl.on("topologyChanged", () => void refresh());
    ctx.wl.on("connected", () => void refresh(true));
    ctx.obs.on("connected", () => void refresh(true));
    // Nuove scene o fonti aggiunte: riallinea.
    ctx.obs.onObs("SceneItemCreated", () => void refresh(true));
  }
  return { refresh: () => refresh(true) };
}
