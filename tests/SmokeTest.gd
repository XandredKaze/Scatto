extends Node

# Test di fumo eseguibile in headless, tramite il normale avvio del
# progetto (cosí gli autoload come SaveManager sono disponibili):
#   godot --headless --path . -- --smoke-test
#
# Verifica: generazione stanze, nemico dorato forzato, progressione
# 5 stanze + boss, scelta potenziamenti, la serie di 3 run consecutive
# senza Hub che rende speciale il terzo Custode, e la persistenza in
# SaveManager (archivio potenziamenti + bestiario + statistiche).

var run: Run

func run_and_quit() -> void:
	print("=== SCATTO SMOKE TEST ===")

	await _test_gamepad_input()
	await _test_controller_menu_navigation()
	_test_maze_grid()
	await _test_maze_integration()
	await _test_maze_dash_no_tunneling()
	await _test_maze_enemy_closes_final_gap()
	await _test_all_boss_moves()
	await _test_boss_signals_wired_in_run()
	await _test_real_dash_collision()
	await _test_boss_attack_patterns()
	await _test_tutorial_screen_has_no_spoilers()
	await _test_hud_debug_golden_button()
	await _test_direction_indicator()
	await _test_pause_menu()

	SaveManager.reset_all()

	run = Run.new()
	add_child(run)
	run.debug_force_golden = true
	run.begin_new_streak()

	var enemy_count: int = run.enemy_container.get_child_count()
	print("Stanza 1 - nemici generati: ", enemy_count)
	_assert(enemy_count > 0, "nessun nemico generato nella stanza 1")

	var has_golden := false
	for e in run.enemy_container.get_children():
		if e.is_golden:
			has_golden = true
	print("Nemico dorato forzato presente: ", has_golden)
	_assert(has_golden, "il nemico dorato forzato non è comparso nella stanza 1")

	_clear_five_rooms_to_boss()

	print("--- Test icone potenziamenti attivi in HUD (solo durante la run) ---")
	# 5 scelte di fine stanza + 1 bottino garantito dal nemico dorato forzato.
	_assert(run.player.active_powerups.size() == 6, "attesi 6 potenziamenti raccolti, trovati %d" % run.player.active_powerups.size())
	# La HUD aggiorna il vassoio in _process(): servono alcuni frame reali
	# (non chiamate sincrone) perché il motore lo esegua davvero. Si
	# attende con un margine generoso per non essere fragili a
	# variazioni di timing in headless.
	for i in range(20):
		if run.hud.powerup_tray.get_child_count() == 2:
			break
		await get_tree().process_frame
	_assert(run.hud.powerup_tray.get_child_count() == 2, "attese 2 icone distinte in HUD (bottino dorato + potenziamento ripetuto), trovate %d" % run.hud.powerup_tray.get_child_count())
	print("Potenziamenti attivi mostrati in HUD: ", run.hud.powerup_tray.get_child_count())

	_assert(run.room_number == 6, "numero stanza atteso 6, trovato %d" % run.room_number)
	_assert(run.current_boss != null, "il boss non è stato generato")
	_assert(not run.current_boss.is_special, "il boss della run 1 non dovrebbe essere speciale")
	print("Run 1: boss normale confermato (", run.current_boss.display_name, ")")
	var normal_boss_id := _defeat_current_boss()
	_assert(run.run_complete_screen.visible, "schermata di fine run non mostrata")
	_assert(run.streak_run_index == 1, "streak_run_index atteso 1, trovato %d" % run.streak_run_index)

	# Regressione: il boss sconfitto non deve restare a schermo (nodo
	# non rimosso) quando si continua senza tornare all'Hub.
	await get_tree().process_frame
	_assert(run.boss_container.get_child_count() == 0, "il boss sconfitto è rimasto nella scena dopo la vittoria")

	run._on_continue_pressed()
	_assert(run.boss_container.get_child_count() == 0, "il boss sconfitto è ancora presente dopo aver iniziato la nuova run")
	_assert(run.streak_run_index == 2, "streak_run_index atteso 2, trovato %d" % run.streak_run_index)
	_clear_five_rooms_to_boss()
	_assert(not run.current_boss.is_special, "il boss della run 2 non dovrebbe essere speciale")
	print("Run 2: boss normale confermato")
	_defeat_current_boss()

	run._on_continue_pressed()
	_assert(run.streak_run_index == 3, "streak_run_index atteso 3, trovato %d" % run.streak_run_index)
	_clear_five_rooms_to_boss()
	_assert(run.current_boss.is_special, "il boss della run 3 DOVREBBE essere speciale")
	print("Run 3: boss SPECIALE confermato (", run.current_boss.display_name, ")")
	var special_boss_id := _defeat_current_boss()
	var special_boss_drop: String = GameData.BOSSES[special_boss_id].guaranteed_drop

	# Sconfiggere un boss speciale deve concludere la partita: resta solo
	# "Torna all'Hub", "Continua" deve sparire.
	_assert(not run.run_complete_screen.continue_btn.visible, "'Continua' non dovrebbe essere disponibile dopo un boss speciale")
	_assert(run.run_complete_screen.hub_btn.visible, "'Torna all'Hub' dovrebbe restare disponibile dopo un boss speciale")
	_assert(run.run_complete_screen.hub_btn.has_focus(), "'Torna all'Hub' dovrebbe avere il focus dopo un boss speciale")

	print("Statistiche finali: ", SaveManager.stats)
	_assert(SaveManager.stats.runs_won == 3, "attese 3 run vinte, trovate %d" % SaveManager.stats.runs_won)
	_assert(SaveManager.stats.special_boss_defeated == 1, "atteso 1 boss speciale sconfitto")
	_assert(SaveManager.stats.golden_defeated == 1, "atteso 1 nemico dorato sconfitto")
	_assert(SaveManager.is_powerup_unlocked("cuore_dorato"), "potenziamento leggendario del dorato non sbloccato")
	_assert(SaveManager.is_powerup_unlocked(special_boss_drop), "potenziamento leggendario del boss speciale (%s) non sbloccato" % special_boss_drop)
	_assert(SaveManager.is_enemy_unlocked("strisciante_dorato"), "variante dorata non sbloccata nel bestiario")
	_assert(SaveManager.is_enemy_unlocked(special_boss_id), "boss speciale (%s) non sbloccato nel bestiario" % special_boss_id)
	_assert(SaveManager.is_enemy_unlocked(normal_boss_id), "boss normale (%s) non sbloccato nel bestiario" % normal_boss_id)

	run._on_hub_pressed()

	print("--- Test sconfitta del giocatore e reset della serie ---")
	run = Run.new()
	add_child(run)
	run.begin_new_streak()
	run.streak_run_index = 2
	run.player.hp = 1.0
	run.player.take_damage(999.0)
	_assert(not run.player.alive, "il giocatore dovrebbe risultare morto")
	_assert(run.game_over_screen.visible, "schermata di game over non mostrata")
	_assert(run.streak_run_index == 0, "la serie dovrebbe azzerarsi dopo la sconfitta")
	print("Sconfitta e reset della serie: OK")

	print("--- Test apertura Archivio e Bestiario (sfondo opaco) ---")
	var archive := ArchiveScreen.new()
	add_child(archive)
	archive.refresh()
	_assert(archive.list_box.get_child_count() == GameData.POWERUPS.size(), "l'archivio non elenca tutti i potenziamenti")
	archive.queue_free()

	var bestiary := BestiaryScreen.new()
	add_child(bestiary)
	bestiary.refresh()
	_assert(bestiary.list_box.get_child_count() > 0, "il bestiario non elenca alcuna voce")
	bestiary.queue_free()
	await get_tree().physics_frame
	print("Archivio e Bestiario: costruiti e popolati senza errori")

	print("=== TUTTI I CONTROLLI SUPERATI ===")
	get_tree().quit()

