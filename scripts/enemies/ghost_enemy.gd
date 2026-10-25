extends CharacterBody3D
## Standard enemy: roaming ghosts, night shadows, Walker's guards, food
## minions and Guys in White agents. Weakened ghosts can be captured with
## the Fenton Thermos. Bosses extend this script.

const B := preload("res://scripts/util/builder.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")

signal died(enemy: Node, captured: bool)

var kind := "minion"
var display_name := "Ghost"
var max_health := 36.0
var health := 36.0
var speed := 8.0
var damage := 7.0
var fire_rate := 1.7
var attack_range := 30.0
var sight := 65.0
var xp := 15
var flies := true
var capturable := true
var weaken_ratio := 0.3
var state := "wander"
var home := Vector3.ZERO
var leash := 120.0

var target: Node3D = null
var visual: Node3D
var swirl: Node3D
var ice_block: Node3D
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _fire_t := 1.5
var _frozen_t := 0.0
var _weak_t := 0.0
var _knock := Vector3.ZERO
var _t := 0.0
var _hit_flash := 0.0
var _body_mats: Array[StandardMaterial3D] = []
var _scale_base := 1.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("capturable")
	_setup_kind()
	collision_layer = B.L_ENEMY
	collision_mask = B.L_WORLD if flies else (B.L_WORLD | B.L_PHASE)
	health = max_health
	if home == Vector3.ZERO:
		home = global_position
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6 * _scale_base
	shape.height = 1.8 * _scale_base
	cs.shape = shape
	cs.position.y = 0.9 * _scale_base
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	_build_visual()
	_fire_t = randf_range(0.8, fire_rate + 0.5)


func _setup_kind() -> void:
	match kind:
		"shadow":
			display_name = "Shadow Ghost"
			max_health = 55.0
			speed = 10.0
			damage = 10.0
			xp = 25
		"guard":
			display_name = "Walker's Guard"
			max_health = 45.0
			speed = 7.0
			damage = 8.0
			xp = 20
		"food":
			display_name = "Mystery Meat"
			max_health = 18.0
			speed = 9.0
			damage = 5.0
			xp = 8
			attack_range = 4.0
		"giw":
			display_name = "Guy in White"
			max_health = 40.0
			speed = 6.0
			damage = 6.0
			xp = 18
			flies = false
			capturable = false
			fire_rate = 1.3
		"hacked":
			display_name = "Hacked Drone"
			max_health = 25.0
			speed = 12.0
			damage = 6.0
			xp = 12
			capturable = false


# --- Visuals -------------------------------------------------------------
func _body_mat(c: Color, emission := 0.3) -> StandardMaterial3D:
	var m := B.toon_unique(c, emission, 0.03)
	_body_mats.append(m)
	return m


func _build_visual() -> void:
	match kind:
		"giw":
			var suit := _body_mat(Color(0.95, 0.95, 0.97), 0.0)
			var torso := B.cylinder(visual, 0.3, 1.0, Vector3(0, 1.15, 0), suit, 0)
			torso.scale = Vector3(1.0, 1.0, 0.75)
			B.box(visual, Vector3(0.5, 0.8, 0.3), Vector3(0, 0.4, 0), suit, 0)
			B.sphere(visual, 0.2, Vector3(0, 1.85, 0), B.toon(Color(0.95, 0.78, 0.66), 0.0, 0.02))
			B.box(visual, Vector3(0.34, 0.08, 0.06), Vector3(0, 1.88, -0.18), B.toon(Color(0.02, 0.02, 0.02)), 0)
			B.box(visual, Vector3(0.12, 0.12, 0.6), Vector3(0.3, 1.2, -0.35), B.toon(Color(0.2, 0.2, 0.25), 0.0, 0.01), 0)
			B.sphere(visual, 0.06, Vector3(0.3, 1.2, -0.68), B.glow(Color(0.4, 0.8, 1.0), 3.0))
		"guard":
			var m := _body_mat(Color(0.88, 0.9, 0.95), 0.2)
			B.box(visual, Vector3(0.7, 1.1, 0.45), Vector3(0, 1.1, 0), m, 0)
			B.sphere(visual, 0.28, Vector3(0, 1.9, 0), _body_mat(Color(0.7, 0.95, 0.75), 0.4))
			B.cylinder(visual, 0.32, 0.1, Vector3(0, 2.12, 0), B.toon(Color(0.1, 0.1, 0.12)), 0)
			B.cylinder(visual, 0.2, 0.25, Vector3(0, 2.25, 0), B.toon(Color(0.1, 0.1, 0.12)), 0)
			_eyes(Vector3(0, 1.92, -0.25), Color(1.0, 0.3, 0.2), 0.05)
			var tail := B.cylinder(visual, 0.32, 0.8, Vector3(0, 0.25, 0), m, 0, 0.0)
			tail.rotation.x = PI
		"food":
			var m := _body_mat(Color(0.55, 0.32, 0.2), 0.2)
			B.sphere(visual, 0.55, Vector3(0, 0.8, 0), m)
			_eyes(Vector3(0, 0.95, -0.45), Color(1, 1, 0.3), 0.08)
		"hacked":
			var m := _body_mat(Color(0.25, 0.3, 0.35), 0.0)
			B.box(visual, Vector3(1.2, 0.35, 1.2), Vector3(0, 1.0, 0), m, 0)
			for x in [-0.7, 0.7]:
				for z in [-0.7, 0.7]:
					B.cylinder(visual, 0.3, 0.05, Vector3(x, 1.2, z), B.glow(Color(0.3, 1.0, 0.4), 2.0, 0.6), 0)
			_eyes(Vector3(0, 0.95, -0.6), Color(0.3, 1.0, 0.4), 0.12)
		_:
			var c := Color(0.55, 0.95, 0.75) if kind == "minion" else Color(0.32, 0.12, 0.45)
			var m := _body_mat(c, 0.6)
			var head := B.sphere(visual, 0.62, Vector3(0, 1.25, 0), m, 0, 18)
			head.scale = Vector3(1.0, 1.1, 1.0)
			var tail := B.cylinder(visual, 0.55, 1.2, Vector3(0, 0.45, 0.1), m, 0, 0.0)
			tail.rotation.x = PI + 0.3
			for side in [-1.0, 1.0]:
				var arm := B.cylinder(visual, 0.14, 0.7, Vector3(0.62 * side, 1.05, -0.1), m, 0, 0.05)
				arm.rotation.z = 0.9 * side
			_eyes(Vector3(0, 1.35, -0.55), Color(1.0, 0.2, 0.2) if kind == "minion" else Color(1.0, 0.85, 0.2), 0.11)
			var mouth := B.box(visual, Vector3(0.4, 0.08, 0.05), Vector3(0, 1.05, -0.6), B.toon(Color(0.05, 0.08, 0.06)), 0)
			mouth.rotation.z = 0.1


