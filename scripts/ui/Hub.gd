class_name Hub
extends Control

# L'Hub non è piú un menu ma una stanza: scelto il salvataggio, il
# giocatore ci cammina dentro e interagisce con i mobili avvicinandosi e
# premendo "Interagisci" (E sulla tastiera, A/Croce sul controller).
#
# - Computer sul tavolo: Bestiario, Archivio potenziamenti, Tutorial.
# - Cabinato arcade: avvia la run.
# - Letto: Impostazioni, Cambia salvataggio, Esci dal gioco.
# - Macchinetta degli snack: per ora solo "Work in progress".
#
# Vicino a un mobile compare, in dissolvenza, "Interagisci con [tasto]",
# col tasto della periferica che il giocatore sta usando in quel momento
# (l'ultima da cui è arrivato un input).

signal start_run_requested
# Torna alla scelta del salvataggio. Senza questa via d'uscita, scelto
# uno slot lo si potrebbe cambiare solo riavviando il gioco.
signal change_slot_requested

const ROOM_SIZE := Vector2(1280, 720)
const WALL := 48.0
const PLAYER_SPAWN := Vector2(640, 520)
# Distanza massima (dal bordo del mobile) per poterci interagire.
const INTERACT_RANGE := 64.0
const PROMPT_FADE_SPEED := 6.0
const WIP_DURATION := 2.2
const INTERACT_ACTION := "interact"
# Sottofondo della stanza. Il brano è importato con il loop attivo e con
# loop_offset a 22 s (assets/audio/hub.mp3.import): l'introduzione si
# sente una volta sola entrando, poi riparte da lí. Il lettore è figlio
# dell'Hub, quindi avviando una run (Hub liberato) la musica si ferma da
# sola e lascia il posto a quella della run.
const MUSIC_PATH := "res://assets/audio/hub.mp3"
const MUSIC_VOLUME_DB := Run.MUSIC_VOLUME_DB

# Ingombro a terra di ogni mobile: stanno contro le pareti, cosí il centro
# della stanza resta libero per camminare.
const LAYOUT := {
	# Il tavolo con la sedia davanti: la sedia fa parte dell'ingombro, cosí
	# ci si ferma davanti a lei e non ci si passa sopra.
	HubFurniture.COMPUTER: Rect2(150, 130, 200, 100),
	HubFurniture.ARCADE: Rect2(596, 150, 88, 44),
	HubFurniture.VENDING: Rect2(1010, 160, 120, 44),
	HubFurniture.BED: Rect2(90, 440, 150, 210),
}

var room: Node2D
var arena: ArenaVisual
var player: Player
var furniture: Array = []
var furniture_by_kind := {}
var prompts := {}
var nearby: HubFurniture = null
var using_joypad := false
var joypad_device := 0

var computer_menu: PanelContainer
var bed_menu: PanelContainer
var open_menu: PanelContainer = null
# "Work in progress" della macchinetta: per qualche secondo prende il posto
# di "Interagisci con…" nel suo messaggio.
var wip_timer := 0.0
var stats_label: Label
var music_player: AudioStreamPlayer

var archive_panel: ArchiveScreen
var bestiary_panel: BestiaryScreen
var tutorial_panel: TutorialScreen
var settings_panel: SettingsScreen
var tutorial_btn: Button
var archive_btn: Button
var bestiary_btn: Button
var settings_btn: Button
var slot_btn: Button
var quit_btn: Button

