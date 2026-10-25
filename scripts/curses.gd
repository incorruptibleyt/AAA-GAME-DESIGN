class_name Curses
## Crypt Pass extras.
##
## Curses make a run harder for a bigger score. Each has a level, and the levels of the
## curses you switch on add up to your Curse Level (+15% score per level). Beating the floor
## 5 boss at a Curse Level earns that hero a reward (MASTERY). Restless Dead is free for
## everyone; the rest come with the Crypt Pass.
##
## The Daily Crypt is 3 floors with the same rooms, hero and three rules for everyone each
## day. It turns over at 07:00 UTC. Everyone can play it on Sundays.

const LIST := [
	{"id": "restless", "title": "Restless Dead", "text": "Skeletons move 20% faster", "level": 1, "free": true},
	{"id": "gilded", "title": "Gilded Horde", "text": "Twice as many golden elites", "level": 1},
	{"id": "narrow", "title": "Narrow Path", "text": "Two blessings to choose from, no reroll", "level": 1},
	{"id": "blood", "title": "Blood Price", "text": "Your special costs a quarter of your health", "level": 1},
	{"id": "fragile", "title": "Fragile Chain", "text": "The Bone Chain drains twice as fast", "level": 2},
	{"id": "famine", "title": "Famine", "text": "Skeletons never drop hearts", "level": 2},
	{"id": "hourglass", "title": "Hourglass", "text": "45 s a room, then the chain drains fast", "level": 2},
	{"id": "gravepact", "title": "Grave Pact", "text": "The chain only grows right after a dash", "level": 2},
	{"id": "twin", "title": "Twin Wardens", "text": "Two bosses at once, each a bit weaker", "level": 2},
	{"id": "brittle", "title": "Brittle Bones", "text": "Start every run with half health", "level": 3},
]

const BONUS_PER_LEVEL := 0.15
const SAVE_SECTION := "curses"
const MASTERY_SECTION := "mastery"
## Hourglass: seconds per room (the boss gets longer), then the chain drains fast and
## skeletons hit harder.
const HOURGLASS_ROOM := 45.0
const HOURGLASS_BOSS := 75.0

## Rewards for beating the floor 5 boss at these Curse Levels, earned per hero.
const MASTERY := [
	{"level": 1, "title": "Cursed", "text": "Title: Cursed"},
	{"level": 2, "title": "Crimson Lantern", "text": "Your hero's light turns blood red"},
	{"level": 4, "title": "Bone Crown", "text": "Title: Bone Crown"},
	{"level": 6, "title": "Grave Aura", "text": "A red glow at your hero's feet"},
	{"level": 8, "title": "Dread", "text": "Title: Dread"},
	{"level": 10, "title": "Golden Bolts", "text": "Your hero's shots turn gold"},
]


static func get_curse(id: String) -> Dictionary:
	for c: Dictionary in LIST:
		if c.id == id:
			return c
	for c: Dictionary in RULES:
		if c.id == id:
			return c
	return {}


static func is_curse(id: String) -> bool:
	for c: Dictionary in LIST:
		if c.id == id:
			return true
	return false


## Free players get the free curse; the Crypt Pass opens them all.
static func available(id: String, owned: bool) -> bool:
	return owned or bool(get_curse(id).get("free", false))


## The curses the player switched on in the Curses screen (and is allowed to use).
static func chosen(cfg: ConfigFile, owned := true) -> Array:
	var ids := []
	for c: Dictionary in LIST:
		if bool(cfg.get_value(SAVE_SECTION, c.id, false)) and available(c.id, owned):
			ids.append(c.id)
	return ids


## Curse Level: the levels of the curses in `ids` added up (daily rules that aren't curses
## count nothing).
static func level_of(ids: Array) -> int:
	var n := 0
	for id in ids:
		if is_curse(id):
			n += int(get_curse(id).level)
	return n


static func max_level() -> int:
	return level_of(LIST.map(func(c): return c.id))


## Score multiplier for a set of curses: +15% per Curse Level.
static func score_mult(ids: Array) -> float:
	return 1.0 + BONUS_PER_LEVEL * level_of(ids)


static func names(ids: Array) -> String:
	return ", ".join(ids.map(func(id): return get_curse(id).get("title", id)))


