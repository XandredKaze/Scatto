class_name MazeGrid
extends RefCounted

# Struttura della mappa: SALE sparse nel buio, collegate da CORRIDOI.
#
# La griglia di celle viene suddivisa ricorsivamente (BSP) in zone; in
# ogni zona si ricava una sala più piccola della zona stessa, in una
# posizione a caso, cosí fra una sala e l'altra resta sempre del vuoto
# (almeno due celle) e le sale non formano mai un unico blocco compatto.
# Ogni taglio della suddivisione collega le due metà con un corridoio
# largo una cella fra le due sale più vicine: l'albero dei tagli basta a
# rendere tutto raggiungibile. Qualche corridoio in più chiude degli
# anelli, cosí non si torna sempre per la stessa strada.
#
# Le celle che non sono né sala né corridoio sono VUOTO: non ci si entra
# (is_position_free le rifiuta, e i muri le chiudono) e non si disegnano.
#
# Una sala è la SALA DEL PREMIO: la più lontana dallo spawn fra quelle
# raggiunte da un solo corridoio. L'imbocco di quel corridoio ospita la
# porta di uscita (vedi ExitGate), chiusa finché la mappa non è ripulita:
# è l'unico modo di raggiungere la mappa successiva, e nessun nemico vi
# viene generato (sarebbe irraggiungibile, e la porta non si aprirebbe).
#
# Le pareti sono sia segmenti Rect2 (collisione e disegno) sia grafo di
# celle collegate (pathfinding AStar2D). Nessun nodo della scena: è puro
# dato/logica, cosí è testabile senza avviare l'albero di gioco.

# Lato di una sala, in celle: in BalanceConfig (gruppo "Mappe"). Il
# massimo non scende mai sotto il minimo, qualunque cosa si imposti.
static var MIN_ROOM_CELLS: int:
	get: return BalanceConfig.current().mappe_sala_minima
static var MAX_ROOM_CELLS: int:
	get: return max(MIN_ROOM_CELLS, BalanceConfig.current().mappe_sala_massima)
# Lato minimo di una zona della suddivisione: una sala minima più una
# cella di vuoto per parte. È questo margine a tenere le sale separate.
static var MIN_ZONE_CELLS: int:
	get: return MIN_ROOM_CELLS + 2
# Una zona ancora divisibile ma già piccola può restare intera: la sua
# sala avrà molto vuoto attorno, e la mappa risulta meno regolare.
const ZONE_STOP_CHANCE := 0.25
# Corridoi oltre a quelli indispensabili, per chiudere qualche anello.
static var EXTRA_CORRIDORS: int:
	get: return BalanceConfig.current().mappe_corridoi_extra
const EXTRA_CORRIDOR_CHANCE := 0.6

const VOID_CELL := -1
const CORRIDOR_CELL := -2

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
var doorways: Array = []     # Array[{a: cella fuori, b: cella della sala}]
var spawn_cell: Vector2i = Vector2i.ZERO
var spawn_room_index: int = -1
var exit_room_index: int = -1
var gate_doorway: Dictionary = {}  # {a: cella del corridoio, b: cella dentro la sala del premio}

var _kind: Array = []        # _kind[y][x]: indice della sala, CORRIDOR_CELL o VOID_CELL
var _linked := {}            # coppie di sale già unite da un corridoio

func generate(p_cols: int, p_rows: int, p_cell_size: float, rng: RandomNumberGenerator, spawn_hint: Vector2i = Vector2i(0, 0)) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size

	rooms.clear()
	doorways.clear()
	extra_blockers.clear()
	_linked = {}
	exit_room_index = -1
	spawn_room_index = -1
	gate_doorway = {}
	_reset_grid()

	_split_zone(Rect2i(0, 0, cols, rows), rng, true)
	_pick_spawn(spawn_hint)
	_compute_doorways()
	_pick_exit_room()
	_add_extra_corridors(rng)
	_compute_doorways()
	_build_wall_rects()
	_build_astar()

func _reset_grid() -> void:
	open_right = []
	open_down = []
	_kind = []
	for y in range(rows):
		var right_row: Array = []
		var down_row: Array = []
		var kind_row: Array = []
		for x in range(cols):
			right_row.append(false)
			down_row.append(false)
			kind_row.append(VOID_CELL)
		open_right.append(right_row)
		open_down.append(down_row)
		_kind.append(kind_row)

# --- Suddivisione in zone e sale ---------------------------------------------

