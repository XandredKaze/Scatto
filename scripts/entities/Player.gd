class_name Player
extends Area2D

# L'unico attacco del giocatore è lo scatto: muoversi con WASD/frecce,
# scattare con Spazio o Shift. Durante lo scatto il giocatore è invulnerabile
# e infligge danno a ogni nemico attraversato (una sola volta per scatto).
# Fuori dallo scatto, il contatto con un nemico danneggia il giocatore.

signal dash_hit(target: Node, damage: float)
signal enemy_defeated(target: Node)
signal died

const BASE_SPEED := 220.0
const BASE_DASH_DAMAGE := 22.0
const DASH_SPEED := 900.0
const DASH_DURATION := 0.16
const BASE_DASH_COOLDOWN := 0.55
const HIT_IFRAME := 0.8
const KNOCKBACK := 20.0

var radius := 14.0
var speed_mult := 1.0
var dash_damage_bonus := 0.0
var dash_distance_mult := 1.0
var dash_cooldown_mult := 1.0
var max_dash_charges := 1
var dash_charges := 1
var charge_regen_timer := 0.0
var extra_iframes := 0.0
var has_contrattacco := false
var has_furia := false
var has_shockwave := false

var max_hp := 100.0
var hp := 100.0
var facing := Vector2.UP
var is_dashing := false
var dash_timer := 0.0
var dash_vector := Vector2.ZERO
var hit_iframe_timer := 0.0
var hit_enemies_this_dash: Array = []
var alive := true

var arena_bounds: Rect2 = Rect2()
var _dash_key_was_down := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2 | 4 | 8
	monitoring = true
	monitorable = true
	add_to_group("player")
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	queue_redraw()

func reset_stats() -> void:
	speed_mult = 1.0
	dash_damage_bonus = 0.0
	dash_distance_mult = 1.0
	dash_cooldown_mult = 1.0
	max_dash_charges = 1
	dash_charges = 1
	charge_regen_timer = 0.0
	extra_iframes = 0.0
	has_contrattacco = false
	has_furia = false
	has_shockwave = false
	max_hp = 100.0
	hp = 100.0
	facing = Vector2.UP
	is_dashing = false
	dash_timer = 0.0
	hit_iframe_timer = 0.0
	hit_enemies_this_dash.clear()
	alive = true

func dash_cooldown() -> float:
	return BASE_DASH_COOLDOWN * dash_cooldown_mult

func dash_damage() -> float:
	var dmg := BASE_DASH_DAMAGE + dash_damage_bonus
	if has_furia:
		var missing_ratio: float = clamp(1.0 - hp / max_hp, 0.0, 1.0)
		dmg *= 1.0 + missing_ratio * 0.5
	return dmg

func is_invulnerable() -> bool:
	return is_dashing or hit_iframe_timer > 0.0

func can_dash() -> bool:
	return dash_charges > 0 and not is_dashing and alive

func start_dash(direction: Vector2) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_vector = direction
	dash_charges -= 1
	hit_enemies_this_dash.clear()
	hit_iframe_timer = 0.0

func end_dash() -> void:
	is_dashing = false
	hit_iframe_timer = max(hit_iframe_timer, extra_iframes)

func take_damage(amount: float) -> bool:
	if is_invulnerable() or not alive:
		return false
	hp = clamp(hp - amount, 0.0, max_hp)
	hit_iframe_timer = HIT_IFRAME
	if hp <= 0.0:
		alive = false
		died.emit()
	return true

func heal(amount: float) -> void:
	hp = clamp(hp + amount, 0.0, max_hp)

func apply_powerup(id: String) -> void:
	GameData.apply_powerup(id, self)
	hp = clamp(hp, 0.0, max_hp)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_read_input_and_move(delta)
	_update_timers(delta)
	_resolve_combat()
	queue_redraw()

func _read_input_and_move(delta: float) -> void:
	var move := Vector2.ZERO
	move.x = _axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT)
	move.y = _axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)
	if move.length() > 0.0:
		move = move.normalized()
		facing = move

	var dash_down := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)
	if dash_down and not _dash_key_was_down and can_dash():
		var dir: Vector2 = move if move != Vector2.ZERO else facing
		start_dash(dir)
	_dash_key_was_down = dash_down

	if is_dashing:
		var dist: float = DASH_SPEED * dash_distance_mult
		position += dash_vector * dist * delta
		dash_timer -= delta
		if dash_timer <= 0.0:
			end_dash()
	else:
		position += move * BASE_SPEED * speed_mult * delta

	_clamp_to_arena()

func _axis(pos_key: int, alt_key: int) -> float:
	return 1.0 if (Input.is_key_pressed(pos_key) or Input.is_key_pressed(alt_key)) else 0.0

func _update_timers(delta: float) -> void:
	if hit_iframe_timer > 0.0:
		hit_iframe_timer -= delta
	if dash_charges < max_dash_charges:
		charge_regen_timer += delta
		if charge_regen_timer >= dash_cooldown():
			dash_charges += 1
			charge_regen_timer = 0.0

func _clamp_to_arena() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	position.x = clamp(position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	position.y = clamp(position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

func _resolve_combat() -> void:
	var overlaps := get_overlapping_areas()
	if is_dashing:
		for area in overlaps:
			if not area.is_in_group("combat_target"):
				continue
			if not area.alive or hit_enemies_this_dash.has(area):
				continue
			hit_enemies_this_dash.append(area)
			var dmg := dash_damage()
			area.take_damage(dmg)
			var knock: Vector2 = area.global_position - global_position
			if knock.length() > 0.001:
				area.global_position += knock.normalized() * KNOCKBACK
			dash_hit.emit(area, dmg)
			if not area.alive:
				if has_contrattacco:
					dash_charges = min(max_dash_charges, dash_charges + 1)
				enemy_defeated.emit(area)
	else:
		for area in overlaps:
			if area.is_in_group("combat_target"):
				if area.alive and area.can_deal_contact_damage():
					if take_damage(area.damage):
						area.trigger_contact()
			elif area.is_in_group("enemy_projectile"):
				if take_damage(area.damage):
					area.queue_free()

func _draw() -> void:
	var body_color := Color(0.95, 0.95, 0.96)
	if hit_iframe_timer > 0.0 and not is_dashing:
		body_color.a = 0.5
	if is_dashing:
		draw_circle(Vector2.ZERO, radius + 4.0, Color(0.4, 0.88, 0.76, 0.35))
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(facing * (radius + 6.0), 3.0, Color(0.4, 0.88, 0.76))
