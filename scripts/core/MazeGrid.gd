class_name MazeGrid
extends RefCounted

# Struttura della mappa: un complesso di SALE rettangolari collegate fra
# loro da varchi, non più un labirinto di corridoi.
#
# La griglia di celle viene suddivisa ricorsivamente (BSP) in blocchi
# rettangolari; ogni blocco diventa una sala con l'interno completamente
# aperto, e ogni taglio della suddivisione lascia un varco nel muro che
# separa le due metà. L'albero dei tagli garantisce da solo che tutte le
# sale siano collegate; qualche varco in più (extra_door_chance) chiude
# degli anelli, cosí non si passa sempre e solo per la stessa porta.
#
# Una sala è la SALA DEL PREMIO: la più lontana dallo spawn fra quelle con
# un solo varco. Quel varco ospita la porta di uscita (vedi ExitGate), che
# resta chiusa finché la mappa non è ripulita: è l'unico modo di
# raggiungere la mappa successiva, e nessun nemico vi viene generato
# (sarebbe irraggiungibile e la mappa non si potrebbe mai ripulire).
#
# Le pareti sono rappresentate sia come segmenti Rect2 (collisione e
# disegno) sia come grafo di celle collegate (per il pathfinding dei
# nemici tramite AStar2D). Nessun nodo della scena: è puro dato/logica,
# cosí è testabile senza avviare l'albero di gioco.

# Lato minimo di una sala, in celle. Due celle bastano a farne una sala
# invece di un corridoio, e su una griglia 8x6 lasciano spazio a un buon
# numero di stanze di taglie diverse.
const MIN_ROOM_CELLS := 2
# Un'area fino a questa superficie (in celle) può restare intera invece di
# essere divisa ancora, con probabilità HALL_CHANCE: sono i saloni.
const MAX_HALL_CELLS := 12
const HALL_CHANCE := 0.4
# Larghezza del passaggio lasciato libero in un varco. Il varco occupa un
# lato intero di cella (cell_size), troppo per leggersi come una porta:
# due spallette di muro lo stringono fino a questa misura.
const DOOR_WIDTH := 132.0

var cols: int
var rows: int
var cell_size: float
var wall_thickness: float = 16.0
var origin: Vector2 = Vector2.ZERO

var open_right: Array = []  # open_right[y][x]: passaggio tra (x,y) e (x+1,y)
var open_down: Array = []   # open_down[y][x]: passaggio tra (x,y) e (x,y+1)
var wall_rects: Array = []
var astar: AStar2D

# Ostacoli che bloccano il movimento ma non fanno parte della muratura:
# oggi solo la porta di uscita mentre è chiusa. Restano fuori da
# `wall_rects` perché chi disegna la stanza non li deve rendere come
# blocchi di pietra — la porta si disegna da sé.
var extra_blockers: Array = []

var rooms: Array = []        # Array[Rect2i], in coordinate di cella
var doorways: Array = []     # Array[{a: Vector2i, b: Vector2i}]
var exit_room_index: int = -1
var gate_doorway: Dictionary = {}  # {a: cella fuori, b: cella dentro la sala del premio}

var _room_of_cell: Array = []

func generate(p_cols: int, p_rows: int, p_cell_size: float, rng: RandomNumberGenerator, spawn_cell: Vector2i = Vector2i(0, 0), extra_door_chance: float = 0.22) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size

	rooms.clear()
	doorways.clear()
	extra_blockers.clear()
	exit_room_index = -1
	gate_doorway = {}
	_reset_openings()

	_split_and_connect(Rect2i(0, 0, cols, rows), rng, true)
	_open_room_interiors()
	_build_room_index()
	_pick_exit_room(spawn_cell)
	_add_extra_doors(rng, extra_door_chance)
	_build_wall_rects()
	_build_astar()

func _reset_openings() -> void:
	open_right = []
	open_down = []
	for y in range(rows):
		var right_row: Array = []
		var down_row: Array = []
		for x in range(cols):
			right_row.append(false)
			down_row.append(false)
		open_right.append(right_row)
		open_down.append(down_row)

# --- Suddivisione in sale ----------------------------------------------------

