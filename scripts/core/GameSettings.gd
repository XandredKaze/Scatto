class_name GameSettings
extends RefCounted

# Impostazioni di gioco (audio, video, assegnazione dei tasti) applicate
# al motore e salvate nel file di salvataggio via SaveManager.settings.
#
# Come InputSetup, questa classe non viene mai istanziata: è solo un
# contenitore di costanti e funzioni statiche. Le preferenze vivono in
# SaveManager (unico punto di persistenza del progetto), qui c'è solo la
# logica per leggerle, applicarle davvero al motore e riscriverle.
#
# Le assegnazioni dei tasti sostituiscono SOLO gli eventi dello stesso
# tipo: assegnare un tasto della tastiera non tocca il binding del
# controller della stessa azione e viceversa, cosí i due dispositivi
# restano sempre utilizzabili insieme. Gli assi analogici (stick) non
# sono riassegnabili e restano sempre attivi sul movimento.

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

# Esito dell'ultima applicazione della risoluzione: falso quando la
# finestra NON ha davvero assunto la dimensione richiesta. Capita quando il
# gioco non è padrone della propria finestra — tipicamente eseguendolo
# dentro l'editor con l'anteprima incorporata, che la ridimensiona lui.
# In quel caso l'impostazione resta salvata e vale al prossimo avvio del
# gioco da solo: è la schermata Impostazioni a dirlo, invece di lasciar
# credere che la scelta sia stata ignorata.
static var resolution_applied := true

# Azioni riassegnabili dal menu impostazioni, nell'ordine in cui vengono
# mostrate. Le azioni di navigazione dei menu (ui_accept/ui_cancel) sono
# deliberatamente escluse: riassegnarle potrebbe rendere il menu stesso
# inutilizzabile.
const REBINDABLE := [
	{"action": "move_up", "label": "Muovi su"},
	{"action": "move_down", "label": "Muovi giù"},
	{"action": "move_left", "label": "Muovi a sinistra"},
	{"action": "move_right", "label": "Muovi a destra"},
	{"action": "special_attack", "label": "Attacco 1 (scatto)"},
	{"action": "special_attack_2", "label": "Attacco 2 (scatto)"},
	{"action": "tame", "label": "Addomestica"},
	{"action": "pause", "label": "Pausa"},
]

const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A / Croce",
	JOY_BUTTON_B: "B / Cerchio",
	JOY_BUTTON_X: "X / Quadrato",
	JOY_BUTTON_Y: "Y / Triangolo",
	JOY_BUTTON_LEFT_SHOULDER: "L1 / LB",
	JOY_BUTTON_RIGHT_SHOULDER: "R1 / RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "Start / Opzioni",
	JOY_BUTTON_BACK: "Select / Condividi",
	JOY_BUTTON_DPAD_UP: "D-pad su",
	JOY_BUTTON_DPAD_DOWN: "D-pad giù",
	JOY_BUTTON_DPAD_LEFT: "D-pad sinistra",
	JOY_BUTTON_DPAD_RIGHT: "D-pad destra",
}

# --- Applicazione all'avvio -------------------------------------------------

# Richiamata una sola volta da Main._ready(), subito DOPO
# InputSetup.ensure_actions(): le azioni devono già esistere nei loro
# valori predefiniti perché le assegnazioni salvate possano sostituirli.
static func apply_all() -> void:
	apply_volume()
	apply_display()
	apply_bindings()

static func apply_volume() -> void:
	var volume: float = get_volume()
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(volume, 0.0001)))

static func apply_display() -> void:
	# In headless (test automatici, build server) non esiste una finestra
	# da ridimensionare: le chiamate al DisplayServer vanno saltate del
	# tutto, non solo protette dagli errori.
	if DisplayServer.get_name() == "headless":
		return
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		resolution_applied = true
		return
	# L'ordine conta: una finestra massimizzata o a schermo intero ignora
	# le richieste di ridimensionamento, quindi si torna prima in modalità
	# finestra e solo dopo si cambia la dimensione.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var wanted: Vector2i = current_resolution()
	DisplayServer.window_set_size(wanted)
	# Ingrandendo, una finestra ancorata in alto a sinistra finirebbe per
	# metà fuori dallo schermo: si ricentra su quello spazio utilizzabile.
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position + (usable.size - wanted) / 2)
	resolution_applied = DisplayServer.window_get_size() == wanted

static func apply_bindings() -> void:
	var saved: Dictionary = _saved_bindings()
	for entry in REBINDABLE:
		var action: String = entry.action
		if not saved.has(action) or not InputMap.has_action(action):
			continue
		var binding: Dictionary = saved[action]
		if binding.has("key"):
			_replace_keyboard_event(action, int(binding.key))
		if binding.has("joypad"):
			_replace_joypad_event(action, int(binding.joypad))

