class_name BalanceConfig
extends Resource

## Tutti i valori di bilanciamento del gioco, modificabili dall'editor.
##
## Apri [code]res://bilanciamento.tres[/code] dal pannello FileSystem di
## Godot: i valori compaiono nell'Inspector, divisi per gruppi. Salva
## (Ctrl+S) e avvia il gioco: le modifiche valgono subito, senza toccare
## il codice. Accanto a ogni valore cambiato Godot mostra una freccia per
## tornare al valore originale.
##
## I valori di partenza sono quelli con cui il gioco è stato tarato: se
## [code]bilanciamento.tres[/code] manca o è rovinato, si usano questi.

const PATH := "res://bilanciamento.tres"

static var _current: BalanceConfig = null
# Cresce ogni volta che cambia la configurazione in uso: chi tiene dati
# derivati in memoria (GameData) sa cosí quando rigenerarli.
static var version := 0

## La configurazione in uso. Viene letta da disco la prima volta.
static func current() -> BalanceConfig:
	if _current == null:
		var loaded: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
		_current = loaded as BalanceConfig if loaded is BalanceConfig else BalanceConfig.new()
		version += 1
	return _current

## Sostituisce la configurazione in uso (serve ai test). `null` torna a
## quella su disco alla prossima lettura.
static func use(config: BalanceConfig) -> void:
	_current = config
	version += 1

# =============================================================================
@export_group("Giocatore", "giocatore_")
## Punti vita con cui si comincia ogni serie di run.
@export_range(1, 1000, 1, "or_greater") var giocatore_vita := 100.0
## Velocità di camminata, in pixel al secondo.
@export_range(10, 1000, 1, "or_greater") var giocatore_velocità := 220.0
## Danno di base dello scatto, prima di potenziamenti e Furia.
@export_range(0, 500, 1, "or_greater") var giocatore_danno_scatto := 22.0
## Velocità durante lo scatto, in pixel al secondo. Insieme alla durata
## decide quanta strada copre uno scatto.
@export_range(100, 5000, 10, "or_greater") var giocatore_velocità_scatto := 900.0
## Quanto dura uno scatto, in secondi. Durante lo scatto si è invulnerabili.
@export_range(0.02, 2.0, 0.01, "or_greater") var giocatore_durata_scatto := 0.16
## Secondi per ricaricare una carica di scatto.
@export_range(0.05, 10.0, 0.01, "or_greater") var giocatore_ricarica_scatto := 0.55
## Cariche di scatto disponibili a inizio serie.
@export_range(1, 10, 1, "or_greater") var giocatore_cariche_scatto := 1
## Secondi di invulnerabilità dopo aver subito un colpo.
@export_range(0.0, 5.0, 0.05, "or_greater") var giocatore_invulnerabilità_dopo_colpo := 0.8
## Quanto un colpo subito ti spinge indietro, in pixel.
@export_range(0.0, 200.0, 1.0, "or_greater") var giocatore_respinta := 20.0

# =============================================================================
@export_group("Alleati e addomesticamento", "alleati_")
## Quanti alleati puoi avere al seguito insieme. Ogni alleato occupa uno
## dei due pulsanti d'attacco speciale, quindi il massimo è 2; a 0
## l'addomesticamento è disattivato.
@export_range(0, 2, 1) var alleati_massimo := 2
## Distanza massima, in pixel, a cui puoi addomesticare un nemico.
@export_range(10, 1000, 5, "or_greater") var alleati_raggio := 180.0
## Secondi di attesa fra un addomesticamento e l'altro.
@export_range(0.0, 120.0, 0.5, "or_greater") var alleati_ricarica := 14.0

