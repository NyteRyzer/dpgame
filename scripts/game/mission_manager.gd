extends Node
## Story campaign "The Fractured Portal": data-driven chapters and steps,
## objective tracking, waypoints, boss spawning and NPC dialogue that
## changes with story progress.

var game: Node = null
var boss: Node = null
var _count := 0
var _wave_t := 0.0

const CHAPTERS := [
	{
		"title": "Chapter 1 - Going Ghost",
		"intro": "Something is wrong with the Fenton Portal...",
		"steps": [
			{"type": "reach", "spot": "lab", "radius": 4.0, "text": "Head down to the basement lab: take the stairs through Jazz's room, then the lab stairs by the west wall."},
			{"type": "talk", "npc": "jack", "text": "Talk to Jack in the lab."},
			{"type": "transform", "text": "Press [G] to GO GHOST."},
			{"type": "reach", "spot": "roof", "radius": 7.0, "text": "Fly up to the Fenton Ops Center on the roof. [Space] fly, [3] phase through ceilings."},
			{"type": "reach", "spot": "casper", "radius": 16.0, "text": "Ghost sighting at Casper High! Fly there. (Hold [Shift] to boost)"},
			{"type": "boss", "boss": "lunch_lady", "spot": "casper", "offset": Vector3(0, 3, -10), "text": "Defeat the Lunch Lady Ghost."},
			{"type": "capture", "text": "Hold [E] near her to suck her into the Fenton Thermos."},
			{"type": "deposit", "text": "Return to the Fenton Works lab and empty the Thermos into containment."},
		],
	},
	{
		"title": "Chapter 2 - Amity Under Attack",
		"intro": "Rifts are opening all over town.",
		"steps": [
			{"type": "talk", "npc": "sam", "text": "Meet Sam and Tucker at the Nasty Burger."},
			{"type": "defeat", "count": 10, "spot_pos": Vector3(0, 25, -120), "text": "Ghost invasion downtown! Defeat the ghosts (%d/%d)."},
			{"type": "boss", "boss": "box_ghost", "spot": "mall", "offset": Vector3(0, 3, -6), "text": "The Box Ghost is terrorising the Amity Park Mall. Stop him!"},
			{"type": "capture", "text": "Capture the Box Ghost with the Fenton Thermos [Hold E]."},
			{"type": "reach", "spot": "axion", "radius": 30.0, "text": "Tucker picked up a hunter's signal at Axion Labs. Investigate."},
			{"type": "boss", "boss": "skulker", "spot": "axion_roof", "offset": Vector3(0, 12, 0), "text": "Skulker is hunting you! Defeat the Ghost Zone's greatest hunter."},
			{"type": "capture", "text": "Capture Skulker with the Fenton Thermos [Hold E]."},
			{"type": "deposit", "text": "Bring the captured ghosts back to Fenton Works containment."},
		],
	},
	{
		"title": "Chapter 3 - Into the Ghost Zone",
		"intro": "Someone is weakening the barrier from the other side.",
		"steps": [
			{"type": "realm", "realm": "ghost_zone", "text": "Step through the Fenton Portal in the lab into the Ghost Zone."},
			{"type": "reach", "spot": "far_frozen", "realm": "ghost_zone", "radius": 35.0, "text": "Find Frostbite in the Far Frozen (east of the Phantom Expanse)."},
			{"type": "talk", "npc": "frostbite", "text": "Talk to Frostbite."},
			{"type": "freeze", "count": 3, "text": "Ice training: freeze ghosts with Cryokinesis [4] (%d/%d)."},
			{"type": "reach", "spot": "prison_gate", "realm": "ghost_zone", "radius": 30.0, "text": "Infiltrate Walker's Prison (far west). Its walls are ghost-shielded: use the gate."},
			{"type": "boss", "boss": "walker", "spot": "walker_yard", "realm": "ghost_zone", "offset": Vector3(0, 2, 0), "text": "Defeat Walker in the prison yard."},
			{"type": "capture", "text": "Capture Walker with the Fenton Thermos [Hold E]."},
			{"type": "realm", "realm": "amity", "text": "Return home through the portal at the Phantom Expanse."},
			{"type": "deposit", "text": "Empty the Thermos into containment at Fenton Works."},
		],
	},
	{
		"title": "Chapter 4 - The Plasmius Conspiracy",
		"intro": "Coming in a future build.",
		"steps": [
			{"type": "end", "text": "Free roam! Patrol for ghost events, race the skies, hunt the remaining artifacts, and explore the Ghost Zone. Vlad's Mansion awaits in Chapter 4."},
		],
	},
]


func _ready() -> void:
	# A boss or capture step can't survive a reload: restart the fight.
	var s := current_step()
	if s.get("type") == "capture":
		GameState.story_step = maxi(0, GameState.story_step - 1)
	_enter_step()


func chapter() -> Dictionary:
	return CHAPTERS[clampi(GameState.story_chapter - 1, 0, CHAPTERS.size() - 1)]


func current_step() -> Dictionary:
	var steps: Array = chapter()["steps"]
	return steps[clampi(GameState.story_step, 0, steps.size() - 1)]


