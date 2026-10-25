extends StaticBody3D
## Generic "press E" object (containment unit, Fenton computer, vault...).

const B := preload("res://scripts/util/builder.gd")

var interact_text := "Interact"
var callback: Callable


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = B.L_WORLD
	collision_mask = 0


func interact(player: Node) -> void:
	if callback.is_valid():
		callback.call(player)
