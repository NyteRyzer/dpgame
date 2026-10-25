extends CharacterBody3D
## The playable hero: human mode, ghost mode, flight, the full ghost-power
## kit, the Fenton Thermos, and the third-person camera rig.

const B := preload("res://scripts/util/builder.gd")
const Model := preload("res://scripts/player/character_model.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const Clone := preload("res://scripts/player/clone.gd")

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.5
const GHOST_RUN := 9.0
const FLY_SPEED := 19.0
const BOOST_SPEED := 46.0
const GRAVITY := 22.0
const MAX_HEALTH := 100.0
const MAX_ENERGY := 100.0

var game: Node = null
var model: Node3D
var cam_pivot: Node3D
var cam_pitch: Node3D
var spring: SpringArm3D
var camera: Camera3D
var speed_lines: CPUParticles3D
var shield_mesh: MeshInstance3D
var beam: MeshInstance3D
var collision: CollisionShape3D

var health := MAX_HEALTH
var energy := MAX_ENERGY
var ghost := false
var flying := false
var phasing := false
var shielded := false
var invisible := false
var overshadowing: Node = null
var overshadow_time := 0.0
var dead := false
var realm := "amity"
var gravity_scale := 1.0

var cooldowns := {}
var cooldown_max := {}
var lock_time := 0.0
var invuln := 0.0
var net_time := 0.0
var slow_time := 0.0
var drained := 0.0
var sense_time := 0.0
var since_damage := 99.0
var fire_timer := 0.0
var aim_timer := 0.0
var shake := 0.0
var aiming := false
var thermos_target: Node3D = null
var thermos_progress := 0.0
var cinematic := false
var _yaw := 0.0
var _pitch := -0.2
var _last_safe := Vector3.ZERO
var _safe_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("player_targets")
	collision_layer = B.L_PLAYER
	collision_mask = B.L_WORLD | B.L_PHASE
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	collision.shape = cap
	collision.position.y = 0.9
	add_child(collision)

	model = Model.new()
	add_child(model)
	GameState.customization_changed.connect(func() -> void: model.apply_look(GameState.look))

	shield_mesh = B.sphere(model.rig, 1.25, Vector3.ZERO, B.glow(Color(0.35, 1.0, 0.6), 1.2, 0.22), 0, 24) as MeshInstance3D
	shield_mesh.visible = false
	var bm := CylinderMesh.new()
	bm.top_radius = 0.55
	bm.bottom_radius = 0.1
	bm.height = 1.0
	beam = B.mesh_instance(self, bm, Vector3.ZERO, B.glow(Color(0.6, 0.85, 1.0), 3.0, 0.55))
	beam.top_level = true
	beam.visible = false

	_build_camera()
	_last_safe = global_position


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	cam_pitch = Node3D.new()
	cam_pivot.add_child(cam_pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 5.0
	spring.collision_mask = B.L_WORLD | B.L_PHASE
	spring.margin = 0.3
	var s := SphereShape3D.new()
	s.radius = 0.25
	spring.shape = s
	spring.position = Vector3(0.55, 0, 0)
	spring.add_excluded_object(get_rid())
	cam_pitch.add_child(spring)
	camera = Camera3D.new()
	camera.far = 1800.0
	camera.fov = GameState.settings.get("fov", 75.0)
	spring.add_child(camera)
	camera.current = true
	speed_lines = B.particles(camera, Color(0.85, 1.0, 0.9), 40, 0.35, false, 1.0, 0.05)
	speed_lines.position = Vector3(0, 0, -6)
	speed_lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	speed_lines.emission_box_extents = Vector3(6, 4, 1)
	speed_lines.direction = Vector3(0, 0, 1)
	speed_lines.spread = 2.0
	speed_lines.initial_velocity_min = 30.0
	speed_lines.initial_velocity_max = 40.0
	speed_lines.scale_amount_min = 1.0
	speed_lines.scale_amount_max = 3.0
	speed_lines.emitting = false
	cam_pivot.global_position = global_position + Vector3(0, 1.6, 0)


func teleport(pos: Vector3, yaw := INF) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_last_safe = pos
	if yaw != INF:
		_yaw = yaw
		model.rotation.y = yaw
	if cam_pivot:
		cam_pivot.global_position = pos + Vector3(0, 1.6, 0)


# --- Input ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = GameState.settings.get("mouse_sensitivity", 0.25) * 0.01
		var inv := -1.0 if GameState.settings.get("invert_y", false) else 1.0
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * inv, -1.35, 1.1)


func is_intangible() -> bool:
	return phasing or (invuln > 0.0 and lock_time <= 0.0)


func is_hidden() -> bool:
	return invisible or overshadowing != null


func cooldown_ready(id: String) -> bool:
	return cooldowns.get(id, 0.0) <= 0.0


func _start_cd(id: String, t: float) -> void:
	cooldowns[id] = t
	cooldown_max[id] = t


func _toast(text: String, c := Color(1, 0.6, 0.6)) -> void:
	GameState.notify.emit(text, c)


# --- Main loop -----------------------------------------------------------
func _physics_process(delta: float) -> void:
	if dead:
		return
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	lock_time = maxf(0.0, lock_time - delta)
	invuln = maxf(0.0, invuln - delta)
	net_time = maxf(0.0, net_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	drained = maxf(0.0, drained - delta)
	sense_time = maxf(0.0, sense_time - delta)
	since_damage += delta
	fire_timer = maxf(0.0, fire_timer - delta)
	aim_timer = maxf(0.0, aim_timer - delta)

	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= stick.x * delta * 2.6
	_pitch = clampf(_pitch - stick.y * delta * 2.0, -1.35, 1.1)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if lock_time > 0.0 or (game and game.input_blocked()):
		input = Vector2.ZERO
	if lock_time > 0.0:
		velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))
		move_and_slide()
		_update_resources(delta)
		_update_model(delta, Vector3.ZERO)
		return

	var move_dir := Vector3.ZERO
	if flying:
		move_dir = _fly(delta, input)
	else:
		move_dir = _ground(delta, input)
	if not (game and game.input_blocked()):
		_handle_powers(delta)
	move_and_slide()
	_update_resources(delta)
	_update_model(delta, move_dir)
	_update_thermos(delta)

	# Remember a safe position for falling out of the world.
	_safe_timer += delta
	if is_on_floor() and _safe_timer > 1.0:
		_safe_timer = 0.0
		_last_safe = global_position
	if global_position.y < -120.0:
		teleport(_last_safe + Vector3(0, 2, 0))
		_toast("Whoa! Pulled back to safety.", Color(1, 1, 0.7))