func _test_tutorial_screen_has_no_spoilers() -> void:
	print("--- Test Tutorial (nessuna anticipazione su boss/dorato) ---")
	var tutorial := TutorialScreen.new()
	add_child(tutorial)

	var texts: Array = []
	_collect_label_texts(tutorial, texts)
	_assert(texts.size() > 0, "il tutorial non contiene alcun testo")

	var forbidden := ["custode", "corrotto", "dorat", "boss", "colosso", "spettro"]
	for text in texts:
		var lowered: String = String(text).to_lower()
		for word in forbidden:
			_assert(not lowered.contains(word), "il tutorial rivela '%s' nel testo: %s" % [word, text])

	print("Tutorial: %d etichette, nessuna anticipazione su boss/dorato" % texts.size())
	tutorial.queue_free()
	await get_tree().process_frame

func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node.text)
	for child in node.get_children():
		_collect_label_texts(child, out)

func _test_direction_indicator() -> void:
	print("--- Test indicatore di direzione verso il portale ---")
	var indicator_run := Run.new()
	add_child(indicator_run)
	indicator_run.begin_new_streak()
	await get_tree().process_frame

	_assert(not indicator_run.hud.direction_indicator.visible, "l'indicatore non dovrebbe essere visibile prima che la stanza sia ripulita")

	# Ripulisce la stanza: il portale si attiva ma il giocatore resta
	# lontano dallo spawn, quindi quasi certamente fuori schermo.
	_kill_all_room_enemies_of(indicator_run)
	_assert(indicator_run.room_cleared, "setup del test: la stanza dovrebbe risultare ripulita")
	await get_tree().process_frame

	_assert(indicator_run.hud.direction_indicator.visible, "l'indicatore dovrebbe comparire quando il portale è attivo e fuori schermo")

	var player_pos: Vector2 = indicator_run.player.global_position
	var expected_angle: float = (indicator_run.exit_position - player_pos).angle()
	var angle_diff: float = abs(wrapf(indicator_run.hud.direction_indicator.rotation - expected_angle, -PI, PI))
	_assert(angle_diff < 0.01, "l'indicatore non punta nella direzione corretta (differenza %.3f rad)" % angle_diff)

	# Se il giocatore è già dove si trova il portale, l'indicatore deve
	# nascondersi: il portale è per forza a schermo.
	indicator_run.player.global_position = indicator_run.exit_position
	await get_tree().process_frame
	_assert(not indicator_run.hud.direction_indicator.visible, "l'indicatore non dovrebbe essere visibile quando il portale è già a schermo")

	# Attraversando il portale la stanza avanza e il portale si disattiva:
	# l'indicatore deve sparire di nuovo.
	indicator_run._physics_process(0.016)
	await get_tree().process_frame
	_assert(not indicator_run.hud.direction_indicator.visible, "l'indicatore dovrebbe sparire una volta attraversato il portale")

	print("Indicatore di direzione: OK")
	indicator_run.queue_free()
	await get_tree().process_frame

