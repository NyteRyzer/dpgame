extends "res://scripts/enemies/ghost_enemy.gd"
## Multi-phase boss ghosts. Each boss has its own attack patterns, a phase-2
## transition at half health, and must be captured in the Fenton Thermos
## once defeated.

signal phase_changed(phase: int)

var boss_id := "lunch_lady"
var game: Node = null
var phase := 1
var shout: Label3D
var _pattern := 0
var _special_t := 8.0
var _shout_t := 0.0

const LINES := {
	"lunch_lady": ["Who wants MEAT?!", "You will eat your vegetables... I mean, MEAT!", "Respect the old menu!", "MYSTERY MEAT, ASSEMBLE!"],
	"box_ghost": ["I am the BOX GHOST!", "BEWARE!", "Fear my cardboard fury!", "Corrugated chaos!"],
	"skulker": ["Your pelt will look fine on my wall, whelp.", "The Ghost Zone's greatest hunter!", "Target acquired.", "Switching to hunting mode!"],
	"walker": ["Rule 47: no flying in my prison.", "You're in violation, punk.", "Lock him up!", "Everyone does time eventually."],
}


func _setup_kind() -> void:
	capturable = true
	weaken_ratio = 0.0
	leash = 260.0
	sight = 120.0
	match boss_id:
		"lunch_lady":
			display_name = "The Lunch Lady"
			max_health = 260.0
			speed = 6.0
			damage = 9.0
			fire_rate = 1.8
			attack_range = 35.0
			xp = 150
			_scale_base = 1.5
		"box_ghost":
			display_name = "The Box Ghost"
			max_health = 200.0
			speed = 9.0
			damage = 10.0
			fire_rate = 1.6
			attack_range = 40.0
			xp = 150
			_scale_base = 1.4
		"skulker":
			display_name = "Skulker"
			max_health = 400.0
			speed = 15.0
			damage = 13.0
			fire_rate = 2.2
			attack_range = 60.0
			xp = 250
			_scale_base = 1.6
		"walker":
			display_name = "Walker"
			max_health = 360.0
			speed = 8.0
			damage = 10.0
			fire_rate = 1.4
			attack_range = 45.0
			xp = 250
			_scale_base = 1.5


func _ready() -> void:
	add_to_group("bosses")
	super._ready()
	shout = B.label(self, "", Vector3(0, 3.6 * _scale_base, 0), 56, Color(1, 1, 0.75), true, 0.012)
	shout.no_depth_test = true
	_say(0)


func _say(i := -1) -> void:
	var lines: Array = LINES.get(boss_id, ["..."])
	shout.text = lines[i if i >= 0 else randi() % lines.size()]
	shout.modulate.a = 1.0
	_shout_t = 3.0


