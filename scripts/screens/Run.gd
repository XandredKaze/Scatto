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

# Stanze 1-5: labirinto procedurale, molto più grande dello schermo.
# Corridoi larghi e spessore delle pareti maggiorato per l'aspetto da
# galleria mineraria (vedi ArenaVisual per il rendering roccioso).
const MAZE_COLS := 8
const MAZE_ROWS := 6
const CELL_SIZE := 300.0
const WALL_THICKNESS := 34.0
# Sala del boss (6): arena aperta (niente pareti interne) ma comunque
# più grande della finestra di gioco, cosí anche lí la camera segue il
# giocatore invece di mostrare l'intera sala in un colpo solo.
const BOSS_ARENA_SIZE := Vector2(1920, 1080)
const WALL_MARGIN := 48.0
const SHOCKWAVE_RADIUS := 70.0
const SHOCKWAVE_RATIO := 0.4
# Addomesticamento: rende alleato un nemico comune nelle vicinanze (non
# dorato). Gli alleati restano con te finché non muoiono o non finisci/
# riavvii la run (persistono invece tra una stanza e l'altra, e tra le
# run consecutive di una stessa serie).
const MAX_ALLIES := 2
const TAME_RANGE := 180.0
# Attacchi speciali concessi dagli alleati (vedi GameData.ALLY_SPECIAL_ATTACKS
# e Player.granted_ability_id/special_attack_requested).
const LUNGE_OFFSET := 40.0
const LUNGE_RADIUS := 50.0
const LUNGE_DAMAGE := 18.0
const DART_SPEED := 420.0
const DART_DAMAGE := 14.0
const SLAM_RADIUS := 90.0
const SLAM_DAMAGE := 16.0
const SWARM_COUNT := 6
const SWARM_SPEED := 300.0
const SWARM_DAMAGE := 6.0

var player: Player
var current_boss: Boss = null
var room_number := 1
var streak_run_index := 0
var room_cleared := false
var run_start_snapshot: Dictionary = {}

var current_maze: MazeGrid = null
var arena_rect: Rect2
var rng := RandomNumberGenerator.new()
var allies: Array = []

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
var pause_screen: PauseScreen

func _ready() -> void:
	rng.randomize()
	debug_mode = OS.get_cmdline_user_args().has("--debug-scatto") or OS.get_cmdline_args().has("--debug-scatto")

	_build_scene_tree()
	_spawn_player()

func _build_scene_tree() -> void:
	arena_visual = ArenaVisual.new()
	arena_visual.wall_margin = WALL_MARGIN
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

	pause_screen = PauseScreen.new()
	pause_screen.run = self
	pause_screen.hub_pressed.connect(_on_hub_pressed)
	pause_screen.retry_pressed.connect(_retry_run)
	ui_layer.add_child(pause_screen)

func _spawn_player() -> void:
	player = Player.new()
	player.enemy_defeated.connect(_on_enemy_defeated)
	player.dash_hit.connect(_on_dash_hit)
	player.died.connect(_on_player_died)
	player.tame_requested.connect(_on_tame_requested)
	player.special_attack_requested.connect(_on_special_attack_requested)
	player_container.add_child(player)

# --- Ciclo di vita della run -------------------------------------------------

func begin_new_streak() -> void:
	player.reset_stats()
	streak_run_index = 1
	_clear_allies()
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
	run_start_snapshot = player.snapshot_stats()
	_generate_room(1)

func _retry_run() -> void:
	player.restore_stats(run_start_snapshot)
	room_number = 1
	current_boss = null
	_clear_allies()
	_generate_room(1)

# --- Generazione stanze -------------------------------------------------

func _generate_room(n: int) -> void:
	_clear_hostile_enemies()
	_clear_container(projectile_container)
	_clear_container(boss_container)
	room_cleared = false

	var maze := MazeGrid.new()
	maze.wall_thickness = WALL_THICKNESS
	maze.generate(MAZE_COLS, MAZE_ROWS, CELL_SIZE, rng)
	current_maze = maze
	arena_rect = Rect2()

	var spawn_cell := Vector2i(0, MAZE_ROWS - 1)

	arena_visual.maze = maze
	arena_visual.queue_redraw()

	player.maze = maze
	player.arena_bounds = Rect2()
	player.global_position = maze.cell_center(spawn_cell.x, spawn_cell.y)
	player.hit_enemies_this_dash.clear()
	_configure_camera_limits(maze.total_bounds())

	var excluded_cells: Array = [spawn_cell]
	excluded_cells.append_array(maze._open_neighbors(spawn_cell))

	_reposition_allies_maze(maze, spawn_cell, excluded_cells)

	var spawns := _build_room_spawns(n, maze, excluded_cells)
	var has_golden := false
	for spawn in spawns:
		var enemy := Enemy.new()
		enemy.maze = maze
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

