class_name Hub
extends Control

# Schermata centrale: avvia una nuova run, apre l'archivio dei
# potenziamenti o il bestiario. Le statistiche mostrate provengono
# dal salvataggio persistente (SaveManager).

signal start_run_requested

var archive_panel: ArchiveScreen
var bestiary_panel: BestiaryScreen
var tutorial_panel: TutorialScreen
var settings_panel: SettingsScreen
var stats_label: Label
var start_btn: Button
var tutorial_btn: Button
var archive_btn: Button
var bestiary_btn: Button
var settings_btn: Button
var quit_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = Color8(13, 14, 18)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(490, 92)
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "SCATTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(300, 0)
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Un roguelike a scatto"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(300, 0)
	subtitle.modulate = Color(0.7, 0.7, 0.75)
	vbox.add_child(subtitle)

	# Promemoria dei comandi in alto, sopra le voci del menu: con sei voci
	# in elenco non c'è più spazio per tenerlo in fondo.
	var hint := Label.new()
	hint.text = "WASD/Frecce per muoverti, E e Q (R1/L1) per attaccare"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(300, 0)
	hint.modulate = Color(0.5, 0.5, 0.55)
	vbox.add_child(hint)

	_add_spacer(vbox, 10)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.custom_minimum_size = Vector2(300, 0)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_label.modulate = Color(0.75, 0.75, 0.8)
	vbox.add_child(stats_label)

	_add_spacer(vbox, 10)

	start_btn = Button.new()
	start_btn.text = "Inizia Run"
	start_btn.custom_minimum_size = Vector2(260, 44)
	start_btn.pressed.connect(func(): start_run_requested.emit())
	vbox.add_child(start_btn)

	tutorial_btn = Button.new()
	tutorial_btn.text = "Tutorial"
	tutorial_btn.custom_minimum_size = Vector2(260, 44)
	tutorial_btn.pressed.connect(_open_tutorial)
	vbox.add_child(tutorial_btn)

	archive_btn = Button.new()
	archive_btn.text = "Archivio Potenziamenti"
	archive_btn.custom_minimum_size = Vector2(260, 44)
	archive_btn.pressed.connect(_open_archive)
	vbox.add_child(archive_btn)

	bestiary_btn = Button.new()
	bestiary_btn.text = "Bestiario"
	bestiary_btn.custom_minimum_size = Vector2(260, 44)
	bestiary_btn.pressed.connect(_open_bestiary)
	vbox.add_child(bestiary_btn)

	settings_btn = Button.new()
	settings_btn.text = "Impostazioni"
	settings_btn.custom_minimum_size = Vector2(260, 44)
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)

	quit_btn = Button.new()
	quit_btn.text = "Esci dal gioco"
	quit_btn.custom_minimum_size = Vector2(260, 44)
	quit_btn.pressed.connect(_quit_game)
	vbox.add_child(quit_btn)

	_refresh_stats()
	start_btn.grab_focus()

func _refresh_stats() -> void:
	var s: Dictionary = SaveManager.stats
	stats_label.text = "Run vinte: %d  •  Serie migliore: %d\nMorti: %d  •  Dorati sconfitti: %d" % [
		s.runs_won, s.best_streak, s.deaths, s.golden_defeated
	]

func _add_spacer(container: Control, h: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, h)
	container.add_child(spacer)

func _open_archive() -> void:
	if archive_panel == null:
		archive_panel = ArchiveScreen.new()
		archive_panel.closed.connect(func(): archive_panel.hide(); _set_menu_focusable(true); start_btn.grab_focus())
		add_child(archive_panel)
	archive_panel.refresh()
	archive_panel.show()
	_set_menu_focusable(false)
	archive_panel.close_btn.grab_focus()

func _open_bestiary() -> void:
	if bestiary_panel == null:
		bestiary_panel = BestiaryScreen.new()
		bestiary_panel.closed.connect(func(): bestiary_panel.hide(); _set_menu_focusable(true); start_btn.grab_focus())
		add_child(bestiary_panel)
	bestiary_panel.refresh()
	bestiary_panel.show()
	_set_menu_focusable(false)
	bestiary_panel.close_btn.grab_focus()

func _open_settings() -> void:
	if settings_panel == null:
		settings_panel = SettingsScreen.new()
		settings_panel.closed.connect(func(): settings_panel.hide(); _set_menu_focusable(true); start_btn.grab_focus())
		add_child(settings_panel)
	settings_panel.show()
	_set_menu_focusable(false)
	settings_panel.refresh()
	settings_panel.focus_first_control()

# Chiusura del software richiesta dall'Hub: i progressi (archivio,
# bestiario, statistiche) e le impostazioni sono già su disco a ogni
# cambiamento, quindi non c'è nulla da salvare qui.
func _quit_game() -> void:
	get_tree().quit()

func _open_tutorial() -> void:
	if tutorial_panel == null:
		tutorial_panel = TutorialScreen.new()
		tutorial_panel.closed.connect(func(): tutorial_panel.hide(); _set_menu_focusable(true); start_btn.grab_focus())
		add_child(tutorial_panel)
	tutorial_panel.show()
	_set_menu_focusable(false)
	tutorial_panel.focus_close_button()

# Mentre un pannello (Archivio/Bestiario/Tutorial) è aperto sopra l'Hub,
# i pulsanti dell'Hub restano nell'albero (nascosti solo visivamente
# dallo sfondo opaco del pannello) e quindi continuerebbero a essere
# candidati validi per la risoluzione automatica del focus da
# tastiera/controller: scorrendo verso il basso nel pannello, una volta
# finiti i controlli navigabili al suo interno, il focus "sconfinerebbe"
# sui pulsanti dell'Hub sottostante. Disattivarli temporaneamente evita
# la fuoriuscita.
func _set_menu_focusable(enabled: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	start_btn.focus_mode = mode
	tutorial_btn.focus_mode = mode
	archive_btn.focus_mode = mode
	bestiary_btn.focus_mode = mode
	settings_btn.focus_mode = mode
	quit_btn.focus_mode = mode