# ---------------------------------------------------------------- hero rewards

## The highest Curse Level this hero has beaten the floor 5 boss at.
static func mastery(cfg: ConfigFile, hero_id: String) -> int:
	return int(cfg.get_value(MASTERY_SECTION, hero_id, 0))


## Saves a floor 5 (or deeper) boss win at `level` and returns the rewards it newly earned.
static func record_mastery(cfg: ConfigFile, hero_id: String, level: int) -> Array:
	var before := mastery(cfg, hero_id)
	if level <= before:
		return []
	cfg.set_value(MASTERY_SECTION, hero_id, level)
	return MASTERY.filter(func(m): return m.level > before and m.level <= level)


## The best title a hero has earned ("" before the first reward).
static func mastery_title(level: int) -> String:
	var t := ""
	for m: Dictionary in MASTERY:
		if level >= m.level and m.text.begins_with("Title"):
			t = m.title
	return t


static func next_reward(level: int) -> Dictionary:
	for m: Dictionary in MASTERY:
		if m.level > level:
			return m
	return {}


# ---------------------------------------------------------------- Daily Crypt

const DAILY_FLOORS := 3
## The daily day starts at 07:00 UTC, when Google Play's daily leaderboards reset too.
const DAY_START_HOURS := 7
## Daily Crypt #1.
const FIRST_DAY := "2026-10-24"

## Today's rules come one from each slot: "help" makes the run easier, "harm" is a curse,
## "trade" is a bit of both.
const RULES := [
	{"id": "blessed", "kind": "help", "title": "Blessed Start", "text": "Begin with today's blessing"},
	{"id": "rich", "kind": "help", "title": "Rich Veins", "text": "+50% coins"},
	{"id": "dice", "kind": "help", "title": "Loaded Dice", "text": "Three free rerolls"},
	{"id": "quick", "kind": "help", "title": "Quick Hands", "text": "Your special charges twice as fast"},
	{"id": "hearty", "kind": "help", "title": "Hearty", "text": "Hearts heal twice as much"},
	{"id": "longlinks", "kind": "help", "title": "Long Links", "text": "The Bone Chain lasts 1.5 s longer"},
	{"id": "glass", "kind": "trade", "title": "Glass Bolts", "text": "+50% damage, but 30% less health"},
	{"id": "frenzy", "kind": "trade", "title": "Frenzy", "text": "Skeletons 25% faster, kills worth double"},
	{"id": "swarm", "kind": "trade", "title": "Swarm", "text": "One more skeleton a wave, kills worth +50%"},
	{"id": "hunt", "kind": "trade", "title": "Elite Hunt", "text": "Twice the elites, each worth triple"},
]
## Curses that can be the daily's "harm" rule (Gilded Horde is left out: Elite Hunt does it).
const DAILY_CURSES := ["restless", "narrow", "blood", "fragile", "famine", "hourglass", "gravepact", "twin", "brittle"]
## Rules that cancel each other out never come on the same day.
const CLASHES := [["dice", "narrow"], ["hearty", "famine"]]

## One theme per weekday (0 = Sunday), so the week has a rhythm.
const THEMES := [
	{"name": "Free Crypt Sunday", "text": "Free for everyone today", "hero": ""},
	{"name": "Marrow Monday", "text": "The chain climbs to x4", "hero": "rogue", "perk": "marrow"},
	{"name": "Tough Tuesday", "text": "Two curses, no help", "hero": "knight", "slots": ["harm", "harm", "trade"]},
	{"name": "Wild Wednesday", "text": "Two trade-offs", "hero": "barbarian", "slots": ["help", "trade", "trade"]},
	{"name": "Thunder Thursday", "text": "Start with Twin Bolts", "hero": "mage", "perk": "multishot"},
	{"name": "Frenzy Friday", "text": "The dead are restless tonight", "hero": "rogue", "force": "frenzy"},
	{"name": "Swarm Saturday", "text": "The crypt is packed", "hero": "knight", "force": "swarm"},
]
## Sunday's hero takes turns, so free players get to try a hero they don't own.
const SUNDAY_HEROES := ["knight", "barbarian", "mage"]


## Seconds since 1970, shifted so the daily day starts at 07:00 UTC.
static func _day_clock() -> int:
	return int(Time.get_unix_time_from_system()) - DAY_START_HOURS * 3600