func _test_hud_debug_golden_button() -> void:
	print("--- Test pulsante debug 'Forza nemico dorato' in HUD ---")
	var r := Run.new()
	add_child(r)

	# Verifica negativa: senza debug_mode il pulsante non deve esistere.
	var normal_button := _find_button_with_text(r.hud, "Forza nemico dorato")
	_assert(normal_button == null, "il pulsante di debug è presente anche senza modalità debug")

	# Forza debug_mode e ricrea una HUD isolata per verificare il pulsante,
	# indipendentemente dagli argomenti con cui è stato avviato il processo.
	r.debug_mode = true
	var debug_hud := HUD.new()
	debug_hud.run = r
	add_child(debug_hud)

	var found_button := _find_button_with_text(debug_hud, "Forza nemico dorato")
	_assert(found_button != null, "il pulsante di debug 'Forza nemico dorato' non è presente con debug_mode attivo")
	_assert(not r.debug_force_golden, "debug_force_golden dovrebbe partire disattivato")
	found_button.pressed.emit()
	_assert(r.debug_force_golden, "il pulsante di debug non ha impostato debug_force_golden")
	print("Pulsante debug 'Forza nemico dorato': OK")

	debug_hud.queue_free()
	r.queue_free()
	await get_tree().process_frame

func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and String(node.text).contains(text):
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null

func _test_pause_menu() -> void:
	print("--- Test menu di pausa (riprendi / riprova / torna all'Hub) ---")
	_assert(_action_has_joypad_button("pause", JOY_BUTTON_START), "l'azione pause non ha un binding per il tasto Start del controller")

	var pause_run := Run.new()
	add_child(pause_run)
	pause_run.begin_new_streak()

	_assert(not get_tree().paused, "il gioco non dovrebbe partire in pausa")
	_assert(not pause_run.pause_screen.visible, "il menu di pausa non dovrebbe essere visibile all'avvio")

	# Apertura: Esc (azione "pause") deve mettere in pausa e mostrare il menu.
	await _tap_key(KEY_ESCAPE)
	_assert(get_tree().paused, "Esc non ha messo in pausa il gioco")
	_assert(pause_run.pause_screen.visible, "Esc non ha mostrato il menu di pausa")
	_assert(pause_run.pause_screen.resume_btn.has_focus(), "'Riprendi' non ha il focus quando si apre la pausa")

	# Chiusura con lo stesso tasto: deve riprendere.
	await _tap_key(KEY_ESCAPE)
	_assert(not get_tree().paused, "Esc non ha tolto la pausa")
	_assert(not pause_run.pause_screen.visible, "Esc non ha nascosto il menu di pausa")

	# Non deve aprirsi sopra un altro overlay modale già attivo.
	pause_run.powerup_choice_screen.show()
	await _tap_key(KEY_ESCAPE)
	_assert(not get_tree().paused, "la pausa non dovrebbe aprirsi sopra la scelta del potenziamento")
	pause_run.powerup_choice_screen.hide()

	# "Torna all'Hub": deve togliere la pausa ed emettere return_to_hub_requested.
	# Un Array (tipo per riferimento) invece di un bool: i lambda di
	# GDScript catturano le variabili locali per valore, quindi una
	# riassegnazione diretta dentro al lambda non sarebbe visibile qui.
	pause_run.pause_screen._open()
	_assert(get_tree().paused, "setup del test: la pausa dovrebbe essere attiva prima di premere 'Torna all'Hub'")
	var went_to_hub := [false]
	pause_run.return_to_hub_requested.connect(func(): went_to_hub[0] = true)
	pause_run.pause_screen.hub_pressed.emit()
	_assert(not get_tree().paused, "'Torna all'Hub' dal menu di pausa non ha tolto la pausa")
	_assert(went_to_hub[0], "'Torna all'Hub' dal menu di pausa non ha emesso return_to_hub_requested")

	pause_run.queue_free()
	await get_tree().process_frame

	# "Riprova la run dall'inizio": ripristina lo stato del giocatore a
	# come era all'inizio di questa run e riparte dalla stanza 1.
	var retry_run := Run.new()
	add_child(retry_run)
	retry_run.begin_new_streak()
	_assert(retry_run.player.dash_damage_bonus == 0.0, "setup del test: il danno da scatto dovrebbe partire da 0")

	_kill_all_room_enemies_of(retry_run)
	retry_run.player.global_position = retry_run.exit_position
	retry_run._physics_process(0.016)
	retry_run._on_powerup_selected("lama_rapida")
	_assert(retry_run.room_number == 2, "setup del test: dopo la scelta si dovrebbe essere alla stanza 2")
	_assert(retry_run.player.dash_damage_bonus == 6.0, "setup del test: 'Lama Rapida' dovrebbe dare +6 danno da scatto")

	retry_run.pause_screen.retry_pressed.emit()
	_assert(retry_run.room_number == 1, "'Riprova la run dall'inizio' non ha riportato alla stanza 1")
	_assert(retry_run.player.dash_damage_bonus == 0.0, "'Riprova la run dall'inizio' non ha ripristinato le statistiche del giocatore")
	_assert(retry_run.player.active_powerups.is_empty(), "'Riprova la run dall'inizio' non ha svuotato i potenziamenti attivi")

	print("Menu di pausa: OK")
	retry_run.queue_free()
	await get_tree().process_frame

