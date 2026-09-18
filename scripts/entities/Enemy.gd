class_name Enemy
extends CombatEntity

# Nemico comune di stanza. Il comportamento "chase" insegue il giocatore,
# "ranged" mantiene le distanze e spara proiettili. setup_from_data()
# deve essere chiamato PRIMA di aggiungere il nodo all'albero, cosí che
# _ready() costruisca la CollisionShape2D con il raggio corretto.
#
# Se `maze` è impostato, il movimento segue un percorso calcolato con
# MazeGrid.get_path() (pathfinding reale attraverso i corridoi) invece
# di puntare in linea retta verso il giocatore; altrimenti (stanze senza
# labirinto, o nei test isolati) si comporta come prima con
# `arena_bounds`. Il percorso è ricalcolato periodicamente, non ad ogni
# frame, per restare economico anche con molti nemici in campo.

signal spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float)

var enemy_id := "strisciante"
var display_name := "Strisciante"
var desc := ""
var speed := 95.0
var behavior := "chase"
var keep_distance := 190.0
var attack_cooldown := 1.4
var projectile_speed := 260.0
var is_golden := false
var guaranteed_drop := ""

var attack_timer := 0.0
var arena_bounds: Rect2 = Rect2()
var maze: MazeGrid = null
var current_path: PackedVector2Array = PackedVector2Array()
var path_target_index := 0
var path_recalc_timer := 0.0

# Alleato: convertito da nemico comune tramite l'abilità speciale del
# giocatore (Run._convert_enemy_to_ally). Da questo momento insegue e
# attacca gli altri nemici invece del giocatore, riusando lo stesso
# sistema di pathfinding/collisione ma con logica di movimento e
# combattimento dedicata (vedi _physics_process_ally sotto).
var is_ally := false
const ALLY_ENGAGE_RADIUS := 260.0
const ALLY_FOLLOW_DISTANCE := 130.0
var ally_path: PackedVector2Array = PackedVector2Array()
var ally_path_target_index := 0
var ally_path_recalc_timer := 0.0

func setup_from_data(data: Dictionary, golden: bool) -> void:
	enemy_id = data.id
	display_name = data.name
	desc = data.desc
	max_hp = data.hp
	hp = data.hp
	speed = data.speed
	damage = data.damage
	radius = data.radius
	color = data.color
	behavior = data.get("behavior", "chase")
	contact_cooldown = data.get("contact_cooldown", 0.6)
	keep_distance = data.get("keep_distance", 190.0)
	attack_cooldown = data.get("attack_cooldown", 1.4)
	projectile_speed = data.get("projectile_speed", 260.0)
	guaranteed_drop = data.get("guaranteed_drop", "")
	is_golden = golden

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	super._ready()
	add_to_group("enemy")
	attack_timer = randf() * attack_cooldown if attack_cooldown > 0.0 else 0.0
	path_recalc_timer = randf() * 0.3

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if is_ally:
		_physics_process_ally(delta, player)
		return
	if maze != null:
		_physics_process_maze(delta, player)
	else:
		_physics_process_direct(delta, player)

func _physics_process_direct(delta: float, player: Node) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO
	match behavior:
		"chase":
			global_position += dir * speed * delta
		"ranged":
			var d := to_player.length()
			if d < keep_distance - 15.0:
				global_position -= dir * speed * delta
			elif d > keep_distance + 15.0:
				global_position += dir * speed * delta
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				spawn_projectile.emit(global_position, dir, projectile_speed, damage)
	_clamp_to_arena()

func _physics_process_maze(delta: float, player: Node) -> void:
	path_recalc_timer -= delta
	if path_recalc_timer <= 0.0 or current_path.size() < 2:
		current_path = maze.get_path(global_position, player.global_position)
		path_target_index = 1 if current_path.size() > 1 else 0
		path_recalc_timer = 0.35 + randf() * 0.25

	var to_player: Vector2 = player.global_position - global_position
	var straight_dist: float = to_player.length()

	match behavior:
		"chase":
			_move_along_path(delta, player)
		"ranged":
			if straight_dist > keep_distance + 15.0:
				_move_along_path(delta, player)
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				var dir: Vector2 = to_player.normalized() if straight_dist > 0.001 else Vector2.ZERO
				spawn_projectile.emit(global_position, dir, projectile_speed, damage)

