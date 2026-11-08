class_name HeroStyle
## Hero looks: how a hero is dressed. Each hero has five slots (outfit, head, weapon, glow,
## and a Master aura only that hero has),
## and a look for each slot is picked on the Style screen from the ones Hero Mastery has
## unlocked (hero_mastery.gd). Looks never change how a hero plays.
##
## The KayKit heroes are painted from one small texture of colour swatches, so an outfit is
## a recolour of the pixels of the hero's cloth (channel "a") and trim or armour ("b") with a
## shader. Hats, helmets, capes and weapons can be hidden, and borrowed from another hero's
## model (they share one skeleton), and a crown, horns or a halo can be added.

const SECTION := "hero_style"
const SLOTS := ["outfit", "head", "hold", "glow", "aura"]

## Which pixels of each hero's texture are their cloth ("a") and their trim or armour ("b"):
## [hue, hue width (1 = any hue), lowest saturation, highest saturation, the saturation and
## brightness the new colour is matched to, and the lowest brightness (the Knight's dark
## visor stays dark)]. Measured from the KayKit textures.
const CHANNELS := {
	"rogue": {"a": [0.60, 0.05, 0.6, 1.1, 1.0, 0.55], "b": [0.045, 0.025, 0.47, 0.72, 0.6, 0.62]},
	"knight": {"a": [0.995, 0.04, 0.45, 1.1, 0.7, 0.85], "b": [0.0, 1.0, 0.0, 0.17, 0.1, 0.55, 0.36]},
	"barbarian": {"a": [0.07, 0.04, 0.13, 0.3, 0.2, 0.42], "b": [0.57, 0.04, 0.28, 0.55, 0.4, 0.5]},
	"mage": {"a": [0.68, 0.05, 0.22, 0.7, 0.4, 0.5], "b": [0.92, 0.04, 0.6, 1.1, 0.85, 0.65]},
}
## The meshes of each model that take the outfit colours (not the weapons).
const PREFIX := {"rogue": "Rogue_", "knight": "Knight_", "barbarian": "Barbarian_", "mage": "Mage_"}
## Each hero's own hat or helmet.
const OWN_HAT := {"knight": "Knight_Helmet", "barbarian": "Barbarian_Hat", "mage": "Mage_Hat"}

## The top of each hero's head, in the head bone's space (where a crown sits).
const HEAD_TOP := {"rogue": 0.74, "knight": 0.86, "barbarian": 0.74, "mage": 0.72}

# ---------------------------------------------------------------- the looks

## Outfit colours: the cloth ("a"), the trim ("b": the Mage's cape lining and collar, the
## Barbarian's shirt), the Knight's armour and the Rogue's leather. null = as painted.
const OUTFITS := {
	"crimson": {"name": "Crimson", "a": Color(0.42, 0.05, 0.12), "b": Color(1.0, 0.78, 0.3), "leather": Color(0.24, 0.17, 0.14)},
	"forest": {"name": "Forest", "a": Color(0.16, 0.46, 0.2), "b": Color(0.85, 0.7, 0.3), "armor": Color(0.28, 0.54, 0.26), "leather": Color(0.5, 0.33, 0.18)},
	"midnight": {"name": "Midnight", "a": Color(0.11, 0.13, 0.32), "b": Color(0.82, 0.86, 0.95), "armor": Color(0.2, 0.26, 0.62)},
	"ivory": {"name": "Ivory", "a": Color(0.94, 0.91, 0.83), "b": Color(0.35, 0.6, 0.95), "armor": Color(0.88, 0.88, 0.86), "leather": Color(0.62, 0.45, 0.3)},
	"shadow": {"name": "Shadow", "a": Color(0.14, 0.12, 0.17), "b": Color(0.6, 0.25, 0.9), "armor": Color(0.2, 0.19, 0.23), "leather": Color(0.16, 0.14, 0.16)},
	"royal": {"name": "Royal", "a": Color(0.44, 0.17, 0.7), "b": Color(1.0, 0.78, 0.3), "armor": Color(0.55, 0.3, 0.85)},
	"ember": {"name": "Ember", "a": Color(0.95, 0.45, 0.12), "b": Color(0.28, 0.16, 0.12), "armor": Color(0.88, 0.48, 0.22)},
	"frost": {"name": "Frost", "a": Color(0.55, 0.85, 1.0), "b": Color(0.95, 0.97, 1.0), "armor": Color(0.6, 0.88, 1.0)},
	"rose": {"name": "Rose", "a": Color(0.96, 0.68, 0.8), "b": Color(1.0, 0.9, 0.94), "leather": Color(0.55, 0.32, 0.36)},
	"sea": {"name": "Sea", "a": Color(0.1, 0.55, 0.6), "b": Color(1.0, 0.78, 0.3), "armor": Color(0.2, 0.66, 0.68)},
	"gold": {"name": "Gilded", "a": Color(0.95, 0.75, 0.25), "b": Color(1.0, 0.97, 0.9), "armor": Color(0.95, 0.76, 0.3), "leather": Color(0.45, 0.3, 0.16)},
	"bone": {"name": "Bone", "a": Color(0.86, 0.83, 0.74), "b": Color(0.2, 0.2, 0.23), "armor": Color(0.84, 0.8, 0.68), "leather": Color(0.2, 0.19, 0.2)},
}