func _kill_all_room_enemies_of(target_run: Run) -> void:
	for e in target_run.enemy_container.get_children():
		if e.alive:
			e.take_damage(99999.0)
			target_run._on_enemy_defeated(e)

func _tap_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	# parse_input_event accoda l'evento al prossimo ciclo del motore:
	# un paio di frame reali bastano perché PauseScreen._process() lo
	# veda come "appena premuto" (comportamento già osservato per le
	# altre azioni testate in questo file).
	await get_tree().process_frame
	await get_tree().process_frame

	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _test_controller_menu_navigation() -> void:
	print("--- Test navigazione menu da controller (Hub + scelta potenziamenti) ---")

	# La traduzione "pulsante a fuoco + ui_accept -> click" è gestita
	# internamente da BaseButton (Godot stesso, non codice di questo
	# progetto) e in headless la pipeline GUI di eventi sintetici non è
	# affidabile da simulare end-to-end; qui verifichiamo quindi le due
	# cose che dipendono dal nostro codice: che i binding joypad per
	# conferma/annulla esistano e che il focus iniziale sia impostato
	# correttamente su ciascun menu, cosí che un pad abbia sempre da
	# dove partire per navigare.
	_assert(_action_has_joypad_button("ui_accept", JOY_BUTTON_A), "ui_accept non ha un binding per il tasto A del controller")
	_assert(_action_has_joypad_button("ui_cancel", JOY_BUTTON_B), "ui_cancel non ha un binding per il tasto B del controller")

	var hub := Hub.new()
	add_child(hub)
	await get_tree().process_frame
	_assert(hub.start_btn.has_focus(), "'Inizia Run' non ha il focus iniziale nell'Hub")
	hub.queue_free()
	await get_tree().process_frame

	var choice_screen := PowerupChoiceScreen.new()
	add_child(choice_screen)
	choice_screen.show()
	var choices: Array = GameData.get_regular_powerup_pool().slice(0, 3)
	choice_screen.show_choices(choices, 1)
	await get_tree().process_frame

	var first_card_button: Button = choice_screen.cards_box.get_child(0).get_meta("pick_button")
	_assert(first_card_button.has_focus(), "il primo potenziamento non ha il focus dopo show_choices()")

	print("Navigazione menu da controller: OK (binding e focus iniziale verificati)")
	choice_screen.queue_free()
	await get_tree().process_frame

func _action_has_joypad_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _test_gamepad_input() -> void:
	print("--- Test input da controller (eventi joypad simulati) ---")
	_assert(InputMap.has_action("move_right"), "l'azione move_right non è stata registrata")
	_assert(InputMap.has_action("dash"), "l'azione dash non è stata registrata")

	var p := Player.new()
	p.arena_bounds = Rect2(Vector2(48, 48), Vector2(1184, 624))
	add_child(p)
	var start_pos: Vector2 = p.global_position

	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)

	for i in range(6):
		await get_tree().physics_frame

	print("Posizione dopo stick a destra: ", p.global_position, " (partenza: ", start_pos, ")")
	_assert(p.global_position.x > start_pos.x, "lo stick analogico del controller non ha mosso il giocatore")

	var stick_release := InputEventJoypadMotion.new()
	stick_release.device = 0
	stick_release.axis = JOY_AXIS_LEFT_X
	stick_release.axis_value = 0.0
	Input.parse_input_event(stick_release)

	var btn := InputEventJoypadButton.new()
	btn.device = 0
	btn.button_index = JOY_BUTTON_A
	btn.pressed = true
	Input.parse_input_event(btn)
	# parse_input_event accoda l'evento al prossimo ciclo di input del
	# motore: servono un paio di frame reali prima che Player lo veda
	# come "appena premuto" nel proprio _physics_process. Si attende con
	# un margine generoso per non essere fragili a variazioni di timing.
	for i in range(10):
		if p.is_dashing:
			break
		await get_tree().physics_frame
	_assert(p.is_dashing, "il tasto A del controller non ha attivato lo scatto")
	print("Input da controller (stick + tasto A): OK")

	var btn_release := InputEventJoypadButton.new()
	btn_release.device = 0
	btn_release.button_index = JOY_BUTTON_A
	btn_release.pressed = false
	Input.parse_input_event(btn_release)

	p.queue_free()
	await get_tree().physics_frame

