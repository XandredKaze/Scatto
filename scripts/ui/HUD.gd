class_name HUD
extends Control

# Interfaccia di gioco: vita, cariche di scatto, numero di stanza,
# barra vita del boss e banner di notifica. Legge lo stato direttamente
# dal nodo Run assegnato a `run` ad ogni frame (pattern a polling,
# più semplice di una sincronizzazione a segnali per una HUD di questo tipo).

var run: Node = null

var hp_bar: ProgressBar
var hp_label: Label
var room_label: Label
var streak_label: Label
var dash_pips: HBoxContainer
var boss_panel: VBoxContainer
var boss_name_label: Label
var boss_bar: ProgressBar
var banner_label: Label
var banner_timer := 0.0
var powerup_tray: HBoxContainer
var sigil: HudSigil
var minimap: Minimap
# Riquadro che annuncia il potenziamento trovato in una cassa: nome,
# rarità e descrizione, per qualche secondo, senza fermare il gioco.
var found_panel: PanelContainer
var found_icon: PowerupIcon
var found_name_label: Label
var found_rarity_label: Label
var found_desc_label: Label
var found_timer := 0.0
const FOUND_WIDTH := 460.0
const FOUND_TOP := 110.0
const FOUND_DURATION := 5.0
var _last_powerup_summary := ""
var ally_label: Label
var keys_label: Label
var tokens_label: Label
var tame_pip: ColorRect
const SPECIAL_ATTACK_KEYS := ["E", "Q"]
# Banner di notifica, in alto al centro: largo abbastanza per i messaggi
# più lunghi (es. "Il varco si è aperto: raggiungi la porta.") ma non
# tanto da invadere la colonna di informazioni in alto a sinistra o la
# mini mappa in alto a destra.
const BANNER_WIDTH := 720.0
const BANNER_TOP := 70.0
var special_attack_labels: Array = []
var special_attack_pips: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Targa del sigillo a sinistra, vita e cariche di scatto a destra:
	# il blocco compatto in alto a sinistra del riferimento estetico.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)

	sigil = HudSigil.new()
	top_row.add_child(sigil)

	var status_col := VBoxContainer.new()
	status_col.add_theme_constant_override("separation", 6)
	status_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(status_col)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 10)
	status_col.add_child(health_row)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 18)
	hp_bar.show_percentage = false
	health_row.add_child(hp_bar)

	hp_label = Label.new()
	health_row.add_child(hp_label)

	dash_pips = HBoxContainer.new()
	dash_pips.add_theme_constant_override("separation", 6)
	status_col.add_child(dash_pips)

	room_label = Label.new()
	vbox.add_child(room_label)

	streak_label = Label.new()
	streak_label.modulate = Palette.BONE_DIM
	vbox.add_child(streak_label)

	var tame_row := HBoxContainer.new()
	tame_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tame_row)

	tame_pip = ColorRect.new()
	tame_pip.custom_minimum_size = Vector2(18, 18)
	tame_row.add_child(tame_pip)

	ally_label = Label.new()
	ally_label.text = "Alleati: 0 / %d" % Run.MAX_ALLIES
	tame_row.add_child(ally_label)

	for i in range(SPECIAL_ATTACK_KEYS.size()):
		var special_row := HBoxContainer.new()
		special_row.add_theme_constant_override("separation", 8)
		vbox.add_child(special_row)

		var special_pip := ColorRect.new()
		special_pip.custom_minimum_size = Vector2(18, 18)
		special_row.add_child(special_pip)
		special_attack_pips.append(special_pip)

		var special_label := Label.new()
		special_label.text = "%s: nessuno" % SPECIAL_ATTACK_KEYS[i]
		special_row.add_child(special_label)
		special_attack_labels.append(special_label)

	# Chiavi virtuali (valgono per la serie di run) e gettoni (restano nel
	# salvataggio), con la stessa icona dell'oggetto a terra.
	var inventory_row := HBoxContainer.new()
	inventory_row.add_theme_constant_override("separation", 6)
	vbox.add_child(inventory_row)
	inventory_row.add_child(_inventory_icon(Pickup.KEY))
	keys_label = Label.new()
	keys_label.text = "0"
	inventory_row.add_child(keys_label)
	var inventory_gap := Control.new()
	inventory_gap.custom_minimum_size = Vector2(12, 0)
	inventory_row.add_child(inventory_gap)
	inventory_row.add_child(_inventory_icon(Pickup.TOKEN))
	tokens_label = Label.new()
	tokens_label.text = "0"
	inventory_row.add_child(tokens_label)

	var powerup_label := Label.new()
	powerup_label.text = "Potenziamenti attivi"
	powerup_label.modulate = Palette.BONE_DIM
	vbox.add_child(powerup_label)

	powerup_tray = HBoxContainer.new()
	powerup_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	powerup_tray.add_theme_constant_override("separation", 8)
	vbox.add_child(powerup_tray)

	boss_panel = VBoxContainer.new()
	boss_panel.hide()
	vbox.add_child(boss_panel)

	boss_name_label = Label.new()
	boss_panel.add_child(boss_name_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(300, 16)
	boss_bar.show_percentage = false
	boss_panel.add_child(boss_bar)

	if run != null and run.debug_mode:
		var debug_spacer := Control.new()
		debug_spacer.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(debug_spacer)

		var debug_label := Label.new()
		debug_label.text = "Debug"
		debug_label.modulate = Palette.EMBER
		vbox.add_child(debug_label)

		var force_golden_btn := Button.new()
		force_golden_btn.text = "Forza nemico dorato (prossima stanza)"
		force_golden_btn.custom_minimum_size = Vector2(280, 36)
		force_golden_btn.pressed.connect(func(): run.debug_force_golden = true)
		vbox.add_child(force_golden_btn)

	# In alto a destra la mini mappa, oscurata finché non si esplora: nella
	# sala del boss (niente mappa) sparisce. Come il banner, si posiziona a
	# mano sulla finestra vera (_layout_minimap), perché questo Control
	# resta 0x0 sotto il CanvasLayer.
	minimap = Minimap.new()
	minimap.hide()
	add_child(minimap)

	_build_found_panel()

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.size = Vector2(BANNER_WIDTH, 30.0)
	banner_label.add_theme_font_size_override("font_size", 22)
	banner_label.add_theme_color_override("font_color", Palette.EMBER)
	banner_label.hide()
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_label)
	# Centrato sulla finestra vera, non sulle ancore: questo Control sta
	# sotto un CanvasLayer e le sue ancore non gli danno una larghezza
	# (resta 0x0, come per la Vignette), quindi "al centro" finiva a x = 0
	# e la prima metà di ogni messaggio usciva dallo schermo.
	_layout_banner()
	get_viewport().size_changed.connect(_layout_banner)