func _configure_camera_limits(bounds: Rect2) -> void:
	if player.camera == null:
		return
	player.camera.limit_left = int(bounds.position.x)
	player.camera.limit_top = int(bounds.position.y)
	player.camera.limit_right = int(bounds.end.x)
	player.camera.limit_bottom = int(bounds.end.y)

func _build_room_spawns(room_num: int, maze: MazeGrid, excluded_cells: Array) -> Array:
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
		spawns.append({"data": t, "golden": false, "position": _random_enemy_point(maze, excluded_cells)})

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
			spawns[existing_index] = {"data": golden_data, "golden": true, "position": _random_enemy_point(maze, excluded_cells)}
		else:
			spawns.append({"data": golden_data, "golden": true, "position": _random_enemy_point(maze, excluded_cells)})

	return spawns

func _random_enemy_point(maze: MazeGrid, excluded_cells: Array) -> Vector2:
	var cell := maze.random_cell(rng, excluded_cells)
	return maze.cell_center(cell.x, cell.y)

# --- Combattimento e progressione -------------------------------------------------

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
	_damage_hostiles_in_radius(target.global_position, SHOCKWAVE_RADIUS, damage * SHOCKWAVE_RATIO, target)

# Danneggia ogni nemico/boss ostile (alleati sempre esclusi) entro
# `radius` da `center`, notificando Run se qualcuno viene ucciso.
# `exclude`, se impostato, salta quel nodo specifico (es. il bersaglio
# già colpito direttamente dallo scatto, per l'onda d'urto).
func _damage_hostiles_in_radius(center: Vector2, radius: float, damage: float, exclude: Node = null) -> void:
	for group in ["enemy", "boss"]:
		for other in get_tree().get_nodes_in_group(group):
			if other == exclude or not other.alive:
				continue
			if other is Enemy and other.is_ally:
				continue
			if center.distance_to(other.global_position) <= radius:
				other.take_damage(damage)
				if not other.alive:
					_on_enemy_defeated(other)

func _check_room_cleared() -> void:
	if room_cleared or current_boss != null:
		return
	for e in enemy_container.get_children():
		if e is Enemy and e.is_ally:
			continue
		if e.alive:
			return
	room_cleared = true
	# La ricompensa viene consegnata subito, senza dover raggiungere un
	# punto della stanza: non appena l'ultimo nemico ostile cade, si
	# passa direttamente alla scelta del potenziamento.
	var choices := _roll_powerup_choices(3)
	powerup_choice_screen.show()
	powerup_choice_screen.show_choices(choices, room_number)

# --- Alleati (addomesticamento) -------------------------------------------------

func _on_tame_requested() -> void:
	if allies.size() >= MAX_ALLIES:
		hud.show_banner("Hai già %d alleati al seguito (massimo)." % MAX_ALLIES, 2.0)
		return
	var candidate := _find_tameable_enemy()
	if candidate == null:
		hud.show_banner("Nessun nemico comune abbastanza vicino da addomesticare.", 2.0)
		return
	_convert_enemy_to_ally(candidate)

func _find_tameable_enemy() -> Enemy:
	var best: Enemy = null
	var best_dist := TAME_RANGE
	for c in enemy_container.get_children():
		if not (c is Enemy) or c.is_ally or c.is_golden or not c.alive:
			continue
		var d: float = player.global_position.distance_to(c.global_position)
		if d <= best_dist:
			best_dist = d
			best = c
	return best

func _convert_enemy_to_ally(enemy: Enemy) -> void:
	enemy.is_ally = true
	enemy.collision_mask = 2 | 4 | 8
	enemy.hp = enemy.max_hp
	enemy.ally_path = PackedVector2Array()
	enemy.defeated.connect(_on_ally_defeated.bind(enemy))
	enemy.ally_kill.connect(_on_enemy_defeated)
	allies.append(enemy)
	SaveManager.unlock_enemy(enemy.enemy_id)
	_sync_granted_ability()
	var ability_name: String = GameData.ALLY_SPECIAL_ATTACKS[enemy.enemy_id].name
	hud.show_banner("%s si è unito a te! Nuovo attacco speciale: %s" % [enemy.display_name, ability_name], 3.0)
	# L'addomesticamento non passa da _on_enemy_defeated (il nemico non è
	# stato sconfitto, è ancora vivo come alleato): se era l'ultimo nemico
	# ostile della stanza, va comunque verificato qui, altrimenti la
	# ricompensa non verrebbe mai consegnata.
	_check_room_cleared()

