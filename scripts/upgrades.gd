class_name Upgrades
## The blessing cards offered after each cleared room. To add one, copy an entry in LIST,
## give it a new id, and say what it changes in `apply` below.
##
## Every blessing belongs to a family (Shot, Flame, Frost, Bone) and has a rarity.
## Rarer cards turn up less often. "needs" means the card only appears once you own that
## blessing. "hero" means only that hero is offered it. "vault" means it is bought with
## coins in the Armory's Vault before it can turn up. Owning both halves of a SYNERGY
## puts its gold card in the next pick.

const FAMILIES := {
	"bolt": {"name": "Shot", "color": Color(1.0, 0.85, 0.35)},
	"flame": {"name": "Flame", "color": Color(1.0, 0.52, 0.2)},
	"frost": {"name": "Frost", "color": Color(0.55, 0.9, 1.0)},
	"bone": {"name": "Bone", "color": Color(0.88, 0.92, 0.72)},
	# The Blood Moon event's own blessings (events.gd): only offered in its runs.
	"moon": {"name": "Blood Moon", "color": Color(1.0, 0.38, 0.34)},
	# Version 246: Frostfall's own, each about its Blizzard (blizzard.gd).
	"yule": {"name": "Frostfall", "color": Color(0.5, 1.0, 0.72)},
}

const RARITIES := {
	"common": {"name": "COMMON", "color": Color(0.62, 0.64, 0.7), "weight": 60},
	"rare": {"name": "RARE", "color": Color(0.35, 0.62, 1.0), "weight": 30},
	"epic": {"name": "EPIC", "color": Color(0.78, 0.42, 1.0), "weight": 10},
	"synergy": {"name": "SYNERGY", "color": Color(1.0, 0.78, 0.25), "weight": 0},
}

