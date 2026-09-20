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
	await _test_hub_subpanel_navigation()
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
	await _test_pause_menu()
	await _test_ally_taming()
	await _test_ally_combat()
	await _test_taming_last_enemy_clears_room()
	await _test_ally_kill_clears_room()
	await _test_shockwave_ignores_allies()
	await _test_ranged_ally_keeps_behavior()
	await _test_unlocked_boss_legendary_in_reward_pool()
	await _test_legendary_rarity_weighting()
	await _test_ally_grants_special_attack()
	await _test_dash_traded_for_ally_attacks()
	await _test_run_music()
	await _test_pause_menu_settings()
	await _test_ally_catchup_speed()
	await _test_hostiles_attack_allies()
	await _test_boss_attacks_allies()
	await _test_special_attack_pacing()
	await _test_ally_powerups()
	await _test_ally_special_attack_empowered_duplicate()
	await _test_ally_special_attack_effects()
	await _test_special_attack_visual_effects()
	_test_special_attack_key_bindings()
	await _test_settings_screen()
	await _test_hub_settings_and_quit_entries()
	await _test_crypt_ui_theme()
	await _test_vignette_below_hud()
	await _test_blood_decals()
	await _test_arena_visual_geometry()
	_test_creature_rim_colors()
	_test_creature_shapes()
	await _test_flower_shoots_its_own_colour()
	await _test_slime_body_trail()
	await _test_room_clear_freezes_player_and_clears_projectiles()
	await _test_boss_defeat_freezes_player_and_clears_projectiles()

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

func _test_ally_taming() -> void:
	print("--- Test addomesticamento nemici comuni (alleati) ---")
	var tame_run := Run.new()
	add_child(tame_run)
	tame_run.begin_new_streak()
	await get_tree().process_frame

	# Sostituisce i nemici generati casualmente con bersagli noti, tutti
	# vicini al giocatore, per un test deterministico del limite massimo
	# di alleati e dell'esclusione dei nemici dorati.
	for e in tame_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# Un nemico dorato isolato non deve mai poter essere addomesticato:
	# testato con lui come unico bersaglio nel raggio, cosí un eventuale
	# bug che lo rendesse comunque bersaglio non verrebbe mascherato da
	# un bersaglio comune più vicino.
	var golden := Enemy.new()
	golden.maze = tame_run.current_maze
	golden.setup_from_data(GameData.build_golden_enemy_data("strisciante"), true)
	golden.global_position = tame_run.player.global_position
	tame_run.enemy_container.add_child(golden)
	tame_run._on_tame_requested()
	_assert(not golden.is_ally, "un nemico dorato non dovrebbe poter essere addomesticato")
	_assert(tame_run.allies.is_empty(), "il tentativo su un dorato isolato non dovrebbe creare alleati")
	golden.queue_free()
	await get_tree().process_frame

	# Tre bersagli comuni via via più lontani dal giocatore: ogni
	# addomesticamento deve scegliere sempre il più vicino non ancora
	# alleato, cosí l'ordine di conversione è deterministico.
	var targets: Array = []
	for i in range(3):
		var e := Enemy.new()
		e.maze = tame_run.current_maze
		e.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
		e.hp = e.max_hp * 0.5
		e.global_position = tame_run.player.global_position + Vector2(20.0 * (i + 1), 0.0)
		tame_run.enemy_container.add_child(e)
		targets.append(e)

	tame_run._on_tame_requested()
	_assert(targets[0].is_ally, "il bersaglio più vicino dovrebbe diventare alleato per primo")
	_assert(tame_run.allies.size() == 1, "dovrebbe esserci esattamente 1 alleato")
	_assert(targets[0].hp == targets[0].max_hp, "l'alleato appena convertito dovrebbe essere guarito a vita piena")

	tame_run._on_tame_requested()
	_assert(targets[1].is_ally, "il secondo bersaglio più vicino dovrebbe diventare alleato")
	_assert(tame_run.allies.size() == 2, "dovrebbero esserci esattamente 2 alleati")

	tame_run._on_tame_requested()
	_assert(not targets[2].is_ally, "il terzo tentativo dovrebbe fallire: limite massimo di 2 alleati già raggiunto")
	_assert(tame_run.allies.size() == 2, "il numero di alleati non dovrebbe mai superare il massimo (2)")

	# Un alleato ancora vivo non deve bloccare il rilevamento di stanza
	# ripulita: solo il terzo bersaglio (mai addomesticato) va sconfitto.
	targets[2].take_damage(99999.0)
	tame_run._on_enemy_defeated(targets[2])
	_assert(tame_run.room_cleared, "la stanza dovrebbe risultare ripulita ignorando gli alleati ancora vivi")
	_assert(tame_run.player.frozen, "il giocatore dovrebbe restare fermo dopo la pulizia della stanza")

	# Il resto del test verifica un'altra regressione (lo scatto non deve
	# mai colpire un alleato): sblocca qui il giocatore, cosí non si
	# confonde con l'immobilità dovuta alla pulizia della stanza appena
	# verificata sopra.
	tame_run.player.unfreeze()

	# Lo scatto del giocatore non deve mai danneggiare un proprio alleato.
	var ally_hp_before: float = targets[0].hp
	tame_run.player.global_position = targets[0].global_position
	tame_run.player.start_dash(Vector2.RIGHT)
	for i in range(6):
		await get_tree().physics_frame
	_assert(targets[0].hp == ally_hp_before, "lo scatto ha danneggiato un proprio alleato: non dovrebbe mai accadere")

	# Gli alleati devono sopravvivere al passaggio di stanza (a differenza
	# dei nemici ostili, cancellati e rigenerati ad ogni nuova stanza).
	var surviving_allies: Array = tame_run.allies.duplicate()
	tame_run._generate_room(2)
	_assert(tame_run.allies.size() == 2, "gli alleati non dovrebbero sparire al cambio di stanza")
	for a in surviving_allies:
		_assert(is_instance_valid(a) and a.is_ally, "un alleato è stato erroneamente rimosso al cambio di stanza")
		_assert(a.maze == tame_run.current_maze, "un alleato non è stato ricollegato al labirinto della nuova stanza")

	print("Addomesticamento: OK (conversione, limite massimo, dorati esclusi, stanza ripulita, nessun fuoco amico, persistenza tra stanze)")
	tame_run.queue_free()
	await get_tree().process_frame

func _test_ally_combat() -> void:
	print("--- Test combattimento alleato <-> nemico ostile (fisica reale) ---")
	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	ally.is_ally = true
	add_child(ally)
	ally.collision_mask = 2 | 4 | 8
	ally.global_position = Vector2(400, 300)

	var hostile := Enemy.new()
	hostile.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	add_child(hostile)
	hostile.global_position = Vector2(415, 300)

	# Enemy._physics_process richiede un nodo nel gruppo "player" anche
	# quando (come qui) l'alleato non lo insegue affatto, perché il
	# nemico ostile è già entro il raggio di ingaggio.
	var p := Player.new()
	add_child(p)
	p.global_position = Vector2(0, 0)

	var hostile_start_hp: float = hostile.hp
	var ally_start_hp: float = ally.hp

	for i in range(20):
		await get_tree().physics_frame

	print("HP nemico ostile dopo il combattimento: ", hostile.hp, " / ", hostile_start_hp)
	_assert(hostile.hp < hostile_start_hp, "l'alleato non ha inflitto danno al nemico ostile")
	print("HP alleato dopo il contrattacco del nemico ostile: ", ally.hp, " / ", ally_start_hp)
	_assert(ally.hp < ally_start_hp, "il nemico ostile non ha inflitto danno all'alleato")

	print("Combattimento alleato: OK")
	ally.queue_free()
	hostile.queue_free()
	p.queue_free()
	await get_tree().physics_frame

func _test_taming_last_enemy_clears_room() -> void:
	print("--- Test regressione: addomesticare l'ultimo nemico deve ripulire la stanza ---")
	# L'addomesticamento non passa da _on_enemy_defeated (il bersaglio
	# resta vivo, come alleato): senza il controllo dedicato in
	# _convert_enemy_to_ally(), convertire l'ultimo nemico ostile della
	# stanza non consegnerebbe mai la ricompensa.
	var solo_run := Run.new()
	add_child(solo_run)
	solo_run.begin_new_streak()
	await get_tree().process_frame

	for e in solo_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	var last_enemy := Enemy.new()
	last_enemy.maze = solo_run.current_maze
	last_enemy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	last_enemy.global_position = solo_run.player.global_position
	solo_run.enemy_container.add_child(last_enemy)

	_assert(not solo_run.room_cleared, "setup del test: la stanza non dovrebbe risultare ripulita prima dell'addomesticamento")
	solo_run._on_tame_requested()
	_assert(last_enemy.is_ally, "l'unico nemico della stanza dovrebbe diventare alleato")
	_assert(solo_run.room_cleared, "addomesticare l'ultimo nemico ostile dovrebbe ripulire la stanza (ricompensa consegnata)")

	print("Addomesticare l'ultimo nemico: OK (ricompensa consegnata)")
	solo_run.queue_free()
	await get_tree().process_frame

func _test_ally_kill_clears_room() -> void:
	print("--- Test regressione: un'uccisione dell'alleato deve ripulire la stanza ---")
	# Quando è l'alleato (non lo scatto del giocatore) a finire l'ultimo
	# nemico ostile, Run non lo saprebbe mai senza il segnale Enemy.ally_kill
	# collegato in _convert_enemy_to_ally(): la ricompensa non verrebbe mai
	# consegnata. Qui il nemico viene finito per davvero, via fisica reale.
	var kill_run := Run.new()
	add_child(kill_run)
	kill_run.begin_new_streak()
	await get_tree().process_frame

	for e in kill_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# L'ultimo nemico ostile va aggiunto PRIMA di addomesticare l'alleato:
	# se fosse l'unico nemico presente, l'addomesticamento stesso
	# ripulirebbe già la stanza (fix precedente), mascherando il bug qui
	# testato (l'uccisione da parte dell'alleato, non la conversione).
	var last_hostile := Enemy.new()
	last_hostile.maze = kill_run.current_maze
	last_hostile.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	last_hostile.hp = 1.0
	last_hostile.max_hp = 1.0
	kill_run.enemy_container.add_child(last_hostile)

	var helper := Enemy.new()
	helper.maze = kill_run.current_maze
	helper.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	helper.global_position = kill_run.player.global_position + Vector2(60.0, 0.0)
	kill_run.enemy_container.add_child(helper)
	kill_run.player.global_position = helper.global_position
	kill_run._on_tame_requested()
	_assert(helper.is_ally, "setup del test: il bersaglio dovrebbe diventare alleato")
	_assert(not kill_run.room_cleared, "setup del test: la stanza non dovrebbe risultare ripulita prima del colpo di grazia")

	last_hostile.global_position = helper.global_position
	for i in range(10):
		await get_tree().physics_frame
		if not last_hostile.alive:
			break

	_assert(not last_hostile.alive, "setup del test: l'alleato dovrebbe aver finito l'ultimo nemico ostile")
	_assert(kill_run.room_cleared, "un'uccisione dell'alleato dovrebbe ripulire la stanza (ricompensa consegnata)")

	print("Uccisione dell'alleato: OK (ricompensa consegnata)")
	kill_run.queue_free()
	await get_tree().process_frame

func _test_shockwave_ignores_allies() -> void:
	print("--- Test regressione: l'onda d'urto non deve colpire i propri alleati ---")
	# _on_dash_hit itera i gruppi "enemy"/"boss" per il danno ad area
	# della benedizione del Custode: gli alleati restano nel gruppo
	# "enemy" (sono ancora nodi Enemy), quindi senza l'esclusione
	# esplicita l'onda d'urto del giocatore colpirebbe anche loro.
	var sw_run := Run.new()
	add_child(sw_run)
	sw_run.begin_new_streak()
	await get_tree().process_frame

	for e in sw_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	var ally_target := Enemy.new()
	ally_target.maze = sw_run.current_maze
	ally_target.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	ally_target.global_position = sw_run.player.global_position
	sw_run.enemy_container.add_child(ally_target)
	sw_run.player.global_position = ally_target.global_position
	sw_run._on_tame_requested()
	_assert(ally_target.is_ally, "setup del test: il bersaglio dovrebbe diventare alleato")

	var victim := Enemy.new()
	victim.maze = sw_run.current_maze
	victim.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	victim.global_position = ally_target.global_position + Vector2(30.0, 0.0)
	sw_run.enemy_container.add_child(victim)

	sw_run.player.has_shockwave = true
	var ally_hp_before: float = ally_target.hp
	sw_run._on_dash_hit(victim, 40.0)
	_assert(ally_target.hp == ally_hp_before, "l'onda d'urto ha danneggiato un proprio alleato: non dovrebbe mai accadere")

	print("Onda d'urto: OK (alleati ignorati)")
	sw_run.queue_free()
	await get_tree().process_frame

