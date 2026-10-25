extends Node
## Developer tool: a scripted tour that captures screenshots, used to verify
## rendering in CI or headless-with-display environments.
## Run: godot --path . res://scenes/game.tscn -- --autoshot=<dir>

var game: Node
var out_dir := "user://shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoshot="):
			out_dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)


func _run() -> void:
	var p: Node3D = game.player
	await _wait(90)
	await _shot("01_bedroom")
	p.teleport(game.amity.spots["lab"] + Vector3(0, 0, 3), 0.0)
	p._yaw = 0.0
	p._pitch = -0.05
	await _wait(40)
	p.toggle_ghost()
	await _wait(50)
	await _shot("02_transform_lab")
	await _wait(80)
	await _shot("03_ghost_lab")
	p.teleport(Vector3(-200, 60, 200), 0.0)
	p.flying = true
	p._yaw = -0.6
	p._pitch = -0.25
	game.time_of_day = 15.0
	await _wait(60)
	await _shot("04_city_day")
	p.teleport(Vector3(-20, 90, 60), 0.0)
	p._yaw = 0.3
	p._pitch = -0.35
	await _wait(60)
	await _shot("05_downtown")
	game.time_of_day = 22.0
	await _wait(60)
	await _shot("06_city_night")
	game.time_of_day = 13.0
	var cas: Vector3 = game.amity.spots["casper"]
	p.teleport(cas + Vector3(0, 6, 30), 0.0)
	p._yaw = 0.0
	p._pitch = -0.1
	var b: Node = game.spawn_boss("lunch_lady", cas + Vector3(0, 4, 10))
	game.spawn_enemy("minion", cas + Vector3(6, 6, 14))
	await _wait(30)
	Input.action_press("fire")
	await _wait(20)
	await _shot("07_boss_fight")
	Input.action_release("fire")
	p.teleport(Vector3(40, 3, 238), 0.0)
	p._yaw = 0.0
	p._pitch = -0.15
	await _wait(40)
	await _shot("08_nasty_burger")
	game.hud.toggle_map()
	await _wait(5)
	await _shot("09_map")
	game.hud.toggle_map()
	game.travel("ghost_zone", "spawn")
	await _wait(90)
	p._yaw = PI
	p._pitch = -0.1
	await _wait(30)
	await _shot("10_ghost_zone")
	p.teleport(Vector3(560, 30, 60), 0.0)
	p._yaw = -1.2
	await _wait(60)
	await _shot("11_far_frozen")
	game.open_menu("powers")
	await _wait(10)
	await _shot("12_menu")
	get_tree().quit()