func _eyes(center: Vector3, c: Color, r: float, parent: Node3D = null) -> void:
	for side in [-1.0, 1.0]:
		var e := B.sphere(parent if parent else visual, r, center + Vector3(r * 1.6 * side, 0, 0), B.glow(c, 4.0), 0, 8)
		e.scale = Vector3(1.0, 1.3, 0.6)


# --- Queries used by the player / game -----------------------------------
func is_alive() -> bool:
	return state != "dead" and state != "captured"


func is_capturable() -> bool:
	return capturable and state == "weakened"


func capture_time() -> float:
	return 1.1


func pull_toward(pos: Vector3, progress: float, delta: float) -> void:
	global_position = global_position.lerp(pos, clampf(delta * 2.5 * progress, 0.0, 1.0))
	visual.scale = Vector3.ONE * maxf(0.15, 1.0 - progress * 0.85)
	visual.rotation.y += delta * 20.0


func captured() -> void:
	if not is_alive():
		return
	state = "captured"
	GameState.thermos.append(display_name)
	GameState.ghosts_defeated += 1
	GameState.add_xp(xp + 10, "Captured %s" % display_name)
	died.emit(self, true)
	queue_free()


func knockback(v: Vector3) -> void:
	_knock += v


# --- Damage --------------------------------------------------------------
func take_damage(amount: float, from := Vector3.ZERO, effect := "") -> void:
	if not is_alive():
		return
	if state == "frozen":
		amount *= 2.0
	health -= amount
	_hit_flash = 0.12
	B.popup(get_parent(), global_position + Vector3(0, 2.2 * _scale_base, 0), str(int(amount)), Color(1, 1, 0.6) if effect != "ice" else Color(0.6, 0.9, 1.0), 48)
	if effect == "ice" and state != "weakened":
		_freeze(4.0)
	if from != Vector3.ZERO and effect != "wail":
		_knock += (global_position - from).normalized() * 3.0
	if health <= 0.0:
		_on_zero_health()
	elif capturable and health <= max_health * weaken_ratio and state != "weakened":
		_weaken()
	elif target == null:
		target = _find_target(999.0)


func _on_zero_health() -> void:
	state = "dead"
	GameState.ghosts_defeated += 1
	GameState.add_xp(xp)
	B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.4, 1.0, 0.6) if kind != "giw" else Color(1, 1, 1), 40, 7.0, 0.3)
	died.emit(self, false)
	queue_free()


func _weaken() -> void:
	state = "weakened"
	_weak_t = 14.0
	if ice_block:
		ice_block.queue_free()
		ice_block = null
	swirl = B.torus(self, 0.25, 0.45, Vector3(0, 2.4 * _scale_base, 0), B.glow(Color(1.0, 0.95, 0.4), 3.0))
	B.popup(get_parent(), global_position + Vector3(0, 2.8 * _scale_base, 0), "WEAKENED - HOLD E", Color(0.7, 0.9, 1.0), 40)


func _freeze(t: float) -> void:
	if state == "weakened":
		return
	state = "frozen"
	_frozen_t = t
	get_tree().call_group("game", "on_enemy_frozen")
	if ice_block == null:
		ice_block = B.box(self, Vector3(1.6, 2.4, 1.6) * _scale_base, Vector3(0, 1.1 * _scale_base, 0), B.glow(Color(0.7, 0.9, 1.0), 0.8, 0.55), 0)


