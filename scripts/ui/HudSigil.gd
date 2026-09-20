class_name HudSigil
extends Control

# Il sigillo incorniciato in alto a sinistra della HUD: la targa con il
# rombo che, nel riferimento estetico, apre la riga della vita e dà
# all'interfaccia un punto d'appoggio solido invece di lasciare barra e
# indicatori a galleggiare sullo schermo.
#
# Il rombo si accende di cremisi quando il giocatore è in buona salute e
# si spegne man mano che la vita cala: è una seconda lettura, periferica,
# della stessa informazione della barra.

var health_ratio := 1.0:
	set(value):
		var clamped: float = clamp(value, 0.0, 1.0)
		if is_equal_approx(clamped, health_ratio):
			return
		health_ratio = clamped
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(52, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.UI_BG)
	draw_rect(rect, Palette.STONE_EDGE, false, 1.0)

	var c: Vector2 = size * 0.5
	var r: float = min(size.x, size.y) * 0.32
	var diamond := PackedVector2Array([
		c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0),
	])
	draw_colored_polygon(diamond, Palette.with_alpha(Palette.BLOOD, 0.25 + 0.55 * health_ratio))
	var outline: PackedVector2Array = diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, Palette.with_alpha(Palette.EMBER, 0.35 + 0.65 * health_ratio), 2.0, true)
	# Lama stilizzata dentro il rombo, come l'emblema del riferimento.
	draw_line(c + Vector2(0.0, -r * 0.55), c + Vector2(0.0, r * 0.62), Palette.STEEL, 2.0)
	draw_line(c + Vector2(-r * 0.3, r * 0.2), c + Vector2(r * 0.3, r * 0.2), Palette.STEEL_DIM, 2.0)
