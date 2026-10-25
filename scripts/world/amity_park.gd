extends Node3D
## Procedurally assembles Amity Park: a grid of city blocks with roads,
## downtown towers, residential streets, landmark buildings with interiors,
## Fenton Works (with its basement lab and the Fenton Portal), Lake Eerie,
## the Guys in White HQ and Vlad's estate.

const B := preload("res://scripts/util/builder.gd")
const Pedestrian := preload("res://scripts/world/pedestrian.gd")
const Car := preload("res://scripts/world/car.gd")
const Interactable := preload("res://scripts/world/interactable.gd")

const PITCH := 80.0
const ROAD := 14.0
const GRID := 5            # roads from -GRID*PITCH to +GRID*PITCH
const SLAB := 0.2          # sidewalk height
const WORLD_HALF := 640.0
const WALL := 0.4
const FW := Vector3(-200, 0, 120)   # Fenton Works

var game: Node = null
var rng := RandomNumberGenerator.new()
var spots := {}
var landmarks: Array = []          # {name, pos, radius}
var map_rects: Array = []          # [Rect2 (x,z,w,d), Color]
var map_labels: Array = []         # [Vector2, String]
var artifact_spots: Array = []
var ped_routes: Array = []
var car_routes: Array = []
var event_spots: Array = []        # open street positions for events
var lamp_mat: StandardMaterial3D
var neon_mats: Array = []
var school_spot := Vector3.ZERO
var stage_spot := Vector3.ZERO
var substation_spot := Vector3.ZERO
var race_points: Array = []

var _mat_concrete: Material
var _mat_grass: Material
var _mat_road: Material
var _mat_line: Material


func build(game_ref: Node) -> void:
	game = game_ref
	rng.seed = 20041
	_mat_concrete = B.toon(Color(0.5, 0.5, 0.5))
	_mat_grass = B.toon(Color(0.32, 0.55, 0.3))
	_mat_road = B.toon(Color(0.17, 0.17, 0.19))
	_mat_line = B.toon(Color(0.95, 0.8, 0.2), 0.2)
	lamp_mat = B.glow_unique(Color(1.0, 0.9, 0.6), 0.2)
	_ground()
	_roads()
	_blocks()
	_fenton_works()
	_casper_high(Vector3(120, 0, 120))
	_sports_field(Vector3(200, 0, 120))
	_nasty_burger(Vector3(40, 0, 200))
	_park(Vector3(40, 0, 40))
	_city_hall(Vector3(-40, 0, 40))
	_museum(Vector3(120, 0, -40))
	_axion_labs(Vector3(280, 0, -200))
	_mall(Vector3(-200, 0, -200))
	_lake_eerie()
	_giw_hq(Vector3(540, 0, 40))
	_vlad_mansion(Vector3(-540, 0, -260))
	_lamps()
	_routes()
	_race_course()


# --- Helpers ---------------------------------------------------------------
func _rbox(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, mat: Material, layer := B.L_WORLD) -> Node3D:
	return B.box(self, Vector3(x1 - x0, y1 - y0, z1 - z0), Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), mat, layer)


func _landmark(name: String, pos: Vector3, radius: float) -> void:
	landmarks.append({"name": name, "pos": pos, "radius": radius})
	map_labels.append([Vector2(pos.x, pos.z), name])


func _map(center: Vector3, w: float, d: float, c: Color) -> void:
	map_rects.append([Rect2(center.x - w * 0.5, center.z - d * 0.5, w, d), c])


func _sign(text: String, pos: Vector3, size := 160, color := Color(0.95, 1.0, 0.9), rot_y := 0.0, neon := false) -> Label3D:
	var l := B.label(self, text, pos, size, color, false, 0.03)
	l.rotation.y = rot_y
	if neon:
		l.outline_modulate = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3)
		neon_mats.append(l)
	return l


## Wall with rectangular openings (doors/windows). Runs along X (axis=0) or Z
## (axis=1). Openings are [u0, u1, v0, v1] in wall-local metres.
func _wall(axis: int, a0: float, a1: float, c: float, y0: float, h: float, openings: Array, mat: Material, layer := B.L_PHASE, t := WALL) -> void:
	var cuts := [0.0, a1 - a0]
	for o in openings:
		cuts.append(clampf(o[0], 0.0, a1 - a0))
		cuts.append(clampf(o[1], 0.0, a1 - a0))
	cuts.sort()
	for i in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 < 0.01:
			continue
		var mid := (u0 + u1) * 0.5
		var holes: Array = []
		for o in openings:
			if o[0] <= mid and o[1] >= mid:
				holes.append([o[2], o[3]])
		holes.sort_custom(func(p, q): return p[0] < q[0])
		var v := 0.0
		for hole in holes:
			if hole[0] > v + 0.01:
				_wall_piece(axis, a0 + u0, a0 + u1, c, y0 + v, y0 + hole[0], mat, layer, t)
			v = maxf(v, hole[1])
		if h > v + 0.01:
			_wall_piece(axis, a0 + u0, a0 + u1, c, y0 + v, y0 + h, mat, layer, t)


func _wall_piece(axis: int, a0: float, a1: float, c: float, y0: float, y1: float, mat: Material, layer: int, t: float) -> void:
	if axis == 0:
		_rbox(a0, a1, c - t * 0.5, c + t * 0.5, y0, y1, mat, layer)
	else:
		_rbox(c - t * 0.5, c + t * 0.5, a0, a1, y0, y1, mat, layer)


## A building you can walk, fly or phase into. Returns interior floor heights.
func _hollow(center: Vector3, w: float, d: float, floors: int, fh: float, mat: Material, door_side := "south", door_w := 3.4, big_windows := false) -> Array:
	var x0 := center.x - w * 0.5
	var x1 := center.x + w * 0.5
	var z0 := center.z - d * 0.5
	var z1 := center.z + d * 0.5
	var base := center.y + SLAB
	var h := floors * fh
	var heights: Array = []
	for side in ["north", "south", "west", "east"]:
		var along := w if side in ["north", "south"] else d
		var ops: Array = []
		if side == door_side:
			ops.append([along * 0.5 - door_w * 0.5, along * 0.5 + door_w * 0.5, 0.0, minf(3.2, fh - 0.3)])
		var ww := 2.6 if big_windows else 1.8
		var wh := 2.0 if big_windows else 1.5
		var n := int(along / 6.0)
		for f in floors:
			for k in n:
				var u := (k + 0.5) * along / n
				if f == 0 and side == door_side and absf(u - along * 0.5) < door_w:
					continue
				ops.append([u - ww * 0.5, u + ww * 0.5, f * fh + 1.1, f * fh + 1.1 + wh])
		match side:
			"north":
				_wall(0, x0, x1, z0, base, h, ops, mat)
			"south":
				_wall(0, x0, x1, z1, base, h, ops, mat)
			"west":
				_wall(1, z0, z1, x0 + WALL * 0.5, base, h, ops, mat)
			"east":
				_wall(1, z0, z1, x1 - WALL * 0.5, base, h, ops, mat)
	var floor_mat := B.toon(Color(0.55, 0.5, 0.45))
	heights.append(base)
	for f in range(1, floors):
		var y := base + f * fh
		# Stairwell opening in the north-east corner with a ramp.
		var sx0 := x1 - 4.0
		var sz1 := z0 + 0.4 + fh * 1.7
		_rbox(x0, sx0, z0, z1, y - 0.3, y, floor_mat, B.L_PHASE)
		_rbox(sx0, x1, sz1, z1, y - 0.3, y, floor_mat, B.L_PHASE)
		_ramp(Vector3(x1 - 2.1, y - fh, sz1), Vector3(x1 - 2.1, y, z0 + 0.4), 3.4)
		heights.append(y)
	_rbox(x0, x1, z0, z1, base + h, base + h + 0.4, B.toon(Color(0.4, 0.4, 0.42), 0.0, 0.0), B.L_PHASE)
	_map(center, w, d, Color(0.55, 0.62, 0.7))
	return heights


