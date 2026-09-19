class_name BestiaryScreen
extends Control

# Bestiario: elenca ogni nemico comune, la variante dorata e i boss.
# Un avversario compare come "???" finché non viene sconfitto per la
# prima volta (SaveManager.bestiary).

signal closed

var list_box: VBoxContainer
var close_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sfondo completamente opaco: la schermata sottostante (Hub) non deve
	# trasparire e mescolarsi con il testo del bestiario. Deliberatamente
	# senza set_anchors_preset(FULL_RECT): nel frame in cui questo nodo
	# viene creato il ridimensionamento via anchor non ha ancora effetto,
	# lasciando bg con size (0, 0) e quindi invisibile (bug osservato su
	# tutte le schermate overlay di questo tipo, con il contenuto
	# sottostante che trasparisce nei punti non coperti dal resto del
	# pannello) — posizione e size fissate qui a mano evitano il problema,
	# dato che il viewport di questo progetto ha dimensioni fisse.
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
	title.text = "Bestiario"
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

# Il pulsante Chiudi sta sotto l'elenco scorrevole: dandogli il focus
# iniziale, "giù" da lì non entra nell'elenco dall'alto come ci si
# aspetterebbe, ma salta al primo controllo navigabile che si trova
# geometricamente sotto di lui — che con l'elenco non ancora scorso è
# l'ULTIMA riga, non la prima (la risoluzione automatica del focus
# ignora l'ordine logico della lista, guarda solo le posizioni a
# schermo). Partire dalla prima riga rende invece "giù" un
# attraversamento naturale dall'alto verso il basso, con "giù"
# dall'ultima riga che arriva comunque a Chiudi.
func focus_first_item() -> void:
	if list_box.get_child_count() > 0:
		list_box.get_child(0).grab_focus()
	else:
		close_btn.grab_focus()

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
	_make_row_focusable(row)

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
