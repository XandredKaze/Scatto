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
# Colore del profilo luminoso: è ciò che rende leggibile una creatura
# quasi nera su una pietra quasi nera, ed è anche l'unico segnale di
# schieramento (cremisi = ostile, acciaio = alleato, oro = dorato).
var rim_color: Color = Palette.RIM_HOSTILE
# Scostamento del corpo rispetto al punto in cui la creatura si trova
# davvero. Serve a chi si stacca da terra (il salto del Corazzato):
# l'ombra resta al suolo mentre il corpo sale, cosí il salto si vede.
# La collisione non ne risente: è puro disegno.
var body_offset := Vector2.ZERO

# Quanto ci mette una creatura sconfitta a sparire dalla stanza. Non è
# un ritardo gratuito: in quel tempo si dissolve e si accascia, cosí si
# vede DOVE è caduta invece di vederla svanire di colpo. Da morta non è
# già più né un bersaglio né una minaccia.
const DEATH_FADE := 0.35

var hp := 0.0
var alive := true
var death_timer := 0.0
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
		death_timer = DEATH_FADE
		# Nell'istante stesso in cui cade smette di essere un bersaglio
		# e un pericolo: spegne la propria area, cosí durante la
		# dissolvenza non colpisce e non può essere colpita.
		monitorable = false
		monitoring = false
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
	if not alive and death_timer > 0.0:
		death_timer -= delta
		# La dissolvenza passa da modulate e scale invece che dai singoli
		# _draw: cosí vale identica per ogni specie e per il boss, senza
		# doverla riscrivere dentro ognuna delle loro sagome.
		var remaining: float = clamp(death_timer / DEATH_FADE, 0.0, 1.0)
		modulate.a = remaining
		scale = Vector2.ONE * (0.55 + 0.45 * remaining)
		if death_timer <= 0.0:
			queue_free()
			return
	queue_redraw()

# Le creature si disegnano come nel riferimento estetico: una massa
# scura, un volto pallido e un profilo luminoso. Il colore proprio della
# specie resta riconoscibile, ma cupo: a dare la lettura immediata sono
# la silhouette e il bordo illuminato, non il riempimento.
func _draw() -> void:
	# L'ombra resta dove la creatura poggia davvero; tutto il resto segue
	# body_offset, cosí un corpo in aria si stacca dalla propria ombra.
	var lift: float = -body_offset.y
	_draw_ground_shadow(1.0 - clamp(lift / (radius * 6.0), 0.0, 0.4))
	var body: Color = color.lerp(Palette.VOID, 0.55)
	if hit_flash > 0.0:
		body = Palette.BONE
	draw_set_transform(body_offset, 0.0, Vector2.ONE)
	# Alone: la creatura sembra emettere la propria poca luce.
	draw_circle(Vector2.ZERO, radius + 6.0, Palette.with_alpha(rim_color, 0.07))
	draw_circle(Vector2.ZERO, radius, body)
	# Il profilo va tenuto basso: deve staccare la creatura dal fondo,
	# non trasformarla in un anello al neon.
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 28, Palette.with_alpha(rim_color, 0.5), 1.5, true)
	_draw_pale_face()
	_draw_hp_bar()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Ombra schiacciata a terra: stacca la creatura dal pavimento e le dà
# peso, come nelle scene isometriche di riferimento.
func _draw_ground_shadow(scale_factor: float = 1.0) -> void:
	draw_set_transform(Vector2(0.0, radius * 0.62), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, radius * 1.15 * scale_factor, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Il volto pallido: la macchia chiara che, nel riferimento, è l'unica
# parte riconoscibile di creature altrimenti in ombra.
func _draw_pale_face() -> void:
	var face_center := Vector2(0.0, -radius * 0.22)
	var face_radius: float = radius * 0.44
	draw_circle(face_center, face_radius, Palette.BONE_DIM)
	draw_circle(face_center + Vector2(0.0, -face_radius * 0.12), face_radius * 0.78, Palette.BONE)
	var eye_dx: float = face_radius * 0.38
	var eye_r: float = max(1.0, face_radius * 0.18)
	draw_circle(face_center + Vector2(-eye_dx, 0.0), eye_r, Palette.VOID)
	draw_circle(face_center + Vector2(eye_dx, 0.0), eye_r, Palette.VOID)

func _draw_hp_bar() -> void:
	# Una creatura sconfitta non ha più una vita da mostrare.
	if max_hp <= 0.0 or not alive:
		return
	var w := radius * 2.0
	var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	var top_left := Vector2(-w / 2.0, -radius - 11.0)
	draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(w + 2, 6)), Palette.with_alpha(Palette.VOID, 0.8))
	draw_rect(Rect2(top_left, Vector2(w, 4)), Palette.with_alpha(Palette.STONE, 0.9))
	draw_rect(Rect2(top_left, Vector2(w * ratio, 4)), rim_color)