## Each hero's own colours, for the Classic outfit's swatch on the Style screen.
const CLASSIC_OUTFIT := {"rogue": Color(0.2, 0.4, 0.85), "knight": Color(0.85, 0.2, 0.25), "barbarian": Color(0.45, 0.36, 0.28), "mage": Color(0.45, 0.4, 0.7)}
const CLASSIC_TRIM := {"rogue": Color(0.6, 0.38, 0.25), "knight": Color(0.7, 0.72, 0.78), "barbarian": Color(0.4, 0.55, 0.65), "mage": Color(0.7, 0.15, 0.5)}

## Head looks. hat: keep the hero's own hat or helmet; borrow: wear another hero's;
## extras: a crown, horns or a halo.
const HEADS := {
	"bare": {"name": "Bare head", "hat": false},
	"crown": {"name": "Crown", "hat": true, "extras": ["crown"]},
	"halo": {"name": "Halo", "hat": true, "extras": ["halo"]},
	"horns": {"name": "Horns", "hat": false, "extras": ["horns"]},
	"horned_hat": {"name": "Horned hat", "hat": true, "extras": ["horns"]},
	"wizard": {"name": "Wizard hat", "hat": false, "borrow": ["Mage", "Mage_Hat"]},
	"helm": {"name": "Knight helm", "hat": false, "borrow": ["Knight", "Knight_Helmet"]},
	"bear": {"name": "Bear hat", "hat": false, "borrow": ["Barbarian", "Barbarian_Hat"]},
	# The Mage's own: a deep hood with only shadow and glowing eyes inside (mage_hood.gd).
	"shadow_hood": {"name": "Shadow Hood", "hat": false, "hide": ["Mage_Head"], "extras": ["mage_hood"]},
}

## What each hero holds (parts of their own model: hide, show).
const HOLDS := {
	"rogue": {
		"heavy": {"name": "Heavy crossbow", "hide": ["1H_Crossbow"], "show": ["2H_Crossbow"]},
		"knife": {"name": "Crossbow and knife", "show": ["Knife_Offhand"]},
		"twin_knives": {"name": "Twin knives", "hide": ["1H_Crossbow"], "show": ["Knife", "Knife_Offhand"]},
	},
	"knight": {
		"badge": {"name": "Crest shield", "hide": ["Round_Shield"], "show": ["Badge_Shield"]},
		"spike": {"name": "Spiked shield", "hide": ["Round_Shield"], "show": ["Spike_Shield"]},
		"tower": {"name": "Tower shield", "hide": ["Round_Shield"], "show": ["Rectangle_Shield"]},
		"greatsword": {"name": "Greatsword", "hide": ["1H_Sword", "Round_Shield"], "show": ["2H_Sword"]},
		"twin_swords": {"name": "Twin swords", "hide": ["Round_Shield"], "show": ["1H_Sword_Offhand"]},
	},
	"barbarian": {
		"twin_axes": {"name": "Twin axes", "show": ["1H_Axe_Offhand"]},
		"axe_shield": {"name": "Axe and shield", "show": ["Barbarian_Round_Shield"]},
		"great_axe": {"name": "Great axe", "hide": ["1H_Axe"], "show": ["2H_Axe"]},
		"tankard": {"name": "Axe and tankard", "show": ["Mug"]},
	},
	"mage": {
		"wand": {"name": "Wand", "hide": ["2H_Staff"], "show": ["1H_Wand"]},
		"tome": {"name": "Wand and tome", "hide": ["2H_Staff"], "show": ["1H_Wand", "Spellbook"]},
		"open_tome": {"name": "Open spellbook", "hide": ["2H_Staff"], "show": ["1H_Wand", "Spellbook_open"]},
	},
}

## Glow: the ring at the hero's feet, the glow on their edges and their shots. None is
## red-pink, which is what danger looks like (ShotLook.DANGER).
const GLOWS := {
	"emerald": {"name": "Emerald", "ring": Color(0.3, 1.0, 0.55), "bolt": Color(0.55, 1.0, 0.7)},
	"azure": {"name": "Azure", "ring": Color(0.4, 0.68, 1.0), "bolt": Color(0.62, 0.84, 1.0)},
	"ember": {"name": "Ember", "ring": Color(1.0, 0.52, 0.16), "bolt": Color(1.0, 0.68, 0.28)},
	"frost": {"name": "Frost", "ring": Color(0.4, 0.94, 1.0), "bolt": Color(0.62, 1.0, 1.0)},
	"gold": {"name": "Gold", "ring": Color(1.0, 0.82, 0.3), "bolt": Color(1.0, 0.9, 0.55)},
	"violet": {"name": "Violet", "ring": Color(0.72, 0.45, 1.0), "bolt": Color(0.84, 0.66, 1.0)},
	"silver": {"name": "Silver", "ring": Color(0.86, 0.9, 1.0), "bolt": Color(1.0, 1.0, 1.0)},
	"lime": {"name": "Lime", "ring": Color(0.72, 1.0, 0.3), "bolt": Color(0.86, 1.0, 0.55)},
}