# Taglia ricorsivamente `area` in due metà, ricorre su entrambe e lascia un
# varco sulla linea di taglio. Le foglie della ricorsione sono le sale.
# Poiché ogni taglio collega le proprie due metà con un varco, l'insieme
# delle sale risulta un albero: tutte raggiungibili, nessuna isolata.
func _split_and_connect(area: Rect2i, rng: RandomNumberGenerator, is_root: bool = false) -> void:
	var can_cut_x: bool = area.size.x >= MIN_ROOM_CELLS * 2
	var can_cut_y: bool = area.size.y >= MIN_ROOM_CELLS * 2
	if not can_cut_x and not can_cut_y:
		rooms.append(area)
		return
	# Fermarsi a volte pur potendo ancora tagliare è ciò che dà sale di
	# taglie diverse (qualche salone 4x3 accanto a stanzette 2x2) invece
	# di una scacchiera di rettangoli identici. Mai sulle aree troppo
	# allungate, che diventerebbero corridoi, e mai alla radice: la mappa
	# potrebbe restare un'unica sala senza varchi, quindi senza porta.
	var elongated: bool = max(area.size.x, area.size.y) > min(area.size.x, area.size.y) * 2 + 1
	if not is_root and not elongated and area.size.x * area.size.y <= MAX_HALL_CELLS and rng.randf() < HALL_CHANCE:
		rooms.append(area)
		return

	var cut_vertical: bool
	if can_cut_x and can_cut_y:
		# Si taglia il lato lungo: le sale restano larghe abbastanza da
		# essere sale, non corridoi.
		if area.size.x == area.size.y:
			cut_vertical = rng.randf() < 0.5
		else:
			cut_vertical = area.size.x > area.size.y
	else:
		cut_vertical = can_cut_x

	if cut_vertical:
		var cut: int = rng.randi_range(area.position.x + MIN_ROOM_CELLS, area.end.x - MIN_ROOM_CELLS)
		_split_and_connect(Rect2i(area.position, Vector2i(cut - area.position.x, area.size.y)), rng)
		_split_and_connect(Rect2i(Vector2i(cut, area.position.y), Vector2i(area.end.x - cut, area.size.y)), rng)
		var door_y: int = rng.randi_range(area.position.y, area.end.y - 1)
		_carve_doorway(Vector2i(cut - 1, door_y), Vector2i(cut, door_y))
	else:
		var cut_y: int = rng.randi_range(area.position.y + MIN_ROOM_CELLS, area.end.y - MIN_ROOM_CELLS)
		_split_and_connect(Rect2i(area.position, Vector2i(area.size.x, cut_y - area.position.y)), rng)
		_split_and_connect(Rect2i(Vector2i(area.position.x, cut_y), Vector2i(area.size.x, area.end.y - cut_y)), rng)
		var door_x: int = rng.randi_range(area.position.x, area.end.x - 1)
		_carve_doorway(Vector2i(door_x, cut_y - 1), Vector2i(door_x, cut_y))

func _open_room_interiors() -> void:
	for room in rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x - 1):
				open_right[y][x] = true
		for y in range(room.position.y, room.end.y - 1):
			for x in range(room.position.x, room.end.x):
				open_down[y][x] = true

