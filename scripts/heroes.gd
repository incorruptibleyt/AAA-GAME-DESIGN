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
		"special": "Shadow Volley", "special_text": "Three rings of bolts in every direction.",
		# Version 129: names and personality. "about" sits under the name; "pick" lines are
		# said on the Heroes screen, "hello" at the start of a run, "win" over a beaten boss.
		"name": "Wren", "about": "Quick, cheeky and never quiet for long.", "voice": 1.32,
		"pick": ["Quick hands, quicker feet.", "They won't even hear me coming.", "Bones? I'll take the noisy ones."],
		"hello": ["Stay sharp, stay quiet.", "In and out. Easy.", "Let's see what's down here."],
		"win": ["Too easy. Next!", "Didn't even break a sweat.", "Who's counting? Me. I'm counting."],
		"emote": ["Jump_Full_Short", "1H_Ranged_Reload"]},
	{"id": "knight", "title": "Knight", "text": "Tough and armored. Slow sword waves cut through enemies.", "cost": 100,
		"key": "Knight", "hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"],
		"attack_anim": "1H_Melee_Attack_Slice_Horizontal", "body": Color(0.6, 0.62, 0.7), "helmet": true, "ring": Color(1.0, 0.85, 0.35),
		"health": 150.0, "move_speed": 4.7, "damage": 22.0, "rate": 1.0, "bolt_speed": 13.0, "bolt_size": 0.4,
		"bolt_color": Color(1.0, 0.86, 0.5), "pierce": 1, "armor": 0.15,
		"special": "Shield Slam", "special_text": "A huge shockwave that slows and shoves everything nearby.",
		"name": "Sir Bram", "about": "Steady, kind, and a little old-fashioned.", "voice": 0.86,
		"pick": ["Shield up. I've got you.", "No skeleton gets past me.", "For the living!"],
		"hello": ["Stay behind my shield.", "Steady now. Forward!", "On my honour, we'll clear it."],
		"win": ["Duty done. Onward!", "A fair fight, fairly won.", "Rest now, old bones."],
		"emote": ["Block", "Cheer"]},
	{"id": "barbarian", "title": "Barbarian", "text": "Hurls heavy axes and heals a little with every kill.", "cost": 200,
		"key": "Barbarian", "hide": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "2H_Axe", "Mug"], "attack_anim": "Throw",
		"body": Color(0.7, 0.45, 0.3), "horns": true, "ring": Color(0.35, 1.0, 0.5),
		"health": 120.0, "move_speed": 5.0, "damage": 16.0, "rate": 1.4, "bolt_speed": 15.0, "bolt_size": 0.3,
		"bolt_color": Color(1.0, 0.7, 0.4), "push": 9.0, "heal_on_kill": 2.0,
		"special": "Whirlwind", "special_text": "Spin with your axes, shredding and healing as you go.",
		"name": "Bjorn", "about": "Loud, happy, and always hungry for a fight.", "voice": 0.72,
		"pick": ["MORE SKELETONS! MORE!", "I'll crack every bone in here!", "Axes ready. Belly full. GO!"],
		"hello": ["Come out, bones! Bjorn is here!", "Smells like a fight. Good!", "Last one down is a skeleton!"],
		"win": ["HA! Who's next?!", "That one was crunchy!", "Bring me a bigger one!"],
		"emote": ["2H_Melee_Attack_Spin", "Cheer"]},
	{"id": "mage", "title": "Mage", "text": "Fragile, but magic orbs explode and hit whole groups.", "cost": 300,
		"key": "Mage", "hide": ["Spellbook", "Spellbook_open", "1H_Wand"], "attack_anim": "Spellcast_Shoot",
		"body": Color(0.45, 0.3, 0.75), "hat": true, "ring": Color(0.8, 0.5, 1.0),
		"health": 80.0, "move_speed": 5.4, "damage": 11.0, "rate": 1.7, "bolt_speed": 14.0, "bolt_size": 0.3,
		"bolt_color": Color(0.8, 0.45, 1.0), "splash": 1.8,
		"special": "Meteor", "special_text": "Burning rocks crash onto the five nearest skeletons.",
		"name": "Quill", "about": "Clever, curious, and a bit of a show-off.", "voice": 1.12,
		"pick": ["Bones are just puzzles that walk.", "Stand back. This gets bright.", "This crypt? Badly written."],
		"hello": ["Let's make this interesting.", "Mind the sparks.", "Fascinating. And smelly."],
		"win": ["As calculated.", "Was that the boss? Huh.", "Write that one down!"],
		"emote": ["Spellcast_Raise", "Spellcast_Long"]},
]

