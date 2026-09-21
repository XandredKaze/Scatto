class_name SaveSlotScreen
extends Control

# Scelta del salvataggio, prima dell'Hub. Tre slot indipendenti: ognuno
# si può selezionare per giocarci o svuotare per ricominciare da capo.
#
# Lo svuotamento è distruttivo e irreversibile, quindi chiede conferma:
# il pulsante diventa "Confermi?" e cancella solo alla seconda pressione.
# La conferma scade da sola dopo CONFIRM_TIMEOUT e si annulla toccando
# qualunque altra voce, perché un "sí" restato armato mentre il
# giocatore fa altro è il modo più facile per perdere una partita.

signal slot_chosen(slot: int)

const CONFIRM_TIMEOUT := 4.0

var select_buttons: Array = []
var clear_buttons: Array = []
# Slot con lo svuotamento già armato, in attesa della conferma (0 = nessuno).
var pending_clear_slot := 0
var pending_clear_timer := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = Palette.UI_BG
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(340, 140)
	vbox.custom_minimum_size = Vector2(600, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "SCATTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(600, 0)
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Scegli un salvataggio"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(600, 0)
	subtitle.modulate = Palette.BONE_DIM
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(600, 0)
		vbox.add_child(row)

		var select_btn := Button.new()
		select_btn.custom_minimum_size = Vector2(0, 52)
		# Il pulsante di scelta occupa tutto lo spazio che avanza e
		# taglia il testo se serve: cosí le tre righe restano allineate
		# comunque sia lungo il riepilogo dello slot.
		select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_btn.clip_text = true
		select_btn.pressed.connect(_on_slot_selected.bind(slot))
		row.add_child(select_btn)
		select_buttons.append(select_btn)

		var clear_btn := Button.new()
		clear_btn.custom_minimum_size = Vector2(150, 52)
		clear_btn.pressed.connect(_on_clear_pressed.bind(slot))
		row.add_child(clear_btn)
		clear_buttons.append(clear_btn)

	var hint := Label.new()
	hint.text = "Le impostazioni (volume, video, tasti) sono in comune a tutti i salvataggi."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(600, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Palette.STEEL_DIM
	vbox.add_child(hint)

	_build_focus_chain()
	refresh()
	select_buttons[0].grab_focus()

# Catena di focus esplicita. La risoluzione automatica di Godot, basata
# sulla posizione, in una griglia di pulsanti affiancati sceglie spesso
# una direzione diversa da quella attesa: qui ogni vicino è dichiarato.
func _build_focus_chain() -> void:
	var count: int = select_buttons.size()
	for i in range(count):
		var select_btn: Button = select_buttons[i]
		var clear_btn: Button = clear_buttons[i]
		var next: int = (i + 1) % count
		var previous: int = (i - 1 + count) % count

		select_btn.focus_neighbor_right = clear_btn.get_path()
		clear_btn.focus_neighbor_left = select_btn.get_path()
		select_btn.focus_neighbor_bottom = select_buttons[next].get_path()
		select_btn.focus_neighbor_top = select_buttons[previous].get_path()
		clear_btn.focus_neighbor_bottom = clear_buttons[next].get_path()
		clear_btn.focus_neighbor_top = clear_buttons[previous].get_path()
		# Tabulazione: alterna scelta e svuotamento riga per riga.
		select_btn.focus_next = clear_btn.get_path()
		clear_btn.focus_next = select_buttons[next].get_path()
		select_btn.focus_previous = clear_buttons[previous].get_path()
		clear_btn.focus_previous = select_btn.get_path()

func refresh() -> void:
	for i in range(select_buttons.size()):
		var slot: int = i + 1
		var summary: Dictionary = SaveManager.slot_summary(slot)
		select_buttons[i].text = "Slot %d — %s" % [slot, _summary_text(summary)]
		var clear_btn: Button = clear_buttons[i]
		# Uno slot vuoto non ha niente da svuotare.
		clear_btn.disabled = not summary.exists
		clear_btn.text = "Confermi?" if pending_clear_slot == slot else "Svuota"
		clear_btn.modulate = Palette.EMBER if pending_clear_slot == slot else Color.WHITE

func _summary_text(summary: Dictionary) -> String:
	if not summary.exists:
		return "vuoto"
	return "%d vinte · serie %d · %d potenziamenti · %d creature" % [
		summary.runs_won, summary.best_streak, summary.powerups, summary.bestiary
	]

func _process(delta: float) -> void:
	if pending_clear_slot == 0:
		return
	pending_clear_timer -= delta
	if pending_clear_timer <= 0.0:
		_cancel_pending_clear()

func _on_slot_selected(slot: int) -> void:
	# Scegliere uno slot annulla una conferma rimasta armata altrove.
	_cancel_pending_clear()
	SaveManager.use_slot(slot)
	slot_chosen.emit(slot)

func _on_clear_pressed(slot: int) -> void:
	if pending_clear_slot == slot:
		SaveManager.clear_slot(slot)
		_cancel_pending_clear()
		# Svuotato lo slot non c'è più niente da cancellare: il focus
		# passa alla scelta, che è l'unica azione rimasta su questa riga.
		select_buttons[slot - 1].grab_focus()
		return
	pending_clear_slot = slot
	pending_clear_timer = CONFIRM_TIMEOUT
	refresh()

func _cancel_pending_clear() -> void:
	if pending_clear_slot == 0:
		return
	pending_clear_slot = 0
	pending_clear_timer = 0.0
	refresh()
