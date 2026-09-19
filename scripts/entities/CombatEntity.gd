class_name CombatEntity
extends Area2D

# Base condivisa da Enemy e Boss: vita, danno da contatto, riquadro vita
# e disegno del corpo. Il danno viene inflitto dal Player durante lo scatto
# tramite take_damage(); il contatto verso il Player passa da
# can_deal_contact_damage()/trigger_contact().

signal defeated

var radius := 14.0
var max_hp := 30.0
var damage := 8.0
var contact_cooldown := 0.6
var color := Color(0.5, 0.68, 0.34)

var hp := 0.0
var alive := true
var hit_flash := 0.0
var contact_timer := 0.0

func _ready() -> void:
	hp = max_hp
	monitoring = true
	monitorable = true
	add_to_group("combat_target")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	hit_flash = 0.12
	if hp <= 0.0:
		hp = 0.0
		alive = false
		defeated.emit()

func can_deal_contact_damage() -> bool:
	return alive and contact_timer <= 0.0

func trigger_contact() -> void:
	contact_timer = contact_cooldown

func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash -= delta
	if contact_timer > 0.0:
		contact_timer -= delta
	queue_redraw()

func _draw() -> void:
	var draw_color := color
	if hit_flash > 0.0:
		draw_color = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, radius, draw_color)
	_draw_hp_bar()

func _draw_hp_bar() -> void:
	if max_hp <= 0.0:
		return
	var w := radius * 2.0
	var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	var top_left := Vector2(-w / 2.0, -radius - 10.0)
	draw_rect(Rect2(top_left, Vector2(w, 5)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(top_left, Vector2(w * ratio, 5)), Color(0.4, 0.88, 0.76))
