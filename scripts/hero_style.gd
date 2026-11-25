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

## Version 172: every Mastery outfit has its own woven pattern too ("pat" 21-32: brocade,
## leaf scales, stars, pearl, smoke, pinstripes, coals, hoarfrost, petals, waves, polished
## gold, bone plates); they were plain recolours of the cloth before.
## Outfit colours: the cloth ("a"), the trim ("b": the Mage's cape lining and collar, the
## Barbarian's shirt), the Knight's armour and the Rogue's leather. null = as painted.
const OUTFITS := {
	"crimson": {"name": "Velvet", "a": Color(0.3, 0.13, 0.09), "b": Color(1.0, 0.8, 0.32), "armor": Color(0.38, 0.17, 0.11), "leather": Color(0.24, 0.17, 0.14), "pat": 21},
	"forest": {"name": "Forest", "a": Color(0.16, 0.46, 0.2), "b": Color(0.85, 0.7, 0.3), "armor": Color(0.28, 0.54, 0.26), "leather": Color(0.5, 0.33, 0.18), "pat": 22},
	"midnight": {"name": "Midnight", "a": Color(0.11, 0.13, 0.32), "b": Color(0.82, 0.86, 0.95), "armor": Color(0.2, 0.26, 0.62), "pat": 23},
	"ivory": {"name": "Ivory", "a": Color(0.94, 0.91, 0.83), "b": Color(0.35, 0.6, 0.95), "armor": Color(0.88, 0.88, 0.86), "leather": Color(0.62, 0.45, 0.3), "pat": 24},
	"shadow": {"name": "Shadow", "a": Color(0.14, 0.12, 0.17), "b": Color(0.6, 0.25, 0.9), "armor": Color(0.2, 0.19, 0.23), "leather": Color(0.16, 0.14, 0.16), "pat": 25},
	"royal": {"name": "Royal", "a": Color(0.44, 0.17, 0.7), "b": Color(1.0, 0.78, 0.3), "armor": Color(0.55, 0.3, 0.85), "pat": 26},
	"ember": {"name": "Ember", "a": Color(0.17, 0.14, 0.15), "b": Color(1.0, 0.5, 0.12), "armor": Color(0.22, 0.19, 0.2), "pat": 27},
	"frost": {"name": "Frost", "a": Color(0.55, 0.85, 1.0), "b": Color(0.95, 0.97, 1.0), "armor": Color(0.6, 0.88, 1.0), "pat": 28},
	"rose": {"name": "Lilac", "a": Color(0.74, 0.66, 1.0), "b": Color(1.0, 0.95, 1.0), "armor": Color(0.7, 0.64, 0.98), "leather": Color(0.55, 0.34, 0.28), "pat": 29},
	"sea": {"name": "Sea", "a": Color(0.1, 0.55, 0.6), "b": Color(1.0, 0.78, 0.3), "armor": Color(0.2, 0.66, 0.68), "pat": 30},
	"gold": {"name": "Gilded", "a": Color(0.95, 0.75, 0.25), "b": Color(1.0, 0.97, 0.9), "armor": Color(0.95, 0.76, 0.3), "leather": Color(0.45, 0.3, 0.16), "pat": 31},
	"bone": {"name": "Bone", "a": Color(0.86, 0.83, 0.74), "b": Color(0.2, 0.2, 0.23), "armor": Color(0.84, 0.8, 0.68), "leather": Color(0.2, 0.19, 0.2), "pat": 32},
	# Version 132, the Legend road (Mastery 12, 17 and 19): outfits with their own moving
	# pattern, like Feat outfits ("pat", the outfit shader).
	"diamond": {"name": "Diamond", "a": Color(0.86, 0.88, 0.94), "b": Color(0.55, 0.62, 0.8), "armor": Color(0.8, 0.83, 0.9), "leather": Color(0.4, 0.44, 0.56), "pat": 11},
	"mythic": {"name": "Mythic", "a": Color(0.04, 0.18, 0.22), "b": Color(0.4, 0.9, 1.0), "armor": Color(0.06, 0.24, 0.28), "leather": Color(0.08, 0.12, 0.14), "pat": 12},
	"legend": {"name": "Legend", "a": Color(0.22, 0.08, 0.05), "b": Color(1.0, 0.8, 0.35), "armor": Color(0.3, 0.12, 0.07), "leather": Color(0.3, 0.12, 0.08), "pat": 13},
}

## Each hero's own colours, for the Classic outfit's swatch on the Style screen.
const CLASSIC_OUTFIT := {"rogue": Color(0.2, 0.4, 0.85), "knight": Color(0.85, 0.2, 0.25), "barbarian": Color(0.45, 0.36, 0.28), "mage": Color(0.45, 0.4, 0.7)}
const CLASSIC_TRIM := {"rogue": Color(0.6, 0.38, 0.25), "knight": Color(0.7, 0.72, 0.78), "barbarian": Color(0.4, 0.55, 0.65), "mage": Color(0.7, 0.15, 0.5)}

## Head looks. hat: keep the hero's own hat or helmet; borrow: wear another hero's;
## extras: a crown, horns or a halo.
const HEADS := {
	"bare": {"name": "Bare head", "hat": false},
	"crown": {"name": "Crown", "hat": false, "extras": ["crown"]},
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
		"frostforged": {"name": "Frostforged crossbow", "hide": ["1H_Crossbow"], "show": ["2H_Crossbow"], "finish": "frost"},
		"emberforged": {"name": "Emberforged knives", "hide": ["1H_Crossbow"], "show": ["Knife", "Knife_Offhand"], "finish": "ember"},
	},
	"knight": {
		"badge": {"name": "Crest shield", "hide": ["Round_Shield"], "show": ["Badge_Shield"]},
		"spike": {"name": "Spiked shield", "hide": ["Round_Shield"], "show": ["Spike_Shield"]},
		"tower": {"name": "Tower shield", "hide": ["Round_Shield"], "show": ["Rectangle_Shield"]},
		"greatsword": {"name": "Greatsword", "hide": ["1H_Sword", "Round_Shield"], "show": ["2H_Sword"]},
		"twin_swords": {"name": "Twin swords", "hide": ["Round_Shield"], "show": ["1H_Sword_Offhand"]},
		"frostforged": {"name": "Frostforged sword and shield", "hide": ["Round_Shield"], "show": ["Badge_Shield"], "finish": "frost"},
		"emberforged": {"name": "Emberforged greatsword", "hide": ["1H_Sword", "Round_Shield"], "show": ["2H_Sword"], "finish": "ember"},
	},
	"barbarian": {
		"twin_axes": {"name": "Twin axes", "show": ["1H_Axe_Offhand"]},
		"axe_shield": {"name": "Axe and shield", "show": ["Barbarian_Round_Shield"]},
		"great_axe": {"name": "Great axe", "hide": ["1H_Axe"], "show": ["2H_Axe"]},
		"tankard": {"name": "Axe and tankard", "show": ["Mug"]},
		"frostforged": {"name": "Frostforged twin axes", "show": ["1H_Axe_Offhand"], "finish": "frost"},
		"emberforged": {"name": "Emberforged great axe", "hide": ["1H_Axe"], "show": ["2H_Axe"], "finish": "ember"},
	},
	"mage": {
		"wand": {"name": "Wand", "hide": ["2H_Staff"], "show": ["1H_Wand"]},
		"tome": {"name": "Wand and tome", "hide": ["2H_Staff"], "show": ["1H_Wand", "Spellbook"]},
		"open_tome": {"name": "Open spellbook", "hide": ["2H_Staff"], "show": ["1H_Wand", "Spellbook_open"]},
		"frostforged": {"name": "Frostforged staff", "finish": "frost"},
		"emberforged": {"name": "Emberforged wand and tome", "hide": ["2H_Staff"], "show": ["1H_Wand", "Spellbook_open"], "finish": "ember"},
	},
}

## A weapon finish any hero can carry (EXTRA "hold", version 172): it is worn on the hero's
## grandest weapon (the parts hidden and shown for it).
const GRAND := {
	"rogue": {"hide": ["1H_Crossbow"], "show": ["2H_Crossbow", "Knife_Offhand"]},
	"knight": {"hide": ["1H_Sword", "Round_Shield"], "show": ["2H_Sword"]},
	"barbarian": {"hide": ["1H_Axe"], "show": ["2H_Axe"]},
	"mage": {},
}

## (Version 175: the red looks were moved off red-pink too. Crimson and Blood Moon are a
## blood orange-red, Rose is a rose-gold peach, and the Blood Eclipse shots are gold.)
## Glow: the ring at the hero's feet, the glow on their edges and their shots. None is
## red-pink, which is what danger looks like (ShotLook.DANGER).
## Version 232 (whole-game review, fix 9): no two glows look alike any more. Each glow has
## its own main colour, or its own second colour where two share one; a second colour now
## shows on wide arcs of the ring (LookFx "two"). Inferno burns purple and orange (it was
## Ember again), Silver Moon is night blue and silver like its outfit (it was Silver), Mythic
## orchid with cyan (Violet), Diamond white with cyan (Frost), Sulfur yellow with blue (Lime),
## Abyss deep blue with sea green (Azure), Candlelight gold with white flames (Gold). The
## glows that were near-twins of a free one got a second colour too: Aurora green and violet,
## Eclipse indigo and cyan, Venom lime and purple, Mirage aqua and sand, Glacier ice and deep
## blue, Spectral pale green and white, Sapphire blue and gold, Photon white and orchid.
const GLOWS := {
	"emerald": {"name": "Emerald", "fx": "flow", "ring": Color(0.3, 1.0, 0.55), "bolt": Color(0.55, 1.0, 0.7)},
	"azure": {"name": "Azure", "fx": "wave", "ring": Color(0.4, 0.68, 1.0), "bolt": Color(0.62, 0.84, 1.0)},
	"ember": {"name": "Ember", "fx": "flame", "ring": Color(1.0, 0.52, 0.16), "bolt": Color(1.0, 0.68, 0.28)},
	"frost": {"name": "Frost", "fx": "frost", "ring": Color(0.4, 0.94, 1.0), "bolt": Color(0.62, 1.0, 1.0)},
	"gold": {"name": "Gold", "fx": "stars", "ring": Color(1.0, 0.82, 0.3), "bolt": Color(1.0, 0.9, 0.55)},
	"violet": {"name": "Violet", "fx": "runes", "ring": Color(0.58, 0.45, 1.0), "bolt": Color(0.84, 0.66, 1.0)},
	"silver": {"name": "Silver", "fx": "beads", "ring": Color(0.86, 0.9, 1.0), "bolt": Color(1.0, 1.0, 1.0)},
	"lime": {"name": "Lime", "fx": "storm", "ring": Color(0.72, 1.0, 0.3), "bolt": Color(0.86, 1.0, 0.55)},
	# Version 132, the Legend road (Mastery 11, 16 and 18): glows that shimmer between two
	# colours on the hero's edges ("ring2"), bright like Feat glows.
	"diamond": {"name": "Diamond", "fx": "flow", "ring": Color(0.95, 0.97, 1.0), "ring2": Color(0.3, 0.9, 1.0), "bolt": Color(0.92, 1.0, 1.0)},
	"mythic": {"name": "Mythic", "fx": "storm", "ring": Color(0.92, 0.4, 1.0), "ring2": Color(0.3, 0.92, 1.0), "bolt": Color(0.92, 0.7, 1.0)},
	"legend": {"name": "Legend", "fx": "rays", "ring": Color(1.0, 0.5, 0.18), "ring2": Color(1.0, 0.86, 0.32), "bolt": Color(1.0, 0.82, 0.45)},
}

