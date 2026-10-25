class_name Doors
## After each blessing (not in the first run) two doors lead on, and the player picks one.
## Each door promises something different: a path that fills the next blessing pick with
## one family, a healing spring, treasure, a shrine with a free reroll, or a champion
## (a golden elite waits, and the blessing after it is rare or better).
## A door is saved as {"kind", "family"}; everything else comes from `describe`.

const KINDS := ["path", "spring", "treasure", "shrine", "champion"]
## Healing Spring: share of max health healed. Treasure Room: extra coins in the next room.
const SPRING_HEAL := 0.3
const TREASURE_COINS := 0.6
const PATHS := {"bolt": "Hunter's Path", "flame": "Burning Path", "frost": "Frozen Path", "bone": "Bone Path"}


## Two different doors. `boss_next`: no Champion's Door before the boss.
## `can_reroll`: no Shrine with Narrow Path. The Daily Crypt passes its own `rng`, so
## everyone gets the same doors.
static func offer(rng: RandomNumberGenerator, boss_next: bool, can_reroll: bool) -> Array:
	var kinds := KINDS.filter(func(k): return not (k == "champion" and boss_next) and not (k == "shrine" and not can_reroll))
	var out := []
	while out.size() < 2 and not kinds.is_empty():
		var kind: String = kinds[rng.randi() % kinds.size()]
		kinds.erase(kind)
		var families: Array = PATHS.keys()
		out.append({"kind": kind, "family": families[rng.randi() % families.size()] if kind == "path" else ""})
	return out


## Title, text, colour and icon for a door.
static func describe(door: Dictionary) -> Dictionary:
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
			return {"title": "Shrine", "text": "+1 reroll\nfor the blessings", "color": Color(0.6, 0.75, 1.0),
				"icon": "door_shrine", "family": "bolt"}
		"champion":
			return {"title": "Champion's Door", "text": "A golden elite waits.\nNext pick: rare or better",
				"color": Color(1.0, 0.55, 0.3), "icon": "door_champion", "family": "bolt"}
	return {}


## A line shown as the door's room starts ("" when its promise was kept at once).
static func room_tip(door: Dictionary) -> String:
	match str(door.get("kind", "")):
		"path":
			return "%s: your next pick leans %s" % [PATHS[door.family], Upgrades.FAMILIES[door.family].name]
		"treasure":
			return "Treasure Room: +%d%% coins here" % roundi(TREASURE_COINS * 100)
		"champion":
			return "Champion's Door: a golden elite waits"
	return ""
