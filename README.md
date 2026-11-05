# Scatto — Cuphead Online Coop (prototipo)

Mod che aggiunge la co-op **online** a Cuphead: l'host gioca Cuphead (P1),
il client gioca Mugman (P2), ognuno dal proprio PC con la propria copia del gioco.

**Non serve BepInEx**: la mod si carica con [Unity Doorstop](https://github.com/NeighTools/UnityDoorstop),
un singolo file (`winhttp.dll`, 26 KB) che Unity carica all'avvio e che a sua volta carica la mod.
Per installare si copiano 4 file, per disinstallare si cancellano.

> ⚠️ **Prototipo non ancora provato nel gioco vero.** La logica di rete è testata
> (vedi "Stato"), ma i punti di aggancio a Cuphead vanno verificati con il gioco installato.

## Come funziona

**Lockstep degli input**: entrambi i PC eseguono la stessa partita. A ogni frame ognuno manda all'altro
il proprio input e aspetta quello dell'altro. Poi la mod intercetta le letture dei controlli di Rewired
(la libreria input di Cuphead) e fa vedere al gioco gli stessi input di P1 e P2 su entrambi i PC.

Per tenere le due partite uguali la mod:
- **sincronizza il salvataggio**. È la causa del bug del **ponte di legno che sparisce
  nell'overworld** con altre mod co-op online. Lo stato della mappa (ponti, scale, eventi già visti)
  viene dal file di salvataggio: se host e client caricano save diversi, le mappe sono diverse.
  Qui il client gioca con una copia esatta del save dell'host (vedi sotto);
- **fissa il passo del tempo** a 1/60 s per frame (`Time.captureFramerate`), anche durante le attese di rete;
- **reimposta il seed** di `UnityEngine.Random` alla connessione e a ogni cambio di scena;
- **riparte il conteggio dei frame a ogni scena** ("epoche"), così i tempi di caricamento diversi non sfasano;
- **controlla un checksum** (posizioni dei giocatori) ogni 60 frame e segnala i desync nell'HUD.

## Installazione

1. Compila la mod (vedi sotto): ottieni la cartella `dist/`.
2. Copia **il contenuto** di `dist/` nella cartella di Cuphead (quella con `Cuphead.exe`):
   ```
   Cuphead/
   ├── Cuphead.exe
   ├── winhttp.dll              ← Doorstop
   ├── doorstop_config.ini
   └── CupheadOnlineCoop/
       ├── CupheadOnlineCoop.dll
       └── 0Harmony.dll         ← libreria per modificare i metodi del gioco
   ```
3. Avvia Cuphead una volta: viene creato `CupheadOnlineCoop/CupheadOnlineCoop.ini` (la configurazione).
   Se non compare, guarda la sezione "Problemi".

**Disinstallare:** cancella `winhttp.dll`, `doorstop_config.ini` e la cartella `CupheadOnlineCoop`.
Per disattivarla al volo: `enabled=false` in `doorstop_config.ini`.

## Giocare

Configura `CupheadOnlineCoop/CupheadOnlineCoop.ini` su entrambi i PC:

| | Host | Client |
|---|---|---|
| `Mode` | `Host` | `Client` |
| `HostAddress` | – | IP dell'host |
| `Port` | 7777 (UDP) | uguale all'host |

Per collegarvi senza aprire porte sul router, il modo più semplice è una VPN tipo
**Tailscale**, **ZeroTier** o **Radmin VPN**: usate l'IP della VPN come `HostAddress`.
Altrimenti l'host deve inoltrare la porta UDP 7777.

**La prima volta:**
1. Avviate entrambi il gioco e restate nella schermata del titolo.
2. Il client si collega. Se il suo slot 3 è diverso dallo slot 1 dell'host, riceve il salvataggio
   dell'host, lo copia nel **slot 3** (il vecchio contenuto finisce in un file `.coop-backup-...`)
   e chiede di **riavviare Cuphead**.
3. Dopo il riavvio il client si ricollega da solo e l'HUD mostra "Connesso".
4. Host sceglie lo **slot 1**, client lo **slot 3** (l'HUD lo ricorda). Da qui in poi i menu e il gioco
   sono sincronizzati: naviga l'host, il client si unisce come Mugman.

Gli slot si cambiano con `HostSaveSlot` / `ClientSaveSlot`. Tasti: **F8** mostra/nasconde l'HUD,
**F9** chiude e riapre la connessione (rilegge la configurazione).

## Compilare

Serve il [.NET SDK](https://dotnet.microsoft.com/download) (6 o più recente) e Cuphead installato
(la build usa `UnityEngine.dll` e `Rewired_Core.dll` del gioco):

```bash
dotnet build CupheadOnlineCoop -c Release -p:CupheadDir="C:\Program Files (x86)\Steam\steamapps\common\Cuphead"
```

La build scarica Doorstop 4.3.0 (verificandone l'hash SHA-256) e prepara `dist/`.
Opzioni:
- `-p:DoorstopArch=x86` se Cuphead è a 32 bit. Per saperlo: avvia il gioco e guarda in
  Gestione attività; se accanto a "Cuphead" c'è "(32 bit)", usa x86, altrimenti va bene x64 (predefinito).
- `-p:Install=true` per copiare direttamente la mod nella cartella del gioco.

## Problemi

- **Non viene creato il file `.ini` / la mod non parte**: quasi sempre l'architettura di `winhttp.dll`
  è sbagliata. Ricompila con l'altra (`-p:DoorstopArch=x86` o `x64`).
- **Log**: `CupheadOnlineCoop/CupheadOnlineCoop.log` (e anche il log di Unity, `output_log.txt` / `Player.log`).
- L'antivirus può segnalare `winhttp.dll` perché si inserisce nel processo del gioco: è normale per i loader di mod
  (è lo stesso file usato da BepInEx).

## Struttura

| File | Cosa fa |
|---|---|
| `src/Loader/Entrypoint.cs` | Entry point chiamato da Doorstop all'avvio |
| `src/Loader/Loader.cs` | Attende che Unity sia pronto, applica le patch, log su file |
| `src/Loader/ModConfig.cs` | Configurazione `.ini` (con i valori predefiniti commentati) |
| `src/CoopBehaviour.cs` | Ciclo per frame e HUD |
| `src/CoopSession.cs` | Lockstep, handshake, epoche, attese e predizione, checksum |
| `src/Patches/RewiredPatches.cs` | Patch Harmony su `Rewired.Player.GetButton/GetAxis/...` |
| `src/Inputs/*` | Tabella azioni Rewired, frame di input, buffer per frame |
| `src/Net/*` | Socket UDP non bloccante e formato dei pacchetti |
| `src/Sync/SaveSync.cs` | Trasferimento del salvataggio host → client (fix del ponte) |
| `src/Sync/StateChecksum.cs` | Rilevamento desync |

## Stato

Verificato (fuori dal gioco, con librerie finte al posto di Unity/Rewired e host + client veri in rete locale):
- compila per .NET 3.5 e la build produce la cartella `dist/` con Doorstop e Harmony;
- il salvataggio arriva identico al client, con backup del vecchio file;
- 400 frame di input, attraverso un cambio di scena, sono **identici su host e client**, senza frame predetti.

Da verificare / fare con il gioco installato:
- [ ] **Percorso e nome dei salvataggi**: il valore predefinito è `%AppData%\Cuphead\cuphead_player_data_v1_slot_{0}.sav`.
      Controlla i file sul tuo PC e correggi `SaveDirectory` / `SaveFilePattern` se serve.
- [ ] **ID Rewired** di P1/P2 (`Player1RewiredId` = 0, `Player2RewiredId` = 1) e che il join di Mugman
      funzioni anche se al giocatore Rewired 2 non è assegnato nessun controller fisico. Se Cuphead controlla
      `controllers.joystickCount`, servirà una patch in più.
- [ ] Nomi delle classi per il checksum (`AbstractPlayerController`, `MapPlayerController`), da confermare
      aprendo `Cuphead_Data/Managed/Assembly-CSharp.dll` con dnSpy/ILSpy.
- [ ] Fonti di non-determinismo oltre a `UnityEngine.Random`: `System.Random`, `Time.unscaledDeltaTime`,
      `WaitForSecondsRealtime`, ordine di `FindObjectsOfType`. Ogni desync segnalato dall'HUD indica dove guardare.
- [ ] Pausa e menu delle opzioni (una pausa su un solo PC sfasa le partite).
- [ ] Riconnessione a partita in corso e risincronizzazione dello stato dopo un desync.

Se mi mandi `Assembly-CSharp.dll` (o il file `CupheadOnlineCoop/CupheadOnlineCoop.log` dopo una prova),
posso completare questi punti.