func _on_ally_defeated(ally) -> void:
	allies.erase(ally)
	var fallen_name: String = ally.display_name
	if is_instance_valid(ally):
		ally.queue_free()
	_sync_granted_ability()
	hud.show_banner("Il tuo alleato %s è caduto in battaglia." % fallen_name, 2.5)

func _clear_allies() -> void:
	for a in allies:
		if is_instance_valid(a):
			a.queue_free()
	allies.clear()
	_sync_granted_ability()

# L'attacco speciale concesso al giocatore riflette sempre l'alleato più
# di recente addomesticato tra quelli ancora vivi (ultimo in `allies`,
# dato che le nuove conversioni vengono accodate): se muore, l'abilità
# passa all'alleato superstite più recente, o sparisce se non ne resta
# nessuno.
func _sync_granted_ability() -> void:
	var latest_type := ""
	for a in allies:
		if is_instance_valid(a) and a.alive:
			latest_type = a.enemy_id
	player.granted_ability_id = latest_type

func _on_special_attack_requested(ability_id: String, origin: Vector2, dir: Vector2) -> void:
	match ability_id:
		"strisciante":
			_damage_hostiles_in_radius(origin + dir * LUNGE_OFFSET, LUNGE_RADIUS, LUNGE_DAMAGE)
		"pungiglione":
			_on_enemy_spawn_projectile(origin, dir, DART_SPEED, DART_DAMAGE, true)
		"corazzato":
			_damage_hostiles_in_radius(origin, SLAM_RADIUS, SLAM_DAMAGE)
		"sciame":
			for i in range(SWARM_COUNT):
				var angle: float = TAU * float(i) / float(SWARM_COUNT)
				_on_enemy_spawn_projectile(origin, Vector2(cos(angle), sin(angle)), SWARM_SPEED, SWARM_DAMAGE, true)
		_:
			return
	hud.show_banner("%s!" % GameData.ALLY_SPECIAL_ATTACKS[ability_id].name, 1.5)

func _clear_hostile_enemies() -> void:
	for c in enemy_container.get_children():
		if c is Enemy and c.is_ally:
			continue
		c.queue_free()

func _reposition_allies_maze(maze: MazeGrid, spawn_cell: Vector2i, excluded_cells: Array) -> void:
	if allies.is_empty():
		return
	var neighbor_cells: Array = maze._open_neighbors(spawn_cell)
	for i in range(allies.size()):
		var ally = allies[i]
		if not is_instance_valid(ally) or not ally.alive:
			continue
		ally.maze = maze
		ally.arena_bounds = Rect2()
		ally.ally_path = PackedVector2Array()
		var cell: Vector2i = neighbor_cells[i] if i < neighbor_cells.size() else spawn_cell
		ally.global_position = maze.cell_center(cell.x, cell.y)
	excluded_cells.append_array(neighbor_cells)

func _reposition_allies_open(rect: Rect2, near_pos: Vector2) -> void:
	if allies.is_empty():
		return
	for i in range(allies.size()):
		var ally = allies[i]
		if not is_instance_valid(ally) or not ally.alive:
			continue
		ally.maze = null
		ally.arena_bounds = rect
		ally.ally_path = PackedVector2Array()
		var side: float = 1.0 if i % 2 == 0 else -1.0
		ally.global_position = near_pos + Vector2(side * 40.0 * float(i + 1), 30.0)

func _on_boss_defeated(boss) -> void:
	SaveManager.record_run_won(streak_run_index)
	var was_special: bool = boss.is_special
	var boss_name: String = boss.display_name
	current_boss = null
	boss.queue_free()
	run_complete_screen.show_summary(streak_run_index, was_special, boss_name)
	run_complete_screen.show()
	if was_special:
		run_complete_screen.hub_btn.grab_focus()
	else:
		run_complete_screen.continue_btn.grab_focus()

