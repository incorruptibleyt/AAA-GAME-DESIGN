class_name Doors
## After each blessing (not in the first run) two doors lead on, and the player picks one.
## Each door promises something different: a path that fills the next blessing pick with
## one family, a healing spring, treasure, a shrine with a free reroll, or a champion
## (a purple elite waits, and the blessing after it is rare or better).
## A door is saved as {"kind", "family"}; everything else comes from `describe`.

const KINDS := ["path", "spring", "treasure", "shrine", "champion", "cursed", "dark", "traps"]
## Version 242 (whole-game review fix 13): the first doors that lead to a different room
## instead of a different reward. The Dark Room is lit only by the hero's lantern (the Omen
## of Night's light, game.gd _night_light) and pays two blessings; the Trap Hall has rows of
## spikes firing across it (trap_hall.gd) and heals fully once won. Neither comes right
## before the boss, on floor 1, in the Crypt Race or in the Queen Hunt.
const ROOM_KINDS := ["dark", "traps"]
## Version 219 (review 4 fix 30): the Cursed Door, a real risk for a reward. One Omen
## (loops.gd) holds until the floor's boss is beaten, and every coin on the floor is worth
## 60% more. Version 219 review (Phase 0): +40%, never on floors 1-2, never right before the
## boss, never while a curse already holds, and the door says what the Omen does.
const CURSED_COINS := 0.4
const CURSE_OMENS := ["graves", "stalker", "night", "bones", "blades", "horde"]   # v241: three rule Omens
## Healing Spring: share of max health healed. Treasure Room: extra coins in the next room.
const SPRING_HEAL := 0.3
const TREASURE_COINS := 0.6
const PATHS := {"bolt": "Hunter's Path", "flame": "Burning Path", "frost": "Frozen Path", "bone": "Bone Path"}


## Two different doors. `boss_next`: no Champion's Door before the boss, and no Treasure
## Room either (version 145: its gold room and its coins belong to a room of skeletons, and
## the boss room has only the boss).
## `can_reroll`: no Shrine with Narrow Path. `taken`: the hero's blessings; a path is only
## offered for a family with at least 2 cards the hero can still get, so its promise ("2 of 3
## are ... blessings") is kept. The Daily Crypt passes its own `rng`, so everyone gets the
## same doors.
## `full_health`: the hero has 90% health or more, so a Healing Spring would be wasted
## (version 212, critic fix #5). The Daily Crypt passes false: everyone gets the same doors.
static func offer(rng: RandomNumberGenerator, boss_next: bool, can_reroll: bool, taken := {}, full_health := false) -> Array:
	var families: Array = PATHS.keys().filter(func(f): return Upgrades.family_left(taken, f) >= 2)
	# Version 213 (hardest review fix #11): no Champion's Door once no rare cards are left
	# (it promises "rare or better"; with none left it handed out commons).
	var no_rares := not taken.is_empty() and Upgrades.rares_left(taken) == 0
	var kinds := KINDS.filter(func(k): return not (k in ["champion", "treasure"] and boss_next) and not (k == "shrine" and not can_reroll) \
		and not (k == "champion" and no_rares) \
		and not (k == "cursed" and (Game.event != "" or Game.daily or Game.race or boss_next \
			or Game.floor_num <= 2 or Game._curse_omen != "")) \
		and not (k in ROOM_KINDS and (boss_next or Game.race or Game.event == "hunt" or Game.floor_num <= 1)) \
		and not (k == "path" and families.is_empty()) and not (k == "spring" and full_health))
	var out := []
	while out.size() < 2 and not kinds.is_empty():
		var kind: String = kinds[rng.randi() % kinds.size()]
		kinds.erase(kind)
		var d := {"kind": kind, "family": families[rng.randi() % families.size()] if kind == "path" else ""}
		if kind == "cursed":
			d.omen = CURSE_OMENS[rng.randi() % CURSE_OMENS.size()]
		out.append(d)
	return out


## Title, text, colour and icon for a door.
## `rerolls`: how many the player has now, for the Shrine's text (-1 leaves it out).
static func describe(door: Dictionary, rerolls := -1) -> Dictionary:
	match str(door.get("kind", "")):
		"path":
			var fam: Dictionary = Upgrades.FAMILIES[door.family]
			return {"title": PATHS[door.family], "text": "Your next pick: 2 of 3\nare %s blessings" % fam.name,
				"color": fam.color, "icon": "", "family": door.family}
		"spring":
			return {"title": "Healing Spring", "text": "Heal %d%% of your\nhealth now" % roundi(SPRING_HEAL * 100),
				"color": Color(0.5, 1.0, 0.6), "icon": "vitality", "family": "bone"}
		"treasure":
			return {"title": "Treasure Room", "text": "+%d%% coins in\nthe next room" % roundi(TREASURE_COINS * 100),
				"color": Color(1.0, 0.82, 0.3), "icon": "greed", "family": "bone"}
		"shrine":
			# version 212 (critic fix #5): says how many you have
			var text := "+1 reroll\nfor the blessings" if rerolls < 0 else "+1 blessing reroll\n(you have %d)" % rerolls
			return {"title": "Shrine", "text": text, "color": Color(0.6, 0.75, 1.0),
				"icon": "door_shrine", "family": "bolt"}
		"champion":
			return {"title": "Champion's Door", "text": "An elite waits.\nNext pick: rare\nor better",
				"color": Color(1.0, 0.55, 0.3), "icon": "door_champion", "family": "bolt"}
		"dark":
			return {"title": "Dark Room", "text": "Lit only round you.\nPick 2 blessings\nafter it",
				"color": Color(0.62, 0.66, 1.0), "icon": "door_dark", "family": "frost"}
		"traps":
			return {"title": "Trap Hall", "text": "Spike rows fire\nacross the hall.\nFull heal after it",
				"color": Color(1.0, 0.5, 0.38), "icon": "door_traps", "family": "flame"}
		"cursed":
			return {"title": "Cursed Door", "text": "%s\nuntil the boss.\n+%d%% coins" % [omen_text(str(door.get("omen", "blades"))), roundi(CURSED_COINS * 100)],
				"color": Color(0.85, 0.5, 1.0), "icon": "greed", "family": "bolt"}
	return {}


## What the Omen does, in plain words ("Skeletons hit 25% harder"; the rule Omens have a
## shorter line that fits on the door card).
static func omen_text(id: String) -> String:
	var o := Loops.get_omen(id)
	return str(o.get("short", o.text)) if not o.is_empty() else omen_title(id)


static func omen_title(id: String) -> String:
	for o: Dictionary in Loops.OMENS:
		if o.id == id:
			return str(o.title)
	return id


## A line shown as the door's room starts ("" when its promise was kept at once).
static func room_tip(door: Dictionary) -> String:
	match str(door.get("kind", "")):
		"path":
			return "%s: your next pick leans %s" % [PATHS[door.family], Upgrades.FAMILIES[door.family].name]
		"treasure":
			return "Treasure Room: +%d%% coins here" % roundi(TREASURE_COINS * 100)
		"champion":
			return "Champion's Door: an elite waits"
		"dark":
			return "Dark Room: only your lantern lights it. Two blessings after!"
		"traps":
			return "Trap Hall: keep off the red rows. Lead skeletons onto them!"
		"cursed":
			var o: Dictionary = {}
			for x: Dictionary in Loops.OMENS:
				if x.id == str(door.get("omen", "")):
					o = x
			return "Cursed: %s. +%d%% coins" % [str(o.get("text", "")), roundi(CURSED_COINS * 100)]
	return ""
