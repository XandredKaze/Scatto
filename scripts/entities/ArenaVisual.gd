class_name ArenaVisual
extends Node2D

# Disegna lo spazio di gioco nello stile della cripta gotica di
# riferimento: pavimento di lastre di pietra tagliata, fredde e quasi
# nere, segnate da fughe, crepe e sangue rappreso; muri come blocchi di
# muratura con lo spigolo superiore illuminato e un'ombra netta proiettata
# sul pavimento; e, appesi alle pareti lunghe, stendardi cremisi e bracieri
# che sono le uniche fonti di colore acceso della stanza.
#
# La stanza del boss usa la stessa muratura su un'arena aperta
# rettangolare, cosí le due modalità appartengono allo stesso luogo.
#
# La collisione resta quella rettangolare di MazeGrid.wall_rects: qui si
# genera solo geometria decorativa, una volta per stanza (non ad ogni
# frame), perciò nulla di ciò che si vede sposta i limiti in cui il
# giocatore può muoversi.

var arena_size := Vector2(1280, 720):
	set(value):
		arena_size = value
		# Nella sala del boss (nessun labirinto) è questa misura a
		# definire la stanza: cambiarla deve rigenerare il decoro.
		if maze == null:
			_build_geometry()
			queue_redraw()
var wall_margin := 48.0

var maze: MazeGrid = null:
	set(value):
		maze = value
		_build_geometry()
		queue_redraw()

# Lato della lastra di pavimento. Grande abbastanza da tenere basso il
# numero di primitive su un labirinto da 2400x1800 px, piccolo abbastanza
# perché la muratura si legga come tale.
const TILE_SIZE := 75.0
const WALL_LIP := 0.42  # quota del muro occupata dalla "faccia" illuminata
const WALL_SHADOW_OFFSET := Vector2(0.0, 7.0)
const MAX_RUBBLE := 220
const MAX_CRACKS := 34
const MAX_STAINS := 26

var _floor_tiles: Array = []   # {rect: Rect2, color: Color}
var _cracks: Array = []        # PackedVector2Array di polilinee
var _rubble: Array = []        # {pos, radius, color}
var _stains: Array = []        # {pos, radius, color} sangue già rappreso
var _props: Array = []         # {kind, pos, size}
var _tone_noise := FastNoiseLite.new()

func _init() -> void:
	_tone_noise.seed = 4242
	_tone_noise.frequency = 0.012

func _draw() -> void:
	if maze != null:
		_draw_floor(maze.total_bounds())
		_draw_props()
		_draw_walls(maze.wall_rects)
	else:
		_draw_open_arena()

func _draw_open_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), Palette.VOID)
	var inner := Rect2(Vector2(wall_margin, wall_margin), arena_size - Vector2(wall_margin, wall_margin) * 2.0)
	_draw_floor(inner)
	_draw_props()
	_draw_walls(_arena_wall_rects())

# I muri dell'arena aperta sono le quattro fasce di bordo: non esistono in
# MazeGrid (lí la collisione è il rettangolo `arena_rect` di Run), quindi
# si ricavano qui per poterli disegnare con la stessa muratura del labirinto.
func _arena_wall_rects() -> Array:
	var m := wall_margin
	return [
		Rect2(Vector2.ZERO, Vector2(arena_size.x, m)),
		Rect2(Vector2(0.0, arena_size.y - m), Vector2(arena_size.x, m)),
		Rect2(Vector2.ZERO, Vector2(m, arena_size.y)),
		Rect2(Vector2(arena_size.x - m, 0.0), Vector2(m, arena_size.y)),
	]

# --- Pavimento ---------------------------------------------------------------

func _draw_floor(bounds: Rect2) -> void:
	draw_rect(bounds, Palette.STONE_DEEP)
	for tile in _floor_tiles:
		draw_rect(tile.rect, tile.color)
		# Fuga: due lati per lastra bastano a chiudere la griglia e
		# costano metà delle linee di un contorno completo.
		var joint: Color = Palette.with_alpha(Palette.JOINT, 0.55)
		draw_line(tile.rect.position, Vector2(tile.rect.end.x, tile.rect.position.y), joint, 1.0)
		draw_line(tile.rect.position, Vector2(tile.rect.position.x, tile.rect.end.y), joint, 1.0)
	for crack in _cracks:
		draw_polyline(crack, Palette.with_alpha(Palette.VOID, 0.5), 1.0, true)
	for stain in _stains:
		draw_circle(stain.pos, stain.radius, stain.color)
	for bit in _rubble:
		draw_circle(bit.pos, bit.radius, bit.color)

