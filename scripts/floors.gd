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
		"ambient": Color(0.2, 0.195, 0.25), "fog": Color(0.03, 0.03, 0.06), "background": Color(0.02, 0.02, 0.035),
		"moon": Color(0.55, 0.6, 0.9), "torch": Color(1.0, 0.62, 0.3), "torch_energy": 1.4,
		# Version 277 (floor 1's new look): a few small candle sparks and dust, where big
		# orange embers hazed the whole room.
		"motes": [Color(1.0, 0.66, 0.32, 0.5), Color(0.8, 0.76, 0.9, 0.25)], "motes_fall": false, "motes_size": 0.35, "banner": Color(1, 0.7, 0.4),
		# Version 265: its own cover (props.gd add_cover): blocks of ossuary wall, thigh bones and
		# rows of skulls stacked the old way, for crates; bone totems for barrels.
		"cover": "bone",
		# Version 277: cooler and darker (it was the brightest floor by far, washed orange), so
		# the candlelight pools by the walls and the Bone Chain in the middle show.
		"floor_style": 1, "props": "bone", "pillar": "pillar_decorated", "light": [1.1, 1.6, 0.45, 0.45]},
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
		# Version 256: its own cover (props.gd add_cover): blocks of clear ice with skeletons
		# frozen inside for crates, frosted urns of skulls for barrels.
		"cover": "ice",
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
		"banner": Color(1, 0.55, 0.3),
		# Version 257: its own cover (props.gd add_cover): funeral pyres burning for crates,
		# iron fire cages with a burning skull for barrels.
		"cover": "ember",
		"floor_style": 3, "props": "ember", "light": [1.35, 1.6, 0.4, 0.3]},
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
		"banner": Color(0.5, 0.95, 0.88),
		# Version 260: its own cover (props.gd add_cover): rowboats lying keel up with a
		# drowned sailor under them for crates, sunken diving helmets for barrels.
		"cover": "wreck",
		"props": "water", "light": [1.3, 1.7, 0.35, 0.2]},
	# Version 128: a cave grown over with glowing mushrooms. Mossy green stone under cool
	# green light, with blue and lime fungus glowing in the moss ("spores", room.gd), so it
	# looks like none of the other four. (Version 296: the fungus was hot pink, the colour of
	# skeleton shots and of the bounce caps, so a shot got lost in it; now blue.)
	{"name": "Glowcap Grotto", "wisp": Color(0.72, 0.9, 1.0), "floor": Color(0.68, 0.78, 0.62), "spores": Color(0.42, 0.62, 1.0, 1.0),
		"spores2": Color(0.72, 1.0, 0.3),
		# Mossy green stone, dark moss in patches and along the walls, and the glow of
		# the fungus on top: green and pink sit opposite each other, so the glow pops.
		"grout": Color(0.03, 0.045, 0.03), "grime": Color(0.08, 0.14, 0.07), "grime_amount": 0.75,
		"patch_tint": Color(0.8, 0.92, 0.82), "patch_rough": 0.3,
		"wall": Color(0.1, 0.13, 0.11), "trim": Color(0.21, 0.27, 0.22),
		"ambient": Color(0.2, 0.24, 0.22), "fog": Color(0.03, 0.05, 0.04), "background": Color(0.015, 0.025, 0.02),
		"moon": Color(0.74, 0.86, 0.8), "torch": Color(1.0, 0.6, 0.85), "torch_energy": 1.5,
		# Spores drifting up: small and pale, so they never look like shots or coins.
		"motes": [Color(1.0, 0.6, 0.9, 0.45), Color(0.8, 1.0, 0.5, 0.25)], "motes_fall": false, "motes_size": 0.45,
		"banner": Color(1.0, 0.6, 0.9),
		# Version 258: its own cover (props.gd add_cover): fallen hollow trunks, mossy and
		# sprouting glowcaps, for crates; hollow stumps with glowing shelf fungus for barrels.
		"cover": "grotto",
		"floor_style": 4, "props": "fungus", "pillar": "wall_pillar", "light": [1.25, 1.7, 0.3, 0.2]},
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
		"banner": Color(1.0, 0.32, 0.26), "floor_style": 5, "props": "moon", "pillar": "pillar_decorated", "light": [1.25, 1.75, 0.1, 0.3],
		"cover": "moon"},   # version 278: blood altars and moon lanterns instead of the KayKit crates and barrels
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
		"banner": Color(1.0, 0.35, 0.3), "floor_style": 6, "props": "yule", "pillar": "timber", "light": [1.2, 1.45, 0.0, 0.0],
		"cover": "yule"},   # version 278: Krampus's sleigh and sack instead of the KayKit crates and barrels
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
		"banner": Color(1.0, 0.8, 0.42),
		# v273: its own Tomb Mummies, and Frost Wraiths for the tomb's spirits (were "fe", one a room).
		"guests": "yf",
		# v274: its own boss, the Sand Pharaoh (until then the King and the Lich together).
		"boss": "P",
		# Version 259: its own cover (props.gd add_cover): the heads of fallen colossi sunk in
		# the sand for crates, glazed scarab statues holding up the sun for barrels.
		"cover": "sand",
		"floor_style": 7, "props": "sand", "pillar": "lotus", "light": [1.05, 1.45, 0.1, 0.0]},
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
		"pebble": Color(0.62, 0.58, 0.66), "guests": "zd",   # v272: its own Geode Guards (were "dr")
		# v275: its own boss, the Crystal Tyrant (until then the Skeleton King from floor 1).
		"boss": "M",
		"banner": Color(0.82, 0.6, 1.0),
		# Version 261: its own cover (props.gd add_cover): great geodes split open, amethyst
		# glowing inside, for crates; heaps of ore with a pickaxe and a lantern for barrels.
		"cover": "mine",
		"floor_style": 8, "props": "mine", "pillar": "rock", "light": [1.3, 1.6, 0.0, 0.0]},
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
		"pebble": Color(0.55, 0.42, 0.32), "guests": "lf",   # v271: its own Hush Keepers (were "fe")
		# v276: its own boss, the Archivist (until then the Lich from floor 2).
		"boss": "B",
		"banner": Color(0.5, 1.0, 0.85),
		# Version 262: its own cover (props.gd add_cover): dead scribes' desks heaped with
		# books for crates, great hourglasses of glowing green sand for barrels.
		"cover": "library",
		"floor_style": 9, "props": "library", "pillar": "shelf", "light": [1.35, 1.65, 0.0, 0.0]},
	# Version 250 (review fix 4): the Clockwork Foundry, floor 9 (the Crypt Pass), the Cinder
	# Colossus's floor, which until now was the Ember Catacomb relit ("Ashen Catacomb"). The
	# works where the dead forge their iron giant: riveted iron floor plates with the furnaces'
	# glow under long grates, a great brass gear turning in the floor, walls of iron plate run
	# with copper pipes and gauges, boilers with their fire doors open, gears turning on the
	# walls, pistons pumping and iron pillars with turning brass collars.
	{"name": "Clockwork Foundry", "wisp": Color(1.0, 0.82, 0.55), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.03, 0.03, 0.035), "grime": Color(0.3, 0.15, 0.08), "grime_amount": 0.75,
		"patch_tint": Color(0.9, 0.9, 0.95), "patch_rough": 0.4, "spores": Color(1.0, 0.42, 0.1, 1.0),   # (the furnaces' glow, room.gd)
		"wall": Color(0.14, 0.15, 0.17), "trim": Color(0.36, 0.27, 0.12),
		"ambient": Color(0.22, 0.22, 0.27), "fog": Color(0.05, 0.04, 0.035), "background": Color(0.02, 0.018, 0.016),
		"moon": Color(0.85, 0.88, 0.95), "torch": Color(1.0, 0.6, 0.3), "torch_energy": 1.4, "pool": 0.55,
		# Sparks drifting up from the furnaces, and wisps of steam.
		"motes": [Color(1.0, 0.65, 0.3, 0.6), Color(0.85, 0.88, 0.92, 0.3)], "motes_fall": false, "motes_size": 0.4,
		# Version 270 (hard review fix 3): its own Clockwork Skeletons beside its Cinder
		# Skeleton stokers (the Grotto's Sporelings it borrowed are gone).
		# Version 281: its own boss, the Forgemaster, in place of the Cinder Colossus of floor 3.
		"pebble": Color(0.5, 0.5, 0.54), "guests": "ue", "boss": "F",
		"banner": Color(1.0, 0.7, 0.35),
		# Version 263: its own cover (props.gd add_cover): anvils on iron blocks with a blade
		# still glowing on them for crates, steam valves with red handwheels for barrels.
		"cover": "foundry",
		"floor_style": 10, "props": "foundry", "pillar": "iron", "light": [1.3, 1.6, 0.0, 0.0]},
	# Version 255: the Starfall Abyss, floor 10 (the Crypt Pass), the last floor of each loop,
	# which until now was floor 4's Glowcap Grotto again. The bottom of the crypt, where the
	# world breaks off into a starry void: pale moonstone plates drifted apart over the abyss
	# (stars and a nebula far below in every gap, room.gd), a star gate in the middle, walls
	# split by starlit cracks under a frieze of silver constellations, broken pillars whose
	# pieces float apart, rocks drifting in the air, great chains rising into the dark and
	# braziers of cold star fire. Starlight "spores" (the gate, the plate edges) and gold stars
	# ("spores2"). It keeps the Sporelings, Rootbinders and the Sporemother its floor had.
	{"name": "Starfall Abyss", "wisp": Color(0.85, 0.88, 1.0), "floor": Color(1.0, 1.0, 1.0),
		"grout": Color(0.01, 0.01, 0.03), "grime": Color(0.13, 0.12, 0.17), "grime_amount": 0.6,
		"patch_tint": Color(0.9, 0.9, 1.0), "patch_rough": 0.4,
		"spores": Color(0.55, 0.68, 1.0, 1.0), "spores2": Color(1.0, 0.82, 0.5),
		"wall": Color(0.12, 0.12, 0.15), "trim": Color(0.28, 0.29, 0.33),
		# (Version 387, review of v383 fix 8: darker, so its stars and star gate shine; it read washed out.)
		"ambient": Color(0.15, 0.155, 0.2), "fog": Color(0.02, 0.02, 0.05), "background": Color(0.006, 0.007, 0.02),
		"moon": Color(0.7, 0.74, 0.88), "torch": Color(0.62, 0.78, 1.0), "torch_energy": 1.3, "pool": 0.5,
		# Star dust drifting down out of the dark, a little of it gold.
		"motes": [Color(0.85, 0.9, 1.0, 0.6), Color(1.0, 0.85, 0.55, 0.35)], "motes_fall": true, "motes_size": 0.35,
		# Version 269 (hard review fix 3): its own skeleton, the Void Walker (it borrowed the
		# Grotto's Sporelings and Rootbinders before).
		"pebble": Color(0.46, 0.47, 0.55), "guests": "v",
		# Version 268 (hard review fix 2): its own boss, the Star Eater (was the Sporemother).
		"boss": "A",
		"banner": Color(0.7, 0.75, 1.0),
		# Version 264: its own cover (props.gd add_cover): open moonstone coffins with their
		# lids floating over them for crates, great bells fallen out of the dark for barrels.
		"cover": "abyss",
		"floor_style": 11, "props": "abyss", "pillar": "drift", "light": [1.3, 1.6, 0.0, 0.0]},
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
## The Clockwork Foundry: floor 9, the fourth floor of each Crypt Pass loop (version 250).
const FOUNDRY := 10
## The Starfall Abyss: floor 10, the last floor of each Crypt Pass loop (version 255).
const ABYSS := 11
## The free floors (1-5) in order: Bone, Frozen, Ember, Grotto, and the Sandfall Tomb.
const FREE_ORDER := [0, 1, 2, GROTTO, SANDFALL]
## Each loop of the Crypt Pass (5 floors, see Loops): the Drowned Vault first, then (version
## 248) the Amethyst Mine where the Bone Crypt came back relit, (version 249) the Whispering
## Library where the Frozen Ossuary did and (version 250) the Clockwork Foundry where the
## Ember Catacomb did, and (version 255) the Starfall Abyss where floor 4's Glowcap Grotto
## came back.
const PASS_ORDER := [DROWNED, MINE, LIBRARY, FOUNDRY, ABYSS]


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
	if f > REMIX_FROM:
		return REMIX_ORDER[(f - REMIX_FROM - 1) % REMIX_ORDER.size()]
	return PASS_ORDER[(f - Store.FREE_FLOORS - 1) % PASS_ORDER.size()]


