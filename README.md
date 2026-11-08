# Scatto

Ponte tra **Elgato Wave Link** e **OBS Studio**. Gira in background sul PC della diretta e fa dialogare i due programmi:

| Funzione | Cosa fa |
|---|---|
| **Mix per scena** | Quando cambi scena in OBS, applica un preset di volumi/mute in Wave Link (es. scena "Pausa" → mic muto, musica più alta). |
| **Indicatore mic** | Quando muti un canale in Wave Link, mostra/nasconde una fonte in OBS (es. un'icona "MIC MUTO"). |
| **Sync livelli** | Tiene allineati volume e mute tra un canale Wave Link e una fonte audio di OBS, in una o in entrambe le direzioni. |
| **Azioni su eventi** | All'avvio/stop della diretta o della registrazione (anche pausa/ripresa) applica un preset. |

## Come funziona

Wave Link non ha un SDK ufficiale per i plugin. Scatto usa la stessa **API WebSocket locale** che usa il plugin Stream Deck di Elgato, e si collega a OBS con **obs-websocket v5** (integrato in OBS 28+).

```
 OBS Studio  ⇄  obs-websocket (porta 4455)  ⇄  Scatto  ⇄  WebSocket locale  ⇄  Wave Link
```

La versione di Wave Link viene rilevata da sola:

- **Wave Link 3.x**: porta letta da `%LOCALAPPDATA%\Packages\Elgato.WaveLink_…\LocalState\ws-info.json`, altrimenti 1884–1893. I mix sono quelli che hai creato tu, con i loro nomi.
- **Wave Link 1.x / 2.x**: porte 1824–1833, due mix fissi: `Monitor` (alias `local`) e `Stream`.

> ⚠️ L'API di Wave Link è **non ufficiale** e può cambiare con gli aggiornamenti di Elgato. Il protocollo 3.x è basato sul comportamento di Wave Link 3.2.x; se qualcosa non va avvia con `"logLevel": "debug"` e apri una issue con il log.

## Requisiti

- Windows (o macOS con Wave Link 2.x) con Wave Link avviato
- OBS Studio 28 o successivo
- [Node.js](https://nodejs.org) 20 o successivo

## Installazione

1. In OBS: **Strumenti → Impostazioni server WebSocket** → spunta *Abilita server WebSocket* e copia la password (*Mostra info di connessione*).
2. Nella cartella del progetto:

   ```bash
   npm install
   ```

   ```bash
   npm run build
   ```

3. Copia `config.example.json` in `config.json` e inserisci la password di OBS.
4. Con Wave Link e OBS aperti, guarda i nomi esatti di canali, mix, scene e fonti:

   ```bash
   npm run list
   ```

5. Modifica `config.json` con i tuoi nomi e avvia:

   ```bash
   npm start
   ```

Scatto si riconnette da solo se chiudi e riapri Wave Link o OBS, quindi puoi lasciarlo sempre acceso (ad esempio mettendo un collegamento a `npm start` in *Esecuzione automatica* di Windows).

## Configurazione

Tutto sta in `config.json` (vedi `config.example.json`). Canali, mix, scene e fonti si indicano **per nome** (maiuscole/minuscole non contano) o per id. Per i mix basta una parola del nome se è univoca: `"stream"` trova `"Stream Mix"`.

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

```bash
npm run dev
```

```bash
npm test
```

Struttura:

```
src/
  index.ts              CLI (run, list, help)
  config.ts             schema e validazione di config.json
  obs.ts                connessione a obs-websocket con riconnessione
  wavelink/
    rpc.ts              client JSON-RPC su WebSocket
    discovery.ts        ricerca porta e rilevamento versione
    v2.ts / v3.ts       adattatori per i due protocolli
    connection.ts       riconnessione automatica
  features/             le quattro funzioni + applicazione dei preset
test/                   test con un finto Wave Link e un finto OBS
```
