extends CanvasLayer
## In-game HUD: location & city status, health/ecto bars, power slots with
## cooldowns, GO GHOST button, minimap, mission tracker, toasts, boss bar,
## dialogue box, world-space markers and screen effects.

const UI := preload("res://scripts/ui/ui_theme.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const WeaponWheel := preload("res://scripts/ui/weapon_wheel.gd")

const SLOTS := [
	["fire", "1", "Blast", "blast"],
	["shield", "2", "Shield", "shield"],
	["phase", "3", "Phase", "phase"],
	["ice", "4", "Ice", "ice"],
	["sense", "Q", "Sense", "sense"],
	["invisibility", "V", "Invis", "invis"],
	["construct", "Z", "Construct", "construct"],
	["overshadow", "T", "Possess", "overshadow"],
	["duplicate", "F", "Duplicate", "duplicate"],
	["wail", "R", "Wail", "wail"],
]

var game: Node = null
var root: Control
var loc_label: Label
var status_label: Label
var time_label: Label
var ecto_label: Label
var obj_title: Label
var obj_text: Label
var event_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var en_bar: ProgressBar
var en_text: Label
var xp_bar: ProgressBar
var lvl_label: Label
var id_label: Label
var id_bar: ProgressBar
var ghost_btn: PanelContainer
var ghost_label: Label
var thermos_label: Label
var prompt: Label
var capture_bar: ProgressBar
var toasts: VBoxContainer
var boss_panel: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var banner: Label
var banner_sub: Label
var dialog_panel: PanelContainer
var dialog_name: Label
var dialog_text: Label
var vignette: ColorRect
var fade: ColorRect
var overlay: Control
var minimap: Control
var big_map: Control
var crosshair: Label
var wheel: Control
var weapon_label: Label
var _hit_t := 0.0
var _hit_kill := false
var _sense_t := 0.0
var _sense_pos := Vector3.ZERO
var _sense_label: Label
var slots := {}
var _slot_on: StyleBoxFlat
var _slot_off: StyleBoxFlat
var _banner_t := 0.0
var _vignette_t := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 5
	add_to_group("hud")
	_slot_on = UI.panel(UI.GREEN, Color(0.1, 0.3, 0.18, 0.92), 6)
	_slot_off = UI.panel(UI.GREEN_DIM, UI.PANEL, 6)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)

	_build_top_left()
	_build_top_right()
	_build_bottom_left()
	_build_bottom_center()
	_build_bottom_right()
	_build_center()

	wheel = WeaponWheel.new()
	root.add_child(wheel)

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.2, 1.0, 0.45, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	GameState.notify.connect(toast)


func _anchor(c: Control, preset: int, pos: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.position = pos
	root.add_child(c)


func _build_top_left() -> void:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	p.add_child(v)
	loc_label = UI.label("AMITY PARK • DOWNTOWN", 20, UI.GREEN)
	status_label = UI.label("City Status: Safe", 16)
	time_label = UI.label("Day 1 · 15:00", 15, Color(0.8, 0.9, 0.85))
	ecto_label = UI.label("ECTOPLASM DETECTED", 16, Color(1.0, 0.4, 0.35))
	ecto_label.visible = false
	for l in [loc_label, status_label, time_label, ecto_label]:
		v.add_child(l)
	_anchor(p, Control.PRESET_TOP_LEFT, Vector2(16, 16))


func _build_top_right() -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	obj_title = UI.label("", 15, Color(0.6, 0.9, 0.7))
	obj_text = UI.label("", 18)
	obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_text.custom_minimum_size = Vector2(356, 0)
	event_label = UI.label("", 17, Color(1.0, 0.75, 0.35))
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.custom_minimum_size = Vector2(356, 0)
	for l in [obj_title, obj_text, event_label]:
		v.add_child(l)
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -16
	p.offset_top = 16
	root.add_child(p)

	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.offset_top = 90
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	boss_panel = PanelContainer.new()
	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	boss_name = UI.label("", 20, Color(1.0, 0.6, 0.4))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = UI.bar(Color(1.0, 0.35, 0.25), 14)
	boss_bar.custom_minimum_size = Vector2(520, 14)
	bv.add_child(boss_name)
	bv.add_child(boss_bar)
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_panel.offset_top = 16
	boss_panel.visible = false
	root.add_child(boss_panel)

	var bwrap := VBoxContainer.new()
	bwrap.set_anchors_preset(Control.PRESET_CENTER)
	bwrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bwrap.grow_vertical = Control.GROW_DIRECTION_BOTH
	bwrap.offset_top = -200
	bwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = UI.label("", 52, UI.GREEN)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 10)
	banner_sub = UI.label("", 22, Color(0.9, 1, 0.95))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bwrap.add_child(banner)
	bwrap.add_child(banner_sub)
	root.add_child(bwrap)


