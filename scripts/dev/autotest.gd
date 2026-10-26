extends Node
## Developer tool: plays through the story campaign by driving game systems
## directly and reports whether each objective advances.
## Run: godot --headless --path . res://scenes/game.tscn -- --autotest

var game: Node
var _fails := 0


func _ready() -> void:
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _check(label: String, cond: bool) -> void:
	print("%s  %s  (ch %d step %d)" % ["PASS" if cond else "FAIL", label, GameState.story_chapter, GameState.story_step])
	if not cond:
		_fails += 1


func _at(ch: int, step: int) -> bool:
	return GameState.story_chapter == ch and GameState.story_step == step


func _talk(id: String) -> void:
	game.talk_to(game.npcs[id])
	while not game._dialog.is_empty():
		game._advance_dialog()
	await _wait(2)


func _go(pos: Vector3) -> void:
	game.player.teleport(pos)
	await _wait(10)


func _beat_boss() -> void:
	for i in 300:
		await _wait(1)
		if game.missions.boss and is_instance_valid(game.missions.boss):
			break
	var b: Node = game.missions.boss
	_check("boss spawned: %s" % (b.display_name if b else "none"), b != null)
	if b == null:
		return
	b.take_damage(b.max_health * 0.6, Vector3.ZERO, "")
	_check("boss enters phase 2", b.phase == 2)
	b.take_damage(b.max_health, Vector3.ZERO, "")
	await _wait(5)
	_check("boss weakened -> capture step", game.missions.current_step().get("type") == "capture")
	b.captured()
	await _wait(5)


