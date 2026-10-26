extends Control
## Radial weapon & ability wheel. Hold [Tab] (gamepad: Back), point with the
## mouse or right stick, release to equip an attack mode or fire an ability.
## Time slows while the wheel is open.

const UI := preload("res://scripts/ui/ui_theme.gd")

const ENTRIES := [
	{"id": "blast", "kind": "weapon", "name": "Ecto Blast", "hint": "Rapid fire", "color": Color(0.3, 1.0, 0.45)},
	{"id": "charge", "kind": "weapon", "name": "Charged Beam", "hint": "Hold, release", "color": Color(0.45, 1.0, 0.75)},
	{"id": "spread", "kind": "weapon", "name": "Ecto Spread", "hint": "Close range", "color": Color(0.6, 1.0, 0.3)},
	{"id": "ice", "kind": "weapon", "name": "Ice Shot", "hint": "Freeze", "color": Color(0.55, 0.85, 1.0)},
	{"id": "shield", "kind": "ability", "name": "Ghost Shield", "hint": "[2]", "color": Color(0.35, 1.0, 0.6)},
	{"id": "phase", "kind": "ability", "name": "Intangibility", "hint": "[3]", "color": Color(0.75, 1.0, 0.9)},
	{"id": "invis", "kind": "ability", "name": "Invisibility", "hint": "[V]", "color": Color(0.8, 0.85, 0.95)},
	{"id": "sense", "kind": "ability", "name": "Ghost Sense", "hint": "[Q]", "color": Color(0.5, 0.8, 1.0)},
	{"id": "construct", "kind": "ability", "name": "Ecto Construct", "hint": "[Z]", "color": Color(0.3, 1.0, 0.5)},
	{"id": "duplicate", "kind": "ability", "name": "Duplication", "hint": "[F]", "color": Color(0.5, 1.0, 0.65)},
	{"id": "wail", "kind": "ability", "name": "Ghostly Wail", "hint": "[R]", "color": Color(0.7, 1.0, 0.85)},
	{"id": "overshadow", "kind": "ability", "name": "Overshadow", "hint": "[T]", "color": Color(0.6, 0.9, 0.5)},
	{"id": "tail", "kind": "ability", "name": "Ghost Tail", "hint": "[B]", "color": Color(0.5, 0.95, 0.8)},
	{"id": "transform", "kind": "ability", "name": "Transform", "hint": "[G]", "color": Color(0.9, 1.0, 0.95)},
]
const INNER := 120.0
const OUTER := 290.0

var player: Node = null
var selected := -1
var _sel := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(p: Node) -> void:
	player = p
	visible = true
	_sel = Vector2.ZERO
	selected = -1
	Engine.time_scale = 0.2
	queue_redraw()


## Closes the wheel. When `apply` is true the highlighted entry is used.
func close(apply := true) -> void:
	if not visible:
		return
	visible = false
	Engine.time_scale = 1.0
	if apply and selected >= 0 and player:
		var e: Dictionary = ENTRIES[selected]
		if not _available(e):
			GameState.notify.emit("%s is locked: %s" % [e["name"], _lock_reason(e)], Color(1, 0.7, 0.6))
		elif e["kind"] == "weapon":
			player.set_weapon(e["id"])
			GameState.notify.emit("Equipped: %s" % GameState.WEAPONS[e["id"]][0], e["color"])
		else:
			player.activate_ability(e["id"])


func _power_id(e: Dictionary) -> String:
	return {"charge": "blast", "spread": "blast"}.get(e["id"], e["id"])


func _available(e: Dictionary) -> bool:
	if e["id"] == "transform":
		return true
	if e["kind"] == "ability" and player and not player.ghost:
		return false
	return GameState.has_power(_power_id(e))


func _lock_reason(e: Dictionary) -> String:
	if e["kind"] == "ability" and player and not player.ghost and GameState.has_power(_power_id(e)):
		return "go ghost first [G]"
	var p: Array = GameState.POWERS.get(_power_id(e), ["", "", "locked"])
	return p[2]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_sel = (_sel + event.relative).limit_length(180.0)
		_pick()
		get_viewport().set_input_as_handled()


func _pick() -> void:
	if _sel.length() < 35.0:
		selected = -1
		return
	var seg := TAU / ENTRIES.size()
	var a := fposmod(_sel.angle() + PI / 2.0 + seg / 2.0, TAU)
	selected = int(a / seg) % ENTRIES.size()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.5:
		_sel = stick * 120.0
		_pick()
	queue_redraw()


