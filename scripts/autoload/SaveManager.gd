extends Node

# Salvataggio persistente: archivio potenziamenti, bestiario, statistiche
# e impostazioni (audio, video, assegnazione dei tasti).
# Sopravvive tra una run e l'altra e tra un avvio e l'altro del gioco.
#
# I progressi stanno su TRE slot indipendenti, scelti dal giocatore
# all'avvio (SaveSlotScreen). Le impostazioni invece sono UNA SOLA per
# tutto il gioco, in un file a parte: sono preferenze della persona che
# gioca, non progressi di una partita, e svuotare uno slot non deve
# costringere a rifare volume, risoluzione e tasti.

const SLOT_COUNT := 3
const SLOT_PATH_TEMPLATE := "user://scatto_save_%d.json"
const SETTINGS_PATH := "user://scatto_settings.json"
# Salvataggio unico dei primi tempi, prima che esistessero gli slot.
# Alla prima esecuzione il suo contenuto viene travasato nello slot 1 e
# nelle impostazioni globali, e il vecchio file rimosso.
const LEGACY_SAVE_PATH := "user://scatto_save.json"
# Il gioco si chiamava "Scatto": rinominandolo, Godot cambia anche la
# cartella dei dati utente, e i salvataggi di chi già giocava
# resterebbero in quella vecchia, invisibili. Alla prima esecuzione col
# nome nuovo vengono portati qui. I file si copiano, non si spostano:
# la cartella di prima resta com'è, come rete di sicurezza.
const LEGACY_USER_DIR_NAME := "Scatto"
const MIGRATED_FILE_NAMES := [
	"scatto_save_1.json", "scatto_save_2.json", "scatto_save_3.json",
	"scatto_settings.json", "scatto_save.json",
]

# Slot attualmente in uso (1..SLOT_COUNT). Parte da 1 come ripiego
# prudente: cosí qualunque salvataggio che avvenisse prima della scelta
# finisce comunque in uno slot valido invece che nel vuoto.
var current_slot := 1

var archive: Dictionary = {}
var bestiary: Dictionary = {}
# Preferenze del giocatore. Qui c'è solo il dato grezzo: a leggerlo,
# applicarlo al motore e riscriverlo ci pensa GameSettings.
var settings: Dictionary = {}
var stats: Dictionary = {
	"runs_started": 0,
	"runs_won": 0,
	"deaths": 0,
	"best_streak": 0,
	"golden_defeated": 0,
	"special_boss_defeated": 0,
}

func _ready() -> void:
	_migrate_legacy_user_dir()
	load_settings()
	_migrate_legacy_save()
	use_slot(current_slot)

# --- Slot -------------------------------------------------------------------

static func slot_path(slot: int) -> String:
	return SLOT_PATH_TEMPLATE % slot

static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT

# Passa a uno slot: da qui in poi ogni progresso registrato finisce lí.
func use_slot(slot: int) -> void:
	if not is_valid_slot(slot):
		return
	current_slot = slot
	load_data()

func slot_exists(slot: int) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(slot_path(slot))

# Riepilogo di uno slot senza entrarci dentro: serve alla schermata di
# scelta per mostrare che cosa contiene ciascuno prima di sceglierlo.
func slot_summary(slot: int) -> Dictionary:
	var summary := {
		"exists": false,
		"runs_won": 0,
		"best_streak": 0,
		"deaths": 0,
		"powerups": 0,
		"bestiary": 0,
	}
	if not slot_exists(slot):
		return summary
	var parsed = _read_json(slot_path(slot))
	if typeof(parsed) != TYPE_DICTIONARY:
		return summary
	summary.exists = true
	var slot_stats: Dictionary = parsed.get("stats", {})
	summary.runs_won = int(slot_stats.get("runs_won", 0))
	summary.best_streak = int(slot_stats.get("best_streak", 0))
	summary.deaths = int(slot_stats.get("deaths", 0))
	summary.powerups = (parsed.get("archive", {}) as Dictionary).size()
	summary.bestiary = (parsed.get("bestiary", {}) as Dictionary).size()
	return summary

