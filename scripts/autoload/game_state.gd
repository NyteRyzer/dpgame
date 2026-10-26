extends Node
## Global game state: ghost-form customization, progression, story flags,
## settings, input bindings and save/load.

signal notify(text: String, color: Color)
signal xp_changed
signal level_up(level: int)
signal customization_changed
signal progress_changed

const SAVE_PATH := "user://a_so_called_phantom_save.json"
const SAVE_VERSION := 1

# --- Ghost Form Studio options (ordered) -----------------------------------
const SUIT_COLORS := {
	"Black": Color(0.07, 0.07, 0.09),
	"White": Color(0.9, 0.93, 0.95),
	"Blue": Color(0.1, 0.2, 0.55),
	"Purple": Color(0.3, 0.12, 0.46),
	"Crimson": Color(0.52, 0.05, 0.1),
}
const ACCENT_COLORS := {
	"White": Color(0.95, 0.97, 1.0),
	"Green": Color(0.25, 1.0, 0.45),
	"Purple": Color(0.7, 0.35, 1.0),
	"Blue": Color(0.3, 0.6, 1.0),
	"Red": Color(1.0, 0.2, 0.2),
	"Gold": Color(1.0, 0.8, 0.2),
}
const HAIR_COLORS := {
	"White": Color(0.96, 0.97, 1.0),
	"Silver": Color(0.68, 0.72, 0.78),
	"Green": Color(0.3, 0.95, 0.5),
	"Black": Color(0.06, 0.06, 0.08),
	"Blue": Color(0.25, 0.45, 1.0),
}
const HAIRSTYLES := ["Spiky", "Swept", "Mohawk", "Long"]
const EYE_COLORS := {
	"Toxic Green": Color(0.3, 1.0, 0.4),
	"Ice Blue": Color(0.4, 0.85, 1.0),
	"Blood Red": Color(1.0, 0.15, 0.15),
	"Violet": Color(0.75, 0.35, 1.0),
	"Gold": Color(1.0, 0.82, 0.25),
}
const AURA_COLORS := {
	"Ecto Green": Color(0.25, 1.0, 0.45),
	"Spectral White": Color(0.9, 0.95, 1.0),
	"Frost Blue": Color(0.4, 0.75, 1.0),
	"Shadow Purple": Color(0.55, 0.2, 0.9),
	"Inferno Red": Color(1.0, 0.3, 0.15),
	"Prismatic": Color(1.0, 1.0, 1.0),
}
const EMBLEMS := ["Initials", "Ghost Ring", "None"]

## Cosmetics earned through Hero Reputation (never stat boosts).
const COSMETIC_UNLOCKS := {
	"hairstyle:Long": 5,
	"aura:Prismatic": 10,
}

const DEFAULT_LOOK := {
	"name": "Danny Phantom",
	"suit": "Black",
	"accent": "White",
	"hair": "White",
	"hairstyle": "Spiky",
	"eyes": "Toxic Green",
	"aura": "Ecto Green",
	"emblem": "Initials",
}

# --- Powers -------------------------------------------------------------
## power id -> [display name, key hint, unlock description]
const POWERS := {
	"flight": ["Flight", "Space / C", "Signature"],
	"blast": ["Ecto Blast", "LMB / 1", "Signature"],
	"shield": ["Ghost Shield", "2", "Signature"],
	"phase": ["Intangibility", "3", "Signature"],
	"invis": ["Invisibility", "V", "Signature"],
	"sense": ["Ghost Sense", "Q", "Signature"],
	"tail": ["Ghost Tail", "B", "Signature"],
	"construct": ["Ecto Constructs", "Z", "Ghost Mastery Lv 2"],
	"overshadow": ["Overshadowing", "T", "Ghost Mastery Lv 3"],
	"wail": ["Ghostly Wail", "R", "Ghost Mastery Lv 4"],
	"duplicate": ["Duplication", "F", "Ghost Mastery Lv 5"],
	"ice": ["Cryokinesis", "4", "Train with Frostbite (Ch. 3) or Lv 7"],
}
const POWER_LEVELS := {"construct": 2, "overshadow": 3, "wail": 4, "duplicate": 5, "ice": 7}