func _roll_powerup_choices(count: int) -> Array:
	# I potenziamenti leggendari dei boss speciali già sconfitti almeno
	# una volta (in qualsiasi run precedente) entrano nello stesso pool
	# casuale dei potenziamenti comuni/rari, cosí possono ricomparire
	# come scelta di fine stanza oltre che come bottino garantito la
	# prima volta che si sconfigge quel boss. L'estrazione è pesata per
	# rarità (GameData.weighted_pick_without_replacement): un leggendario
	# resta un colpo di fortuna raro, non una scelta alla pari delle altre.
	var pool: Array = GameData.get_regular_powerup_pool().duplicate()
	pool.append_array(GameData.get_unlocked_boss_legendary_pool())
	return GameData.weighted_pick_without_replacement(pool, count, rng)

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
	var archetype: String = GameData.BOSS_ARCHETYPES[rng.randi_range(0, GameData.BOSS_ARCHETYPES.size() - 1)]
	var boss_id: String = (archetype + "_corrotto") if special else archetype
	var data: Dictionary = GameData.BOSSES[boss_id]

	_clear_hostile_enemies()
	_clear_container(projectile_container)
	_clear_container(boss_container)
	room_cleared = false

	current_maze = null
	arena_rect = Rect2(Vector2(WALL_MARGIN, WALL_MARGIN), BOSS_ARENA_SIZE - Vector2(WALL_MARGIN, WALL_MARGIN) * 2.0)

	arena_visual.maze = null
	arena_visual.arena_size = BOSS_ARENA_SIZE
	arena_visual.queue_redraw()

	player.maze = null
	player.arena_bounds = arena_rect
	player.global_position = Vector2(BOSS_ARENA_SIZE.x / 2.0, BOSS_ARENA_SIZE.y - WALL_MARGIN - 60.0)
	player.hit_enemies_this_dash.clear()
	_configure_camera_limits(arena_rect)

	_reposition_allies_open(arena_rect, player.global_position)

	var boss := Boss.new()
	boss.arena_bounds = arena_rect
	boss.setup_from_data(data)
	boss.global_position = Vector2(BOSS_ARENA_SIZE.x / 2.0, WALL_MARGIN + 90.0)
	boss.spawn_projectile.connect(_on_enemy_spawn_projectile)
	boss.melee_aoe.connect(_on_boss_melee_aoe)
	boss.summon_requested.connect(_on_boss_summon_requested)
	boss_container.add_child(boss)
	current_boss = boss

	hud.show_banner("%s si risveglia!" % data.name if special else "%s appare!" % data.name, 2.5)

func _on_boss_melee_aoe(origin: Vector2, radius: float, dmg: float) -> void:
	if player != null and player.alive and player.global_position.distance_to(origin) <= radius:
		player.take_damage(dmg)

func _on_boss_summon_requested(enemy_type_id: String, count: int, origin: Vector2) -> void:
	if not GameData.ENEMY_TYPES.has(enemy_type_id):
		return
	var data: Dictionary = GameData.ENEMY_TYPES[enemy_type_id]
	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var offset := Vector2(cos(angle), sin(angle)) * rng.randf_range(50.0, 110.0)
		var pos := origin + offset
		if arena_rect.size != Vector2.ZERO:
			pos.x = clamp(pos.x, arena_rect.position.x + 20.0, arena_rect.end.x - 20.0)
			pos.y = clamp(pos.y, arena_rect.position.y + 20.0, arena_rect.end.y - 20.0)
		var enemy := Enemy.new()
		enemy.maze = current_maze
		enemy.arena_bounds = arena_rect
		enemy.setup_from_data(data, false)
		enemy.global_position = pos
		enemy.spawn_projectile.connect(_on_enemy_spawn_projectile)
		enemy_container.add_child(enemy)

func _on_enemy_spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float, is_ally_projectile: bool = false) -> void:
	var proj := EnemyProjectile.new()
	proj.maze = current_maze
	proj.arena_bounds = arena_rect
	proj.is_ally_projectile = is_ally_projectile
	proj.setup(pos, dir, speed, dmg)
	if is_ally_projectile:
		proj.ally_kill.connect(_on_enemy_defeated)
	projectile_container.add_child(proj)

func _on_player_died() -> void:
	SaveManager.record_death()
	game_over_screen.show_summary(room_number, streak_run_index)
	game_over_screen.show()
	game_over_screen.hub_btn.grab_focus()
	streak_run_index = 0

func _on_continue_pressed() -> void:
	run_complete_screen.hide()
	_continue_streak()

func _on_hub_pressed() -> void:
	get_tree().paused = false
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
		if e is Enemy and e.is_ally:
			continue
		if e.alive:
			e.take_damage(99999.0)
			if not e.alive:
				_on_enemy_defeated(e)
	if current_boss != null and current_boss.alive:
		current_boss.take_damage(99999.0)
		if not current_boss.alive:
			_on_enemy_defeated(current_boss)