const LIST := [
	{"id": "damage", "family": "bolt", "rarity": "common", "title": "Sharpened Shots", "text": "+20% damage", "max": 10},
	{"id": "speed", "family": "bolt", "rarity": "common", "title": "Quick Draw", "text": "+15% attack speed", "max": 10},
	{"id": "crit", "family": "bolt", "rarity": "common", "title": "Keen Eye", "text": "+15% critical hit chance", "max": 3},
	{"id": "multishot", "family": "bolt", "rarity": "rare", "title": "Twin Shots", "text": "+1 shot forward: +40% damage in all", "max": 3},
	{"id": "rear", "family": "bolt", "rarity": "rare", "title": "Eyes in the Back", "text": "+1 shot backward", "max": 1},
	{"id": "pierce", "family": "bolt", "rarity": "rare", "title": "Piercing Shot", "text": "Shots pass through 1 more enemy", "max": 2},
	{"id": "diagonal", "family": "bolt", "rarity": "epic", "title": "Fan of Shots", "text": "+2 shots at an angle", "max": 2},
	{"id": "fire", "family": "flame", "rarity": "rare", "title": "Fire Shots", "text": "Hits set enemies on fire", "max": 2},
	# Version 307 (player panel fix 2): Kindling, Frostbite and Deep Freeze were number cards
	# (fire twice as hot, chill twice as long, +30% damage); now each changes what happens.
	{"id": "kindling", "family": "flame", "rarity": "common", "title": "Kindling", "text": "Burning skeletons leave a patch of fire where they fall", "max": 1, "needs": "fire"},
	{"id": "pyre", "family": "flame", "rarity": "epic", "title": "Pyre", "text": "Burning skeletons explode when they die", "max": 1, "needs": "fire"},
	{"id": "frost", "family": "frost", "rarity": "rare", "title": "Frost Shots", "text": "Hits slow enemies down", "max": 1},
	{"id": "frostbite", "family": "frost", "rarity": "common", "title": "Frostbite", "text": "Every 3rd hit on a chilled skeleton freezes it solid", "max": 1, "needs": "frost"},
	{"id": "deepfreeze", "family": "frost", "rarity": "rare", "title": "Deep Freeze", "text": "Chilled skeletons shatter at 20% health (bosses take +30%)", "max": 1, "needs": "frost"},
	{"id": "vitality", "family": "bone", "rarity": "common", "title": "Vitality", "text": "+30 max health and heal 30 (more on deeper floors)", "max": 12},
	{"id": "boots", "family": "bone", "rarity": "common", "title": "Swift Boots", "text": "+12% move speed", "max": 3},
	{"id": "magnet", "family": "bone", "rarity": "common", "title": "Treasure Magnet", "text": "Hearts heal 30% more, and fly to you from twice as far", "max": 1},
	{"id": "greed", "family": "bone", "rarity": "common", "title": "Golden Touch", "text": "+30% coins from skeletons", "max": 2},
	{"id": "harvest", "family": "bone", "rarity": "rare", "title": "Bone Harvest", "text": "Heal 1% of your health per kill at chain x2+, up to 4% each room", "max": 3},
	{"id": "ward", "family": "bone", "rarity": "rare", "title": "Bone Ward", "text": "Block the first hit in every room", "max": 2},
	{"id": "links", "family": "bone", "rarity": "rare", "title": "Long Links", "text": "Bone Chain lasts 1 second longer", "max": 1},
	{"id": "marrow", "family": "bone", "rarity": "epic", "title": "Marrow", "text": "Bone Chain can climb to x4, and shots pierce 1 more enemy", "max": 1},
	# Version 307 (player panel fix 2): six cards that change how a run plays, for every hero
	# but Bouncing Shots ("heroes": only those heroes are offered it; the Knight's sword and
	# the Barbarian's axes, which already come back off walls, have no use for it).
	{"id": "bounce", "heroes": ["rogue", "mage"], "family": "bolt", "rarity": "rare", "title": "Bouncing Shots", "text": "Shots bounce off walls and pillars once", "max": 1},
	{"id": "spark", "family": "bolt", "rarity": "rare", "title": "Static Shots", "text": "Every hit throws a spark of lightning to the next skeleton", "max": 2},
	{"id": "orbit", "family": "bone", "rarity": "rare", "title": "Spinning Bones", "text": "Two bone blades circle you, cutting every skeleton they touch", "max": 2},
	{"id": "blaze_dash", "family": "flame", "rarity": "rare", "title": "Blazing Dash", "text": "Your dash leaves a trail of fire that burns skeletons", "max": 1},
	{"id": "phantom", "family": "bone", "rarity": "rare", "title": "Phantom Dash", "text": "Dash through skeletons to cut every one you pass", "max": 1},
	{"id": "cold_snap", "family": "frost", "rarity": "rare", "title": "Cold Snap", "text": "Your special freezes every skeleton near you solid", "max": 1},
	# Hero blessings: only the named hero is offered these. Version 239 (whole-game review fix
	# 8): two of each hero's three were plain number bumps (Nimble, Backstab, Bulwark, Broad
	# Swing, Bloodlust, Heavy Axes, Volatile Orbs, Arcane Flow). Now each one changes how that
	# hero's own attack works (see hero.gd and projectile.gd).
	{"id": "shadowstep", "hero": "rogue", "family": "bone", "rarity": "rare", "title": "Shadow Step", "text": "Dashing leaves your shadow behind: it throws knives for 2 seconds", "max": 1},
	{"id": "ricochet", "hero": "rogue", "family": "bolt", "rarity": "rare", "title": "Ricochet", "text": "Knives and bolts bounce on to 1 more skeleton", "max": 2},
	{"id": "quiver", "hero": "rogue", "family": "bolt", "rarity": "epic", "title": "Shadow Quiver", "text": "Shadow Volley fires 5 rings instead of 3", "max": 1},
	{"id": "riposte", "hero": "knight", "family": "bone", "rarity": "rare", "title": "Riposte", "text": "Shots your shield blocks fly back as sword waves", "max": 1},
	{"id": "cutting_wind", "hero": "knight", "family": "bolt", "rarity": "common", "title": "Cutting Wind", "text": "Every swing also throws a wide wave through the skeletons behind", "max": 1},
	{"id": "aftershock", "hero": "knight", "family": "bone", "rarity": "epic", "title": "Aftershock", "text": "Shield Slam reaches 40% further and freezes longer", "max": 1},
	{"id": "thunder_catch", "hero": "barbarian", "family": "bone", "rarity": "rare", "title": "Thunder Catch", "text": "Catching an axe slams the ground, throwing back skeletons near you", "max": 1},
	{"id": "buzzsaw", "hero": "barbarian", "family": "bolt", "rarity": "common", "title": "Buzzsaw", "text": "Axes stop and spin at the far end, grinding skeletons, then fly back", "max": 1},
	{"id": "whirl", "hero": "barbarian", "family": "bolt", "rarity": "epic", "title": "Endless Whirl", "text": "Whirlwind lasts twice as long", "max": 1},
	{"id": "burning_ground", "hero": "mage", "family": "flame", "rarity": "rare", "title": "Burning Ground", "text": "Charged orbs leave a pool of fire that burns skeletons", "max": 1},
	{"id": "frost_orbit", "hero": "mage", "family": "frost", "rarity": "common", "title": "Frost Orbit", "text": "While you move, ice orbs circle you, chilling skeletons they touch", "max": 1},
	{"id": "meteors", "hero": "mage", "family": "flame", "rarity": "epic", "title": "Meteor Storm", "text": "Meteor hits 3 more skeletons", "max": 1},
	# Event blessings: only offered in that event's runs and hunts ("event" is its id). The
	# Blood Moon's (version 134):
	{"id": "bloodpact", "event": "blood_moon", "family": "moon", "rarity": "rare", "title": "Blood Pact", "text": "+30% damage, but 15% less max health", "max": 1},
	{"id": "moonstep", "event": "blood_moon", "family": "moon", "rarity": "common", "title": "Moonlit Step", "text": "Dash recharges 25% faster, +8% move speed", "max": 2},
	{"id": "shardhunter", "event": "blood_moon", "family": "moon", "rarity": "rare", "title": "Shard Hunter", "text": "Skeletons felled in a Moon Surge pay 2 more Moon Shards", "max": 1},
	{"id": "eclipse_heart", "event": "blood_moon", "family": "moon", "rarity": "epic", "title": "Eclipse Heart", "text": "During a Moon Surge you heal 1 per kill and hit 25% harder", "max": 1},
	# Frostfall's (version 246; its runs used to be offered the Moon Surge ones):
	{"id": "hearth", "event": "frostfall", "family": "yule", "rarity": "common", "title": "Hearthkeeper", "text": "Fires warm 50% farther; in a Blizzard their warmth heals you", "max": 1},
	{"id": "furs", "event": "frostfall", "family": "yule", "rarity": "common", "title": "Thick Furs", "text": "The cold builds 40% slower", "max": 2},
	{"id": "gifthunter", "event": "frostfall", "family": "yule", "rarity": "rare", "title": "Gift Hunter", "text": "Gift Thieves never get away; Blizzard kills pay 2 more Snowflakes", "max": 1},
	{"id": "winters_heart", "event": "frostfall", "family": "yule", "rarity": "epic", "title": "Winter's Heart", "text": "The cold can't freeze you; in a Blizzard your hits chill skeletons", "max": 1},
	# Vault blessings: bought once with coins in the Armory, then they can turn up in runs.
	{"id": "siphon", "vault": true, "family": "bone", "rarity": "rare", "title": "Soul Siphon", "text": "Perfect dodges heal 10, up to 12% of your health each room", "max": 2},
	{"id": "frozen_ground", "vault": true, "family": "frost", "rarity": "rare", "title": "Frozen Ground", "text": "Perfect dodges chill skeletons near you", "max": 1},
	{"id": "executioner", "vault": true, "family": "bolt", "rarity": "rare", "title": "Executioner", "text": "+50% damage to nearly dead skeletons", "max": 1},
	{"id": "flashfire", "vault": true, "family": "flame", "rarity": "rare", "title": "Flashfire", "text": "Critical hits set skeletons on fire", "max": 1},
	{"id": "splinters", "vault": true, "family": "bone", "rarity": "epic", "title": "Bone Splinters", "text": "Kills burst into 3 bone shards", "max": 1},
	{"id": "overcharge", "vault": true, "family": "bolt", "rarity": "epic", "title": "Overcharge", "text": "Shots hit 25% harder at Chain x2 or more", "max": 1},
	# Version 219 (review 4 fix 29): more Vault cards that change how a run plays, so coins
	# have something worth saving for.
	{"id": "opening_volley", "vault": true, "family": "bolt", "rarity": "rare", "title": "Opening Volley", "text": "Every room starts with your special ready", "max": 1},
	{"id": "last_stand", "vault": true, "family": "bone", "rarity": "rare", "title": "Last Stand", "text": "+40% damage while under 30% health", "max": 1},
	{"id": "blood_rush", "vault": true, "family": "bone", "rarity": "rare", "title": "Blood Rush", "text": "Kills at the chain's cap heal 1% of your health", "max": 1},
	{"id": "chain_echo", "vault": true, "family": "bolt", "rarity": "epic", "title": "Chain Echo", "text": "When the chain fades, half of it stays", "max": 1},
]

