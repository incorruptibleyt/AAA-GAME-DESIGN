class_name Events
## Big limited-time events (version 134). Jesse, Nov 10 2026: events have to be
## extraordinary, big and flashy, like a Supercell event, not a small weekly twist. So an
## event takes over the whole game for two weeks:
##
##   * its own crypt, skeletons, rule (the Moon Surge) and boss, in an event run of three
##     floors (Game.event == "run");
##   * a boss hunt with five difficulty tiers, each paying out again every day (Game.event
##     == "hunt");
##   * Moon Shards, earned by both, filling a 30-step event road whose prizes end in a full
##     event set every hero can wear (hero_style.gd EXTRA "event");
##   * Moon Caskets, event chests opened with a big reveal (drop_screen.gd), by rarity;
##   * three chapters with a story, each opening something new, and a double-shard weekend;
##   * the title screen and menus taken over (menu_backdrop.gd), with its own music.
##
## Everything runs offline: an event starts and ends by the date, at 07:00 UTC like the
## Daily Crypt, the same for everyone. An event ships inside an update before its start.
## `forced_day` (the robot's `event=N`, or the lab) plays any day of it.

const BLOOD_MOON := {
	"id": "blood_moon",
	"name": "BLOOD MOON",
	"start": "2026-11-20",
	"days": 14,
	"color": Color(1.0, 0.24, 0.2),
	"gold": Color(1.0, 0.78, 0.4),
	"story": "Once in a hundred years the moon bleeds. Tonight the Blood Moon Queen wakes, and every skeleton in the crypt answers her call.",
	"chapters": [
		{"name": "MOONRISE", "day": 1, "text": "The Blood Moon run opens, and the Queen Hunt tiers 1-2.", "tiers": 2},
		{"name": "THE HUNT", "day": 6, "text": "Hunt tiers 3-4 open. Double shards on the weekend!", "tiers": 4},
		{"name": "ECLIPSE", "day": 11, "text": "The moon goes black. Tier 5, Eclipse, opens: the Queen at her worst.", "tiers": 5},
	],
	# Event days (1 = the first) worth double Moon Shards: Saturday and Sunday, Nov 28-29.
	"double": [9, 10],
}
const LIST := [BLOOD_MOON]

## Days before the start when the title shows what's coming.
const TEASE_DAYS := 7

## Moon Shards: a room cleared, an elite, a skeleton killed during a Moon Surge, a floor
## boss, the Queen. A full event run (3 floors) is worth about 200; a hunt win 35-95.
const ROOM_SHARDS := 3
const ELITE_SHARDS := 2
const SURGE_SHARDS := 1
const BOSS_SHARDS := 15
const QUEEN_SHARDS := 40
const RUN_FLOORS := 3
## The Crypt Pass earns half as many again.
const PASS_BONUS := 0.5

## The Queen Hunt: straight to the Queen, with blessings to start, on one of five tiers.
## hp: the Queen's health; floor: how deep the hunt counts as (skeleton toughness);
## gifts: blessings to start with; shards: a win (half again for the day's first).
const TIERS := [
	{"name": "TIER I", "hp": 0.75, "floor": 2, "gifts": 4, "shards": 35},
	{"name": "TIER II", "hp": 1.0, "floor": 3, "gifts": 5, "shards": 50},
	{"name": "TIER III", "hp": 1.25, "floor": 4, "gifts": 6, "shards": 65},
	{"name": "TIER IV", "hp": 1.4, "floor": 5, "gifts": 7, "shards": 80},
	{"name": "ECLIPSE", "hp": 1.6, "floor": 6, "gifts": 8, "shards": 100},
]

