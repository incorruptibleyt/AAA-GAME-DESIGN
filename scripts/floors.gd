class_name Floors
## Each floor of the crypt has its own look, made from colours, lights, particles and its
## own props (props.gd): the Bone Crypt, the Frozen Ossuary, the Ember Catacomb and (version
## 128) the Glowcap Grotto on floor 4. Past the free floors (the Crypt Pass) the Drowned
## Vault joins them: floor 6 is flooded, then every fifth floor (see index). Each endless
## loop below floor 5 darkens them. To add a theme, copy an entry in THEMES. The floor keys (grout, grime, patch,
## water) are explained in room.gd's _floor_material; colours there are as they look on
## screen. "light" is [ambient strength, sun strength, how far the sun turns warm, how far
## the ambient turns warm]: a bright, clear arena where every character reads (the Frozen
## Ossuary stays cool and gentler, as its pale floor would wash out white skeletons).

const THEMES := [
	{"name": "Bone Crypt", "floor": Color(1, 1, 1),
		# Moss and dirt in patches and along the walls; damp stone that shines in torchlight.
		"grout": Color(0.07, 0.06, 0.07), "grime": Color(0.3, 0.29, 0.21), "grime_amount": 0.55,
		"patch_tint": Color(0.86, 0.87, 0.92), "patch_rough": 0.45,
		"wall": Color(0.15, 0.14, 0.19), "trim": Color(0.27, 0.25, 0.31),
		"ambient": Color(0.2, 0.19, 0.28), "fog": Color(0.03, 0.03, 0.06), "background": Color(0.02, 0.02, 0.035),
		"moon": Color(0.55, 0.6, 0.9), "torch": Color(1.0, 0.62, 0.3), "torch_energy": 1.4,
		"motes": [Color(1.0, 0.55, 0.2, 0.9), Color(0.7, 0.6, 1.0, 0.35)], "motes_fall": false, "banner": Color(1, 0.7, 0.4),
		"props": "bone", "light": [1.1, 2.0, 0.85, 1.0]},
	{"name": "Frozen Ossuary", "floor": Color(0.8, 0.88, 0.97),
		# Frost creeping in from the walls; patches of dark, glassy ice.
		"grout": Color(0.08, 0.1, 0.14), "grime": Color(0.64, 0.7, 0.78), "grime_amount": 0.4,
		"patch_tint": Color(0.72, 0.83, 0.95), "patch_rough": 0.1,
		"wall": Color(0.12, 0.16, 0.23), "trim": Color(0.3, 0.38, 0.48),
		"ambient": Color(0.27, 0.31, 0.4), "fog": Color(0.05, 0.08, 0.13), "background": Color(0.02, 0.035, 0.06),
		"moon": Color(0.72, 0.83, 0.95), "torch": Color(0.72, 0.87, 1.0), "torch_energy": 1.5,
		"motes": [Color(0.95, 0.98, 1.0, 0.9), Color(0.6, 0.8, 1.0, 0.4)], "motes_fall": true, "banner": Color(0.6, 0.9, 1.0),
		"props": "ice", "light": [1.05, 1.2, 0.15, 0.1]},
	# Charcoal slabs with fire in the gaps ("seams"), so fire and warnings stand out on them.
	{"name": "Ember Catacomb", "floor": Color(0.34, 0.3, 0.3), "seams": Color(1.0, 0.28, 0.04),
		# Soot in patches and along the walls; pale ash.
		"grout": Color(0.03, 0.02, 0.02), "grime": Color(0.03, 0.025, 0.025), "grime_amount": 0.8,
		"patch_tint": Color(1.6, 1.5, 1.45), "patch_rough": 0.95,
		"wall": Color(0.19, 0.1, 0.08), "trim": Color(0.35, 0.18, 0.12),
		"ambient": Color(0.25, 0.17, 0.14), "fog": Color(0.09, 0.03, 0.02), "background": Color(0.05, 0.015, 0.01),
		"moon": Color(0.9, 0.6, 0.45), "torch": Color(1.0, 0.45, 0.18), "torch_energy": 1.7,
		# Embers stay small, dim and deep red so they never look like coins or enemy shots.
		"motes": [Color(0.95, 0.38, 0.16, 0.5), Color(0.7, 0.15, 0.06, 0.2)], "motes_fall": false, "motes_size": 0.5,
		"banner": Color(1, 0.55, 0.3), "props": "ember", "light": [1.35, 1.6, 0.4, 0.3]},
	# Flooded halls: dark green-grey stone under shallow water that pools in the low places
	# and fills the gaps, rippling and catching the light. Pale sea-green lamps.
	{"name": "Drowned Vault", "floor": Color(0.76, 0.9, 0.88), "water": Color(0.07, 0.25, 0.27, 1.0),
		# Algae in patches and along the walls; the pools themselves are the second patch.
		"grout": Color(0.02, 0.05, 0.05), "grime": Color(0.13, 0.22, 0.15), "grime_amount": 0.6,
		"patch_tint": Color(0.8, 0.92, 0.92), "patch_rough": 0.05,
		"wall": Color(0.08, 0.14, 0.15), "trim": Color(0.17, 0.27, 0.27),
		"ambient": Color(0.17, 0.26, 0.28), "fog": Color(0.02, 0.07, 0.08), "background": Color(0.01, 0.03, 0.035),
		"moon": Color(0.55, 0.85, 0.82), "torch": Color(0.6, 1.0, 0.85), "torch_energy": 1.5,
		# Bubbles drifting up, pale so they never look like shots.
		"motes": [Color(0.75, 1.0, 0.95, 0.45), Color(0.45, 0.8, 0.85, 0.2)], "motes_fall": false, "motes_size": 0.6,
		"banner": Color(0.5, 0.95, 0.88), "props": "water", "light": [1.3, 1.7, 0.35, 0.2]},
	# Version 128: a cave grown over with glowing mushrooms. Mossy green stone under cool
	# green light, with pink and lime fungus glowing in the moss ("spores", room.gd), so it
	# looks like none of the other four (and pink isn't used by hearts, coins or warnings).
	{"name": "Glowcap Grotto", "floor": Color(0.68, 0.78, 0.62), "spores": Color(1.0, 0.36, 0.78, 1.0),
		"spores2": Color(0.72, 1.0, 0.3),
		# Mossy green stone, dark moss in patches and along the walls, and the pink glow of
		# the fungus on top: green and pink sit opposite each other, so the glow pops.
		"grout": Color(0.03, 0.045, 0.03), "grime": Color(0.08, 0.14, 0.07), "grime_amount": 0.75,
		"patch_tint": Color(0.8, 0.92, 0.82), "patch_rough": 0.3,
		"wall": Color(0.1, 0.13, 0.11), "trim": Color(0.21, 0.27, 0.22),
		"ambient": Color(0.2, 0.24, 0.22), "fog": Color(0.03, 0.05, 0.04), "background": Color(0.015, 0.025, 0.02),
		"moon": Color(0.74, 0.86, 0.8), "torch": Color(1.0, 0.6, 0.85), "torch_energy": 1.5,
		# Spores drifting up: small and pale, so they never look like shots or coins.
		"motes": [Color(1.0, 0.6, 0.9, 0.45), Color(0.8, 1.0, 0.5, 0.25)], "motes_fall": false, "motes_size": 0.45,
		"banner": Color(1.0, 0.6, 0.9), "props": "fungus", "light": [1.25, 1.7, 0.3, 0.2]},
]