func _cam_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


func _ground(delta: float, input: Vector2) -> Vector3:
	var b := _cam_basis()
	var dir := (b * Vector3(input.x, 0, input.y))
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := GHOST_RUN if ghost else WALK_SPEED
	if Input.is_action_pressed("sprint"):
		speed = GHOST_RUN * 1.5 if ghost else SPRINT_SPEED
	if overshadowing:
		speed = WALK_SPEED
	if slow_time > 0.0 or net_time > 0.0:
		speed *= 0.45
	var target := dir * speed
	var accel := 14.0 if is_on_floor() else 4.0
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(target, clampf(accel * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * gravity_scale * delta
	if Input.is_action_just_pressed("jump") and not (game and game.input_blocked()):
		if ghost and overshadowing == null and net_time <= 0.0:
			_start_flight()
		elif is_on_floor():
			velocity.y = 7.5 if gravity_scale >= 1.0 else 5.0
	return dir


func _start_flight() -> void:
	flying = true
	floor_snap_length = 0.0
	velocity.y = maxf(velocity.y, 7.0)
	B.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(0.4, 1.0, 0.6), 16, 4.0, 0.2)


func _land() -> void:
	flying = false
	floor_snap_length = 0.4
	model.set_tail(false)


func _fly(delta: float, input: Vector2) -> Vector3:
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var dir := b * Vector3(input.x, 0, input.y)
	var vert := 0.0
	if not (game and game.input_blocked()):
		if Input.is_action_pressed("jump"):
			vert += 1.0
		if Input.is_action_pressed("descend"):
			vert -= 1.0
	dir.y += vert
	if dir.length() > 1.0:
		dir = dir.normalized()
	var max_speed := FLY_SPEED
	if Input.is_action_pressed("sprint"):
		max_speed = BOOST_SPEED
	if model.tail_mode:
		max_speed *= 1.4
	if drained > 0.0 or slow_time > 0.0:
		max_speed *= 0.5
	var target := dir * max_speed
	# Momentum: accelerate quickly, glide to a stop.
	var rate := 3.2 if dir.length() > 0.1 else 1.6
	velocity = velocity.lerp(target, 1.0 - exp(-rate * delta))
	if dir.length() < 0.1:
		velocity.y += sin(Time.get_ticks_msec() * 0.002) * 0.02
	if Input.is_action_just_pressed("dodge") and cooldown_ready("dodge"):
		var d := dir if dir.length() > 0.1 else -(b.z)
		velocity += d.normalized() * 30.0
		invuln = 0.35
		_start_cd("dodge", 0.9)
		B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.6, 1.0, 0.8), 20, 6.0, 0.3)
	if is_on_floor() and vert < 0.0:
		_land()
	if net_time > 0.0 or not ghost:
		_land()
	return Vector3(velocity.x, 0, velocity.z) if velocity.length() > 2.0 else Vector3.ZERO


