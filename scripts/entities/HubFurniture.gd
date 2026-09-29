class_name HubFurniture
extends Node2D

# Un mobile della stanza dell'Hub, disegnato in vista dall'alto di tre
# quarti come la cassa virtuale: il piano superiore in alto, la faccia
# frontale sotto. `footprint` è l'ingombro a terra in coordinate del mondo
# (il rettangolo che blocca il passo e da cui si misura la distanza per
# interagire); il disegno può salire oltre, verso il muro.
#
# - COMPUTER: tavolo con computer (Bestiario, Archivio, Tutorial).
# - ARCADE: cabinato da sala giochi (avvia la run).
# - BED: letto (Impostazioni, Cambia salvataggio, Esci).
# - VENDING: macchinetta degli snack (work in progress).

const COMPUTER := "computer"
const ARCADE := "arcade"
const BED := "letto"
const VENDING := "macchinetta"

const NAMES := {
	COMPUTER: "Computer",
	ARCADE: "Cabinato arcade",
	BED: "Letto",
	VENDING: "Macchinetta degli snack",
}

var kind: String = COMPUTER
var footprint := Rect2()
var _t := 0.0

func setup(p_kind: String, p_footprint: Rect2) -> void:
	kind = p_kind
	footprint = p_footprint
	position = Vector2.ZERO

func display_name() -> String:
	return NAMES.get(kind, kind)

# Distanza dal punto al bordo dell'ingombro (0 se ci sta sopra).
func distance_to(point: Vector2) -> float:
	var closest := Vector2(clamp(point.x, footprint.position.x, footprint.end.x), clamp(point.y, footprint.position.y, footprint.end.y))
	return point.distance_to(closest)

# Punto sopra il mobile a cui si aggancia il messaggio "Interagisci".
func prompt_anchor() -> Vector2:
	return Vector2(footprint.get_center().x, footprint.position.y - _height() - 12.0)

func _height() -> float:
	match kind:
		ARCADE:
			return 96.0
		VENDING:
			return 104.0
		COMPUTER:
			return 76.0
	return 0.0

func _process(delta: float) -> void:
	_t = fmod(_t + delta, TAU * 20.0)
	queue_redraw()

func _draw() -> void:
	var f := footprint
	# Ombra a terra: appoggia il mobile sul pavimento invece di farlo
	# galleggiare sulle lastre.
	var shadow_size: Vector2 = f.size if kind != COMPUTER else Vector2(f.size.x, 60)
	draw_rect(Rect2(f.position + Vector2(6, 8), shadow_size), Palette.SHADOW)
	match kind:
		COMPUTER:
			_draw_computer(f)
		ARCADE:
			_draw_arcade(f)
		BED:
			_draw_bed(f)
		VENDING:
			_draw_vending(f)

func _outlined(rect: Rect2, fill: Color, edge: Color = Palette.STONE_EDGE) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, 1.5)

# Tavolo scuro con monitor acceso, tastiera e una sedia davanti.
func _draw_computer(f: Rect2) -> void:
	# L'ingombro comprende la sedia: il tavolo ne occupa i primi 60 px.
	var desk := Rect2(f.position, Vector2(f.size.x, 60))
	var top := Rect2(desk.position + Vector2(0, -26), Vector2(desk.size.x, 30))
	var front := Rect2(Vector2(desk.position.x, top.end.y), Vector2(desk.size.x, desk.size.y - 4))
	_outlined(front, Palette.STONE)
	_outlined(top, Palette.STONE_LIT)
	# Gambe
	draw_rect(Rect2(front.position + Vector2(8, front.size.y - 6), Vector2(10, 10)), Palette.JOINT)
	draw_rect(Rect2(Vector2(front.end.x - 18, front.end.y - 4), Vector2(10, 10)), Palette.JOINT)
	# Monitor: il bagliore del neon è ciò che lo fa riconoscere da lontano.
	var mon := Rect2(Vector2(f.get_center().x - 44, top.position.y - 50), Vector2(88, 56))
	for i in range(4):
		draw_rect(mon.grow(10.0 - i * 2.5), Palette.with_alpha(Palette.NEON, 0.03 + 0.02 * i))
	_outlined(mon, Palette.VOID, Palette.STEEL_DIM)
	var screen := mon.grow(-5)
	draw_rect(screen, Palette.with_alpha(Palette.NEON_DIM, 0.55))
	# Righe di testo che scorrono sullo schermo.
	for i in range(5):
		var w: float = screen.size.x * (0.35 + 0.5 * abs(sin(i * 1.7 + floor(_t * 2.0))))
		draw_rect(Rect2(screen.position + Vector2(5, 5 + i * 8), Vector2(w - 10, 3)), Palette.with_alpha(Palette.NEON, 0.8))
	draw_rect(Rect2(Vector2(mon.get_center().x - 5, mon.end.y), Vector2(10, 8)), Palette.STEEL_DIM)
	# Tastiera
	var kb := Rect2(Vector2(f.get_center().x - 34, top.position.y + 12), Vector2(68, 12))
	_outlined(kb, Palette.STONE_DEEP, Palette.STEEL_DIM)
	for i in range(6):
		draw_rect(Rect2(kb.position + Vector2(4 + i * 10.5, 3), Vector2(7, 6)), Palette.STEEL_DIM)
	# Sedia davanti al tavolo.
	var chair := Rect2(Vector2(f.get_center().x - 20, desk.end.y + 8), Vector2(40, 30))
	_outlined(chair, Palette.BLOOD_DEEP, Palette.BLOOD)
	draw_rect(Rect2(chair.position + Vector2(0, chair.size.y - 8), Vector2(chair.size.x, 8)), Palette.BLOOD)

