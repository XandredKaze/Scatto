class_name Enemy
extends CombatEntity

# Nemico comune di stanza. Il comportamento "chase" insegue il giocatore,
# "ranged" mantiene le distanze e spara proiettili. setup_from_data()
# deve essere chiamato PRIMA di aggiungere il nodo all'albero, cosí che
# _ready() costruisca la CollisionShape2D con il raggio corretto.
#
# Se `maze` è impostato, il movimento segue un percorso calcolato con
# MazeGrid.get_path() (pathfinding reale attraverso i corridoi) invece
# di puntare in linea retta verso il giocatore; altrimenti (stanze senza
# labirinto, o nei test isolati) si comporta come prima con
# `arena_bounds`. Il percorso è ricalcolato periodicamente, non ad ogni
# frame, per restare economico anche con molti nemici in campo.

signal spawn_projectile(pos: Vector2, dir: Vector2, speed: float, dmg: float, is_ally_projectile: bool, color: Color)
signal ally_kill(defeated: Node)
# Onda d'urto scaricata a terra dal Corazzato a ogni atterraggio. La
# gestisce Run (che sa chi è amico e chi nemico), come già fa per il
# colpo al suolo del boss.
signal shockwave(origin: Vector2, radius: float, dmg: float, from_ally: bool)

var enemy_id := "strisciante"
var display_name := "Strisciante"
var desc := ""
var speed := 95.0
var behavior := "chase"
var keep_distance := 190.0
var attack_cooldown := 1.4
var projectile_speed := 260.0
var is_golden := false
# Forma con cui la creatura viene disegnata: ogni specie ha la propria
# (vedi _draw). "brute" è la sagoma generica, condivisa da chi non ha
# bisogno di distinguersi per forma.
var shape := "brute"
# Direzione verso cui la creatura sta andando davvero, ricavata dallo
# spostamento fotogramma per fotogramma: orienta corpo, ali e petali
# senza dover toccare il codice di movimento, che resta uno solo per
# tutte le specie.
var heading := Vector2.RIGHT
var _previous_position := Vector2.ZERO
# Posizioni recenti del corpo, usate dalla melma per strisciare dietro
# di sé invece di traslare come un disco rigido.
var _body_trail: Array = []
var guaranteed_drop := ""
# Valori originali del tipo, da cui si ricalcolano i bonus da alleato
# (Run._apply_ally_buffs): applicare i moltiplicatori sempre alla base
# evita che raccogliere due volte lo stesso potenziamento li componga in
# modo esponenziale.
var base_max_hp := 30.0
var base_damage := 8.0

var attack_timer := 0.0

# --- Schema d'attacco ---------------------------------------------------------
#
# Ogni specie ha il proprio modo di arrivare a colpire, non solo il
# proprio aspetto. Lo schema è una piccola macchina a stati condivisa:
# _update_attack_pattern() la fa avanzare e risponde al chiamante che
# cosa fare del movimento in questo fotogramma — "avanza" (muoviti
# normalmente), "fermo" (resta dove sei) o "scatta" (lanciati in
# charge_dir). È cosí che lo stesso schema vale sia quando la creatura è
# ostile sia quando combatte come alleato, senza scriverlo due volte.
var attack_pattern := "nessuno"
var attack_state := "avanza"
var attack_state_timer := 0.0
var charge_dir := Vector2.RIGHT

# Morso (Strisciante): si ferma a un soffio dalla preda, affonda il
# colpo, poi riprende a inseguirla.
const BITE_WINDUP := 0.3
const BITE_STRIKE := 0.12
const BITE_RECOVER := 0.45
const BITE_REACH_BONUS := 6.0

# Carica (Sciame): a tiro si ferma, punta la preda e si lancia.
const SWARM_CHARGE_RANGE := 240.0
const SWARM_CHARGE_TIME := 1.5
const SWARM_DASH_TIME := 0.32
const SWARM_DASH_SPEED := 520.0
const SWARM_RECOVER := 0.7

# Salto (Corazzato): avanza a balzi e a ogni atterraggio scarica a terra
# un'onda d'urto. Il moltiplicatore di velocità in aria compensa i tempi
# fermi, cosí l'andatura media resta quella di prima.
const HOP_CROUCH := 0.22
const HOP_AIR := 0.4
const HOP_LAND := 0.3
const HOP_SPEED_MULT := 2.3
const HOP_HEIGHT := 16.0
const HOP_SHOCKWAVE_RADIUS := 54.0
const HOP_SHOCKWAVE_DAMAGE_RATIO := 0.35

# Agguato (Pungiglione): non insegue, vive attaccato alle pareti e tra un
# dardo e l'altro sprofonda nel pavimento per rispuntare poco più in là.
const BURROW_SINK := 0.3
const BURROW_HIDDEN := 0.25
const BURROW_RISE := 0.3
const BURROW_MIN_DISTANCE := 70.0
const BURROW_MAX_DISTANCE := 180.0
# Quanto vicino a una parete deve rispuntare. Il punto scelto deve
# starci senza compenetrare il muro ma avercelo a ridosso.
const WALL_HUG_DISTANCE := 34.0
const BURROW_ATTEMPTS := 40
const BURROW_ANCHOR_RETRIES := 30
# Margine con cui si verifica la linea di tiro: è il raggio del dardo.
# Un colpo che sfiora lo spigolo del muro non arriverebbe comunque.
const SHOT_CLEARANCE := 5.0
# Quanto aspetta prima di riprovare dopo aver rinunciato a un tiro
# ostruito. Breve: il tempo vero lo passa sotto il pavimento.
const BLOCKED_SHOT_RETRY := 0.25
var burrow_target := Vector2.ZERO
var _anchored_to_wall := false
var _anchor_attempts := 0
# Durata residua del lampo dell'onda d'urto appena scaricata: puro
# disegno, non tocca il colpo (già inflitto al momento dell'atterraggio).
var _land_flash := 0.0

var arena_bounds: Rect2 = Rect2()
var maze: MazeGrid = null
var current_path: PackedVector2Array = PackedVector2Array()
var path_target_index := 0
var path_recalc_timer := 0.0

