import { describe, expect, it } from "vitest";
import { parseConfig } from "../src/config.js";
import { setupEventActions } from "../src/features/eventActions.js";
import { setupLevelSync } from "../src/features/levelSync.js";
import { setupMicIndicators } from "../src/features/micIndicator.js";
import { applyPreset } from "../src/features/presets.js";
import { setupSceneMixes } from "../src/features/sceneMixes.js";
import { FakeObs, FakeWl, channelsV3, flush, makeCtx, mixesV3 } from "./fakes.js";

describe("config", () => {
  it("segnala preset inesistenti", () => {
    expect(() => parseConfig({ sceneMixes: { scenes: { A: "nope" } } })).toThrow(/preset "nope"/);
  });
  it("accetta un config minimo", () => {
    expect(parseConfig({}).obs.url).toBe("ws://127.0.0.1:4455");
  });
  it("valida il config di esempio", async () => {
    const { readFileSync } = await import("node:fs");
    expect(() => parseConfig(JSON.parse(readFileSync("config.example.json", "utf8")))).not.toThrow();
  });
});

describe("applyPreset", () => {
  it("risolve canali e mix per nome, '*' e 'global'", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    const ctx = makeCtx({}, wl, obs);
    await applyPreset(
      ctx,
      {
        channels: { microfono: { "stream mix": { muted: true } }, Musica: { "*": { level: 10 }, global: { muted: false } } },
        mixes: { "Monitor Mix": { level: 50 } },
        obs: { Desktop: { volume: 50, muted: true } },
      },
      "test",
    );
    expect(wl.calls).toEqual(
      expect.arrayContaining([
        { channelId: "ch-mic", mixId: "mix-str", patch: { muted: true } },
        { channelId: "ch-music", mixId: "mix-mon", patch: { level: 10 } },
        { channelId: "ch-music", mixId: "mix-str", patch: { level: 10 } },
        { channelId: "ch-music", mixId: null, patch: { muted: false } },
        { mixId: "mix-mon", patch: { level: 50 } },
      ]),
    );
    expect(obs.calls.map((c) => c.type)).toEqual(expect.arrayContaining(["SetInputMute", "SetInputVolume"]));
  });
});

describe("sceneMixes", () => {
  it("applica il preset della scena, con fallback '*'", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    const ctx = makeCtx(
      {
        presets: { pausa: { channels: { Microfono: { stream: { muted: true } } } } },
        sceneMixes: { applyOnConnect: false, scenes: { Pausa: "pausa", "*": { channels: { Microfono: { "Stream Mix": { muted: false } } } } } },
      },
      wl,
      obs,
    );
    setupSceneMixes(ctx);
    obs.userEvent("CurrentProgramSceneChanged", { sceneName: "Pausa" });
    await flush();
    expect(wl.chans[0]!.mixes["mix-str"]!.muted).toBe(true);
    obs.userEvent("CurrentProgramSceneChanged", { sceneName: "Altro" });
    await flush();
    expect(wl.chans[0]!.mixes["mix-str"]!.muted).toBe(false);
  });
});

describe("micIndicators", () => {
  it("mostra la fonte nelle scene che la contengono quando il mic è muto", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    obs.scenes = { Gioco: ["Cam", "MicOff"], Pausa: ["Sfondo"], Chat: ["MicOff"] };
    const ctx = makeCtx({ micIndicators: [{ channel: "Microfono", mix: "stream mix", source: "MicOff" }] }, wl, obs);
    const ind = setupMicIndicators(ctx);
    await ind.refresh();
    const enabled = () => obs.calls.filter((c) => c.type === "SetSceneItemEnabled").map((c) => [c.data.sceneName, c.data.sceneItemEnabled]);
    expect(enabled()).toEqual(expect.arrayContaining([["Gioco", false], ["Chat", false]]));
    obs.calls = [];
    await wl.setChannel("ch-mic", "mix-str", { muted: true });
    await flush();
    expect(enabled()).toEqual(expect.arrayContaining([["Gioco", true], ["Chat", true]]));
    expect(enabled()).toHaveLength(2);
    // Un cambio di volume non deve ritoccare OBS.
    obs.calls = [];
    await wl.setChannel("ch-mic", "mix-str", { level: 50 });
    await flush();
    expect(enabled()).toHaveLength(0);
  });
});

describe("levelSync", () => {
  const cfg = { levelSync: [{ channel: "Musica", mix: "Stream Mix", obsInput: "Musica OBS" }] };

  it("Wave Link -> OBS senza loop", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    setupLevelSync(makeCtx(cfg, wl, obs));
    await wl.setChannel("ch-music", "mix-str", { level: 60 });
    await flush();
    expect(obs.inputs["Musica OBS"]!.mul).toBeCloseTo(0.6);
    // L'eco di OBS non deve generare una nuova scrittura su Wave Link.
    expect(wl.calls).toHaveLength(1);
  });

  it("OBS -> Wave Link per volume e mute", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    setupLevelSync(makeCtx(cfg, wl, obs));
    obs.userEvent("InputVolumeChanged", { inputName: "Musica OBS", inputVolumeMul: 0.25, inputVolumeDb: -12 });
    obs.userEvent("InputMuteStateChanged", { inputName: "Musica OBS", inputMuted: true });
    await flush();
    expect(wl.chans[1]!.mixes["mix-str"]).toEqual({ level: 25, muted: true });
    // Nessun rimbalzo verso OBS oltre all'allineamento dei valori già uguali.
    expect(obs.calls.filter((c) => c.type.startsWith("Set"))).toHaveLength(0);
  });

  it("rispetta la direzione wavelink-to-obs", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    setupLevelSync(makeCtx({ levelSync: [{ ...cfg.levelSync[0], direction: "wavelink-to-obs" }] }, wl, obs));
    obs.userEvent("InputVolumeChanged", { inputName: "Musica OBS", inputVolumeMul: 0.9, inputVolumeDb: 0 });
    await flush();
    expect(wl.calls).toHaveLength(0);
  });
});

describe("eventActions", () => {
  it("applica preset su avvio diretta e pausa registrazione", async () => {
    const wl = new FakeWl(channelsV3(), mixesV3());
    const obs = new FakeObs();
    setupEventActions(
      makeCtx(
        {
          presets: { live: { channels: { Microfono: { "Stream Mix": { muted: false } } } }, pausa: { channels: { Microfono: { "Stream Mix": { muted: true } } } } },
          events: { streamStarted: "live", recordingPaused: "pausa" },
        },
        wl,
        obs,
      ),
    );
    obs.userEvent("RecordStateChanged", { outputActive: true, outputState: "OBS_WEBSOCKET_OUTPUT_PAUSED" });
    await flush();
    expect(wl.chans[0]!.mixes["mix-str"]!.muted).toBe(true);
    obs.userEvent("StreamStateChanged", { outputActive: true, outputState: "OBS_WEBSOCKET_OUTPUT_STARTED" });
    await flush();
    expect(wl.chans[0]!.mixes["mix-str"]!.muted).toBe(false);
  });
});
