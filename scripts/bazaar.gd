class_name Bazaar
## The Bone Bazaar (version 152, coins review fix 5): a small shop for spare coins, on the
## Armory's third tab. Three looks a day, which change when the Daily Crypt does (07:00 UTC):
## one cheaper, one middle and one grand. They come from the Bazaar's own looks (hero_style.gd
## EXTRA "bazaar": the price) and the Bone Drop looks still to be found, so a player out of
## luck with drops can buy one. Feat looks are earned, never sold.
##
## Why: players who have filled the Armory end runs with 1,000+ coins and nothing to buy,
## and a shop that changes each day is a reason to look in each day.

const SECTION := "bazaar"
const OWNED := "bazaar_looks"
const OFFERS := 3
## Bone Drop looks cost by the rarity of drop they're found in (Super Rare, Epic, Legendary).
const DROP_PRICE := {2: 700, 3: 1100, 4: 1500}
## Each day's three: one look from each band of prices.
const BANDS := [[0, 700], [701, 1100], [1101, 99999]]


static func owns(cfg: ConfigFile, slot: String, key: String) -> bool:
	return bool(cfg.get_value(OWNED, slot + "/" + key, false))


static func price(slot: String, key: String) -> int:
	var e := HeroStyle.extra(slot, key)
	if e.has("bazaar"):
		return int(e.bazaar)
	if e.has("drop"):
		return int(DROP_PRICE.get(int(e.drop), 1500))
	return -1


static func has(cfg: ConfigFile, slot: String, key: String) -> bool:
	var e := HeroStyle.extra(slot, key)
	return Drops.has_look(cfg, slot, key) if e.has("drop") else owns(cfg, slot, key)


## Every look the Bazaar can sell: [[slot, key]].
static func pool() -> Array:
	var out := []
	for slot: String in HeroStyle.EXTRA:
		for key: String in HeroStyle.EXTRA[slot]:
			if price(slot, key) > 0:
				out.append([slot, key])
	return out


## Today's looks: [[slot, key]], picked once a day from the looks not yet owned and kept in
## the save, so a look bought today stays on the shelf as SOLD.
static func today(cfg: ConfigFile, day := "") -> Array:
	if day == "":
		day = Curses.today()
	if str(cfg.get_value(SECTION, "day", "")) == day:
		return cfg.get_value(SECTION, "offer", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bazaar" + day)
	var left := pool().filter(func(l: Array) -> bool: return not has(cfg, l[0], l[1]))
	var offer := []
	for band: Array in BANDS:
		var fits := left.filter(func(l: Array) -> bool:
			var p := price(l[0], l[1])
			return p >= int(band[0]) and p <= int(band[1]))
		if not fits.is_empty():
			var pick: Array = fits[rng.randi() % fits.size()]
			offer.append(pick)
			left.erase(pick)
	while offer.size() < OFFERS and not left.is_empty():   # a band ran out: any look left
		var pick: Array = left[rng.randi() % left.size()]
		offer.append(pick)
		left.erase(pick)
	cfg.set_value(SECTION, "day", day)
	cfg.set_value(SECTION, "offer", offer)
	return offer


## True until the Bazaar tab is opened on a day with looks to sell (the NEW pill on its tab,
## and NEW LOOKS on the ARMORY button when nothing there can be upgraded).
static func unseen(cfg: ConfigFile) -> bool:
	if str(cfg.get_value(SECTION, "seen", "")) == Curses.today():
		return false
	return pool().any(func(l: Array) -> bool: return not has(cfg, l[0], l[1]))


static func mark_seen(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "seen", Curses.today())


## Buys a look (the caller checks the coins and saves).
static func give(cfg: ConfigFile, slot: String, key: String) -> void:
	if HeroStyle.extra(slot, key).has("drop"):
		cfg.set_value(Drops.LOOK_SECTION, slot + "/" + key, true)
	else:
		cfg.set_value(OWNED, slot + "/" + key, true)


## "New looks in 5 h" (or "in 40 min").
static func refresh_text() -> String:
	var now := int(Time.get_unix_time_from_system())
	var day_start := Curses.DAY_START_HOURS * 3600
	var into := posmod(now - day_start, 86400)
	var left := 86400 - into
	return "New looks in %d h" % ceili(left / 3600.0) if left >= 3600 else "New looks in %d min" % maxi(1, ceili(left / 60.0))


static func slot_name(slot: String) -> String:
	return {"outfit": "Outfit", "head": "Headwear", "hold": "Weapon", "glow": "Glow", "aura": "Aura"}.get(slot, slot.capitalize())