# Taglia ricorsivamente `zone` in due metà, ricorre su entrambe e unisce
# con un corridoio le due sale più vicine fra le due metà. Restituisce gli
# indici delle sale nate in questa zona.
func _split_zone(zone: Rect2i, rng: RandomNumberGenerator, is_root: bool = false) -> Array:
	var can_cut_x: bool = zone.size.x >= MIN_ZONE_CELLS * 2
	var can_cut_y: bool = zone.size.y >= MIN_ZONE_CELLS * 2
	var stop: bool = not can_cut_x and not can_cut_y
	# Mai alla radice: la mappa resterebbe una sola sala, senza corridoi e
	# quindi senza porta di uscita.
	if not stop and not is_root and zone.size.x <= MIN_ZONE_CELLS * 3 and zone.size.y <= MIN_ZONE_CELLS * 3:
		stop = rng.randf() < ZONE_STOP_CHANCE
	if stop:
		return [_place_room(zone, rng)]

	var cut_x: bool
	if can_cut_x and can_cut_y:
		# Si taglia il lato lungo, cosí le zone restano grosso modo quadrate.
		if zone.size.x == zone.size.y:
			cut_x = rng.randf() < 0.5
		else:
			cut_x = zone.size.x > zone.size.y
	else:
		cut_x = can_cut_x

	var first: Rect2i
	var second: Rect2i
	if cut_x:
		var cut: int = rng.randi_range(zone.position.x + MIN_ZONE_CELLS, zone.end.x - MIN_ZONE_CELLS)
		first = Rect2i(zone.position, Vector2i(cut - zone.position.x, zone.size.y))
		second = Rect2i(Vector2i(cut, zone.position.y), Vector2i(zone.end.x - cut, zone.size.y))
	else:
		var cut_y: int = rng.randi_range(zone.position.y + MIN_ZONE_CELLS, zone.end.y - MIN_ZONE_CELLS)
		first = Rect2i(zone.position, Vector2i(zone.size.x, cut_y - zone.position.y))
		second = Rect2i(Vector2i(zone.position.x, cut_y), Vector2i(zone.size.x, zone.end.y - cut_y))

	var left: Array = _split_zone(first, rng)
	var right: Array = _split_zone(second, rng)
	_connect_nearest(left, right, rng)
	return left + right

# Una sala più piccola della sua zona, in una posizione a caso al suo
# interno, con almeno una cella di vuoto per lato quando la zona lo
# permette: è quel margine a lasciare il buio fra una sala e l'altra.
func _place_room(zone: Rect2i, rng: RandomNumberGenerator) -> int:
	var size := Vector2i(_room_extent(zone.size.x, rng), _room_extent(zone.size.y, rng))
	var pos := Vector2i(
		_room_offset(zone.position.x, zone.size.x, size.x, rng),
		_room_offset(zone.position.y, zone.size.y, size.y, rng)
	)
	var room := Rect2i(pos, size)
	var index: int = rooms.size()
	rooms.append(room)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_kind[y][x] = index
			if x < room.end.x - 1:
				open_right[y][x] = true
			if y < room.end.y - 1:
				open_down[y][x] = true
	return index

func _room_extent(span: int, rng: RandomNumberGenerator) -> int:
	var top: int = min(MAX_ROOM_CELLS, span - 2)
	if top >= MIN_ROOM_CELLS:
		return rng.randi_range(MIN_ROOM_CELLS, top)
	# Zona più stretta del previsto (griglie piccole): la sala si prende
	# quello che c'è, rinunciando al margine prima che alla sala.
	return min(span, MIN_ROOM_CELLS)

func _room_offset(start: int, span: int, extent: int, rng: RandomNumberGenerator) -> int:
	var slack: int = span - extent
	if slack >= 2:
		return rng.randi_range(start + 1, start + slack - 1)
	return start + slack / 2

# --- Corridoi ----------------------------------------------------------------

func _connect_nearest(group_a: Array, group_b: Array, rng: RandomNumberGenerator) -> void:
	var best_a := -1
	var best_b := -1
	var best_dist := INF
	for ia in group_a:
		for ib in group_b:
			var d: float = _room_distance(ia, ib)
			if d < best_dist:
				best_dist = d
				best_a = ia
				best_b = ib
	if best_a < 0:
		return
	_carve_path(_corridor_path(rooms[best_a], rooms[best_b], rng))
	_linked[_pair_key(best_a, best_b)] = true

