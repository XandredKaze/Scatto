class_name SettingsScreen
extends Control

# Impostazioni raggiungibili dall'Hub: volume, risoluzione/schermo intero
# e riassegnazione dei tasti. I valori vengono applicati subito e salvati
# su disco (GameSettings -> SaveManager), quindi sopravvivono al riavvio.
#
# La navigazione da controller qui NON si affida alla risoluzione
# automatica del focus in base alla posizione a schermo (che in questo
# progetto si è già rivelata imprevedibile): i controlli selezionabili
# sono incatenati a mano in un anello verticale esplicito
# (focus_neighbor_top/bottom + focus_next/previous), cosí su/giù seguono
# sempre l'ordine logico dell'elenco e dall'ultima voce si torna alla
# prima. Sinistra/destra restano libere per il cursore del volume.

signal closed

const ROW_LABEL_WIDTH := 250
const ROW_VALUE_WIDTH := 300
const ROW_HEIGHT := 34

var close_btn: Button
var reset_btn: Button
var volume_slider: HSlider
var volume_value_label: Label
var resolution_btn: Button
var fullscreen_btn: Button
var resolution_warning: Label
# Pulsante di assegnazione per ogni azione riassegnabile, nello stesso
# ordine di GameSettings.REBINDABLE.
var binding_buttons: Array = []
# Azione in attesa del prossimo tasto premuto ("" = nessuna).
var listening_action := ""
var listening_button: Button = null
var _focus_chain: Array = []

func _ready() -> void:
	# Raggiungibile anche dal menu di pausa, cioè a simulazione ferma
	# (get_tree().paused): senza PROCESS_MODE_ALWAYS questa schermata non
	# riceverebbe più input e resterebbe bloccata, senza nemmeno poter
	# essere chiusa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Sfondo opaco a dimensione esplicita: con il solo anchor preset il
	# ridimensionamento non ha ancora effetto nel frame di creazione e lo
	# sfondo resterebbe di dimensione (0, 0), lasciando trasparire l'Hub.
	var bg := ColorRect.new()
	bg.color = Palette.UI_BG
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.position = Vector2(315, 14)
	panel.custom_minimum_size = Vector2(650, 0)
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)

	var title := Label.new()
	title.text = "Impostazioni"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var hint := Label.new()
	hint.text = "Su/giù per spostarti, A/Croce o Invio per confermare. B/Cerchio o Esc per tornare indietro."
	hint.modulate = Palette.BONE_DIM
	panel.add_child(hint)

	panel.add_child(_section_title("Audio"))
	panel.add_child(_build_volume_row())

	panel.add_child(_section_title("Video"))
	resolution_btn = _make_value_button()
	panel.add_child(_value_row("Risoluzione", resolution_btn))
	resolution_btn.pressed.connect(_cycle_resolution)

	fullscreen_btn = _make_value_button()
	panel.add_child(_value_row("Schermo intero", fullscreen_btn))
	fullscreen_btn.pressed.connect(_toggle_fullscreen)

	# Mostrata solo quando la finestra non ha davvero cambiato dimensione
	# (vedi GameSettings.resolution_applied).
	resolution_warning = Label.new()
	resolution_warning.text = "La finestra non si lascia ridimensionare qui (succede eseguendo il gioco dentro l'editor): la scelta resta salvata e varrà avviando il gioco da solo."
	resolution_warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	resolution_warning.custom_minimum_size = Vector2(650, 0)
	resolution_warning.modulate = Palette.GOLD
	resolution_warning.hide()
	panel.add_child(resolution_warning)

	panel.add_child(_section_title("Comandi"))
	var rebind_hint := Label.new()
	rebind_hint.text = "Scegli un comando e premi il tasto (o il pulsante del controller) da assegnargli."
	rebind_hint.modulate = Palette.BONE_DIM
	panel.add_child(rebind_hint)

	for entry in GameSettings.REBINDABLE:
		var btn := _make_value_button()
		btn.pressed.connect(_start_listening.bind(entry.action, btn))
		binding_buttons.append(btn)
		panel.add_child(_value_row(entry.label, btn))

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 12)
	panel.add_child(actions_row)

	reset_btn = Button.new()
	reset_btn.text = "Ripristina comandi"
	reset_btn.custom_minimum_size = Vector2(270, 36)
	reset_btn.pressed.connect(_reset_bindings)
	actions_row.add_child(reset_btn)

	close_btn = Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(270, 36)
	close_btn.pressed.connect(func(): closed.emit())
	actions_row.add_child(close_btn)

	_build_focus_chain()
	refresh()

# --- Costruzione delle righe -------------------------------------------------

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Palette.EMBER
	return label

func _make_value_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(ROW_VALUE_WIDTH, ROW_HEIGHT)
	return btn

