extends Node3D
## The Ghost Zone: a second open world of floating islands, drifting doors,
## and ghost realms (Far Frozen, Walker's Prison, Skulker's Island, Pariah's
## Keep, Clockwork's tower, Ghost Writer's manor, Aragon's kingdom).

const B := preload("res://scripts/util/builder.gd")

var game: Node = null
var rng := RandomNumberGenerator.new()
var spots := {}
var landmarks: Array = []
var map_rects: Array = []
var map_labels: Array = []
var artifact_spots: Array = []
var enemy_zones: Array = []      # [center, radius, kind]
var door_portals: Array = []     # positions for Amity-bound doors
var gears: Array = []

var _rock: Material
var _top: Material


func build(game_ref: Node) -> void:
	game = game_ref
	rng.seed = 6661
	_rock = B.toon(Color(0.25, 0.15, 0.32), 0.1, 0.06)
	_top = B.toon(Color(0.2, 0.38, 0.36), 0.0, 0.05)
	_hub()
	_islands()
	_far_frozen(Vector3(650, -20, 0))
	_walker_prison(Vector3(-600, 20, 150))
	_skulker_island(Vector3(0, -30, 650))
	_pariah_keep(Vector3(0, 120, -760))
	_clockwork(Vector3(470, 160, -460))
	_ghost_writer(Vector3(-460, 60, -420))
	_aragon(Vector3(-360, -10, 560))
	_doors()
	_wisps()


func _landmark(name: String, pos: Vector3, radius: float) -> void:
	landmarks.append({"name": name, "pos": pos, "radius": radius})
	map_labels.append([Vector2(pos.x, pos.z), name])


## Floating island: flat walkable top on an inverted rock spire.
func island(pos: Vector3, r: float, top: Material = null, rock: Material = null) -> void:
	var top_mat := top if top else _top
	var rock_mat := rock if rock else _rock
	B.cylinder(self, r, 1.2, pos + Vector3(0, -0.6, 0), top_mat, B.L_WORLD, -1.0, 20)
	var depth := r * rng.randf_range(1.0, 1.8)
	var spire := B.cylinder(self, r * 0.95, depth, pos + Vector3(0, -1.2 - depth * 0.5, 0), rock_mat, 0, -1.0, 12)
	(spire.mesh as CylinderMesh).bottom_radius = r * 0.12
	map_rects.append([Rect2(pos.x - r, pos.z - r, r * 2, r * 2), Color(0.35, 0.6, 0.5)])


func _hub() -> void:
	island(Vector3.ZERO, 34.0)
	spots["spawn"] = Vector3(0, 0.2, 8)
	spots["portal"] = Vector3(0, 4.5, -24)
	for k in 8:
		var a := k * TAU / 8.0
		B.cylinder(self, 0.8, 7.0, Vector3(cos(a) * 28, 3.5, sin(a) * 28), B.toon(Color(0.4, 0.3, 0.5), 0.2, 0.04), B.L_WORLD, -1.0, 8)
		B.sphere(self, 0.9, Vector3(cos(a) * 28, 7.6, sin(a) * 28), B.glow(Color(0.4, 1.0, 0.6), 3.0))
	B.label(self, "THE PHANTOM EXPANSE", Vector3(0, 14, -24), 140, Color(0.6, 1.0, 0.75), true, 0.03)
	_landmark("Phantom Expanse", Vector3.ZERO, 120.0)
	enemy_zones.append([Vector3(0, 20, 0), 200.0, "minion"])


func _islands() -> void:
	var specials := [Vector3(650, 0, 0), Vector3(-600, 0, 150), Vector3(0, 0, 650), Vector3(0, 0, -760), Vector3(470, 0, -460), Vector3(-460, 0, -420), Vector3(-360, 0, 560)]
	var made := 0
	var tries := 0
	while made < 55 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(70.0, 720.0)
		var p := Vector3(cos(a) * d, rng.randf_range(-60.0, 140.0), sin(a) * d)
		var ok := true
		for s in specials:
			if Vector2(p.x - s.x, p.z - s.z).length() < 140.0:
				ok = false
				break
		if not ok:
			continue
		made += 1
		var r := rng.randf_range(6.0, 22.0)
		var tint := Color.from_hsv(rng.randf_range(0.35, 0.8), 0.45, 0.55)
		island(p, r, B.toon(tint, 0.15, 0.05))
		if rng.randf() < 0.4:
			# Crystal formation.
			for k in rng.randi_range(2, 5):
				var cpos := p + Vector3(rng.randf_range(-r, r) * 0.5, 0, rng.randf_range(-r, r) * 0.5)
				var cr := B.cylinder(self, 0.8, rng.randf_range(3, 7), cpos + Vector3(0, 2, 0), B.glow(Color(0.4, 1.0, 0.7).lerp(Color(0.7, 0.4, 1.0), rng.randf()), 1.5, 0.85), 0, 0.0, 6)
				cr.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		if made % 6 == 0:
			artifact_spots.append(p + Vector3(0, 0.1, 0))
		if made % 5 == 0:
			enemy_zones.append([p + Vector3(0, 10, 0), 60.0, "minion" if rng.randf() < 0.7 else "shadow"])
		if made % 9 == 0:
			door_portals.append(p + Vector3(0, 4, 0))