# --- Powers --------------------------------------------------------------
func _handle_powers(delta: float) -> void:
	aiming = Input.is_action_pressed("aim")
	if Input.is_action_just_pressed("transform"):
		toggle_ghost()
	if Input.is_action_pressed("fire") and fire_timer <= 0.0:
		_fire()
	if not ghost:
		if Input.is_action_just_pressed("dodge") and cooldown_ready("dodge") and is_on_floor():
			var d := Vector3(velocity.x, 0, velocity.z)
			if d.length() < 0.5:
				d = -_cam_basis().z
			velocity += d.normalized() * 12.0
			_start_cd("dodge", 1.0)
		return
	if Input.is_action_just_pressed("shield"):
		set_shield(not shielded)
	if Input.is_action_just_pressed("phase"):
		set_phase(not phasing)
	if Input.is_action_just_pressed("invisibility"):
		set_invisible(not invisible)
	if Input.is_action_just_pressed("ice"):
		_ice()
	if Input.is_action_just_pressed("sense"):
		_sense()
	if Input.is_action_just_pressed("wail"):
		_wail()
	if Input.is_action_just_pressed("duplicate"):
		_duplicate()
	if Input.is_action_just_pressed("construct"):
		_construct()
	if Input.is_action_just_pressed("overshadow"):
		_overshadow()
	if Input.is_action_just_pressed("tail"):
		if not GameState.has_power("tail"):
			pass
		elif flying:
			model.set_tail(not model.tail_mode)
		else:
			_toast("Take flight first to switch into ghost-tail form.", Color(0.8, 1, 0.9))
	if overshadowing:
		overshadow_time -= delta
		if overshadow_time <= 0.0:
			end_overshadow()


func toggle_ghost() -> void:
	if model.transforming or overshadowing:
		return
	var to_ghost := not ghost
	if not to_ghost:
		set_shield(false)
		set_phase(false, true)
		set_invisible(false)
	var horizontal := Vector2(velocity.x, velocity.z).length()
	cinematic = GameState.settings.get("cinematic_transform", true) and horizontal < 1.0 and (is_on_floor() or flying)
	var duration := 1.5 if cinematic else 0.4
	if cinematic:
		lock_time = duration + 0.1
		invuln = duration + 0.1
	ghost = to_ghost
	if game:
		game.on_player_transform(to_ghost)
	if not to_ghost and flying:
		_land()
	await model.play_transform(to_ghost, duration)
	cinematic = false


