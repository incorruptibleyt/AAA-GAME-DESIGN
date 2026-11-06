class_name BoneRoad
## The Bone Road: one long path of rewards on the title screen. Every room cleared adds a
## bone and every boss beaten adds BOSS_BONES more, in any mode, and bones are never lost.
## Each step on the road is claimed by a tap on the Bone Road screen (road_screen.gd).
##
## A run that dies on floor 1 is worth about 3 bones; a whole floor about 9. The first
## steps come in the first runs; the last one takes about a hundred runs.

const SECTION := "road"
const ROOM_BONES := 1
const BOSS_BONES := 4

## at: bones needed. kind: "coins" (n coins), "drop" (n Bone Drops), "lucky" (n Lucky Starts).
const STEPS := [
	{"at": 3, "kind": "coins", "n": 25},
	{"at": 8, "kind": "drop", "n": 1},
	{"at": 15, "kind": "coins", "n": 40},
	{"at": 24, "kind": "lucky", "n": 1},
	{"at": 35, "kind": "coins", "n": 60},
	{"at": 48, "kind": "drop", "n": 2},
	{"at": 62, "kind": "coins", "n": 80},
	{"at": 78, "kind": "lucky", "n": 1},
	{"at": 95, "kind": "coins", "n": 100},
	{"at": 115, "kind": "drop", "n": 3},
	{"at": 135, "kind": "coins", "n": 120},
	{"at": 158, "kind": "lucky", "n": 1},
	{"at": 182, "kind": "coins", "n": 140},
	{"at": 208, "kind": "drop", "n": 2},
	{"at": 235, "kind": "coins", "n": 160},
	{"at": 265, "kind": "drop", "n": 3},
	{"at": 295, "kind": "coins", "n": 180},
	{"at": 328, "kind": "lucky", "n": 2},
	{"at": 362, "kind": "coins", "n": 200},
	{"at": 400, "kind": "drop", "n": 3},
	{"at": 440, "kind": "coins", "n": 220},
	{"at": 482, "kind": "lucky", "n": 2},
	{"at": 526, "kind": "coins", "n": 250},
	{"at": 572, "kind": "drop", "n": 4},
	{"at": 620, "kind": "coins", "n": 280},
	{"at": 670, "kind": "lucky", "n": 2},
	{"at": 722, "kind": "coins", "n": 320},
	{"at": 776, "kind": "drop", "n": 4},
	{"at": 832, "kind": "coins", "n": 360},
	{"at": 890, "kind": "lucky", "n": 3},
	{"at": 950, "kind": "drop", "n": 5},
	{"at": 1000, "kind": "coins", "n": 1000},
]


static func bones(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "bones", 0))


static func add(cfg: ConfigFile, n: int) -> void:
	if n > 0:
		cfg.set_value(SECTION, "bones", bones(cfg) + n)


static func claimed(cfg: ConfigFile, i: int) -> bool:
	return bool(cfg.get_value(SECTION, "got_%d" % i, false))


## Steps reached but not claimed yet.
static func ready_count(cfg: ConfigFile) -> int:
	var b := bones(cfg)
	var n := 0
	for i in STEPS.size():
		if b >= int(STEPS[i].at) and not claimed(cfg, i):
			n += 1
	return n


## The first step not reached yet (STEPS.size() when the road is done).
static func next_index(cfg: ConfigFile) -> int:
	var b := bones(cfg)
	for i in STEPS.size():
		if b < int(STEPS[i].at):
			return i
	return STEPS.size()


## How far along to the next step, 0..1, for the bar on the title.
static func progress(cfg: ConfigFile) -> float:
	var i := next_index(cfg)
	if i >= STEPS.size():
		return 1.0
	var from := 0 if i == 0 else int(STEPS[i - 1].at)
	return clampf(float(bones(cfg) - from) / float(int(STEPS[i].at) - from), 0.0, 1.0)


static func reward_text(s: Dictionary) -> String:
	match str(s.kind):
		"drop":
			return "Bone Drop" if int(s.n) == 1 else "%d Bone Drops" % int(s.n)
		"lucky":
			return "Lucky Start" if int(s.n) == 1 else "%d Lucky Starts" % int(s.n)
	return "%d coins" % int(s.n)


## Claims step `i` into `cfg` (drops and Lucky Starts; the caller adds coins, which it
## holds). Returns the step, or {} if it can't be claimed.
static func claim(cfg: ConfigFile, i: int) -> Dictionary:
	if i < 0 or i >= STEPS.size() or claimed(cfg, i) or bones(cfg) < int(STEPS[i].at):
		return {}
	var s: Dictionary = STEPS[i]
	cfg.set_value(SECTION, "got_%d" % i, true)
	match str(s.kind):
		"drop":
			cfg.set_value(Drops.SECTION, "waiting", Drops.waiting(cfg) + int(s.n))
		"lucky":
			cfg.set_value(Drops.SECTION, "lucky", Drops.lucky(cfg) + int(s.n))
	return s
