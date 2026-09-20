class_name CombatEntity
extends Area2D

# Base condivisa da Enemy e Boss: vita, danno da contatto, riquadro vita
# e disegno del corpo. Il danno viene inflitto dal Player durante lo scatto
# tramite take_damage(); il contatto verso il Player passa da
# can_deal_contact_damage()/trigger_contact().

signal defeated

# Ogni quanto un avversario ostile si chiede chi stia attaccando.
const TARGET_RECHECK_INTERVAL := 0.5
# Un altro bersaglio deve essere più vicino di cosí (in pixel) per rubare
# l'attenzione a quello attuale: senza questo margine un nemico esitante
# tra giocatore e alleato quasi equidistanti cambierebbe idea in
# continuazione, restando fermo sul posto.
const TARGET_SWITCH_MARGIN := 70.0

var radius := 14.0
var max_hp := 30.0
var damage := 8.0
var contact_cooldown := 0.6
var color := Color(0.5, 0.68, 0.34)

var hp := 0.0
var alive := true
var hit_flash := 0.0
var contact_timer := 0.0
# Chi questo avversario sta attaccando: il giocatore o uno dei suoi
# alleati (vedi update_hostile_target). Non usato dagli alleati, che
# scelgono i propri bersagli con Enemy._find_nearest_hostile.
var current_target: Node = null
var target_recheck_timer := 0.0

func _ready() -> void:
	hp = max_hp
	monitoring = true
	monitorable = true
	# Sfasato a caso, cosí i nemici di una stanza non ricontrollano il
	# bersaglio tutti nello stesso frame.
	target_recheck_timer = randf() * TARGET_RECHECK_INTERVAL
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

# Bersaglio di un avversario ostile: il giocatore oppure uno degli alleati
# che il giocatore si è fatto addomesticando. Viene scelto il più vicino,
# cosí un alleato che si butta nella mischia attira davvero i nemici
# addosso a sé invece di essere ignorato. La scelta viene rifatta solo ogni
# TARGET_RECHECK_INTERVAL (e subito se il bersaglio attuale muore o
# sparisce), non a ogni frame.
func update_hostile_target(delta: float) -> Node:
	target_recheck_timer -= delta
	if target_recheck_timer > 0.0 and _is_attackable(current_target):
		return current_target
	target_recheck_timer = TARGET_RECHECK_INTERVAL
	current_target = _pick_hostile_target()
	return current_target

func _pick_hostile_target() -> Node:
	var best: Node = null
	var best_dist := INF
	var player := get_tree().get_first_node_in_group("player")
	if _is_attackable(player):
		best = player
		best_dist = global_position.distance_to(player.global_position)
	for ally in get_tree().get_nodes_in_group("ally"):
		if not _is_attackable(ally):
			continue
		var d: float = global_position.distance_to(ally.global_position)
		if d < best_dist:
			best = ally
			best_dist = d
	# Il bersaglio attuale resta tale finché un altro non è più vicino di
	# TARGET_SWITCH_MARGIN: evita il tentennamento tra due bersagli quasi
	# equidistanti.
	if best != null and _is_attackable(current_target) and current_target != best:
		if global_position.distance_to(current_target.global_position) - best_dist < TARGET_SWITCH_MARGIN:
			return current_target
	return best

func _is_attackable(node) -> bool:
	return node != null and is_instance_valid(node) and node.is_inside_tree() and node.alive

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