# Cabinato arcade: mobile alto e stretto, insegna in cima, schermo che
# pulsa, joystick e pulsanti sul pannello comandi.
func _draw_arcade(f: Rect2) -> void:
	var h: float = _height()
	var body := Rect2(Vector2(f.position.x, f.position.y - h), Vector2(f.size.x, f.size.y + h))
	for i in range(4):
		draw_rect(body.grow(12.0 - i * 3.0), Palette.with_alpha(Palette.EMBER, 0.025 + 0.015 * i))
	_outlined(body, Palette.STONE_DEEP, Palette.BLOOD)
	# Fianchi decorati.
	draw_rect(Rect2(body.position, Vector2(6, body.size.y)), Palette.BLOOD)
	draw_rect(Rect2(Vector2(body.end.x - 6, body.position.y), Vector2(6, body.size.y)), Palette.BLOOD)
	# Insegna luminosa.
	var marquee := Rect2(body.position + Vector2(8, 6), Vector2(body.size.x - 16, 20))
	var pulse: float = 0.7 + 0.3 * sin(_t * 3.0)
	draw_rect(marquee, Palette.with_alpha(Palette.EMBER, pulse))
	var font := ThemeDB.fallback_font
	draw_string(font, marquee.position + Vector2(0, 15), "A.M.I.C.", HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x, 13, Palette.VOID)
	# Schermo: una piccola scena di gioco che si muove.
	var screen := Rect2(body.position + Vector2(12, 32), Vector2(body.size.x - 24, 48))
	_outlined(screen, Palette.VOID, Palette.STEEL_DIM)
	var dot := screen.position + Vector2(screen.size.x * (0.5 + 0.35 * sin(_t * 1.8)), screen.size.y * (0.5 + 0.3 * cos(_t * 2.4)))
	draw_circle(dot, 4.0, Palette.BLOOD_BRIGHT)
	draw_circle(screen.get_center() + Vector2(-18, 10), 3.0, Palette.NEON)
	draw_circle(screen.get_center() + Vector2(16, -8), 3.0, Palette.POLLEN)
	# Pannello comandi.
	var panel := Rect2(Vector2(body.position.x + 4, screen.end.y + 8), Vector2(body.size.x - 8, 22))
	_outlined(panel, Palette.STONE_LIT)
	draw_line(panel.position + Vector2(18, 16), panel.position + Vector2(18, 5), Palette.STEEL, 2.0)
	draw_circle(panel.position + Vector2(18, 5), 4.0, Palette.BLOOD_BRIGHT)
	for i in range(3):
		draw_circle(panel.position + Vector2(40 + i * 12, 11), 4.0, [Palette.NEON, Palette.POLLEN, Palette.EMBER][i])
	# Feritoia per i gettoni.
	draw_rect(Rect2(Vector2(body.get_center().x - 6, panel.end.y + 14), Vector2(12, 4)), Palette.GOLD)

