# Scatto — Cuphead Online Coop (prototipo)

Mod per **BepInEx 5** che aggiunge la co-op **online** a Cuphead: l'host gioca Cuphead (P1),
il client gioca Mugman (P2), ognuno dal proprio PC con la propria copia del gioco.

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

1. Installa [BepInEx 5](https://github.com/BepInEx/BepInEx/releases) (versione x64 o x86, la stessa
   architettura di `Cuphead.exe`) nella cartella del gioco. Avvia Cuphead una volta e chiudilo.
2. Compila la mod (vedi sotto) o copia `CupheadOnlineCoop.dll` in `Cuphead/BepInEx/plugins/CupheadOnlineCoop/`.
3. Avvia Cuphead una volta: viene creato `BepInEx/config/scatto.cuphead.onlinecoop.cfg`.

## Giocare

Configura il file `.cfg` su entrambi i PC:

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

Serve il [.NET SDK](https://dotnet.microsoft.com/download) (6 o più recente) e Cuphead con BepInEx già installato:

```bash
dotnet build CupheadOnlineCoop -c Release -p:CupheadDir="C:\Program Files (x86)\Steam\steamapps\common\Cuphead"
```

La DLL viene copiata automaticamente in `BepInEx/plugins/CupheadOnlineCoop/`.

## Struttura

| File | Cosa fa |
|---|---|
| `src/Plugin.cs` | Entry point BepInEx, configurazione, HUD |
| `src/CoopSession.cs` | Lockstep, handshake, epoche, attese e predizione, checksum |
| `src/Patches/RewiredPatches.cs` | Patch Harmony su `Rewired.Player.GetButton/GetAxis/...` |
| `src/Inputs/*` | Tabella azioni Rewired, frame di input, buffer per frame |
| `src/Net/*` | Socket UDP non bloccante e formato dei pacchetti |
| `src/Sync/SaveSync.cs` | Trasferimento del salvataggio host → client (fix del ponte) |
| `src/Sync/StateChecksum.cs` | Rilevamento desync |

## Stato

Verificato (fuori dal gioco, con librerie finte al posto di Unity/Rewired e host + client veri in rete locale):
- compila per .NET 3.5;
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

Se mi mandi `Assembly-CSharp.dll` (o il log di BepInEx `BepInEx/LogOutput.log` dopo una prova),
posso completare questi punti.
