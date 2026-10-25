class_name Upgrades
## The blessing cards offered after each cleared room. To add one, copy an entry in LIST,
## give it a new id, and say what it changes in `apply` below.
##
## Every blessing belongs to a family (Shot, Flame, Frost, Bone) and has a rarity.
## Rarer cards turn up less often. "needs" means the card only appears once you own that
## blessing. "hero" means only that hero is offered it. Owning both halves of a SYNERGY
## puts its gold card in the next pick.

const FAMILIES := {
	"bolt": {"name": "Shot", "color": Color(1.0, 0.85, 0.35)},
	"flame": {"name": "Flame", "color": Color(1.0, 0.52, 0.2)},
	"frost": {"name": "Frost", "color": Color(0.55, 0.9, 1.0)},
	"bone": {"name": "Bone", "color": Color(0.88, 0.92, 0.72)},
}

const RARITIES := {
	"common": {"name": "COMMON", "color": Color(0.62, 0.64, 0.7), "weight": 60},
	"rare": {"name": "RARE", "color": Color(0.35, 0.62, 1.0), "weight": 30},
	"epic": {"name": "EPIC", "color": Color(0.78, 0.42, 1.0), "weight": 10},
	"synergy": {"name": "SYNERGY", "color": Color(1.0, 0.78, 0.25), "weight": 0},
}

