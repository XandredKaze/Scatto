class_name GameData
extends RefCounted

# Definizioni di tutti i dati di gioco: nemici, variante dorata, boss e
# potenziamenti. Qui stanno le parti fisse (nomi, colori, comportamenti,
# testi); i numeri di bilanciamento stanno in BalanceConfig, modificabile
# dall'editor aprendo res://bilanciamento.tres. Nessuna istanza di questa
# classe viene mai creata: solo costanti, proprietà e funzioni statiche.

const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"

# Le parti fisse di ogni nemico (nome, colore, comportamento, testi). I
# NUMERI (vita, velocità, danno...) stanno in BalanceConfig, cioè in
# res://bilanciamento.tres, e vengono uniti a queste voci in ENEMY_TYPES.
const _ENEMY_BASE := {
	"strisciante": {
		"id": "strisciante", "name": "Strisciante", "common": true,
		"radius": 14.0, "color": Color8(104, 44, 52),
		"behavior": "chase", "shape": "slime", "attack_pattern": "morso",
		"desc": "Una melma nera e allungata che striscia come un serpente: raggiunta la preda si ferma a un soffio da lei e affonda il morso, poi riprende a inseguirla.",
		"tip": "Si ferma a un soffio da te per morderti: quell'attimo di immobilità è il momento buono per colpirlo.",
	},
	"pungiglione": {
		"id": "pungiglione", "name": "Pungiglione",
		"radius": 12.0, "color": Color8(246, 214, 92),
		"behavior": "ranged", "shape": "flower", "attack_pattern": "agguato",
		"desc": "Un fiore carnivoro dai petali rossi e bianchi, abbarbicato alle pareti: sputa dardi di polline velenoso e tra un colpo e l'altro sprofonda nel pavimento per rispuntare poco più in là.",
		"tip": "Non insegue: spara e sprofonda. Colpiscilo appena rispunta, prima che il dardo parta.",
	},
	"corazzato": {
		"id": "corazzato", "name": "Corazzato",
		"radius": 20.0, "color": Color8(112, 94, 74),
		"behavior": "chase", "shape": "brute", "attack_pattern": "salto",
		"desc": "Una massa corazzata che avanza a piccoli balzi: ogni atterraggio scarica a terra un'onda d'urto. Lenta, ma devastante da vicino. Appare dalla {dalla} mappa.",
		"tip": "Non basta stargli lontano: ogni suo atterraggio scarica un'onda d'urto intorno a sé. Colpiscilo e allontanati.",
	},
	"sciame": {
		"id": "sciame", "name": "Sciame",
		"radius": 9.0, "color": Color8(126, 58, 104),
		"behavior": "chase", "shape": "insect", "attack_pattern": "carica",
		"desc": "Insetti volanti dalle mandibole spalancate, sempre in sciame. A tiro della preda si fermano a caricare per un attimo, poi si lanciano in picchiata. Appaiono dalla {dalla} mappa.",
		"tip": "Prima di lanciarsi resta fermo a caricare: è lí che lo prendi. Fragile, ma attacca in gruppo.",
	},
}

# Dati di gioco completi (parti fisse + numeri di bilanciamento). Sono
# proprietà calcolate: chi le legge non deve sapere da dove vengono i
# numeri, e le tabelle si rigenerano da sole se cambia la configurazione.
static var ENEMY_TYPES: Dictionary:
	get:
		_refresh()
		return _enemy_types
static var ALLY_SPECIAL_ATTACKS: Dictionary:
	get:
		_refresh()
		return _ally_special_attacks
static var GOLDEN_VARIANTS: Dictionary:
	get:
		_refresh()
		return _golden_variants
static var BOSSES: Dictionary:
	get:
		_refresh()
		return _bosses
static var POWERUPS: Array:
	get:
		_refresh()
		return _powerups

