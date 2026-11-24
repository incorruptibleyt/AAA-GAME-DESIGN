class_name Legends
## Version 312 (Jesse: "an amazing list of late game cosmetics that cost crazy amounts of
## coins"): the LEGEND VAULT, the Armory's fourth tab. Twelve looks for players who have
## everything else, at prices from 25,000 to 1,000,000 coins. Each one is a new kind of look
## the game didn't have, built to be seen from the run camera above the hero: pets that
## follow you, wings, footsteps, finishers (how skeletons fall) and two grand sets.
## Every hero wears them (they are bought once, for the whole crypt), one per kind.
##
## Why: the player panel's Archero fan quit at 50,000 coins with nothing to spend them on,
## and the Bazaar's dearest look is 1,500. A crypt this deep needs prizes worth saving for.

const SECTION := "legends"
const SLOTS := ["pet", "wings", "steps", "finisher", "grand"]
const SLOT_NAMES := {"pet": "PET", "wings": "WINGS", "steps": "FOOTSTEPS", "finisher": "FINISHER", "grand": "GRAND SET"}
## The vault's gold.
const GOLD := Color(1.0, 0.8, 0.3)

## `ready`: built in this version (the rest show as COMING SOON in the vault).
const LIST := [
	{"id": "wisp", "slot": "pet", "name": "Lantern Wisp", "price": 25000, "ready": true,
		"text": "A little ghost with a swinging lantern. Its warm light follows you."},
	{"id": "ember_steps", "slot": "steps", "name": "Ember Steps", "price": 40000, "ready": true,
		"text": "Every step burns into the floor and smoulders away."},
	{"id": "raven", "slot": "pet", "name": "Crypt Raven", "price": 60000, "ready": true,
		"text": "A black raven with a bird-skull head. It circles you in a fight and rests on your shoulder."},
	{"id": "bone_wings", "slot": "wings", "name": "Bone Wings", "price": 80000, "ready": true,
		"text": "Skeleton wings with torn dusk skin. They spread when you dash."},
	{"id": "gold_rush", "slot": "finisher", "name": "Gold Rush", "price": 100000, "ready": true,
		"text": "Every skeleton you fell bursts into a fountain of gold coins."},
	{"id": "star_steps", "slot": "steps", "name": "Stardust Steps", "price": 120000, "ready": true,
		"text": "Each step leaves a little constellation that twinkles away."},
	{"id": "mimic", "slot": "pet", "name": "Mimic", "price": 150000, "ready": true,
		"text": "A treasure chest with fangs. It hops after you and snaps at skeletons."},
	{"id": "soul_harvest", "slot": "finisher", "name": "Soul Harvest", "price": 200000, "ready": true,
		"text": "A ghost rises from every skeleton you fell and flies into you."},
	{"id": "phoenix", "slot": "wings", "name": "Phoenix Wings", "price": 250000, "ready": true,
		"text": "Wings of burning feathers. A dash leaves a firebird behind."},
	{"id": "wyrm", "slot": "pet", "name": "Bone Wyrm", "price": 400000, "ready": true,
		"text": "A tiny skeleton dragon on your shoulder that breathes violet fire at bosses."},
	{"id": "starfall", "slot": "grand", "name": "Starfall Mantle", "price": 600000, "ready": true,
		"text": "A cape and tall collar that are a window into the night sky, and a crown of stars with a comet."},
	{"id": "emperor", "slot": "grand", "name": "The Bone Emperor", "price": 1000000, "ready": true,
		"text": "Golden bone armour, a spine cape, a crown of skulls, and a bone throne."},
]


static func def(id: String) -> Dictionary:
	for d: Dictionary in LIST:
		if d.id == id:
			return d
	return {}


static func owns(cfg: ConfigFile, id: String) -> bool:
	return bool(cfg.get_value(SECTION, "own_" + id, false))


static func give(cfg: ConfigFile, id: String) -> void:
	cfg.set_value(SECTION, "own_" + id, true)


static func owned_count(cfg: ConfigFile) -> int:
	var n := 0
	for d: Dictionary in LIST:
		if owns(cfg, d.id):
			n += 1
	return n


## What is worn: {slot: id}, only looks that are owned and built.
static func worn(cfg: ConfigFile) -> Dictionary:
	var out := {}
	for slot: String in SLOTS:
		var id := str(cfg.get_value(SECTION, "wear_" + slot, ""))
		if id != "" and owns(cfg, id) and bool(def(id).get("ready", false)):
			out[slot] = id
	return out


static func is_worn(cfg: ConfigFile, id: String) -> bool:
	var d := def(id)
	return not d.is_empty() and str(cfg.get_value(SECTION, "wear_" + str(d.slot), "")) == id


## Wears `id` (taking off what was worn in its kind), or takes it off if it was worn.
static func toggle(cfg: ConfigFile, id: String) -> void:
	var d := def(id)
	if d.is_empty():
		return
	cfg.set_value(SECTION, "wear_" + str(d.slot), "" if is_worn(cfg, id) else id)


static func wear(cfg: ConfigFile, id: String) -> void:
	var d := def(id)
	if not d.is_empty():
		cfg.set_value(SECTION, "wear_" + str(d.slot), id)


## "1,000,000"
static func price_text(id: String) -> String:
	return Hud.thousands(int(def(id).get("price", 0)))


# ---------------------------------------------------------------- on the hero

## Adds the worn legends to a hero's model (CharacterVisual._dress_model): the pet beside them,
## wings on their back, footsteps behind them, and on a pedestal the finisher played beside
## them (in a run Game.on_enemy_died plays it: LegendFinish).
## `legend` is {slot: id} (HeroStyle.dressed puts it in the style as "legend").
static func dress(visual: Node3D, model: Node3D, legend: Dictionary) -> void:
	var pet := str(legend.get("pet", ""))
	if pet != "":
		var p := LegendPet.new()
		p.kind = pet
		p.name = "LegendPet"
		visual.add_child(p)
	var wings := str(legend.get("wings", ""))
	if wings != "":
		LegendWings.make(visual, model, wings)   # version 313
	var finisher := str(legend.get("finisher", ""))
	if finisher != "" and visual.get_viewport() is SubViewport:
		var show := LegendFinish.Show.new()   # version 314: on a pedestal, played over and over
		show.kind = finisher
		visual.add_child(show)
	var grand := str(legend.get("grand", ""))
	if grand != "":
		LegendGrand.make(visual, model, grand)   # version 315 (its crown: HeroStyle.crown_grand)
	var steps := str(legend.get("steps", ""))
	if steps != "":
		var st := LegendSteps.new()   # version 313
		st.kind = steps
		st.name = "LegendSteps"
		visual.add_child(st)
