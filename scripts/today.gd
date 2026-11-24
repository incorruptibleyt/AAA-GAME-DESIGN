class_name Today
## Version 311 (player panel fix 3, short sessions, part 3): TODAY'S GOALS. Three small goals
## a day, picked from GOALS for the day (the same for everyone, as the Daily Crypt is), each
## worth GOAL_COINS coins when it's done, and the three together open the Today Chest
## (CHEST_COINS coins and a Bone Drop). They change when the Daily Crypt does.
##
## Why: the player panel's casual player had nothing to do in a five-minute visit, and nothing
## said "come back tomorrow". Goals any run can finish (Quick Play too) give a short visit a
## reason and a finish line.
##
## Progress is counted in `pending` as it happens (Game calls add / best) and is saved with the
## run's other numbers at the end screens (Game._bank_today), like the Bone Road's bones.

const SECTION := "today"
const GOAL_COINS := 100
const CHEST_COINS := 250
const COUNT := 3

## Each goal: what it counts, the amounts by difficulty (easy, middle, hard) and its words.
## "best" goals keep the day's best instead of a total.
const GOALS := [
	{"id": "kills", "need": [50, 90, 140], "text": "Destroy %d skeletons"},
	{"id": "elites", "need": [2, 3, 5], "text": "Destroy %d elite skeletons"},
	{"id": "specials", "need": [6, 10, 16], "text": "Use your special %d times"},
	{"id": "rooms", "need": [5, 8, 12], "text": "Clear %d rooms"},
	{"id": "bosses", "need": [1, 2, 3], "text": "Beat %d bosses"},
	{"id": "quick", "need": [1, 2, 3], "text": "Win %d Quick Plays"},
	{"id": "chain", "need": [20, 25, 30], "best": true, "text": "Reach a x%s Bone Chain"},
	{"id": "coins", "need": [150, 300, 500], "text": "Pick up %d coins in runs"},
]

## Counted since the last save (Game banks them at the end screens and the title).
static var pending := {}
## The best Bone Chain this run (x10, so x2.5 is 25), for the "chain" goal.
static var best_chain := 0


static func add(id: String, n := 1) -> void:
	if n > 0:
		pending[id] = int(pending.get(id, 0)) + n


static func best(id: String, v: int) -> void:
	if v > int(pending.get(id, 0)):
		pending[id] = v


static func def(id: String) -> Dictionary:
	for g: Dictionary in GOALS:
		if g.id == id:
			return g
	return {}


## Today's three goals: [{id, need, text}], one easy, one middle and one hard, three different
## kinds. Picked once a day (from the day's own seed) and kept in the save. Quick Play goals
## only once Quick Play is open.
static func goals(cfg: ConfigFile, day := "") -> Array:
	if day == "":
		day = Curses.today()
	if str(cfg.get_value(SECTION, "day", "")) != day:
		_new_day(cfg, day)
	return cfg.get_value(SECTION, "goals", [])


static func _new_day(cfg: ConfigFile, day: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("today" + day)
	var pool := GOALS.filter(func(g: Dictionary) -> bool:
		return g.id != "quick" or Game.quick_open(cfg))
	var out := []
	for tier in COUNT:
		var g: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(g)
		var need := int(g.need[tier])
		out.append({"id": g.id, "need": need, "text": text_of(g.id, need)})
	cfg.set_value(SECTION, "day", day)
	cfg.set_value(SECTION, "goals", out)
	cfg.set_value(SECTION, "have", {})
	cfg.set_value(SECTION, "paid", [])
	cfg.set_value(SECTION, "chest", false)


static func text_of(id: String, need: int) -> String:
	var g := def(id)
	if g.get("best", false):
		return str(g.text) % str(snappedf(need / 10.0, 0.1))
	return str(g.text) % need


static func have(cfg: ConfigFile, id: String) -> int:
	return int((cfg.get_value(SECTION, "have", {}) as Dictionary).get(id, 0))


static func done(cfg: ConfigFile, g: Dictionary) -> bool:
	return have(cfg, g.id) >= int(g.need)


static func done_count(cfg: ConfigFile) -> int:
	var n := 0
	for g: Dictionary in goals(cfg):
		if done(cfg, g):
			n += 1
	return n


## "45/90", or "x2.1/x2.5" for the chain.
static func progress_text(cfg: ConfigFile, g: Dictionary) -> String:
	var h := mini(have(cfg, g.id), int(g.need))
	if def(g.id).get("best", false):
		return "x%s / x%s" % [str(snappedf(maxi(h, 10) / 10.0, 0.1)), str(snappedf(int(g.need) / 10.0, 0.1))]
	return "%d / %d" % [h, int(g.need)]


## The three goals are done and the chest not opened yet.
static func chest_ready(cfg: ConfigFile) -> bool:
	return done_count(cfg) >= COUNT and not bool(cfg.get_value(SECTION, "chest", false))


static func chest_open(cfg: ConfigFile) -> bool:
	return bool(cfg.get_value(SECTION, "chest", false))


## Moves `pending` into today's goals in `cfg` (the caller saves it). Returns the goals this
## finished, each paid GOAL_COINS (added to the save's coins by the caller).
static func bank(cfg: ConfigFile) -> Array:
	var list := goals(cfg)
	var h: Dictionary = (cfg.get_value(SECTION, "have", {}) as Dictionary).duplicate()
	for id: String in pending:
		if def(id).get("best", false):
			h[id] = maxi(int(h.get(id, 0)), int(pending[id]))
		else:
			h[id] = int(h.get(id, 0)) + int(pending[id])
	pending.clear()
	cfg.set_value(SECTION, "have", h)
	var paid: Array = (cfg.get_value(SECTION, "paid", []) as Array).duplicate()
	var finished := []
	for g: Dictionary in list:
		if int(h.get(g.id, 0)) >= int(g.need) and not paid.has(g.id):
			paid.append(g.id)
			finished.append(g)
	cfg.set_value(SECTION, "paid", paid)
	return finished


## Opens the Today Chest in `cfg` (the caller pays the coins and saves). False if it isn't ready.
static func open_chest(cfg: ConfigFile) -> bool:
	if not chest_ready(cfg):
		return false
	cfg.set_value(SECTION, "chest", true)
	Drops.add(cfg)
	return true
