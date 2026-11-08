class_name Drops
## Bone Drops: a free surprise reward after a good run. A drop is earned by beating a boss,
## or by reaching room 3 (or a deeper floor) before dying, at most MAX_PER_RUN a run and
## never in the tutorial's deaths. They wait in the save until opened (from the end
## screen or the title), and what's inside is only rolled when one is opened.
##
## Five kinds, from most to least common. Every drop gives something; nothing is ever
## bought with money. Average: about 55 coins a drop (about half a run's coins).
## Version 116: a look is guaranteed after PITY drops in a row without one (a new player's
## first look comes at about drop 6, all 12 by about drop 75), the odds show behind "?",
## and once the Armory is full, spare coins buy a drop (BUY_COST, BUY_PER_DAY a day).
## The rarer kinds can hold a look found nowhere else (hero_style.gd EXTRA "drop"): a glow
## in a Super Rare, an outfit or aura in an Epic, headwear in a Legendary. Once all of a
## kind's looks are found, it gives what it did before.

const SECTION := "drops"
const MAX_PER_RUN := 3
## Unopened drops past this aren't kept (more than a few would pile up unopened).
const MAX_WAITING := 10

## weight: chance out of 100. Colours match the blessing card rarities.
const TIERS := [
	{"id": "bone", "name": "COMMON", "weight": 47, "coins": 30, "color": Color(0.82, 0.8, 0.74)},
	{"id": "green", "name": "RARE", "weight": 28, "coins": 50, "color": Color(0.35, 0.9, 0.45)},
	{"id": "blue", "name": "SUPER RARE", "weight": 14, "coins": 90, "color": Color(0.35, 0.65, 1.0)},
	{"id": "purple", "name": "EPIC", "weight": 8, "coins": 150, "color": Color(0.75, 0.4, 1.0)},
	{"id": "gold", "name": "LEGENDARY", "weight": 3, "coins": 300, "color": Color(1.0, 0.78, 0.25)},
]
## How often a drop of each kind holds a drop-only look while one is still to be found:
## out of 12 (Super Rare 1 in 3, Epic 2 in 3, Legendary 3 in 4).
const LOOK_CHANCE := [0, 0, 4, 8, 9]
const LOOK_SECTION := "drop_looks"

## A drop-only look is certain on the PITY-th drop in a row without one.
const PITY := 8
## Spare coins buy a drop once every Armory upgrade is bought.
const BUY_COST := 150
const BUY_PER_DAY := 3

## Armory upgrades a Legendary drop can give a free level of.
const FREE_LEVELS := ["vigor", "might", "haste", "swift", "luck"]


static func waiting(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "waiting", 0))


## Drops opened in a row without a look.
static func dry(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "dry", 0))


## "Look guaranteed in 3 drops" (or "" once every drop look is found).
static func pity_text(cfg: ConfigFile) -> String:
	if found_looks(cfg) >= all_looks():
		return ""
	var n := maxi(1, PITY - dry(cfg))
	return "New look guaranteed in the next drop!" if n == 1 else "New look guaranteed within %d drops" % n


## The odds, for the "?" on the drop screen.
static func odds_text(cfg: ConfigFile) -> String:
	var lines := ["WHAT'S INSIDE A BONE DROP"]
	for i in TIERS.size():
		var t: Dictionary = TIERS[i]
		var extra := ""
		if not missing_looks(cfg, i).is_empty() and int(LOOK_CHANCE[i]) > 0:
			extra = "  ·  look %d%%" % roundi(LOOK_CHANCE[i] * 100.0 / 12.0)
		lines.append("%s  %d%%  ·  %d coins%s" % [str(t.name).capitalize(), int(t.weight), int(t.coins), extra])
	lines.append("Epic: a Lucky Start 1 in 3. Legendary: a free Armory level while any are left.")
	if found_looks(cfg) < all_looks():
		lines.append("A new look is certain after %d drops in a row without one." % PITY)
	lines.append("Looks found: %d of %d. Drops are never sold for money." % [found_looks(cfg), all_looks()])
	return "\n".join(lines)


## True when every Armory upgrade is bought, so coins can buy a drop instead.
static func armory_full(cfg: ConfigFile) -> bool:
	for u: Dictionary in Armory.LIST:
		if Armory.level(cfg, u.id) < int(u.max):
			return false
	return true