static var _enemy_types: Dictionary = {}
static var _ally_special_attacks: Dictionary = {}
static var _golden_variants: Dictionary = {}
static var _bosses: Dictionary = {}
static var _powerups: Array = []
static var _built_version := -1

# Rigenera le tabelle se la configurazione di bilanciamento in uso è
# cambiata (o se non sono mai state costruite).
static func _refresh() -> void:
	var c: BalanceConfig = BalanceConfig.current()
	if _built_version == BalanceConfig.version:
		return
	_built_version = BalanceConfig.version
	_enemy_types = _build_enemy_types(c)
	_ally_special_attacks = _build_ally_special_attacks(c)
	_golden_variants = _build_golden_variants(c)
	_bosses = _build_bosses(c)
	_powerups = _build_powerups(c)

static func _build_enemy_types(c: BalanceConfig) -> Dictionary:
	var t: Dictionary = _ENEMY_BASE.duplicate(true)
	_set_stats(t.strisciante, c.strisciante_vita, c.strisciante_velocità, c.strisciante_danno)
	t.strisciante["contact_cooldown"] = c.strisciante_ricarica_contatto

	_set_stats(t.pungiglione, c.pungiglione_vita, c.pungiglione_velocità, c.pungiglione_danno)
	t.pungiglione["keep_distance"] = c.pungiglione_distanza
	t.pungiglione["attack_cooldown"] = c.pungiglione_ricarica_tiro
	t.pungiglione["projectile_speed"] = c.pungiglione_velocità_dardo

	_set_stats(t.corazzato, c.corazzato_vita, c.corazzato_velocità, c.corazzato_danno)
	t.corazzato["contact_cooldown"] = c.corazzato_ricarica_contatto
	t.corazzato["min_room"] = c.corazzato_dalla_mappa
	t.corazzato["desc"] = String(t.corazzato.desc).format({"dalla": _ordinal(c.corazzato_dalla_mappa)})

	_set_stats(t.sciame, c.sciame_vita, c.sciame_velocità, c.sciame_danno)
	t.sciame["contact_cooldown"] = c.sciame_ricarica_contatto
	t.sciame["min_room"] = c.sciame_dalla_mappa
	t.sciame["group_min"] = min(c.sciame_gruppo_min, c.sciame_gruppo_max)
	t.sciame["group_max"] = max(c.sciame_gruppo_min, c.sciame_gruppo_max)
	t.sciame["desc"] = String(t.sciame.desc).format({"dalla": _ordinal(c.sciame_dalla_mappa)})
	return t

static func _set_stats(entry: Dictionary, hp: float, speed: float, damage: float) -> void:
	entry["hp"] = hp
	entry["speed"] = speed
	entry["damage"] = damage

static func _build_ally_special_attacks(c: BalanceConfig) -> Dictionary:
	var t: Dictionary = _ALLY_SPECIAL_BASE.duplicate(true)
	t.strisciante["cooldown"] = c.speciale_morso_ricarica
	t.pungiglione["cooldown"] = c.speciale_dardo_ricarica
	t.corazzato["cooldown"] = c.speciale_colpo_ricarica
	t.sciame["cooldown"] = c.speciale_raffica_ricarica
	return t

static func _build_golden_variants(c: BalanceConfig) -> Dictionary:
	var t: Dictionary = _GOLDEN_BASE.duplicate(true)
	t.strisciante["hp_mult"] = c.dorato_moltiplicatore_vita
	t.strisciante["speed_mult"] = c.dorato_moltiplicatore_velocità
	t.strisciante["damage_mult"] = c.dorato_moltiplicatore_danno
	return t