## Master auras: looks only one hero has, one at each of Mastery levels 8, 9 and 10. An aura
## colours the hero's outline (ink; ink2 makes it pulse between two colours, cycle runs it
## through the colours of the rainbow, skipping red-pink), the dash ring and dash trail, and
## gives the hero their own trail of light (MOTIFS): the Rogue's shadow wisps, the Knight's
## rising motes, the Barbarian's embers, the Mage's stars. All of it reads from the top-down
## camera, where hats and outfits are small.
const AURAS := {
	"rogue": {
		"nightshade": {"name": "Nightshade", "level": 8, "ink": Color(0.66, 0.32, 1.0), "spark": Color(0.78, 0.52, 1.0)},
		"venom": {"name": "Venom", "level": 9, "ink": Color(0.42, 1.0, 0.22), "spark": Color(0.66, 1.0, 0.36)},
		"shadow_king": {"name": "Shadow King", "level": 10, "ink": Color(1.0, 0.76, 0.22), "ink2": Color(0.58, 0.24, 1.0), "spark": Color(1.0, 0.84, 0.4)},
	},
	"knight": {
		"sunguard": {"name": "Sunguard", "level": 8, "ink": Color(1.0, 0.64, 0.16), "spark": Color(1.0, 0.8, 0.4)},
		"stormplate": {"name": "Stormplate", "level": 9, "ink": Color(0.3, 0.64, 1.0), "spark": Color(0.72, 0.88, 1.0)},
		"paladin": {"name": "Paladin", "level": 10, "ink": Color(1.0, 0.97, 0.86), "ink2": Color(1.0, 0.72, 0.2), "spark": Color(1.0, 0.86, 0.45)},
	},
	"barbarian": {
		"wildfire": {"name": "Wildfire", "level": 8, "ink": Color(1.0, 0.46, 0.08), "spark": Color(1.0, 0.62, 0.22)},
		"thunder": {"name": "Thunder", "level": 9, "ink": Color(1.0, 0.94, 0.25), "spark": Color(1.0, 1.0, 0.62)},
		"warlord": {"name": "Warlord", "level": 10, "ink": Color(1.0, 0.42, 0.06), "ink2": Color(0.35, 0.85, 1.0), "spark": Color(1.0, 0.72, 0.3)},
	},
	"mage": {
		"starfire": {"name": "Starfire", "level": 8, "ink": Color(0.48, 0.5, 1.0), "spark": Color(0.72, 0.76, 1.0)},
		"arcane_frost": {"name": "Arcane Frost", "level": 9, "ink": Color(0.4, 0.95, 1.0), "spark": Color(0.82, 1.0, 1.0)},
		"archmage": {"name": "Archmage", "level": 10, "ink": Color(0.7, 0.45, 1.0), "cycle": true, "spark": Color(0.82, 0.7, 1.0)},
	},
}
## Each hero's own trail of light for their auras (Fx.motif).
const MOTIFS := {"rogue": "wisps", "knight": "motes", "barbarian": "embers", "mage": "stars"}

## The Crypt King set: four looks every hero gets with the Crypt Pass, one for each of the
## outfit, head, glow and aura slots, the grandest in the game. Free players can try them on
## (the Style screen shows them first, on every tab). Their keys start with "crypt".
## The outfit is obsidian black veined with glowing molten gold, trimmed in polished gold,
## and a band of light runs up the hero every couple of seconds. It is the opposite of the
## all-gold Gilded outfit (Mastery 10), so the two are never mistaken for each other: the
## big part of each hero is obsidian (the Rogue's and Mage's cloth, the Knight's armour,
## the Barbarian's furs) and the trim is gold.
const PASS_KEY := "crypt"
const PASS_OUTFIT := {"name": "Crypt Gold", "pass": true,
	"gold": Color(1.0, 0.77, 0.26), "obsidian": Color(0.1, 0.075, 0.14),
	"gold_on": {"rogue": "b", "knight": "a", "barbarian": "b", "mage": "b"}}
const PASS_HEAD := {"name": "Crypt Crown", "hat": true, "extras": ["crypt_crown"], "pass": true}
const PASS_GLOW := {"name": "Crypt Gold", "ring": Color(1.0, 0.84, 0.38), "bolt": Color(1.0, 0.92, 0.6), "pass": true}
## The aura: a gold outline a white glint runs round, gold crowns of light rising, and a
## turning gold sigil on the floor under the hero, the one thing seen from anywhere in a room.
const PASS_AURA := {"name": "Crypt King", "pass": true, "ink": Color(1.0, 0.78, 0.22), "ink2": Color(1.0, 0.95, 0.72),
	"spark": Color(1.0, 0.86, 0.42), "motif": "regal", "shine": true, "sigil": true}

