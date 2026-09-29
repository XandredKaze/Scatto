class_name BloodDecals
extends Node2D

# Il sangue che resta a terra. Nel riferimento estetico metà del
# carattere della scena viene proprio da qui: schizzi cremisi sparsi
# sulla pietra grigia, che raccontano lo scontro appena avvenuto e
# spezzano l'uniformità del pavimento.
#
# Le macchie sono puramente decorative (nessuna collisione) e vengono
# disegnate sotto le creature. Si accumulano durante la stanza e si
# azzerano quando la stanza cambia; oltre MAX_MARKS le più vecchie
# vengono scartate, cosí una run lunga non fa crescere il disegno senza
# limite.

const MAX_MARKS := 520

var _marks: Array = []  # {pos: Vector2, radius: float, color: Color}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = -5
	_rng.randomize()

# `amount` è la scala dello schizzo: un colpo andato a segno ne chiede
# poco, la morte di una creatura molto di più.
func splatter(pos: Vector2, amount: float, tint: Color = Palette.BLOOD) -> void:
	var blobs: int = clamp(int(amount * 6.0), 2, 22)
	var spread: float = 8.0 + amount * 26.0
	for i in range(blobs):
		var offset: Vector2 = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.0, spread)
		_marks.append({
			"pos": pos + offset,
			"radius": _rng.randf_range(2.0, 4.0 + amount * 6.0),
			"color": Color(tint.r, tint.g, tint.b, _rng.randf_range(0.45, 0.85)),
		})
	if _marks.size() > MAX_MARKS:
		_marks = _marks.slice(_marks.size() - MAX_MARKS)
	queue_redraw()

func clear_all() -> void:
	_marks.clear()
	queue_redraw()

func mark_count() -> int:
	return _marks.size()

func _draw() -> void:
	for mark in _marks:
		draw_circle(mark.pos, mark.radius, mark.color)