# Alleato: convertito da nemico comune tramite l'abilità speciale del
# giocatore (Run._convert_enemy_to_ally). Da questo momento insegue e
# attacca gli altri nemici invece del giocatore, riusando lo stesso
# sistema di pathfinding/collisione ma con logica di movimento e
# combattimento dedicata (vedi _physics_process_ally sotto).
var is_ally := false
const ALLY_ENGAGE_RADIUS := 260.0
const ALLY_FOLLOW_DISTANCE := 130.0
# Inseguimento del giocatore. Quasi tutti i tipi sono più lenti di lui
# (il Corazzato va a 55 contro i 220 del giocatore), quindi un alleato
# rimasto indietro non lo raggiungerebbe mai e resterebbe perso in fondo
# al labirinto. Oltre ALLY_CATCHUP_START la velocità cresce in modo
# esponenziale con la distanza: raddoppia ogni ALLY_CATCHUP_DOUBLING
# pixel di distacco, fino al tetto di ALLY_CATCHUP_MAX_MULT, che evita
# che l'inseguimento diventi un teletrasporto.
# L'accelerazione vale solo mentre l'alleato sta tornando dal giocatore:
# se è impegnato contro un nemico si muove alla sua velocità normale.
const ALLY_CATCHUP_START := 200.0
const ALLY_CATCHUP_DOUBLING := 220.0
const ALLY_CATCHUP_MAX_MULT := 8.0
var ally_path: PackedVector2Array = PackedVector2Array()
var ally_path_target_index := 0
var ally_path_recalc_timer := 0.0

func setup_from_data(data: Dictionary, golden: bool) -> void:
	enemy_id = data.id
	display_name = data.name
	desc = data.desc
	max_hp = data.hp
	hp = data.hp
	speed = data.speed
	damage = data.damage
	radius = data.radius
	color = data.color
	behavior = data.get("behavior", "chase")
	contact_cooldown = data.get("contact_cooldown", 0.6)
	keep_distance = data.get("keep_distance", 190.0)
	attack_cooldown = data.get("attack_cooldown", 1.4)
	projectile_speed = data.get("projectile_speed", 260.0)
	shape = data.get("shape", "brute")
	attack_pattern = data.get("attack_pattern", "nessuno")
	guaranteed_drop = data.get("guaranteed_drop", "")
	is_golden = golden
	base_max_hp = max_hp
	base_damage = damage

# Riapplica i moltiplicatori da potenziamento a questo alleato, partendo
# sempre dai valori base del tipo. La quota di vita attuale viene
# conservata, cosí un alleato ferito non si cura di colpo raccogliendo
# Pelle Coriacea (né perde vita se il moltiplicatore cala).
func apply_ally_buffs(hp_mult: float, damage_mult: float) -> void:
	var ratio: float = (hp / max_hp) if max_hp > 0.0 else 1.0
	max_hp = base_max_hp * hp_mult
	hp = max_hp * ratio
	damage = base_damage * damage_mult

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	super._ready()
	add_to_group("enemy")
	attack_timer = randf() * attack_cooldown if attack_cooldown > 0.0 else 0.0
	path_recalc_timer = randf() * 0.3
	_previous_position = global_position

# La direzione di marcia si ricava dallo spostamento appena avvenuto,
# non da dove la creatura vorrebbe andare: cosí vale identica per
# inseguimento, fuga, percorso nel labirinto e comportamento da alleato,
# senza dover toccare nessuno dei quattro. Il filtro evita che una
# creatura ferma contro un muro giri su se stessa per micro-spostamenti.
func _process(delta: float) -> void:
	super._process(delta)
	var moved: Vector2 = global_position - _previous_position
	if moved.length() > 0.6:
		heading = heading.lerp(moved.normalized(), 0.3).normalized()
	_previous_position = global_position
	if _land_flash > 0.0:
		_land_flash -= delta
	if shape == "slime":
		_update_body_trail()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if is_ally:
		_physics_process_ally(delta, player)
		return
	# Un nemico ostile non punta per forza al giocatore: se un suo alleato
	# è più vicino, se la prende con quello (vedi update_hostile_target).
	var previous_target: Node = current_target
	var target: Node = update_hostile_target(delta)
	if target == null:
		return
	if target != previous_target:
		# Il percorso calcolato porta al bersaglio precedente: va rifatto
		# subito, altrimenti il nemico continuerebbe a inseguire per un
		# attimo chi ha appena smesso di interessargli.
		current_path = PackedVector2Array()
		path_recalc_timer = 0.0
	if maze != null:
		_physics_process_maze(delta, target)
	else:
		_physics_process_direct(delta, target)

func _physics_process_direct(delta: float, target: Node) -> void:
	var to_player: Vector2 = target.global_position - global_position
	var dir: Vector2 = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO
	match behavior:
		"chase":
			if _apply_pattern_action(_update_attack_pattern(delta, target), delta):
				return
			global_position += dir * current_move_speed() * delta
		"ranged":
			if attack_pattern == "agguato":
				_pattern_agguato(delta, target, false, global_position)
				return
			var d := to_player.length()
			if d < keep_distance - 15.0:
				global_position -= dir * speed * delta
			elif d > keep_distance + 15.0:
				global_position += dir * speed * delta
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				spawn_projectile.emit(global_position, dir, projectile_speed, damage, false, color)
	_clamp_to_arena()

func _physics_process_maze(delta: float, target: Node) -> void:
	path_recalc_timer -= delta
	if path_recalc_timer <= 0.0 or current_path.size() < 2:
		current_path = maze.get_path(global_position, target.global_position)
		path_target_index = 1 if current_path.size() > 1 else 0
		path_recalc_timer = 0.35 + randf() * 0.25

	var to_player: Vector2 = target.global_position - global_position
	var straight_dist: float = to_player.length()

	match behavior:
		"chase":
			if _apply_pattern_action(_update_attack_pattern(delta, target), delta):
				return
			_move_along_path(delta, target)
		"ranged":
			if attack_pattern == "agguato":
				_pattern_agguato(delta, target, false, global_position)
				return
			if straight_dist > keep_distance + 15.0:
				_move_along_path(delta, target)
			attack_timer -= delta
			if attack_timer <= 0.0:
				attack_timer = attack_cooldown
				var dir: Vector2 = to_player.normalized() if straight_dist > 0.001 else Vector2.ZERO
				spawn_projectile.emit(global_position, dir, projectile_speed, damage, false, color)