## The order each hero's looks are unlocked in: three for each Mastery level from 2 to 10
## (27 each), the grandest last. [slot, key].
const ORDER := {
	"rogue": [["outfit", "crimson"], ["glow", "emerald"], ["hold", "knife"],
		["outfit", "forest"], ["head", "horns"], ["glow", "ember"],
		["outfit", "midnight"], ["hold", "heavy"], ["glow", "violet"],
		["outfit", "shadow"], ["head", "wizard"], ["glow", "frost"],
		["outfit", "ivory"], ["hold", "twin_knives"], ["glow", "lime"],
		["outfit", "rose"], ["head", "bear"], ["glow", "silver"],
		["outfit", "sea"], ["outfit", "ember"], ["outfit", "bone"],
		["outfit", "royal"], ["head", "helm"], ["head", "halo"],
		["glow", "gold"], ["outfit", "gold"], ["head", "crown"]],
	"knight": [["outfit", "midnight"], ["glow", "azure"], ["hold", "badge"],
		["outfit", "forest"], ["head", "bare"], ["glow", "ember"],
		["outfit", "ivory"], ["hold", "tower"], ["glow", "emerald"],
		["outfit", "shadow"], ["head", "horned_hat"], ["glow", "frost"],
		["outfit", "royal"], ["hold", "spike"], ["glow", "violet"],
		["outfit", "sea"], ["head", "bear"], ["glow", "silver"],
		["outfit", "ember"], ["hold", "twin_swords"], ["head", "wizard"],
		["outfit", "frost"], ["hold", "greatsword"], ["glow", "lime"],
		["outfit", "gold"], ["head", "halo"], ["head", "crown"]],
	"barbarian": [["outfit", "crimson"], ["glow", "ember"], ["hold", "tankard"],
		["outfit", "forest"], ["head", "bare"], ["glow", "azure"],
		["outfit", "midnight"], ["hold", "twin_axes"], ["glow", "gold"],
		["outfit", "ivory"], ["head", "horned_hat"], ["glow", "frost"],
		["outfit", "shadow"], ["hold", "axe_shield"], ["glow", "violet"],
		["outfit", "sea"], ["head", "helm"], ["glow", "silver"],
		["outfit", "ember"], ["head", "wizard"], ["outfit", "royal"],
		["outfit", "frost"], ["hold", "great_axe"], ["glow", "lime"],
		["outfit", "gold"], ["head", "halo"], ["head", "crown"]],
	"mage": [["outfit", "crimson"], ["glow", "frost"], ["hold", "wand"],
		["outfit", "forest"], ["head", "bare"], ["glow", "emerald"],
		["outfit", "midnight"], ["head", "shadow_hood"], ["glow", "ember"],
		["outfit", "ivory"], ["head", "horned_hat"], ["glow", "gold"],
		["outfit", "shadow"], ["hold", "open_tome"], ["glow", "azure"],
		["outfit", "sea"], ["hold", "tome"], ["glow", "silver"],
		["outfit", "rose"], ["head", "horns"], ["head", "bear"],
		["outfit", "ember"], ["outfit", "frost"], ["glow", "lime"],
		["outfit", "gold"], ["head", "halo"], ["head", "crown"]],
}
const PER_LEVEL := 3


## Every look of hero `id`: [{slot, key, name, level}], the plain one of each slot (level 1)
## first.
static func items(id: String) -> Array:
	var out := []
	for slot: String in SLOTS:
		out.append({"slot": slot, "key": "", "name": item_name(id, slot, ""), "level": 1})
	var order: Array = ORDER.get(id, [])
	for i in order.size():
		var slot: String = order[i][0]
		var key: String = order[i][1]
		out.append({"slot": slot, "key": key, "name": item_name(id, slot, key), "level": 2 + i / PER_LEVEL})
	var auras: Dictionary = AURAS.get(id, {})
	for key: String in auras:
		out.append({"slot": "aura", "key": key, "name": auras[key].name, "level": int(auras[key].level), "only": true})
	for slot: String in PASS_SLOTS:
		out.append({"slot": slot, "key": pass_key(slot), "name": item_name(id, slot, pass_key(slot)), "level": 1, "pass": true})
	return out


## The slots the Crypt King set fills, and each look's key ("crypt", "crypt_crown"...).
const PASS_SLOTS := ["outfit", "head", "glow", "aura"]

static func pass_key(slot: String) -> String:
	return "crypt_crown" if slot == "head" else ("crypt_king" if slot == "aura" else PASS_KEY)


static func is_pass(key: String) -> bool:
	return key.begins_with(PASS_KEY)


## Whether hero `id` may wear `key` in `slot`: a Mastery look once its level is reached, a
## Crypt King look with the Crypt Pass.
static func has_look(cfg: ConfigFile, id: String, slot: String, key: String) -> bool:
	if key == "":
		return true
	if is_pass(key):
		return pass_key(slot) == key and Store.owned(cfg)
	return item_level(id, slot, key) <= HeroMastery.level(cfg, id)


