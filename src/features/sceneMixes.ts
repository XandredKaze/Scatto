import { resolvePreset } from "../config.js";
import { logger } from "../log.js";
import { type Ctx, whenBothConnected } from "./context.js";
import { applyPreset } from "./presets.js";

const log = logger("scene");

/** Funzione 1: applica un preset Wave Link quando cambia la scena di programma in OBS. */
export function setupSceneMixes(ctx: Ctx): void {
  const conf = ctx.cfg.sceneMixes;
  if (!conf || Object.keys(conf.scenes).length === 0) return;

  const onScene = async (sceneName: string) => {
    const ref = conf.scenes[sceneName] ?? conf.scenes["*"];
    if (!ref) return;
    log.info(`scena "${sceneName}"`);
    await applyPreset(ctx, resolvePreset(ctx.cfg, ref), `scena ${sceneName}`);
  };

  ctx.obs.onObs("CurrentProgramSceneChanged", ({ sceneName }) => void onScene(sceneName));

  if (conf.applyOnConnect) {
    whenBothConnected(ctx, async () => {
      try {
        const { currentProgramSceneName } = await ctx.obs.call("GetCurrentProgramScene");
        await onScene(currentProgramSceneName);
      } catch (err) {
        log.warn(`impossibile leggere la scena corrente: ${(err as Error).message}`);
      }
    });
  }
}
