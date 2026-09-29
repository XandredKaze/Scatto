class_name Minimap
extends Control

# Mini mappa in alto a destra della HUD. All'inizio di ogni mappa è
# tutta oscurata: si scopre esplorando. Entrando in una sala compare
# l'intera sala; percorrendo un corridoio compare il tratto calpestato.
# Da ogni tratto già scoperto spunta un moncone verso i passaggi ancora
# inesplorati, cosí si capisce dove si può andare senza svelare dove porta.
#
# Lo stato di scoperta vive qui ed è legato alla mappa: quando Run genera
# una mappa nuova (set_maze con un'altra MazeGrid) si riparte da zero.

# Spazio massimo occupato dalla griglia: la dimensione della cella della
# mini mappa si adatta alle colonne/righe configurate in bilanciamento.tres.
const MAX_GRID_SIZE := Vector2(220.0, 160.0)
const PADDING := 6.0
# Larghezza dei corridoi rispetto alla cella: piú sottili delle sale, come
# nel gioco.
const CORRIDOR_WIDTH_RATIO := 0.4
const PLAYER_DOT_RADIUS := 3.0

var maze: MazeGrid = null
# Indici delle sale scoperte e celle di corridoio scoperte (chiave Vector2i).
var revealed_rooms := {}
var revealed_corridors := {}
var player_cell := Vector2i(-1, -1)
var player_pos := Vector2.ZERO
var gate_open := false
# Oggetti ancora a terra nella mappa (Pickup): compaiono come segnalini,
# ma solo nelle sale già scoperte.
var pickups: Array = []
# La mappa ingrandita della finestra "Visualizza" è un'altra Minimap che
# rispecchia questa (mirror) con uno spazio piú grande.
var max_grid_size := MAX_GRID_SIZE
var _cell_px := 8.0
var _blink := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_min_size()

# Aggancia una mappa nuova e oscura tutto. Richiamare con la stessa mappa
# non azzera niente.
func set_maze(new_maze: MazeGrid) -> void:
	if new_maze == maze:
		return
	maze = new_maze
	revealed_rooms.clear()
	revealed_corridors.clear()
	player_cell = Vector2i(-1, -1)
	gate_open = false
	_update_min_size()
	queue_redraw()

# Posizione del giocatore nel mondo: scopre la sala o il tratto di
# corridoio in cui si trova.
func track_player(world_pos: Vector2) -> void:
	if maze == null:
		return
	player_pos = world_pos
	var cell: Vector2i = maze.world_to_cell(world_pos)
	if cell != player_cell:
		player_cell = cell
		reveal_cell(cell)
	queue_redraw()

func reveal_cell(cell: Vector2i) -> void:
	if maze == null:
		return
	var room: int = maze.room_at(cell)
	if room >= 0:
		revealed_rooms[room] = true
	elif maze.is_corridor_cell(cell):
		revealed_corridors[cell] = true

func is_cell_revealed(cell: Vector2i) -> bool:
	if maze == null:
		return false
	var room: int = maze.room_at(cell)
	if room >= 0:
		return revealed_rooms.has(room)
	return revealed_corridors.has(cell)

# Copia lo stato di un'altra mini mappa, condividendone le sale scoperte
# (gli stessi Dictionary, non una copia): la mappa ingrandita mostra cosí
# esattamente ciò che si è esplorato, senza tenere uno stato proprio.
func mirror(src: Minimap) -> void:
	if maze != src.maze:
		maze = src.maze
		_update_min_size()
	revealed_rooms = src.revealed_rooms
	revealed_corridors = src.revealed_corridors
	player_cell = src.player_cell
	player_pos = src.player_pos
	gate_open = src.gate_open
	pickups = src.pickups
	queue_redraw()

func set_gate_open(value: bool) -> void:
	if value != gate_open:
		gate_open = value
		queue_redraw()

func _process(delta: float) -> void:
	if maze == null:
		return
	_blink = fmod(_blink + delta, 1.0)

func _update_min_size() -> void:
	if maze == null or maze.cols <= 0 or maze.rows <= 0:
		custom_minimum_size = Vector2.ZERO
		return
	_cell_px = floor(min(max_grid_size.x / maze.cols, max_grid_size.y / maze.rows))
	_cell_px = max(_cell_px, 3.0)
	custom_minimum_size = Vector2(maze.cols, maze.rows) * _cell_px + Vector2.ONE * PADDING * 2.0

func _cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(PADDING, PADDING) + Vector2(cell) * _cell_px

func _draw() -> void:
	if maze == null:
		return
	var frame := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(frame, Palette.with_alpha(Palette.VOID, 0.82))
	draw_rect(frame, Palette.STONE_EDGE, false, 1.0)

	var corridor_w: float = max(2.0, round(_cell_px * CORRIDOR_WIDTH_RATIO))
	var inset: float = 1.0 if _cell_px >= 6.0 else 0.0

	for cell in maze.open_cells():
		if not is_cell_revealed(cell):
			continue
		var o: Vector2 = _cell_origin(cell)
		var is_room: bool = maze.room_at(cell) >= 0
		var fill: Color = Palette.STONE_LIT if is_room else Palette.STONE_EDGE
		if is_room and maze.room_at(cell) == maze.exit_room_index:
			fill = Palette.BLOOD_DEEP
		if is_room:
			draw_rect(Rect2(o, Vector2.ONE * _cell_px), fill)
		else:
			var c: Vector2 = o + Vector2.ONE * _cell_px * 0.5
			draw_rect(Rect2(c - Vector2.ONE * corridor_w * 0.5, Vector2.ONE * corridor_w), fill)
		# Passaggi verso i vicini: pieni se anche l'altro lato è scoperto,
		# un moncone se non lo è ancora.
		for n in _open_neighbors_of(cell):
			if maze.room_at(cell) >= 0 and maze.room_at(cell) == maze.room_at(n):
				continue
			_draw_passage(cell, n, corridor_w, fill, is_cell_revealed(n))

	# Contorno delle sale scoperte: senza, due sale vicine si leggerebbero
	# come un blocco solo.
	for room_index in revealed_rooms.keys():
		var r: Rect2i = maze.rooms[room_index]
		var rect := Rect2(_cell_origin(r.position), Vector2(r.size) * _cell_px)
		draw_rect(rect.grow(-inset), Palette.BONE_DIM if room_index != maze.exit_room_index else Palette.BLOOD, false, 1.0)

	_draw_gate(corridor_w)
	_draw_pickups()
	_draw_player()