func _ramp(bottom: Vector3, top: Vector3, width: float, layer := B.L_PHASE) -> void:
	var run := Vector2(top.x - bottom.x, top.z - bottom.z)
	var rise := top.y - bottom.y
	var length := sqrt(run.length_squared() + rise * rise)
	var body := B.box(self, Vector3(width, 0.3, length), (bottom + top) * 0.5 + Vector3(0, -0.12, 0), B.toon(Color(0.5, 0.42, 0.35), 0.0, 0.03), layer)
	var yaw := atan2(-run.x, -run.y)
	body.rotation = Vector3(atan2(rise, run.length()), yaw, 0)


func _tree(pos: Vector3, s := 1.0) -> void:
	B.cylinder(self, 0.3 * s, 3.0 * s, pos + Vector3(0, 1.5 * s, 0), B.toon(Color(0.4, 0.27, 0.15), 0.0, 0.03), B.L_WORLD, -1.0, 8)
	B.cylinder(self, 2.2 * s, 4.5 * s, pos + Vector3(0, 4.8 * s, 0), B.toon(Color(0.18, 0.42 + rng.randf() * 0.12, 0.2), 0.0, 0.05), 0, 0.0, 10)
	B.cylinder(self, 1.6 * s, 3.4 * s, pos + Vector3(0, 6.6 * s, 0), B.toon(Color(0.2, 0.48, 0.22), 0.0, 0.05), 0, 0.0, 10)


func _interactable(pos: Vector3, size: Vector3, text: String, cb: Callable, mat: Material) -> Node3D:
	var it: StaticBody3D = Interactable.new()
	it.interact_text = text
	it.callback = cb
	it.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	it.add_child(cs)
	B.box(it, size, Vector3.ZERO, mat, 0)
	add_child(it)
	return it


# --- Ground and roads ------------------------------------------------------
func _ground() -> void:
	# Big ground plane with a hole for the Fenton Works basement.
	var hx0 := FW.x - 9.0
	var hx1 := FW.x + 9.0
	var hz0 := FW.z - 8.0
	var hz1 := FW.z + 8.0
	var w := WORLD_HALF
	var g := B.toon(Color(0.3, 0.5, 0.28))
	_rbox(-w, hx0, -w, w, -2.0, 0.0, g)
	_rbox(hx1, w, -w, w, -2.0, 0.0, g)
	_rbox(hx0, hx1, -w, hz0, -2.0, 0.0, g)
	_rbox(hx0, hx1, hz1, w, -2.0, 0.0, g)
	# Distant hills ring the valley.
	for i in 28:
		var a := i * TAU / 28.0
		var r := WORLD_HALF + 60.0
		var hill := B.sphere(self, rng.randf_range(90, 150), Vector3(cos(a) * r, -30, sin(a) * r), B.toon(Color(0.26, 0.42, 0.3)), 0, 12)
		hill.scale.y = rng.randf_range(0.5, 0.9)


func _roads() -> void:
	var ext := GRID * PITCH + ROAD * 0.5
	for k in range(-GRID, GRID + 1):
		var c := k * PITCH
		B.box(self, Vector3(ROAD, 0.04, ext * 2.0), Vector3(c, 0.02, 0), _mat_road, 0)
		B.box(self, Vector3(ext * 2.0, 0.05, ROAD), Vector3(0, 0.025, c), _mat_road, 0)
		B.box(self, Vector3(0.3, 0.06, ext * 2.0), Vector3(c, 0.03, 0), _mat_line, 0)
		B.box(self, Vector3(ext * 2.0, 0.07, 0.3), Vector3(0, 0.035, c), _mat_line, 0)


func block_center(i: int, j: int) -> Vector3:
	return Vector3(i * PITCH + PITCH * 0.5, 0, j * PITCH + PITCH * 0.5)


func _block_kind(i: int, j: int) -> String:
	var special := {
		Vector2i(-3, 1): "fenton", Vector2i(1, 1): "school", Vector2i(2, 1): "field",
		Vector2i(0, 2): "nasty", Vector2i(0, 0): "park", Vector2i(-1, 0): "cityhall",
		Vector2i(1, -1): "museum", Vector2i(3, -3): "axion", Vector2i(-3, -3): "mall",
	}
	var key := Vector2i(i, j)
	if special.has(key):
		return special[key]
	if absi(i) <= 1 and j >= -3 and j <= -1:
		return "downtown"
	if (i <= -2 and j >= 0) or j >= 3:
		return "residential"
	return "midrise"


func _blocks() -> void:
	var inner := PITCH - ROAD
	for i in range(-GRID, GRID):
		for j in range(-GRID, GRID):
			var c := block_center(i, j)
			var kind := _block_kind(i, j)
			var top_mat := _mat_grass if kind in ["residential", "park", "field", "fenton"] else _mat_concrete
			if kind == "fenton":
				# Slab with a hole for the basement.
				var x0 := c.x - inner * 0.5
				var x1 := c.x + inner * 0.5
				var z0 := c.z - inner * 0.5
				var z1 := c.z + inner * 0.5
				_rbox(x0, FW.x - 9.0, z0, z1, -0.1, SLAB, top_mat)
				_rbox(FW.x + 9.0, x1, z0, z1, -0.1, SLAB, top_mat)
				_rbox(FW.x - 9.0, FW.x + 9.0, z0, FW.z - 8.0, -0.1, SLAB, top_mat)
				_rbox(FW.x - 9.0, FW.x + 9.0, FW.z + 8.0, z1, -0.1, SLAB, top_mat)
			else:
				B.box(self, Vector3(inner, SLAB + 0.1, inner), c + Vector3(0, (SLAB - 0.1) * 0.5, 0), top_mat)
			# Sidewalk rim.
			if top_mat == _mat_grass:
				for s in [-1.0, 1.0]:
					B.box(self, Vector3(inner, 0.04, 3.0), c + Vector3(0, SLAB + 0.02, s * (inner * 0.5 - 1.5)), _mat_concrete, 0)
					B.box(self, Vector3(3.0, 0.04, inner), c + Vector3(s * (inner * 0.5 - 1.5), SLAB + 0.02, 0), _mat_concrete, 0)
			ped_routes.append(_sidewalk_loop(c, inner * 0.5 - 1.5))
			match kind:
				"downtown":
					_downtown_block(c)
				"residential":
					_residential_block(c)
				"midrise":
					_midrise_block(c)
				"fenton":
					for off in [Vector3(-22, 0, -22), Vector3(22, 0, -22), Vector3(-22, 0, 22), Vector3(22, 0, 22)]:
						_house(c + off, rng.randf_range(9, 11), rng.randf_range(9, 11))
			if kind in ["downtown", "midrise"] and rng.randf() < 0.35:
				event_spots.append(c + Vector3(0, SLAB, inner * 0.5 + ROAD * 0.5))


