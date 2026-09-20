class_name PauseScreen
extends Control

# Menu di pausa raggiungibile durante una run con Esc o il tasto Start/
# Opzioni del controller. Ferma la simulazione di gioco (get_tree().paused)
# ma resta interattivo grazie a PROCESS_MODE_ALWAYS: senza questo, una
# volta in pausa nessun nodo (compreso questo menu) riceverebbe più input,
# e non si potrebbe più uscire dalla pausa.
#
# Offre le tre azioni richieste: riprendere la run esattamente da dove
# era stata messa in pausa, riprovarla dall'inizio (stessa run, stato del
# giocatore riportato a come era all'inizio di QUESTA run) oppure
# abbandonarla e tornare all'Hub.

signal hub_pressed
signal retry_pressed

var run: Node = null
var resume_btn: Button
var retry_btn: Button
var hub_btn: Button
var settings_btn: Button
var settings_panel: SettingsScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()

	var bg := ColorRect.new()
	bg.color = Palette.UI_BG
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(490, 220)
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(300, 0)
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	resume_btn = Button.new()
	resume_btn.text = "Riprendi"
	resume_btn.custom_minimum_size = Vector2(280, 48)
	resume_btn.pressed.connect(_close)
	vbox.add_child(resume_btn)

	retry_btn = Button.new()
	retry_btn.text = "Riprova la run dall'inizio"
	retry_btn.custom_minimum_size = Vector2(280, 48)
	retry_btn.pressed.connect(func():
		_close()
		retry_pressed.emit()
	)
	vbox.add_child(retry_btn)

	settings_btn = Button.new()
	settings_btn.text = "Impostazioni"
	settings_btn.custom_minimum_size = Vector2(280, 48)
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)

	hub_btn = Button.new()
	hub_btn.text = "Torna all'Hub"
	hub_btn.custom_minimum_size = Vector2(280, 48)
	hub_btn.pressed.connect(func():
		_close()
		hub_pressed.emit()
	)
	vbox.add_child(hub_btn)

# Le stesse Impostazioni dell'Hub, aperte sopra il menu di pausa. Mentre
# sono aperte i pulsanti della pausa non devono restare selezionabili,
# altrimenti il focus da controller potrebbe sconfinare sul menu coperto.
func _open_settings() -> void:
	if settings_panel == null:
		settings_panel = SettingsScreen.new()
		settings_panel.closed.connect(_close_settings)
		add_child(settings_panel)
	settings_panel.show()
	_set_menu_focusable(false)
	settings_panel.refresh()
	settings_panel.focus_first_control()

func _close_settings() -> void:
	settings_panel.hide()
	_set_menu_focusable(true)
	resume_btn.grab_focus()

func _set_menu_focusable(enabled: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	resume_btn.focus_mode = mode
	retry_btn.focus_mode = mode
	settings_btn.focus_mode = mode
	hub_btn.focus_mode = mode

func _process(_delta: float) -> void:
	# Con le Impostazioni aperte sopra la pausa, Esc/Start servono a
	# chiuderle (se ne occupa la schermata stessa) e non devono anche
	# togliere la pausa. Vale anche mentre si sta riassegnando un tasto:
	# lí Esc annulla l'assegnazione.
	if settings_panel != null and settings_panel.visible:
		return
	if Input.is_action_just_pressed("pause"):
		if visible:
			_close()
		else:
			_open()

func _open() -> void:
	# Non aprire la pausa sopra un altro overlay modale già attivo
	# (scelta potenziamento, fine run, game over).
	if run != null and (run.powerup_choice_screen.visible or run.run_complete_screen.visible or run.game_over_screen.visible):
		return
	get_tree().paused = true
	show()
	resume_btn.grab_focus()

func _close() -> void:
	get_tree().paused = false
	hide()
