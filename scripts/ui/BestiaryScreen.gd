class_name BestiaryScreen
extends Control

# Bestiario: elenca ogni nemico comune, la variante dorata e i boss.
# Un avversario compare come "???" finché non viene sconfitto per la
# prima volta (SaveManager.bestiary).

signal closed

var list_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sfondo completamente opaco: la schermata sottostante (Hub) non deve
	# trasparire e mescolarsi con il testo del bestiario.
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 255)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.position = Vector2(80, 60)
	panel.custom_minimum_size = Vector2(800, 520)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)

	var title := Label.new()
	title.text = "Bestiario"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 420)
	panel.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(780, 0)
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	var close_btn := Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.pressed.connect(func(): closed.emit())
	panel.add_child(close_btn)

func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for entry in _all_entries():
		var unlocked: bool = SaveManager.is_enemy_unlocked(entry.id)
		list_box.add_child(_build_row(entry, unlocked))

func _all_entries() -> Array:
	var entries: Array = []
	for key in GameData.ENEMY_TYPES.keys():
		var e: Dictionary = GameData.ENEMY_TYPES[key]
		entries.append({"id": e.id, "name": e.name, "desc": e.desc, "tag": ""})
	for key in GameData.GOLDEN_VARIANTS.keys():
		var g: Dictionary = GameData.GOLDEN_VARIANTS[key]
		entries.append({"id": g.id, "name": g.name, "desc": g.desc, "tag": "AUREO · 1/%d" % GameData.GOLDEN_CHANCE_DENOMINATOR})
	for key in GameData.BOSSES.keys():
		var b: Dictionary = GameData.BOSSES[key]
		var is_special: bool = b.get("special", false)
		entries.append({"id": b.id, "name": b.name, "desc": b.desc, "tag": "BOSS SPECIALE" if is_special else "BOSS"})
	return entries

func _build_row(entry: Dictionary, unlocked: bool) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var name_label := Label.new()
	var tag: String = entry.get("tag", "")
	var tag_text := (" [%s]" % tag) if tag != "" else ""
	name_label.text = (entry.name + tag_text) if unlocked else ("???" + tag_text)
	name_label.custom_minimum_size = Vector2(280, 0)
	name_label.modulate = Color(1, 1, 1) if unlocked else Color(0.4, 0.4, 0.45)
	hbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = entry.desc if unlocked else "Non ancora incontrato."
	desc_label.custom_minimum_size = Vector2(460, 0)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.modulate = Color(0.85, 0.85, 0.88) if unlocked else Color(0.35, 0.35, 0.4)
	hbox.add_child(desc_label)

	return row

func _row_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(24, 26, 33, 255)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
