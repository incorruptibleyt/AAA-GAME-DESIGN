class_name Feats
## Feats: twenty skill challenges, each worth a look no one can buy (hero_style.gd EXTRA,
## "feat"). Every hero can wear a Feat look once it's earned. The game checks them as they
## happen (game.gd _feat_*), never in the tutorial, and a Feat is kept forever.
##
## LIST: id, name, what to do (text), the look it gives ([slot, key]), and for counted ones
## the target (goal) and the record that counts towards it (stat: a best in one run, read
## from the save's [feats] best_<stat>), so the Feats screen can show progress.

const SECTION := "feats"

const LIST := [
	{"id": "dodger", "name": "Quick Feet", "text": "Make 15 PERFECT dodges in a run that reaches floor 3", "look": ["glow", "mirage"], "goal": 15, "stat": "perfect3"},
	{"id": "linked", "name": "Iron Chain", "text": "Hold the Bone Chain at x3 for 30 seconds", "look": ["glow", "inferno"], "goal": 30, "stat": "chain_hold"},
	{"id": "untouched", "name": "Untouched", "text": "Clear a room on floor 2 or deeper without being hit", "look": ["glow", "glacier"]},
	{"id": "rusher", "name": "Room Rusher", "text": "Clear a room on floor 2 or deeper in under 10 seconds", "look": ["aura", "quickstep"]},
	{"id": "centurion", "name": "Centurion", "text": "Destroy 150 skeletons in one run", "look": ["outfit", "bonecarved"], "goal": 150, "stat": "kills"},
	{"id": "blessed", "name": "Blessed", "text": "Hold 12 blessings in one run", "look": ["glow", "aurora"], "goal": 12, "stat": "blessings"},
	{"id": "halfway", "name": "Halfway Hero", "text": "Beat the boss of floor 3 or deeper", "look": ["outfit", "frostbite"]},
	{"id": "laststand", "name": "Last Stand", "text": "Beat a boss with 15% health or less left", "look": ["outfit", "magma"]},
	{"id": "cleankill", "name": "Clean Kill", "text": "Beat a boss without being hit in its room", "look": ["outfit", "ghostwalk"]},
	{"id": "specialist", "name": "Specialist", "text": "Use your special 4 times in one boss fight", "look": ["aura", "arcane"], "goal": 4, "stat": "boss_special"},
	{"id": "bossbreaker", "name": "Boss Breaker", "text": "Beat a floor 3+ boss in under 30 seconds", "look": ["head", "storm_halo"]},
	{"id": "chainlord", "name": "Chain Lord", "text": "Grow the Bone Chain to x3 on floor 4 or deeper", "look": ["aura", "stormcaller"], "goal": 30, "stat": "chain4"},
	{"id": "perfectionist", "name": "Perfectionist", "text": "Make 40 PERFECT dodges in one run", "look": ["aura", "phantom"], "goal": 40, "stat": "perfect"},
	{"id": "highscore", "name": "High Scorer", "text": "Score 20,000 in one run", "look": ["outfit", "thunder"], "goal": 20000, "stat": "score"},
	{"id": "dailywin", "name": "Daily Victor", "text": "Win the Daily Crypt's official run", "look": ["aura", "sunflare"]},
	{"id": "faithful", "name": "Faithful", "text": "Reach a 7-day Daily Crypt streak (one missed day a week is forgiven)", "look": ["outfit", "shadowflame"], "goal": 7, "stat": "streak"},
	{"id": "fourheroes", "name": "Band of Four", "text": "Beat a boss with each of the 4 heroes", "look": ["head", "star_circlet"], "goal": 4, "stat": "heroes"},
	{"id": "conqueror", "name": "Crypt Conqueror", "text": "Beat the boss of floor 5 or deeper", "look": ["head", "flame_crown"]},
	{"id": "flawless", "name": "Flawless", "text": "Clear a whole floor, boss too, without being hit", "look": ["outfit", "starweave"]},
	{"id": "legend", "name": "True Master", "text": "Reach Mastery level 10 with any hero", "look": ["head", "skull_helm"], "goal": 10, "stat": "mastery"},
]


static func get_feat(id: String) -> Dictionary:
	for f: Dictionary in LIST:
		if f.id == id:
			return f
	return {}


static func done(cfg: ConfigFile, id: String) -> bool:
	return bool(cfg.get_value(SECTION, id, false))


static func count(cfg: ConfigFile) -> int:
	return LIST.filter(func(f: Dictionary) -> bool: return done(cfg, f.id)).size()


## Marks Feat `id` done in `cfg` (the caller saves). Returns the Feat if it was new.
static func complete(cfg: ConfigFile, id: String) -> Dictionary:
	if done(cfg, id):
		return {}
	cfg.set_value(SECTION, id, true)
	cfg.set_value(SECTION, "new", true)   # a NEW tag on the Feats button until it's opened
	return get_feat(id)


## The best value towards a counted Feat (one run's best, the streak, heroes...).
static func best(cfg: ConfigFile, stat: String) -> int:
	return int(cfg.get_value(SECTION, "best_" + stat, 0))


static func note_best(cfg: ConfigFile, stat: String, v: int) -> void:
	if v > best(cfg, stat):
		cfg.set_value(SECTION, "best_" + stat, v)


## "Ghostwalk outfit" for the Feat's look.
static func reward_label(f: Dictionary) -> String:
	return HeroStyle.item_label("", str(f.look[0]), str(f.look[1]))


## Progress text for the Feats screen: "7 / 10", "x2.4 / x3", or "" for one-off Feats.
static func progress(cfg: ConfigFile, f: Dictionary) -> String:
	if not f.has("goal"):
		return ""
	var g := int(f.goal)
	var b := mini(best(cfg, str(f.stat)), g)
	if f.stat == "chain" or f.stat == "chain4":
		return "best x%.1f / x%.1f" % [maxf(1.0, b / 10.0), g / 10.0]
	if f.stat == "chain_hold":
		return "best %ds / %ds" % [b, g]
	if f.stat == "score":
		return "best %s / %s" % [Hud.thousands(b), Hud.thousands(g)]
	return "best %d / %d" % [b, g]
