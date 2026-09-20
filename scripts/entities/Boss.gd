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
# Sagoma con cui il boss viene disegnato: una per archetipo, cosí
# l'aspetto corrisponde al nome invece di essere la stessa massa per
# tutti e tre (vedi _draw). La variante corrotta condivide la sagoma del
# boss di base e se ne distingue per il bagliore.
var shape := "custode"
# Verso dove il boss è rivolto: la visiera del Custode, i pugni del
# Colosso e il cappuccio dello Spettro devono guardare la preda.
var heading := Vector2.DOWN
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
	shape = data.get("shape", "custode")
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
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > 1.0:
		heading = heading.lerp(to_target.normalized(), 0.12).normalized()
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
	# Il bagliore proprio del boss fa da profilo luminoso.
	rim_color = glow_color
	match shape:
		"colosso":
			_draw_colosso()
		"spettro":
			_draw_spettro()
		_:
			_draw_custode()

	if is_special:
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 40, glow_color, 3.0)
	if mode == "telegraph":
		# Il preavviso resta l'informazione più urgente sullo schermo:
		# cremisi acceso, pieno, impossibile da confondere col decoro.
		var telegraph_radius: float = radius + 90.0 if pending_attack == "slam" else radius + 12.0
		draw_arc(Vector2.ZERO, telegraph_radius, 0.0, TAU, 40, Palette.with_alpha(Palette.EMBER, 0.85), 3.0)
		draw_circle(Vector2.ZERO, telegraph_radius, Palette.with_alpha(Palette.BLOOD, 0.08))
	_draw_hp_bar()

func _animation_phase(speed_factor: float) -> float:
	return float(Time.get_ticks_msec()) * 0.001 * speed_factor

