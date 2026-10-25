extends Node3D
## Procedural, customizable hero model with a human form and a ghost form.
## Handles limb animation, the two-ring transformation sequence, and
## translucency for intangibility/invisibility. The model faces -Z.

const B := preload("res://scripts/util/builder.gd")

const WAIST := 0.95
const HUMAN_LOOK := {
	"shirt": Color(0.95, 0.95, 0.93),
	"jeans": Color(0.18, 0.28, 0.55),
	"shoes": Color(0.8, 0.12, 0.12),
	"red": Color(0.85, 0.12, 0.12),
	"hair": Color(0.07, 0.06, 0.08),
	"eyes": Color(0.25, 0.45, 0.85),
}
const SKIN := Color(0.96, 0.8, 0.68)

var ghost := false
var anim_state := "idle"
var speed_ratio := 0.0
var aim_arm := 0.0  # 0..1 blend of the right arm pointing forward
var tail_mode := false
var transforming := false
var _look: Dictionary = {}
var _t := 0.0
var _alpha := 1.0

var rig: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var legs_root: Node3D
var tail: MeshInstance3D
var hair_ghost: Node3D
var hair_human: Node3D
var emblem_root: Node3D
var aura: CPUParticles3D
var aura_light: OmniLight3D
var mouth_glow: MeshInstance3D
var _mats := {}
var _parts: Array = []  # {node, h, g, u}


func _ready() -> void:
	_look = GameState.look.duplicate()
	_build()
	_apply_all()


func _build() -> void:
	for key in ["suit", "accent", "shirt", "jeans", "shoes", "red", "skin", "hair_g", "hair_h", "eyes_g", "eyes_h"]:
		_mats[key] = B.toon_unique(Color.WHITE, 0.0, 0.014)
	_mats["skin"].albedo_color = SKIN
	_mats["shirt"].albedo_color = HUMAN_LOOK["shirt"]
	_mats["jeans"].albedo_color = HUMAN_LOOK["jeans"]
	_mats["shoes"].albedo_color = HUMAN_LOOK["shoes"]
	_mats["red"].albedo_color = HUMAN_LOOK["red"]
	_mats["hair_h"].albedo_color = HUMAN_LOOK["hair"]
	_mats["eyes_h"].albedo_color = HUMAN_LOOK["eyes"]
	for key in ["eyes_g", "accent"]:
		_mats[key].emission_enabled = true
	_mats["eyes_g"].emission_energy_multiplier = 4.0
	_mats["accent"].emission_energy_multiplier = 0.25

	rig = Node3D.new()
	rig.position = Vector3(0, 1.0, 0)
	add_child(rig)
	body = Node3D.new()
	body.position = Vector3(0, -1.0, 0)
	rig.add_child(body)

	# Torso, belt, collar, head.
	var torso := _capsule(body, 0.22, 0.72, Vector3(0, 1.17, 0))
	torso.scale = Vector3(1.1, 1.0, 0.8)
	_part(torso, 1.2, "suit", "shirt")
	var belt := B.cylinder(body, 0.215, 0.08, Vector3(0, 0.9, 0), _mats["accent"], 0)
	belt.scale = Vector3(1.05, 1.0, 0.82)
	_part(belt, 0.9, "accent", "jeans")
	var collar := B.torus(body, 0.07, 0.12, Vector3(0, 1.47, 0), _mats["accent"])
	_part(collar, 1.47, "accent", "red")
	var oval := B.sphere(body, 0.09, Vector3(0, 1.26, -0.17), _mats["red"])
	oval.scale = Vector3(1.0, 0.65, 0.25)
	_part(oval, 1.26, false, true)
	var head := B.sphere(body, 0.19, Vector3(0, 1.64, 0), _mats["skin"], 0, 20)
	_part(head, 1.64, "skin", "skin")
	for side in [-1.0, 1.0]:
		var eye := B.sphere(body, 0.038, Vector3(0.072 * side, 1.66, -0.172), _mats["eyes_g"], 0, 10)
		eye.scale = Vector3(1.0, 1.35, 0.5)
		_part(eye, 1.66, "eyes_g", "eyes_h")
	mouth_glow = B.sphere(body, 0.05, Vector3(0, 1.57, -0.18), B.glow(Color(0.5, 1.0, 0.7), 4.0), 0, 8) as MeshInstance3D
	mouth_glow.visible = false

	hair_ghost = Node3D.new()
	body.add_child(hair_ghost)
	hair_human = Node3D.new()
	body.add_child(hair_human)
	_build_hair(hair_human, "Spiky", "hair_h")
	_part(hair_ghost, 1.8, true, false)
	_part(hair_human, 1.8, false, true)

	emblem_root = Node3D.new()
	emblem_root.position = Vector3(0, 1.24, -0.185)
	body.add_child(emblem_root)
	_part(emblem_root, 1.24, true, false)

	# Arms (pivot at shoulders).
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.31 * side, 1.42, 0)
		body.add_child(pivot)
		var sleeve := _capsule(pivot, 0.085, 0.28, Vector3(0, -0.1, 0))
		_part(sleeve, 1.32, "suit", "shirt")
		var arm := _capsule(pivot, 0.07, 0.56, Vector3(0, -0.3, 0))
		_part(arm, 1.12, "suit", "skin")
		var glove := B.sphere(pivot, 0.085, Vector3(0, -0.6, 0), _mats["accent"], 0, 10)
		_part(glove, 0.82, "accent", "skin")
		if side < 0:
			arm_l = pivot
		else:
			arm_r = pivot

	# Legs (pivot at hips) and the ghost tail that replaces them.
	legs_root = Node3D.new()
	body.add_child(legs_root)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.115 * side, 0.86, 0)
		legs_root.add_child(pivot)
		var leg := _capsule(pivot, 0.095, 0.8, Vector3(0, -0.4, 0))
		_part(leg, 0.45, "suit", "jeans")
		var boot := B.box(pivot, Vector3(0.17, 0.13, 0.27), Vector3(0, -0.79, -0.04), _mats["accent"], 0)
		_part(boot, 0.07, "accent", "shoes")
		if side < 0:
			leg_l = pivot
		else:
			leg_r = pivot
	var tmesh := CylinderMesh.new()
	tmesh.top_radius = 0.22
	tmesh.bottom_radius = 0.0
	tmesh.height = 1.1
	tail = B.mesh_instance(body, tmesh, Vector3(0, 0.38, 0.12), _mats["suit"])
	tail.rotation.x = 0.35
	tail.visible = false

	aura = B.particles(rig, Color(0.3, 1.0, 0.5), 36, 1.2, false, 0.6, 0.08)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 0.6
	aura.gravity = Vector3(0, 0.6, 0)
	aura_light = OmniLight3D.new()
	aura_light.omni_range = 3.5
	aura_light.light_energy = 0.7
	aura_light.position = Vector3(0, 0.3, 0)
	rig.add_child(aura_light)


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 14
	m.rings = 6
	return B.mesh_instance(parent, m, pos, _mats["suit"])