func _move_along_path(delta: float, target: Node) -> void:
	if current_path.size() < 2:
		# Il percorso ha un solo punto (o nessuno) quando nemico e
		# bersaglio sono nella stessa cella del labirinto: lí dentro non
		# può esserci una parete di mezzo, quindi si chiude la distanza
		# in linea retta invece di restare fermi in attesa di un
		# percorso che non arriverà mai (la cella di destinazione, non
		# il punto esatto del bersaglio, è già stata raggiunta).
		var to_player: Vector2 = target.global_position - global_position
		if to_player.length() > 0.001:
			var dir: Vector2 = to_player.normalized()
			global_position = maze.resolve_move(global_position, dir * current_move_speed() * delta, radius)
		return
	if path_target_index >= current_path.size():
		path_target_index = current_path.size() - 1
	var waypoint: Vector2 = current_path[path_target_index]
	var to_target: Vector2 = waypoint - global_position
	if to_target.length() < 10.0 and path_target_index < current_path.size() - 1:
		path_target_index += 1
		waypoint = current_path[path_target_index]
		to_target = waypoint - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
	global_position = maze.resolve_move(global_position, dir * speed * delta, radius)


# --- Schemi d'attacco ---------------------------------------------------------

# Fa avanzare la macchina a stati e risponde che cosa fare del movimento
# in questo fotogramma: "avanza", "fermo" o "scatta". Vale sia per una
# creatura ostile sia per un alleato: cambia solo chi è il bersaglio.
func _update_attack_pattern(delta: float, target: Node) -> String:
	match attack_pattern:
		"morso":
			return _pattern_morso(delta, target)
		"carica":
			return _pattern_carica(delta, target)
		"salto":
			return _pattern_salto(delta)
	return "avanza"

# Distanza alla quale questa creatura considera la preda "a portata di
# morso": i due corpi quasi a contatto, senza compenetrarsi.
func melee_reach(target: Node) -> float:
	var target_radius: float = target.radius if target != null and "radius" in target else 0.0
	return radius + target_radius + BITE_REACH_BONUS

# Velocità di questo fotogramma: il Corazzato in aria va più forte, cosí
# i tempi fermi del balzo non lo rendono più lento di prima.
func current_move_speed() -> float:
	if attack_pattern == "salto" and attack_state == "salto":
		return speed * HOP_SPEED_MULT
	return speed

func _start_attack_state(next_state: String, duration: float) -> void:
	attack_state = next_state
	attack_state_timer = duration

# Strisciante: raggiunta la preda si ferma, arretra la testa, affonda il
# morso e si prende un attimo prima di tornare a inseguirla.
func _pattern_morso(delta: float, target: Node) -> String:
	attack_state_timer -= delta
	match attack_state:
		"carica":
			_face(target)
			if attack_state_timer <= 0.0:
				_start_attack_state("colpisce", BITE_STRIKE)
				_strike_melee(target)
			return "fermo"
		"colpisce":
			if attack_state_timer <= 0.0:
				_start_attack_state("recupero", BITE_RECOVER)
			return "fermo"
		"recupero":
			if attack_state_timer <= 0.0:
				_start_attack_state("avanza", 0.0)
			return "fermo"
	if target != null and global_position.distance_to(target.global_position) <= melee_reach(target):
		_face(target)
		_start_attack_state("carica", BITE_WINDUP)
		return "fermo"
	return "avanza"

# Sciame: a tiro si ferma a caricare per SWARM_CHARGE_TIME puntando la
# preda, poi si lancia. La carica è lunga apposta: è il preavviso che
# rende l'attacco schivabile invece che inevitabile.
func _pattern_carica(delta: float, target: Node) -> String:
	attack_state_timer -= delta
	match attack_state:
		"carica":
			# Continua a puntare fino all'ultimo istante: la direzione
			# dello scatto è quella dell'attimo in cui parte.
			if target != null:
				var to_target: Vector2 = target.global_position - global_position
				if to_target.length() > 0.001:
					charge_dir = to_target.normalized()
					heading = charge_dir
			if attack_state_timer <= 0.0:
				_start_attack_state("scatto", SWARM_DASH_TIME)
			return "fermo"
		"scatto":
			if attack_state_timer <= 0.0:
				_start_attack_state("recupero", SWARM_RECOVER)
				return "fermo"
			return "scatta"
		"recupero":
			if attack_state_timer <= 0.0:
				_start_attack_state("avanza", 0.0)
			return "avanza"
	if target != null and global_position.distance_to(target.global_position) <= SWARM_CHARGE_RANGE:
		_start_attack_state("carica", SWARM_CHARGE_TIME)
		return "fermo"
	return "avanza"

# Corazzato: non cammina, avanza a balzi. Si raccoglie, salta (ed è solo
# in aria che si sposta), e atterrando scarica a terra un'onda d'urto.
func _pattern_salto(delta: float) -> String:
	attack_state_timer -= delta
	match attack_state:
		"salto":
			if attack_state_timer <= 0.0:
				_start_attack_state("atterra", HOP_LAND)
				_land_flash = 0.3
				shockwave.emit(global_position, HOP_SHOCKWAVE_RADIUS, damage * HOP_SHOCKWAVE_DAMAGE_RATIO, is_ally)
				return "fermo"
			return "avanza"
		"atterra":
			if attack_state_timer <= 0.0:
				_start_attack_state("carica", HOP_CROUCH)
			return "fermo"
	if attack_state != "carica":
		_start_attack_state("carica", HOP_CROUCH)
	if attack_state_timer <= 0.0:
		_start_attack_state("salto", HOP_AIR)
	return "fermo"

# Quanto il Corazzato è staccato da terra in questo istante (0 a terra).
func hop_height() -> float:
	if attack_pattern != "salto" or attack_state != "salto":
		return 0.0
	var t: float = 1.0 - clamp(attack_state_timer / HOP_AIR, 0.0, 1.0)
	# Parabola: sale, culmina a metà volo e ricade.
	return HOP_HEIGHT * 4.0 * t * (1.0 - t)

func _face(target: Node) -> void:
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > 0.001:
		heading = to_target.normalized()

