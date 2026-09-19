class_name TutorialScreen
extends Control

# Tutorial richiamabile dall'Hub: spiega comandi e nemici comuni.
# Deliberatamente NON menziona il Custode, il Custode Corrotto né la
# variante dorata degli avversari: quelli restano una scoperta del
# giocatore durante la run.

signal closed

var close_btn: Button
var steps_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color8(10, 11, 15, 255)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
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
	steps_box = VBoxContainer.new()
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

	content.add_child(_build_section_title("Attacchi speciali degli alleati"))
	var abilities_box := VBoxContainer.new()
	abilities_box.add_theme_constant_override("separation", 6)
	content.add_child(abilities_box)
	for key in GameData.ALLY_SPECIAL_ATTACKS.keys():
		abilities_box.add_child(_build_ability_row(GameData.ENEMY_TYPES[key], GameData.ALLY_SPECIAL_ATTACKS[key]))

	close_btn = Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.pressed.connect(func(): closed.emit())
	panel.add_child(close_btn)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

# Il pulsante Chiudi sta sotto tutto il contenuto scorrevole: dandogli il
# focus iniziale, "giù" da lì non entra nel contenuto dall'alto come ci
# si aspetterebbe, ma salta al primo controllo navigabile che si trova
# geometricamente sotto di lui — che con il contenuto non ancora scorso
# è l'ULTIMA riga, non la prima (la risoluzione automatica del focus
# ignora l'ordine logico, guarda solo le posizioni a schermo). Partire
# dal primo passo dei Comandi rende invece "giù" un attraversamento
# naturale dall'alto verso il basso, con "giù" dall'ultima riga che
# arriva comunque a Chiudi.
func focus_first_item() -> void:
	if steps_box.get_child_count() > 0:
		steps_box.get_child(0).grab_focus()
	else:
		close_btn.grab_focus()

func _steps() -> Array:
	return [
		{"n": 1, "title": "Movimento", "text": "WASD o frecce direzionali, oppure lo stick sinistro/D-pad di un controller."},
		{"n": 2, "title": "Scatto — il tuo unico attacco", "text": "Spazio, Shift o il tasto A/Croce del controller. Durante lo scatto sei invulnerabile e infliggi danno a ogni nemico che attraversi."},
		{"n": 3, "title": "Attenzione al contatto", "text": "Fuori dallo scatto, toccare un nemico (o un suo proiettile) ti danneggia: usa lo scatto anche per attraversare in sicurezza."},
		{"n": 4, "title": "Ripulisci la stanza", "text": "Sconfiggi tutti i nemici della stanza: la ricompensa viene consegnata subito, senza doverla raccogliere. Al momento della ripulitura resti fermo sul posto e ogni proiettile ancora in volo (nemico, alleato o tuo) sparisce, cosí puoi scegliere il potenziamento con calma."},
		{"n": 5, "title": "Scegli un potenziamento", "text": "Dopo ogni stanza scegli uno tra 3 potenziamenti casuali: ti rendono più forte per il resto della run."},
		{"n": 6, "title": "Addomesticamento", "text": "Tasto F o tasto X/Quadrato del controller: rende alleato il nemico comune più vicino. Puoi avere al massimo 2 alleati contemporaneamente, riconoscibili dall'anello acqua che li circonda; restano al tuo fianco e combattono per te finché non muoiono o non concludi/riavvii la run. L'abilità ha un tempo di recupero prima di poter essere riusata."},
		{"n": 7, "title": "Attacchi speciali degli alleati", "text": "Tasto E (dorsale destro/RB-R1 del controller) e tasto Q (dorsale sinistro/LB-L1): ogni alleato vivo concede il proprio attacco speciale su un pulsante diverso (vedi sotto, ciascuno con un effetto visivo riconoscibile), cosí con 2 alleati diversi hai 2 attacchi distinti utilizzabili in modo indipendente, ciascuno con il proprio tempo di recupero. Se addomestichi due nemici dello stesso tipo, i due alleati condividono un solo pulsante ma con una versione potenziata dell'attacco. Se un alleato muore, il suo attacco sparisce (o torna alla versione normale, se era potenziato)."},
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
	_make_row_focusable(row)

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
	_make_row_focusable(row)

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

func _build_ability_row(enemy_entry: Dictionary, ability_entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	_make_row_focusable(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var icon := PowerupIcon.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.set_icon(ability_entry.get("icon", "circle"), enemy_entry.color)
	hbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = "%s (da %s)" % [ability_entry.name, enemy_entry.name]
	name_label.custom_minimum_size = Vector2(260, 0)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = ability_entry.desc
	desc_label.custom_minimum_size = Vector2(660, 0)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.modulate = Color(0.85, 0.85, 0.88)
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

func _row_focus_style() -> StyleBoxFlat:
	var sb := _row_style()
	sb.border_color = Color(0.4, 0.88, 0.76)
	sb.set_border_width_all(2)
	return sb

# Rende la riga selezionabile da tastiera/controller (altrimenti, con
# nessun controllo navigabile nell'elenco, il D-pad/stick non avrebbe
# nulla su cui scorrere all'interno dello ScrollContainer): PanelContainer
# non disegna da solo un riquadro di focus come i Button, quindi lo si
# simula scambiando lo stylebox "panel" quando il focus entra/esce. Lo
# ScrollContainer segue automaticamente il controllo con il focus.
func _make_row_focusable(row: Control) -> void:
	row.focus_mode = Control.FOCUS_ALL
	row.focus_entered.connect(func(): row.add_theme_stylebox_override("panel", _row_focus_style()))
	row.focus_exited.connect(func(): row.add_theme_stylebox_override("panel", _row_style()))