## Version 299 (deep review fix 7, the endless remix): loops 3 and on (floor 11+) were floors
## 6-10 again, only darker. Now they go round all nine places that have a danger of their
## own (so the free crypts and their bosses come back too, five floors a loop, so each loop
## starts somewhere new), and each floor brings a second place's danger along with its own
## (REMIX_PARTNER: two partners per place, taking turns by loop).
const REMIX_FROM := 10
## Version 304 (Supercell review fix 1): the Bone Crypt joins the round (it has no danger of
## its own, so it brings one guest danger), so the Skeleton King and his King's Leap come back
## too; ten places, so each place takes turns between its two partners by how many times the
## round has gone by (remix_partner), not by loop, or every place would always get the same one.
const REMIX_ORDER := [1, 2, GROTTO, SANDFALL, DROWNED, 0, MINE, LIBRARY, FOUNDRY, ABYSS]
const REMIX_PARTNER := {
	0: [LIBRARY, SANDFALL],       # the Bone Crypt + rolling shelves / quicksand
	1: [FOUNDRY, ABYSS],          # black ice + magnets / loose plates
	2: [MINE, DROWNED],           # fire seams + gas / the tide
	GROTTO: [SANDFALL, LIBRARY],  # bounce caps + quicksand / rolling shelves
	SANDFALL: [ABYSS, FOUNDRY],   # quicksand + loose plates / magnets
	DROWNED: [1, GROTTO],         # the tide + black ice / bounce caps
	MINE: [2, SANDFALL],          # gas + fire seams / quicksand
	LIBRARY: [1, MINE],           # rolling shelves + black ice / gas
	FOUNDRY: [GROTTO, 2],         # magnets + bounce caps / fire seams
	ABYSS: [DROWNED, 1],          # loose plates + the tide / black ice
}
## The one word for each place's danger, for the floor's banner.
const DANGER_WORD := {1: "Black Ice", 2: "Fire Seams", GROTTO: "Bounce Caps", SANDFALL: "Quicksand",
	DROWNED: "The Tide", MINE: "Mine Gas", LIBRARY: "Rolling Shelves", FOUNDRY: "Magnets", ABYSS: "Loose Plates"}