## Master auras: looks only one hero has, one at each of Mastery levels 8, 9 and 10. An aura
## colours the hero's outline (ink; ink2 makes it pulse between two colours, cycle runs it
## through the colours of the rainbow, skipping red-pink), the dash ring and dash trail, and
## gives the hero their own trail of light (MOTIFS): the Rogue's shadow wisps, the Knight's
## rising motes, the Barbarian's embers, the Mage's stars. All of it reads from the top-down
## camera, where hats and outfits are small.
## Version 252 (whole-game review fix 6): the level-20 auras, the top Mastery prize, each have
## a colour and a shape of their own (they were all one orange-gold column): the Rogue's
## Nightlord shadow daggers circling him (violet and silver), the Knight's Lionheart mane of
## gold flame round his head, the Barbarian's Worldbreaker lightning striking the floor
## round him (electric cyan and violet), the Mage's Starsage gold stars running round two
## turning green rings. Their "motif" names the shape (Fx.motif).
const AURAS := {
	"rogue": {
		"nightshade": {"name": "Nightshade", "level": 8, "shell": 0, "ink": Color(0.52, 0.34, 1.0), "spark": Color(0.68, 0.56, 1.0)},
		"venom": {"name": "Venom", "level": 9, "shell": 4, "ink": Color(0.42, 1.0, 0.22), "spark": Color(0.66, 1.0, 0.36)},
		"shadow_king": {"name": "Shadow King", "level": 10, "shell": 1, "ink": Color(1.0, 0.76, 0.22), "ink2": Color(0.58, 0.24, 1.0), "spark": Color(1.0, 0.84, 0.4)},
		"duskblade": {"name": "Duskblade", "level": 15, "shell": 2, "ink": Color(0.7, 0.3, 1.0), "ink2": Color(0.3, 0.95, 1.0), "spark": Color(0.75, 0.6, 1.0)},
		"nightlord": {"name": "Nightlord", "level": 20, "shell": 0, "ink": Color(0.6, 0.3, 1.0), "ink2": Color(0.9, 0.93, 1.0), "shine": true, "spark": Color(0.86, 0.84, 1.0), "motif": "blades"},
	},
	"knight": {
		"sunguard": {"name": "Sunguard", "level": 8, "shell": 1, "ink": Color(1.0, 0.64, 0.16), "spark": Color(1.0, 0.8, 0.4)},
		"stormplate": {"name": "Stormplate", "level": 9, "shell": 3, "ink": Color(0.3, 0.64, 1.0), "spark": Color(0.72, 0.88, 1.0)},
		"paladin": {"name": "Paladin", "level": 10, "shell": 4, "ink": Color(1.0, 0.97, 0.86), "ink2": Color(1.0, 0.72, 0.2), "spark": Color(1.0, 0.86, 0.45)},
		"dawnshield": {"name": "Dawnshield", "level": 15, "shell": 2, "ink": Color(0.85, 0.97, 1.0), "ink2": Color(0.4, 0.75, 1.0), "spark": Color(0.85, 0.95, 1.0)},
		"lionheart": {"name": "Lionheart", "level": 20, "shell": 1, "ink": Color(1.0, 0.58, 0.12), "ink2": Color(1.0, 0.93, 0.62), "shine": true, "spark": Color(1.0, 0.82, 0.4), "motif": "mane"},
	},
	"barbarian": {
		"wildfire": {"name": "Wildfire", "level": 8, "shell": 0, "ink": Color(1.0, 0.46, 0.08), "spark": Color(1.0, 0.62, 0.22)},
		"thunder": {"name": "Thunder", "level": 9, "shell": 4, "ink": Color(1.0, 0.94, 0.25), "spark": Color(1.0, 1.0, 0.62)},
		"warlord": {"name": "Warlord", "level": 10, "shell": 1, "ink": Color(1.0, 0.42, 0.06), "ink2": Color(0.35, 0.85, 1.0), "spark": Color(1.0, 0.72, 0.3)},
		"stormrage": {"name": "Stormrage", "level": 15, "shell": 3, "ink": Color(0.35, 0.6, 1.0), "ink2": Color(0.95, 0.95, 1.0), "spark": Color(0.7, 0.85, 1.0)},
		"worldbreaker": {"name": "Worldbreaker", "level": 20, "shell": 3, "ink": Color(0.3, 0.95, 1.0), "ink2": Color(0.72, 0.45, 1.0), "shine": true, "spark": Color(0.3, 0.95, 1.0), "motif": "lightning"},
	},
	"mage": {
		"starfire": {"name": "Starfire", "level": 8, "shell": 2, "ink": Color(0.48, 0.5, 1.0), "spark": Color(0.72, 0.76, 1.0)},
		"arcane_frost": {"name": "Arcane Frost", "level": 9, "shell": 4, "ink": Color(0.4, 0.95, 1.0), "spark": Color(0.82, 1.0, 1.0)},
		"archmage": {"name": "Archmage", "level": 10, "shell": 1, "ink": Color(0.58, 0.46, 1.0), "cycle": true, "spark": Color(0.76, 0.7, 1.0)},
		"voidweave": {"name": "Voidweave", "level": 15, "shell": 0, "ink": Color(0.25, 0.3, 1.0), "ink2": Color(0.85, 0.45, 1.0), "spark": Color(0.6, 0.6, 1.0)},
		"starsage": {"name": "Starsage", "level": 20, "shell": 2, "ink": Color(0.25, 1.0, 0.6), "ink2": Color(1.0, 0.86, 0.4), "shine": true, "spark": Color(1.0, 0.86, 0.45), "motif": "orrery"},
	},
}
## Each hero's own trail of light for their auras (Fx.motif).
const MOTIFS := {"rogue": "wisps", "knight": "motes", "barbarian": "embers", "mage": "stars"}

## The Crypt King set: five looks every hero gets with the Crypt Pass, one for each of the
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
	"gold_on": {"rogue": "b", "knight": "none", "barbarian": "none", "mage": "b"}}
const PASS_HEAD := {"name": "Crypt Crown", "hat": false, "extras": ["crypt_crown"], "pass": true}
const PASS_GLOW := {"name": "Crypt Gold", "fx": "crown", "ring": Color(1.0, 0.84, 0.38), "bolt": Color(1.0, 0.92, 0.6), "pass": true}
## The set's weapon (version 198): the hero's grandest weapon in obsidian, edged in gold,
## with teal soul fire burning along it. Until then the paid set carried a plain grey weapon.
## Version 253: whole weapons of their own instead (CryptArms, built by ForgedArms.dress).
const PASS_HOLD := {"name": "Crypt King's arms", "finish": "crypt", "pass": true}
## The aura: a gold outline a white glint runs round, gold crowns of light rising, and a
## turning gold sigil on the floor under the hero, the one thing seen from anywhere in a room.
const PASS_AURA := {"name": "Crypt King", "pass": true, "ink": Color(1.0, 0.78, 0.22), "ink2": Color(1.0, 0.95, 0.72),
	"spark": Color(1.0, 0.86, 0.42), "motif": "regal", "shine": true, "sigil": true}