# Letto contro la parete: testiera scura, cuscino pallido e coperta cremisi.
func _draw_bed(f: Rect2) -> void:
	_outlined(f, Palette.STONE)
	var headboard := Rect2(f.position + Vector2(-4, -14), Vector2(f.size.x + 8, 20))
	_outlined(headboard, Palette.STONE_LIT)
	var mattress := f.grow(-6)
	draw_rect(mattress, Palette.BONE_DIM)
	var pillow := Rect2(mattress.position + Vector2(10, 8), Vector2(mattress.size.x - 20, 30))
	draw_rect(pillow, Palette.BONE)
	draw_rect(pillow, Palette.BONE_DIM, false, 1.0)
	var blanket := Rect2(Vector2(mattress.position.x, pillow.end.y + 14), Vector2(mattress.size.x, mattress.end.y - pillow.end.y - 14))
	draw_rect(blanket, Palette.BLOOD)
	draw_rect(Rect2(blanket.position, Vector2(blanket.size.x, 10)), Palette.BLOOD_BRIGHT)
	# Pieghe della coperta.
	for i in range(3):
		var y: float = blanket.position.y + 30 + i * 36
		if y < blanket.end.y - 6:
			draw_line(Vector2(blanket.position.x + 8, y), Vector2(blanket.end.x - 8, y + 6), Palette.BLOOD_DEEP, 2.0)

# Macchinetta degli snack: vetrina con file di merendine colorate,
# tastierino e feritoia per le monete, insegna al neon.
func _draw_vending(f: Rect2) -> void:
	var h: float = _height()
	var body := Rect2(Vector2(f.position.x, f.position.y - h), Vector2(f.size.x, f.size.y + h))
	for i in range(4):
		draw_rect(body.grow(12.0 - i * 3.0), Palette.with_alpha(Palette.NEON, 0.025 + 0.015 * i))
	_outlined(body, Palette.STONE_LIT, Palette.NEON_DIM)
	var sign := Rect2(body.position + Vector2(8, 6), Vector2(body.size.x - 16, 18))
	var flicker: float = 0.55 + 0.45 * (1.0 if fmod(_t, 3.1) > 0.15 else 0.2)
	draw_rect(sign, Palette.with_alpha(Palette.NEON, flicker))
	draw_string(ThemeDB.fallback_font, sign.position + Vector2(0, 14), "SNACK", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 13, Palette.VOID)
	var glass := Rect2(body.position + Vector2(8, 30), Vector2(body.size.x - 40, body.size.y - 60))
	draw_rect(glass, Palette.with_alpha(Palette.VOID, 0.9))
	var colors := [Palette.BLOOD_BRIGHT, Palette.GOLD, Palette.NEON, Palette.POLLEN, Palette.EMBER, Palette.STEEL]
	var rows := 4
	var cols := 3
	var cell := Vector2(glass.size.x / cols, glass.size.y / rows)
	for r in range(rows):
		for c in range(cols):
			var col: Color = colors[(r * cols + c) % colors.size()]
			var item := Rect2(glass.position + Vector2(c * cell.x + 4, r * cell.y + 4), Vector2(cell.x - 8, cell.y - 12))
			draw_rect(item, col)
			draw_line(glass.position + Vector2(c * cell.x + 2, (r + 1) * cell.y - 4), glass.position + Vector2((c + 1) * cell.x - 2, (r + 1) * cell.y - 4), Palette.STEEL_DIM, 1.5)
	draw_rect(glass, Palette.with_alpha(Palette.BONE, 0.06))
	draw_line(glass.position + Vector2(6, 4), glass.position + Vector2(18, glass.size.y * 0.4), Palette.with_alpha(Palette.BONE, 0.25), 2.0)
	# Tastierino e feritoia a destra della vetrina.
	var pad := Rect2(Vector2(glass.end.x + 6, glass.position.y + 6), Vector2(20, 34))
	_outlined(pad, Palette.STONE_DEEP, Palette.STEEL_DIM)
	for i in range(3):
		for j in range(2):
			draw_rect(Rect2(pad.position + Vector2(3 + j * 8, 4 + i * 10), Vector2(5, 6)), Palette.STEEL)
	draw_rect(Rect2(Vector2(pad.position.x + 5, pad.end.y + 10), Vector2(10, 3)), Palette.GOLD)
	# Vano di ritiro in basso.
	draw_rect(Rect2(Vector2(body.position.x + 12, glass.end.y + 8), Vector2(body.size.x - 44, 14)), Palette.VOID)
