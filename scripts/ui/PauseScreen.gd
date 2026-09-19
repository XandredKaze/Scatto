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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()

	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 255)
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

	var retry_btn := Button.new()
	retry_btn.text = "Riprova la run dall'inizio"
	retry_btn.custom_minimum_size = Vector2(280, 48)
	retry_btn.pressed.connect(func():
		_close()
		retry_pressed.emit()
	)
	vbox.add_child(retry_btn)

	var hub_btn := Button.new()
	hub_btn.text = "Torna all'Hub"
	hub_btn.custom_minimum_size = Vector2(280, 48)
	hub_btn.pressed.connect(func():
		_close()
		hub_pressed.emit()
	)
	vbox.add_child(hub_btn)

func _process(_delta: float) -> void:
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
