extends RefCounted
## Static helpers for building procedural geometry, toon materials and effects.
## Everything in the game is generated from primitives, so the project has no
## binary asset dependencies.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const PORTAL_SHADER := preload("res://shaders/portal.gdshader")

# Physics layer bits.
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_PHASE := 8      # walls Danny can phase through
const L_NPC := 16
const L_TRIGGER := 32

static var _cache := {}


static func toon(color: Color, emission := 0.0, outline := 0.0) -> StandardMaterial3D:
	var key := "toon_%s_%s_%s" % [color.to_html(), emission, outline]
	if _cache.has(key):
		return _cache[key]
	var m := toon_unique(color, emission, outline)
	_cache[key] = m
	return m


## A material instance that can be safely modified (alpha, colors) at runtime.
static func toon_unique(color: Color, emission := 0.0, outline := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if outline > 0.0:
		m.next_pass = outline_mat(outline, false)
	return m


static func outline_mat(width: float, box_mode: bool) -> ShaderMaterial:
	var key := "outline_%s_%s" % [width, box_mode]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("thickness", width)
	m.set_shader_parameter("box_mode", box_mode)
	_cache[key] = m
	return m


static func glow(color: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "glow_%s_%s_%s" % [color.to_html(), energy, alpha]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func glow_unique(color: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = glow(color, energy, alpha).duplicate()
	return m


static func building_mat(color: Color, windows := true, spacing := Vector2(3.0, 3.6), outline := 0.06) -> ShaderMaterial:
	var key := "bld_%s_%s_%s_%s" % [color.to_html(), windows, spacing, outline]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = BUILDING_SHADER
	m.set_shader_parameter("wall_color", color)
	m.set_shader_parameter("trim_color", color.darkened(0.35))
	m.set_shader_parameter("windows", windows)
	m.set_shader_parameter("window_spacing", spacing)
	if outline > 0.0:
		m.next_pass = outline_mat(outline, true)
	_cache[key] = m
	return m


static func portal_mat(a := Color(0.2, 1.0, 0.45), b := Color(0.05, 0.35, 0.15), speed := 1.5) -> ShaderMaterial:
	var key := "portal_%s_%s_%s" % [a.to_html(), b.to_html(), speed]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = PORTAL_SHADER
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("speed", speed)
	_cache[key] = m
	return m


# --- Geometry ------------------------------------------------------------
## Adds a box. With a collision layer the box is a StaticBody3D (returned);
## otherwise a bare MeshInstance3D is returned.
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, layer := L_WORLD, rot := Vector3.ZERO) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if layer == 0:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	body.rotation = rot
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, layer := L_WORLD, top_radius := -1.0, segments := 24) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if layer == 0:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	if top_radius < 0.0 or is_equal_approx(top_radius, radius):
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
	else:
		cs.shape = mesh.create_convex_shape()
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func sphere(parent: Node, radius: float, pos: Vector3, mat: Material, layer := 0, segments := 16) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	if layer == 0:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func mesh_instance(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 10
	return mesh_instance(parent, mesh, pos, mat)


static func label(parent: Node, text: String, pos: Vector3, font_size := 96, color := Color.WHITE, billboard := false, pixel := 0.02) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = maxi(font_size / 6, 4)
	l.outline_modulate = Color(0.02, 0.02, 0.03)
	l.modulate = color
	l.pixel_size = pixel
	l.position = pos
	l.double_sided = true
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = false
	parent.add_child(l)
	return l


## Trigger volume (Area3D) that detects the player body.
static func trigger(parent: Node, pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	a.collision_layer = L_TRIGGER
	a.collision_mask = L_PLAYER
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)
	parent.add_child(a)
	return a


# --- Effects -------------------------------------------------------------
static func particles(parent: Node, color: Color, amount := 24, lifetime := 0.8, one_shot := false, speed := 3.0, size := 0.12, spread := 180.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var orb := SphereMesh.new()
	orb.radius = size * 0.5
	orb.height = size
	orb.radial_segments = 6
	orb.rings = 3
	p.mesh = orb
	var bm := _particle_mat(color)
	p.material_override = bm
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	if one_shot:
		p.emitting = true
		p.finished.connect(p.queue_free)
	return p


static func _particle_mat(color: Color) -> StandardMaterial3D:
	var key := "pmat_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.85)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	_cache[key] = m
	return m


static func burst(world: Node, pos: Vector3, color: Color, amount := 30, speed := 8.0, size := 0.25) -> void:
	var p := particles(world, color, amount, 0.7, true, speed, size)
	p.global_position = pos


## Expanding translucent sphere used for explosions and the Ghostly Wail.
static func shockwave(world: Node, pos: Vector3, color: Color, radius := 6.0, time := 0.5) -> void:
	var s := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	s.mesh = mesh
	var m := glow_unique(color, 2.5, 0.5)
	s.material_override = m
	world.add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.2
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * radius, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(s.queue_free)


## Floating text that rises and fades (damage numbers, shouts).
static func popup(world: Node, pos: Vector3, text: String, color := Color.WHITE, size := 64) -> void:
	var l := label(world, text, Vector3.ZERO, size, color, true, 0.01)
	l.global_position = pos
	l.no_depth_test = true
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.6, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