const LIST := [
	{"id": "damage", "family": "bolt", "rarity": "common", "title": "Sharpened Shots", "text": "+20% damage", "max": 99},
	{"id": "speed", "family": "bolt", "rarity": "common", "title": "Quick Draw", "text": "+15% attack speed", "max": 99},
	{"id": "crit", "family": "bolt", "rarity": "common", "title": "Keen Eye", "text": "+15% critical hit chance", "max": 3},
	{"id": "multishot", "family": "bolt", "rarity": "rare", "title": "Twin Shots", "text": "+1 shot forward (each hits 10% softer)", "max": 3},
	{"id": "rear", "family": "bolt", "rarity": "rare", "title": "Eyes in the Back", "text": "+1 shot backward", "max": 1},
	{"id": "pierce", "family": "bolt", "rarity": "rare", "title": "Piercing Shot", "text": "Shots pass through 1 more enemy", "max": 2},
	{"id": "diagonal", "family": "bolt", "rarity": "epic", "title": "Fan of Shots", "text": "+2 shots at an angle", "max": 2},
	{"id": "fire", "family": "flame", "rarity": "rare", "title": "Fire Shots", "text": "Hits set enemies on fire", "max": 2},
	{"id": "kindling", "family": "flame", "rarity": "common", "title": "Kindling", "text": "Fire burns twice as hot", "max": 1, "needs": "fire"},
	{"id": "pyre", "family": "flame", "rarity": "epic", "title": "Pyre", "text": "Burning skeletons explode when they die", "max": 1, "needs": "fire"},
	{"id": "frost", "family": "frost", "rarity": "rare", "title": "Frost Shots", "text": "Hits slow enemies down", "max": 1},
	{"id": "frostbite", "family": "frost", "rarity": "common", "title": "Frostbite", "text": "Chill lasts twice as long", "max": 1, "needs": "frost"},
	{"id": "deepfreeze", "family": "frost", "rarity": "rare", "title": "Deep Freeze", "text": "Chilled skeletons take +30% damage", "max": 1, "needs": "frost"},
	{"id": "vitality", "family": "bone", "rarity": "common", "title": "Vitality", "text": "+30 max health and heal 30", "max": 99},
	{"id": "boots", "family": "bone", "rarity": "common", "title": "Swift Boots", "text": "+12% move speed", "max": 3},
	{"id": "magnet", "family": "bone", "rarity": "common", "title": "Treasure Magnet", "text": "Pick up hearts and coins from twice as far", "max": 1},
	{"id": "greed", "family": "bone", "rarity": "common", "title": "Golden Touch", "text": "+30% coins from skeletons", "max": 2},
	{"id": "harvest", "family": "bone", "rarity": "rare", "title": "Bone Harvest", "text": "Heal 2 per kill while your chain is x2 or more", "max": 3},
	{"id": "ward", "family": "bone", "rarity": "rare", "title": "Bone Ward", "text": "Block the first hit in every room", "max": 2},
	{"id": "links", "family": "bone", "rarity": "rare", "title": "Long Links", "text": "Bone Chain lasts 1 second longer", "max": 1},
	{"id": "marrow", "family": "bone", "rarity": "epic", "title": "Marrow", "text": "Bone Chain can climb to x4", "max": 1},
	# Hero blessings: only the named hero is offered these.
	{"id": "nimble", "hero": "rogue", "family": "bone", "rarity": "rare", "title": "Nimble", "text": "Dash recharges 40% faster", "max": 1},
	{"id": "backstab", "hero": "rogue", "family": "bolt", "rarity": "rare", "title": "Backstab", "text": "Critical hits deal triple damage", "max": 1},
	{"id": "quiver", "hero": "rogue", "family": "bolt", "rarity": "epic", "title": "Shadow Quiver", "text": "Shadow Volley fires 5 rings instead of 3", "max": 1},
	{"id": "bulwark", "hero": "knight", "family": "bone", "rarity": "rare", "title": "Bulwark", "text": "Take 10% less damage", "max": 2},
	{"id": "broad", "hero": "knight", "family": "bolt", "rarity": "common", "title": "Broad Swing", "text": "Sword waves 25% wider and 10% harder", "max": 2},
	{"id": "aftershock", "hero": "knight", "family": "bone", "rarity": "epic", "title": "Aftershock", "text": "Shield Slam reaches 40% further and freezes longer", "max": 1},
	{"id": "bloodlust", "hero": "barbarian", "family": "bone", "rarity": "rare", "title": "Bloodlust", "text": "Heal 2 more for every kill", "max": 2},
	{"id": "heavy", "hero": "barbarian", "family": "bolt", "rarity": "common", "title": "Heavy Axes", "text": "Axes hit 10% harder and knock skeletons further", "max": 2},
	{"id": "whirl", "hero": "barbarian", "family": "bolt", "rarity": "epic", "title": "Endless Whirl", "text": "Whirlwind lasts twice as long", "max": 1},
	{"id": "volatile", "hero": "mage", "family": "flame", "rarity": "rare", "title": "Volatile Orbs", "text": "Orb blasts are 35% wider", "max": 2},
	{"id": "flow", "hero": "mage", "family": "frost", "rarity": "common", "title": "Arcane Flow", "text": "Orbs fly 20% faster, cast 10% faster", "max": 2},
	{"id": "meteors", "hero": "mage", "family": "flame", "rarity": "epic", "title": "Meteor Storm", "text": "Meteor hits 3 more skeletons", "max": 1},
]

const SYNERGIES := [
	{"id": "shatter", "family": "frost", "rarity": "synergy", "title": "Shatter", "text": "Fire + Frost: chilled skeletons burst into ice when they die", "max": 1, "parts": ["fire", "frost"]},
	{"id": "bonestorm", "family": "bolt", "rarity": "synergy", "title": "Bone Storm", "text": "Fan + Pierce: every 3rd volley adds a ring of piercing shards", "max": 1, "parts": ["diagonal", "pierce"]},
	{"id": "ossuary", "family": "bone", "rarity": "synergy", "title": "Ossuary", "text": "Ward + Vitality: reaching Chain x2 recharges a Bone Ward", "max": 1, "parts": ["ward", "vitality"]},
	{"id": "wildfire", "family": "flame", "rarity": "synergy", "title": "Wildfire", "text": "Fire + Twin Shots: burning spreads to a skeleton nearby", "max": 1, "parts": ["fire", "multishot"]},
	{"id": "glacier", "family": "frost", "rarity": "synergy", "title": "Glacier", "text": "Frost + Ward: blocking a hit freezes every skeleton near you", "max": 1, "parts": ["frost", "ward"]},
	{"id": "deadeye", "family": "bolt", "rarity": "synergy", "title": "Deadeye", "text": "Keen Eye + Pierce: critical hits fly through every skeleton", "max": 1, "parts": ["crit", "pierce"]},
]


