class_name Floors
## Each floor of the crypt has its own look, made from colours, lights, particles and its
## own props (props.gd): the Bone Crypt, the Frozen Ossuary, the Ember Catacomb, (version
## 128) the Glowcap Grotto on floor 4 and (version 247) the Sandfall Tomb on floor 5. Past the free floors (the Crypt Pass) the Drowned
## Vault joins them: floor 6 is flooded, then every fifth floor (see index). Each endless
## loop below floor 5 darkens them. To add a theme, copy an entry in THEMES. The floor keys (grout, grime, patch,
## water) are explained in room.gd's _floor_material; colours there are as they look on
## screen. "light" is [ambient strength, sun strength, how far the sun turns warm, how far
## the ambient turns warm]: a bright, clear arena where every character reads (the Frozen
## Ossuary stays cool and gentler, as its pale floor would wash out white skeletons).

const THEMES := [
	{"name": "Bone Crypt", "wisp": Color(1.0, 0.82, 0.55), "floor": Color(1, 1, 1),
		# Moss and dirt in patches and along the walls; damp stone that shines in torchlight.
		"grout": Color(0.07, 0.06, 0.07), "grime": Color(0.3, 0.29, 0.21), "grime_amount": 0.55,
		"patch_tint": Color(0.86, 0.87, 0.92), "patch_rough": 0.45,
		"wall": Color(0.15, 0.14, 0.19), "trim": Color(0.27, 0.25, 0.31),
		"ambient": Color(0.2, 0.19, 0.28), "fog": Color(0.03, 0.03, 0.06), "background": Color(0.02, 0.02, 0.035),
		"moon": Color(0.55, 0.6, 0.9), "torch": Color(1.0, 0.62, 0.3), "torch_energy": 1.4,
		"motes": [Color(1.0, 0.55, 0.2, 0.9), Color(0.7, 0.6, 1.0, 0.35)], "motes_fall": false, "banner": Color(1, 0.7, 0.4),
		"floor_style": 1, "props": "bone", "pillar": "pillar_decorated", "light": [1.1, 2.0, 0.85, 1.0]},
	# Version 213 (hardest review fix #15): dark slate stone with the frost in the patches, so a
	# blue hero and blue shots stand out (the pale blue floor hid them).
	{"name": "Frozen Ossuary", "wisp": Color(0.8, 0.62, 1.0), "floor": Color(0.5, 0.53, 0.58),
		# Frost creeping in from the walls; patches of dark, glassy ice.
		"grout": Color(0.06, 0.07, 0.1), "grime": Color(0.4, 0.43, 0.48), "grime_amount": 0.4,
		"patch_tint": Color(0.66, 0.76, 0.88), "patch_rough": 0.1,
		"wall": Color(0.12, 0.16, 0.23), "trim": Color(0.3, 0.38, 0.48),
		"ambient": Color(0.27, 0.31, 0.4), "fog": Color(0.05, 0.08, 0.13), "background": Color(0.02, 0.035, 0.06),
		"moon": Color(0.72, 0.83, 0.95), "torch": Color(0.72, 0.87, 1.0), "torch_energy": 1.5,
		"motes": [Color(0.95, 0.98, 1.0, 0.9), Color(0.6, 0.8, 1.0, 0.4)], "motes_fall": true, "banner": Color(0.6, 0.9, 1.0),
		"floor_style": 2, "props": "ice", "pillar": "column", "light": [1.05, 1.2, 0.15, 0.1]},
	# Charcoal slabs with fire in the gaps ("seams"), so fire and warnings stand out on them.
	{"name": "Ember Catacomb", "wisp": Color(0.45, 0.78, 1.0), "floor": Color(0.34, 0.3, 0.3), "seams": Color(1.0, 0.28, 0.04),
		# Soot in patches and along the walls; pale ash.
		"grout": Color(0.03, 0.02, 0.02), "grime": Color(0.03, 0.025, 0.025), "grime_amount": 0.8,
		"patch_tint": Color(1.6, 1.5, 1.45), "patch_rough": 0.95,
		"wall": Color(0.19, 0.1, 0.08), "trim": Color(0.35, 0.18, 0.12),
		"ambient": Color(0.25, 0.17, 0.14), "fog": Color(0.09, 0.03, 0.02), "background": Color(0.05, 0.015, 0.01),
		"moon": Color(0.9, 0.6, 0.45), "torch": Color(1.0, 0.45, 0.18), "torch_energy": 1.7,
		# Embers stay small, dim and deep red so they never look like coins or enemy shots.
		"motes": [Color(0.95, 0.38, 0.16, 0.5), Color(0.7, 0.15, 0.06, 0.2)], "motes_fall": false, "motes_size": 0.5,
		"banner": Color(1, 0.55, 0.3), "floor_style": 3, "props": "ember", "light": [1.35, 1.6, 0.4, 0.3]},
	# Flooded halls: dark green-grey stone under shallow water that pools in the low places
	# and fills the gaps, rippling and catching the light. Pale sea-green lamps.
	{"name": "Drowned Vault", "wisp": Color(0.35, 1.0, 0.9), "floor": Color(0.76, 0.9, 0.88), "water": Color(0.07, 0.25, 0.27, 1.0),
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
	{"name": "Glowcap Grotto", "wisp": Color(0.72, 0.9, 1.0), "floor": Color(0.68, 0.78, 0.62), "spores": Color(1.0, 0.36, 0.78, 1.0),
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
		"banner": Color(1.0, 0.6, 0.9), "floor_style": 4, "props": "fungus", "pillar": "wall_pillar", "light": [1.25, 1.7, 0.3, 0.2]},
	# Version 134: the Blood Moon crypt, only in the Blood Moon event (events.gd). Black
	# marble and gold under the red light of the moon, blood veins in the stone throbbing
	# like a heart, pale wisps high up, petals falling. Warnings turn ice white here (telegraph.gd),
	# so they never melt into the red or the gold. (Version 140: wisps are never a gameplay
	# colour: not green like hearts, not pink or red like enemy shots.)
	{"name": "Blood Moon Crypt", "wisp": Color(0.72, 0.9, 1.0), "floor": Color(1.0, 0.95, 1.0), "seams": Color(1.0, 0.1, 0.07),
		"grout": Color(0.05, 0.02, 0.03), "grime": Color(0.05, 0.045, 0.07), "grime_amount": 0.5,
		"patch_tint": Color(0.85, 0.8, 0.9), "patch_rough": 0.25,
		"wall": Color(0.13, 0.06, 0.08), "trim": Color(0.32, 0.12, 0.13),
		"ambient": Color(0.19, 0.17, 0.25), "fog": Color(0.06, 0.01, 0.03), "background": Color(0.04, 0.0, 0.01),
		"moon": Color(0.95, 0.74, 0.8), "torch": Color(1.0, 0.62, 0.32), "torch_energy": 1.2,
		# Petals falling: deep red and pale rose, small, so they never look like shots.
		"motes": [Color(1.0, 0.18, 0.18, 0.75), Color(1.0, 0.6, 0.6, 0.35)], "motes_fall": true, "motes_size": 0.55,
		"banner": Color(1.0, 0.32, 0.26), "floor_style": 5, "props": "moon", "pillar": "pillar_decorated", "light": [1.25, 1.75, 0.1, 0.3]},
	# Version 243: Frostfall Hall, only in the Frostfall event (events.gd). The one crypt
	# with no stone floor: a great hall of dark timber under deep snow, a pine-green carpet
	# with gold snowflakes down the middle, log walls hung with garlands of little lights,
	# pine trees and gifts in the corners. Blue night outside, warm fire inside, and heavy
	# snow falling. Not the Frozen Ossuary (dark ice and cold blue everywhere).
	{"name": "Frostfall Hall", "wisp": Color(0.78, 0.88, 1.0), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.035, 0.022, 0.015), "grime": Color(0.6, 0.65, 0.76), "grime_amount": 0.75,
		"patch_tint": Color(0.9, 0.95, 1.0), "patch_rough": 0.5,
		"wall": Color(0.17, 0.11, 0.07), "trim": Color(0.32, 0.22, 0.14),
		"ambient": Color(0.2, 0.24, 0.4), "fog": Color(0.03, 0.045, 0.1), "background": Color(0.012, 0.018, 0.045),
		"moon": Color(0.62, 0.74, 1.0), "torch": Color(1.0, 0.6, 0.28), "torch_energy": 1.7, "pool": 1.2,
		# Big soft snowflakes falling (white, slow, never the shape or speed of a shot).
		"motes": [Color(0.96, 0.98, 1.0, 0.9), Color(0.78, 0.86, 1.0, 0.45)], "motes_fall": true, "motes_size": 0.85,
		"banner": Color(1.0, 0.35, 0.3), "floor_style": 6, "props": "yule", "pillar": "timber", "light": [1.2, 1.45, 0.0, 0.0]},
	# Version 247 (whole-game review fix 4): the Sandfall Tomb, floor 5, where the free game
	# ends with the King and the Lich. Until now floor 5 was the Frozen Ossuary again. A royal
	# tomb under the desert: great sandstone blocks carved with signs, turquoise and gold
	# inlay with a winged sun in the middle, sand pouring in through cracks in the walls and
	# drifting in rippled dunes along them, painted coffins standing guard, obelisks, lotus
	# columns and jars. Warm sun through the cracks, cool turquoise in the shadows.
	{"name": "Sandfall Tomb", "wisp": Color(0.62, 0.95, 1.0), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.06, 0.04, 0.03), "grime": Color(0.5, 0.4, 0.28), "grime_amount": 0.8,
		"patch_tint": Color(0.95, 0.9, 0.85), "patch_rough": 0.7,
		"wall": Color(0.3, 0.21, 0.13), "trim": Color(0.42, 0.3, 0.18),
		"ambient": Color(0.2, 0.21, 0.27), "fog": Color(0.07, 0.045, 0.03), "background": Color(0.035, 0.022, 0.014),
		"moon": Color(0.92, 0.86, 0.76), "torch": Color(1.0, 0.62, 0.32), "torch_energy": 1.3, "pool": 0.55,
		# Grains of sand drifting in the light: small and pale, never the shape of a shot.
		"motes": [Color(1.0, 0.86, 0.6, 0.6), Color(0.92, 0.72, 0.48, 0.28)], "motes_fall": false, "motes_size": 0.4,
		"pebble": Color(0.9, 0.68, 0.45),   # the colour of loose stones on the floor (props.gd)
		"banner": Color(1.0, 0.8, 0.42), "floor_style": 7, "props": "sand", "pillar": "lotus", "light": [1.05, 1.45, 0.1, 0.0]},
	# Version 248 (review fix 4): the Amethyst Mine, floor 7 (the Crypt Pass), which until
	# now was the Bone Crypt relit ("Moonlit Crypt"). An old mine the dead dug for crystals:
	# bare rock in broken slabs, mine-cart rails on timber sleepers down the middle with a spur
	# curving off to the side, amethyst glowing in the cracks, timber props holding up the
	# walls, crystal clusters, carts of crystals and boarded-up tunnels. Violet in the dark,
	# warm lanterns, dust falling from the roof.
	{"name": "Amethyst Mine", "wisp": Color(0.72, 0.9, 1.0), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.04, 0.035, 0.05), "grime": Color(0.3, 0.29, 0.29), "grime_amount": 0.7,
		"patch_tint": Color(0.9, 0.88, 0.95), "patch_rough": 0.8, "spores": Color(0.72, 0.32, 1.0, 1.0),   # (the amethyst glow, room.gd)
		"wall": Color(0.16, 0.14, 0.18), "trim": Color(0.26, 0.17, 0.1),
		"ambient": Color(0.2, 0.21, 0.27), "fog": Color(0.04, 0.035, 0.06), "background": Color(0.016, 0.012, 0.03),
		"moon": Color(0.82, 0.84, 1.0), "torch": Color(1.0, 0.64, 0.34), "torch_energy": 1.5, "pool": 0.6,
		# Dust sifting down from the roof, and a few violet glints.
		"motes": [Color(0.85, 0.8, 0.9, 0.45), Color(0.8, 0.55, 1.0, 0.35)], "motes_fall": true, "motes_size": 0.4,
		"pebble": Color(0.62, 0.58, 0.66), "guests": "dr",
		"banner": Color(0.82, 0.6, 1.0), "floor_style": 8, "props": "mine", "pillar": "rock", "light": [1.3, 1.6, 0.0, 0.0]},
	# Version 249 (review fix 4): the Whispering Library, floor 8 (the Crypt Pass), the Lich's
	# own floor, which until now was the Frozen Ossuary relit ("Aurora Ossuary"). The Lich's
	# library of forbidden books: a herringbone parquet floor with worn rugs and a brass circle
	# of glowing letters set in the middle, walls of bookcases, bookcases for pillars, lecterns
	# with their pages circling in the air, ladders, a clock and a great globe. Warm candlelight
	# and the cold teal glow of books that whisper.
	{"name": "Whispering Library", "wisp": Color(0.6, 1.0, 0.9), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.03, 0.018, 0.012), "grime": Color(0.12, 0.09, 0.07), "grime_amount": 0.5,
		"patch_tint": Color(0.95, 0.9, 0.85), "patch_rough": 0.6, "spores": Color(0.35, 1.0, 0.82, 1.0),   # (the whispering glow, room.gd)
		"wall": Color(0.2, 0.12, 0.07), "trim": Color(0.3, 0.18, 0.1),
		"ambient": Color(0.21, 0.2, 0.26), "fog": Color(0.05, 0.035, 0.03), "background": Color(0.02, 0.014, 0.012),
		"moon": Color(0.75, 0.9, 1.0), "torch": Color(1.0, 0.7, 0.4), "torch_energy": 1.4, "pool": 0.6,
		# Dust turning in the candlelight, and a few teal sparks of whispering.
		"motes": [Color(1.0, 0.88, 0.65, 0.5), Color(0.45, 1.0, 0.85, 0.35)], "motes_fall": false, "motes_size": 0.4,
		"pebble": Color(0.55, 0.42, 0.32), "guests": "fe",
		"banner": Color(0.5, 1.0, 0.85), "floor_style": 9, "props": "library", "pillar": "shelf", "light": [1.35, 1.65, 0.0, 0.0]},
]

