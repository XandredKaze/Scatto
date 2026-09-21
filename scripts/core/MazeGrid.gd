class_name MazeGrid
extends RefCounted

# Labirinto generato proceduralmente su una griglia di celle, con
# algoritmo "recursive backtracker" (genera un albero di copertura, cioè
# un labirinto "perfetto": un solo percorso tra due celle qualsiasi) più
# un passaggio successivo che riapre una percentuale di pareti interne
# per creare anelli ed evitare vicoli ciechi frustranti in combattimento.
#
# Le pareti sono rappresentate sia come segmenti Rect2 (collisione e
# disegno) sia come grafo di celle collegate (per il pathfinding dei
# nemici tramite AStar2D). Nessun nodo della scena: è puro dato/logica,
# cosí è testabile senza avviare l'albero di gioco.

var cols: int
var rows: int
var cell_size: float
var wall_thickness: float = 16.0
var origin: Vector2 = Vector2.ZERO

var open_right: Array = []  # open_right[y][x]: passaggio tra (x,y) e (x+1,y)
var open_down: Array = []   # open_down[y][x]: passaggio tra (x,y) e (x,y+1)
var wall_rects: Array = []
var astar: AStar2D

func generate(p_cols: int, p_rows: int, p_cell_size: float, rng: RandomNumberGenerator, loop_chance: float = 0.16) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell_size

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

	_carve_perfect_maze(rng)
	_add_loops(rng, loop_chance)
	_build_wall_rects()
	_build_astar()

func _carve_perfect_maze(rng: RandomNumberGenerator) -> void:
	var visited: Array = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(false)
		visited.append(row)

	var start := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
	visited[start.y][start.x] = true
	var stack: Array = [start]

	while stack.size() > 0:
		var current: Vector2i = stack[stack.size() - 1]
		var neighbors := _unvisited_neighbors(current, visited)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = neighbors[rng.randi_range(0, neighbors.size() - 1)]
		_carve(current, next)
		visited[next.y][next.x] = true
		stack.append(next)

func _unvisited_neighbors(cell: Vector2i, visited: Array) -> Array:
	var result: Array = []
	var candidates := [
		Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1),
	]
	for c in candidates:
		if c.x >= 0 and c.x < cols and c.y >= 0 and c.y < rows and not visited[c.y][c.x]:
			result.append(c)
	return result

func _carve(a: Vector2i, b: Vector2i) -> void:
	if a.y == b.y:
		open_right[a.y][min(a.x, b.x)] = true
	else:
		open_down[min(a.y, b.y)][a.x] = true

func _add_loops(rng: RandomNumberGenerator, loop_chance: float) -> void:
	for y in range(rows):
		for x in range(cols - 1):
			if not open_right[y][x] and rng.randf() < loop_chance:
				open_right[y][x] = true
	for y in range(rows - 1):
		for x in range(cols):
			if not open_down[y][x] and rng.randf() < loop_chance:
				open_down[y][x] = true

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
	var dist := {from: 0}
	var queue: Array = [from]
	var farthest := from
	var farthest_dist := 0
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = dist[cur]
		if d > farthest_dist:
			farthest_dist = d
			farthest = cur
		for n in _open_neighbors(cur):
			if not dist.has(n):
				dist[n] = d + 1
				queue.append(n)
	return farthest

func random_cell(rng: RandomNumberGenerator, exclude: Array = []) -> Vector2i:
	var attempts := 0
	while attempts < 200:
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if not exclude.has(c):
			return c
		attempts += 1
	return Vector2i(0, 0)

func total_bounds() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * cell_size)

func is_position_free(pos: Vector2, radius: float) -> bool:
	for rect in wall_rects:
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
