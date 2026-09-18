class_name PowerupChoiceScreen
extends Control

# Overlay mostrato dopo aver ripulito una stanza (1-5): il giocatore
# sceglie uno tra 3 potenziamenti casuali (esclusi quelli leggendari,
# ottenibili solo come bottino garantito).

signal powerup_selected(id: String)

var cards_box: HBoxContainer
var title_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 235)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(80, 150)
	vbox.custom_minimum_size = Vector2(800, 340)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(800, 0)
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	cards_box = HBoxContainer.new()
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.add_theme_constant_override("separation", 20)
	vbox.add_child(cards_box)

func show_choices(choices: Array, room_number: int) -> void:
	title_label.text = "Stanza %d ripulita! Scegli un potenziamento" % room_number
	for c in cards_box.get_children():
		c.queue_free()
	for choice in choices:
		cards_box.add_child(_build_card(choice))

func _build_card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(210, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = String(entry.rarity).to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.custom_minimum_size = Vector2(210, 0)
	rarity_label.modulate = Color(0.7, 0.7, 0.75)
	vbox.add_child(rarity_label)

	var desc_label := Label.new()
	desc_label.text = entry.desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(210, 0)
	vbox.add_child(desc_label)

	var pick_btn := Button.new()
	pick_btn.text = "Scegli"
	pick_btn.custom_minimum_size = Vector2(0, 36)
	pick_btn.pressed.connect(func(): powerup_selected.emit(entry.id))
	vbox.add_child(pick_btn)

	return panel
