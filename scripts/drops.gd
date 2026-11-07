class_name Drops
## Bone Drops: a free surprise reward after a good run. A drop is earned by beating a boss,
## or by reaching room 3 (or a deeper floor) before dying, at most MAX_PER_RUN a run and
## never in the tutorial's deaths. They wait in the save until opened (from the end
## screen or the title), and what's inside is only rolled when one is opened.
##
## Five kinds, from most to least common. Every drop gives something; nothing is ever
## bought with money. Average: about 25 coins a drop (about a fifth of a run).

const SECTION := "drops"
const MAX_PER_RUN := 3
## Unopened drops past this aren't kept (more than a few would pile up unopened).
const MAX_WAITING := 10

## weight: chance out of 100. Colours match the blessing card rarities.
const TIERS := [
	{"id": "bone", "name": "COMMON", "weight": 50, "coins": 10, "color": Color(0.82, 0.8, 0.74)},
	{"id": "green", "name": "RARE", "weight": 28, "coins": 20, "color": Color(0.35, 0.9, 0.45)},
	{"id": "blue", "name": "SUPER RARE", "weight": 14, "coins": 40, "color": Color(0.35, 0.65, 1.0)},
	{"id": "purple", "name": "EPIC", "weight": 6, "coins": 80, "color": Color(0.75, 0.4, 1.0)},
	{"id": "gold", "name": "LEGENDARY", "weight": 2, "coins": 200, "color": Color(1.0, 0.78, 0.25)},
]
## Armory upgrades a Legendary drop can give a free level of.
const FREE_LEVELS := ["vigor", "might", "haste", "swift", "luck"]


static func waiting(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "waiting", 0))


static func add(cfg: ConfigFile, n := 1) -> void:
	cfg.set_value(SECTION, "waiting", mini(waiting(cfg) + n, MAX_WAITING))
	cfg.set_value(SECTION, "earned", int(cfg.get_value(SECTION, "earned", 0)) + n)


## Lucky Start tokens: the next normal run (not the Daily) starts with a free blessing.
static func lucky(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "lucky", 0))


static func use_lucky(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "lucky", maxi(lucky(cfg) - 1, 0))


static func tier_index(id: String) -> int:
	for i in TIERS.size():
		if TIERS[i].id == id:
			return i
	return 0


## Opens one waiting drop: rolls it and writes the prize into `cfg` (Armory levels and
## Lucky Start tokens; coins are added by the caller, which holds the coin count).
## Returns {tier, name, color, coins, text, kind} or {} if none was waiting.
static func open(cfg: ConfigFile, rng: RandomNumberGenerator = null) -> Dictionary:
	if waiting(cfg) <= 0:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var roll := rng.randi_range(1, 100)
	var t: Dictionary = TIERS[0]
	var i := 0
	for tier: Dictionary in TIERS:
		roll -= int(tier.weight)
		t = tier
		if roll <= 0:
			break
		i += 1
	i = mini(i, TIERS.size() - 1)
	var out := {"tier": i, "name": t.name, "color": t.color, "coins": int(t.coins), "kind": "coins", "text": ""}
	# An Epic is a Lucky Start one time in three; a Legendary is a free Armory level when
	# there's one left to give.
	if t.id == "purple" and rng.randi_range(0, 2) == 0:
		cfg.set_value(SECTION, "lucky", lucky(cfg) + 1)
		out.coins = 0
		out.kind = "lucky"
		out.text = "LUCKY START\nYour next run begins\nwith a free blessing!"
	elif t.id == "gold":
		var open_ids := []
		for u: Dictionary in Armory.LIST:
			if u.id in FREE_LEVELS and Armory.level(cfg, u.id) < int(u.max):
				open_ids.append(u)
		if not open_ids.is_empty():
			var u: Dictionary = open_ids[rng.randi_range(0, open_ids.size() - 1)]
			var lv := Armory.level(cfg, u.id) + 1
			cfg.set_value(Armory.SAVE_SECTION, u.id, lv)
			out.coins = 0
			out.kind = "armory"
			out.text = "FREE ARMORY UPGRADE\n%s  level %d\n(%s)" % [u.title, lv, u.text]
	if out.kind == "coins":
		out.text = "+%d COINS" % out.coins
	cfg.set_value(SECTION, "waiting", waiting(cfg) - 1)
	cfg.set_value(SECTION, "opened", int(cfg.get_value(SECTION, "opened", 0)) + 1)
	if i >= 3:
		cfg.set_value(SECTION, "best_" + str(t.id), int(cfg.get_value(SECTION, "best_" + str(t.id), 0)) + 1)
	return out