# Il morso: a differenza del danno da contatto — che è il bersaglio a
# rilevare — qui è la creatura a colpire, perché si ferma appena fuori
# dalla sovrapposizione e nessun contatto avverrebbe mai.
func _strike_melee(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	if global_position.distance_to(target.global_position) > melee_reach(target) + 12.0:
		return
	var was_alive: bool = target.alive
	target.take_damage(damage)
	if is_ally and was_alive and not target.alive:
		ally_kill.emit(target)

# Movimento dello scatto dello Sciame: ignora il percorso nel labirinto
# (si lancia in linea retta) ma non le pareti, contro cui si ferma.
func _move_charge(delta: float) -> void:
	var step: Vector2 = charge_dir * SWARM_DASH_SPEED * delta
	if maze != null:
		global_position = maze.resolve_move(global_position, step, radius)
	else:
		global_position += step
		_clamp_to_arena()

# Applica al movimento ciò che lo schema d'attacco ha deciso. Restituisce
# true se il movimento è già stato gestito qui (fermo o scatto) e il
# chiamante non deve muovere la creatura.
func _apply_pattern_action(action: String, delta: float) -> bool:
	if action == "scatta":
		_move_charge(delta)
		return true
	return action == "fermo"

# --- Agguato del Pungiglione --------------------------------------------------

# Non insegue e non indietreggia: resta abbarbicato alla parete, spara, e
# subito dopo sprofonda per rispuntare poco più in là. Mentre è sotto il
# pavimento non è raggiungibile — è sotto terra — ma sono frazioni di
# secondo.
func _pattern_agguato(delta: float, target: Node, from_ally: bool, anchor: Vector2) -> void:
	attack_state_timer -= delta
	match attack_state:
		"sparisce":
			if attack_state_timer <= 0.0:
				_start_attack_state("sepolto", BURROW_HIDDEN)
				_set_targetable(false)
				global_position = burrow_target
			return
		"sepolto":
			if attack_state_timer <= 0.0:
				_start_attack_state("riemerge", BURROW_RISE)
			return
		"riemerge":
			if attack_state_timer <= 0.0:
				_start_attack_state("avanza", 0.0)
				_set_targetable(true)
			return

	if not _anchored_to_wall:
		# Appena nato può trovarsi in mezzo al corridoio: si attacca
		# subito a una parete, senza animazione. Se il primo tentativo
		# non trova un appiglio valido riprova al fotogramma dopo invece
		# di rassegnarsi: restare in mezzo al corridoio sarebbe proprio
		# il difetto da evitare.
		var target_position: Vector2 = target.global_position if target != null else Vector2.ZERO
		var spot: Vector2 = _pick_burrow_spot(global_position, 0.0, BURROW_MAX_DISTANCE, target_position, target != null)
		_anchor_attempts += 1
		if spot != global_position:
			global_position = spot
			_anchored_to_wall = true
		elif _is_wall_hug_spot(global_position) or _anchor_attempts >= BURROW_ANCHOR_RETRIES:
			# O è già a ridosso di una parete, o in questa stanza non ne
			# esiste una raggiungibile: dopo qualche tentativo smette di
			# cercarne una ad ogni fotogramma e si accontenta.
			_anchored_to_wall = true

	attack_timer -= delta
	if attack_timer > 0.0 or target == null:
		return

	if not has_clear_shot(target.global_position):
		# C'è una parete di mezzo: sparare sarebbe solo uno spreco, e
		# restare lí a insistere il difetto peggiore, visto che questo
		# nemico non insegue. Si sposta cercando un punto da cui la
		# preda sia davvero a tiro.
		attack_timer = BLOCKED_SHOT_RETRY
		_relocate(anchor, target.global_position, true)
		return

	attack_timer = attack_cooldown
	var to_target: Vector2 = target.global_position - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.RIGHT
	heading = dir
	spawn_projectile.emit(global_position, dir, projectile_speed, damage, from_ally, color)
	_relocate(anchor, target.global_position, true)

# La preda è davvero a tiro, o c'è un muro di mezzo? Senza questo
# controllo il fiore scarica dardi contro una parete restandosene
# dall'altra parte, e — non inseguendo nessuno — potrebbe non smettere
# mai.
func has_clear_shot(target_position: Vector2) -> bool:
	return _has_sight_between(global_position, target_position)

func _has_sight_between(from_position: Vector2, to_position: Vector2) -> bool:
	if maze == null:
		return true
	return maze.has_line_of_sight(from_position, to_position, SHOT_CLEARANCE)

# Sprofonda e rispunta altrove. Se conosce la posizione della preda
# cerca un punto da cui averla davvero a tiro.
func _relocate(around: Vector2, sight_to: Vector2, require_sight: bool) -> void:
	burrow_target = _pick_burrow_spot(around, BURROW_MIN_DISTANCE, BURROW_MAX_DISTANCE, sight_to, require_sight)
	if burrow_target != global_position:
		_start_attack_state("sparisce", BURROW_SINK)

func _set_targetable(value: bool) -> void:
	monitorable = value
	monitoring = value

# Quanto il fiore è emerso dal pavimento: 1 in superficie, 0 sepolto.
func burrow_scale() -> float:
	if attack_pattern != "agguato":
		return 1.0
	match attack_state:
		"sparisce":
			return clamp(attack_state_timer / BURROW_SINK, 0.0, 1.0)
		"sepolto":
			return 0.0
		"riemerge":
			return 1.0 - clamp(attack_state_timer / BURROW_RISE, 0.0, 1.0)
	return 1.0

func is_burrowed() -> bool:
	return attack_pattern == "agguato" and attack_state == "sepolto"

# Un punto dove rispuntare: dentro la mappa, largo abbastanza da
# contenere il fiore, e con una parete a ridosso. Se non ne trova uno
# valido resta dov'è: meglio fermo che incastrato in un muro.
func _pick_burrow_spot(around: Vector2, min_distance: float, max_distance: float, sight_to: Vector2 = Vector2.ZERO, require_sight: bool = false) -> Vector2:
	# Due passate: prima si cerca un appiglio da cui la preda sia
	# davvero a tiro; se in giro non ce n'è, ci si accontenta di un
	# appiglio qualunque — continuare a spostarsi è sempre meglio che
	# restare inchiodati dietro un muro.
	for pass_index in range(2):
		var needs_sight: bool = require_sight and pass_index == 0
		for i in range(BURROW_ATTEMPTS):
			var angle: float = randf() * TAU
			var distance: float = lerp(min_distance, max_distance, randf())
			var candidate: Vector2 = around + Vector2.RIGHT.rotated(angle) * distance
			if not _is_wall_hug_spot(candidate):
				continue
			if needs_sight and not _has_sight_between(candidate, sight_to):
				continue
			return candidate
		if not require_sight:
			break
	return global_position

func _is_wall_hug_spot(pos: Vector2) -> bool:
	if maze != null:
		if not maze.total_bounds().has_point(pos):
			return false
		# Ci deve stare senza compenetrare la parete...
		if not maze.is_position_free(pos, radius + 2.0):
			return false
		# ...ma deve avercene una a ridosso: il fiore vive attaccato al muro.
		return not maze.is_position_free(pos, radius + WALL_HUG_DISTANCE)
	if arena_bounds.size.x <= 0.0 or arena_bounds.size.y <= 0.0:
		return false
	var inner: Rect2 = arena_bounds.grow(-radius)
	if not inner.has_point(pos):
		return false
	# Nell'arena aperta del boss la parete è il bordo della stanza.
	var edge_distance: float = min(
		min(pos.x - inner.position.x, inner.end.x - pos.x),
		min(pos.y - inner.position.y, inner.end.y - pos.y)
	)
	return edge_distance <= WALL_HUG_DISTANCE

# --- Comportamento da alleato -------------------------------------------------

func _physics_process_ally(delta: float, player: Node) -> void:
	# Mantiene lo stesso comportamento avuto da nemico: un tipo "ranged"
	# resta un alleato di supporto a distanza (mantiene le distanze e
	# spara), un "chase" resta un alleato da mischia (si avvicina e
	# colpisce a contatto). _ally_resolve_combat() gestisce il contatto
	# per entrambi, esattamente come un nemico ostile può sempre colpire
	# per contatto il giocatore anche se il suo comportamento primario è
	# "ranged".
	var hostile := _find_nearest_hostile(ALLY_ENGAGE_RADIUS)
	if behavior == "ranged":
		_ally_behavior_ranged(delta, player, hostile)
	else:
		_ally_behavior_chase(delta, player, hostile)
	_ally_resolve_combat()

func _ally_behavior_chase(delta: float, player: Node, hostile: Node) -> void:
	if hostile != null:
		# Stesso schema d'attacco che aveva da nemico, solo rivolto
		# contro gli ostili: morde, balza o si lancia come prima.
		if _apply_pattern_action(_update_attack_pattern(delta, hostile), delta):
			return
		_ally_move_toward(delta, hostile.global_position, melee_reach(hostile), current_move_speed())
		return
	# Tornando dal giocatore lo schema non c'entra: si limita a seguirlo.
	_start_attack_state("avanza", 0.0)
	_ally_move_toward(delta, player.global_position, ALLY_FOLLOW_DISTANCE, ally_follow_speed(player.global_position))

func _ally_behavior_ranged(delta: float, player: Node, hostile: Node) -> void:
	if attack_pattern == "agguato":
		_ally_behavior_agguato(delta, player, hostile)
		return
	if hostile == null:
		_ally_move_toward(delta, player.global_position, ALLY_FOLLOW_DISTANCE, ally_follow_speed(player.global_position))
		return
	var dist: float = global_position.distance_to(hostile.global_position)
	if dist > keep_distance + 15.0:
		_ally_move_toward(delta, hostile.global_position, keep_distance, speed)
	elif dist < keep_distance - 15.0:
		_ally_move_away_from(delta, hostile.global_position)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		var to_target: Vector2 = hostile.global_position - global_position
		var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
		spawn_projectile.emit(global_position, dir, projectile_speed, damage, true, color)

# Il Pungiglione alleato non cammina neppure da alleato: si sposta
# sprofondando e rispuntando. Se è rimasto indietro rispunta vicino al
# giocatore invece che vicino a dove era, altrimenti resterebbe
# abbarbicato a una parete in fondo al labirinto mentre la run prosegue.
func _ally_behavior_agguato(delta: float, player: Node, hostile: Node) -> void:
	var too_far: bool = global_position.distance_to(player.global_position) > ALLY_FOLLOW_DISTANCE * 1.6
	var anchor: Vector2 = player.global_position if too_far else global_position
	if hostile != null:
		_pattern_agguato(delta, hostile, true, anchor)
		return
	# Nessun nemico in vista: non spara, ma continua a spostarsi per
	# restare al passo col giocatore.
	if too_far and attack_state == "avanza":
		burrow_target = _pick_burrow_spot(player.global_position, 0.0, ALLY_FOLLOW_DISTANCE)
		if burrow_target != global_position:
			_start_attack_state("sparisce", BURROW_SINK)
	_pattern_agguato(delta, null, true, anchor)

# Velocità con cui questo alleato torna verso `dest_pos` (la posizione del
# giocatore): la sua andatura normale fino a ALLY_CATCHUP_START, poi
# raddoppiata ogni ALLY_CATCHUP_DOUBLING pixel di distacco, fino al tetto.
func ally_follow_speed(dest_pos: Vector2) -> float:
	var dist: float = global_position.distance_to(dest_pos)
	if dist <= ALLY_CATCHUP_START:
		return speed
	var doublings: float = (dist - ALLY_CATCHUP_START) / ALLY_CATCHUP_DOUBLING
	return speed * min(pow(2.0, doublings), ALLY_CATCHUP_MAX_MULT)

func _ally_move_toward(delta: float, dest_pos: Vector2, stop_distance: float, move_speed: float) -> void:
	if global_position.distance_to(dest_pos) <= stop_distance:
		return
	if maze != null:
		_ally_move_along_maze(delta, dest_pos, move_speed)
	else:
		var to_dest: Vector2 = dest_pos - global_position
		var dir: Vector2 = to_dest.normalized() if to_dest.length() > 0.001 else Vector2.ZERO
		global_position += dir * move_speed * delta
		_clamp_to_arena()

func _ally_move_away_from(delta: float, threat_pos: Vector2) -> void:
	var away: Vector2 = global_position - threat_pos
	var dir: Vector2 = away.normalized() if away.length() > 0.001 else Vector2.ZERO
	if maze != null:
		global_position = maze.resolve_move(global_position, dir * speed * delta, radius)
	else:
		global_position += dir * speed * delta
		_clamp_to_arena()

func _find_nearest_hostile(max_radius: float) -> Node:
	var nearest: Node = null
	var nearest_dist := max_radius
	for group in ["enemy", "boss"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self or not node.alive:
				continue
			if node is Enemy and node.is_ally:
				continue
			var d: float = global_position.distance_to(node.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node
	return nearest

func _ally_move_along_maze(delta: float, dest_pos: Vector2, move_speed: float) -> void:
	ally_path_recalc_timer -= delta
	if ally_path_recalc_timer <= 0.0 or ally_path.size() < 2:
		ally_path = maze.get_path(global_position, dest_pos)
		ally_path_target_index = 1 if ally_path.size() > 1 else 0
		ally_path_recalc_timer = 0.35 + randf() * 0.25

	if ally_path.size() < 2:
		var to_dest: Vector2 = dest_pos - global_position
		if to_dest.length() > 0.001:
			var dir: Vector2 = to_dest.normalized()
			global_position = maze.resolve_move(global_position, dir * move_speed * delta, radius)
		return
	if ally_path_target_index >= ally_path.size():
		ally_path_target_index = ally_path.size() - 1
	var target: Vector2 = ally_path[ally_path_target_index]
	var to_target: Vector2 = target - global_position
	if to_target.length() < 10.0 and ally_path_target_index < ally_path.size() - 1:
		ally_path_target_index += 1
		target = ally_path[ally_path_target_index]
		to_target = target - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 0.001 else Vector2.ZERO
	global_position = maze.resolve_move(global_position, dir * move_speed * delta, radius)

func _ally_resolve_combat() -> void:
	# Stesso schema del Player._resolve_combat(): è l'alleato stesso a
	# scandire le proprie aree sovrapposte, dato che i nemici comuni non
	# controllano mai le proprie (collision_mask = 0 di default). Il
	# cooldown di contatto (contact_timer, ereditato da CombatEntity) è
	# per-istanza, quindi alleato e nemico infliggono danno l'un l'altro
	# ognuno al proprio ritmo, esattamente come già avviene per il
	# contatto nemico -> giocatore.
	if not alive:
		return
	for area in get_overlapping_areas():
		if not alive:
			return
		if area == self:
			continue
		if area.is_in_group("enemy_projectile"):
			if area.is_ally_projectile:
				# Un proiettile alleato (anche il proprio, appena sparato
				# e ancora sovrapposto a sé stessi) non deve mai ferire
				# un alleato: senza questo controllo un alleato "ranged"
				# distruggerebbe il proprio colpo nel momento stesso in
				# cui lo spara.
				continue
			take_damage(area.damage)
			area.queue_free()
			continue
		if not area.is_in_group("combat_target"):
			continue
		if area is Enemy and area.is_ally:
			continue
		if not area.alive:
			continue
		if can_deal_contact_damage():
			var was_alive: bool = area.alive
			area.take_damage(damage)
			trigger_contact()
			if was_alive and not area.alive:
				# Il colpo dell'alleato ha ucciso il bersaglio: Run non lo
				# saprebbe mai (ascolta solo enemy_defeated del Player, per
				# lo scatto), quindi senza questo segnale una stanza il cui
				# ultimo nemico viene finito da un alleato invece che dallo
				# scatto non consegnerebbe mai la ricompensa.
				ally_kill.emit(area)
		if area.can_deal_contact_damage():
			take_damage(area.damage)
			area.trigger_contact()

func _clamp_to_arena() -> void:
	if arena_bounds.size == Vector2.ZERO:
		return
	global_position.x = clamp(global_position.x, arena_bounds.position.x + radius, arena_bounds.end.x - radius)
	global_position.y = clamp(global_position.y, arena_bounds.position.y + radius, arena_bounds.end.y - radius)

# --- Aspetto -----------------------------------------------------------------

# Ogni specie ha la propria sagoma. Su una pietra quasi nera il colore
# del corpo da solo non basta a distinguerle: a fare il lavoro sono la
# forma, le proporzioni e il movimento delle parti.
func _draw() -> void:
	rim_color = current_rim_color()
	match shape:
		"slime":
			_draw_slime()
		"insect":
			_draw_insect()
		"flower":
			_draw_flower()
		_:
			# Il balzo alza il corpo (e i suoi arti) lasciando l'ombra a
			# terra; il lampo è l'onda d'urto appena scaricata.
			body_offset = Vector2(0.0, -hop_height())
			_draw_landing_shockwave()
			draw_set_transform(body_offset, 0.0, Vector2.ONE)
			_draw_limbs()
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			super._draw()
	_draw_allegiance_badges()

# Anello che si allarga e sfuma sul punto d'atterraggio: è il segno
# dell'onda d'urto, il cui colpo è già stato inflitto da Run.
func _draw_landing_shockwave() -> void:
	if _land_flash <= 0.0:
		return
	var t: float = 1.0 - clamp(_land_flash / 0.3, 0.0, 1.0)
	var ring_radius: float = lerp(radius * 0.6, HOP_SHOCKWAVE_RADIUS, t)
	var fade: float = 1.0 - t
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Palette.with_alpha(Palette.STONE_EDGE, fade * 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, ring_radius, Palette.with_alpha(Palette.STONE, fade * 0.12))

# Contrassegni che valgono per tutte le sagome: l'anello dorato della
# variante rara e il marchio del legame sopra la testa degli alleati.
func _draw_allegiance_badges() -> void:
	if is_golden:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 28, Palette.with_alpha(Palette.GOLD, 0.75), 2.0)
	if is_ally:
		var top := Vector2(0.0, -radius - 8.0)
		draw_line(top + Vector2(-5.0, 0.0), top + Vector2(5.0, 0.0), Palette.STEEL, 2.0)
		draw_line(top + Vector2(0.0, -4.0), top + Vector2(0.0, 4.0), Palette.STEEL, 2.0)

# Fase di animazione sfasata per istanza: uno sciame di insetti che
# battesse le ali all'unisono sembrerebbe un unico oggetto.
func _animation_phase(speed_factor: float) -> float:
	return float(Time.get_ticks_msec()) * 0.001 * speed_factor + float(get_instance_id() % 628) * 0.01

# --- Strisciante: melma nera che striscia come un serpente --------------------

const SLIME_SEGMENTS := 8
const SLIME_TRAIL_GAP := 6.0

# Il corpo segue le posizioni realmente occupate poco fa: è questo, più
# di qualunque disegno, a dare l'andatura serpentina — la melma si
# allunga quando corre e si raccoglie in una pozza quando si ferma.
func _update_body_trail() -> void:
	if _body_trail.is_empty() or _body_trail[0].distance_to(global_position) >= SLIME_TRAIL_GAP:
		_body_trail.push_front(global_position)
		while _body_trail.size() > SLIME_SEGMENTS:
			_body_trail.pop_back()

func _draw_slime() -> void:
	_draw_ground_shadow()
	# Nera. Del colore della specie resta appena un soffio, quel tanto
	# che basta perché non sia una silhouette piatta — tranne nella
	# variante dorata, che deve invece farsi notare.
	var body: Color = Palette.VOID.lerp(color, 0.4 if is_golden else 0.07)
	if hit_flash > 0.0:
		body = Palette.BONE
	var phase: float = _animation_phase(5.0)
	# Il primo disegno può arrivare prima del primo _process: senza
	# questo la melma resterebbe senza corpo da disegnare.
	if _body_trail.is_empty():
		_update_body_trail()
	var count: int = _body_trail.size()

	# Dalla coda alla testa, cosí la testa resta sopra al resto.
	for i in range(count - 1, -1, -1):
		var t: float = float(i) / float(SLIME_SEGMENTS - 1)
		var segment: Vector2 = to_local(_body_trail[i])
		var along: Vector2 = heading
		if i < count - 1:
			var delta_pos: Vector2 = _body_trail[i] - _body_trail[i + 1]
			if delta_pos.length() > 0.001:
				along = delta_pos.normalized()
		# Onda trasversale che viaggia dalla testa alla coda: l'ondeggiare
		# del serpente, presente anche da ferma.
		var across := Vector2(-along.y, along.x)
		segment += across * sin(phase - float(i) * 0.85) * radius * (0.16 + 0.3 * t)
		var segment_radius: float = radius * (1.0 - 0.58 * t)
		draw_circle(segment, segment_radius, body)
		# Il profilo si spegne in fretta verso la coda: serve a staccare
		# la testa dal fondo, non a colorare di rosso tutta la melma.
		draw_arc(segment, segment_radius, 0.0, TAU, 20, Palette.with_alpha(rim_color, 0.34 * pow(1.0 - t, 2.0)), 1.5, true)

	# Testa: riflesso umido e due occhi pallidi, gli unici punti chiari
	# di una creatura per il resto completamente nera.
	_draw_bite_jaws(body)
	var across_head := Vector2(-heading.y, heading.x)
	draw_circle(-heading * radius * 0.2 - across_head * radius * 0.3, radius * 0.26, Palette.with_alpha(Palette.STEEL, 0.22))
	var eye_forward: Vector2 = heading * radius * 0.3
	var eye_side: Vector2 = across_head * radius * 0.36
	draw_circle(eye_forward + eye_side, radius * 0.17, Palette.BONE)
	draw_circle(eye_forward - eye_side, radius * 0.17, Palette.BONE)
	_draw_hp_bar()

# L'animazione del morso: la melma arretra la testa mentre si carica,
# spalanca le fauci, poi scatta in avanti richiudendole. Sono due archi e
# uno scostamento, ma bastano a far capire che cosa sta per succedere —
# che è il punto: l'attacco deve essere leggibile prima di arrivare.
func _draw_bite_jaws(body: Color) -> void:
	if attack_pattern != "morso" or attack_state == "avanza":
		return
	var reach: float = radius * (1.0 + 0.55 * _bite_phase())
	var gape: float = _bite_gape()
	var mouth: Vector2 = heading * reach
	for side in [-1.0, 1.0]:
		var jaw_angle: float = heading.angle() + side * (0.12 + 0.75 * gape)
		var jaw_tip: Vector2 = mouth + Vector2.RIGHT.rotated(jaw_angle) * radius * 0.75
		draw_line(mouth, jaw_tip, body.lerp(Palette.VOID, 0.4), 4.0)
		draw_circle(jaw_tip, radius * 0.1, Palette.BONE_DIM)
	# Gola: il rosso che si intravede quando le fauci sono aperte.
	draw_circle(mouth, radius * 0.3 * gape, Palette.with_alpha(Palette.BLOOD, 0.75))

# -1 testa completamente arretrata, +1 affondo pieno.
func _bite_phase() -> float:
	match attack_state:
		"carica":
			return -(1.0 - clamp(attack_state_timer / BITE_WINDUP, 0.0, 1.0))
		"colpisce":
			return lerp(1.0, 0.3, 1.0 - clamp(attack_state_timer / BITE_STRIKE, 0.0, 1.0))
		"recupero":
			return lerp(0.3, 0.0, 1.0 - clamp(attack_state_timer / BITE_RECOVER, 0.0, 1.0))
	return 0.0

# 0 fauci chiuse, 1 spalancate.
func _bite_gape() -> float:
	match attack_state:
		"carica":
			return 1.0 - clamp(attack_state_timer / BITE_WINDUP, 0.0, 1.0)
		"colpisce":
			return clamp(attack_state_timer / BITE_STRIKE, 0.0, 1.0)
	return 0.0

# --- Sciame: insetto volante --------------------------------------------------

func _draw_insect() -> void:
	# Ombra piccola e staccata verso il basso: è in volo, non appoggiato.
	draw_set_transform(Vector2(0.0, radius * 2.3), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 0.8, Palette.with_alpha(Palette.VOID, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var phase: float = _animation_phase(1.0)
	var hover: float = sin(phase * 2.4) * radius * 0.32
	var chitin: Color = color.lerp(Palette.VOID, 0.45)
	if hit_flash > 0.0:
		chitin = Palette.BONE
	# Disegnato più grande del proprio raggio di collisione: a 9 px di
	# raggio un insetto "in scala" sarebbe una macchia, e mandibole e
	# livrea — cioè tutto ciò che lo rende riconoscibile — sparirebbero.
	var r: float = radius * 1.3

	# Tutto si disegna in un sistema ruotato dove +X è "avanti": cosí
	# corpo, ali e mandibole seguono da soli la direzione di volo.
	draw_set_transform(Vector2(0.0, hover), heading.angle(), Vector2.ONE)

	# In carica il battito impazzisce: è il preavviso che l'insetto sta
	# per lanciarsi, e insieme al mirino disegnato sotto rende lo scatto
	# schivabile invece che inevitabile.
	var wing_rate: float = 20.0 if attack_state == "carica" else 11.0
	var beat: float = 0.4 + 0.6 * abs(sin(phase * wing_rate))
	for side in [-1.0, 1.0]:
		for pair in range(2):
			var span: float = r * (2.0 - 0.5 * float(pair))
			var root := Vector2(r * (0.15 - 0.3 * float(pair)), 0.0)
			var wing := PackedVector2Array([
				root,
				root + Vector2(-span * 0.25, side * span * 0.34 * beat),
				root + Vector2(-span * 0.85, side * span * 0.72 * beat),
				root + Vector2(-span * 0.62, side * span * 0.16 * beat),
			])
			draw_colored_polygon(wing, Palette.with_alpha(Palette.STEEL, 0.14))
			draw_polyline(wing, Palette.with_alpha(Palette.STEEL, 0.16), 1.0, true)

	# Addome a bande: la livrea inconfondibile del calabrone.
	for i in range(3):
		var band_x: float = -r * (1.9 - 0.45 * float(i))
		var band_r: float = r * (0.26 + 0.09 * float(i))
		draw_circle(Vector2(band_x, 0.0), band_r, chitin if i % 2 == 0 else Palette.CHITIN_AMBER)

	# Torace e testa.
	draw_circle(Vector2(r * 0.1, 0.0), r * 0.5, chitin)
	draw_circle(Vector2(r * 0.72, 0.0), r * 0.36, chitin)

	# Mandibole spalancate del cervo volante: la parte che più di tutte
	# dice "insetto" anche a pochi pixel di dimensione.
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([
			Vector2(r * 0.95, side * r * 0.18),
			Vector2(r * 1.55, side * r * 0.58),
			Vector2(r * 1.95, side * r * 0.12),
		]), Palette.BONE, 2.5, true)
		draw_line(
			Vector2(r * 0.85, side * r * 0.24),
			Vector2(r * 1.35, side * r * 0.95),
			Palette.with_alpha(Palette.BONE_DIM, 0.65), 1.0
		)
		draw_circle(Vector2(r * 0.8, side * r * 0.2), r * 0.12, Palette.BONE)

	draw_arc(Vector2(r * 0.1, 0.0), r * 0.52, 0.0, TAU, 20, Palette.with_alpha(rim_color, 0.4), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_charge_telegraph()
	_draw_hp_bar()

# Mirino della carica: una linea che si allunga verso la preda man mano
# che l'insetto finisce di caricare. Quando tocca il fondo, parte.
func _draw_charge_telegraph() -> void:
	if attack_pattern != "carica" or attack_state != "carica":
		return
	var progress: float = 1.0 - clamp(attack_state_timer / SWARM_CHARGE_TIME, 0.0, 1.0)
	var length: float = radius * 2.0 + radius * 7.0 * progress
	var tip: Vector2 = charge_dir * length
	draw_line(charge_dir * radius * 1.4, tip, Palette.with_alpha(rim_color, 0.25 + 0.5 * progress), 2.0)
	draw_circle(tip, radius * 0.22 * (0.4 + progress), Palette.with_alpha(rim_color, 0.5 + 0.4 * progress))
	# Anello che si stringe attorno all'insetto: il conto alla rovescia.
	draw_arc(Vector2.ZERO, radius * (2.2 - 1.1 * progress), 0.0, TAU, 28, Palette.with_alpha(rim_color, 0.3 + 0.4 * progress), 1.5, true)

# --- Pungiglione: fiore carnivoro rosso e bianco ------------------------------

const FLOWER_PETALS := 8

func _draw_flower() -> void:
	# Il buco nel pavimento resta visibile mentre il fiore sprofonda e
	# mentre rispunta: è l'indizio che dice al giocatore dove guardare.
	var emerged: float = burrow_scale()
	if emerged < 1.0:
		draw_set_transform(Vector2(0.0, radius * 0.5), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius * 1.25, Palette.VOID)
		draw_arc(Vector2.ZERO, radius * 1.25, 0.0, TAU, 28, Palette.with_alpha(Palette.BLOOD_DEEP, 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if emerged <= 0.01:
		return
	# Sprofondando il fiore si rimpicciolisce e scende dentro il buco.
	draw_set_transform(Vector2(0.0, radius * 0.5 * (1.0 - emerged)), 0.0, Vector2(emerged, emerged))

	_draw_ground_shadow()
	var phase: float = _animation_phase(1.0)
	# Il fiore respira: i petali si aprono e si chiudono piano.
	var bloom: float = 1.0 + 0.09 * sin(phase * 1.6)
	var spin: float = heading.angle() + 0.1 * sin(phase * 0.9)

	for i in range(FLOWER_PETALS):
		var angle: float = spin + TAU * float(i) / float(FLOWER_PETALS)
		var out := Vector2.RIGHT.rotated(angle)
		var across := Vector2(-out.y, out.x)
		var petal := PackedVector2Array([
			out * radius * 0.3,
			out * radius * 0.75 * bloom + across * radius * 0.46,
			out * radius * 1.45 * bloom,
			out * radius * 0.75 * bloom - across * radius * 0.46,
		])
		# Petali alternati rossi e bianchi: due tinte sole, cosí la
		# livrea si legge anche quando il fiore è lontano e piccolo.
		var petal_color: Color = Palette.BLOOD if i % 2 == 0 else Palette.BONE
		if hit_flash > 0.0:
			petal_color = Palette.BONE
		draw_colored_polygon(petal, petal_color)
		var outline: PackedVector2Array = petal.duplicate()
		outline.append(petal[0])
		draw_polyline(outline, Palette.with_alpha(rim_color, 0.45), 1.0, true)

	# Cuore del fiore: lo stesso giallo dei dardi che spara, cosí si
	# capisce a colpo d'occhio da dove arriveranno i colpi.
	draw_circle(Vector2.ZERO, radius * 0.52, Palette.BLOOD_DEEP)
	draw_circle(Vector2.ZERO, radius * 0.34, Palette.POLLEN)
	# Stami puntati in avanti: la bocca da cui parte il dardo.
	for i in range(3):
		var stem_angle: float = heading.angle() + (float(i) - 1.0) * 0.32
		var tip: Vector2 = Vector2.RIGHT.rotated(stem_angle) * radius * 0.9
		draw_line(Vector2.ZERO, tip, Palette.with_alpha(Palette.POLLEN, 0.75), 1.5)
		draw_circle(tip, radius * 0.11, Palette.POLLEN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hp_bar()

# Cremisi se ostile, acciaio freddo se alleato, oro se dorato. È una
# funzione a sé e non due righe dentro _draw perché lo schieramento di
# una creatura è un'informazione di gioco, verificabile senza dover
# disegnare nulla.
func current_rim_color() -> Color:
	if is_ally:
		return Palette.RIM_ALLY
	if is_golden:
		return Palette.RIM_GOLDEN
	return Palette.RIM_HOSTILE

# Arti sottili e scuri che si allungano dal corpo, come le creature
# striscianti del riferimento estetico. Ondeggiano lentamente: basta
# questo a togliere alle creature l'aria di dischetti fermi.
func _draw_limbs() -> void:
	var phase: float = float(Time.get_ticks_msec()) * 0.0022 + float(get_instance_id() % 628) * 0.01
	var count: int = 4 if radius < 18.0 else 6
	for i in range(count):
		var base_angle: float = TAU * float(i) / float(count) + PI * 0.25
		var angle: float = base_angle + sin(phase + float(i)) * 0.16
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var length: float = radius * (2.1 + 0.16 * sin(phase * 1.7 + float(i) * 2.0))
		var knee: Vector2 = dir.rotated(-0.35) * (length * 0.55)
		var limb := PackedVector2Array([Vector2.ZERO, knee, dir * length])
		draw_polyline(limb, color.lerp(Palette.VOID, 0.25), 3.0, true)
		draw_polyline(limb, Palette.with_alpha(rim_color, 0.22), 1.0, true)
		draw_circle(dir * length, 1.8, Palette.with_alpha(rim_color, 0.45))