## Drops still to buy today (0 when the Armory isn't full yet).
static func buys_left(cfg: ConfigFile, today: String) -> int:
	if not armory_full(cfg):
		return 0
	if str(cfg.get_value(SECTION, "buy_day", "")) != today:
		return BUY_PER_DAY
	return maxi(0, BUY_PER_DAY - int(cfg.get_value(SECTION, "bought", 0)))


static func buy(cfg: ConfigFile, today: String) -> void:
	if str(cfg.get_value(SECTION, "buy_day", "")) != today:
		cfg.set_value(SECTION, "buy_day", today)
		cfg.set_value(SECTION, "bought", 0)
	cfg.set_value(SECTION, "bought", int(cfg.get_value(SECTION, "bought", 0)) + 1)
	cfg.set_value(SECTION, "waiting", mini(waiting(cfg) + 1, MAX_WAITING))


static func add(cfg: ConfigFile, n := 1) -> void:
	cfg.set_value(SECTION, "waiting", mini(waiting(cfg) + n, MAX_WAITING))
	cfg.set_value(SECTION, "earned", int(cfg.get_value(SECTION, "earned", 0)) + n)


## Lucky Start tokens: the next normal run (not the Daily) starts with a free blessing.
static func lucky(cfg: ConfigFile) -> int:
	return int(cfg.get_value(SECTION, "lucky", 0))


static func use_lucky(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "lucky", maxi(lucky(cfg) - 1, 0))


static func has_look(cfg: ConfigFile, slot: String, key: String) -> bool:
	return bool(cfg.get_value(LOOK_SECTION, slot + "/" + key, false))


## The drop-only looks a drop of tier `i` can hold that `cfg` hasn't found: [[slot, key]].
static func missing_looks(cfg: ConfigFile, i: int) -> Array:
	var out := []
	for slot: String in HeroStyle.EXTRA:
		for key: String in HeroStyle.EXTRA[slot]:
			if int(HeroStyle.EXTRA[slot][key].get("drop", -1)) == i and not has_look(cfg, slot, key):
				out.append([slot, key])
	return out


static func found_looks(cfg: ConfigFile) -> int:
	return cfg.get_section_keys(LOOK_SECTION).size() if cfg.has_section(LOOK_SECTION) else 0


static func all_looks() -> int:
	var n := 0
	for slot: String in HeroStyle.EXTRA:
		for key: String in HeroStyle.EXTRA[slot]:
			if HeroStyle.EXTRA[slot][key].has("drop"):
				n += 1
	return n


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
	# A look found nowhere else, while there are some of this kind still to find; certain
	# after PITY drops in a row without one (the drop becomes the lowest kind with one left).
	var miss := missing_looks(cfg, i)
	var hit := not miss.is_empty() and rng.randi_range(1, 12) <= int(LOOK_CHANCE[i])
	if not hit and dry(cfg) + 1 >= PITY:
		for k in range(2, TIERS.size()):
			if not missing_looks(cfg, k).is_empty():
				i = k
				t = TIERS[k]
				miss = missing_looks(cfg, k)
				hit = true
				break
	var out := {"tier": i, "name": t.name, "color": t.color, "coins": int(t.coins), "kind": "coins", "text": ""}
	if hit:
		var look: Array = miss[rng.randi_range(0, miss.size() - 1)]
		cfg.set_value(LOOK_SECTION, "%s/%s" % look, true)
		var id := str(cfg.get_value("heroes", "selected", "rogue"))
		var picks := HeroStyle.picks(cfg, id)
		# Shown on its own: the Crypt King set's crown and glow would hide the new look.
		for slot: String in HeroStyle.PASS_SLOTS:
			if picks.get(slot, "") == HeroStyle.pass_key(slot):
				picks[slot] = ""
		picks[look[0]] = look[1]
		out.coins = 0
		out.kind = "look"
		out.look = look
		out.preview = HeroStyle.dressed(Heroes.get_hero(id), picks)
		out.hero = id
		out.text = "NEW LOOK: %s\nOnly found in Bone Drops.\nEvery hero can wear it." % HeroStyle.item_label(id, look[0], look[1])
		cfg.set_value(SECTION, "waiting", waiting(cfg) - 1)
		cfg.set_value(SECTION, "opened", int(cfg.get_value(SECTION, "opened", 0)) + 1)
		cfg.set_value(SECTION, "dry", 0)
		if i >= 3:
			cfg.set_value(SECTION, "best_" + str(t.id), int(cfg.get_value(SECTION, "best_" + str(t.id), 0)) + 1)
		return out
	cfg.set_value(SECTION, "dry", dry(cfg) + 1)
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