func _test_ranged_ally_keeps_behavior() -> void:
	print("--- Test regressione: un alleato \"ranged\" mantiene mira e distanza da nemico ---")
	# Un nemico comune convertito in alleato deve mantenere lo stesso
	# comportamento avuto da ostile: il Pungiglione è "ranged" (mantiene
	# le distanze e spara), quindi da alleato non deve diventare un
	# lottatore da mischia che cammina fino al contatto.
	var ranged_run := Run.new()
	add_child(ranged_run)
	ranged_run.begin_new_streak()
	await get_tree().process_frame

	for e in ranged_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# Anche senza .maze sui due nemici, _on_enemy_spawn_projectile assegna
	# comunque proj.maze = current_maze: il proiettile dell'alleato
	# verrebbe distrutto da un muro reale lungo la traiettoria pur avendo
	# scelto un movimento diretto per alleato e bersaglio. Azzerato qui,
	# solo per questo test isolato del comportamento a distanza.
	ranged_run.current_maze = null

	# Il nemico ostile va aggiunto PRIMA di addomesticare l'alleato: se il
	# Pungiglione fosse l'unico nemico presente, l'addomesticamento stesso
	# ripulirebbe già la stanza (fix precedente), mascherando qui il
	# comportamento a distanza che si vuole verificare. Niente labirinto
	# per nessuno dei due (maze lasciato a null, movimento diretto): con
	# la mappa reale il percorso tra due punti puó essere molto più lungo
	# della distanza in linea d'aria (un vicolo cieco da aggirare), il che
	# renderebbe il tempo di viaggio imprevedibile e il test fragile.
	var hostile := Enemy.new()
	hostile.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	hostile.hp = 1.0
	hostile.max_hp = 1.0
	ranged_run.enemy_container.add_child(hostile)

	var ranged_ally := Enemy.new()
	ranged_ally.setup_from_data(GameData.ENEMY_TYPES["pungiglione"], false)
	ranged_ally.global_position = ranged_run.player.global_position
	# A differenza dello spawn reale (_generate_room collega sempre
	# spawn_projectile a _on_enemy_spawn_projectile), qui il nemico è
	# aggiunto a mano: senza questo collegamento il proiettile a distanza
	# dell'alleato non verrebbe mai creato.
	ranged_ally.spawn_projectile.connect(ranged_run._on_enemy_spawn_projectile)
	ranged_run.enemy_container.add_child(ranged_ally)
	ranged_run.player.global_position = ranged_ally.global_position
	ranged_run._on_tame_requested()
	_assert(ranged_ally.is_ally, "setup del test: il Pungiglione dovrebbe diventare alleato")
	_assert(ranged_ally.behavior == "ranged", "setup del test: il comportamento originale dovrebbe restare \"ranged\"")
	_assert(not ranged_run.room_cleared, "setup del test: la stanza non dovrebbe risultare ripulita prima del colpo")

	# attack_timer parte da un valore casuale (randf() * attack_cooldown,
	# vedi Enemy._ready()): azzerato qui per rendere deterministico il
	# momento del primo colpo, altrimenti il test sarebbe fragile a
	# seconda di quanto tempo resta prima del budget di frame sottostante.
	ranged_ally.attack_timer = 0.0
	hostile.global_position = ranged_ally.global_position + Vector2(220.0, 0.0)
	for i in range(150):
		await get_tree().physics_frame
		if not hostile.alive:
			break

	_assert(not hostile.alive, "l'alleato a distanza non ha mai finito il nemico ostile")
	var final_dist: float = ranged_ally.global_position.distance_to(hostile.global_position)
	print("Distanza finale alleato<->bersaglio: ", final_dist)
	_assert(final_dist > 100.0, "l'alleato \"ranged\" si è avvicinato a distanza di mischia invece di sparare da lontano")
	_assert(ranged_run.room_cleared, "un'uccisione a distanza dell'alleato dovrebbe ripulire la stanza (ricompensa consegnata)")

	print("Comportamento a distanza dell'alleato: OK")
	ranged_run.queue_free()
	await get_tree().process_frame

func _test_unlocked_boss_legendary_in_reward_pool() -> void:
	print("--- Test regressione: leggendari dei boss sconfitti nel pool ricompense ---")
	# I leggendari dei boss speciali erano ottenibili solo come bottino
	# garantito la prima volta che si sconfiggeva quel boss: ora, una
	# volta sbloccati nel bestiario, devono poter ricomparire anche tra
	# le 3 scelte casuali di fine stanza in run successive.
	var previous_bestiary: Dictionary = SaveManager.bestiary.duplicate(true)
	SaveManager.bestiary = {}

	_assert(GameData.get_unlocked_boss_legendary_pool().is_empty(), "nessun leggendario di boss dovrebbe comparire senza boss sconfitti")

	SaveManager.bestiary["custode_corrotto"] = {"first_defeated_at": 0, "times_defeated": 1}
	var unlocked: Array = GameData.get_unlocked_boss_legendary_pool()
	_assert(unlocked.size() == 1 and unlocked[0].id == "benedizione_del_custode", "la Benedizione del Custode dovrebbe sbloccarsi dopo aver sconfitto il Custode Corrotto")

	# Il Cuore Dorato è bottino di un nemico dorato, non di un boss:
	# anche se sbloccato nel bestiario, non deve mai finire in questo pool.
	SaveManager.bestiary["strisciante_dorato"] = {"first_defeated_at": 0, "times_defeated": 1}
	unlocked = GameData.get_unlocked_boss_legendary_pool()
	_assert(unlocked.size() == 1, "il Cuore Dorato non deve mai comparire nel pool dei leggendari dei boss")

	# Integrazione: con il boss sbloccato, il potenziamento deve poter
	# comparire davvero tra le 3 scelte di fine stanza generate da Run.
	# Si ripete il tiro finché non lo si osserva almeno una volta, per
	# non essere fragili alla casualità dello shuffle.
	var legend_run := Run.new()
	add_child(legend_run)
	legend_run.begin_new_streak()
	await get_tree().process_frame
	# L'estrazione pesata (GameData.weighted_pick_without_replacement) rende
	# un leggendario molto più raro di un comune/raro: servono molti più
	# tentativi di prima per non rischiare un falso negativo occasionale.
	var seen := false
	for i in range(3000):
		var choices: Array = legend_run._roll_powerup_choices(3)
		for c in choices:
			if c.id == "benedizione_del_custode":
				seen = true
				break
		if seen:
			break
	_assert(seen, "la Benedizione del Custode non è mai comparsa tra le scelte di fine stanza in 3000 tentativi")
	legend_run.queue_free()
	await get_tree().process_frame

	SaveManager.bestiary = previous_bestiary
	SaveManager.save_data()
	print("Leggendari dei boss sconfitti nel pool ricompense: OK")

func _test_legendary_rarity_weighting() -> void:
	print("--- Test regressione: i leggendari devono comparire molto più raramente ---")
	# Verifica statisticamente (non solo "compare almeno una volta") che
	# il peso di rarità funzioni davvero: comuni più frequenti dei rari,
	# rari nettamente più frequenti dei leggendari.
	var previous_bestiary: Dictionary = SaveManager.bestiary.duplicate(true)
	SaveManager.bestiary["custode_corrotto"] = {"first_defeated_at": 0, "times_defeated": 1}
	SaveManager.bestiary["colosso_corrotto"] = {"first_defeated_at": 0, "times_defeated": 1}
	SaveManager.bestiary["spettro_corrotto"] = {"first_defeated_at": 0, "times_defeated": 1}

	var weight_run := Run.new()
	add_child(weight_run)
	weight_run.begin_new_streak()
	await get_tree().process_frame

	var counts := {"common": 0, "rare": 0, "legendary": 0}
	var trials := 3000
	for i in range(trials):
		var choices: Array = weight_run._roll_powerup_choices(3)
		for c in choices:
			counts[c.rarity] += 1

	print("Occorrenze su %d estrazioni da 3 carte: %s" % [trials, counts])
	_assert(counts.legendary > 0, "setup del test: i leggendari dovrebbero comparire almeno qualche volta su %d tentativi" % trials)
	_assert(counts.common > counts.rare, "i comuni dovrebbero comparire più spesso dei rari")
	_assert(counts.rare > counts.legendary, "i rari dovrebbero comparire più spesso dei leggendari")
	# Confronta l'ORDINE DI GRANDEZZA atteso dai pesi (12 comune / 4 raro /
	# 1 leggendario a voce), non un valore esatto, per non essere fragile
	# alla varianza statistica su un campione finito.
	var legendary_ratio: float = float(counts.rare) / float(max(counts.legendary, 1))
	_assert(legendary_ratio > 2.0, "i leggendari non sembrano sufficientemente più rari dei rari (rapporto rari/leggendari: %.2f)" % legendary_ratio)

	weight_run.queue_free()
	await get_tree().process_frame
	SaveManager.bestiary = previous_bestiary
	SaveManager.save_data()
	print("Peso di rarità dei leggendari: OK")

func _test_ally_grants_special_attack() -> void:
	print("--- Test regressione: addomesticare concede un attacco speciale per alleato, su slot indipendenti ---")
	var grant_run := Run.new()
	add_child(grant_run)
	grant_run.begin_new_streak()
	await get_tree().process_frame

	for e in grant_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# Un nemico ostile "esca" mai coinvolto, cosí la stanza non risulta mai
	# ripulita durante questo test (altrimenti il giocatore verrebbe
	# congelato dalla pulizia della stanza, confondendosi con quanto si
	# vuole verificare qui: la sola concessione/gestione degli slot).
	var decoy := Enemy.new()
	decoy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	decoy.global_position = grant_run.player.global_position + Vector2(600.0, 600.0)
	grant_run.enemy_container.add_child(decoy)

	_assert(grant_run.player.granted_ability_ids == ["", ""], "setup del test: senza alleati non dovrebbe esserci alcun attacco speciale concesso")
	_assert(not grant_run.player.can_use_special_attack(0) and not grant_run.player.can_use_special_attack(1), "senza alleati nessuno slot dovrebbe essere utilizzabile")

	var first_ally := Enemy.new()
	first_ally.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	first_ally.global_position = grant_run.player.global_position
	grant_run.enemy_container.add_child(first_ally)
	grant_run.player.global_position = first_ally.global_position
	grant_run._on_tame_requested()
	_assert(grant_run.player.granted_ability_ids[0] == "strisciante", "il primo slot dovrebbe corrispondere al tipo dell'alleato appena addomesticato")
	_assert(grant_run.player.granted_ability_ids[1] == "", "il secondo slot dovrebbe restare vuoto con un solo alleato")
	_assert(not grant_run.player.special_attack_empowered[0], "con un solo alleato l'attacco non dovrebbe essere potenziato")
	_assert(grant_run.player.can_use_special_attack(0), "con un alleato vivo lo slot 0 dovrebbe essere utilizzabile")

	var second_ally := Enemy.new()
	second_ally.setup_from_data(GameData.ENEMY_TYPES["pungiglione"], false)
	second_ally.global_position = grant_run.player.global_position
	grant_run.enemy_container.add_child(second_ally)
	grant_run._on_tame_requested()
	_assert(grant_run.player.granted_ability_ids[0] == "strisciante", "il primo alleato dovrebbe mantenere il proprio slot dopo il secondo addomesticamento")
	_assert(grant_run.player.granted_ability_ids[1] == "pungiglione", "il secondo alleato di tipo diverso dovrebbe occupare il secondo slot")
	_assert(grant_run.player.can_use_special_attack(0) and grant_run.player.can_use_special_attack(1), "con 2 alleati diversi entrambi gli slot dovrebbero essere utilizzabili")

	# Gli slot hanno tempi di recupero indipendenti per abilità: mettere in
	# cooldown l'abilità dello slot 0 non deve toccare lo slot 1.
	grant_run.player.special_attack_cooldowns[grant_run.player.granted_ability_ids[0]] = 3.0
	_assert(not grant_run.player.can_use_special_attack(0), "lo slot 0 dovrebbe risultare in tempo di recupero")
	_assert(grant_run.player.can_use_special_attack(1), "lo slot 1 non dovrebbe essere influenzato dal tempo di recupero dello slot 0")
	grant_run.player.special_attack_cooldowns.clear()

	# Se l'alleato nello slot 1 muore, il suo slot torna vuoto; lo slot 0
	# resta legato all'alleato superstite.
	second_ally.take_damage(99999.0)
	_assert(grant_run.player.granted_ability_ids[0] == "strisciante", "lo slot dell'alleato superstite non dovrebbe cambiare")
	_assert(grant_run.player.granted_ability_ids[1] == "", "lo slot dell'alleato caduto dovrebbe tornare vuoto")

	first_ally.take_damage(99999.0)
	_assert(grant_run.player.granted_ability_ids == ["", ""], "senza alleati superstiti nessuno slot dovrebbe restare assegnato")
	_assert(not grant_run.player.can_use_special_attack(0) and not grant_run.player.can_use_special_attack(1), "senza alleati nessuno slot dovrebbe essere più utilizzabile")

	print("Concessione dell'attacco speciale su slot indipendenti: OK")
	grant_run.queue_free()
	await get_tree().process_frame

