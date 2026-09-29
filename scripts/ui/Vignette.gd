class_name Vignette
extends Control

# Oscuramento ai bordi dello schermo. È l'effetto che più di ogni altro
# dà alla scena l'atmosfera del riferimento: la luce sembra provenire da
# dove si trova il giocatore e spegnersi verso i lati, invece di
# illuminare la stanza in modo piatto e uniforme.
#
# Realizzato con fasce di rettangoli a opacità crescente e non con uno
# shader: il progetto gira in modalità GL Compatibility e l'effetto deve
# funzionare allo stesso modo ovunque, senza dipendere dalla
# compilazione di materiali.
#
# Le fasce dei quattro lati sono disgiunte tra loro ma si sovrappongono
# agli angoli: è proprio lí che l'oscuramento risulta più fitto, come in
# una vignettatura vera.

# Quota del lato coperta dalla sfumatura, opacità massima al bordo
# estremo e numero di gradini: con meno di ~20 fasce si vedrebbero le
# bande, con molte di più non cambia nulla di percepibile.
const DEPTH_RATIO := 0.34
const MAX_ALPHA := 0.78
const BANDS := 24
const EDGE_COLOR := Color(0.016, 0.018, 0.031)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le misure si prendono dal viewport e non dal proprio rettangolo:
	# appeso a un CanvasLayer questo Control può essere disegnato prima
	# che il layout gli abbia assegnato una dimensione, e l'effetto
	# sparirebbe senza che nulla segnali l'errore.
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var w: float = viewport_size.x
	var h: float = viewport_size.y
	if w <= 0.0 or h <= 0.0:
		return
	var depth_x: float = w * DEPTH_RATIO
	var depth_y: float = h * DEPTH_RATIO
	var band_x: float = depth_x / float(BANDS)
	var band_y: float = depth_y / float(BANDS)

	for i in range(BANDS):
		var t: float = float(i) / float(BANDS)
		var alpha: float = MAX_ALPHA * pow(1.0 - t, 2.2)
		var color := Color(EDGE_COLOR.r, EDGE_COLOR.g, EDGE_COLOR.b, alpha)
		draw_rect(Rect2(Vector2(0.0, i * band_y), Vector2(w, band_y)), color)
		draw_rect(Rect2(Vector2(0.0, h - (i + 1) * band_y), Vector2(w, band_y)), color)
		draw_rect(Rect2(Vector2(i * band_x, 0.0), Vector2(band_x, h)), color)
		draw_rect(Rect2(Vector2(w - (i + 1) * band_x, 0.0), Vector2(band_x, h)), color)
