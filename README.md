# WaveOBS

Ponte tra **Elgato Wave Link** e **OBS Studio**. Parte da solo quando apri OBS, si chiude quando chiudi OBS, e non richiede di installare Node.js o altro.

| Funzione | Cosa fa |
|---|---|
| **Mix per scena** | Quando cambi scena in OBS, applica un preset di volumi/mute in Wave Link (es. scena "Pausa" → mic muto, musica più alta). |
| **Indicatore mic** | Quando muti un canale in Wave Link, mostra/nasconde una fonte in OBS (es. un'icona "MIC MUTO"). |
| **Sync livelli** | Tiene allineati volume e mute tra un canale Wave Link e una fonte audio di OBS, in una o in entrambe le direzioni. |
| **Azioni su eventi** | All'avvio/stop della diretta o della registrazione (anche pausa/ripresa) applica un preset. |

## Come funziona

```
 OBS ── script waveobs.lua ──avvia──▶ waveobs.exe (nascosto)
  ▲                                      │
  └──── obs-websocket (porta 4455) ◀─────┤
                                         └──▶ WebSocket locale ⇄ Wave Link
```

- Lo script **waveobs.lua**, caricato in OBS, avvia **waveobs.exe** in background (senza finestre) all'apertura di OBS.
- `waveobs.exe` contiene già tutto il necessario: non serve installare Node.js.
- Si collega a OBS tramite **obs-websocket** (incluso in OBS 28+) e ne legge da solo porta e password.
- Si collega a Wave Link con la stessa **API WebSocket locale** usata dal plugin Stream Deck di Elgato.
- Quando OBS si chiude, WaveOBS si chiude. Se premi "Riavvia WaveOBS" o ricarichi lo script, la nuova istanza sostituisce la vecchia.

La versione di Wave Link viene rilevata da sola:

- **Wave Link 3.x**: porta letta da `%LOCALAPPDATA%\Packages\Elgato.WaveLink_…\LocalState\ws-info.json`, altrimenti 1884–1893. I mix sono quelli che hai creato tu, con i loro nomi.
- **Wave Link 1.x / 2.x**: porte 1824–1833, due mix fissi: `Monitor` (alias `local`) e `Stream`.

> ⚠️ L'API di Wave Link è **non ufficiale** e può cambiare con gli aggiornamenti di Elgato. Il protocollo 3.x è basato sul comportamento di Wave Link 3.2.x; se qualcosa non va metti `"logLevel": "debug"` nel config e guarda `waveobs.log`.

## Installazione (Windows)

1. Scarica **WaveOBS-windows** (dalla pagina *Releases*, oppure dagli *Artifacts* dell'ultima esecuzione in *Actions* su GitHub) ed estrailo in una cartella fissa, ad esempio `C:\WaveOBS\`. Dentro trovi `waveobs.exe`, `waveobs.lua`, `config.example.json` e `LEGGIMI.txt`.
2. In OBS: **Strumenti → Impostazioni server WebSocket** → spunta *Abilita server WebSocket*.
3. In OBS: **Strumenti → Script** → **+** → scegli `waveobs.lua`.
4. Nella finestra dello script premi **Modifica configurazione**: si apre `config.json`, creato dall'esempio. Scrivi i tuoi nomi, salva e premi **Riavvia WaveOBS**.

Fatto: da ora WaveOBS parte e si chiude insieme a OBS. Nella finestra dello script ci sono anche **Apri log** e l'opzione per disattivare l'avvio automatico.

Per vedere i nomi esatti di canali, mix, scene e fonti, con Wave Link e OBS aperti, apri un Prompt dei comandi nella cartella e scrivi:

```bash
waveobs list
```

## Configurazione

Tutto sta in `config.json`, accanto a `waveobs.exe` (vedi `config.example.json`). La sezione `obs` può restare vuota: porta e password vengono lette dalle impostazioni di OBS. Se vuoi indicarle a mano: `"obs": { "url": "ws://127.0.0.1:4455", "password": "..." }`. Canali, mix, scene e fonti si indicano **per nome** (maiuscole/minuscole non contano) o per id. Per i mix basta una parola del nome se è univoca: `"stream"` trova `"Stream Mix"`.

### Preset

Un preset è uno stato audio riutilizzabile. I livelli vanno da 0 a 100.

```json
"presets": {
  "pausa": {
    "channels": {
      "Microfono": { "stream": { "muted": true } },
      "Musica":    { "stream": { "level": 80 }, "monitor": { "level": 30 } },
      "Game":      { "*": { "muted": true } }
    },
    "mixes": { "Stream": { "level": 100 } },
    "obs":   { "Audio desktop": { "volume": 50, "muted": false } }
  }
}
```

- Le chiavi dentro un canale sono i mix. `"*"` vuol dire tutti i mix, `"global"` il livello generale del canale (solo 3.x; in 2.x vale per entrambi i mix).
- `mixes` regola il volume/mute generale di un mix.
- `obs` regola le fonti audio di OBS (volume 0–100, dove 100 = 0 dB).

### Mix per scena

```json
"sceneMixes": {
  "applyOnConnect": true,
  "scenes": {
    "Gioco": "live",
    "Pausa": "pausa",
    "*": "live"
  }
}
```

Al posto del nome del preset puoi scrivere un preset completo. `"*"` vale per tutte le scene non elencate. Con `applyOnConnect` il preset della scena attiva viene applicato anche all'avvio.

### Indicatore mic

```json
"micIndicators": [
  { "channel": "Microfono", "mix": "stream", "source": "Icona Mic Muto", "showWhen": "muted" }
]
```

La fonte viene mostrata/nascosta in tutte le scene che la contengono (o solo in quelle indicate con `"scenes": ["Gioco"]`). Se ometti `mix` conta il mute generale del canale (3.x) o il mix Stream (2.x). Le fonti dentro un *gruppo* di OBS non vengono trovate: mettile direttamente nella scena.

### Sync livelli

```json
"levelSync": [
  { "channel": "Musica", "mix": "stream", "obsInput": "Musica (Wave Link)", "direction": "both", "volume": true, "mute": true }
]
```

`direction` può essere `both`, `wavelink-to-obs` o `obs-to-wavelink`. All'avvio vince Wave Link (OBS per `obs-to-wavelink`). Il volume è mappato in modo lineare: 100 in Wave Link = 0 dB in OBS.

> Non sincronizzare un canale con una fonte OBS che riceve già lo stesso audio dal mix Stream di Wave Link, altrimenti il volume viene applicato due volte.

### Azioni su eventi

```json
"events": {
  "streamStarted": "live",
  "streamStopped": "fine",
  "recordingStarted": "live",
  "recordingStopped": "fine",
  "recordingPaused": "pausa",
  "recordingResumed": "live"
}
```

## Sviluppo

Serve Node.js 22 solo per chi sviluppa.

```bash
npm install
```

```bash
npm test
```

```bash
npm run dev -- list
```

Per creare l'eseguibile per il sistema corrente (su Windows produce `release/waveobs.exe`):

```bash
npm run exe
```

La GitHub Action `.github/workflows/build.yml` esegue i test e crea `waveobs.exe` su Windows a ogni push. Con un tag `v*` pubblica anche lo zip nelle *Releases*.

Struttura:

```
obs/waveobs.lua         script OBS che avvia/riavvia waveobs.exe
scripts/build-exe.mjs   creazione dell'eseguibile autonomo (Node SEA)
src/
  index.ts              CLI (run, list, help) e modalità --with-obs
  config.ts             schema e validazione di config.json
  obs.ts                connessione a obs-websocket con riconnessione
  obsSettings.ts        lettura di porta/password dalle impostazioni di OBS
  instance.ts           istanza singola (la nuova sostituisce la vecchia)
  wavelink/
    rpc.ts              client JSON-RPC su WebSocket
    discovery.ts        ricerca porta e rilevamento versione
    v2.ts / v3.ts       adattatori per i due protocolli
    connection.ts       riconnessione automatica
  features/             le quattro funzioni + applicazione dei preset
test/                   test con un finto Wave Link e un finto OBS
```
