class_name Warmup
## Phones turn each new look (a material on a kind of mesh, a particle effect, the damage
## numbers) into a graphics program the first time it's drawn, and with this game's
## renderer the game waits for it: the first hit, the first enemy shot and each new kind
## of skeleton, fire or floor froze play for up to a second (frame rate "lowest 9" in run
## reports). Godot keeps the programs in user://shader_cache, so it happened once per
## install or update, just when a new player is making up their mind. At launch, behind
## the black screen, this draws one of everything for a few frames and removes it all, so
## the wait happens there instead. The first launch after an install or update takes
## longest; run reports say how long the last one took ("warm-up").

const FOES := ["m", "w", "a", "g", "x", "t", "s", "f", "e", "d", "p", "r", "L", "K", "C", "T", "S", "A", "v", "u", "l", "z", "y", "P", "M", "B", "k", "F", "b", "h", "Q", "q", "o", "n", "i", "Y"]

## Version 165: the skeletons, floor and effects of the first floor. A new player's first
## launch warms only these (with the hero they play), and the rest waits for the black
## screen after the tutorial: on a cheap phone (an Adreno 619) the whole set took 53 s on
## the first launch, nearly a minute before the title. Once the whole set has been drawn
## for a build, later launches warm only these too (the phone keeps the rest ready).
const FIRST_FOES := ["m", "w", "a", "g", "x", "t", "s", "K"]

const BUDGET_MS := 12000

static var last_ms := 0
static var last_core := false
## Version 221: the step a full warm-up stopped at when it ran out of time (see mark_full),
## and whether this session has already shown the full one (it shows once a session).
static var last_stop := 0
static var full_tried := false


## Which warm-up this launch needs: true for the short one (see FIRST_FOES).
static func core_only(cfg: ConfigFile) -> bool:
	return str(cfg.get_value("stats", "warmed_build", "")) == Game.BUILD or Game.first_run_pending()


## Notes how far this build's full warm-up got (see core_only and resume_step).
## Version 221 (v219 review): only a finished one marks the build. One that ran out of time
## saves the step it stopped at, and the next launch carries on from there, so a slow phone
## sees the loading bar once a launch and each one gets further. Before, it started again
## from the first step after every run, up to 3 times (3 black screens on update day).
static func mark_full(cfg: ConfigFile, finished := true) -> void:
	if finished:
		cfg.set_value("stats", "warmed_build", Game.BUILD)
		if cfg.has_section_key("stats", "warm_step"):
			cfg.erase_section_key("stats", "warm_step")
	else:
		cfg.set_value("stats", "warm_step", "%s|%d" % [Game.BUILD, last_stop])
	if cfg.has_section_key("stats", "warm_tries"):
		cfg.erase_section_key("stats", "warm_tries")   # (versions 218-220 counted tries)


## Where this build's full warm-up carries on from (0: from the start).
static func resume_step(cfg: ConfigFile) -> int:
	var parts := str(cfg.get_value("stats", "warm_step", "")).split("|")
	if parts.size() == 2 and parts[0] == Game.BUILD:
		return maxi(0, int(parts[1]))
	return 0