const SYNERGIES := [
	{"id": "shatter", "family": "frost", "rarity": "synergy", "title": "Shatter", "text": "Fire + Frost: chilled skeletons burst into ice when they die", "max": 1, "parts": ["fire", "frost"]},
	{"id": "bonestorm", "family": "bolt", "rarity": "synergy", "title": "Bone Storm", "text": "Fan + Pierce: every 3rd volley adds a ring of piercing shards", "max": 1, "parts": ["diagonal", "pierce"]},
	{"id": "ossuary", "family": "bone", "rarity": "synergy", "title": "Ossuary", "text": "Ward + Vitality: reaching Chain x2 recharges a Bone Ward", "max": 1, "parts": ["ward", "vitality"]},
	{"id": "wildfire", "family": "flame", "rarity": "synergy", "title": "Wildfire", "text": "Fire + Twin Shots: burning spreads to a skeleton nearby", "max": 1, "parts": ["fire", "multishot"]},
	{"id": "glacier", "family": "frost", "rarity": "synergy", "title": "Glacier", "text": "Frost + Ward: blocking a hit freezes every skeleton near you", "max": 1, "parts": ["frost", "ward"]},
	{"id": "deadeye", "family": "bolt", "rarity": "synergy", "title": "Deadeye", "text": "Keen Eye + Pierce: critical hits fly through every skeleton", "max": 1, "parts": ["crit", "pierce"]},
]