func _value_row(label_text: String, value_control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(value_control)
	return row

func _build_volume_row() -> Control:
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(ROW_VALUE_WIDTH - 60, ROW_HEIGHT)
	volume_slider.value_changed.connect(_on_volume_changed)

	volume_value_label = Label.new()
	volume_value_label.custom_minimum_size = Vector2(52, ROW_HEIGHT)
	volume_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	holder.add_child(volume_slider)
	holder.add_child(volume_value_label)
	return _value_row("Volume generale", holder)

# Incatena a mano i controlli selezionabili in un anello verticale, cosí
# su/giù seguono l'ordine dell'elenco invece della geometria a schermo.
func _build_focus_chain() -> void:
	_focus_chain = [volume_slider, resolution_btn, fullscreen_btn]
	_focus_chain.append_array(binding_buttons)
	_focus_chain.append(reset_btn)
	_focus_chain.append(close_btn)

	for i in range(_focus_chain.size()):
		var control: Control = _focus_chain[i]
		var previous: Control = _focus_chain[(i - 1 + _focus_chain.size()) % _focus_chain.size()]
		var next: Control = _focus_chain[(i + 1) % _focus_chain.size()]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_neighbor_top = previous.get_path()
		control.focus_previous = previous.get_path()
		control.focus_neighbor_bottom = next.get_path()
		control.focus_next = next.get_path()

	# Ultima riga a due pulsanti affiancati: sinistra/destra si muovono tra
	# loro, non altrove.
	reset_btn.focus_neighbor_right = close_btn.get_path()
	close_btn.focus_neighbor_left = reset_btn.get_path()

# --- Stato mostrato -------------------------------------------------

# Riallinea tutta la schermata ai valori realmente in vigore. Richiamata
# all'apertura e dopo ogni modifica, cosí l'elenco non può mostrare un
# binding diverso da quello attivo nell'InputMap.
func refresh() -> void:
	volume_slider.set_value_no_signal(GameSettings.get_volume())
	_update_volume_label()
	var res: Vector2i = GameSettings.current_resolution()
	resolution_btn.text = "%d x %d" % [res.x, res.y]
	# Niente da scegliere se lo schermo lascia passare una sola misura, e
	# niente da scegliere a schermo intero.
	resolution_btn.disabled = GameSettings.is_fullscreen() or GameSettings.available_resolutions().size() < 2
	resolution_warning.visible = not GameSettings.is_fullscreen() and not GameSettings.resolution_applied
	fullscreen_btn.text = "Sì" if GameSettings.is_fullscreen() else "No"
	_refresh_binding_labels()

func _refresh_binding_labels() -> void:
	for i in range(GameSettings.REBINDABLE.size()):
		var btn: Button = binding_buttons[i]
		if btn == listening_button:
			continue
		btn.text = GameSettings.binding_label(GameSettings.REBINDABLE[i].action)

func _update_volume_label() -> void:
	volume_value_label.text = "%d%%" % int(round(GameSettings.get_volume() * 100.0))

func focus_first_control() -> void:
	volume_slider.grab_focus()

# --- Azioni -------------------------------------------------

func _on_volume_changed(value: float) -> void:
	GameSettings.set_volume(value)
	_update_volume_label()

func _cycle_resolution() -> void:
	GameSettings.cycle_resolution()
	refresh()

func _toggle_fullscreen() -> void:
	GameSettings.set_fullscreen(not GameSettings.is_fullscreen())
	refresh()

func _reset_bindings() -> void:
	GameSettings.reset_bindings()
	refresh()

func _start_listening(action: String, btn: Button) -> void:
	listening_action = action
	listening_button = btn
	btn.text = "Premi un tasto…"

func _stop_listening() -> void:
	var btn: Button = listening_button
	listening_action = ""
	listening_button = null
	refresh()
	if btn != null:
		btn.grab_focus()

# Durante l'attesa di un tasto gli eventi vengono intercettati qui, prima
# che chiunque altro li veda (_input precede _unhandled_input e il
# sistema di focus): cosí premere "A" per assegnarlo non fa anche
# scattare il pulsante selezionato, e Esc/B annullano l'assegnazione
# invece di chiudere la schermata.
#
# Vengono considerate solo le pressioni (pressed == true): il rilascio
# del tasto con cui si è confermato l'ingresso in ascolto arriva quando
# l'ascolto è già attivo e non deve essere scambiato per l'assegnazione.
func _input(event: InputEvent) -> void:
	if not visible or listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if keycode != KEY_ESCAPE:
			GameSettings.rebind(listening_action, event)
		_stop_listening()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index != JOY_BUTTON_B:
			GameSettings.rebind(listening_action, event)
		_stop_listening()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible and listening_action == "" and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