## The place whose danger joins this floor's own in the remix, or -1.
static func remix_partner(floor_num: int) -> int:
	if Game.event != "" or lobby or floor_num <= REMIX_FROM:
		return -1
	var pair: Array = REMIX_PARTNER.get(index(floor_num), [])
	var round := (floor_num - REMIX_FROM - 1) / REMIX_ORDER.size()
	return -1 if pair.is_empty() else int(pair[round % 2])


static func theme(floor_num: int) -> Dictionary:
	var t: Dictionary = THEMES[index(floor_num)]
	var loop := Loops.loop_of(floor_num)
	if remixed(floor_num):
		t = t.duplicate()
		t.merge(PASS_REMIX[index(floor_num)], true)
	# Version 387 (visual review of v383, fix 8): the endless remix and the Daily Crypt were
	# the same places again, only darker and redder (floor 12 read as a muddy floor 3). Each
	# place now comes back in its own light, and the Daily Crypt has a violet-and-gold one.
	var own := Game.event == "" and not lobby
	if own and floor_num > REMIX_FROM and REMIX_LOOK.has(index(floor_num)):
		t = t.duplicate()
		t.merge(REMIX_LOOK[index(floor_num)], true)
		return t if loop <= 1 else _deeper(t, loop, true)
	if own and Game.daily:
		# Version 396 (visual review of v388, fix 9): the Daily Crypt is its own place, the
		# Sundial Court: its own floor, walls, props and cover. The day's three floors are its
		# dawn, noon and dusk, and each day has its own weather (Curses.weather).
		t = t.duplicate()
		t.merge(DAILY_LOOK, true)
		t.merge(DAILY_HOURS[clampi(floor_num - 1, 0, DAILY_HOURS.size() - 1)], true)
		t.merge(Curses.weather(Game._daily_date).get("look", {}), true)
	return t if loop <= 1 else _deeper(t, loop)