func _test_boss_attack_patterns() -> void:
	print("--- Test pattern d'attacco del boss speciale (fisica reale, ~6s) ---")
	var container := Node2D.new()
	add_child(container)

	var boss := Boss.new()
	boss.arena_bounds = Rect2(Vector2(48, 48), Vector2(864, 444))
	boss.setup_from_data(GameData.BOSSES["custode_corrotto"])
	boss.global_position = Vector2(480, 200)
	boss.spawn_projectile.connect(func(pos, dir, speed, dmg):
		var proj := EnemyProjectile.new()
		proj.arena_bounds = boss.arena_bounds
		proj.setup(pos, dir, speed, dmg)
		container.add_child(proj)
	)
	container.add_child(boss)

	var p := Player.new()
	p.arena_bounds = boss.arena_bounds
	p.global_position = Vector2(480, 450)
	container.add_child(p)

	var modes_seen := {}
	for i in range(360):
		await get_tree().physics_frame
		modes_seen[boss.mode] = true

	print("Modalità osservate nel boss: ", modes_seen.keys())
	print("Proiettili ancora attivi a fine test: ", container.get_children().filter(func(c): return c is EnemyProjectile).size())
	_assert(boss.alive, "il boss non dovrebbe morire da solo durante il test")
	_assert(modes_seen.has("chase"), "il boss dovrebbe passare per lo stato chase")
	_assert(modes_seen.has("telegraph"), "il boss dovrebbe passare per lo stato telegraph")
	print("Pattern d'attacco del boss: OK (nessun errore in %d frame)" % 360)

	container.queue_free()
	await get_tree().physics_frame