func _sidewalk_loop(c: Vector3, r: float) -> Array:
	var pts := [c + Vector3(-r, SLAB, -r), c + Vector3(r, SLAB, -r), c + Vector3(r, SLAB, r), c + Vector3(-r, SLAB, r)]
	if rng.randf() < 0.5:
		pts.reverse()
	return pts


func _tower(pos: Vector3, w: float, d: float, h: float, color: Color) -> void:
	var mat := B.building_mat(color, true, Vector2(3.2, 3.8))
	B.box(self, Vector3(w, h, d), pos + Vector3(0, SLAB + h * 0.5, 0), mat)
	_map(pos, w, d, Color(0.45, 0.5, 0.58))
	var roof_y := SLAB + h
	if rng.randf() < 0.6:
		B.box(self, Vector3(w * 0.4, 3.0, d * 0.4), pos + Vector3(rng.randf_range(-w, w) * 0.2, roof_y + 1.5, rng.randf_range(-d, d) * 0.2), B.building_mat(color.darkened(0.2), false), B.L_WORLD)
	if rng.randf() < 0.3:
		B.cylinder(self, 0.25, 12.0, pos + Vector3(w * 0.3, roof_y + 6.0, d * 0.3), B.toon(Color(0.3, 0.3, 0.32)), 0)
		B.sphere(self, 0.4, pos + Vector3(w * 0.3, roof_y + 12.2, d * 0.3), B.glow(Color(1, 0.2, 0.2), 3.0))
	if h > 50.0 and rng.randf() < 0.5:
		artifact_spots.append(pos + Vector3(0, roof_y + 0.2, 0) + Vector3(w * 0.3, 0, -d * 0.3))


func _downtown_block(c: Vector3) -> void:
	var palette := [Color(0.55, 0.6, 0.7), Color(0.65, 0.62, 0.55), Color(0.42, 0.5, 0.6), Color(0.6, 0.55, 0.62), Color(0.5, 0.58, 0.55)]
	var layout := rng.randi() % 3
	match layout:
		0:
			_tower(c + Vector3(-14, 0, -14), 26, 26, rng.randf_range(70, 130), palette[rng.randi() % 5])
			_tower(c + Vector3(16, 0, 14), 22, 24, rng.randf_range(45, 95), palette[rng.randi() % 5])
			_tower(c + Vector3(16, 0, -16), 20, 18, rng.randf_range(25, 50), palette[rng.randi() % 5])
		1:
			_tower(c, 36, 36, rng.randf_range(90, 150), palette[rng.randi() % 5])
		_:
			for off in [Vector3(-14, 0, -14), Vector3(14, 0, -14), Vector3(-14, 0, 14), Vector3(14, 0, 14)]:
				_tower(c + off, 22, 22, rng.randf_range(30, 85), palette[rng.randi() % 5])


func _midrise_block(c: Vector3) -> void:
	var palette := [Color(0.72, 0.55, 0.42), Color(0.6, 0.62, 0.66), Color(0.75, 0.7, 0.58), Color(0.55, 0.45, 0.4), Color(0.62, 0.68, 0.6)]
	var offs := [Vector3(-15, 0, -15), Vector3(15, 0, -15), Vector3(-15, 0, 15), Vector3(15, 0, 15)]
	for off in offs:
		if rng.randf() < 0.15:
			continue
		var h := 3.8 * rng.randi_range(2, 6)
		_tower(c + off, rng.randf_range(20, 26), rng.randf_range(20, 26), h, palette[rng.randi() % 5])


func _house(pos: Vector3, w: float, d: float) -> void:
	var colors := [Color(0.85, 0.75, 0.55), Color(0.65, 0.78, 0.85), Color(0.9, 0.85, 0.8), Color(0.75, 0.6, 0.7), Color(0.7, 0.8, 0.6)]
	var col: Color = colors[rng.randi() % colors.size()]
	var h := 6.5
	B.box(self, Vector3(w, h, d), pos + Vector3(0, SLAB + h * 0.5, 0), B.building_mat(col, true, Vector2(3.0, 3.2)))
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.0, 3.0, d + 1.0)
	var r := B.mesh_instance(self, roof, pos + Vector3(0, SLAB + h + 1.5, 0), B.toon(Color(0.5, 0.25, 0.2), 0.0, 0.05))
	r.rotation.y = PI / 2 if rng.randf() < 0.5 else 0.0
	B.box(self, Vector3(1.4, 2.4, 0.1), pos + Vector3(0, SLAB + 1.2, d * 0.5 + 0.05), B.toon(Color(0.4, 0.25, 0.15)), 0)
	_map(pos, w, d, Color(0.6, 0.55, 0.5))
	if rng.randf() < 0.5:
		_tree(pos + Vector3(w * 0.5 + 4.0, SLAB, d * 0.5 + 3.0), rng.randf_range(0.7, 1.0))


func _residential_block(c: Vector3) -> void:
	for off in [Vector3(-18, 0, -18), Vector3(18, 0, -18), Vector3(-18, 0, 18), Vector3(18, 0, 18), Vector3(0, 0, -18), Vector3(0, 0, 18)]:
		if rng.randf() < 0.2:
			continue
		_house(c + off + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), rng.randf_range(9, 12), rng.randf_range(9, 12))


func _lamps() -> void:
	for i in range(-GRID, GRID + 1):
		for j in range(-GRID, GRID + 1):
			if (i + j) % 2 != 0:
				continue
			var p := Vector3(i * PITCH + ROAD * 0.5 + 1.0, SLAB, j * PITCH + ROAD * 0.5 + 1.0)
			B.cylinder(self, 0.15, 7.0, p + Vector3(0, 3.5, 0), B.toon(Color(0.2, 0.22, 0.25), 0.0, 0.02), B.L_WORLD, -1.0, 8)
			B.box(self, Vector3(2.0, 0.15, 0.2), p + Vector3(-1.0, 7.0, 0), B.toon(Color(0.2, 0.22, 0.25)), 0)
			B.sphere(self, 0.35, p + Vector3(-1.8, 6.75, 0), lamp_mat, 0, 8)


