class_name ExitGate
extends Node2D

# La porta che chiude il varco verso la sala del premio, e con essa la
# strada verso la mappa successiva. Resta serrata finché nella mappa c'è
# un nemico ostile in piedi: finché è chiusa, Run la registra fra gli
# ostacoli del livello (MazeGrid.extra_blockers), quindi ferma davvero
# chiunque — giocatore, nemici, alleati e proiettili.
#
# Vista dall'alto una saracinesca mostra le teste delle sue sbarre: una
# fila di blocchi di ferro che attraversa l'apertura. Aprendosi la fila si
# spezza a metà e le due parti rientrano negli stipiti, lasciando al loro
# posto la luce della soglia — che pulsa, cosí si riconosce da lontano
# dov'è l'uscita anche in una sala già visitata.

const BAR_COUNT := 7
const OPEN_TIME := 0.55
const GLOW_PULSE_SPEED := 2.2
const GLOW_RINGS := 9

var gap_rect: Rect2 = Rect2()
var is_open := false

var _long_is_y := false
var _half_long := 0.0
var _half_thick := 0.0
var _open_progress := 0.0
var _pulse := 0.0

func setup(rect: Rect2) -> void:
	gap_rect = rect
	_long_is_y = rect.size.y > rect.size.x
	_half_long = (rect.size.y if _long_is_y else rect.size.x) * 0.5
	_half_thick = (rect.size.x if _long_is_y else rect.size.y) * 0.5
	global_position = rect.get_center()
	queue_redraw()

# Apre la porta. L'animazione è solo estetica: chi decide se si passa o no
# è Run, che toglie il blocco dagli ostacoli del livello nello stesso
# istante — non si resta mai bloccati contro una grata che sta salendo.
func open() -> void:
	if is_open:
		return
	is_open = true
	set_process(true)

func _ready() -> void:
	# Nessun z_index: l'ordine è quello dell'albero, e Run inserisce la
	# porta fra il pavimento e i contenitori delle creature (così la grata
	# sta sulle lastre e chi la attraversa le passa sopra).
	set_process(true)

func _process(delta: float) -> void:
	_pulse += delta * GLOW_PULSE_SPEED
	if is_open and _open_progress < 1.0:
		_open_progress = min(1.0, _open_progress + delta / OPEN_TIME)
	queue_redraw()

# --- Disegno -----------------------------------------------------------------

func _draw() -> void:
	if gap_rect.size == Vector2.ZERO:
		return
	_draw_glow()
	if _open_progress < 1.0:
		_draw_grate()
		_draw_seal()
	_draw_threshold()

# Alone circolare, come quello dei bracieri: su un pavimento quasi nero
# pochi cerchi a bassissima opacità bastano a leggersi come luce. Da
# chiusa è un rosso spento (il sigillo trattiene); da aperta è brace viva
# e pulsa, cosí la porta si trova anche guardando la mappa da lontano.
func _draw_glow() -> void:
	var opening: float = _open_progress
	var pulse: float = 0.5 + 0.5 * sin(_pulse)
	var color: Color = Palette.BLOOD.lerp(Palette.EMBER, opening)
	var outer: float = lerp(_half_long * 1.1, _half_long * 1.8, opening)
	# Tanti cerchi molto tenui invece di pochi carichi: con pochi anelli
	# si vedono i gradini e l'alone sembra un bersaglio, non una luce.
	var base_alpha: float = lerp(0.016, 0.022 + 0.016 * pulse, opening)
	var step_alpha: float = lerp(0.012, 0.03, opening)
	for i in range(GLOW_RINGS):
		var t: float = float(i) / float(GLOW_RINGS - 1)
		draw_circle(Vector2.ZERO, lerp(outer, _half_long * 0.3, t), Palette.with_alpha(color, base_alpha + t * step_alpha))

# La saracinesca vista dall'alto: una lastra di ferro che riempie il
# varco, divisa in teste di sbarra. Aprendosi si spezza a metà e le due
# parti rientrano negli stipiti.
func _draw_grate() -> void:
	var opening: float = _open_progress
	var reach: float = _half_long * (1.0 - opening)
	if reach <= 0.5:
		return
	var iron: Color = Palette.VOID.lerp(Palette.STEEL_DIM, 0.45)
	# Due metà: ognuna parte dallo stipite e arriva verso il centro
	# quanto la porta è ancora chiusa.
	for side in [-1.0, 1.0]:
		var from: float = side * _half_long
		var to: float = side * (_half_long - reach)
		draw_rect(_span_rect(min(from, to), max(from, to), -_half_thick, _half_thick), iron)
		# Spigolo illuminato: fa leggere il ferro come volume, non come
		# una macchia sul pavimento.
		draw_rect(_span_rect(min(from, to), max(from, to), -_half_thick, -_half_thick * 0.45), Palette.STEEL_DIM)
	# Fughe fra le teste delle sbarre: fisse sul ferro, quindi scorrono
	# verso lo stipite insieme alla loro metà e spariscono dentro al muro.
	var slide: float = _half_long - reach
	var step: float = (_half_long * 2.0) / float(BAR_COUNT)
	for i in range(1, BAR_COUNT):
		var rest: float = -_half_long + step * float(i)
		var pos: float = rest + signf(rest) * slide
		if absf(pos) < _half_long - 1.0:
			draw_line(_point(pos, -_half_thick), _point(pos, _half_thick), Palette.VOID, 2.0)

# Il sigillo: un rombo cremisi al centro della grata, lo stesso segno
# dell'emblema della HUD. Dice "chiuso finché resta qualcuno in piedi", e
# si spegne nell'istante in cui la porta inizia ad aprirsi.
func _draw_seal() -> void:
	var fade: float = 1.0 - clamp(_open_progress * 3.0, 0.0, 1.0)
	if fade <= 0.0:
		return
	var r: float = _half_thick * 1.35
	var diamond := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
	draw_colored_polygon(diamond, Palette.with_alpha(Palette.BLOOD_DEEP, fade))
	var inner := PackedVector2Array([Vector2(0, -r * 0.55), Vector2(r * 0.55, 0), Vector2(0, r * 0.55), Vector2(-r * 0.55, 0)])
	draw_colored_polygon(inner, Palette.with_alpha(Palette.BLOOD, fade))
	draw_circle(Vector2.ZERO, r * 0.2, Palette.with_alpha(Palette.EMBER, fade))

# La soglia vera e propria: una linea di brace che attraversa il varco,
# visibile solo quando la grata ha cominciato ad alzarsi.
func _draw_threshold() -> void:
	var opening: float = _open_progress
	if opening <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(_pulse)
	draw_rect(_span_rect(-_half_long, _half_long, -1.5, 1.5), Palette.with_alpha(Palette.EMBER, opening * (0.55 + 0.35 * pulse)))

# Rettangolo in coordinate locali a partire da un intervallo LUNGO
# l'apertura e uno ATTRAVERSO il suo spessore: cosí lo stesso disegno vale
# per un varco su muro verticale e su muro orizzontale.
func _span_rect(along_from: float, along_to: float, across_from: float, across_to: float) -> Rect2:
	var a := _point(along_from, across_from)
	var b := _point(along_to, across_to)
	return Rect2(Vector2(min(a.x, b.x), min(a.y, b.y)), (b - a).abs())

func _point(along: float, across: float) -> Vector2:
	return Vector2(across, along) if _long_is_y else Vector2(along, across)