## The event road: 30 steps, about 2,400 shards in all (a couple of runs a day for the two
## weeks). kind: casket (n Moon Caskets), coins, drop (Bone Drops), lucky (Lucky Starts) or
## look (an event look: [slot, key] in HeroStyle.EXTRA).
const ROAD := [
	{"at": 40, "kind": "casket", "n": 1},
	{"at": 85, "kind": "coins", "n": 100},
	{"at": 130, "kind": "casket", "n": 1},
	{"at": 180, "kind": "drop", "n": 1},
	{"at": 230, "kind": "casket", "n": 1},
	{"at": 285, "kind": "coins", "n": 150},
	{"at": 340, "kind": "lucky", "n": 1},
	{"at": 400, "kind": "casket", "n": 1},
	{"at": 460, "kind": "coins", "n": 200},
	{"at": 525, "kind": "look", "look": ["outfit", "blood_moon"]},
	{"at": 595, "kind": "casket", "n": 1},
	{"at": 665, "kind": "drop", "n": 2},
	{"at": 740, "kind": "coins", "n": 250},
	{"at": 815, "kind": "casket", "n": 2},
	{"at": 895, "kind": "lucky", "n": 1},
	{"at": 975, "kind": "coins", "n": 300},
	{"at": 1060, "kind": "casket", "n": 1},
	{"at": 1145, "kind": "look", "look": ["head", "moon_crown"]},
	{"at": 1235, "kind": "drop", "n": 2},
	{"at": 1325, "kind": "casket", "n": 2},
	{"at": 1420, "kind": "coins", "n": 350},
	{"at": 1520, "kind": "lucky", "n": 2},
	{"at": 1620, "kind": "casket", "n": 1},
	{"at": 1725, "kind": "look", "look": ["glow", "moonlight"]},
	{"at": 1830, "kind": "coins", "n": 400},
	{"at": 1940, "kind": "drop", "n": 3},
	{"at": 2050, "kind": "casket", "n": 2},
	{"at": 2165, "kind": "coins", "n": 500},
	{"at": 2280, "kind": "casket", "n": 3},
	{"at": 2400, "kind": "look", "look": ["aura", "blood_moon"]},
]

## Moon Caskets: weight out of 100, by rarity (drop_screen.gd shows them in the colours of
## the blessing cards, and Mythic in the event's own crimson).
const CASKETS := [
	{"id": "rare", "name": "RARE", "weight": 52, "color": Color(0.35, 0.9, 0.45)},
	{"id": "super", "name": "SUPER RARE", "weight": 28, "color": Color(0.35, 0.65, 1.0)},
	{"id": "epic", "name": "EPIC", "weight": 13, "color": Color(0.75, 0.4, 1.0)},
	{"id": "mythic", "name": "MYTHIC", "weight": 5, "color": Color(1.0, 0.25, 0.3)},
	{"id": "legendary", "name": "LEGENDARY", "weight": 2, "color": Color(1.0, 0.78, 0.25)},
]
## Every casket earned is kept (version 140; before, any past 20 were lost).
const MAX_CASKETS := 999

## Lab and robot: play this day of the first event (0 = the real date).
static var forced_day := 0


# ---------------------------------------------------------------- the calendar

static func _unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date)


## Day of event `e` today: 1 on its first day, 0 or less before it, past e.days after it.
static func day(e: Dictionary = BLOOD_MOON) -> int:
	if forced_day != 0:
		return forced_day
	return (_unix(Curses.today()) - _unix(e.start)) / 86400 + 1


## The event on now, or {}.
static func current() -> Dictionary:
	for e: Dictionary in LIST:
		var d := day(e)
		if d >= 1 and d <= int(e.days):
			return e
	return {}


static func active() -> bool:
	return not current().is_empty()


## The next event within TEASE_DAYS of starting, or {}.
static func coming() -> Dictionary:
	for e: Dictionary in LIST:
		var d := day(e)
		if d <= 0 and d > -TEASE_DAYS:
			return e
	return {}


## Seconds until the event on now ends (or the coming one starts).
static func seconds_left(e: Dictionary) -> int:
	var d := day(e)
	# Seconds since today's event day started (07:00 UTC).
	var into := int(Time.get_unix_time_from_system()) - (_unix(Curses.today()) + Curses.DAY_START_HOURS * 3600)
	if d <= 0:
		return (1 - d) * 86400 - into
	return (int(e.days) - d + 1) * 86400 - into


## "6d 4h", "3h 20m", "12m".
static func time_text(s: int) -> String:
	s = maxi(s, 0)
	if s >= 86400:
		return "%dd %dh" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	return "%dm" % maxi(1, s / 60)