func _room_distance(ia: int, ib: int) -> float:
	var a: Rect2i = rooms[ia]
	var b: Rect2i = rooms[ib]
	return Vector2(a.get_center()).distance_to(Vector2(b.get_center()))

# Il percorso di un corridoio fra due sale, cella per cella. Se le due
# sale si fronteggiano (si sovrappongono lungo un asse) il corridoio è
# dritto; altrimenti piega una volta ad angolo retto. Fra i tracciati
# possibili (ogni colonna o riga in comune, o le due pieghe) si sceglie
# quello che corre meno a ridosso di corridoi e sale già scavati: due
# corridoi affiancati, separati solo da un muretto, sembrano un errore.
func _corridor_path(a: Rect2i, b: Rect2i, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = _corridor_candidates(a, b)
	# Ordine casuale: a parità di punteggio vince un tracciato qualsiasi,
	# non sempre il primo (che sarebbe sempre sul lato sinistro/alto).
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var best: Array = candidates[0]
	var best_score: int = _crowding(best)
	for path in candidates:
		var score: int = _crowding(path)
		if score < best_score:
			best_score = score
			best = path
	return best

func _corridor_candidates(a: Rect2i, b: Rect2i) -> Array:
	var lo_x: int = max(a.position.x, b.position.x)
	var hi_x: int = min(a.end.x, b.end.x) - 1
	var lo_y: int = max(a.position.y, b.position.y)
	var hi_y: int = min(a.end.y, b.end.y) - 1
	var ca: Vector2i = _room_center(a)
	var cb: Vector2i = _room_center(b)
	var result: Array = []
	if lo_x <= hi_x:
		for x in range(lo_x, hi_x + 1):
			result.append(_straight(Vector2i(x, ca.y), Vector2i(x, cb.y)))
		return result
	if lo_y <= hi_y:
		for y in range(lo_y, hi_y + 1):
			result.append(_straight(Vector2i(ca.x, y), Vector2i(cb.x, y)))
		return result
	for corner in [Vector2i(cb.x, ca.y), Vector2i(ca.x, cb.y)]:
		var path: Array = _straight(ca, corner)
		var tail: Array = _straight(corner, cb)
		tail.pop_front()
		path.append_array(tail)
		result.append(path)
	return result

# Quante celle nuove del tracciato (quelle che oggi sono vuoto) toccano di
# lato qualcosa di già scavato che non fa parte del tracciato stesso.
func _crowding(path: Array) -> int:
	var on_path := {}
	for cell in path:
		on_path[cell] = true
	var score := 0
	for cell in path:
		if _kind[cell.y][cell.x] != VOID_CELL:
			continue
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + step
			if on_path.has(n) or not _in_grid(n):
				continue
			if _kind[n.y][n.x] != VOID_CELL:
				score += 1
	return score

func _room_center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2

func _straight(from: Vector2i, to: Vector2i) -> Array:
	var path: Array = [from]
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var cur := from
	while cur != to:
		cur += step
		path.append(cur)
	return path

func _carve_path(path: Array) -> void:
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		if _kind[cell.y][cell.x] == VOID_CELL:
			_kind[cell.y][cell.x] = CORRIDOR_CELL
		if i > 0:
			_carve(path[i - 1], cell)

func _carve(a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		open_right[a.y][min(a.x, b.x)] = true
	else:
		open_down[min(a.y, b.y)][a.x] = true

# Corridoi in più fra sale vicine non ancora unite direttamente: chiudono
# anelli, cosí il giocatore ha più di una strada. Mai verso la sala del
# premio né attraverso di essa: deve conservare il suo unico imbocco,
# quello con la porta.
func _add_extra_corridors(rng: RandomNumberGenerator) -> void:
	var pairs: Array = []
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			if i == exit_room_index or j == exit_room_index:
				continue
			if _linked.has(_pair_key(i, j)):
				continue
			pairs.append([_room_distance(i, j), i, j])
	pairs.sort_custom(func(p, q): return p[0] < q[0])
	var added := 0
	for pair in pairs:
		if added >= EXTRA_CORRIDORS:
			break
		if rng.randf() > EXTRA_CORRIDOR_CHANCE:
			continue
		var path: Array = _corridor_path(rooms[pair[1]], rooms[pair[2]], rng)
		if exit_room_index >= 0 and path.any(func(c): return _kind[c.y][c.x] == exit_room_index):
			continue
		# Un anello è facoltativo: lo si scava solo se passa pulito, senza
		# costeggiare niente di già scavato.
		if _crowding(path) > 0:
			continue
		_carve_path(path)
		_linked[_pair_key(pair[1], pair[2])] = true
		added += 1

func _pair_key(i: int, j: int) -> Vector2i:
	return Vector2i(min(i, j), max(i, j))

# --- Varchi, spawn e sala del premio -----------------------------------------

# Un varco è un passaggio aperto fra una cella di sala e una cella che non
# appartiene a quella sala (di solito l'imbocco di un corridoio).
func _compute_doorways() -> void:
	doorways.clear()
	for y in range(rows):
		for x in range(cols):
			if x < cols - 1 and open_right[y][x]:
				_record_doorway(Vector2i(x, y), Vector2i(x + 1, y))
			if y < rows - 1 and open_down[y][x]:
				_record_doorway(Vector2i(x, y), Vector2i(x, y + 1))

func _record_doorway(p: Vector2i, q: Vector2i) -> void:
	var kp: int = _kind[p.y][p.x]
	var kq: int = _kind[q.y][q.x]
	if kp == kq:
		return
	if kp >= 0:
		doorways.append({"a": q, "b": p})
	elif kq >= 0:
		doorways.append({"a": p, "b": q})

# Lo spawn è al centro della sala più vicina al punto suggerito (di norma
# un angolo della mappa), cosí la sala del premio finisce dall'altra parte.
func _pick_spawn(hint: Vector2i) -> void:
	var best := -1
	var best_dist := INF
	for i in range(rooms.size()):
		var d: float = Vector2(rooms[i].get_center()).distance_to(Vector2(hint))
		if d < best_dist:
			best_dist = d
			best = i
	spawn_room_index = best
	if best >= 0:
		spawn_cell = _room_center(rooms[best])

# La sala del premio è la più lontana dallo spawn (in passi lungo i
# passaggi aperti, non in linea d'aria) fra quelle con UN SOLO varco:
# quel varco diventa la porta, e chiuderlo non isola nient'altro.
func _pick_exit_room() -> void:
	if rooms.size() < 2:
		return
	var dist := _cell_distances(spawn_cell)
	var best_room := -1
	var best_dist := -1
	for i in range(rooms.size()):
		if i == spawn_room_index or doorways_of_room(i).size() != 1:
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

# --- Interrogazioni su sale e celle ------------------------------------------

func room_at(cell: Vector2i) -> int:
	if not _in_grid(cell):
		return -1
	var k: int = _kind[cell.y][cell.x]
	return k if k >= 0 else -1

func is_open_cell(cell: Vector2i) -> bool:
	return _in_grid(cell) and _kind[cell.y][cell.x] != VOID_CELL

func is_corridor_cell(cell: Vector2i) -> bool:
	return _in_grid(cell) and _kind[cell.y][cell.x] == CORRIDOR_CELL

func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

# Vero se il punto cade dentro una sala (non in un corridoio né nel vuoto).
func is_room_point(pos: Vector2) -> bool:
	if not total_bounds().has_point(pos):
		return false
	return room_at(world_to_cell(pos)) >= 0

func open_cells() -> Array:
	var result: Array = []
	for y in range(rows):
		for x in range(cols):
			if _kind[y][x] != VOID_CELL:
				result.append(Vector2i(x, y))
	return result

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size))

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