func _part(node: Node3D, h: float, g, u) -> void:
	_parts.append({"node": node, "h": h, "g": g, "u": u})


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	m.rings = 1
	var mi := B.mesh_instance(parent, m, pos, mat)
	mi.rotation = rot


func _build_hair(root: Node3D, style: String, mat_key: String) -> void:
	for c in root.get_children():
		c.queue_free()
	var mat: Material = _mats[mat_key]
	var cap := B.sphere(root, 0.205, Vector3(0, 1.69, 0.02), mat, 0, 16)
	match style:
		"Spiky":
			cap.scale = Vector3(1.02, 0.78, 1.05)
			var spikes := [
				[Vector3(0, 1.84, -0.1), Vector3(-0.9, 0, 0)],
				[Vector3(0.1, 1.83, -0.06), Vector3(-0.7, 0, -0.6)],
				[Vector3(-0.1, 1.83, -0.06), Vector3(-0.7, 0, 0.6)],
				[Vector3(0, 1.86, 0.06), Vector3(0.3, 0, 0)],
				[Vector3(0.12, 1.8, 0.1), Vector3(0.6, 0, -0.7)],
				[Vector3(-0.12, 1.8, 0.1), Vector3(0.6, 0, 0.7)],
				[Vector3(0, 1.74, 0.19), Vector3(1.3, 0, 0)],
				[Vector3(0.05, 1.76, -0.17), Vector3(-1.5, 0, -0.2)],
			]
			for s in spikes:
				_cone(root, 0.075, 0.24, s[0], s[1], mat)
		"Swept":
			cap.scale = Vector3(1.04, 0.8, 1.08)
			var sweep := B.sphere(root, 0.16, Vector3(0.06, 1.8, -0.1), mat, 0, 12)
			sweep.scale = Vector3(1.3, 0.45, 1.2)
			sweep.rotation = Vector3(0.3, 0, -0.35)
			_cone(root, 0.09, 0.3, Vector3(0.14, 1.72, -0.14), Vector3(-1.2, 0, -1.0), mat)
			_cone(root, 0.07, 0.26, Vector3(-0.08, 1.76, 0.16), Vector3(1.2, 0, 0.4), mat)
		"Mohawk":
			cap.scale = Vector3(0.9, 0.62, 0.98)
			for i in 5:
				var z := -0.13 + i * 0.07
				_cone(root, 0.06, 0.3 - absf(i - 2) * 0.04, Vector3(0, 1.86, z), Vector3(z * 2.2, 0, 0), mat)
		"Long":
			cap.scale = Vector3(1.06, 0.82, 1.08)
			B.box(root, Vector3(0.38, 0.5, 0.12), Vector3(0, 1.5, 0.15), mat, 0)
			for side in [-1.0, 1.0]:
				B.box(root, Vector3(0.07, 0.36, 0.1), Vector3(0.19 * side, 1.52, -0.04), mat, 0)