# Svuota uno slot: il file sparisce del tutto, cosí "vuoto" è una cosa
# sola (il file non c'è) e non due (c'è ma è azzerato). Se è lo slot in
# uso, azzera anche i dati in memoria.
func clear_slot(slot: int) -> void:
	if not is_valid_slot(slot):
		return
	if FileAccess.file_exists(slot_path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
	if slot == current_slot:
		_reset_progress()

# --- Lettura e scrittura -----------------------------------------------------

func load_data() -> void:
	_reset_progress()
	var parsed = _read_json(slot_path(current_slot))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	archive = parsed.get("archive", {})
	bestiary = parsed.get("bestiary", {})
	var loaded_stats: Dictionary = parsed.get("stats", {})
	for key in stats.keys():
		if loaded_stats.has(key):
			stats[key] = loaded_stats[key]

func load_settings() -> void:
	var parsed = _read_json(SETTINGS_PATH)
	if typeof(parsed) == TYPE_DICTIONARY:
		settings = parsed

# Scrive progressi e impostazioni, ognuno nel proprio file. È un solo
# punto d'ingresso perché il resto del gioco non deve sapere che sono
# due file diversi.
func save_data() -> void:
	_write_json(slot_path(current_slot), {"archive": archive, "bestiary": bestiary, "stats": stats})
	_write_json(SETTINGS_PATH, settings)

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _reset_progress() -> void:
	archive = {}
	bestiary = {}
	stats = {
		"runs_started": 0,
		"runs_won": 0,
		"deaths": 0,
		"best_streak": 0,
		"golden_defeated": 0,
		"special_boss_defeated": 0,
	}

# Recupera i salvataggi rimasti nella cartella del vecchio nome del
# gioco. Non serve sapere come si chiami quella nuova: basta che sia la
# sorella di "Scatto" sotto lo stesso genitore, e questo vale su ogni
# piattaforma, perché a cambiare è solo il nome del progetto.
func _migrate_legacy_user_dir() -> void:
	var current_dir: String = OS.get_user_data_dir()
	var legacy_dir: String = current_dir.get_base_dir().path_join(LEGACY_USER_DIR_NAME)
	if legacy_dir == current_dir:
		return
	recover_saves_from(legacy_dir, current_dir)

# Copia i salvataggi da una cartella all'altra e dice quanti ne ha
# portati. È una funzione a sé, e non due righe dentro la migrazione,
# perché la regola che conta — non sovrascrivere mai quello che c'è già
# — si possa verificare senza dover rinominare il gioco.
func recover_saves_from(legacy_dir: String, current_dir: String) -> int:
	if not DirAccess.dir_exists_absolute(legacy_dir):
		return 0
	var recovered := 0
	for file_name in MIGRATED_FILE_NAMES:
		var source: String = legacy_dir.path_join(file_name)
		var destination: String = current_dir.path_join(file_name)
		# Mai sovrascrivere: se qui c'è già qualcosa, è più recente di
		# quello che si stava recuperando.
		if FileAccess.file_exists(source) and not FileAccess.file_exists(destination):
			if DirAccess.copy_absolute(source, destination) == OK:
				recovered += 1
	return recovered

# Chi giocava prima degli slot non deve perdere niente: il vecchio
# salvataggio unico diventa lo slot 1, le sue impostazioni diventano
# quelle globali, e il file di partenza viene rimosso perché la
# migrazione avvenga una volta sola.
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	if FileAccess.file_exists(slot_path(1)):
		return
	var parsed = _read_json(LEGACY_SAVE_PATH)
	if typeof(parsed) == TYPE_DICTIONARY:
		_write_json(slot_path(1), {
			"archive": parsed.get("archive", {}),
			"bestiary": parsed.get("bestiary", {}),
			"stats": parsed.get("stats", {}),
		})
		var legacy_settings: Dictionary = parsed.get("settings", {})
		if not legacy_settings.is_empty():
			settings = legacy_settings
			_write_json(SETTINGS_PATH, settings)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))

func unlock_powerup(id: String) -> bool:
	var is_new := not archive.has(id)
	if is_new:
		archive[id] = {"first_seen_at": Time.get_unix_time_from_system(), "times_collected": 1}
	else:
		archive[id]["times_collected"] += 1
	save_data()
	return is_new

func unlock_enemy(id: String) -> bool:
	var is_new := not bestiary.has(id)
	if is_new:
		bestiary[id] = {"first_defeated_at": Time.get_unix_time_from_system(), "times_defeated": 1}
	else:
		bestiary[id]["times_defeated"] += 1
	save_data()
	return is_new

func record_run_start() -> void:
	stats.runs_started += 1
	save_data()

func record_run_won(streak: int) -> void:
	stats.runs_won += 1
	if streak > stats.best_streak:
		stats.best_streak = streak
	save_data()

func record_death() -> void:
	stats.deaths += 1
	save_data()

func record_golden_defeated() -> void:
	stats.golden_defeated += 1
	save_data()

func record_special_boss_defeated() -> void:
	stats.special_boss_defeated += 1
	save_data()

func is_powerup_unlocked(id: String) -> bool:
	return archive.has(id)

func is_enemy_unlocked(id: String) -> bool:
	return bestiary.has(id)

# Azzera i progressi dello slot in uso, lasciando intatte le
# impostazioni: quelle non appartengono a una partita.
func reset_all() -> void:
	_reset_progress()
	save_data()