func is_free_roam() -> bool:
	return GameState.story_chapter >= CHAPTERS.size()


func title_text() -> String:
	return chapter()["title"].to_upper()


func objective_text() -> String:
	var s := current_step()
	var t: String = s.get("text", "")
	if s.get("type") in ["defeat", "freeze"]:
		return t % [_count, s["count"]]
	return t


## True while the story is running a fight that random events shouldn't interrupt.
func blocking_events() -> bool:
	return current_step().get("type") in ["boss", "capture", "defeat"]


func _spot_pos(s: Dictionary) -> Vector3:
	var realm: String = s.get("realm", "amity")
	var root: Node = game.amity if realm == "amity" else game.ghost_zone
	if s.has("spot_pos"):
		return s["spot_pos"]
	return root.spots.get(s.get("spot", ""), Vector3.ZERO)


func _advance() -> void:
	var steps: Array = chapter()["steps"]
	GameState.story_step += 1
	game.clear_waypoint()
	if GameState.story_step >= steps.size():
		_complete_chapter()
		return
	GameState.save_game()
	_enter_step()


func _complete_chapter() -> void:
	var finished: String = chapter()["title"]
	GameState.add_xp(200, "Chapter complete")
	GameState.add_reputation(3)
	if GameState.story_chapter == 2:
		GameState.unlock_tech("deflector")
	GameState.story_chapter += 1
	GameState.story_step = 0
	GameState.save_game()
	game.hud.show_banner("%s COMPLETE" % finished.to_upper(), "Next: %s" % chapter()["title"], 5.0)
	_enter_step()


func _enter_step() -> void:
	_count = 0
	_wave_t = 0.0
	var s := current_step()
	for n in get_tree().get_nodes_in_group("npcs"):
		n.set_marker(s.get("type") == "talk" and n.npc_id == s.get("npc"))
	if GameState.story_step == 0:
		game.hud.show_banner(chapter()["title"].to_upper(), chapter()["intro"], 4.5)
	_update_waypoint()


func _update_waypoint() -> void:
	var s := current_step()
	match s.get("type"):
		"reach":
			game.set_waypoint(_spot_pos(s), "Objective", s.get("realm", "amity"))
		"boss":
			game.set_waypoint(_spot_pos(s), "Ghost sighting", s.get("realm", "amity"))
		"talk":
			var n: Node3D = game.npcs.get(s["npc"])
			if n:
				game.set_waypoint(n.global_position + Vector3(0, 2, 0), n.display_name, "ghost_zone" if s["npc"] == "frostbite" else "amity")
		"deposit":
			game.set_waypoint(game.amity.spots["containment"] + Vector3(0, 1.5, 0), "Containment", "amity")
		"realm":
			if s["realm"] == "ghost_zone":
				game.set_waypoint(game.amity.spots["portal"], "Fenton Portal", "amity")
			else:
				game.set_waypoint(game.ghost_zone.spots["portal"], "Portal home", "ghost_zone")
		"defeat":
			game.set_waypoint(_spot_pos(s), "Ghost invasion", "amity")
		_:
			game.clear_waypoint()


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	var s := current_step()
	var p: Node3D = game.player
	var realm: String = s.get("realm", "amity")
	match s.get("type"):
		"reach":
			if game.realm == realm and p.global_position.distance_to(_spot_pos(s)) < s["radius"]:
				_advance()
		"boss":
			if boss == null or not is_instance_valid(boss):
				var at := _spot_pos(s)
				if game.realm == realm and p.global_position.distance_to(at) < 140.0:
					boss = game.spawn_boss(s["boss"], at + s.get("offset", Vector3.ZERO))
					boss.phase_changed.connect(func(_ph: int) -> void: game.hud.show_banner("PHASE 2", boss.display_name + " is enraged!", 2.0))
					game.hud.show_banner(boss.display_name.to_upper(), "Boss fight", 2.5)
			else:
				game.set_waypoint(boss.global_position + Vector3(0, 3, 0), boss.display_name, realm)
				if boss.state == "weakened":
					_advance()
		"capture":
			if boss == null or not is_instance_valid(boss):
				# Captured (or lost) - continue the story.
				boss = null
				_advance()
			else:
				game.set_waypoint(boss.global_position + Vector3(0, 3, 0), "Capture!", realm)
		"defeat":
			_wave_t -= delta
			var alive := 0
			for e in get_tree().get_nodes_in_group("story_wave"):
				alive += 1
			if _wave_t <= 0.0 and alive < 4 and _count + alive < s["count"] and game.realm == "amity":
				_wave_t = 2.0
				var c := _spot_pos(s)
				var e: Node = game.spawn_enemy("minion" if randf() < 0.75 else "shadow", c + Vector3(randf_range(-40, 40), randf_range(0, 20), randf_range(-40, 40)))
				e.add_to_group("story_wave")
				e.leash = 400.0
				e.died.connect(func(_en: Node, _cap: bool) -> void:
					_count += 1
					if _count >= current_step().get("count", 9999):
						GameState.add_reputation(1)
						_advance())
		"realm":
			if game.realm == s["realm"]:
				_advance()