## Feat and Bone Drop looks: any hero can wear them. A Feat look is earned by its challenge
## (feats.gd: "feat" is the Feat), a drop look only comes out of a Bone Drop (drops.gd:
## "drop" is the drop's rarity). Outfits here have their own animated pattern ("pat", drawn
## by the outfit shader over the cloth and trim); heads are built by feat_heads.gd.
const EXTRA := {
	"outfit": {
		"bonecarved": {"name": "Bonecarved", "a": Color(0.88, 0.85, 0.76), "b": Color(0.2, 0.19, 0.22), "pat": 6, "feat": "centurion"},
		"frostbite": {"name": "Frostbite", "a": Color(0.3, 0.6, 0.95), "b": Color(0.95, 0.98, 1.0), "pat": 4, "feat": "halfway"},
		"magma": {"name": "Cinder Ice", "a": Color(0.12, 0.15, 0.22), "b": Color(0.62, 0.84, 1.0), "pat": 2, "feat": "laststand"},
		"ghostwalk": {"name": "Ghostwalk", "a": Color(0.27, 0.3, 0.33), "b": Color(0.82, 1.0, 0.95), "pat": 1, "feat": "cleankill"},
		"thunder": {"name": "Thunder", "a": Color(0.32, 0.33, 0.36), "b": Color(1.0, 0.86, 0.3), "pat": 5, "feat": "highscore"},
		"shadowflame": {"name": "Shadowflame", "a": Color(0.06, 0.07, 0.13), "b": Color(0.25, 0.58, 1.0), "pat": 7, "feat": "faithful"},
		"starweave": {"name": "Starweave", "a": Color(0.34, 0.38, 0.8), "b": Color(0.95, 0.8, 0.35), "pat": 3, "feat": "flawless"},
		"toxic": {"name": "Toxic", "a": Color(0.55, 0.78, 0.08), "b": Color(0.24, 0.08, 0.34), "pat": 8, "drop": 3},
		"prism": {"name": "Prism", "a": Color(0.92, 0.92, 0.96), "b": Color(0.36, 0.3, 0.62), "pat": 9, "drop": 3},
		"abyssal": {"name": "Abyssal", "a": Color(0.05, 0.17, 0.32), "b": Color(0.2, 0.86, 0.8), "pat": 10, "drop": 3},
		# The Blood Moon event set (events.gd, version 134): "event" is the event's id.
		"blood_moon": {"name": "Blood Moon", "a": Color(0.2, 0.12, 0.42), "b": Color(1.0, 0.76, 0.38), "pat": 14, "event": "blood_moon"},
		# Version 219 (review 4 fix 26): the Silver Moon set, the event road's Crypt Pass row
		# ("passroad"). Night blue and moon silver, so it never reads as a red danger mark.
		"silver_moon": {"name": "Silver Moon", "a": Color(0.06, 0.16, 0.4), "b": Color(0.84, 0.9, 1.0), "pat": 14, "own": true, "event": "blood_moon", "passroad": true},
		# Version 244: the Frostfall set (the winter event's road) and its Pass row, Polar
		# Night. Each has a pattern of its own: a knitted jumper strung with fairy lights, and
		# night cloth with the northern lights rippling up it.
		"yule_knit": {"name": "Yule Knit", "a": Color(0.05, 0.3, 0.17), "b": Color(0.97, 0.93, 0.84), "pat": 37, "own": true, "event": "frostfall"},
		"polar_night": {"name": "Polar Night", "a": Color(0.03, 0.06, 0.2), "b": Color(0.3, 1.0, 0.7), "pat": 38, "own": true, "event": "frostfall", "passroad": true},
		# The Bone Bazaar (bazaar.gd, version 152): "bazaar" is the price in coins.
		"tidecaller": {"name": "Tidecaller", "a": Color(0.93, 0.7, 0.38), "b": Color(0.08, 0.66, 0.72), "pat": 33, "own": true, "bazaar": 900},
		"sunforged": {"name": "Sunforged", "a": Color(0.8, 0.42, 0.08), "b": Color(1.0, 0.72, 0.2), "pat": 34, "own": true, "bazaar": 900},
		"plaguebone": {"name": "Plaguebone", "a": Color(0.07, 0.15, 0.09), "b": Color(0.85, 0.95, 0.25), "pat": 35, "own": true, "bazaar": 900},
		"nightbloom": {"name": "Nightbloom", "a": Color(0.02, 0.36, 0.2), "b": Color(0.72, 0.42, 1.0), "pat": 36, "own": true, "bazaar": 900},
		# The Crypt Race (race.gd, version 153): "race" is the Race Road step's trophies.
		"pacesetter": {"name": "Pacesetter", "a": Color(0.1, 0.1, 0.13), "b": Color(1.0, 0.5, 0.1), "pat": 15, "race": 275},
		"crystal_sprint": {"name": "Crystal Sprint", "a": Color(0.05, 0.12, 0.26), "b": Color(0.45, 0.95, 1.0), "pat": 16, "race": 900},
	},
	"head": {
		"storm_halo": {"name": "Storm Halo", "hat": true, "extras": ["storm_halo"], "feat": "bossbreaker"},
		"star_circlet": {"name": "Star Circlet", "hat": false, "extras": ["star_circlet"], "feat": "fourheroes"},
		"flame_crown": {"name": "Flame Horns", "hat": false, "extras": ["flame_crown"], "feat": "conqueror"},
		"skull_helm": {"name": "Skull Helm", "hat": false, "hide_head": true, "extras": ["skull_helm"], "feat": "legend"},
		"antlers": {"name": "Antlers", "hat": false, "extras": ["antlers"], "drop": 4},
		"phantom_horns": {"name": "Phantom Horns", "hat": false, "extras": ["phantom_horns"], "drop": 4},
		"bone_crown": {"name": "Bone Mask", "hat": false, "extras": ["bone_crown"], "drop": 4},
		"moon_crown": {"name": "Moon Crown", "hat": false, "extras": ["moon_crown"], "event": "blood_moon"},
		"candle_crown": {"name": "Candle Crown", "hat": false, "extras": ["candle_crown"], "event": "frostfall"},
	},
	"glow": {
		"mirage": {"name": "Mirage", "fx": "storm", "ring": Color(0.35, 1.0, 0.95), "ring2": Color(1.0, 0.8, 0.45), "bolt": Color(1.0, 1.0, 1.0), "feat": "dodger"},
		"inferno": {"name": "Inferno", "fx": "flame", "ring": Color(0.6, 0.22, 1.0), "ring2": Color(1.0, 0.55, 0.15), "bolt": Color(0.85, 0.6, 1.0), "feat": "linked"},
		"glacier": {"name": "Glacier", "fx": "rays", "ring": Color(0.72, 0.88, 1.0), "ring2": Color(0.15, 0.3, 0.95), "bolt": Color(0.4, 0.75, 1.0), "feat": "untouched"},
		"aurora": {"name": "Aurora", "fx": "wave", "ring": Color(0.35, 1.0, 0.6), "ring2": Color(0.55, 0.45, 1.0), "bolt": Color(0.75, 0.5, 1.0), "feat": "blessed"},
		"eclipse": {"name": "Eclipse", "fx": "eclipse", "ring": Color(0.42, 0.28, 1.0), "ring2": Color(0.3, 0.92, 1.0), "bolt": Color(1.0, 0.82, 0.3), "drop": 2},
		"venom": {"name": "Venom", "fx": "beads", "ring": Color(0.7, 1.0, 0.15), "ring2": Color(0.8, 0.3, 1.0), "bolt": Color(0.7, 0.35, 1.0), "drop": 2},
		"abyss": {"name": "Abyss", "fx": "wave", "ring": Color(0.1, 0.22, 0.85), "ring2": Color(0.35, 1.0, 0.55), "bolt": Color(0.5, 1.0, 0.7), "drop": 2},
		# Moon-white edges shimmering to blood-moon orange; pale moonlight shots.
		"moonlight": {"name": "Moonlight", "fx": "beads", "ring": Color(1.0, 0.9, 0.65), "ring2": Color(1.0, 0.48, 0.12), "bolt": Color(1.0, 0.94, 0.82), "event": "blood_moon"},
		"silver_moon": {"name": "Silver Moon", "fx": "eclipse", "ring": Color(0.22, 0.32, 0.95), "ring2": Color(0.9, 0.93, 1.0), "bolt": Color(0.9, 0.95, 1.0), "event": "blood_moon", "passroad": true},
		# Version 142: the Queen Hunt's ECLIPSE prize (Events.ECLIPSE_LOOK). A dark blood-orange
		# ring with a night-violet crescent (version 232; it was gold, the Legend glow's colours).
		"blood_eclipse": {"name": "Blood Eclipse", "fx": "eclipse", "ring": Color(0.72, 0.3, 0.03), "ring2": Color(0.5, 0.22, 0.95), "bolt": Color(1.0, 0.62, 0.28), "event": "blood_moon", "hunt": true},
		# Frostfall (version 244): frost white and candle gold with snowflakes turning round the
		# ring; the Pass row's northern lights hanging off it; and the Krampus Hunt's WHITEOUT
		# prize, a blizzard whirling round it.
		"snowbound": {"name": "Snowbound", "fx": "snowflake", "ring": Color(0.86, 0.95, 1.0), "ring2": Color(1.0, 0.8, 0.42), "bolt": Color(0.92, 0.97, 1.0), "event": "frostfall"},
		"polar_night": {"name": "Polar Night", "fx": "aurora", "ring": Color(0.55, 0.95, 1.0), "ring2": Color(0.3, 1.0, 0.5), "bolt": Color(0.6, 1.0, 0.8), "event": "frostfall", "passroad": true},
		"whiteout": {"name": "Whiteout", "fx": "whirl", "ring": Color(1.0, 1.0, 1.0), "ring2": Color(0.3, 0.85, 1.0), "bolt": Color(0.92, 0.98, 1.0), "event": "frostfall", "hunt": true},
		"candle": {"name": "Candlelight", "fx": "flame", "ring": Color(1.0, 0.76, 0.32), "ring2": Color(1.0, 0.97, 0.88), "bolt": Color(1.0, 0.95, 0.8), "bazaar": 450},
		"sulfur": {"name": "Sulfur", "fx": "runes", "ring": Color(1.0, 0.93, 0.2), "ring2": Color(0.3, 0.5, 1.0), "bolt": Color(1.0, 1.0, 0.6), "bazaar": 450},
		"spectral": {"name": "Spectral", "fx": "runes", "ring": Color(0.75, 1.0, 0.62), "ring2": Color(1.0, 1.0, 1.0), "bolt": Color(0.85, 1.0, 0.8), "bazaar": 600},
		"sapphire": {"name": "Sapphire", "fx": "beads", "ring": Color(0.2, 0.45, 1.0), "ring2": Color(1.0, 0.82, 0.35), "bolt": Color(0.6, 0.8, 1.0), "bazaar": 600},
		# Crypt Race glows: Photon (white light with orchid lightning, version 232; it was the
		# blue of Azure and Sapphire), Afterburn (flame orange to jet blue).
		"photon": {"name": "Photon", "fx": "storm", "ring": Color(0.95, 0.95, 1.0), "ring2": Color(0.85, 0.4, 1.0), "bolt": Color(0.95, 0.85, 1.0), "race": 100},
		"afterburn": {"name": "Afterburn", "fx": "wave", "ring": Color(1.0, 0.45, 0.08), "ring2": Color(0.3, 0.75, 1.0), "bolt": Color(1.0, 0.8, 0.45), "race": 800},
	},
	# Weapon finishes sold in the Bone Bazaar (version 172): the hero's grandest weapon in
	# polished gold, or in night-violet steel with stars in it.
	"hold": {
		"gilded": {"name": "Gilded arms", "finish": "gold", "bazaar": 900},
		"voidsteel": {"name": "Voidsteel arms", "finish": "void", "bazaar": 1300},
	},
	"aura": {
		"quickstep": {"name": "Quickstep", "ink": Color(1.0, 0.9, 0.3), "spark": Color(1.0, 0.95, 0.6), "motif": "quick", "feat": "rusher"},
		"arcane": {"name": "Arcane", "ink": Color(0.52, 0.42, 1.0), "ink2": Color(0.35, 0.85, 1.0), "spark": Color(0.7, 0.62, 1.0), "motif": "arcane", "feat": "specialist"},
		"stormcaller": {"name": "Stormcaller", "ink": Color(0.45, 0.75, 1.0), "ink2": Color(1.0, 1.0, 1.0), "spark": Color(0.75, 0.9, 1.0), "motif": "storm", "feat": "chainlord"},
		"phantom": {"name": "Phantom", "ink": Color(0.75, 1.0, 0.95), "spark": Color(0.8, 1.0, 0.95), "motif": "souls", "feat": "perfectionist"},
		"sunflare": {"name": "Sunflare", "ink": Color(1.0, 0.66, 0.15), "ink2": Color(1.0, 0.92, 0.5), "spark": Color(1.0, 0.8, 0.35), "motif": "sun", "feat": "dailywin"},
		"snowfall": {"name": "Snowfall", "ink": Color(0.85, 0.95, 1.0), "spark": Color(1.0, 1.0, 1.0), "motif": "snow", "drop": 3},
		"bubbles": {"name": "Bubbles", "ink": Color(0.4, 1.0, 0.3), "spark": Color(0.6, 1.0, 0.4), "motif": "bubbles", "drop": 3},
		"fireflies": {"name": "Fireflies", "ink": Color(0.85, 1.0, 0.3), "spark": Color(0.95, 1.0, 0.45), "motif": "fireflies", "drop": 3},
		# The set's crown jewel: a blood-red outline pulsing to gold, a swarm of little bats
		# circling the hero, and a blood moon on the floor under them.
		"blood_moon": {"name": "Blood Moon", "ink": Color(1.0, 0.58, 0.12), "ink2": Color(1.0, 0.8, 0.36), "spark": Color(1.0, 0.66, 0.2), "motif": "bats", "shine": true, "event": "blood_moon"},
		"silver_moon": {"name": "Silver Moon", "ink": Color(0.72, 0.82, 1.0), "ink2": Color(0.95, 0.97, 1.0), "spark": Color(0.85, 0.92, 1.0), "motif": "bats", "shine": true, "event": "blood_moon", "passroad": true},
		# Frostfall (version 244): a snow globe round the hero (snowflakes swirling in a glass
		# dome on a gold base, a snowflake on the floor), and the Pass row's northern lights
		# hanging round them under a compass star.
		"snow_globe": {"name": "Snow Globe", "ink": Color(0.78, 0.9, 1.0), "ink2": Color(1.0, 0.82, 0.45), "spark": Color(1.0, 1.0, 1.0), "motif": "globe", "shine": true, "event": "frostfall"},
		"polar_night": {"name": "Polar Night", "ink": Color(0.3, 1.0, 0.7), "ink2": Color(0.68, 0.45, 1.0), "spark": Color(0.6, 1.0, 0.85), "motif": "aurora", "shine": true, "event": "frostfall", "passroad": true},
		"wisp": {"name": "Will-o'-Wisp", "ink": Color(0.35, 0.75, 1.0), "ink2": Color(0.6, 1.0, 0.95), "spark": Color(0.6, 0.9, 1.0), "motif": "fireflies", "bazaar": 1500},
		"golden_souls": {"name": "Golden Souls", "ink": Color(1.0, 0.66, 0.2), "ink2": Color(0.55, 0.9, 1.0), "spark": Color(1.0, 0.86, 0.5), "motif": "souls", "bazaar": 1500},
		# Crypt Race auras: a comet's tail of teal glints streaming behind the hero, and the Bone
		# King league's own, violet and gold, with the shine.
		"comet": {"name": "Comet", "ink": Color(0.3, 0.9, 1.0), "ink2": Color(0.9, 1.0, 1.0), "spark": Color(0.55, 0.95, 1.0), "motif": "comet", "race": 500},
		"bone_comet": {"name": "Bone King Comet", "ink": Color(0.86, 0.52, 1.0), "ink2": Color(1.0, 0.82, 0.35), "spark": Color(1.0, 0.85, 0.5), "motif": "comet", "shine": true, "race": 1400},
		# Version 254 (whole-game review fix 14): the Bone Road's last prize, found nowhere else.
		# A chain of bone vertebrae circling the hero that burns gold, then red-hot, with the
		# run's Bone Chain (Fx.motif "bonechain").
		"bone_chain": {"name": "Bone Chain", "ink": Color(0.55, 0.42, 0.9), "ink2": Color(1.0, 0.78, 0.3), "spark": Color(1.0, 0.9, 0.7), "motif": "bonechain", "shine": true, "road": true},
	},
}
## Each hero's own head (hidden under a Skull Helm).
const HEAD_MESH := {"rogue": "Rogue_Head_Hooded", "knight": "Knight_Head", "barbarian": "Barbarian_Head", "mage": "Mage_Head"}


static func extra(slot: String, key: String) -> Dictionary:
	return EXTRA.get(slot, {}).get(key, {})


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
## The Legend road (version 132): one look at each of these Mastery levels for every hero,
## besides each hero's own auras at 15 and 20 (AURAS). Levels 13 and 14 give the forged
## weapons (version 172).
const LEGEND := {11: ["glow", "diamond"], 12: ["outfit", "diamond"], 13: ["hold", "frostforged"], 14: ["hold", "emberforged"], 16: ["glow", "mythic"],
	17: ["outfit", "mythic"], 18: ["glow", "legend"], 19: ["outfit", "legend"]}


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
	for lv: int in LEGEND:
		var it: Array = LEGEND[lv]
		out.append({"slot": it[0], "key": it[1], "name": item_name(id, it[0], it[1]), "level": lv})
	var auras: Dictionary = AURAS.get(id, {})
	for key: String in auras:
		out.append({"slot": "aura", "key": key, "name": auras[key].name, "level": int(auras[key].level), "only": true})
	for slot: String in EXTRA:
		for key: String in EXTRA[slot]:
			var e: Dictionary = EXTRA[slot][key]
			var it := {"slot": slot, "key": key, "name": e.name, "level": 1}
			if e.has("feat"):
				it.feat = e.feat
			elif e.has("event"):
				it.event = e.event
			elif e.has("bazaar"):
				it.bazaar = int(e.bazaar)
			elif e.has("race"):
				it.race = int(e.race)
			elif e.has("road"):
				it.road = true
			else:
				it.drop = int(e.drop)
			out.append(it)
	for slot: String in PASS_SLOTS:
		out.append({"slot": slot, "key": pass_key(slot), "name": item_name(id, slot, pass_key(slot)), "level": 1, "pass": true})
	return out


## A Mastery look (not a Crypt King, Feat or Bone Drop look).
static func is_mastery(it: Dictionary) -> bool:
	return it.key != "" and not it.get("pass", false) and not is_special(it)


## A Feat, Bone Drop, event or Bone Bazaar look: won or bought, not a Mastery level.
static func is_special(it: Dictionary) -> bool:
	return it.has("feat") or it.has("drop") or it.has("event") or it.has("bazaar") or it.has("race") or it.has("road")


## How much there is to a glow's ring (LookFx.set_ring): 0 a Mastery glow, 1 a Feat, Bone
## Drop or Bazaar glow, 2 a Legend road, Crypt Race, event or Crypt King glow.
## The Barbarian's tunic is the big block of his chest. Given an outfit's trim colour it
## became a yellow bib on every gold-trimmed outfit, so it takes a brighter shade of the
## main colour with only a touch of the trim.
## Red or pink (the colour of danger in this game, kept off the heroes' looks).
static func _reddish(c: Color) -> bool:
	return c.s > 0.45 and c.v > 0.25 and (c.h < 0.045 or c.h > 0.9)


static func _tunic(main: Color, trim: Color) -> Color:
	return main.lerp(trim, 0.22)


static func glow_tier(glow: Dictionary) -> int:
	if glow.get("pass", false) or glow.has("race") or glow.has("event") or (glow.has("ring2") and not is_special(glow)):
		return 2
	return 1 if is_special(glow) else 0


## The slots the Crypt King set fills, and each look's key ("crypt", "crypt_crown"...).
const PASS_SLOTS := ["outfit", "head", "hold", "glow", "aura"]

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
	var e := extra(slot, key)
	if e.has("feat"):
		return Feats.done(cfg, e.feat)
	if e.has("drop"):
		return Drops.has_look(cfg, slot, key)
	if e.has("bazaar"):
		return Bazaar.owns(cfg, slot, key)
	if e.has("race"):
		return Race.has_look(cfg, slot, key)
	if e.has("road"):
		return BoneRoad.has_prize(cfg)
	if e.has("event"):
		# v220 (v219 review): the Silver Moon set from the Pass row goes with the Pass (a
		# refund used to leave it on).
		return Events.has_look(cfg, slot, key) and (not e.get("passroad", false) or Store.owned(cfg))
	return item_level(id, slot, key) <= HeroMastery.level(cfg, id)