## Returns true when every step was drawn (false when it ran out of time).
## Version 221: `from` skips the steps an earlier launch already drew (the phone keeps them).
static func run(core := false, from := 0) -> bool:
	if not core:
		full_tried = true
	var room := Room.current
	var hero: Hero = Game.hero
	if room == null or hero == null or Game.world == null:
		return false
	var finished := true
	var started := Time.get_ticks_msec()
	var bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true)   # warnings and pickups make sounds as they appear
	var old_room := _ids(room)
	var old_world := _ids(Game.world)
	var holder := Node3D.new()
	holder.name = "Warmup"
	room.add_child(holder)   # skeletons only stand still on the title screen
	var at := hero.global_position
	var spots: Array[Vector3] = []
	# (Version 243: 6 rows, for the Frostfall skeletons. Version 272: enough for every kind of
	# skeleton and then every hero; from version 269 the new skeletons pushed the last heroes
	# past the end, and their step stopped before warming them.)
	for i in maxi(30, FOES.size() + Heroes.LIST.size() + 1):
		spots.append(at + Vector3((i % 5 - 2) * 1.3, 0, (i / 5 - 1) * 1.3))
	var tree := Game.get_tree()
	var made: Array = []
	# A few things a frame rather than everything at once: on a new install a slow phone can
	# take many seconds to prepare it all, and one frame that long looks frozen (Android may
	# even offer to close the app). Between batches a loading bar shows how far it has got.
	var bar := _Bar.new()
	Game.add_child(bar)
	var steps: Array[Callable] = []

	# Every kind of skeleton (and a golden elite) with its health bar and a damage number,
	# then every hero with its glow.
	var foes: Array[Enemy] = []
	var kinds: Array = FIRST_FOES if core else FOES
	for k in range(0, kinds.size(), 4):
		steps.append(func():
			for i in range(k, mini(k + 4, kinds.size())):
				var e := Enemy.create(kinds[i], holder, spots[i])
				e._spawn_timer = 0.0
				if kinds[i] == "w":
					e.make_elite("ward")   # version 237: its bubble and name tag compile here too
					if e._tag:
						e._tag.visible = true
					if e._bubble:
						e._bubble.visible = true
				if kinds[i] == "Q":
					(e as BloodQueen)._ghost(1.0)   # her Eclipse shadow (version 221)
				if e._bar:
					e._bar.reveal()
				DamageNumber.hit(e, 1234567890.0, kinds[i] == "K")
				foes.append(e))
	var heroes: Array[CharacterVisual] = []
	# Version 218: the heroes first (their hit flash is the first thing a run needs).
	steps.push_front(func():
		for i in Heroes.LIST.size():
			if core and Heroes.LIST[i].id != hero.hero_id:
				continue   # (the short warm-up: only the hero being played)
			var v := CharacterVisual.new()
			v.outline_me = true   # so the outline shader is ready before the first run
			holder.add_child(v)
			v.position = spots[FOES.size() + i]
			# (The first in an outfit, so the outfit shader is ready: hero_style.gd.)
			var picks := {"outfit": "crimson"} if i == 0 else {}
			if i == 1 and Store.owned():
				# A Pass owner's Crypt King set (its crown, gold outfit and sigil shaders).
				for slot: String in HeroStyle.PASS_SLOTS:
					picks[slot] = HeroStyle.pass_key(slot)
			var def := HeroStyle.dressed(Heroes.LIST[i], picks)
			v.build(Heroes.look(def))
			if def.has("aura") and def.aura.get("sigil", false):
				CryptSigil.make(v)
			heroes.append(v)
		# Version 239: the Rogue's Shadow Step shadow (its see-through glass on a moving body).
		if not core or hero.hero_id == "rogue":
			var sv := CharacterVisual.new()
			holder.add_child(sv)
			sv.position = spots[spots.size() - 1] + Vector3(1.3, 0, 0)
			sv.build(Heroes.look(Heroes.get_hero("rogue")))
			var sm := ShadowStep.material()
			for g: GeometryInstance3D in sv._meshes:
				if is_instance_valid(g):
					g.material_override = sm
		DamageNumber.healed(hero, 9876543210.0))

	# Every Feat and Bone Drop look: the headwear's flame, ghost and glow materials, the
	# patterned outfits and the auras (version 115 left these out, so the first Legendary
	# reveal froze while its head was prepared). Two batches of a few heroes each.
	var keys := {}
	var most := 0
	for slot: String in ["head", "outfit", "glow", "aura", "hold"]:
		keys[slot] = HeroStyle.EXTRA[slot].keys()
		most = maxi(most, keys[slot].size())
	for half in (0 if core else 2):
		steps.append(func():
			for i in range(half * ceili(most / 2.0), mini(most, (half + 1) * ceili(most / 2.0))):
				var v := CharacterVisual.new()
				v.outline_me = true
				holder.add_child(v)
				v.position = spots[i % spots.size()] + Vector3(0, 0, 2.6)
				var picks := {}
				for slot: String in keys:
					picks[slot] = keys[slot][i % keys[slot].size()]
				v.build(Heroes.look(HeroStyle.dressed(Heroes.LIST[i % Heroes.LIST.size()], picks)))
			var g := Fx.aura_ground(Color.CYAN, Color.WHITE, 6)
			holder.add_child(g)
			g.position = at + Vector3(0, 0.04, 2.0)
			# Version 172: an aura's column of light (LookFx.shell).
			var sh := LookFx.shell(Color.CYAN, Color.WHITE)
			holder.add_child(sh)
			sh.position += at + Vector3(1.5, 0, 2.0)
			var wv := LookFx.wave(Color.CYAN, Color.WHITE)
			holder.add_child(wv)
			wv.position = at + Vector3(-1.5, 0.03, 2.0)
			# Version 174: every kind of column, the circling lights and the sunburst.
			for kind in 4:
				var fx := LookFx.aura_fx({"ink": Color.CYAN, "shine": true, "motif": ["wisps", "motes", "stars", "storm"][kind]})
				holder.add_child(fx)
				fx.position = at + Vector3(kind - 1.5, 0, 3.2)
			# Version 252: the level-20 auras' own shapes (blades, mane, lightning, orrery), and
			# version 254's Bone Chain (the Bone Road's last prize).
			for kind in 5:
				var mo := Fx.motif(["blades", "mane", "lightning", "orrery", "bonechain"][kind], Color.CYAN, 1.4)
				holder.add_child(mo)
				mo.position = at + Vector3(kind - 2.0, 0.3, 4.2))

	# The Heroes/Style pedestal and the Bone Drop chest: each has its own little 3D world with
	# its own lights, so their shaders differ from the room's (version 119: the first reveal
	# and the first chest could stall while these were prepared). Drawn behind the loading
	# screen, on a layer under it.
	if not core: steps.append(func():
		var layer := CanvasLayer.new()
		layer.layer = -1
		Game.add_child(layer)
		made.append(layer)
		var stage := HeroStage.new(Vector2(240, 300))
		layer.add_child(stage)
		var picks := {"head": "flame_crown", "outfit": "starweave", "glow": "aurora", "aura": "nightlord"}   # (a grade 4 aura: its lights and sunburst too)
		stage.show_hero(HeroStyle.dressed(Heroes.LIST[0], picks))
		stage.set_active(true)
		stage.reveal("glow", true)   # its sparks (version 131)
		var chest := ChestShow.new()
		chest.size = Vector2(240, 240)
		chest.position = Vector2(250, 0)
		layer.add_child(chest)
		chest.reset()
		chest.open_up(Color(1.0, 0.8, 0.3), 2, true)
		chest.warm()   # (version 223: the great hand, its prizes and the dark crypt's floor)
		# The lit wall behind the menus (version 130), with its torch and dust.
		var wall := ColorRect.new()
		wall.color = Color(0, 0, 0, 1)
		wall.size = Vector2(300, 300)
		wall.position = Vector2(0, 310)
		layer.add_child(wall)
		var bd := MenuBackdrop.add_to(wall)
		bd.show_off(stage, Vector2(0.5, 0.4), 0.8, 0.3)
		# the candle shrine under short lists (version 136)
		var shrine := MenuBackdrop._Shrine.new()
		shrine.visible = true
		wall.add_child(shrine)
		shrine.place(Rect2(0, 0, 300, 260), 240.0, Color.WHITE))

	# Shots, warnings, fire, pickups and every particle effect: a few at a time, so a slow
	# phone never spends long on one frame (Android closes an app that stops answering),
	# and a report from a phone that dies here names the very effect (Game.loading).
	steps.append(func():
		for i in 5:   # every hero's shot (the Barbarian's axe model loads here too)
			Projectile.fire(Actor.Team.HERO, at + Vector3(-1 - i * 0.4, 1, 1), Vector3.FORWARD, 0.0, 0.0, hero.bolt_color, 0.3, "Shot",
				["bolt", "wave", "axe", "orb", "shard"][i]))
	steps.append(func():
		Fx.impact(at + Vector3.UP, hero.bolt_color)
		Projectile.fire(Actor.Team.UNDEAD, at + Vector3(1, 1, 1), Vector3.FORWARD, 0.0, 0.0, Color.WHITE))
	steps.append(func():
		Telegraph.circle(at + Vector3(-1.5, 0, 0), 1.0, 9.0, func(): pass)
		Telegraph.line(at, Vector3.FORWARD, 3.0, 1.0, 9.0, func(): pass)
		# Version 242: the Trap Hall's rows (its spikes are one instanced mesh per row).
		var hall := TrapHall.lay(holder)
		hall.set_process(false)
		hall.position = Vector3(0, 0, at.z - 4.0)
		for r: Dictionary in hall._rows:
			(r.spikes as Node3D).position.y = 0.0
		FirePatch.spawn(at + Vector3(1.5, 0, 0), 1.0, 9.0)
		Pickup.drop(at + Vector3(0, 0, 1))
		Pickup.drop_coins(at + Vector3(0, 0, -1), 3))
	steps.append(func():
		Fx.sparks(at + Vector3.UP)
		Fx.bones(at))
	steps.append(func():
		Fx.dust(at)
		Fx.trail(at + Vector3.UP, Color(0.45, 0.8, 1.0)))
	steps.append(func():
		Fx.magic(at + Vector3.UP, Color(1, 0.6, 0.2))
		Fx.shockwave(at, Color(1, 0.9, 0.6), 2.0))
	steps.append(func():
		Fx.flame(holder, Vector2(0.5, 0.7), at + Vector3(0, 0, 0.6))
		Fx.wisps(holder, Color(0.6, 1.0, 0.85), 2, 1.0, 1.0))   # the room's wisps (version 136)

	# Each floor's own flagstones and props (the Frozen Ossuary's ice, the Ember
	# Catacomb's fire seams and braziers, the Drowned Vault's water and falling water), and
	# the Tidecaller's wave.
	steps.append(func():
		for i in Floors.THEMES.size():
			if core and Floors.THEMES[i] != Floors.current():
				continue
			U.floor_quad(holder, Vector2(1, 1), Room._floor_material(Floors.THEMES[i]), spots[i] + Vector3(0, 0.02, 0.6))
			# Each crypt's own walls (version 134).
			U.box(holder, Vector3(0.6, 0.6, 0.6), Room._wall_material(Floors.THEMES[i], U.mat(Color.GRAY)), spots[i] + Vector3(0.6, 0.3, 0.6)))
	if not core: steps.append(func():
		var props := [Props._skull_pile(true), Props._skull_pile(false), Props._crystals(), Props._icicles(), Props._brazier(), Props._grate(),
			Props._kelp_column(), Props._spout()]
		for i in props.size():
			Props._mesh(holder, props[i]).position = spots[5 + i] + Vector3(0, 0, -0.6)
		U.floor_quad(holder, Vector2(1, 1), Props._splash_mat(), spots[14] + Vector3(0, 0.03, 0))
		U.floor_quad(holder, Vector2(1, 1), Props._foam_mat(), spots[16] + Vector3(0, 0.03, 0))
		U.box(holder, Vector3(1, 0.6, 0.3), Tidecaller._foam_material(), spots[15] + Vector3(0, 0.3, 0)))
	# Version 243, Frostfall: the timber post, a snowball, a frost ring, a brazier with its
	# warm ring, the ring of cold round the hero and the block of ice.
	if not core: steps.append(func():
		var post := MeshInstance3D.new()
		post.mesh = Props.timber_post()
		holder.add_child(post)
		post.position = spots[2] + Vector3(0, 0, -0.6)
		var ball := MeshInstance3D.new()
		ball.mesh = Snowball._mesh()
		holder.add_child(ball)
		ball.position = spots[3] + Vector3(0, 0.4, 0)
		FrostRing.warm_up(holder, spots[1])
		Blizzard.warm_up(holder, spots[4]))
	# The Sandfall Tomb (version 247): a sandfall (its falling-sand shader and the dust where
	# it lands) and a lotus column.
	if not core: steps.append(func():
		var fall := Node3D.new()
		holder.add_child(fall)
		fall.position = spots[25] + Vector3(0, 0, -0.6)
		Props._add_sandfall(fall)
		Props._mesh(holder, Props.lotus_column()).position = spots[26] + Vector3(0, 0, -0.6))
	# The Whispering Library (version 249): a lectern with its flying pages (their shader turns
	# them) and a bookcase pillar.
	if not core: steps.append(func():
		var lect := Node3D.new()
		holder.add_child(lect)
		lect.position = spots[27] + Vector3(0, 0, -0.6)
		Props._mesh(lect, Props._lectern())
		Props._add_pages(lect, Vector3.ZERO)
		Props._mesh(holder, Props.bookcase_column()).position = spots[28] + Vector3(0, 0, -0.6))
	# The Clockwork Foundry (version 250): an iron column with its turning gear collar (the
	# moving-metal shader) and a piston pumping.
	if not core: steps.append(func():
		var col := Node3D.new()
		holder.add_child(col)
		col.position = spots[29] + Vector3(0, 0, -0.6)
		Props.add_iron_column(col)
		var pis := Node3D.new()
		holder.add_child(pis)
		pis.position = spots[24] + Vector3(0, 0, 0.6)
		Props._add_piston(pis))
	# The Starfall Abyss (version 255): a broken column floating apart and a standing stone's
	# floating top (the floating-stone shader), and a brazier of cold star fire.
	if not core: steps.append(func():
		var col := Node3D.new()
		holder.add_child(col)
		col.position = spots[27] + Vector3(0.6, 0, -0.6)
		Props.add_drift_column(col)
		var stone := Node3D.new()
		holder.add_child(stone)
		stone.position = spots[26] + Vector3(0.6, 0, 0.6)
		Props._add_monolith(stone)
		Props._add_star_brazier(stone))
	# Version 256, each floor its own cover: the Frozen Ossuary's block of clear ice with a
	# skeleton frozen inside and its frosted urn of skulls (see-through ice); version 262, the
	# Whispering Library's hourglass (see-through glass).
	if not core: steps.append(func():
		Props._mesh(holder, Props._ice_block()).position = spots[25] + Vector3(0.6, 0, 0.6)
		Props._mesh(holder, Props._frost_urn()).position = spots[28] + Vector3(0.6, 0, 0.6)
		Props._mesh(holder, Props._hourglass()).position = spots[29] + Vector3(0.6, 0, 0.6))
	# The Glowcap Grotto (version 128): its mushrooms and shelf fungus, the glow under them,
	# a spore cloud, crawling roots and the Sporemother's pod.
	if core: steps.append(func():
		Props._mesh(holder, Props._skull_pile(true)).position = spots[5] + Vector3(0, 0, -0.6)
		Props._mesh(holder, Props._skull_pile(false)).position = spots[6] + Vector3(0, 0, -0.6))
	if not core: steps.append(func():
		Props._mesh(holder, Props._mushroom_clump()).position = spots[21]
		Props._mesh(holder, Props._shelf_fungus()).position = spots[22]
		Props._glow_pool(holder, 1.0)
		SporeCloud.spawn(spots[23], 1.0, 0.5)
		RootCrawl._burst(spots[23] + Vector3(0.5, 0, 0), 1.0, 0.2)
		var pod := U.sphere(holder, 0.28, U.mat(Color(1.0, 0.42, 0.82), 0.4, 0.7))
		pod.position = spots[24] + Vector3(0, 1, 0))
	# Version 271: the Hush Keeper's circle of letters, sealed, with its curtain of light.
	if not core: steps.append(func():
		HushCircle.warm(holder, spots[22] + Vector3(0, 0.035, 0)))
	# Version 274: the Sand Pharaoh's sand (pouring, and in mounds), sunbeam and scarabs.
	if not core: steps.append(func():
		SandMound.warm(holder, spots[21] + Vector3(0, 0, 0.6))
		SandPharaoh.warm(holder, spots[23] + Vector3(0, 0, 0.6)))
	# Version 284: the Sandfall Tomb's quicksand pits.
	if not core: steps.append(func():
		Quicksand.warm(holder, spots[24] + Vector3(0, 0, 0.6)))
	# Version 285: the Amethyst Mine's gas vent and cloud.
	if not core: steps.append(func():
		MineGas.warm(holder, spots[23] + Vector3(0, 0, 0.6)))
	# Version 286: the Whispering Library's rolling bookcase on its rails.
	if not core: steps.append(func():
		RollingStacks.warm(holder, spots[22] + Vector3(0, 0, 0.6)))
	# Version 287: the Clockwork Foundry's magnet coil, lit.
	if not core: steps.append(func():
		ElectroMagnet.warm(holder, spots[24] + Vector3(0, 0, 0.6)))
	# Version 288: the Starfall Abyss's loose plate and the void under it.
	if not core: steps.append(func():
		FallingPlates.warm(holder, spots[21] + Vector3(0, 0, 0.6)))
	# Version 290: the Frozen Ossuary's black ice.
	if not core: steps.append(func():
		IcePatch.warm(holder, spots[22] + Vector3(0, 0, 0.6)))
	# Version 291: the Ember Catacomb's fire seam, burning.
	if not core: steps.append(func():
		FireSeam.warm(holder, spots[23] + Vector3(0, 0, 0.6)))
	# Version 292: the Glowcap Grotto's bounce cap.
	if not core: steps.append(func():
		BounceCap.warm(holder, spots[24] + Vector3(0, 0, 0.6)))
	# Version 293: the Drowned Vault's tide.
	if not core: steps.append(func():
		TideSurge.warm(holder, spots[25] + Vector3(0, 0, 0.6)))
	# Version 275: the Crystal Tyrant's spires (standing and cracking), ripple and cart.
	if not core: steps.append(func():
		CrystalTyrant.warm(holder, spots[22] + Vector3(0, 0, 0.6)))
	# Version 276: the Archivist's page wings, a flying book, a footprint of its Retelling
	# and a burnt stroke of its words.
	if not core: steps.append(func():
		Archivist.warm(holder, spots[21] + Vector3(0, 0, 0.6)))
	# Version 281: the Forgemaster's press, saw blade, ingot, running belt and pendulum.
	if not core: steps.append(func():
		Forgemaster.warm(holder, spots[23] + Vector3(0, 0, 0.6)))

	# Draw each batch for two frames. Frames, not frame_post_draw: that signal never comes
	# without a screen (robot test runs).
	if from > 0:
		print("[warmup] carrying on from step %d of %d" % [from, steps.size()])
	for n in range(mini(from, steps.size()), steps.size()):
		# Version 167: never more than 12 s. A phone this slow (or one of Google's test phones,
		# drawing in software) would wait up to a minute; whatever is left is prepared the
		# first time it is drawn instead, with a short pause then, or by the next launch
		# (version 221: it carries on from this step).
		if Time.get_ticks_msec() - started > BUDGET_MS:
			print("[warmup] stopped at step %d of %d (over %d ms)" % [n, steps.size(), BUDGET_MS])
			finished = false
			last_stop = n
			break
		Game.loading = "loading %d/%d" % [n + 1, steps.size()]
		Game.note_spot()   # if a phone dies while loading, the report says at which step
		steps[n].call()
		# Shots, warnings, fire and pickups land in the room: they mustn't hurt or be collected.
		for c in _new(room, old_room) + _new(Game.world, old_world):
			if not made.has(c):
				made.append(c)
				if c.get_parent() == room and c != holder:
					c.process_mode = Node.PROCESS_MODE_DISABLED
		bar.progress((n + 1.0) / (steps.size() + 1.0), Time.get_ticks_msec() - started)
		for i in 2:
			await tree.process_frame

	# Then every character being hit (white flash).
	for e in foes:
		e.take_damage(1.0, Vector3.ZERO, 0.0)
		if e._bar:
			# Half-empty and low enough to be in view (they float above tall skeletons).
			e._bar.process_mode = Node.PROCESS_MODE_DISABLED
			e._bar.visible = true
			e._bar.global_position = e.global_position + Vector3(0, 1.0, 0.5)
			e._bar._fill.scale = Vector3(0.5, 1, 1)
	for i in heroes.size():
		heroes[i].soft_flash = i == 1   # so a boss's softer flash is ready too
		# Version 217 (review 3 fix #6): and the hero's red rim flash (v216), on the last one
		# (the only one in the short warm-up), so the first hit in a run never stutters.
		heroes[i].hero_flash = i == heroes.size() - 1 and i != 1
		heroes[i].hit()
	made += _new(Game.world, old_world).filter(func(c): return not made.has(c))
	for i in 3:
		await tree.process_frame
	bar.progress(1.0, Time.get_ticks_msec() - started)
	Game.loading = ""

	for c in made:
		if is_instance_valid(c):
			c.queue_free()
	bar.queue_free()
	AudioServer.set_bus_mute(bus, muted)
	last_ms = Time.get_ticks_msec() - started
	last_core = core
	print("[warmup] %d ms%s" % [last_ms, " (first floor only)" if core else ""])
	return finished


