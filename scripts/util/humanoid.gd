extends RefCounted
## Lightweight stylised humanoid used for civilians and story NPCs.

const B := preload("res://scripts/util/builder.gd")

const SKIN_TONES := [Color(0.98, 0.84, 0.72), Color(0.9, 0.72, 0.56), Color(0.72, 0.5, 0.34), Color(0.5, 0.33, 0.22), Color(0.36, 0.24, 0.16)]
const SHIRTS := [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.95, 0.8, 0.2), Color(0.3, 0.7, 0.35), Color(0.6, 0.3, 0.7), Color(0.95, 0.55, 0.2), Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.25)]
const PANTS := [Color(0.2, 0.25, 0.45), Color(0.15, 0.15, 0.18), Color(0.45, 0.35, 0.25), Color(0.35, 0.38, 0.42)]
const HAIRS := [Color(0.08, 0.06, 0.05), Color(0.35, 0.2, 0.1), Color(0.85, 0.7, 0.35), Color(0.6, 0.25, 0.12), Color(0.6, 0.6, 0.62)]


static func random_colors(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()],
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()],
		"pants": PANTS[rng.randi() % PANTS.size()],
		"hair": HAIRS[rng.randi() % HAIRS.size()],
		"shoes": Color(0.12, 0.12, 0.14),
	}


## Builds the figure under `parent` (feet at y=0, facing -Z) and returns
## handles to the animated parts.
static func build(parent: Node3D, c: Dictionary, height := 1.0) -> Dictionary:
	var root := Node3D.new()
	root.scale = Vector3.ONE * height
	parent.add_child(root)
	var skin := B.toon(c.get("skin", SKIN_TONES[0]), 0.0, 0.015)
	var shirt := B.toon(c.get("shirt", SHIRTS[0]), 0.0, 0.015)
	var pants := B.toon(c.get("pants", PANTS[0]), 0.0, 0.015)
	var hair := B.toon(c.get("hair", HAIRS[0]), 0.0, 0.015)
	var shoes := B.toon(c.get("shoes", Color(0.12, 0.12, 0.14)), 0.0, 0.015)
	var torso := _capsule(root, 0.21, 0.7, Vector3(0, 1.15, 0), shirt)
	torso.scale = Vector3(1.1, 1.0, 0.8)
	B.sphere(root, 0.18, Vector3(0, 1.62, 0), skin, 0, 16)
	var cap := B.sphere(root, 0.19, Vector3(0, 1.68, 0.03), hair, 0, 14)
	cap.scale = Vector3(1.02, 0.72, 1.05)
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		var e := B.sphere(root, 0.03, Vector3(0.065 * side, 1.64, -0.165), B.toon(Color(0.05, 0.05, 0.08)), 0, 8)
		eyes.append(e)
	var parts := {"root": root, "eyes": eyes}
	for side in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(0.29 * side, 1.4, 0)
		root.add_child(ap)
		_capsule(ap, 0.075, 0.6, Vector3(0, -0.3, 0), shirt if c.get("long_sleeves", false) else skin)
		B.sphere(ap, 0.075, Vector3(0, -0.6, 0), skin, 0, 8)
		var lp := Node3D.new()
		lp.position = Vector3(0.11 * side, 0.85, 0)
		root.add_child(lp)
		_capsule(lp, 0.09, 0.8, Vector3(0, -0.4, 0), pants)
		B.box(lp, Vector3(0.15, 0.1, 0.25), Vector3(0, -0.8, -0.04), shoes, 0)
		parts["arm_l" if side < 0 else "arm_r"] = ap
		parts["leg_l" if side < 0 else "leg_r"] = lp
	return parts


static func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 10
	m.rings = 4
	return B.mesh_instance(parent, m, pos, mat)


static func animate(parts: Dictionary, t: float, moving: float, wave := false) -> void:
	var s := sin(t) * 0.7 * moving
	parts["leg_l"].rotation.x = s
	parts["leg_r"].rotation.x = -s
	parts["arm_l"].rotation.x = -s * 0.8
	if wave:
		parts["arm_r"].rotation = Vector3(0, 0, 2.6 + sin(t * 2.0) * 0.3)
	else:
		parts["arm_r"].rotation = Vector3(s * 0.8, 0, 0)
