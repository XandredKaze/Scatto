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
var _last_powerup_summary := ""
var ally_label: Label
var tame_pip: ColorRect
var special_attack_label: Label
var special_attack_pip: ColorRect

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

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 10)
	vbox.add_child(health_row)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 20)
	hp_bar.show_percentage = false
	health_row.add_child(hp_bar)

	hp_label = Label.new()
	health_row.add_child(hp_label)

	room_label = Label.new()
	vbox.add_child(room_label)

	streak_label = Label.new()
	streak_label.modulate = Color(0.7, 0.7, 0.75)
	vbox.add_child(streak_label)

	dash_pips = HBoxContainer.new()
	dash_pips.add_theme_constant_override("separation", 6)
	vbox.add_child(dash_pips)

	var tame_row := HBoxContainer.new()
	tame_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tame_row)

	tame_pip = ColorRect.new()
	tame_pip.custom_minimum_size = Vector2(18, 18)
	tame_row.add_child(tame_pip)

	ally_label = Label.new()
	ally_label.text = "Alleati: 0 / %d" % Run.MAX_ALLIES
	tame_row.add_child(ally_label)

	var special_row := HBoxContainer.new()
	special_row.add_theme_constant_override("separation", 8)
	vbox.add_child(special_row)

	special_attack_pip = ColorRect.new()
	special_attack_pip.custom_minimum_size = Vector2(18, 18)
	special_row.add_child(special_attack_pip)

	special_attack_label = Label.new()
	special_attack_label.text = "Attacco speciale: nessuno"
	special_row.add_child(special_attack_label)

	var powerup_label := Label.new()
	powerup_label.text = "Potenziamenti attivi"
	powerup_label.modulate = Color(0.7, 0.7, 0.75)
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
		debug_label.modulate = Color(1, 0.4, 0.4)
		vbox.add_child(debug_label)

		var force_golden_btn := Button.new()
		force_golden_btn.text = "Forza nemico dorato (prossima stanza)"
		force_golden_btn.custom_minimum_size = Vector2(280, 36)
		force_golden_btn.pressed.connect(func(): run.debug_force_golden = true)
		vbox.add_child(force_golden_btn)

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label.position = Vector2(-200, 70)
	banner_label.custom_minimum_size = Vector2(400, 30)
	banner_label.add_theme_font_size_override("font_size", 22)
	banner_label.hide()
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_label)

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

	if run == null or run.player == null:
		return
	var player = run.player
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_label.text = "%d / %d PV" % [int(ceil(player.hp)), int(player.max_hp)]

	if run.room_number <= 5:
		room_label.text = "Stanza %d / 5" % run.room_number
	else:
		room_label.text = "Sala del Custode"

	streak_label.text = "Run consecutive senza Hub: %d" % run.streak_run_index

	_sync_dash_pips(player.max_dash_charges, player.dash_charges)
	_update_powerup_tray(player)
	ally_label.text = "Alleati: %d / %d" % [run.allies.size(), Run.MAX_ALLIES]
	tame_pip.color = Color(0.4, 0.88, 0.76) if player.can_tame() else Color(0.25, 0.27, 0.33)

	if player.granted_ability_id == "":
		special_attack_label.text = "Attacco speciale: nessuno"
		special_attack_pip.color = Color(0.25, 0.27, 0.33)
	else:
		var ability: Dictionary = GameData.ALLY_SPECIAL_ATTACKS[player.granted_ability_id]
		special_attack_label.text = "Attacco speciale: %s" % ability.name
		special_attack_pip.color = Color(0.4, 0.88, 0.76) if player.can_use_special_attack() else Color(0.25, 0.27, 0.33)

	if run.current_boss != null and is_instance_valid(run.current_boss) and run.current_boss.alive:
		boss_panel.show()
		boss_name_label.text = run.current_boss.display_name
		boss_bar.max_value = run.current_boss.max_hp
		boss_bar.value = run.current_boss.hp
	else:
		boss_panel.hide()

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

func _sync_dash_pips(max_charges: int, charges: int) -> void:
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
		pip.color = Color(0.4, 0.88, 0.76) if i < charges else Color(0.25, 0.27, 0.33)
