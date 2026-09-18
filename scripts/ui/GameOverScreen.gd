class_name GameOverScreen
extends Control

signal hub_pressed

var summary_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 235)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(440, 250)
	vbox.custom_minimum_size = Vector2(400, 180)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := Label.new()
	title.text = "Sei stato sconfitto"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(400, 0)
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.custom_minimum_size = Vector2(400, 0)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(summary_label)

	var hub_btn := Button.new()
	hub_btn.text = "Torna all'Hub"
	hub_btn.custom_minimum_size = Vector2(280, 44)
	hub_btn.pressed.connect(func(): hub_pressed.emit())
	vbox.add_child(hub_btn)

func show_summary(room_number: int, streak_run_index: int) -> void:
	var room_text := "nella sala del Custode" if room_number >= 6 else ("nella stanza %d" % room_number)
	summary_label.text = "Sei caduto %s.\nLa serie di %d run senza tornare all'Hub si interrompe qui." % [room_text, streak_run_index]
