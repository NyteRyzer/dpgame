extends Node3D
## Aerial race: fly through every checkpoint ring as fast as you can.

const B := preload("res://scripts/util/builder.gd")

var points: Array = []
var game: Node = null
var active := false
var time := 0.0
var _next := 0
var _rings: Array[Node3D] = []
var _start: Node3D
var _cool := 0.0


func _ready() -> void:
	_start = _make_ring(points[0], 6.0, Color(1.0, 0.85, 0.2))
	B.label(_start, "AERIAL RACE", Vector3(0, 8, 0), 96, Color(1, 0.9, 0.4), true, 0.03)
	for i in range(1, points.size()):
		var r := _make_ring(points[i], 5.0, Color(0.3, 1.0, 0.5))
		r.visible = false
		_rings.append(r)


func _make_ring(p: Vector3, radius: float, c: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	var t := B.torus(root, radius - 0.4, radius, Vector3.ZERO, B.glow(c, 2.5, 0.8))
	t.rotation.x = PI / 2
	return root


func _physics_process(delta: float) -> void:
	_cool -= delta
	var player: Node3D = game.player if game else null
	if player == null:
		return
	var pos := player.global_position + Vector3(0, 1, 0)
	if not active:
		_start.rotation.y += delta
		if _cool <= 0.0 and pos.distance_to(_start.global_position) < 6.0:
			_begin()
		return
	time += delta
	_rings[_next].rotation.y += delta * 2.0
	if pos.distance_to(_rings[_next].global_position) < 5.5:
		B.burst(self, _rings[_next].global_position, Color(0.4, 1.0, 0.6), 30, 8.0, 0.3)
		_rings[_next].visible = false
		_next += 1
		if _next >= _rings.size():
			_finish()
		else:
			_rings[_next].visible = true
			game.set_waypoint(_rings[_next].global_position, "Checkpoint %d/%d" % [_next + 1, _rings.size()])
	if time > 180.0:
		GameState.notify.emit("Race timed out.", Color(1, 0.6, 0.6))
		_reset()


func _begin() -> void:
	active = true
	time = 0.0
	_next = 0
	_start.visible = false
	_rings[0].visible = true
	GameState.notify.emit("AERIAL RACE! Fly through every ring. Boost with Shift.", Color(1, 0.9, 0.4))
	game.set_waypoint(_rings[0].global_position, "Checkpoint 1/%d" % _rings.size())


func _finish() -> void:
	var best := GameState.race_best
	var msg := "Race complete: %.2fs" % time
	if best <= 0.0 or time < best:
		GameState.race_best = time
		msg += "  NEW RECORD!"
	GameState.notify.emit(msg, Color(1, 0.9, 0.4))
	GameState.add_xp(50 if time < 90.0 else 30, "Aerial race")
	GameState.add_reputation(1)
	_reset()


func _reset() -> void:
	active = false
	_cool = 4.0
	_start.visible = true
	for r in _rings:
		r.visible = false
	if game:
		game.clear_race_waypoint()


func race_text() -> String:
	if not active:
		return ""
	return "RACE  %.1fs   %d/%d" % [time, _next, _rings.size()]