# --- Muratura ----------------------------------------------------------------

func _draw_walls(rects: Array) -> void:
	for rect in rects:
		# L'ombra proiettata sul pavimento è ciò che dà spessore al muro:
		# senza, i blocchi sembrerebbero dipinti sulle lastre.
		draw_rect(Rect2(rect.position + WALL_SHADOW_OFFSET, rect.size), Palette.SHADOW)
		# I muri sono l'elemento più scuro della stanza, più del
		# pavimento: è cosí che nel riferimento si legge dove si può
		# passare e dove no, ancora prima di urtarli.
		draw_rect(rect, Palette.VOID)

		# Faccia superiore, quella che prende la poca luce presente. La
		# sua altezza segue lo SPESSORE del muro (il lato corto), cosí
		# blocchi orizzontali e verticali sembrano alti uguale.
		var thickness: float = min(rect.size.x, rect.size.y)
		var lip_height: float = min(rect.size.y, max(3.0, thickness * WALL_LIP))
		var lip := Rect2(rect.position, Vector2(rect.size.x, lip_height))
		draw_rect(lip, Palette.STONE_DEEP)

		_draw_masonry_seams(rect)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Palette.with_alpha(Palette.STONE_EDGE, 0.7), 1.0)

func _draw_masonry_seams(rect: Rect2) -> void:
	var step := 46.0
	if rect.size.x >= rect.size.y:
		var x: float = rect.position.x + step
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Palette.JOINT, 1.0)
			x += step
	else:
		var y: float = rect.position.y + step
		while y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Palette.JOINT, 1.0)
			y += step

# --- Stendardi e bracieri ----------------------------------------------------

func _draw_props() -> void:
	for prop in _props:
		match prop.kind:
			"banner":
				_draw_banner(prop.pos, prop.size)
			"brazier":
				_draw_brazier(prop.pos)

func _draw_banner(top: Vector2, size: Vector2) -> void:
	var w: float = size.x
	var h: float = size.y
	# Asta e drappo: il drappo termina a punta, come quelli appesi nella
	# cripta di riferimento.
	draw_line(top + Vector2(-w * 0.6, 0.0), top + Vector2(w * 0.6, 0.0), Palette.STONE_EDGE, 2.0)
	var cloth := PackedVector2Array([
		top + Vector2(-w * 0.5, 0.0),
		top + Vector2(w * 0.5, 0.0),
		top + Vector2(w * 0.5, h * 0.82),
		top + Vector2(0.0, h),
		top + Vector2(-w * 0.5, h * 0.82),
	])
	draw_colored_polygon(cloth, Palette.BLOOD_DEEP)
	# Simbolo: una croce sottile in acciaio, come sugli stendardi del
	# riferimento.
	var center: Vector2 = top + Vector2(0.0, h * 0.42)
	draw_line(center + Vector2(0.0, -h * 0.26), center + Vector2(0.0, h * 0.26), Palette.STEEL_DIM, 2.0)
	draw_line(center + Vector2(-w * 0.22, -h * 0.04), center + Vector2(w * 0.22, -h * 0.04), Palette.STEEL_DIM, 2.0)

func _draw_brazier(pos: Vector2) -> void:
	# Alone: cerchi concentrici a bassissima opacità. Su un pavimento
	# quasi nero bastano a leggersi come luce, senza bisogno di shader.
	for i in range(5):
		var t: float = float(i) / 4.0
		draw_circle(pos, lerp(120.0, 26.0, t), Palette.with_alpha(Palette.BLOOD, 0.045 + t * 0.05))
	draw_circle(pos, 9.0, Palette.STONE_LIT)
	draw_circle(pos, 6.0, Palette.BLOOD)
	draw_circle(pos, 3.0, Palette.EMBER)

# --- Generazione (una volta per stanza) --------------------------------------