## The synergy that taking `u` now would unlock (its other half is already held), or {}.
## Version 143: the blessing cards wear a badge for it.
static func completes(u: Dictionary, taken: Dictionary) -> Dictionary:
	if taken.has(u.id):
		return {}
	for s in SYNERGIES:
		if taken.has(s.id) or not (s.parts as Array).has(u.id):
			continue
		var other: String = s.parts[1] if s.parts[0] == u.id else s.parts[0]
		if taken.has(other):
			return s
	return {}


## Version 213 (hardest review fix #11): cards that never run out. Long runs used up every
## blessing around floor 14, then the pick screen had fewer than 3 cards or none. These only
## fill empty slots, so they never crowd out a real blessing.
const ENDLESS := [
	{"id": "deep_power", "family": "bolt", "rarity": "common", "title": "Deep Power", "text": "+8% damage", "max": 999, "endless": true},
	{"id": "deep_vigor", "family": "bone", "rarity": "common", "title": "Deep Vigor", "text": "+8% max health and heal it", "max": 999, "endless": true},
	{"id": "deep_haste", "family": "bolt", "rarity": "common", "title": "Deep Haste", "text": "+6% attack speed", "max": 999, "endless": true},
	# Version 219 (review 4 fix 30): deep cards with a choice in them. Three of these are
	# dealt at random once the blessings run out (they were the same three every time).
	{"id": "deep_glass", "family": "bolt", "rarity": "common", "title": "Glass Edge", "text": "+15% damage, but -6% max health", "max": 5, "endless": true},
	{"id": "deep_pierce", "family": "bolt", "rarity": "common", "title": "Deep Pierce", "text": "Shots pierce one more skeleton", "max": 3, "endless": true},
	{"id": "deep_ward", "family": "bone", "rarity": "common", "title": "Deep Ward", "text": "+1 Bone Ward: blocks a hit, comes back each room", "max": 3, "endless": true},
	{"id": "deep_steady", "family": "bone", "rarity": "common", "title": "Steady Chain", "text": "The chain fades 10% slower", "max": 5, "endless": true},
	{"id": "deep_stride", "family": "bone", "rarity": "common", "title": "Deep Stride", "text": "+8% move speed, but -4% damage", "max": 4, "endless": true},
]