static func _build_bosses(c: BalanceConfig) -> Dictionary:
	var t: Dictionary = _BOSS_BASE.duplicate(true)
	_set_stats(t.custode, c.custode_vita, c.custode_velocità, c.custode_danno)
	_set_stats(t.custode_corrotto, c.custode_corrotto_vita, c.custode_corrotto_velocità, c.custode_corrotto_danno)
	_set_stats(t.colosso, c.colosso_vita, c.colosso_velocità, c.colosso_danno)
	_set_stats(t.colosso_corrotto, c.colosso_corrotto_vita, c.colosso_corrotto_velocità, c.colosso_corrotto_danno)
	_set_stats(t.spettro, c.spettro_vita, c.spettro_velocità, c.spettro_danno)
	_set_stats(t.spettro_corrotto, c.spettro_corrotto_vita, c.spettro_corrotto_velocità, c.spettro_corrotto_danno)
	return t

# Le descrizioni dei potenziamenti citano i loro numeri: si compongono
# qui dai valori in uso, cosí restano vere qualunque cosa si cambi.
static func _build_powerups(c: BalanceConfig) -> Array:
	var values := {
		"lama_rapida": {"danno": _num(c.potenziamento_lama_rapida_danno)},
		"passo_veloce": {"velocita": _num(c.potenziamento_passo_veloce_velocità)},
		"scatto_lungo": {"distanza": _num(c.potenziamento_scatto_lungo_distanza)},
		"cuore_di_ferro": {"vita": _num(c.potenziamento_cuore_di_ferro_vita)},
		"zanne_affilate": {"danno": _num(c.potenziamento_zanne_affilate_danno)},
		"richiamo_rapido": {"riduzione": _num(c.potenziamento_richiamo_rapido_riduzione)},
		"pelle_coriacea": {"vita": _num(c.potenziamento_pelle_coriacea_vita)},
		"istinto_di_branco": {"danno": _num(c.potenziamento_istinto_di_branco_danno)},
		"scatto_fulmine": {"riduzione": _num(c.potenziamento_scatto_fulmine_riduzione)},
		"scatto_fantasma": {"secondi": _num(c.potenziamento_scatto_fantasma_invulnerabilità)},
		"doppio_scatto": {"cariche_testo": "Aggiunge una carica di scatto." if c.potenziamento_doppio_scatto_cariche == 1 else "Aggiunge %d cariche di scatto." % c.potenziamento_doppio_scatto_cariche},
		"furia": {"massimo": _num(c.potenziamento_furia_danno_massimo)},
		"eco_selvaggia": {"riduzione": _num(c.potenziamento_eco_selvaggia_riduzione)},
		"vincolo_vitale": {"cura": _num(c.potenziamento_vincolo_vitale_cura)},
		"passo_del_predatore": {"velocita": _num(c.potenziamento_passo_del_predatore_velocità)},
		"cuore_dorato": {"vita": _num(c.potenziamento_cuore_dorato_vita), "danno": _num(c.potenziamento_cuore_dorato_danno)},
		"corazza_di_magma": {"vita": _num(c.potenziamento_corazza_di_magma_vita), "danno": _num(c.potenziamento_corazza_di_magma_danno)},
		"velo_spettrale": {"velocita": _num(c.potenziamento_velo_spettrale_velocità), "secondi": _num(c.potenziamento_velo_spettrale_invulnerabilità)},
	}
	var result: Array = []
	for base in _POWERUP_BASE:
		var entry: Dictionary = base.duplicate(true)
		if values.has(entry.id):
			entry["desc"] = String(entry.desc).format(values[entry.id])
		result.append(entry)
	return result

# Un numero come lo si scrive in una descrizione: niente ".0" sugli interi,
# al massimo due decimali sugli altri.
static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2)

static func _ordinal(n: int) -> String:
	var words := ["prima", "seconda", "terza", "quarta", "quinta"]
	return words[n - 1] if n >= 1 and n <= words.size() else "%d°" % n

