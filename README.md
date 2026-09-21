# A.M.I.C.

Un roguelike top-down realizzato in **Godot 4.3** costruito su una rinuncia: si parte con lo *scatto* come unico attacco — non esiste un tasto per colpire, bisogna scattare addosso agli avversari restando invulnerabili per la durata dello scatto — ma addomesticare un nemico lo sostituisce con gli attacchi speciali degli alleati.

## Schermata del titolo

All'avvio si apre la classica schermata del titolo: il logo, il nome **A.M.I.C.** e l'invito lampeggiante a premere un tasto. "Un tasto qualsiasi" è da prendere alla lettera — tastiera, controller o mouse — e da lí si passa alla scelta del salvataggio. La si vede una volta sola, all'accensione: tornando all'Hub o cambiando salvataggio non ci si ripassa.

Il gioco si chiamava **Scatto**, dal nome della sua meccanica. Rinominandolo, Godot cambia anche la cartella dei dati utente: i salvataggi di chi già giocava resterebbero in quella vecchia, invisibili. Alla prima esecuzione col nome nuovo vengono quindi recuperati da lí — copiati e non spostati, cosí la cartella di prima resta com'è come rete di sicurezza — e non si sovrascrive mai un file già presente in quella nuova. La parola *scatto* resta ovunque indichi la meccanica: a cambiare è solo il nome del gioco.

Il logo (`assets/images/amic_logo.png`) è ritagliato: lo sfondo attorno al soggetto è trasparente e non nero, altrimenti sulla schermata comparirebbe un riquadro squadrato attorno al disegno.

## Salvataggi

All'avvio, **prima dell'Hub**, si sceglie su quale dei **tre slot** giocare. Ogni slot ha i propri progressi — archivio dei potenziamenti, bestiario, statistiche — completamente indipendenti dagli altri, e la riga di ciascuno riassume che cosa contiene prima di sceglierlo (run vinte, serie migliore, potenziamenti e creature scoperte) oppure dichiara che è vuoto.

Ogni slot si può **svuotare** per ricominciare da capo. Siccome è un'azione distruttiva e irreversibile, chiede conferma: il pulsante diventa "Confermi?" e cancella solo alla seconda pressione. La conferma scade da sola dopo qualche secondo e si annulla toccando qualunque altra voce, perché un "sí" restato armato mentre si fa altro è il modo più facile per perdere una partita per sbaglio.

Le **impostazioni** (volume, risoluzione, assegnazione dei tasti) sono invece **in comune a tutti i salvataggi** e stanno in un file a parte: sono preferenze di chi gioca, non progressi di una partita, e svuotare uno slot non deve costringere a rifarle.

Dall'Hub si torna alla scelta con la voce **Cambia salvataggio**: senza, scelto uno slot lo si potrebbe cambiare solo riavviando il gioco.

Chi giocava prima che gli slot esistessero non perde niente: al primo avvio il vecchio salvataggio unico viene travasato nello slot 1, e le sue impostazioni diventano quelle globali.

## Come si gioca

