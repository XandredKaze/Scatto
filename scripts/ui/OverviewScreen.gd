class_name OverviewScreen
extends Control

# Finestra "Visualizza": finché il tasto resta premuto (Tab, o View/Select
# sul controller) mostra i potenziamenti ottenuti con la descrizione
# estesa e la mappa ingrandita. NON mette in pausa: il gioco continua
# sotto, quindi guardarla ha un prezzo, come consultare una mappa vera.
#
# Si apre solo durante il gioco vero e proprio: non sopra la scelta del
# potenziamento, le schermate di fine run o il menu di pausa.

const ACTION := "overview"
const MARGIN := 36.0
const MAP_MAX_SIZE := Vector2(600.0, 430.0)

var run: Node = null

var backdrop: ColorRect
var content: HBoxContainer
var big_map: Minimap
var no_map_label: Label
var inventory_label: Label
var powerup_list: GridContainer
var empty_label: Label
var _last_summary := ""
var _built := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deve accorgersi del rilascio del tasto anche se nel frattempo il
	# gioco va in pausa, per non restare aperta sopra il menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	backdrop = ColorRect.new()
	backdrop.color = Palette.with_alpha(Palette.VOID, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	# --- Mappa ingrandita ---
	var map_col := VBoxContainer.new()
	map_col.add_theme_constant_override("separation", 8)
	content.add_child(map_col)
	map_col.add_child(_title("Mappa"))
	big_map = Minimap.new()
	big_map.max_grid_size = MAP_MAX_SIZE
	map_col.add_child(big_map)
	no_map_label = Label.new()
	no_map_label.text = "Qui non c'è una mappa da esplorare."
	no_map_label.modulate = Palette.BONE_DIM
	no_map_label.custom_minimum_size = Vector2(MAP_MAX_SIZE.x, 0)
	map_col.add_child(no_map_label)
	var legend := Label.new()
	legend.text = "Puntino cremisi: tu  ·  barra cremisi: porta del premio (chiusa), divisa ai lati quando è aperta  ·  monconi chiari: passaggi ancora da esplorare"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD
	legend.custom_minimum_size = Vector2(MAP_MAX_SIZE.x, 0)
	legend.add_theme_font_size_override("font_size", 13)
	legend.modulate = Palette.BONE_DIM
	map_col.add_child(legend)

	# --- Potenziamenti ottenuti ---
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 8)
	list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(list_col)
	list_col.add_child(_title("Potenziamenti ottenuti"))
	inventory_label = Label.new()
	inventory_label.modulate = Palette.BONE_DIM
	list_col.add_child(inventory_label)
	powerup_list = GridContainer.new()
	powerup_list.columns = 1
	powerup_list.add_theme_constant_override("h_separation", 18)
	powerup_list.add_theme_constant_override("v_separation", 10)
	list_col.add_child(powerup_list)
	empty_label = Label.new()
	empty_label.text = "Nessun potenziamento, per ora."
	empty_label.modulate = Palette.BONE_DIM
	list_col.add_child(empty_label)

	var hint := Label.new()
	hint.text = "Rilascia per chiudere: il gioco non è in pausa."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Palette.EMBER
	list_col.add_child(hint)

func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Palette.EMBER)
	return label

# Vero quando la finestra può aprirsi: una run in corso, senza schermate
# modali aperte e senza pausa.
func can_open() -> bool:
	if run == null or not is_instance_valid(run) or run.player == null:
		return false
	if get_tree().paused or not run.player.alive:
		return false
	for screen in [run.powerup_choice_screen, run.run_complete_screen, run.game_over_screen, run.pause_screen]:
		if screen != null and screen.visible:
			return false
	return true

func _process(_delta: float) -> void:
	var wanted: bool = Input.is_action_pressed(ACTION) and can_open()
	if not wanted:
		if visible:
			hide()
		return
	if not visible:
		_built = false
		show()
	_refresh()

func _refresh() -> void:
	_layout()
	var small: Minimap = run.hud.minimap
	var has_map: bool = run.current_maze != null and small.maze != null
	big_map.visible = has_map
	no_map_label.visible = not has_map
	if has_map:
		big_map.mirror(small)
	inventory_label.text = "Chiavi virtuali: %d  ·  Gettoni: %d" % [run.player.virtual_keys, SaveManager.tokens()]
	_refresh_powerups()

func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	backdrop.position = Vector2.ZERO
	backdrop.size = view
	content.position = Vector2(MARGIN, MARGIN)
	content.size = view - Vector2(MARGIN, MARGIN) * 2.0

# La lista si ricostruisce solo quando cambia (un potenziamento raccolto
# mentre è aperta), non a ogni frame.
func _refresh_powerups() -> void:
	var counts := {}
	var order: Array = []
	for id in run.player.active_powerups:
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1
	var summary := ""
	for id in order:
		summary += "%s:%d;" % [id, counts[id]]
	if _built and summary == _last_summary:
		return
	_built = true
	_last_summary = summary

	for c in powerup_list.get_children():
		powerup_list.remove_child(c)
		c.queue_free()
	empty_label.visible = order.is_empty()
	# Con molti potenziamenti la lista va su due colonne, piú strette,
	# per restare tutta sullo schermo senza bisogno di scorrerla.
	var two_columns: bool = order.size() > 6
	powerup_list.columns = 2 if two_columns else 1
	var desc_width: float = 250.0 if two_columns else 520.0
	for id in order:
		var entry: Dictionary = GameData.get_powerup(id)
		if entry.is_empty():
			continue
		powerup_list.add_child(_build_entry(entry, counts[id], desc_width))

func _build_entry(entry: Dictionary, count: int, desc_width: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_meta("powerup_id", entry.id)

	var icon := PowerupIcon.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.set_icon(entry.get("icon", "circle"), GameData.rarity_color(entry.rarity))
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	var name_label := Label.new()
	name_label.text = entry.name if count <= 1 else "%s  ×%d" % [entry.name, count]
	name_label.add_theme_font_size_override("font_size", 17)
	col.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = GameData.rarity_name(entry.rarity)
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", GameData.rarity_color(entry.rarity))
	col.add_child(rarity_label)

	var desc_label := Label.new()
	desc_label.name = "Desc"
	desc_label.text = GameData.powerup_details(entry, count)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(desc_width, 0)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.modulate = Palette.BONE
	col.add_child(desc_label)
	return row