func _aim_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 400.0
	var q := PhysicsRayQueryParameters3D.create(from, to, B.L_WORLD | B.L_ENEMY | B.L_PHASE, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else to


func _face_camera() -> void:
	model.rotation.y = _yaw
	aim_timer = 0.5


func _fire() -> void:
	if phasing:
		fire_timer = 0.4
		_toast("You can't attack while intangible. [3] to solidify.", Color(0.8, 1, 0.9))
		return
	if overshadowing:
		return
	_face_camera()
	var hand: Vector3 = model.hand_position()
	var dir := (_aim_point() - hand).normalized()
	if ghost:
		if energy < 3.0:
			fire_timer = 0.3
			return
		energy -= 3.0
		fire_timer = 0.17
		Projectile.spawn(get_parent(), hand, dir, {"speed": 70.0, "damage": 12.0, "team": "player", "color": Color(0.3, 1.0, 0.45), "radius": 0.22, "shooter": self, "lifetime": 2.5})
	else:
		# Fenton Wrist Ray: weaker, but usable without revealing the secret.
		fire_timer = 0.32
		Projectile.spawn(get_parent(), hand, dir, {"speed": 60.0, "damage": 6.0, "team": "player", "color": Color(1.0, 0.25, 0.25), "radius": 0.15, "shooter": self, "lifetime": 1.6})
	if invisible:
		set_invisible(false)


func set_shield(on: bool) -> void:
	if on and energy < 10.0:
		_toast("Not enough ecto energy.")
		return
	shielded = on
	shield_mesh.visible = on


func set_phase(on: bool, force := false) -> void:
	if on:
		if energy < 5.0:
			_toast("Not enough ecto energy.")
			return
		phasing = true
		collision_mask = B.L_WORLD
		model.set_alpha(0.4)
		B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.7, 1.0, 0.9), 12, 2.0, 0.2)
		return
	if not phasing:
		return
	if not force and _inside_phase_wall():
		_toast("Too solid in here! Move out of the wall first.", Color(1, 0.9, 0.5))
		return
	phasing = false
	collision_mask = B.L_WORLD | B.L_PHASE
	model.set_alpha(0.12 if invisible else 1.0)


func _inside_phase_wall() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collision.shape
	q.transform = collision.global_transform
	q.collision_mask = B.L_PHASE
	q.margin = -0.05
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func set_invisible(on: bool) -> void:
	if on and energy < 10.0:
		_toast("Not enough ecto energy.")
		return
	invisible = on
	if on:
		model.set_alpha(0.12)
	else:
		model.set_alpha(0.4 if phasing else 1.0)


func _ice() -> void:
	if not GameState.has_power("ice"):
		_toast("Cryokinesis is locked. Train with Frostbite in the Far Frozen.", Color(0.7, 0.9, 1))
		return
	if not cooldown_ready("ice") or energy < 12.0 or phasing:
		return
	energy -= 12.0
	_start_cd("ice", 0.7)
	_face_camera()
	var hand: Vector3 = model.hand_position()
	var dir := (_aim_point() - hand).normalized()
	Projectile.spawn(get_parent(), hand, dir, {"speed": 55.0, "damage": 10.0, "team": "player", "effect": "ice", "color": Color(0.6, 0.9, 1.0), "radius": 0.3, "shooter": self, "lifetime": 2.0})


func _sense() -> void:
	if not cooldown_ready("sense"):
		return
	_start_cd("sense", 5.0)
	sense_time = 6.0
	var mist := B.particles(model.rig, Color(0.55, 0.8, 1.0), 26, 1.2, true, 1.2, 0.18)
	mist.position = Vector3(0, 0.6, -0.25)
	mist.direction = Vector3(0, 0.6, -1)
	mist.spread = 25.0
	if game:
		game.on_ghost_sense(sense_range())


func sense_range() -> float:
	return 240.0 if GameState.has_tech("scanner") else 120.0