## Where the Drowned Vault and the Glowcap Grotto sit in THEMES.
const DROWNED := 3
const GROTTO := 4
## The Blood Moon crypt: never in the rotation, only in the event's runs (Game.event).
const BLOOD_MOON := 5
## Frostfall Hall: never in the rotation, only in the Frostfall event's runs.
const FROSTFALL := 6
## The Sandfall Tomb: floor 5 (version 247).
const SANDFALL := 7
## The Amethyst Mine: floor 7, the second floor of each Crypt Pass loop (version 248).
const MINE := 8
## The Whispering Library: floor 8, the third floor of each Crypt Pass loop (version 249).
const LIBRARY := 9
## The free floors (1-5) in order: Bone, Frozen, Ember, Grotto, and the Sandfall Tomb.
const FREE_ORDER := [0, 1, 2, GROTTO, SANDFALL]
## Each loop of the Crypt Pass (5 floors, see Loops): the Drowned Vault first, then (version
## 248) the Amethyst Mine where the Bone Crypt came back relit, and (version 249) the
## Whispering Library where the Frozen Ossuary did.
const PASS_ORDER := [DROWNED, MINE, LIBRARY, 2, GROTTO]


## Which entry of THEMES a floor uses: floors 1-5 go Bone, Frozen, Ember, Grotto, Sandfall
## (until version 128 floor 4 was the Bone Crypt again, with the Lich for a second time, and
## until version 247 floor 5 was the Frozen Ossuary again);
## from floor 6 the five themes take turns starting with the Drowned Vault (6, 11, 16...),
## so it is the first thing the Crypt Pass shows. Music, room sounds and each theme's own
## skeletons follow the same order.
## The title's lobby room in the event's crypt while an event is on (the takeover).
static var lobby := false


