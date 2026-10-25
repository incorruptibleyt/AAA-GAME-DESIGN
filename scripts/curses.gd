class_name Curses
## Crypt Pass extras: Curses that make a run harder for a bigger score, and the Daily
## Crypt, the same rooms, starting blessing and curse for everyone on a given day.

const LIST := [
	{"id": "brittle", "title": "Brittle Bones", "text": "Start every run with half health", "bonus": 0.5},
	{"id": "fragile", "title": "Fragile Chain", "text": "The Bone Chain drains twice as fast", "bonus": 0.4},
	{"id": "restless", "title": "Restless Dead", "text": "Skeletons move 20% faster", "bonus": 0.3},
	{"id": "famine", "title": "Famine", "text": "Skeletons never drop hearts", "bonus": 0.3},
	{"id": "gilded", "title": "Gilded Horde", "text": "Twice as many golden elites", "bonus": 0.3},
]

const SAVE_SECTION := "curses"


static func get_curse(id: String) -> Dictionary:
	for c: Dictionary in LIST:
		if c.id == id:
			return c
	return {}


## The curses the player switched on in the Curses screen.
static func chosen(cfg: ConfigFile) -> Array:
	var ids := []
	for c: Dictionary in LIST:
		if bool(cfg.get_value(SAVE_SECTION, c.id, false)):
			ids.append(c.id)
	return ids


## Score multiplier for a set of curses: 1 plus each curse's bonus.
static func score_mult(ids: Array) -> float:
	var m := 1.0
	for id in ids:
		m += float(get_curse(id).get("bonus", 0.0))
	return m


static func names(ids: Array) -> String:
	return ", ".join(ids.map(func(id): return get_curse(id).title))


# ---------------------------------------------------------------- Daily Crypt

## Today's date in UTC, so everyone's day turns over at the same moment.
static func today() -> String:
	return Time.get_date_string_from_system(true)


## A random number generator that gives the same numbers to everyone today.
static func daily_rng(salt := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [today(), salt])
	return rng


static func daily_curse() -> String:
	return LIST[daily_rng(1).randi() % LIST.size()].id


## Today's starting blessing: any blessing that doesn't need another one first.
static func daily_blessing() -> Dictionary:
	var pool := Upgrades.LIST.filter(func(u: Dictionary): return not u.has("needs") and u.id != "vitality")
	return pool[daily_rng(2).randi() % pool.size()]


static func daily_best(cfg: ConfigFile) -> int:
	return int(cfg.get_value("daily", today(), 0))