static func get_def(id: String) -> Dictionary:
	for u in LIST + SYNERGIES:
		if u.id == id:
			return u
	return {}


## Only the hero a blessing is made for is offered it.
static func fits_hero(u: Dictionary) -> bool:
	return not u.has("hero") or (Game.hero != null and Game.hero.hero_id == u.hero)


## The colour a card's title uses.
static func color(u: Dictionary) -> Color:
	return FAMILIES[u.family].color


static func apply(id: String, h: Hero) -> void:
	h.perks[id] = h.perks.get(id, 0) + 1
	match id:
		"damage": h.damage *= 1.2
		"speed": h.shots_per_second *= 1.15
		"multishot":
			h.front_bolts += 1
			h.damage *= 0.9
		"diagonal": h.diagonal_bolts += 1
		"rear": h.rear_bolts += 1
		"pierce": h.pierce += 1
		"crit": h.crit_chance += 0.15
		"fire": h.burn_dps += 8.0
		"kindling": h.burn_dps *= 2.0
		"vitality":
			h.max_health += 30.0
			h.heal(30.0)
		"harvest": h.harvest_heal += 2.0
		"boots": h.move_speed *= 1.12
		"frost": h.frost = true
		"frostbite": h.frost_time *= 2.0
		"magnet": h.magnet = 2.0
		"greed": h.coin_bonus += 0.3
		"ward":
			h.ward_max += 1
			h.ward += 1
		"ossuary":
			h.ward = h.ward_max
		"nimble": h.dash_cooldown_time *= 0.6
		"backstab": h.crit_mult = 3.0
		"quiver": h.volley_rings = 5
		"bulwark": h.armor += 0.1
		"broad":
			h.bolt_size *= 1.25
			h.damage *= 1.1
		"aftershock": h.slam_reach *= 1.4
		"bloodlust": h.heal_on_kill += 2.0
		"heavy":
			h.damage *= 1.1
			h.bolt_push *= 1.5
		"whirl": h.whirl_time *= 2.0
		"volatile": h.splash *= 1.35
		"flow":
			h.bolt_speed *= 1.2
			h.shots_per_second *= 1.1
		"meteors": h.meteor_count += 3


## Pick up to `count` different blessings the hero can still take. Rarer cards are
## less likely, and a synergy the hero has just unlocked always takes the first slot.
## `finish_synergy` (first run) also offers the missing half of a synergy you half own.
static func roll(taken: Dictionary, count := 3, finish_synergy := false) -> Array:
	var out := []
	for s in SYNERGIES:
		if not taken.has(s.id) and taken.has(s.parts[0]) and taken.has(s.parts[1]):
			out.append(s)
			break
	var pool := []
	for u in LIST:
		if taken.get(u.id, 0) < u.max and (not u.has("needs") or taken.has(u.needs)) and fits_hero(u):
			pool.append(u)
	if finish_synergy and out.is_empty():
		for s in SYNERGIES:
			var half: Array = s.parts.filter(func(id): return not taken.has(id))
			if half.size() == 1:
				var u := get_def(half[0])
				if pool.has(u):
					out.append(u)
					pool.erase(u)
					break
	while out.size() < count and not pool.is_empty():
		var total := 0
		for u in pool:
			total += RARITIES[u.rarity].weight
		var r := randi() % total
		for u in pool:
			r -= RARITIES[u.rarity].weight
			if r < 0:
				out.append(u)
				pool.erase(u)
				break
	return out


## The very first pick: three plain common cards, one of them Vitality (half of Ossuary).
static func roll_commons(taken: Dictionary) -> Array:
	var pool := LIST.filter(func(u): return u.rarity == "common" and not u.has("needs") and not u.has("hero") and taken.get(u.id, 0) < u.max and u.id != "vitality")
	pool.shuffle()
	var out := [get_def("vitality")] + pool.slice(0, 2)
	out.shuffle()
	return out
