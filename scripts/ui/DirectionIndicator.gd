class_name DirectionIndicator
extends Control

# Freccia ai bordi dello schermo che punta verso il portale di uscita,
# visibile solo quando la stanza è ripulita (portale attivo) e solo se
# il portale non è già inquadrato dalla camera. Ruota semplicemente se
# stessa: il resto (posizione sul bordo, quando mostrarla) lo decide chi
# la usa (vedi HUD._update_direction_indicator).

var arrow_color := Color(0.4, 0.88, 0.76)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)
	size = custom_minimum_size
	# I punti disegnati sono già centrati sull'origine locale (0,0):
	# nessun pivot_offset, altrimenti la freccia ruoterebbe attorno a un
	# punto lontano da sé invece che sul posto.
	pivot_offset = Vector2.ZERO

func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(14, 0), Vector2(-8, -9), Vector2(-8, 9),
	])
	draw_colored_polygon(points, arrow_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.55), 1.5, true)