func exit_room_cells() -> Array:
	return room_cells(exit_room_index)

func has_exit_gate() -> bool:
	return exit_room_index >= 0 and not gate_doorway.is_empty()

# Il rettangolo di passaggio libero all'imbocco della sala del premio: è lí
# che si installa la porta (mentre è chiusa diventa un blocco in
# `extra_blockers`, e lí si disegna la grata).
func gate_rect() -> Rect2:
	if not has_exit_gate():
		return Rect2()
	return doorway_gap_rect(gate_doorway.a, gate_doorway.b)

# Il passaggio fra due celle adiacenti è largo quanto un corridoio: il lato
# della cella meno mezzo muro per parte (le pareti del corridoio).
func doorway_gap_rect(a: Vector2i, b: Vector2i) -> Rect2:
	var t := wall_thickness
	var half: float = (cell_size - t) * 0.5
	if a.y == b.y:
		var x: float = origin.x + float(max(a.x, b.x)) * cell_size
		var center_y: float = origin.y + (float(a.y) + 0.5) * cell_size
		return Rect2(Vector2(x - t * 0.5, center_y - half), Vector2(t, half * 2.0))
	var y: float = origin.y + float(max(a.y, b.y)) * cell_size
	var center_x: float = origin.x + (float(a.x) + 0.5) * cell_size
	return Rect2(Vector2(center_x - half, y - t * 0.5), Vector2(half * 2.0, t))

