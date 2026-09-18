# Scatto

Un roguelike top-down realizzato in **Godot 4.3** in cui l'unico attacco a disposizione è lo *scatto* contro i nemici: non esiste un tasto per colpire, bisogna scattare addosso agli avversari per infliggere danno, restando invulnerabili per la durata dello scatto.

## Come si gioca

- **Movimento**: `WASD`/frecce direzionali, oppure lo stick sinistro o il D-pad di un controller.
- **Scatto (unico attacco)**: `Spazio`/`Shift`, oppure il tasto A (Xbox) / Croce (PlayStation) del controller. Durante lo scatto sei invulnerabile e infliggi danno a ogni nemico che attraversi (una sola volta a scatto).
- Fuori dallo scatto, il contatto con un nemico o un suo proiettile ti danneggia.
- **Addomesticamento**: `F`, oppure il tasto X (Xbox) / Quadrato (PlayStation) del controller. Rende alleato il nemico comune (non dorato) più vicino entro un certo raggio; l'alleato guarito a piena vita combatte al tuo fianco — insegue e attacca gli altri nemici invece di te — finché non muore o non concludi/riavvii la run. Puoi avere al massimo **2 alleati** contemporaneamente (riconoscibili dall'anello acqua) e l'abilità ha un tempo di recupero prima di poter essere riusata. Un alleato mantiene lo stesso stile di combattimento che aveva da nemico: un tipo da mischia si avvicina e colpisce a contatto, un tipo a distanza mantiene le distanze dal bersaglio e gli spara contro.
- **Attacchi speciali degli alleati**: `E` (dorsale destro/RB-R1 del controller) e `Q` (dorsale sinistro/LB-L1), un pulsante per ogni alleato vivo. Ogni tipo di nemico reso alleato concede un attacco a tema, con il proprio tempo di recupero indipendente da quello dello scatto e dell'addomesticamento e un effetto visivo riconoscibile (colorato in base al tipo di alleato): lo Strisciante dà un balzo mordente in corpo a corpo con un fascio di graffi, il Pungiglione un dardo avvelenato a distanza con una scia colorata, il Corazzato un'onda d'urto anulare intorno a te, lo Sciame una raffica di proiettili colorati in tutte le direzioni. Con 2 alleati di tipo diverso hai entrambi gli attacchi utilizzabili in modo indipendente su pulsanti diversi; con 2 alleati dello stesso tipo i due condividono un solo pulsante in una versione potenziata (più danno, o un colpo/proiettile aggiuntivo). Se un alleato muore, il suo attacco sparisce (o torna alla versione base, se era potenziato).
- Il controller è riconosciuto automaticamente (nessuna configurazione richiesta) e può essere usato insieme alla tastiera in qualsiasi momento.
- **Menu e scelta dei potenziamenti**: navigabili anche da controller con lo stick/D-pad, confermando con il tasto A/Croce e tornando indietro con B/Cerchio. Ogni menu (Hub, scelta del potenziamento, archivio, bestiario, tutorial, fine run) mette a fuoco automaticamente l'opzione predefinita, cosí il pad ha sempre un punto di partenza da cui navigare.
- **Pausa**: `Esc` o il tasto Start/Opzioni del controller, in qualsiasi momento durante una run (tranne sopra un altro menu già aperto, come la scelta del potenziamento). Il menu di pausa offre tre opzioni, navigabili anch'esse da controller: **Riprendi** (torna esattamente da dove eri), **Riprova la run dall'inizio** (rigioca la stanza 1 di questa run con le statistiche che avevi quando l'hai iniziata, senza i potenziamenti presi nel frattempo) e **Torna all'Hub** (abbandona la run e interrompe la serie, come morire).

### Stanze e labirinto

Le stanze 1-5 sono **labirinti generati proceduralmente** (8x6 celle, molto più grandi dello schermo) con corridoi larghi e qualche anello per evitare vicoli ciechi frustranti. La telecamera resta sempre centrata sul giocatore e lo segue ovunque si muova; i nemici della stanza inseguono seguendo un percorso reale attraverso i corridoi, non in linea retta.

Visivamente i corridoi hanno un aspetto da **galleria mineraria/grotta**: le pareti non sono rettangoli netti ma sagome di roccia dai bordi irregolari, con toni di colore che variano leggermente da un tratto all'altro, e il pavimento è punteggiato di piccoli detriti. La collisione resta comunque rettangolare sotto il cofano (il "bordo roccioso" è puramente decorativo, generato una volta per stanza), cosí il movimento resta preciso e prevedibile.

La **sesta stanza** (il boss) è invece un'unica arena aperta, senza pareti interne, ma comunque più grande dello schermo: lo spazio per schivare gli attacchi del boss non è mai limitato al primo piano visibile.

Non appena sconfiggi l'ultimo nemico ostile di una stanza, la ricompensa (la scelta del potenziamento) viene consegnata immediatamente: non serve raggiungere alcun punto della mappa per riscattarla. In quel momento resti fermo sul posto e ogni proiettile ancora in volo (nemico, alleato o del tuo ultimo attacco speciale) sparisce; riprendi il controllo non appena scegli il potenziamento e la stanza successiva (o la sala del boss) comincia. Lo stesso vale alla sconfitta del boss, sulla schermata di fine run.

### Struttura di una run

- Una run completa consiste nel ripulire **5 stanze** di nemici; dopo ogni stanza scegli uno tra 3 potenziamenti casuali.
- Alla **sesta stanza** trovi un boss, scelto a caso tra tre archetipi, ciascuno con mosse proprie:
  - **Custode**: carica diretta o raffica di proiettili in cerchio.
  - **Colosso di Pietra**: lento e tanky, colpisce il terreno intorno a sé (danno ad area) o scaglia detriti in un cono.
  - **Spettro Errante**: veloce e sfuggente, si teletrasporta accanto al giocatore e spara raffiche rapide.
- Dopo aver sconfitto un boss normale puoi scegliere se **tornare all'Hub** (la serie si azzera, ma i progressi restano salvati) oppure **continuare senza tornarci**: mantieni i potenziamenti accumulati e affronti subito una nuova run.
- Se vinci **3 run consecutive senza mai tornare all'Hub**, il boss della terza run è sostituito dalla sua variante speciale corrotta (più potente, con una mossa esclusiva in più e un potenziamento leggendario garantito). **Sconfiggere un boss speciale conclude la partita**: resta disponibile solo "Torna all'Hub".
- Morire in qualsiasi momento interrompe la serie e riporta all'Hub.
- Ogni boss speciale sconfitto **almeno una volta** (in qualsiasi run precedente, non solo quella corrente) sblocca per sempre il suo potenziamento leggendario nel pool delle scelte casuali di fine stanza: da quel momento in poi può ricomparire anche senza dover sconfiggere di nuovo quel boss, oltre a restare comunque un bottino garantito la prima volta. Le scelte di fine stanza sono estratte con un peso per rarità (comune > raro > leggendario), cosí un leggendario resta un colpo di fortuna occasionale invece di comparire alla pari degli altri.

### Nemico dorato

Lo **Strisciante** (il nemico comune di base) ha una rarissima **variante dorata**: ogni stanza generata ha **1 probabilità su 4096** di far comparire lo Strisciante Dorato, molto più forte del normale e con un bottino leggendario garantito.

### Archivio e Bestiario

Dall'Hub sono raggiungibili due schermate persistenti (salvate su disco, sopravvivono tra una partita e l'altra):

- **Archivio dei Potenziamenti**: elenca tutti i potenziamenti del gioco; quelli mai raccolti restano "???" finché non li ottieni per la prima volta.
- **Bestiario**: elenca tutti gli avversari (nemici comuni, la variante dorata e i boss); un nemico resta "???" finché non lo sconfiggi per la prima volta.

### Tutorial

Dall'Hub è raggiungibile anche un **Tutorial** che spiega passo per passo i comandi (movimento, scatto, contatto, potenziamenti) e il comportamento dei nemici comuni. I boss, le loro varianti speciali e la variante dorata non vengono mai menzionati: restano una scoperta della run.

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
  core/MazeGrid.gd            # labirinto procedurale: generazione, collisione, pathfinding
  autoload/SaveManager.gd     # persistenza (archivio, bestiario, statistiche) su user://
  data/GameData.gd            # dati di nemici, variante dorata, boss e potenziamenti
  entities/                   # Player, Enemy, Boss, EnemyProjectile, CombatEntity, ArenaVisual, SpecialAttackEffect
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
