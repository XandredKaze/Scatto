class_name Palette
extends RefCounted

# Linguaggio cromatico unico del gioco, ricavato dal riferimento
# estetico: una cripta gotica quasi nera, in pietra blu-grigia fredda,
# illuminata solo da bagliori cremisi. Tutto ciò che si disegna (arena,
# creature, effetti, interfaccia) pesca da qui, cosí il gioco resta una
# sola immagine coerente invece di una raccolta di colori scelti volta
# per volta nei singoli file.
#
# Le tre regole che tengono in piedi lo stile:
#   1. il fondo è quasi nero e desaturato (VOID -> STONE_EDGE);
#   2. l'unico colore acceso è il cremisi (BLOOD_* / EMBER), usato con
#      parsimonia perché faccia da faro per l'occhio;
#   3. le creature sono masse scure con un profilo luminoso e un volto
#      pallido (BONE): si leggono per silhouette, non per colore pieno.

# --- Pietra e oscurità ---
const VOID := Color8(7, 8, 12)
const STONE_DEEP := Color8(17, 19, 25)
const STONE := Color8(26, 30, 38)
const STONE_LIT := Color8(38, 43, 54)
const STONE_EDGE := Color8(56, 62, 76)
const JOINT := Color8(11, 12, 17)
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)

# --- Cremisi: sangue, stendardi, bagliori ---
const BLOOD_DEEP := Color8(66, 10, 28)
const BLOOD := Color8(158, 20, 56)
const BLOOD_BRIGHT := Color8(226, 36, 82)
const EMBER := Color8(255, 62, 118)

# --- Luci fredde: ossa, acciaio, oro ---
const BONE := Color8(216, 211, 212)
const BONE_DIM := Color8(146, 142, 147)
const STEEL := Color8(158, 177, 198)
const STEEL_DIM := Color8(88, 100, 117)
const GOLD := Color8(216, 170, 80)
# Giallo polline: il cuore del Pungiglione e i dardi che spara. È l'unica
# nota calda del gioco oltre all'oro, e serve proprio a questo: annunciare
# da lontano da dove arriveranno i colpi.
const POLLEN := Color8(246, 214, 92)
# Ambra spenta delle bande dell'insetto: volutamente più cupa dell'oro,
# che resta riservato alla variante dorata.
const CHITIN_AMBER := Color8(184, 136, 64)

# --- Ruoli in combattimento (profilo luminoso delle creature) ---
# Ostile: cremisi. Alleato: acciaio freddo. Dorato: oro.
const RIM_HOSTILE := EMBER
const RIM_ALLY := STEEL
const RIM_GOLDEN := GOLD

# Interfaccia: indicatore pronto / non pronto.
const UI_READY := BLOOD_BRIGHT
const UI_IDLE := Color8(44, 48, 60)
const UI_BG := Color8(13, 14, 19)
const UI_BG_SOFT := Color8(21, 23, 30)

static func with_alpha(base: Color, alpha: float) -> Color:
	return Color(base.r, base.g, base.b, alpha)

# Tema comune a tutti i Control del gioco. Va assegnato alla radice di
# ogni schermata (vedi apply_theme): l'ereditarietà del tema in Godot
# passa solo per Control e Window, quindi un Node2D o un CanvasLayer
# lungo la strada la interrompe — assegnarlo alla finestra principale
# non basterebbe a raggiungere le schermate di gioco.
static var _shared_theme: Theme = null

static func theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = build_theme()
	return _shared_theme

# Applica il tema a `root` e, se richiesto, a ogni suo figlio Control di
# primo livello: comodo per i CanvasLayer, dove ogni schermata è una
# radice a sé.
static func apply_theme(root: Node, include_children: bool = false) -> void:
	if root is Control:
		root.theme = theme()
	if not include_children:
		return
	for child in root.get_children():
		if child is Control:
			child.theme = theme()

static func build_theme() -> Theme:
	var theme := Theme.new()

	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", Color8(255, 236, 240))
	theme.set_color("font_focus_color", "Button", Color8(255, 236, 240))
	theme.set_color("font_pressed_color", "Button", EMBER)
	theme.set_color("font_disabled_color", "Button", STEEL_DIM)

	theme.set_stylebox("normal", "Button", _button_box(UI_BG_SOFT, STONE_EDGE, 1))
	theme.set_stylebox("hover", "Button", _button_box(Color8(31, 22, 30), BLOOD, 1))
	theme.set_stylebox("pressed", "Button", _button_box(Color8(44, 14, 30), BLOOD_BRIGHT, 1))
	theme.set_stylebox("focus", "Button", _button_box(Color(0, 0, 0, 0), EMBER, 2))
	theme.set_stylebox("disabled", "Button", _button_box(Color8(15, 16, 21), Color8(38, 41, 50), 1))

	var panel := _button_box(UI_BG, STONE_EDGE, 1)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# La barra della vita è l'unico elemento a pieno cremisi
	# dell'interfaccia: deve essere la prima cosa che si nota.
	theme.set_stylebox("background", "ProgressBar", _flat_box(Color8(24, 12, 17), 2))
	theme.set_stylebox("fill", "ProgressBar", _flat_box(BLOOD, 2))

	theme.set_color("font_color", "ProgressBar", BONE)
	return theme

static func _flat_box(bg: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	return box

static func _button_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := _flat_box(bg, 3)
	box.set_border_width_all(width)
	box.border_color = border
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