# =============================================================================
@export_group("Attacchi speciali degli alleati")
@export_subgroup("Morso Selvaggio (Strisciante)", "speciale_morso_")
## Danno del morso, prima dei potenziamenti.
@export_range(0, 500, 1, "or_greater") var speciale_morso_danno := 45.0
## Raggio della zona colpita, in pixel.
@export_range(5, 500, 1, "or_greater") var speciale_morso_raggio := 50.0
## Quanto davanti a te cade il morso, in pixel.
@export_range(0, 300, 1, "or_greater") var speciale_morso_portata := 40.0
## Secondi fra un morso e l'altro.
@export_range(0.05, 30.0, 0.05, "or_greater") var speciale_morso_ricarica := 2.0
@export_subgroup("Dardo Velenoso (Pungiglione)", "speciale_dardo_")
## Danno di ogni dardo, prima dei potenziamenti.
@export_range(0, 500, 1, "or_greater") var speciale_dardo_danno := 13.0
## Velocità del dardo, in pixel al secondo.
@export_range(10, 3000, 10, "or_greater") var speciale_dardo_velocità := 420.0
## Secondi fra un dardo e l'altro.
@export_range(0.05, 30.0, 0.05, "or_greater") var speciale_dardo_ricarica := 0.5
@export_subgroup("Colpo Corazzato (Corazzato)", "speciale_colpo_")
## Danno dell'onda d'urto, prima dei potenziamenti.
@export_range(0, 500, 1, "or_greater") var speciale_colpo_danno := 28.0
## Raggio dell'onda d'urto intorno a te, in pixel.
@export_range(5, 1000, 1, "or_greater") var speciale_colpo_raggio := 90.0
## Secondi fra un colpo e l'altro.
@export_range(0.05, 30.0, 0.05, "or_greater") var speciale_colpo_ricarica := 1.5
@export_subgroup("Sciame Vendicativo (Sciame)", "speciale_raffica_")
## Danno di ogni proiettile, prima dei potenziamenti.
@export_range(0, 500, 1, "or_greater") var speciale_raffica_danno := 12.0
## Quanti proiettili parte, in cerchio.
@export_range(1, 64, 1, "or_greater") var speciale_raffica_proiettili := 6
## Velocità dei proiettili, in pixel al secondo.
@export_range(10, 3000, 10, "or_greater") var speciale_raffica_velocità := 300.0
## Secondi fra una raffica e l'altra.
@export_range(0.05, 30.0, 0.05, "or_greater") var speciale_raffica_ricarica := 1.1
@export_subgroup("Versione potenziata (due alleati dello stesso tipo)", "potenziato_")
## Moltiplicatore di danno di Morso Selvaggio e Colpo Corazzato potenziati.
@export_range(1.0, 10.0, 0.05, "or_greater") var potenziato_moltiplicatore_danno := 1.75
## Dardo Velenoso potenziato spara un secondo dardo, deviato di questi gradi.
@export_range(0.0, 90.0, 0.5) var potenziato_scarto_secondo_dardo := 14.32
## Proiettili di Sciame Vendicativo potenziato.
@export_range(1, 64, 1, "or_greater") var potenziato_proiettili_raffica := 10

# =============================================================================
@export_group("Nemici")
@export_subgroup("Strisciante", "strisciante_")
@export_range(1, 5000, 1, "or_greater") var strisciante_vita := 30.0
## Pixel al secondo.
@export_range(0, 1000, 1, "or_greater") var strisciante_velocità := 95.0
## Danno di ogni morso.
@export_range(0, 500, 1, "or_greater") var strisciante_danno := 8.0
## Secondi minimi fra due colpi da contatto.
@export_range(0.05, 10.0, 0.05, "or_greater") var strisciante_ricarica_contatto := 0.6
## Secondi in cui si ferma a caricare il morso: è il momento buono per colpirlo.
@export_range(0.0, 5.0, 0.01, "or_greater") var strisciante_preparazione_morso := 0.3
## Secondi di pausa dopo il morso, prima di tornare a inseguire.
@export_range(0.0, 5.0, 0.01, "or_greater") var strisciante_recupero_morso := 0.45

@export_subgroup("Pungiglione", "pungiglione_")
@export_range(1, 5000, 1, "or_greater") var pungiglione_vita := 20.0
## Pixel al secondo.
@export_range(0, 1000, 1, "or_greater") var pungiglione_velocità := 75.0
## Danno di ogni dardo.
@export_range(0, 500, 1, "or_greater") var pungiglione_danno := 6.0
## Distanza, in pixel, a cui cerca di restare dalla preda.
@export_range(0, 2000, 5, "or_greater") var pungiglione_distanza := 190.0
## Secondi fra un dardo e l'altro.
@export_range(0.05, 30.0, 0.05, "or_greater") var pungiglione_ricarica_tiro := 1.4
## Velocità dei dardi, in pixel al secondo.
@export_range(10, 3000, 10, "or_greater") var pungiglione_velocità_dardo := 260.0
## Distanza minima, in pixel, fra dove sprofonda e dove rispunta.
@export_range(0, 1000, 5, "or_greater") var pungiglione_sprofondamento_min := 70.0
## Distanza massima, in pixel, fra dove sprofonda e dove rispunta.
@export_range(0, 2000, 5, "or_greater") var pungiglione_sprofondamento_max := 180.0

