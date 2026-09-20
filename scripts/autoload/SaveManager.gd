extends Node

# Salvataggio persistente: archivio potenziamenti, bestiario, statistiche
# e impostazioni (audio, video, assegnazione dei tasti).
# Sopravvive tra una run e l'altra e tra un avvio e l'altro del gioco.

const SAVE_PATH := "user://scatto_save.json"

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
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	archive = parsed.get("archive", {})
	bestiary = parsed.get("bestiary", {})
	settings = parsed.get("settings", {})
	var loaded_stats: Dictionary = parsed.get("stats", {})
	for key in stats.keys():
		if loaded_stats.has(key):
			stats[key] = loaded_stats[key]

func save_data() -> void:
	var data := {"archive": archive, "bestiary": bestiary, "stats": stats, "settings": settings}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

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

func reset_all() -> void:
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
	save_data()