# --- Fenton Works ------------------------------------------------------------
func _fenton_works() -> void:
	var c := FW
	var brick := B.building_mat(Color(0.72, 0.55, 0.4), false)
	var x0 := c.x - 9.0
	var x1 := c.x + 9.0
	var z0 := c.z - 8.0
	var z1 := c.z + 8.0
	var lab_floor := -6.0
	var gf := SLAB
	var f2 := gf + 4.2
	var roof := f2 + 4.2
	var metal := B.toon(Color(0.55, 0.6, 0.62), 0.0, 0.02)
	var lab_wall := B.toon(Color(0.42, 0.48, 0.5))

	# Basement laboratory (solid earth walls).
	_rbox(x0, x1, z0, z1, lab_floor - 0.5, lab_floor, B.toon(Color(0.35, 0.4, 0.42)))
	_rbox(x0 - 0.5, x1 + 0.5, z0 - 0.5, z0, lab_floor, 0.0, lab_wall)
	_rbox(x0 - 0.5, x1 + 0.5, z1, z1 + 0.5, lab_floor, 0.0, lab_wall)
	_rbox(x0 - 0.5, x0, z0, z1, lab_floor, 0.0, lab_wall)
	_rbox(x1, x1 + 0.5, z0, z1, lab_floor, 0.0, lab_wall)
	# Ground floor (phaseable) with a stair opening along the west wall.
	var floor_mat := B.toon(Color(0.6, 0.45, 0.3))
	_rbox(x0 + 3.0, x1, z0, z1, gf - 0.4, gf, floor_mat, B.L_PHASE)
	_rbox(x0, x0 + 3.0, z0 + 12.0, z1, gf - 0.4, gf, floor_mat, B.L_PHASE)
	_ramp(Vector3(x0 + 1.5, lab_floor, z0 + 2.0), Vector3(x0 + 1.5, gf, z0 + 12.0), 2.8)
	for k in 3:
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.6, 1.0, 0.75)
		lt.omni_range = 12.0
		lt.light_energy = 1.4
		lt.position = Vector3(c.x - 5.0 + k * 6.0, lab_floor + 4.5, c.z)
		add_child(lt)
	# Lab equipment.
	B.box(self, Vector3(4, 1.0, 1.4), Vector3(c.x - 2, lab_floor + 0.5, c.z + 5.5), metal)
	B.box(self, Vector3(1.4, 1.0, 4), Vector3(c.x + 6.5, lab_floor + 0.5, c.z + 3), metal)
	for k in 4:
		B.box(self, Vector3(0.5, 0.4, 0.3), Vector3(c.x - 3.2 + k * 0.8, lab_floor + 1.2, c.z + 5.5), B.glow(Color(0.3, 1.0, 0.4).lerp(Color(0.3, 0.6, 1.0), k / 3.0), 2.0), 0)
	var lab_sign := B.label(self, "FENTON LAB", Vector3(c.x, lab_floor + 4.8, z1 - 0.3), 72, Color(0.4, 1.0, 0.55), false, 0.02)
	lab_sign.rotation.y = PI
	# The Fenton Portal on the north wall.
	var portal_pos := Vector3(c.x + 2.0, lab_floor + 2.8, z0 + 0.8)
	spots["portal"] = portal_pos
	spots["portal_exit"] = Vector3(c.x + 2.0, lab_floor + 0.1, z0 + 6.0)
	_rbox(portal_pos.x - 3.6, portal_pos.x + 3.6, z0, z0 + 0.6, lab_floor, lab_floor + 6.0, B.toon(Color(0.3, 0.33, 0.36), 0.0, 0.03))
	B.label(self, "FENTON\nPORTAL", portal_pos + Vector3(-5.6, 0.6, -0.1), 48, Color(0.6, 1.0, 0.7), false, 0.012)
	# Ghost containment unit.
	var cont := Vector3(c.x + 7.0, lab_floor, c.z - 4.5)
	B.cylinder(self, 1.0, 2.6, cont + Vector3(0, 1.3, 0), B.glow(Color(0.3, 1.0, 0.5), 1.2, 0.45), 0)
	B.cylinder(self, 1.15, 0.3, cont + Vector3(0, 0.15, 0), metal, 0)
	B.cylinder(self, 1.15, 0.3, cont + Vector3(0, 2.75, 0), metal, 0)
	_interactable(cont + Vector3(-1.4, 0.6, 0), Vector3(0.6, 1.2, 1.2), "Empty the Fenton Thermos into containment", func(_p): game.deposit_thermos(), B.toon(Color(0.3, 0.32, 0.35), 0.0, 0.02))
	B.label(self, "GHOST CONTAINMENT", cont + Vector3(0, 3.3, 0), 40, Color(0.6, 1.0, 0.7), true, 0.01)
	spots["containment"] = cont
	# Weapons vault.
	_interactable(Vector3(x1 - 0.6, lab_floor + 1.6, c.z + 4.5), Vector3(0.4, 3.0, 3.0), "Browse the Fenton weapons vault", func(_p): game.open_menu("tech"), B.toon(Color(0.35, 0.4, 0.45), 0.2, 0.03))
	var vault_sign := B.label(self, "WEAPONS VAULT", Vector3(x1 - 0.9, lab_floor + 3.5, c.z + 4.5), 36, Color(1, 0.8, 0.4), false, 0.01)
	vault_sign.rotation.y = -PI / 2
	spots["lab"] = Vector3(c.x - 1.0, lab_floor + 0.1, c.z + 2.0)

	# Exterior walls: phaseable brick with a front door and windows.
	var front_ops := [[8.0, 10.0, 0.0, 3.0], [2.0, 4.5, 1.2, 3.0], [13.5, 16.0, 1.2, 3.0], [2.0, 4.5, 5.4, 7.2], [13.0, 16.0, 5.2, 7.6]]
	_wall(0, x0, x1, z1, gf, 8.4, front_ops, brick)
	_wall(0, x0, x1, z0, gf, 8.4, [[3.0, 5.0, 5.4, 7.0], [12.0, 14.0, 1.2, 3.0]], brick)
	_wall(1, z0, z1, x0 + WALL * 0.5, gf, 8.4, [[6.0, 8.0, 5.4, 7.0]], brick)
	_wall(1, z0, z1, x1 - WALL * 0.5, gf, 8.4, [[6.0, 8.0, 1.2, 3.0], [6.0, 8.0, 5.4, 7.0]], brick)
	# Second floor with stairs up along the east wall.
	_rbox(x0, x1 - 3.0, z0, z1, f2 - 0.3, f2, floor_mat, B.L_PHASE)
	_rbox(x1 - 3.0, x1, z0, z0 + 2.0, f2 - 0.3, f2, floor_mat, B.L_PHASE)
	_ramp(Vector3(x1 - 1.6, gf, z1 - 2.0), Vector3(x1 - 1.6, f2, z0 + 2.0), 2.6)
	# Interior partition between Danny's and Jazz's rooms (with a doorway).
	_wall(1, z0, z1 - 4.0, c.x + 1.0, f2, 4.0, [[9.0, 11.0, 0.0, 2.6]], B.toon(Color(0.4, 0.45, 0.7)))
	_rbox(x0, x1, z0, z1, roof, roof + 0.4, B.toon(Color(0.45, 0.32, 0.25)), B.L_PHASE)
	# Ground floor furniture: couch, TV, kitchen.
	B.box(self, Vector3(4, 0.9, 1.4), Vector3(c.x - 1.0, gf + 0.45, c.z + 3.0), B.toon(Color(0.35, 0.55, 0.4), 0.0, 0.03))
	B.box(self, Vector3(2.4, 1.4, 0.4), Vector3(c.x - 1.0, gf + 1.0, c.z - 1.0), B.toon(Color(0.1, 0.1, 0.12), 0.0, 0.02))
	B.box(self, Vector3(5, 1.0, 1.2), Vector3(c.x + 4.0, gf + 0.5, z0 + 1.0), B.toon(Color(0.9, 0.9, 0.88), 0.0, 0.02))
	B.box(self, Vector3(1.2, 2.2, 1.2), Vector3(c.x + 1.5, gf + 1.1, z0 + 1.0), B.toon(Color(0.85, 0.9, 0.92), 0.0, 0.02))
	B.label(self, "FENTON FUDGE", Vector3(c.x + 1.5, gf + 2.4, z0 + 1.65), 24, Color(0.6, 0.4, 0.2), false, 0.01)
	# Danny's bedroom: bed, desk, space posters.
	var bed := Vector3(c.x - 6.5, f2, c.z - 4.5)
	B.box(self, Vector3(2.0, 0.6, 3.6), bed + Vector3(0, 0.3, 0), B.toon(Color(0.2, 0.3, 0.6), 0.0, 0.03))
	B.box(self, Vector3(2.0, 0.25, 0.8), bed + Vector3(0, 0.7, -1.3), B.toon(Color(0.9, 0.9, 0.9)), 0)
	B.box(self, Vector3(2.4, 1.0, 1.0), Vector3(c.x - 2.0, f2 + 0.5, z0 + 0.8), B.toon(Color(0.5, 0.35, 0.22), 0.0, 0.03))
	B.box(self, Vector3(0.9, 0.6, 0.1), Vector3(c.x - 2.0, f2 + 1.4, z0 + 0.6), B.glow(Color(0.3, 0.6, 1.0), 1.0), 0)
	var poster := B.label(self, "ASTRONAUT\nACADEMY", Vector3(x0 + 0.3, f2 + 2.4, c.z + 1.0), 32, Color(0.95, 0.95, 1.0), false, 0.01)
	poster.rotation.y = PI / 2
	B.label(self, "DANNY'S ROOM", Vector3(c.x - 4.0, f2 + 3.4, z0 + 0.3), 32, Color(1, 1, 0.8), false, 0.01)
	spots["bedroom"] = Vector3(c.x - 4.0, f2 + 0.1, c.z - 1.0)
	# Jazz's room: bookshelf.
	B.box(self, Vector3(0.6, 2.4, 3.0), Vector3(x1 - 3.6, f2 + 1.2, c.z - 5.0), B.toon(Color(0.45, 0.3, 0.2), 0.0, 0.03))
	spots["livingroom"] = Vector3(c.x - 2.0, gf + 0.1, c.z + 5.0)

	# Roof: the Fenton Ops Center and the neon sign.
	var ops := Vector3(c.x + 2.0, roof + 0.4, c.z - 1.0)
	B.cylinder(self, 4.5, 2.4, ops + Vector3(0, 1.2, 0), B.toon(Color(0.6, 0.65, 0.68), 0.0, 0.04), B.L_PHASE)
	var dome := B.sphere(self, 4.0, ops + Vector3(0, 2.4, 0), B.toon(Color(0.3, 0.7, 0.55), 0.3, 0.04), 0, 20)
	dome.scale.y = 0.55
	B.cylinder(self, 6.0, 0.4, ops + Vector3(0, 2.3, 0), B.toon(Color(0.5, 0.52, 0.55), 0.0, 0.04), 0)
	B.cylinder(self, 0.15, 6.0, ops + Vector3(0, 6.0, 0), metal, 0)
	B.sphere(self, 0.5, ops + Vector3(0, 9.0, 0), B.glow(Color(0.3, 1.0, 0.4), 3.0))
	_interactable(ops + Vector3(0, 0.8, 5.0), Vector3(1.4, 1.2, 0.6), "Fenton Ops Computer: save your progress", func(_p): game.save_point(), B.glow(Color(0.3, 1.0, 0.5), 1.0))
	spots["roof"] = Vector3(c.x - 4.0, roof + 0.5, c.z + 4.0)
	_sign("FENTON WORKS", Vector3(c.x, roof + 2.2, z1 + 0.4), 150, Color(0.3, 1.0, 0.45), 0.0, true)
	_landmark("Fenton Works", c, 30.0)
	_map(c, 18, 16, Color(0.3, 0.8, 0.45))