@export_subgroup("Corazzato", "corazzato_")
@export_range(1, 5000, 1, "or_greater") var corazzato_vita := 75.0
## Pixel al secondo (fra un balzo e l'altro va più veloce, vedi sotto).
@export_range(0, 1000, 1, "or_greater") var corazzato_velocità := 55.0
## Danno da contatto.
@export_range(0, 500, 1, "or_greater") var corazzato_danno := 16.0
## Secondi minimi fra due colpi da contatto.
@export_range(0.05, 10.0, 0.05, "or_greater") var corazzato_ricarica_contatto := 0.8
## Prima mappa della run in cui può comparire.
@export_range(1, 5, 1) var corazzato_dalla_mappa := 3
## Quanto va più veloce durante il balzo rispetto alla sua velocità.
@export_range(0.0, 10.0, 0.05, "or_greater") var corazzato_moltiplicatore_balzo := 2.3
## Raggio dell'onda d'urto a ogni atterraggio, in pixel.
@export_range(0, 1000, 1, "or_greater") var corazzato_raggio_onda := 54.0
## Danno dell'onda d'urto, in percentuale del suo danno da contatto.
@export_range(0, 500, 1, "or_greater", "suffix:%") var corazzato_danno_onda := 35.0

@export_subgroup("Sciame", "sciame_")
@export_range(1, 5000, 1, "or_greater") var sciame_vita := 10.0
## Pixel al secondo.
@export_range(0, 1000, 1, "or_greater") var sciame_velocità := 135.0
## Danno da contatto.
@export_range(0, 500, 1, "or_greater") var sciame_danno := 5.0
## Secondi minimi fra due colpi da contatto.
@export_range(0.05, 10.0, 0.05, "or_greater") var sciame_ricarica_contatto := 0.5
## Prima mappa della run in cui può comparire.
@export_range(1, 5, 1) var sciame_dalla_mappa := 2
## Insetti minimi per sciame.
@export_range(1, 30, 1, "or_greater") var sciame_gruppo_min := 3
## Insetti massimi per sciame.
@export_range(1, 30, 1, "or_greater") var sciame_gruppo_max := 5
## Distanza dalla preda, in pixel, a cui si ferma a caricare la picchiata.
@export_range(0, 2000, 5, "or_greater") var sciame_portata_carica := 240.0
## Secondi di carica prima della picchiata: è il momento buono per colpirlo.
@export_range(0.0, 10.0, 0.05, "or_greater") var sciame_durata_carica := 1.5
## Velocità della picchiata, in pixel al secondo.
@export_range(10, 3000, 10, "or_greater") var sciame_velocità_picchiata := 520.0
## Durata della picchiata, in secondi.
@export_range(0.02, 5.0, 0.01, "or_greater") var sciame_durata_picchiata := 0.32
## Secondi di pausa dopo la picchiata.
@export_range(0.0, 10.0, 0.05, "or_greater") var sciame_recupero := 0.7

@export_subgroup("Strisciante Dorato", "dorato_")
## Probabilità che compaia in una mappa: una su questo numero.
@export_range(1, 100000, 1, "or_greater") var dorato_una_su := 4096
## Moltiplicatore della vita dello Strisciante.
@export_range(0.1, 50.0, 0.05, "or_greater") var dorato_moltiplicatore_vita := 3.5
## Moltiplicatore della velocità dello Strisciante.
@export_range(0.1, 10.0, 0.05, "or_greater") var dorato_moltiplicatore_velocità := 1.3
## Moltiplicatore del danno dello Strisciante.
@export_range(0.1, 20.0, 0.05, "or_greater") var dorato_moltiplicatore_danno := 1.5

