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
		"tip": "Ti insegue senza sosta: scattagli contro per fermarlo.",
	},
	"pungiglione": {
		"id": "pungiglione", "name": "Pungiglione",
		"hp": 20.0, "speed": 75.0, "damage": 6.0, "radius": 12.0, "color": Color8(63, 184, 175),
		"behavior": "ranged", "keep_distance": 190.0, "attack_cooldown": 1.4, "projectile_speed": 260.0,
		"desc": "Mantiene le distanze e colpisce con dardi velenosi a distanza.",
		"tip": "Mantiene le distanze e spara dardi: scatta verso di lui per chiudere lo spazio.",
	},
	"corazzato": {
		"id": "corazzato", "name": "Corazzato",
		"hp": 75.0, "speed": 55.0, "damage": 16.0, "radius": 20.0, "color": Color8(138, 109, 75),
		"behavior": "chase", "contact_cooldown": 0.8, "min_room": 3,
		"desc": "Una massa corazzata lenta ma devastante da vicino. Appare dalla terza stanza.",
		"tip": "Lento ma incassa molti colpi e fa male da vicino: colpiscilo e allontanati.",
	},
	"sciame": {
		"id": "sciame", "name": "Sciame",
		"hp": 10.0, "speed": 135.0, "damage": 5.0, "radius": 9.0, "color": Color8(201, 107, 176),
		"behavior": "chase", "contact_cooldown": 0.5, "group_min": 3, "group_max": 5, "min_room": 2,
		"desc": "Piccole creature veloci che attaccano sempre in gruppo. Appaiono dalla seconda stanza.",
		"tip": "Veloce e fragile, ma attacca in gruppo: un solo scatto ben piazzato può travolgerne più di uno.",
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

# Ogni voce normale ha una variante speciale corrispondente
# (id + "_corrotto"), usata quando streak_run_index >= 3.
const BOSS_ARCHETYPES := ["custode", "colosso", "spettro"]

const BOSSES := {
	"custode": {
		"id": "custode", "name": "Custode", "hp": 320.0, "speed": 65.0, "radius": 34.0,
		"damage": 18.0, "color": Color8(106, 76, 147),
		"attacks": ["charge", "burst"], "special_attacks": ["volley"],
		"desc": "Il guardiano che veglia sulla sesta stanza di ogni run. Alterna cariche dirette a raffiche di proiettili in cerchio.",
	},
	"custode_corrotto": {
		"id": "custode_corrotto", "name": "Custode Corrotto", "special": true,
		"hp": 480.0, "speed": 75.0, "radius": 38.0, "damage": 24.0,
		"color": Color8(58, 13, 43), "glow": Color8(255, 45, 85),
		"attacks": ["charge", "burst"], "special_attacks": ["volley"],
		"guaranteed_drop": "benedizione_del_custode",
		"desc": "Una versione corrotta del Custode, risvegliata solo da chi incatena tre vittorie senza mai tornare all'Hub. Aggiunge una raffica di proiettili mirati.",
	},
	"colosso": {
		"id": "colosso", "name": "Colosso di Pietra", "hp": 420.0, "speed": 45.0, "radius": 40.0,
		"damage": 20.0, "color": Color8(120, 100, 80),
		"attacks": ["slam", "cono"], "special_attacks": ["richiamo"],
		"desc": "Una massa di roccia lenta ma devastante: colpisce il terreno intorno a sé e scaglia detriti in un cono.",
	},
	"colosso_corrotto": {
		"id": "colosso_corrotto", "name": "Colosso Corrotto", "special": true,
		"hp": 620.0, "speed": 50.0, "radius": 44.0, "damage": 27.0,
		"color": Color8(50, 20, 15), "glow": Color8(255, 120, 40),
		"attacks": ["slam", "cono"], "special_attacks": ["richiamo"],
		"guaranteed_drop": "corazza_di_magma",
		"desc": "Una versione corrotta del Colosso: oltre a colpo al suolo e detriti, richiama sciami di creature in suo aiuto.",
	},
	"spettro": {
		"id": "spettro", "name": "Spettro Errante", "hp": 260.0, "speed": 85.0, "radius": 28.0,
		"damage": 14.0, "color": Color8(150, 180, 220),
		"attacks": ["teletrasporto", "raffica"], "special_attacks": ["raffica_ampia"],
		"desc": "Una presenza inafferrabile che si teletrasporta accanto alla preda e colpisce a distanza con raffiche rapide.",
	},
	"spettro_corrotto": {
		"id": "spettro_corrotto", "name": "Spettro Corrotto", "special": true,
		"hp": 380.0, "speed": 95.0, "radius": 30.0, "damage": 18.0,
		"color": Color8(60, 40, 110), "glow": Color8(140, 80, 255),
		"attacks": ["teletrasporto", "raffica"], "special_attacks": ["raffica_ampia"],
		"guaranteed_drop": "velo_spettrale",
		"desc": "Una versione corrotta dello Spettro: la sua raffica diventa una tempesta di proiettili quasi impossibile da schivare del tutto.",
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
	{"id": "corazza_di_magma", "name": "Corazza di Magma", "rarity": "legendary", "icon": "flame", "desc": "Bottino del Colosso Corrotto. +80 vita massima e +8 danno da scatto.", "dropped_only_by": "colosso_corrotto"},
	{"id": "velo_spettrale", "name": "Velo Spettrale", "rarity": "legendary", "icon": "ghost", "desc": "Bottino dello Spettro Corrotto. +25% velocità di movimento e +0.2s di invulnerabilità extra dopo lo scatto.", "dropped_only_by": "spettro_corrotto"},
]

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color8(244, 196, 48)
		"rare":
			return Color8(122, 162, 247)
		_:
			return Color8(200, 200, 205)

# Pesi relativi per l'estrazione casuale delle scelte di fine stanza: un
# comune è 3 volte più probabile di un raro, un raro 4 volte più
# probabile di un leggendario (quindi un leggendario ~12 volte più raro
# di un comune), cosí i leggendari dei boss sconfitti restano un colpo
# di fortuna occasionale invece di comparire alla pari degli altri.
static func rarity_weight(rarity: String) -> float:
	match rarity:
		"legendary":
			return 1.0
		"rare":
			return 4.0
		_:
			return 12.0

# Estrae `count` voci distinte da `pool` senza reinserimento, con
# probabilità proporzionale al peso di rarità di ciascuna (vedi
# rarity_weight): ad ogni estrazione si ricalcola il peso totale delle
# voci rimaste, cosí l'assenza (o esaurimento) di una rarità non altera
# le proporzioni tra le altre.
static func weighted_pick_without_replacement(pool: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var remaining: Array = pool.duplicate()
	var result: Array = []
	while remaining.size() > 0 and result.size() < count:
		var total_weight := 0.0
		for p in remaining:
			total_weight += rarity_weight(p.rarity)
		var roll: float = rng.randf() * total_weight
		var cumulative := 0.0
		var picked_index: int = remaining.size() - 1
		for i in range(remaining.size()):
			cumulative += rarity_weight(remaining[i].rarity)
			if roll < cumulative:
				picked_index = i
				break
		result.append(remaining[picked_index])
		remaining.remove_at(picked_index)
	return result

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

# Potenziamenti leggendari dei boss speciali già sconfitti almeno una
# volta (bestiario persistente, non nella run corrente): una volta
# dimostrato di poterli battere, il loro bottino può ricomparire come
# scelta casuale di fine stanza in run successive, oltre che come
# bottino garantito la prima volta che li si sconfigge. Esclude
# deliberatamente il Cuore Dorato (bottino dello Strisciante Dorato,
# non di un boss): "dropped_only_by" punta a "strisciante_dorato", che
# non è una chiave di BOSSES.
static func get_unlocked_boss_legendary_pool() -> Array:
	var result: Array = []
	for p in POWERUPS:
		var source: String = p.get("dropped_only_by", "")
		if source == "" or not BOSSES.has(source):
			continue
		if SaveManager.is_enemy_unlocked(source):
			result.append(p)
	return result

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
		"corazza_di_magma":
			player.max_hp += 80.0
			player.hp += 80.0
			player.dash_damage_bonus += 8.0
		"velo_spettrale":
			player.speed_mult += 0.25
			player.extra_iframes += 0.2