func _wail() -> void:
	if not GameState.has_power("wail"):
		_toast("Ghostly Wail unlocks at Ghost Mastery Lv 4.", Color(0.8, 1, 0.9))
		return
	if not cooldown_ready("wail"):
		return
	if energy < 60.0:
		_toast("The Ghostly Wail needs 60 ecto energy.")
		return
	set_phase(false, true)
	set_invisible(false)
	_start_cd("wail", 40.0)
	lock_time = 1.2
	invuln = 1.2
	_face_camera()
	model.mouth_glow.visible = true
	shake = 0.25
	var charge := B.particles(model.rig, Color(0.5, 1.0, 0.75), 40, 0.5, false, -3.0, 0.2)
	charge.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	charge.emission_sphere_radius = 2.0
	await get_tree().create_timer(0.9).timeout
	charge.queue_free()
	if dead:
		return
	model.mouth_glow.visible = false
	shake = 1.2
	var origin := global_position + Vector3(0, 1.5, 0)
	var fwd := -_cam_basis().z
	var world := get_parent()
	for i in 3:
		B.shockwave(world, origin + fwd * (4.0 + i * 6.0), Color(0.55, 1.0, 0.8), 8.0 + i * 6.0, 0.6 + i * 0.15)
	B.burst(world, origin, Color(0.7, 1.0, 0.85), 80, 30.0, 0.35)
	for group in ["enemies", "destructibles"]:
		for n in get_tree().get_nodes_in_group(group):
			if not (n is Node3D) or not n.has_method("take_damage"):
				continue
			var to: Vector3 = n.global_position - origin
			var d := to.length()
			if d < 14.0 or (d < 45.0 and to.normalized().dot(fwd) > 0.3):
				n.take_damage(150.0 * (1.0 - d / 60.0), origin, "wail")
				if n.has_method("knockback"):
					n.knockback(to.normalized() * 30.0)
	energy = 0.0
	drained = 4.0
	_toast("GHOSTLY WAIL! Ecto reserves drained.", Color(0.6, 1, 0.8))


func _duplicate() -> void:
	if not GameState.has_power("duplicate"):
		_toast("Duplication unlocks at Ghost Mastery Lv 5.", Color(0.8, 1, 0.9))
		return
	if not cooldown_ready("duplicate") or energy < 30.0:
		return
	energy -= 30.0
	_start_cd("duplicate", 14.0)
	for side in [-1.0, 1.0]:
		var c: Node3D = Clone.new()
		c.player = self
		c.side = side
		get_parent().add_child(c)
		c.global_position = global_position + _cam_basis().x * side * 2.0
		B.burst(get_parent(), c.global_position + Vector3(0, 1, 0), Color(0.4, 1, 0.6), 20, 5.0, 0.2)


func _construct() -> void:
	if not GameState.has_power("construct"):
		_toast("Ecto Constructs unlock at Ghost Mastery Lv 2.", Color(0.8, 1, 0.9))
		return
	if not cooldown_ready("construct") or energy < 20.0:
		return
	energy -= 20.0
	_start_cd("construct", 2.5)
	var mat := B.glow(Color(0.3, 1.0, 0.5), 1.5, 0.55)
	var node: Node3D
	var world := get_parent()
	if flying:
		# A floating ecto platform to stand on.
		node = B.box(world, Vector3(4, 0.3, 4), Vector3.ZERO, mat, B.L_WORLD)
		node.global_position = global_position + Vector3(0, -0.4, 0)
		_land()
	else:
		# A protective ecto wall in front of you.
		var fwd := -_cam_basis().z
		node = B.box(world, Vector3(4.5, 3.2, 0.4), Vector3.ZERO, mat, B.L_WORLD)
		node.global_position = global_position + fwd * 3.0 + Vector3(0, 1.6, 0)
		node.rotation.y = _yaw
	B.burst(world, node.global_position, Color(0.4, 1.0, 0.6), 24, 4.0, 0.25)
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(node):
			B.burst(world, node.global_position, Color(0.4, 1.0, 0.6), 16, 3.0, 0.2)
			node.queue_free())


