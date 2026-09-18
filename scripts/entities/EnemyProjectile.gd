class_name EnemyProjectile
extends Area2D

var radius := 5.0
var damage := 6.0
var velocity := Vector2.ZERO
var life := 3.0
var arena_bounds: Rect2 = Rect2()

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
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
	if arena_bounds.size != Vector2.ZERO:
		var r: Rect2 = arena_bounds.grow(40.0)
		if not r.has_point(global_position):
			queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color8(224, 102, 63))
