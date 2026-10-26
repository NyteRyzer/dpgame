extends Area3D
## Generic projectile: ecto blasts, ice shots, rockets, meat, boxes, nets.
## Damage is dealt to anything with take_damage(amount, from, effect).

const B := preload("res://scripts/util/builder.gd")

var velocity := Vector3.ZERO
var damage := 10.0
var team := "player"      # "player" or "enemy"
var effect := ""          # "", "ice", "net", "explode", "goo"
var homing: Node3D = null
var homing_strength := 0.0
var lifetime := 3.0
var radius := 0.25
var color := Color(0.3, 1.0, 0.5)
var drop := 0.0
var shooter: Node = null
var splash := 0.0          # >0: area damage radius on impact
var _dead := false
var _exclude: Array[RID] = []


static func spawn(world: Node, from: Vector3, dir: Vector3, opts: Dictionary) -> Area3D:
	var p: Area3D = load("res://scripts/combat/projectile.gd").new()
	for k in opts:
		p.set(k, opts[k])
	p.velocity = dir.normalized() * float(opts.get("speed", 40.0))
	world.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	monitorable = false
	collision_layer = 0
	if team == "player":
		collision_mask = B.L_WORLD | B.L_ENEMY | B.L_PHASE
	else:
		collision_mask = B.L_WORLD | B.L_PLAYER | B.L_PHASE
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	_build_visual()
	body_entered.connect(_on_body)
	if shooter is CollisionObject3D:
		_exclude.append(shooter.get_rid())


func _build_visual() -> void:
	match effect:
		"explode":
			# Rocket: body + exhaust.
			var r := B.cylinder(self, 0.12, 0.7, Vector3.ZERO, B.toon(Color(0.35, 0.38, 0.4), 0.0, 0.01), 0)
			r.rotation.x = PI / 2
			B.sphere(self, 0.14, Vector3(0, 0, 0.4), B.glow(Color(1.0, 0.6, 0.2), 4.0))
			var trail := B.particles(self, Color(1.0, 0.55, 0.2), 20, 0.4, false, 1.0, 0.25)
			trail.position = Vector3(0, 0, 0.4)
		"box":
			B.box(self, Vector3.ONE * radius * 1.6, Vector3.ZERO, B.toon(Color(0.65, 0.48, 0.28), 0.0, 0.02), 0)
		"meat":
			B.sphere(self, radius, Vector3.ZERO, B.toon(Color(0.6, 0.2, 0.15), 0.3, 0.02))
		"net":
			var n := B.torus(self, radius * 0.6, radius, Vector3.ZERO, B.glow(Color(0.7, 0.8, 0.9), 1.5))
			n.rotation.x = PI / 2
		_:
			B.sphere(self, radius, Vector3.ZERO, B.glow(color, 4.0), 0, 10)
			B.sphere(self, radius * 1.8, Vector3.ZERO, B.glow(color, 1.5, 0.35), 0, 10)
			var t := B.particles(self, color, 12, 0.25, false, 0.4, radius * 1.2)
			t.local_coords = false


func _physics_process(delta: float) -> void:
	if _dead:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
		return
	if is_instance_valid(homing) and homing_strength > 0.0:
		var to := (homing.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
		var spd := velocity.length()
		velocity = velocity.normalized().slerp(to, clampf(homing_strength * delta, 0.0, 1.0)) * spd
	velocity.y -= drop * delta
	# Ray-cast the step so fast shots can't tunnel through thin walls.
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"]
		_on_body(hit["collider"])
		if _dead:
			return
		_exclude.append(hit["rid"])
	global_position = to
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _on_body(body: Node) -> void:
	if _dead or body == shooter:
		return
	if body.has_method("is_intangible") and body.is_intangible():
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, effect)
		if team == "player" and body.is_in_group("enemies"):
			var killed: bool = body.has_method("is_alive") and not body.is_alive()
			get_tree().call_group("hud", "hit_marker", killed)
	elif effect == "ice":
		_spawn_ice_crystal()
	_impact()


func _spawn_ice_crystal() -> void:
	# Cryokinesis builds temporary ice structures where it hits the world.
	var world := get_parent()
	var ice := B.box(world, Vector3(2.2, 2.6, 2.2), Vector3.ZERO, B.toon(Color(0.7, 0.9, 1.0, 1.0), 0.4, 0.03), B.L_WORLD, Vector3(0, randf() * TAU, 0.2))
	ice.global_position = global_position
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(ice):
			ice.queue_free())


func _impact() -> void:
	_dead = true
	var world := get_parent()
	if effect == "explode":
		B.burst(world, global_position, Color(1.0, 0.55, 0.2), 40, 10.0, 0.4)
		B.shockwave(world, global_position, Color(1.0, 0.6, 0.2), 4.0, 0.35)
		# Splash damage.
		for n in get_tree().get_nodes_in_group("player_targets" if team == "enemy" else "enemies"):
			if n is Node3D and n.global_position.distance_to(global_position) < 4.0 and n.has_method("take_damage"):
				n.take_damage(damage * 0.5, global_position, "")
	else:
		B.burst(world, global_position, color if effect == "" else Color(0.8, 0.9, 1.0), 14, 5.0, 0.18)
	if splash > 0.0:
		B.shockwave(world, global_position, color, splash, 0.4)
		B.burst(world, global_position, color, 40, splash * 3.0, 0.3)
		for n in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("destructibles"):
			if n is Node3D and n.is_inside_tree() and n.has_method("take_damage") and n.global_position.distance_to(global_position) < splash:
				n.take_damage(damage * 0.5, global_position, "")
	queue_free()


func _expire() -> void:
	_dead = true
	queue_free()