# --- Hooks from the game ------------------------------------------------------
func on_transform(to_ghost: bool) -> void:
	if to_ghost and current_step().get("type") == "transform":
		GameState.add_xp(20, "Going ghost!")
		_advance()


func on_talked(npc_id: String) -> void:
	var s := current_step()
	if s.get("type") == "talk" and s.get("npc") == npc_id:
		if npc_id == "frostbite":
			GameState.set_flag("frostbite_training")
			GameState.notify.emit("New power: Cryokinesis [4]! Freeze ghosts and build ice.", Color(0.6, 0.9, 1.0))
		if npc_id == "sam":
			game.npcs["tucker"].set_marker(false)
		_advance()


func on_freeze() -> void:
	var s := current_step()
	if s.get("type") == "freeze":
		_count += 1
		if _count >= s["count"]:
			_advance()


func on_deposit(_ghosts: Array) -> void:
	if current_step().get("type") == "deposit":
		_advance()


func on_travel(_realm: String) -> void:
	_update_waypoint()


func on_player_died() -> void:
	var s := current_step()
	if s.get("type") == "capture":
		GameState.story_step -= 1
	if boss and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	for e in get_tree().get_nodes_in_group("story_wave"):
		e.queue_free()
	_enter_step()


# --- Dialogue -------------------------------------------------------------------
func dialog_for(npc_id: String) -> Array:
	var ch := GameState.story_chapter
	var st := GameState.story_step
	var me: String = GameState.look.get("name", "Danny Phantom")
	var talk_now: bool = current_step().get("type") == "talk" and current_step().get("npc") == npc_id
	match npc_id:
		"jack":
			if talk_now:
				return [["Jack Fenton", "Danny-boy! The Fenton Portal's been making funny noises all morning. Ecto-readings are off the charts!"],
					["Jack Fenton", "Your mother thinks someone is tampering with the barrier from the other side. Here, take the Fenton Thermos. Suck up any ghost you see!"],
					["Danny", "(If they only knew... time to go ghost.)"]]
			if ch == 1:
				return [["Jack Fenton", "A ghost at the high school? Ha! No ghost can resist the Fenton Thermos!"]]
			if ch == 2:
				return [["Jack Fenton", "The Ghost Boy was spotted downtown again. I'll rip him apart molecule by molecule! ...Why are you making that face?"]]
			return [["Jack Fenton", "Contained ghosts: %d. FENTON WORKS IS OPEN FOR BUSINESS!" % GameState.contained.size()]]
		"maddie":
			if ch >= 3:
				return [["Maddie Fenton", "The portal's readings are stabilising. Whoever was weakening the barrier... their trail leads to Wisconsin. Odd."]]
			return [["Maddie Fenton", "Sweetie, the rift readings form a pattern. Somebody is doing this on purpose."]]
		"jazz":
			if GameState.contained.size() > 0:
				return [["Jazz Fenton", "I saw the news, little brother. %s saved the whole block. I'm... proud of him. Of you. Whatever." % me]]
			return [["Jazz Fenton", "Mom and Dad are in the lab again. If you need a cover story, I've got you."]]
		"sam":
			if talk_now:
				return [["Sam Manson", "There you are! Rifts are popping open all over downtown and the ghosts are way more aggressive than usual."],
					["Tucker Foley", "My PDA counts at least ten ghosts near the towers. Time to bust some ectoplasm!"],
					["Sam Manson", "Go. We'll keep the crowds back. And try not to transform in front of everyone this time."]]
			if ch == 2 and st >= 4:
				return [["Tucker Foley", "That signal at Axion Labs? It's Skulker's tech. He's hunting you, dude."]]
			if ch >= 3:
				return [["Sam Manson", "The Ghost Zone? Bring back pictures. Not of Walker, though."]]
			return [["Sam Manson", "Nasty Burger is the only place in town that hasn't been haunted this week. Yet."]]
		"tucker":
			if ch >= 2:
				return [["Tucker Foley", "Pro tip: [Shift] boosts your flight and the aerial race ring is right outside. I've clocked my best time at... okay I can't fly."],
					["Tucker Foley", "Artifacts found: %d. Collect five and I'll rig your Ecto Scanner to show the rest on your map." % GameState.artifacts.size()]]
			return [["Tucker Foley", "Danny! Sam's looking for you. Something about the Nasty Burger being 'the only safe zone'."]]
		"frostbite":
			if talk_now:
				return [["Frostbite", "Great One! The legends spoke of your coming. The barrier between worlds is cracking, and the ghosts grow restless."],
					["Frostbite", "Your core is not like your other powers. It is ice. Let me show you... hold out your hand."],
					["Frostbite", "There. Cryokinesis is yours. Freeze your enemies, and build with the cold. Walker holds a prisoner who knows who is behind this."]]
			return [["Frostbite", "The Far Frozen will always welcome you, Great One."]]
		"lancer":
			return [["Mr. Lancer", "Mr. Fenton! Late AGAIN? Great Gatsby! Where do you keep disappearing to?"]]
	return [["???", "..."]]