# =============================================================================
@export_group("Boss")
@export_subgroup("Ritmo degli attacchi (tutti i boss)", "boss_")
## Secondi di inseguimento fra un attacco e l'altro, a vita piena.
@export_range(0.1, 20.0, 0.05, "or_greater") var boss_pausa := 1.8
## Pausa minima fra un attacco e l'altro, anche quando il boss è infuriato.
@export_range(0.05, 20.0, 0.05, "or_greater") var boss_pausa_minima := 0.6
## Quanto il boss accelera il ritmo man mano che perde vita: a vita zero
## la pausa fra gli attacchi si accorcia di questa percentuale in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var boss_aggressività := 60.0
## Secondi di avviso prima di ogni attacco (il lampo che lo annuncia).
@export_range(0.0, 5.0, 0.05, "or_greater") var boss_avviso := 0.5
## Secondi di pausa dopo ogni attacco.
@export_range(0.0, 5.0, 0.05, "or_greater") var boss_recupero := 0.5
## Durante la carica il boss va più veloce di questo fattore.
@export_range(0.1, 20.0, 0.1, "or_greater") var boss_velocità_carica := 3.2
## Durata della carica, in secondi.
@export_range(0.05, 5.0, 0.05, "or_greater") var boss_durata_carica := 0.4
@export_subgroup("Custode", "custode_")
@export_range(1, 20000, 1, "or_greater") var custode_vita := 320.0
@export_range(0, 1000, 1, "or_greater") var custode_velocità := 65.0
@export_range(0, 500, 1, "or_greater") var custode_danno := 18.0
@export_subgroup("Custode Corrotto", "custode_corrotto_")
@export_range(1, 20000, 1, "or_greater") var custode_corrotto_vita := 480.0
@export_range(0, 1000, 1, "or_greater") var custode_corrotto_velocità := 75.0
@export_range(0, 500, 1, "or_greater") var custode_corrotto_danno := 24.0
@export_subgroup("Colosso di Pietra", "colosso_")
@export_range(1, 20000, 1, "or_greater") var colosso_vita := 420.0
@export_range(0, 1000, 1, "or_greater") var colosso_velocità := 45.0
@export_range(0, 500, 1, "or_greater") var colosso_danno := 20.0
@export_subgroup("Colosso Corrotto", "colosso_corrotto_")
@export_range(1, 20000, 1, "or_greater") var colosso_corrotto_vita := 620.0
@export_range(0, 1000, 1, "or_greater") var colosso_corrotto_velocità := 50.0
@export_range(0, 500, 1, "or_greater") var colosso_corrotto_danno := 27.0
@export_subgroup("Spettro Errante", "spettro_")
@export_range(1, 20000, 1, "or_greater") var spettro_vita := 260.0
@export_range(0, 1000, 1, "or_greater") var spettro_velocità := 85.0
@export_range(0, 500, 1, "or_greater") var spettro_danno := 14.0
@export_subgroup("Spettro Corrotto", "spettro_corrotto_")
@export_range(1, 20000, 1, "or_greater") var spettro_corrotto_vita := 380.0
@export_range(0, 1000, 1, "or_greater") var spettro_corrotto_velocità := 95.0
@export_range(0, 500, 1, "or_greater") var spettro_corrotto_danno := 18.0

