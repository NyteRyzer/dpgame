extends Control
## North-up minimap / full map of the current realm.

const UI := preload("res://scripts/ui/ui_theme.gd")

var game: Node = null
var meters_per_px := 1.2
var big := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _to_map(p: Vector3, center: Vector3) -> Vector2:
	return size * 0.5 + Vector2(p.x - center.x, p.z - center.z) / meters_per_px


func _draw() -> void:
	if game == null or game.player == null:
		return
	var player: Node3D = game.player
	var center := player.global_position
	if big:
		center = Vector3.ZERO
	var r := Rect2(Vector2.ZERO, size)
	var amity: bool = game.realm == "amity"
	draw_rect(r, Color(0.04, 0.1, 0.07, 0.88) if amity else Color(0.05, 0.12, 0.08, 0.88))
	var root: Node = game.realm_root()
	if amity:
		# Road grid.
		var pitch: float = root.PITCH
		var ext: float = root.GRID * pitch
		for k in range(-root.GRID, root.GRID + 1):
			var a := _to_map(Vector3(k * pitch, 0, -ext), center)
			var b := _to_map(Vector3(k * pitch, 0, ext), center)
			draw_line(a, b, Color(0.2, 0.25, 0.25), maxf(2.0, 14.0 / meters_per_px))
			a = _to_map(Vector3(-ext, 0, k * pitch), center)
			b = _to_map(Vector3(ext, 0, k * pitch), center)
			draw_line(a, b, Color(0.2, 0.25, 0.25), maxf(2.0, 14.0 / meters_per_px))
	for entry in root.map_rects:
		var rect: Rect2 = entry[0]
		var p0 := _to_map(Vector3(rect.position.x, 0, rect.position.y), center)
		var mr := Rect2(p0, rect.size / meters_per_px)
		if mr.intersects(r):
			draw_rect(mr, Color(entry[1], 0.8))
	var font := get_theme_default_font()
	if big:
		for l in root.map_labels:
			var lp := _to_map(Vector3(l[0].x, 0, l[0].y), center)
			draw_string(font, lp + Vector2(-60, 0), l[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 0.85))
	# Artifacts (with the Ecto Scanner).
	if GameState.has_tech("scanner"):
		for a in get_tree().get_nodes_in_group("artifacts"):
			if a.is_inside_tree():
				draw_circle(_to_map(a.global_position, center), 3.0, Color(0.4, 1.0, 0.6))
	# Story NPCs.
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.is_inside_tree():
			draw_circle(_to_map(n.global_position, center), 4.0, Color(0.4, 0.7, 1.0))
	# Enemies.
	var sensed: bool = game.sense_active()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_inside_tree():
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < 90.0 or sensed or big:
			var boss: bool = e.is_in_group("bosses")
			draw_circle(_to_map(e.global_position, center), 6.0 if boss else 3.5, Color(1.0, 0.3, 0.3) if not boss else Color(1.0, 0.6, 0.1))
	# Waypoint.
	if game.waypoint_active and game.waypoint_realm == game.realm:
		var wp := _to_map(game.waypoint, center)
		wp = wp.clamp(Vector2(6, 6), size - Vector2(6, 6))
		draw_circle(wp, 6.0, Color(1.0, 0.9, 0.2))
		draw_arc(wp, 9.0, 0, TAU, 16, Color(0, 0, 0, 0.8), 2.0)
	# Player arrow.
	var pp := _to_map(center if not big else player.global_position, center)
	var yaw: float = player.model.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([pp + fwd * 9.0, pp - fwd * 6.0 + right * 6.0, pp - fwd * 3.0, pp - fwd * 6.0 - right * 6.0])
	draw_colored_polygon(pts, UI.GREEN)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0), 1.5)
	draw_rect(r, UI.GREEN_DIM, false, 2.0)
	draw_string(font, Vector2(size.x * 0.5 - 4, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.GREEN)
