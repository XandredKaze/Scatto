class_name RunCompleteScreen
extends Control

# Mostrata dopo aver sconfitto il boss. Normalmente il giocatore sceglie
# se tornare all'Hub (azzera la serie) o continuare senza tornarci
# (mantiene i potenziamenti e la serie: alla terza run consecutiva il
# boss della sesta stanza sarà una variante speciale). Sconfiggere un
# boss speciale conclude invece la partita: resta solo "Torna all'Hub".

signal continue_pressed
signal hub_pressed

var title_label: Label
var summary_label: Label
var continue_btn: Button
var hub_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 255)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(440, 220)
	vbox.custom_minimum_size = Vector2(400, 220)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(400, 0)
	title_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title_label)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.custom_minimum_size = Vector2(400, 0)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(summary_label)

	continue_btn = Button.new()
	continue_btn.text = "Continua senza tornare all'Hub"
	continue_btn.custom_minimum_size = Vector2(320, 44)
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	vbox.add_child(continue_btn)

	hub_btn = Button.new()
	hub_btn.text = "Torna all'Hub"
	hub_btn.custom_minimum_size = Vector2(320, 44)
	hub_btn.pressed.connect(func(): hub_pressed.emit())
	vbox.add_child(hub_btn)

func show_summary(streak_run_index: int, was_special: bool, boss_name: String = "il boss") -> void:
	continue_btn.visible = not was_special
	if was_special:
		title_label.text = "%s sconfitto!" % boss_name
		summary_label.text = "Hai raggiunto e sconfitto una variante speciale dopo %d run consecutive senza tornare all'Hub.\nLa tua serie si conclude qui, con la vittoria più difficile possibile." % streak_run_index
	else:
		title_label.text = "%s sconfitto!" % boss_name
		var text := "Run %d completata senza tornare all'Hub." % streak_run_index
		if streak_run_index >= 2:
			text += "\nContinua per affrontare un boss sempre più temibile."
		summary_label.text = text