## Version 387: each place's own light when it comes back in the endless remix (floor 11+).
## Names stay close to the place's own, so a player knows where they are.
const REMIX_LOOK := {
	0: {"name": "Gilded Crypt", "ambient": Color(0.23, 0.2, 0.15), "moon": Color(0.95, 0.8, 0.5), "torch": Color(1.0, 0.8, 0.38),
		"motes": [Color(1.0, 0.85, 0.4, 0.6), Color(1.0, 0.95, 0.75, 0.25)], "banner": Color(1.0, 0.82, 0.4)},
	1: {"name": "Twilight Ossuary", "ambient": Color(0.26, 0.21, 0.36), "moon": Color(0.8, 0.62, 1.0), "torch": Color(0.85, 0.62, 1.0),
		"motes": [Color(0.85, 0.7, 1.0, 0.7), Color(0.6, 0.8, 1.0, 0.3)], "banner": Color(0.82, 0.65, 1.0)},
	# Version 396 (fix 9): floor 12 stands on its own floor, black glass over a furnace
	# (room.gd floor style 13), between walls of glass with furnace doors.
	2: {"name": "Bluefire Catacomb", "floor_style": 13, "floor": Color(0.26, 0.3, 0.4), "seams": Color(0.15, 0.5, 1.0), "ambient": Color(0.16, 0.18, 0.26), "moon": Color(0.55, 0.7, 1.0),
		"torch": Color(0.45, 0.7, 1.0), "fog": Color(0.02, 0.04, 0.09), "background": Color(0.01, 0.015, 0.04),
		"motes": [Color(0.45, 0.75, 1.0, 0.55), Color(0.3, 0.45, 1.0, 0.2)], "banner": Color(0.5, 0.75, 1.0)},
	DROWNED: {"name": "Sunken Gold Vault", "ambient": Color(0.24, 0.22, 0.15), "moon": Color(1.0, 0.86, 0.55), "torch": Color(1.0, 0.8, 0.45),
		"motes": [Color(1.0, 0.88, 0.5, 0.6), Color(0.6, 1.0, 0.9, 0.25)], "banner": Color(1.0, 0.85, 0.5)},
	GROTTO: {"name": "Bloom Grotto", "spores": Color(1.0, 0.45, 0.8, 1.0), "ambient": Color(0.28, 0.19, 0.27), "moon": Color(1.0, 0.65, 0.85),
		"torch": Color(1.0, 0.58, 0.82), "motes": [Color(1.0, 0.6, 0.85, 0.65), Color(1.0, 0.9, 0.6, 0.25)], "banner": Color(1.0, 0.6, 0.85)},
	SANDFALL: {"name": "Moonlit Tomb", "ambient": Color(0.17, 0.2, 0.3), "moon": Color(0.62, 0.76, 1.0), "torch": Color(0.58, 0.8, 1.0),
		"motes": [Color(0.75, 0.85, 1.0, 0.55), Color(1.0, 0.9, 0.7, 0.2)], "banner": Color(0.65, 0.8, 1.0)},
	MINE: {"name": "Emerald Mine", "ambient": Color(0.15, 0.25, 0.19), "moon": Color(0.55, 1.0, 0.7), "torch": Color(0.55, 1.0, 0.62),
		"motes": [Color(0.55, 1.0, 0.7, 0.6), Color(0.9, 1.0, 0.7, 0.25)], "banner": Color(0.55, 1.0, 0.7)},
	LIBRARY: {"name": "Candlelit Library", "ambient": Color(0.27, 0.19, 0.13), "moon": Color(1.0, 0.72, 0.45), "torch": Color(1.0, 0.62, 0.3),
		"motes": [Color(1.0, 0.7, 0.35, 0.55), Color(1.0, 0.9, 0.7, 0.25)], "banner": Color(1.0, 0.7, 0.4)},
	FOUNDRY: {"name": "Frozen Foundry", "ambient": Color(0.16, 0.21, 0.27), "moon": Color(0.62, 0.82, 1.0), "torch": Color(0.5, 0.88, 1.0),
		"motes": [Color(0.75, 0.92, 1.0, 0.6), Color(0.5, 0.8, 1.0, 0.25)], "motes_fall": true, "banner": Color(0.6, 0.88, 1.0)},
	ABYSS: {"name": "Crimson Abyss", "spores": Color(1.0, 0.45, 0.55, 1.0), "ambient": Color(0.25, 0.15, 0.18), "moon": Color(1.0, 0.62, 0.66),
		"torch": Color(1.0, 0.52, 0.56), "motes": [Color(1.0, 0.6, 0.65, 0.55), Color(1.0, 0.85, 0.55, 0.3)], "banner": Color(1.0, 0.6, 0.62)},
}
## Version 387: the Daily Crypt's own light. Version 388: warm gold, like a sunrise (the
## violet of 387 was too close to floor 1's own cool light to tell apart).
const DAILY_LOOK := {"name": "Sundial Court", "floor": Color(0.58, 0.54, 0.46), "floor_style": 12, "props": "dial", "pillar": "sunpost", "cover": "dial",
	"grout": Color(0.07, 0.055, 0.04), "grime": Color(0.34, 0.27, 0.17), "grime_amount": 0.5,
	"wall": Color(0.2, 0.16, 0.11), "trim": Color(0.34, 0.27, 0.18),
	"fog": Color(0.06, 0.045, 0.03), "background": Color(0.03, 0.022, 0.015),
	"ambient": Color(0.27, 0.23, 0.18), "moon": Color(1.0, 0.82, 0.56), "torch": Color(1.0, 0.72, 0.36), "pool": 1.0,
	"torch_energy": 1.4, "light": [1.1, 1.5, 0.4, 0.4],
	"motes": [Color(1.0, 0.84, 0.4, 0.65), Color(1.0, 0.95, 0.7, 0.3)], "motes_fall": false, "motes_size": 1.0, "banner": Color(1.0, 0.8, 0.4)}
