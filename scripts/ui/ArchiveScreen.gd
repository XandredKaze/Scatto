class_name ArchiveScreen
extends Control

# Archivio dei potenziamenti: elenca ogni potenziamento del gioco.
# Quelli mai raccolti sono mostrati come "???" finché non vengono
# sbloccati per la prima volta (SaveManager.archive).

signal closed

var list_box: VBoxContainer
var close_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sfondo completamente opaco: la schermata sottostante (Hub) non deve
	# trasparire e mescolarsi con il testo dell'archivio.
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
	title.text = "Archivio dei Potenziamenti"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 490)
	panel.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(980, 0)
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	close_btn = Button.new()
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.pressed.connect(func(): closed.emit())
	panel.add_child(close_btn)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for entry in GameData.POWERUPS:
		var unlocked: bool = SaveManager.is_powerup_unlocked(entry.id)
		list_box.add_child(_build_row(entry, unlocked))

func _build_row(entry: Dictionary, unlocked: bool) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style())
	_make_row_focusable(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var icon := PowerupIcon.new()
	icon.custom_minimum_size = Vector2(32, 32)
	var icon_color: Color = GameData.rarity_color(entry.rarity) if unlocked else Color(0.35, 0.35, 0.4)
	icon.set_icon(entry.get("icon", "circle"), icon_color)
	hbox.add_child(icon)

	var name_label := Label.new()
	var rarity_tag := " [%s]" % String(entry.rarity).to_upper()
	name_label.text = (entry.name + rarity_tag) if unlocked else ("??? " + rarity_tag)
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.modulate = GameData.rarity_color(entry.rarity) if unlocked else Color(0.4, 0.4, 0.45)
	hbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = entry.desc if unlocked else "Non ancora scoperto."
	desc_label.custom_minimum_size = Vector2(480, 0)
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
