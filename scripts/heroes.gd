class_name Heroes
## The heroes you can play. The Rogue is free; the others are unlocked with coins on the
## title screen. To add one: copy an entry in LIST (the KayKit model name goes in "key",
## and "hide" lists the extra weapons in that model you don't want shown). "ring" is the
## hero's own colour: the ring at their feet and the glow around their edges.

const LIST := [
	{"id": "rogue", "title": "Rogue", "text": "Quick crossbow bolts. A good all-rounder.", "cost": 0,
		"key": "Rogue_Hooded", "hide": ["Knife", "Knife_Offhand", "2H_Crossbow", "Throwable"], "attack_anim": "1H_Ranged_Shoot",
		"body": Color(0.25, 0.45, 0.78), "hood": true, "ring": Color(0.3, 0.6, 1.0),
		"health": 100.0, "move_speed": 5.2, "damage": 12.0, "rate": 1.8, "bolt_speed": 17.0, "bolt_size": 0.22,
		"bolt_color": Color(0.55, 0.85, 1.0),
		"special": "Shadow Volley", "special_text": "Three rings of bolts in every direction."},
	{"id": "knight", "title": "Knight", "text": "Tough and armoured. Slow sword waves cut through enemies.", "cost": 100,
		"key": "Knight", "hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"],
		"attack_anim": "1H_Melee_Attack_Slice_Horizontal", "body": Color(0.6, 0.62, 0.7), "helmet": true, "ring": Color(1.0, 0.85, 0.35),
		"health": 150.0, "move_speed": 4.7, "damage": 22.0, "rate": 1.0, "bolt_speed": 13.0, "bolt_size": 0.4,
		"bolt_color": Color(1.0, 0.95, 0.75), "pierce": 1, "armor": 0.15,
		"special": "Shield Slam", "special_text": "A huge shockwave that stuns and shoves everything nearby."},
	{"id": "barbarian", "title": "Barbarian", "text": "Hurls heavy axes and heals a little with every kill.", "cost": 200,
		"key": "Barbarian", "hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "2H_Axe", "Mug"], "attack_anim": "Throw",
		"body": Color(0.7, 0.45, 0.3), "horns": true, "ring": Color(0.35, 1.0, 0.5),
		"health": 120.0, "move_speed": 5.0, "damage": 16.0, "rate": 1.4, "bolt_speed": 15.0, "bolt_size": 0.3,
		"bolt_color": Color(1.0, 0.7, 0.4), "push": 9.0, "heal_on_kill": 2.0,
		"special": "Whirlwind", "special_text": "Spin with your axes, shredding and healing as you go."},
	{"id": "mage", "title": "Mage", "text": "Fragile, but magic orbs explode and hit whole groups.", "cost": 300,
		"key": "Mage", "hide": ["Spellbook", "Spellbook_open", "1H_Wand"], "attack_anim": "Spellcast_Shoot",
		"body": Color(0.45, 0.3, 0.75), "hat": true, "ring": Color(0.8, 0.5, 1.0),
		"health": 80.0, "move_speed": 5.4, "damage": 11.0, "rate": 1.7, "bolt_speed": 14.0, "bolt_size": 0.3,
		"bolt_color": Color(0.8, 0.45, 1.0), "splash": 1.8,
		"special": "Meteor", "special_text": "Burning rocks crash onto the five nearest skeletons."},
]

const SAVE_SECTION := "heroes"


## How a hero looks (CharacterVisual.build), in a run and on the Heroes screen.
static func look(def: Dictionary) -> Dictionary:
	var l := {"key": def.key, "height": 2.1, "body": def.body, "accent": Color(0.85, 0.75, 0.5), "eyes": Color(0.6, 0.9, 1.0),
		"hide": def.hide, "attack_anim": def.attack_anim, "rim": Color(def.ring, 0.9)}
	for extra in ["hood", "helmet", "hat", "horns"]:
		if def.has(extra):
			l[extra] = def[extra]
	return l


static func get_hero(id: String) -> Dictionary:
	for h: Dictionary in LIST:
		if h.id == id:
			return h
	return LIST[0]


## Bought with coins, or every hero with the Crypt Pass.
static func unlocked(cfg: ConfigFile, id: String) -> bool:
	return get_hero(id).cost == 0 or Store.owned(cfg) or bool(cfg.get_value(SAVE_SECTION, id, false))


static func selected(cfg: ConfigFile) -> String:
	var id := str(cfg.get_value(SAVE_SECTION, "selected", "rogue"))
	return id if unlocked(cfg, id) else "rogue"