## The looks hero `id` gets at Mastery level `lv`.
static func level_items(id: String, lv: int) -> Array:
	return items(id).filter(func(it: Dictionary) -> bool: return it.level == lv and is_mastery(it))


static func item_name(id: String, slot: String, key: String) -> String:
	if key == "":
		return "No aura" if slot == "aura" else "Classic"
	if is_pass(key):
		return str({"outfit": PASS_OUTFIT, "head": PASS_HEAD, "hold": PASS_HOLD, "glow": PASS_GLOW, "aura": PASS_AURA}.get(slot, {}).get("name", key))
	if not extra(slot, key).is_empty():
		return extra(slot, key).name
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
			if is_pass(key) or not extra(slot, key).is_empty():
				return n + " aura"
			return n if key == "" else n + " aura (%s only)" % str(Heroes.get_hero(id).title)
	return n


static func item_level(id: String, slot: String, key: String) -> int:
	if key == "" or is_pass(key) or not extra(slot, key).is_empty():
		return 1
	for it: Dictionary in items(id):
		if it.slot == slot and it.key == key:
			return it.level
	return 99


# ---------------------------------------------------------------- what's worn

## The look hero `id` wears in `slot` ("" = Classic). A look that isn't unlocked (an edited
## save) is worn as Classic.
## The test robot's `outfit=KEY` (autoplay.gd, version 353): every hero wears it.
static var robot_outfit := ""


static func worn(cfg: ConfigFile, id: String, slot: String) -> String:
	if slot == "outfit" and robot_outfit != "":
		return robot_outfit
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


## Version 185: which looks are NEW is kept look by look ("seen_keys" in the save), for
## every way a look is won (Mastery, Feats, Bone Drops, the Bazaar, the Crypt Race, events
## and the Crypt Pass). Before, only Mastery looks counted, and the count was wiped the
## moment the Style screen opened, with nothing on the cards to say which looks were new.
## A look every hero can wear is kept once ("head/antlers"); a Mastery look per hero
## ("rogue/outfit/crimson").
static func _seen_id(id: String, it: Dictionary) -> String:
	if is_special(it) or it.get("pass", false):
		return "%s/%s" % [it.slot, it.key]
	return "%s/%s/%s" % [id, it.slot, it.key]


## The looks seen so far. A save from before version 185 starts with every look it owns as
## seen, but for the Mastery looks the old count still called new.
static func _seen(cfg: ConfigFile) -> Dictionary:
	var out := {}
	if cfg.has_section_key(SECTION, "seen_keys"):
		for k in cfg.get_value(SECTION, "seen_keys", []):
			out[str(k)] = true
		return out
	for h: Dictionary in Heroes.LIST:
		var id: String = h.id
		var seen_lv := int(cfg.get_value(SECTION, id + "_seen", 1))
		for it: Dictionary in items(id):
			if it.key == "" or not has_look(cfg, id, it.slot, it.key):
				continue
			if is_mastery(it) and int(it.level) > seen_lv:
				continue
			out[_seen_id(id, it)] = true
	return out


## Writes the first "seen_keys" into an older save. True when `cfg` changed (save it).
static func migrate_seen(cfg: ConfigFile) -> bool:
	if cfg.has_section_key(SECTION, "seen_keys"):
		return false
	cfg.set_value(SECTION, "seen_keys", _seen(cfg).keys())
	return true


## The looks hero `id` owns and hasn't been shown on the Style screen yet.
static func new_looks(cfg: ConfigFile, id: String) -> Array:
	var seen := _seen(cfg)
	var out := []
	for it: Dictionary in items(id):
		if it.key != "" and not seen.has(_seen_id(id, it)) and has_look(cfg, id, it.slot, it.key):
			out.append(it)
	return out


## How many different new looks the unlocked heroes have between them. A look every hero
## can wear counts once (it was counted once per hero: one Bone Drop look read "4 NEW LOOKS").
static func new_count_all(cfg: ConfigFile) -> int:
	var seen := _seen(cfg)
	var fresh := {}
	for h: Dictionary in Heroes.LIST:
		if not Heroes.unlocked(cfg, h.id):
			continue
		for it: Dictionary in items(h.id):
			var k := _seen_id(h.id, it)
			if it.key != "" and not seen.has(k) and not fresh.has(k) and has_look(cfg, h.id, it.slot, it.key):
				fresh[k] = true
	return fresh.size()


## How many new looks hero `id` has (the STYLE button, the NEW LOOKS tags).
static func unseen(cfg: ConfigFile, id: String) -> int:
	return new_looks(cfg, id).size()


## Hero `id`'s Style screen has shown its new looks: they are new no longer.
static func mark_seen(cfg: ConfigFile, id: String) -> void:
	var seen := _seen(cfg)
	for it: Dictionary in new_looks(cfg, id):
		seen[_seen_id(id, it)] = true
	cfg.set_value(SECTION, "seen_keys", seen.keys())
	cfg.set_value(SECTION, id + "_seen", HeroMastery.level(cfg, id))
	cfg.set_value(SECTION, id + "_auras_seen", true)
	cfg.set_value(SECTION, id + "_holds_seen", true)


## `def` (an entry of Heroes.LIST) as this player has dressed them.
static func styled(cfg: ConfigFile, def: Dictionary) -> Dictionary:
	# Version 312: the Legend Vault's looks (legends.gd) are worn by every hero.
	var legend := Legends.worn(cfg)
	var d := dressed(def, grand_head(picks(cfg, def.id), legend))
	if not legend.is_empty():
		d.style.legend = legend
		crown_grand(d, legend)
	return d


## Version 315: a Legend Vault grand set brings its own crown, so the hero's own head look
## comes off for it: the picks with no head look (the class hat comes back, see crown_grand).
static func grand_head(p: Dictionary, legend: Dictionary) -> Dictionary:
	if str(legend.get("grand", "")) == "":
		return p
	var q := p.duplicate()
	q.head = ""
	return q


## ... and the grand set's crown on the bare head, in the class hat's place.
static func crown_grand(d: Dictionary, legend: Dictionary) -> void:
	var g := str(legend.get("grand", ""))
	if g == "":
		return
	var id := str(d.style.id)
	if OWN_HAT.has(id):
		d.style.hide.append(OWN_HAT[id])
	d.style.hat = false
	d.style.extras = [g + "_crown"]


## `def` in the looks `p` ({slot: key}): its glow colours, and a "style" for the model.
static func dressed(def: Dictionary, p: Dictionary) -> Dictionary:
	var d := def.duplicate()
	var id: String = def.id
	var glow: Dictionary = PASS_GLOW if is_pass(p.get("glow", "")) else GLOWS.get(p.get("glow", ""), extra("glow", p.get("glow", "")))
	if not glow.is_empty():
		d.ring = glow.ring
		d.ring_fx = str(glow.get("fx", "flow"))
		d.ring_tier = glow_tier(glow)
		d.bolt_color = glow.bolt
		# Feat, Bone Drop and Pass glows shine brighter and wider on the hero's edges, so the
		# player can see what they won (version 119: the Eclipse reveal showed a faint rim).
		if is_special(glow) or is_pass(p.get("glow", "")):
			d.rim_strong = true
		if glow.has("ring2"):
			# A Legend road glow shimmers between two colours; a little stronger than a plain
			# glow but not the wide Feat rim (with the bright Legend outfits it hid the hero).
			d.ring2 = glow.ring2
			d.rim_legend = true
	var style := {"id": id, "hide": [], "show": [], "borrow": [], "extras": []}
	var outfit: Dictionary = OUTFITS.get(p.get("outfit", ""), {})
	var xo := extra("outfit", p.get("outfit", ""))
	if not xo.is_empty():
		# The Knight is mostly armour (his "b"): it takes the main colour, his cloth the trim.
		style.outfit = {"a": xo.b, "b": xo.a, "pat": int(xo.pat)} if id == "knight" else {"a": xo.a, "b": xo.b, "pat": int(xo.pat)}
		if id == "barbarian":
			style.outfit.b = _tunic(xo.a.lightened(0.2), xo.b)
		if xo.get("own", false):
			style.outfit.own = true
			style.outfit.own_a = xo.a
			style.outfit.own_b = xo.b
	elif is_pass(p.get("outfit", "")):
		var on: String = PASS_OUTFIT.gold_on.get(id, "a")
		style.outfit = {"a": PASS_OUTFIT.gold if on == "a" else PASS_OUTFIT.obsidian,
			"b": PASS_OUTFIT.gold if on == "b" else PASS_OUTFIT.obsidian, "gold": on}
	elif not outfit.is_empty():
		var b = outfit.get("b")
		if id == "knight":
			b = outfit.get("armor")
		elif id == "rogue":
			b = outfit.get("leather")
		elif id == "barbarian":
			b = _tunic(outfit.get("armor", outfit.a.lightened(0.2)), outfit.b)
		style.outfit = {"a": outfit.a, "b": b}
		if outfit.has("pat"):
			style.outfit.pat = int(outfit.pat)
		style.outfit.key = str(p.get("outfit", ""))   # its own shapes (outfit_shapes.gd, v353)
	var head: Dictionary = PASS_HEAD if is_pass(p.get("head", "")) else HEADS.get(p.get("head", ""), extra("head", p.get("head", "")))
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
		if head.get("hide_head", false) and HEAD_MESH.has(id):
			style.hide.append(HEAD_MESH[id])
	style.hat = has_hat
	style.eye = d.get("ring", Color(0.6, 0.8, 1.0))
	# How far a halo floats over the hat: high over a wizard's hat, just over a helmet.
	var wizard: bool = (id == "mage" and head.get("hat", true)) or p.get("head", "") == "wizard"
	style.hat_h = 0.8 if wizard else 0.42
	var hold: Dictionary = HOLDS.get(id, {}).get(p.get("hold", ""), {})
	var xh := extra("hold", p.get("hold", ""))
	if is_pass(p.get("hold", "")):
		xh = PASS_HOLD
	if not xh.is_empty():
		hold = GRAND.get(id, {}).duplicate()
		hold.finish = xh.finish
	if not hold.is_empty():
		style.hide.append_array(hold.get("hide", []))
		style.show = hold.get("show", [])
	# The weapon's material (LookFx.weapon): its finish, and a worn Glow's colour running
	# along it (version 172: a Glow was only a ring and a faint edge light).
	style.finish = str(hold.get("finish", ""))
	# A pale outfit (ivory, bone, ghost white, polished gold) is close to white already: the
	# glow's line is softer on it, or the two add up to a white blob (version 175).
	if style.has("outfit"):
		var pale := 0.0
		for ch in ["a", "b"]:
			var oc = style.outfit.get(ch)
			if oc is Color:
				pale = maxf(pale, oc.v * (1.0 - oc.s * 0.8) * (1.0 if ch == ("b" if id == "knight" else "a") else 0.6))
		d.rim_soft = lerpf(1.0, 0.55, smoothstep(0.55, 0.9, pale))
		# (Version 188: the Crypt King outfit is obsidian veined with gold. Under the full
		# rim light and aura it bleached to a yellow-white blob in a run and hid itself.)
		if style.outfit.get("gold", "") != "":
			d.rim_soft = 0.45
		if int(style.outfit.get("pat", 0)) == 14:
			d.rim_soft = 0.5   # (v192) the Blood Moon outfit: its own aura washed it to brown
	if not glow.is_empty():
		style.enchant = glow.ring
	d.style = style
	var aura: Dictionary = PASS_AURA if is_pass(p.get("aura", "")) else AURAS.get(id, {}).get(p.get("aura", ""), extra("aura", p.get("aura", "")))
	if not aura.is_empty():
		d.aura = aura.duplicate()
		d.aura.soft = float(d.get("rim_soft", 1.0))   # a fainter column of light on a pale outfit
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