func _build_visual() -> void:
	var s := _scale_base
	var root := Node3D.new()
	root.scale = Vector3.ONE * s
	visual.add_child(root)
	match boss_id:
		"lunch_lady":
			var skin := _body_mat(Color(0.6, 0.85, 0.7), 0.5)
			var dress := _body_mat(Color(0.45, 0.2, 0.5), 0.2)
			var body := B.sphere(root, 0.7, Vector3(0, 1.0, 0), dress, 0, 18)
			body.scale = Vector3(1.0, 1.15, 0.9)
			B.box(root, Vector3(0.9, 0.9, 0.1), Vector3(0, 0.95, -0.58), B.toon(Color(0.95, 0.95, 0.92), 0.0, 0.02), 0)
			B.sphere(root, 0.36, Vector3(0, 1.95, 0), skin)
			var net := B.sphere(root, 0.38, Vector3(0, 2.08, 0.04), B.toon(Color(0.96, 0.96, 0.98), 0.1, 0.02))
			net.scale = Vector3(1.0, 0.6, 1.0)
			_eyes(Vector3(0, 1.98, -0.32), Color(1.0, 0.25, 0.25), 0.06, root)
			for side in [-1.0, 1.0]:
				var arm := B.cylinder(root, 0.13, 0.8, Vector3(0.72 * side, 1.25, -0.15), skin, 0, 0.1)
				arm.rotation.z = 1.0 * side
			var tail := B.cylinder(root, 0.6, 1.0, Vector3(0, 0.15, 0.1), dress, 0, 0.0)
			tail.rotation.x = PI + 0.3
		"box_ghost":
			var skin := _body_mat(Color(0.55, 0.75, 0.95), 0.6)
			var overalls := _body_mat(Color(0.2, 0.3, 0.6), 0.1)
			var body := B.sphere(root, 0.62, Vector3(0, 1.1, 0), overalls, 0, 18)
			body.scale = Vector3(1.1, 1.2, 0.9)
			B.sphere(root, 0.34, Vector3(0, 1.95, 0), skin)
			var cap := B.cylinder(root, 0.34, 0.16, Vector3(0, 2.2, 0), B.toon(Color(0.15, 0.2, 0.45), 0.0, 0.02), 0)
			cap.rotation.x = 0.15
			_eyes(Vector3(0, 2.0, -0.3), Color(1, 1, 1), 0.06, root)
			B.box(root, Vector3(0.8, 0.6, 0.6), Vector3(0, 1.3, -0.9), B.toon(Color(0.68, 0.5, 0.3), 0.0, 0.03), 0)
			var tail := B.cylinder(root, 0.5, 1.0, Vector3(0, 0.2, 0.1), skin, 0, 0.0)
			tail.rotation.x = PI + 0.3
		"skulker":
			var armor := _body_mat(Color(0.35, 0.4, 0.42), 0.1)
			var dark := B.toon(Color(0.15, 0.17, 0.2), 0.0, 0.02)
			B.box(root, Vector3(1.0, 1.0, 0.7), Vector3(0, 1.35, 0), armor, 0)
			B.box(root, Vector3(0.7, 0.7, 0.5), Vector3(0, 0.6, 0), dark, 0)
			B.box(root, Vector3(0.45, 0.45, 0.45), Vector3(0, 2.1, 0), armor, 0)
			_eyes(Vector3(0, 2.15, -0.24), Color(1.0, 0.15, 0.1), 0.05, root)
			var flame := B.particles(root, Color(0.3, 1.0, 0.4), 24, 0.6, false, 1.2, 0.18)
			flame.position = Vector3(0, 2.4, 0)
			flame.direction = Vector3(0, 1, 0.3)
			flame.spread = 20.0
			for side in [-1.0, 1.0]:
				B.box(root, Vector3(0.35, 0.35, 0.35), Vector3(0.68 * side, 1.75, 0), armor, 0)
				var cannon := B.cylinder(root, 0.1, 0.7, Vector3(0.68 * side, 2.0, -0.2), dark, 0)
				cannon.rotation.x = PI / 2
				var leg := B.box(root, Vector3(0.28, 0.8, 0.3), Vector3(0.25 * side, 0.0, 0), dark, 0)
				leg.rotation.x = 0.2
			B.box(root, Vector3(0.6, 0.8, 0.3), Vector3(0, 1.4, 0.48), dark, 0)
			var jet := B.particles(root, Color(1.0, 0.6, 0.2), 24, 0.35, false, 3.0, 0.2)
			jet.position = Vector3(0, 0.9, 0.5)
			jet.direction = Vector3(0, -1, 0)
			jet.spread = 15.0
		"walker":
			var suit := _body_mat(Color(0.92, 0.93, 0.96), 0.15)
			var skin := _body_mat(Color(0.72, 0.9, 0.75), 0.4)
			var body := B.box(root, Vector3(0.9, 1.3, 0.55), Vector3(0, 1.2, 0), suit, 0)
			body.rotation.y = 0.0
			B.sphere(root, 0.32, Vector3(0, 2.15, 0), skin)
			B.cylinder(root, 0.5, 0.06, Vector3(0, 2.38, 0), B.toon(Color(0.08, 0.08, 0.1)), 0)
			B.cylinder(root, 0.3, 0.32, Vector3(0, 2.55, 0), B.toon(Color(0.08, 0.08, 0.1)), 0)
			_eyes(Vector3(0, 2.18, -0.28), Color(1.0, 0.3, 0.2), 0.05, root)
			B.box(root, Vector3(0.08, 0.6, 0.04), Vector3(0, 1.3, -0.3), B.toon(Color(0.1, 0.1, 0.12)), 0)
			var tail := B.cylinder(root, 0.45, 0.9, Vector3(0, 0.15, 0), suit, 0, 0.0)
			tail.rotation.x = PI