func _build_geometry() -> void:
	_floor_tiles.clear()
	_cracks.clear()
	_rubble.clear()
	_stains.clear()
	_props.clear()

	var bounds: Rect2 = maze.total_bounds() if maze != null else Rect2(
		Vector2(wall_margin, wall_margin),
		arena_size - Vector2(wall_margin, wall_margin) * 2.0
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = _geometry_seed()

	_build_floor_tiles(bounds, rng)
	_build_cracks(bounds, rng)
	_build_stains(bounds, rng)
	_build_rubble(bounds, rng)
	_build_props(bounds, rng)

func _geometry_seed() -> int:
	if maze != null:
		return maze.cols * 92821 + maze.rows * 6151 + maze.wall_rects.size() * 131
	return int(arena_size.x) * 31 + int(arena_size.y)

func _build_floor_tiles(bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var y: float = bounds.position.y
	while y < bounds.end.y:
		var x: float = bounds.position.x
		while x < bounds.end.x:
			var rect := Rect2(Vector2(x, y), Vector2(
				min(TILE_SIZE, bounds.end.x - x),
				min(TILE_SIZE, bounds.end.y - y)
			))
			_floor_tiles.append({"rect": rect, "color": _slab_color(rect.get_center(), rng)})
			x += TILE_SIZE
		y += TILE_SIZE

func _slab_color(center: Vector2, rng: RandomNumberGenerator) -> Color:
	# Il rumore dà alla pietra chiazze larghe di tono diverso; il piccolo
	# scarto casuale evita che due lastre vicine risultino identiche.
	var n: float = (_tone_noise.get_noise_2d(center.x, center.y) + 1.0) * 0.5
	var base: Color = Palette.STONE_DEEP.lerp(Palette.STONE_LIT, n * 0.55)
	var jitter: float = rng.randf_range(-0.018, 0.018)
	return Color(
		clamp(base.r + jitter, 0.0, 1.0),
		clamp(base.g + jitter, 0.0, 1.0),
		clamp(base.b + jitter, 0.0, 1.0)
	)

func _build_cracks(bounds: Rect2, rng: RandomNumberGenerator) -> void:
	for i in range(MAX_CRACKS):
		var start = _random_free_point(bounds, rng, 10.0)
		if start == null:
			continue
		var pts := PackedVector2Array()
		var cursor: Vector2 = start
		var dir: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		pts.append(cursor)
		for _s in range(rng.randi_range(2, 4)):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			cursor += dir * rng.randf_range(8.0, 18.0)
			if not bounds.has_point(cursor):
				break
			pts.append(cursor)
		if pts.size() >= 2:
			_cracks.append(pts)

func _build_stains(bounds: Rect2, rng: RandomNumberGenerator) -> void:
	# Sangue vecchio, già parte della stanza prima che il giocatore
	# arrivi: dice che qui è successo qualcosa, e spezza il grigio.
	for i in range(MAX_STAINS):
		var center = _random_free_point(bounds, rng, 22.0)
		if center == null:
			continue
		for _blob in range(rng.randi_range(3, 6)):
			var offset := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 26.0)
			_stains.append({
				"pos": center + offset,
				"radius": rng.randf_range(4.0, 13.0),
				"color": Palette.with_alpha(Palette.BLOOD_DEEP, rng.randf_range(0.35, 0.6)),
			})

func _build_rubble(bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var colors := [Palette.VOID, Palette.STONE, Palette.STONE_LIT]
	var attempts := 0
	while _rubble.size() < MAX_RUBBLE and attempts < MAX_RUBBLE * 6:
		attempts += 1
		var pos = _random_free_point(bounds, rng, 6.0)
		if pos == null:
			continue
		_rubble.append({
			"pos": pos,
			"radius": rng.randf_range(1.2, 3.6),
			"color": colors[rng.randi_range(0, colors.size() - 1)],
		})

# Stendardi e bracieri stanno appoggiati ai muri, mai in mezzo al
# passaggio: si scelgono i muri abbastanza lunghi e ci si mette il
# decoro contro la faccia inferiore, dove il giocatore lo vede.
func _build_props(bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var wall_rects: Array = maze.wall_rects if maze != null else _arena_wall_rects()
	for rect in wall_rects:
		if rect.size.x < rect.size.y or rect.size.x < 160.0:
			continue
		# Solo i muri che hanno pavimento davanti a sé: su quello più in
		# basso lo stendardo penderebbe fuori dalla stanza, invisibile.
		if rect.end.y >= bounds.end.y - 40.0:
			continue
		var roll: float = rng.randf()
		if roll < 0.14:
			_props.append({
				"kind": "banner",
				"pos": Vector2(rect.get_center().x, rect.end.y),
				"size": Vector2(rng.randf_range(34.0, 46.0), rng.randf_range(86.0, 124.0)),
			})
		elif roll < 0.24:
			_props.append({
				"kind": "brazier",
				"pos": Vector2(rect.get_center().x, rect.end.y + 22.0),
				"size": Vector2.ZERO,
			})

func _random_free_point(bounds: Rect2, rng: RandomNumberGenerator, clearance: float):
	for _try in range(8):
		var pos := Vector2(
			bounds.position.x + rng.randf() * bounds.size.x,
			bounds.position.y + rng.randf() * bounds.size.y
		)
		if maze == null or maze.is_position_free(pos, clearance):
			return pos
	return null
