class_name ArchiveScreen
extends Control

# Archivio dei potenziamenti: elenca ogni potenziamento del gioco.
# Quelli mai raccolti sono mostrati come "???" finché non vengono
# sbloccati per la prima volta (SaveManager.archive).

signal closed

var list_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 235)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.position = Vector2(80, 60)
	panel.custom_minimum_size = Vector2(800, 520)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)

	var title := Label.new()
	title.text = "Archivio dei Potenziamenti"
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
	for entry in GameData.POWERUPS:
		var unlocked: bool = SaveManager.is_powerup_unlocked(entry.id)
		list_box.add_child(_build_row(entry, unlocked))

func _build_row(entry: Dictionary, unlocked: bool) -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var name_label := Label.new()
	var rarity_tag := " [%s]" % String(entry.rarity).to_upper()
	name_label.text = (entry.name + rarity_tag) if unlocked else ("??? " + rarity_tag)
	name_label.custom_minimum_size = Vector2(260, 0)
	name_label.modulate = _rarity_color(entry.rarity) if unlocked else Color(0.4, 0.4, 0.45)
	hbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = entry.desc if unlocked else "Non ancora scoperto."
	desc_label.custom_minimum_size = Vector2(480, 0)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.modulate = Color(0.85, 0.85, 0.88) if unlocked else Color(0.35, 0.35, 0.4)
	hbox.add_child(desc_label)

	return row

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color8(244, 196, 48)
		"rare":
			return Color8(122, 162, 247)
		_:
			return Color8(200, 200, 205)