func capture_time() -> float:
	return 2.2


func _on_zero_health() -> void:
	# Bosses aren't destroyed: they're left dazed for the Fenton Thermos.
	health = 0.0
	state = "weakened"
	_weak_t = 99999.0
	swirl = B.torus(self, 0.3, 0.55, Vector3(0, 3.2 * _scale_base, 0), B.glow(Color(1.0, 0.95, 0.4), 3.0))
	shout.text = "Ugh... the Fenton Thermos? No..."
	_shout_t = 99.0
	GameState.notify.emit("%s is weakened! Hold [E] to capture with the Fenton Thermos." % display_name, Color(0.6, 0.9, 1.0))


func captured() -> void:
	if not is_alive():
		return
	state = "captured"
	GameState.thermos.append(display_name)
	GameState.ghosts_defeated += 1
	GameState.add_xp(xp, "Captured %s" % display_name)
	GameState.add_reputation(2)
	died.emit(self, true)
	queue_free()


func take_damage(amount: float, from := Vector3.ZERO, effect := "") -> void:
	if state == "weakened":
		return
	if effect == "ice" and boss_id == "skulker":
		amount *= 1.3
	super.take_damage(amount * (0.6 if effect == "ice" else 1.0), from, "" if effect == "ice" and _frozen_t > 0.0 else effect)
	if state == "frozen":
		_frozen_t = minf(_frozen_t, 1.5)  # bosses shake off ice quickly
	if phase == 1 and health < max_health * 0.5 and is_alive():
		_enter_phase_two()


func _enter_phase_two() -> void:
	phase = 2
	_say(3)
	B.shockwave(get_parent(), global_position + Vector3(0, 1.5, 0), Color(1.0, 0.4, 0.3), 10.0, 0.6)
	B.burst(get_parent(), global_position + Vector3(0, 1.5, 0), Color(1.0, 0.5, 0.3), 60, 12.0, 0.35)
	match boss_id:
		"lunch_lady":
			visual.scale = Vector3.ONE * 1.35
			speed = 7.5
		"box_ghost":
			fire_rate = 1.1
		"skulker":
			speed = 20.0
			fire_rate = 1.5
			for m in _body_mats:
				m.albedo_color = Color(0.5, 0.2, 0.18)
		"walker":
			fire_rate = 1.0
	_special_t = 2.0
	phase_changed.emit(2)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _shout_t > 0.0:
		_shout_t -= delta
		if _shout_t < 0.5:
			shout.modulate.a = maxf(0.0, _shout_t / 0.5)
	if state == "chase" or state == "wander":
		_special_t -= delta
		if _special_t <= 0.0 and target:
			_special()


func _think(delta: float) -> Vector3:
	# Bosses always hunt the hero once engaged.
	if target == null:
		target = _find_target(sight)
	var v := super._think(delta)
	if target:
		state = "chase"
	if boss_id == "skulker" and target:
		# Skulker circles high and fast around his prey.
		var to := target.global_position - global_position
		var around := to.cross(Vector3.UP).normalized()
		v = (around * 0.8 + to.normalized() * (0.4 if to.length() > 25.0 else -0.2)).normalized() * speed
		v.y = clampf(target.global_position.y + 8.0 - global_position.y, -6.0, 6.0)
	return v