func _open_neighbors_of(cell: Vector2i) -> Array:
	var result: Array = []
	for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var n: Vector2i = cell + d
		if _is_open_between(cell, n):
			result.append(n)
	return result

func _is_open_between(a: Vector2i, b: Vector2i) -> bool:
	if not maze.is_open_cell(a) or not maze.is_open_cell(b):
		return false
	var lo := Vector2i(min(a.x, b.x), min(a.y, b.y))
	if a.y == b.y:
		return maze.open_right[lo.y][lo.x]
	return maze.open_down[lo.y][lo.x]

func _draw_passage(cell: Vector2i, n: Vector2i, width: float, color: Color, full: bool) -> void:
	var c: Vector2 = _cell_origin(cell) + Vector2.ONE * _cell_px * 0.5
	var dir := Vector2(n - cell)
	# Pieno fino al centro della cella vicina, oppure moncone fino al
	# bordo tra le due celle (poco oltre, per farlo vedere).
	var length: float = _cell_px if full else _cell_px * 0.9
	var end: Vector2 = c + dir * length
	var half := Vector2(abs(dir.y), abs(dir.x)) * width * 0.5
	var rect := Rect2(c - half, Vector2.ZERO).expand(end + half)
	draw_rect(rect, color if full else Palette.BONE_DIM)

# La porta della sala del premio compare appena se ne scopre uno dei due
# lati: cremisi da chiusa, accesa quando si apre.
func _draw_gate(corridor_w: float) -> void:
	if not maze.has_exit_gate():
		return
	var a: Vector2i = maze.gate_doorway.a
	var b: Vector2i = maze.gate_doorway.b
	if not (is_cell_revealed(a) or is_cell_revealed(b)):
		return
	var mid: Vector2 = (_cell_origin(a) + _cell_origin(b)) * 0.5 + Vector2.ONE * _cell_px * 0.5
	var dir := Vector2(b - a)
	var across := Vector2(abs(dir.y), abs(dir.x))
	var bar_len: float = max(corridor_w + 2.0, _cell_px * 0.8)
	var thick: float = max(2.0, _cell_px * 0.25)
	if not gate_open:
		var rect := Rect2(mid - across * bar_len * 0.5 - dir * thick * 0.5, Vector2.ZERO).expand(mid + across * bar_len * 0.5 + dir * thick * 0.5)
		draw_rect(rect, Palette.BLOOD_BRIGHT)
		return
	# Aperta: la grata si è ritirata negli stipiti, come nel gioco, e il
	# varco al centro resta libero.
	var jamb: float = max(1.0, bar_len * 0.22)
	for side in [-1.0, 1.0]:
		var outer: Vector2 = mid + across * bar_len * 0.5 * side
		var inner: Vector2 = outer - across * jamb * side
		draw_rect(Rect2(outer - dir * thick * 0.5, Vector2.ZERO).expand(inner + dir * thick * 0.5), Palette.EMBER)

func _draw_pickups() -> void:
	var half: float = max(1.5, _cell_px * 0.22)
	for p in pickups:
		if not is_instance_valid(p) or not (p is Pickup):
			continue
		var cell: Vector2i = maze.world_to_cell(p.global_position)
		if not is_cell_revealed(cell):
			continue
		var local: Vector2 = (p.global_position - maze.origin) / maze.cell_size
		var at: Vector2 = Vector2(PADDING, PADDING) + local * _cell_px
		var color: Color
		match p.kind:
			Pickup.POTION:
				color = Palette.BLOOD_BRIGHT
			Pickup.TOKEN:
				color = Palette.GOLD
			Pickup.CHEST:
				color = Palette.NEON_DIM if p.opened else Palette.NEON
			_:
				color = Palette.NEON
		# Sulla mappa ingrandita c'è spazio per l'icona vera dell'oggetto;
		# su quella piccola basta un segnalino del suo colore.
		if _cell_px >= 16.0:
			Pickup.draw_art(self, p.kind, at, _cell_px / 50.0, 0.0, p.opened)
		elif p.kind == Pickup.CHEST:
			draw_rect(Rect2(at - Vector2.ONE * (half + 1.0), Vector2.ONE * (half + 1.0) * 2.0), color, false, 1.0)
		else:
			draw_rect(Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0), color)

func _draw_player() -> void:
	if player_cell.x < 0:
		return
	var local: Vector2 = (player_pos - maze.origin) / maze.cell_size
	var p: Vector2 = Vector2(PADDING, PADDING) + local * _cell_px
	var pulse: float = 0.5 + 0.5 * sin(_blink * TAU)
	var r: float = max(PLAYER_DOT_RADIUS, _cell_px * 0.3)
	draw_circle(p, r + 1.5, Palette.BONE)
	draw_circle(p, r, Palette.BLOOD_BRIGHT.lerp(Palette.EMBER, pulse))
