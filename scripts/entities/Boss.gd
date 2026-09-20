class_name Boss
extends CombatEntity

# Boss della sesta stanza. Macchina a stati semplice: chase -> telegraph
# -> (una mossa scelta dal pool di questo boss) -> recover -> chase.
# Il pool di mosse è dati-driven (GameData.BOSSES[...].attacks /
# .special_attacks), cosí ogni archetipo di boss ha un set di attacchi
# propri e la variante speciale ne aggiunge uno esclusivo, senza dover
# duplicare la macchina a stati per ogni boss.

signal spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float)
signal melee_aoe(origin: Vector2, radius: float, dmg: float)
signal summon_requested(enemy_type_id: String, count: int, origin: Vector2)

var boss_id := "custode"
var display_name := "Custode"
var desc := ""
var speed := 65.0
var is_special := false
var guaranteed_drop := ""
var glow_color := Color(1, 0.18, 0.33)
var attack_pool: Array = ["charge", "burst"]

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
	attack_pool = data.get("attacks", ["charge", "burst"]).duplicate()
	if is_special:
		attack_pool.append_array(data.get("special_attacks", []))

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
	# Come i nemici comuni, anche il boss se la prende con l'alleato che
	# gli sta più vicino invece di puntare sempre e solo al giocatore.
	var target: Node = update_hostile_target(delta)
	if target == null:
		return
	var aggression: float = 1.0 + (1.0 - hp_ratio()) * 0.6
	match mode:
		"chase":
			var dir: Vector2 = target.global_position - global_position
			dir = dir.normalized() if dir.length() > 0.001 else Vector2.ZERO
			global_position += dir * speed * delta
			mode_timer -= delta
			if mode_timer <= 0.0:
				_begin_attack(target)
		"telegraph":
			telegraph_timer -= delta
			if telegraph_timer <= 0.0:
				_execute_attack(target)
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

func _begin_attack(target: Node) -> void:
	pending_attack = attack_pool[randi() % attack_pool.size()]
	mode = "telegraph"
	telegraph_timer = 0.5
	var dir: Vector2 = target.global_position - global_position
	charge_vector = dir.normalized() if dir.length() > 0.001 else Vector2.DOWN

func _execute_attack(target: Node) -> void:
	match pending_attack:
		"charge":
			mode = "charge"
			mode_timer = 0.4
		"burst":
			_fire_ring(10, 220.0, damage * 0.6)
			_end_attack()
		"volley":
			_fire_aimed_fan(target, 6, 0.12, 300.0, damage * 0.7)
			_end_attack()
		"raffica":
			_fire_aimed_fan(target, 4, 0.08, 340.0, damage * 0.65)
			_end_attack()
		"raffica_ampia":
			_fire_aimed_fan(target, 8, 0.1, 360.0, damage * 0.7)
			_end_attack()
		"cono":
			_fire_aimed_fan(target, 5, 0.22, 200.0, damage * 0.55)
			_end_attack()
		"slam":
			melee_aoe.emit(global_position, radius + 90.0, damage * 1.4)
			_end_attack()
		"teletrasporto":
			var offset_angle: float = randf() * TAU
			var offset_dist: float = randf_range(140.0, 220.0)
			var landing: Vector2 = target.global_position + Vector2(cos(offset_angle), sin(offset_angle)) * offset_dist
			if arena_bounds.size != Vector2.ZERO:
				landing.x = clamp(landing.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
				landing.y = clamp(landing.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)
			global_position = landing
			_end_attack()
		"richiamo":
			summon_requested.emit("sciame", randi_range(2, 3), global_position)
			_end_attack()
		_:
			_end_attack()

func _fire_ring(count: int, speed_val: float, dmg: float) -> void:
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		spawn_projectile.emit(global_position, Vector2(cos(angle), sin(angle)), speed_val, dmg)

func _fire_aimed_fan(target: Node, count: int, spread_step: float, speed_val: float, dmg: float) -> void:
	var to_target: Vector2 = target.global_position - global_position
	var base_angle := to_target.angle()
	for i in range(count):
		var spread: float = (float(i) - float(count - 1) / 2.0) * spread_step
		var angle: float = base_angle + spread
		spawn_projectile.emit(global_position, Vector2(cos(angle), sin(angle)), speed_val, dmg)

func _end_attack() -> void:
	mode = "recover"
	mode_timer = 0.5

func _draw() -> void:
	super._draw()
	if is_special:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 32, glow_color, 3.0)
	if mode == "telegraph":
		var telegraph_radius: float = radius + 90.0 if pending_attack == "slam" else radius + 10.0
		draw_arc(Vector2.ZERO, telegraph_radius, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
