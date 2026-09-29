class_name Pickup
extends Node2D

# Oggetto a terra al centro di una sala: si raccoglie passandoci sopra.
# Chi decide cosa succede alla raccolta è Run (_check_pickups): qui c'è
# solo che cos'è, dove sta e come si disegna.
#
# - POTION: pozione di cura, si beve subito (cura una parte della vita
#   mancante). A vita piena resta a terra, per non sprecarla.
# - TOKEN: gettone, finisce nel salvataggio e si accumula fra le run.
# - KEY: chiave virtuale, si accumula; ognuna apre una sola cassa.
# - CHEST: cassa del potenziamento virtuale. Non si raccoglie: toccandola
#   con almeno una chiave si apre, consuma la chiave e dona un
#   potenziamento a caso. Aperta resta lí, spenta.

const POTION := "pozione"
const TOKEN := "gettone"
const KEY := "chiave"
const CHEST := "cassa"
# Ordine in cui gli oggetti di una stessa sala si dispongono attorno al
# centro, e ordine delle icone nella HUD.
const KINDS := [POTION, KEY, TOKEN, CHEST]

const NAMES := {
	POTION: "Pozione di cura",
	TOKEN: "Gettone",
	KEY: "Chiave virtuale",
	CHEST: "Cassa del potenziamento virtuale",
}

# Distanza dal centro del giocatore entro cui l'oggetto si raccoglie.
const PICKUP_RADIUS := 22.0
const CHEST_RADIUS := 32.0
# Scala del disegno a terra: un po' piú grande dell'icona della HUD, cosí
# gli oggetti si notano accanto al giocatore.
const WORLD_SCALE := 1.3

var kind: String = POTION
var opened := false
# Solo per la cassa: vero dopo aver avvisato che serve una chiave, finché
# il giocatore non si allontana (cosí l'avviso non si ripete a ogni frame).
var warned := false
var _t := 0.0

func setup(p_kind: String) -> void:
	kind = p_kind
	_t = randf() * TAU

func touch_radius() -> float:
	return CHEST_RADIUS if kind == CHEST else PICKUP_RADIUS

func open_chest() -> void:
	opened = true
	queue_redraw()

func _process(delta: float) -> void:
	_t = fmod(_t + delta, TAU * 10.0)
	queue_redraw()

func _draw() -> void:
	draw_art(self, kind, Vector2.ZERO, WORLD_SCALE, _t, opened)

# Disegna l'oggetto su `canvas` (da chiamare dentro il suo _draw): lo usa
# sia l'oggetto a terra sia la HUD per le proprie icone, cosí restano
# identici.
static func draw_art(canvas: CanvasItem, p_kind: String, at: Vector2, s: float, t: float, is_open := false) -> void:
	var bob: float = sin(t * 2.2) * 2.5 * s if p_kind != CHEST else 0.0
	var c: Vector2 = at + Vector2(0.0, bob)
	if s >= 1.0:
		# Ombra a terra e alone: gli oggetti devono spiccare sul pavimento
		# scuro anche nella penombra ai bordi dello schermo.
		canvas.draw_set_transform(at + Vector2(0.0, 14.0 * s), 0.0, Vector2(1.0, 0.35))
		canvas.draw_circle(Vector2.ZERO, 14.0 * s, Palette.SHADOW)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var glow: Color = _glow_color(p_kind, is_open)
		for i in range(5):
			canvas.draw_circle(c, (30.0 - i * 5.0) * s, Palette.with_alpha(glow, 0.035 + 0.02 * i))
	match p_kind:
		POTION:
			_draw_potion(canvas, c, s, t)
		TOKEN:
			_draw_token(canvas, c, s, t)
		KEY:
			_draw_key(canvas, c, s, t)
		CHEST:
			_draw_chest(canvas, at, s, t, is_open)

static func _glow_color(p_kind: String, is_open: bool) -> Color:
	match p_kind:
		POTION:
			return Palette.BLOOD_BRIGHT
		TOKEN:
			return Palette.GOLD
		CHEST:
			return Palette.NEON_DIM if is_open else Palette.NEON
	return Palette.NEON

# Fiala di vetro dal collo stretto, piena di cremisi vivo.
static func _draw_potion(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var body_r: float = 9.0 * s
	var body_c: Vector2 = c + Vector2(0.0, 3.0 * s)
	canvas.draw_circle(body_c, body_r + 1.5 * s, Palette.STEEL_DIM)
	canvas.draw_circle(body_c, body_r, Palette.BLOOD_DEEP)
	# Il liquido riempie la parte bassa della fiala e ondeggia appena.
	var level: float = body_c.y - body_r * (0.15 + 0.08 * sin(t * 3.0))
	var liquid := PackedVector2Array()
	for i in range(17):
		var a: float = PI * float(i) / 16.0
		liquid.append(body_c + Vector2(cos(a), sin(a)) * body_r)
	liquid.append(Vector2(body_c.x - body_r, level))
	liquid.append(Vector2(body_c.x + body_r, level))
	canvas.draw_colored_polygon(liquid, Palette.BLOOD_BRIGHT)
	var neck := Rect2(c + Vector2(-3.5, -11.0) * s, Vector2(7.0, 7.0) * s)
	canvas.draw_rect(neck, Palette.STEEL_DIM)
	canvas.draw_rect(Rect2(c + Vector2(-4.5, -14.0) * s, Vector2(9.0, 4.0) * s), Palette.CHITIN_AMBER)
	# Riflesso sul vetro.
	canvas.draw_circle(body_c + Vector2(-3.5, -3.5) * s, 2.0 * s, Palette.with_alpha(Palette.BONE, 0.8))

# Moneta d'oro vista di tre quarti: gira su se stessa restringendosi.
static func _draw_token(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var squash: float = 0.35 + 0.65 * abs(cos(t * 1.6))
	var r: float = 9.0 * s
	canvas.draw_set_transform(c, 0.0, Vector2(squash, 1.0))
	canvas.draw_circle(Vector2.ZERO, r + 1.5 * s, Palette.CHITIN_AMBER)
	canvas.draw_circle(Vector2.ZERO, r, Palette.GOLD)
	canvas.draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 20, Palette.CHITIN_AMBER, max(1.0, 1.5 * s))
	# Sigillo a rombo al centro, lo stesso della HUD.
	var d: float = r * 0.32
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]), Palette.CHITIN_AMBER)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_circle(c + Vector2(-3.0 * squash, -3.5) * s, 1.6 * s, Palette.with_alpha(Palette.BONE, 0.85))

