extends AnimatableBody3D
## Traffic: cars loop around city blocks, stop for people, panic near ghost
## fights, and can be hacked by Technus during a takeover event.

const B := preload("res://scripts/util/builder.gd")

signal destroyed(car: Node)

const COLORS := [Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.95, 0.85, 0.2), Color(0.92, 0.92, 0.94), Color(0.15, 0.15, 0.17), Color(0.2, 0.6, 0.35), Color(0.95, 0.5, 0.15)]

var route: Array = []
var game: Node = null
var cruise := 12.0
var hacked := false
var health := 45.0
var _idx := 0
var _speed := 0.0
var _honk_t := 0.0
var _label: Label3D
var _body_mat: StandardMaterial3D
var _lights: Array = []
var _hack_glow: Node3D
var _smoke: CPUParticles3D
var _hit_cd := 0.0
var _broken := false


func _ready() -> void:
	add_to_group("cars")
	collision_layer = B.L_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.4, 4.2)
	cs.shape = shape
	cs.position.y = 0.85
	add_child(cs)
	var c: Color = COLORS[randi() % COLORS.size()]
	_body_mat = B.toon_unique(c, 0.0, 0.03)
	B.box(self, Vector3(2.0, 0.8, 4.2), Vector3(0, 0.75, 0), _body_mat, 0)
	B.box(self, Vector3(1.8, 0.65, 2.2), Vector3(0, 1.45, 0.2), B.toon(Color(0.55, 0.75, 0.9), 0.15, 0.02), 0)
	for x in [-1.0, 1.0]:
		for z in [-1.35, 1.35]:
			var w := B.cylinder(self, 0.38, 0.3, Vector3(x * 0.95, 0.38, z), B.toon(Color(0.08, 0.08, 0.09), 0.0, 0.02), 0, -1.0, 12)
			w.rotation.z = PI / 2
		_lights.append(B.box(self, Vector3(0.4, 0.2, 0.05), Vector3(x * 0.65, 0.85, -2.11), B.glow(Color(1.0, 0.95, 0.75), 2.0), 0))
		B.box(self, Vector3(0.4, 0.18, 0.05), Vector3(x * 0.65, 0.85, 2.11), B.glow(Color(1.0, 0.15, 0.1), 2.0), 0)
	_label = B.label(self, "", Vector3(0, 2.6, 0), 48, Color(1, 1, 0.6), true, 0.012)
	if route.size() > 0:
		_idx = randi() % route.size()
		global_position = route[_idx]
		_idx = (_idx + 1) % route.size()
	_speed = cruise


func set_hacked(on: bool) -> void:
	hacked = on
	if on:
		add_to_group("destructibles")
		health = 45.0
		_hack_glow = B.box(self, Vector3(2.2, 1.6, 4.4), Vector3(0, 0.95, 0), B.glow(Color(0.3, 1.0, 0.4), 1.0, 0.25), 0)
		_label.text = "TECHNUS.EXE"
	else:
		remove_from_group("destructibles")
		if _hack_glow:
			_hack_glow.queue_free()
			_hack_glow = null
		_label.text = ""


func take_damage(amount: float, _from := Vector3.ZERO, _effect := "") -> void:
	if not hacked:
		return
	health -= amount
	if health <= 0.0:
		set_hacked(false)
		_broken = true
		_smoke = B.particles(self, Color(0.3, 0.3, 0.32), 20, 1.5, false, 1.5, 0.6)
		_smoke.position = Vector3(0, 1.4, -1.5)
		B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.3, 1.0, 0.4), 40, 8.0, 0.3)
		GameState.add_xp(10)
		destroyed.emit(self)
		get_tree().create_timer(15.0).timeout.connect(func() -> void:
			_broken = false
			if is_instance_valid(_smoke):
				_smoke.queue_free())


func _physics_process(delta: float) -> void:
	if route.is_empty() or _broken:
		return
	var night: float = game.night if game else 0.0
	for l in _lights:
		l.visible = night > 0.3
	_honk_t -= delta
	_hit_cd -= delta
	if _honk_t <= 0.0 and _label.text != "" and not hacked:
		_label.text = ""
	var player: Node3D = game.player if game else null
	if hacked and player:
		_chase(delta, player)
		return
	if player and player.global_position.distance_to(global_position) > 260.0:
		return
	var tgt: Vector3 = route[_idx]
	var to := tgt - global_position
	to.y = 0
	if to.length() < 1.0:
		_idx = (_idx + 1) % route.size()
		return
	var fwd := to.normalized()
	var want := cruise
	if _blocked(fwd):
		want = 0.0
	elif _danger_near():
		want = cruise * 1.6
		if _honk_t <= 0.0:
			_honk_t = 3.0
			_label.text = "HONK!"
	_speed = move_toward(_speed, want, delta * (14.0 if want < _speed else 6.0))
	global_position += fwd * minf(_speed * delta, to.length())
	var yaw := atan2(-fwd.x, -fwd.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 6.0, 0.0, 1.0))


func _blocked(fwd: Vector3) -> bool:
	var checks: Array = get_tree().get_nodes_in_group("pedestrians")
	if game and game.player:
		checks.append(game.player)
	for n in checks:
		var to: Vector3 = n.global_position - global_position
		if absf(to.y) > 3.0:
			continue
		var ahead := to.dot(fwd)
		if ahead > 0.0 and ahead < 8.0 and (to - fwd * ahead).length() < 2.0:
			return true
	for c in get_tree().get_nodes_in_group("cars"):
		if c == self:
			continue
		var to: Vector3 = c.global_position - global_position
		var ahead := to.dot(fwd)
		if ahead > 0.0 and ahead < 7.0 and (to - fwd * ahead).length() < 1.6:
			return true
	return false


func _danger_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < 30.0:
			return true
	return false


func _chase(delta: float, player: Node3D) -> void:
	var to := player.global_position - global_position
	to.y = 0
	var fwd := to.normalized()
	_speed = move_toward(_speed, 16.0, delta * 8.0)
	if to.length() > 2.0:
		global_position += fwd * _speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-fwd.x, -fwd.z), clampf(delta * 3.0, 0.0, 1.0))
	if to.length() < 3.0 and _hit_cd <= 0.0 and absf(player.global_position.y - global_position.y) < 2.5:
		_hit_cd = 1.5
		player.take_damage(12.0, global_position, "explode")
