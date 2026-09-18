class_name Enemy
extends CombatEntity

# Nemico comune di stanza. Il comportamento "chase" insegue il giocatore,
# "ranged" mantiene le distanze e spara proiettili. setup_from_data()
# deve essere chiamato PRIMA di aggiungere il nodo all'albero, cosí che
# _ready() costruisca la CollisionShape2D con il raggio corretto.

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

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
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

func _clamp_to_arena() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	global_position.x = clamp(global_position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	global_position.y = clamp(global_position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

func _draw() -> void:
	super._draw()
	if is_golden:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24, Color(0.96, 0.77, 0.19), 2.0)