## The looks hero `id` gets at Mastery level `lv`.
static func level_items(id: String, lv: int) -> Array:
	return items(id).filter(func(it: Dictionary) -> bool: return it.level == lv and it.key != "" and not it.get("pass", false))


static func item_name(id: String, slot: String, key: String) -> String:
	if key == "":
		return "No aura" if slot == "aura" else "Classic"
	if is_pass(key):
		return str({"outfit": PASS_OUTFIT, "head": PASS_HEAD, "glow": PASS_GLOW, "aura": PASS_AURA}.get(slot, {}).get("name", key))
	match slot:
		"outfit":
			return OUTFITS.get(key, {}).get("name", key)
		"head":
			return HEADS.get(key, {}).get("name", key)
		"hold":
			return HOLDS.get(id, {}).get(key, {}).get("name", key)
		"glow":
			return GLOWS.get(key, {}).get("name", key)
		"aura":
			return AURAS.get(id, {}).get(key, {}).get("name", key)
	return key


## "Crimson outfit", "Crown", "Ember glow".
static func item_label(id: String, slot: String, key: String) -> String:
	var n := item_name(id, slot, key)
	match slot:
		"outfit":
			return n + " outfit"
		"glow":
			return n + " glow"
		"aura":
			if is_pass(key):
				return n + " aura"
			return n if key == "" else n + " aura (%s only)" % str(Heroes.get_hero(id).title)
	return n


static func item_level(id: String, slot: String, key: String) -> int:
	if key == "" or is_pass(key):
		return 1
	for it: Dictionary in items(id):
		if it.slot == slot and it.key == key:
			return it.level
	return 99


# ---------------------------------------------------------------- what's worn

## The look hero `id` wears in `slot` ("" = Classic). A look that isn't unlocked (an edited
## save) is worn as Classic.
static func worn(cfg: ConfigFile, id: String, slot: String) -> String:
	var key := str(cfg.get_value(SECTION, "%s_%s" % [id, slot], ""))
	if not has_look(cfg, id, slot, key):
		return ""   # (a Crypt King look after a refund, too)
	return key


static func picks(cfg: ConfigFile, id: String) -> Dictionary:
	var out := {}
	for slot: String in SLOTS:
		out[slot] = worn(cfg, id, slot)
	return out


static func wear(cfg: ConfigFile, id: String, slot: String, key: String) -> void:
	cfg.set_value(SECTION, "%s_%s" % [id, slot], key)


## How many looks hero `id` has unlocked since the Style screen was last opened for them.
static func unseen(cfg: ConfigFile, id: String) -> int:
	var seen := int(cfg.get_value(SECTION, id + "_seen", 1))
	var lv := HeroMastery.level(cfg, id)
	var n := 0
	for l in range(seen + 1, lv + 1):
		n += level_items(id, l).size()
	# Auras came in version 102: a hero whose Style screen was last opened at level 8 or
	# more has auras at levels they had already seen.
	if not bool(cfg.get_value(SECTION, id + "_auras_seen", false)):
		for a: Dictionary in AURAS.get(id, {}).values():
			if int(a.level) <= mini(seen, lv):
				n += 1
	return n


static func mark_seen(cfg: ConfigFile, id: String) -> void:
	cfg.set_value(SECTION, id + "_seen", HeroMastery.level(cfg, id))
	cfg.set_value(SECTION, id + "_auras_seen", true)


## `def` (an entry of Heroes.LIST) as this player has dressed them.
static func styled(cfg: ConfigFile, def: Dictionary) -> Dictionary:
	return dressed(def, picks(cfg, def.id))


## `def` in the looks `p` ({slot: key}): its glow colours, and a "style" for the model.
static func dressed(def: Dictionary, p: Dictionary) -> Dictionary:
	var d := def.duplicate()
	var id: String = def.id
	var glow: Dictionary = PASS_GLOW if is_pass(p.get("glow", "")) else GLOWS.get(p.get("glow", ""), {})
	if not glow.is_empty():
		d.ring = glow.ring
		d.bolt_color = glow.bolt
	var style := {"id": id, "hide": [], "show": [], "borrow": [], "extras": []}
	var outfit: Dictionary = OUTFITS.get(p.get("outfit", ""), {})
	if is_pass(p.get("outfit", "")):
		var on: String = PASS_OUTFIT.gold_on.get(id, "a")
		style.outfit = {"a": PASS_OUTFIT.gold if on == "a" else PASS_OUTFIT.obsidian,
			"b": PASS_OUTFIT.gold if on == "b" else PASS_OUTFIT.obsidian, "gold": on}
	elif not outfit.is_empty():
		var b = outfit.get("b")
		if id == "knight":
			b = outfit.get("armor")
		elif id == "rogue":
			b = outfit.get("leather")
		style.outfit = {"a": outfit.a, "b": b}
	var head: Dictionary = PASS_HEAD if is_pass(p.get("head", "")) else HEADS.get(p.get("head", ""), {})
	var has_hat := OWN_HAT.has(id)
	if not head.is_empty():
		if not head.get("hat", true) and OWN_HAT.has(id):
			style.hide.append(OWN_HAT[id])
			has_hat = false
		if head.has("borrow"):
			style.borrow.append(head.borrow)
			has_hat = true
		style.extras = head.get("extras", [])
		style.hide.append_array(head.get("hide", []))
	style.hat = has_hat
	style.eye = d.get("ring", Color(0.6, 0.8, 1.0))
	# How far a halo floats over the hat: high over a wizard's hat, just over a helmet.
	var wizard: bool = (id == "mage" and head.get("hat", true)) or p.get("head", "") == "wizard"
	style.hat_h = 0.8 if wizard else 0.42
	var hold: Dictionary = HOLDS.get(id, {}).get(p.get("hold", ""), {})
	if not hold.is_empty():
		style.hide.append_array(hold.get("hide", []))
		style.show = hold.get("show", [])
	d.style = style
	var aura: Dictionary = PASS_AURA if is_pass(p.get("aura", "")) else AURAS.get(id, {}).get(p.get("aura", ""), {})
	if not aura.is_empty():
		d.aura = aura.duplicate()
		if not d.aura.has("motif"):
			d.aura.motif = MOTIFS.get(id, "wisps")
	return d