- **Movimento**: `WASD`/frecce direzionali, oppure lo stick sinistro o il D-pad di un controller.
- **I due pulsanti d'attacco**: `E` (dorsale destro/RB-R1 del controller) e `Q` (dorsale sinistro/LB-L1). Sono gli unici pulsanti d'attacco del gioco e quello che fanno dipende da quanti alleati hai al seguito.
- **Scatto (attacco di partenza)**: finché **non hai alcun alleato**, entrambi i pulsanti eseguono lo scatto. Durante lo scatto sei invulnerabile e infliggi danno a ogni nemico che attraversi (una sola volta a scatto).
- Fuori dallo scatto, il contatto con un nemico o un suo proiettile ti danneggia.
- **Addomesticamento (e rinuncia allo scatto)**: `F`, oppure il tasto X (Xbox) / Quadrato (PlayStation) del controller. Rende alleato il nemico comune (non dorato) più vicino entro un certo raggio. **Dal momento in cui hai anche un solo alleato perdi lo scatto**, su entrambi i pulsanti: al suo posto arrivano gli attacchi speciali degli alleati. Se tutti i tuoi alleati cadono, lo scatto torna disponibile. L'alleato guarito a piena vita combatte al tuo fianco — insegue e attacca gli altri nemici invece di te — finché non muore o non concludi/riavvii la run. Puoi avere al massimo **2 alleati** contemporaneamente (riconoscibili dal profilo d'acciaio e dal marchio del legame sopra la testa) e l'abilità ha un tempo di recupero prima di poter essere riusata. Un alleato mantiene lo stesso stile di combattimento che aveva da nemico: un tipo da mischia si avvicina e colpisce a contatto, un tipo a distanza mantiene le distanze dal bersaglio e gli spara contro. Quasi tutti i tipi sono più lenti di te, quindi un alleato rimasto indietro **accelera per raggiungerti**, e lo fa in modo esponenziale: oltre un certo distacco la sua velocità raddoppia ogni ~220 pixel di distanza, fino a un tetto di 8 volte l'andatura normale. Così non lo perdi in fondo a un corridoio, ma l'inseguimento non diventa un teletrasporto — e l'accelerazione vale solo mentre sta tornando da te, non mentre è impegnato contro un nemico. **Gli avversari non ti ignorano più a favore del giocatore**: nemici comuni e boss attaccano chi hanno più vicino tra te e i tuoi alleati, quindi un alleato mandato avanti fa davvero da esca — insegue, viene inseguito, incassa colpi e proiettili al posto tuo, e il colpo ad area del boss non distingue amici da nemici. Un avversario cambia bersaglio solo se l'altro è nettamente più vicino, per non restare indeciso a metà strada, e torna su di te appena l'alleato cade.
- **Attacchi speciali degli alleati**: sugli stessi due pulsanti dello scatto, uno per ogni alleato vivo. Ogni tipo di nemico reso alleato concede un attacco a tema, con un effetto visivo riconoscibile (colorato in base al tipo di alleato) e un **ritmo proprio**: danno e tempo di recupero vanno letti insieme, perché senza scatto questi sono l'unica offesa rimasta e devono reggere il confronto con l'attacco base.
  - **Morso Selvaggio** (Strisciante, corpo a corpo): tanto danno, colpi radi — un solo balzo stende quasi ogni nemico comune, ma torna pronto con calma (2s).
  - **Dardo Velenoso** (Pungiglione, a distanza): poco danno, tanti colpi — quasi a raffica (0,5s), ma ogni dardo punge poco e può mancare il bersaglio.
  - **Colpo Corazzato** (Corazzato, ad area): bilanciato — danno e ritmo intermedi (1,5s), ma colpisce tutti i nemici intorno a te invece di uno solo.
  - **Sciame Vendicativo** (Sciame, raffica circolare): variante a distanza che sacrifica il danno del singolo proiettile per coprire ogni direzione (1,1s); sul bersaglio singolo rende poco, su un gruppo tantissimo.

  Con un solo alleato il pulsante rimasto libero resta inattivo (non torna a scattare) finché non ne addomestichi un secondo. Con 2 alleati di tipo diverso hai entrambi gli attacchi utilizzabili in modo indipendente su pulsanti diversi; con 2 alleati dello stesso tipo i due condividono un solo pulsante in una versione potenziata (più danno, o un colpo/proiettile aggiuntivo). Se un alleato muore, il suo attacco sparisce (o torna alla versione base, se era potenziato).