## A thin bone-white bar low on the black launch screen. It stays hidden on a quick launch
## (most launches take under a second) and appears once the wait passes 0.4 seconds.
class _Bar extends CanvasLayer:
	var _fill: ColorRect
	var _box: Control

	func _init() -> void:
		layer = 11   # above the HUD's black fade, below the opening animation
		_box = Control.new()
		_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.visible = false
		add_child(_box)
		var label := Label.new()
		label.text = "Waking the dead..."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.82, 0.85))
		label.anchor_left = 0.0
		label.anchor_right = 1.0
		label.anchor_top = 0.62
		label.anchor_bottom = 0.62
		label.offset_top = -50
		label.offset_bottom = -12
		_box.add_child(label)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.12)
		track.anchor_left = 0.25
		track.anchor_right = 0.75
		track.anchor_top = 0.62
		track.anchor_bottom = 0.62
		track.offset_bottom = 6
		_box.add_child(track)
		_fill = ColorRect.new()
		_fill.color = Color(0.95, 0.72, 0.42)
		_fill.anchor_bottom = 1.0
		_fill.anchor_right = 0.0
		track.add_child(_fill)

	func progress(done: float, ms: int) -> void:
		if ms > 400:
			_box.visible = true
		_fill.anchor_right = clampf(done, 0.0, 1.0)


## What was added under `parent` since the warm-up began (only that is removed afterwards).
static func _new(parent: Node, old: Dictionary) -> Array:
	return parent.get_children().filter(func(c): return not old.has(c.get_instance_id()))


static func _ids(parent: Node) -> Dictionary:
	var ids := {}
	for c in parent.get_children():
		ids[c.get_instance_id()] = true
	return ids
