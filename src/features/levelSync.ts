import { logger } from "../log.js";
import { channelState, effectiveMixId, findChannel } from "../util/match.js";
import { LEVEL_TOLERANCE, mulToPct, pctToMul } from "../util/volume.js";
import { type Ctx, whenBothConnected } from "./context.js";

const log = logger("sync");

interface ObsState {
  level?: number;
  muted?: boolean;
}

/**
 * Funzione 3: sincronizza volume e mute tra un canale Wave Link e una fonte audio OBS.
 * I loop vengono evitati confrontando sempre con l'ultimo stato noto del lato di destinazione.
 */
export function setupLevelSync(ctx: Ctx): void {
  const rules = ctx.cfg.levelSync;
  if (!rules.length) return;
  const obsState = new Map<string, ObsState>();

  const toObs = rules.filter((r) => r.direction !== "obs-to-wavelink");
  const toWl = rules.filter((r) => r.direction !== "wavelink-to-obs");

  /** Stato noto di una fonte OBS (sempre lo stesso oggetto, così le letture in corso vedono gli aggiornamenti). */
  const known = (inputName: string): ObsState => {
    let st = obsState.get(inputName);
    if (!st) obsState.set(inputName, (st = {}));
    return st;
  };

  /** Completa lo stato noto di una fonte OBS leggendolo, senza sovrascrivere valori più recenti. */
  const ensureObsState = async (inputName: string): Promise<ObsState> => {
    const st = known(inputName);
    if (st.level === undefined || st.muted === undefined) {
      const [vol, mute] = await Promise.all([
        ctx.obs.call("GetInputVolume", { inputName }),
        ctx.obs.call("GetInputMute", { inputName }),
      ]);
      st.level ??= mulToPct(vol.inputVolumeMul);
      st.muted ??= mute.inputMuted;
    }
    return st;
  };

  const pushToObs = async (rule: (typeof rules)[number]) => {
    if (!ctx.obs.connected || !ctx.wl.connected) return;
    try {
      const obsSt = await ensureObsState(rule.obsInput);
      const ch = findChannel(ctx.wl.channels(), rule.channel);
      if (!ch) return;
      const st = channelState(ch, ctx.wl.mixes(), rule.mix);
      if (!st) return;
      if (rule.volume && Math.abs((obsSt.level ?? -100) - st.level) > LEVEL_TOLERANCE) {
        obsSt.level = st.level;
        await ctx.obs.call("SetInputVolume", { inputName: rule.obsInput, inputVolumeMul: pctToMul(st.level) });
        log.debug(`WL ${ch.name} -> OBS ${rule.obsInput} volume ${st.level}`);
      }
      if (rule.mute && obsSt.muted !== st.muted) {
        obsSt.muted = st.muted;
        await ctx.obs.call("SetInputMute", { inputName: rule.obsInput, inputMuted: st.muted });
        log.debug(`WL ${ch.name} -> OBS ${rule.obsInput} muted ${st.muted}`);
      }
    } catch (err) {
      log.warn(`OBS "${rule.obsInput}": ${(err as Error).message}`);
    }
  };

  const pushToWl = async (rule: (typeof rules)[number], obs: ObsState) => {
    if (!ctx.wl.connected) return;
    const mixes = ctx.wl.mixes();
    const ch = findChannel(ctx.wl.channels(), rule.channel);
    if (!ch) return;
    const st = channelState(ch, mixes, rule.mix);
    const mixId = effectiveMixId(ch, mixes, rule.mix);
    if (!st || mixId === undefined) return;
    try {
      if (rule.volume && obs.level !== undefined && Math.abs(obs.level - st.level) > LEVEL_TOLERANCE) {
        await ctx.wl.setChannel(ch.id, mixId, { level: obs.level });
        log.debug(`OBS ${rule.obsInput} -> WL ${ch.name} volume ${obs.level}`);
      }
      if (rule.mute && obs.muted !== undefined && obs.muted !== st.muted) {
        await ctx.wl.setChannel(ch.id, mixId, { muted: obs.muted });
        log.debug(`OBS ${rule.obsInput} -> WL ${ch.name} muted ${obs.muted}`);
      }
    } catch (err) {
      log.warn(`Wave Link "${rule.channel}": ${(err as Error).message}`);
    }
  };

  // Wave Link -> OBS
  ctx.wl.on("channelChanged", (ch) => {
    for (const rule of toObs) {
      if (findChannel([ch], rule.channel)) void pushToObs(rule);
    }
  });

  // OBS -> Wave Link
  ctx.obs.onObs("InputVolumeChanged", ({ inputName, inputVolumeMul }) => {
    const level = mulToPct(inputVolumeMul);
    known(inputName).level = level;
    for (const rule of toWl) if (rule.obsInput === inputName) void pushToWl(rule, { level });
  });
  ctx.obs.onObs("InputMuteStateChanged", ({ inputName, inputMuted }) => {
    known(inputName).muted = inputMuted;
    for (const rule of toWl) if (rule.obsInput === inputName) void pushToWl(rule, { muted: inputMuted });
  });

  ctx.obs.on("disconnected", () => obsState.clear());

  // Allineamento iniziale: per "both" e "wavelink-to-obs" vince Wave Link, per "obs-to-wavelink" vince OBS.
  whenBothConnected(ctx, async () => {
    obsState.clear();
    for (const rule of rules) {
      if (rule.direction === "obs-to-wavelink") {
        try {
          const [{ inputVolumeMul }, { inputMuted }] = await Promise.all([
            ctx.obs.call("GetInputVolume", { inputName: rule.obsInput }),
            ctx.obs.call("GetInputMute", { inputName: rule.obsInput }),
          ]);
          const st = Object.assign(known(rule.obsInput), { level: mulToPct(inputVolumeMul), muted: inputMuted });
          await pushToWl(rule, st);
        } catch (err) {
          log.warn(`fonte OBS "${rule.obsInput}" non trovata: ${(err as Error).message}`);
        }
      } else {
        await pushToObs(rule);
      }
    }
    log.info(`sincronizzazione attiva su ${rules.length} regol${rules.length === 1 ? "a" : "e"}`);
  });
}
