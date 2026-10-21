class_name Armory
## Permanent upgrades bought with coins on the title screen. They stay between runs.
## To add one: copy an entry in LIST, then say what it does in `apply_to_hero` (or where
## the game checks it).

const LIST := [
	{"id": "vigor", "title": "Vigor", "text": "+10 max health", "max": 5, "costs": [15, 30, 50, 80, 120]},
	{"id": "might", "title": "Might", "text": "+8% damage", "max": 5, "costs": [15, 30, 50, 80, 120]},
	{"id": "haste", "title": "Haste", "text": "+6% attack speed", "max": 5, "costs": [20, 40, 60, 90, 130]},
	{"id": "swift", "title": "Fleet Foot", "text": "+5% move speed", "max": 3, "costs": [20, 45, 80]},
	{"id": "luck", "title": "Lucky Bones", "text": "Hearts drop more often", "max": 3, "costs": [25, 50, 90]},
	{"id": "blessed", "title": "Blessed Start", "text": "Begin each run with a blessing", "max": 1, "costs": [150]},
	{"id": "second_wind", "title": "Second Wind", "text": "Once per run, survive a killing blow", "max": 1, "costs": [200]},
]

const SAVE_SECTION := "armory"


static func level(cfg: ConfigFile, id: String) -> int:
	return int(cfg.get_value(SAVE_SECTION, id, 0))


static func next_cost(cfg: ConfigFile, u: Dictionary) -> int:
	var lv := level(cfg, u.id)
	return -1 if lv >= u.max else int(u.costs[lv])


static func apply_to_hero(cfg: ConfigFile, h: Hero) -> void:
	var vigor := level(cfg, "vigor")
	h.max_health += 10.0 * vigor
	h.health = h.max_health
	h.damage *= 1.0 + 0.08 * level(cfg, "might")
	h.shots_per_second *= 1.0 + 0.06 * level(cfg, "haste")
	h.move_speed *= 1.0 + 0.05 * level(cfg, "swift")
	h.second_wind = level(cfg, "second_wind") > 0


static func heart_bonus(cfg: ConfigFile) -> float:
	return 0.04 * level(cfg, "luck")