# Dopo aver aperto o chiuso un menu si aspetta che il tasto venga
# rilasciato: A è sia "Interagisci" sia la conferma dei menu, e senza
# questa attesa la stessa pressione aprirebbe il menu e premerebbe subito
# la sua prima voce (o, chiudendolo, riaprirebbe il mobile).
var _interact_locked := false
var _focus_pending: Control = null
# Frame in cui si è chiuso un pannello: lo stesso B/Esc che lo ha chiuso
# non deve chiudere anche il menu sotto.
var _panel_closed_frame := -10

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = ROOM_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	room = Node2D.new()
	add_child(room)
	arena = ArenaVisual.new()
	arena.wall_margin = WALL
	room.add_child(arena)
	arena.arena_size = ROOM_SIZE

	for kind in [HubFurniture.COMPUTER, HubFurniture.ARCADE, HubFurniture.VENDING, HubFurniture.BED]:
		var piece := HubFurniture.new()
		piece.setup(kind, LAYOUT[kind])
		room.add_child(piece)
		furniture.append(piece)
		furniture_by_kind[kind] = piece

	player = Player.new()
	player.attacks_enabled = false
	room.add_child(player)
	player.arena_bounds = Rect2(Vector2(WALL, WALL), ROOM_SIZE - Vector2(WALL, WALL) * 2.0)
	player.obstacles = furniture.map(func(f): return f.footprint)
	player.global_position = PLAYER_SPAWN
	# La stanza è grande quanto lo schermo: niente telecamera che segua il
	# giocatore, cosí mondo e schermo coincidono (e i messaggi sopra i
	# mobili si posizionano con le stesse coordinate).
	if player.camera != null:
		player.camera.enabled = false

	_build_overlay_labels()
	for piece in furniture:
		prompts[piece.kind] = _build_prompt(piece)

	computer_menu = _build_menu("Computer", [
		["Bestiario", _open_bestiary],
		["Archivio potenziamenti", _open_archive],
		["Tutorial", _open_tutorial],
	])
	bestiary_btn = computer_menu.get_meta("buttons")[0]
	archive_btn = computer_menu.get_meta("buttons")[1]
	tutorial_btn = computer_menu.get_meta("buttons")[2]

	bed_menu = _build_menu("Letto", [
		["Impostazioni", _open_settings],
		["Cambia salvataggio", func(): change_slot_requested.emit()],
		["Esci dal gioco", _quit_game],
	])
	settings_btn = bed_menu.get_meta("buttons")[0]
	slot_btn = bed_menu.get_meta("buttons")[1]
	quit_btn = bed_menu.get_meta("buttons")[2]

	music_player = AudioStreamPlayer.new()
	music_player.stream = load(MUSIC_PATH)
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)
	music_player.play()

	_refresh_stats()

# --- Interfaccia sopra la stanza ---------------------------------------------

func _build_overlay_labels() -> void:
	var title := Label.new()
	title.text = "A.M.I.C."
	title.position = Vector2(WALL + 8, 8)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.EMBER)
	add_child(title)

	stats_label = Label.new()
	stats_label.position = Vector2(WALL, ROOM_SIZE.y - WALL + 10)
	stats_label.size = Vector2(ROOM_SIZE.x - WALL * 2.0, 28)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.modulate = Palette.BONE_DIM
	add_child(stats_label)

# Messaggio sopra un mobile: il nome e "Interagisci con [tasto]". Parte
# trasparente e si accende/spegne in dissolvenza (_update_prompts).
func _build_prompt(piece: HubFurniture) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)

	var name_label := Label.new()
	name_label.text = piece.display_name()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.modulate = Palette.BONE_DIM
	box.add_child(name_label)

	var action_label := Label.new()
	action_label.name = "Action"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 17)
	action_label.add_theme_color_override("font_color", Palette.EMBER)
	box.add_child(action_label)
	return box

func interact_text() -> String:
	return "Interagisci con %s" % GameSettings.action_key_label(INTERACT_ACTION, using_joypad, joypad_device)