- Il controller è riconosciuto automaticamente (nessuna configurazione richiesta) e può essere usato insieme alla tastiera in qualsiasi momento.
- **Menu e scelta dei potenziamenti**: navigabili anche da controller con lo stick/D-pad, confermando con il tasto A/Croce e tornando indietro con B/Cerchio. Ogni menu (Hub, scelta del potenziamento, archivio, bestiario, tutorial, fine run) mette a fuoco automaticamente l'opzione predefinita, cosí il pad ha sempre un punto di partenza da cui navigare. Archivio, Bestiario e Tutorial elencano più voci di quante ne stiano a schermo: qui lo stick sinistro/D-pad su/giù scorre direttamente la vista (niente da selezionare riga per riga), mentre B/Cerchio chiude il pannello in qualsiasi momento.
- **Pausa**: `Esc` o il tasto Start/Opzioni del controller, in qualsiasi momento durante una run (tranne sopra un altro menu già aperto, come la scelta del potenziamento). Il menu di pausa offre quattro opzioni, navigabili anch'esse da controller: **Riprendi** (torna esattamente da dove eri), **Riprova la run dall'inizio** (rigioca la stanza 1 di questa run con le statistiche che avevi quando l'hai iniziata, senza i potenziamenti presi nel frattempo), **Impostazioni** (le stesse dell'Hub — volume, video, comandi — senza dover abbandonare la run) e **Torna all'Hub** (abbandona la run e interrompe la serie, come morire).

### Stanze e labirinto

Le stanze 1-5 sono **labirinti generati proceduralmente** (8x6 celle, molto più grandi dello schermo) con corridoi larghi e qualche anello per evitare vicoli ciechi frustranti. La telecamera resta sempre centrata sul giocatore e lo segue ovunque si muova; i nemici della stanza inseguono seguendo un percorso reale attraverso i corridoi, non in linea retta.

Visivamente le stanze sono una **cripta gotica**: pavimento di lastre di pietra tagliata, fredde e quasi nere, segnate da fughe, crepe e sangue rappreso; muri come blocchi di muratura più scuri del pavimento, con lo spigolo superiore appena illuminato e un'ombra netta proiettata a terra; e, appesi alle pareti lunghe, stendardi cremisi e bracieri che sono le uniche fonti di colore acceso. Il decoro è generato una volta per stanza e la collisione resta quella rettangolare sotto il cofano, cosí il movimento resta preciso e prevedibile.

### Stile estetico

Tutto il gioco pesca da un unico linguaggio cromatico (`scripts/data/Palette.gd`), tenuto insieme da tre regole:

1. **il fondo è quasi nero e desaturato**, sul blu-grigio della pietra;
2. **l'unico colore acceso è il cremisi**, usato con parsimonia perché faccia da faro per l'occhio: sangue, stendardi, bracieri, barra della vita, preavvisi d'attacco del boss;
3. **le creature sono masse scure con un volto pallido e un profilo luminoso**, e si leggono per silhouette invece che per colore pieno. Il colore del profilo dice anche da che parte stanno: cremisi se ostili, acciaio freddo se alleate, oro se dorate.

Una creatura sconfitta **sparisce dalla stanza**: si dissolve e si accascia in poco più di un terzo di secondo, e in quell'istante smette di essere sia un bersaglio sia un pericolo. Quello che resta sul pavimento è il sangue, non il corpo.

Ne fanno parte anche l'**oscuramento ai bordi dello schermo** (la luce sembra venire da dove si trova il giocatore e spegnersi verso i lati; è disegnato a fasce e non con uno shader, perché il progetto gira in GL Compatibility), il **sangue che resta a terra** dove le creature cadono e dove il giocatore incassa colpi — e che si azzera a ogni stanza nuova — e la **falce di luce** che segna il fendente dello scatto.

Il giocatore è la figura incappucciata dal mantello cremisi: l'unica della scena col rosso pieno addosso, cosí resta individuabile anche in mezzo alla mischia.

**Ogni specie ha la propria sagoma**, perché in una cripta quasi nera il colore del corpo da solo non basta a distinguerle:

- **Strisciante** — una melma nera e allungata, fatta di segmenti che seguono le posizioni realmente occupate poco prima: si allunga come un serpente quando corre e si raccoglie in una pozza quando si ferma. Di chiaro ha solo due occhi.
- **Pungiglione** — un fiore carnivoro a otto petali alternati rossi e bianchi, con il cuore giallo. È lo stesso giallo dei dardi che spara, cosí si capisce a colpo d'occhio da dove arriveranno i colpi.
- **Corazzato** — la sagoma generica: una massa scura e tozza con arti sottili in movimento.
- **Sciame** — un insetto volante con addome a bande, ali portate all'indietro che battono rapidissime e le mandibole spalancate del cervo volante. L'ombra è piccola e staccata verso il basso, perché è in volo e non appoggiato.

La variante dorata eredita la sagoma della propria specie (lo Strisciante Dorato è una melma) ma in ambra, con l'anello d'oro attorno.

**Anche i tre boss hanno l'aspetto del proprio nome**, sagoma e bagliore:

- **Custode** — una sentinella corazzata: corpo ottagonale di piastre d'acciaio, spallacci, uno scudo tenuto verso la preda e una visiera accesa al posto degli occhi. Le rune che gli orbitano intorno sono le stesse che scaglia nella raffica circolare. Bagliore d'acciaio freddo.
- **Colosso di Pietra** — nessuna curva: lastre squadrate e sbilenche, giunti profondi, due pugni enormi che oscillano ai lati e detriti sparsi alla base. Le crepe bruciano d'ambra, la roccia calda che ha dentro.
- **Spettro Errante** — non tocca terra e non ha contorni netti: un cappuccio vuoto, un sudario sfrangiato che ondeggia, scie che si sfilacciano dietro e due occhi accesi di luce funeraria. È semitrasparente, così il pavimento si intravede attraverso.

Le versioni corrotte condividono la sagoma del boss di base e se ne distinguono per il bagliore: cremisi per il Custode Corrotto, magma per il Colosso Corrotto, viola per lo Spettro Corrotto.

La **sesta stanza** (il boss) è invece un'unica arena aperta, senza pareti interne, ma comunque più grande dello schermo: lo spazio per schivare gli attacchi del boss non è mai limitato al primo piano visibile.

Non appena sconfiggi l'ultimo nemico ostile di una stanza, la ricompensa (la scelta del potenziamento) viene consegnata immediatamente: non serve raggiungere alcun punto della mappa per riscattarla. In quel momento resti fermo sul posto e ogni proiettile ancora in volo (nemico, alleato o del tuo ultimo attacco speciale) sparisce; riprendi il controllo non appena scegli il potenziamento e la stanza successiva (o la sala del boss) comincia. Lo stesso vale alla sconfitta del boss, sulla schermata di fine run.

### Struttura di una run

- Una run completa consiste nel ripulire **5 stanze** di nemici; dopo ogni stanza scegli uno tra 3 potenziamenti casuali.
- I potenziamenti coprono **entrambi i modi di combattere**: alcuni rafforzano lo scatto (danno, distanza, cariche, invulnerabilità), altri gli alleati e i loro attacchi speciali (più danno degli attacchi speciali, tempi di recupero più brevi, alleati più resistenti o più letali, addomesticamento più rapido, cure alla caduta di un alleato, velocità extra mentre hai un alleato). Finché hai alleati — e quindi non hai lo scatto — i potenziamenti che agiscono *solo* sullo scatto non ti vengono nemmeno proposti, per non sprecare una delle 3 scelte; restano comunque attivi se li avevi già raccolti e riperdi tutti gli alleati. Due leggendari cambiano le regole: **Vincolo Spezzato** ti lascia lo scatto anche con gli alleati al seguito, **Anima del Branco** rende sempre potenziati gli attacchi speciali.
- Alla **sesta stanza** trovi un boss, scelto a caso tra tre archetipi, ciascuno con mosse proprie:
  - **Custode**: carica diretta o raffica di proiettili in cerchio.
  - **Colosso di Pietra**: lento e tanky, colpisce il terreno intorno a sé (danno ad area) o scaglia detriti in un cono.
  - **Spettro Errante**: veloce e sfuggente, si teletrasporta accanto al giocatore e spara raffiche rapide.