func _build_bottom_left() -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	var h1 := HBoxContainer.new()
	h1.add_child(UI.label("HEALTH", 14, Color(1.0, 0.6, 0.6)))
	hp_text = UI.label("100 / 100", 14)
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h1.add_child(hp_text)
	v.add_child(h1)
	hp_bar = UI.bar(Color(0.95, 0.3, 0.3), 14)
	v.add_child(hp_bar)
	var h2 := HBoxContainer.new()
	h2.add_child(UI.label("ECTO ENERGY", 14, UI.GREEN))
	en_text = UI.label("100 / 100", 14)
	en_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h2.add_child(en_text)
	v.add_child(h2)
	en_bar = UI.bar(UI.GREEN, 14)
	v.add_child(en_bar)
	var h3 := HBoxContainer.new()
	lvl_label = UI.label("Ghost Mastery Lv 1", 13, Color(0.7, 0.9, 1.0))
	h3.add_child(lvl_label)
	id_label = UI.label("Identity: Secret", 13)
	id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h3.add_child(id_label)
	v.add_child(h3)
	xp_bar = UI.bar(Color(0.45, 0.75, 1.0), 6)
	v.add_child(xp_bar)
	id_bar = UI.bar(Color(1.0, 0.75, 0.3), 4)
	v.add_child(id_bar)
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 16
	p.offset_bottom = -16
	root.add_child(p)


func _build_bottom_center() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for s in SLOTS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(60, 64)
		var box := Control.new()
		box.custom_minimum_size = Vector2(36, 48)
		slot.add_child(box)
		var key := UI.label(s[1], 22, UI.GREEN)
		key.position = Vector2(2, 0)
		box.add_child(key)
		var nm := UI.label(s[2], 11)
		nm.position = Vector2(0, 34)
		box.add_child(nm)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.6)
		cd.position = Vector2(-10, -6)
		cd.size = Vector2(60, 0)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cd)
		h.add_child(slot)
		slots[s[0]] = {"panel": slot, "cd": cd, "power": s[3], "name": nm}
	ghost_btn = PanelContainer.new()
	ghost_btn.custom_minimum_size = Vector2(116, 64)
	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	ghost_btn.add_child(gv)
	ghost_label = UI.label("GO GHOST", 18, UI.GREEN)
	ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(ghost_label)
	var gk := UI.label("G", 14)
	gk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gv.add_child(gk)
	h.add_child(ghost_btn)
	h.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	h.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.offset_bottom = -16
	root.add_child(h)


func _build_bottom_right() -> void:
	var v := VBoxContainer.new()
	minimap = Minimap.new()
	minimap.game = game
	minimap.custom_minimum_size = Vector2(230, 230)
	v.add_child(minimap)
	thermos_label = UI.label("Fenton Thermos: empty", 14, Color(0.6, 0.85, 1.0))
	thermos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(thermos_label)
	v.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_right = -16
	v.offset_bottom = -16
	root.add_child(v)

	big_map = Minimap.new()
	big_map.game = game
	big_map.big = true
	big_map.meters_per_px = 1.6
	big_map.set_anchors_preset(Control.PRESET_CENTER)
	big_map.custom_minimum_size = Vector2(740, 740)
	big_map.size = Vector2(740, 740)
	big_map.position = -big_map.size * 0.5
	big_map.visible = false
	root.add_child(big_map)