func _carve(a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		open_right[a.y][min(a.x, b.x)] = true
	else:
		open_down[min(a.y, b.y)][a.x] = true

func _carve_doorway(a: Vector2i, b: Vector2i) -> void:
	_carve(a, b)
	doorways.append({"a": a, "b": b})

# Varchi in più fra sale già collegate: chiudono anelli, cosí il giocatore
# ha più di una strada. Al massimo un varco per coppia di sale (due porte
# sullo stesso muro lo farebbero sembrare una linea tratteggiata, e non
# aggiungono nessuna strada nuova), e mai sulla sala del premio, che deve
# conservare il suo unico varco — quello con la porta.
func _add_extra_doors(rng: RandomNumberGenerator, chance: float) -> void:
	var linked := {}
	for d in doorways:
		linked[_room_pair_key(d.a, d.b)] = true
	var candidates: Array = []
	for y in range(rows):
		for x in range(cols - 1):
			if not open_right[y][x]:
				candidates.append([Vector2i(x, y), Vector2i(x + 1, y)])
	for y in range(rows - 1):
		for x in range(cols):
			if not open_down[y][x]:
				candidates.append([Vector2i(x, y), Vector2i(x, y + 1)])
	# Mescolati: scorrendoli in ordine i varchi extra finirebbero sempre
	# sul primo tratto di muro di ogni coppia (in alto a sinistra).
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	for pair in candidates:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if _same_room(a, b) or _touches_exit_room(a, b):
			continue
		var key: Vector2i = _room_pair_key(a, b)
		if linked.has(key):
			continue
		if rng.randf() < chance:
			_carve_doorway(a, b)
			linked[key] = true

func _room_pair_key(a: Vector2i, b: Vector2i) -> Vector2i:
	var ra: int = room_at(a)
	var rb: int = room_at(b)
	return Vector2i(min(ra, rb), max(ra, rb))

func _same_room(a: Vector2i, b: Vector2i) -> bool:
	return room_at(a) == room_at(b)

func _touches_exit_room(a: Vector2i, b: Vector2i) -> bool:
	if exit_room_index < 0:
		return false
	return room_at(a) == exit_room_index or room_at(b) == exit_room_index

func _build_room_index() -> void:
	_room_of_cell = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(-1)
		_room_of_cell.append(row)
	for i in range(rooms.size()):
		var room: Rect2i = rooms[i]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				_room_of_cell[y][x] = i

func room_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= rows:
		return -1
	return _room_of_cell[cell.y][cell.x]

func room_cells(index: int) -> Array:
	var result: Array = []
	if index < 0 or index >= rooms.size():
		return result
	var room: Rect2i = rooms[index]
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			result.append(Vector2i(x, y))
	return result

func doorways_of_room(index: int) -> Array:
	var result: Array = []
	for d in doorways:
		if room_at(d.a) == index or room_at(d.b) == index:
			result.append(d)
	return result

# --- Sala del premio e porta di uscita ---------------------------------------

# La sala del premio è la più lontana dallo spawn (in passi lungo i
# passaggi aperti, non in linea d'aria) fra quelle con UN SOLO varco:
# quel varco diventa la porta, e chiudendolo non si isola nient'altro.
func _pick_exit_room(spawn_cell: Vector2i) -> void:
	if rooms.size() < 2:
		return
	var dist := _cell_distances(spawn_cell)
	var best_room := -1
	var best_dist := -1
	for i in range(rooms.size()):
		if doorways_of_room(i).size() != 1:
			continue
		var far := -1
		for cell in room_cells(i):
			var d: int = dist.get(cell, -1)
			if d > far:
				far = d
		if far > best_dist:
			best_dist = far
			best_room = i
	if best_room < 0:
		return
	exit_room_index = best_room
	var door: Dictionary = doorways_of_room(best_room)[0]
	# `b` è sempre la cella dentro la sala del premio: chi attraversa la
	# porta va da `a` verso `b`.
	if room_at(door.a) == best_room:
		gate_doorway = {"a": door.b, "b": door.a}
	else:
		gate_doorway = {"a": door.a, "b": door.b}

func _cell_distances(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array = [from]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for n in _open_neighbors(cur):
			if not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist

func exit_room_cells() -> Array:
	return room_cells(exit_room_index)

func has_exit_gate() -> bool:
	return exit_room_index >= 0 and not gate_doorway.is_empty()

# Il rettangolo di passaggio libero lasciato da un varco: è lí che si
# installa la porta di uscita (mentre è chiusa diventa un blocco in
# `extra_blockers`, e lí si disegna la grata).
func gate_rect() -> Rect2:
	if not has_exit_gate():
		return Rect2()
	return doorway_gap_rect(gate_doorway.a, gate_doorway.b)

func doorway_gap_rect(a: Vector2i, b: Vector2i) -> Rect2:
	var t := wall_thickness
	var half := DOOR_WIDTH * 0.5
	if a.y == b.y:
		var x: float = origin.x + float(max(a.x, b.x)) * cell_size
		var center_y: float = origin.y + (float(a.y) + 0.5) * cell_size
		return Rect2(Vector2(x - t * 0.5, center_y - half), Vector2(t, DOOR_WIDTH))
	var y: float = origin.y + float(max(a.y, b.y)) * cell_size
	var center_x: float = origin.x + (float(a.x) + 0.5) * cell_size
	return Rect2(Vector2(center_x - half, y - t * 0.5), Vector2(DOOR_WIDTH, t))

func is_gate_doorway(a: Vector2i, b: Vector2i) -> bool:
	if not has_exit_gate():
		return false
	var ga: Vector2i = gate_doorway.a
	var gb: Vector2i = gate_doorway.b
	return (a == ga and b == gb) or (a == gb and b == ga)

# --- Geometria e interrogazioni ----------------------------------------------

func _open_neighbors(cell: Vector2i) -> Array:
	var result: Array = []
	var x := cell.x
	var y := cell.y
	if x > 0 and open_right[y][x - 1]:
		result.append(Vector2i(x - 1, y))
	if x < cols - 1 and open_right[y][x]:
		result.append(Vector2i(x + 1, y))
	if y > 0 and open_down[y - 1][x]:
		result.append(Vector2i(x, y - 1))
	if y < rows - 1 and open_down[y][x]:
		result.append(Vector2i(x, y + 1))
	return result

func cell_center(cx: int, cy: int) -> Vector2:
	return origin + Vector2((float(cx) + 0.5) * cell_size, (float(cy) + 0.5) * cell_size)

func world_to_cell(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - origin
	return Vector2i(
		clampi(int(floor(local.x / cell_size)), 0, cols - 1),
		clampi(int(floor(local.y / cell_size)), 0, rows - 1)
	)

func find_farthest_cell(from: Vector2i) -> Vector2i:
	var dist := _cell_distances(from)
	var farthest := from
	var farthest_dist := 0
	for cell in dist.keys():
		var d: int = dist[cell]
		if d > farthest_dist:
			farthest_dist = d
			farthest = cell
	return farthest

func random_cell(rng: RandomNumberGenerator, exclude: Array = []) -> Vector2i:
	var attempts := 0
	while attempts < 200:
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if not exclude.has(c):
			return c
		attempts += 1
	# Ripiego deterministico: la prima cella ammessa trovata scorrendo la
	# griglia. Tirare a caso e arrendersi su (0,0) rischierebbe di metterci
	# un nemico proprio dove non deve stare (la sala del premio, chiusa
	# dalla porta: la mappa non si potrebbe più ripulire).
	for y in range(rows):
		for x in range(cols):
			var c := Vector2i(x, y)
			if not exclude.has(c):
				return c
	return Vector2i(0, 0)

func total_bounds() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * cell_size)

func is_position_free(pos: Vector2, radius: float) -> bool:
	for rect in wall_rects:
		if _circle_intersects_rect(pos, radius, rect):
			return false
	for rect in extra_blockers:
		if _circle_intersects_rect(pos, radius, rect):
			return false
	return true

func resolve_move(current_pos: Vector2, delta_move: Vector2, radius: float) -> Vector2:
	# Suddivide lo spostamento in sotto-passi non più lunghi di metà
	# spessore muro: un singolo passo troppo grande (es. uno scatto veloce
	# su più frame accumulati) potrebbe "teletrasportare" l'entità oltre
	# una parete sottile senza mai testare un punto che vi si trova dentro.
	var pos := current_pos
	var total_dist: float = delta_move.length()
	if total_dist <= 0.001:
		return pos
	var max_step: float = wall_thickness * 0.5
	var steps: int = max(1, ceili(total_dist / max_step))
	var step_move: Vector2 = delta_move / float(steps)
	for i in range(steps):
		var try_x := Vector2(pos.x + step_move.x, pos.y)
		if is_position_free(try_x, radius):
			pos.x = try_x.x
		var try_y := Vector2(pos.x, pos.y + step_move.y)
		if is_position_free(try_y, radius):
			pos.y = try_y.y
	return pos

func get_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	if astar == null:
		return PackedVector2Array()
	var from_cell := world_to_cell(from_pos)
	var to_cell := world_to_cell(to_pos)
	return astar.get_point_path(_cell_id(from_cell.x, from_cell.y), _cell_id(to_cell.x, to_cell.y))

# Vero se tra i due punti non si frappone alcuna parete. Serve a chi
# spara da fermo (il Pungiglione) per non scaricare dardi contro un muro
# restandosene al sicuro dall'altra parte senza mai colpire nulla.
# `clearance` allarga le pareti del raggio del proiettile: un tiro che
# sfiora lo spigolo non arriverebbe comunque a destinazione.
func has_line_of_sight(from_pos: Vector2, to_pos: Vector2, clearance: float = 0.0) -> bool:
	for rect in wall_rects:
		if _segment_intersects_rect(from_pos, to_pos, rect.grow(clearance)):
			return false
	for rect in extra_blockers:
		if _segment_intersects_rect(from_pos, to_pos, rect.grow(clearance)):
			return false
	return true

# Intersezione segmento/rettangolo col metodo delle lastre: si restringe
# l'intervallo di percorrenza del segmento asse per asse e si guarda se
# ne resta qualcosa dentro il rettangolo.
func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var direction: Vector2 = b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in range(2):
		var origin: float = a[axis]
		var step: float = direction[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(step) < 0.00001:
			# Segmento parallelo a questo asse: o è già dentro la fascia
			# del rettangolo, o non la attraverserà mai.
			if origin < low or origin > high:
				return false
			continue
		var t1: float = (low - origin) / step
		var t2: float = (high - origin) / step
		if t1 > t2:
			var swap: float = t1
			t1 = t2
			t2 = swap
		t_min = max(t_min, t1)
		t_max = min(t_max, t2)
		if t_min > t_max:
			return false
	return true

func _cell_id(x: int, y: int) -> int:
	return y * cols + x

func _build_astar() -> void:
	astar = AStar2D.new()
	for y in range(rows):
		for x in range(cols):
			astar.add_point(_cell_id(x, y), cell_center(x, y))
	for y in range(rows):
		for x in range(cols):
			if x < cols - 1 and open_right[y][x]:
				astar.connect_points(_cell_id(x, y), _cell_id(x + 1, y))
			if y < rows - 1 and open_down[y][x]:
				astar.connect_points(_cell_id(x, y), _cell_id(x, y + 1))

func _build_wall_rects() -> void:
	wall_rects.clear()
	var t := wall_thickness
	for y in range(rows):
		wall_rects.append(_vertical_wall_rect(0, y, t))
		wall_rects.append(_vertical_wall_rect(cols, y, t))
		for x in range(cols - 1):
			if not open_right[y][x]:
				wall_rects.append(_vertical_wall_rect(x + 1, y, t))
	for x in range(cols):
		wall_rects.append(_horizontal_wall_rect(x, 0, t))
		wall_rects.append(_horizontal_wall_rect(x, rows, t))
		for y in range(rows - 1):
			if not open_down[y][x]:
				wall_rects.append(_horizontal_wall_rect(x, y + 1, t))
	_build_doorway_jambs(t)

# Spallette che stringono ogni varco fino a DOOR_WIDTH: un'apertura larga
# quanto un lato di cella non si leggerebbe come una porta, e la grata
# dell'uscita avrebbe l'aria di una recinzione.
func _build_doorway_jambs(t: float) -> void:
	for d in doorways:
		var a: Vector2i = d.a
		var b: Vector2i = d.b
		var half := DOOR_WIDTH * 0.5
		if a.y == b.y:
			var x: float = origin.x + float(max(a.x, b.x)) * cell_size
			var span_start: float = origin.y + float(a.y) * cell_size - t * 0.5
			var span_end: float = span_start + cell_size + t
			var center_y: float = origin.y + (float(a.y) + 0.5) * cell_size
			_append_jamb(Rect2(Vector2(x - t * 0.5, span_start), Vector2(t, center_y - half - span_start)))
			_append_jamb(Rect2(Vector2(x - t * 0.5, center_y + half), Vector2(t, span_end - center_y - half)))
		else:
			var y: float = origin.y + float(max(a.y, b.y)) * cell_size
			var span_start_x: float = origin.x + float(a.x) * cell_size - t * 0.5
			var span_end_x: float = span_start_x + cell_size + t
			var center_x: float = origin.x + (float(a.x) + 0.5) * cell_size
			_append_jamb(Rect2(Vector2(span_start_x, y - t * 0.5), Vector2(center_x - half - span_start_x, t)))
			_append_jamb(Rect2(Vector2(center_x + half, y - t * 0.5), Vector2(span_end_x - center_x - half, t)))

func _append_jamb(rect: Rect2) -> void:
	if rect.size.x > 0.5 and rect.size.y > 0.5:
		wall_rects.append(rect)

func _vertical_wall_rect(grid_x: int, y: int, t: float) -> Rect2:
	var cx: float = origin.x + float(grid_x) * cell_size
	var cy: float = origin.y + float(y) * cell_size
	return Rect2(Vector2(cx - t / 2.0, cy - t / 2.0), Vector2(t, cell_size + t))

func _horizontal_wall_rect(x: int, grid_y: int, t: float) -> Rect2:
	var cx: float = origin.x + float(x) * cell_size
	var cy: float = origin.y + float(grid_y) * cell_size
	return Rect2(Vector2(cx - t / 2.0, cy - t / 2.0), Vector2(cell_size + t, t))

func _circle_intersects_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	var closest_x: float = clamp(pos.x, rect.position.x, rect.end.x)
	var closest_y: float = clamp(pos.y, rect.position.y, rect.end.y)
	var dx: float = pos.x - closest_x
	var dy: float = pos.y - closest_y
	return (dx * dx + dy * dy) < (radius * radius)
