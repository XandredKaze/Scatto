class_name Run
extends Node2D

# Orchestratore di una run: genera le stanze 1-5, la sala del boss (6),
# gestisce la scelta dei potenziamenti, la serie di run consecutive senza
# tornare all'Hub e le condizioni di vittoria/sconfitta.
#
# Modalità debug (solo se il gioco è avviato con l'argomento
# "--debug-scatto"): G forza la comparsa di un nemico dorato nella
# prossima stanza, K uccide tutti i nemici della stanza corrente,
# B salta direttamente alla sala del boss.

signal return_to_hub_requested

const ARENA_SIZE := Vector2(960, 540)
const WALL_MARGIN := 48.0
const EXIT_RADIUS := 28.0
const SHOCKWAVE_RADIUS := 70.0
const SHOCKWAVE_RATIO := 0.4

var player: Player
var current_boss: Boss = null
var room_number := 1
var streak_run_index := 0
var room_cleared := false

var arena_rect: Rect2
var exit_position: Vector2
var rng := RandomNumberGenerator.new()

var debug_mode := false
var debug_force_golden := false

var player_container: Node2D
var enemy_container: Node2D
var boss_container: Node2D
var projectile_container: Node2D
var arena_visual: ArenaVisual
var ui_layer: CanvasLayer
var hud: HUD
var powerup_choice_screen: PowerupChoiceScreen
var run_complete_screen: RunCompleteScreen
var game_over_screen: GameOverScreen

func _ready() -> void:
	rng.randomize()
	debug_mode = OS.get_cmdline_user_args().has("--debug-scatto") or OS.get_cmdline_args().has("--debug-scatto")

	arena_rect = Rect2(Vector2(WALL_MARGIN, WALL_MARGIN), ARENA_SIZE - Vector2(WALL_MARGIN, WALL_MARGIN) * 2.0)
	exit_position = Vector2(ARENA_SIZE.x / 2.0, WALL_MARGIN + 20.0)

	_build_scene_tree()
	_spawn_player()

func _build_scene_tree() -> void:
	arena_visual = ArenaVisual.new()
	arena_visual.arena_size = ARENA_SIZE
	arena_visual.wall_margin = WALL_MARGIN
	arena_visual.exit_position = exit_position
	arena_visual.exit_radius = EXIT_RADIUS
	add_child(arena_visual)

	player_container = Node2D.new()
	add_child(player_container)
	enemy_container = Node2D.new()
	add_child(enemy_container)
	boss_container = Node2D.new()
	add_child(boss_container)
	projectile_container = Node2D.new()
	add_child(projectile_container)

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	hud = HUD.new()
	hud.run = self
	ui_layer.add_child(hud)

	powerup_choice_screen = PowerupChoiceScreen.new()
	powerup_choice_screen.hide()
	powerup_choice_screen.powerup_selected.connect(_on_powerup_selected)
	ui_layer.add_child(powerup_choice_screen)

	run_complete_screen = RunCompleteScreen.new()
	run_complete_screen.hide()
	run_complete_screen.continue_pressed.connect(_on_continue_pressed)
	run_complete_screen.hub_pressed.connect(_on_hub_pressed)
	ui_layer.add_child(run_complete_screen)

	game_over_screen = GameOverScreen.new()
	game_over_screen.hide()
	game_over_screen.hub_pressed.connect(_on_hub_pressed)
	ui_layer.add_child(game_over_screen)

func _spawn_player() -> void:
	player = Player.new()
	player.arena_bounds = arena_rect
	player.enemy_defeated.connect(_on_enemy_defeated)
	player.dash_hit.connect(_on_dash_hit)
	player.died.connect(_on_player_died)
	player_container.add_child(player)

# --- Ciclo di vita della run -------------------------------------------------

func begin_new_streak() -> void:
	player.reset_stats()
	streak_run_index = 1
	_start_run_common()

func _continue_streak() -> void:
	streak_run_index += 1
	player.heal(player.max_hp * 0.2)
	player.alive = true
	_start_run_common()

func _start_run_common() -> void:
	SaveManager.record_run_start()
	room_number = 1
	current_boss = null
	_generate_room(1)

