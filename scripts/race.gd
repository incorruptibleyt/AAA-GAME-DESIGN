class_name Race
## The Crypt Race (version 153, part A of the live race plan): race a rival through the same
## crypt at the same time. Four rooms and the floor's boss; both racers get the same rooms,
## the same blessing cards and doors, and the same two-blessing Race Kit, and the Armory is
## left at home, so the quicker run wins, not the bigger Armory. Whoever fells the boss first
## wins. A racer who falls is knocked down for a few seconds and gets up again (a race is
## never over until someone crosses the line). Kills fill the SURGE meter (double at Chain
## x2 or more); a full meter stuns the rival for a moment, and the rival's surges throw
## skeletons into your room.
##
## Part A has no server: every rival is a bot (marked BOT on every screen, as the PvP review
## asked), run by the plan in Rival below, with its skill picked by the player's trophies.
## Part B swaps the bot for a real player online, keeping a bot only when nobody is found.
##
## Rewards, all the race's own: trophies (+20 a win, more on a streak, -10 a loss, none lost
## under 100 or below the start of the league reached), five leagues, coins every race, a
## Bone Drop for the first win each day, and the Race Road: 16 steps by best trophies, with
## six looks found nowhere else (hero_style.gd EXTRA "race").

const SECTION := "race"
## Floor-1 wins before the race opens (the floor-1 help ends at the same point).
const UNLOCK_CLEARS := 2
## The race crypt: one easy, two medium and one hard room, then the boss (legs 0-4).
const ROOMS := [1, 2, 1]
const LEGS := 5

const WIN := 20
const STREAK_STEP := 2   # +2 more for each win in a row after the first...
const STREAK_MAX := 10   # ...up to +10
const LOSS := 10
const SAFE_UNDER := 100  # losses cost no trophies under this
const WIN_COINS := 40
const LOSS_COINS := 15

## A racer who falls is down this long (the rival keeps going), then up with GET_UP health.
const DOWN_TIME := 4.0
const GET_UP := 0.5
## Kill points to fill the SURGE meter (an elite is worth 3; at Chain x2 or more, double).
const SURGE_POINTS := 16.0
## A surge stuns the rival this long; a rival's surge throws SURGE_FOES skeletons in.
const SURGE_STUN := 2.0
## A surge fired while the rival fights its boss (version 155): stunned this much longer.
const BIG_SURGE := 1.5
const SURGE_FOES := 2

const LEAGUES := [
	{"name": "BRONZE", "at": 0, "col": Color(0.88, 0.58, 0.34)},
	{"name": "SILVER", "at": 200, "col": Color(0.8, 0.86, 0.95)},
	{"name": "GOLD", "at": 500, "col": Color(1.0, 0.8, 0.3)},
	{"name": "CRYSTAL", "at": 900, "col": Color(0.45, 0.92, 1.0)},
	{"name": "BONE KING", "at": 1400, "col": Color(0.86, 0.52, 1.0)},
]

## The Race Road, by best trophies (never lost). kind: coins, drop, lucky (n), or look.
const ROAD := [
	{"at": 25, "kind": "coins", "n": 100},
	{"at": 50, "kind": "drop", "n": 1},
	{"at": 100, "kind": "look", "slot": "glow", "key": "photon"},
	{"at": 150, "kind": "coins", "n": 200},
	{"at": 200, "kind": "drop", "n": 2},
	{"at": 275, "kind": "look", "slot": "outfit", "key": "pacesetter"},
	{"at": 350, "kind": "coins", "n": 300},
	{"at": 425, "kind": "lucky", "n": 2},
	{"at": 500, "kind": "look", "slot": "aura", "key": "comet"},
	{"at": 600, "kind": "coins", "n": 400},
	{"at": 700, "kind": "drop", "n": 3},
	{"at": 800, "kind": "look", "slot": "glow", "key": "afterburn"},
	{"at": 900, "kind": "look", "slot": "outfit", "key": "crystal_sprint"},
	{"at": 1050, "kind": "coins", "n": 600},
	{"at": 1200, "kind": "drop", "n": 4},
	{"at": 1400, "kind": "look", "slot": "aura", "key": "bone_comet"},
]

