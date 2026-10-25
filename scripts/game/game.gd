extends Node3D
## Top-level game: builds both realms, the player, HUD and menus; runs the
## day/night cycle, realm travel, interactions, dialogue, secret-identity
## suspicion, and spawning.

const B := preload("res://scripts/util/builder.gd")
const AmityPark := preload("res://scripts/world/amity_park.gd")
const GhostZone := preload("res://scripts/world/ghost_zone.gd")
const Player := preload("res://scripts/player/player.gd")
const Enemy := preload("res://scripts/enemies/ghost_enemy.gd")
const Boss := preload("res://scripts/enemies/boss.gd")
const NPC := preload("res://scripts/world/npc.gd")
const Portal := preload("res://scripts/world/portal.gd")
const Artifact := preload("res://scripts/world/artifact.gd")
const Race := preload("res://scripts/world/race.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Missions := preload("res://scripts/game/mission_manager.gd")
const Director := preload("res://scripts/game/event_director.gd")
const GZ_SKY := preload("res://shaders/ghost_zone_sky.gdshader")

const DAY_SECONDS := 900.0   # one in-game day = 15 real minutes

var amity: Node3D
var ghost_zone: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var missions: Node
var director: Node
var race: Node3D
var realm := "amity"
var district := "Fenton Works"
var npcs := {}
var interact_target: Node = null

var env: Environment
var sun: DirectionalLight3D
var day_sky: ProceduralSkyMaterial
var gz_sky_mat: ShaderMaterial
var day_sky_res: Sky
var gz_sky_res: Sky
var time_of_day := 16.0
var day_count := 1
var night := 0.0
var suspicion := 0.0

var waypoint := Vector3.ZERO
var waypoint_text := ""
var waypoint_realm := "amity"
var waypoint_active := false
var _race_waypoint := false

var _dialog: Array = []
var _dialog_done: Callable
var _dialog_cd := 0.0
var _sense_until := 0.0
var _travel_cd := 0.0
var _tick := 0.0
var _last_hour := -1
var _students: Array = []
var _respawning := false


func _ready() -> void:
	add_to_group("game")
	if GameState.pending_new_game:
		GameState.reset()
		GameState.pending_new_game = false
	_setup_environment()

	amity = AmityPark.new()
	amity.name = "AmityPark"
	amity.build(self)
	add_child(amity)
	ghost_zone = GhostZone.new()
	ghost_zone.name = "GhostZone"
	ghost_zone.build(self)

	player = Player.new()
	player.game = self
	amity.add_child(player)
	var start: Vector3 = amity.spots["bedroom"] if GameState.story_chapter == 1 and GameState.story_step == 0 else amity.spots["livingroom"]
	player.teleport(start, PI)

	_populate_amity()
	_populate_ghost_zone()

	hud = HUD.new()
	hud.game = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.game = self
	add_child(pause_menu)
	missions = Missions.new()
	missions.game = self
	add_child(missions)
	director = Director.new()
	director.game = self
	add_child(director)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_day(0.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoshot"):
			var shots: Node = load("res://scripts/dev/autoshot.gd").new()
			shots.game = self
			shots.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(shots)
		if a == "--autotest":
			GameState.reset()
			var test: Node = load("res://scripts/dev/autotest.gd").new()
			test.game = self
			add_child(test)
	hud.toast("Welcome to Amity Park, %s. [Esc] opens the Fenton OS menu." % GameState.look.get("name", "Phantom"), Color(0.7, 1.0, 0.8))


func _exit_tree() -> void:
	# The inactive realm lives outside the tree; free it with the game.
	for r in [amity, ghost_zone]:
		if is_instance_valid(r) and not r.is_inside_tree():
			r.free()


# --- Setup ---------------------------------------------------------------------
func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	day_sky = ProceduralSkyMaterial.new()
	day_sky.sky_curve = 0.12
	day_sky.ground_bottom_color = Color(0.2, 0.3, 0.22)
	day_sky.ground_horizon_color = Color(0.55, 0.65, 0.7)
	day_sky_res = Sky.new()
	day_sky_res.sky_material = day_sky
	gz_sky_mat = ShaderMaterial.new()
	gz_sky_mat.shader = GZ_SKY
	gz_sky_res = Sky.new()
	gz_sky_res.sky_material = gz_sky_mat
	env.sky = day_sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.tonemap_white = 1.4
	env.fog_enabled = true
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.3
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.light_energy = 1.2
	add_child(sun)


func _make_npc(id: String, display: String, colors: Dictionary, pos: Vector3, parent: Node3D, height := 1.0, yaw := 0.0) -> Node3D:
	var n: StaticBody3D = NPC.new()
	n.npc_id = id
	n.display_name = display
	n.colors = colors
	n.height = height
	n.game = self
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	npcs[id] = n
	return n


func _populate_amity() -> void:
	var s: Dictionary = amity.spots
	var portal: Area3D = Portal.new()
	portal.game = self
	portal.target_realm = "ghost_zone"
	portal.target_spot = "spawn"
	portal.radius = 2.6
	portal.label_text = ""
	portal.position = s["portal"]
	amity.add_child(portal)
	# Hidden temporary rifts that also lead into the Ghost Zone.
	for p in [amity.spots["casper"] + Vector3(-30, 0.5, 30), Vector3(-380, 3, -440 - 26)]:
		var rift: Area3D = Portal.new()
		rift.game = self
		rift.style = "door"
		rift.target_realm = "ghost_zone"
		rift.target_spot = "spawn"
		rift.radius = 2.2
		rift.label_text = "UNSTABLE RIFT"
		rift.position = p + Vector3(0, 2.2, 0)
		amity.add_child(rift)
	_make_npc("jack", "Jack Fenton", {"skin": Color(0.95, 0.8, 0.68), "shirt": Color(0.95, 0.5, 0.15), "pants": Color(0.95, 0.5, 0.15), "hair": Color(0.15, 0.12, 0.1), "long_sleeves": true}, s["lab"] + Vector3(-3, 0, -2), amity, 1.15, PI)
	_make_npc("maddie", "Maddie Fenton", {"skin": Color(0.95, 0.8, 0.68), "shirt": Color(0.2, 0.3, 0.75), "pants": Color(0.2, 0.3, 0.75), "hair": Color(0.45, 0.22, 0.12), "long_sleeves": true}, s["lab"] + Vector3(5, 0, -3), amity, 1.0, PI)
	_make_npc("jazz", "Jazz Fenton", {"skin": Color(0.96, 0.82, 0.7), "shirt": Color(0.2, 0.2, 0.25), "pants": Color(0.15, 0.4, 0.75), "hair": Color(0.85, 0.35, 0.15)}, s["livingroom"] + Vector3(3, 0, -1), amity, 1.0, PI)
	_make_npc("sam", "Sam Manson", {"skin": Color(0.97, 0.88, 0.82), "shirt": Color(0.12, 0.1, 0.14), "pants": Color(0.35, 0.15, 0.4), "hair": Color(0.06, 0.05, 0.08), "shoes": Color(0.1, 0.1, 0.12)}, s["nasty"] + Vector3(-2, 0, 0), amity, 0.97)
	_make_npc("tucker", "Tucker Foley", {"skin": Color(0.45, 0.3, 0.2), "shirt": Color(0.95, 0.85, 0.25), "pants": Color(0.3, 0.45, 0.3), "hair": Color(0.85, 0.15, 0.15)}, s["nasty"] + Vector3(2, 0, 0), amity, 0.97)
	_make_npc("lancer", "Mr. Lancer", {"skin": Color(0.93, 0.78, 0.65), "shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.3, 0.3, 0.35), "hair": Color(0.93, 0.78, 0.65), "long_sleeves": true}, amity.school_spot + Vector3(6, 0, -4), amity, 1.05)
	for i in amity.artifact_spots.size():
		_artifact("amity_%d" % i, amity.artifact_spots[i], amity)
	amity.spawn_life(amity, 46, 18)
	race = Race.new()
	race.game = self
	race.points = amity.race_points
	amity.add_child(race)
	# Guys in White HQ guards.
	for i in 3:
		var e: Node = spawn_enemy("giw", amity.spots["giw_yard"] + Vector3(0, 1, -20 + i * 20), amity)
		e.leash = 60.0


func _populate_ghost_zone() -> void:
	var s: Dictionary = ghost_zone.spots
	var portal: Area3D = Portal.new()
	portal.game = self
	portal.target_realm = "amity"
	portal.target_spot = "portal_exit"
	portal.radius = 4.0
	portal.label_text = "PORTAL TO AMITY PARK"
	portal.position = s["portal"]
	ghost_zone.add_child(portal)
	for p in ghost_zone.door_portals:
		var d: Area3D = Portal.new()
		d.game = self
		d.style = "door"
		d.target_realm = "amity"
		d.target_spot = "random_roof"
		d.radius = 2.2
		d.label_text = "DOOR TO AMITY?"
		d.position = p
		ghost_zone.add_child(d)
	_make_npc("frostbite", "Frostbite", {"skin": Color(0.92, 0.96, 1.0), "shirt": Color(0.92, 0.96, 1.0), "pants": Color(0.85, 0.9, 0.95), "hair": Color(0.95, 0.97, 1.0), "shoes": Color(0.7, 0.8, 0.9), "long_sleeves": true}, s["frostbite"], ghost_zone, 2.0)
	for i in ghost_zone.artifact_spots.size():
		_artifact("gz_%d" % i, ghost_zone.artifact_spots[i], ghost_zone)


func _artifact(id: String, pos: Vector3, parent: Node3D) -> void:
	if GameState.artifacts.has(id):
		return
	var a: Area3D = Artifact.new()
	a.artifact_id = id
	a.position = pos
	parent.add_child(a)


func total_artifacts() -> int:
	return amity.artifact_spots.size() + ghost_zone.artifact_spots.size()


# --- Spawning ----------------------------------------------------------------------
func realm_root() -> Node3D:
	return amity if realm == "amity" else ghost_zone


func spawn_enemy(kind: String, pos: Vector3, parent: Node = null) -> Node:
	var e: CharacterBody3D = Enemy.new()
	e.kind = kind
	e.position = pos
	e.home = pos
	(parent if parent else realm_root()).add_child(e)
	return e


func spawn_boss(id: String, pos: Vector3) -> Node:
	var b: CharacterBody3D = Boss.new()
	b.boss_id = id
	b.game = self
	b.position = pos
	b.home = pos
	realm_root().add_child(b)
	return b


func active_boss() -> Node:
	for b in get_tree().get_nodes_in_group("bosses"):
		if b.is_inside_tree() and b.is_alive() and b.global_position.distance_to(player.global_position) < 200.0:
			return b
	return null


# --- Queries for HUD ---------------------------------------------------------------
func input_blocked() -> bool:
	return not _dialog.is_empty() or pause_menu.visible


func sense_active() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _sense_until


func ectoplasm_near() -> bool:
	var r := 60.0 if not GameState.has_tech("scanner") else 110.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_inside_tree() and e.kind != "giw" and e.global_position.distance_to(player.global_position) < r:
			return true
	return false


func city_status() -> String:
	if realm != "amity":
		return "Unknown dimension"
	if director and director.is_active():
		return "UNDER ATTACK"
	if active_boss():
		return "Ghost Emergency"
	if ectoplasm_near():
		return "Ghost Activity"
	return "Safe"


func time_text() -> String:
	if realm != "amity":
		return "Time flows strangely here..."
	var h := int(time_of_day) % 24
	var m := int(fmod(time_of_day, 1.0) * 60.0)
	return "Day %d · %02d:%02d %s" % [day_count, h, m, "(night)" if night > 0.5 else ""]


# --- Waypoints ------------------------------------------------------------------
func set_waypoint(pos: Vector3, text: String, wp_realm := "amity") -> void:
	if race and race.active and not text.begins_with("Checkpoint"):
		return
	waypoint = pos
	waypoint_text = text
	waypoint_realm = wp_realm
	waypoint_active = true
	_race_waypoint = text.begins_with("Checkpoint")


func clear_waypoint() -> void:
	waypoint_active = false


func clear_race_waypoint() -> void:
	_race_waypoint = false
	waypoint_active = false
	missions._update_waypoint()


func director_waypoint_ok() -> bool:
	return not (race and race.active) and not missions.blocking_events()


# --- Events from the player ------------------------------------------------------
func on_player_transform(to_ghost: bool) -> void:
	missions.on_transform(to_ghost)
	if realm != "amity":
		return
	var witnesses := 0
	for p in get_tree().get_nodes_in_group("pedestrians"):
		if p.is_witness() and p.global_position.distance_to(player.global_position) < 28.0:
			witnesses += 1
	if witnesses > 0:
		suspicion = minf(100.0, suspicion + 12.0 * witnesses)
		hud.toast("%d witness%s saw you transform! Your secret identity is at risk." % [witnesses, "" if witnesses == 1 else "es"], Color(1.0, 0.8, 0.4))


func on_ghost_sense(r: float) -> void:
	_sense_until = Time.get_ticks_msec() / 1000.0 + 6.0
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_inside_tree() and e.global_position.distance_to(player.global_position) < r:
			n += 1
	hud.toast("Ghost Sense: %d ghost%s within %dm" % [n, "" if n == 1 else "s", int(r)] if n > 0 else "Ghost Sense: all quiet.", Color(0.6, 0.85, 1.0))


func on_enemy_frozen() -> void:
	missions.on_freeze()


func on_player_damaged(amount: float) -> void:
	hud.flash_damage(amount)


func on_player_died() -> void:
	if _respawning:
		return
	_respawning = true
	hud.show_banner("KNOCKED OUT", "Waking up at Fenton Works...", 3.0)
	var lost := GameState.thermos.size()
	GameState.thermos.clear()
	if lost > 0:
		hud.toast("The Fenton Thermos popped open - %d ghost(s) escaped!" % lost, Color(1, 0.6, 0.5))
	missions.on_player_died()
	await get_tree().create_timer(3.0).timeout
	if realm != "amity":
		_do_travel("amity", "livingroom")
	player.revive(amity.spots["livingroom"])
	_respawning = false


func talk_to(npc: Node) -> void:
	start_dialog(missions.dialog_for(npc.npc_id), func() -> void: missions.on_talked(npc.npc_id))


func start_dialog(lines: Array, on_done: Callable = Callable()) -> void:
	if lines.is_empty():
		return
	_dialog = lines.duplicate()
	_dialog_done = on_done
	_dialog_cd = 0.25
	hud.show_dialog(_dialog[0][0], _dialog[0][1])


func _advance_dialog() -> void:
	_dialog.pop_front()
	_dialog_cd = 0.2
	if _dialog.is_empty():
		hud.hide_dialog()
		if _dialog_done.is_valid():
			_dialog_done.call()
	else:
		hud.show_dialog(_dialog[0][0], _dialog[0][1])


func deposit_thermos() -> void:
	if GameState.thermos.is_empty():
		hud.toast("The Fenton Thermos is empty. Weaken a ghost, then hold [E] to capture it.", Color(0.7, 0.9, 1.0))
		return
	var ghosts: Array = GameState.thermos.duplicate()
	GameState.contained.append_array(ghosts)
	GameState.thermos.clear()
	GameState.add_xp(10 * ghosts.size(), "Contained %d ghost(s)" % ghosts.size())
	hud.toast("Contained: %s" % ", ".join(PackedStringArray(ghosts)), Color(0.5, 1.0, 0.7))
	missions.on_deposit(ghosts)
	GameState.save_game()


func save_point() -> void:
	GameState.save_game()
	hud.toast("Progress saved to the Fenton Ops Computer.", Color(0.5, 1.0, 0.7))


func open_menu(tab := "story") -> void:
	pause_menu.open(tab)


# --- Realm travel ---------------------------------------------------------------
func travel(target: String, spot: String) -> void:
	if _travel_cd > 0.0 or player.dead:
		return
	_travel_cd = 3.0
	call_deferred("_do_travel", target, spot)


func _do_travel(target: String, spot: String) -> void:
	var to_root: Node3D = amity if target == "amity" else ghost_zone
	var from_root: Node3D = realm_root()
	player.end_overshadow()
	if player.get_parent():
		player.get_parent().remove_child(player)
	if from_root != to_root:
		remove_child(from_root)
		add_child(to_root)
	realm = target
	to_root.add_child(player)
	player.camera.current = true
	var pos: Vector3
	if spot == "random_roof":
		pos = amity.artifact_spots[randi() % amity.artifact_spots.size()] + Vector3(3, 2, 3)
	else:
		pos = to_root.spots.get(spot, Vector3(0, 2, 0))
	player.teleport(pos, 0.0)
	player.realm = target
	player.gravity_scale = 1.0 if target == "amity" else 0.35
	if target == "ghost_zone" and not player.ghost and not player.dead:
		hud.toast("You feel lighter here... ghost form is recommended. [G]", Color(0.7, 1.0, 0.8))
	_apply_realm_environment()
	hud.flash_travel()
	hud.show_banner("THE GHOST ZONE" if target == "ghost_zone" else "AMITY PARK", "", 2.5)
	missions.on_travel(target)
	interact_target = null


func _apply_realm_environment() -> void:
	if realm == "amity":
		env.sky = day_sky_res
		env.fog_density = 0.0009
		sun.shadow_enabled = true
		_update_day(0.0)
	else:
		env.sky = gz_sky_res
		env.fog_light_color = Color(0.15, 0.45, 0.25)
		env.fog_density = 0.0028
		env.ambient_light_energy = 0.6
		sun.light_color = Color(0.75, 1.0, 0.85)
		sun.light_energy = 0.8
		sun.rotation_degrees = Vector3(-60, 40, 0)
		RenderingServer.global_shader_parameter_set("night_factor", 0.6)


# --- Day / night -----------------------------------------------------------------
func _update_day(delta: float) -> void:
	time_of_day += delta * 24.0 / DAY_SECONDS
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day_count += 1
	var t := time_of_day
	var day := clampf(sin((t - 6.0) / 12.0 * PI) * 1.6 + 0.15, 0.0, 1.0) if t > 5.0 and t < 19.0 else 0.0
	night = 1.0 - day
	if realm != "amity":
		return
	var dusk := clampf(1.0 - absf(day - 0.35) * 3.0, 0.0, 1.0)
	if t < 5.0 or t > 19.0:
		dusk = 0.0
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.22, 0.45, 0.88), day)
	var horizon := Color(0.07, 0.09, 0.18).lerp(Color(0.68, 0.8, 0.95), day).lerp(Color(0.98, 0.55, 0.35), dusk * 0.7)
	day_sky.sky_top_color = top
	day_sky.sky_horizon_color = horizon
	day_sky.ground_horizon_color = horizon.darkened(0.2)
	env.fog_light_color = horizon.darkened(0.1)
	env.ambient_light_energy = lerpf(0.3, 0.55, day)
	# Sun by day, moon by night.
	var sun_angle := (t - 6.0) / 12.0 * 180.0
	if day <= 0.0:
		sun_angle = fmod(t + 6.0, 24.0) / 12.0 * 180.0
	sun.rotation_degrees = Vector3(-clampf(sun_angle, 8.0, 172.0), 35.0, 0.0)
	sun.light_energy = lerpf(0.22, 0.95, day)
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.96, 0.9), day).lerp(Color(1.0, 0.7, 0.45), dusk * 0.6)
	var power := 0.0 if director and director.power_out else 1.0
	RenderingServer.global_shader_parameter_set("night_factor", night * power)
	amity.lamp_mat.emission_energy_multiplier = (0.2 + night * 5.0) * power
	# School schedule.
	var hour := int(t)
	if hour != _last_hour:
		_last_hour = hour
		if hour == 8:
			hud.toast("*RIIING* The first bell rings at Casper High.", Color(1, 0.95, 0.7))
		elif hour == 15:
			hud.toast("*RIIING* School's out at Casper High!", Color(1, 0.95, 0.7))
		elif hour == 20:
			hud.toast("Night falls on Amity Park. Ghost activity is rising...", Color(0.75, 0.6, 1.0))
		var school := hour >= 8 and hour < 15
		if school and _students.is_empty():
			_students = amity.spawn_students(amity, 12)
		elif not school and not _students.is_empty():
			for s in _students:
				if is_instance_valid(s):
					s.queue_free()
			_students.clear()


