class_name EnemyProjectile
extends Area2D

var radius := 5.0
var damage := 6.0
var velocity := Vector2.ZERO
var life := 3.0
var arena_bounds: Rect2 = Rect2()
var maze: MazeGrid = null

# I proiettili nemici colpiscono il giocatore tramite la scansione delle
# proprie aree sovrapposte fatta da Player (i nemici non controllano mai
# le proprie, collision_mask = 0 di default per Enemy/Boss). Un proiettile
# sparato da un alleato deve invece colpire un nemico ostile, che non fa
# mai quella scansione: qui il proiettile stesso, quando is_ally_projectile
# è vero, si occupa di controllare le proprie sovrapposizioni e infliggere
# danno al primo bersaglio ostile valido.
var is_ally_projectile := false
# Colore del proiettile, personalizzabile da Run in base a chi lo spara
# (es. il colore a tema dell'alleato per Dardo Velenoso/Sciame Vendicativo),
# cosí gli attacchi speciali del giocatore restano riconoscibili a colpo
# d'occhio rispetto ai proiettili nemici generici.
var color := Color8(224, 102, 63)

signal ally_kill(defeated: Node)

func _ready() -> void:
	collision_layer = 8
	collision_mask = (2 | 4) if is_ally_projectile else 0
	monitoring = true
	monitorable = true
	add_to_group("enemy_projectile")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	queue_redraw()

func setup(pos: Vector2, dir: Vector2, spd: float, dmg: float) -> void:
	global_position = pos
	velocity = dir * spd
	damage = dmg

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if is_ally_projectile and _hit_hostile_target():
		return
	if maze != null:
		if not maze.is_position_free(global_position, radius):
			queue_free()
	elif arena_bounds.size != Vector2.ZERO:
		var r: Rect2 = arena_bounds.grow(40.0)
		if not r.has_point(global_position):
			queue_free()

func _hit_hostile_target() -> bool:
	for area in get_overlapping_areas():
		if not area.is_in_group("combat_target"):
			continue
		if area is Enemy and area.is_ally:
			continue
		if not area.alive:
			continue
		area.take_damage(damage)
		if not area.alive:
			ally_kill.emit(area)
		queue_free()
		return true
	return false

func _draw() -> void:
	# I proiettili degli attacchi speciali del giocatore hanno anche una
	# breve scia dietro di sé, per distinguerli a colpo d'occhio dai
	# proiettili nemici generici (che restano un semplice cerchio).
	if is_ally_projectile and velocity.length() > 0.001:
		var back: Vector2 = -velocity.normalized() * (radius * 2.5)
		draw_line(Vector2.ZERO, back, Color(color.r, color.g, color.b, 0.4), radius)
	draw_circle(Vector2.ZERO, radius, color)
