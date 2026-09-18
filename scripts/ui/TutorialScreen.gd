class_name TutorialScreen
extends Control

# Tutorial richiamabile dall'Hub: spiega comandi e nemici comuni.
# Deliberatamente NON menziona il Custode, il Custode Corrotto né la
# variante dorata degli avversari: quelli restano una scoperta del
# giocatore durante la run.

signal closed

var close_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 255)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.position = Vector2(140, 60)
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)

	var title := Label.new()
	title.text = "Tutorial"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 490)
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(980, 0)
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)

	content.add_child(_build_section_title("Comandi"))
	var steps_box := VBoxContainer.new()
	steps_box.add_theme_constant_override("separation", 6)
	content.add_child(steps_box)
	for step in _steps():
		steps_box.add_child(_build_step_row(step.n, step.title, step.text))

	content.add_child(_build_section_title("Nemici comuni"))
	var enemies_box := VBoxContainer.new()
	enemies_box.add_theme_constant_override("separation", 6)
	content.add_child(enemies_box)
	for key in GameData.ENEMY_TYPES.keys():
		enemies_box.add_child(_build_enemy_row(GameData.ENEMY_TYPES[key]))

	close_btn = Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.pressed.connect(func(): closed.emit())
	panel.add_child(close_btn)

func _steps() -> Array:
	return [
		{"n": 1, "title": "Movimento", "text": "WASD o frecce direzionali, oppure lo stick sinistro/D-pad di un controller."},
		{"n": 2, "title": "Scatto — il tuo unico attacco", "text": "Spazio, Shift o il tasto A/Croce del controller. Durante lo scatto sei invulnerabile e infliggi danno a ogni nemico che attraversi."},
		{"n": 3, "title": "Attenzione al contatto", "text": "Fuori dallo scatto, toccare un nemico (o un suo proiettile) ti danneggia: usa lo scatto anche per attraversare in sicurezza."},
		{"n": 4, "title": "Ripulisci la stanza", "text": "Sconfiggi tutti i nemici della stanza: la ricompensa viene consegnata subito, senza doverla raccogliere."},
		{"n": 5, "title": "Scegli un potenziamento", "text": "Dopo ogni stanza scegli uno tra 3 potenziamenti casuali: ti rendono più forte per il resto della run."},
		{"n": 6, "title": "Addomesticamento", "text": "Tasto E o tasto X/Quadrato del controller: rende alleato il nemico comune più vicino. Puoi avere al massimo 2 alleati contemporaneamente, riconoscibili dall'anello acqua che li circonda; restano al tuo fianco e combattono per te finché non muoiono o non concludi/riavvii la run. L'abilità ha un tempo di recupero prima di poter essere riusata."},
	]

func _build_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(0.4, 0.88, 0.76)
	return label

func _build_step_row(n: int, step_title: String, text: String) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var number_label := Label.new()
	number_label.text = str(n)
	number_label.custom_minimum_size = Vector2(30, 0)
	number_label.add_theme_font_size_override("font_size", 20)
	number_label.modulate = Color(0.4, 0.88, 0.76)
	hbox.add_child(number_label)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var title_label := Label.new()
	title_label.text = step_title
	vbox.add_child(title_label)

	var text_label := Label.new()
	text_label.text = text
	text_label.custom_minimum_size = Vector2(880, 0)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.modulate = Color(0.85, 0.85, 0.88)
	vbox.add_child(text_label)

	return row

func _build_enemy_row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var icon := PowerupIcon.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.set_icon("circle", entry.color)
	hbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(name_label)

	var tip_label := Label.new()
	tip_label.text = entry.get("tip", entry.desc)
	tip_label.custom_minimum_size = Vector2(760, 0)
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.modulate = Color(0.85, 0.85, 0.88)
	hbox.add_child(tip_label)

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