## Attack modes for the left mouse button, picked from the weapon wheel.
const WEAPONS := {
	"blast": ["Ecto Blast", "Rapid-fire ecto bolts. 3 energy each."],
	"charge": ["Charged Ecto Beam", "Hold to charge, release for a heavy explosive blast."],
	"spread": ["Ecto Spread", "A close-range burst of six bolts."],
	"ice": ["Ice Shot", "Freezes ghosts solid and builds ice. Needs Cryokinesis."],
}

## Fenton Technology path.
const TECH := {
	"thermos": ["Fenton Thermos", "Capture weakened ghosts (hold E)."],
	"scanner": ["Ecto Scanner", "Ghost Sense range doubled, artifacts show on the minimap. Collect 5 artifacts."],
	"deflector": ["Specter Deflector", "Take 25% less damage. Defeat Skulker."],
	"booster": ["Fenton Booster", "Faster ecto-energy regeneration. Reach Hero Reputation 8."],
}

var look: Dictionary = DEFAULT_LOOK.duplicate()
var xp := 0
var level := 1
var reputation := 0
var story_chapter := 1
var story_step := 0
var flags := {}
var artifacts: Array = []
var discovered: Array = []
var thermos: Array = []
var contained: Array = []
var tech: Array = ["thermos"]
var race_best := 0.0
var ghosts_defeated := 0
var settings := {
	"mouse_sensitivity": 0.25,
	"invert_y": false,
	"cinematic_transform": true,
	"fov": 75.0,
	"aim_assist": true,
	"master_volume": 0.8,
}

## Set by the title screen to tell the game whether to load or start fresh.
var pending_new_game := false


func _ready() -> void:
	_setup_input()
	load_game()


# --- Progression ---------------------------------------------------------
func xp_to_next() -> int:
	return 100 + (level - 1) * 75


func add_xp(amount: int, reason := "") -> void:
	xp += amount
	if reason != "":
		notify.emit("+%d XP  %s" % [amount, reason], Color(0.5, 1.0, 0.6))
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		level_up.emit(level)
		notify.emit("GHOST MASTERY LEVEL %d" % level, Color(0.3, 1.0, 0.5))
		for p in POWER_LEVELS:
			if POWER_LEVELS[p] == level:
				notify.emit("New power unlocked: %s [%s]" % [POWERS[p][0], POWERS[p][1]], Color(0.6, 1.0, 1.0))
	xp_changed.emit()


func add_reputation(amount: int) -> void:
	var before := reputation
	reputation += amount
	for key in COSMETIC_UNLOCKS:
		var need: int = COSMETIC_UNLOCKS[key]
		if before < need and reputation >= need:
			notify.emit("Cosmetic unlocked: %s" % key.split(":")[1], Color(1.0, 0.85, 0.3))
	if before < 8 and reputation >= 8:
		unlock_tech("booster")
	progress_changed.emit()


func has_power(id: String) -> bool:
	if id == "ice":
		return flags.get("frostbite_training", false) or level >= POWER_LEVELS["ice"]
	if POWER_LEVELS.has(id):
		return level >= POWER_LEVELS[id]
	return POWERS.has(id)


func has_tech(id: String) -> bool:
	return tech.has(id)


func unlock_tech(id: String) -> void:
	if tech.has(id):
		return
	tech.append(id)
	notify.emit("Fenton Tech acquired: %s" % TECH[id][0], Color(0.4, 0.9, 1.0))
	progress_changed.emit()


func is_cosmetic_unlocked(category: String, option: String) -> bool:
	var key := "%s:%s" % [category, option]
	if not COSMETIC_UNLOCKS.has(key):
		return true
	return reputation >= COSMETIC_UNLOCKS[key]


func set_look(key: String, value) -> void:
	look[key] = value
	customization_changed.emit()


func collect_artifact(id: String) -> void:
	if artifacts.has(id):
		return
	artifacts.append(id)
	add_xp(20, "Ectoplasmic artifact (%d)" % artifacts.size())
	if artifacts.size() >= 5:
		unlock_tech("scanner")
	progress_changed.emit()


