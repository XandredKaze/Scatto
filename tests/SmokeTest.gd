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

	await _test_real_dash_collision()
	await _test_boss_attack_patterns()

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
	# (non chiamate sincrone) perché il motore lo esegua davvero.
	for i in range(4):
		await get_tree().process_frame
	_assert(run.hud.powerup_tray.get_child_count() == 2, "attese 2 icone distinte in HUD (bottino dorato + potenziamento ripetuto), trovate %d" % run.hud.powerup_tray.get_child_count())
	print("Potenziamenti attivi mostrati in HUD: ", run.hud.powerup_tray.get_child_count())

	_assert(run.room_number == 6, "numero stanza atteso 6, trovato %d" % run.room_number)
	_assert(run.current_boss != null, "il boss non è stato generato")
	_assert(not run.current_boss.is_special, "il boss della run 1 non dovrebbe essere speciale")
	print("Run 1: boss normale confermato (", run.current_boss.display_name, ")")
	_defeat_current_boss()
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
	_defeat_current_boss()

	print("Statistiche finali: ", SaveManager.stats)
	_assert(SaveManager.stats.runs_won == 3, "attese 3 run vinte, trovate %d" % SaveManager.stats.runs_won)
	_assert(SaveManager.stats.special_boss_defeated == 1, "atteso 1 boss speciale sconfitto")
	_assert(SaveManager.stats.golden_defeated == 1, "atteso 1 nemico dorato sconfitto")
	_assert(SaveManager.is_powerup_unlocked("cuore_dorato"), "potenziamento leggendario del dorato non sbloccato")
	_assert(SaveManager.is_powerup_unlocked("benedizione_del_custode"), "potenziamento leggendario del boss speciale non sbloccato")
	_assert(SaveManager.is_enemy_unlocked("strisciante_dorato"), "variante dorata non sbloccata nel bestiario")
	_assert(SaveManager.is_enemy_unlocked("custode_corrotto"), "boss speciale non sbloccato nel bestiario")
	_assert(SaveManager.is_enemy_unlocked("custode"), "boss normale non sbloccato nel bestiario")

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

func _defeat_current_boss() -> void:
	var boss = run.current_boss
	boss.take_damage(99999.0)
	run._on_enemy_defeated(boss)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		printerr("FALLITO: " + message)
		get_tree().quit(1)