func _run() -> void:
	var p: Node3D = game.player
	var a: Node = game.amity
	await _wait(30)
	print("artifacts: amity %d, ghost zone %d" % [a.artifact_spots.size(), game.ghost_zone.artifact_spots.size()])
	_check("starts at chapter 1 step 0", _at(1, 0))
	await _go(a.spots["lab"])
	_check("reached lab", _at(1, 1))
	await _talk("jack")
	_check("talked to Jack", _at(1, 2))
	p.toggle_ghost()
	await _wait(120)
	_check("went ghost", _at(1, 3) and p.ghost)
	await _go(a.spots["roof"])
	_check("reached roof", _at(1, 4))
	await _go(a.spots["casper"])
	_check("reached Casper High", _at(1, 5))
	await _beat_boss()
	_check("Lunch Lady in thermos", GameState.thermos.has("The Lunch Lady"))
	game.deposit_thermos()
	await _wait(5)
	_check("chapter 1 complete", _at(2, 0))

	await _go(a.spots["nasty"] + Vector3(0, 0, 3))
	await _talk("sam")
	_check("met Sam & Tucker", _at(2, 1))
	await _go(Vector3(0, 30, -100))
	for i in 600:
		await _wait(2)
		for e in get_tree().get_nodes_in_group("story_wave"):
			if e.is_alive():
				e.take_damage(999.0, Vector3.ZERO, "")
		if not _at(2, 1):
			break
	_check("downtown invasion cleared", _at(2, 2))
	await _go(a.spots["mall"])
	await _beat_boss()
	_check("Box Ghost captured", _at(2, 4))
	await _go(a.spots["axion"])
	_check("reached Axion", _at(2, 5))
	await _go(a.spots["axion_roof"] + Vector3(0, 2, 0))
	await _beat_boss()
	game.deposit_thermos()
	await _wait(5)
	_check("chapter 2 complete + deflector", _at(3, 0) and GameState.has_tech("deflector"))

	game.travel("ghost_zone", "spawn")
	await _wait(10)
	_check("entered Ghost Zone", game.realm == "ghost_zone" and _at(3, 1))
	await _go(game.ghost_zone.spots["far_frozen"])
	_check("reached Far Frozen", _at(3, 2))
	await _talk("frostbite")
	_check("Frostbite taught ice", _at(3, 3) and GameState.has_power("ice"))
	for i in 3:
		var e: Node = game.spawn_enemy("minion", p.global_position + Vector3(10 + i * 3, 3, 0))
		await _wait(2)
		e.take_damage(1.0, Vector3.ZERO, "ice")
	await _wait(3)
	_check("ice training", _at(3, 4))
	await _go(game.ghost_zone.spots["prison_gate"])
	_check("reached prison gate", _at(3, 5))
	await _go(game.ghost_zone.spots["walker_yard"] + Vector3(0, 0, 10))
	await _beat_boss()
	_check("Walker captured", _at(3, 7))
	await _wait(200)  # portal travel cooldown
	game.travel("amity", "portal_exit")
	await _wait(10)
	_check("returned home", game.realm == "amity" and _at(3, 8))
	game.deposit_thermos()
	await _wait(5)
	_check("chapter 3 complete -> free roam", _at(4, 0) and game.missions.is_free_roam())

	# Systems smoke tests.
	game.director.start("rift")
	await _wait(5)
	_check("rift event started", game.director.active == "rift")
	for t in get_tree().get_nodes_in_group("event_targets"):
		t.take_damage(9999.0)
	await _wait(5)
	_check("rift event cleared", game.director.active == "")
	p.set_phase(true)
	_check("phasing", p.phasing and not (p.collision_mask & 8))
	p.set_phase(false)

	# Movement: walk up the basement stairs, then fly.
	if p.ghost:
		p.toggle_ghost()
		await _wait(120)
	await _go(Vector3(-207.5, -5.8, 115.0))
	p._yaw = PI
	Input.action_press("move_forward")
	await _wait(200)
	Input.action_release("move_forward")
	_check("climbed lab stairs (pos %s)" % str(p.global_position.snapped(Vector3.ONE * 0.1)), p.global_position.y > 0.0 and p.global_position.z > 123.0)
	await _go(Vector3(0, 0.3, 160))
	var start: Vector3 = p.global_position
	p._yaw = 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(60)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("sprinted %.1fm" % start.distance_to(p.global_position), start.distance_to(p.global_position) > 6.0)
	p.toggle_ghost()
	await _wait(120)
	Input.action_press("jump")
	await _wait(5)
	Input.action_release("jump")
	await _wait(2)
	Input.action_press("jump")
	await _wait(90)
	Input.action_release("jump")
	_check("flying upward (y=%.1f)" % p.global_position.y, p.flying and p.global_position.y > 10.0)
	var fstart: Vector3 = p.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(120)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("boost flight %.1fm" % fstart.distance_to(p.global_position), fstart.distance_to(p.global_position) > 40.0)
	# Flight feel: banking into a turn and leaning into fast flight.
	p._yaw = 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(60)
	_check("boost pose (lean %.2f, boosting %s)" % [p.model.fly_lean, p.boosting], p.boosting and p.model.fly_lean > 1.0)
	var max_bank := 0.0
	for i in 40:
		p._yaw += 0.04
		await _wait(1)
		max_bank = maxf(max_bank, absf(p.model.fly_bank))
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("banks into turns (%.2f)" % max_bank, max_bank > 0.15)

	# Aiming and zoom.
	var fov_before: float = p.camera.fov
	Input.action_press("aim")
	await _wait(40)
	var fov_aim: float = p.camera.fov
	p.aim_zoom = 1
	await _wait(40)
	var fov_zoom: float = p.camera.fov
	Input.action_release("aim")
	_check("aim zoom FOV %.0f -> %.0f -> %.0f" % [fov_before, fov_aim, fov_zoom], fov_aim < fov_before - 10.0 and fov_zoom < fov_aim - 10.0)

	# Weapon wheel: open, pick the Charged Beam, release.
	game.hud.wheel.open(p)
	_check("wheel slows time", Engine.time_scale < 0.5)
	game.hud.wheel.selected = 1
	game.hud.wheel.close(true)
	_check("wheel equips charged beam", p.weapon == "charge" and is_equal_approx(Engine.time_scale, 1.0))
	var dummy: Node = game.spawn_enemy("minion", p.global_position - p.camera.global_basis.z * 14.0)
	await _wait(30)
	p.energy = 100.0
	Input.action_press("fire")
	await _wait(80)
	_check("charge builds (%.2f)" % p.charge, p.charge > 0.9)
	for i in 10:
		# Track the target with the camera like a player would.
		if is_instance_valid(dummy):
			var d: Vector3 = dummy.global_position + Vector3(0, 1.2, 0) - p.camera.global_position
			p._yaw = atan2(-d.x, -d.z)
			p._pitch = asin(clampf(d.normalized().y, -1.0, 1.0))
		await _wait(1)
	Input.action_release("fire")
	await _wait(60)
	_check("charged blast hits", not is_instance_valid(dummy) or dummy.health < dummy.max_health)
	game.hud.wheel.open(p)
	game.hud.wheel.selected = 4
	game.hud.wheel.close(true)
	_check("wheel activates shield", p.shielded)
	p.set_shield(false)
	p.set_weapon("blast")

	# Ghost sense reacts when a ghost pops up nearby.
	game._sense_react_cd = 0.0
	game.hud._sense_t = 0.0
	game.spawn_enemy("minion", p.global_position + Vector3(20, 2, 0))
	await _wait(30)
	_check("ghost sense alert", game.hud._sense_t > 0.0 and p.model._shiver > 0.0)
	print("AUTOTEST DONE: %d failure(s), level %d, xp %d, rep %d" % [_fails, GameState.level, GameState.xp, GameState.reputation])
	get_tree().quit(1 if _fails > 0 else 0)