## Rival skills. room: seconds a medium room takes them (blessing pick included), boss:
## the boss fight, falls: [chance of a first fall, of a second]; surge: seconds between
## the surges they send. Tuned by robot races (version 153 notes).
const SKILLS := {
	"easy": {"name": "ROOKIE", "room": 27.0, "boss": 34.0, "falls": [0.35, 0.1], "surge": 30.0},
	"medium": {"name": "RACER", "room": 22.0, "boss": 27.0, "falls": [0.2, 0.05], "surge": 22.0},
	"hard": {"name": "CHAMPION", "room": 17.5, "boss": 21.0, "falls": [0.1, 0.0], "surge": 16.0},
}
const ORDER := ["easy", "medium", "hard"]
## Rivals are matched to your own speed once you have raced a few times (version 154): a
## rival's whole race takes your usual race time times this (Rookie slower, Champion
## quicker). The rival also loses time to your surges, so RACER at 0.97 gives you a little
## better than even odds, and the climb comes from meeting more CHAMPIONs higher up.
const MATCH := {"easy": 1.15, "medium": 0.97, "hard": 0.88}
## Version 156 (deeper review fix 2): matching every rival to your own speed meant getting
## better never moved you up, and players stalled at Gold. Now rivals match your speed only
## while you learn (under LADDER_FROM trophies); from there each trophy count has its own
## fixed race time (LADDER: [trophies, seconds for an even rival]), so a quicker player
## climbs until the rivals are as quick as they are. LADDER_BLEND trophies ease from one to
## the other.
const LADDER := [[200, 130.0], [500, 105.0], [900, 85.0], [1400, 70.0], [2500, 55.0]]
const LADDER_FROM := 200
const LADDER_BLEND := 100
## After this many losses in a row on the ladder, the next rival runs slower than your
## usual time (a way back for a player who climbed past their speed).
const COMEBACK_LOSSES := 3
## Races remembered for your usual time, and how many before rivals are matched to it.
const PACE_KEEP := 5
const PACE_MIN := 2
## How long each leg takes against a medium room: easy room, medium, medium, hard (the boss
## has its own time).
const LEG_MULT := [0.8, 1.0, 1.0, 1.2]

const NAMES := ["Grimsby", "Marrowmancer", "Rattlebones", "Lady Ulna", "Count Clavicle", "Femurphy",
	"Wraithwick", "Old Knucklebone", "Tibia Tess", "Cryptkeeper Kip", "Sir Sternum", "Mossgrave",
	"Bonnie Bones", "Hollow Hal", "Skully Sue", "Vertebrax", "Duke Dustwhistle", "Patella Pip",
	"Gravemoss Gus", "Ribcage Rory", "Candlewick", "Morrow", "Ossia", "Brother Ash"]


# ---------------------------------------------------------------- save

static func unlocked(cfg: ConfigFile) -> bool:
	return Game.f1_clears(cfg) >= UNLOCK_CLEARS


static func trophies(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "trophies", 0))


static func best(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "best", 0))


static func stat(cfg: ConfigFile, key: String) -> int:
	return int(cfg.get_value(SECTION, key, 0))


static func league_index(t: int) -> int:
	var i := 0
	for j in LEAGUES.size():
		if t >= int(LEAGUES[j].at):
			i = j
	return i


static func league(t: int) -> Dictionary:
	return LEAGUES[league_index(t)]


## 0..1 through the current league (1 in the last).
static func league_progress(t: int) -> float:
	var i := league_index(t)
	if i >= LEAGUES.size() - 1:
		return 1.0
	var from := int(LEAGUES[i].at)
	return clampf(float(t - from) / float(int(LEAGUES[i + 1].at) - from), 0.0, 1.0)


## "Silver at 200" (or "Top league!").
static func next_league_text(t: int) -> String:
	var i := league_index(t)
	if i >= LEAGUES.size() - 1:
		return "Top league!"
	return "%s at %d" % [str(LEAGUES[i + 1].name).capitalize(), int(LEAGUES[i + 1].at)]