# =============================================================================
@export_group("Potenziamenti", "potenziamento_")
## Lama Rapida: danno da scatto in più.
@export_range(0, 200, 1, "or_greater") var potenziamento_lama_rapida_danno := 6.0
## Passo Veloce: velocità di movimento in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_passo_veloce_velocità := 15.0
## Scatto Lungo: distanza dello scatto in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_scatto_lungo_distanza := 25.0
## Cuore di Ferro: punti vita massimi in più.
@export_range(0, 1000, 1, "or_greater") var potenziamento_cuore_di_ferro_vita := 25.0
## Zanne Affilate: danno degli attacchi speciali in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_zanne_affilate_danno := 15.0
## Richiamo Rapido: riduzione del tempo di recupero dell'addomesticamento.
@export_range(0, 95, 1, "suffix:%") var potenziamento_richiamo_rapido_riduzione := 20.0
## Pelle Coriacea: vita massima degli alleati in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_pelle_coriacea_vita := 35.0
## Istinto di Branco: danno inflitto dagli alleati in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_istinto_di_branco_danno := 30.0
## Scatto Fulmine: riduzione del tempo di ricarica dello scatto.
@export_range(0, 95, 1, "suffix:%") var potenziamento_scatto_fulmine_riduzione := 20.0
## Scatto Fantasma: secondi di invulnerabilità in più dopo lo scatto.
@export_range(0.0, 5.0, 0.01, "or_greater") var potenziamento_scatto_fantasma_invulnerabilità := 0.15
## Doppio Scatto: cariche di scatto in più.
@export_range(1, 10, 1, "or_greater") var potenziamento_doppio_scatto_cariche := 1
## Furia: danno da scatto in più quando si è quasi senza vita (cresce man mano
## che si perde vita, fino a questo valore).
@export_range(0, 1000, 1, "or_greater", "suffix:%") var potenziamento_furia_danno_massimo := 50.0
## Eco Selvaggia: riduzione del tempo di recupero degli attacchi speciali.
@export_range(0, 95, 1, "suffix:%") var potenziamento_eco_selvaggia_riduzione := 25.0
## Vincolo Vitale: vita recuperata quando cade un alleato.
@export_range(0, 1000, 1, "or_greater") var potenziamento_vincolo_vitale_cura := 30.0
## Passo del Predatore: velocità di movimento in più mentre hai un alleato.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_passo_del_predatore_velocità := 25.0
## Cuore Dorato (bottino dello Strisciante Dorato): vita massima in più.
@export_range(0, 1000, 1, "or_greater") var potenziamento_cuore_dorato_vita := 40.0
## Cuore Dorato: danno da scatto in più.
@export_range(0, 200, 1, "or_greater") var potenziamento_cuore_dorato_danno := 10.0
## Benedizione del Custode: raggio dell'onda d'urto dello scatto, in pixel.
@export_range(0, 1000, 1, "or_greater") var potenziamento_benedizione_raggio := 70.0
## Benedizione del Custode: danno dell'onda, in percentuale del danno da scatto.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_benedizione_danno := 40.0
## Corazza di Magma: vita massima in più.
@export_range(0, 1000, 1, "or_greater") var potenziamento_corazza_di_magma_vita := 80.0
## Corazza di Magma: danno da scatto in più.
@export_range(0, 200, 1, "or_greater") var potenziamento_corazza_di_magma_danno := 8.0
## Velo Spettrale: velocità di movimento in più.
@export_range(0, 500, 1, "or_greater", "suffix:%") var potenziamento_velo_spettrale_velocità := 25.0
## Velo Spettrale: secondi di invulnerabilità in più dopo lo scatto.
@export_range(0.0, 5.0, 0.01, "or_greater") var potenziamento_velo_spettrale_invulnerabilità := 0.2

# =============================================================================
@export_group("Ricompense", "ricompense_")
## Quanti potenziamenti vengono proposti oltre la porta di ogni mappa.
@export_range(1, 3, 1) var ricompense_scelte := 3
## Peso di estrazione dei potenziamenti comuni. Conta il rapporto fra i
## tre pesi: con 12 / 4 / 1 un comune esce 12 volte più spesso di un
## leggendario.
@export_range(0.0, 1000.0, 0.5, "or_greater") var ricompense_peso_comune := 12.0
## Peso di estrazione dei potenziamenti rari.
@export_range(0.0, 1000.0, 0.5, "or_greater") var ricompense_peso_raro := 4.0
## Peso di estrazione dei leggendari (solo quelli dei boss corrotti già
## sconfitti almeno una volta).
@export_range(0.0, 1000.0, 0.5, "or_greater") var ricompense_peso_leggendario := 1.0

# =============================================================================
@export_group("Mappe", "mappe_")
## Nemici nella prima mappa (prima di aggiungere quelli per mappa).
@export_range(0, 50, 1, "or_greater") var mappe_nemici_base := 3
## Nemici in più a ogni mappa successiva (si arrotonda per difetto).
@export_range(0.0, 10.0, 0.1, "or_greater") var mappe_nemici_per_mappa := 0.8
## Tetto al numero di nemici di una mappa (gli sciami possono sforarlo di poco).
@export_range(1, 100, 1, "or_greater") var mappe_nemici_massimi := 8
## Larghezza della mappa, in celle da 150 px.
@export_range(10, 60, 1) var mappe_colonne := 22
## Altezza della mappa, in celle da 150 px.
@export_range(10, 60, 1) var mappe_righe := 16
## Lato minimo di una sala, in celle.
@export_range(2, 10, 1) var mappe_sala_minima := 3
## Lato massimo di una sala, in celle.
@export_range(2, 20, 1) var mappe_sala_massima := 6
## Corridoi oltre a quelli indispensabili, per chiudere degli anelli.
@export_range(0, 10, 1) var mappe_corridoi_extra := 2

# =============================================================================
@export_group("Serie di run", "serie_")
## Vita recuperata passando a una nuova run senza tornare all'Hub, in
## percentuale della vita massima.
@export_range(0, 100, 1, "suffix:%") var serie_cura_fra_run := 20.0
## Da quale run consecutiva (senza tornare all'Hub) compare il boss corrotto.
@export_range(1, 20, 1) var serie_run_boss_corrotto := 3