func _build_emblem() -> void:
	for c in emblem_root.get_children():
		c.queue_free()
	var accent: Color = GameState.ACCENT_COLORS.get(_look.get("accent", "White"), Color.WHITE)
	match _look.get("emblem", "Initials"):
		"Initials":
			var words: PackedStringArray = String(_look.get("name", "DP")).strip_edges().split(" ", false)
			var initials := ""
			for w in words:
				initials += w.substr(0, 1).to_upper()
			if initials == "":
				initials = "?"
			var l := B.label(emblem_root, initials.substr(0, 2), Vector3.ZERO, 64, accent, false, 0.004)
			l.rotation.y = PI
			l.outline_size = 10
		"Ghost Ring":
			var t := B.torus(emblem_root, 0.05, 0.08, Vector3.ZERO, B.glow(accent, 1.5))
			t.rotation.x = PI / 2


# --- Appearance ----------------------------------------------------------
func apply_look(look: Dictionary) -> void:
	_look = look.duplicate()
	if is_inside_tree() and rig != null:
		_apply_all()


func _apply_all() -> void:
	var suit: Color = GameState.SUIT_COLORS.get(_look.get("suit"), Color(0.07, 0.07, 0.09))
	var accent: Color = GameState.ACCENT_COLORS.get(_look.get("accent"), Color.WHITE)
	var hair: Color = GameState.HAIR_COLORS.get(_look.get("hair"), Color.WHITE)
	var eyes: Color = GameState.EYE_COLORS.get(_look.get("eyes"), Color.GREEN)
	var aura_c: Color = GameState.AURA_COLORS.get(_look.get("aura"), Color.GREEN)
	_mats["suit"].albedo_color = suit
	_mats["accent"].albedo_color = accent
	_mats["accent"].emission = accent
	_mats["hair_g"].albedo_color = hair
	_mats["eyes_g"].albedo_color = eyes
	_mats["eyes_g"].emission = eyes
	_build_hair(hair_ghost, _look.get("hairstyle", "Spiky"), "hair_g")
	_build_emblem()
	aura.color_ramp.set_color(0, Color(aura_c, 0.9))
	aura.color_ramp.set_color(1, Color(aura_c, 0.0))
	aura_light.light_color = aura_c
	tail.material_override = _mats["suit"]
	set_form(ghost, true)


## Instantly switch every part to the given form.
func set_form(to_ghost: bool, force := false) -> void:
	if ghost == to_ghost and not force:
		return
	ghost = to_ghost
	for p in _parts:
		_apply_part(p, to_ghost)
	aura.emitting = to_ghost
	aura_light.visible = to_ghost
	if not to_ghost:
		set_tail(false)


func _apply_part(p: Dictionary, to_ghost: bool) -> void:
	var v = p["g"] if to_ghost else p["u"]
	var node: Node3D = p["node"]
	if typeof(v) == TYPE_BOOL:
		node.visible = v
	else:
		node.visible = true
		(node as MeshInstance3D).material_override = _mats[v]


func set_tail(on: bool) -> void:
	tail_mode = on and ghost
	tail.visible = tail_mode
	legs_root.visible = not tail_mode


## The signature transformation: two glowing rings split from the waist and
## sweep to the head and feet, converting the body as they pass.
func play_transform(to_ghost: bool, duration: float) -> void:
	transforming = true
	var ring_mat := B.glow_unique(Color(0.92, 1.0, 0.95), 4.0, 0.95)
	var rings: Array[MeshInstance3D] = []
	for i in 2:
		var r := B.torus(body, 0.36, 0.46, Vector3(0, WAIST, 0), ring_mat)
		rings.append(r)
	var flash := B.particles(rig, Color(0.4, 1.0, 0.6), 40, 0.6, false, 1.5, 0.12)
	flash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flash.emission_sphere_radius = 0.4
	var done := {}
	var tw := create_tween()
	tw.tween_method(func(p: float) -> void:
		var top := lerpf(WAIST, 2.0, p)
		var bottom := lerpf(WAIST, -0.05, p)
		rings[0].position.y = top
		rings[1].position.y = bottom
		var s := 1.0 + sin(p * PI) * 0.15
		rings[0].scale = Vector3(s, 1, s)
		rings[1].scale = Vector3(s, 1, s)
		for i in _parts.size():
			if done.has(i):
				continue
			var h: float = _parts[i]["h"]
			if (h >= WAIST and top >= h) or (h < WAIST and bottom <= h):
				done[i] = true
				_apply_part(_parts[i], to_ghost)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.2)
	await tw.finished
	for r in rings:
		r.queue_free()
	flash.emitting = false
	get_tree().create_timer(1.0).timeout.connect(flash.queue_free)
	set_form(to_ghost, true)
	var burst := B.particles(rig, Color(0.3, 1.0, 0.45) if to_ghost else Color(0.9, 1.0, 0.95), 60, 0.7, true, 6.0, 0.16)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.3
	transforming = false