## The daily's date ("2026-10-25"). `offset` -1 is yesterday's.
static func today(offset := 0) -> String:
	return Time.get_date_string_from_unix_time(_day_clock() + offset * 86400)


static func _unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date)


## Daily Crypt #1 was FIRST_DAY.
static func day_number(date := "") -> int:
	if date == "":
		date = today()
	return (_unix(date) - _unix(FIRST_DAY)) / 86400 + 1


static func weekday(date := "") -> int:
	if date == "":
		date = today()
	return int(Time.get_date_dict_from_unix_time(_unix(date)).weekday)


static func theme(date := "") -> Dictionary:
	return THEMES[weekday(date)]


static func free_today() -> bool:
	return weekday() == 0


static func open_today(owned: bool) -> bool:
	return owned or free_today()


static func daily_hero(date := "") -> String:
	var t := theme(date)
	if t.hero != "":
		return t.hero
	return SUNDAY_HEROES[(day_number(date) / 7) % SUNDAY_HEROES.size()]


## Seconds until the next Daily Crypt.
static func seconds_left() -> int:
	return 86400 - posmod(_day_clock(), 86400)


## A random number generator that gives everyone the same numbers on `date`.
static func daily_rng(salt := 0, date := "") -> RandomNumberGenerator:
	if date == "":
		date = today()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [date, salt])
	return rng


static func _pool(kind: String) -> Array:
	if kind == "harm":
		return DAILY_CURSES.duplicate()
	return RULES.filter(func(r): return r.kind == kind).map(func(r): return r.id)


static func _clash(a: String, b: String) -> bool:
	return CLASHES.any(func(pair): return pair.has(a) and pair.has(b) and a != b)


## Rules worked out so far, by date. Each day avoids the rules really shown the day before,
## so days are worked out in order from Daily Crypt #1.
static var _rules_by_day := {}


## The three rules for `date` (today by default). No rule comes back on two days running.
static func daily_rules(date := "") -> Array:
	if date == "":
		date = today()
	if _unix(date) < _unix(FIRST_DAY):
		return _pick_rules(date, [])
	if not _rules_by_day.has(date):
		var prev := []
		var day := _unix(FIRST_DAY)
		while day <= _unix(date):
			var d := Time.get_date_string_from_unix_time(day)
			if not _rules_by_day.has(d):
				_rules_by_day[d] = _pick_rules(d, prev)
			prev = _rules_by_day[d]
			day += 86400
	return (_rules_by_day[date] as Array).duplicate()


static func _pick_rules(date: String, avoid: Array) -> Array:
	var t := theme(date)
	var slots: Array = t.get("slots", ["help", "harm", "trade"])
	var force: String = t.get("force", "")
	# Tomorrow's set rule (Frenzy Friday, Swarm Saturday) isn't picked today, so it isn't on two days running.
	var tomorrow: String = theme(Time.get_date_string_from_unix_time(_unix(date) + 86400)).get("force", "")
	var rng := daily_rng(1, date)
	var out := []
	for i in slots.size():
		if force != "" and i == slots.size() - 1:
			out.append(force)
			continue
		var pool := _pool(slots[i]).filter(func(id): return not out.has(id) and not avoid.has(id) and id != force and id != tomorrow \
				and not out.any(func(o): return _clash(o, id)) and not _clash(force, id))
		out.append(pool[rng.randi() % pool.size()])
	return out


## Today's starting blessing (with Blessed Start): any blessing that doesn't need another first.
static func daily_blessing(date := "") -> Dictionary:
	var pool := Upgrades.LIST.filter(func(u: Dictionary): return not u.has("needs") and u.id != "vitality")
	return pool[daily_rng(2, date).randi() % pool.size()]


## The best Official score on `date`.
static func daily_best(cfg: ConfigFile, date := "") -> int:
	return int(cfg.get_value("daily", date if date != "" else today(), 0))


## Each day has one Official run that counts; after that it's Practice.
static func official_used(cfg: ConfigFile, date := "") -> bool:
	return bool(cfg.get_value("daily", (date if date != "" else today()) + "_official", false))


static func use_official(cfg: ConfigFile, date: String) -> void:
	cfg.set_value("daily", date + "_official", true)