func _build_menu(title_text: String, entries: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.hide()
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Palette.EMBER)
	col.add_child(title)

	var buttons: Array = []
	for entry in entries:
		var btn := Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(300, 44)
		btn.pressed.connect(entry[1])
		col.add_child(btn)
		buttons.append(btn)

	var close := Button.new()
	close.text = "Chiudi"
	close.custom_minimum_size = Vector2(300, 40)
	close.pressed.connect(_close_menu)
	col.add_child(close)
	buttons.append(close)

	# Su/giù seguono l'ordine delle voci e dall'ultima si torna alla prima.
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		var prev: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next: Button = buttons[(i + 1) % buttons.size()]
		b.focus_neighbor_top = prev.get_path()
		b.focus_neighbor_bottom = next.get_path()
		b.focus_previous = prev.get_path()
		b.focus_next = next.get_path()

	panel.set_meta("buttons", buttons)
	return panel

func _layout_menu(panel: PanelContainer) -> void:
	panel.reset_size()
	panel.position = (ROOM_SIZE - panel.size) * 0.5

func _refresh_stats() -> void:
	var s: Dictionary = SaveManager.stats
	stats_label.text = "Slot %d  •  Run vinte: %d  •  Serie migliore: %d  •  Morti: %d  •  Dorati sconfitti: %d  •  Gettoni: %d" % [
		SaveManager.current_slot, s.runs_won, s.best_streak, s.deaths, s.golden_defeated, SaveManager.tokens()
	]

# --- Input e interazione -----------------------------------------------------

# Tiene traccia dell'ultima periferica usata, per scrivere il tasto giusto
# nel messaggio. Non consuma l'evento.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		using_joypad = true
		joypad_device = event.device
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		using_joypad = true
		joypad_device = event.device
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		using_joypad = false

func _process(delta: float) -> void:
	var panel_open := is_panel_open()
	player.frozen = open_menu != null or panel_open

	if _interact_locked and not Input.is_action_pressed(INTERACT_ACTION) and not Input.is_action_pressed("ui_accept"):
		_interact_locked = false
		if _focus_pending != null and is_instance_valid(_focus_pending) and _focus_pending.is_visible_in_tree():
			_focus_pending.grab_focus()
		_focus_pending = null

	nearby = null
	if open_menu == null and not panel_open:
		nearby = nearest_furniture()
	_update_prompts(delta)

	if wip_timer > 0.0:
		wip_timer -= delta

	if nearby != null and not _interact_locked and Input.is_action_just_pressed(INTERACT_ACTION):
		interact_with(nearby)
	elif open_menu != null and not panel_open and Input.is_action_just_pressed("ui_cancel") and Engine.get_process_frames() - _panel_closed_frame > 1:
		_close_menu()

func nearest_furniture() -> HubFurniture:
	var best: HubFurniture = null
	var best_d := INTERACT_RANGE
	for piece in furniture:
		var d: float = piece.distance_to(player.global_position)
		if d <= best_d:
			best_d = d
			best = piece
	return best

func _update_prompts(delta: float) -> void:
	var text := interact_text()
	for piece in furniture:
		var box: VBoxContainer = prompts[piece.kind]
		var action_label: Label = box.get_node("Action")
		var showing_wip: bool = piece.kind == HubFurniture.VENDING and wip_timer > 0.0
		action_label.text = "Work in progress" if showing_wip else text
		action_label.add_theme_color_override("font_color", Palette.NEON if showing_wip else Palette.EMBER)
		var target: float = 1.0 if piece == nearby or showing_wip else 0.0
		box.modulate.a = move_toward(box.modulate.a, target, PROMPT_FADE_SPEED * delta)
		box.visible = box.modulate.a > 0.0
		box.reset_size()
		# Dentro lo schermo anche per i mobili addossati alla parete di fondo.
		var pos: Vector2 = piece.prompt_anchor() - Vector2(box.size.x * 0.5, box.size.y)
		box.position = Vector2(clamp(pos.x, 4.0, ROOM_SIZE.x - box.size.x - 4.0), max(pos.y, 2.0))

func interact_with(piece: HubFurniture) -> void:
	match piece.kind:
		HubFurniture.COMPUTER:
			_open_menu(computer_menu)
		HubFurniture.BED:
			_open_menu(bed_menu)
		HubFurniture.ARCADE:
			start_run_requested.emit()
		HubFurniture.VENDING:
			_show_wip(piece)

