class_name Armory
## Permanent upgrades bought with coins on the title screen. They stay between runs.
## Later levels cost more (Oct 30 balance pass: the whole Armory was 1,590 coins, about one
## good run; it's now 2,425, with coins dropping at 60%).
## To add one: copy an entry in LIST, then say what it does in `apply_to_hero` (or where
## the game checks it).
##
## The Vault sells new blessings (the "vault" ones in upgrades.gd): bought once, they can
## turn up in the blessing picks of every run after.

const LIST := [
	{"id": "vigor", "title": "Vigor", "text": "+10 max health", "max": 5, "costs": [15, 40, 80, 130, 200]},
	{"id": "might", "title": "Might", "text": "+8% damage", "max": 5, "costs": [15, 40, 80, 130, 200]},
	{"id": "haste", "title": "Haste", "text": "+6% attack speed", "max": 5, "costs": [20, 50, 90, 140, 210]},
	{"id": "swift", "title": "Fleet Foot", "text": "+5% move speed", "max": 3, "costs": [20, 60, 120]},
	{"id": "luck", "title": "Lucky Bones", "text": "Hearts drop more often", "max": 3, "costs": [25, 70, 140]},
	{"id": "blessed", "title": "Blessed Start", "text": "Begin each run with a blessing", "max": 1, "costs": [250]},
	{"id": "second_wind", "title": "Second Wind", "text": "Once per run, survive a killing blow", "max": 1, "costs": [300]},
]

const SAVE_SECTION := "armory"

const VAULT := [
	{"id": "siphon", "cost": 300},
	{"id": "frozen_ground", "cost": 400},
	{"id": "executioner", "cost": 450},
	{"id": "flashfire", "cost": 450},
	{"id": "splinters", "cost": 600},
	{"id": "overcharge", "cost": 650},
]
const VAULT_SECTION := "vault"


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


## What a Vault blessing costs (0 if `id` isn't one).
static func vault_cost(id: String) -> int:
	for v: Dictionary in VAULT:
		if v.id == id:
			return int(v.cost)
	return 0


static func vault_has(cfg: ConfigFile, id: String) -> bool:
	return bool(cfg.get_value(VAULT_SECTION, id, false))


## The Vault blessings bought so far.
static func vault_owned(cfg: ConfigFile) -> Array:
	return VAULT.filter(func(v): return vault_has(cfg, v.id)).map(func(v): return v.id)


static func heart_bonus(cfg: ConfigFile) -> float:
	return 0.03 * level(cfg, "luck")