## How much bigger than the model's own a hero's weapons are drawn (version 175).
const WEAPON_SIZE := 1.25
## (In a run, by hero: the Rogue's crossbow and the Mage's wand and books are small things,
## the Knight's greatsword is already long.)
## (Version 204: the Rogue's 2.1, times the crossbow's own 1.5-1.7 below, drew the crossbow
## about three times its size in a run: wider than the Rogue, right in front of him, hiding
## the skeletons and arrows coming at him. Found in real run pictures; the Style screen and
## the grey test stage use the smaller pedestal size, so they never showed it. Now 2x like
## the Mage: it shows ahead of the Rogue when he shoots and tucks in at rest.)
const WEAPON_SIZE_RUN := {"rogue": 2.0, "knight": 1.5, "barbarian": 1.6, "mage": 2.0}
## Version 181: in a run some weapons need more again (the crossbows sit tight against the
## Rogue and the wand under the Mage's hat brim) and the long knives less. (Version 204: the
## crossbows no longer get more; see WEAPON_SIZE_RUN.)
const WEAPON_RUN_PART := {"1H_Crossbow": 1.0, "2H_Crossbow": 1.0, "1H_Wand": 1.5, "Knife": 0.8, "Knife_Offhand": 0.8}

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
		_borrow(skel, str(part[0]), str(part[1]), id, style)
	var outfit: Dictionary = style.get("outfit", {})
	if not outfit.is_empty():
		_recolour(skel, id, outfit)
	if outfit.has("key"):   # version 353 (visual review fix 9): the outfit's own shapes
		var legend: Dictionary = style.get("legend", {})
		OutfitShapes.dress(skel, str(outfit.key), str(legend.get("wings", "")) != "")
	# (Version 175: every weapon, with or without a finish or Glow. The weapon material gives
	# it a lit edge, and weapons are a quarter bigger: from the camera above they could not
	# be seen at all.)
	var cover = outfit.get("a") if outfit.get("a") is Color else CLASSIC_OUTFIT.get(id, Color(0.3, 0.22, 0.55))
	_arm(skel, str(style.get("finish", "")), style.get("enchant"), cover, float(style.get("weapon_size", WEAPON_SIZE)))
	for extra: String in style.get("extras", []):
		_extra(skel, id, extra, bool(style.get("hat", false)), float(style.get("hat_h", 0.45)), style)


## Everything in the hero's hands takes the weapon material (LookFx.weapon).
static func _arm(skel: Skeleton3D, finish: String, glow: Variant, book: Variant = null, big := WEAPON_SIZE) -> void:
	for c in skel.get_children():
		var att := c as BoneAttachment3D
		if att == null or not str(att.bone_name).begins_with("handslot"):
			continue
		for w in att.get_children():
			var mi := w as MeshInstance3D
			if mi and mi.mesh:
				var src := Art.base_material(mi.mesh.surface_get_material(0))
				if src and src.albedo_texture:
					mi.material_override = LookFx.weapon(src, finish, glow, book if str(mi.name).begins_with("Spellbook") else null)
				if str(mi.name) == "1H_Wand" and not mi.has_meta("big"):
					_wand_star(mi, glow if glow is Color else Color(0.6, 0.85, 1.0))
				if not mi.has_meta("big"):
					mi.set_meta("big", true)
					mi.scale *= big * (float(WEAPON_RUN_PART.get(str(mi.name), 1.0)) if big > WEAPON_SIZE else 1.0)
					if str(mi.name) == "Badge_Shield":
						_crest(mi, book if book is Color and not _reddish(book) else Color(0.18, 0.36, 0.8))
					elif str(mi.name) == "Mug":
						_tankard(mi, skel)
				# v228-231: forged, gilded and void weapons have their own shapes (last, so a
				# whole new weapon can hide what was added onto the one it replaces)
				ForgedArms.dress(mi, finish)


## The Knight's crest shield (version 177) was a blank cream slab: it gets a crest on its
## face, a diamond in the outfit's colour with a gold boss at its heart.
static func _crest(shield: MeshInstance3D, col: Color) -> void:
	var box := shield.mesh.get_aabb()
	var face := Vector3(box.get_center().x, box.get_center().y + 0.04, box.end.z)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = col
	paint.roughness = 0.5
	paint.emission_enabled = true
	paint.emission = col
	paint.emission_energy_multiplier = 0.25
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.32)
	gold.metallic = 0.7
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.22)
	gold.emission_energy_multiplier = 0.4
	for side: float in [1.0, -1.0]:   # both faces: the pedestal shows one, the run camera the other
		var at := Vector3(face.x, face.y, box.end.z if side > 0.0 else box.position.z)
		var d := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.4, 0.4, 0.04)
		d.mesh = dm
		d.material_override = paint
		d.position = at
		d.rotation.z = PI * 0.25
		d.scale = Vector3(1.0, 1.25, 1.0)
		shield.add_child(d)
		var b := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.1
		bm.height = 0.2
		bm.radial_segments = 10
		bm.rings = 5
		b.mesh = bm
		b.material_override = gold
		b.position = at + Vector3(0, 0, 0.02 * side)
		b.scale = Vector3(1, 1, 0.6)
		shield.add_child(b)
		for n: MeshInstance3D in [d, b]:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The Barbarian's tankard (version 177) sat in his axe hand, inside the axe, where nobody
## saw it. It moves to his free hand, grows, and gets a head of foam.
static func _tankard(mug: MeshInstance3D, skel: Skeleton3D) -> void:
	for c in skel.get_children():
		var att := c as BoneAttachment3D
		if att and str(att.bone_name) == "handslot.l" and mug.get_parent() != att:
			mug.get_parent().remove_child(mug)
			att.add_child(mug)
			mug.position = Vector3(0, 0.02, 0.05)
			break
	var box := mug.mesh.get_aabb()
	var foam := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.16
	fm.height = 0.2
	fm.radial_segments = 10
	fm.rings = 5
	foam.mesh = fm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1.0, 0.97, 0.88)
	white.roughness = 0.9
	white.emission_enabled = true
	white.emission = Color(1.0, 0.95, 0.8)
	white.emission_energy_multiplier = 0.3
	foam.material_override = white
	foam.position = Vector3(0, box.end.y - 0.02, 0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mug.add_child(foam)


## The Mage's wand (version 176): a star of light at its tip in the Glow's colour. The bare
## stick was the weakest thing a hero could hold.
static func _wand_star(wand: MeshInstance3D, col: Color) -> void:
	var box := wand.mesh.get_aabb()
	var axis := box.get_longest_axis_index()
	var lo := box.position[axis]
	var hi := box.end[axis]
	var tip := box.get_center()
	tip[axis] = hi if absf(hi) > absf(lo) else lo   # the end away from the hand
	var core := U.unlit(Color(col.lightened(0.5), 1.0))
	var halo := U.unlit(Color(col, 0.5), U.soft_circle()).duplicate() as StandardMaterial3D
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.billboard_keep_scale = true
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 10
	sm.rings = 5
	s.mesh = sm
	s.material_override = core
	s.position = tip
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wand.add_child(s)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.5)
	q.mesh = qm
	q.material_override = halo
	q.position = tip
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.set_meta("fx", true)
	wand.add_child(q)


## A part (hat, cape, weapon) from another hero's model, worn on this skeleton on the same
## bone (in the models they hang from the head, chest and hand bones). A hat made for a
## smaller head grows to fit (the Knight's head is the biggest: his head would poke through).
static func _borrow(skel: Skeleton3D, model_key: String, part: String, id := "", style := {}) -> void:
	var p := _part(model_key, part)
	if p.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = p.mesh
	mi.material_override = p.material
	# Version 172: a borrowed wizard's hat is dyed to match its wearer (the outfit worn, or
	# the hero's own colour), not left the Mage's purple.
	if part == "Mage_Hat":
		var src := (p.mesh as Mesh).surface_get_material(0) as BaseMaterial3D
		var o: Dictionary = style.get("outfit", {})
		var cloth = o.get("b" if id == "knight" else "a")
		if o.get("gold", "") != "":
			cloth = PASS_OUTFIT.obsidian
		if cloth == null:
			cloth = CLASSIC_OUTFIT.get(id, Color(0.45, 0.4, 0.7))
		# (Version 182: never a red hat. The Knight's classic colour is red, and red is the
		# colour of danger in this game: a red cone on his head read as a warning.)
		if cloth is Color and _reddish(cloth):
			cloth = Color(0.2, 0.3, 0.7)
		if src and src.albedo_texture:
			var dye := {"a": cloth, "b": null}
			if o.has("pat"):
				dye.pat = o.pat
			mi.material_override = _material("mage", dye, src)
	# Version 176: a borrowed bear hat or knight's helm takes the outfit's colour too (they
	# stayed brown and grey over any outfit). With the Classic outfit they stay as made.
	if part in ["Barbarian_Hat", "Knight_Helmet"]:
		var src2 := (p.mesh as Mesh).surface_get_material(0) as BaseMaterial3D
		var o2: Dictionary = style.get("outfit", {})
		var c2 = o2.get("b" if id == "knight" else "a")
		if o2.get("gold", "") != "":
			c2 = PASS_OUTFIT.obsidian
		if c2 is Color and src2 and src2.albedo_texture:
			var dye2 := {"a": c2, "b": null} if part == "Barbarian_Hat" else {"a": null, "b": c2}
			if o2.has("pat"):
				dye2.pat = o2.pat
			mi.material_override = _material("barbarian" if part == "Barbarian_Hat" else "knight", dye2, src2)
	mi.name = "Borrowed_" + part
	mi.transform = p.transform
	var grow := float(HEAD_TOP.get(id, 0.74)) / float(HEAD_TOP.get(model_key.to_lower(), 0.74))
	if p.bone == "head" and grow > 1.01:
		mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * grow), Vector3.ZERO) * mi.transform
	if part == "Mage_Hat":
		# Version 175: a narrower brim on other heroes. On their bigger heads the hat was a
		# wide disc that hid the whole hero from the camera above.
		mi.transform = Transform3D(Basis.from_scale(Vector3(0.74, 0.92, 0.74)), Vector3.ZERO) * mi.transform
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
				# Version 174: the hood keeps the outfit's pattern (it was left plain, and from
				# above in a run the hood is most of what you see of the Rogue).
				for k: String in ["pat", "gold", "own", "own_a", "own_b"]:
					if outfit.has(k):
						o[k] = outfit[k]
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
	var key := "%s %s %s %s %s %s %s %s" % [id, outfit.get("a", null), outfit.get("b", null), both, outfit.get("gold", ""), outfit.get("pat", 0), outfit.get("own_a", ""), outfit.get("own_b", "")]
	if _mats.has(key):
		return _mats[key]
	# A plain recolour gets a short copy of the shader without the gold and pattern code:
	# every recoloured hero ran all of it before, which costs phones' GPUs even unused.
	# (Version 175: always the full shader. Every outfit has a pattern since version 172, so
	# the short copy was only left for a dyed wizard's hat, and nothing warmed it up.)
	var fancy := true
	var skey := "%s %s" % [both, fancy]
	if not _shaders.has(skey):
		var code := SHADER.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;" if both else "shader_type spatial;")
		if not fancy:
			var a := code.find("\t// <fancy>")
			var b := code.find("\t// </fancy>")
			code = code.substr(0, a) + code.substr(b + "\t// </fancy>".length())
		var sh := Shader.new()
		sh.code = code
		_shaders[skey] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[skey]
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
	m.set_shader_parameter("pat", int(outfit.get("pat", 0)))
	if outfit.get("own", false):
		var oa: Color = outfit.get("own_a", Color.GRAY)
		var ob: Color = outfit.get("own_b", Color.WHITE)
		m.set_shader_parameter("own", 1.0)
		m.set_shader_parameter("own_a", Vector3(oa.r, oa.g, oa.b))
		m.set_shader_parameter("own_b", Vector3(ob.r, ob.g, ob.b))
	# The Knight's recoloured armour is metal, not painted plastic (version 172).
	m.set_shader_parameter("b_metal", 0.55 if id == "knight" else 0.0)
	_mats[key] = m
	return m


