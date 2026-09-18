class_name ArenaVisual
extends Node2D

# Disegna lo spazio di gioco: un labirinto (quando `maze` è impostato,
# stanze 1-5) oppure un'arena aperta rettangolare (sala del boss).
# In entrambi i casi il disegno è in coordinate di mondo: la Camera2D
# del giocatore si occupa di mostrarne solo la porzione inquadrata.

var arena_size := Vector2(1280, 720)
var wall_margin := 48.0
var exit_active := false
var exit_position := Vector2.ZERO
var exit_radius := 28.0
var maze: MazeGrid = null

func _draw() -> void:
	if maze != null:
		_draw_maze()
	else:
		_draw_open_arena()
	if exit_active:
		draw_circle(exit_position, exit_radius, Color(0.4, 0.88, 0.76, 0.35))
		draw_arc(exit_position, exit_radius, 0.0, TAU, 24, Color(0.4, 0.88, 0.76, 0.8), 2.0)

func _draw_open_arena() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color8(21, 22, 28))
	var inner := Rect2(Vector2(wall_margin, wall_margin), arena_size - Vector2(wall_margin, wall_margin) * 2.0)
	draw_rect(inner, Color8(30, 32, 41))
	draw_rect(inner, Color8(58, 61, 74), false, 4.0)

func _draw_maze() -> void:
	draw_rect(maze.total_bounds(), Color8(30, 32, 41))
	for rect in maze.wall_rects:
		draw_rect(rect, Color8(58, 61, 74))

func set_exit_active(active: bool) -> void:
	if exit_active == active:
		return
	exit_active = active
	queue_redraw()