# --- Landmarks ---------------------------------------------------------------
func _casper_high(c: Vector3) -> void:
	var mat := B.building_mat(Color(0.82, 0.72, 0.55), false)
	var heights := _hollow(c, 52, 30, 2, 5.0, mat, "south", 5.0, true)
	var gf: float = heights[0]
	# Cafeteria tables + lockers.
	for k in 4:
		for m in 2:
			B.box(self, Vector3(6, 0.8, 1.6), Vector3(c.x - 16 + k * 8.0, gf + 0.4, c.z - 6 + m * 6.0), B.toon(Color(0.7, 0.7, 0.72), 0.0, 0.02))
	for k in 12:
		B.box(self, Vector3(1.0, 2.2, 0.6), Vector3(c.x + 6 + k * 1.05, gf + 1.1, c.z - 14.4), B.toon(Color(0.3, 0.45, 0.75), 0.0, 0.02))
	B.box(self, Vector3(6, 1.1, 1.0), Vector3(c.x - 16, gf + 0.55, c.z - 13.5), B.toon(Color(0.85, 0.85, 0.85), 0.0, 0.02))
	B.label(self, "CAFETERIA", Vector3(c.x - 14, gf + 4.0, c.z - 14.6), 48, Color(1, 0.9, 0.5), false, 0.015)
	_sign("CASPER HIGH", Vector3(c.x, gf + 11.5, c.z + 15.4), 170, Color(0.95, 0.9, 0.6))
	B.cylinder(self, 0.12, 12.0, c + Vector3(-22, 6.0, 20), B.toon(Color(0.8, 0.8, 0.82)), 0)
	B.box(self, Vector3(2.4, 1.4, 0.05), c + Vector3(-20.8, 11.2, 20), B.toon(Color(0.2, 0.3, 0.7)), 0)
	school_spot = Vector3(c.x, SLAB, c.z + 22)
	spots["casper"] = school_spot
	spots["cafeteria"] = Vector3(c.x - 12, gf + 0.2, c.z - 4)
	artifact_spots.append(Vector3(c.x + 20, gf + 10.6, c.z - 10))
	_landmark("Casper High", c, 45.0)


func _sports_field(c: Vector3) -> void:
	B.box(self, Vector3(50, 0.05, 30), c + Vector3(0, SLAB + 0.03, 0), B.toon(Color(0.25, 0.6, 0.28)), 0)
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(0.4, 0.06, 30), c + Vector3(s * 22, SLAB + 0.06, 0), B.toon(Color(0.95, 0.95, 0.95)), 0)
		B.cylinder(self, 0.15, 6.0, c + Vector3(s * 24, SLAB + 3.0, -3), B.toon(Color(0.95, 0.85, 0.2)), 0)
		B.cylinder(self, 0.15, 6.0, c + Vector3(s * 24, SLAB + 3.0, 3), B.toon(Color(0.95, 0.85, 0.2)), 0)
		B.box(self, Vector3(0.3, 0.3, 6.0), c + Vector3(s * 24, SLAB + 2.5, 0), B.toon(Color(0.95, 0.85, 0.2)), 0)
	for k in 4:
		B.box(self, Vector3(40, 0.8, 1.6), c + Vector3(0, SLAB + 0.4 + k * 0.8, -19 - k * 1.6), B.toon(Color(0.6, 0.62, 0.65), 0.0, 0.02))
	_map(c, 50, 30, Color(0.3, 0.65, 0.3))
	event_spots.append(c + Vector3(0, SLAB, 0))


