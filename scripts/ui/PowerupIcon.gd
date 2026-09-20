class_name PowerupIcon
extends Control

# Icona vettoriale (nessun asset esterno) usata per riconoscere a colpo
# d'occhio un potenziamento: nella scelta di fine stanza, nell'archivio
# e nella barra dei potenziamenti attivi della HUD durante la run.

var shape := "sword"
var icon_color := Color(1, 1, 1)

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(32, 32)

func set_icon(shape_id: String, color: Color) -> void:
	shape = shape_id
	icon_color = color
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 3.0
	match shape:
		"sword":
			_draw_sword(c, r)
		"boot":
			_draw_boot(c, r)
		"arrow":
			_draw_arrow(c, r)
		"heart":
			_draw_heart(c, r, icon_color)
		"bolt":
			_draw_bolt(c, r)
		"ghost":
			_draw_ghost(c, r)
		"double":
			_draw_double(c, r)
		"cycle":
			_draw_cycle(c, r)
		"flame":
			_draw_flame(c, r)
		"heart_gold":
			_draw_heart(c, r, Palette.GOLD)
			draw_arc(c, r + 4.0, 0.0, TAU, 20, Palette.with_alpha(Palette.GOLD, 0.78), 1.5)
		"shield":
			_draw_shield(c, r)
		"paw":
			_draw_paw(c, r)
		"fang":
			_draw_fang(c, r)
		"link":
			_draw_link(c, r)
		_:
			draw_circle(c, r, icon_color)

func _draw_sword(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.5), icon_color, 4.0)
	draw_line(c + Vector2(-r * 0.4, r * 0.15), c + Vector2(r * 0.4, r * 0.15), icon_color, 3.0)
	draw_line(c + Vector2(0, r * 0.5), c + Vector2(0, r), icon_color, 3.0)

func _draw_boot(c: Vector2, r: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(-r * 0.3, -r), c + Vector2(r * 0.1, -r),
		c + Vector2(r * 0.1, r * 0.3), c + Vector2(r * 0.8, r * 0.5),
		c + Vector2(r * 0.8, r), c + Vector2(-r * 0.3, r),
	])
	draw_colored_polygon(points, icon_color)

func _draw_arrow(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), icon_color, 4.0)
	draw_line(c + Vector2(r * 0.4, -r * 0.5), c + Vector2(r, 0), icon_color, 4.0)
	draw_line(c + Vector2(r * 0.4, r * 0.5), c + Vector2(r, 0), icon_color, 4.0)

func _draw_heart(c: Vector2, r: float, col: Color) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var t: float = TAU * float(i) / float(steps)
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(c + Vector2(x, y) * (r / 18.0))
	draw_colored_polygon(points, col)

func _draw_bolt(c: Vector2, r: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.5, r * 0.15),
		c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.15, r),
		c + Vector2(r * 0.5, -r * 0.1), c + Vector2(r * 0.05, -r * 0.1),
	])
	draw_colored_polygon(points, icon_color)

func _draw_ghost(c: Vector2, r: float) -> void:
	var body_center := c + Vector2(0, -r * 0.1)
	draw_circle(body_center, r * 0.8, Color(icon_color.r, icon_color.g, icon_color.b, 0.75))
	draw_arc(body_center, r * 0.8, 0.0, TAU, 20, icon_color, 1.5)

func _draw_double(c: Vector2, r: float) -> void:
	draw_arc(c + Vector2(-r * 0.35, 0), r * 0.5, 0.0, TAU, 16, icon_color, 3.0)
	draw_arc(c + Vector2(r * 0.35, 0), r * 0.5, 0.0, TAU, 16, icon_color, 3.0)

func _draw_cycle(c: Vector2, r: float) -> void:
	draw_arc(c, r * 0.7, 0.3, TAU - 0.3, 20, icon_color, 3.0)
	var tip: Vector2 = c + Vector2(cos(-0.3), sin(-0.3)) * r * 0.7
	draw_line(tip, tip + Vector2(-6, -4), icon_color, 3.0)
	draw_line(tip, tip + Vector2(-2, 6), icon_color, 3.0)

func _draw_flame(c: Vector2, r: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r * 0.6, -r * 0.1),
		c + Vector2(r * 0.35, r), c + Vector2(-r * 0.35, r),
		c + Vector2(-r * 0.6, -r * 0.1),
	])
	draw_colored_polygon(points, icon_color)

func _draw_paw(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(0, r * 0.35), r * 0.55, icon_color)
	for i in range(3):
		var angle: float = PI + PI * 0.25 * float(i + 1)
		draw_circle(c + Vector2(cos(angle), sin(angle)) * r * 0.7, r * 0.22, icon_color)

func _draw_fang(c: Vector2, r: float) -> void:
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([
			c + Vector2(side * r * 0.65, -r * 0.7),
			c + Vector2(side * r * 0.15, -r * 0.7),
			c + Vector2(side * r * 0.4, r * 0.85),
		])
		draw_colored_polygon(points, icon_color)

func _draw_link(c: Vector2, r: float) -> void:
	# Anello spezzato: due archi che non si chiudono, per "Vincolo Spezzato".
	draw_arc(c + Vector2(-r * 0.35, 0), r * 0.55, PI * 0.35, TAU - PI * 0.35, 18, icon_color, 3.0)
	draw_arc(c + Vector2(r * 0.35, 0), r * 0.55, -PI * 0.65, PI * 0.65, 18, icon_color, 3.0)

func _draw_shield(c: Vector2, r: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r * 0.75, -r * 0.55),
		c + Vector2(r * 0.75, r * 0.2), c + Vector2(0, r),
		c + Vector2(-r * 0.75, r * 0.2), c + Vector2(-r * 0.75, -r * 0.55),
	])
	draw_colored_polygon(points, icon_color)