func _test_settings_screen() -> void:
	print("--- Test impostazioni (volume, video, assegnazione tasti, persistenza) ---")
	var previous_settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.settings = {}

	var screen := SettingsScreen.new()
	add_child(screen)
	await get_tree().process_frame

	# Volume: applicato davvero al bus audio e salvato.
	screen.volume_slider.value = 0.5
	await get_tree().process_frame
	_assert(is_equal_approx(GameSettings.get_volume(), 0.5), "il cursore del volume non ha aggiornato l'impostazione")
	_assert(not AudioServer.is_bus_mute(0), "a volume 50%% il bus audio non dovrebbe essere silenziato")
	_assert(SaveManager.settings.get("volume", -1.0) == 0.5, "il volume non è stato salvato")
	screen.volume_slider.value = 0.0
	await get_tree().process_frame
	_assert(AudioServer.is_bus_mute(0), "a volume 0 il bus audio dovrebbe essere silenziato")
	screen.volume_slider.value = 1.0
	await get_tree().process_frame

	# Video: la risoluzione cicla tra quelle previste e torna all'inizio.
	var available: Array = GameSettings.available_resolutions()
	_assert(available.size() > 1, "setup del test: servono almeno due risoluzioni selezionabili")
	var first_res: Vector2i = GameSettings.current_resolution()
	screen._cycle_resolution()
	_assert(GameSettings.current_resolution() != first_res, "il pulsante risoluzione non ha cambiato valore")
	_assert(screen.resolution_btn.text == "%d x %d" % [GameSettings.current_resolution().x, GameSettings.current_resolution().y], "l'etichetta della risoluzione non riflette il valore attuale")
	for i in range(available.size() - 1):
		screen._cycle_resolution()
	_assert(GameSettings.current_resolution() == first_res, "ciclando tutte le risoluzioni si dovrebbe tornare alla prima")

	# La risoluzione viene salvata per valore: un indice salvato non
	# reggerebbe il passaggio a uno schermo che offre meno scelte.
	screen._cycle_resolution()
	var chosen: Vector2i = GameSettings.current_resolution()
	_assert(SaveManager.settings.resolution_w == chosen.x and SaveManager.settings.resolution_h == chosen.y, "la risoluzione scelta non è stata salvata per valore")
	# Una risoluzione salvata che questo schermo non offre non deve essere
	# usata: si ripiega su una valida invece di chiedere l'impossibile.
	SaveManager.settings["resolution_w"] = 7680
	SaveManager.settings["resolution_h"] = 4320
	_assert(GameSettings.available_resolutions().has(GameSettings.current_resolution()), "una risoluzione salvata non più disponibile dovrebbe ripiegare su una valida")
	GameSettings.set_resolution(first_res)

	# Nessuna risoluzione proposta deve superare lo spazio utilizzabile
	# dello schermo: una finestra più grande dello schermo non può essere
	# creata, e la scelta sembrerebbe ignorata.
	for res in GameSettings.available_resolutions():
		_assert(GameSettings.RESOLUTIONS.has(res), "l'elenco disponibile deve essere un sottoinsieme delle risoluzioni previste")

	# L'avviso sulla finestra non ridimensionabile compare solo quando il
	# ridimensionamento non ha davvero avuto effetto.
	GameSettings.resolution_applied = true
	screen.refresh()
	_assert(not screen.resolution_warning.visible, "senza problemi di ridimensionamento l'avviso non dovrebbe comparire")
	GameSettings.resolution_applied = false
	screen.refresh()
	_assert(screen.resolution_warning.visible, "se la finestra non si è ridimensionata l'utente va avvisato invece di lasciarlo nel dubbio")
	GameSettings.resolution_applied = true

	screen._toggle_fullscreen()
	_assert(GameSettings.is_fullscreen(), "il pulsante schermo intero non ha attivato l'impostazione")
	_assert(screen.resolution_btn.disabled, "a schermo intero la scelta della risoluzione dovrebbe essere disattivata")
	screen._toggle_fullscreen()
	_assert(not GameSettings.is_fullscreen(), "il pulsante schermo intero non ha disattivato l'impostazione")

	# Assegnazione di un tasto: sostituisce solo il binding da tastiera e
	# lascia intatto quello del controller della stessa azione.
	_assert(_action_has_key("tame", KEY_F), "setup del test: l'azione tame dovrebbe partire dal tasto F")
	screen._start_listening("tame", screen.binding_buttons[6])
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_L
	key_event.pressed = true
	screen._input(key_event)
	_assert(_action_has_key("tame", KEY_L), "il tasto assegnato non è finito nell'azione")
	_assert(not _action_has_key("tame", KEY_F), "il vecchio tasto dovrebbe essere stato sostituito")
	_assert(_action_has_joypad_button("tame", JOY_BUTTON_X), "assegnare un tasto non deve togliere il binding del controller")
	_assert(screen.listening_action == "", "dopo l'assegnazione la schermata non dovrebbe restare in ascolto")
	_assert(SaveManager.settings.bindings.tame.key == KEY_L, "l'assegnazione non è stata salvata")

	# Assegnazione da controller: sostituisce solo il binding del joypad.
	screen._start_listening("tame", screen.binding_buttons[6])
	var pad_event := InputEventJoypadButton.new()
	pad_event.button_index = JOY_BUTTON_Y
	pad_event.pressed = true
	screen._input(pad_event)
	_assert(_action_has_joypad_button("tame", JOY_BUTTON_Y), "il pulsante del controller assegnato non è finito nell'azione")
	_assert(not _action_has_joypad_button("tame", JOY_BUTTON_X), "il vecchio pulsante del controller dovrebbe essere stato sostituito")
	_assert(_action_has_key("tame", KEY_L), "assegnare un pulsante del controller non deve togliere il binding da tastiera")

	# Esc annulla senza assegnare nulla.
	screen._start_listening("tame", screen.binding_buttons[6])
	var esc_event := InputEventKey.new()
	esc_event.physical_keycode = KEY_ESCAPE
	esc_event.pressed = true
	screen._input(esc_event)
	_assert(_action_has_key("tame", KEY_L), "Esc dovrebbe annullare l'assegnazione, non sostituirla")
	_assert(not _action_has_key("tame", KEY_ESCAPE), "Esc non deve mai essere assegnato a un'azione")
	_assert(screen.listening_action == "", "Esc dovrebbe interrompere l'ascolto")

	# Le impostazioni salvate devono essere riapplicate a freddo, come
	# all'avvio successivo del gioco.
	InputMap.action_erase_events("tame")
	GameSettings.apply_bindings()
	_assert(_action_has_key("tame", KEY_L), "le assegnazioni salvate non sono state riapplicate all'avvio")
	_assert(_action_has_joypad_button("tame", JOY_BUTTON_Y), "le assegnazioni del controller salvate non sono state riapplicate")

	# Ripristino dei predefiniti.
	screen._reset_bindings()
	_assert(_action_has_key("tame", KEY_F), "il ripristino non ha riportato l'azione al tasto predefinito")
	_assert(_action_has_joypad_button("tame", JOY_BUTTON_X), "il ripristino non ha riportato l'azione al pulsante predefinito")
	_assert(SaveManager.settings.get("bindings", {}).is_empty(), "il ripristino dovrebbe svuotare le assegnazioni salvate")

	# La navigazione da controller non si affida alla geometria: ogni
	# controllo selezionabile deve avere un vicino sopra/sotto esplicito.
	var chain_size: int = 3 + GameSettings.REBINDABLE.size() + 2
	_assert(screen._focus_chain.size() == chain_size, "la catena di focus dovrebbe coprire tutti i controlli selezionabili")
	for control in screen._focus_chain:
		_assert(control.focus_mode == Control.FOCUS_ALL, "ogni controllo della catena dovrebbe essere selezionabile")
		_assert(not control.focus_neighbor_top.is_empty(), "manca il vicino superiore esplicito su un controllo delle impostazioni")
		_assert(not control.focus_neighbor_bottom.is_empty(), "manca il vicino inferiore esplicito su un controllo delle impostazioni")
	_assert(screen.close_btn.focus_neighbor_bottom == screen._focus_chain[0].get_path(), "dall'ultima voce si dovrebbe tornare alla prima")
	_assert(screen._focus_chain[0].focus_neighbor_top == screen.close_btn.get_path(), "dalla prima voce si dovrebbe risalire all'ultima")

	print("Impostazioni: OK")
	screen.queue_free()
	await get_tree().process_frame
	SaveManager.settings = previous_settings
	SaveManager.save_data()

func _test_hub_settings_and_quit_entries() -> void:
	print("--- Test regressione: voci Impostazioni e uscita nell'Hub ---")
	var hub := Hub.new()
	add_child(hub)
	await get_tree().process_frame

	_assert(hub.settings_btn != null and hub.settings_btn.text == "Impostazioni", "l'Hub dovrebbe avere una voce Impostazioni")
	_assert(hub.quit_btn != null and hub.quit_btn.text == "Esci dal gioco", "l'Hub dovrebbe avere una voce per chiudere il gioco")

	# Nota: qui non si verifica a pixel che il menu stia nello schermo. In
	# headless il TextServer riporta altezze del testo circa doppie rispetto
	# al rendering reale (un Label alto 23px diventa 48px), quindi un
	# controllo del genere segnalerebbe uno sbordamento inesistente. Il
	# rientro del menu va verificato su uno screenshot vero.
	hub._open_settings()
	await get_tree().process_frame
	_assert(hub.settings_panel != null and hub.settings_panel.visible, "la voce Impostazioni non ha aperto la schermata")
	_assert(hub.start_btn.focus_mode == Control.FOCUS_NONE, "con le impostazioni aperte i pulsanti dell'Hub non devono essere selezionabili")
	_assert(hub.settings_btn.focus_mode == Control.FOCUS_NONE, "anche la voce Impostazioni va disattivata mentre il pannello è aperto")
	_assert(hub.quit_btn.focus_mode == Control.FOCUS_NONE, "anche la voce di uscita va disattivata mentre il pannello è aperto")
	_assert(hub.settings_panel.volume_slider.has_focus(), "all'apertura il focus dovrebbe partire dal primo controllo delle impostazioni")

	hub.settings_panel.closed.emit()
	await get_tree().process_frame
	_assert(not hub.settings_panel.visible, "chiudendo le impostazioni il pannello dovrebbe sparire")
	_assert(hub.start_btn.focus_mode == Control.FOCUS_ALL, "chiuse le impostazioni i pulsanti dell'Hub tornano selezionabili")
	_assert(hub.start_btn.has_focus(), "chiuse le impostazioni il focus dovrebbe tornare sull'Hub")

	print("Voci Impostazioni e uscita nell'Hub: OK")
	hub.queue_free()
	await get_tree().process_frame

func _test_dash_traded_for_ally_attacks() -> void:
	print("--- Test regressione: lo scatto sta sui pulsanti d'attacco e sparisce con il primo alleato ---")
	var trade_run := Run.new()
	add_child(trade_run)
	trade_run.begin_new_streak()
	await get_tree().process_frame

	for e in trade_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# Come negli altri test sugli alleati: un'esca lontana tiene la stanza
	# "non ripulita", altrimenti il giocatore verrebbe congelato.
	var decoy := Enemy.new()
	decoy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	decoy.global_position = trade_run.player.global_position + Vector2(600.0, 600.0)
	trade_run.enemy_container.add_child(decoy)

	var p: Player = trade_run.player
	_assert(p.has_dash(), "senza alleati il giocatore dovrebbe avere lo scatto")
	_assert(p.can_dash(), "senza alleati lo scatto dovrebbe essere utilizzabile")

	# Pulsante d'attacco libero -> scatto, con un evento joypad reale sul
	# dorsale destro (R1), non chiamando start_dash() a mano.
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_RIGHT_SHOULDER
	press.pressed = true
	Input.parse_input_event(press)
	for i in range(10):
		if p.is_dashing:
			break
		await get_tree().physics_frame
	_assert(p.is_dashing, "con gli slot liberi il dorsale destro dovrebbe eseguire lo scatto")
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_RIGHT_SHOULDER
	release.pressed = false
	Input.parse_input_event(release)
	# Lo scatto dura alcuni frame: si attende che finisca davvero, altrimenti
	# i controlli seguenti vedrebbero ancora attivo QUESTO scatto.
	for i in range(30):
		if not p.is_dashing:
			break
		await get_tree().physics_frame
	_assert(not p.is_dashing, "setup del test: lo scatto iniziale non è terminato")

	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	ally.global_position = p.global_position
	trade_run.enemy_container.add_child(ally)
	trade_run._on_tame_requested()
	_assert(p.granted_ability_ids[0] == "strisciante", "setup del test: l'alleato dovrebbe occupare il primo slot")
	_assert(not p.has_dash(), "con un alleato al seguito lo scatto non dovrebbe più esistere")
	_assert(not p.can_dash(), "con un alleato al seguito lo scatto non dovrebbe essere utilizzabile")
	_assert(p.granted_ability_ids[1] == "", "il secondo slot dovrebbe restare vuoto con un solo alleato")
	_assert(not p.can_use_special_attack(1), "il secondo pulsante dovrebbe restare inattivo, non tornare a scattare")

	# Un pulsante libero non deve più scattare mentre c'è un alleato.
	p.dash_charges = p.max_dash_charges
	var press_free := InputEventJoypadButton.new()
	press_free.device = 0
	press_free.button_index = JOY_BUTTON_LEFT_SHOULDER
	press_free.pressed = true
	Input.parse_input_event(press_free)
	for i in range(6):
		await get_tree().physics_frame
	_assert(not p.is_dashing, "il pulsante libero non deve scattare finché si ha un alleato")
	var release_free := InputEventJoypadButton.new()
	release_free.device = 0
	release_free.button_index = JOY_BUTTON_LEFT_SHOULDER
	release_free.pressed = false
	Input.parse_input_event(release_free)
	await get_tree().physics_frame

	# Le scelte di fine stanza non devono più proporre potenziamenti che
	# agiscono solo sullo scatto, finché lo scatto non c'è.
	var dashless_offers: Array = []
	for i in range(200):
		dashless_offers.append_array(trade_run._roll_powerup_choices(3))
	for offer in dashless_offers:
		_assert(not offer.get("needs_dash", false), "senza scatto non dovrebbe essere offerto il potenziamento da solo scatto '%s'" % offer.id)

	# Caduto l'alleato, lo scatto torna.
	ally.take_damage(99999.0)
	await get_tree().process_frame
	_assert(p.has_dash(), "perso l'ultimo alleato lo scatto dovrebbe tornare disponibile")

	# "Vincolo Spezzato": lo scatto resta anche con un alleato al seguito.
	var keeper := Enemy.new()
	keeper.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	keeper.global_position = p.global_position
	trade_run.enemy_container.add_child(keeper)
	p.apply_powerup("vincolo_spezzato")
	trade_run._on_tame_requested()
	_assert(p.granted_ability_ids[0] == "corazzato", "setup del test: il secondo alleato dovrebbe essere stato addomesticato")
	_assert(p.has_dash(), "con Vincolo Spezzato lo scatto dovrebbe restare anche con un alleato")

	print("Scatto barattato con gli attacchi degli alleati: OK")
	trade_run.queue_free()
	await get_tree().process_frame