## How many rare-or-better blessings the hero could still be offered (the Champion's Door
## promises one, so it is only offered while some are left).
static func rares_left(taken: Dictionary) -> int:
	var n := 0
	for u in LIST:
		if u.rarity != "common" and taken.get(u.id, 0) < u.max and (not u.has("needs") or taken.has(u.needs)) and fits_hero(u) and unlocked(u):
			n += 1
	return n


static func get_def(id: String) -> Dictionary:
	for u in LIST + SYNERGIES + ENDLESS:
		if u.id == id:
			return u
	return {}


## Only the hero a blessing is made for is offered it.
static func fits_hero(u: Dictionary) -> bool:
	if u.has("heroes"):
		return Game.hero != null and (u.heroes as Array).has(Game.hero.hero_id)
	return not u.has("hero") or (Game.hero != null and Game.hero.hero_id == u.hero)


## Vault blessings only turn up once they're bought; an event's own only in its runs.
static func unlocked(u: Dictionary) -> bool:
	var ev := str(u.get("event", ""))
	if ev != "" and (Game.event == "" or str(Events.ev().get("id", "")) != ev):
		return false
	return not u.get("vault", false) or Game.vault.has(u.id)


## What Vitality gives on this floor (see Game.heal_scale): 30 on floor 1, 54 on floor 5,
## then it keeps pace with enemy hits deeper down.
static func vitality_amount() -> float:
	return roundf(30.0 * Game.heal_scale())


## A card's text, with this floor's real numbers where they change.
static func card_text(u: Dictionary) -> String:
	if u.id == "vitality":
		var v := int(vitality_amount())
		return "+%d max health and heal %d" % [v, v]
	return u.text


## The colour a card's title uses.
static func color(u: Dictionary) -> Color:
	return FAMILIES[u.family].color


static func apply(id: String, h: Hero) -> void:
	h.perks[id] = h.perks.get(id, 0) + 1
	match id:
		"damage": h.damage *= 1.2
		"speed": h.shots_per_second *= 1.15
		"multishot": h.front_bolts += 1   # the forward shots share the extra damage (Hero.front_share)
		"diagonal": h.diagonal_bolts += 1
		"rear": h.rear_bolts += 1
		"pierce": h.pierce += 1
		"crit": h.crit_chance += 0.15
		"fire": h.burn_dps += 8.0   # (Kindling no longer doubles it: version 307)
		"vitality":
			var v := vitality_amount()
			h.max_health += v
			h.heal(v)
		"harvest": h.harvest_heal += 2.0   # version 213: per kill it heals 1% of max health a pick
		"marrow": h.pierce += 1   # version 213: the chain to x4 alone was weaker than a common card
		# Version 219 (review 4 fix 30): +8% of the damage the hero had at the first deep
		# card, added (x1.08 compounded, and the endless floors got easier the deeper you went).
		"deep_power": h.damage += _deep_base(h, "damage") * 0.08
		"deep_vigor":
			var add := roundf(_deep_base(h, "max_health") * 0.08)
			h.max_health += add
			h.heal(add)
		"deep_haste": h.shots_per_second += _deep_base(h, "shots_per_second") * 0.06
		# Version 219 review (Phase 0): Glass Edge and Deep Stride add a share of the base too
		# (Glass multiplied, x4 damage after 10 picks), and Glass stops at 5.
		"deep_glass":
			h.damage += _deep_base(h, "damage") * 0.15
			h.max_health = maxf(20.0, roundf(h.max_health - _deep_base(h, "max_health") * 0.06))
			h.health = minf(h.health, h.max_health)
		"deep_pierce": h.pierce += 1
		"deep_ward":
			h.ward_max += 1
			h.ward += 1
		"deep_stride":
			h.move_speed += _deep_base(h, "move_speed") * 0.08
			h.damage -= _deep_base(h, "damage") * 0.04
		"boots": h.move_speed *= 1.12
		"frost": h.frost = true
		"magnet": h.magnet = 2.0
		"greed": h.coin_bonus += 0.3
		"ward":
			h.ward_max += 1
			h.ward += 1
		"ossuary":
			h.ward = h.ward_max
		"quiver": h.volley_rings = 5
		"aftershock": h.slam_reach *= 1.4
		"whirl": h.whirl_time *= 2.0
		# (Version 239's hero blessings work from h.perks: hero.gd and projectile.gd look
		# them up, so a saved run brings them back with no number of their own to save.)
		"meteors": h.meteor_count += 3
		"bloodpact":
			h.damage *= 1.3
			h.max_health = roundf(h.max_health * 0.85)
			h.health = minf(h.health, h.max_health)
		"moonstep":
			h.dash_cooldown_time *= 0.75
			h.move_speed *= 1.08