func _move_along_path(delta: float, player: Node) -> void:
	if current_path.size() < 2:
		# Il percorso ha un solo punto (o nessuno) quando nemico e
		# giocatore sono nella stessa cella del labirinto: lí dentro non
		# può esserci una parete di mezzo, quindi si chiude la distanza
		# in linea retta invece di restare fermi in attesa di un
		# percorso che non arriverà mai (la cella di destinazione, non
		# il punto esatto del giocatore, è già stata raggiunta).
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length() > 0.001:
			var dir: Vector2 = to_player.normalized()
			global_position = maze.resolve_move(global_position, dir * speed * delta, radius)
		return
	if path_target_index >= current_path.size():
		path_target_index = current_path.size() - 1
	var target: Vector2 = current_path[path_target_index]
	var to_target: Vector2 = target - global_position
	if to_target.length() < 10.0 and path_target_index < current_path.size() - 1:
		path_target_index += 1
		target = current_path[path_target_index]
		to_target = target - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
	global_position = maze.resolve_move(global_position, dir * speed * delta, radius)

# --- Comportamento da alleato -------------------------------------------------

func _physics_process_ally(delta: float, player: Node) -> void:
	var hostile := _find_nearest_hostile(ALLY_ENGAGE_RADIUS)
	var dest_pos: Vector2 = hostile.global_position if hostile != null else player.global_position
	var stop_distance: float = (radius + hostile.radius - 4.0) if hostile != null else ALLY_FOLLOW_DISTANCE
	if global_position.distance_to(dest_pos) > stop_distance:
		if maze != null:
			_ally_move_along_maze(delta, dest_pos)
		else:
			var to_dest: Vector2 = dest_pos - global_position
			var dir: Vector2 = to_dest.normalized() if to_dest.length() > 0.001 else Vector2.ZERO
			global_position += dir * speed * delta
			_clamp_to_arena()
	_ally_resolve_combat()

func _find_nearest_hostile(max_radius: float) -> Node:
	var nearest: Node = null
	var nearest_dist := max_radius
	for group in ["enemy", "boss"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not node.alive:
				continue
			if node is Enemy and node.is_ally:
				continue
			var d: float = global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node
	return nearest

func _ally_move_along_maze(delta: float, dest_pos: Vector2) -> void:
	ally_path_recalc_timer -= delta
	if ally_path_recalc_timer <= 0.0 or ally_path.size() < 2:
		ally_path = maze.get_path(global_position, dest_pos)
		ally_path_target_index = 1 if ally_path.size() > 1 else 0
		ally_path_recalc_timer = 0.35 + randf() * 0.25

	if ally_path.size() < 2:
		var to_dest: Vector2 = dest_pos - global_position
		if to_dest.length() > 0.001:
			var dir: Vector2 = to_dest.normalized()
			global_position = maze.resolve_move(global_position, dir * speed * delta, radius)
		return
	if ally_path_target_index >= ally_path.size():
		ally_path_target_index = ally_path.size() - 1
	var target: Vector2 = ally_path[ally_path_target_index]
	var to_target: Vector2 = target - global_position
	if to_target.length() < 10.0 and ally_path_target_index < ally_path.size() - 1:
		ally_path_target_index += 1
		target = ally_path[ally_path_target_index]
		to_target = target - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
	global_position = maze.resolve_move(global_position, dir * speed * delta, radius)

func _ally_resolve_combat() -> void:
	# Stesso schema del Player._resolve_combat(): è l'alleato stesso a
	# scandire le proprie aree sovrapposte, dato che i nemici comuni non
	# controllano mai le proprie (collision_mask = 0 di default). Il
	# cooldown di contatto (contact_timer, ereditato da CombatEntity) è
	# per-istanza, quindi alleato e nemico infliggono danno l'un l'altro
	# ognuno al proprio ritmo, esattamente come già avviene per il
	# contatto nemico -> giocatore.
	if not alive:
		return
	for area in get_overlapping_areas():
		if not alive:
			return
		if area == self:
			continue
		if area.is_in_group("enemy_projectile"):
			take_damage(area.damage)
			area.queue_free()
			continue
		if not area.is_in_group("combat_target"):
			continue
		if area is Enemy and area.is_ally:
			continue
		if not area.alive:
			continue
		if can_deal_contact_damage():
			area.take_damage(damage)
			trigger_contact()
		if area.can_deal_contact_damage():
			take_damage(area.damage)
			area.trigger_contact()

func _clamp_to_arena() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	global_position.x = clamp(global_position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	global_position.y = clamp(global_position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

func _draw() -> void:
	super._draw()
	if is_golden:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color(0.96, 0.77, 0.19), 2.0)
	if is_ally:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color(0.4, 0.88, 0.76), 3.0)
