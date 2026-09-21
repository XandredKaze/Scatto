class_name Player
extends Area2D

# Il giocatore ha due soli pulsanti d'attacco (E/R1 e Q/L1) e ciò che
# fanno dipende da quanti alleati ha al seguito:
#
# - nessun alleato: entrambi i pulsanti eseguono lo SCATTO, l'attacco base.
#   Durante lo scatto il giocatore è invulnerabile e infligge danno a ogni
#   nemico attraversato (una sola volta per scatto).
# - almeno un alleato: lo scatto non è più disponibile su nessun pulsante.
#   Ogni alleato vivo occupa un pulsante con il proprio attacco speciale;
#   il pulsante eventualmente rimasto libero resta inattivo finché non
#   arriva il secondo alleato.
#
# Addomesticare è quindi una rinuncia: si baratta l'attacco base (e la sua
# invulnerabilità) per gli attacchi speciali degli alleati. Se tutti gli
# alleati cadono, lo scatto torna disponibile. L'unica eccezione è il
# potenziamento leggendario "Vincolo Spezzato" (keeps_dash_with_allies).
#
# Fuori dallo scatto, il contatto con un nemico danneggia il giocatore.

signal dash_hit(target: Node, damage: float)
signal enemy_defeated(target: Node)
signal tame_requested
signal special_attack_requested(ability_id: String, origin: Vector2, dir: Vector2, empowered: bool)
# Emesso ogni volta che un colpo va effettivamente a segno sul giocatore
# (non quando viene assorbito da invulnerabilità o iframe): Run lo usa
# per lasciare sangue a terra nel punto esatto in cui è stato colpito.
signal hurt(pos: Vector2)
signal died

const BASE_SPEED := 220.0
const BASE_DASH_DAMAGE := 22.0
const DASH_SPEED := 900.0
const DASH_DURATION := 0.16
const BASE_DASH_COOLDOWN := 0.55
const HIT_IFRAME := 0.8
const KNOCKBACK := 20.0
const TAME_COOLDOWN := 14.0
# I due soli pulsanti d'attacco del giocatore (E/R1 e Q/L1): un pulsante
# per alleato vivo (fino a MAX_ALLIES = 2), cosí ogni attacco speciale
# concesso resta utilizzabile in modo indipendente. Un pulsante senza
# alleato esegue lo scatto, ma solo finché non si ha alcun alleato
# (vedi has_dash()).
const SPECIAL_ATTACK_ACTIONS := ["special_attack", "special_attack_2"]

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
# Potenziamenti legati agli alleati e ai loro attacchi speciali: sono
# l'altra metà dell'arsenale ora che addomesticare toglie lo scatto.
var special_damage_mult := 1.0
var special_cooldown_mult := 1.0
var tame_cooldown_mult := 1.0
var ally_hp_mult := 1.0
var ally_damage_mult := 1.0
var pack_speed_bonus := 0.0
var has_vincolo_vitale := false
var has_richiamo_primordiale := false
var always_empowered := false
# "Vincolo Spezzato": unica eccezione alla regola per cui un alleato
# toglie lo scatto.
var keeps_dash_with_allies := false

var max_hp := 100.0
var hp := 100.0
var facing := Vector2.UP
var is_dashing := false
var dash_timer := 0.0
var dash_vector := Vector2.ZERO
var hit_iframe_timer := 0.0
var hit_enemies_this_dash: Array = []
var tame_cooldown_timer := 0.0
# Un'abilità per slot (indice = indice nel bottone SPECIAL_ATTACK_ACTIONS),
# impostate da Run ad ogni cambio degli alleati: ogni alleato vivo occupa
# un proprio slot/pulsante, stringa vuota se quello slot non ha alleato.
# Se due alleati vivi sono dello stesso tipo, condividono un solo slot in
# versione potenziata (special_attack_empowered) e l'altro slot resta vuoto.
var granted_ability_ids: Array = ["", ""]
var special_attack_empowered: Array = [false, false]
# Tempo di recupero per id di abilità (non per slot): cosí il tempo di
# recupero resta legato all'abilità stessa anche se cambia lo slot/pulsante
# a cui è assegnata (es. un alleato muore e l'altro viene ripromosso allo
# slot 0).
var special_attack_cooldowns: Dictionary = {}
var alive := true
var active_powerups: Array = []
# Impostato da Run mentre è aperta la scelta del potenziamento di fine
# stanza (o la schermata di fine boss): il giocatore resta immobile e non
# risponde più a input finché non riprende una nuova stanza.
var frozen := false