func _draw_boss_shadow(scale_factor: float, opacity: float) -> void:
	draw_set_transform(Vector2(0.0, radius * 0.7), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * scale_factor, Palette.with_alpha(Palette.VOID, opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Custode: sentinella corazzata ------------------------------------------

# Un guardiano, non un mostro: corpo ottagonale di piastre, spallacci,
# uno scudo tenuto verso la preda e una visiera accesa al posto degli
# occhi. Le rune che gli orbitano intorno sono le stesse che scaglia
# nella raffica circolare.
func _draw_custode() -> void:
	_draw_boss_shadow(1.15, 0.5)
	var phase: float = _animation_phase(1.0)
	# Il Custode è l'unico boss in acciaio lavorato: va tenuto più chiaro
	# degli altri due, altrimenti l'armatura non si legge come tale e
	# resta l'ennesima massa nera.
	var plate: Color = color.lerp(Palette.STONE_LIT, 0.65)
	if hit_flash > 0.0:
		plate = Palette.BONE
	var facing: float = heading.angle()

	# Rune in orbita: preannunciano la raffica in cerchio.
	for i in range(6):
		var rune_angle: float = phase * 0.7 + TAU * float(i) / 6.0
		var rune_pos: Vector2 = Vector2.RIGHT.rotated(rune_angle) * (radius * 1.5)
		var rune_size: float = radius * 0.15
		draw_colored_polygon(PackedVector2Array([
			rune_pos + Vector2(0.0, -rune_size), rune_pos + Vector2(rune_size, 0.0),
			rune_pos + Vector2(0.0, rune_size), rune_pos + Vector2(-rune_size, 0.0),
		]), Palette.with_alpha(glow_color, 0.55))

	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)

	# Corpo: un ottagono di piastre, non un disco.
	var armour := PackedVector2Array()
	for i in range(8):
		armour.append(Vector2.RIGHT.rotated(TAU * float(i) / 8.0 + PI / 8.0) * radius)
	draw_colored_polygon(armour, plate.lerp(Palette.VOID, 0.2))
	var armour_outline: PackedVector2Array = armour.duplicate()
	armour_outline.append(armour[0])
	draw_polyline(armour_outline, Palette.with_alpha(Palette.STONE_EDGE, 0.9), 2.0, true)

	# Spallacci.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(-radius * 0.15, side * radius * 0.82), radius * 0.32, plate.lerp(Palette.VOID, 0.05))

	# Scudo tenuto verso la preda, con l'emblema inciso.
	var shield_front: float = radius * 1.15
	draw_arc(Vector2.ZERO, shield_front, -1.2, 1.2, 32, plate.lerp(Palette.STONE_EDGE, 0.55), radius * 0.28, true)
	draw_arc(Vector2.ZERO, shield_front + radius * 0.14, -1.2, 1.2, 32, Palette.with_alpha(Palette.VOID, 0.85), 2.0, true)
	draw_arc(Vector2.ZERO, shield_front - radius * 0.14, -1.2, 1.2, 32, Palette.with_alpha(Palette.VOID, 0.85), 2.0, true)
	# Emblema inciso sullo scudo.
	draw_line(Vector2(shield_front, -radius * 0.34), Vector2(shield_front, radius * 0.34), Palette.with_alpha(glow_color, 0.8), 2.5)
	draw_line(Vector2(shield_front - radius * 0.12, 0.0), Vector2(shield_front + radius * 0.12, 0.0), Palette.with_alpha(glow_color, 0.8), 2.5)

	# Elmo e visiera: l'unico punto acceso del guardiano, il suo sguardo.
	draw_circle(Vector2(radius * 0.28, 0.0), radius * 0.44, plate.lerp(Palette.VOID, 0.45))
	var visor_x: float = radius * 0.52
	draw_line(Vector2(visor_x, -radius * 0.26), Vector2(visor_x, radius * 0.26), Palette.with_alpha(glow_color, 0.35), radius * 0.2)
	draw_line(Vector2(visor_x, -radius * 0.2), Vector2(visor_x, radius * 0.2), glow_color, radius * 0.09)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Colosso di Pietra: golem di roccia --------------------------------------

# Nessuna curva: lastre squadrate, giunti profondi e crepe accese, due
# pugni enormi che oscillano ai lati e detriti sparsi alla base. Tutto
# dice "pietra pesante", che è esattamente la sua mossa — il colpo al
# suolo.
func _draw_colosso() -> void:
	_draw_boss_shadow(1.25, 0.55)
	var phase: float = _animation_phase(1.0)
	var rock: Color = color.lerp(Palette.STONE, 0.5)
	if hit_flash > 0.0:
		rock = Palette.BONE
	var facing: float = heading.angle()

	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)

	# Detriti che gli girano intorno ai piedi.
	for i in range(7):
		var debris_angle: float = phase * 0.35 + TAU * float(i) / 7.0
		var debris: Vector2 = Vector2.RIGHT.rotated(debris_angle) * (radius * (1.25 + 0.1 * sin(phase + float(i))))
		draw_rect(Rect2(debris - Vector2(radius * 0.06, radius * 0.06), Vector2(radius * 0.12, radius * 0.12)), rock.lerp(Palette.VOID, 0.4))

	# Pugni: due blocchi che oscillano avanti e indietro.
	for side in [-1.0, 1.0]:
		var swing: float = sin(phase * 1.6 + (0.0 if side > 0.0 else PI)) * radius * 0.16
		var fist := Vector2(radius * 0.35 + swing, side * radius * 0.95)
		draw_rect(Rect2(fist - Vector2(radius * 0.3, radius * 0.3), Vector2(radius * 0.6, radius * 0.6)), rock.lerp(Palette.VOID, 0.25))
		draw_rect(Rect2(fist - Vector2(radius * 0.3, radius * 0.3), Vector2(radius * 0.6, radius * 0.6)), Palette.with_alpha(Palette.VOID, 0.8), false, 2.0)

	# Torso: tre lastre sovrapposte, sbilenche quanto basta perché non
	# sembri un rettangolo disegnato col righello.
	var slabs := [
		[Vector2(-radius * 0.15, 0.0), Vector2(radius * 1.5, radius * 1.45), 0.0],
		[Vector2(radius * 0.2, -radius * 0.35), Vector2(radius * 0.9, radius * 0.75), 0.12],
		[Vector2(radius * 0.1, radius * 0.4), Vector2(radius * 1.0, radius * 0.6), -0.09],
	]
	for slab in slabs:
		var center: Vector2 = slab[0]
		var size: Vector2 = slab[1]
		draw_set_transform(Vector2.ZERO, facing + float(slab[2]), Vector2.ONE)
		draw_rect(Rect2(center - size * 0.5, size), rock)
		draw_rect(Rect2(center - size * 0.5, size), Palette.with_alpha(Palette.VOID, 0.85), false, 2.0)
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)

	# Crepe accese: la corruzione (o il magma) che filtra da dentro.
	for i in range(4):
		var crack_y: float = (float(i) - 1.5) * radius * 0.34
		draw_polyline(PackedVector2Array([
			Vector2(-radius * 0.45, crack_y),
			Vector2(-radius * 0.08, crack_y + radius * 0.12),
			Vector2(radius * 0.3, crack_y - radius * 0.07),
		]), Palette.with_alpha(glow_color, 0.75), 1.5, true)

	# Due occhi infossati nella roccia.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(radius * 0.55, side * radius * 0.26), radius * 0.1, glow_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Spettro Errante: presenza senza corpo -----------------------------------

