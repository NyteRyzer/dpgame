extends Node
## Dynamic city events: ghost invasions, portal emergencies, Skulker's hunt,
## Ember's concert, Guys in White raids, Technus takeovers and night terrors.
## Also keeps ambient ghosts roaming and sends the GIW after exposed heroes.

const Destructible := preload("res://scripts/world/destructible.gd")

var game: Node = null
var active := ""
var _cooldown := 90.0
var _targets: Array = []
var _enemies: Array = []
var _time := 0.0
var _ambient_t := 5.0
var _giw_t := 0.0
var _goal := 0
var _done := 0
var _spot := Vector3.ZERO
var power_out := false


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = 6.0
		_ambient()
	_giw_t -= delta
	if game.suspicion >= 70.0 and _giw_t <= 0.0 and game.realm == "amity" and game.player.ghost:
		_giw_t = 45.0
		GameState.notify.emit("The Guys in White are responding to reports of ghost activity!", Color(0.85, 0.9, 1.0))
		for i in 2:
			_spawn("giw", game.player.global_position + Vector3(randf_range(-25, 25), 1, randf_range(-25, 25)), false)
	if active != "":
		_update_event(delta)
		return
	if game.realm != "amity" or game.missions.blocking_events():
		return
	# Let new players finish the opening tutorial before the city erupts.
	if GameState.story_chapter == 1 and GameState.story_step < 5:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		start_random()


func status_text() -> String:
	match active:
		"invasion":
			return "GHOST INVASION: defeat the ghosts (%d/%d)" % [_done, _goal]
		"rift":
			return "PORTAL EMERGENCY: seal the unstable rift"
		"skulker":
			return "SKULKER'S HUNT: survive or capture Skulker"
		"ember":
			return "EMBER'S CONCERT: destroy the amplifiers (%d/%d) before the crowd is hypnotised" % [_done, _goal]
		"giw":
			return "GUYS IN WHITE RAID: destroy the ghost traps (%d/%d) - %ds" % [_done, _goal, int(maxf(0.0, 75.0 - _time))]
		"technus":
			return "TECHNUS TAKEOVER: stop the hacked machines (%d/%d). City power is out!" % [_done, _goal]
		"night":
			return "NIGHT TERRORS: banish the shadow ghosts (%d/%d)" % [_done, _goal]
	return ""


func is_active() -> bool:
	return active != ""


func start_random() -> void:
	var options := ["invasion", "rift", "giw", "technus"]
	if game.night > 0.5:
		options += ["ember", "night", "night"]
	if GameState.story_chapter >= 3:
		options.append("skulker")
	start(options[randi() % options.size()])


func _pick_spot() -> Vector3:
	var spots: Array = game.amity.event_spots
	var p: Vector3 = game.player.global_position
	# Prefer somewhere reasonably close so events find the player.
	var best: Vector3 = spots[randi() % spots.size()]
	for i in 6:
		var s: Vector3 = spots[randi() % spots.size()]
		var d := s.distance_to(p)
		if d > 60.0 and d < best.distance_to(p):
			best = s
	return best


func start(kind: String) -> void:
	active = kind
	_time = 0.0
	_done = 0
	_targets.clear()
	_enemies.clear()
	_spot = _pick_spot()
	var title := ""
	match kind:
		"invasion":
			_goal = 8
			title = "GHOST INVASION"
			for i in _goal:
				_spawn("minion" if i % 3 else "shadow", _spot + Vector3(randf_range(-30, 30), randf_range(4, 25), randf_range(-30, 30)))
		"rift":
			_goal = 1
			title = "PORTAL EMERGENCY"
			_target("rift", _spot)
			for i in 3:
				_spawn("minion", _spot + Vector3(randf_range(-10, 10), 6, randf_range(-10, 10)))
		"skulker":
			_goal = 1
			title = "SKULKER'S HUNT"
			var b: Node = game.spawn_boss("skulker", game.player.global_position + Vector3(40, 30, 0))
			b.died.connect(func(_e: Node, _c: bool) -> void: _done += 1)
			_enemies.append(b)
			_spot = game.player.global_position
		"ember":
			_goal = 3
			_spot = game.amity.stage_spot
			title = "EMBER'S CONCERT"
			for i in 3:
				_target("speaker", _spot + Vector3(-8 + i * 8, 1.2, 1.0))
			for p in get_tree().get_nodes_in_group("pedestrians"):
				if p.global_position.distance_to(_spot) < 140.0:
					p.hypnotize(_spot + Vector3(randf_range(-10, 10), 0, 14))
			GameState.notify.emit("\"You're gonna remember my name!\" - Ember's music is hypnotising the crowd!", Color(0.85, 0.5, 1.0))
		"giw":
			_goal = 3
			title = "GUYS IN WHITE RAID"
			for i in 3:
				_target("trap", _spot + Vector3(-14 + i * 14, 0.2, randf_range(-6, 6)))
			for i in 3:
				_spawn("giw", _spot + Vector3(randf_range(-15, 15), 1, randf_range(-15, 15)))
		"technus":
			_goal = 0
			title = "TECHNUS TAKEOVER"
			_target("node", game.amity.substation_spot)
			var cars := get_tree().get_nodes_in_group("cars")
			cars.sort_custom(func(a, b): return a.global_position.distance_to(game.player.global_position) < b.global_position.distance_to(game.player.global_position))
			for i in mini(3, cars.size()):
				cars[i].set_hacked(true)
				cars[i].destroyed.connect(_on_target_down, CONNECT_ONE_SHOT)
				_targets.append(cars[i])
			for i in 3:
				_spawn("hacked", _spot + Vector3(randf_range(-20, 20), 8, randf_range(-20, 20)))
			_goal = _targets.size()
			power_out = true
			_spot = game.amity.substation_spot
			GameState.notify.emit("\"I am TECHNUS, master of all things electronic!\"", Color(0.5, 1.0, 0.5))
		"night":
			_goal = 6
			title = "NIGHT TERRORS"
			for i in _goal:
				_spawn("shadow", _spot + Vector3(randf_range(-35, 35), randf_range(5, 30), randf_range(-35, 35)))
	if game.director_waypoint_ok():
		game.set_waypoint(_spot + Vector3(0, 3, 0), title.capitalize(), "amity")
	game.hud.show_banner(title, "Dynamic event", 3.0)


