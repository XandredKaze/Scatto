class_name InputSetup
extends RefCounted

# Configura le azioni di input a codice invece che nel project.godot,
# cosí ogni azione è legata sia a tastiera che a controller (stick
# sinistro/D-pad per il movimento) senza dover scrivere a mano il formato
# [input] del progetto. Chiamata una sola volta all'avvio (Main._ready()).
#
# Non esiste un'azione "dash" dedicata: lo scatto è l'attacco base dei due
# pulsanti d'attacco (special_attack su E/R1 e special_attack_2 su Q/L1)
# e li occupa solo finché nessun alleato li ha presi (vedi Player).
#
# Le azioni predefinite di Godot per la navigazione nei menu (ui_up/down/
# left/right) hanno già un binding joypad nativo (stick sinistro e D-pad);
# manca solo il tasto di conferma/annulla, aggiunto qui a ui_accept/ui_cancel
# cosí i pulsanti dell'Hub e della scelta dei potenziamenti sono navigabili
# e selezionabili anche da controller.

static func ensure_actions() -> void:
	_ensure_move_axis("move_left", KEY_A, KEY_LEFT, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
	_ensure_move_axis("move_right", KEY_D, KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
	_ensure_move_axis("move_up", KEY_W, KEY_UP, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
	_ensure_move_axis("move_down", KEY_S, KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
	_ensure_tame()
	_ensure_special_attack()
	_ensure_special_attack_2()
	_ensure_joypad_button_on_action("ui_accept", JOY_BUTTON_A)
	_ensure_joypad_button_on_action("ui_cancel", JOY_BUTTON_B)
	_ensure_pause()

static func _ensure_move_axis(action: String, key1: Key, key2: Key, axis: JoyAxis, axis_value: float, dpad_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)

	var k1 := InputEventKey.new()
	k1.physical_keycode = key1
	InputMap.action_add_event(action, k1)

	var k2 := InputEventKey.new()
	k2.physical_keycode = key2
	InputMap.action_add_event(action, k2)

	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = axis_value
	InputMap.action_add_event(action, motion)

	var dpad := InputEventJoypadButton.new()
	dpad.button_index = dpad_button
	InputMap.action_add_event(action, dpad)

static func _ensure_tame() -> void:
	if InputMap.has_action("tame"):
		return
	InputMap.add_action("tame")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("tame", key)

	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = JOY_BUTTON_X
	InputMap.action_add_event("tame", joy_btn)

static func _ensure_special_attack() -> void:
	if InputMap.has_action("special_attack"):
		return
	InputMap.add_action("special_attack")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event("special_attack", key)

	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("special_attack", joy_btn)

static func _ensure_special_attack_2() -> void:
	if InputMap.has_action("special_attack_2"):
		return
	InputMap.add_action("special_attack_2")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event("special_attack_2", key)

	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("special_attack_2", joy_btn)

static func _ensure_pause() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")

	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", esc)

	var start_btn := InputEventJoypadButton.new()
	start_btn.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", start_btn)

static func _ensure_joypad_button_on_action(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = button
	InputMap.action_add_event(action, joy_btn)
