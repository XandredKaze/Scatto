class_name Boss
extends CombatEntity

# Boss della sesta stanza. Macchina a stati semplice: chase -> telegraph
# -> (charge | burst | volley) -> recover -> chase. "volley" è disponibile
# solo per la variante speciale (Custode Corrotto).

signal spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float)

var boss_id := "custode"
var display_name := "Custode"
var desc := ""
var speed := 65.0
var is_special := false
var guaranteed_drop := ""
var glow_color := Color(1, 0.18, 0.33)

var mode := "chase"
var mode_timer := 1.5
var telegraph_timer := 0.0
var pending_attack := "charge"
var charge_vector := Vector2.ZERO
var intro_timer := 1.0
var arena_bounds: Rect2 = Rect2()

func setup_from_data(data: Dictionary) -> void:
	boss_id = data.id
	display_name = data.name
	desc = data.desc
	max_hp = data.hp
	hp = data.hp
	speed = data.speed
	damage = data.damage
	radius = data.radius
	color = data.color
	is_special = data.get("special", false)
	guaranteed_drop = data.get("guaranteed_drop", "")
	if data.has("glow"):
		glow_color = data.glow

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	super._ready()
	add_to_group("boss")

func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if intro_timer > 0.0:
		intro_timer -= delta
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var aggression: float = 1.0 + (1.0 - hp_ratio()) * 0.6
	match mode:
		"chase":
			var dir: Vector2 = player.global_position - global_position
			dir = dir.normalized() if dir.length() > 0.001 else Vector2.ZERO
			global_position += dir * speed * delta
			mode_timer -= delta
			if mode_timer <= 0.0:
				_begin_attack(player)
		"telegraph":
			telegraph_timer -= delta
			if telegraph_timer <= 0.0:
				_execute_attack(player)
		"charge":
			global_position += charge_vector * speed * 3.2 * delta
			mode_timer -= delta
			if mode_timer <= 0.0:
				_end_attack()
		"recover":
			mode_timer -= delta
			if mode_timer <= 0.0:
				mode = "chase"
				mode_timer = max(0.6, 1.8 / aggression)
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	global_position.x = clamp(global_position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	global_position.y = clamp(global_position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

func _begin_attack(player: Node) -> void:
	var options := ["charge", "burst"]
	if is_special:
		options.append("volley")
	pending_attack = options[randi() % options.size()]
	mode = "telegraph"
	telegraph_timer = 0.5
	var dir: Vector2 = player.global_position - global_position
	charge_vector = dir.normalized() if dir.length() > 0.001 else Vector2.DOWN

func _execute_attack(player: Node) -> void:
	match pending_attack:
		"charge":
			mode = "charge"
			mode_timer = 0.4
		"burst":
			var count := 10
			for i in range(count):
				var angle: float = TAU * float(i) / float(count)
				spawn_projectile.emit(global_position, Vector2(cos(angle), sin(angle)), 220.0, damage * 0.6)
			_end_attack()
		"volley":
			var to_player: Vector2 = player.global_position - global_position
			var base_angle := to_player.angle()
			var count := 6
			for i in range(count):
				var spread: float = (float(i) - float(count - 1) / 2.0) * 0.12
				var angle: float = base_angle + spread
				spawn_projectile.emit(global_position, Vector2(cos(angle), sin(angle)), 300.0, damage * 0.7)
			_end_attack()

func _end_attack() -> void:
	mode = "recover"
	mode_timer = 0.5

func _draw() -> void:
	super._draw()
	if is_special:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, glow_color, 3.0)
	if mode == "telegraph":
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