- Dopo aver sconfitto un boss normale puoi scegliere se **tornare all'Hub** (la serie si azzera, ma i progressi restano salvati) oppure **continuare senza tornarci**: mantieni i potenziamenti accumulati e affronti subito una nuova run.
- Se vinci **3 run consecutive senza mai tornare all'Hub**, il boss della terza run è sostituito dalla sua variante speciale corrotta (più potente, con una mossa esclusiva in più e un potenziamento leggendario garantito). **Sconfiggere un boss speciale conclude la partita**: resta disponibile solo "Torna all'Hub".
- Morire in qualsiasi momento interrompe la serie e riporta all'Hub.
- Ogni boss speciale sconfitto **almeno una volta** (in qualsiasi run precedente, non solo quella corrente) sblocca per sempre il suo potenziamento leggendario nel pool delle scelte casuali di fine stanza: da quel momento in poi può ricomparire anche senza dover sconfiggere di nuovo quel boss, oltre a restare comunque un bottino garantito la prima volta. Le scelte di fine stanza sono estratte con un peso per rarità (comune > raro > leggendario), cosí un leggendario resta un colpo di fortuna occasionale invece di comparire alla pari degli altri.

### Come attaccano i nemici

Ogni specie ha il proprio modo di arrivare a colpire, non solo il proprio aspetto. Sono quattro schemi distinti, e ognuno lascia al giocatore una finestra diversa per reagire:

- **Strisciante** — ti insegue, ma raggiunta la preda **si ferma a un soffio da lei**, arretra la testa, spalanca le fauci e affonda il morso; poi si prende un attimo e torna a inseguire. Si ferma appena fuori dal contatto, quindi il morso è il suo vero attacco — e quell'attimo di immobilità è il momento buono per colpirlo.
- **Pungiglione** — **non insegue nessuno**: vive abbarbicato alle pareti, spara il suo dardo e subito dopo **sprofonda nel pavimento per rispuntare poco più in là**, sempre contro un muro e sempre dentro la stanza. Prima di sparare controlla di avere davvero la preda a tiro: se c'è una parete di mezzo non spreca il colpo, sprofonda e va a cercare un punto da cui vederla. Mentre è sotto terra non è colpibile, ma sono frazioni di secondo: il momento per colpirlo è appena rispunta, prima che il dardo parta.
- **Corazzato** — colpisce come prima, ma **non cammina più: avanza a balzi**, e ogni atterraggio scarica a terra una piccola onda d'urto che prende chi gli sta intorno. Stargli lontano non basta più del tutto.
- **Sciame** — a tiro della preda **si ferma a caricare per un secondo e mezzo**, puntandola con un mirino che si allunga mentre le ali impazziscono, poi si lancia in picchiata come uno scatto. La carica è lunga apposta: è ciò che rende l'attacco schivabile invece che inevitabile.

Gli schemi valgono anche quando la creatura combatte come tua alleata, rivolti contro gli ostili. L'unica eccezione è il Pungiglione: da alleato usa lo sprofondamento anche per starti dietro (rispunta vicino a te quando è rimasto indietro), perché un fiore inchiodato a una parete in fondo al labirinto sarebbe un alleato perso.

### Nemico dorato

Lo **Strisciante** (il nemico comune di base) ha una rarissima **variante dorata**: ogni stanza generata ha **1 probabilità su 4096** di far comparire lo Strisciante Dorato, molto più forte del normale e con un bottino leggendario garantito.

### Archivio e Bestiario

Dall'Hub sono raggiungibili due schermate persistenti (salvate su disco, sopravvivono tra una partita e l'altra):