# --- Generazione stanze -------------------------------------------------

func _generate_room(n: int) -> void:
	_clear_container(enemy_container)
	_clear_container(projectile_container)
	room_cleared = false
	arena_visual.set_exit_active(false)
	player.global_position = Vector2(ARENA_SIZE.x / 2.0, ARENA_SIZE.y - WALL_MARGIN - 60.0)
	player.hit_enemies_this_dash.clear()

	var spawns := _build_room_spawns(n)
	var has_golden := false
	for spawn in spawns:
		var enemy := Enemy.new()
		enemy.arena_bounds = arena_rect
		enemy.setup_from_data(spawn.data, spawn.golden)
		enemy.global_position = spawn.position
		enemy.spawn_projectile.connect(_on_enemy_spawn_projectile)
		enemy_container.add_child(enemy)
		if spawn.golden:
			has_golden = true

	if has_golden:
		hud.show_banner("Senti una presenza dorata nella stanza...", 2.5)
	else:
		hud.show_banner("Stanza %d di 5" % n)

func _build_room_spawns(room_num: int) -> Array:
	var available: Array = []
	for key in GameData.ENEMY_TYPES.keys():
		var data: Dictionary = GameData.ENEMY_TYPES[key]
		if not data.has("min_room") or room_num >= int(data.min_room):
			available.append(data)

	var enemy_count: int = min(3 + int(room_num * 0.8), 8)
	var picks: Array = []
	while picks.size() < enemy_count:
		var t: Dictionary = available[rng.randi_range(0, available.size() - 1)]
		if t.has("group_min"):
			var group_count := rng.randi_range(int(t.group_min), int(t.group_max))
			for i in range(group_count):
				if picks.size() >= enemy_count + 3:
					break
				picks.append(t)
		else:
			picks.append(t)

	var spawns: Array = []
	for t in picks:
		spawns.append({"data": t, "golden": false, "position": _random_spawn_point()})

	var golden_triggered := debug_force_golden or rng.randi_range(0, GameData.GOLDEN_CHANCE_DENOMINATOR - 1) == 0
	debug_force_golden = false
	if golden_triggered:
		var golden_base_id: String = GameData.GOLDEN_VARIANTS.keys()[0]
		var golden_data := GameData.build_golden_enemy_data(golden_base_id)
		var existing_index := -1
		for i in range(spawns.size()):
			if spawns[i].data.id == golden_base_id:
				existing_index = i
				break
		if existing_index >= 0:
			spawns[existing_index] = {"data": golden_data, "golden": true, "position": _random_spawn_point()}
		else:
			spawns.append({"data": golden_data, "golden": true, "position": _random_spawn_point()})

	return spawns

func _random_spawn_point() -> Vector2:
	var margin := WALL_MARGIN + 40.0
	return Vector2(
		rng.randf_range(margin, ARENA_SIZE.x - margin),
		rng.randf_range(margin + 60.0, ARENA_SIZE.y - margin)
	)

# --- Combattimento e progressione -------------------------------------------------

func _physics_process(_delta: float) -> void:
	if room_cleared and current_boss == null and room_number <= 5 and player != null and player.alive:
		if player.global_position.distance_to(exit_position) <= EXIT_RADIUS:
			_on_room_exit()

func _on_enemy_defeated(entity) -> void:
	var is_boss: bool = entity is Boss
	var entity_id: String = entity.enemy_id if entity is Enemy else entity.boss_id
	var first_bestiary := SaveManager.unlock_enemy(entity_id)

	if entity is Enemy and entity.is_golden:
		SaveManager.record_golden_defeated()
	if is_boss and entity.is_special:
		SaveManager.record_special_boss_defeated()

	var drop_id: String = entity.guaranteed_drop
	if drop_id != "":
		player.apply_powerup(drop_id)
		SaveManager.unlock_powerup(drop_id)
		hud.show_banner("Bottino raro: %s!" % GameData.get_powerup(drop_id).name, 2.5)
	elif first_bestiary:
		hud.show_banner("Nuova creatura scoperta: %s" % entity.display_name, 2.0)

	if is_boss:
		_on_boss_defeated(entity)
	else:
		_check_room_cleared()

