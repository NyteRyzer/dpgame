extends CanvasLayer
## "Fenton OS" pause menu: story log, powers, Ghost Form Studio, Fenton tech
## and progression, settings, controls, and save & quit.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Customizer := preload("res://scripts/ui/customizer.gd")

var game: Node = null
var _root: Control
var _content: VBoxContainer
var _tab := "story"
var _tabs := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI.make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.04, 0.02, 0.7)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel(UI.GREEN, Color(0.02, 0.06, 0.04, 0.95), 14, 3))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 80
	panel.offset_right = -80
	panel.offset_top = 50
	panel.offset_bottom = -50
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var header := HBoxContainer.new()
	var title := UI.label("FENTON OS v6.66", 30, UI.GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UI.label("A SO CALLED PHANTOM", 18, Color(0.7, 0.9, 0.8)))
	v.add_child(header)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["resume", "Resume"], ["story", "Story"], ["powers", "Powers"], ["ghost", "Ghost Form"], ["tech", "Progress & Tech"], ["settings", "Settings"], ["controls", "Controls"], ["quit", "Save & Quit"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(0, 40)
		var id: String = t[0]
		b.pressed.connect(func() -> void: _select(id))
		tabs.add_child(b)
		_tabs[id] = b
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func open(tab := "story") -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_select(tab)


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _select(id: String) -> void:
	match id:
		"resume":
			close()
			return
		"quit":
			GameState.save_game()
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/title.tscn")
			return
	_tab = id
	for k in _tabs:
		_tabs[k].add_theme_color_override("font_color", UI.GREEN if k == id else UI.TEXT)
	for c in _content.get_children():
		c.queue_free()
	match id:
		"story":
			_story()
		"powers":
			_powers()
		"ghost":
			_content.add_child(Customizer.new())
		"tech":
			_tech()
		"settings":
			_settings()
		"controls":
			_controls()


func _line(text: String, size := 17, color := UI.TEXT) -> void:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)


func _story() -> void:
	_line("STORY MODE: THE FRACTURED PORTAL", 24, UI.GREEN)
	_line("After a malfunction in the Fenton Portal, unstable rifts are opening across Amity Park. Someone is deliberately weakening the barrier between dimensions.", 16, Color(0.75, 0.9, 0.8))
	var chapters: Array = game.missions.CHAPTERS
	for i in chapters.size():
		var ch: Dictionary = chapters[i]
		var state := "COMPLETE" if i + 1 < GameState.story_chapter else ("IN PROGRESS" if i + 1 == GameState.story_chapter else "LOCKED")
		_line("%s   [%s]" % [ch["title"], state], 19, UI.GREEN if state != "LOCKED" else Color(0.5, 0.55, 0.5))
		if i + 1 == GameState.story_chapter:
			_line("    Current objective: %s" % game.missions.objective_text(), 16)
	_line("")
	_line("FREE ROAM ACTIVITIES", 20, UI.GREEN)
	_line("• Dynamic events start around the city: ghost invasions, portal rifts, Guys in White raids, Technus takeovers, and (at night) Ember's concert and Night Terrors.")
	_line("• Aerial race: fly into the gold ring next to the Nasty Burger. Best time: %s" % ("%.2fs" % GameState.race_best if GameState.race_best > 0.0 else "none yet"))
	_line("• Ectoplasmic artifacts found: %d / %d" % [GameState.artifacts.size(), game.total_artifacts()])
	_line("• Locations discovered: %d" % GameState.discovered.size())
	_line("• Ghosts contained at Fenton Works: %d" % GameState.contained.size())