func _spawn(kind: String, pos: Vector3, tracked := true) -> Node:
	var e: Node = game.spawn_enemy(kind, pos, game.amity)
	e.leash = 200.0
	if tracked:
		_enemies.append(e)
		e.died.connect(func(_en: Node, _cap: bool) -> void:
			if active in ["invasion", "night"]:
				_done += 1)
	return e


func _target(kind: String, pos: Vector3) -> void:
	var t: StaticBody3D = Destructible.new()
	t.kind = kind
	t.game = game
	t.max_health = {"rift": 180.0, "speaker": 70.0, "node": 120.0, "trap": 60.0}[kind]
	t.position = pos
	game.amity.add_child(t)
	t.destroyed.connect(_on_target_down)
	_targets.append(t)


func _on_target_down(_t: Node) -> void:
	_done += 1


func _update_event(delta: float) -> void:
	_time += delta
	var finished := _done >= _goal
	if active == "giw" and _time > 75.0:
		finished = true
	if active == "technus":
		var node_alive := false
		for t in _targets:
			if is_instance_valid(t) and t.has_method("health_ratio"):
				node_alive = true
		finished = _done >= _goal + 1 or (not node_alive and _done >= _goal)
	if finished:
		_complete(true)
	elif _time > 240.0:
		_complete(false)


func _complete(success: bool) -> void:
	var kind := active
	active = ""
	_cooldown = randf_range(70.0, 120.0)
	power_out = false
	for t in _targets:
		if is_instance_valid(t):
			if t.has_method("set_hacked"):
				t.set_hacked(false)
			elif t.has_method("health_ratio"):
				t.queue_free()
	for e in _enemies:
		if is_instance_valid(e) and e.is_alive() and not success:
			e.queue_free()
	_targets.clear()
	_enemies.clear()
	if kind == "ember":
		for p in get_tree().get_nodes_in_group("pedestrians"):
			p.wake()
	if game.director_waypoint_ok():
		game.missions._update_waypoint()
	if success:
		GameState.add_xp(60, "Event cleared")
		GameState.add_reputation(1)
		game.hud.show_banner("AMITY PARK IS SAFE", "Hero Reputation +1", 3.0)
		GameState.save_game()
	else:
		GameState.notify.emit("The event fizzled out... the ghosts slipped away.", Color(1, 0.7, 0.6))


func _ambient() -> void:
	var p: Vector3 = game.player.global_position
	var count := 0
	for e in get_tree().get_nodes_in_group("ambient"):
		if e.is_inside_tree():
			if e.global_position.distance_to(p) > 300.0:
				e.queue_free()
			else:
				count += 1
	if game.realm == "amity":
		var cap := 2 + int(game.night * 4.0)
		if count < cap:
			var a := randf() * TAU
			var pos := p + Vector3(cos(a), 0, sin(a)) * randf_range(70, 140) + Vector3(0, randf_range(10, 40), 0)
			var kind := "shadow" if game.night > 0.5 and randf() < 0.5 else "minion"
			var e: Node = game.spawn_enemy(kind, pos, game.amity)
			e.add_to_group("ambient")
	else:
		var zones: Array = game.ghost_zone.enemy_zones
		for z in zones:
			if z[0].distance_to(p) < z[1] + 200.0 and count < 7:
				var pos: Vector3 = z[0] + Vector3(randf_range(-z[1], z[1]) * 0.6, randf_range(0, 20), randf_range(-z[1], z[1]) * 0.6)
				if pos.distance_to(p) > 35.0:
					var e: Node = game.spawn_enemy(z[2], pos, game.ghost_zone)
					e.add_to_group("ambient")
					count += 1