func _test_run_music() -> void:
	print("--- Test regressione: sottofondo musicale solo durante la run, in loop ---")
	var music_run := Run.new()
	add_child(music_run)
	music_run.begin_new_streak()
	await get_tree().process_frame

	_assert(music_run.music_player != null, "la run dovrebbe avere un lettore per il sottofondo musicale")
	_assert(music_run.music_player.stream != null, "il brano di sottofondo non è stato caricato")
	_assert(music_run.music_player.stream is AudioStreamMP3, "il brano di sottofondo dovrebbe essere l'mp3 importato")
	_assert(music_run.music_player.stream.loop, "il brano di sottofondo deve ripartire in loop, non finire a metà run")
	# Il punto da cui riparte il loop salta l'introduzione, che si sente
	# una volta sola. Deve restare dentro la traccia: un valore oltre la
	# fine spezzerebbe il loop invece di accorciarlo.
	var loop_from: float = music_run.music_player.stream.loop_offset
	_assert(loop_from >= 0.0 and loop_from < music_run.music_player.stream.get_length(), "il punto di ripartenza del loop (%.1fs) deve cadere dentro la traccia (%.1fs)" % [loop_from, music_run.music_player.stream.get_length()])
	_assert(music_run.music_player.playing, "il sottofondo dovrebbe partire con la run")
	# Il lettore è figlio della run: tornando all'Hub la run viene liberata
	# e la musica si ferma con lei, senza gestione esterna.
	_assert(music_run.music_player.get_parent() == music_run, "il lettore deve essere figlio della run, cosí la musica finisce con essa")

	music_run.queue_free()
	await get_tree().process_frame

	# Nell'Hub non deve esserci sottofondo.
	var quiet_hub := Hub.new()
	add_child(quiet_hub)
	await get_tree().process_frame
	var hub_players := 0
	for c in quiet_hub.get_children():
		if c is AudioStreamPlayer:
			hub_players += 1
	_assert(hub_players == 0, "l'Hub non dovrebbe avere sottofondo musicale")
	quiet_hub.queue_free()
	await get_tree().process_frame

	print("Sottofondo musicale della run: OK")

func _test_pause_menu_settings() -> void:
	print("--- Test regressione: Impostazioni raggiungibili dal menu di pausa ---")
	var pause_run := Run.new()
	add_child(pause_run)
	pause_run.begin_new_streak()
	await get_tree().process_frame

	var pause: PauseScreen = pause_run.pause_screen
	pause._open()
	await get_tree().process_frame
	_assert(pause.visible and get_tree().paused, "setup del test: il menu di pausa dovrebbe essere aperto e il gioco in pausa")
	_assert(pause.settings_btn != null and pause.settings_btn.text == "Impostazioni", "il menu di pausa dovrebbe avere una voce Impostazioni")

	pause._open_settings()
	await get_tree().process_frame
	_assert(pause.settings_panel != null and pause.settings_panel.visible, "la voce Impostazioni non ha aperto la schermata")
	# A gioco in pausa la schermata deve continuare a ricevere input,
	# altrimenti resterebbe bloccata e nemmeno chiudibile.
	_assert(pause.settings_panel.process_mode == Node.PROCESS_MODE_ALWAYS, "le Impostazioni aperte in pausa devono restare attive a simulazione ferma")
	_assert(pause.resume_btn.focus_mode == Control.FOCUS_NONE, "con le Impostazioni aperte i pulsanti della pausa non devono essere selezionabili")
	_assert(pause.hub_btn.focus_mode == Control.FOCUS_NONE, "anche 'Torna all'Hub' va disattivato mentre le Impostazioni sono aperte")
	_assert(pause.settings_panel.volume_slider.has_focus(), "all'apertura il focus dovrebbe partire dal primo controllo delle Impostazioni")

	# Le impostazioni cambiate dalla pausa valgono davvero.
	pause.settings_panel.volume_slider.value = 0.35
	await get_tree().process_frame
	_assert(is_equal_approx(GameSettings.get_volume(), 0.35), "una modifica fatta dalla pausa dovrebbe essere applicata")
	pause.settings_panel.volume_slider.value = 1.0

	pause.settings_panel.closed.emit()
	await get_tree().process_frame
	_assert(not pause.settings_panel.visible, "chiudendo le Impostazioni il pannello dovrebbe sparire")
	_assert(get_tree().paused, "chiudendo le Impostazioni il gioco deve restare in pausa, non riprendere")
	_assert(pause.visible, "chiudendo le Impostazioni si deve tornare al menu di pausa")
	_assert(pause.resume_btn.focus_mode == Control.FOCUS_ALL and pause.resume_btn.has_focus(), "chiuse le Impostazioni il focus torna al menu di pausa")

	pause._close()
	await get_tree().process_frame
	_assert(not get_tree().paused, "il menu di pausa dovrebbe essersi chiuso correttamente")

	print("Impostazioni nel menu di pausa: OK")
	pause_run.queue_free()
	await get_tree().process_frame

func _test_ally_catchup_speed() -> void:
	print("--- Test regressione: un alleato rimasto indietro accelera esponenzialmente ---")
	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	ally.is_ally = true
	add_child(ally)
	ally.global_position = Vector2.ZERO
	var base: float = ally.speed

	# Vicino al giocatore nessuna accelerazione: si muove come sempre.
	_assert(is_equal_approx(ally.ally_follow_speed(Vector2(50.0, 0.0)), base), "vicino al giocatore l'alleato dovrebbe andare alla sua velocità normale")
	_assert(is_equal_approx(ally.ally_follow_speed(Vector2(Enemy.ALLY_CATCHUP_START, 0.0)), base), "alla soglia l'accelerazione non dovrebbe essere ancora partita")

	# Oltre la soglia raddoppia ogni ALLY_CATCHUP_DOUBLING pixel.
	var one_doubling: float = Enemy.ALLY_CATCHUP_START + Enemy.ALLY_CATCHUP_DOUBLING
	var two_doublings: float = Enemy.ALLY_CATCHUP_START + Enemy.ALLY_CATCHUP_DOUBLING * 2.0
	var at_one: float = ally.ally_follow_speed(Vector2(one_doubling, 0.0))
	var at_two: float = ally.ally_follow_speed(Vector2(two_doublings, 0.0))
	_assert(is_equal_approx(at_one, base * 2.0), "a un raddoppio di distanza la velocità dovrebbe essere doppia (attesa %.1f, trovata %.1f)" % [base * 2.0, at_one])
	_assert(is_equal_approx(at_two, base * 4.0), "a due raddoppi la velocità dovrebbe essere quadrupla (attesa %.1f, trovata %.1f)" % [base * 4.0, at_two])

	# La crescita è esponenziale, non lineare: il secondo tratto di
	# distanza aggiunge più velocità del primo.
	var gain_first: float = at_one - base
	var gain_second: float = at_two - at_one
	_assert(gain_second > gain_first, "la crescita dovrebbe essere esponenziale: il secondo tratto deve valere più del primo (%.1f contro %.1f)" % [gain_second, gain_first])

	# Il tetto evita che l'inseguimento diventi un teletrasporto.
	var very_far: float = ally.ally_follow_speed(Vector2(100000.0, 0.0))
	_assert(is_equal_approx(very_far, base * Enemy.ALLY_CATCHUP_MAX_MULT), "a distanza enorme la velocità dovrebbe fermarsi al tetto")

	# Anche il tipo più lento deve poter superare il giocatore quando è
	# molto lontano, altrimenti non lo raggiungerebbe mai.
	var player_speed: float = Player.BASE_SPEED
	_assert(base * Enemy.ALLY_CATCHUP_MAX_MULT > player_speed, "al massimo dell'inseguimento anche l'alleato più lento deve superare il giocatore (%.1f contro %.1f)" % [base * Enemy.ALLY_CATCHUP_MAX_MULT, player_speed])

	ally.queue_free()
	await get_tree().process_frame

	# Verifica sul movimento reale: due alleati identici, uno vicino e uno
	# lontano dal giocatore, devono coprire distanze diverse nello stesso
	# tempo (niente labirinto e nessun nemico, cosí si misura solo questo).
	var move_run := Run.new()
	add_child(move_run)
	move_run.begin_new_streak()
	await get_tree().process_frame
	for e in move_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame
	move_run.current_maze = null
	move_run.player.maze = null

	var player_pos: Vector2 = move_run.player.global_position
	var near_ally := _spawn_follower(move_run, player_pos + Vector2(Enemy.ALLY_CATCHUP_START + 20.0, 0.0))
	var far_ally := _spawn_follower(move_run, player_pos + Vector2(Enemy.ALLY_CATCHUP_START + Enemy.ALLY_CATCHUP_DOUBLING * 2.0, 0.0))
	var near_before: float = near_ally.global_position.distance_to(player_pos)
	var far_before: float = far_ally.global_position.distance_to(player_pos)
	for i in range(20):
		await get_tree().physics_frame
	var near_closed: float = near_before - near_ally.global_position.distance_to(player_pos)
	var far_closed: float = far_before - far_ally.global_position.distance_to(player_pos)
	print("Distanza recuperata in 20 frame: vicino %.1f, lontano %.1f" % [near_closed, far_closed])
	_assert(near_closed > 0.0 and far_closed > 0.0, "entrambi gli alleati dovrebbero avvicinarsi al giocatore")
	_assert(far_closed > near_closed * 1.5, "l'alleato più lontano dovrebbe recuperare molto più in fretta (%.1f contro %.1f)" % [far_closed, near_closed])

	print("Accelerazione di inseguimento degli alleati: OK")
	move_run.queue_free()
	await get_tree().process_frame

# Alleato "puro" usato per misurare il solo inseguimento: nessun nemico
# intorno, quindi segue sempre e solo il giocatore.
func _spawn_follower(run_node: Run, pos: Vector2) -> Enemy:
	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	ally.is_ally = true
	ally.maze = null
	run_node.enemy_container.add_child(ally)
	ally.global_position = pos
	return ally