## Version 396: the Sundial Court's three floors are its dawn, noon and dusk: the brass hand
## on the floor points at the hour ("hour", room.gd floor style 12) and the light follows.
const DAILY_HOURS := [
	{"name": "Sundial Court at Dawn", "hour": 0.0},
	{"name": "Sundial Court at Noon", "hour": 0.5, "ambient": Color(0.29, 0.26, 0.19), "moon": Color(1.0, 0.92, 0.7), "torch": Color(1.0, 0.8, 0.45)},
	{"name": "Sundial Court at Dusk", "hour": 1.0, "ambient": Color(0.23, 0.2, 0.28), "moon": Color(0.95, 0.78, 0.74), "torch": Color(1.0, 0.6, 0.42), "pool": 0.6,
		"floor_tint": Color(0.8, 0.74, 0.9),
		"banner": Color(1.0, 0.62, 0.5)},
]


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
## Version 304: not in the endless remix (floor 11+), where a place comes back as itself
## (the review found floors 11 and 12 were the Pass's relit Aurora and Ashen crypts, and the
## Bone Crypt would have come back as the Moonlit Crypt instead of the King's own).
static func remixed(floor_num: int) -> bool:
	return Game.event == "" and not lobby and floor_num > Store.FREE_FLOORS and floor_num <= REMIX_FROM \
			and PASS_REMIX.has(index(floor_num))


