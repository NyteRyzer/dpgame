extends Area3D
## Dimensional portal (the Fenton Portal, Ghost Zone doors and temporary rifts)
## that moves the player between Amity Park and the Ghost Zone.

const B := preload("res://scripts/util/builder.gd")

var target_realm := "ghost_zone"
var target_spot := "portal"
var label_text := "FENTON PORTAL"
var radius := 3.0
var game: Node = null
var style := "fenton"   # "fenton", "door", "rift"
var _visual: Node3D
var _t := 0.0


func _ready() -> void:
	collision_layer = B.L_TRIGGER
	collision_mask = B.L_PLAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius * 0.8
	s.height = 1.4
	cs.shape = s
	cs.rotation.x = PI / 2
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	disc.mesh = q
	_visual.add_child(disc)
	match style:
		"door":
			disc.material_override = B.portal_mat(Color(0.75, 0.4, 1.0), Color(0.15, 0.05, 0.3), 1.0)
			B.box(_visual, Vector3(radius * 2.2, 0.4, 0.5), Vector3(0, radius * 1.05, 0), B.toon(Color(0.35, 0.15, 0.5), 0.3, 0.04), 0)
			B.box(_visual, Vector3(radius * 2.2, 0.4, 0.5), Vector3(0, -radius * 1.05, 0), B.toon(Color(0.35, 0.15, 0.5), 0.3, 0.04), 0)
			for side in [-1.0, 1.0]:
				B.box(_visual, Vector3(0.4, radius * 2.2, 0.5), Vector3(radius * 1.05 * side, 0, 0), B.toon(Color(0.35, 0.15, 0.5), 0.3, 0.04), 0)
		_:
			disc.material_override = B.portal_mat()
			var frame := B.torus(_visual, radius * 0.95, radius * 1.18, Vector3.ZERO, B.toon(Color(0.55, 0.6, 0.62), 0.0, 0.03))
			frame.rotation.x = PI / 2
			for i in 8:
				var a := i * TAU / 8.0
				B.box(_visual, Vector3(0.5, 0.5, 0.6), Vector3(cos(a), sin(a), 0) * radius * 1.1, B.glow(Color(0.3, 1.0, 0.45), 2.0), 0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.5) if style != "door" else Color(0.7, 0.4, 1.0)
	light.omni_range = radius * 5.0
	light.light_energy = 1.5
	light.position = Vector3(0, 0, -1)
	add_child(light)
	if label_text != "":
		B.label(self, label_text, Vector3(0, radius * 1.5, 0), 64, Color(0.7, 1.0, 0.8), true, 0.015)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if body.is_in_group("player") and game:
		game.travel(target_realm, target_spot)


func _process(delta: float) -> void:
	_t += delta
	_visual.scale = Vector3.ONE * (1.0 + sin(_t * 2.0) * 0.02)
