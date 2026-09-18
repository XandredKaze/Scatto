# Scatto

Un roguelike top-down realizzato in **Godot 4.3** in cui l'unico attacco a disposizione è lo *scatto* contro i nemici: non esiste un tasto per colpire, bisogna scattare addosso agli avversari per infliggere danno, restando invulnerabili per la durata dello scatto.

## Come si gioca

- **Movimento**: `WASD`/frecce direzionali, oppure lo stick sinistro o il D-pad di un controller.
- **Scatto (unico attacco)**: `Spazio`/`Shift`, oppure il tasto A (Xbox) / Croce (PlayStation) del controller. Durante lo scatto sei invulnerabile e infliggi danno a ogni nemico che attraversi (una sola volta a scatto).
- Fuori dallo scatto, il contatto con un nemico o un suo proiettile ti danneggia.
- Il controller è riconosciuto automaticamente (nessuna configurazione richiesta) e può essere usato insieme alla tastiera in qualsiasi momento.
- **Menu e scelta dei potenziamenti**: navigabili anche da controller con lo stick/D-pad, confermando con il tasto A/Croce e tornando indietro con B/Cerchio. Ogni menu (Hub, scelta del potenziamento, archivio, bestiario, tutorial, fine run) mette a fuoco automaticamente l'opzione predefinita, cosí il pad ha sempre un punto di partenza da cui navigare.
- **Pausa**: `Esc` o il tasto Start/Opzioni del controller, in qualsiasi momento durante una run (tranne sopra un altro menu già aperto, come la scelta del potenziamento). Il menu di pausa offre tre opzioni, navigabili anch'esse da controller: **Riprendi** (torna esattamente da dove eri), **Riprova la run dall'inizio** (rigioca la stanza 1 di questa run con le statistiche che avevi quando l'hai iniziata, senza i potenziamenti presi nel frattempo) e **Torna all'Hub** (abbandona la run e interrompe la serie, come morire).

### Struttura di una run

- Una run completa consiste nel ripulire **5 stanze** di nemici; dopo ogni stanza scegli uno tra 3 potenziamenti casuali.
- Alla **sesta stanza** trovi un boss, scelto a caso tra tre archetipi, ciascuno con mosse proprie:
  - **Custode**: carica diretta o raffica di proiettili in cerchio.
  - **Colosso di Pietra**: lento e tanky, colpisce il terreno intorno a sé (danno ad area) o scaglia detriti in un cono.
  - **Spettro Errante**: veloce e sfuggente, si teletrasporta accanto al giocatore e spara raffiche rapide.
- Dopo aver sconfitto un boss normale puoi scegliere se **tornare all'Hub** (la serie si azzera, ma i progressi restano salvati) oppure **continuare senza tornarci**: mantieni i potenziamenti accumulati e affronti subito una nuova run.
- Se vinci **3 run consecutive senza mai tornare all'Hub**, il boss della terza run è sostituito dalla sua variante speciale corrotta (più potente, con una mossa esclusiva in più e un potenziamento leggendario garantito). **Sconfiggere un boss speciale conclude la partita**: resta disponibile solo "Torna all'Hub".
- Morire in qualsiasi momento interrompe la serie e riporta all'Hub.

### Nemico dorato

Lo **Strisciante** (il nemico comune di base) ha una rarissima **variante dorata**: ogni stanza generata ha **1 probabilità su 4096** di far comparire lo Strisciante Dorato, molto più forte del normale e con un bottino leggendario garantito.

### Archivio e Bestiario

Dall'Hub sono raggiungibili due schermate persistenti (salvate su disco, sopravvivono tra una partita e l'altra):

- **Archivio dei Potenziamenti**: elenca tutti i potenziamenti del gioco; quelli mai raccolti restano "???" finché non li ottieni per la prima volta.
- **Bestiario**: elenca tutti gli avversari (nemici comuni, la variante dorata e i boss); un nemico resta "???" finché non lo sconfiggi per la prima volta.

### Tutorial

Dall'Hub è raggiungibile anche un **Tutorial** che spiega passo per passo i comandi (movimento, scatto, contatto, potenziamenti) e il comportamento dei nemici comuni. Il Custode, il Custode Corrotto e la variante dorata non vengono mai menzionati: restano una scoperta della run.

## Aprire il progetto

Serve **Godot 4.3** (o successivo, engine `GL Compatibility`). Apri la cartella del repository come progetto dall'editor di Godot e premi Play, oppure da riga di comando:

```bash
godot --path .
```

## Struttura del progetto

```
project.godot
scenes/Main.tscn              # unica scena "fisica": tutto il resto è costruito da codice
scripts/
  Main.gd                     # coordina Hub <-> Run
  core/InputSetup.gd          # azioni di input (tastiera + controller) registrate a codice
  autoload/SaveManager.gd     # persistenza (archivio, bestiario, statistiche) su user://
  data/GameData.gd            # dati di nemici, variante dorata, boss e potenziamenti
  entities/                   # Player, Enemy, Boss, EnemyProjectile, CombatEntity, ArenaVisual
  screens/Run.gd              # orchestratore di una run (stanze, boss, serie, salvataggio)
  ui/                         # Hub, Archivio, Bestiario, Tutorial, scelta potenziamento, pausa, fine run, game over, HUD
tests/SmokeTest.gd            # test end-to-end eseguibile in headless (vedi sotto)
```

La maggior parte dei nodi (UI, entità) viene costruita interamente da script (`Node.new()` + figli aggiunti in `_ready()`), non da file `.tscn`: rende il progetto interamente ispezionabile come testo e facilmente testabile in headless.

## Test automatico (headless)

Il progetto include un test end-to-end che avvia una partita reale (fisica inclusa) e verifica: generazione stanze, danno da scatto e da contatto tramite la vera fisica `Area2D`, i pattern d'attacco del boss, la progressione delle 5 stanze + boss, la scelta dei potenziamenti, la regola delle 3 run consecutive senza Hub, la sconfitta del giocatore e la persistenza in `SaveManager`.

```bash
godot --headless --path . -- --smoke-test
```

## Modalità debug in-partita

Avviando il gioco con l'argomento `--debug-scatto` (es. `godot --path . -- --debug-scatto`), durante una run sono disponibili scorciatoie utili per collaudare rapidamente contenuti rari:

- `G`: forza la comparsa di un nemico dorato nella prossima stanza generata.
- `K`: uccide istantaneamente tutti i nemici della stanza corrente.
- `B`: salta direttamente alla sala del Custode.

Con `--debug-scatto` attivo, nella HUD compare anche un pulsante **"Forza nemico dorato"**, equivalente al tasto `G` ma cliccabile (utile testando con un controller, dove `G` non è raggiungibile).