## An aura's outline colour right now (`t` in seconds), as the outline shader draws it: for
## the dash trail and the Style screen's swatch.
static func aura_ink(aura: Dictionary, t := 0.0) -> Color:
	var ink: Color = aura.get("ink", Color.WHITE)
	if aura.get("cycle", false):
		return Color.from_hsv(lerpf(0.12, 0.78, 0.5 + 0.5 * sin(t * 1.6)), 0.7, 1.0)
	if aura.has("ink2"):
		return ink.lerp(aura.ink2, 0.5 + 0.5 * sin(t * 3.0))
	return ink


static var _shaders := {}
static var _mats := {}


## Dresses a KayKit hero `model` (CharacterVisual) in `style`: {id, outfit: {a, b}, hide,
## show, borrow, extras, hat, hat_h} as made by dressed().
static func dress(model: Node3D, style: Dictionary) -> void:
	var id := str(style.get("id", ""))
	var skel := Art._find_skeleton(model)
	if skel == null or not CHANNELS.has(id):
		return
	# Parts shown, hidden, then borrowed.
	for part: String in style.get("show", []):
		var n := model.find_child(part, true, false) as Node3D
		if n:
			n.visible = true
	Art.hide_parts(model, style.get("hide", []))
	for part: Array in style.get("borrow", []):
		_borrow(skel, str(part[0]), str(part[1]), id)
	var outfit: Dictionary = style.get("outfit", {})
	if not outfit.is_empty():
		_recolour(skel, id, outfit)
	for extra: String in style.get("extras", []):
		_extra(skel, id, extra, bool(style.get("hat", false)), float(style.get("hat_h", 0.45)), style)


## A part (hat, cape, weapon) from another hero's model, worn on this skeleton on the same
## bone (in the models they hang from the head, chest and hand bones). A hat made for a
## smaller head grows to fit (the Knight's head is the biggest: his head would poke through).
static func _borrow(skel: Skeleton3D, model_key: String, part: String, id := "") -> void:
	var p := _part(model_key, part)
	if p.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = p.mesh
	mi.material_override = p.material
	mi.name = "Borrowed_" + part
	mi.transform = p.transform
	var grow := float(HEAD_TOP.get(id, 0.74)) / float(HEAD_TOP.get(model_key.to_lower(), 0.74))
	if p.bone == "head" and grow > 1.01:
		mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * grow), Vector3.ZERO) * mi.transform
	_attachment(skel, p.bone).add_child(mi)


static var _parts := {}


## A part of another hero's model: its mesh, where it sits and on which bone. Looked up once
## (making a whole hero just to find a hat each time a hero appears is slow on a phone).
static func _part(model_key: String, part: String) -> Dictionary:
	var key := model_key + "/" + part
	if not _parts.has(key):
		var found := {}
		var scene := Art.get_model(model_key)
		if scene:
			var other := scene.instantiate()
			var src := other.find_child(part, true, false) as MeshInstance3D
			var holder := src.get_parent() as BoneAttachment3D if src else null
			if src and holder and src.mesh:
				found = {"mesh": src.mesh, "transform": src.transform, "bone": str(holder.bone_name), "material": src.material_override}
			other.free()
		_parts[key] = found
	return _parts[key]