## Pick up to `count` different blessings the hero can still take. Rarer cards are
## less likely, and a synergy the hero has just unlocked always takes the first slot.
## `finish_synergy` (first run) also offers the missing half of a synergy you half own,
## Wildfire first.
## `family` (a door's path) makes all but one card that family when it can, and
## `better` (the Champion's Door) leaves out common cards. `rng` (the Daily Crypt's, seeded)
## gives everyone with the same blessings the same cards; without it they're random.
## Version 219 (review 4 fix 33): commons the player just passed over rest for two picks
## (id -> picks left; game.gd fills it), and Vitality isn't offered at full health. Only in
## free play: Daily Crypt and Crypt Race offers (`rng` given) stay the same for everyone.
static var resting := {}


## Notes a pick: the commons on offer that weren't taken rest for the next two picks.
static func note_pick(offered: Array, chosen: Dictionary) -> void:
	for id in resting.keys():
		resting[id] = int(resting[id]) - 1
		if int(resting[id]) <= 0:
			resting.erase(id)
	for u: Dictionary in offered:
		if u.get("rarity", "") == "common" and u.get("id", "") != chosen.get("id", ""):
			resting[u.id] = 2


## A reroll: the cards just swapped away (any rarity) aren't dealt straight back.
static func note_reroll(offered: Array) -> void:
	for u: Dictionary in offered:
		if u.has("id"):
			resting[u.id] = maxi(int(resting.get(u.id, 0)), 1)


static func _fresh(pool: Array, count: int) -> Array:
	var full: bool = Game.hero != null and is_instance_valid(Game.hero) and Game.hero.health >= Game.hero.max_health - 0.5
	var kept := pool.filter(func(u: Dictionary) -> bool: return not resting.has(u.id) and not (full and u.id == "vitality"))
	return kept if kept.size() >= count else pool


static func roll(taken: Dictionary, count := 3, finish_synergy := false, family := "", better := false, rng: RandomNumberGenerator = null) -> Array:
	var out := []
	for s in SYNERGIES:
		if not taken.has(s.id) and taken.has(s.parts[0]) and taken.has(s.parts[1]):
			out.append(s)
			break
	var pool := []
	for u in LIST:
		if taken.get(u.id, 0) < u.max and (not u.has("needs") or taken.has(u.needs)) and fits_hero(u) and unlocked(u):
			pool.append(u)
	if better:
		var rarer := pool.filter(func(u): return u.rarity != "common")
		if not rarer.is_empty():
			pool = rarer
	# v220 (v219 review): a Path door's promise and the step-4 synergy come first, so resting
	# cards are only set aside on an ordinary pick.
	if rng == null and family == "" and not finish_synergy:
		pool = _fresh(pool, count)
	if finish_synergy and out.is_empty():
		# Wildfire first: room 1 offered half of it (roll_first), and it's the one you see.
		var order := SYNERGIES.duplicate()
		order.sort_custom(func(a, b): return a.id == "wildfire" and b.id != "wildfire")
		for s in order:
			var half: Array = s.parts.filter(func(id): return not taken.has(id))
			if half.size() == 1:
				var u := get_def(half[0])
				if pool.has(u):
					out.append(u)
					pool.erase(u)
					break
	var lean := count - 1 if family != "" else 0
	while out.size() < count and not pool.is_empty():
		var from := pool
		if lean > 0:
			lean -= 1
			var same := pool.filter(func(x): return x.family == family)
			if not same.is_empty():
				from = same
		var u := _weighted(from, rng)
		out.append(u)
		pool.erase(u)
	var deep := ENDLESS.filter(func(e: Dictionary) -> bool: return taken.get(e.id, 0) < int(e.max) and not out.has(e))
	while out.size() < count and not deep.is_empty():
		var e: Dictionary = deep[(rng.randi() if rng else randi()) % deep.size()]
		out.append(e)
		deep.erase(e)
	return out