# Non tocca terra e non ha contorni netti: un cappuccio vuoto, un sudario
# sfrangiato che ondeggia e due occhi accesi. Semitrasparente, cosí il
# pavimento si intravede attraverso — ed è il motivo per cui il suo
# teletrasporto non sorprende: si vede che non è materia.
func _draw_spettro() -> void:
	# Ombra minima e lontana: fluttua, non poggia.
	draw_set_transform(Vector2(0.0, radius * 1.15), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, radius * 0.6, Palette.with_alpha(Palette.VOID, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var phase: float = _animation_phase(1.0)
	var hover: float = sin(phase * 1.4) * radius * 0.12
	var shroud: Color = color.lerp(Palette.VOID, 0.35)
	var body_alpha: float = 0.62
	if hit_flash > 0.0:
		shroud = Palette.BONE
		body_alpha = 0.9

	draw_set_transform(Vector2(0.0, hover), heading.angle() + PI * 0.5, Vector2.ONE)

	# Scie che si sfilacciano dietro di lui.
	for i in range(5):
		var wisp_x: float = (float(i) - 2.0) * radius * 0.3
		var wisp_len: float = radius * (0.7 + 0.5 * abs(sin(phase * 2.0 + float(i) * 1.3)))
		draw_line(
			Vector2(wisp_x, radius * 0.4), Vector2(wisp_x * 1.4, radius * 0.4 + wisp_len),
			Palette.with_alpha(shroud, 0.3), 3.0
		)

	# Sudario: largo in basso e sfrangiato, stretto sulle spalle.
	var hem := PackedVector2Array()
	hem.append(Vector2(-radius * 0.5, -radius * 0.7))
	hem.append(Vector2(radius * 0.5, -radius * 0.7))
	var tatters := 9
	for i in range(tatters + 1):
		var t: float = float(i) / float(tatters)
		var x: float = lerp(radius * 1.05, -radius * 1.05, t)
		var fray: float = radius * (0.55 + 0.35 * sin(phase * 2.6 + t * 9.0))
		hem.append(Vector2(x, radius * 0.45 + fray))
	draw_colored_polygon(hem, Palette.with_alpha(shroud, body_alpha))
	var hem_outline: PackedVector2Array = hem.duplicate()
	hem_outline.append(hem[0])
	draw_polyline(hem_outline, Palette.with_alpha(glow_color, 0.3), 1.5, true)

	# Cappuccio vuoto e due occhi accesi: l'unica cosa nitida di lui.
	draw_circle(Vector2(0.0, -radius * 0.55), radius * 0.58, Palette.with_alpha(Palette.VOID, 0.85))
	draw_arc(Vector2(0.0, -radius * 0.55), radius * 0.58, 0.0, TAU, 28, Palette.with_alpha(glow_color, 0.45), 2.0, true)
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * radius * 0.2, -radius * 0.6), radius * 0.1, glow_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