var arena_bounds: Rect2 = Rect2()
var maze: MazeGrid = null
var camera: Camera2D

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

	# La camera è figlia del giocatore: la sua posizione lo segue sempre,
	# in modo rigido (nessuno smoothing), qualunque cosa faccia.
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

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
	special_damage_mult = 1.0
	special_cooldown_mult = 1.0
	tame_cooldown_mult = 1.0
	ally_hp_mult = 1.0
	ally_damage_mult = 1.0
	pack_speed_bonus = 0.0
	has_vincolo_vitale = false
	has_richiamo_primordiale = false
	always_empowered = false
	keeps_dash_with_allies = false
	max_hp = 100.0
	hp = 100.0
	facing = Vector2.UP
	is_dashing = false
	dash_timer = 0.0
	hit_iframe_timer = 0.0
	hit_enemies_this_dash.clear()
	tame_cooldown_timer = 0.0
	special_attack_cooldowns.clear()
	active_powerups.clear()
	frozen = false
	alive = true

func snapshot_stats() -> Dictionary:
	return {
		"speed_mult": speed_mult,
		"dash_damage_bonus": dash_damage_bonus,
		"dash_distance_mult": dash_distance_mult,
		"dash_cooldown_mult": dash_cooldown_mult,
		"max_dash_charges": max_dash_charges,
		"extra_iframes": extra_iframes,
		"has_contrattacco": has_contrattacco,
		"has_furia": has_furia,
		"has_shockwave": has_shockwave,
		"special_damage_mult": special_damage_mult,
		"special_cooldown_mult": special_cooldown_mult,
		"tame_cooldown_mult": tame_cooldown_mult,
		"ally_hp_mult": ally_hp_mult,
		"ally_damage_mult": ally_damage_mult,
		"pack_speed_bonus": pack_speed_bonus,
		"has_vincolo_vitale": has_vincolo_vitale,
		"has_richiamo_primordiale": has_richiamo_primordiale,
		"always_empowered": always_empowered,
		"keeps_dash_with_allies": keeps_dash_with_allies,
		"max_hp": max_hp,
		"hp": hp,
		"active_powerups": active_powerups.duplicate(),
	}

func restore_stats(snapshot: Dictionary) -> void:
	speed_mult = snapshot.speed_mult
	dash_damage_bonus = snapshot.dash_damage_bonus
	dash_distance_mult = snapshot.dash_distance_mult
	dash_cooldown_mult = snapshot.dash_cooldown_mult
	max_dash_charges = snapshot.max_dash_charges
	dash_charges = snapshot.max_dash_charges
	charge_regen_timer = 0.0
	extra_iframes = snapshot.extra_iframes
	has_contrattacco = snapshot.has_contrattacco
	has_furia = snapshot.has_furia
	has_shockwave = snapshot.has_shockwave
	special_damage_mult = snapshot.special_damage_mult
	special_cooldown_mult = snapshot.special_cooldown_mult
	tame_cooldown_mult = snapshot.tame_cooldown_mult
	ally_hp_mult = snapshot.ally_hp_mult
	ally_damage_mult = snapshot.ally_damage_mult
	pack_speed_bonus = snapshot.pack_speed_bonus
	has_vincolo_vitale = snapshot.has_vincolo_vitale
	has_richiamo_primordiale = snapshot.has_richiamo_primordiale
	always_empowered = snapshot.always_empowered
	keeps_dash_with_allies = snapshot.keeps_dash_with_allies
	max_hp = snapshot.max_hp
	hp = snapshot.hp
	active_powerups = snapshot.active_powerups.duplicate()
	facing = Vector2.UP
	is_dashing = false
	dash_timer = 0.0
	hit_iframe_timer = 0.0
	hit_enemies_this_dash.clear()
	tame_cooldown_timer = 0.0
	special_attack_cooldowns.clear()
	frozen = false
	alive = true

func dash_cooldown() -> float:
	return BASE_DASH_COOLDOWN * dash_cooldown_mult

func tame_cooldown() -> float:
	return TAME_COOLDOWN * tame_cooldown_mult

# Il tempo di recupero è proprio dell'abilità, non uguale per tutte: un
# dardo a distanza torna pronto quasi subito, un morso in corpo a corpo
# molto più lentamente (vedi GameData.ALLY_SPECIAL_ATTACKS).
func special_attack_cooldown(ability_id: String) -> float:
	return float(GameData.ALLY_SPECIAL_ATTACKS[ability_id].cooldown) * special_cooldown_mult

# Almeno un alleato vivo al seguito: basta guardare gli slot d'abilità,
# che Run tiene sincronizzati con gli alleati vivi (_sync_granted_ability).
func has_ally() -> bool:
	for ability_id in granted_ability_ids:
		if ability_id != "":
			return true
	return false

# Lo scatto esiste solo finché non si ha alcun alleato: addomesticare lo
# toglie, perdere tutti gli alleati lo restituisce.
func has_dash() -> bool:
	return keeps_dash_with_allies or not has_ally()

