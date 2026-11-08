import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { readObsWebsocketSettings } from "../src/obsSettings.js";

describe("readObsWebsocketSettings", () => {
  const write = (data: object) => {
    const p = join(mkdtempSync(join(tmpdir(), "waveobs-")), "config.json");
    writeFileSync(p, JSON.stringify(data));
    return p;
  };
  it("legge porta e password", () => {
    const p = write({ server_enabled: true, server_port: 4466, auth_required: true, server_password: "segreta" });
    expect(readObsWebsocketSettings([p])).toEqual({ port: 4466, password: "segreta" });
  });
  it("ignora la password se l'autenticazione è disattivata", () => {
    const p = write({ server_port: 4455, auth_required: false, server_password: "x" });
    expect(readObsWebsocketSettings([p])).toEqual({ port: 4455, password: undefined });
  });
  it("restituisce null se il file non c'è", () => {
    expect(readObsWebsocketSettings(["/non/esiste.json"])).toBeNull();
  });
});