func _nasty_burger(c: Vector3) -> void:
	var mat := B.building_mat(Color(0.85, 0.3, 0.2), false)
	var heights := _hollow(c, 22, 16, 1, 5.0, mat, "south", 4.0, true)
	var gf: float = heights[0]
	B.box(self, Vector3(12, 1.2, 1.2), Vector3(c.x, gf + 0.6, c.z - 4.5), B.toon(Color(0.95, 0.8, 0.2), 0.0, 0.03))
	for k in 3:
		B.box(self, Vector3(3, 0.8, 1.6), Vector3(c.x - 6 + k * 6, gf + 0.4, c.z + 3.5), B.toon(Color(0.8, 0.15, 0.15), 0.0, 0.03))
	B.label(self, "MENU\nNasty Burger .. $2\nNasty Fries .... $1\nNasty Shake .... $1", Vector3(c.x, gf + 3.4, c.z - 7.6), 28, Color(1, 1, 0.8), false, 0.01)
	# The giant burger on the roof.
	var top := gf + 5.4
	B.cylinder(self, 6.0, 1.4, Vector3(c.x, top + 0.7, c.z), B.toon(Color(0.85, 0.6, 0.3), 0.0, 0.05), B.L_WORLD)
	B.cylinder(self, 6.4, 0.5, Vector3(c.x, top + 1.65, c.z), B.toon(Color(0.3, 0.75, 0.25), 0.0, 0.04), 0)
	B.cylinder(self, 6.1, 1.2, Vector3(c.x, top + 2.4, c.z), B.toon(Color(0.45, 0.25, 0.15), 0.0, 0.05), B.L_WORLD)
	var bun := B.sphere(self, 6.0, Vector3(c.x, top + 3.0, c.z), B.toon(Color(0.9, 0.62, 0.3), 0.0, 0.05), 0, 20)
	bun.scale.y = 0.5
	_sign("NASTY BURGER", Vector3(c.x, gf + 4.4, c.z + 8.3), 110, Color(1.0, 0.85, 0.2), 0.0, true)
	spots["nasty"] = Vector3(c.x, SLAB, c.z + 14)
	artifact_spots.append(Vector3(c.x, top + 6.2, c.z))
	_landmark("Nasty Burger", c, 30.0)
	for off in [Vector3(-24, 0, -18), Vector3(24, 0, -18), Vector3(-24, 0, 18), Vector3(24, 0, 18)]:
		_tower(c + off, 14, 14, 3.8 * rng.randi_range(1, 3), Color(0.7, 0.65, 0.55))


func _park(c: Vector3) -> void:
	for k in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(12, 28)
		_tree(c + Vector3(cos(a) * r, SLAB, sin(a) * r), rng.randf_range(0.7, 1.1))
	B.cylinder(self, 4.0, 0.8, c + Vector3(0, SLAB + 0.4, 0), B.toon(Color(0.7, 0.7, 0.72), 0.0, 0.03), B.L_WORLD)
	B.cylinder(self, 3.6, 0.1, c + Vector3(0, SLAB + 0.8, 0), B.toon(Color(0.3, 0.55, 0.9), 0.3), 0)
	B.cylinder(self, 0.4, 2.5, c + Vector3(0, SLAB + 1.6, 0), B.toon(Color(0.7, 0.7, 0.72)), 0)
	# Concert stage on the north side (Ember's concert event).
	var st := c + Vector3(0, SLAB, -22)
	B.box(self, Vector3(18, 1.2, 8), st + Vector3(0, 0.6, 0), B.toon(Color(0.2, 0.2, 0.25), 0.0, 0.04))
	B.box(self, Vector3(18, 0.6, 8), st + Vector3(0, 8.0, 0), B.toon(Color(0.25, 0.25, 0.3), 0.0, 0.04), 0)
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(0.5, 8, 0.5), st + Vector3(s * 8.8, 4.0, 3.6), B.toon(Color(0.3, 0.3, 0.32)), B.L_WORLD)
	stage_spot = st
	_map(c, 60, 60, Color(0.3, 0.6, 0.32))
	_landmark("Amity Park Commons", c, 32.0)
	event_spots.append(c + Vector3(0, SLAB, 14))


func _city_hall(c: Vector3) -> void:
	var mat := B.building_mat(Color(0.88, 0.86, 0.8), false)
	var heights := _hollow(c, 40, 26, 2, 6.0, mat, "south", 5.0, true)
	var gf: float = heights[0]
	for k in 8:
		B.cylinder(self, 0.6, 10.0, Vector3(c.x - 14 + k * 4.0, gf + 5.0, c.z + 15.5), B.toon(Color(0.92, 0.9, 0.86), 0.0, 0.03), B.L_WORLD, -1.0, 12)
	B.box(self, Vector3(36, 1.0, 4), Vector3(c.x, gf + 10.5, c.z + 15.5), B.toon(Color(0.9, 0.88, 0.84), 0.0, 0.03), 0)
	var dome := B.sphere(self, 8.0, Vector3(c.x, gf + 12.4, c.z), B.toon(Color(0.4, 0.65, 0.55), 0.0, 0.05), B.L_WORLD, 20)
	dome.scale.y = 0.7
	B.box(self, Vector3(8, 1.0, 1.4), Vector3(c.x, gf + 0.5, c.z - 8), B.toon(Color(0.45, 0.3, 0.2), 0.0, 0.03))
	B.label(self, "MAYOR'S OFFICE", Vector3(c.x, gf + 9.5, c.z - 12.6), 40, Color(1, 0.9, 0.6), false, 0.012)
	_sign("CITY HALL", Vector3(c.x, gf + 12.0, c.z + 17.6), 130, Color(0.95, 0.95, 0.9))
	artifact_spots.append(Vector3(c.x, gf + 18.2, c.z))
	_landmark("City Hall", c, 32.0)


func _museum(c: Vector3) -> void:
	var mat := B.building_mat(Color(0.78, 0.74, 0.66), false)
	var heights := _hollow(c, 44, 30, 1, 9.0, mat, "south", 6.0, true)
	var gf: float = heights[0]
	for k in 6:
		B.cylinder(self, 0.7, 9.0, Vector3(c.x - 15 + k * 6.0, gf + 4.5, c.z + 17.5), B.toon(Color(0.88, 0.85, 0.8), 0.0, 0.03), B.L_WORLD, -1.0, 12)
	var ped := PrismMesh.new()
	ped.size = Vector3(40, 4, 5)
	B.mesh_instance(self, ped, Vector3(c.x, gf + 11.4, c.z + 17.5), B.toon(Color(0.85, 0.82, 0.76), 0.0, 0.05))
	for k in 5:
		var p := Vector3(c.x - 14 + k * 7.0, gf, c.z - 4)
		B.box(self, Vector3(1.6, 1.2, 1.6), p + Vector3(0, 0.6, 0), B.toon(Color(0.3, 0.25, 0.22), 0.0, 0.02))
		B.sphere(self, 0.45, p + Vector3(0, 1.7, 0), B.glow(Color(0.5, 1.0, 0.6).lerp(Color(0.7, 0.3, 1.0), k / 4.0), 2.0), 0, 10)
	# Dinosaur skeleton.
	var bone := B.toon(Color(0.92, 0.9, 0.82), 0.0, 0.02)
	B.box(self, Vector3(2.0, 1.6, 8.0), Vector3(c.x, gf + 4.0, c.z + 6), bone, 0)
	var neck := B.box(self, Vector3(1.2, 1.2, 3.0), Vector3(c.x, gf + 5.5, c.z + 1.0), bone, 0)
	neck.rotation.x = 0.5
	B.box(self, Vector3(1.6, 1.4, 2.4), Vector3(c.x, gf + 6.4, c.z - 0.6), bone, 0)
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(0.6, 3.4, 0.8), Vector3(c.x + s * 0.9, gf + 1.7, c.z + 6), bone, 0)
	_sign("AMITY PARK MUSEUM", Vector3(c.x, gf + 14.2, c.z + 15.4), 110, Color(0.95, 0.92, 0.8))
	artifact_spots.append(Vector3(c.x + 14, gf + 0.2, c.z - 10))
	_landmark("Amity Park Museum", c, 32.0)


