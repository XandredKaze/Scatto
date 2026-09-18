class_name ArenaVisual
extends Node2D

# Disegna lo spazio di gioco: un labirinto (quando `maze` è impostato,
# stanze 1-5) reso con un aspetto di grotta/galleria mineraria — pareti
# dai bordi irregolari invece di rettangoli netti, roccia dai toni
# variabili e pavimento punteggiato di detriti — oppure un'arena aperta
# rettangolare (sala del boss). In entrambi i casi il disegno è in
# coordinate di mondo: la Camera2D del giocatore si occupa di mostrarne
# solo la porzione inquadrata.
#
# La collisione resta rettangolare (MazeGrid.wall_rects): qui si genera
# solo geometria decorativa, una volta per stanza (non ad ogni frame),
# cosí il bordo roccioso è puramente visivo e non cambia dove il
# giocatore può o non può passare.

var arena_size := Vector2(1280, 720)
var wall_margin := 48.0

var maze: MazeGrid = null:
	set(value):
		maze = value
		if maze != null:
			_build_cave_geometry()
		queue_redraw()

const FLOOR_COLOR := Color8(41, 36, 31)
const ROCK_COLOR_DARK := Color8(40, 36, 33)
const ROCK_COLOR_BASE := Color8(63, 56, 49)
const ROCK_COLOR_LIGHT := Color8(85, 76, 64)
const ROCK_EDGE_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const SPECKLE_COLORS := [Color8(30, 27, 24), Color8(52, 46, 40), Color8(96, 84, 58)]

const WALL_SEGMENT_LEN := 26.0
const MAX_FLOOR_SPECKLES := 260

var _wall_polygons: Array = []
var _wall_colors: Array = []
var _floor_speckles: Array = []  # Array di {pos: Vector2, radius: float, color: Color}
var _tone_noise := FastNoiseLite.new()

func _init() -> void:
	_tone_noise.seed = 4242
	_tone_noise.frequency = 0.01

func _draw() -> void:
	if maze != null:
		_draw_maze()
	else:
		_draw_open_arena()

func _draw_open_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color8(18, 16, 15))
	var inner := Rect2(Vector2(wall_margin, wall_margin), arena_size - Vector2(wall_margin, wall_margin) * 2.0)
	draw_rect(inner, FLOOR_COLOR)
	draw_rect(inner, ROCK_COLOR_LIGHT, false, 5.0)

func _draw_maze() -> void:
	draw_rect(maze.total_bounds(), FLOOR_COLOR)
	for speckle in _floor_speckles:
		draw_circle(speckle.pos, speckle.radius, speckle.color)
	for i in range(_wall_polygons.size()):
		var poly: PackedVector2Array = _wall_polygons[i]
		draw_colored_polygon(poly, _wall_colors[i])
		var outline: PackedVector2Array = poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, ROCK_EDGE_COLOR, 2.0, true)

# --- Geometria della grotta (generata una volta per stanza) -------------------------------------------------

func _build_cave_geometry() -> void:
	_wall_polygons.clear()
	_wall_colors.clear()
	_floor_speckles.clear()

	var wall_rng := RandomNumberGenerator.new()
	for rect in maze.wall_rects:
		wall_rng.seed = hash(rect.position) ^ hash(rect.size)
		_wall_polygons.append(_jagged_wall_polygon(rect, wall_rng))
		_wall_colors.append(_rock_color_for(rect))

	_build_floor_speckles()

func _jagged_wall_polygon(rect: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	# Spinge i bordi del rettangolo verso l'esterno/interno in modo
	# irregolare cosí da sembrare roccia scavata invece di un muro netto,
	# restando ben al di sotto della metà spessore muro per non aprire
	# varchi visivi rispetto alla collisione rettangolare sottostante.
	var jitter: float = max(3.0, maze.wall_thickness * 0.4)
	var corners := [
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y),
	]
	var normals := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var pts: PackedVector2Array = PackedVector2Array()
	for side in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var normal: Vector2 = normals[side]
		var seg_len: float = a.distance_to(b)
		var subdivisions: int = max(1, int(seg_len / WALL_SEGMENT_LEN))
		for i in range(subdivisions):
			var t: float = float(i) / float(subdivisions)
			var base: Vector2 = a.lerp(b, t)
			# Meno spostamento vicino agli angoli, per evitare che i
			# quattro lati del rettangolo si separino vistosamente.
			var edge_jitter: float = jitter * 0.35 if i == 0 else jitter
			pts.append(base + normal * rng.randf_range(-edge_jitter, edge_jitter))
	return pts

func _rock_color_for(rect: Rect2) -> Color:
	var center: Vector2 = rect.get_center()
	var n: float = (_tone_noise.get_noise_2d(center.x, center.y) + 1.0) * 0.5
	if n < 0.45:
		return ROCK_COLOR_DARK.lerp(ROCK_COLOR_BASE, n / 0.45)
	return ROCK_COLOR_BASE.lerp(ROCK_COLOR_LIGHT, (n - 0.45) / 0.55)

func _build_floor_speckles() -> void:
	var bounds: Rect2 = maze.total_bounds()
	var area: float = bounds.size.x * bounds.size.y
	var target_count: int = min(MAX_FLOOR_SPECKLES, int(area / 4500.0))
	var speckle_rng := RandomNumberGenerator.new()
	speckle_rng.seed = maze.cols * 92821 + maze.rows * 6151 + maze.wall_rects.size() * 131

	var attempts := 0
	while _floor_speckles.size() < target_count and attempts < target_count * 6:
		attempts += 1
		var pos := Vector2(
			bounds.position.x + speckle_rng.randf() * bounds.size.x,
			bounds.position.y + speckle_rng.randf() * bounds.size.y
		)
		if not maze.is_position_free(pos, 6.0):
			continue
		var color: Color = SPECKLE_COLORS[speckle_rng.randi_range(0, SPECKLE_COLORS.size() - 1)]
		_floor_speckles.append({"pos": pos, "radius": speckle_rng.randf_range(1.5, 4.0), "color": color})