const SAVE_SECTION := "heroes"


## How a hero looks (CharacterVisual.build), in a run and on the Heroes screen.
## `stage`: drawn big on a pedestal or a reveal. Only there do Feat, Bone Drop and Pass glows
## shine at full strength; in a run (and on the title) they stay soft, so the hero's face and
## facing still read (version 121: the strong rim turned the hero into a yellow ball in fights).
static func look(def: Dictionary, stage := false) -> Dictionary:
	var l := {"key": def.key, "height": 2.1, "body": def.body, "accent": Color(0.85, 0.75, 0.5), "eyes": Color(0.6, 0.9, 1.0),
		"hide": def.hide, "attack_anim": def.attack_anim, "rim": Color(def.ring, 0.9)}
	if def.get("rim_strong", false):
		if stage:
			l.rim = Color(def.ring.r * 1.6, def.ring.g * 1.6, def.ring.b * 1.6, 1.0)
			l.rim_power = 1.4
		else:
			l.rim = Color(def.ring, 0.4)
			l.rim_power = 3.0
	elif def.get("rim_legend", false):
		l.rim = Color(def.ring.r * 1.2, def.ring.g * 1.2, def.ring.b * 1.2, 1.0) if stage else Color(def.ring, 0.9)
		l.rim_power = 2.2 if stage else 2.4
	if def.has("ring2"):
		var k: float = l.rim.r / maxf(0.001, def.ring.r) if def.ring.r > 0.01 else 1.0
		l.rim2 = Color(def.ring2.r * k, def.ring2.g * k, def.ring2.b * k, l.rim.a)
	for extra in ["hood", "helmet", "hat", "horns", "style", "aura"]:
		if def.has(extra):
			l[extra] = def[extra]
	return l


static func get_hero(id: String) -> Dictionary:
	for h: Dictionary in LIST:
		if h.id == id:
			return h
	return LIST[0]


## One of a hero's lines ("pick", "hello" or "win"), never the same one twice in a row.
static var _last_line := {}

static func line(def: Dictionary, kind: String) -> String:
	var lines: Array = get_hero(str(def.get("id", "rogue"))).get(kind, [])
	if lines.is_empty():
		return ""
	var key: String = str(def.get("id", "")) + "/" + kind
	var pick: String = lines.pick_random()
	if lines.size() > 1:
		while pick == _last_line.get(key, ""):
			pick = lines.pick_random()
	_last_line[key] = pick
	return pick


## The name a hero goes by, and the name with the class ("Wren the Rogue").
static func hero_name(def: Dictionary) -> String:
	return str(get_hero(str(def.get("id", "rogue"))).get("name", def.get("title", "")))


static func full_name(def: Dictionary) -> String:
	var h := get_hero(str(def.get("id", "rogue")))
	return "%s the %s" % [h.get("name", h.title), h.title]


## Bought with coins, or every hero with the Crypt Pass.
static func unlocked(cfg: ConfigFile, id: String) -> bool:
	return get_hero(id).cost == 0 or Store.owned(cfg) or bool(cfg.get_value(SAVE_SECTION, id, false))


static func selected(cfg: ConfigFile) -> String:
	var id := str(cfg.get_value(SAVE_SECTION, "selected", "rogue"))
	return id if unlocked(cfg, id) else "rogue"