# Attacco speciale concesso al giocatore da un alleato di questo tipo
# (vedi Player.granted_ability_ids e Run._on_special_attack_requested):
# ogni nemico comune diventa un'abilità attiva diversa una volta reso
# amico, in tema con il suo comportamento originale da ostile. Ogni alleato
# vivo occupa un proprio pulsante (fino a due); se i due
# alleati vivi sono dello stesso tipo, condividono un solo pulsante in
# versione "potenziata" (EMPOWERED_DAMAGE_MULT e affini qui sotto).
# Tempo di recupero e danno di ogni attacco stanno in BalanceConfig
# ("Attacchi speciali degli alleati"); i valori di partenza seguono questa
# logica:
#
# - corpo a corpo (Morso Selvaggio): tanto danno, pochi colpi -> il
#   recupero più lungo, ma un singolo colpo stende quasi ogni nemico comune;
# - a distanza (Dardo Velenoso): poco danno, tanti colpi -> il recupero
#   più breve di tutti, si tira quasi a raffica ma ogni dardo punge poco
#   e può mancare il bersaglio;
# - ad area (Colpo Corazzato): bilanciato -> danno e ritmo intermedi, ma
#   colpisce tutti i nemici intorno invece di uno solo;
# - a raffica circolare (Sciame Vendicativo): variante "a distanza" che
#   sacrifica il danno del singolo proiettile per coprire ogni direzione.
const _ALLY_SPECIAL_BASE := {
	"strisciante": {
		"name": "Morso Selvaggio", "icon": "sword",
		"desc": "Un balzo che morde tutti i nemici davanti a te: tanto danno, colpi radi.",
	},
	"pungiglione": {
		"name": "Dardo Velenoso", "icon": "arrow",
		"desc": "Scaglia un dardo avvelenato nella direzione in cui guardi: poco danno, ma quasi a raffica.",
	},
	"corazzato": {
		"name": "Colpo Corazzato", "icon": "shield",
		"desc": "Un'onda d'urto che danneggia tutti i nemici intorno a te: danno e ritmo bilanciati.",
	},
	"sciame": {
		"name": "Sciame Vendicativo", "icon": "bolt",
		"desc": "Una raffica di proiettili deboli in tutte le direzioni intorno a te.",
	},
}

# Versione potenziata degli attacchi speciali (due alleati dello stesso
# tipo condividono un pulsante): moltiplicatore di danno di Morso Selvaggio
# e Colpo Corazzato, scarto angolare (radianti) del secondo Dardo Velenoso,
# proiettili di Sciame Vendicativo. Valori in BalanceConfig.
static var EMPOWERED_DAMAGE_MULT: float:
	get: return BalanceConfig.current().potenziato_moltiplicatore_danno
static var EMPOWERED_DART_SPREAD: float:
	get: return deg_to_rad(BalanceConfig.current().potenziato_scarto_secondo_dardo)
static var EMPOWERED_SWARM_COUNT: int:
	get: return BalanceConfig.current().potenziato_proiettili_raffica

# L'avversario comune con variante dorata: 1 possibilità su GOLDEN_CHANCE_DENOMINATOR
# di comparire in una stanza al posto (o in aggiunta) allo Strisciante normale.
const _GOLDEN_BASE := {
	"strisciante": {
		"id": "strisciante_dorato", "name": "Strisciante Dorato", "base_id": "strisciante",
		"color": Color8(244, 196, 48),
		"guaranteed_drop": "cuore_dorato",
		"desc": "Una rarissima variante dorata dello Strisciante. Si dice porti fortuna a chi la sconfigge.",
	},
}

static var GOLDEN_CHANCE_DENOMINATOR: int:
	get: return BalanceConfig.current().dorato_una_su

# Ogni voce normale ha una variante speciale corrispondente
# (id + "_corrotto"), usata quando streak_run_index >= 3.
const BOSS_ARCHETYPES := ["custode", "colosso", "spettro"]