func _far_frozen(c: Vector3) -> void:
	var snow := B.toon(Color(0.9, 0.95, 1.0), 0.1, 0.05)
	var ice := B.toon(Color(0.55, 0.8, 0.95), 0.25, 0.05)
	island(c, 50.0, snow, ice)
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		island(c + Vector3(cos(a) * 95, rng.randf_range(-20, 30), sin(a) * 95), rng.randf_range(12, 20), snow, ice)
	for k in 5:
		var a := k * TAU / 5.0
		var d := B.sphere(self, 5.0, c + Vector3(cos(a) * 28, 0, sin(a) * 28), snow, B.L_WORLD, 16)
		d.scale.y = 0.7
	for k in 14:
		var sp := c + Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45))
		if sp.distance_to(c) < 14.0:
			continue
		B.cylinder(self, rng.randf_range(0.8, 1.6), rng.randf_range(4, 10), sp + Vector3(0, 3, 0), B.glow(Color(0.6, 0.9, 1.0), 1.0, 0.8), B.L_WORLD, 0.0, 6)
	var snowfall := B.particles(self, Color(1, 1, 1), 160, 6.0, false, 1.0, 0.25)
	snowfall.position = c + Vector3(0, 40, 0)
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(80, 1, 80)
	snowfall.direction = Vector3(0.2, -1, 0)
	snowfall.spread = 10.0
	snowfall.initial_velocity_min = 5.0
	snowfall.initial_velocity_max = 8.0
	spots["frostbite"] = c + Vector3(0, 0.1, -6)
	spots["far_frozen"] = c + Vector3(0, 0.2, 12)
	B.label(self, "THE FAR FROZEN", c + Vector3(0, 22, 0), 140, Color(0.7, 0.9, 1.0), true, 0.03)
	artifact_spots.append(c + Vector3(30, 0.2, 30))
	_landmark("The Far Frozen", c, 140.0)


func _walker_prison(c: Vector3) -> void:
	var floor := B.toon(Color(0.35, 0.35, 0.4), 0.05, 0.05)
	var wall := B.building_mat(Color(0.5, 0.5, 0.58), true, Vector2(4.0, 5.0))
	var shield := B.glow(Color(0.95, 0.35, 0.55), 1.0, 0.2)
	B.box(self, Vector3(130, 3, 130), c + Vector3(0, -1.5, 0), floor)
	var spire := B.cylinder(self, 70.0, 90.0, c + Vector3(0, -48, 0), _rock, 0, -1.0, 12)
	(spire.mesh as CylinderMesh).bottom_radius = 8.0
	var h := 22.0
	# Prison walls are ghost-shielded: no phasing through them.
	B.box(self, Vector3(120, h, 3), c + Vector3(0, h * 0.5, -60), wall)
	B.box(self, Vector3(120, h, 3), c + Vector3(0, h * 0.5, 60), wall)
	B.box(self, Vector3(3, h, 120), c + Vector3(-60, h * 0.5, 0), wall)
	B.box(self, Vector3(3, h, 50), c + Vector3(60, h * 0.5, -35), wall)
	B.box(self, Vector3(3, h, 50), c + Vector3(60, h * 0.5, 35), wall)
	B.box(self, Vector3(3, 8, 20), c + Vector3(60, h - 4, 0), wall)
	B.box(self, Vector3(122, 0.6, 122), c + Vector3(0, h + 6, 0), shield, 0)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			B.cylinder(self, 4.0, 34.0, c + Vector3(s * 60, 17, t * 60), wall, B.L_WORLD)
			var lamp := SpotLight3D.new()
			lamp.light_color = Color(1.0, 0.95, 0.7)
			lamp.spot_range = 90.0
			lamp.spot_angle = 18.0
			lamp.light_energy = 3.0
			lamp.position = c + Vector3(s * 58, 34, t * 58)
			lamp.basis = Basis.looking_at(c - lamp.position, Vector3.UP)
			add_child(lamp)
	# Cell blocks.
	for row in 2:
		for k in 6:
			var cp := c + Vector3(-45 + k * 10, 0, -50 + row * 100 - (1 - row * 2) * 0)
			cp.z = c.z + (-50 if row == 0 else 50)
			B.box(self, Vector3(9, 8, 8), cp + Vector3(0, 4, 0), B.toon(Color(0.4, 0.4, 0.46), 0.0, 0.04))
			for b in 5:
				B.box(self, Vector3(0.25, 7, 0.25), cp + Vector3(-3.6 + b * 1.8, 3.5, 4.2 * (1 if row == 0 else -1)), B.toon(Color(0.2, 0.2, 0.22)), 0)
	B.label(self, "WALKER'S PRISON", c + Vector3(62, h + 3, 0), 150, Color(1, 0.8, 0.7), false, 0.03).rotation.y = PI / 2
	B.label(self, "RULE 1: NO FLYING.  RULE 2: NO PHASING.  RULE 3: OBEY RULES 1 AND 2.", c + Vector3(61.8, 6, 18), 40, Color(1, 0.95, 0.8), false, 0.02).rotation.y = PI / 2
	spots["walker_yard"] = c + Vector3(0, 0.2, 0)
	spots["prison_gate"] = c + Vector3(80, 4, 0)
	B.box(self, Vector3(30, 1.0, 14), c + Vector3(76, -0.5, 0), floor)
	enemy_zones.append([c + Vector3(0, 3, 0), 55.0, "guard"])
	artifact_spots.append(c + Vector3(-50, 0.2, 0))
	map_rects.append([Rect2(c.x - 60, c.z - 60, 120, 120), Color(0.55, 0.55, 0.6)])
	_landmark("Walker's Prison", c, 110.0)