func _test_hostiles_attack_allies() -> void:
	print("--- Test regressione: i nemici ostili se la prendono anche con gli alleati ---")
	var aggro_run := Run.new()
	add_child(aggro_run)
	aggro_run.begin_new_streak()
	await get_tree().process_frame

	for e in aggro_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame
	# Senza labirinto: qui interessa la scelta del bersaglio, non il
	# percorso tra i corridoi.
	aggro_run.current_maze = null
	aggro_run.player.maze = null

	var player_pos: Vector2 = aggro_run.player.global_position

	# Un alleato mandato avanti, il giocatore che resta indietro.
	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	ally.global_position = player_pos
	aggro_run.enemy_container.add_child(ally)
	aggro_run._on_tame_requested()
	_assert(ally.is_ally, "setup del test: il nemico avrebbe dovuto diventare alleato")
	_assert(ally.is_in_group("ally"), "un alleato deve entrare nel gruppo consultato dagli avversari")
	ally.maze = null
	ally.global_position = player_pos + Vector2(500.0, 0.0)

	# Un nemico ostile piazzato accanto all'alleato e lontano dal giocatore.
	var hostile := Enemy.new()
	hostile.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	hostile.global_position = ally.global_position + Vector2(120.0, 0.0)
	aggro_run.enemy_container.add_child(hostile)
	await get_tree().physics_frame

	var target: Node = hostile.update_hostile_target(0.0)
	_assert(target == ally, "il nemico dovrebbe prendersela con l'alleato, che è molto più vicino del giocatore")

	# E deve avvicinarglisi davvero, non solo "puntarlo".
	var dist_before: float = hostile.global_position.distance_to(ally.global_position)
	for i in range(30):
		await get_tree().physics_frame
	var dist_after: float = hostile.global_position.distance_to(ally.global_position)
	_assert(dist_after < dist_before, "il nemico non si è avvicinato all'alleato (%.1f -> %.1f)" % [dist_before, dist_after])

	# Il bersaglio non deve ballare tra due candidati quasi equidistanti:
	# il giocatore appena più vicino dell'alleato non basta a rubare
	# l'attenzione (serve un vantaggio di TARGET_SWITCH_MARGIN).
	var margin: float = CombatEntity.TARGET_SWITCH_MARGIN
	ally.global_position = hostile.global_position + Vector2(300.0, 0.0)
	aggro_run.player.global_position = hostile.global_position + Vector2(0.0, 300.0 - margin * 0.5)
	hostile.current_target = ally
	hostile.target_recheck_timer = 0.0
	_assert(hostile.update_hostile_target(0.0) == ally, "un bersaglio appena più vicino non dovrebbe rubare l'attenzione")

	# Se invece il giocatore è nettamente più vicino, il nemico cambia idea.
	aggro_run.player.global_position = hostile.global_position + Vector2(0.0, 300.0 - margin * 2.0)
	hostile.target_recheck_timer = 0.0
	_assert(hostile.update_hostile_target(0.0) == aggro_run.player, "con il giocatore nettamente più vicino il nemico dovrebbe tornare su di lui")

	# Morto l'alleato, il nemico torna a occuparsi del giocatore anche se
	# il tempo di ricontrollo non è ancora scaduto.
	hostile.current_target = ally
	hostile.target_recheck_timer = 99.0
	ally.take_damage(99999.0)
	await get_tree().process_frame
	_assert(hostile.update_hostile_target(0.0) == aggro_run.player, "caduto l'alleato il nemico deve tornare sul giocatore senza aspettare")

	print("Aggressività verso gli alleati: OK")
	aggro_run.queue_free()
	await get_tree().process_frame

func _test_boss_attacks_allies() -> void:
	print("--- Test regressione: anche il boss se la prende con gli alleati ---")
	var boss_run := Run.new()
	add_child(boss_run)
	boss_run.begin_new_streak()
	await get_tree().process_frame

	for e in boss_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame
	boss_run.current_maze = null
	boss_run.player.maze = null

	var player_pos: Vector2 = boss_run.player.global_position
	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	ally.global_position = player_pos
	boss_run.enemy_container.add_child(ally)
	boss_run._on_tame_requested()
	ally.maze = null
	ally.global_position = player_pos + Vector2(600.0, 0.0)

	var boss := Boss.new()
	boss.setup_from_data(GameData.BOSSES["custode"])
	boss.global_position = ally.global_position + Vector2(150.0, 0.0)
	boss_run.boss_container.add_child(boss)
	boss_run.current_boss = boss
	await get_tree().physics_frame

	_assert(boss.update_hostile_target(0.0) == ally, "il boss dovrebbe puntare l'alleato, molto più vicino del giocatore")

	# Il colpo al suolo del boss non distingue amici da nemici.
	var ally_hp_before: float = ally.hp
	boss_run._on_boss_melee_aoe(ally.global_position, 120.0, 25.0)
	_assert(ally.hp < ally_hp_before, "il colpo ad area del boss dovrebbe danneggiare anche un alleato nel raggio")

	print("Aggressività del boss verso gli alleati: OK")
	boss_run.queue_free()
	await get_tree().process_frame

func _test_special_attack_pacing() -> void:
	print("--- Test bilanciamento: ritmo e danno di ogni tipo di attacco speciale ---")
	var pace_run := Run.new()
	add_child(pace_run)
	pace_run.begin_new_streak()
	await get_tree().process_frame

	var p: Player = pace_run.player
	var melee: float = p.special_attack_cooldown("strisciante")
	var ranged: float = p.special_attack_cooldown("pungiglione")
	var aoe: float = p.special_attack_cooldown("corazzato")
	var burst: float = p.special_attack_cooldown("sciame")

	# Ogni attacco deve tornare pronto molto più in fretta del vecchio
	# recupero unico da 6 secondi, che li rendeva inutilizzabili come
	# attacco principale.
	for entry in GameData.ALLY_SPECIAL_ATTACKS.keys():
		var cd: float = p.special_attack_cooldown(entry)
		_assert(cd <= 2.5, "il recupero di %s è ancora troppo lungo (%.2fs)" % [entry, cd])

	# I ruoli: a distanza il più rapido, corpo a corpo il più lento, area
	# nel mezzo.
	_assert(ranged < aoe, "l'attacco a distanza dovrebbe tornare pronto prima di quello ad area (%.2f vs %.2f)" % [ranged, aoe])
	_assert(aoe < melee, "l'attacco ad area dovrebbe tornare pronto prima di quello in corpo a corpo (%.2f vs %.2f)" % [aoe, melee])
	_assert(burst < aoe, "la raffica circolare è un attacco a distanza: dovrebbe essere più rapida di quello ad area (%.2f vs %.2f)" % [burst, aoe])

	# Il danno segue il ruolo opposto: pochi colpi forti in mischia, tanti
	# colpi deboli a distanza.
	_assert(Run.LUNGE_DAMAGE > Run.SLAM_DAMAGE, "il morso in corpo a corpo dovrebbe fare più danno dell'onda d'urto")
	_assert(Run.SLAM_DAMAGE > Run.DART_DAMAGE, "l'onda d'urto dovrebbe fare più danno del singolo dardo")
	_assert(Run.SWARM_DAMAGE < Run.DART_DAMAGE, "i proiettili della raffica circolare dovrebbero essere i più deboli")

	# Un colpo in corpo a corpo deve stendere un nemico comune di base: è
	# il senso di "tanto danno, pochi colpi".
	_assert(Run.LUNGE_DAMAGE >= float(GameData.ENEMY_TYPES["strisciante"].hp), "un Morso Selvaggio dovrebbe bastare a stendere uno Strisciante")

	# Il danno al secondo di ogni attacco deve reggere il confronto con
	# l'attacco base: senza scatto sono l'unica offesa rimasta.
	var dash_dps: float = Player.BASE_DASH_DAMAGE / p.dash_cooldown()
	var dps := {
		"strisciante": Run.LUNGE_DAMAGE / melee,
		"pungiglione": Run.DART_DAMAGE / ranged,
		"corazzato": Run.SLAM_DAMAGE / aoe,
		"sciame": Run.SWARM_DAMAGE / burst,
	}
	print("Danno al secondo (bersaglio singolo): scatto %.1f, %s" % [dash_dps, dps])
	for ability_id in dps.keys():
		_assert(dps[ability_id] >= dash_dps * 0.15, "%s resta troppo debole rispetto allo scatto (%.1f contro %.1f al secondo)" % [ability_id, dps[ability_id], dash_dps])

	print("Ritmo e danno degli attacchi speciali: OK")
	pace_run.queue_free()
	await get_tree().process_frame

func _test_ally_powerups() -> void:
	print("--- Test regressione: i potenziamenti dedicati ad alleati e attacchi speciali ---")
	var pw_run := Run.new()
	add_child(pw_run)
	pw_run.begin_new_streak()
	await get_tree().process_frame

	for e in pw_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	var decoy := Enemy.new()
	decoy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	decoy.global_position = pw_run.player.global_position + Vector2(600.0, 600.0)
	pw_run.enemy_container.add_child(decoy)

	var p: Player = pw_run.player
	var base_tame: float = p.tame_cooldown()
	var base_special: float = p.special_attack_cooldown("corazzato")

	p.apply_powerup("richiamo_rapido")
	_assert(p.tame_cooldown() < base_tame, "Richiamo Rapido dovrebbe ridurre il recupero dell'addomesticamento")
	p.apply_powerup("eco_selvaggia")
	_assert(p.special_attack_cooldown("corazzato") < base_special, "Eco Selvaggia dovrebbe ridurre il recupero degli attacchi speciali")

	p.apply_powerup("passo_del_predatore")
	var solo_speed: float = p.current_speed_mult()
	_assert(is_equal_approx(solo_speed, p.speed_mult), "Passo del Predatore non dovrebbe dare velocità extra senza alleati")

	# Bonus applicati a un alleato addomesticato DOPO averli raccolti.
	p.apply_powerup("pelle_coriacea")
	p.apply_powerup("istinto_di_branco")
	var base_data: Dictionary = GameData.ENEMY_TYPES["strisciante"]
	var ally := Enemy.new()
	ally.setup_from_data(base_data, false)
	ally.global_position = p.global_position
	pw_run.enemy_container.add_child(ally)
	pw_run._on_tame_requested()
	_assert(ally.is_ally, "setup del test: il nemico dovrebbe essere diventato alleato")
	_assert(ally.max_hp > float(base_data.hp), "Pelle Coriacea dovrebbe aver aumentato la vita massima dell'alleato (%.1f vs %.1f)" % [ally.max_hp, float(base_data.hp)])
	_assert(ally.damage > float(base_data.damage), "Istinto di Branco dovrebbe aver aumentato il danno dell'alleato (%.1f vs %.1f)" % [ally.damage, float(base_data.damage)])
	_assert(p.current_speed_mult() > p.speed_mult, "Passo del Predatore dovrebbe dare velocità extra con un alleato al seguito")

	# Un potenziamento raccolto DOPO deve raggiungere anche gli alleati già
	# al seguito, ricalcolando sempre dai valori base (niente accumulo
	# esponenziale raccogliendolo due volte).
	var hp_after_first: float = ally.max_hp
	pw_run._on_powerup_selected("pelle_coriacea")
	_assert(ally.max_hp > hp_after_first, "un potenziamento raccolto dopo dovrebbe aggiornare anche gli alleati già al seguito")
	_assert(is_equal_approx(ally.max_hp, float(base_data.hp) * p.ally_hp_mult), "la vita dell'alleato dovrebbe essere ricalcolata dal valore base per il moltiplicatore corrente")

	# "Vincolo Vitale": la caduta di un alleato cura e azzera il recupero.
	p.apply_powerup("vincolo_vitale")
	p.hp = 10.0
	p.tame_cooldown_timer = 9.0
	ally.take_damage(99999.0)
	await get_tree().process_frame
	_assert(p.hp > 10.0, "Vincolo Vitale dovrebbe curare alla caduta di un alleato")
	_assert(p.tame_cooldown_timer == 0.0, "Vincolo Vitale dovrebbe azzerare il recupero dell'addomesticamento")

	# "Anima del Branco": l'attacco speciale è sempre potenziato. Si osserva
	# dal numero di proiettili dello Sciame, che in versione potenziata ne
	# spara EMPOWERED_SWARM_COUNT invece di SWARM_COUNT.
	p.apply_powerup("anima_del_branco")
	for c in pw_run.projectile_container.get_children():
		c.queue_free()
	await get_tree().process_frame
	pw_run._on_special_attack_requested("sciame", p.global_position, Vector2.RIGHT, false)
	_assert(pw_run.projectile_container.get_child_count() == GameData.EMPOWERED_SWARM_COUNT, "con Anima del Branco lo Sciame dovrebbe sparare %d proiettili anche senza alleato gemello, trovati %d" % [GameData.EMPOWERED_SWARM_COUNT, pw_run.projectile_container.get_child_count()])

	# "Zanne Affilate": più danno negli attacchi speciali.
	var target := Enemy.new()
	target.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	target.global_position = p.global_position
	pw_run.enemy_container.add_child(target)
	var hp_before: float = target.hp
	pw_run._on_special_attack_requested("corazzato", p.global_position, Vector2.RIGHT, false)
	var plain_damage: float = hp_before - target.hp
	target.hp = target.max_hp
	p.apply_powerup("zanne_affilate")
	hp_before = target.hp
	pw_run._on_special_attack_requested("corazzato", p.global_position, Vector2.RIGHT, false)
	var buffed_damage: float = hp_before - target.hp
	_assert(buffed_damage > plain_damage, "Zanne Affilate dovrebbe aumentare il danno dell'attacco speciale (%.1f vs %.1f)" % [buffed_damage, plain_damage])

	print("Potenziamenti di alleati e attacchi speciali: OK")
	pw_run.queue_free()
	await get_tree().process_frame