## The trophies a win would give now (streak included).
static func win_trophies(cfg: ConfigFile) -> int:
	return WIN + mini(STREAK_MAX, STREAK_STEP * stat(cfg, "streak"))


static func first_win_ready(cfg: ConfigFile) -> bool:
	return str(cfg.get_value(SECTION, "won_day", "")) != Curses.today()


## A race is marked as running from the countdown to the result, so one left by closing the
## game counts as a loss when it opens again (settle_left).
static func mark_running(cfg: ConfigFile, on: bool) -> void:
	cfg.set_value(SECTION, "running", on)


## Called as the game opens: a race left by closing the game is a loss. Returns its result
## ({} when there was none).
static func settle_left(cfg: ConfigFile) -> Dictionary:
	if not bool(cfg.get_value(SECTION, "running", false)):
		return {}
	return record(cfg, false)


## Writes a race's result into the save: trophies, streaks, coins, the day's first-win drop.
## The caller adds `coins` to the coins it holds. Returns what changed, for the results screen.
static func record(cfg: ConfigFile, won: bool, pace := 0.0) -> Dictionary:
	mark_running(cfg, false)
	if pace > 0.0:
		var paces: Array = cfg.get_value(SECTION, "paces", [])
		paces.append(snappedf(pace, 0.1))
		while paces.size() > PACE_KEEP:
			paces.pop_front()
		cfg.set_value(SECTION, "paces", paces)
	var before := trophies(cfg)
	var t := before
	var out := {"won": won, "before": before, "drop": false, "league_up": false, "league_down": false}
	cfg.set_value(SECTION, "races", stat(cfg, "races") + 1)
	if won:
		var gain := win_trophies(cfg)
		t += gain
		out.delta = gain
		out.streak_bonus = gain - WIN
		cfg.set_value(SECTION, "wins", stat(cfg, "wins") + 1)
		cfg.set_value(SECTION, "streak", stat(cfg, "streak") + 1)
		cfg.set_value(SECTION, "losses_row", 0)
		out.coins = WIN_COINS
		# Your best winning time, for the results and the lobby.
		var bt := float(cfg.get_value(SECTION, "best_t", 0.0))
		out.best_t = bt
		if pace > 0.0 and (bt <= 0.0 or pace < bt):
			cfg.set_value(SECTION, "best_t", snappedf(pace, 0.1))
			out.best_t = pace
			out.time_best = bt > 0.0   # a new best (the first win is just a time)
		if first_win_ready(cfg):
			cfg.set_value(SECTION, "won_day", Curses.today())
			Drops.add(cfg, 1)
			out.drop = true
	else:
		# Never below the start of the league you're in, and nothing lost while learning.
		var floor_t := int(league(before).at)
		t = before if before < SAFE_UNDER else maxi(floor_t, before - LOSS)
		out.delta = t - before
		cfg.set_value(SECTION, "streak", 0)
		cfg.set_value(SECTION, "losses_row", stat(cfg, "losses_row") + 1)
		out.coins = LOSS_COINS
	cfg.set_value(SECTION, "trophies", t)
	out.after = t
	out.league_up = league_index(t) > league_index(before)
	var old_best := best(cfg)
	if t > old_best:
		cfg.set_value(SECTION, "best", t)
	out.new_best = t > old_best
	out.road_new = road_ready(cfg) > 0 and _road_reached(old_best) < _road_reached(maxi(t, old_best))
	return out


## Your usual race time: the middle of your last few (0 until PACE_MIN races are known).
static func usual_pace(cfg: ConfigFile) -> float:
	var paces: Array = cfg.get_value(SECTION, "paces", [])
	if paces.size() < PACE_MIN:
		return 0.0
	var p := paces.duplicate()
	p.sort()
	return float(p[p.size() / 2])