const _BOSS_BASE := {
	"custode": {
		"id": "custode", "name": "Custode", "radius": 34.0,
		"color": Color8(58, 42, 82), "shape": "custode", "glow": Color8(150, 196, 255),
		"attacks": ["charge", "burst"], "special_attacks": ["volley"],
		"desc": "Il guardiano che veglia sulla sesta stanza di ogni run. Alterna cariche dirette a raffiche di proiettili in cerchio.",
	},
	"custode_corrotto": {
		"id": "custode_corrotto", "name": "Custode Corrotto", "special": true,
		"radius": 38.0,
		"color": Color8(48, 10, 30), "glow": Color8(255, 62, 118), "shape": "custode",
		"attacks": ["charge", "burst"], "special_attacks": ["volley"],
		"guaranteed_drop": "benedizione_del_custode",
		"desc": "Una versione corrotta del Custode, risvegliata solo da chi incatena tre vittorie senza mai tornare all'Hub. Aggiunge una raffica di proiettili mirati.",
	},
	"colosso": {
		"id": "colosso", "name": "Colosso di Pietra", "radius": 40.0,
		"color": Color8(74, 66, 58), "shape": "colosso", "glow": Color8(238, 154, 74),
		"attacks": ["slam", "cono"], "special_attacks": ["richiamo"],
		"desc": "Una massa di roccia lenta ma devastante: colpisce il terreno intorno a sé e scaglia detriti in un cono.",
	},
	"colosso_corrotto": {
		"id": "colosso_corrotto", "name": "Colosso Corrotto", "special": true,
		"radius": 44.0,
		"color": Color8(44, 18, 14), "glow": Color8(255, 116, 72), "shape": "colosso",
		"attacks": ["slam", "cono"], "special_attacks": ["richiamo"],
		"guaranteed_drop": "corazza_di_magma",
		"desc": "Una versione corrotta del Colosso: oltre a colpo al suolo e detriti, richiama sciami di creature in suo aiuto.",
	},
	"spettro": {
		"id": "spettro", "name": "Spettro Errante", "radius": 28.0,
		"color": Color8(92, 112, 138), "shape": "spettro", "glow": Color8(168, 226, 232),
		"attacks": ["teletrasporto", "raffica"], "special_attacks": ["raffica_ampia"],
		"desc": "Una presenza inafferrabile che si teletrasporta accanto alla preda e colpisce a distanza con raffiche rapide.",
	},
	"spettro_corrotto": {
		"id": "spettro_corrotto", "name": "Spettro Corrotto", "special": true,
		"radius": 30.0,
		"color": Color8(44, 30, 78), "glow": Color8(154, 104, 255), "shape": "spettro",
		"attacks": ["teletrasporto", "raffica"], "special_attacks": ["raffica_ampia"],
		"guaranteed_drop": "velo_spettrale",
		"desc": "Una versione corrotta dello Spettro: la sua raffica diventa una tempesta di proiettili quasi impossibile da schivare del tutto.",
	},
}