# --- Main loop -----------------------------------------------------------------------
func _process(delta: float) -> void:
	_update_day(delta)
	_travel_cd = maxf(0.0, _travel_cd - delta)
	_dialog_cd = maxf(0.0, _dialog_cd - delta)
	suspicion = maxf(0.0, suspicion - delta * (1.5 if not player.ghost else 0.4))
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.4
		district = realm_root().district_at(player.global_position)
		for l in realm_root().landmarks:
			if Vector2(player.global_position.x - l["pos"].x, player.global_position.z - l["pos"].z).length() < l["radius"] * 0.7:
				GameState.discover(l["name"])
	_find_interactable()
	_bounds()


func _find_interactable() -> void:
	interact_target = null
	if player.dead:
		return
	var best := 3.6
	for n in get_tree().get_nodes_in_group("interactables"):
		if not n.is_inside_tree():
			continue
		var d: float = n.global_position.distance_to(player.global_position + Vector3(0, 0.9, 0))
		if d < best:
			best = d
			interact_target = n


func _bounds() -> void:
	var p := player.global_position
	if realm == "amity":
		var lim: float = amity.WORLD_HALF - 15.0
		if absf(p.x) > lim or absf(p.z) > lim:
			player.velocity += Vector3(-signf(p.x) if absf(p.x) > lim else 0.0, 0, -signf(p.z) if absf(p.z) > lim else 0.0) * 4.0
		if p.y > 420.0:
			player.velocity.y = minf(player.velocity.y, -5.0)
	else:
		var flat := Vector2(p.x, p.z)
		if flat.length() > 950.0:
			var back := -flat.normalized() * 4.0
			player.velocity += Vector3(back.x, 0, back.y)
		if p.y > 450.0:
			player.velocity.y = minf(player.velocity.y, -5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not pause_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("pause"):
		if not _dialog.is_empty():
			return
		pause_menu.open("story")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map"):
		hud.toggle_map()
	if not _dialog.is_empty():
		if _dialog_cd <= 0.0 and (event.is_action_pressed("interact") or event.is_action_pressed("jump") or (event is InputEventMouseButton and event.pressed)):
			_advance_dialog()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and interact_target and player._find_thermos_target() == null:
		interact_target.interact(player)
		get_viewport().set_input_as_handled()
