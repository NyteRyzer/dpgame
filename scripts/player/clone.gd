extends Node3D
## Duplication: a temporary copy of the hero that flies alongside and fires
## ecto blasts at nearby ghosts. Enemies may target clones instead of you.

const B := preload("res://scripts/util/builder.gd")
const Model := preload("res://scripts/player/character_model.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")

var player: Node3D
var side := 1.0
var life := 12.0
var hits := 4
var _fire := 0.5
var model: Node3D


func _ready() -> void:
	add_to_group("player_targets")
	model = Model.new()
	add_child(model)
	model.set_form(true, true)
	model.set_alpha(0.75)
	model.anim_state = "hover"


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or not is_instance_valid(player):
		_vanish()
		return
	var basis := Basis(Vector3.UP, player.model.rotation.y)
	var want: Vector3 = player.global_position + basis.x * side * 2.2 + Vector3(0, 0.6 + sin(life * 2.0 + side) * 0.3, 1.0)
	global_position = global_position.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	model.anim_state = "fly" if player.velocity.length() > 4.0 else "hover"
	model.speed_ratio = clampf(player.velocity.length() / 19.0, 0.0, 1.0)
	model.rotation.y = lerp_angle(model.rotation.y, player.model.rotation.y, delta * 8.0)
	_fire -= delta
	if _fire <= 0.0:
		_fire = 0.55
		var target := _nearest_enemy()
		if target:
			var from: Vector3 = model.hand_position()
			var dir: Vector3 = (target.global_position + Vector3(0, 1, 0) - from)
			Projectile.spawn(get_parent(), from, dir, {"speed": 60.0, "damage": 7.0, "team": "player", "color": Color(0.3, 1.0, 0.45), "radius": 0.18, "lifetime": 2.0})
			model.aim_arm = 1.0
	model.aim_arm = lerpf(model.aim_arm, 0.0, delta * 3.0)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := 45.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best = e
			best_d = d
	return best


func take_damage(_amount: float, _from := Vector3.ZERO, _effect := "") -> void:
	hits -= 1
	if hits <= 0:
		_vanish()


func _vanish() -> void:
	if is_queued_for_deletion():
		return
	B.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.4, 1, 0.6), 20, 5.0, 0.2)
	queue_free()
