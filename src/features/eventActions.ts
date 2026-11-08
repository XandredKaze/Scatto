import { type Config, resolvePreset } from "../config.js";
import { logger } from "../log.js";
import type { Ctx } from "./context.js";
import { applyPreset } from "./presets.js";

const log = logger("eventi");

type EventKey = keyof Config["events"];

const STATE_TO_EVENT: Record<string, { stream?: EventKey; record?: EventKey }> = {
  OBS_WEBSOCKET_OUTPUT_STARTED: { stream: "streamStarted", record: "recordingStarted" },
  OBS_WEBSOCKET_OUTPUT_STOPPED: { stream: "streamStopped", record: "recordingStopped" },
  OBS_WEBSOCKET_OUTPUT_PAUSED: { record: "recordingPaused" },
  OBS_WEBSOCKET_OUTPUT_RESUMED: { record: "recordingResumed" },
};

/** Funzione 4: applica preset quando parte/finisce la diretta o la registrazione. */
export function setupEventActions(ctx: Ctx): void {
  const events = ctx.cfg.events;
  if (Object.keys(events).length === 0) return;

  const fire = (key: EventKey | undefined) => {
    if (!key) return;
    const ref = events[key];
    if (!ref) return;
    log.info(key);
    void applyPreset(ctx, resolvePreset(ctx.cfg, ref), key);
  };

  ctx.obs.onObs("StreamStateChanged", ({ outputState }) => fire(STATE_TO_EVENT[outputState]?.stream));
  ctx.obs.onObs("RecordStateChanged", ({ outputState }) => fire(STATE_TO_EVENT[outputState]?.record));
}