## Where the Drowned Vault and the Glowcap Grotto sit in THEMES.
const DROWNED := 3
const GROTTO := 4
## The free floors (1-5) in order: Bone, Frozen, Ember, Grotto, Frozen.
const FREE_ORDER := [0, 1, 2, GROTTO, 1]
## Each loop of the Crypt Pass (5 floors, see Loops) shows all five, the Drowned Vault first.
const PASS_ORDER := [DROWNED, 0, 1, 2, GROTTO]


## Which entry of THEMES a floor uses: floors 1-5 go Bone, Frozen, Ember, Grotto, Frozen
## (until version 128 floor 4 was the Bone Crypt again, with the Lich for a second time);
## from floor 6 the five themes take turns starting with the Drowned Vault (6, 11, 16...),
## so it is the first thing the Crypt Pass shows. Music, room sounds and each theme's own
## skeletons follow the same order.
static func index(floor_num: int) -> int:
	var f := maxi(floor_num, 1)
	if f <= Store.FREE_FLOORS:
		return FREE_ORDER[(f - 1) % FREE_ORDER.size()]
	return PASS_ORDER[(f - Store.FREE_FLOORS - 1) % PASS_ORDER.size()]


static func theme(floor_num: int) -> Dictionary:
	var t: Dictionary = THEMES[index(floor_num)]
	var loop := Loops.loop_of(floor_num)
	return t if loop <= 1 else _deeper(t, loop)


## Every endless loop is a little darker and redder than the one before (down to loop 4).
static func _deeper(t: Dictionary, loop: int) -> Dictionary:
	var steps := mini(loop - 1, 3)
	var dark := pow(0.86, steps)
	var red := 0.14 * steps
	var d := t.duplicate()
	for key in ["ambient", "moon", "fog", "background", "wall", "trim", "torch"]:
		var c: Color = t[key]
		var blood := Color(c.get_luminance() * 1.6, c.get_luminance() * 0.4, c.get_luminance() * 0.35)
		c = c.lerp(blood, red)
		if key in ["ambient", "moon"]:
			c = Color(c.r * dark, c.g * dark, c.b * dark)
		d[key] = c
	d["banner"] = (t.banner as Color).lerp(Color(1, 0.3, 0.25), red)
	d["blood"] = [0.0, 0.35, 0.45, 0.5][steps]   # stains on the floor (room.gd)
	return d


static func current() -> Dictionary:
	return theme(Game.floor_num)


## The Ember Catacomb, where red warnings would melt into the floor.
static func hot() -> bool:
	return current().name == "Ember Catacomb"


## The Drowned Vault (Crypt Pass floors only).
static func drowned() -> bool:
	return index(Game.floor_num) == DROWNED


## The Glowcap Grotto (floor 4, then every fifth floor from 10).
static func grotto() -> bool:
	return index(Game.floor_num) == GROTTO