func _overshadow() -> void:
	if overshadowing:
		end_overshadow()
		return
	if not GameState.has_power("overshadow"):
		_toast("Overshadowing unlocks at Ghost Mastery Lv 3.", Color(0.8, 1, 0.9))
		return
	if energy < 20.0:
		return
	var best: Node3D = null
	var best_d := 5.0
	for p in get_tree().get_nodes_in_group("pedestrians"):
		var d: float = p.global_position.distance_to(global_position)
		if d < best_d and p.has_method("possess"):
			best = p
			best_d = d
	if best == null:
		_toast("Get closer to a civilian to overshadow them.", Color(0.8, 1, 0.9))
		return
	energy -= 20.0
	set_shield(false)
	set_phase(false, true)
	set_invisible(false)
	if flying:
		_land()
	overshadowing = best
	overshadow_time = 25.0
	global_position = best.global_position
	best.possess(self)
	model.visible = false
	_toast("Overshadowing a civilian. Ghosts and hunters can't spot you. [T] to leave.", Color(0.7, 1, 0.8))


func end_overshadow() -> void:
	if overshadowing == null:
		return
	if is_instance_valid(overshadowing):
		overshadowing.release()
	overshadowing = null
	model.visible = true
	B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.4, 1, 0.6), 20, 4.0, 0.2)


# --- Fenton Thermos --------------------------------------------------------
func _find_thermos_target() -> Node3D:
	var best: Node3D = null
	var best_d := 16.0
	for e in get_tree().get_nodes_in_group("capturable"):
		if not e.has_method("is_capturable") or not e.is_capturable():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best = e
			best_d = d
	return best


func _update_thermos(delta: float) -> void:
	var holding: bool = Input.is_action_pressed("interact") and not (game and game.input_blocked())
	if holding and thermos_target == null:
		thermos_target = _find_thermos_target()
		thermos_progress = 0.0
	if not holding or thermos_target == null or not is_instance_valid(thermos_target) or not thermos_target.is_capturable():
		thermos_target = null
		thermos_progress = 0.0
		beam.visible = false
		return
	var need: float = thermos_target.capture_time() if thermos_target.has_method("capture_time") else 1.2
	thermos_progress += delta / need
	var a: Vector3 = model.hand_position()
	var b: Vector3 = thermos_target.global_position + Vector3(0, 0.8, 0)
	var len := a.distance_to(b)
	beam.visible = true
	beam.global_position = (a + b) * 0.5
	if len > 0.01:
		beam.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
		beam.rotate_object_local(Vector3.RIGHT, -PI / 2)
	beam.scale = Vector3(1, len, 1)
	thermos_target.pull_toward(a, thermos_progress, delta)
	if thermos_progress >= 1.0:
		var t := thermos_target
		thermos_target = null
		beam.visible = false
		B.burst(get_parent(), a, Color(0.6, 0.85, 1.0), 30, 4.0, 0.2)
		t.captured()


# --- Damage --------------------------------------------------------------
func take_damage(amount: float, from := Vector3.ZERO, effect := "") -> void:
	if dead or invuln > 0.0 or phasing:
		return
	if shielded:
		energy -= amount * 0.6
		B.burst(get_parent(), global_position + Vector3(0, 1, 0) + (from - global_position).normalized() * 1.2, Color(0.5, 1.0, 0.7), 10, 4.0, 0.2)
		if energy <= 0.0:
			energy = 0.0
			set_shield(false)
			_toast("Shield broke!")
		return
	if GameState.has_tech("deflector"):
		amount *= 0.75
	health -= amount
	since_damage = 0.0
	shake = maxf(shake, 0.25 + amount * 0.01)
	if invisible:
		set_invisible(false)
	if overshadowing:
		end_overshadow()
	match effect:
		"net":
			net_time = 2.5
			_toast("Netted! Flight disabled for a moment.", Color(1, 0.8, 0.5))
		"goo":
			slow_time = 2.0
		"explode":
			velocity += (global_position - from).normalized() * 12.0 + Vector3(0, 5, 0)
	if game:
		game.on_player_damaged(amount)
	if health <= 0.0:
		health = 0.0
		_die()