# --- Audio -------------------------------------------------

static func get_volume() -> float:
	return clamp(float(SaveManager.settings.get("volume", 1.0)), 0.0, 1.0)

static func set_volume(value: float) -> void:
	SaveManager.settings["volume"] = clamp(value, 0.0, 1.0)
	apply_volume()
	SaveManager.save_data()

# --- Video -------------------------------------------------

# Solo le risoluzioni che stanno davvero nello spazio utilizzabile dello
# schermo su cui si trova la finestra. Proporre una finestra più grande
# dello schermo significa chiedere al sistema operativo qualcosa che non
# può concedere: la finestra verrebbe ritagliata o spostata, e la scelta
# sembrerebbe semplicemente "non funzionare".
static func available_resolutions() -> Array:
	if DisplayServer.get_name() == "headless":
		return RESOLUTIONS.duplicate()
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var fitting: Array = []
	for res in RESOLUTIONS:
		if res.x <= usable.x and res.y <= usable.y:
			fitting.append(res)
	# Su uno schermo più piccolo di ogni voce dell'elenco resta comunque
	# la più bassa, altrimenti non ci sarebbe nulla da scegliere.
	return fitting if not fitting.is_empty() else [RESOLUTIONS[0]]

# La risoluzione viene salvata per valore, non come indice: l'elenco delle
# scelte dipende dallo schermo, quindi un indice salvato su un monitor
# grande punterebbe altrove (o a nulla) su uno più piccolo.
static func current_resolution() -> Vector2i:
	var available: Array = available_resolutions()
	var saved := Vector2i(
		int(SaveManager.settings.get("resolution_w", 0)),
		int(SaveManager.settings.get("resolution_h", 0))
	)
	return saved if available.has(saved) else available[0]

static func get_resolution_index() -> int:
	return available_resolutions().find(current_resolution())

static func set_resolution(res: Vector2i) -> void:
	SaveManager.settings["resolution_w"] = res.x
	SaveManager.settings["resolution_h"] = res.y
	apply_display()
	SaveManager.save_data()

static func cycle_resolution() -> void:
	var available: Array = available_resolutions()
	set_resolution(available[(get_resolution_index() + 1) % available.size()])

static func is_fullscreen() -> bool:
	return bool(SaveManager.settings.get("fullscreen", false))

static func set_fullscreen(enabled: bool) -> void:
	SaveManager.settings["fullscreen"] = enabled
	apply_display()
	SaveManager.save_data()

# --- Assegnazione dei tasti -------------------------------------------------

# Assegna all'azione l'evento appena premuto dal giocatore, sostituendo
# solo il binding dello stesso dispositivo. Restituisce false (senza
# cambiare nulla) se l'evento non è di un tipo assegnabile.
static func rebind(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	var saved: Dictionary = _saved_bindings()
	var binding: Dictionary = saved.get(action, {})
	if event is InputEventKey:
		var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if keycode == 0:
			return false
		_replace_keyboard_event(action, keycode)
		binding["key"] = keycode
	elif event is InputEventJoypadButton:
		_replace_joypad_event(action, int(event.button_index))
		binding["joypad"] = int(event.button_index)
	else:
		return false
	saved[action] = binding
	SaveManager.settings["bindings"] = saved
	SaveManager.save_data()
	return true

# Riporta TUTTE le azioni riassegnabili ai binding predefiniti,
# ricostruendole da zero con InputSetup (unica definizione dei valori di
# fabbrica, cosí non esiste una seconda copia da tenere allineata).
static func reset_bindings() -> void:
	SaveManager.settings["bindings"] = {}
	SaveManager.save_data()
	for entry in REBINDABLE:
		if InputMap.has_action(entry.action):
			InputMap.erase_action(entry.action)
	InputSetup.ensure_actions()

# Etichetta leggibile dei binding attuali di un'azione, es.
# "W  •  D-pad su". Legge direttamente dall'InputMap, che è la fonte di
# verità dopo apply_bindings().
static func binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var parts: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			parts.append(OS.get_keycode_string(keycode))
		elif event is InputEventJoypadButton:
			parts.append(JOY_BUTTON_NAMES.get(event.button_index, "Tasto %d" % event.button_index))
	if parts.is_empty():
		return "—"
	return "  •  ".join(parts)

static func _saved_bindings() -> Dictionary:
	var saved = SaveManager.settings.get("bindings", {})
	return saved if typeof(saved) == TYPE_DICTIONARY else {}

static func _replace_keyboard_event(action: String, keycode: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)

static func _replace_joypad_event(action: String, button_index: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var joy := InputEventJoypadButton.new()
	joy.button_index = button_index
	InputMap.action_add_event(action, joy)