func _test_maze_grid() -> void:
	print("--- Test MazeGrid (generazione, collisione, pathfinding) ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var maze := MazeGrid.new()
	maze.generate(7, 6, 160.0, rng)

	_assert(maze.wall_rects.size() > 0, "il labirinto non ha generato pareti")

	# Connettività: ogni cella deve essere raggiungibile da (0,0) via BFS
	# sulle sole connessioni aperte (nessuna isola scollegata).
	var reached := {Vector2i(0, 0): true}
	var queue: Array = [Vector2i(0, 0)]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for n in maze._open_neighbors(cur):
			if not reached.has(n):
				reached[n] = true
				queue.append(n)
	_assert(reached.size() == maze.cols * maze.rows, "il labirinto ha celle non raggiungibili (%d su %d)" % [reached.size(), maze.cols * maze.rows])

	# Il centro di ogni cella deve essere libero (mai dentro una parete).
	var all_centers_free := true
	for y in range(maze.rows):
		for x in range(maze.cols):
			if not maze.is_position_free(maze.cell_center(x, y), 12.0):
				all_centers_free = false
	_assert(all_centers_free, "il centro di almeno una cella risulta dentro una parete")

	# Il centro di una parete perimetrale deve essere bloccato.
	var boundary_point: Vector2 = maze.origin + Vector2(0.0, maze.cell_size * 0.5)
	_assert(not maze.is_position_free(boundary_point, 12.0), "il muro perimetrale non blocca la posizione")

	# resolve_move non deve mai spingere un'entità dentro una parete.
	var far_move := maze.resolve_move(maze.cell_center(0, 0), Vector2(2000, 0), 12.0)
	_assert(maze.is_position_free(far_move, 12.0), "resolve_move ha lasciato l'entità dentro una parete")
	_assert(far_move.x < maze.origin.x + maze.cell_size * float(maze.cols), "resolve_move non ha bloccato il movimento al muro perimetrale")

	# Pathfinding: il percorso tra due celle deve esistere ed essere
	# composto solo da passi verso celle adiacenti aperte.
	var farthest := maze.find_farthest_cell(Vector2i(0, 0))
	_assert(farthest != Vector2i(0, 0), "find_farthest_cell dovrebbe trovare una cella diversa dall'origine")
	var path := maze.get_path(maze.cell_center(0, 0), maze.cell_center(farthest.x, farthest.y))
	_assert(path.size() >= 2, "il percorso verso la cella più lontana dovrebbe avere almeno 2 punti")
	for i in range(path.size() - 1):
		_assert(maze.world_to_cell(path[i]).distance_to(maze.world_to_cell(path[i + 1])) <= 1.5, "il percorso salta tra celle non adiacenti")

	print("MazeGrid: %d x %d celle, %d segmenti muro, tutte connesse, pathfinding OK" % [maze.cols, maze.rows, maze.wall_rects.size()])

func _test_maze_integration() -> void:
	print("--- Test integrazione labirinto nel gioco reale (Run) ---")
	var maze_run := Run.new()
	add_child(maze_run)
	maze_run.begin_new_streak()

	_assert(maze_run.current_maze != null, "la stanza 1 dovrebbe generare un labirinto")
	_assert(maze_run.player.maze == maze_run.current_maze, "il giocatore non è collegato al labirinto della stanza")
	_assert(maze_run.current_maze.is_position_free(maze_run.player.global_position, maze_run.player.radius), "il giocatore è spawnato dentro un muro")

	# L'uscita è la cella più lontana dallo spawn in numero di passi lungo
	# i corridoi (BFS), non in linea d'aria: un labirinto tortuoso può
	# piazzarla vicina in termini di pixel pur essendo lontana da
	# percorrere. Si verifica quindi la distanza sul grafo, non quella
	# euclidea (già verificata a parte in _test_maze_grid).
	var spawn_pos: Vector2 = maze_run.player.global_position
	var exit_path_len: int = maze_run.current_maze.get_path(spawn_pos, maze_run.exit_position).size()
	var min_expected_hops: int = (maze_run.MAZE_COLS + maze_run.MAZE_ROWS) / 2
	_assert(exit_path_len >= min_expected_hops, "l'uscita è troppo vicina allo spawn lungo il percorso (%d celle, attese almeno %d)" % [exit_path_len, min_expected_hops])

	var bounds: Rect2 = maze_run.current_maze.total_bounds()
	_assert(maze_run.player.camera.limit_left == int(bounds.position.x), "il limite sinistro della camera non combacia col labirinto")
	_assert(maze_run.player.camera.limit_right == int(bounds.end.x), "il limite destro della camera non combacia col labirinto")
	_assert(bounds.size.x > 1280.0 and bounds.size.y > 720.0, "il labirinto dovrebbe essere più grande della finestra di gioco (%s)" % bounds.size)

	_assert(maze_run.enemy_container.get_child_count() > 0, "la stanza 1 dovrebbe avere nemici")
	for e in maze_run.enemy_container.get_children():
		_assert(e.maze == maze_run.current_maze, "un nemico non è collegato al labirinto della stanza")
		_assert(maze_run.current_maze.is_position_free(e.global_position, e.radius), "un nemico è spawnato dentro un muro")

	# Un nemico deve muoversi davvero seguendo un percorso reale nel
	# labirinto (fisica reale su più frame, non restare immobile/bloccato).
	# Non si verifica che la distanza in linea d'aria diminuisca sempre:
	# in un labirinto il percorso più breve può richiedere di allontanarsi
	# temporaneamente per aggirare una parete, quindi la distanza in
	# linea d'aria non è monotona nel breve periodo. Si verifica invece
	# che la distanza sul GRAFO del percorso (numero di celle da
	# attraversare) diminuisca, e che la posizione sia cambiata davvero.
	var target_enemy = maze_run.enemy_container.get_child(0)
	var pos_before: Vector2 = target_enemy.global_position
	var path_len_before: int = maze_run.current_maze.get_path(pos_before, maze_run.player.global_position).size()
	for i in range(180):
		await get_tree().physics_frame
	var pos_after: Vector2 = target_enemy.global_position
	if target_enemy.alive:
		var path_len_after: int = maze_run.current_maze.get_path(pos_after, maze_run.player.global_position).size()
		_assert(pos_after.distance_to(pos_before) > 20.0, "il nemico è rimasto fermo/bloccato nel labirinto per 3s (spostamento %.1f)" % pos_after.distance_to(pos_before))
		_assert(path_len_after < path_len_before or path_len_after <= 2, "il nemico non si è avvicinato al giocatore lungo il percorso (celle: %d -> %d)" % [path_len_before, path_len_after])
		_assert(maze_run.current_maze.is_position_free(pos_after, target_enemy.radius), "il nemico ha attraversato un muro")

	# Attraversa le 5 stanze fino alla sala del boss: lí l'arena torna
	# aperta (niente labirinto) ma resta più grande dello schermo.
	for i in range(5):
		maze_run._debug_kill_all()
		maze_run.player.global_position = maze_run.exit_position
		maze_run._physics_process(0.016)
		if maze_run.powerup_choice_screen.visible:
			maze_run._on_powerup_selected(GameData.get_regular_powerup_pool()[0].id)
	_assert(maze_run.room_number == 6, "non si è arrivati alla sala del boss (stanza %d)" % maze_run.room_number)
	_assert(maze_run.current_maze == null, "la sala del boss non dovrebbe avere un labirinto")
	_assert(maze_run.player.maze == null, "il giocatore non dovrebbe avere un labirinto nella sala del boss")
	var boss_bounds: Rect2 = maze_run.arena_rect
	_assert(boss_bounds.size.x > 1280.0 or boss_bounds.size.y > 720.0, "la sala del boss non è più grande della finestra di gioco (%s)" % boss_bounds.size)

	print("Integrazione labirinto: OK (uscita a %d celle di percorso dallo spawn, sala boss %s)" % [exit_path_len, boss_bounds.size])
	maze_run.queue_free()
	await get_tree().process_frame

func _test_maze_enemy_closes_final_gap() -> void:
	print("--- Test regressione: il nemico non deve bloccarsi vicino al giocatore nel labirinto ---")
	# Bug reale trovato in gioco: MazeGrid.get_path() porta il nemico al
	# CENTRO della cella del giocatore, non alla sua posizione esatta.
	# Una volta nella stessa cella, get_path() restituisce un percorso di
	# un solo punto (o nessuno): senza un fallback, _move_along_path si
	# limitava a un return e il nemico restava fermo per sempre, anche
	# se il giocatore non era esattamente al centro della cella (cosa
	# che succede quasi sempre, dato che si muove di continuo).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var maze := MazeGrid.new()
	maze.generate(6, 6, 160.0, rng)

	var p := Player.new()
	add_child(p)
	p.maze = maze
	# Il giocatore è vicino a un angolo della cella (0,0), non al centro:
	# esattamente la situazione che prima faceva bloccare il nemico.
	p.global_position = maze.cell_center(0, 0) + Vector2(50.0, 50.0)

	var e := Enemy.new()
	e.maze = maze
	e.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	add_child(e)
	# Il nemico parte già nella stessa cella del giocatore, dal lato
	# opposto: get_path() tra i due restituisce subito un solo punto.
	e.global_position = maze.cell_center(0, 0) + Vector2(-50.0, -50.0)
	await get_tree().physics_frame

	var dist_start: float = e.global_position.distance_to(p.global_position)
	var frozen_frames := 0
	var last_pos: Vector2 = e.global_position
	for i in range(180):
		await get_tree().physics_frame
		if e.global_position.distance_to(last_pos) < 0.01:
			frozen_frames += 1
		last_pos = e.global_position

	var dist_end: float = e.global_position.distance_to(p.global_position)
	print("Distanza nemico->giocatore: %.1f -> %.1f (frame fermi: %d/180)" % [dist_start, dist_end, frozen_frames])
	_assert(dist_end < 40.0, "il nemico dovrebbe aver raggiunto il giocatore nella stessa cella (distanza finale %.1f)" % dist_end)
	_assert(frozen_frames < 150, "il nemico è rimasto fermo per quasi tutto il test (%d/180 frame)" % frozen_frames)
	print("Chiusura del divario finale nel labirinto: OK")

	e.queue_free()
	p.queue_free()
	await get_tree().process_frame

func _test_maze_dash_no_tunneling() -> void:
	print("--- Test scatto ad alta velocità contro un muro del labirinto ---")
	var rng := RandomNumberGenerator.new()
	rng.seed = 999

	var maze := MazeGrid.new()
	maze.generate(6, 6, 160.0, rng)

	var p := Player.new()
	add_child(p)
	p.maze = maze
	# Cella d'angolo (0,0): il muro perimetrale è sempre immediatamente a
	# nord e a ovest, indipendentemente da come è stato generato il resto
	# del labirinto, quindi lo scatto verso l'alto lo colpisce di sicuro.
	p.global_position = maze.cell_center(0, 0)
	await get_tree().physics_frame

	p.start_dash(Vector2.UP)
	for i in range(20):
		await get_tree().physics_frame

	_assert(maze.total_bounds().has_point(p.global_position), "il giocatore è uscito dai confini del labirinto durante lo scatto")
	_assert(maze.is_position_free(p.global_position, p.radius), "lo scatto ha attraversato un muro del labirinto (tunneling)")
	print("Scatto contro muro: OK (nessun tunneling, posizione finale %s)" % p.global_position)

	p.queue_free()
	await get_tree().process_frame

func _test_all_boss_moves() -> void:
	print("--- Test di ogni mossa di ogni boss (esecuzione diretta e deterministica) ---")
	var bounds := Rect2(Vector2(48, 48), Vector2(1184, 624))

	for boss_id in GameData.BOSSES.keys():
		var data: Dictionary = GameData.BOSSES[boss_id]
		var container := Node2D.new()
		add_child(container)

		var projectile_count := [0]
		var melee_count := [0]
		var summon_count := [0]

		var boss := Boss.new()
		boss.arena_bounds = bounds
		boss.setup_from_data(data)
		boss.global_position = Vector2(600, 300)
		boss.spawn_projectile.connect(func(pos, dir, speed, dmg): projectile_count[0] += 1)
		boss.melee_aoe.connect(func(origin, radius, dmg): melee_count[0] += 1)
		boss.summon_requested.connect(func(enemy_type_id, count, origin): summon_count[0] += 1)
		container.add_child(boss)
		boss.intro_timer = 0.0

		var p := Player.new()
		p.arena_bounds = bounds
		p.global_position = Vector2(600, 500)
		container.add_child(p)
		await get_tree().physics_frame

		for attack_name in data.get("attacks", []) + data.get("special_attacks", []):
			projectile_count[0] = 0
			melee_count[0] = 0
			summon_count[0] = 0
			var pos_before: Vector2 = boss.global_position
			boss.pending_attack = attack_name
			boss.mode = "telegraph"
			boss.telegraph_timer = 0.0
			boss._execute_attack(p)

			match attack_name:
				"charge":
					_assert(boss.mode == "charge", "%s/charge dovrebbe entrare in modalità charge" % boss_id)
				"burst", "volley", "raffica", "raffica_ampia", "cono":
					_assert(projectile_count[0] > 0, "%s/%s dovrebbe generare almeno un proiettile" % [boss_id, attack_name])
				"slam":
					_assert(melee_count[0] == 1, "%s/slam dovrebbe emettere un colpo ad area corpo a corpo" % boss_id)
				"teletrasporto":
					_assert(boss.global_position != pos_before, "%s/teletrasporto dovrebbe spostare il boss" % boss_id)
				"richiamo":
					_assert(summon_count[0] == 1, "%s/richiamo dovrebbe richiedere l'evocazione di rinforzi" % boss_id)
			_assert(boss.alive, "%s non dovrebbe morire eseguendo %s" % [boss_id, attack_name])

		print("%s (%s): mosse verificate senza errori -> %s" % [data.name, boss_id, data.get("attacks", []) + data.get("special_attacks", [])])
		container.queue_free()
		await get_tree().process_frame

	print("Mosse di tutti i boss: OK")

func _test_boss_signals_wired_in_run() -> void:
	print("--- Test collegamento segnali melee_aoe/summon_requested in Run ---")
	var signal_run := Run.new()
	add_child(signal_run)
	signal_run.begin_new_streak()

	var hp_before: float = signal_run.player.hp
	signal_run._on_boss_melee_aoe(signal_run.player.global_position, 100.0, 20.0)
	_assert(signal_run.player.hp == hp_before - 20.0, "_on_boss_melee_aoe non ha applicato il danno corretto al giocatore")

	var enemy_count_before: int = signal_run.enemy_container.get_child_count()
	signal_run._on_boss_summon_requested("sciame", 3, signal_run.player.global_position)
	_assert(signal_run.enemy_container.get_child_count() == enemy_count_before + 3, "_on_boss_summon_requested non ha generato il numero corretto di rinforzi")

	print("Segnali boss collegati a Run: OK")
	signal_run.queue_free()
	await get_tree().process_frame

func _test_real_dash_collision() -> void:
	print("--- Test collisione reale scatto->nemico (fisica Area2D) ---")
	var p := Player.new()
	p.arena_bounds = Rect2(Vector2(48, 48), Vector2(864, 444))
	add_child(p)
	p.global_position = Vector2(400, 300)

	var e := Enemy.new()
	e.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	e.global_position = Vector2(430, 300)
	add_child(e)

	var start_hp: float = e.hp
	p.start_dash(Vector2.RIGHT)
	_assert(p.is_dashing, "il giocatore dovrebbe risultare in scatto")

	for i in range(6):
		await get_tree().physics_frame

	print("HP nemico dopo scatto reale: ", e.hp, " / ", start_hp)
	_assert(e.hp < start_hp, "lo scatto reale (via fisica Area2D) non ha danneggiato il nemico")
	print("Collisione via fisica reale: OK")

	p.queue_free()
	e.queue_free()
	await get_tree().physics_frame

	print("--- Test danno da contatto nemico->giocatore (fisica Area2D) ---")
	var p2 := Player.new()
	p2.arena_bounds = Rect2(Vector2(48, 48), Vector2(864, 444))
	add_child(p2)
	p2.global_position = Vector2(400, 300)

	var e2 := Enemy.new()
	e2.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	e2.global_position = Vector2(410, 300)
	add_child(e2)

	var start_player_hp: float = p2.hp
	for i in range(6):
		await get_tree().physics_frame

	print("PV giocatore dopo contatto reale: ", p2.hp, " / ", start_player_hp)
	_assert(p2.hp < start_player_hp, "il contatto reale nemico->giocatore non ha inflitto danno")
	print("Danno da contatto via fisica reale: OK")

	p2.queue_free()
	e2.queue_free()
	await get_tree().physics_frame

func _clear_five_rooms_to_boss() -> void:
	for i in range(1, 6):
		_kill_all_room_enemies()
		_assert(run.room_cleared, "la stanza %d non risulta ripulita" % run.room_number)
		run.player.global_position = run.exit_position
		run._physics_process(0.016)
		_assert(run.powerup_choice_screen.visible, "schermata scelta potenziamento non mostrata (stanza %d)" % i)
		# Regressione: restare fermi nel portale non deve rigenerare la
		# scelta del potenziamento ad ogni frame (il portale si disattiva
		# subito dopo il primo trigger).
		_assert(not run.room_cleared, "il portale non si è disattivato dopo il primo utilizzo (stanza %d)" % i)
		for j in range(5):
			run._physics_process(0.016)
			_assert(not run.room_cleared, "il portale ha ri-generato la scelta mentre il giocatore restava fermo (stanza %d)" % i)
		var choice: Dictionary = GameData.get_regular_powerup_pool()[0]
		run._on_powerup_selected(choice.id)

func _kill_all_room_enemies() -> void:
	for e in run.enemy_container.get_children():
		if e.alive:
			e.take_damage(99999.0)
			run._on_enemy_defeated(e)

func _defeat_current_boss() -> String:
	var boss = run.current_boss
	var boss_id: String = boss.boss_id
	boss.take_damage(99999.0)
	run._on_enemy_defeated(boss)
	return boss_id

func _assert(condition: bool, message: String) -> void:
	if not condition:
		printerr("FALLITO: " + message)
		get_tree().quit(1)