## The chapter on now (0, 1, 2).
static func chapter(e: Dictionary = BLOOD_MOON) -> int:
	var d := day(e)
	var c := 0
	for i in e.chapters.size():
		if d >= int(e.chapters[i].day):
			c = i
	return c


static func chapter_info(e: Dictionary = BLOOD_MOON) -> Dictionary:
	return e.chapters[chapter(e)]


## The Eclipse: the last chapter, when the moon goes black.
static func eclipse(e: Dictionary = BLOOD_MOON) -> bool:
	return chapter(e) == e.chapters.size() - 1


## Days until the next chapter (0 in the last one).
static func days_to_next_chapter(e: Dictionary = BLOOD_MOON) -> int:
	var c := chapter(e)
	if c + 1 >= e.chapters.size():
		return 0
	return int(e.chapters[c + 1].day) - day(e)


static func double_today(e: Dictionary = BLOOD_MOON) -> bool:
	return e.double.has(day(e))


## Shards for `n` earned: doubled on double days, half again with the Crypt Pass.
static func boosted(n: int, owned: bool, e: Dictionary = BLOOD_MOON) -> int:
	var m := (2.0 if double_today(e) else 1.0) * (1.0 + PASS_BONUS if owned else 1.0)
	return roundi(n * m)


# ---------------------------------------------------------------- the save

static func section(e: Dictionary = BLOOD_MOON) -> String:
	return "event_" + str(e.id)