const CAP_R := 0.6
const CAP_Y := -0.2
const CAP_Z := -0.06

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
		"starfall_crown":
			att.add_child(LegendGrand.starfall_crown(id, y))   # version 315: Legend Vault
		"emperor_crown":
			att.add_child(LegendEmperor.crown(id, y))   # version 316: Legend Vault
		"storm_halo", "star_circlet", "flame_crown", "skull_helm", "antlers", "phantom_horns", "bone_crown", "moon_crown", "candle_crown", "horns", "halo":
			att.add_child(FeatHeads.make(kind, id, y, hat, style))
		"mage_hood":
			var o: Dictionary = style.get("outfit", {})
			var cloth: Color = o.get("a", CLASSIC_OUTFIT.get(id, Color(0.45, 0.4, 0.7)))
			var trim: Color = o.get("b", Color(0.95, 0.62, 0.28))
			if o.get("gold", "") != "":   # the Crypt King outfit: obsidian hood, gold trim
				cloth = PASS_OUTFIT.obsidian
				trim = PASS_OUTFIT.gold
			att.add_child(MageHood.make(cloth, trim, style.get("eye", Color(0.6, 0.8, 1.0))))
	# Version 191: under a crown or horns the Knight wears a mail coif and the Barbarian a fur
	# cap, in the outfit's colours. Without their helmet and bear hood these two were a bare
	# head, which from the camera above was a big peach ball that took over the whole look.
	# (Version 315: the Legend Vault crowns bring their own caps instead.)
	if not hat and id in ["knight", "barbarian"] and not kind in ["skull_helm", "mage_hood", "starfall_crown", "emperor_crown"]:
		var oc: Dictionary = style.get("outfit", {})
		var col := Color(0.6, 0.63, 0.7) if id == "knight" else Color(0.4, 0.28, 0.19)
		var pick = oc.get("b" if id == "knight" else "a")
		if pick is Color:
			col = pick
		if kind == "candle_crown" and col.s > 0.25 and col.h > 0.2 and col.h < 0.5:
			# (Version 244: a warm brown fur cap under the green wreath. A green cap (Yule Knit,
			# Forest) and the wreath were one green ball from above; a cream one, a white ball.)
			col = Color(0.48, 0.32, 0.2)
		if kind == "moon_crown" and col.s > 0.35 and col.h > 0.07 and col.h < 0.18:
			# (Version 208: a gold cap (Tidecaller) under the gold Moon Crown made the head
			# one gold ball that read as a coin; the cap goes deep bronze.)
			col = col.darkened(0.55)
		var velvet := false
		if oc.get("gold", "") != "":
			# (Version 200: royal violet velvet under the Crypt Crown. Glossy obsidian with the
			# crown's dark band on it read as a peaked police cap.)
			col = Color(0.26, 0.12, 0.4)
			velvet = true
		var cap := SphereMesh.new()
		cap.radius = CAP_R
		cap.height = CAP_R
		cap.is_hemisphere = true
		cap.radial_segments = 16
		cap.rings = 8
		var cm := StandardMaterial3D.new()
		cm.albedo_color = col
		cm.roughness = 0.45 if id == "knight" else 0.95
		cm.metallic = 0.35 if id == "knight" else 0.0
		if velvet:
			cm.roughness = 1.0
			cm.metallic = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = cm
		mi.position = Vector3(0, y + CAP_Y, CAP_Z)
		mi.scale = Vector3(1.0, 0.9, 1.06)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)


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
				base = y + 0.14
				r = 0.46   # (0.4 before version 175: it looked like a toy on the big hat)
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
	# (Version 175: emeralds, not rubies. Red-pink is the colour of danger in this game.)
	var gems := [U.mat(Color(0.15, 0.9, 0.5), 0.2, 1.6), U.mat(Color(0.25, 0.55, 1.0), 0.2, 1.6)]
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
		# (version 174: jewels on the points, not gold balls, and a great diamond at the front)
		U.sphere(att, 0.075, gems[(i + 1) % 2], Vector3(0, base + 0.55, 0) + dir * r * 1.22)
		if i == 0:
			var jewel := U.sphere(att, 0.1, U.mat(Color(0.75, 0.95, 1.0), 0.1, 2.2), Vector3(0, base + 0.12, 0) + dir * r * 1.1)
			jewel.scale = Vector3(0.9, 1.25, 0.6)
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
// A Feat or Bone Drop outfit's animated pattern (EXTRA "pat"; 0 = none).
uniform int pat = 0;
// 1 while the hero lies dead or knocked down (character_visual.gd): the bands measured by
// height above the floor (Crypt mantle and hem fire, Blood Moon hem) are off, or a lying
// hero would be all hem.
uniform float calm = 0.0;
uniform float own = 0.0;   // 1 = a special pattern takes this outfit's own colours
uniform vec3 own_a = vec3(0.5);
uniform vec3 own_b = vec3(1.0);
uniform float b_metal = 0.0;
varying vec3 wpos;
varying vec3 opos;
varying vec3 mpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	opos = NODE_POSITION_WORLD;
	mpos = VERTEX;   // the model's own space: patterns stay put on the cloth as the hero turns
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.1) * 0.15;
}

