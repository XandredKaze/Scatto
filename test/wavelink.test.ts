import { afterEach, describe, expect, it } from "vitest";
import { connectWaveLink, detectProtocol } from "../src/wavelink/discovery.js";
import type { WaveLinkClient, WlChannel } from "../src/wavelink/types.js";
import { MIX_LOCAL, MIX_STREAM } from "../src/wavelink/v2.js";
import { type MockServer, startMock, tick } from "./mockWaveLink.js";

let server: MockServer | null = null;
let client: WaveLinkClient | null = null;
afterEach(async () => {
  client?.close();
  await server?.close();
  server = client = null;
});

describe("detectProtocol", () => {
  it("riconosce 3.x da appID", () => {
    expect(detectProtocol({ appID: "EWL", interfaceRevision: 2 })?.protocol).toBe(3);
  });
  it("riconosce 2.x da appName", () => {
    expect(detectProtocol({ appName: "Elgato Wave Link", interfaceRevision: 3 })?.protocol).toBe(2);
  });
  it("rifiuta risposte estranee", () => {
    expect(detectProtocol({ foo: 1 })).toBeNull();
  });
});

describe("Wave Link 3.x", () => {
  const setup = async (setChannel?: (p: any) => unknown) => {
    server = await startMock({
      getApplicationInfo: () => ({ appID: "EWL", interfaceRevision: 2, name: "Wave Link", version: "3.2.5" }),
      getChannels: () => ({
        channels: [{ id: "ch-mic", name: "Microfono", level: 1, isMuted: false, mixes: [{ id: "mix-s", level: 0.5, isMuted: false }] }],
      }),
      getMixes: () => ({ mixes: [{ id: "mix-s", name: "Stream Mix", level: 0.8, isMuted: false }] }),
      setChannel: setChannel ?? ((p) => p),
      setMix: (p) => p,
    });
    client = await connectWaveLink({ host: "127.0.0.1", port: server.port });
    return client;
  };

  it("normalizza i livelli 0..1 in 0..100", async () => {
    const wl = await setup();
    expect(wl.info.protocol).toBe(3);
    expect(wl.channels()[0]).toMatchObject({ name: "Microfono", level: 100, mixes: { "mix-s": { level: 50, muted: false } } });
    expect(wl.mixes()[0]).toMatchObject({ name: "Stream Mix", level: 80 });
  });

  it("setChannel per mix invia livelli 0..1", async () => {
    const wl = await setup();
    await wl.setChannel("ch-mic", "mix-s", { level: 25, muted: true });
    const call = server!.received.find((r) => r.method === "setChannel");
    expect(call?.params).toEqual({ id: "ch-mic", mixes: [{ id: "mix-s", level: 0.25, isMuted: true }] });
    expect(wl.channels()[0]!.mixes["mix-s"]).toEqual({ level: 25, muted: true });
  });

  it("riprova con mixId se il server rifiuta id (-32602)", async () => {
    const wl = await setup((p) => {
      if (p.mixes?.[0]?.id) throw Object.assign(new Error("Invalid params"), { code: -32602 });
      return p;
    });
    await wl.setChannel("ch-mic", "mix-s", { muted: true });
    const calls = server!.received.filter((r) => r.method === "setChannel");
    expect(calls).toHaveLength(2);
    expect(calls[1]!.params).toEqual({ id: "ch-mic", mixes: [{ mixId: "mix-s", isMuted: true }] });
  });

  it("applica le notifiche channelChanged parziali", async () => {
    const wl = await setup();
    const seen: WlChannel[] = [];
    wl.on("channelChanged", (c) => seen.push(structuredClone(c)));
    server!.notify("channelChanged", { id: "ch-mic", mixes: [{ id: "mix-s", isMuted: true }] });
    await tick();
    expect(seen).toHaveLength(1);
    expect(seen[0]!.mixes["mix-s"]).toEqual({ level: 50, muted: true });
  });
});

describe("Wave Link 2.x", () => {
  const setup = async () => {
    server = await startMock({
      getApplicationInfo: () => ({ appName: "Elgato Wave Link", appVersion: "1.10.1", interfaceRevision: 3 }),
      getInputConfigs: () => [
        { identifier: "PCM_IN_01", name: "Microfono", isAvailable: true, localMixer: [false, 90], streamMixer: [false, 100] },
        { identifier: "Music", name: "Musica", isAvailable: true, localMixer: [false, 40], streamMixer: [true, 30] },
        { identifier: "Aux2", name: "Aux 2", isAvailable: false, localMixer: [false, 0], streamMixer: [false, 0] },
      ],
      getOutputConfig: () => ({ localMixer: [false, 70], streamMixer: [false, 100] }),
      setInputConfig: () => ({}),
      setOutputConfig: () => ({}),
    });
    client = await connectWaveLink({ host: "127.0.0.1", port: server.port });
    return client;
  };

  it("crea due mix fissi e ignora i canali non disponibili", async () => {
    const wl = await setup();
    expect(wl.info.protocol).toBe(2);
    expect(wl.mixes().map((m) => m.name)).toEqual(["Monitor", "Stream"]);
    expect(wl.channels().map((c) => c.name)).toEqual(["Microfono", "Musica"]);
    expect(wl.channels()[1]!.mixes[MIX_STREAM]).toEqual({ level: 30, muted: true });
  });

  it("setChannel usa setInputConfig con property Volume/Mute", async () => {
    const wl = await setup();
    await wl.setChannel("Music", MIX_STREAM, { level: 55.4, muted: false });
    const calls = server!.received.filter((r) => r.method === "setInputConfig").map((r) => r.params);
    expect(calls).toEqual([
      { identifier: "Music", mixerID: MIX_STREAM, property: "Volume", value: 55 },
      { identifier: "Music", mixerID: MIX_STREAM, property: "Mute", value: false },
    ]);
  });

  it("mixId null applica a entrambi i mix", async () => {
    const wl = await setup();
    await wl.setChannel("Music", null, { muted: true });
    const mixers = server!.received.filter((r) => r.method === "setInputConfig").map((r) => (r.params as any).mixerID);
    expect(mixers).toEqual([MIX_LOCAL, MIX_STREAM]);
  });

  it("aggiorna lo stato dalle notifiche", async () => {
    const wl = await setup();
    server!.notify("inputMuteChanged", { identifier: "PCM_IN_01", mixerID: MIX_STREAM, value: true });
    server!.notify("outputVolumeChanged", { mixerID: MIX_LOCAL, value: 12 });
    await tick();
    expect(wl.channels()[0]!.mixes[MIX_STREAM]!.muted).toBe(true);
    expect(wl.mixes()[0]!.level).toBe(12);
  });
});