# "needs_dash": il potenziamento agisce solo sullo scatto, quindi non
# viene nemmeno offerto tra le scelte di fine stanza a chi lo scatto non
# ce l'ha più (cioè a chi ha alleati al seguito, vedi Player.has_dash() e
# Run._roll_powerup_choices). Resta comunque valido se già raccolto: se
# tutti gli alleati cadono, lo scatto — e i suoi potenziamenti — tornano.
const _POWERUP_BASE := [
	{"id": "lama_rapida", "name": "Lama Rapida", "rarity": "common", "icon": "sword", "needs_dash": true, "desc": "+{danno} danno da scatto."},
	{"id": "passo_veloce", "name": "Passo Veloce", "rarity": "common", "icon": "boot", "desc": "+{velocita}% velocità di movimento."},
	{"id": "scatto_lungo", "name": "Scatto Lungo", "rarity": "common", "icon": "arrow", "needs_dash": true, "desc": "+{distanza}% distanza dello scatto."},
	{"id": "cuore_di_ferro", "name": "Cuore di Ferro", "rarity": "common", "icon": "heart", "desc": "+{vita} punti vita massimi."},
	{"id": "zanne_affilate", "name": "Zanne Affilate", "rarity": "common", "icon": "sword", "desc": "+{danno}% danno degli attacchi speciali degli alleati."},
	{"id": "richiamo_rapido", "name": "Richiamo Rapido", "rarity": "common", "icon": "cycle", "desc": "-{riduzione}% tempo di recupero dell'addomesticamento."},
	{"id": "pelle_coriacea", "name": "Pelle Coriacea", "rarity": "common", "icon": "shield", "desc": "+{vita}% vita massima degli alleati."},
	{"id": "istinto_di_branco", "name": "Istinto di Branco", "rarity": "common", "icon": "fang", "desc": "+{danno}% danno inflitto dagli alleati in combattimento."},
	{"id": "scatto_fulmine", "name": "Scatto Fulmine", "rarity": "rare", "icon": "bolt", "needs_dash": true, "desc": "-{riduzione}% tempo di recupero dello scatto."},
	{"id": "scatto_fantasma", "name": "Scatto Fantasma", "rarity": "rare", "icon": "ghost", "needs_dash": true, "desc": "+{secondi}s di invulnerabilità dopo lo scatto."},
	{"id": "doppio_scatto", "name": "Doppio Scatto", "rarity": "rare", "icon": "double", "needs_dash": true, "desc": "{cariche_testo}"},
	{"id": "contrattacco", "name": "Contrattacco", "rarity": "rare", "icon": "cycle", "needs_dash": true, "desc": "Un'uccisione con lo scatto restituisce subito una carica di scatto."},
	{"id": "furia", "name": "Furia", "rarity": "rare", "icon": "flame", "needs_dash": true, "desc": "Più sei ferito, più danno infligge il tuo scatto (fino a +{massimo}%)."},
	{"id": "eco_selvaggia", "name": "Eco Selvaggia", "rarity": "rare", "icon": "bolt", "desc": "-{riduzione}% tempo di recupero degli attacchi speciali degli alleati."},
	{"id": "vincolo_vitale", "name": "Vincolo Vitale", "rarity": "rare", "icon": "heart", "desc": "Quando un alleato cade recuperi {cura} vita e l'addomesticamento torna subito pronto."},
	{"id": "passo_del_predatore", "name": "Passo del Predatore", "rarity": "rare", "icon": "boot", "desc": "+{velocita}% velocità di movimento mentre hai almeno un alleato."},
	{"id": "richiamo_primordiale", "name": "Richiamo Primordiale", "rarity": "rare", "icon": "paw", "desc": "Addomesticare un nemico azzera il tempo di recupero di tutti gli attacchi speciali."},
	{"id": "vincolo_spezzato", "name": "Vincolo Spezzato", "rarity": "legendary", "icon": "link", "desc": "Conservi lo scatto anche mentre hai alleati al seguito."},
	{"id": "anima_del_branco", "name": "Anima del Branco", "rarity": "legendary", "icon": "paw", "desc": "Gli attacchi speciali degli alleati sono sempre nella versione potenziata."},
	{"id": "cuore_dorato", "name": "Cuore Dorato", "rarity": "legendary", "icon": "heart_gold", "desc": "Bottino di uno Strisciante Dorato. +{vita} vita massima e +{danno} danno da scatto.", "dropped_only_by": "strisciante_dorato"},
	{"id": "benedizione_del_custode", "name": "Benedizione del Custode", "rarity": "legendary", "icon": "shield", "needs_dash": true, "desc": "Concessa dal Custode Corrotto. Lo scatto genera un'onda d'urto che danneggia i nemici vicini.", "dropped_only_by": "custode_corrotto"},
	{"id": "corazza_di_magma", "name": "Corazza di Magma", "rarity": "legendary", "icon": "flame", "desc": "Bottino del Colosso Corrotto. +{vita} vita massima e +{danno} danno da scatto.", "dropped_only_by": "colosso_corrotto"},
	{"id": "velo_spettrale", "name": "Velo Spettrale", "rarity": "legendary", "icon": "ghost", "desc": "Bottino dello Spettro Corrotto. +{velocita}% velocità di movimento e +{secondi}s di invulnerabilità extra dopo lo scatto.", "dropped_only_by": "spettro_corrotto"},
]

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color8(244, 196, 48)
		"rare":
			return Color8(124, 150, 196)
		_:
			return Color8(196, 191, 192)