// A star or sparkle in a grid of cells: a soft point in one cell in `rare`, twinkling.
float twinkle(vec3 p, float rare, float speed) {
	vec3 cell = floor(p);
	float h = hash3(cell);
	float d = length(fract(p) - 0.5);
	return step(1.0 - rare, h) * (1.0 - smoothstep(0.0, 0.22, d)) * (0.45 + 0.55 * sin(TIME * speed + h * 40.0));
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
	ROUGHNESS = mix(rough, 0.34, mb * b_metal);
	METALLIC = mix(metal, 1.0, mb * b_metal * 0.9);
	// Version 172: a soft sheen at the edges of dyed cloth and armour, so an outfit has some
	// depth to it instead of one flat colour.
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = o * sheen * 0.45 * clamp(ma + mb, 0.0, 1.0);
	// <fancy>
	float g = ma * a_gold + mb * b_gold;
	float k = ma * a_dark + mb * b_dark;
	if (g + k > 0.001) {
		// Gold: a warm glow at the edges, and a band of light that runs up the hero
		// every 2.2 seconds. Obsidian: glossy black, veined with molten gold that
		// slowly breathes, with a violet sheen at the edges.
		float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		vec3 lp = wpos - opos;
		float h = lp.y + 0.35 * (lp.x + lp.z);
		// (Version 198: fewer, thicker veins. The thin ones read as a fishnet in a run.)
		float vn = sin(lp.x * 6.0 + lp.y * 4.0 + sin(lp.z * 5.0) * 1.6) * sin(lp.z * 5.5 - lp.y * 3.5 + sin(lp.x * 4.5) * 1.4);
		float vein = (1.0 - smoothstep(0.07, 0.2, abs(vn))) * (0.7 + 0.3 * sin(TIME * 1.7 + lp.y * 3.0));
		// A mantle of polished gold over the shoulders, and teal soul fire burning up from
		// the hem: from the run camera the obsidian body was one black lump with no colour.
		float mantle = k * (1.0 - calm) * smoothstep(0.72, 0.84, wpos.y) * (1.0 - smoothstep(1.12, 1.22, wpos.y));
		float hemf = k * (1.0 - calm) * (1.0 - smoothstep(0.1, 0.62, wpos.y + 0.07 * sin(lp.x * 13.0 + TIME * 3.1) * sin(lp.z * 11.0 - TIME * 2.3)));
		k -= mantle;
		g += mantle;
		float ph = fract(TIME * 0.45 - h * 0.32);
		float band = smoothstep(0.0, 0.03, ph) * (1.0 - smoothstep(0.03, 0.09, ph));
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.08, 1.0, 0.86), g);
		ROUGHNESS = mix(ROUGHNESS, 0.28, g + k * 0.6);
		METALLIC = mix(METALLIC, 0.7, g);
		ALBEDO = mix(ALBEDO, vec3(1.0, 0.72, 0.22), k * vein * 0.8);
		EMISSION += vec3(1.0, 0.72, 0.24) * g * (0.22 + edge * 0.85)
			+ vec3(1.0, 0.94, 0.75) * band * (g * 1.5 + k * 0.6)
			+ vec3(1.0, 0.62, 0.16) * k * vein * 1.1
			+ vec3(0.55, 0.35, 0.9) * k * edge * 0.45
			+ vec3(0.08, 0.95, 0.72) * hemf * (0.85 + 0.25 * sin(TIME * 2.6 + lp.x * 5.0));
		ALBEDO = mix(ALBEDO, vec3(0.05, 0.5, 0.42), hemf * 0.7);
	}
	float w = clamp(ma + mb, 0.0, 1.0);
	if (pat > 0 && w > 0.001) {
		float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		// Version 116: a pattern 3.5 times coarser, so it reads on a hero 150 pixels tall.
		vec3 q = mpos * 0.62;
		vec3 em = vec3(0.0);
		vec3 al = ALBEDO;
		float met = 0.0;
		float ang = atan(mpos.x, mpos.z);
		vec3 gold = vec3(1.0, 0.8, 0.34);
		if (pat == 21) {
			// Crimson: velvet with a gold-thread lattice of diamonds.
			vec2 uv = vec2(ang * 1.27, q.y * 2.6);
			float dia = abs(fract(uv.x + uv.y) - 0.5) + abs(fract(uv.x - uv.y) - 0.5);
			float line = 1.0 - smoothstep(0.012, 0.04, abs(dia - 0.5));
			float gem = 1.0 - smoothstep(0.0, 0.09, dia);
			al = mix(al, gold, line * 0.3 + gem * 0.85);
			em = gold * (line * 0.1 * (0.7 + 0.3 * sin(TIME * 2.0 + q.y * 4.0)) + gem * 0.5 + edge * 0.25);
		} else if (pat == 22) {
			// Forest: overlapping leaf scales, lighter at each tip.
			vec2 uv = vec2(ang * 2.9, q.y * 6.5);
			uv.x += 0.5 * floor(uv.y);
			vec2 f = fract(uv) - vec2(0.5, 1.0);
			float d = length(f);
			float rimline = 1.0 - smoothstep(0.0, 0.07, abs(d - 0.52));
			al = mix(al * (0.72 + 0.5 * (1.0 - fract(uv.y))), al * 0.4, rimline * 0.8);
			em = vec3(0.45, 1.0, 0.5) * edge * 0.32;
		} else if (pat == 23) {
			// Midnight: a night sky, stars coming and going.
			float st = twinkle(q * 5.0, 0.34, 2.5) + twinkle(q * 9.0 + 2.3, 0.22, 4.0) * 0.7;
			al = mix(al, al * 0.7, 0.5);
			em = vec3(0.88, 0.92, 1.0) * st * 2.6 + vec3(0.3, 0.45, 1.0) * edge * 0.65;
		} else if (pat == 24) {
			// Ivory: mother-of-pearl, with bands of gold filigree.
			vec3 iri = hsv2rgb(vec3(fract(edge * 0.9 + q.y * 0.35 + TIME * 0.05), 0.3, 1.0));
			float d = abs(fract(q.y * 2.3 + 0.06 * sin(ang * 8.0)) - 0.5);
			float band = 1.0 - smoothstep(0.02, 0.06, d);
			al = mix(al * mix(vec3(1.0), iri, 0.55), gold, band * 0.8);
			em = iri * edge * 0.3 + gold * band * 0.18;
		} else if (pat == 25) {
			// Shadow: smoke curling up the cloth, violet at the edges.
			float n = fbm(q * 1.8 + vec3(0.0, -TIME * 0.4, 0.0));
			al = mix(al, al * 0.45, n);
			em = vec3(0.58, 0.26, 0.98) * (smoothstep(0.44, 0.7, n) * 0.95 + edge * 0.95);
		} else if (pat == 26) {
			// Royal: gold pinstripes and a gleam running up them.
			float stripe = 1.0 - smoothstep(0.05, 0.12, abs(fract(ang * 2.4) - 0.5));
			float sweep = pow(max(0.0, sin(q.y * 2.4 - TIME * 2.0)), 10.0);
			al = mix(al, gold, stripe * 0.8);
			em = gold * (stripe * (0.16 + sweep * 0.9) + edge * 0.3);
		} else if (pat == 27) {
			// Ember: banked coals glowing through the cloth.
			float n = fbm(q * 2.2 + vec3(0.0, -TIME * 0.25, 0.0));
			float hot = smoothstep(0.52, 0.72, n);
			// (Version 188: charcoal cloth, so the coals are the colour; it was all orange.)
			al = mix(al, vec3(1.0, 0.7, 0.25), hot * 0.6);
			em = vec3(1.0, 0.45, 0.08) * (hot * 1.15 * (0.8 + 0.2 * sin(TIME * 5.0 + q.x * 6.0)) + edge * 0.5);
		} else if (pat == 28) {
			// Frost: hoarfrost creeping over the cloth, and glints.
			float n = vnoise(q * 6.0) * 0.6 + vnoise(q * 13.0) * 0.4;
			float sp = twinkle(q * 7.0 + floor(TIME * 1.5) * 0.3, 0.1, 5.0);
			al = mix(al, vec3(1.0), smoothstep(0.52, 0.75, n) * 0.7);
			em = vec3(0.6, 0.9, 1.0) * edge * 0.6 + vec3(1.0) * sp * 2.2;
		} else if (pat == 29) {
			// Rose: pale petals scattered over it.
			vec2 uv = vec2(ang * 2.4, q.y * 5.2);
			uv.x += 0.5 * floor(uv.y);
			vec2 f = fract(uv) - 0.5;
			float petal = 1.0 - smoothstep(0.16, 0.24, length(f * vec2(1.0, 1.5) + vec2(0.0, 0.1 * sin(f.x * 6.0))));
			al = mix(al, vec3(1.0, 0.97, 0.94), petal * 0.75);
			em = vec3(0.8, 0.7, 1.0) * edge * 0.38;
		} else if (pat == 30) {
			// Sea: waves rolling round the cloth with lines of foam.
			float wv = sin(q.y * 9.0 + sin(ang * 3.0 + TIME * 1.2) * 1.2 - TIME * 0.8);
			float foam = smoothstep(0.82, 1.0, wv);
			al = mix(al, al * 0.6, smoothstep(0.2, -1.0, wv) * 0.5);
			al = mix(al, vec3(0.86, 1.0, 1.0), foam * 0.75);
			em = vec3(0.3, 0.92, 0.9) * (foam * 0.3 + edge * 0.42);
		} else if (pat == 31) {
			// Gilded (Mastery 10): polished gold, a gleam running up it and glints.
			// (version 173: a narrow, softer gleam; the wide one washed the whole hero out to white)
			float sweep = pow(max(0.0, sin(q.y * 2.5 + q.x - TIME * 2.2)), 48.0);
			float sp = twinkle(q * 8.0 + floor(TIME * 2.5) * 0.27, 0.08, 7.0);
			met = 1.0;
			al = al * vec3(1.05, 0.95, 0.7);
			em = vec3(1.0, 0.72, 0.25) * (0.06 + edge * 0.5) + vec3(1.0, 0.96, 0.8) * (sweep * 0.45 + sp * 1.6);
		} else if (pat == 32) {
			// Bone: cracked plates with ribs across them.
			float cracks = 1.0 - smoothstep(0.015, 0.05, abs(fbm(q * 2.6) - 0.5));
			float ribs = 1.0 - smoothstep(0.05, 0.1, abs(fract(q.y * 3.0) - 0.5));
			al = mix(al, vec3(0.2, 0.17, 0.15), max(cracks * 0.8, ribs * 0.4));
			em = vec3(1.0, 0.95, 0.85) * edge * 0.22;
		} else if (pat == 1) {
			// Ghostwalk: pale and see-through-looking, cold light at the edges and wisps rising.
			float n = fbm(q * 1.6 + vec3(0.0, -TIME * 0.7, 0.0));
			float wisp = smoothstep(0.46, 0.72, n);
			al = mix(al, mix(vec3(0.1, 0.32, 0.42), own_a * 0.75, own), 0.6);   // a dark core, so the cold edges stand out
			em = mix(vec3(0.45, 0.95, 1.0), own_b, own) * (edge * 2.4 + wisp * 1.3 + 0.08) * (0.88 + 0.12 * sin(TIME * 9.0));
		} else if (pat == 2) {
			// Cinder Ice (was Magma, too close to the Crypt King's molten veins): dark slate
			// split by cracks of blue-white frost light that breathe.
			float n = fbm(q * 2.2);
			float crack = 1.0 - smoothstep(0.02, 0.075, abs(n - 0.5));
			float pulse = 0.75 + 0.25 * sin(TIME * 2.2 + q.y * 3.0);
			float hot = smoothstep(0.62, 0.82, fbm(q * 1.3 + vec3(0.0, TIME * 0.15, 0.0)));
			al = mix(al, vec3(0.8, 0.95, 1.0), crack * 0.9);
			em = vec3(0.45, 0.8, 1.0) * (crack * 1.7 * pulse + hot * 0.3 + edge * 0.55);
		} else if (pat == 3) {
			// Starweave: the night sky woven in: drifting nebula and twinkling stars.
			float n = fbm(q * 1.2 + vec3(TIME * 0.04, 0.0, 0.0));
			vec3 neb = mix(mix(vec3(0.25, 0.1, 0.55), own_a * 1.5, own), mix(vec3(0.1, 0.45, 0.8), own_b * 0.8, own), n);
			float st = twinkle(q * 4.0, 0.22, 3.0) + twinkle(q * 7.0 + 3.1, 0.14, 4.5) * 0.7;
			al = mix(al, mix(vec3(0.06, 0.05, 0.16), own_a * 0.55, own) + neb * 0.4, 0.9);
			em = neb * 0.45 + vec3(1.0, 0.95, 0.85) * st * 3.0 + mix(vec3(0.6, 0.5, 1.0), own_b, own) * edge * 0.8;
		} else if (pat == 4) {
			// Frostbite: ice crystal facets with sparkles that come and go.
			vec3 r = q * 4.0;
			float facet = abs(fract(r.x + r.y * 0.57) - 0.5) + abs(fract(r.y - r.z * 0.57) - 0.5);
			float line = 1.0 - smoothstep(0.03, 0.09, abs(facet - 0.5));
			float sp = twinkle(q * 9.0 + floor(TIME * 2.0) * 0.37, 0.08, 6.0);
			al = mix(al, vec3(0.92, 0.98, 1.0), line * 0.5);
			em = vec3(0.55, 0.85, 1.0) * (edge * 0.8 + line * 0.3) + vec3(1.0) * sp * 2.5;
		} else if (pat == 5) {
			// Thunder: storm cloth with lightning that crawls over it and flashes.
			float n = vnoise(vec3(q.x * 2.0, q.y * 4.0 + TIME * 3.0, q.z * 2.0));
			float bolt = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
			float flash = pow(max(0.0, sin(TIME * 3.3 + q.y * 1.5)), 10.0);
			al = mix(al, al * 0.85, 0.5);
			em = mix(vec3(0.55, 0.8, 1.0), own_b, own) * bolt * (0.5 + 2.5 * flash) + mix(vec3(0.4, 0.55, 1.0), own_b, own) * edge * (0.4 + flash);
		} else if (pat == 6) {
			// Bonecarved: ivory carved with runes, soul light pulsing in the grooves.
			// Clean runes: carved bands round the body, each with short upright strokes.
			vec3 g = q * vec3(3.0, 3.0, 3.0);
			vec3 f = fract(g);
			float h = hash3(floor(g));
			float band = 1.0 - smoothstep(0.06, 0.1, abs(f.y - 0.5));
			float stroke = (1.0 - smoothstep(0.07, 0.11, abs(fract(atan(mpos.x, mpos.z) * 1.6) - 0.5))) * step(0.25, f.y) * step(f.y, 0.75);
			float groove = clamp(band + stroke * step(0.35, h), 0.0, 1.0);
			al = mix(al, vec3(0.1, 0.35, 0.28), groove * 0.9);
			em = vec3(0.35, 1.0, 0.75) * groove * (1.1 + 0.6 * sin(TIME * 2.0 + h * 6.0)) + vec3(1.0, 0.95, 0.85) * edge * 0.15;
		} else if (pat == 7) {
			// Shadowflame: violet flames licking up a black cloak.
			float n = fbm(vec3(q.x * 2.0, q.y * 1.4 - TIME * 1.6, q.z * 2.0));
			float fl = smoothstep(0.42, 0.72, n) * (0.8 + 0.2 * sin(TIME * 7.0 + q.x * 5.0));
			al = mix(al, al * 0.6, 0.6);
			em = mix(vec3(0.45, 0.15, 0.95), vec3(0.85, 0.6, 1.0), smoothstep(0.65, 0.85, n)) * fl * 1.4 + vec3(0.6, 0.3, 1.0) * edge * 0.7;
		} else if (pat == 8) {
			// Toxic: bubbling slime, bubbles swelling and popping as they rise.
			vec3 r = q * 3.2 + vec3(0.0, -TIME * 0.6, 0.0);
			float h = hash3(floor(r));
			float ph = fract(TIME * 0.45 + h);
			float d = length(fract(r) - 0.5);
			float bub = (1.0 - smoothstep(0.0, 0.05, abs(d - (0.08 + 0.28 * ph)))) * (1.0 - ph) * step(0.45, h);
			float slime = smoothstep(0.45, 0.7, fbm(q * 1.5 + vec3(0.0, TIME * 0.2, 0.0)));
			// (Version 232, fix 9: acid yellow-green, not leaf green: it was Forest's twin.)
			al = mix(al, mix(vec3(0.78, 1.0, 0.12), own_b, own), slime * 0.45);
			em = mix(vec3(0.72, 1.0, 0.1), own_b, own) * (bub * 1.8 + slime * 0.25 + edge * 0.45) * 0.6;   // 60%: it glared
		} else if (pat == 9) {
			// Prism: bands of colour running over pearly cloth (never red-pink: that's danger).
			float t = 0.5 + 0.5 * sin(q.y * 2.4 + q.x * 1.2 - TIME * 1.6);
			vec3 col = hsv2rgb(vec3(0.13 + 0.62 * t, 0.55, 1.0));
			al = mix(al, al * col * 1.15, 0.65);
			em = col * (0.18 + edge * 0.9);
		} else if (pat == 10) {
			// Abyssal: deep water, rippling light from above and glowing creatures drifting.
			float c1 = vnoise(q * 2.6 + vec3(TIME * 0.35, 0.0, TIME * 0.2));
			float c2 = vnoise(q * 2.9 - vec3(0.0, TIME * 0.3, TIME * 0.25));
			float caus = smoothstep(0.55, 0.75, 1.0 - abs(c1 - c2) * 3.0);
			float dots = twinkle(q * 6.0 + vec3(0.0, TIME * 0.25, 0.0), 0.12, 2.0);
			em = vec3(0.15, 0.8, 0.85) * (caus * 0.45 + edge * 0.35) + vec3(0.4, 1.0, 1.0) * dots * 1.8;
		} else if (pat == 11) {
			// Diamond (Mastery 12): cut-gem facets with rainbow fire in the edges, a gleam
			// sweeping up the hero and bright glints.
			vec3 r = q * 3.0;
			float facet = abs(fract(r.x * 0.8 + r.y * 0.5) - 0.5) + abs(fract(r.y * 0.8 - r.z * 0.5) - 0.5)
				+ abs(fract(r.z * 0.8 + r.x * 0.4) - 0.5) * 0.6;
			float line = 1.0 - smoothstep(0.02, 0.07, abs(fract(facet * 2.0) - 0.5));
			float sweep = pow(max(0.0, sin(q.y * 1.5 + q.x * 0.8 - TIME * 2.0)), 12.0);
			vec3 fire = hsv2rgb(vec3(fract(facet * 1.7 + TIME * 0.15), 0.45, 1.0));
			float sp = twinkle(q * 8.0 + floor(TIME * 3.0) * 0.21, 0.07, 7.0);
			al = mix(al, vec3(0.72, 0.76, 0.86), 0.4);   // (v176 bluer, it was plain white from above; v232 silver, the ice blue was Frost again)
			al = mix(al, vec3(1.0), line * 0.6);
			em = fire * (line * 0.5 + edge * 0.35) + vec3(0.8, 0.92, 1.0) * sweep * 0.9 + vec3(1.0) * sp * 2.5;
		} else if (pat == 12) {
			// Mythic (Mastery 17): deep violet cloth, thin rings of light rising round the hero
			// with runes glowing between them, violet turning to cyan. (The first try's wide
			// bright bands and blocks read as a checked shirt.)
			float y = q.y * 2.2 - TIME * 0.45;
			float d = abs(fract(y) - 0.5);
			float ring = 1.0 - smoothstep(0.015, 0.045, d);
			float band = 1.0 - smoothstep(0.08, 0.13, d);
			float glyph = step(0.62, fract(ang * 4.0 + floor(y) * 0.37 + TIME * 0.15)) * band * (1.0 - ring);
			float n = fbm(q * 1.4 + vec3(0.0, -TIME * 0.3, 0.0));
			// (Version 232, fix 9: deep teal-black under orchid light. Violet cloth made it a
			// twin of Shadow and Royal.)
			// The cloth's edge glows cyan and the rings orchid, so it reads as teal and orchid
			// from the run camera, never as Shadow's violet.
			float ring2 = 1.0 - smoothstep(0.06, 0.1, d);
			vec3 c = mix(vec3(0.72, 0.32, 1.0), vec3(0.3, 0.9, 1.0), n * 0.3);
			al = mix(al, vec3(0.03, 0.15, 0.18), 0.75);
			em = vec3(0.2, 0.8, 0.9) * (0.06 + n * 0.14 + edge * 0.55) + c * (ring2 * 1.25 + glyph * 0.55);
		} else if (pat == 13) {
			// Legend (Mastery 19): a sun's rays turning round the hero in red-gold, embers
			// rising through them.
			// (Version 176: it was a plain red outfit with faint rays, weaker than the level 2
			// Crimson. Now black cloth with living flames climbing it from the hem, orange at
			// the root and gold at the tips, the last outfit on the Mastery road.)
			float rays = pow(0.5 + 0.5 * sin(ang * 6.0 + TIME * 1.2), 6.0) * (0.6 + 0.4 * sin(q.y * 3.0 - TIME * 2.0));
			float up = twinkle(q * 5.0 + vec3(0.0, -TIME * 1.2, 0.0), 0.1, 3.0);
			float tong = fbm(vec3(ang * 2.2, q.y * 2.4 - TIME * 1.1, TIME * 0.2));
			float fl = smoothstep(0.52, 0.68, tong) * (1.0 - 0.45 * fract(q.y * 0.9));
			vec3 fire = mix(vec3(1.0, 0.3, 0.04), vec3(1.0, 0.86, 0.4), smoothstep(0.3, 1.0, fl));
			al = mix(al, fire, fl * 0.8);
			em = fire * fl * 0.55 + vec3(1.0, 0.55, 0.15) * rays * 0.35 + vec3(1.0, 0.8, 0.4) * edge * 0.55 + vec3(1.0, 0.7, 0.25) * up * 2.2;
		} else if (pat == 14) {
			// Blood Moon (the event set): black-crimson cloth, veins of blood light throbbing
			// with a heartbeat (two beats, then a rest), and little gold crescent moons
			// drifting up.
			float t = fract(TIME * 1.1);
			float hb = exp(-t * 10.0) + 0.6 * exp(-max(t - 0.2, 0.0) * 10.0) * step(0.2, t);
			float n = fbm(q * 2.0);
			float vein = 1.0 - smoothstep(0.015, 0.06, abs(n - 0.5));
			vec3 r = q * 2.3 + vec3(0.0, -TIME * 0.3, 0.0);
			vec2 f = fract(r.xy + r.z * 0.5) - 0.5;
			float h = hash3(floor(r));
			float mr = 0.2 + 0.06 * own;   // (v232) Silver Moon's moons are bigger
			float moon = (1.0 - smoothstep(mr - 0.04, mr, length(f))) * smoothstep(mr - 0.07, mr - 0.02, length(f - vec2(0.08, 0.07) * (1.0 + own * 0.3)));
			moon *= step(0.5, h) * (0.6 + 0.4 * sin(TIME * 2.0 + h * 30.0));
			// (Version 182: night-purple cloth and amber veins, not black-crimson and red. Red
			// is the colour of danger in this game.)
			// (Version 192: indigo, not near-black, with bigger moons, and the hem burns
			// blood-orange like a moonrise. The outfit was a dark lump with a speck on it.)
			float hem = (1.0 - calm) * (1.0 - smoothstep(0.16, 0.9 + 0.35 * own, wpos.y));   // (v196) height above the floor: a cape or hat has its own origin, and was all hem
			// (Version 232: the Silver Moon set, "own", takes its own night blue and silver here.
			// Every pat-14 outfit was painted indigo and amber, so the Crypt Pass's Silver Moon
			// outfit looked exactly like the free Blood Moon one.)
			vec3 cloth = mix(vec3(0.15, 0.09, 0.32), own_a, own);
			vec3 hem_col = mix(vec3(0.85, 0.3, 0.06), own_b * 0.9, own);
			vec3 vein_col = mix(vec3(1.0, 0.58, 0.14), own_b, own);
			vec3 edge_col = mix(vec3(1.0, 0.62, 0.2), own_b, own);
			vec3 moon_col = mix(vec3(1.0, 0.8, 0.45), vec3(0.95, 0.97, 1.0), own);
			vec3 hem_glow = mix(vec3(1.0, 0.4, 0.08), own_b * 0.85, own);
			al = mix(al, cloth, 0.75);
			al = mix(al, hem_col, hem * 0.75);
			// (Silver Moon also wears a bright silver outline and stronger veins, so from the
			// run camera it is night blue edged in silver, never plain Midnight blue.)
			em = vein_col * vein * (0.3 + 1.0 * hb) * (1.0 - own * 0.35) + edge_col * edge * (0.45 + 0.35 * hb + own * 0.6) + moon_col * moon * 1.9
				+ hem_glow * hem * (0.35 + 0.25 * hb);
		} else if (pat == 33) {
			// Tidecaller (Bone Bazaar, version 183): sand-gold cloth with teal waves rolling
			// round the hero, a line of white foam riding each crest.
			float wv = q.y * 4.0 + sin(ang * 3.0 + TIME * 1.4) * 0.35 + sin(ang * 7.0 - TIME * 0.9) * 0.12;
			float f = fract(wv);
			float sea = smoothstep(0.3, 0.5, f);
			float crest = 1.0 - smoothstep(0.0, 0.07, abs(f - 0.5));
			al = mix(own_a * 0.95, own_b * 0.75, sea * 0.9);
			em = own_b * sea * 0.3 + vec3(0.85, 1.0, 1.0) * crest * (1.0 + 0.6 * sin(TIME * 3.0 + ang * 4.0)) + own_b * edge * 0.7;
			met = (1.0 - sea) * 0.5;
		} else if (pat == 34) {
			// Sunforged: bronze cloth set with gold sun medallions whose rays turn.
			vec2 uv = vec2(ang * 0.95, q.y * 1.7);
			uv.x += 0.5 * floor(uv.y);
			vec2 f = fract(uv) - 0.5;
			float d = length(f);
			float disc = 1.0 - smoothstep(0.15, 0.18, d);
			float rays = pow(abs(sin(atan(f.y, f.x) * 6.0 + TIME * 1.2)), 6.0) * smoothstep(0.15, 0.18, d) * (1.0 - smoothstep(0.28, 0.4, d));
			float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + uv.y * 3.0);
			// (Version 188: dark bronze with white-hot suns, so it is not one more orange.)
			al = mix(own_a, vec3(1.0, 0.92, 0.6), clamp(disc + rays * 0.6, 0.0, 1.0));
			em = vec3(1.0, 0.9, 0.5) * (disc * 2.0 * pulse + rays * 1.6) + own_b * edge * 0.6;
			met = clamp(disc + rays, 0.0, 1.0) * 0.9 + 0.2;
		} else if (pat == 35) {
			// Plaguebone: dark rotten cloth over pale ribs, lime slime dripping down it and
			// bubbles swelling and popping.
			float rib = (1.0 - smoothstep(0.1, 0.16, abs(fract(q.y * 3.0) - 0.5))) * smoothstep(0.04, 0.08, abs(mpos.x));   // bone-white ribs all the way round, split by the spine
			float col = ang * 2.2;
			float h = hash3(vec3(floor(col * 1.6), 2.3, 5.1));
			float drop = fract(q.y * 1.2 + TIME * (0.25 + 0.35 * h) + h * 5.0);
			float drip = (1.0 - smoothstep(0.22, 0.34, abs(fract(col * 1.6) - 0.5))) * smoothstep(0.35, 0.95, drop) * step(0.3, h);
			float slime = smoothstep(0.5, 0.7, fbm(q * 1.5 + vec3(0.0, TIME * 0.2, 0.0)));
			vec3 r = q * 3.2 + vec3(0.0, -TIME * 0.6, 0.0);
			float hb = hash3(floor(r));
			float ph = fract(TIME * 0.45 + hb);
			float bub = (1.0 - smoothstep(0.0, 0.05, abs(length(fract(r) - 0.5) - (0.08 + 0.28 * ph)))) * (1.0 - ph) * step(0.5, hb);
			al = mix(mix(mix(own_a, own_b * 0.35, slime * 0.35), vec3(0.95, 0.93, 0.8), rib * 0.95), own_b, drip * 0.5 * (1.0 - rib));
			em = vec3(0.9, 0.9, 0.75) * rib * 0.35 + own_b * (drip * 0.8 * (1.0 - rib) + bub * 1.6 + edge * 0.5) * 0.8;
		} else if (pat == 36) {
			// Nightbloom: deep green cloth on which violet flowers open and glow, a gold
			// light in each heart.
			vec2 uv = vec2(ang * 1.3, q.y * 2.6);
			uv.x += 0.5 * floor(uv.y);
			vec2 f = fract(uv) - 0.5;
			float h = hash3(vec3(floor(uv), 1.3));
			float pa = atan(f.y, f.x);
			float rr = length(f);
			float petal = 0.32 * (0.55 + 0.45 * cos(pa * 5.0 + h * 6.0));
			float bloom = (1.0 - smoothstep(petal - 0.03, petal + 0.02, rr)) * step(0.15, h);
			float heart = (1.0 - smoothstep(0.04, 0.07, rr)) * step(0.15, h);
			float vine = (1.0 - smoothstep(0.02, 0.05, abs(f.x + 0.12 * sin(uv.y * 6.28)))) * (1.0 - bloom);
			al = mix(mix(own_a, own_a * 1.8, vine * 0.6), own_b * 0.85, bloom * 0.85);
			em = own_b * bloom * (1.2 + 0.5 * sin(TIME * 2.0 + h * 20.0)) + vec3(1.0, 0.85, 0.45) * heart * 1.6 + own_b * edge * 0.55;
		} else if (pat == 37) {
			// Yule Knit (Frostfall, version 244): a knitted jumper, evergreen with cream bands.
			// Each band has a green zigzag through it strung with fairy lights (gold, ice blue
			// and warm white) that blink one after another round the hero; between the bands,
			// a row of big cream snowflakes, glinting in turn; and the knit's own stitches.
			float u = ang * 3.82;   // about 24 stitches round
			float v = q.y * 2.0;
			float row = fract(v);
			float rid = floor(v);
			float st = abs(fract(u * 2.0) - 0.5) * 2.0;
			float vs = fract(q.y * 14.0 + st * 0.5);
			float knit = 0.84 + 0.16 * smoothstep(0.15, 0.45, vs) * (1.0 - smoothstep(0.65, 0.95, vs));
			float band = 1.0 - smoothstep(0.27, 0.3, row);
			float zig = abs(fract(u * 0.5) - 0.5) * 2.0;
			float zz = (1.0 - smoothstep(0.025, 0.06, abs(row - 0.05 - zig * 0.17))) * band;
			float lid = floor(u * 0.5);
			vec2 lf = vec2((fract(u * 0.5) - 0.5) * 0.9, (row - 0.14) * 2.4);
			float bulb = (1.0 - smoothstep(0.1, 0.15, length(lf))) * band;
			float which = mod(lid + rid, 3.0);
			vec3 bc = which < 0.5 ? vec3(1.0, 0.78, 0.3) : (which < 1.5 ? vec3(0.45, 0.82, 1.0) : vec3(1.0, 0.95, 0.82));
			float on = 0.25 + 0.75 * smoothstep(0.35, 0.5, fract(TIME * 0.7 - lid / 6.0)) * (1.0 - smoothstep(0.85, 1.0, fract(TIME * 0.7 - lid / 6.0)));
			vec2 sf = vec2(fract(ang * 1.27) - 0.5, (row - 0.64) * 1.5);
			float fr = length(sf);
			float fa = atan(sf.y, sf.x);
			float arms = (1.0 - smoothstep(0.035, 0.07, fr * abs(sin(fa * 3.0)))) * (1.0 - smoothstep(0.3, 0.34, fr));
			float flake = max(arms, 1.0 - smoothstep(0.06, 0.09, fr)) * (1.0 - band);
			float glint = pow(0.5 + 0.5 * sin(TIME * 1.4 - floor(ang * 1.27) * 1.3 - rid * 2.0), 8.0);
			vec3 cloth = mix(own_a * knit, own_b * knit, band * (1.0 - zz));
			al = mix(mix(cloth, own_b * 0.95, flake), bc, bulb);
			em = bc * bulb * on * 2.2 + own_b * flake * (0.12 + 0.9 * glint) + own_b * edge * 0.25;
		} else if (pat == 38) {
			// Polar Night (Frostfall's Pass row, version 244): night-blue cloth with the
			// northern lights rippling up it, green curtains turning violet as they rise, fine
			// rays running through them, and stars twinkling in the dark between.
			float fold = fbm(vec3(ang * 1.2 + TIME * 0.12, q.y * 0.8, TIME * 0.15));
			float hang = q.y * 1.6 + fold * 1.2;
			float bnd = fract(hang - TIME * 0.18);
			float cur = smoothstep(0.0, 0.3, bnd) * (1.0 - smoothstep(0.42, 0.8, bnd));
			float rays = 0.5 + 0.5 * sin(ang * 22.0 + fold * 10.0 + TIME * 0.7);
			float lit = cur * (0.65 + 0.35 * rays);
			vec3 aur = mix(own_b, vec3(0.7, 0.42, 1.0), smoothstep(0.15, 0.7, bnd));
			float star = twinkle(q * 6.0, 0.08, 3.0) * (1.0 - cur);
			al = mix(own_a, aur * 0.55, lit * 0.65);
			em = aur * lit * 1.15 + vec3(0.9, 0.95, 1.0) * star * 2.2 + own_b * edge * 0.4;
		} else if (pat == 15 || pat == 16) {
			// The Crypt Race outfits (version 153). Pacesetter: black racing cloth with hot
			// orange speed streaks shooting back round the hero, and a chevron stripe down the
			// middle. Crystal Sprint: the same streaks in ice blue over deep navy, with crystal
			// glints riding them.
			vec3 hot = pat == 15 ? vec3(1.0, 0.48, 0.08) : vec3(0.35, 0.92, 1.0);
			vec3 tip = pat == 15 ? vec3(1.0, 0.9, 0.55) : vec3(0.9, 1.0, 1.0);
			float lane = floor(q.y * 6.0);
			float h = hash3(vec3(lane, 1.7, 3.1));
			float run = fract(ang * 0.9 + TIME * (0.9 + h * 0.8) + h * 7.0);
			float streak = smoothstep(0.0, 0.55, run) * (1.0 - smoothstep(0.55, 0.62, run));
			float thin = 1.0 - smoothstep(0.08, 0.22, abs(fract(q.y * 6.0) - 0.5));
			streak *= thin * step(0.35, h);
			float chev = 1.0 - smoothstep(0.04, 0.09, abs(fract(q.y * 2.5 - abs(mpos.x) * 3.0 + TIME * 0.6) - 0.5));
			chev *= 1.0 - smoothstep(0.12, 0.2, abs(mpos.x));
			float glint = pat == 16 ? twinkle(q * 7.0 + vec3(TIME * 0.5, 0.0, 0.0), 0.1, 5.0) : 0.0;
			al = mix(al, pat == 15 ? vec3(0.06, 0.06, 0.08) : vec3(0.04, 0.1, 0.22), 0.65);
			em = mix(hot, tip, streak * streak) * streak * 1.6 + hot * chev * 0.9 + hot * edge * 0.5 + vec3(1.0) * glint * 2.2;
		}
		ALBEDO = mix(ALBEDO, al, w);
		EMISSION += em * w;
		METALLIC = mix(METALLIC, 0.78, met * w);
		ROUGHNESS = mix(ROUGHNESS, 0.24, met * w);
	}
	// </fancy>
}
"""