func _test_ally_special_attack_empowered_duplicate() -> void:
	print("--- Test regressione: 2 alleati dello stesso tipo condividono uno slot potenziato ---")
	var dup_run := Run.new()
	add_child(dup_run)
	dup_run.begin_new_streak()
	await get_tree().process_frame

	for e in dup_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame

	# Nemico "esca" mai coinvolto, per lo stesso motivo del test precedente:
	# evita che la stanza risulti ripulita (e il giocatore congelato) come
	# effetto collaterale dell'addomesticamento durante questo test.
	var decoy := Enemy.new()
	decoy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	decoy.global_position = dup_run.player.global_position + Vector2(600.0, 600.0)
	dup_run.enemy_container.add_child(decoy)

	var first_ally := Enemy.new()
	first_ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	first_ally.global_position = dup_run.player.global_position
	dup_run.enemy_container.add_child(first_ally)
	dup_run.player.global_position = first_ally.global_position
	dup_run._on_tame_requested()

	var second_ally := Enemy.new()
	second_ally.setup_from_data(GameData.ENEMY_TYPES["corazzato"], false)
	second_ally.global_position = dup_run.player.global_position
	dup_run.enemy_container.add_child(second_ally)
	dup_run._on_tame_requested()

	_assert(dup_run.player.granted_ability_ids[0] == "corazzato", "il primo slot dovrebbe restare assegnato al tipo condiviso")
	_assert(dup_run.player.granted_ability_ids[1] == "", "il secondo slot dovrebbe restare vuoto quando i due alleati sono dello stesso tipo")
	_assert(dup_run.player.special_attack_empowered[0], "con 2 alleati dello stesso tipo l'unico slot dovrebbe risultare potenziato")

	# Se uno dei due gemelli muore, resta un solo alleato di quel tipo:
	# l'abilità deve tornare alla versione normale (non più potenziata).
	second_ally.take_damage(99999.0)
	_assert(dup_run.player.granted_ability_ids[0] == "corazzato", "il tipo condiviso dovrebbe restare assegnato con un alleato superstite")
	_assert(not dup_run.player.special_attack_empowered[0], "con un solo alleato superstite l'attacco non dovrebbe più essere potenziato")

	print("Attacco speciale potenziato su alleati gemelli: OK")
	dup_run.queue_free()
	await get_tree().process_frame

func _spawn_damage_dummy(container: Node, pos: Vector2) -> Enemy:
	# Bersaglio "sacco da colpi": un nemico comune con una riserva di vita
	# enorme. Serve per misurare il danno DAVVERO inflitto da un attacco:
	# con la vita normale di un nemico comune un colpo forte la azzererebbe
	# e la misura risulterebbe troncata, facendo sembrare uguali due
	# attacchi di potenza diversa.
	var dummy := Enemy.new()
	dummy.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	dummy.max_hp = 100000.0
	dummy.hp = dummy.max_hp
	dummy.global_position = pos
	container.add_child(dummy)
	return dummy

func _test_ally_special_attack_effects() -> void:
	print("--- Test regressione: gli attacchi speciali degli alleati infliggono danno reale ---")
	var fx_run := Run.new()
	add_child(fx_run)
	fx_run.begin_new_streak()
	await get_tree().process_frame

	for e in fx_run.enemy_container.get_children():
		e.queue_free()
	await get_tree().process_frame
	# Niente labirinto per questo test: con la mappa reale il percorso in
	# linea retta di un proiettile potrebbe attraversare un muro (vedi
	# nota analoga in _test_ranged_ally_keeps_behavior), rendendo
	# imprevedibile se Dardo Velenoso/Sciame Vendicativo raggiungono il
	# bersaglio.
	fx_run.current_maze = null

	var player_pos: Vector2 = fx_run.player.global_position
	var dir := Vector2.RIGHT

	# Morso Selvaggio (strisciante): mischia davanti al giocatore.
	var lunge_target := _spawn_damage_dummy(fx_run.enemy_container, player_pos + dir * fx_run.LUNGE_OFFSET)
	var lunge_hp_before: float = lunge_target.hp
	fx_run._on_special_attack_requested("strisciante", player_pos, dir)
	_assert(lunge_target.hp < lunge_hp_before, "Morso Selvaggio non ha danneggiato il nemico davanti al giocatore")
	var lunge_dmg: float = lunge_hp_before - lunge_target.hp
	lunge_target.queue_free()
	await get_tree().process_frame

	# Versione potenziata di Morso Selvaggio: stesso bersaglio/posizione,
	# ma deve infliggere più danno (EMPOWERED_DAMAGE_MULT) della versione base.
	var lunge_target_emp := _spawn_damage_dummy(fx_run.enemy_container, player_pos + dir * fx_run.LUNGE_OFFSET)
	var lunge_hp_before_emp: float = lunge_target_emp.hp
	fx_run._on_special_attack_requested("strisciante", player_pos, dir, true)
	var lunge_dmg_emp: float = lunge_hp_before_emp - lunge_target_emp.hp
	_assert(lunge_dmg_emp > lunge_dmg, "Morso Selvaggio potenziato dovrebbe infliggere più danno della versione base (base=%.1f potenziato=%.1f)" % [lunge_dmg, lunge_dmg_emp])
	lunge_target_emp.queue_free()
	await get_tree().process_frame

	# Colpo Corazzato (corazzato): danno ad area intorno al giocatore.
	var slam_target := _spawn_damage_dummy(fx_run.enemy_container, player_pos + Vector2(fx_run.SLAM_RADIUS - 10.0, 0.0))
	var slam_hp_before: float = slam_target.hp
	fx_run._on_special_attack_requested("corazzato", player_pos, dir)
	_assert(slam_target.hp < slam_hp_before, "Colpo Corazzato non ha danneggiato il nemico nei paraggi del giocatore")
	var slam_dmg: float = slam_hp_before - slam_target.hp
	slam_target.queue_free()
	await get_tree().process_frame

	# Versione potenziata di Colpo Corazzato: stesso danno base atteso più
	# alto di EMPOWERED_DAMAGE_MULT rispetto alla versione normale.
	var slam_target_emp := _spawn_damage_dummy(fx_run.enemy_container, player_pos + Vector2(fx_run.SLAM_RADIUS - 10.0, 0.0))
	var slam_hp_before_emp: float = slam_target_emp.hp
	fx_run._on_special_attack_requested("corazzato", player_pos, dir, true)
	var slam_dmg_emp: float = slam_hp_before_emp - slam_target_emp.hp
	_assert(slam_dmg_emp > slam_dmg, "Colpo Corazzato potenziato dovrebbe infliggere più danno della versione base (base=%.1f potenziato=%.1f)" % [slam_dmg, slam_dmg_emp])
	slam_target_emp.queue_free()
	await get_tree().process_frame

	# Dardo Velenoso (pungiglione): proiettile singolo, serve fisica reale.
	var dart_target := Enemy.new()
	dart_target.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	dart_target.global_position = player_pos + dir * 200.0
	fx_run.enemy_container.add_child(dart_target)
	var dart_hp_before: float = dart_target.hp
	var dart_count_before: int = fx_run.projectile_container.get_child_count()
	fx_run._on_special_attack_requested("pungiglione", player_pos, dir)
	_assert(fx_run.projectile_container.get_child_count() - dart_count_before == 1, "Dardo Velenoso normale dovrebbe generare un solo proiettile")
	for i in range(60):
		await get_tree().physics_frame
		if dart_target.hp < dart_hp_before:
			break
	_assert(dart_target.hp < dart_hp_before, "Dardo Velenoso non ha mai raggiunto/danneggiato il bersaglio")
	dart_target.queue_free()
	fx_run._clear_container(fx_run.projectile_container)
	await get_tree().process_frame

	# Versione potenziata di Dardo Velenoso: un secondo dardo in più
	# (invece di raddoppiare il danno di un singolo colpo).
	var dart_count_before_emp: int = fx_run.projectile_container.get_child_count()
	fx_run._on_special_attack_requested("pungiglione", player_pos, dir, true)
	_assert(fx_run.projectile_container.get_child_count() - dart_count_before_emp == 2, "Dardo Velenoso potenziato dovrebbe generare due proiettili")
	fx_run._clear_container(fx_run.projectile_container)
	await get_tree().process_frame

	# Sciame Vendicativo (sciame): raffica a ventaglio; un bersaglio
	# sull'angolo 0 (direzione (1, 0), il primo dei proiettili) viene
	# colpito con certezza.
	var swarm_target := Enemy.new()
	swarm_target.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	swarm_target.global_position = player_pos + Vector2(150.0, 0.0)
	fx_run.enemy_container.add_child(swarm_target)
	var swarm_hp_before: float = swarm_target.hp
	var swarm_count_before: int = fx_run.projectile_container.get_child_count()
	fx_run._on_special_attack_requested("sciame", player_pos, dir)
	_assert(fx_run.projectile_container.get_child_count() - swarm_count_before == fx_run.SWARM_COUNT, "Sciame Vendicativo normale dovrebbe generare SWARM_COUNT proiettili")
	for i in range(60):
		await get_tree().physics_frame
		if swarm_target.hp < swarm_hp_before:
			break
	_assert(swarm_target.hp < swarm_hp_before, "Sciame Vendicativo non ha mai raggiunto/danneggiato il bersaglio")
	swarm_target.queue_free()
	fx_run._clear_container(fx_run.projectile_container)
	await get_tree().process_frame

	# Versione potenziata di Sciame Vendicativo: più proiettili
	# (EMPOWERED_SWARM_COUNT invece di SWARM_COUNT).
	var swarm_count_before_emp: int = fx_run.projectile_container.get_child_count()
	fx_run._on_special_attack_requested("sciame", player_pos, dir, true)
	_assert(fx_run.projectile_container.get_child_count() - swarm_count_before_emp == GameData.EMPOWERED_SWARM_COUNT, "Sciame Vendicativo potenziato dovrebbe generare EMPOWERED_SWARM_COUNT proiettili")
	fx_run._clear_container(fx_run.projectile_container)
	await get_tree().process_frame

	print("Effetti degli attacchi speciali: OK")
	fx_run.queue_free()
	await get_tree().process_frame

func _test_special_attack_visual_effects() -> void:
	print("--- Test regressione: gli attacchi speciali generano un effetto visivo riconoscibile ---")
	var vfx_run := Run.new()
	add_child(vfx_run)
	vfx_run.begin_new_streak()
	await get_tree().process_frame
	vfx_run.current_maze = null

	var player_pos: Vector2 = vfx_run.player.global_position
	for ability_id in ["strisciante", "corazzato", "pungiglione", "sciame"]:
		var effect_count_before: int = vfx_run.effect_container.get_child_count()
		vfx_run._on_special_attack_requested(ability_id, player_pos, Vector2.RIGHT)
		_assert(vfx_run.effect_container.get_child_count() > effect_count_before, "%s non ha generato alcun effetto visivo in effect_container" % ability_id)
		var effect = vfx_run.effect_container.get_child(vfx_run.effect_container.get_child_count() - 1)
		_assert(effect is SpecialAttackEffect, "il nodo generato in effect_container non è un SpecialAttackEffect (%s)" % ability_id)
		_assert(effect.color == GameData.ENEMY_TYPES[ability_id].color, "l'effetto visivo di %s non usa il colore a tema dell'alleato" % ability_id)
	vfx_run._clear_container(vfx_run.effect_container)
	vfx_run._clear_container(vfx_run.projectile_container)
	await get_tree().process_frame

	# Gli effetti sono puramente decorativi e temporanei: si autodistruggono
	# da soli entro la propria durata, senza bisogno di ripulitura esterna.
	var short_effect := SpecialAttackEffect.new()
	short_effect.setup(SpecialAttackEffect.Kind.RING, Color.WHITE, 20.0, 0.05)
	vfx_run.effect_container.add_child(short_effect)
	for i in range(30):
		await get_tree().process_frame
		if not is_instance_valid(short_effect):
			break
	_assert(not is_instance_valid(short_effect), "l'effetto visivo dovrebbe autodistruggersi alla fine della propria durata")

	# I proiettili degli attacchi speciali del giocatore (Dardo Velenoso,
	# Sciame Vendicativo) usano il colore a tema dell'alleato invece del
	# colore generico dei proiettili nemici, per restare riconoscibili.
	var default_color := Color8(224, 102, 63)
	vfx_run._on_special_attack_requested("pungiglione", player_pos, Vector2.RIGHT)
	var dart := vfx_run.projectile_container.get_child(vfx_run.projectile_container.get_child_count() - 1)
	_assert(dart.color == GameData.ENEMY_TYPES["pungiglione"].color, "Dardo Velenoso dovrebbe usare il colore a tema del Pungiglione")
	_assert(dart.color != default_color, "Dardo Velenoso non dovrebbe usare il colore generico dei proiettili nemici")
	vfx_run._clear_container(vfx_run.projectile_container)
	vfx_run._clear_container(vfx_run.effect_container)
	await get_tree().process_frame

	print("Effetti visivi degli attacchi speciali: OK")
	vfx_run.queue_free()
	await get_tree().process_frame

func _test_special_attack_key_bindings() -> void:
	print("--- Test regressione: addomesticamento e attacchi speciali su pulsanti distinti ---")
	_assert(_action_has_key("tame", KEY_F), "l'azione tame non ha un binding per il tasto F")
	_assert(_action_has_joypad_button("tame", JOY_BUTTON_X), "l'azione tame non ha un binding per il tasto X del controller")
	_assert(_action_has_key("special_attack", KEY_E), "l'azione special_attack non ha un binding per il tasto E")
	_assert(_action_has_joypad_button("special_attack", JOY_BUTTON_RIGHT_SHOULDER), "l'azione special_attack non ha un binding per il dorsale destro (R1/RB) del controller")
	_assert(_action_has_key("special_attack_2", KEY_Q), "l'azione special_attack_2 non ha un binding per il tasto Q")
	_assert(_action_has_joypad_button("special_attack_2", JOY_BUTTON_LEFT_SHOULDER), "l'azione special_attack_2 non ha un binding per il dorsale sinistro (L1/LB) del controller")
	print("Binding addomesticamento/attacchi speciali su pulsanti distinti: OK")