## A rival's plan times x this (0 = the tables as they are). Under LADDER_FROM trophies the
## rival is matched to your usual speed (once a few races are known); from there its time
## comes from the trophy ladder, blended over LADDER_BLEND trophies.
static func match_scale(cfg: ConfigFile, skill: String) -> float:
	var t := trophies(cfg)
	var usual := usual_pace(cfg)
	var mine := 0.0
	if usual > 0.0:
		mine = clampf(usual * float(MATCH[skill]), table_time("hard") * 0.8, table_time("easy") * 1.35)
	var want := mine
	if t >= LADDER_FROM:
		var lad := ladder_time(t) * float(MATCH[skill])
		var k := clampf(float(t - LADDER_FROM) / float(LADDER_BLEND), 0.0, 1.0)
		want = lerpf(mine, lad, k) if mine > 0.0 else lad
		# A way back after a run of losses: this rival is slower than you usually are.
		if usual > 0.0 and stat(cfg, "losses_row") >= COMEBACK_LOSSES:
			want = maxf(want, usual * float(MATCH.easy))
	if want <= 0.0:
		return 0.0
	return want / table_time(skill)


## An even rival's whole race time at `t` trophies on the ladder.
static func ladder_time(t: int) -> float:
	if t <= int(LADDER[0][0]):
		return float(LADDER[0][1])
	for i in LADDER.size() - 1:
		var a: Array = LADDER[i]
		var b: Array = LADDER[i + 1]
		if t <= int(b[0]):
			return lerpf(float(a[1]), float(b[1]), float(t - int(a[0])) / float(int(b[0]) - int(a[0])))
	return float(LADDER[-1][1])


## A whole race's plan time for a skill from the tables alone.
static func table_time(skill: String) -> float:
	var s: Dictionary = SKILLS[skill]
	var t := float(s.boss)
	for i in LEGS - 1:
		t += float(s.room) * float(LEG_MULT[i])
	return t


## How long a full race would take at this pace: `t` seconds to reach place `p` on the track,
## scaled by how much of a medium race that part is. 0 when too little of the race was run.
static func pace_of(t: float, p: float) -> float:
	if p < 1.5 or t <= 0.0:
		return 0.0
	var ref := Rival.new()
	ref.skill = "medium"
	var s: Dictionary = SKILLS.medium
	var acc := 0.0
	for i in LEGS:
		acc += float(s.boss) if i == LEGS - 1 else float(s.room) * float(LEG_MULT[i])
		ref.ends.append(acc)
	return t * acc / maxf(ref.time_at(p), 1.0)


# ---------------------------------------------------------------- the Race Road

static func road_claimed(cfg: ConfigFile, i: int) -> bool:
	return bool(cfg.get_value(SECTION, "got_%d" % i, false))


static func _road_reached(b: int) -> int:
	var n := 0
	for s: Dictionary in ROAD:
		if b >= int(s.at):
			n += 1
	return n


static func road_ready(cfg: ConfigFile) -> int:
	var b := best(cfg)
	var n := 0
	for i in ROAD.size():
		if b >= int(ROAD[i].at) and not road_claimed(cfg, i):
			n += 1
	return n


## The first step not reached yet (ROAD.size() when all are).
static func road_next(cfg: ConfigFile) -> int:
	var b := best(cfg)
	for i in ROAD.size():
		if b < int(ROAD[i].at):
			return i
	return ROAD.size()


static func road_text(s: Dictionary) -> String:
	match str(s.kind):
		"drop":
			return "Bone Drop" if int(s.n) == 1 else "%d Bone Drops" % int(s.n)
		"lucky":
			return "Lucky Start" if int(s.n) == 1 else "%d Lucky Starts" % int(s.n)
		"look":
			return "%s %s" % [str(HeroStyle.extra(s.slot, s.key).name), {"glow": "glow", "outfit": "outfit", "aura": "aura"}.get(str(s.slot), "")]
	return "%d coins" % int(s.n)


## Claims step `i` (the caller adds coins). Returns the step, or {} if it can't be claimed.
static func claim(cfg: ConfigFile, i: int) -> Dictionary:
	if i < 0 or i >= ROAD.size() or road_claimed(cfg, i) or best(cfg) < int(ROAD[i].at):
		return {}
	var s: Dictionary = ROAD[i]
	cfg.set_value(SECTION, "got_%d" % i, true)
	match str(s.kind):
		"drop":
			Drops.add(cfg, int(s.n))
		"lucky":
			cfg.set_value(Drops.SECTION, "lucky", Drops.lucky(cfg) + int(s.n))
	return s