# Velocità effettiva: "Passo del Predatore" rende più veloci solo mentre
# si ha almeno un alleato (cioè proprio quando manca lo scatto).
func current_speed_mult() -> float:
	return speed_mult + (pack_speed_bonus if has_ally() else 0.0)

func dash_damage() -> float:
	var dmg := BASE_DASH_DAMAGE + dash_damage_bonus
	if has_furia:
		var missing_ratio: float = clamp(1.0 - hp / max_hp, 0.0, 1.0)
		dmg *= 1.0 + missing_ratio * 0.5
	return dmg

func is_invulnerable() -> bool:
	return is_dashing or hit_iframe_timer > 0.0

func can_dash() -> bool:
	return has_dash() and dash_charges > 0 and not is_dashing and alive and not frozen

func can_tame() -> bool:
	return tame_cooldown_timer <= 0.0 and alive and not frozen

func can_use_special_attack(slot: int) -> bool:
	if not alive or frozen or slot < 0 or slot >= granted_ability_ids.size():
		return false
	var ability_id: String = granted_ability_ids[slot]
	if ability_id == "":
		return false
	return special_attack_cooldowns.get(ability_id, 0.0) <= 0.0

# Richiamato da Run quando la stanza viene ripulita (o il boss sconfitto):
# il giocatore resta fermo e invulnerabile mentre è aperta la schermata di
# scelta del potenziamento/fine run, cosí non può continuare a scattare o
# usare abilità a vuoto mentre non c'è più nulla da combattere.
func freeze() -> void:
	frozen = true
	is_dashing = false
	dash_timer = 0.0

func unfreeze() -> void:
	frozen = false

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
	hurt.emit(global_position)
	if hp <= 0.0:
		alive = false
		died.emit()
	return true

func heal(amount: float) -> void:
	hp = clamp(hp + amount, 0.0, max_hp)

func apply_powerup(id: String) -> void:
	GameData.apply_powerup(id, self)
	hp = clamp(hp, 0.0, max_hp)
	active_powerups.append(id)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if frozen:
		queue_redraw()
		return
	_read_input_and_move(delta)
	_update_timers(delta)
	_resolve_combat()
	queue_redraw()

func _read_input_and_move(delta: float) -> void:
	# Input.get_vector legge sia tastiera (WASD/frecce) sia lo stick
	# sinistro/D-pad di un controller, in modo unificato e con supporto
	# analogico nativo.
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move.length() > 0.0:
		facing = move.normalized()

	if Input.is_action_just_pressed("tame") and can_tame():
		tame_cooldown_timer = tame_cooldown()
		tame_requested.emit()

	# Ogni pulsante d'attacco lancia l'abilità dell'alleato che lo occupa;
	# se è libero esegue lo scatto, che però esiste solo finché non si ha
	# alcun alleato (can_dash() -> has_dash()).
	for slot in range(SPECIAL_ATTACK_ACTIONS.size()):
		if not Input.is_action_just_pressed(SPECIAL_ATTACK_ACTIONS[slot]):
			continue
		var ability_id: String = granted_ability_ids[slot]
		if ability_id != "":
			if can_use_special_attack(slot):
				special_attack_cooldowns[ability_id] = special_attack_cooldown(ability_id)
				special_attack_requested.emit(ability_id, global_position, facing, special_attack_empowered[slot])
		elif can_dash():
			start_dash(move.normalized() if move != Vector2.ZERO else facing)

	var move_delta: Vector2
	if is_dashing:
		var dist: float = DASH_SPEED * dash_distance_mult
		move_delta = dash_vector * dist * delta
		dash_timer -= delta
		if dash_timer <= 0.0:
			end_dash()
	else:
		move_delta = move * BASE_SPEED * current_speed_mult() * delta

	_apply_movement(move_delta)

func _update_timers(delta: float) -> void:
	if hit_iframe_timer > 0.0:
		hit_iframe_timer -= delta
	if tame_cooldown_timer > 0.0:
		tame_cooldown_timer -= delta
	for ability_id in special_attack_cooldowns.keys():
		if special_attack_cooldowns[ability_id] > 0.0:
			special_attack_cooldowns[ability_id] -= delta
	if dash_charges < max_dash_charges:
		charge_regen_timer += delta
		if charge_regen_timer >= dash_cooldown():
			dash_charges += 1
			charge_regen_timer = 0.0

func _apply_movement(move_delta: Vector2) -> void:
	if maze != null:
		position = maze.resolve_move(position, move_delta, radius)
	else:
		position += move_delta
		_clamp_to_arena()

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
			if area is Enemy and area.is_ally:
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
				if area is Enemy and area.is_ally:
					continue
				if area.alive and area.can_deal_contact_damage():
					if take_damage(area.damage):
						area.trigger_contact()
			elif area.is_in_group("enemy_projectile"):
				if area.is_ally_projectile:
					continue
				if take_damage(area.damage):
					area.queue_free()