# Tessera magnetica: scheda scura con banda e chip al neon.
static func _draw_key(canvas: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var size := Vector2(22.0, 14.0) * s
	var rect := Rect2(c - size * 0.5, size)
	canvas.draw_rect(rect.grow(1.5 * s), Palette.NEON_DIM)
	canvas.draw_rect(rect, Palette.STONE_DEEP)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, 2.5 * s), Vector2(size.x, 3.0 * s)), Palette.NEON_DIM)
	var chip := Rect2(rect.position + Vector2(3.0, 7.0) * s, Vector2(6.0, 4.5) * s)
	canvas.draw_rect(chip, Palette.NEON)
	# Tacche del circuito e una spia che lampeggia.
	for i in range(3):
		canvas.draw_rect(Rect2(rect.position + Vector2(11.0 + i * 3.0, 8.5) * s, Vector2(1.5, 3.0) * s), Palette.NEON_DIM)
	var blink: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 5.0))
	canvas.draw_circle(rect.position + Vector2(size.x - 3.5 * s, 4.0 * s), 1.6 * s, Palette.with_alpha(Palette.NEON, blink))

# Cassa cibernetica: blocco d'acciaio scuro solcato da linee al neon, con
# la serratura rossa finché è sigillata. Aperta, il coperchio si solleva
# e le luci si spengono.
static func _draw_chest(canvas: CanvasItem, at: Vector2, s: float, t: float, is_open: bool) -> void:
	var w: float = 34.0 * s
	var h: float = 22.0 * s
	var body := Rect2(at + Vector2(-w * 0.5, -h * 0.35), Vector2(w, h))
	var line_col: Color = Palette.NEON_DIM if is_open else Palette.NEON
	var pulse: float = 1.0 if is_open else 0.7 + 0.3 * sin(t * 2.6)
	canvas.draw_rect(body.grow(1.5 * s), Palette.STEEL_DIM)
	canvas.draw_rect(body, Palette.STONE)
	# Linee del circuito sul fianco.
	canvas.draw_line(body.position + Vector2(3.0 * s, h * 0.55), body.position + Vector2(w * 0.35, h * 0.55), Palette.with_alpha(line_col, pulse), max(1.0, 1.5 * s))
	canvas.draw_line(body.position + Vector2(w * 0.65, h * 0.55), body.position + Vector2(w - 3.0 * s, h * 0.55), Palette.with_alpha(line_col, pulse), max(1.0, 1.5 * s))
	canvas.draw_line(body.position + Vector2(w * 0.2, h * 0.55), body.position + Vector2(w * 0.2, h - 3.0 * s), Palette.with_alpha(line_col, pulse * 0.8), max(1.0, 1.0 * s))
	canvas.draw_line(body.position + Vector2(w * 0.8, h * 0.55), body.position + Vector2(w * 0.8, h - 3.0 * s), Palette.with_alpha(line_col, pulse * 0.8), max(1.0, 1.0 * s))
	# Coperchio: chiuso aderisce al corpo, aperto è sollevato e inclinato.
	var lid_h: float = 8.0 * s
	var lid_pos: Vector2 = body.position + Vector2(0.0, -lid_h)
	if is_open:
		lid_pos += Vector2(0.0, -6.0 * s)
	var lid := Rect2(lid_pos, Vector2(w, lid_h))
	canvas.draw_rect(lid.grow(1.5 * s), Palette.STEEL_DIM)
	canvas.draw_rect(lid, Palette.STONE_LIT)
	canvas.draw_line(lid.position + Vector2(3.0 * s, lid_h * 0.5), lid.position + Vector2(w - 3.0 * s, lid_h * 0.5), Palette.with_alpha(line_col, pulse), max(1.0, 1.5 * s))
	if is_open:
		# Dentro, il bagliore ormai spento di ciò che conteneva.
		canvas.draw_rect(Rect2(body.position + Vector2(3.0 * s, -5.0 * s), Vector2(w - 6.0 * s, 5.0 * s)), Palette.with_alpha(Palette.NEON_DIM, 0.6))
	# Serratura al centro: rossa da sigillata, azzurra da aperta.
	var lock_c: Vector2 = body.position + Vector2(w * 0.5, h * 0.55)
	canvas.draw_rect(Rect2(lock_c - Vector2(5.0, 5.0) * s, Vector2(10.0, 10.0) * s), Palette.VOID)
	canvas.draw_circle(lock_c, 3.0 * s, Palette.NEON if is_open else Palette.with_alpha(Palette.BLOOD_BRIGHT, pulse))