## A race look is worn once its Race Road step is claimed.
static func has_look(cfg: ConfigFile, slot: String, key: String) -> bool:
	for i in ROAD.size():
		var s: Dictionary = ROAD[i]
		if s.kind == "look" and s.slot == slot and s.key == key:
			return road_claimed(cfg, i)
	return false


static func look_at(slot: String, key: String) -> int:
	for s: Dictionary in ROAD:
		if s.kind == "look" and s.slot == slot and s.key == key:
			return int(s.at)
	return 0


# ---------------------------------------------------------------- a race

## Which rival skill to meet, by trophies; two losses in a row bring an easier one.
static func pick_skill(cfg: ConfigFile, rng: RandomNumberGenerator) -> String:
	var t := trophies(cfg)
	var w: Array = [1.0, 0.0, 0.0]
	if t >= LADDER_FROM:
		w = [0.2, 0.6, 0.2]   # (the ladder makes rivals quicker as trophies rise)
	elif t >= 60:
		w = [0.6, 0.4, 0.0]
	var r := rng.randf()
	var i := 0
	var sum := 0.0
	for j in 3:
		sum += float(w[j])
		if r < sum:
			i = j
			break
	if stat(cfg, "losses_row") >= 2:
		i = maxi(0, i - 1)
	return ORDER[i]


## Sets up a race: its seed, the rival, and the Race Kit.
static func new_match(cfg: ConfigFile) -> Match:
	var m := Match.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	m.seed = rng.randi()
	m.date = "race-%d" % m.seed
	var r := Rival.new()
	r.skill = pick_skill(cfg, rng)
	var mine := Heroes.selected(cfg)
	# Not the rival you just raced (RACE AGAIN brings someone new).
	var last := str(cfg.get_value(SECTION, "last_rival", ""))
	var names := NAMES.filter(func(n: String) -> bool: return n != last)
	r.name = str(names[rng.randi() % names.size()])
	cfg.set_value(SECTION, "last_rival", r.name)
	# A different hero from yours, so the two racers are easy to tell apart.
	var others: Array = []
	for h in Heroes.LIST:
		if str(h.id) != mine:
			others.append(str(h.id))
	if others.is_empty():
		others.append(mine)
	r.hero_id = str(others[rng.randi() % others.size()])
	r.trophies = maxi(0, trophies(cfg) + rng.randi_range(-30, 30))
	r.scale = match_scale(cfg, r.skill)
	r.matched = r.scale > 0.0
	if not r.matched:
		r.scale = 1.0
	r.plan(rng)
	m.rival = r
	m.kit = kit(m.date)
	m.trophies = trophies(cfg)
	m.hero_id = mine
	return m


## The Race Kit: two blessings both racers start with, picked by the race's seed from the
## plain ones (no hero's own, no Vault or event ones, nothing that needs another first).
static func kit(date: String) -> Array:
	var rng := Curses.daily_rng(77, date)
	var pool: Array = Upgrades.LIST.filter(func(u: Dictionary) -> bool:
		return u.rarity != "epic" and not u.has("hero") and not u.has("vault") and not u.has("event") and not u.has("needs"))
	var out := []
	while out.size() < 2 and not pool.is_empty():
		var u: Dictionary = pool[rng.randi() % pool.size()]
		out.append(str(u.id))
		pool.erase(u)
	return out


static func kit_text(ids: Array) -> String:
	return " + ".join(ids.map(func(id): return str(Upgrades.get_def(id).title)))


