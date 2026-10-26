extends Control
## Title screen with a live 3D preview of your phantom and the Ghost Form
## Studio for customising it before you play.

const UI := preload("res://scripts/ui/ui_theme.gd")
const B := preload("res://scripts/util/builder.gd")
const Model := preload("res://scripts/player/character_model.gd")
const Customizer := preload("res://scripts/ui/customizer.gd")

var _model: Node3D
var _pivot: Node3D
var _menu: VBoxContainer
var _studio: PanelContainer
var _controls: PanelContainer
var _form_btn: Button
var _cam: Camera3D
var _left: Control
var _t := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.time_scale = 1.0
	get_tree().paused = false
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.04, 0.03)
	add_child(bg)

	# 3D preview in its own world.
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	svc.add_child(sv)
	var world := Node3D.new()
	sv.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/ghost_zone_sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	world.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.1
	world.add_child(light)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.3, 1.0, 0.5)
	rim.light_energy = 3.0
	rim.omni_range = 8.0
	rim.position = Vector3(-1.5, 2.5, -2.0)
	world.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(-1.1, 1.3, 3.6)
	cam.fov = 40
	world.add_child(cam)
	cam.rotation = Vector3(-0.08, 0.0, 0.0)
	_cam = cam
	# Floating platform.
	B.cylinder(world, 1.3, 0.25, Vector3(0, -0.12, 0), B.toon(Color(0.3, 0.2, 0.4), 0.2, 0.03), 0)
	var ring := B.torus(world, 1.3, 1.45, Vector3(0, 0.02, 0), B.glow(Color(0.3, 1.0, 0.5), 2.5))
	ring.scale = Vector3(1, 0.3, 1)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	_model = Model.new()
	_pivot.add_child(_model)
	_model.set_form(true, true)
	_model.anim_state = "hover"
	_pivot.position = Vector3(0, 0.15, 0)
	_pivot.rotation.y = PI + 0.5
	GameState.customization_changed.connect(func() -> void: _model.apply_look(GameState.look))

	# Title and main menu.
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 70
	left.offset_top = 70
	left.offset_right = 760
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	_left = left
	var t1 := UI.label("A SO CALLED", 34, Color(0.9, 1.0, 0.95))
	t1.add_theme_constant_override("outline_size", 8)
	var t2 := UI.label("PHANTOM", 110, UI.GREEN)
	t2.add_theme_constant_override("outline_size", 14)
	t2.add_theme_color_override("font_outline_color", Color(0.02, 0.15, 0.06))
	var sub := UI.label("An open-world ghost-hero adventure in Amity Park and the Ghost Zone", 18, Color(0.75, 0.9, 0.8))
	left.add_child(t1)
	left.add_child(t2)
	left.add_child(sub)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.custom_minimum_size = Vector2(340, 0)
	left.add_child(_menu)
	if GameState.has_save():
		_button("Continue  (Ch. %d, Lv %d)" % [GameState.story_chapter, GameState.level], _continue)
	_button("New Game", _new_game)
	_button("Ghost Form Studio", _toggle_studio)
	_button("Controls", _toggle_controls)
	_button("Quit", func() -> void: get_tree().quit())
	var foot := UI.label("Fan-made prototype inspired by Danny Phantom (Nickelodeon). Not affiliated with or endorsed by Nickelodeon/Paramount.", 13, Color(0.5, 0.6, 0.55))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 70
	foot.offset_top = -40
	add_child(foot)

	# Studio panel on the right.
	_studio = PanelContainer.new()
	_studio.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_studio.offset_left = -720
	_studio.offset_right = -40
	_studio.offset_top = 40
	_studio.offset_bottom = -40
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_studio.add_child(sc)
	var sv2 := VBoxContainer.new()
	sv2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(sv2)
	sv2.add_child(Customizer.new())
	_form_btn = Button.new()
	_form_btn.text = "Preview: Transform to human"
	_form_btn.pressed.connect(_preview_transform)
	sv2.add_child(_form_btn)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_toggle_studio)
	sv2.add_child(done)
	_studio.visible = false
	add_child(_studio)

	_controls = PanelContainer.new()
	_controls.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_controls.offset_left = -620
	_controls.offset_right = -40
	_controls.offset_top = 60
	_controls.offset_bottom = -60
	var cv := VBoxContainer.new()
	_controls.add_child(cv)
	cv.add_child(UI.label("CONTROLS", 26, UI.GREEN))
	for line in ["WASD - move    Mouse - camera", "Space - jump / fly / ascend    C - descend", "Shift - sprint / boost    Alt - dodge roll", "G - GO GHOST", "LMB fire   RMB aim (wheel = zoom, X = swap shoulder)", "Tab (hold) - weapon & power wheel", "2 shield   3 phase   4 ice", "Q sense   V invisibility   Z ecto construct", "T overshadow   F duplicate   R Ghostly Wail   B ghost tail", "E (hold) - talk, interact, Fenton Thermos capture", "M - map    Esc/P - Fenton OS menu", "", "Gamepad: Y transform, A fly, X interact, Back = wheel"]:
		cv.add_child(UI.label(line, 17))
	_controls.visible = false
	add_child(_controls)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoshot="):
			_autoshot(a.substr(11))


func _autoshot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/00_title.png")
	_toggle_studio()
	_preview_transform()
	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/00_studio_transform.png")
	get_tree().quit()


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_menu.add_child(b)


func _continue() -> void:
	GameState.pending_new_game = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _new_game() -> void:
	GameState.pending_new_game = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _toggle_studio() -> void:
	_studio.visible = not _studio.visible
	_controls.visible = false
	# Slide the preview so the phantom stands beside the studio panel.
	_left.visible = not _studio.visible


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	_studio.visible = false


func _preview_transform() -> void:
	if _model.transforming:
		return
	var to_ghost: bool = not _model.ghost
	_form_btn.text = "Preview: Transform to human" if to_ghost else "Preview: GO GHOST!"
	_model.play_transform(to_ghost, 1.4)


func _process(delta: float) -> void:
	_t += delta
	_pivot.rotation.y += delta * 0.35
	_pivot.position.y = 0.15 + sin(_t * 1.6) * 0.06
	_model.anim_state = "hover" if _model.ghost else "idle"
	var want_x := 1.25 if _studio.visible else -1.1
	_cam.position.x = lerpf(_cam.position.x, want_x, clampf(delta * 5.0, 0.0, 1.0))