# Il giocatore è la figura incappucciata dal mantello cremisi del
# riferimento estetico: corpo scuro, volto pallido, lama d'acciaio e,
# durante lo scatto, la falce di luce del colpo. È l'unica figura della
# scena col rosso pieno addosso, cosí resta sempre individuabile in
# mezzo alle creature.
func _draw() -> void:
	var alpha: float = 0.55 if (hit_iframe_timer > 0.0 and not is_dashing) else 1.0
	_draw_ground_shadow()
	if is_dashing:
		_draw_dash_trail()
	_draw_cloak(alpha)
	_draw_blade(alpha)
	if is_dashing:
		_draw_crescent()

func _draw_ground_shadow() -> void:
	draw_set_transform(Vector2(0.0, radius * 0.68), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.2, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cloak(alpha: float) -> void:
	# Mantello a campana: base larga, spalle strette, testa piccola. È la
	# silhouette della figura del riferimento, ed è ciò che rende il
	# giocatore riconoscibile anche a colpo d'occhio nella mischia.
	var r: float = radius
	var skirt := PackedVector2Array([
		Vector2(-r * 0.5, -r * 0.15),
		Vector2(r * 0.5, -r * 0.15),
		Vector2(r * 1.3, r * 1.1),
		Vector2(-r * 1.3, r * 1.1),
	])
	draw_colored_polygon(skirt, Palette.with_alpha(Palette.BLOOD, alpha))
	# Piega in ombra sul fondo del mantello: dà volume alla stoffa.
	var hem := PackedVector2Array([
		Vector2(-r * 0.95, r * 0.55),
		Vector2(r * 0.95, r * 0.55),
		Vector2(r * 1.3, r * 1.1),
		Vector2(-r * 1.3, r * 1.1),
	])
	draw_colored_polygon(hem, Palette.with_alpha(Palette.BLOOD_DEEP, alpha))
	# Orlo illuminato: la stessa luce cremisi che tiene insieme la scena.
	draw_line(Vector2(-r * 1.3, r * 1.1), Vector2(r * 1.3, r * 1.1), Palette.with_alpha(Palette.EMBER, alpha * 0.8), 2.0)

	# Cappuccio e volto pallido.
	draw_circle(Vector2(0.0, -r * 0.55), r * 0.62, Palette.with_alpha(Palette.VOID, alpha))
	draw_circle(Vector2(0.0, -r * 0.5), r * 0.34, Palette.with_alpha(Palette.BONE, alpha))
	draw_arc(Vector2(0.0, -r * 0.55), r * 0.62, PI, TAU, 20, Palette.with_alpha(Palette.EMBER, alpha * 0.5), 1.5, true)

func _draw_blade(alpha: float) -> void:
	var dir: Vector2 = facing.normalized() if facing.length() > 0.001 else Vector2.RIGHT
	var grip: Vector2 = dir * (radius * 0.5) + Vector2(0.0, radius * 0.1)
	draw_line(grip, grip + dir * (radius * 1.35), Palette.with_alpha(Palette.STEEL, alpha), 2.0)

# Scia dello scatto: allunga la figura all'indietro, cosí lo scatto si
# legge come uno spostamento fulmineo e non come un teletrasporto.
func _draw_dash_trail() -> void:
	var dir: Vector2 = facing.normalized() if facing.length() > 0.001 else Vector2.RIGHT
	for i in range(3):
		var back: Vector2 = -dir * (float(i + 1) * radius * 0.7)
		draw_circle(back, radius * (0.8 - float(i) * 0.2), Palette.with_alpha(Palette.BLOOD, 0.22 - float(i) * 0.06))

# La falce di luce del colpo: l'arco bianco-acciaio che nel riferimento
# segna il fendente appena portato.
func _draw_crescent() -> void:
	var dir: Vector2 = facing.normalized() if facing.length() > 0.001 else Vector2.RIGHT
	var angle: float = dir.angle()
	var center: Vector2 = dir * (radius * 0.35)
	draw_arc(center, radius * 2.1, angle - 1.0, angle + 1.0, 32, Palette.with_alpha(Palette.BONE, 0.9), 6.0, true)
	draw_arc(center, radius * 2.55, angle - 0.7, angle + 0.7, 24, Palette.with_alpha(Palette.STEEL, 0.55), 3.0, true)
	draw_arc(center, radius * 1.7, angle - 0.55, angle + 0.55, 20, Palette.with_alpha(Palette.BONE, 0.35), 2.0, true)
