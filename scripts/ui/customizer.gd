extends VBoxContainer
## Ghost Form Studio: personalise the ghost form (name, suit, accents, hair,
## hairstyle, eye glow, aura and chest emblem). Changes apply live.

const UI := preload("res://scripts/ui/ui_theme.gd")

var _rows := {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var title := UI.label("GHOST FORM STUDIO", 26, UI.GREEN)
	add_child(title)
	add_child(UI.label("Personalise your phantom. Cosmetics never change your stats.", 14, Color(0.7, 0.85, 0.75)))

	var name_row := HBoxContainer.new()
	name_row.add_child(_row_label("Ghost name"))
	var edit := LineEdit.new()
	edit.text = GameState.look.get("name", "Danny Phantom")
	edit.max_length = 24
	edit.custom_minimum_size = Vector2(260, 0)
	edit.text_changed.connect(func(t: String) -> void:
		GameState.set_look("name", t if t.strip_edges() != "" else "Phantom"))
	name_row.add_child(edit)
	add_child(name_row)

	_swatches("suit", "Ghost suit", GameState.SUIT_COLORS)
	_swatches("accent", "Accent color", GameState.ACCENT_COLORS)
	_swatches("hair", "Hair color", GameState.HAIR_COLORS)
	_choices("hairstyle", "Hairstyle", GameState.HAIRSTYLES)
	_swatches("eyes", "Eye glow", GameState.EYE_COLORS)
	_swatches("aura", "Ghost aura", GameState.AURA_COLORS)
	_choices("emblem", "Chest emblem", GameState.EMBLEMS)

	var reset := Button.new()
	reset.text = "Reset to classic look"
	reset.pressed.connect(func() -> void:
		var keep_name: String = GameState.look.get("name", "Danny Phantom")
		for k in GameState.DEFAULT_LOOK:
			GameState.look[k] = GameState.DEFAULT_LOOK[k]
		GameState.look["name"] = keep_name
		GameState.customization_changed.emit()
		_refresh())
	add_child(reset)
	_refresh()


func _row_label(text: String) -> Label:
	var l := UI.label(text, 16)
	l.custom_minimum_size = Vector2(130, 0)
	return l


func _swatches(key: String, text: String, options: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_row_label(text))
	var buttons := {}
	for opt in options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 34)
		b.tooltip_text = opt
		var col: Color = options[opt]
		if opt == "Prismatic":
			b.text = "*"
		if not GameState.is_cosmetic_unlocked(key, opt):
			b.disabled = true
			b.text = "X"
			b.tooltip_text = "%s - unlocks at Hero Reputation %d" % [opt, GameState.COSMETIC_UNLOCKS["%s:%s" % [key, opt]]]
		b.set_meta("color", col)
		b.pressed.connect(func() -> void:
			GameState.set_look(key, opt)
			_refresh())
		row.add_child(b)
		buttons[opt] = b
	var current := UI.label("", 14, Color(0.75, 0.9, 0.8))
	row.add_child(current)
	_rows[key] = {"buttons": buttons, "label": current, "swatch": true}
	add_child(row)


func _choices(key: String, text: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_row_label(text))
	var buttons := {}
	for opt in options:
		var b := Button.new()
		b.text = opt
		if not GameState.is_cosmetic_unlocked(key, opt):
			b.disabled = true
			b.text = "%s (locked)" % opt
			b.tooltip_text = "Unlocks at Hero Reputation %d" % GameState.COSMETIC_UNLOCKS["%s:%s" % [key, opt]]
		b.pressed.connect(func() -> void:
			GameState.set_look(key, opt)
			_refresh())
		row.add_child(b)
		buttons[opt] = b
	_rows[key] = {"buttons": buttons, "label": null, "swatch": false}
	add_child(row)


func _refresh() -> void:
	for key in _rows:
		var r: Dictionary = _rows[key]
		var selected: String = GameState.look.get(key, "")
		for opt in r["buttons"]:
			var b: Button = r["buttons"][opt]
			var on: bool = opt == selected
			if r["swatch"]:
				var col: Color = b.get_meta("color")
				for state in ["normal", "hover", "pressed", "focus"]:
					var s := UI.panel(Color(1, 1, 1) if on else Color(0, 0, 0, 0.6), col, 6, 3 if on else 1)
					s.shadow_size = 0
					b.add_theme_stylebox_override(state, s)
			else:
				b.add_theme_color_override("font_color", UI.GREEN if on else UI.TEXT)
		if r["label"]:
			r["label"].text = selected
