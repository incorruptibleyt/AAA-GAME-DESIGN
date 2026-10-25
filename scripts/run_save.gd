class_name RunSave
## Saves the run in progress at the start of every room, so a phone call, or Android closing
## the game in the background, doesn't lose it. CONTINUE on the title screen picks the run up
## again at the start of that room (so closing the game can't undo a death, only replay the
## room). Dying, quitting or reaching the end of a run deletes the save.
##
## It lives in its own file, next to save.cfg.

const PATH := "user://run.cfg"
const VERSION := 1

## The hero's numbers that the Armory and blessings change during a run.
const HERO_PROPS := ["max_health", "health", "move_speed", "damage", "shots_per_second", "bolt_speed",
	"front_bolts", "diagonal_bolts", "rear_bolts", "pierce", "crit_chance", "burn_dps", "heal_on_kill",
	"harvest_heal", "bolt_size", "bolt_push", "splash", "armor", "second_wind", "frost", "frost_time",
	"perks", "special_charge", "magnet", "coin_bonus", "ward_max"]


static func exists() -> bool:
	return not read().is_empty()


## The saved run, or {} if there isn't one (or it's from an older version of the game).
static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or int(cfg.get_value("run", "version", 0)) != VERSION:
		return {}
	var data = cfg.get_value("run", "data", {})
	return data if data is Dictionary else {}


static func write(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "version", VERSION)
	cfg.set_value("run", "data", data)
	cfg.save(PATH)


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


## Coins are saved as soon as they're picked up. Remembering how many this run had when they
## were last saved lets CONTINUE take back the ones from the room that gets replayed.
static func bank(run_coins: int) -> void:
	var data := read()
	if data.is_empty():
		return
	data.banked = run_coins
	write(data)


static func hero_state(h: Hero) -> Dictionary:
	var out := {}
	for p in HERO_PROPS:
		var v = h.get(p)
		out[p] = v.duplicate() if v is Dictionary else v
	return out


static func apply_hero(h: Hero, state: Dictionary) -> void:
	for p in HERO_PROPS:
		if state.has(p):
			var v = state[p]
			h.set(p, v.duplicate() if v is Dictionary else v)
	h.health = minf(h.health, h.max_health)