func _axion_labs(c: Vector3) -> void:
	var glass := B.building_mat(Color(0.45, 0.6, 0.72), true, Vector2(2.5, 3.6))
	_tower(c + Vector3(14, 0, -10), 24, 24, 48.0, Color(0.45, 0.6, 0.72))
	var heights := _hollow(c + Vector3(-12, 0, 14), 30, 22, 1, 7.0, glass, "south", 5.0, true)
	var gf: float = heights[0]
	for k in 5:
		B.box(self, Vector3(1.2, 3.0, 1.2), c + Vector3(-22 + k * 3.0, gf + 1.5, 8), B.toon(Color(0.15, 0.17, 0.2), 0.0, 0.02))
		B.box(self, Vector3(1.0, 0.15, 0.05), c + Vector3(-22 + k * 3.0, gf + 2.2, 7.38), B.glow(Color(0.3, 1.0, 0.4), 3.0), 0)
	B.box(self, Vector3(6, 1.1, 1.4), c + Vector3(-12, gf + 0.55, 20), B.toon(Color(0.8, 0.82, 0.85), 0.0, 0.03))
	var dome := B.sphere(self, 9.0, c + Vector3(-14, SLAB, -14), B.toon(Color(0.7, 0.75, 0.8), 0.2, 0.05), B.L_WORLD, 20)
	dome.scale.y = 0.7
	_sign("AXION LABS", Vector3(c.x - 12, gf + 9.0, c.z + 25.4), 130, Color(0.5, 0.85, 1.0), 0.0, true)
	spots["axion_roof"] = c + Vector3(14, SLAB + 48.4, -10)
	spots["axion"] = c + Vector3(-12, SLAB, 30)
	substation_spot = c + Vector3(-22, SLAB, -26)
	B.box(self, Vector3(10, 0.4, 8), substation_spot + Vector3(0, 0.2, 0), B.toon(Color(0.5, 0.5, 0.5)), 0)
	_landmark("Axion Labs", c, 40.0)


func _mall(c: Vector3) -> void:
	var mat := B.building_mat(Color(0.75, 0.68, 0.78), false)
	var heights := _hollow(c, 58, 48, 1, 11.0, mat, "south", 8.0, true)
	var gf: float = heights[0]
	var shops := [["SPOOKY SOUNDS", Color(0.6, 0.3, 0.8)], ["TECH TOWN", Color(0.3, 0.6, 0.9)], ["GOTH GARB", Color(0.2, 0.2, 0.25)], ["PRETZEL PALACE", Color(0.9, 0.6, 0.2)], ["GAME GHOUL", Color(0.3, 0.8, 0.4)], ["FASHION FIENDS", Color(0.9, 0.4, 0.6)]]
	for k in shops.size():
		var x := c.x - 22 + k * 8.8
		B.box(self, Vector3(7.5, 4.0, 0.3), Vector3(x, gf + 2.0, c.z - 22.0), B.toon(shops[k][1], 0.2, 0.02), 0)
		B.label(self, shops[k][0], Vector3(x, gf + 4.6, c.z - 21.7), 36, Color(1, 1, 1), false, 0.012)
	B.cylinder(self, 5.0, 1.0, Vector3(c.x, gf + 0.5, c.z), B.toon(Color(0.7, 0.72, 0.75), 0.0, 0.03), B.L_WORLD)
	B.cylinder(self, 4.5, 0.1, Vector3(c.x, gf + 1.0, c.z), B.toon(Color(0.3, 0.55, 0.9), 0.3), 0)
	for k in 6:
		var lt := OmniLight3D.new()
		lt.omni_range = 18.0
		lt.light_energy = 0.8
		lt.position = Vector3(c.x - 20 + (k % 3) * 20, gf + 9.0, c.z - 10 + (k / 3) * 20)
		add_child(lt)
	_sign("AMITY PARK MALL", Vector3(c.x, gf + 13.0, c.z + 24.4), 150, Color(1.0, 0.8, 0.95), 0.0, true)
	spots["mall"] = Vector3(c.x, gf + 0.2, c.z + 4)
	artifact_spots.append(Vector3(c.x + 24, gf + 0.2, c.z + 18))
	_landmark("Amity Park Mall", c, 40.0)


func _lake_eerie() -> void:
	var z0 := -GRID * PITCH - 40.0
	B.box(self, Vector3(560, 0.4, 150), Vector3(-60, 0.15, z0 - 110), B.glow(Color(0.15, 0.35, 0.55), 0.3, 0.8), 0)
	_map(Vector3(-60, 0, z0 - 110), 560, 150, Color(0.2, 0.4, 0.65))
	for k in 110:
		var p := Vector3(rng.randf_range(-600, 600), 0, rng.randf_range(z0 - 10, z0 + 30))
		if rng.randf() < 0.5:
			p.z = rng.randf_range(-630, z0 - 190)
		_tree(p, rng.randf_range(0.8, 1.4))
	# Cabin.
	var cab := Vector3(300, 0, z0 - 60)
	var wood := B.toon(Color(0.5, 0.33, 0.2), 0.0, 0.04)
	_wall(0, cab.x - 6, cab.x + 6, cab.z - 5, 0.0, 4.0, [[5.0, 7.0, 0.0, 2.6]], wood)
	_wall(0, cab.x - 6, cab.x + 6, cab.z + 5, 0.0, 4.0, [[3.0, 5.0, 1.2, 2.6]], wood)
	_wall(1, cab.z - 5, cab.z + 5, cab.x - 6, 0.0, 4.0, [], wood)
	_wall(1, cab.z - 5, cab.z + 5, cab.x + 6, 0.0, 4.0, [], wood)
	var roof := PrismMesh.new()
	roof.size = Vector3(13.5, 3.0, 11.5)
	B.mesh_instance(self, roof, cab + Vector3(0, 5.5, 0), B.toon(Color(0.35, 0.22, 0.15), 0.0, 0.05))
	_rbox(cab.x - 6, cab.x + 6, cab.z - 5, cab.z + 5, 4.0, 4.2, wood, B.L_PHASE)
	artifact_spots.append(cab + Vector3(0, 0.2, 0))
	# Cave in a rocky hill.
	var cave := Vector3(-380, 0, z0 - 20)
	var rock := B.toon(Color(0.42, 0.4, 0.38), 0.0, 0.05)
	_rbox(cave.x - 16, cave.x + 16, cave.z - 14, cave.z - 10, 0, 12, rock)
	_rbox(cave.x - 16, cave.x - 3, cave.z - 10, cave.z + 10, 0, 12, rock)
	_rbox(cave.x + 3, cave.x + 16, cave.z - 10, cave.z + 10, 0, 12, rock)
	_rbox(cave.x - 3, cave.x + 3, cave.z - 10, cave.z + 10, 5, 12, rock)
	var glow_light := OmniLight3D.new()
	glow_light.light_color = Color(0.3, 1.0, 0.5)
	glow_light.omni_range = 10.0
	glow_light.position = cave + Vector3(0, 2, -6)
	add_child(glow_light)
	artifact_spots.append(cave + Vector3(0, 0.2, -6))
	_landmark("Lake Eerie", Vector3(-60, 0, z0 - 60), 160.0)
	event_spots.append(Vector3(100, 0, z0 + 10))