func _attack(t: Node3D, dist: float) -> void:
	var from := global_position + Vector3(0, 1.6 * _scale_base, 0) - global_basis.z * 1.0
	var aim := t.global_position + Vector3(0, 1.0, 0)
	var world := get_parent()
	match boss_id:
		"lunch_lady":
			var n := 3 if phase == 1 else 5
			for i in n:
				var spread := (i - (n - 1) / 2.0) * 0.12
				var dir := (aim - from).normalized().rotated(Vector3.UP, spread) + Vector3(0, 0.25, 0)
				Projectile.spawn(world, from, dir, {"speed": 30.0, "damage": damage, "team": "enemy", "effect": "meat", "radius": 0.35, "drop": 9.0, "shooter": self})
			if phase == 2 and dist < 9.0:
				_slam()
		"box_ghost":
			var n := 1 if phase == 1 else 3
			for i in n:
				var dir := (aim - from).normalized().rotated(Vector3.UP, (i - (n - 1) / 2.0) * 0.18)
				Projectile.spawn(world, from, dir, {"speed": 28.0, "damage": damage, "team": "enemy", "effect": "box", "radius": 0.55, "shooter": self})
			if randf() < 0.3:
				_say()
		"skulker":
			_pattern = (_pattern + 1) % 3
			if _pattern == 0 or phase == 2:
				for side in [-1.0, 1.0]:
					var f: Vector3 = from + global_basis.x * side * 1.1
					var dir: Vector3 = (aim - f).normalized() + Vector3(0, 0.4, 0) + global_basis.x * side * 0.4
					Projectile.spawn(world, f, dir, {"speed": 26.0, "damage": damage, "team": "enemy", "effect": "explode", "radius": 0.35, "homing": t, "homing_strength": 1.6, "lifetime": 5.0, "shooter": self})
			if _pattern == 1:
				Projectile.spawn(world, from, aim - from, {"speed": 45.0, "damage": 5.0, "team": "enemy", "effect": "net", "radius": 0.6, "shooter": self})
			if _pattern == 2 and phase == 2:
				_minigun(t)
		"walker":
			var n := 3 if phase == 1 else 5
			for i in n:
				var dir := (aim - from).normalized().rotated(Vector3.UP, (i - (n - 1) / 2.0) * 0.1)
				Projectile.spawn(world, from, dir, {"speed": 40.0, "damage": damage, "team": "enemy", "effect": "goo", "color": Color(0.5, 1.0, 0.4), "radius": 0.32, "shooter": self})


func _minigun(t: Node3D) -> void:
	for i in 8:
		if not is_alive() or not is_instance_valid(t):
			return
		var from := global_position + Vector3(0, 2.2 * _scale_base, 0)
		var aim := t.global_position + Vector3(randf_range(-1, 1), 1.0 + randf_range(-0.5, 0.5), randf_range(-1, 1))
		Projectile.spawn(get_parent(), from, aim - from, {"speed": 70.0, "damage": 3.5, "team": "enemy", "color": Color(1.0, 0.8, 0.3), "radius": 0.12, "shooter": self})
		await get_tree().create_timer(0.08).timeout


func _slam() -> void:
	B.shockwave(get_parent(), global_position, Color(0.8, 0.4, 0.3), 9.0, 0.4)
	for p in get_tree().get_nodes_in_group("player_targets"):
		if p.global_position.distance_to(global_position) < 9.0 and p.has_method("take_damage"):
			p.take_damage(15.0, global_position, "explode")


func _special() -> void:
	match boss_id:
		"lunch_lady":
			_special_t = 12.0 if phase == 2 else 18.0
			_say(3)
			if game:
				for i in (3 if phase == 2 else 2):
					game.spawn_enemy("food", global_position + Vector3(randf_range(-5, 5), 0.5, randf_range(-5, 5)), get_parent())
		"box_ghost":
			_special_t = 6.0 if phase == 2 else 10.0
			# Blink to a new spot near the hero.
			if target:
				B.burst(get_parent(), global_position + Vector3(0, 1.5, 0), Color(0.6, 0.8, 1.0), 30, 6.0, 0.3)
				var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 14.0
				global_position = target.global_position + off + Vector3(0, 4, 0)
				B.burst(get_parent(), global_position + Vector3(0, 1.5, 0), Color(0.6, 0.8, 1.0), 30, 6.0, 0.3)
				_say(1)
		"skulker":
			_special_t = 9.0
			_say()
			# Flares: a ring of slow homing rockets.
			if phase == 2 and target:
				for i in 6:
					var dir := Vector3(cos(i * TAU / 6.0), 0.6, sin(i * TAU / 6.0))
					Projectile.spawn(get_parent(), global_position + Vector3(0, 2, 0), dir, {"speed": 18.0, "damage": 8.0, "team": "enemy", "effect": "explode", "radius": 0.3, "homing": target, "homing_strength": 1.0, "lifetime": 6.0, "shooter": self})
		"walker":
			_special_t = 14.0
			_say(2)
			if game and phase == 2:
				for i in 2:
					game.spawn_enemy("guard", global_position + Vector3(randf_range(-8, 8), 1.0, randf_range(-8, 8)), get_parent())