## Every endless loop is a little darker and redder than the one before (down to loop 4).
static func _deeper(t: Dictionary, loop: int, own_light := false) -> Dictionary:
	var steps := mini(loop - 1, 3)
	var dark := pow(0.86, steps)
	# (Version 387: a place in its own remix light only darkens a little, and keeps its colour.)
	if own_light:
		dark = pow(0.94, steps)
	var red := 0.0 if own_light else 0.14 * steps
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


## The Ember Catacomb (the Cinder Colossus's floor; on the Pass the Clockwork Foundry names
## its boss with its own "boss" key instead, see Game.boss_kind).
static func ember() -> bool:
	return index(Game.floor_num) == 2 and Game.event == "" and not lobby


## The Blood Moon crypt (the event).
static func blood_moon() -> bool:
	return index(Game.floor_num) == BLOOD_MOON


## Frostfall Hall (the winter event).
static func frostfall() -> bool:
	return index(Game.floor_num) == FROSTFALL


## The Drowned Vault (Crypt Pass floors only).
static func drowned() -> bool:
	return index(Game.floor_num) == DROWNED


## The Glowcap Grotto (floor 4; until version 255 every fifth floor from 10 too).
static func grotto() -> bool:
	return index(Game.floor_num) == GROTTO


## The Sandfall Tomb (floor 5).
static func sandfall() -> bool:
	return index(Game.floor_num) == SANDFALL