## One race as it runs: the clock, both racers' progress, surges and the result.
class Match extends RefCounted:
	var seed := 0
	var date := ""
	var rival: Rival
	var kit: Array = []
	var trophies := 0
	var hero_id := ""
	var t := 0.0              # seconds since GO
	var legs := 0             # legs the player has finished (5 = crossed the line)
	var leg_frac := 0.0       # how far through the current leg, 0..1
	var surge := 0.0          # kill points toward the next surge sent
	var sent := 0
	var got := 0
	var queued := 0           # rival surges waiting for the next fight
	var falls := 0
	var over := false
	var won := false
	var finish_t := 0.0       # when the winner crossed the line
	var result := {}

	## The player's place on the track, 0..5.
	func me() -> float:
		return minf(float(LEGS), legs + clampf(leg_frac, 0.0, 0.97))

	func them() -> float:
		return rival.progress()

	## Seconds the player is ahead (+) or behind (-) of the rival, by the rival's plan: how
	## long the rival needs to get where the player is now.
	func gap() -> float:
		return rival.time_at(me()) - rival.clock


## A bot rival: its run is planned at the start (when each leg ends, and where it falls),
## then played out on its own clock, which a surge from the player stops for a moment.
class Rival extends RefCounted:
	var name := ""
	var hero_id := "rogue"
	var skill := "medium"
	var trophies := 0
	var ends: Array[float] = []   # when each leg ends on the rival's clock
	var downs: Array[float] = []  # when it falls (knocked down for DOWN_TIME)
	var clock := 0.0              # the rival's own time (stopped while stunned or down)
	var stun := 0.0
	var down := 0.0
	var surge_in := 0.0           # seconds to its next surge
	var falls := 0
	var scale := 1.0              # the plan's times x this (matched to the player's speed)
	var matched := false
	var _at_boss := false
	var _rng := RandomNumberGenerator.new()

	func plan(rng: RandomNumberGenerator) -> void:
		_rng.seed = rng.randi()
		var s: Dictionary = SKILLS[skill]
		var pace := _rng.randf_range(0.95, 1.05) * scale
		var t := 0.0
		for i in LEGS:
			var base: float = s.boss if i == LEGS - 1 else float(s.room) * float(LEG_MULT[i])
			t += base * pace * _rng.randf_range(0.88, 1.12)
			ends.append(t)
		var chances: Array = s.falls
		for c: float in chances:
			if _rng.randf() < c:
				downs.append(_rng.randf_range(t * 0.15, t * 0.95))
		downs.sort()
		surge_in = float(s.surge) * scale * _rng.randf_range(0.8, 1.2)

	## Advances the rival `dt` seconds. Returns what happened: "down", "up", "surge", "boss" (into
	## the boss room), "finish" or "".
	func tick(dt: float) -> String:
		if done():
			return ""
		if down > 0.0:
			down -= dt
			return "up" if down <= 0.0 else ""
		if stun > 0.0:
			stun -= dt
			return ""
		clock += dt
		if not downs.is_empty() and clock >= downs[0]:
			downs.pop_front()
			down = DOWN_TIME + 1.0   # (getting up takes a moment too)
			falls += 1
			return "down"
		if done():
			return "finish"
		if not _at_boss and clock >= ends[LEGS - 2]:
			_at_boss = true
			return "boss"
		surge_in -= dt
		if surge_in <= 0.0:
			surge_in = float(SKILLS[skill].surge) * scale * _rng.randf_range(0.75, 1.25)
			return "surge"
		return ""

	func done() -> bool:
		return clock >= ends[LEGS - 1]

	func progress() -> float:
		for i in LEGS:
			if clock < ends[i]:
				var from := 0.0 if i == 0 else ends[i - 1]
				return i + (clock - from) / (ends[i] - from)
		return float(LEGS)

	## When (on its own clock) the rival reaches place `p` on the track.
	func time_at(p: float) -> float:
		var i := clampi(int(p), 0, LEGS - 1)
		var from := 0.0 if i == 0 else ends[i - 1]
		return from + (ends[i] - from) * clampf(p - i, 0.0, 1.0) if p < LEGS else ends[LEGS - 1]

	func room() -> int:
		return mini(LEGS - 1, int(progress()))


## Ticks the race's clock on real time, also while the blessing cards pause the game (a
## race doesn't stop for anyone). At most 0.1 s a frame, so a phone that put the game away
## doesn't come back to a finished rival.
class Clock extends Node:
	var on_tick: Callable

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		var dt := minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
		if on_tick.is_valid():
			on_tick.call(dt)