static func index(floor_num: int) -> int:
	if Game.event != "" or lobby:
		return int(Events.ev().get("theme", BLOOD_MOON))
	var f := maxi(floor_num, 1)
	if f <= Store.FREE_FLOORS:
		return FREE_ORDER[(f - 1) % FREE_ORDER.size()]
	return PASS_ORDER[(f - Store.FREE_FLOORS - 1) % PASS_ORDER.size()]


static func theme(floor_num: int) -> Dictionary:
	var t: Dictionary = THEMES[index(floor_num)]
	var loop := Loops.loop_of(floor_num)
	if remixed(floor_num):
		t = t.duplicate()
		t.merge(PASS_REMIX[index(floor_num)], true)
	return t if loop <= 1 else _deeper(t, loop)


## Version 219 (review 4 fix 28): the Crypt Pass's own takes on the three free crypts it
## brings back, so its floors aren't reruns: a new name, light and air, and guest skeletons
## from the other crypts (Game.theme_enemy). The floor and its props stay, so they read.
const PASS_REMIX := {
	0: {"name": "Moonlit Crypt", "ambient": Color(0.18, 0.2, 0.34), "moon": Color(0.6, 0.75, 1.0), "torch": Color(0.55, 0.75, 1.0),
		"motes": [Color(0.7, 0.85, 1.0, 0.7), Color(0.85, 0.75, 1.0, 0.3)], "banner": Color(0.65, 0.8, 1.0), "guests": "dr"},
	1: {"name": "Aurora Ossuary", "ambient": Color(0.2, 0.33, 0.33), "moon": Color(0.6, 1.0, 0.85), "torch": Color(0.5, 1.0, 0.8),
		"motes": [Color(0.6, 1.0, 0.85, 0.7), Color(0.7, 0.6, 1.0, 0.35)], "banner": Color(0.55, 1.0, 0.8), "guests": "fe"},
	2: {"name": "Ashen Catacomb", "ambient": Color(0.22, 0.21, 0.24), "moon": Color(0.78, 0.8, 0.9), "torch": Color(0.95, 0.75, 0.55),
		"motes": [Color(0.85, 0.85, 0.9, 0.45), Color(0.6, 0.6, 0.68, 0.2)], "banner": Color(0.85, 0.85, 0.95), "guests": "ep"},
}