func set_alpha(a: float, phase_tint := false) -> void:
	if is_equal_approx(a, _alpha) and not phase_tint:
		return
	_alpha = a
	for key in _mats:
		var m: StandardMaterial3D = _mats[key]
		if a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a
			m.next_pass = null
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = 1.0
			m.next_pass = B.outline_mat(0.014, false)
	for l in emblem_root.get_children():
		if l is Label3D:
			l.modulate.a = a
			l.outline_modulate.a = a
	aura.visible = a > 0.3


# --- Animation -----------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	if _look.get("aura") == "Prismatic" and aura.emitting:
		var c := Color.from_hsv(fmod(_t * 0.25, 1.0), 0.7, 1.0)
		aura.color_ramp.set_color(0, Color(c, 0.9))
		aura_light.light_color = c
	if transforming:
		_pose(arm_l, Vector3(0, 0, -2.4), delta * 6.0)
		_pose(arm_r, Vector3(0, 0, 2.4), delta * 6.0)
		_pose(leg_l, Vector3.ZERO, delta * 6.0)
		_pose(leg_r, Vector3.ZERO, delta * 6.0)
		rig.rotation = rig.rotation.lerp(Vector3.ZERO, delta * 6.0)
		return
	var k := delta * 10.0
	var swing := 0.0
	match anim_state:
		"walk", "run":
			var freq := 9.0 if anim_state == "walk" else 13.0
			var amp := 0.6 if anim_state == "walk" else 0.95
			swing = sin(_t * freq) * amp * clampf(speed_ratio, 0.3, 1.0)
			_pose(leg_l, Vector3(swing, 0, 0), k)
			_pose(leg_r, Vector3(-swing, 0, 0), k)
			_pose(arm_l, Vector3(-swing * 0.8, 0, -0.08), k)
			_pose(arm_r, Vector3(swing * 0.8, 0, 0.08), k)
			rig.position.y = 1.0 + absf(sin(_t * freq)) * 0.05
			rig.rotation = rig.rotation.lerp(Vector3.ZERO, k)
		"fly":
			# Superhero pose: lean into the direction of travel.
			var lean := -1.15 * clampf(speed_ratio, 0.0, 1.0)
			rig.rotation = rig.rotation.lerp(Vector3(lean, 0, 0), delta * 4.0)
			_pose(leg_l, Vector3(0.15, 0, -0.03), k)
			_pose(leg_r, Vector3(0.25, 0, 0.03), k)
			if speed_ratio > 0.75:
				_pose(arm_r, Vector3(3.0, 0, 0.1), k)
				_pose(arm_l, Vector3(0.3, 0, -0.2), k)
			else:
				_pose(arm_l, Vector3(0.2, 0, -0.35), k)
				_pose(arm_r, Vector3(0.2, 0, 0.35), k)
			rig.position.y = 1.0 + sin(_t * 3.0) * 0.04
		"hover", "fall":
			rig.rotation = rig.rotation.lerp(Vector3(-0.08, 0, 0), delta * 4.0)
			var bob := sin(_t * 2.2)
			_pose(leg_l, Vector3(0.12 + bob * 0.08, 0, -0.05), k)
			_pose(leg_r, Vector3(-0.05 - bob * 0.08, 0, 0.05), k)
			_pose(arm_l, Vector3(0.1, 0, -0.4 - bob * 0.05), k)
			_pose(arm_r, Vector3(0.1, 0, 0.4 + bob * 0.05), k)
			rig.position.y = 1.0 + bob * 0.07
		_:
			var breathe := sin(_t * 2.0) * 0.03
			_pose(leg_l, Vector3.ZERO, k)
			_pose(leg_r, Vector3.ZERO, k)
			_pose(arm_l, Vector3(0, 0, -0.1 - breathe), k)
			_pose(arm_r, Vector3(0, 0, 0.1 + breathe), k)
			rig.position.y = 1.0
			rig.rotation = rig.rotation.lerp(Vector3.ZERO, k)
	if aim_arm > 0.01:
		arm_r.rotation = arm_r.rotation.lerp(Vector3(PI / 2, 0, 0), aim_arm)


func _pose(n: Node3D, target: Vector3, w: float) -> void:
	n.rotation = n.rotation.lerp(target, clampf(w, 0.0, 1.0))


func hand_position() -> Vector3:
	return arm_r.to_global(Vector3(0, -0.6, 0))
