import { readFileSync } from "node:fs";
import { z } from "zod";

const patch = z
  .object({
    level: z.number().min(0).max(100).optional(),
    muted: z.boolean().optional(),
  })
  .strict();

/**
 * Un preset descrive uno stato audio da applicare.
 *  channels: { "<canale>": { "<mix>" | "*" | "global": { level?, muted? } } }
 *  mixes:    { "<mix>": { level?, muted? } }
 *  obs:      { "<fonte audio OBS>": { volume?: 0..100, muted? } }
 */
export const presetSchema = z
  .object({
    channels: z.record(z.string(), z.record(z.string(), patch)).default({}),
    mixes: z.record(z.string(), patch).default({}),
    obs: z
      .record(
        z.string(),
        z.object({ volume: z.number().min(0).max(100).optional(), muted: z.boolean().optional() }).strict(),
      )
      .default({}),
  })
  .strict();

const presetRef = z.union([z.string(), presetSchema]);

export const configSchema = z
  .object({
    obs: z
      .object({
        url: z.string().default("ws://127.0.0.1:4455"),
        password: z.string().optional(),
      })
      .default({ url: "ws://127.0.0.1:4455" }),
    wavelink: z
      .object({
        host: z.string().default("127.0.0.1"),
        port: z.number().int().positive().optional(),
      })
      .default({ host: "127.0.0.1" }),
    logLevel: z.enum(["debug", "info", "warn", "error"]).default("info"),

    presets: z.record(z.string(), presetSchema).default({}),

    /** Funzione 1: preset da applicare quando OBS passa a una scena. "*" = scene non elencate. */
    sceneMixes: z
      .object({
        applyOnConnect: z.boolean().default(true),
        scenes: z.record(z.string(), presetRef).default({}),
      })
      .optional(),

    /** Funzione 2: mostra/nasconde fonti OBS in base al mute di un canale Wave Link. */
    micIndicators: z
      .array(
        z
          .object({
            channel: z.string(),
            mix: z.string().optional(),
            source: z.string(),
            scenes: z.array(z.string()).optional(),
            showWhen: z.enum(["muted", "unmuted"]).default("muted"),
          })
          .strict(),
      )
      .default([]),

    /** Funzione 3: sincronizza volume/mute tra un canale Wave Link e una fonte audio OBS. */
    levelSync: z
      .array(
        z
          .object({
            channel: z.string(),
            mix: z.string().optional(),
            obsInput: z.string(),
            direction: z.enum(["both", "wavelink-to-obs", "obs-to-wavelink"]).default("both"),
            volume: z.boolean().default(true),
            mute: z.boolean().default(true),
          })
          .strict(),
      )
      .default([]),

    /** Funzione 4: preset da applicare su eventi OBS. */
    events: z
      .object({
        streamStarted: presetRef.optional(),
        streamStopped: presetRef.optional(),
        recordingStarted: presetRef.optional(),
        recordingStopped: presetRef.optional(),
        recordingPaused: presetRef.optional(),
        recordingResumed: presetRef.optional(),
      })
      .strict()
      .default({}),
  })
  .strict()
  .superRefine((cfg, ctx) => {
    const check = (ref: unknown, path: (string | number)[]) => {
      if (typeof ref === "string" && !(ref in cfg.presets)) {
        ctx.addIssue({ code: "custom", path, message: `preset "${ref}" non definito in "presets"` });
      }
    };
    for (const [scene, ref] of Object.entries(cfg.sceneMixes?.scenes ?? {})) check(ref, ["sceneMixes", "scenes", scene]);
    for (const [ev, ref] of Object.entries(cfg.events)) check(ref, ["events", ev]);
  });

export type Config = z.infer<typeof configSchema>;
export type Preset = z.infer<typeof presetSchema>;
export type PresetRef = z.infer<typeof presetRef>;

export function parseConfig(data: unknown): Config {
  const res = configSchema.safeParse(data);
  if (!res.success) {
    const lines = res.error.issues.map((i) => `  - ${i.path.join(".") || "(radice)"}: ${i.message}`);
    throw new Error(`Configurazione non valida:\n${lines.join("\n")}`);
  }
  return res.data;
}

export function loadConfig(path: string): Config {
  let text: string;
  try {
    text = readFileSync(path, "utf8");
  } catch {
    throw new Error(`File di configurazione non trovato: ${path} (copia config.example.json in config.json)`);
  }
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch (err) {
    throw new Error(`${path} non è JSON valido: ${(err as Error).message}`);
  }
  return parseConfig(json);
}

export function resolvePreset(cfg: Config, ref: PresetRef): Preset {
  return typeof ref === "string" ? cfg.presets[ref]! : ref;
}