## True on a Crypt Pass floor that brings back one of the free crypts (see PASS_REMIX).
static func remixed(floor_num: int) -> bool:
	return Game.event == "" and not lobby and floor_num > Store.FREE_FLOORS and PASS_REMIX.has(index(floor_num))


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
	d["blood"] = [0.0, 0.0, 0.15, 0.2][steps]   # stains on the floor (room.gd); v218: none on the 2nd step; v220: fewer (red warnings read on them)
	return d


static func current() -> Dictionary:
	return theme(Game.floor_num)


## The Ember Catacomb and the Blood Moon crypt, where red warnings would melt into the
## glowing floor ("seams"): warnings turn gold there (telegraph.gd).
static func hot() -> bool:
	return current().has("seams")


## The Ember Catacomb (the Cinder Colossus's floor).
static func ember() -> bool:
	return index(Game.floor_num) == 2 and Game.event == "" and not lobby   # (v219: by place, the Pass's Ashen Catacomb too)


## The Blood Moon crypt (the event).
static func blood_moon() -> bool:
	return index(Game.floor_num) == BLOOD_MOON


## Frostfall Hall (the winter event).
static func frostfall() -> bool:
	return index(Game.floor_num) == FROSTFALL


## The Drowned Vault (Crypt Pass floors only).
static func drowned() -> bool:
	return index(Game.floor_num) == DROWNED


## The Glowcap Grotto (floor 4, then every fifth floor from 10).
static func grotto() -> bool:
	return index(Game.floor_num) == GROTTO


## The Sandfall Tomb (floor 5).
static func sandfall() -> bool:
	return index(Game.floor_num) == SANDFALL