# --- AI ------------------------------------------------------------------
func _find_target(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range
	for t in get_tree().get_nodes_in_group("player_targets"):
		if not (t is Node3D) or not t.is_inside_tree():
			continue
		if t.get("dead") == true:
			continue
		var d: float = t.global_position.distance_to(global_position)
		if t.has_method("is_hidden") and t.is_hidden() and d > 4.0:
			continue
		if d < best_d:
			best = t
			best_d = d
	return best


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_t += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	for m in _body_mats:
		m.emission_energy_multiplier = 3.0 if _hit_flash > 0.0 else 0.5
	var desired := Vector3.ZERO
	match state:
		"frozen":
			_frozen_t -= delta
			if _frozen_t <= 0.0:
				state = "chase"
				if ice_block:
					ice_block.queue_free()
					ice_block = null
			desired = Vector3.ZERO
		"weakened":
			_weak_t -= delta
			visual.rotation.y += delta * 3.0
			if swirl:
				swirl.rotation.y += delta * 6.0
			desired = Vector3(sin(_t), -0.2, cos(_t)) * 1.0
			if _weak_t <= 0.0:
				state = "chase"
				health = max_health * 0.6
				if swirl:
					swirl.queue_free()
					swirl = null
		_:
			desired = _think(delta)
	_knock = _knock.lerp(Vector3.ZERO, clampf(delta * 4.0, 0.0, 1.0))
	if flies:
		velocity = velocity.lerp(desired + _knock, clampf(delta * 3.0, 0.0, 1.0))
	else:
		var hv := Vector3(desired.x, 0, desired.z) + Vector3(_knock.x, 0, _knock.z)
		velocity.x = lerpf(velocity.x, hv.x, clampf(delta * 8.0, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, hv.z, clampf(delta * 8.0, 0.0, 1.0))
		velocity.y = 0.0 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()
	if flies:
		visual.position.y = sin(_t * 2.5) * 0.15
	if target and state != "weakened":
		var to := target.global_position - global_position
		if Vector2(to.x, to.z).length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 6.0, 0.0, 1.0))


## Default behaviour: wander near home, chase and shoot when a target is seen.
func _think(delta: float) -> Vector3:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or target.get("dead") == true:
		target = null
	elif target.has_method("is_hidden") and target.is_hidden() and global_position.distance_to(target.global_position) > 4.0:
		target = null
	if target == null:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander = home + Vector3(randf_range(-20, 20), randf_range(2, 12) if flies else 0.0, randf_range(-20, 20))
			target = _find_target(sight)
		var to_w := _wander - global_position
		if not flies:
			to_w.y = 0
		return to_w.normalized() * speed * 0.4 if to_w.length() > 1.5 else Vector3.ZERO
	var to := target.global_position + Vector3(0, 1.2, 0) - global_position
	var dist := to.length()
	if dist > sight * 1.6 or global_position.distance_to(home) > leash:
		target = null
		return (home - global_position).normalized() * speed
	_fire_t -= delta
	if _fire_t <= 0.0 and dist < attack_range:
		_fire_t = fire_rate * randf_range(0.8, 1.2)
		_attack(target, dist)
	# Strafe around the target at a comfortable distance.
	var keep := attack_range * 0.45
	var dir := to.normalized()
	var side := dir.cross(Vector3.UP).normalized() * sin(_t * 0.7 + get_instance_id() % 7)
	var move := side * 0.6
	if dist > keep:
		move += dir
	elif dist < keep * 0.5:
		move -= dir
	if flies:
		move.y += clampf((target.global_position.y + 2.5 - global_position.y) * 0.2, -1.0, 1.0)
	return move.normalized() * speed if move.length() > 0.05 else Vector3.ZERO


func _attack(t: Node3D, dist: float) -> void:
	var from := global_position + Vector3(0, 1.3 * _scale_base, 0) - global_basis.z * 0.7
	var aim: Vector3 = t.global_position + Vector3(0, 1.0, 0) + (t.get("velocity") if t.get("velocity") != null else Vector3.ZERO) * (dist / 45.0) * 0.5
	match kind:
		"food":
			if dist < 4.5 and t.has_method("take_damage"):
				t.take_damage(damage, global_position, "")
				B.burst(get_parent(), t.global_position + Vector3(0, 1, 0), Color(0.6, 0.3, 0.2), 12, 4.0, 0.2)
		"giw":
			Projectile.spawn(get_parent(), from, aim - from, {"speed": 50.0, "damage": damage, "team": "enemy", "color": Color(0.5, 0.85, 1.0), "radius": 0.18, "shooter": self})
		"guard":
			Projectile.spawn(get_parent(), from, aim - from, {"speed": 38.0, "damage": damage, "team": "enemy", "effect": "goo", "color": Color(0.5, 1.0, 0.5), "radius": 0.3, "shooter": self})
		_:
			Projectile.spawn(get_parent(), from, aim - from, {"speed": 40.0, "damage": damage, "team": "enemy", "color": Color(1.0, 0.35, 0.3) if kind != "shadow" else Color(0.75, 0.3, 1.0), "radius": 0.28, "shooter": self})