func _skulker_island(c: Vector3) -> void:
	island(c, 60.0, B.toon(Color(0.25, 0.5, 0.25), 0.1, 0.05))
	for k in 40:
		var p := c + Vector3(rng.randf_range(-50, 50), 0, rng.randf_range(-50, 50))
		if Vector2(p.x - c.x, p.z - c.z).length() > 52.0:
			continue
		B.cylinder(self, 0.5, 9, p + Vector3(0, 4.5, 0), B.toon(Color(0.35, 0.25, 0.15), 0.0, 0.03), B.L_WORLD, -1.0, 8)
		B.sphere(self, 3.5, p + Vector3(0, 10, 0), B.toon(Color(0.15, 0.45, 0.2), 0.1, 0.05), 0, 10)
	var hut := c + Vector3(0, 0, -10)
	B.box(self, Vector3(14, 6, 10), hut + Vector3(0, 3, 0), B.toon(Color(0.4, 0.3, 0.2), 0.0, 0.05))
	B.label(self, "SKULKER'S TROPHY ROOM", hut + Vector3(0, 7.5, 5.2), 64, Color(0.8, 1.0, 0.6), false, 0.02)
	artifact_spots.append(hut + Vector3(0, 6.2, 0))
	enemy_zones.append([c + Vector3(0, 8, 0), 60.0, "shadow"])
	_landmark("Skulker's Island", c, 120.0)


func _pariah_keep(c: Vector3) -> void:
	var dark := B.building_mat(Color(0.18, 0.12, 0.22), true, Vector2(5.0, 6.0))
	island(c, 70.0, B.toon(Color(0.15, 0.1, 0.18), 0.1, 0.05), B.toon(Color(0.1, 0.05, 0.12), 0.0, 0.05))
	B.box(self, Vector3(60, 40, 50), c + Vector3(0, 20, -10), dark)
	for s in [-1.0, 1.0]:
		B.cylinder(self, 8.0, 70.0, c + Vector3(s * 34, 35, -10), dark, B.L_WORLD)
		B.cylinder(self, 9.0, 16.0, c + Vector3(s * 34, 78, -10), B.toon(Color(0.4, 0.05, 0.1), 0.4, 0.05), 0, 0.0)
	B.box(self, Vector3(18, 24, 1.0), c + Vector3(0, 12, 15.6), B.glow(Color(0.9, 0.2, 0.3), 1.2, 0.35), B.L_WORLD)
	B.label(self, "PARIAH'S KEEP", c + Vector3(0, 48, 16), 160, Color(1.0, 0.4, 0.4), true, 0.035)
	B.label(self, "Sealed by the Ring of Rage - Endgame", c + Vector3(0, 26, 16.3), 48, Color(1, 0.7, 0.7), false, 0.02)
	var red := OmniLight3D.new()
	red.light_color = Color(1.0, 0.2, 0.25)
	red.omni_range = 80.0
	red.light_energy = 2.0
	red.position = c + Vector3(0, 30, 30)
	add_child(red)
	artifact_spots.append(c + Vector3(-40, 0.2, 40))
	enemy_zones.append([c + Vector3(0, 10, 40), 70.0, "shadow"])
	_landmark("Pariah's Keep", c, 130.0)