func _seg_points(i: int, r0: float, r1: float, c: Vector2) -> PackedVector2Array:
	var seg := TAU / ENTRIES.size()
	var a0 := -PI / 2.0 - seg / 2.0 + i * seg + 0.012
	var a1 := a0 + seg - 0.024
	var pts := PackedVector2Array()
	var steps := 10
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for k in steps + 1:
		var a := lerpf(a1, a0, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r0)
	return pts


func _draw() -> void:
	var c := size * 0.5
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.03, 0.02, 0.45))
	var seg := TAU / ENTRIES.size()
	var equipped: String = player.weapon if player else ""
	for i in ENTRIES.size():
		var e: Dictionary = ENTRIES[i]
		var ok := _available(e)
		var col: Color = e["color"]
		var sel := i == selected
		var r1 := OUTER + (14.0 if sel else 0.0)
		var fill := Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.88) if ok else Color(0.08, 0.08, 0.08, 0.85)
		if sel:
			fill = Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.95)
		var pts := _seg_points(i, INNER, r1, c)
		draw_colored_polygon(pts, fill)
		var border := col if ok else Color(0.35, 0.35, 0.35)
		if e["kind"] == "weapon" and e["id"] == equipped:
			border = Color(1, 1, 1)
		draw_polyline(pts + PackedVector2Array([pts[0]]), border, 3.0 if sel or e["id"] == equipped else 1.5, true)
		var mid := -PI / 2.0 + i * seg
		var lp := c + Vector2(cos(mid), sin(mid)) * (INNER + r1) * 0.5
		var tc := Color(1, 1, 1) if ok else Color(0.5, 0.5, 0.5)
		draw_string(font, lp + Vector2(-70, -2), e["name"], HORIZONTAL_ALIGNMENT_CENTER, 140, 15, tc)
		var sub: String = e["hint"]
		if player and e["kind"] == "ability":
			var cd_id: String = e["id"]
			var cd: float = player.cooldowns.get(cd_id, 0.0)
			if cd > 0.0:
				sub = "%.0fs" % cd
		if not ok:
			sub = "LOCKED"
		draw_string(font, lp + Vector2(-70, 16), sub, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(col, 0.85) if ok else Color(0.5, 0.45, 0.45))
		if e["kind"] == "weapon":
			draw_circle(c + Vector2(cos(mid), sin(mid)) * (INNER + 10.0), 4.0, col if ok else Color(0.4, 0.4, 0.4))
	# Centre panel.
	draw_circle(c, INNER - 8.0, Color(0.02, 0.07, 0.05, 0.95))
	draw_arc(c, INNER - 8.0, 0, TAU, 48, UI.GREEN_DIM, 2.0, true)
	var title := "WEAPONS & POWERS"
	var desc := "Point to choose, release [Tab]"
	if selected >= 0:
		var e: Dictionary = ENTRIES[selected]
		title = e["name"]
		if e["kind"] == "weapon":
			desc = GameState.WEAPONS[e["id"]][1]
		else:
			var pw: Array = GameState.POWERS.get(_power_id(e), ["", "", ""])
			desc = "Use ability now" if e["id"] != "transform" else "Go Ghost / Go Human"
			if not _available(e):
				desc = "Locked: " + _lock_reason(e)
			elif pw[0] != "":
				desc = "Use %s now" % pw[0]
	draw_string(font, c + Vector2(-INNER + 14, -14), title, HORIZONTAL_ALIGNMENT_CENTER, (INNER - 14) * 2.0, 18, UI.GREEN)
	_wrap(font, desc, c + Vector2(-INNER + 22, 10), (INNER - 22) * 2.0, 12)
	if player:
		draw_string(font, c + Vector2(-INNER + 14, 68), "Equipped: %s" % GameState.WEAPONS[player.weapon][0], HORIZONTAL_ALIGNMENT_CENTER, (INNER - 14) * 2.0, 12, Color(0.8, 0.9, 0.85))
	# Pointer.
	if _sel.length() > 35.0:
		var dir := _sel.normalized()
		draw_line(c + dir * (INNER - 30.0), c + dir * (INNER - 6.0), Color(1, 1, 1), 3.0, true)
	draw_string(font, Vector2(c.x - 200, c.y + OUTER + 44), "Weapons equip to [LMB].  Powers fire instantly.  Time slows while the wheel is open.", HORIZONTAL_ALIGNMENT_CENTER, 400, 14, Color(0.75, 0.9, 0.8))


func _wrap(font: Font, text: String, pos: Vector2, width: float, fs: int) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for w in words:
		var test := w if line == "" else line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, width, fs, Color(0.85, 0.95, 0.9))
			y += fs + 4
			line = w
		else:
			line = test
	if line != "":
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, width, fs, Color(0.85, 0.95, 0.9))