func _build_center() -> void:
	# The reticle itself is drawn in _draw_crosshair(); this label shows zoom.
	crosshair = UI.label("", 14, Color(0.7, 1.0, 0.8))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.offset_top = 34
	root.add_child(crosshair)

	weapon_label = UI.label("", 15, UI.GREEN)
	weapon_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	weapon_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.offset_top = -108
	weapon_label.offset_bottom = -88
	root.add_child(weapon_label)

	_sense_label = UI.label("", 22, Color(0.6, 0.85, 1.0))
	_sense_label.set_anchors_preset(Control.PRESET_CENTER)
	_sense_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sense_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sense_label.offset_top = -150
	_sense_label.add_theme_constant_override("outline_size", 8)
	root.add_child(_sense_label)

	prompt = UI.label("", 20, Color(1, 1, 0.8))
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.offset_top = 70
	root.add_child(prompt)

	capture_bar = UI.bar(Color(0.55, 0.85, 1.0), 10)
	capture_bar.set_anchors_preset(Control.PRESET_CENTER)
	capture_bar.custom_minimum_size = Vector2(240, 10)
	capture_bar.position = Vector2(-120, 110)
	capture_bar.visible = false
	root.add_child(capture_bar)

	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", UI.panel(UI.GREEN, Color(0.02, 0.06, 0.05, 0.93), 10, 3))
	var v := VBoxContainer.new()
	dialog_panel.add_child(v)
	dialog_name = UI.label("", 22, UI.GREEN)
	dialog_text = UI.label("", 20)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(760, 60)
	var hint := UI.label("[E] / [Space] continue", 13, Color(0.6, 0.8, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(dialog_name)
	v.add_child(dialog_text)
	v.add_child(hint)
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialog_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialog_panel.offset_bottom = -110
	dialog_panel.visible = false
	root.add_child(dialog_panel)


# --- API -------------------------------------------------------------------
func toast(text: String, color := Color.WHITE) -> void:
	var l := UI.label(text, 20, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	toasts.add_child(l)
	while toasts.get_child_count() > 5:
		toasts.get_child(0).queue_free()
		toasts.remove_child(toasts.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func show_banner(title: String, sub := "", t := 4.0) -> void:
	banner.text = title
	banner_sub.text = sub
	banner.modulate.a = 1.0
	banner_sub.modulate.a = 1.0
	_banner_t = t


func show_dialog(speaker: String, text: String) -> void:
	dialog_panel.visible = true
	dialog_name.text = speaker
	dialog_text.text = text


func hide_dialog() -> void:
	dialog_panel.visible = false


func flash_damage(amount: float) -> void:
	_vignette_t = clampf(0.15 + amount * 0.02, 0.0, 0.6)


func flash_travel() -> void:
	fade.color.a = 1.0
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.2)


func toggle_map() -> void:
	big_map.visible = not big_map.visible


# --- Per-frame -------------------------------------------------------------
func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_t += delta
	var p: Node3D = game.player
	loc_label.text = "%s • %s" % ["AMITY PARK" if game.realm == "amity" else "GHOST ZONE", game.district.to_upper()]
	var status: String = game.city_status()
	status_label.text = "City Status: %s" % status
	status_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if status == "Safe" else Color(1.0, 0.6, 0.4))
	time_label.text = game.time_text()
	var near: bool = game.ectoplasm_near()
	ecto_label.visible = near
	if near:
		ecto_label.modulate.a = 0.55 + 0.45 * absf(sin(_t * 5.0))
	hp_bar.value = p.health
	hp_text.text = "%d / 100" % int(ceil(p.health))
	en_bar.value = p.energy
	en_text.text = "%d / 100" % int(p.energy)
	lvl_label.text = "Ghost Mastery Lv %d" % GameState.level
	xp_bar.max_value = GameState.xp_to_next()
	xp_bar.value = GameState.xp
	var sus: float = game.suspicion
	id_bar.value = sus
	id_label.text = "Identity: %s" % ("Secret" if sus < 30.0 else ("Suspicious" if sus < 70.0 else "Exposed!"))
	id_label.add_theme_color_override("font_color", Color(0.8, 1, 0.85) if sus < 30.0 else (Color(1, 0.85, 0.4) if sus < 70.0 else UI.WARN))
	ghost_label.text = "GO HUMAN" if p.ghost else "GO GHOST"
	thermos_label.text = "Fenton Thermos: %s" % ("empty" if GameState.thermos.is_empty() else "%d ghost(s)" % GameState.thermos.size())

	for action in slots:
		var s: Dictionary = slots[action]
		var power: String = s["power"]
		var unlocked := GameState.has_power(power)
		var usable: bool = p.ghost or action == "fire"
		var panel: PanelContainer = s["panel"]
		panel.modulate = Color(1, 1, 1, 1.0 if unlocked and usable else 0.35)
		var active: bool = (action == "shield" and p.shielded) or (action == "phase" and p.phasing) or (action == "invisibility" and p.invisible) or (action == "overshadow" and p.overshadowing != null)
		panel.add_theme_stylebox_override("panel", _slot_on if active else _slot_off)
		var cd_id: String = action if action != "invisibility" else "invis"
		var cd: float = p.cooldowns.get(cd_id, 0.0)
		var mx: float = p.cooldown_max.get(cd_id, 1.0)
		var rect: ColorRect = s["cd"]
		rect.size.y = 64.0 * clampf(cd / maxf(mx, 0.01), 0.0, 1.0)
	crosshair.text = ("ZOOM 2.4x" if p.aim_zoom == 1 else "AIM 1.35x  [wheel: zoom, X: shoulder]") if p.aiming else ""
	var wname: String = GameState.WEAPONS[p.weapon][0] if p.ghost else "Fenton Wrist Ray"
	weapon_label.text = "[LMB] %s    [Tab] wheel" % wname
	_hit_t = maxf(0.0, _hit_t - delta)
	if _sense_t > 0.0:
		_sense_t = maxf(0.0, _sense_t - delta)
		_sense_label.modulate.a = minf(1.0, _sense_t * 2.0)
	else:
		_sense_label.text = ""
	# Interaction prompt / thermos.
	var text := ""
	if p.thermos_target:
		text = "Capturing..."
	elif game.interact_target:
		text = "[E] %s" % game.interact_target.interact_text
	elif p._find_thermos_target():
		text = "[Hold E] Capture with the Fenton Thermos"
	prompt.text = text
	capture_bar.visible = p.thermos_target != null
	capture_bar.value = p.thermos_progress * 100.0
	# Mission tracker.
	obj_title.text = game.missions.title_text()
	obj_text.text = game.missions.objective_text()
	var ev: String = game.director.status_text()
	if game.race and game.race.active:
		ev = game.race.race_text()
	event_label.text = ev
	event_label.visible = ev != ""
	# Boss bar.
	var boss: Node = game.active_boss()
	boss_panel.visible = boss != null
	if boss:
		boss_name.text = "%s  %s" % [boss.display_name, "(PHASE 2)" if boss.phase == 2 else ""]
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
	# Banner and effects.
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t < 1.0:
			banner.modulate.a = maxf(0.0, _banner_t)
			banner_sub.modulate.a = maxf(0.0, _banner_t)
		if _banner_t <= 0.0:
			banner.text = ""
			banner_sub.text = ""
	_vignette_t = maxf(0.0, _vignette_t - delta * 0.8)
	var low: float = 0.25 * (1.0 - p.health / 35.0) if p.health < 35.0 else 0.0
	vignette.color.a = maxf(_vignette_t, low * (0.7 + 0.3 * sin(_t * 6.0)))
	overlay.queue_redraw()


func hit_marker(killed: bool) -> void:
	_hit_t = 0.25
	_hit_kill = killed


## The ghost-sense alert: blue frost at the screen edges and an arrow
## pointing to where the ghost appeared.
func ghost_sense_alert(world_pos: Vector3) -> void:
	_sense_t = 2.2
	_sense_pos = world_pos
	_sense_label.text = "~ GHOST SENSE ~"


func _draw_sense(vp: Vector2, cam: Camera3D) -> void:
	if _sense_t <= 0.0:
		return
	var a := clampf(_sense_t / 2.2, 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(_t * 9.0)
	var col := Color(0.55, 0.85, 1.0, 0.6 * a * pulse)
	var w := 90.0
	for i in 6:
		var inset := i * w / 6.0
		var c := Color(col, col.a * (1.0 - i / 6.0))
		overlay.draw_rect(Rect2(inset, inset, vp.x - inset * 2.0, vp.y - inset * 2.0), c, false, w / 6.0)
	# Direction arrow around the reticle.
	var centre := vp * 0.5
	var to := _sense_pos - cam.global_position
	var local := cam.global_basis.inverse() * to
	var dir := Vector2(local.x, -local.y)
	if local.z > 0.0:
		dir = Vector2(local.x, absf(local.y) + 0.01) if dir.length() < 0.01 else dir
	if dir.length() < 0.01:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	var tip := centre + dir * 120.0
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([tip, tip - dir * 26.0 + side * 14.0, tip - dir * 18.0, tip - dir * 26.0 - side * 14.0])
	overlay.draw_colored_polygon(arrow, Color(0.6, 0.9, 1.0, a))


func _draw_crosshair(vp: Vector2) -> void:
	var p: Node = game.player
	if not (p.ghost or p.aiming) or game.wheel_open():
		return
	var c := vp * 0.5
	var col := Color(1.0, 0.35, 0.3) if p.aim_on_enemy else Color(0.75, 1.0, 0.85)
	var gap := 6.0 if p.aiming else 9.0
	if p.weapon == "spread" and p.ghost:
		gap = 18.0
	var spd: float = p.velocity.length()
	gap += clampf(spd / 50.0, 0.0, 1.0) * 6.0 if not p.aiming else 0.0
	var ln := 8.0
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		overlay.draw_line(c + d * gap, c + d * (gap + ln), Color(0, 0, 0, 0.7), 4.0)
		overlay.draw_line(c + d * gap, c + d * (gap + ln), col, 2.0)
	overlay.draw_circle(c, 2.0, col)
	if p.aiming:
		overlay.draw_arc(c, gap + ln + 8.0, 0, TAU, 40, Color(col, 0.5), 1.5, true)
	if p.charge > 0.0:
		overlay.draw_arc(c, 26.0, -PI / 2.0, -PI / 2.0 + TAU * p.charge, 40, Color(0.5, 1.0, 0.7), 4.0, true)
		if p.charge >= 1.0:
			overlay.draw_arc(c, 31.0, 0, TAU, 40, Color(1, 1, 1, 0.5 + 0.5 * sin(_t * 20.0)), 2.0, true)
	if _hit_t > 0.0:
		var hc := Color(1.0, 0.3, 0.25) if _hit_kill else Color(1, 1, 1)
		hc.a = _hit_t / 0.25
		var s := 7.0 + (0.25 - _hit_t) * 20.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			overlay.draw_line(c + d * s, c + d * (s + 7.0), hc, 2.5)


func _draw_overlay() -> void:
	if game == null or game.player == null:
		return
	var cam: Camera3D = game.player.camera
	if cam == null or not cam.is_inside_tree():
		return
	var vp := overlay.size
	_draw_crosshair(vp)
	_draw_sense(vp, cam)
	var font := overlay.get_theme_default_font()
	# Enemy health bars and ghost-sense markers.
	var sensed: bool = game.sense_active()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_inside_tree() or e.is_in_group("bosses"):
			continue
		var wp: Vector3 = e.global_position + Vector3(0, 2.6, 0)
		var d: float = wp.distance_to(cam.global_position)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		if d < 60.0 and e.health < e.max_health:
			var w := 50.0
			overlay.draw_rect(Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, 6)), Color(0, 0, 0, 0.7))
			var col := Color(1.0, 0.95, 0.4) if e.state == "weakened" else Color(1.0, 0.35, 0.3)
			overlay.draw_rect(Rect2(sp - Vector2(w * 0.5, 0), Vector2(w * clampf(e.health / e.max_health, 0.0, 1.0), 6)), col)
		if sensed and d < game.player.sense_range():
			overlay.draw_arc(sp, 16.0, 0, TAU, 20, Color(0.5, 0.85, 1.0, 0.9), 2.0)
	# Waypoint marker.
	if game.waypoint_active and game.waypoint_realm == game.realm:
		var wp: Vector3 = game.waypoint
		var dist: float = game.player.global_position.distance_to(wp)
		var sp := cam.unproject_position(wp)
		var behind := cam.is_position_behind(wp)
		var margin := 40.0
		if behind:
			sp = vp - sp
			sp.y = vp.y - margin
		sp = sp.clamp(Vector2(margin, margin), vp - Vector2(margin, margin))
		overlay.draw_circle(sp, 10.0, Color(1.0, 0.85, 0.2, 0.9))
		overlay.draw_arc(sp, 14.0, 0, TAU, 20, Color(0, 0, 0, 0.8), 2.0)
		var label := "%s  %dm" % [game.waypoint_text, int(dist)]
		overlay.draw_string(font, sp + Vector2(-150, 34), label, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(1, 0.95, 0.6))