func _build_found_panel() -> void:
	found_panel = PanelContainer.new()
	found_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_panel.custom_minimum_size = Vector2(FOUND_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.UI_BG, 0.92)
	style.border_color = Palette.NEON
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	found_panel.add_theme_stylebox_override("panel", style)
	found_panel.hide()
	add_child(found_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	found_panel.add_child(col)

	var header := Label.new()
	header.text = "Dalla Cassa del potenziamento virtuale"
	header.add_theme_color_override("font_color", Palette.NEON)
	header.add_theme_font_size_override("font_size", 14)
	col.add_child(header)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	col.add_child(title_row)
	found_icon = PowerupIcon.new()
	found_icon.custom_minimum_size = Vector2(36, 36)
	title_row.add_child(found_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	title_row.add_child(names)
	found_name_label = Label.new()
	found_name_label.add_theme_font_size_override("font_size", 20)
	names.add_child(found_name_label)
	found_rarity_label = Label.new()
	found_rarity_label.add_theme_font_size_override("font_size", 14)
	names.add_child(found_rarity_label)

	found_desc_label = Label.new()
	found_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	found_desc_label.custom_minimum_size = Vector2(FOUND_WIDTH - 24.0, 0)
	col.add_child(found_desc_label)

func show_found_powerup(entry: Dictionary) -> void:
	found_icon.set_icon(entry.get("icon", "circle"), GameData.rarity_color(entry.rarity))
	found_name_label.text = entry.name
	found_rarity_label.text = GameData.rarity_name(entry.rarity)
	found_rarity_label.add_theme_color_override("font_color", GameData.rarity_color(entry.rarity))
	found_desc_label.text = entry.desc
	found_panel.modulate.a = 1.0
	found_panel.show()
	found_timer = FOUND_DURATION
	# La dimensione dipende dal testo: si ridimensiona prima di centrarlo.
	found_panel.reset_size()
	_layout_found_panel()

func _layout_found_panel() -> void:
	var width: float = get_viewport_rect().size.x
	found_panel.position = Vector2((width - found_panel.size.x) * 0.5, FOUND_TOP)

func _inventory_icon(kind: String) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(26, 22)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = Pickup.NAMES[kind]
	icon.draw.connect(func(): Pickup.draw_art(icon, kind, icon.size * 0.5, 0.8, 0.0))
	return icon

const MINIMAP_MARGIN := Vector2(20.0, 16.0)

func _layout_minimap() -> void:
	var width: float = get_viewport_rect().size.x
	minimap.position = Vector2(width - minimap.custom_minimum_size.x - MINIMAP_MARGIN.x, MINIMAP_MARGIN.y)

func _layout_banner() -> void:
	var width: float = get_viewport_rect().size.x
	banner_label.position = Vector2((width - BANNER_WIDTH) * 0.5, BANNER_TOP)

func show_banner(text: String, duration: float = 2.0) -> void:
	banner_label.text = text
	banner_label.modulate.a = 1.0
	banner_label.show()
	banner_timer = duration

func _process(delta: float) -> void:
	if banner_timer > 0.0:
		banner_timer -= delta
		banner_label.modulate.a = clamp(banner_timer / 0.4, 0.0, 1.0)
		if banner_timer <= 0.0:
			banner_label.hide()

	if found_timer > 0.0:
		found_timer -= delta
		found_panel.modulate.a = clamp(found_timer / 0.5, 0.0, 1.0)
		_layout_found_panel()
		if found_timer <= 0.0:
			found_panel.hide()

	if run == null or run.player == null:
		return
	var player = run.player
	_update_minimap(player)
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "%d / %d PV" % [int(ceil(player.hp)), int(player.max_hp)]
	sigil.health_ratio = (player.hp / player.max_hp) if player.max_hp > 0.0 else 0.0

	if run.room_number <= 5:
		room_label.text = "Stanza %d / 5" % run.room_number
	else:
		room_label.text = "Sala del Custode"

	streak_label.text = "Run consecutive senza Hub: %d" % run.streak_run_index

	# Le cariche di scatto hanno senso solo finché lo scatto esiste: con
	# alleati al seguito la riga sparisce del tutto invece di mostrare
	# pallini per un attacco non più disponibile.
	dash_pips.visible = player.has_dash()
	_sync_dash_pips(player.max_dash_charges, player.dash_charges, player.emergency_charge_progress())
	_update_powerup_tray(player)
	ally_label.text = "Alleati: %d / %d" % [run.allies.size(), Run.MAX_ALLIES]
	keys_label.text = "Chiavi virtuali: %d" % player.virtual_keys
	tokens_label.text = "Gettoni: %d" % SaveManager.tokens()
	tame_pip.color = Palette.UI_READY if player.can_tame() else Palette.UI_IDLE

	for i in range(SPECIAL_ATTACK_KEYS.size()):
		var ability_id: String = player.granted_ability_ids[i]
		var label: Label = special_attack_labels[i]
		var pip: ColorRect = special_attack_pips[i]
		if ability_id == "":
			# Pulsante libero: esegue lo scatto, ma solo finché il giocatore
			# non ha alleati (addomesticare lo toglie da entrambi i pulsanti).
			if player.has_dash():
				label.text = "%s: Scatto" % SPECIAL_ATTACK_KEYS[i]
				pip.color = Palette.UI_READY if player.can_dash() else Palette.UI_IDLE
			else:
				label.text = "%s: nessuno" % SPECIAL_ATTACK_KEYS[i]
				pip.color = Palette.UI_IDLE
		else:
			var ability: Dictionary = GameData.ALLY_SPECIAL_ATTACKS[ability_id]
			var name_text: String = ability.name
			if player.special_attack_empowered[i]:
				name_text += " (potenziato)"
			label.text = "%s: %s" % [SPECIAL_ATTACK_KEYS[i], name_text]
			pip.color = Palette.UI_READY if player.can_use_special_attack(i) else Palette.UI_IDLE

	if run.current_boss != null and is_instance_valid(run.current_boss) and run.current_boss.alive:
		boss_panel.show()
		boss_name_label.text = run.current_boss.display_name
		boss_bar.max_value = run.current_boss.max_hp
		boss_bar.value = run.current_boss.hp
	else:
		boss_panel.hide()

func _update_minimap(player) -> void:
	var maze: MazeGrid = run.current_maze
	if maze == null:
		minimap.hide()
		minimap.set_maze(null)
		return
	minimap.set_maze(maze)
	minimap.show()
	minimap.pickups = run.pickup_container.get_children()
	minimap.track_player(player.global_position)
	_layout_minimap()
	minimap.set_gate_open(run.exit_gate != null and is_instance_valid(run.exit_gate) and run.exit_gate.is_open)

func _update_powerup_tray(player) -> void:
	var counts := {}
	var order: Array = []
	for id in player.active_powerups:
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1

	var summary := ""
	for id in order:
		summary += "%s:%d;" % [id, counts[id]]
	if summary == _last_powerup_summary:
		return
	_last_powerup_summary = summary

	for c in powerup_tray.get_children():
		c.queue_free()
	for id in order:
		var entry: Dictionary = GameData.get_powerup(id)
		if entry.is_empty():
			continue
		powerup_tray.add_child(_build_tray_icon(entry, counts[id]))

func _build_tray_icon(entry: Dictionary, count: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(30, 30)
	wrap.tooltip_text = ("%s x%d\n%s" % [entry.name, count, entry.desc]) if count > 1 else ("%s\n%s" % [entry.name, entry.desc])

	var icon := PowerupIcon.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.set_icon(entry.get("icon", "circle"), GameData.rarity_color(entry.rarity))
	wrap.add_child(icon)

	if count > 1:
		var badge := Label.new()
		badge.text = str(count)
		badge.add_theme_font_size_override("font_size", 12)
		badge.position = Vector2(18, 16)
		wrap.add_child(badge)

	return wrap

# `reserve_progress` (0-1) è l'attesa verso la carica di riserva quando le
# cariche sono finite: il primo pallino si accende pian piano, senza mai
# arrivare al colore pieno finché la carica non è davvero tornata.
func _sync_dash_pips(max_charges: int, charges: int, reserve_progress := 0.0) -> void:
	while dash_pips.get_child_count() < max_charges:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 18)
		dash_pips.add_child(pip)
	while dash_pips.get_child_count() > max_charges:
		var last := dash_pips.get_child(dash_pips.get_child_count() - 1)
		dash_pips.remove_child(last)
		last.queue_free()
	for i in range(dash_pips.get_child_count()):
		var pip: ColorRect = dash_pips.get_child(i)
		pip.color = Palette.UI_READY if i < charges else Palette.UI_IDLE
	if charges <= 0 and reserve_progress > 0.0 and dash_pips.get_child_count() > 0:
		var first: ColorRect = dash_pips.get_child(0)
		first.color = Palette.UI_IDLE.lerp(Palette.UI_READY, reserve_progress * 0.6)
