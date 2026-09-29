class_name TitleScreen
extends Control

# Schermata del titolo, la prima cosa che si vede all'avvio: il logo, il
# nome del gioco e l'invito a premere un tasto qualsiasi. Da qui si passa
# alla scelta del salvataggio.
#
# "Un tasto qualsiasi" va preso alla lettera: tastiera, controller o
# mouse. L'evento viene consumato e il passaggio alla schermata
# successiva è differito, altrimenti la stessa pressione che fa partire
# la demo arriverebbe anche al pulsante che nel frattempo ha preso il
# fuoco, e si salterebbe un passaggio senza volerlo.

signal start_pressed

const LOGO_PATH := "res://assets/images/amic_logo.png"
const BLINK_SPEED := 3.0

var logo: TextureRect
var title_label: Label
var prompt_label: Label
var _started := false
var _elapsed := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = Palette.UI_BG
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	logo = TextureRect.new()
	logo.texture = load(LOGO_PATH)
	logo.custom_minimum_size = Vector2(0, 420)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(logo)

	title_label = Label.new()
	title_label.text = "A.M.I.C."
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Palette.BONE)
	vbox.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 34)
	vbox.add_child(spacer)

	prompt_label = Label.new()
	prompt_label.text = "Premi un tasto per iniziare la demo"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Palette.EMBER)
	vbox.add_child(prompt_label)

func _process(delta: float) -> void:
	if _started:
		return
	# Lampeggio dell'invito: è il segnale che la schermata sta aspettando
	# qualcosa da te, e non che il gioco si è piantato sul logo.
	_elapsed += delta
	prompt_label.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_elapsed * BLINK_SPEED))

func _unhandled_input(event: InputEvent) -> void:
	if _started or not _is_start_event(event):
		return
	_started = true
	prompt_label.modulate.a = 1.0
	get_viewport().set_input_as_handled()
	call_deferred("_emit_start")

func _is_start_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false

func _emit_start() -> void:
	start_pressed.emit()
