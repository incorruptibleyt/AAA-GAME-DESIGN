class_name HeroMastery
## Hero Mastery: every hero grows from level 1 to MAX_LEVEL the more you play them. Each
## room cleared with a hero gives them ROOM_POINTS, each boss beaten BOSS_POINTS, in any
## mode (the tutorial and the Daily Crypt too), and points are never lost.
##
## Each new level gives its rewards the moment it's reached: coins, Bone Drops, Lucky
## Starts, a title and a gold frame (level 10), and three new looks for the hero to wear
## (hero_style.gd: outfits, headwear, weapons and glows, picked on the Style screen).
## Nothing is bought; the 4 heroes just get a long life of their own.
##
## A run that clears floor 1 is worth 20 points (level 2 straight after the tutorial); five
## floors are about 100. Level 10 (Master) takes 700: roughly 25 runs with one hero.
##
## (Not the Crypt Pass's Curse rewards, curses.gd MASTERY, which are a separate thing.)

const SECTION := "hero_mastery"
const ROOM_POINTS := 2
const BOSS_POINTS := 10
const MAX_LEVEL := 10
## Points needed to reach each level (LEVELS[level - 1]). Quick at first (the tutorial win
## is level 2, a few short runs level 3 and 4), then a longer road to Master. (Lowered from
## 1000 for Master before release: points already earned never lose a level.)
const LEVELS := [0, 20, 45, 80, 125, 180, 250, 350, 500, 700]

## Rewards given when each level is reached (besides its looks, HeroStyle.level_items).
## kind: "coins" (n), "drop" (n Bone Drops), "lucky" (n Lucky Starts), "title" (text),
## "frame" (a Master's gold frame).
const REWARDS := {
	2: [{"kind": "coins", "n": 25}],
	3: [{"kind": "drop", "n": 1}],
	4: [{"kind": "title", "text": "Adept"}, {"kind": "coins", "n": 50}],
	5: [{"kind": "coins", "n": 75}],
	6: [{"kind": "drop", "n": 2}],
	7: [{"kind": "title", "text": "Veteran"}, {"kind": "coins", "n": 100}],
	8: [{"kind": "lucky", "n": 2}],
	9: [{"kind": "drop", "n": 3}],
	10: [{"kind": "title", "text": "Master"}, {"kind": "frame"}, {"kind": "coins", "n": 250}],
}
const FRAME_LEVEL := 10

## The rank colors: Bronze (levels 1-3), Silver (4-6), Gold (7-9), Master (10).
const RANKS := [
	{"from": 1, "name": "Bronze", "color": Color(0.85, 0.55, 0.32)},
	{"from": 4, "name": "Silver", "color": Color(0.8, 0.85, 0.95)},
	{"from": 7, "name": "Gold", "color": Color(1.0, 0.8, 0.3)},
	{"from": 10, "name": "Master", "color": Color(1.0, 0.9, 0.5)},
]


static func points(cfg: ConfigFile, id: String) -> int:
	return int(cfg.get_value(SECTION, id, 0))


static func add(cfg: ConfigFile, id: String, n: int) -> void:
	if n > 0 and id != "":
		cfg.set_value(SECTION, id, points(cfg, id) + n)


static func level_for(p: int) -> int:
	var lv := 1
	for i in LEVELS.size():
		if p >= int(LEVELS[i]):
			lv = i + 1
	return lv


static func level(cfg: ConfigFile, id: String) -> int:
	return level_for(points(cfg, id))


## How far into a level `p` points are: {level, into, need, frac}; at MAX_LEVEL need is 0
## and frac 1.
static func progress(p: int) -> Dictionary:
	var lv := level_for(p)
	if lv >= MAX_LEVEL:
		return {"level": lv, "into": p - int(LEVELS[MAX_LEVEL - 1]), "need": 0, "frac": 1.0}
	var from := int(LEVELS[lv - 1])
	var to := int(LEVELS[lv])
	return {"level": lv, "into": p - from, "need": to - from, "frac": clampf(float(p - from) / float(to - from), 0.0, 1.0)}


static func rank(lv: int) -> Dictionary:
	var r: Dictionary = RANKS[0]
	for k: Dictionary in RANKS:
		if lv >= int(k.from):
			r = k
	return r


## The best title the hero has earned ("" before level 4).
static func title(cfg: ConfigFile, id: String) -> String:
	return title_for(level(cfg, id))


static func title_for(lv: int) -> String:
	var t := ""
	for l in range(1, lv + 1):
		for r: Dictionary in REWARDS.get(l, []):
			if r.kind == "title":
				t = r.text
	return t


# ---------------------------------------------------------------- frame

static func has_frame(cfg: ConfigFile, id: String) -> bool:
	return level(cfg, id) >= FRAME_LEVEL


# ---------------------------------------------------------------- rewards

## Gives every reward of the levels reached since the last call, into `cfg` (Bone Drops and
## Lucky Starts; the caller adds the coins, which it holds, and saves). Returns
## {coins, levels: [{level, rewards}]}; levels is empty if nothing new.
static func grant(cfg: ConfigFile, id: String) -> Dictionary:
	var out := {"coins": 0, "levels": []}
	if id == "":
		return out
	var given := int(cfg.get_value(SECTION, id + "_given", 1))
	var lv := level(cfg, id)
	if lv <= given:
		return out
	for l in range(given + 1, lv + 1):
		var rewards: Array = REWARDS.get(l, [])
		for r: Dictionary in rewards:
			match str(r.kind):
				"coins":
					out.coins += int(r.n)
				"drop":
					cfg.set_value(Drops.SECTION, "waiting", Drops.waiting(cfg) + int(r.n))
				"lucky":
					cfg.set_value(Drops.SECTION, "lucky", Drops.lucky(cfg) + int(r.n))
		out.levels.append({"level": l, "rewards": rewards})
	cfg.set_value(SECTION, id + "_given", lv)
	return out


static func reward_text(r: Dictionary, id: String) -> String:
	match str(r.kind):
		"coins":
			return "%d coins" % int(r.n)
		"drop":
			return "Bone Drop" if int(r.n) == 1 else "%d Bone Drops" % int(r.n)
		"lucky":
			return "Lucky Start" if int(r.n) == 1 else "%d Lucky Starts" % int(r.n)
		"title":
			return "Title: %s" % r.text
		"frame":
			return "Gold frame"
	return ""


## All of a level's rewards in one line ("Title: Adept + 50 coins + 3 new looks").
static func level_text(lv: int, id: String, with_looks := true) -> String:
	var bits := []
	for r: Dictionary in REWARDS.get(lv, []):
		bits.append(reward_text(r, id))
	var looks := HeroStyle.level_items(id, lv).size()
	if looks > 0 and with_looks:
		bits.append("%d new looks" % looks)
	return " + ".join(bits)