func discover(location: String) -> bool:
	if discovered.has(location):
		return false
	discovered.append(location)
	notify.emit("Location discovered: %s" % location, Color(1.0, 0.9, 0.5))
	add_xp(30)
	return true


func set_flag(id: String, value = true) -> void:
	flags[id] = value
	progress_changed.emit()


# --- Save / load ---------------------------------------------------------
func reset() -> void:
	var keep_look := look.duplicate()
	var keep_settings := settings.duplicate()
	xp = 0
	level = 1
	reputation = 0
	story_chapter = 1
	story_step = 0
	flags = {}
	artifacts = []
	discovered = []
	thermos = []
	contained = []
	tech = ["thermos"]
	race_best = 0.0
	ghosts_defeated = 0
	look = keep_look
	settings = keep_settings


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"look": look,
		"xp": xp,
		"level": level,
		"reputation": reputation,
		"story_chapter": story_chapter,
		"story_step": story_step,
		"flags": flags,
		"artifacts": artifacts,
		"discovered": discovered,
		"thermos": thermos,
		"contained": contained,
		"tech": tech,
		"race_best": race_best,
		"ghosts_defeated": ghosts_defeated,
		"settings": settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; starting fresh.")
		return
	for k in DEFAULT_LOOK:
		if data.get("look", {}).has(k):
			look[k] = data["look"][k]
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))
	reputation = int(data.get("reputation", 0))
	story_chapter = int(data.get("story_chapter", 1))
	story_step = int(data.get("story_step", 0))
	flags = data.get("flags", {})
	artifacts = data.get("artifacts", [])
	discovered = data.get("discovered", [])
	thermos = data.get("thermos", [])
	contained = data.get("contained", [])
	tech = data.get("tech", ["thermos"])
	race_best = float(data.get("race_best", 0.0))
	ghosts_defeated = int(data.get("ghosts_defeated", 0))
	var s: Dictionary = data.get("settings", {})
	for k in s:
		settings[k] = s[k]


# --- Input map -----------------------------------------------------------
func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_bind("look_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("look_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A])
	_bind("descend", [KEY_C, KEY_CTRL], [JOY_BUTTON_B])
	_bind("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_bind("dodge", [KEY_ALT], [JOY_BUTTON_RIGHT_STICK])
	_bind("transform", [KEY_G], [JOY_BUTTON_Y])
	_bind("fire", [KEY_1], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], [MOUSE_BUTTON_LEFT])
	_bind("aim", [], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], [MOUSE_BUTTON_RIGHT])
	_bind("shield", [KEY_2], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("phase", [KEY_3], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("ice", [KEY_4], [JOY_BUTTON_DPAD_UP])
	_bind("sense", [KEY_Q], [JOY_BUTTON_DPAD_LEFT])
	_bind("invisibility", [KEY_V], [JOY_BUTTON_DPAD_RIGHT])
	_bind("wail", [KEY_R], [JOY_BUTTON_DPAD_DOWN])
	_bind("duplicate", [KEY_F])
	_bind("overshadow", [KEY_T])
	_bind("construct", [KEY_Z])
	_bind("tail", [KEY_B])
	_bind("interact", [KEY_E], [JOY_BUTTON_X])
	_bind("map", [KEY_M])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("wheel", [KEY_TAB], [JOY_BUTTON_BACK])
	_bind("zoom_in", [], [], [], [MOUSE_BUTTON_WHEEL_UP])
	_bind("zoom_out", [], [], [], [MOUSE_BUTTON_WHEEL_DOWN])
	_bind("swap_shoulder", [KEY_X])


func _bind(action: String, keys: Array, buttons: Array = [], axes: Array = [], mouse: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	for a in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = a[0]
		m.axis_value = a[1]
		InputMap.action_add_event(action, m)
	for mb in mouse:
		var me := InputEventMouseButton.new()
		me.button_index = mb
		InputMap.action_add_event(action, me)