func _clockwork(c: Vector3) -> void:
	island(c, 26.0, B.toon(Color(0.45, 0.35, 0.6), 0.15, 0.05))
	var stone := B.building_mat(Color(0.55, 0.45, 0.7), false)
	B.cylinder(self, 9.0, 50.0, c + Vector3(0, 25, 0), stone, B.L_WORLD)
	var face := B.cylinder(self, 7.0, 0.6, c + Vector3(0, 40, 9.2), B.toon(Color(0.95, 0.9, 0.75), 0.3, 0.04), 0)
	face.rotation.x = PI / 2
	B.label(self, "XII", c + Vector3(0, 45.5, 9.6), 96, Color(0.2, 0.15, 0.1), false, 0.02)
	for k in 3:
		var g := B.torus(self, 3.0 + k, 4.0 + k, c + Vector3(-12 + k * 12, 30 + k * 8, 0), B.toon(Color(0.85, 0.7, 0.3), 0.3, 0.04))
		g.rotation.x = PI / 2
		gears.append(g)
	artifact_spots.append(c + Vector3(0, 50.3, 0))
	_landmark("Clockwork's Realm", c, 70.0)


func _ghost_writer(c: Vector3) -> void:
	island(c, 34.0, B.toon(Color(0.4, 0.3, 0.25), 0.1, 0.05))
	var wall := B.building_mat(Color(0.45, 0.35, 0.3), true, Vector2(3.0, 4.0))
	B.box(self, Vector3(36, 18, 24), c + Vector3(0, 9, -4), wall)
	var roof := PrismMesh.new()
	roof.size = Vector3(38, 8, 26)
	B.mesh_instance(self, roof, c + Vector3(0, 22, -4), B.toon(Color(0.25, 0.15, 0.2), 0.0, 0.05))
	for k in 12:
		var bk := B.box(self, Vector3(1.0, 1.4, 0.3), c + Vector3(rng.randf_range(-20, 20), rng.randf_range(4, 25), rng.randf_range(10, 25)), B.toon(Color.from_hsv(rng.randf(), 0.6, 0.7), 0.3, 0.02), 0)
		bk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
	B.label(self, "GHOST WRITER'S MANOR", c + Vector3(0, 30, 10), 110, Color(0.95, 0.85, 0.7), true, 0.03)
	artifact_spots.append(c + Vector3(0, 26.4, -4))
	_landmark("Ghost Writer's Manor", c, 80.0)


func _aragon(c: Vector3) -> void:
	island(c, 48.0, B.toon(Color(0.3, 0.4, 0.3), 0.1, 0.05))
	var stone := B.building_mat(Color(0.5, 0.48, 0.45), false)
	B.box(self, Vector3(40, 16, 30), c + Vector3(0, 8, 0), stone)
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			B.cylinder(self, 4.0, 26, c + Vector3(s * 20, 13, t * 15), stone, B.L_WORLD)
			B.cylinder(self, 5.0, 7, c + Vector3(s * 20, 29.5, t * 15), B.toon(Color(0.5, 0.15, 0.15), 0.1, 0.05), 0, 0.0)
	B.label(self, "ARAGON'S KINGDOM", c + Vector3(0, 30, 16), 120, Color(1, 0.75, 0.5), true, 0.03)
	enemy_zones.append([c + Vector3(0, 10, 0), 60.0, "minion"])
	_landmark("Aragon's Kingdom", c, 90.0)


func _doors() -> void:
	# Drifting decorative doors to other ghosts' lairs.
	for k in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(60.0, 600.0)
		var p := Vector3(cos(a) * d, rng.randf_range(-30, 160), sin(a) * d)
		var door := Node3D.new()
		add_child(door)
		door.position = p
		door.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		var col := Color.from_hsv(rng.randf(), 0.5, 0.6)
		B.box(door, Vector3(3.4, 6.0, 0.5), Vector3.ZERO, B.toon(col, 0.2, 0.05), 0)
		B.box(door, Vector3(2.6, 5.2, 0.6), Vector3.ZERO, B.toon(col.darkened(0.4), 0.1, 0.0), 0)
		B.sphere(door, 0.2, Vector3(1.0, 0, -0.4), B.glow(Color(1, 0.9, 0.4), 2.0))


func _wisps() -> void:
	var w := B.particles(self, Color(0.6, 1.0, 0.8), 220, 8.0, false, 1.0, 0.6)
	w.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	w.emission_box_extents = Vector3(500, 120, 500)
	w.position = Vector3(0, 40, 0)
	w.direction = Vector3(1, 0.2, 0)
	w.spread = 180.0
	w.initial_velocity_min = 1.0
	w.initial_velocity_max = 4.0


func district_at(p: Vector3) -> String:
	for l in landmarks:
		if Vector2(p.x - l["pos"].x, p.z - l["pos"].z).length() < l["radius"]:
			return l["name"]
	return "The Infinite Realms"


func _process(delta: float) -> void:
	for i in gears.size():
		gears[i].rotation.y += delta * (0.4 if i % 2 == 0 else -0.6)