func heal(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)


func _die() -> void:
	dead = true
	end_overshadow()
	set_shield(false)
	set_phase(false, true)
	set_invisible(false)
	beam.visible = false
	B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.4, 1.0, 0.5), 60, 8.0, 0.3)
	model.visible = false
	if game:
		game.on_player_died()


func revive(pos: Vector3) -> void:
	dead = false
	health = MAX_HEALTH
	energy = MAX_ENERGY
	flying = false
	model.visible = true
	model.set_form(false, true)
	ghost = false
	teleport(pos)
	invuln = 2.0


# --- Resources & presentation --------------------------------------------
func _update_resources(delta: float) -> void:
	var drain := 0.0
	if shielded:
		drain += 6.0
	if phasing:
		drain += 3.0
	if invisible:
		drain += 5.0
	if drain > 0.0:
		energy -= drain * delta
		if energy <= 0.0:
			energy = 0.0
			set_shield(false)
			set_invisible(false)
			set_phase(false)
	elif drained <= 0.0:
		var regen := 10.0 if ghost else 16.0
		if GameState.has_tech("booster"):
			regen *= 1.5
		energy = minf(MAX_ENERGY, energy + regen * delta)
	if since_damage > 6.0 and health < MAX_HEALTH:
		health = minf(MAX_HEALTH, health + 5.0 * delta)


func _process(delta: float) -> void:
	if cam_pivot == null:
		return
	# Camera follow with smoothing; over-the-shoulder when aiming.
	var target := global_position + Vector3(0, 1.6, 0)
	var follow := 1.0 - exp(-(18.0 if flying else 14.0) * delta)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, follow)
	cam_pivot.rotation.y = _yaw
	cam_pitch.rotation.x = _pitch
	var want_len := 5.0
	var want_x := 0.55
	if aiming:
		want_len = 2.6
		want_x = 0.9
	elif cinematic:
		want_len = 3.2
		want_x = 0.0
	elif flying:
		want_len = 6.0
	spring.spring_length = lerpf(spring.spring_length, want_len, delta * 6.0)
	spring.position.x = lerpf(spring.position.x, want_x, delta * 6.0)
	var spd := velocity.length()
	var base_fov: float = GameState.settings.get("fov", 75.0)
	var fov_target := base_fov + clampf((spd - 15.0) / 30.0, 0.0, 1.0) * 20.0
	if aiming:
		fov_target -= 15.0
	camera.fov = lerpf(camera.fov, fov_target, delta * 4.0)
	speed_lines.emitting = flying and spd > 26.0
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.0)
		camera.h_offset = randf_range(-1, 1) * shake * 0.25
		camera.v_offset = randf_range(-1, 1) * shake * 0.25
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _update_model(delta: float, move_dir: Vector3) -> void:
	var spd := velocity.length()
	if flying:
		model.anim_state = "fly" if spd > 4.0 else "hover"
		model.speed_ratio = clampf(spd / FLY_SPEED, 0.0, 1.0)
	elif is_on_floor():
		var hs := Vector2(velocity.x, velocity.z).length()
		model.anim_state = "run" if hs > 7.5 else ("walk" if hs > 0.6 else "idle")
		model.speed_ratio = clampf(hs / SPRINT_SPEED, 0.0, 1.0)
	else:
		model.anim_state = "fall"
	model.aim_arm = lerpf(model.aim_arm, 1.0 if (aim_timer > 0.0 or aiming) else 0.0, clampf(delta * 12.0, 0.0, 1.0))
	var face_dir := move_dir
	if aim_timer > 0.0 or aiming:
		face_dir = -_cam_basis().z
	if face_dir.length() > 0.1:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	if shielded:
		shield_mesh.rotation.y += delta
