extends Node

var world: Node2D
var current_screen: Node = null

func _ready() -> void:
	InputSetup.ensure_actions()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	if "--smoke-test" in OS.get_cmdline_user_args():
		var tester = load("res://tests/SmokeTest.gd").new()
		add_child(tester)
		tester.run_and_quit()
	else:
		_show_hub()

func _show_hub() -> void:
	# Rete di sicurezza: qualunque cosa abbia lasciato l'albero in pausa
	# (es. si torna all'Hub dal menu di pausa) non deve congelare l'Hub.
	get_tree().paused = false
	_clear_world()
	var hub := Hub.new()
	hub.start_run_requested.connect(_on_start_run_requested)
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
