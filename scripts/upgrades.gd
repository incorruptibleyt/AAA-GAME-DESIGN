class_name Upgrades
## The blessing cards offered after each cleared room. To add one, copy an entry in LIST,
## give it a new id, and say what it changes in `apply` below.

const LIST := [
	{"id": "damage", "title": "Sharpened Bolts", "text": "+30% damage", "color": Color(0.95, 0.35, 0.3), "max": 99},
	{"id": "speed", "title": "Quick Draw", "text": "+25% attack speed", "color": Color(1.0, 0.75, 0.25), "max": 99},
	{"id": "multishot", "title": "Twin Bolts", "text": "+1 bolt forward", "color": Color(0.4, 0.75, 1.0), "max": 3},
	{"id": "diagonal", "title": "Fan of Bolts", "text": "+2 bolts at an angle", "color": Color(0.35, 0.6, 1.0), "max": 2},
	{"id": "rear", "title": "Eyes in the Back", "text": "+1 bolt backward", "color": Color(0.6, 0.6, 1.0), "max": 1},
	{"id": "pierce", "title": "Piercing Shot", "text": "Bolts pass through 1 more enemy", "color": Color(0.75, 0.9, 1.0), "max": 2},
	{"id": "crit", "title": "Keen Eye", "text": "+15% critical hit chance", "color": Color(1.0, 0.9, 0.3), "max": 3},
	{"id": "fire", "title": "Fire Bolts", "text": "Hits set enemies on fire", "color": Color(1.0, 0.5, 0.15), "max": 2},
	{"id": "vitality", "title": "Vitality", "text": "+30 max health and heal 30", "color": Color(0.4, 0.95, 0.5), "max": 99},
	{"id": "harvest", "title": "Bone Harvest", "text": "Heal 4 health per kill", "color": Color(0.6, 1.0, 0.6), "max": 3},
	{"id": "boots", "title": "Swift Boots", "text": "+12% move speed", "color": Color(0.6, 0.9, 0.8), "max": 3},
]


static func apply(id: String, h: Hero) -> void:
	match id:
		"damage": h.damage *= 1.3
		"speed": h.shots_per_second *= 1.25
		"multishot":
			h.front_bolts += 1
			h.damage *= 0.9
		"diagonal": h.diagonal_bolts += 1
		"rear": h.rear_bolts += 1
		"pierce": h.pierce += 1
		"crit": h.crit_chance += 0.15
		"fire": h.burn_dps += 8.0
		"vitality":
			h.max_health += 30.0
			h.heal(30.0)
		"harvest": h.heal_on_kill += 4.0
		"boots": h.move_speed *= 1.12


## Pick up to three different blessings the hero can still take.
static func roll(taken: Dictionary, count := 3) -> Array:
	var pool := []
	for u in LIST:
		if taken.get(u.id, 0) < u.max:
			pool.append(u)
	pool.shuffle()
	return pool.slice(0, count)
