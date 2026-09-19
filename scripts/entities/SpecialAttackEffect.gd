class_name SpecialAttackEffect
extends Node2D

# Effetto visivo generico e leggero per rendere riconoscibili gli attacchi
# speciali concessi dagli alleati (vedi Run._spawn_special_effect):
# un anello che si espande e sfuma per gli attacchi ad area (Colpo
# Corazzato, il "colpo di rilascio" di Dardo Velenoso/Sciame Vendicativo),
# oppure un fascio di graffi per l'attacco da mischia (Morso Selvaggio).
# Puramente decorativo (nessuna collisione): si autodistrugge da solo alla
# fine della propria durata.

enum Kind { RING, SLASH }

var kind: int = Kind.RING
var color := Color.WHITE
var max_radius := 60.0
var duration := 0.3
var direction := Vector2.RIGHT
var _elapsed := 0.0

func setup(p_kind: int, p_color: Color, p_max_radius: float, p_duration: float, p_direction: Vector2 = Vector2.RIGHT) -> void:
	kind = p_kind
	color = p_color
	max_radius = p_max_radius
	duration = p_duration
	direction = p_direction

func _ready() -> void:
	z_index = 5
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(_elapsed / duration, 0.0, 1.0)
	var alpha: float = 1.0 - t
	match kind:
		Kind.RING:
			var r: float = lerp(max_radius * 0.35, max_radius, t)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.r, color.g, color.b, alpha * 0.9), 4.0, true)
		Kind.SLASH:
			var fwd: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
			var perp := Vector2(-fwd.y, fwd.x)
			var spread: float = max_radius * (0.4 + 0.6 * t)
			for i in range(3):
				var offset: float = (float(i) - 1.0) * 10.0
				var center: Vector2 = perp * offset
				var from: Vector2 = center - fwd * spread * 0.5
				var to: Vector2 = center + fwd * spread * 0.5
				draw_line(from, to, Color(color.r, color.g, color.b, alpha), 5.0)
