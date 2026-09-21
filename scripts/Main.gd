extends Node

var world: Node2D
var current_screen: Node = null

func _ready() -> void:
	InputSetup.ensure_actions()
	# Dopo ensure_actions(): le azioni devono esistere nei valori
	# predefiniti perché le assegnazioni salvate possano sostituirle.
	GameSettings.apply_all()
	# Il colore con cui si pulisce lo schermo: lo stesso nero delle
	# stanze, cosí le bande di adattamento del rapporto d'aspetto non
	# spiccano ai lati dell'immagine.
	RenderingServer.set_default_clear_color(Palette.VOID)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	if "--smoke-test" in OS.get_cmdline_user_args():
		var tester = load("res://tests/SmokeTest.gd").new()
		add_child(tester)
		tester.run_and_quit()
	else:
		_show_title()

# La prima cosa che si vede all'avvio: logo, nome del gioco e invito a
# premere un tasto. Si mostra una volta sola, all'accensione: tornando
# all'Hub o cambiando salvataggio non si ripassa di qui.
func _show_title() -> void:
	get_tree().paused = false
	_clear_world()
	var title := TitleScreen.new()
	Palette.apply_theme(title)
	title.start_pressed.connect(_show_slot_select)
	world.add_child(title)
	current_screen = title

# Prima dell'Hub si sceglie su quale dei tre salvataggi giocare: da lí
# in poi ogni progresso registrato finisce in quello slot.
func _show_slot_select() -> void:
	get_tree().paused = false
	_clear_world()
	var slots := SaveSlotScreen.new()
	Palette.apply_theme(slots)
	slots.slot_chosen.connect(func(_slot): _show_hub())
	world.add_child(slots)
	current_screen = slots

func _show_hub() -> void:
	# Rete di sicurezza: qualunque cosa abbia lasciato l'albero in pausa
	# (es. si torna all'Hub dal menu di pausa) non deve congelare l'Hub.
	get_tree().paused = false
	_clear_world()
	var hub := Hub.new()
	# Senza il tema della cripta ogni schermata ripartirebbe da quello
	# predefinito di Godot, grigio e fuori posto.
	Palette.apply_theme(hub)
	hub.start_run_requested.connect(_on_start_run_requested)
	hub.change_slot_requested.connect(_show_slot_select)
	world.add_child(hub)
	current_screen = hub

func _on_start_run_requested() -> void:
	_clear_world()
	var run := Run.new()
	run.return_to_hub_requested.connect(_show_hub)
	world.add_child(run)
	current_screen = run
	run.begin_new_streak()

func _clear_world() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null