# --- Geometria e movimento ---------------------------------------------------

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

# Una cella a caso dentro una sala (mai in un corridoio né nel vuoto),
# esclusa ogni cella di `exclude`.
func random_cell(rng: RandomNumberGenerator, exclude: Array = []) -> Vector2i:
	var candidates: Array = []
	for i in range(rooms.size()):
		for cell in room_cells(i):
			if not exclude.has(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return spawn_cell
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func total_bounds() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * cell_size)

func is_position_free(pos: Vector2, radius: float) -> bool:
	# Il vuoto fra le sale non è spazio percorribile: chiunque ci finisse
	# (un Pungiglione che rispunta, un proiettile, una macchia di sangue
	# del decoro) sarebbe fuori dalla mappa.
	if not total_bounds().has_point(pos):
		return false
	if not is_open_cell(world_to_cell(pos)):
		return false
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
	var from_id := _cell_id(from_cell.x, from_cell.y)
	var to_id := _cell_id(to_cell.x, to_cell.y)
	# Nel vuoto non ci sono punti del grafo: chiederne il percorso darebbe
	# errore. Non dovrebbe mai succedere (nessuno può stare nel vuoto), ma
	# un percorso vuoto è un ripiego innocuo.
	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return PackedVector2Array()
	return astar.get_point_path(from_id, to_id)

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
		var start: float = a[axis]
		var step: float = direction[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(step) < 0.00001:
			# Segmento parallelo a questo asse: o è già dentro la fascia
			# del rettangolo, o non la attraverserà mai.
			if start < low or start > high:
				return false
			continue
		var t1: float = (low - start) / step
		var t2: float = (high - start) / step
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
			if _kind[y][x] != VOID_CELL:
				astar.add_point(_cell_id(x, y), cell_center(x, y))
	for y in range(rows):
		for x in range(cols):
			if x < cols - 1 and open_right[y][x]:
				astar.connect_points(_cell_id(x, y), _cell_id(x + 1, y))
			if y < rows - 1 and open_down[y][x]:
				astar.connect_points(_cell_id(x, y), _cell_id(x, y + 1))

# Un muro su ogni lato di cella che separa spazio percorribile da ciò che
# non lo è (il vuoto, il bordo della mappa, o un'altra cella percorribile
# non collegata). I lati consecutivi sulla stessa linea si fondono in un
# unico blocco: meno rettangoli da controllare a ogni passo e nessuna
# giuntura visibile fra una cella e l'altra.
func _build_wall_rects() -> void:
	wall_rects.clear()
	var t := wall_thickness
	for y in range(rows + 1):
		var run_start := -1
		for x in range(cols + 1):
			var wall := false
			if x < cols:
				var above_open: bool = is_open_cell(Vector2i(x, y - 1))
				var below_open: bool = is_open_cell(Vector2i(x, y))
				var linked: bool = above_open and below_open and open_down[y - 1][x]
				wall = (above_open or below_open) and not linked
			if wall and run_start < 0:
				run_start = x
			elif not wall and run_start >= 0:
				wall_rects.append(Rect2(
					origin + Vector2(float(run_start) * cell_size - t * 0.5, float(y) * cell_size - t * 0.5),
					Vector2(float(x - run_start) * cell_size + t, t)
				))
				run_start = -1
	for x in range(cols + 1):
		var run_start := -1
		for y in range(rows + 1):
			var wall := false
			if y < rows:
				var left_open: bool = is_open_cell(Vector2i(x - 1, y))
				var right_open: bool = is_open_cell(Vector2i(x, y))
				var linked: bool = left_open and right_open and open_right[y][x - 1]
				wall = (left_open or right_open) and not linked
			if wall and run_start < 0:
				run_start = y
			elif not wall and run_start >= 0:
				wall_rects.append(Rect2(
					origin + Vector2(float(x) * cell_size - t * 0.5, float(run_start) * cell_size - t * 0.5),
					Vector2(t, float(y - run_start) * cell_size + t)
				))
				run_start = -1

func _circle_intersects_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	var closest_x: float = clamp(pos.x, rect.position.x, rect.end.x)
	var closest_y: float = clamp(pos.y, rect.position.y, rect.end.y)
	var dx: float = pos.x - closest_x
	var dy: float = pos.y - closest_y
	return (dx * dx + dy * dy) < (radius * radius)