func _powers() -> void:
	_line("GHOST POWERS", 24, UI.GREEN)
	_line("Ghost powers work in ghost form. Flight never costs energy - explore freely.", 15, Color(0.75, 0.9, 0.8))
	for id in GameState.POWERS:
		var p: Array = GameState.POWERS[id]
		var owned := GameState.has_power(id)
		_line("%s  [%s]  -  %s" % [p[0], p[1], "UNLOCKED" if owned else "Locked: " + p[2]], 18, UI.GREEN if owned else Color(0.55, 0.6, 0.58))
	_line("")
	_line("Tips: weakened ghosts (yellow swirl) can be captured with the Fenton Thermos by holding [E]. Intangibility makes you immune to attacks but you can't fire. Frozen enemies take double damage. Overshadow civilians to hide from hunters.", 15)


func _tech() -> void:
	_line("PROGRESSION", 24, UI.GREEN)
	_line("Ghost Mastery: Level %d  (%d / %d XP)" % [GameState.level, GameState.xp, GameState.xp_to_next()], 19)
	_line("Hero Reputation: %d   (cosmetics: Long hairstyle at 5, Prismatic aura at 10)" % GameState.reputation, 19)
	_line("Ghosts defeated: %d" % GameState.ghosts_defeated, 17)
	_line("")
	_line("FENTON TECHNOLOGY", 22, UI.GREEN)
	for id in GameState.TECH:
		var t: Array = GameState.TECH[id]
		var owned := GameState.has_tech(id)
		_line("%s  -  %s" % [t[0] if owned else t[0] + " (locked)", t[1]], 17, UI.TEXT if owned else Color(0.55, 0.6, 0.58))
	_line("")
	_line("CONTAINMENT UNIT", 22, UI.GREEN)
	_line(", ".join(PackedStringArray(GameState.contained)) if not GameState.contained.is_empty() else "Empty. Capture ghosts and bring them to the lab.", 16)


func _settings() -> void:
	_line("SETTINGS", 24, UI.GREEN)
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.05, 1.0, 0.01)
	_slider("Field of view", "fov", 60.0, 100.0, 1.0)
	_slider("Master volume", "master_volume", 0.0, 1.0, 0.05)
	_check("Invert camera Y", "invert_y")
	_check("Cinematic transformation when standing still", "cinematic_transform")


func _slider(text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	var l := UI.label(text, 17)
	l.custom_minimum_size = Vector2(320, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = GameState.settings.get(key, lo)
	s.custom_minimum_size = Vector2(320, 24)
	var val := UI.label(str(s.value), 16)
	s.value_changed.connect(func(x: float) -> void:
		GameState.settings[key] = x
		val.text = str(snappedf(x, step))
		if key == "master_volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(x, 0.001))))
	h.add_child(s)
	h.add_child(val)
	_content.add_child(h)


func _check(text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = GameState.settings.get(key, false)
	c.toggled.connect(func(on: bool) -> void: GameState.settings[key] = on)
	_content.add_child(c)


func _controls() -> void:
	_line("CONTROLS", 24, UI.GREEN)
	var rows := [
		["WASD / Left stick", "Move (in flight: relative to camera)"],
		["Mouse / Right stick", "Camera"],
		["Space", "Jump / take off / ascend"],
		["C or Ctrl", "Descend (and land)"],
		["Shift", "Sprint / flight boost"],
		["Alt", "Aerial dodge"],
		["G", "Transform (Go Ghost / Go Human)"],
		["Left mouse / 1", "Ecto blast (human: Fenton wrist ray)"],
		["Right mouse", "Aim (over the shoulder)"],
		["2 / 3 / 4", "Ghost shield / Intangibility / Cryokinesis"],
		["Q / V", "Ghost sense / Invisibility"],
		["Z / T / F / R", "Ecto construct / Overshadow / Duplicate / Ghostly Wail"],
		["B", "Ghost tail (while flying)"],
		["E (hold)", "Talk, interact, capture with the Fenton Thermos"],
		["M", "Map"],
		["Esc / Tab", "Fenton OS menu"],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var k := UI.label(r[0], 17, UI.GREEN)
		k.custom_minimum_size = Vector2(260, 0)
		h.add_child(k)
		h.add_child(UI.label(r[1], 17))
		_content.add_child(h)