func _show_wip(_piece: HubFurniture) -> void:
	wip_timer = WIP_DURATION

func wip_visible() -> bool:
	return wip_timer > 0.0

func _open_menu(menu: PanelContainer) -> void:
	open_menu = menu
	menu.show()
	_layout_menu(menu)
	_set_menu_focusable(menu, true)
	player.freeze()
	_interact_locked = true
	_focus_pending = menu.get_meta("buttons")[0]

func _close_menu() -> void:
	if open_menu == null:
		return
	open_menu.hide()
	open_menu = null
	_focus_pending = null
	_interact_locked = true
	get_viewport().gui_release_focus()

func is_panel_open() -> bool:
	for panel in [archive_panel, bestiary_panel, tutorial_panel, settings_panel]:
		if panel != null and panel.visible:
			return true
	return false

# --- Pannelli (Bestiario, Archivio, Tutorial, Impostazioni) -------------------

# Chiuso un pannello si torna al menu da cui lo si era aperto, con il
# focus sulla voce che l'aveva aperto.
func _on_panel_closed(panel: Control, return_button: Button) -> void:
	panel.hide()
	_panel_closed_frame = Engine.get_process_frames()
	if open_menu != null:
		_set_menu_focusable(open_menu, true)
		if return_button != null and return_button.is_visible_in_tree():
			return_button.grab_focus()

func _open_archive() -> void:
	if archive_panel == null:
		archive_panel = ArchiveScreen.new()
		archive_panel.closed.connect(func(): _on_panel_closed(archive_panel, archive_btn))
		add_child(archive_panel)
	archive_panel.refresh()
	archive_panel.show()
	_menus_unfocusable()
	archive_panel.close_btn.grab_focus()

func _open_bestiary() -> void:
	if bestiary_panel == null:
		bestiary_panel = BestiaryScreen.new()
		bestiary_panel.closed.connect(func(): _on_panel_closed(bestiary_panel, bestiary_btn))
		add_child(bestiary_panel)
	bestiary_panel.refresh()
	bestiary_panel.show()
	_menus_unfocusable()
	bestiary_panel.close_btn.grab_focus()

func _open_tutorial() -> void:
	if tutorial_panel == null:
		tutorial_panel = TutorialScreen.new()
		tutorial_panel.closed.connect(func(): _on_panel_closed(tutorial_panel, tutorial_btn))
		add_child(tutorial_panel)
	tutorial_panel.show()
	_menus_unfocusable()
	tutorial_panel.focus_close_button()

func _open_settings() -> void:
	if settings_panel == null:
		settings_panel = SettingsScreen.new()
		settings_panel.closed.connect(func(): _on_panel_closed(settings_panel, settings_btn))
		add_child(settings_panel)
	settings_panel.show()
	_menus_unfocusable()
	settings_panel.refresh()
	settings_panel.focus_first_control()

# Chiusura del software richiesta dal letto: i progressi (archivio,
# bestiario, statistiche) e le impostazioni sono già su disco a ogni
# cambiamento, quindi non c'è nulla da salvare qui.
func _quit_game() -> void:
	get_tree().quit()

# Mentre un pannello è aperto sopra un menu, le voci del menu restano
# nell'albero (coperte solo dallo sfondo opaco del pannello) e quindi
# sarebbero ancora candidate per il focus da tastiera/controller:
# scorrendo nel pannello il focus "sconfinerebbe" sul menu sotto.
# Disattivarle evita la fuoriuscita.
func _menus_unfocusable() -> void:
	_set_menu_focusable(computer_menu, false)
	_set_menu_focusable(bed_menu, false)

func _set_menu_focusable(menu: PanelContainer, enabled: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for b in menu.get_meta("buttons"):
		b.focus_mode = mode