func _giw_hq(c: Vector3) -> void:
	var white := B.building_mat(Color(0.93, 0.94, 0.96), false)
	B.box(self, Vector3(60, 18, 40), c + Vector3(0, 9, 0), white)
	B.box(self, Vector3(20, 6, 14), c + Vector3(0, 21, 0), white)
	var shield := B.glow(Color(0.95, 0.35, 0.55), 1.0, 0.25)
	# Anti-ghost perimeter: ghost-shielded fence (cannot be phased).
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(90, 7, 0.5), c + Vector3(0, 3.5, s * 35), shield, B.L_WORLD)
	B.box(self, Vector3(0.5, 7, 70), c + Vector3(-45, 3.5, 0), shield, B.L_WORLD)
	B.box(self, Vector3(0.5, 7, 28), c + Vector3(45, 3.5, -21), shield, B.L_WORLD)
	B.box(self, Vector3(0.5, 7, 28), c + Vector3(45, 3.5, 21), shield, B.L_WORLD)
	_sign("GUYS IN WHITE - RESTRICTED", Vector3(c.x + 30.4, 14, c.z), 110, Color(0.3, 0.35, 0.45), PI / 2)
	spots["giw_yard"] = c + Vector3(38, 0, 0)
	_map(c, 60, 40, Color(0.9, 0.9, 0.95))
	artifact_spots.append(c + Vector3(0, 24.2, 0))
	_landmark("Guys in White HQ", c, 55.0)


func _vlad_mansion(c: Vector3) -> void:
	var stone := B.building_mat(Color(0.55, 0.5, 0.62), true, Vector2(4.0, 4.5))
	B.box(self, Vector3(50, 16, 30), c + Vector3(0, 8, 0), stone)
	for s in [-1.0, 1.0]:
		B.cylinder(self, 6.0, 26.0, c + Vector3(s * 28, 13, 0), stone, B.L_WORLD)
		B.cylinder(self, 7.0, 8.0, c + Vector3(s * 28, 30, 0), B.toon(Color(0.85, 0.7, 0.2), 0.2, 0.05), 0, 0.0)
	var roof := PrismMesh.new()
	roof.size = Vector3(52, 8, 32)
	B.mesh_instance(self, roof, c + Vector3(0, 20, 0), B.toon(Color(0.2, 0.45, 0.3), 0.0, 0.05))
	var shield := B.glow(Color(0.95, 0.35, 0.55), 1.0, 0.25)
	B.box(self, Vector3(14, 10, 0.5), c + Vector3(0, 5, 22), shield, B.L_WORLD)
	_sign("MASTERS ESTATE", Vector3(c.x, 18, c.z + 15.4), 120, Color(0.95, 0.8, 0.3))
	B.label(self, "Ghost shield active - Chapter 4: The Plasmius Conspiracy (coming soon)", c + Vector3(0, 11, 22.6), 40, Color(1, 0.7, 0.8), false, 0.015)
	_map(c, 50, 30, Color(0.55, 0.45, 0.65))
	_landmark("Vlad's Mansion", c, 50.0)


# --- Traffic, people and the race ------------------------------------------
func _routes() -> void:
	for n in 22:
		var i0 := rng.randi_range(-GRID, GRID - 2)
		var j0 := rng.randi_range(-GRID, GRID - 2)
		var i1 := mini(i0 + rng.randi_range(1, 3), GRID)
		var j1 := mini(j0 + rng.randi_range(1, 3), GRID)
		var lane := 3.5
		var x0 := i0 * PITCH + lane
		var x1 := i1 * PITCH - lane
		var z0 := j0 * PITCH + lane
		var z1 := j1 * PITCH - lane
		# Travel so the inside of the loop is on the driver's right (right-hand traffic).
		var loop := [Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0)]
		var d: Vector3 = (loop[1] - loop[0]).normalized()
		var center := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
		if (center - loop[0]).dot(d.cross(Vector3.UP)) < 0.0:
			loop.reverse()
		car_routes.append(loop)


func spawn_life(parent: Node, count_peds: int, count_cars: int) -> void:
	for k in count_peds:
		var p: CharacterBody3D = Pedestrian.new()
		p.route = ped_routes[rng.randi() % ped_routes.size()]
		p.game = game
		p.rng.seed = rng.randi()
		p.position = p.route[rng.randi() % p.route.size()] + Vector3(0, 0.1, 0)
		parent.add_child(p)
	for k in count_cars:
		var car: AnimatableBody3D = Car.new()
		car.route = car_routes[k % car_routes.size()]
		car.game = game
		car.cruise = rng.randf_range(9.0, 14.0)
		parent.add_child(car)


func spawn_students(parent: Node, count: int) -> Array:
	var made: Array = []
	for k in count:
		var p: CharacterBody3D = Pedestrian.new()
		var c := school_spot + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-2, 6))
		p.route = [c, c + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-3, 3))]
		p.game = game
		p.rng.seed = rng.randi()
		p.position = c + Vector3(0, 0.1, 0)
		parent.add_child(p)
		made.append(p)
	return made


func _race_course() -> void:
	var start := Vector3(40, 14, 245)
	race_points = [start,
		Vector3(40, 30, 160), Vector3(-30, 45, 80), Vector3(-40, 70, -40),
		Vector3(40, 95, -120), Vector3(120, 60, -200), Vector3(200, 35, -120),
		Vector3(160, 25, -10), Vector3(120, 18, 80), Vector3(60, 22, 160)]


func district_at(p: Vector3) -> String:
	for l in landmarks:
		if Vector2(p.x - l["pos"].x, p.z - l["pos"].z).length() < l["radius"]:
			return l["name"]
	if p.z < -GRID * PITCH:
		return "Lake Eerie Woods"
	if absf(p.x) > GRID * PITCH or absf(p.z) > GRID * PITCH:
		return "Outskirts"
	var i := int(floor(p.x / PITCH))
	var j := int(floor(p.z / PITCH))
	match _block_kind(i, j):
		"downtown":
			return "Downtown"
		"residential", "fenton":
			return "Residential District"
		_:
			return "Midtown"
