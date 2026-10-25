extends Area3D
## Collectible ectoplasmic artifact hidden on rooftops and floating islands.

const B := preload("res://scripts/util/builder.gd")

var artifact_id := ""
var _t := 0.0
var _gem: Node3D


func _ready() -> void:
	add_to_group("artifacts")
	collision_layer = B.L_TRIGGER
	collision_mask = B.L_PLAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.6
	cs.shape = s
	cs.position.y = 1.2
	add_child(cs)
	var m := PrismMesh.new()
	m.size = Vector3(0.6, 0.9, 0.6)
	_gem = B.mesh_instance(self, m, Vector3(0, 1.4, 0), B.glow(Color(0.35, 1.0, 0.55), 3.0))
	var low := B.mesh_instance(_gem, m, Vector3(0, -0.9, 0), B.glow(Color(0.35, 1.0, 0.55), 3.0))
	low.rotation.z = PI
	var p := B.particles(self, Color(0.4, 1.0, 0.6), 10, 1.4, false, 0.6, 0.15)
	p.position.y = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.collect_artifact(artifact_id)
		B.burst(get_parent(), global_position + Vector3(0, 1.4, 0), Color(0.4, 1.0, 0.6), 40, 6.0, 0.25)
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	_gem.rotation.y = _t * 1.5
	_gem.position.y = 1.4 + sin(_t * 2.0) * 0.2