# Pesi relativi per l'estrazione casuale delle scelte oltre la porta (in
# BalanceConfig, gruppo "Ricompense"). Con i valori di partenza un comune
# è 3 volte più probabile di un raro e un raro 4 volte più di un
# leggendario, cosí i leggendari dei boss sconfitti restano un colpo di
# fortuna occasionale invece di comparire alla pari degli altri.
static func rarity_weight(rarity: String) -> float:
	var c: BalanceConfig = BalanceConfig.current()
	match rarity:
		"legendary":
			return c.ricompense_peso_leggendario
		"rare":
			return c.ricompense_peso_raro
		_:
			return c.ricompense_peso_comune

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
	var c: BalanceConfig = BalanceConfig.current()
	match id:
		"lama_rapida":
			player.dash_damage_bonus += c.potenziamento_lama_rapida_danno
		"passo_veloce":
			player.speed_mult += c.potenziamento_passo_veloce_velocità / 100.0
		"scatto_lungo":
			player.dash_distance_mult += c.potenziamento_scatto_lungo_distanza / 100.0
		"cuore_di_ferro":
			player.max_hp += c.potenziamento_cuore_di_ferro_vita
			player.hp += c.potenziamento_cuore_di_ferro_vita
		"scatto_fulmine":
			player.dash_cooldown_mult *= 1.0 - c.potenziamento_scatto_fulmine_riduzione / 100.0
		"scatto_fantasma":
			player.extra_iframes += c.potenziamento_scatto_fantasma_invulnerabilità
		"doppio_scatto":
			player.max_dash_charges += c.potenziamento_doppio_scatto_cariche
			player.dash_charges += c.potenziamento_doppio_scatto_cariche
		"contrattacco":
			player.has_contrattacco = true
		"furia":
			player.has_furia = true
		"zanne_affilate":
			player.special_damage_mult += c.potenziamento_zanne_affilate_danno / 100.0
		"richiamo_rapido":
			player.tame_cooldown_mult *= 1.0 - c.potenziamento_richiamo_rapido_riduzione / 100.0
		"pelle_coriacea":
			player.ally_hp_mult += c.potenziamento_pelle_coriacea_vita / 100.0
		"istinto_di_branco":
			player.ally_damage_mult += c.potenziamento_istinto_di_branco_danno / 100.0
		"eco_selvaggia":
			player.special_cooldown_mult *= 1.0 - c.potenziamento_eco_selvaggia_riduzione / 100.0
		"vincolo_vitale":
			player.has_vincolo_vitale = true
		"passo_del_predatore":
			player.pack_speed_bonus += c.potenziamento_passo_del_predatore_velocità / 100.0
		"richiamo_primordiale":
			player.has_richiamo_primordiale = true
		"vincolo_spezzato":
			player.keeps_dash_with_allies = true
		"anima_del_branco":
			player.always_empowered = true
		"cuore_dorato":
			player.max_hp += c.potenziamento_cuore_dorato_vita
			player.hp += c.potenziamento_cuore_dorato_vita
			player.dash_damage_bonus += c.potenziamento_cuore_dorato_danno
		"benedizione_del_custode":
			player.has_shockwave = true
		"corazza_di_magma":
			player.max_hp += c.potenziamento_corazza_di_magma_vita
			player.hp += c.potenziamento_corazza_di_magma_vita
			player.dash_damage_bonus += c.potenziamento_corazza_di_magma_danno
		"velo_spettrale":
			player.speed_mult += c.potenziamento_velo_spettrale_velocità / 100.0
			player.extra_iframes += c.potenziamento_velo_spettrale_invulnerabilità