func _test_room_clear_freezes_player_and_clears_projectiles() -> void:
	print("--- Test regressione: la pulizia della stanza ferma il giocatore e rimuove i proiettili in volo ---")
	var freeze_run := Run.new()
	add_child(freeze_run)
	freeze_run.begin_new_streak()
	await get_tree().process_frame

	# Un proiettile ostile in volo, indipendente dai nemici della stanza.
	# La stanza viene svuotata dai proiettili prima: se è stato generato un
	# nemico a distanza, può averne già sparato uno di suo e il conteggio
	# non sarebbe più quello del solo proiettile di questo test.
	freeze_run._clear_container(freeze_run.projectile_container)
	await get_tree().process_frame
	freeze_run._on_enemy_spawn_projectile(freeze_run.player.global_position + Vector2(300.0, 0.0), Vector2.LEFT, 50.0, 5.0)
	_assert(freeze_run.projectile_container.get_child_count() == 1, "setup del test: il proiettile ostile dovrebbe essere presente")
	_assert(not freeze_run.player.frozen, "setup del test: il giocatore non dovrebbe partire congelato")
	var pos_before: Vector2 = freeze_run.player.global_position

	_kill_all_room_enemies_of(freeze_run)
	await get_tree().process_frame

	_assert(freeze_run.room_cleared, "setup del test: la stanza dovrebbe risultare ripulita")
	_assert(freeze_run.player.frozen, "la pulizia della stanza dovrebbe congelare il giocatore")
	_assert(freeze_run.projectile_container.get_child_count() == 0, "la pulizia della stanza dovrebbe rimuovere ogni proiettile in volo")
	_assert(not freeze_run.player.can_dash(), "il giocatore congelato non dovrebbe poter scattare")
	_assert(not freeze_run.player.can_tame(), "il giocatore congelato non dovrebbe poter addomesticare")

	for i in range(5):
		await get_tree().physics_frame
	_assert(freeze_run.player.global_position == pos_before, "il giocatore congelato non dovrebbe muoversi")

	# Scegliendo il potenziamento e passando alla stanza successiva il
	# giocatore riprende il controllo.
	var choice: Dictionary = GameData.get_regular_powerup_pool()[0]
	freeze_run._on_powerup_selected(choice.id)
	_assert(not freeze_run.player.frozen, "il giocatore dovrebbe riprendere il controllo nella stanza successiva")

	print("Congelamento del giocatore e pulizia dei proiettili alla fine stanza: OK")
	freeze_run.queue_free()
	await get_tree().process_frame

func _test_boss_defeat_freezes_player_and_clears_projectiles() -> void:
	print("--- Test regressione: la sconfitta del boss ferma il giocatore e rimuove i proiettili in volo ---")
	var boss_run := Run.new()
	add_child(boss_run)
	boss_run.begin_new_streak()
	await get_tree().process_frame

	boss_run._start_boss_room()
	await get_tree().process_frame
	_assert(not boss_run.player.frozen, "setup del test: il giocatore non dovrebbe partire congelato nella sala del boss")

	# Un proiettile del boss ancora in volo al momento della sconfitta.
	boss_run._on_enemy_spawn_projectile(boss_run.player.global_position + Vector2(300.0, 0.0), Vector2.LEFT, 50.0, 5.0)
	_assert(boss_run.projectile_container.get_child_count() == 1, "setup del test: il proiettile del boss dovrebbe essere presente")

	var boss = boss_run.current_boss
	boss.take_damage(99999.0)
	boss_run._on_enemy_defeated(boss)
	await get_tree().process_frame

	_assert(boss_run.run_complete_screen.visible, "setup del test: la schermata di fine run dovrebbe comparire")
	_assert(boss_run.player.frozen, "la sconfitta del boss dovrebbe congelare il giocatore")
	_assert(boss_run.projectile_container.get_child_count() == 0, "la sconfitta del boss dovrebbe rimuovere ogni proiettile in volo")

	boss_run._on_continue_pressed()
	_assert(not boss_run.player.frozen, "il giocatore dovrebbe riprendere il controllo continuando la serie")

	print("Congelamento del giocatore e pulizia dei proiettili alla sconfitta del boss: OK")
	boss_run.queue_free()
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

func _test_hub_subpanel_navigation() -> void:
	print("--- Test regressione: Archivio/Bestiario/Tutorial si scorrono senza spostare il focus ---")
	# La navigazione a focus tra le righe (basata sulla posizione a
	# schermo dei controlli) si è rivelata inaffidabile/confusa da
	# controller in questi pannelli: niente più righe navigabili. Lo
	# stick/D-pad su/giù scorre direttamente la vista leggendo
	# move_up/move_down (la stessa azione, con binding joypad già
	# verificati, usata per muovere il giocatore in game), senza mai
	# toccare il focus: l'unico controllo selezionabile resta Chiudi, che
	# quindi non può mai "saltare" altrove.
	var nav_hub := Hub.new()
	add_child(nav_hub)
	await get_tree().process_frame
	_assert(nav_hub.start_btn.focus_mode == Control.FOCUS_ALL, "setup del test: i pulsanti dell'Hub dovrebbero essere navigabili prima di aprire un pannello")

	# Aprendo un pannello sopra l'Hub, i suoi pulsanti (nascosti solo
	# visivamente dallo sfondo opaco del pannello, ma ancora nell'albero)
	# non devono restare candidati per la risoluzione del focus da
	# tastiera/controller.
	nav_hub._open_archive()
	await get_tree().process_frame
	_assert(nav_hub.start_btn.focus_mode == Control.FOCUS_NONE, "i pulsanti dell'Hub dovrebbero smettere di essere navigabili con l'Archivio aperto")
	_assert(nav_hub.tutorial_btn.focus_mode == Control.FOCUS_NONE and nav_hub.archive_btn.focus_mode == Control.FOCUS_NONE and nav_hub.bestiary_btn.focus_mode == Control.FOCUS_NONE, "tutti i pulsanti dell'Hub dovrebbero smettere di essere navigabili con l'Archivio aperto")
	_assert(nav_hub.archive_panel.list_box.get_child_count() > 1, "setup del test: l'archivio dovrebbe elencare almeno due potenziamenti")
	for row in nav_hub.archive_panel.list_box.get_children():
		_assert(row.focus_mode == Control.FOCUS_NONE, "una riga dell'archivio non dovrebbe essere selezionabile: solo Chiudi deve poter avere il focus")
	_assert(nav_hub.archive_panel.close_btn.has_focus(), "all'apertura dell'Archivio il focus dovrebbe essere su Chiudi (l'unico controllo selezionabile)")

	# Tenendo giù lo stick sinistro/D-pad (evento reale, non un metodo
	# chiamato direttamente) la vista deve scorrere, ma il focus deve
	# restare su Chiudi: non c'è nessun elenco di controlli da attraversare.
	var scroll_before: float = nav_hub.archive_panel.scroll.scroll_vertical
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	for i in range(20):
		await get_tree().physics_frame
	var scroll_after: float = nav_hub.archive_panel.scroll.scroll_vertical
	_assert(scroll_after > scroll_before, "tenendo lo stick giù la vista dell'Archivio dovrebbe scorrere (scroll_vertical: %s -> %s)" % [scroll_before, scroll_after])
	_assert(nav_hub.archive_panel.close_btn.has_focus(), "il focus dovrebbe restare su Chiudi mentre si scorre la vista, non spostarsi altrove")
	var stick_release := InputEventJoypadMotion.new()
	stick_release.axis = JOY_AXIS_LEFT_Y
	stick_release.axis_value = 0.0
	Input.parse_input_event(stick_release)
	await get_tree().process_frame

	# Il tasto B/Cerchio del controller deve chiudere il pannello (come
	# documentato in README), non solo il click sul pulsante Chiudi.
	var cancel_down := InputEventJoypadButton.new()
	cancel_down.button_index = JOY_BUTTON_B
	cancel_down.pressed = true
	Input.parse_input_event(cancel_down)
	await get_tree().process_frame
	var cancel_up := InputEventJoypadButton.new()
	cancel_up.button_index = JOY_BUTTON_B
	cancel_up.pressed = false
	Input.parse_input_event(cancel_up)
	await get_tree().process_frame

	_assert(not nav_hub.archive_panel.visible, "il tasto B/Cerchio del controller dovrebbe chiudere l'Archivio")
	_assert(nav_hub.start_btn.focus_mode == Control.FOCUS_ALL, "i pulsanti dell'Hub dovrebbero tornare navigabili dopo aver chiuso l'Archivio")
	_assert(nav_hub.start_btn.has_focus(), "il focus dovrebbe tornare su 'Inizia Run' dopo aver chiuso l'Archivio")

	# Stessa verifica, più rapida (chiusura diretta via segnale), per
	# Bestiario e Tutorial.
	nav_hub._open_bestiary()
	await get_tree().process_frame
	_assert(nav_hub.bestiary_panel.list_box.get_child_count() > 0, "setup del test: il bestiario dovrebbe elencare almeno una voce")
	for row in nav_hub.bestiary_panel.list_box.get_children():
		_assert(row.focus_mode == Control.FOCUS_NONE, "una riga del bestiario non dovrebbe essere selezionabile")
	_assert(nav_hub.bestiary_panel.close_btn.has_focus(), "all'apertura del Bestiario il focus dovrebbe essere su Chiudi")
	nav_hub.bestiary_panel.closed.emit()
	await get_tree().process_frame
	_assert(nav_hub.start_btn.focus_mode == Control.FOCUS_ALL, "i pulsanti dell'Hub dovrebbero tornare navigabili dopo aver chiuso il Bestiario")

	nav_hub._open_tutorial()
	await get_tree().process_frame
	_assert(nav_hub.tutorial_panel.close_btn.has_focus(), "all'apertura del Tutorial il focus dovrebbe essere su Chiudi")
	nav_hub.tutorial_panel.closed.emit()
	await get_tree().process_frame
	_assert(nav_hub.start_btn.focus_mode == Control.FOCUS_ALL, "i pulsanti dell'Hub dovrebbero tornare navigabili dopo aver chiuso il Tutorial")

	print("Scorrimento senza spostare il focus nei sottomenu dell'Hub: OK")
	nav_hub.queue_free()
	await get_tree().process_frame

