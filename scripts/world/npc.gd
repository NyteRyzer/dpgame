extends StaticBody3D
## Friendly story character. Dialogue is supplied by the mission manager so
## NPCs remember what the player has done.

const B := preload("res://scripts/util/builder.gd")
const Humanoid := preload("res://scripts/util/humanoid.gd")

var npc_id := "sam"
var display_name := "Sam"
var colors := {}
var height := 1.0
var game: Node = null
var interact_text := ""
var parts: Dictionary
var _t := 0.0
var _marker: Label3D


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("npcs")
	collision_layer = B.L_NPC
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35 * height
	cap.height = 1.8 * height
	cs.shape = cap
	cs.position.y = 0.9 * height
	add_child(cs)
	parts = Humanoid.build(self, colors, height)
	_decorate()
	B.label(self, display_name, Vector3(0, 2.15 * height, 0), 44, Color(0.85, 1.0, 0.9), true, 0.01)
	_marker = B.label(self, "!", Vector3(0, 2.55 * height, 0), 96, Color(1.0, 0.9, 0.2), true, 0.012)
	_marker.visible = false
	interact_text = "Talk to %s" % display_name


func _decorate() -> void:
	var root: Node3D = parts["root"]
	match npc_id:
		"tucker":
			B.cylinder(root, 0.2, 0.08, Vector3(0, 1.8, 0.02), B.toon(Color(0.85, 0.15, 0.15), 0.0, 0.01), 0)
			B.box(root, Vector3(0.32, 0.07, 0.04), Vector3(0, 1.66, -0.18), B.toon(Color(0.1, 0.1, 0.12)), 0)
		"maddie":
			B.box(root, Vector3(0.36, 0.1, 0.06), Vector3(0, 1.68, -0.17), B.glow(Color(0.9, 0.5, 0.2), 1.0), 0)
		"jack":
			B.box(root, Vector3(0.38, 0.1, 0.06), Vector3(0, 1.67, -0.17), B.toon(Color(0.15, 0.15, 0.18)), 0)
		"frostbite":
			for side in [-1.0, 1.0]:
				var horn := B.cylinder(root, 0.06, 0.3, Vector3(0.12 * side, 1.85, 0), B.toon(Color(0.4, 0.7, 1.0), 0.4, 0.01), 0, 0.0)
				horn.rotation.z = -0.4 * side
			var arm := B.box(root, Vector3(0.2, 0.6, 0.2), Vector3(0.38, 1.0, -0.1), B.glow(Color(0.6, 0.9, 1.0), 1.0, 0.7), 0)
			arm.rotation.z = 0.3


func set_marker(on: bool) -> void:
	if _marker:
		_marker.visible = on


func interact(player: Node) -> void:
	if game:
		game.talk_to(self)


func _process(delta: float) -> void:
	_t += delta
	Humanoid.animate(parts, _t * 2.0, 0.0, false)
	if _marker and _marker.visible:
		_marker.position.y = 2.55 * height + sin(_t * 3.0) * 0.1
	if game and game.player:
		var to: Vector3 = game.player.global_position - global_position
		if to.length() < 8.0:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 4.0)