## The bone attachment for `bone` (the model's own, or a new one).
static func _attachment(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	for c in skel.get_children():
		if c is BoneAttachment3D and (c as BoneAttachment3D).bone_name == bone:
			return c
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = bone
	return att


static func _recolour(n: Node, id: String, outfit: Dictionary) -> void:
	var mi := n as MeshInstance3D
	if mi and str(mi.name).begins_with(PREFIX[id]) and mi.mesh:
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if src and src.albedo_texture:
			# (The trim colour stays off the Rogue's face, where it's the colour of skin in shadow,
			# and the Barbarian's fur colours off his beard.)
			var o := outfit
			if str(mi.name).contains("Head") and id == "rogue":
				o = {"a": outfit.get("a"), "b": null}
			if str(mi.name).contains("Head") and id == "barbarian":
				o = {}
			if not o.is_empty():
				mi.material_override = _material(id, o, src)
	for c in n.get_children():
		_recolour(c, id, outfit)


## One material per hero and outfit, shared by every copy of that hero.
static func _material(id: String, outfit: Dictionary, src: BaseMaterial3D) -> ShaderMaterial:
	# Capes are single sheets drawn from both sides: the copy must be too, or they vanish.
	var both := src.cull_mode == BaseMaterial3D.CULL_DISABLED
	var key := "%s %s %s %s %s" % [id, outfit.get("a", null), outfit.get("b", null), both, outfit.get("gold", "")]
	if _mats.has(key):
		return _mats[key]
	if not _shaders.has(both):
		var sh := Shader.new()
		sh.code = SHADER.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;" if both else "shader_type spatial;")
		_shaders[both] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[both]
	m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("rough", src.roughness)
	m.set_shader_parameter("metal", src.metallic)
	var ch: Dictionary = CHANNELS[id]
	for k in ["a", "b"]:
		var on: bool = outfit.get(k) != null
		var c: Array = ch[k]
		m.set_shader_parameter(k + "_src", Vector4(c[0], c[1], c[2], c[3]))
		m.set_shader_parameter(k + "_ref", Vector3(c[4], c[5], c[6] if c.size() > 6 else 0.0))
		var col: Color = outfit.get(k) if on else Color.BLACK
		m.set_shader_parameter(k + "_dst", Vector4(col.h, col.s, col.v, 1.0 if on else 0.0))
		m.set_shader_parameter(k + "_gold", 1.0 if outfit.get("gold", "") == k else 0.0)
		m.set_shader_parameter(k + "_dark", 1.0 if outfit.has("gold") and outfit.get("gold", "") != k else 0.0)
	_mats[key] = m
	return m


## A crown, horns or a halo on the hero's head.
static func _extra(skel: Skeleton3D, id: String, kind: String, hat: bool, hat_h := 0.45, style := {}) -> void:
	if skel.find_bone("head") < 0:
		return
	var att := _attachment(skel, "head")
	var y: float = HEAD_TOP.get(id, 0.74)
	match kind:
		"crown":
			_crown(att, id, y, hat)
		"crypt_crown":
			att.add_child(CryptCrown.make(id, y, hat))
		"mage_hood":
			var o: Dictionary = style.get("outfit", {})
			var cloth: Color = o.get("a", CLASSIC_OUTFIT.get(id, Color(0.45, 0.4, 0.7)))
			var trim: Color = o.get("b", Color(0.95, 0.62, 0.28))
			if o.get("gold", "") != "":   # the Crypt King outfit: obsidian hood, gold trim
				cloth = PASS_OUTFIT.obsidian
				trim = PASS_OUTFIT.gold
			att.add_child(MageHood.make(cloth, trim, style.get("eye", Color(0.6, 0.8, 1.0))))
		"horns":
			var bone := U.mat(Color(0.9, 0.86, 0.76), 0.6)
			var k := 1.0   # size
			if hat and id != "rogue":
				y += 0.12   # on a helmet or hat
			if hat and id == "mage":
				k = 1.7   # bigger and higher, so they clear the wide brim when seen from above
				y += 0.14
			for side in [-1, 1]:
				var horn := U.capsule(att, 0.07 * k, 0.5 * k, bone, Vector3(side * 0.42 * k, y - 0.3 * k, 0))
				horn.rotation.z = side * -0.9
				var tip := U.capsule(att, 0.05 * k, 0.3 * k, bone, Vector3(side * 0.62 * k, y - 0.06 * k, 0))
				tip.rotation.z = side * -0.25
		"halo":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.5
			var ring := MeshInstance3D.new()
			ring.mesh = torus
			ring.material_override = U.unlit(Color(1.0, 0.85, 0.4) * 1.6)
			ring.position = Vector3(0, y + (hat_h if hat else 0.2), 0)
			ring.scale = Vector3(1, 0.5, 1)
			att.add_child(ring)


## The Master's crown (level 10), like the one on the app icon: a flared gold band set with
## gems, five points with ball tips and a soft glow, worn over the hero's own hat or helmet
## (around the Mage's hat, just above the brim).
static func _crown(att: Node3D, id: String, y: float, hat: bool) -> void:
	var r := 0.5
	var base := y - 0.08
	if hat:
		match id:
			"knight":
				base = y + 0.02
				r = 0.56
			"barbarian":
				base = y + 0.06
				r = 0.56
			"mage":
				base = y + 0.16
				r = 0.4
	var gold := U.mat(Color(1.0, 0.78, 0.28), 0.25, 0.55)
	gold.metallic = 0.6
	var band := CylinderMesh.new()
	band.top_radius = r * 1.1
	band.bottom_radius = r
	band.height = 0.2
	band.radial_segments = 20
	var bm := MeshInstance3D.new()
	bm.mesh = band
	bm.material_override = gold
	bm.position = Vector3(0, base + 0.1, 0)
	att.add_child(bm)
	var gems := [U.mat(Color(0.95, 0.12, 0.3), 0.2, 1.6), U.mat(Color(0.25, 0.55, 1.0), 0.2, 1.6)]
	for i in 5:
		var a := i / 5.0 * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var point := CylinderMesh.new()
		point.top_radius = 0.0
		point.bottom_radius = 0.1
		point.height = 0.34
		point.radial_segments = 8
		var pm := MeshInstance3D.new()
		pm.mesh = point
		pm.material_override = gold
		pm.position = Vector3(0, base + 0.36, 0) + dir * r * 1.12
		pm.rotation = Vector3(0.22 * dir.z, 0, -0.22 * dir.x)   # leaning out a little
		att.add_child(pm)
		U.sphere(att, 0.065, gold, Vector3(0, base + 0.55, 0) + dir * r * 1.22)
		var b := i / 5.0 * TAU + TAU / 10.0
		U.sphere(att, 0.06, gems[i % 2], Vector3(0, base + 0.1, 0) + Vector3(sin(b), 0, cos(b)) * r * 1.07)


const SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float rough = 0.8;
uniform float metal = 0.0;
uniform vec4 a_src;
uniform vec3 a_ref;
uniform vec4 a_dst;
uniform vec4 b_src;
uniform vec3 b_ref;
uniform vec4 b_dst;
// The Crypt King outfit: which channel is polished gold, and which obsidian.
uniform float a_gold = 0.0;
uniform float b_gold = 0.0;
uniform float a_dark = 0.0;
uniform float b_dark = 0.0;
varying vec3 wpos;
varying vec3 opos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = NODE_POSITION_WORLD;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 swap(vec3 col, vec3 hsv, vec4 src, vec3 ref, vec4 dst, inout float mask) {
	if (dst.w < 0.5) {
		return col;
	}
	float m = smoothstep(src.z - 0.05, src.z, hsv.y) * (1.0 - smoothstep(src.w, src.w + 0.05, hsv.y));
	m *= smoothstep(ref.z - 0.04, ref.z, hsv.z);
	if (src.y < 1.0) {
		float hd = abs(fract(hsv.x - src.x + 0.5) - 0.5);
		m *= 1.0 - smoothstep(src.y, src.y + 0.025, hd);
	}
	vec3 n = vec3(dst.x, clamp(dst.y * hsv.y / ref.x, 0.0, 1.0), clamp(dst.z * hsv.z / ref.y, 0.0, 1.0));
	mask = m;
	return mix(col, hsv2rgb(n), m);
}

void fragment() {
	// The game's renderer (Compatibility) hands the texture over as painted (sRGB) and
	// takes ALBEDO the same way, so the colours are judged just as they were measured.
	vec3 c = texture(tex, UV).rgb;
	vec3 hsv = rgb2hsv(c);
	float ma = 0.0;
	float mb = 0.0;
	vec3 o = swap(c, hsv, a_src, a_ref, a_dst, ma);
	o = swap(o, hsv, b_src, b_ref, b_dst, mb);
	ALBEDO = o;
	ROUGHNESS = rough;
	METALLIC = metal;
	float g = ma * a_gold + mb * b_gold;
	float k = ma * a_dark + mb * b_dark;
	if (g + k > 0.001) {
		// Gold: a warm glow at the edges, and a band of light that runs up the hero
		// every 2.2 seconds. Obsidian: glossy black, veined with molten gold that
		// slowly breathes, with a violet sheen at the edges.
		float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		vec3 lp = wpos - opos;
		float h = lp.y + 0.35 * (lp.x + lp.z);
		float vn = sin(lp.x * 11.0 + lp.y * 7.0 + sin(lp.z * 9.0) * 1.6) * sin(lp.z * 10.0 - lp.y * 6.0 + sin(lp.x * 8.0) * 1.4);
		float vein = (1.0 - smoothstep(0.035, 0.11, abs(vn))) * (0.7 + 0.3 * sin(TIME * 1.7 + lp.y * 3.0));
		float ph = fract(TIME * 0.45 - h * 0.32);
		float band = smoothstep(0.0, 0.03, ph) * (1.0 - smoothstep(0.03, 0.09, ph));
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.08, 1.0, 0.86), g);
		ROUGHNESS = mix(ROUGHNESS, 0.28, g + k * 0.6);
		METALLIC = mix(METALLIC, 0.7, g);
		ALBEDO = mix(ALBEDO, vec3(1.0, 0.72, 0.22), k * vein * 0.8);
		EMISSION = vec3(1.0, 0.72, 0.24) * g * (0.22 + edge * 0.85)
			+ vec3(1.0, 0.94, 0.75) * band * (g * 1.5 + k * 0.6)
			+ vec3(1.0, 0.62, 0.16) * k * vein * 1.1
			+ vec3(0.55, 0.35, 0.9) * k * edge * 0.45;
	}
}
"""