## A stat as it was when the hero took their first deep card (deep cards add a share of it).
static func _deep_base(h: Hero, stat: String) -> float:
	var key := "deep_base_" + stat
	if not h.has_meta(key):
		h.set_meta(key, float(h.get(stat)))
	return float(h.get_meta(key))


## How many blessings of `family` the hero could still be offered (a door's path promises
## 2 of 3 cards of one family, so it is only offered while at least 2 are left).
static func family_left(taken: Dictionary, family: String) -> int:
	var n := 0
	for u in LIST:
		if u.family == family and taken.get(u.id, 0) < u.max and (not u.has("needs") or taken.has(u.needs)) and fits_hero(u) and unlocked(u):
			n += 1
	return n


## One blessing from `pool`, rarer ones less likely.
static func _weighted(pool: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0
	for u in pool:
		total += RARITIES[u.rarity].weight
	var r := (rng.randi() if rng else randi()) % total
	for u in pool:
		r -= RARITIES[u.rarity].weight
		if r < 0:
			return u
	return pool[0]


## The very first pick (tutorial room 1). Version 240 (whole-game review fix 15): three cards
## that each change how the hero fights, so the first choice is a real one. It used to be
## Vitality and a plain common beside one card you could see (version 142). Now: a new shot
## (Twin Shots or Fire Shots, half of Wildfire), one of the hero's own (version 239), and one
## more you can see at work (Frost Shots, Eyes in the Back or Bone Ward).
## Version 306 (player panel fix 1): the tutorial's "Gifts for the road" were three cards
## picked at random, so mostly number cards and sometimes the same one twice ("Sharpened
## Shots, Quick Draw, Sharpened Shots"). Now they are `n` different cards that each change how
## the hero fights: one of the hero's own blessings, then shot, fire, frost or ward cards,
## from different families where possible. Nothing the hero already holds.
const GIFT_RULES := ["multishot", "fire", "frost", "pierce", "rear", "ward", "diagonal", "spark", "orbit", "phantom"]

static func roll_gifts(taken: Dictionary, n := 3) -> Array:
	var can := func(id: String) -> bool: return not taken.has(id)
	var out := []
	var own := LIST.filter(func(u): return u.has("hero") and u.rarity != "epic" and fits_hero(u) and can.call(u.id))
	own.shuffle()
	if not own.is_empty():
		out.append(own[0])
	var rules := GIFT_RULES.filter(func(id: String) -> bool: return can.call(id) and fits_hero(get_def(id)))
	rules.shuffle()
	for fresh_family in [true, false]:
		for id in rules:
			var u := get_def(id)
			if out.size() >= n or out.has(u):
				continue
			if fresh_family and out.any(func(o): return o.family == u.family):
				continue
			out.append(u)
	return out


static func roll_first(taken: Dictionary) -> Array:
	var can := func(id: String) -> bool: return taken.get(id, 0) < int(get_def(id).get("max", 1))
	var out := []
	var shots := ["multishot", "fire"].filter(can)
	shots.shuffle()
	if not shots.is_empty():
		out.append(get_def(shots[0]))
	var own := LIST.filter(func(u): return u.has("hero") and u.rarity != "epic" and fits_hero(u) and can.call(u.id))
	own.shuffle()
	if not own.is_empty():
		out.append(own[0])
	var seen := ["frost", "rear", "ward"].filter(can)
	seen.shuffle()
	for id in seen:
		if out.size() < 3:
			out.append(get_def(id))
	if out.size() < 3:
		var pool := LIST.filter(func(u): return u.rarity == "common" and not u.has("needs") and not u.has("hero") and not u.has("vault") and not u.has("event") and can.call(u.id) and not out.has(u))
		pool.shuffle()
		out += pool.slice(0, 3 - out.size())
	out.shuffle()
	return out