static func shards(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	return int(cfg.get_value(section(e), "shards", 0))


static func add_shards(cfg: ConfigFile, n: int, e: Dictionary = BLOOD_MOON) -> void:
	if n > 0:
		cfg.set_value(section(e), "shards", shards(cfg, e) + n)
		# Past the road's end, a bonus Moon Casket for every BONUS_EVERY shards more.
		var due := bonus_earned(cfg, e) - int(cfg.get_value(section(e), "bonus_given", 0))
		if due > 0:
			add_caskets(cfg, due, e)
			cfg.set_value(section(e), "bonus_given", bonus_earned(cfg, e))


## Version 135: the road ends at 2,400 shards, which a keen player reaches in the first
## week. After it, every 150 shards more is a bonus Moon Casket (given as they come), so
## the second week still pays.
const BONUS_EVERY := 150


static func road_end() -> int:
	return int(ROAD[ROAD.size() - 1].at)


## Bonus caskets earned past the road's end.
static func bonus_earned(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	return maxi(0, shards(cfg, e) - road_end()) / BONUS_EVERY


## Shards to the next bonus casket (0 before the road's end).
static func to_next_bonus(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	var over := shards(cfg, e) - road_end()
	if over < 0:
		return 0
	return BONUS_EVERY - over % BONUS_EVERY


static func caskets(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	return int(cfg.get_value(section(e), "caskets", 0))


static func add_caskets(cfg: ConfigFile, n: int, e: Dictionary = BLOOD_MOON) -> void:
	cfg.set_value(section(e), "caskets", clampi(caskets(cfg, e) + n, 0, MAX_CASKETS))


# ---------------------------------------------------------------- the road

static func claimed(cfg: ConfigFile, i: int, e: Dictionary = BLOOD_MOON) -> bool:
	return bool(cfg.get_value(section(e), "got_%d" % i, false))


static func ready_count(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	var s := shards(cfg, e)
	var n := 0
	for i in ROAD.size():
		if s >= int(ROAD[i].at) and not claimed(cfg, i, e):
			n += 1
	return n


## The first step not reached yet (ROAD.size() when the road is done).
static func next_index(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	var s := shards(cfg, e)
	for i in ROAD.size():
		if s < int(ROAD[i].at):
			return i
	return ROAD.size()


static func progress(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> float:
	var i := next_index(cfg, e)
	if i >= ROAD.size():
		return 1.0
	var from := 0 if i == 0 else int(ROAD[i - 1].at)
	return clampf(float(shards(cfg, e) - from) / float(int(ROAD[i].at) - from), 0.0, 1.0)


static func step_text(s: Dictionary) -> String:
	match str(s.kind):
		"casket":
			return "Moon Casket" if int(s.n) == 1 else "%d Moon Caskets" % int(s.n)
		"drop":
			return "Bone Drop" if int(s.n) == 1 else "%d Bone Drops" % int(s.n)
		"lucky":
			return "Lucky Start" if int(s.n) == 1 else "%d Lucky Starts" % int(s.n)
		"look":
			return HeroStyle.item_label("rogue", s.look[0], s.look[1])
	return "%d coins" % int(s.n)


## Claims road step `i` into `cfg` (the caller adds coins, which it holds). Returns the
## step, or {} if it can't be claimed.
static func claim(cfg: ConfigFile, i: int, e: Dictionary = BLOOD_MOON) -> Dictionary:
	if i < 0 or i >= ROAD.size() or claimed(cfg, i, e) or shards(cfg, e) < int(ROAD[i].at):
		return {}
	var s: Dictionary = ROAD[i]
	cfg.set_value(section(e), "got_%d" % i, true)
	match str(s.kind):
		"casket":
			add_caskets(cfg, int(s.n), e)
		"drop":
			Drops.add(cfg, int(s.n))
		"lucky":
			cfg.set_value(Drops.SECTION, "lucky", Drops.lucky(cfg) + int(s.n))
		"look":
			give_look(cfg, s.look[0], s.look[1])
	return s


## Version 135: an event that has ended pays out, once, what was left on it: every road
## prize reached but not claimed, and the Moon Caskets not opened (100 coins each, as the
## casket screen is gone with the event). Writes into `cfg` (the caller adds the coins, which
## it holds, and saves). Returns {name, coins, prizes, caskets}, or {} if nothing was left.
static func settle(cfg: ConfigFile) -> Dictionary:
	for e: Dictionary in LIST:
		if day(e) <= int(e.days) or not cfg.has_section(section(e)) or bool(cfg.get_value(section(e), "settled", false)):
			continue
		cfg.set_value(section(e), "settled", true)
		var coins := 0
		var prizes := 0
		for i in ROAD.size():
			var st := claim(cfg, i, e)
			if not st.is_empty():
				prizes += 1
				if st.kind == "coins":
					coins += int(st.n)
		var n := caskets(cfg, e)
		cfg.set_value(section(e), "caskets", 0)
		coins += n * 100
		if prizes + n > 0:
			return {"name": e.name, "coins": coins, "prizes": prizes, "caskets": n}
	return {}


# ---------------------------------------------------------------- event looks

const LOOK_SECTION := "event_looks"


static func has_look(cfg: ConfigFile, slot: String, key: String) -> bool:
	return bool(cfg.get_value(LOOK_SECTION, slot + "/" + key, false))


static func give_look(cfg: ConfigFile, slot: String, key: String) -> void:
	cfg.set_value(LOOK_SECTION, slot + "/" + key, true)


## The event set's looks not found yet, in road order: [[slot, key]].
static func missing_looks(cfg: ConfigFile) -> Array:
	var out := []
	for s: Dictionary in ROAD:
		if s.kind == "look" and not has_look(cfg, s.look[0], s.look[1]):
			out.append(s.look)
	return out


# ---------------------------------------------------------------- Moon Caskets

## Opens one waiting casket: rolls it and writes the prize into `cfg` (the caller adds the
## coins). Returns what drop_screen.gd shows: {tier, name, color, coins, kind, text, ...}.
static func open_casket(cfg: ConfigFile, rng: RandomNumberGenerator = null, e: Dictionary = BLOOD_MOON) -> Dictionary:
	if caskets(cfg, e) <= 0:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var roll := rng.randi_range(1, 100)
	var i := 0
	for k in CASKETS.size():
		roll -= int(CASKETS[k].weight)
		i = k
		if roll <= 0:
			break
	var t: Dictionary = CASKETS[i]
	var out := {"tier": [1, 2, 3, 4, 4][i], "name": t.name, "color": t.color, "coins": 0, "kind": "coins", "text": "", "casket": true}
	cfg.set_value(section(e), "caskets", caskets(cfg, e) - 1)
	cfg.set_value(section(e), "opened", int(cfg.get_value(section(e), "opened", 0)) + 1)
	match str(t.id):
		"rare":
			out.coins = 60
			add_shards(cfg, 15, e)
			out.text = "+60 COINS\n+15 MOON SHARDS"
		"super":
			if rng.randi_range(0, 1) == 0:
				Drops.add(cfg, 1)
				out.coins = 60
				out.text = "BONE DROP\n+60 COINS"
			else:
				out.coins = 150
				add_shards(cfg, 25, e)
				out.text = "+150 COINS\n+25 MOON SHARDS"
		"epic":
			Drops.add(cfg, 1)
			out.coins = 220
			add_shards(cfg, 40, e)
			out.text = "BONE DROP\n+220 COINS\n+40 MOON SHARDS"
		"mythic":
			Drops.add(cfg, 2)
			cfg.set_value(Drops.SECTION, "lucky", Drops.lucky(cfg) + 1)
			out.coins = 350
			out.text = "2 BONE DROPS\nLUCKY START\n+350 COINS"
		"legendary":
			# The next piece of the event set, early; once all are found, a fortune.
			var miss := missing_looks(cfg)
			if miss.is_empty():
				out.coins = 800
				add_shards(cfg, 100, e)
				out.text = "+800 COINS\n+100 MOON SHARDS"
			else:
				var look: Array = miss[0]
				give_look(cfg, look[0], look[1])
				var id := str(cfg.get_value("heroes", "selected", "rogue"))
				var picks := HeroStyle.picks(cfg, id)
				for slot: String in HeroStyle.PASS_SLOTS:
					if picks.get(slot, "") == HeroStyle.pass_key(slot):
						picks[slot] = ""
				picks[look[0]] = look[1]
				out.kind = "look"
				out.look = look
				out.preview = HeroStyle.dressed(Heroes.get_hero(id), picks)
				out.hero = id
				out.text = "NEW LOOK: %s\nThe Blood Moon set, early!\nEvery hero can wear it." % HeroStyle.item_label(id, look[0], look[1])
	return out


## What a casket can hold, for the "?" on the casket screen: [[name, chance, prize]].
static func casket_odds() -> Array:
	var prizes := ["60 coins and 15 shards", "A Bone Drop, or 150 coins", "A Bone Drop and 220 coins",
		"2 Bone Drops, a Lucky Start and 350 coins", "A Blood Moon look, early"]
	var out := []
	for i in CASKETS.size():
		out.append([CASKETS[i].name, int(CASKETS[i].weight), prizes[i]])
	return out


# ---------------------------------------------------------------- the Queen Hunt

## Tiers open now: by chapter, and each needs the one before beaten once.
static func tiers_open(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	var n := int(chapter_info(e).tiers)
	var beaten := best_tier(cfg, e)
	return mini(n, beaten + 1)


## The highest tier ever beaten (0 = none).
static func best_tier(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	return int(cfg.get_value(section(e), "best_tier", 0))


## Whether tier `t` (1-5) was beaten today: the day's first win pays a casket too.
static func won_today(cfg: ConfigFile, t: int, e: Dictionary = BLOOD_MOON) -> bool:
	return str(cfg.get_value(section(e), "won_%d" % t, "")) == Curses.today()


## A hunt won on tier `t`: saves it and returns {shards, casket} (shards before boosts).
static func record_hunt(cfg: ConfigFile, t: int, e: Dictionary = BLOOD_MOON) -> Dictionary:
	var first := not won_today(cfg, t, e)
	cfg.set_value(section(e), "won_%d" % t, Curses.today())
	cfg.set_value(section(e), "best_tier", maxi(best_tier(cfg, e), t))
	cfg.set_value(section(e), "hunts", int(cfg.get_value(section(e), "hunts", 0)) + 1)
	var n := int(TIERS[t - 1].shards)
	if first:
		n = roundi(n * 1.5)
		add_caskets(cfg, 1, e)
	return {"shards": n, "casket": first}


## Event runs played and the Queen's defeats, for the event screen.
static func queen_kills(cfg: ConfigFile, e: Dictionary = BLOOD_MOON) -> int:
	return int(cfg.get_value(section(e), "queen_kills", 0))
