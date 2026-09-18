class_name GameData
extends RefCounted

# Definizioni statiche di tutti i dati di gioco: nemici, variante dorata,
# boss e potenziamenti. Nessuna istanza di questa classe viene mai creata:
# viene usata solo come contenitore di costanti e funzioni statiche.

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"

const ENEMY_TYPES := {
	"strisciante": {
		"id": "strisciante", "name": "Strisciante", "common": true,
		"hp": 30.0, "speed": 95.0, "damage": 8.0, "radius": 14.0, "color": Color8(127, 174, 86),
		"behavior": "chase", "contact_cooldown": 0.6,
		"desc": "Un predatore comune che insegue la sua preda senza sosta.",
	},
	"pungiglione": {
		"id": "pungiglione", "name": "Pungiglione",
		"hp": 20.0, "speed": 75.0, "damage": 6.0, "radius": 12.0, "color": Color8(63, 184, 175),
		"behavior": "ranged", "keep_distance": 190.0, "attack_cooldown": 1.4, "projectile_speed": 260.0,
		"desc": "Mantiene le distanze e colpisce con dardi velenosi a distanza.",
	},
	"corazzato": {
		"id": "corazzato", "name": "Corazzato",
		"hp": 75.0, "speed": 55.0, "damage": 16.0, "radius": 20.0, "color": Color8(138, 109, 75),
		"behavior": "chase", "contact_cooldown": 0.8, "min_room": 3,
		"desc": "Una massa corazzata lenta ma devastante da vicino. Appare dalla terza stanza.",
	},
	"sciame": {
		"id": "sciame", "name": "Sciame",
		"hp": 10.0, "speed": 135.0, "damage": 5.0, "radius": 9.0, "color": Color8(201, 107, 176),
		"behavior": "chase", "contact_cooldown": 0.5, "group_min": 3, "group_max": 5, "min_room": 2,
		"desc": "Piccole creature veloci che attaccano sempre in gruppo. Appaiono dalla seconda stanza.",
	},
}

# L'avversario comune con variante dorata: 1 possibilità su GOLDEN_CHANCE_DENOMINATOR
# di comparire in una stanza al posto (o in aggiunta) allo Strisciante normale.
const GOLDEN_VARIANTS := {
	"strisciante": {
		"id": "strisciante_dorato", "name": "Strisciante Dorato", "base_id": "strisciante",
		"hp_mult": 3.5, "speed_mult": 1.3, "damage_mult": 1.5, "color": Color8(244, 196, 48),
		"guaranteed_drop": "cuore_dorato",
		"desc": "Una rarissima variante dorata dello Strisciante. Si dice porti fortuna a chi la sconfigge.",
	},
}

const GOLDEN_CHANCE_DENOMINATOR := 4096

const BOSSES := {
	"custode": {
		"id": "custode", "name": "Custode", "hp": 320.0, "speed": 65.0, "radius": 34.0,
		"damage": 18.0, "color": Color8(106, 76, 147),
		"desc": "Il guardiano che veglia sulla sesta stanza di ogni run.",
	},
	"custode_corrotto": {
		"id": "custode_corrotto", "name": "Custode Corrotto", "special": true,
		"hp": 480.0, "speed": 75.0, "radius": 38.0, "damage": 24.0,
		"color": Color8(58, 13, 43), "glow": Color8(255, 45, 85),
		"guaranteed_drop": "benedizione_del_custode",
		"desc": "Una versione corrotta del Custode, risvegliata solo da chi incatena tre vittorie senza mai tornare all'Hub.",
	},
}

const POWERUPS := [
	{"id": "lama_rapida", "name": "Lama Rapida", "rarity": "common", "icon": "sword", "desc": "+6 danno da scatto."},
	{"id": "passo_veloce", "name": "Passo Veloce", "rarity": "common", "icon": "boot", "desc": "+15% velocità di movimento."},
	{"id": "scatto_lungo", "name": "Scatto Lungo", "rarity": "common", "icon": "arrow", "desc": "+25% distanza dello scatto."},
	{"id": "cuore_di_ferro", "name": "Cuore di Ferro", "rarity": "common", "icon": "heart", "desc": "+25 punti vita massimi."},
	{"id": "scatto_fulmine", "name": "Scatto Fulmine", "rarity": "rare", "icon": "bolt", "desc": "-20% tempo di recupero dello scatto."},
	{"id": "scatto_fantasma", "name": "Scatto Fantasma", "rarity": "rare", "icon": "ghost", "desc": "+0.15s di invulnerabilità dopo lo scatto."},
	{"id": "doppio_scatto", "name": "Doppio Scatto", "rarity": "rare", "icon": "double", "desc": "Aggiunge una carica di scatto."},
	{"id": "contrattacco", "name": "Contrattacco", "rarity": "rare", "icon": "cycle", "desc": "Un'uccisione con lo scatto restituisce subito una carica di scatto."},
	{"id": "furia", "name": "Furia", "rarity": "rare", "icon": "flame", "desc": "Più sei ferito, più danno infligge il tuo scatto (fino a +50%)."},
	{"id": "cuore_dorato", "name": "Cuore Dorato", "rarity": "legendary", "icon": "heart_gold", "desc": "Bottino di uno Strisciante Dorato. +40 vita massima e +10 danno da scatto.", "dropped_only_by": "strisciante_dorato"},
	{"id": "benedizione_del_custode", "name": "Benedizione del Custode", "rarity": "legendary", "icon": "shield", "desc": "Concessa dal Custode Corrotto. Lo scatto genera un'onda d'urto che danneggia i nemici vicini.", "dropped_only_by": "custode_corrotto"},
]

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color8(244, 196, 48)
		"rare":
			return Color8(122, 162, 247)
		_:
			return Color8(200, 200, 205)

static func build_golden_enemy_data(base_id: String) -> Dictionary:
	var base: Dictionary = ENEMY_TYPES[base_id]
	var golden: Dictionary = GOLDEN_VARIANTS[base_id]
	var merged: Dictionary = base.duplicate()
	merged["id"] = golden["id"]
	merged["name"] = golden["name"]
	merged["color"] = golden["color"]
	merged["hp"] = float(base["hp"]) * float(golden["hp_mult"])
	merged["speed"] = float(base["speed"]) * float(golden["speed_mult"])
	merged["damage"] = float(base["damage"]) * float(golden["damage_mult"])
	merged["guaranteed_drop"] = golden["guaranteed_drop"]
	merged["desc"] = golden["desc"]
	merged["is_golden"] = true
	return merged

static func get_powerup(id: String) -> Dictionary:
	for p in POWERUPS:
		if p.id == id:
			return p
	return {}

static func get_regular_powerup_pool() -> Array:
	return POWERUPS.filter(func(p): return not p.has("dropped_only_by"))

static func apply_powerup(id: String, player: Node) -> void:
	match id:
		"lama_rapida":
			player.dash_damage_bonus += 6.0
		"passo_veloce":
			player.speed_mult += 0.15
		"scatto_lungo":
			player.dash_distance_mult += 0.25
		"cuore_di_ferro":
			player.max_hp += 25.0
			player.hp += 25.0
		"scatto_fulmine":
			player.dash_cooldown_mult *= 0.8
		"scatto_fantasma":
			player.extra_iframes += 0.15
		"doppio_scatto":
			player.max_dash_charges += 1
			player.dash_charges += 1
		"contrattacco":
			player.has_contrattacco = true
		"furia":
			player.has_furia = true
		"cuore_dorato":
			player.max_hp += 40.0
			player.hp += 40.0
			player.dash_damage_bonus += 10.0
		"benedizione_del_custode":
			player.has_shockwave = true