- **Archivio dei Potenziamenti**: elenca tutti i potenziamenti del gioco; quelli mai raccolti restano "???" finché non li ottieni per la prima volta.
- **Bestiario**: elenca tutti gli avversari (nemici comuni, la variante dorata e i boss); un nemico resta "???" finché non lo sconfiggi per la prima volta.

### Impostazioni e uscita

Dall'Hub si raggiungono anche:

- **Impostazioni**: volume generale, risoluzione della finestra (vengono offerte solo le misure che stanno davvero nello spazio utilizzabile del tuo schermo, e la finestra viene ricentrata a ogni cambio invece di crescere fuori dal bordo), schermo intero e **riassegnazione dei tasti** di tutti i comandi di gioco (movimento, i due pulsanti d'attacco, addomesticamento, pausa). Assegnare un tasto della tastiera non tocca il binding del controller della stessa azione e viceversa, cosí i due dispositivi restano sempre utilizzabili insieme; gli assi analogici dello stick non sono riassegnabili e restano sempre attivi sul movimento. `Esc`/B annullano l'assegnazione in corso, e "Ripristina comandi" riporta tutto ai valori predefiniti. Ogni modifica viene applicata subito e salvata su disco, quindi sopravvive al riavvio. La navigazione qui è incatenata a mano (su/giù seguono l'ordine dell'elenco e dall'ultima voce si torna alla prima), cosí il controller non può mai "perdersi" tra i controlli.
- **Esci dal gioco**: chiude il software. Non serve salvare nulla a mano: progressi e impostazioni sono già su disco a ogni cambiamento.

Note:

- Il gioco ha un **sottofondo musicale durante le run** (`assets/audio/mines.mp3`, riprodotto in loop): parte quando inizia una run e si ferma tornando all'Hub, che resta silenzioso. Il loop riparte dal secondo 16 invece che da zero, cosí l'introduzione del brano si sente una volta sola a inizio run e poi gira solo il tema. Non ci sono ancora effetti sonori. Il cursore del volume agisce sul bus audio principale, quindi regola anche la musica.
- Eseguendo il gioco **dentro l'editor di Godot** la finestra può essere gestita dall'editor stesso (nelle versioni che incorporano l'anteprima di gioco) e non lasciarsi ridimensionare dal gioco: in quel caso le Impostazioni lo dicono esplicitamente e la scelta resta salvata, valida al primo avvio del gioco da solo. Per provare davvero il cambio di risoluzione conviene lanciare l'eseguibile esportato, o disattivare l'anteprima incorporata nell'editor.

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
assets/audio/mines.mp3        # sottofondo musicale delle run (importato con il loop attivo)
assets/images/amic_logo.png   # logo della schermata del titolo (sfondo ritagliato)
scripts/
  Main.gd                     # coordina Hub <-> Run
  core/InputSetup.gd          # azioni di input (tastiera + controller) registrate a codice
  core/MazeGrid.gd            # labirinto procedurale: generazione, collisione, pathfinding
  autoload/SaveManager.gd     # persistenza su user://: tre slot di progressi + impostazioni in comune
  data/GameData.gd            # dati di nemici, variante dorata, boss e potenziamenti
  data/Palette.gd             # linguaggio cromatico unico del gioco + tema dell'interfaccia
  entities/                   # Player, Enemy, Boss, EnemyProjectile, CombatEntity, ArenaVisual, BloodDecals, SpecialAttackEffect
  screens/Run.gd              # orchestratore di una run (stanze, boss, serie, salvataggio)
  core/GameSettings.gd        # impostazioni (audio, video, assegnazione tasti): applicazione e persistenza
  ui/                         # titolo, scelta salvataggio, Hub, Archivio, Bestiario, Tutorial, Impostazioni, scelta potenziamento, pausa, fine run, game over, HUD, Vignette, HudSigil
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
