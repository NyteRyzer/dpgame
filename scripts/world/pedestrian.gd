extends CharacterBody3D
## Amity Park civilian: walks the sidewalks, flees ghosts, recognises the
## hero's ghost form, can be overshadowed or hypnotised by Ember's music.

const B := preload("res://scripts/util/builder.gd")
const Humanoid := preload("res://scripts/util/humanoid.gd")

var route: Array = []   # sidewalk loop (Vector3 points)
var rng := RandomNumberGenerator.new()
var state := "walk"
var speed := 1.8
var game: Node = null
var hypno_target := Vector3.ZERO
var parts: Dictionary
var bubble: Label3D
var _idx := 0
var _t := 0.0
var _bubble_t := 0.0
var _react_cd := 0.0
var _daze := 0.0
var _possessor: Node3D = null
var _think_t := 0.0
var _threat: Node3D = null
var _eye_glow: Material


func _ready() -> void:
	add_to_group("pedestrians")
	collision_layer = B.L_NPC
	collision_mask = B.L_WORLD | B.L_PHASE
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	parts = Humanoid.build(self, Humanoid.random_colors(rng), rng.randf_range(0.9, 1.08))
	bubble = B.label(self, "", Vector3(0, 2.25, 0), 40, Color.WHITE, true, 0.01)
	speed = rng.randf_range(1.5, 2.3)
	_idx = rng.randi() % maxi(route.size(), 1)
	_t = rng.randf() * 10.0
	_eye_glow = B.glow(Color(0.3, 1.0, 0.4), 4.0)


func _say(text: String, t := 2.0) -> void:
	bubble.text = text
	_bubble_t = t


func possess(by: Node3D) -> void:
	state = "possessed"
	_possessor = by
	collision_layer = 0
	for e in parts["eyes"]:
		e.material_override = _eye_glow
	_say("...", 1.0)


func release() -> void:
	state = "dazed"
	_daze = 3.0
	_possessor = null
	collision_layer = B.L_NPC
	for e in parts["eyes"]:
		e.material_override = B.toon(Color(0.05, 0.05, 0.08))
	_say("Huh? Where am I?", 2.5)


func hypnotize(target: Vector3) -> void:
	if state == "possessed":
		return
	state = "hypno"
	hypno_target = target
	for e in parts["eyes"]:
		e.material_override = B.glow(Color(0.7, 0.3, 1.0), 4.0)


func wake() -> void:
	if state != "hypno":
		return
	state = "walk"
	for e in parts["eyes"]:
		e.material_override = B.toon(Color(0.05, 0.05, 0.08))
	_say("What was I doing?", 2.0)


func is_witness() -> bool:
	return state == "walk" or state == "flee" or state == "dazed"


func _physics_process(delta: float) -> void:
	_t += delta
	_react_cd -= delta
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			bubble.text = ""
	if state == "possessed":
		if not is_instance_valid(_possessor):
			release()
			return
		global_position = _possessor.global_position
		rotation.y = _possessor.model.rotation.y
		var hs := Vector2(_possessor.velocity.x, _possessor.velocity.z).length()
		Humanoid.animate(parts, _t * 9.0, clampf(hs / 5.0, 0.0, 1.0))
		return
	var player: Node3D = game.player if game else null
	var pd := 9999.0
	if player:
		pd = player.global_position.distance_to(global_position)
	# Far-away civilians idle to save CPU.
	if pd > 170.0:
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.4 + rng.randf() * 0.3
		_threat = _nearest_threat()
		if _threat and state != "hypno":
			if state != "flee":
				_say(["AAAH! GHOST!", "Run!", "Not again!", "Help!"][rng.randi() % 4], 1.5)
			state = "flee"
		elif state == "flee":
			state = "walk"
		if state == "walk" and player and pd < 11.0 and player.ghost and not player.is_hidden() and _react_cd <= 0.0:
			_react_cd = 12.0
			var n: String = GameState.look.get("name", "Phantom")
			_say(["It's %s!" % n, "Whoa, %s!" % n, "Go get 'em, %s!" % n, "Is that... a ghost kid?"][rng.randi() % 4], 2.5)
	var dir := Vector3.ZERO
	var spd := speed
	var wave := false
	match state:
		"flee":
			if is_instance_valid(_threat):
				dir = global_position - _threat.global_position
				dir.y = 0
				spd = 6.5
		"hypno":
			dir = hypno_target - global_position
			dir.y = 0
			if dir.length() < 4.0:
				dir = Vector3.ZERO
			spd = 1.2
		"dazed":
			_daze -= delta
			if _daze <= 0.0:
				state = "walk"
		_:
			if route.size() > 1:
				var tgt: Vector3 = route[_idx]
				dir = tgt - global_position
				dir.y = 0
				if dir.length() < 1.0:
					_idx = (_idx + 1) % route.size()
			if player and pd < 11.0 and player.ghost and not player.is_hidden() and _react_cd > 8.0:
				# Stop and wave at the hero for a moment.
				var to: Vector3 = player.global_position - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), delta * 6.0)
				dir = Vector3.ZERO
				wave = true
	var v := dir.normalized() * spd if dir.length() > 0.1 else Vector3.ZERO
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if v.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), clampf(delta * 8.0, 0.0, 1.0))
	Humanoid.animate(parts, _t * (6.0 + spd * 1.5), clampf(v.length() / 3.0, 0.0, 1.0), wave)


func _nearest_threat() -> Node3D:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and e.is_alive() and e.kind != "giw" and e.global_position.distance_to(global_position) < 22.0:
			return e
	return null