func _action_has_joypad_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func _action_has_key(action: String, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false

func _test_gamepad_input() -> void:
	print("--- Test input da controller (eventi joypad simulati) ---")
	_assert(InputMap.has_action("move_right"), "l'azione move_right non è stata registrata")
	_assert(InputMap.has_action("special_attack"), "l'azione special_attack non è stata registrata")
	_assert(not InputMap.has_action("dash"), "non deve più esistere un'azione dash dedicata: lo scatto vive sui pulsanti d'attacco")

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
	btn.button_index = JOY_BUTTON_RIGHT_SHOULDER
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
	_assert(p.is_dashing, "il dorsale destro (R1/RB) del controller non ha attivato lo scatto")
	print("Input da controller (stick + dorsale destro): OK")

	var btn_release := InputEventJoypadButton.new()
	btn_release.device = 0
	btn_release.button_index = JOY_BUTTON_RIGHT_SHOULDER
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
	var farthest_cell: Vector2i = maze_run.current_maze.find_farthest_cell(maze_run.current_maze.world_to_cell(spawn_pos))
	var farthest_pos: Vector2 = maze_run.current_maze.cell_center(farthest_cell.x, farthest_cell.y)
	var farthest_path_len: int = maze_run.current_maze.get_path(spawn_pos, farthest_pos).size()
	var min_expected_hops: int = (maze_run.MAZE_COLS + maze_run.MAZE_ROWS) / 2
	_assert(farthest_path_len >= min_expected_hops, "il punto più lontano dallo spawn è troppo vicino lungo il percorso (%d celle, attese almeno %d)" % [farthest_path_len, min_expected_hops])

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
		if maze_run.powerup_choice_screen.visible:
			maze_run._on_powerup_selected(GameData.get_regular_powerup_pool()[0].id)
	_assert(maze_run.room_number == 6, "non si è arrivati alla sala del boss (stanza %d)" % maze_run.room_number)
	_assert(maze_run.current_maze == null, "la sala del boss non dovrebbe avere un labirinto")
	_assert(maze_run.player.maze == null, "il giocatore non dovrebbe avere un labirinto nella sala del boss")
	var boss_bounds: Rect2 = maze_run.arena_rect
	_assert(boss_bounds.size.x > 1280.0 or boss_bounds.size.y > 720.0, "la sala del boss non è più grande della finestra di gioco (%s)" % boss_bounds.size)

	print("Integrazione labirinto: OK (punto più lontano a %d celle di percorso dallo spawn, sala boss %s)" % [farthest_path_len, boss_bounds.size])
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
		# La ricompensa viene consegnata subito alla pulizia della stanza,
		# senza dover raggiungere alcun punto: la schermata di scelta deve
		# comparire immediatamente dopo l'ultimo nemico sconfitto.
		_assert(run.room_cleared, "la stanza %d non risulta ripulita" % run.room_number)
		_assert(run.powerup_choice_screen.visible, "schermata scelta potenziamento non mostrata (stanza %d)" % i)
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

# --- Stile estetico: la cripta -----------------------------------------------

func _test_crypt_ui_theme() -> void:
	print("--- Test estetica: il tema della cripta arriva a tutte le schermate ---")
	# L'ereditarietà del tema in Godot passa solo per Control e Window:
	# un Node2D o un CanvasLayer lungo la strada la interrompe. Senza
	# questo controllo il gioco tornerebbe in silenzio al tema grigio
	# predefinito di Godot, e nessun altro test se ne accorgerebbe.
	var hub := Hub.new()
	Palette.apply_theme(hub)
	add_child(hub)
	await get_tree().process_frame

	var hub_button: Button = _find_first_button(hub)
	_assert(hub_button != null, "setup del test: l'Hub dovrebbe avere almeno un pulsante")
	var hub_box: StyleBox = hub_button.get_theme_stylebox("normal", "Button")
	_assert(hub_box is StyleBoxFlat, "i pulsanti dell'Hub non usano il tema del gioco")
	_assert(hub_box.bg_color.is_equal_approx(Palette.UI_BG_SOFT), "i pulsanti dell'Hub non hanno il fondo scuro della cripta")
	hub.queue_free()
	await get_tree().process_frame

	var themed_run := Run.new()
	add_child(themed_run)
	themed_run.begin_new_streak()
	await get_tree().process_frame

	var hud_bar: ProgressBar = themed_run.hud.hp_bar
	var fill: StyleBox = hud_bar.get_theme_stylebox("fill", "ProgressBar")
	_assert(fill is StyleBoxFlat, "la barra della vita non usa il tema del gioco")
	_assert(fill.bg_color.is_equal_approx(Palette.BLOOD), "la barra della vita dovrebbe essere cremisi")

	var pause_button: Button = _find_first_button(themed_run.pause_screen)
	_assert(pause_button != null, "setup del test: il menu di pausa dovrebbe avere almeno un pulsante")
	_assert(pause_button.get_theme_stylebox("normal", "Button").bg_color.is_equal_approx(Palette.UI_BG_SOFT), "il menu di pausa non eredita il tema del gioco")

	themed_run.queue_free()
	await get_tree().process_frame
	print("Tema della cripta: OK")

func _find_first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var found: Button = _find_first_button(child)
		if found != null:
			return found
	return null

func _test_vignette_below_hud() -> void:
	print("--- Test estetica: oscuramento ai bordi sotto l'interfaccia ---")
	var vig_run := Run.new()
	add_child(vig_run)
	vig_run.begin_new_streak()
	await get_tree().process_frame

	_assert(vig_run.vignette != null, "la run dovrebbe avere l'oscuramento ai bordi")
	_assert(vig_run.vignette.get_parent() == vig_run.ui_layer, "l'oscuramento va sul livello dell'interfaccia, non nel mondo di gioco")
	# Deve stare sotto HUD e menu: quei nodi vanno letti senza velo sopra.
	_assert(
		vig_run.ui_layer.get_children().find(vig_run.vignette) < vig_run.ui_layer.get_children().find(vig_run.hud),
		"l'oscuramento non deve coprire la HUD"
	)
	_assert(vig_run.vignette.mouse_filter == Control.MOUSE_FILTER_IGNORE, "l'oscuramento non deve intercettare il mouse")
	vig_run.queue_free()
	await get_tree().process_frame
	print("Oscuramento ai bordi: OK")

func _test_blood_decals() -> void:
	print("--- Test estetica: il sangue resta a terra e cambia con la stanza ---")
	var blood_run := Run.new()
	add_child(blood_run)
	blood_run.begin_new_streak()
	await get_tree().process_frame

	var decals: BloodDecals = blood_run.blood_decals
	_assert(decals != null, "la run dovrebbe avere il livello del sangue")
	_assert(decals.get_parent() == blood_run, "il sangue va nel mondo di gioco, non sull'interfaccia")
	decals.clear_all()

	# Un nemico ucciso deve lasciare il segno dove è caduto.
	var victim = _spawn_follower(blood_run, blood_run.player.global_position + Vector2(80, 0))
	await get_tree().process_frame
	var before: int = decals.mark_count()
	victim.take_damage(victim.max_hp)
	blood_run._on_enemy_defeated(victim)
	_assert(decals.mark_count() > before, "la morte di un nemico dovrebbe lasciare sangue a terra")

	# Anche il giocatore colpito sanguina.
	var after_kill: int = decals.mark_count()
	blood_run.player.hit_iframe_timer = 0.0
	blood_run.player.take_damage(5.0)
	_assert(decals.mark_count() > after_kill, "un colpo subito dal giocatore dovrebbe lasciare sangue a terra")

	# Oltre il tetto le macchie più vecchie vengono scartate: una run
	# lunga non deve far crescere il disegno all'infinito.
	for i in range(120):
		decals.splatter(Vector2(i * 7, i * 5), 2.0)
	_assert(decals.mark_count() <= BloodDecals.MAX_MARKS, "il sangue accumulato dovrebbe essere limitato a MAX_MARKS")

	# Stanza nuova, pavimento pulito.
	blood_run._generate_room(2)
	await get_tree().process_frame
	_assert(decals.mark_count() == 0, "il sangue della stanza precedente non dovrebbe seguire il giocatore")

	blood_run.queue_free()
	await get_tree().process_frame
	print("Sangue a terra: OK")

func _test_arena_visual_geometry() -> void:
	print("--- Test estetica: la muratura viene generata per ogni stanza ---")
	var visual := ArenaVisual.new()
	visual.wall_margin = Run.WALL_MARGIN
	add_child(visual)

	var test_maze := MazeGrid.new()
	var maze_rng := RandomNumberGenerator.new()
	maze_rng.seed = 909
	test_maze.generate(4, 3, 240.0, maze_rng)
	visual.maze = test_maze
	_assert(visual._floor_tiles.size() > 0, "il pavimento del labirinto dovrebbe essere lastricato")

	var tiles_bounds: Rect2 = _tiles_bounds(visual)
	_assert(test_maze.total_bounds().encloses(tiles_bounds), "le lastre non devono sbordare dal labirinto")

	# Sala del boss: Run azzera il labirinto e SOLO DOPO imposta la
	# misura dell'arena. Se la geometria non si rigenerasse anche al
	# cambio di misura, la sala del boss resterebbe lastricata quanto la
	# stanza precedente, molto più piccola.
	visual.maze = null
	visual.arena_size = Run.BOSS_ARENA_SIZE
	var boss_tiles: Rect2 = _tiles_bounds(visual)
	_assert(
		boss_tiles.size.x > Run.BOSS_ARENA_SIZE.x * 0.8,
		"il pavimento della sala del boss copre solo %d px dei %d dell'arena" % [int(boss_tiles.size.x), int(Run.BOSS_ARENA_SIZE.x)]
	)

	visual.queue_free()
	await get_tree().process_frame
	print("Muratura delle stanze: OK")

func _tiles_bounds(visual: ArenaVisual) -> Rect2:
	var bounds: Rect2 = Rect2()
	for i in range(visual._floor_tiles.size()):
		var tile_rect: Rect2 = visual._floor_tiles[i].rect
		bounds = tile_rect if i == 0 else bounds.merge(tile_rect)
	return bounds

func _test_creature_rim_colors() -> void:
	print("--- Test estetica: il profilo luminoso dice da che parte sta una creatura ---")
	# Su una pietra quasi nera la silhouette da sola non basta: è il
	# colore del profilo a distinguere ostili, alleati e dorati.
	var hostile := Enemy.new()
	hostile.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	_assert(hostile.current_rim_color() == Palette.RIM_HOSTILE, "un nemico ostile dovrebbe avere il profilo cremisi")

	var ally := Enemy.new()
	ally.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	ally.is_ally = true
	_assert(ally.current_rim_color() == Palette.RIM_ALLY, "un alleato dovrebbe avere il profilo d'acciaio")

	var golden := Enemy.new()
	golden.setup_from_data(GameData.build_golden_enemy_data("strisciante"), true)
	_assert(golden.current_rim_color() == Palette.RIM_GOLDEN, "un nemico dorato dovrebbe avere il profilo dorato")
	# Addomesticato, un dorato resta pur sempre un alleato: conta lo
	# schieramento, non la rarità.
	golden.is_ally = true
	_assert(golden.current_rim_color() == Palette.RIM_ALLY, "un dorato addomesticato dovrebbe mostrare il profilo da alleato")

	hostile.free()
	ally.free()
	golden.free()
	print("Profili luminosi delle creature: OK")


func _test_creature_shapes() -> void:
	print("--- Test estetica: ogni specie ha la propria sagoma ---")
	# Le specie non si distinguono più per colore ma per forma: se un
	# tipo perde la propria sagoma torna a essere il disco generico,
	# indistinguibile dagli altri, e nulla lo segnalerebbe.
	var expected := {
		"strisciante": "slime",
		"pungiglione": "flower",
		"corazzato": "brute",
		"sciame": "insect",
	}
	for enemy_id in expected:
		var creature := Enemy.new()
		creature.setup_from_data(GameData.ENEMY_TYPES[enemy_id], false)
		_assert(
			creature.shape == expected[enemy_id],
			"%s dovrebbe avere la sagoma '%s', invece ha '%s'" % [enemy_id, expected[enemy_id], creature.shape]
		)
		creature.free()

	# La variante dorata è pur sempre uno Strisciante: deve ereditare la
	# sagoma della specie di base, non ricadere su quella generica.
	var golden := Enemy.new()
	golden.setup_from_data(GameData.build_golden_enemy_data("strisciante"), true)
	_assert(golden.shape == "slime", "lo Strisciante Dorato dovrebbe mantenere la sagoma della specie di base")
	golden.free()
	print("Sagome delle specie: OK")

func _test_flower_shoots_its_own_colour() -> void:
	print("--- Test estetica: i dardi del Pungiglione sono del suo giallo ---")
	var shot_run := Run.new()
	add_child(shot_run)
	shot_run.begin_new_streak()
	await get_tree().process_frame

	# Arena libera e stanza svuotata: qui conta solo il colore del dardo,
	# e un nemico a distanza già presente potrebbe averne sparato uno suo.
	for existing in shot_run.enemy_container.get_children():
		existing.queue_free()
	await get_tree().process_frame
	shot_run._clear_container(shot_run.projectile_container)
	shot_run.current_maze = null
	shot_run.player.maze = null

	var flower := Enemy.new()
	flower.setup_from_data(GameData.ENEMY_TYPES["pungiglione"], false)
	flower.maze = null
	flower.arena_bounds = Rect2(Vector2.ZERO, Vector2(2400, 1800))
	flower.spawn_projectile.connect(shot_run._on_enemy_spawn_projectile)
	shot_run.enemy_container.add_child(flower)
	# Dentro il raggio di tiro e pronto a sparare.
	flower.global_position = shot_run.player.global_position + Vector2(flower.keep_distance, 0.0)
	flower.attack_timer = 0.0

	var fired: EnemyProjectile = null
	for i in range(30):
		await get_tree().physics_frame
		for child in shot_run.projectile_container.get_children():
			if child is EnemyProjectile and not child.is_ally_projectile:
				fired = child
				break
		if fired != null:
			break

	_assert(fired != null, "il Pungiglione ostile non ha sparato alcun dardo")
	if fired != null:
		# Il colore viaggia sul segnale spawn_projectile: se quel dato si
		# perde, i dardi tornano al rosso generico e il legame visivo con
		# il cuore giallo del fiore sparisce senza altri sintomi.
		_assert(
			fired.color.is_equal_approx(GameData.ENEMY_TYPES["pungiglione"].color),
			"il dardo del Pungiglione dovrebbe avere il giallo della specie, invece è %s" % fired.color
		)

	shot_run.queue_free()
	await get_tree().process_frame
	print("Colore dei dardi del Pungiglione: OK")

func _test_slime_body_trail() -> void:
	print("--- Test estetica: la melma si allunga dietro di sé ---")
	var slime := Enemy.new()
	slime.setup_from_data(GameData.ENEMY_TYPES["strisciante"], false)
	add_child(slime)
	slime.global_position = Vector2(500, 500)
	await get_tree().process_frame

	# Ferma: il corpo si raccoglie in un solo segmento, come una pozza.
	for i in range(5):
		await get_tree().process_frame
	_assert(slime._body_trail.size() <= 2, "da ferma la melma non dovrebbe allungarsi (%d segmenti)" % slime._body_trail.size())

	# In movimento: il corpo segue le posizioni appena occupate, ed è
	# questo a dargli l'andatura serpentina.
	for i in range(40):
		slime.global_position += Vector2(Enemy.SLIME_TRAIL_GAP + 1.0, 0.0)
		await get_tree().process_frame
	_assert(slime._body_trail.size() > 2, "in movimento la melma dovrebbe allungarsi dietro di sé")
	_assert(
		slime._body_trail.size() <= Enemy.SLIME_SEGMENTS,
		"il corpo della melma non dovrebbe crescere oltre SLIME_SEGMENTS (%d)" % slime._body_trail.size()
	)
	# La direzione di marcia segue lo spostamento reale: senza, corpo,
	# ali e petali di tutte le specie punterebbero sempre a destra.
	_assert(slime.heading.x > 0.8, "la melma dovrebbe puntare nella direzione in cui si sta muovendo")

	slime.queue_free()
	await get_tree().process_frame
	print("Corpo della melma: OK")