func _on_dash_hit(target, damage: float) -> void:
	if not player.has_shockwave:
		return
	var origin: Vector2 = target.global_position
	for group in ["enemy", "boss"]:
		for other in get_tree().get_nodes_in_group(group):
			if other == target or not other.alive:
				continue
			if origin.distance_to(other.global_position) <= SHOCKWAVE_RADIUS:
				other.take_damage(damage * SHOCKWAVE_RATIO)
				if not other.alive:
					_on_enemy_defeated(other)

func _check_room_cleared() -> void:
	if room_cleared:
		return
	for e in enemy_container.get_children():
		if e.alive:
			return
	room_cleared = true
	arena_visual.set_exit_active(true)
	hud.show_banner("Stanza ripulita! Raggiungi il portale.", 2.5)

func _on_boss_defeated(boss) -> void:
	SaveManager.record_run_won(streak_run_index)
	var was_special: bool = boss.is_special
	current_boss = null
	run_complete_screen.show_summary(streak_run_index, was_special)
	run_complete_screen.show()

func _on_room_exit() -> void:
	# Disattiva subito il portale: restare fermi al suo interno non deve
	# far comparire la scelta del potenziamento ad ogni frame.
	room_cleared = false
	arena_visual.set_exit_active(false)
	var choices := _roll_powerup_choices(3)
	powerup_choice_screen.show_choices(choices, room_number)
	powerup_choice_screen.show()

func _roll_powerup_choices(count: int) -> Array:
	var pool: Array = GameData.get_regular_powerup_pool().duplicate()
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

func _on_powerup_selected(id: String) -> void:
	player.apply_powerup(id)
	SaveManager.unlock_powerup(id)
	powerup_choice_screen.hide()
	_advance_after_room_clear()

func _advance_after_room_clear() -> void:
	if room_number >= 5:
		_start_boss_room()
	else:
		room_number += 1
		_generate_room(room_number)

func _start_boss_room() -> void:
	room_number = 6
	var special := streak_run_index >= 3
	var data: Dictionary = GameData.BOSSES["custode_corrotto"] if special else GameData.BOSSES["custode"]

	_clear_container(enemy_container)
	_clear_container(projectile_container)
	room_cleared = false
	arena_visual.set_exit_active(false)
	player.global_position = Vector2(ARENA_SIZE.x / 2.0, ARENA_SIZE.y - WALL_MARGIN - 60.0)
	player.hit_enemies_this_dash.clear()

	var boss := Boss.new()
	boss.arena_bounds = arena_rect
	boss.setup_from_data(data)
	boss.spawn_projectile.connect(_on_enemy_spawn_projectile)
	boss_container.add_child(boss)
	current_boss = boss

	hud.show_banner("Il Custode Corrotto si risveglia!" if special else "Il Custode appare!", 2.5)

func _on_enemy_spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float) -> void:
	var proj := EnemyProjectile.new()
	proj.arena_bounds = arena_rect
	proj.setup(pos, dir, speed, dmg)
	projectile_container.add_child(proj)

func _on_player_died() -> void:
	SaveManager.record_death()
	game_over_screen.show_summary(room_number, streak_run_index)
	game_over_screen.show()
	streak_run_index = 0

func _on_continue_pressed() -> void:
	run_complete_screen.hide()
	_continue_streak()

func _on_hub_pressed() -> void:
	return_to_hub_requested.emit()

func _clear_container(container: Node) -> void:
	for c in container.get_children():
		c.queue_free()

# --- Debug (solo con --debug-scatto) -------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_mode or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_G:
			debug_force_golden = true
		KEY_K:
			_debug_kill_all()
		KEY_B:
			if current_boss == null:
				_start_boss_room()

func _debug_kill_all() -> void:
	for e in enemy_container.get_children():
		if e.alive:
			e.take_damage(99999.0)
			if not e.alive:
				_on_enemy_defeated(e)
	if current_boss != null and current_boss.alive:
		current_boss.take_damage(99999.0)
		if not current_boss.alive:
			_on_enemy_defeated(current_boss)
