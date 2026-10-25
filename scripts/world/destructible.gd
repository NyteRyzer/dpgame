extends StaticBody3D
## Breakable event objects: ghost rifts, Ember's amplifiers, Technus nodes,
## and Guys in White ghost traps.

const B := preload("res://scripts/util/builder.gd")

signal destroyed(node: Node)

var kind := "rift"
var max_health := 150.0
var health := 150.0
var spawn_interval := 7.0
var game: Node = null
var _t := 0.0
var _spawn_t := 3.0
var _visual: Node3D
var _dead := false


func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("event_targets")
	collision_layer = B.L_WORLD
	collision_mask = 0
	health = max_health
	_visual = Node3D.new()
	add_child(_visual)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	cs.shape = shape
	match kind:
		"rift":
			shape.size = Vector3(5, 7, 1.0)
			cs.position.y = 4.0
			var ring := B.torus(_visual, 2.6, 3.2, Vector3(0, 4, 0), B.glow(Color(0.3, 1.0, 0.5), 3.0))
			ring.rotation.x = PI / 2
			var disc := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(5.6, 5.6)
			disc.mesh = q
			disc.material_override = B.portal_mat(Color(0.3, 1.0, 0.5), Color(0.3, 0.05, 0.4), 3.0)
			disc.position = Vector3(0, 4, 0)
			_visual.add_child(disc)
			var p := B.particles(_visual, Color(0.4, 1.0, 0.6), 30, 1.5, false, 2.0, 0.3)
			p.position = Vector3(0, 4, 0)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 3.0
			var light := OmniLight3D.new()
			light.light_color = Color(0.3, 1.0, 0.5)
			light.omni_range = 18.0
			light.light_energy = 2.0
			light.position = Vector3(0, 4, 0)
			_visual.add_child(light)
		"speaker":
			shape.size = Vector3(2.2, 3.2, 1.6)
			cs.position.y = 1.6
			B.box(_visual, Vector3(2.2, 3.2, 1.6), Vector3(0, 1.6, 0), B.toon(Color(0.12, 0.12, 0.15), 0.0, 0.04), 0)
			for y in [0.9, 2.3]:
				var cone := B.cylinder(_visual, 0.55, 0.1, Vector3(0, y, -0.82), B.glow(Color(0.7, 0.3, 1.0), 2.5), 0)
				cone.rotation.x = PI / 2
		"node":
			shape.size = Vector3(2.0, 4.0, 2.0)
			cs.position.y = 2.0
			B.box(_visual, Vector3(2.0, 4.0, 2.0), Vector3(0, 2.0, 0), B.toon(Color(0.3, 0.32, 0.36), 0.0, 0.04), 0)
			B.sphere(_visual, 0.7, Vector3(0, 4.6, 0), B.glow(Color(0.3, 1.0, 0.4), 3.0))
		"trap":
			shape.size = Vector3(2.4, 1.0, 2.4)
			cs.position.y = 0.5
			B.cylinder(_visual, 1.2, 0.6, Vector3(0, 0.3, 0), B.toon(Color(0.9, 0.92, 0.95), 0.0, 0.03), 0)
			var ring := B.torus(_visual, 1.0, 1.25, Vector3(0, 0.65, 0), B.glow(Color(0.4, 0.8, 1.0), 3.0))
			ring.rotation.y = 0.0
	add_child(cs)


func take_damage(amount: float, _from := Vector3.ZERO, _effect := "") -> void:
	if _dead:
		return
	health -= amount
	B.popup(get_parent(), global_position + Vector3(0, 5.0 if kind == "rift" else 3.0, 0), str(int(amount)), Color(1, 1, 0.6), 48)
	if health <= 0.0:
		_dead = true
		B.burst(get_parent(), global_position + Vector3(0, 3, 0), Color(0.4, 1.0, 0.6), 60, 12.0, 0.4)
		B.shockwave(get_parent(), global_position + Vector3(0, 3, 0), Color(0.5, 1.0, 0.7), 8.0, 0.5)
		GameState.add_xp(25)
		destroyed.emit(self)
		queue_free()


func health_ratio() -> float:
	return health / max_health


func _process(delta: float) -> void:
	_t += delta
	if kind == "rift":
		_visual.rotation.y = sin(_t * 0.5) * 0.3
		_spawn_t -= delta
		if _spawn_t <= 0.0 and game:
			_spawn_t = spawn_interval
			if get_tree().get_nodes_in_group("enemies").size() < 14:
				game.spawn_enemy("minion", global_position + Vector3(randf_range(-3, 3), 4, randf_range(-3, 3)), get_parent())
	elif kind == "speaker":
		_visual.scale = Vector3.ONE * (1.0 + absf(sin(_t * 8.0)) * 0.04)
