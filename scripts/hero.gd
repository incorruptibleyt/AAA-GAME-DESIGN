class_name Hero
extends Actor
## The player's hero. Drag your thumb to move; stand still and the hero automatically
## fires at the nearest skeleton.

# Starting numbers. Blessings (upgrades.gd) change these during a run.
var move_speed := 5.2
var damage := 12.0
var shots_per_second := 1.8
var bolt_speed := 17.0
var front_bolts := 1
var diagonal_bolts := 0
var rear_bolts := 0
var pierce := 0
var crit_chance := 0.05
var burn_dps := 0.0
## Healing per kill (the Barbarian), up to 4% of max health per point in each
## room: 8% for the Barbarian (uncapped, it healed back most of the damage taken on
## floors 1-4). (Version 239: the Bloodlust blessing that raised it became Thunder Catch.)
var heal_on_kill := 0.0
var kill_heal_left := 0.0
## From Bone Harvest: only heals while the Bone Chain is x2 or higher, and only up to 4% of
## max health per pick in each room (three picks used to heal back about 80% of all damage).
var harvest_heal := 0.0
var harvest_left := 0.0
## Soul Siphon's healing left in this room: 12% of max health per pick.
var siphon_left := 0.0
## Set by the chosen hero (heroes.gd).
var hero_id := "rogue"
## Version 314: the Legend Vault finisher this hero wears ("" for none): LegendFinish plays it
## when a skeleton falls (Game.on_enemy_died).
var finisher := ""
var bolt_size := 0.22
var bolt_color := Color(0.55, 0.85, 1.0)
var _finish_col = null   # a weapon finish's sparks when it fires (version 174)
var _finish_ms := 0
var bolt_push := 4.0
var splash := 0.0
var armor := 0.0
var _dash_ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
## From the Armory: survive one killing blow per run.
var second_wind := false
## Crypt Race (race.gd): seconds left lying down after a fall. A racer is never out.
var down_left := 0.0
## Blessings that aren't plain numbers.
var frost := false
var frost_time := 1.5
## Blessings taken this run, by id, for the ones that change rules rather than numbers.
var perks := {}
var _volleys := 0
## The special move fills from kills (elites and perfect dodges count more).
var special_charge := 0.0
var _spin_left := 0.0
var _spin_tick := 0.0
var magnet := 1.0
var coin_bonus := 0.0
## Frozen slow by a Frost Wraith's beam: seconds left.
var chill_left := 0.0
## Held in place by roots (Glowcap Grotto): seconds left. A dash tears free.
var snare_left := 0.0
## After the roots let go (or a dash tears free), a moment when roots can't take hold again,
## so two crawls in a row can't keep the hero pinned under the next attack.
var snare_guard := 0.0
## Version 271: inside a Hush Keeper's circle of letters (the Whispering Library) the weapon
## is silent: seconds left, topped up while the hero stays inside. Step out to fight again.
var hush_left := 0.0
var _hush_said := 0.0
## Version 274: wading through the Sand Pharaoh's sand (SandMound): seconds left, topped up
## while the hero stands in it. Slower until out.
var mired_left := 0.0
var _mired_said := 0.0
## Version 290: sliding on the Frozen Ossuary's black ice (IcePatch): the speed carried.
var _ice_vel := Vector3.ZERO
## Version 243, Frostfall's Blizzard (blizzard.gd): how cold the hero is (0..1; slower as it
## rises), and the block of ice they are frozen in (held like roots; a dash breaks it).
var cold := 0.0
var _ice: MeshInstance3D
## Hero blessings (upgrades.gd) tune these.
var dash_cooldown_time := DASH_COOLDOWN
var crit_mult := 2.0
var volley_rings := 3
var slam_reach := 5.0
var whirl_time := 2.5
var meteor_count := 5
## Bone Ward: hits blocked per room, and how many are left in this room.
var ward_max := 0
var ward := 0
var _ward_bubble: MeshInstance3D

## Dash: flick your thumb (or press Space) to zip a short way, untouchable while dashing.
const DASH_SPEED := 21.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 1.1
## Seconds after getting free of roots before they can take hold again.
const SNARE_GUARD := 1.5
const TWIN_GAIN := 1.4
var _dash_left := 0.0
## Version 292: thrown through the air by a Glowcap Grotto bounce cap (BounceCap): no
## steering, no shooting, out of reach until it lands.
## The most of the hero's full health one hit can take (deep review fix 2).
const HIT_CAP := 0.45
var fling_left := 0.0
var _fling_dur := 0.0
var _fling_vel := Vector3.ZERO
var _dash_cooldown := 0.0
## A dash asked for just before the dash recharged (DASH_BUFFER seconds early) goes off as
## soon as it's ready, instead of being lost (version 140).
const DASH_BUFFER := 0.12
var _dash_wanted := Vector3.ZERO
var _dash_wanted_t := 0.0
var _last_dash_ms := -100000
var _aura: MeshInstance3D
var _dash_dir := Vector3.ZERO
var _trail_t := 0.0
var _master := false
## A Master aura worn (hero_style.gd): its colours colour the dash trail and the dash ring.
var _master_aura := {}
var _ring_was_ready := true

var _shot_timer := 0.4
var _target: Actor
var _retarget := 0.0
var _invulnerable := 0.0
var _moving := false

## Version 233 (whole-game review, fix 2: the heroes fought the same way). The Knight fights
## up close. A skeleton within sword reach (melee_reach) is cut by a SWING: one wide arc in
## front that hits every skeleton in it at once and knocks enemy shots out of the air.
## Farther off he still throws his sword wave. Standing still he holds his shield up
## (guard): shots that come at him from the front clang off it.
var melee_reach := 0.0
var guard := false
var _guard_mark: MeshInstance3D
var _guard_mat: StandardMaterial3D
var _guard_flash := 0.0
var blocked := 0   # shots the shield has stopped this run
const SWING_MULT := 1.5   # a swing hits harder than a wave, and hits everything in the arc
const SWING_ARC := 65.0   # degrees either side of straight ahead (+15 for each Side Shots)
const GUARD_COS := 0.5    # the shield stops shots from within 60 degrees of straight ahead
static var _arc_meshes := {}

## Version 234 (fix 2, the Barbarian). His axes are boomerangs: each flies out a little past
## its target (boomerang = the least it flies, in metres), or until it runs out of cuts or
## hits a wall, then turns and flies back to his hand, cutting skeletons on the way back
## too. Piercing Shot means one more cut each way.
var boomerang := 0.0
var caught := 0   # axes caught this run
var _throw_reach := 0.0

## Version 235 (fix 2, the Mage). Moving (or dashing) in a fight builds arcane charge, full
## after CHARGE_TIME seconds; the first orb after stopping carries it: a big, slower orb that
## hits up to 2.2x as hard with a blast up to 1.7x as wide. Standing still doesn't charge.
## So the Mage plays a dance: dodge, stop, BOOM.
var charges := false
var arcane := 0.0
var charged_shots := 0   # big orbs thrown this run
var _charge_orb: MeshInstance3D
var _charge_full := false
const CHARGE_TIME := 1.2
const CHARGE_MIN := 0.25   # less than this and the next orb is a plain one

## Version 236 (fix 2, the Rogue). The only hero who fights on the run: while moving, the
## Rogue throws knives at the nearest skeleton (run_fire times the crossbow's rate, each
## KNIFE_SHARE of a bolt, Twin Shots and the other hit blessings count); standing still,
## the crossbow fires as before.
var run_fire := 0.0
var knives := 0   # thrown this run
var _knife_timer := 0.35
const KNIFE_SHARE := 0.6

## Version 239 (whole-game review fix 8): each hero's own blessings change how that hero
## attacks. They are looked up in `perks` (so a saved run brings them back by itself).
##   Knight:    Riposte (blocked shots fly back as sword waves), Cutting Wind (a swing
##              also throws a wide wave through the skeletons behind).
##   Barbarian: Thunder Catch (catching an axe slams the ground), Buzzsaw (axes hang
##              and grind at the far end: Projectile.hang).
##   Mage:      Burning Ground (charged orbs leave fire: Projectile._explode), Frost
##              Orbit (ice orbs circle the Mage while moving).
##   Rogue:     Shadow Step (a dash leaves a knife-throwing shadow: shadow_step.gd),
##              Ricochet (shots bounce on: Projectile.bounce).
const WIND_SHARE := 0.8      # Cutting Wind's wave, of a sword wave's damage
const WIND_LIFE := 0.5       # seconds it flies (about 7.5 m)
const RIPOSTE_COL := Color(1.0, 0.97, 0.82)
const THUNDER_R := 2.6       # Thunder Catch reaches this far round him
const THUNDER_SHARE := 0.6
var _thunder_cd := 0.0
const BUZZ_HANG := 0.6       # Buzzsaw: seconds an axe hangs at the far end
const ORBIT_N := 3
const ORBIT_R := 1.7
const ORBIT_SPIN := 4.2      # radians a second
const ORBIT_SHARE := 0.45
const ORBIT_COL := Color(0.62, 0.92, 1.0)
var _orbit: Node3D
var _orbit_a := 0.0
var _orbit_on := 0.0
var _orbit_next := {}        # skeleton's instance id -> when an ice orb may hit it again (ms)

## Version 307 (player panel fix 2): shared blessings that change how a run plays.
## Static Shots: a hit throws a spark of lightning on to the nearest other skeleton within
## SPARK_R (a second pick: on again to a third), for SPARK_SHARE of the hero's damage. At most
## one spark every SPARK_GAP seconds, so a fan of shots doesn't light up the room every frame.
const SPARK_R := 4.5
const SPARK_SHARE := 0.4
const SPARK_GAP_MS := 200
const SPARK_COL := Color(0.72, 0.9, 1.0)
var _spark_ms := -100000
## Spinning Bones: bone blades circle the hero in every fight (two, three with a second pick).
const BONES_R := 1.3
const BONES_SPIN := 5.2      # radians a second (the other way round from Frost Orbit)
const BONES_SHARE := 0.5
const BONES_EVERY_MS := 400
const BONE_COL := Color(0.97, 0.94, 0.84)
var _bones: Node3D
var _bones_n := 0
var _bones_a := 0.0
var _bones_next := {}
## Blazing Dash: patches of fire along the dash. Phantom Dash: each skeleton the dash
## passes through is cut once (PHANTOM_MULT of the hero's damage).
const BLAZE_STEP := 1.1
const PHANTOM_MULT := 2.0
var _dash_from := Vector3.ZERO
var _phantom_cut: Array[Actor] = []
## Cold Snap: the special freezes every skeleton within COLD_SNAP_R solid for COLD_SNAP_TIME.
const COLD_SNAP_R := 4.5
const COLD_SNAP_TIME := 2.0
# Version 308 (player panel fix 2, part 2): the epics change the special, and three new pairs.
const QUIVER_TURN := 0.42   # Shadow Quiver: the volley's knives turn for home after this long
const AFTERSHOCK_DELAY := 0.9
const AFTERSHOCK_REACH := 1.35
const AFTERSHOCK_COL := Color(1.0, 0.8, 0.45, 0.6)
const WHIRL_LONGER := 1.4
const WHIRL_PULL_R := 7.0
const WHIRL_PULL := 6.5
const CRATER_R := 1.5
const CRATER_TIME := 4.0
const FROST_GHOST_TIME := 1.2
const STORM_R := 6.0
const STORM_GAP_MS := 150
var _storm_ms := 0
var _shadow: ShadowStep


static func spawn(parent: Node, pos: Vector3, id := "rogue") -> Hero:
	var cfg := Game._load_save()
	var def := HeroStyle.styled(cfg, Heroes.get_hero(id))   # the looks picked on the Style screen
	var h := Hero.new()
	h.name = "Hero"
	h.team = Team.HERO
	h.radius = 0.45
	h.center_height = 1.0
	h.hero_id = def.id
	h.finisher = str(def.get("style", {}).get("legend", {}).get("finisher", ""))
	h.init_health(def.health)
	h.move_speed = def.move_speed
	h.damage = def.damage
	h.shots_per_second = def.rate
	h.bolt_speed = def.bolt_speed
	h.bolt_size = def.bolt_size
	h.bolt_color = def.bolt_color
	h._finish_col = LookFx.FINISH_SPARK.get(str(def.get("style", {}).get("finish", "")))
	h.bolt_push = def.get("push", 4.0)
	h.pierce = def.get("pierce", 0)
	h.armor = def.get("armor", 0.0)
	h.splash = def.get("splash", 0.0)
	h.heal_on_kill = def.get("heal_on_kill", 0.0)
	h.melee_reach = def.get("melee", 0.0)
	h.guard = def.get("guard", false)
	h.boomerang = def.get("boomerang", 0.0)
	h.charges = def.get("charge", false)
	h.run_fire = def.get("run_fire", 0.0)
	parent.add_child(h)
	h.global_position = pos
	h.make_visual(Heroes.look(def))
	# (Version 182: with an aura on, the glow's ring is fainter, so the two don't stack into
	# one sparkling blob round the feet.)
	h._build_feet_marker(def.ring, def.get("ring2"), str(def.get("ring_fx", "flow")), int(def.get("ring_tier", 0)), 0.5 if def.has("aura") else 1.0)
	if HeroMastery.has_frame(cfg, def.id):
		h._build_gold_ring(HeroMastery.frame_color(HeroMastery.level(cfg, def.id)))   # Hero Mastery level 10 (+ tiers)
		h._master = true
	h._master_aura = def.get("aura", {})
	if not h._master_aura.is_empty():
		h._build_motif()   # a Master aura's own trail of light, instead of the gold sparkles
		if h._master_aura.get("sigil", false):
			h._rings.append(CryptSigil.make(h, 1.5, 0.45))   # the Crypt King's turning gold sigil (2.4 m before v142: it hid the hero's feet and nearby shots)
	elif h._master or HeroStyle.worn(cfg, def.id, "glow") in ["gold", HeroStyle.PASS_KEY]:
		h._build_sparkles()   # Masters (and the Gold glow) leave a trail of gold sparkles
	h._build_dash_ring()
	if h.guard:
		h._build_guard_mark()
	if h.charges:
		h._build_charge_orb()
	# Curse mastery rewards (curses.gd): a red lantern, a grave aura, golden bolts.
	var mastery := Curses.mastery(cfg, def.id)
	if mastery >= 10 and HeroStyle.worn(cfg, def.id, "glow") == "":
		h.bolt_color = Color(1.0, 0.8, 0.3)   # a glow picked on the Style screen wins
	if mastery >= 6:
		h._build_aura()
	# A soft light that travels with the hero so they never get lost in the dark.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.45, 0.42) if mastery >= 2 else Color(0.75, 0.85, 1.0)
	lantern.light_energy = LANTERN_ENERGY
	lantern.omni_range = LANTERN_RANGE
	lantern.position = Vector3(0, 3.6, 0.6)   # high and slightly behind, so the hood isn't blown out
	h.add_child(lantern)
	h.lantern = lantern
	return h


## The hero's lantern, and how it burns in a normal room. Under the Omen of Night (v241) it
## is the main light of the room (Game._night_light).
const LANTERN_ENERGY := 0.9
const LANTERN_RANGE := 8.0
var lantern: OmniLight3D


func place_at(pos: Vector3) -> void:
	visible = true   # hidden on the VICTORY screen
	global_position = pos
	rotation = Vector3.ZERO
	knockback = Vector3.ZERO
	_shot_timer = 0.4
	# A Whirlwind or a chill still running when the last room ended doesn't follow the hero
	# into the next one (the spin used to start the new room by itself, half a turn round).
	_spin_left = 0.0
	chill_left = 0.0
	mired_left = 0.0
	snare_left = 0.0
	snare_guard = 0.0
	cold = 0.0
	_thaw()
	_safe_left = 0.0
	if visual:
		visual.rotation.y = 0.0
	if is_instance_valid(_shadow):
		_shadow.vanish()


func can_be_hit() -> bool:
	return not dead and down_left <= 0.0 and _invulnerable <= 0.0 and _dash_left <= 0.0 and _safe_left <= 0.0 and fling_left <= 0.0 and Game.state == Game.State.PLAYING


func heal(amount: float) -> void:
	var before := health
	super.heal(amount)
	Game.report_event("healed", health - before)


func is_dashing() -> bool:
	return _dash_left > 0.0


## For the Grave Pact curse: a dash in the last 1.5 seconds.
func dashed_recently() -> bool:
	return Time.get_ticks_msec() - _last_dash_ms < 1500


## Throws the hero through the air at `vel` for `dur` seconds (BounceCap).
func fling(vel: Vector3, dur: float) -> void:
	fling_left = dur
	_fling_dur = dur
	_fling_vel = vel
	face(vel, 100.0, 1.0)


func dash_ready() -> bool:
	return _dash_cooldown <= 0.0


## Start a dash along `dir` (on the floor). Does nothing while it's recharging.
func dash(dir: Vector3) -> void:
	dir.y = 0.0
	# (Version 164: not before the tutorial teaches it in room 2, a flick used to dash in room 1.)
	if dead or down_left > 0.0 or fling_left > 0.0 or dir.length_squared() < 0.01 or Game.state != Game.State.PLAYING or not Game.dash_unlocked():
		return
	if not dash_ready():
		if _dash_cooldown <= DASH_BUFFER:
			_dash_wanted = dir
			_dash_wanted_t = DASH_BUFFER + 0.02
		return
	_dash_wanted_t = 0.0
	if perks.has("shadowstep"):
		_shadow_step()
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_dash_from = global_position
	_phantom_cut.clear()
	if snare_left > 0.0:
		snare_left = 0.0   # tearing free of the roots
		snare_guard = SNARE_GUARD
		Fx.magic(center(), RootCrawl.LIME if _ice == null or not _ice.visible else Color(0.75, 0.92, 1.0), 12)
		if _ice and _ice.visible:
			Fx.impact(center(), Color(0.8, 0.95, 1.0))
			Sfx.play("crack", 0.6, 1.3)
		_thaw()
	_last_dash_ms = Time.get_ticks_msec()
	_dash_cooldown = dash_cooldown_time
	_trail_t = 0.0
	knockback = Vector3.ZERO
	rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	Sfx.play("dash", 0.7)
	Game.report_event("dash")
	Fx.dust(global_position, 10)
	_perfect_done = false
	_check_perfect(PERFECT_WINDOW)


## Grave Dash: dashing through a red shot just before it lands is a perfect dodge, and
## so is dashing out of any warning on the floor (a beam, a blast circle, a lunge) as it lands.
## Time slows, nearby shots shatter, and the hero answers with a ring of bolts.
const PERFECT_WINDOW := 0.22
## A plain shot gives a PERFECT only in the last 0.14 s before it would hit (version 119: it
## was 0.22 s like the floor warnings, and PERFECTs came about 12 a minute on floor 1).
const SHOT_WINDOW := 0.14
var _perfect_done := false
## A PERFECT is only for an attack you really avoided: none in the moment after you were
## hurt (a blast that already hit you used to still count as you dashed out of it), and after
## a perfect dash a short safety covers the gap between the dash (DASH_TIME) and the window,
## so "PERFECT!" and your own damage never show together.
const HURT_GRACE_MS := 350
var _hurt_ms := -100000
var _safe_left := 0.0
## The dark disc and coloured ring at the hero's feet (hidden when they die).
var _rings: Array[Node3D] = []
## The aura's circling lights and sunburst: kept from turning with the hero (a dash turns
## the hero's node, and they jumped round with it).
var _aura_fx: Node3D
var _chain_mat: ShaderMaterial   # the Bone Chain aura's links (version 254), lit by the run's chain
var _chain_lit := 0.0


func _check_perfect(window: float) -> void:
	if _perfect_done or Time.get_ticks_msec() - _hurt_ms < HURT_GRACE_MS:
		return
	for p in Projectile.danger:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.time_to_hit(global_position, radius + 0.15) <= minf(window, SHOT_WINDOW):
			_perfect_dodge()
			return
	var kind := Telegraph.dodged(global_position, radius, window)
	if kind > 0:
		_perfect_dodge(kind == 2)


func _perfect_dodge(big := true) -> void:
	Game.buzz(25 if big else 12)
	_perfect_done = true
	_safe_left = maxf(_safe_left, PERFECT_WINDOW - DASH_TIME + 0.05)
	# An elite's swipe (the light kind) is worth less: no free dash, a smaller special charge.
	if big:
		_dash_cooldown = 0.0
	add_charge(0.25 if big else 0.1)
	for p in Projectile.danger.duplicate():
		if is_instance_valid(p) and p.global_position.distance_to(global_position) < 3.0:
			p.shatter()
	Game.perfect_dodge(center(), big)
	# Soul Siphon heals; Frozen Ground chills every skeleton within 5 m.
	if perks.has("siphon"):
		var h := minf(minf(10.0 * perks.siphon, siphon_left), max_health - health)
		if h > 0.0:
			siphon_left -= h
			heal(h)
	if perks.has("frozen_ground"):
		Fx.shockwave(global_position, Color(0.6, 0.92, 1.0), 5.0)
		for a: Actor in Actor.all:
			if a is Enemy and not a.dead and a.global_position.distance_to(global_position) < 5.0:
				(a as Enemy).chill(maxf(frost_time, 2.0))
	var col := bolt_color.lerp(Color.WHITE, 0.4)
	for i in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0 + rotation.y)
		var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 1.1 + d * 0.5, d, damage * 1.5 * Game.chain_damage(), bolt_speed, col, bolt_size)
		p.pierce = pierce + 1
		p.push = bolt_push


func wants_outline() -> bool:
	return true


func special_ready() -> bool:
	return special_charge >= 1.0


func add_charge(amount: float) -> void:
	if Game.curses.has("quick"):
		amount *= 2.0   # Daily Crypt rule: Quick Hands
	var was := special_ready()
	special_charge = minf(1.0, special_charge + amount)
	if special_ready() and not was:
		Sfx.play("upgrade", 0.5)


## Each hero has one big move, used from the button on the right.
func use_special() -> void:
	if dead or down_left > 0.0 or not special_ready() or Game.state != Game.State.PLAYING or not Game.special_unlocked():
		return
	# Version 219 (review 4 fix 30): a full chain feeds the special. Cast at the chain's cap
	# and half the charge comes straight back.
	var full_chain := Game.chain >= Game.CHAIN_FULL - 0.01   # v220: x3 for every build
	special_charge = 0.5 if full_chain else 0.0
	if full_chain:
		Fx.magic(center(), Color(1.0, 0.9, 0.5), 18)
	Game.report_event("special")
	if Game.curses.has("blood"):
		# Blood Price: the special costs a quarter of max health, but never kills.
		health = maxf(1.0, health - max_health * 0.25)
		Game.hud.flash(Color(0.9, 0.1, 0.1), 0.3)
	Game.hud.tip("", 0.0)
	# Version 218 (review 4): the special's name only for the first 3 casts of a run (the
	# button already shows it; every cast put big words over the fight), and nearly white
	# so it reads on any floor (2.7:1 before).
	if int(Game._rep.get("special", 0)) <= 3:
		Game.hud.callout(Heroes.get_hero(hero_id).special.to_upper() + "!", bolt_color.lerp(Color.WHITE, 0.7), true)
	Game.shake(0.25)
	Game.calm_glow(2.2)
	match hero_id:
		"knight": _shield_slam()
		"barbarian":
			_spin_left = whirl_time * (WHIRL_LONGER if perks.has("whirl") else 1.0)
			Sfx.play("dash", 0.9)
		"mage": _meteors()
		_: _shadow_volley()
	if perks.has("cold_snap"):
		_cold_snap()


func _special_hit(a: Actor, amount: float, from: Vector3, push: float) -> void:
	var d := a.global_position - from
	d.y = 0.0
	a.take_damage(amount * Game.chain, d, push)   # specials get the full chain


func _shadow_volley() -> void:
	for wave in volley_rings:
		get_tree().create_timer(0.22 * wave, false).timeout.connect(func():
			if dead:
				return
			Sfx.play("shoot", 0.9)
			for i in 12:
				var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + wave * 0.33) / 12.0)
				var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 1.1 + d * 0.5, d, damage * 1.4 * Game.chain, bolt_speed, bolt_color.lerp(Color(0.6, 0.3, 1.0), 0.4), bolt_size)
				p.pierce = pierce + 1
				p.push = bolt_push
				p.recall_after(QUIVER_TURN if perks.has("quiver") else 0.0))   # Shadow Quiver (version 308)
	if perks.has("quiver"):
		get_tree().create_timer(QUIVER_TURN + 0.05, false).timeout.connect(func():
			Game._teach("quiver", "SHADOW QUIVER: knives fly back, cutting again!"))


func _shield_slam() -> void:
	visual.attack()
	Game.finisher(global_position, 0.35, 0.3, Color(1, 0.95, 0.7), 0.12)
	_invulnerable = maxf(_invulnerable, 1.2)
	_slam(slam_reach, 3.0, 14.0)
	if perks.has("aftershock"):
		# Aftershock (version 308): the floor answers a second later with a bigger slam,
		# reaching the skeletons the first one threw back.
		Fx.shockwave(global_position, AFTERSHOCK_COL, slam_reach * AFTERSHOCK_REACH)
		get_tree().create_timer(AFTERSHOCK_DELAY, false).timeout.connect(func():
			if dead or Game.state != Game.State.PLAYING:
				return
			visual.attack()
			Game.shake(0.3)
			Sfx.play("boom", 0.55, 0.8)
			_slam(slam_reach * AFTERSHOCK_REACH, 2.0, 9.0)
			Game._teach("aftershock", "AFTERSHOCK: Shield Slam hits a second time!"))


func _slam(reach: float, mult: float, push: float) -> void:
	Fx.shockwave(global_position, Color(1, 0.9, 0.6), reach)
	Fx.dust(global_position, 30)
	for a: Actor in Actor.all.duplicate():
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		if a.global_position.distance_to(global_position) < reach + a.radius:
			_special_hit(a, damage * mult, global_position, push)
			if not a.dead and a is Enemy:
				(a as Enemy).chill(2.5)


func _meteors() -> void:
	var targets := Actor.all.filter(func(a: Actor): return a.team == Team.UNDEAD and a.can_be_hit())
	targets.sort_custom(func(a: Actor, b: Actor): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	targets = targets.slice(0, meteor_count)
	if targets.is_empty():
		targets = [self]   # nothing around: one meteor lands in front so the move isn't wasted
	for i in targets.size():
		var spot: Vector3 = targets[i].global_position if targets[i] != self else global_position - basis.z * 3.0
		spot.y = 0.0
		get_tree().create_timer(0.15 * i, false).timeout.connect(func(): _meteor(spot))


func _meteor(spot: Vector3) -> void:
	if Room.current == null:
		return
	var mark := U.floor_quad(Room.current, Vector2(4.4, 4.4), U.unlit(Color(1, 0.75, 0.3, 0.5), U.soft_circle()).duplicate(), spot + Vector3.UP * 0.05)
	var rock := Node3D.new()
	Room.current.add_child(rock)
	rock.global_position = spot + Vector3.UP * 9.0
	U.sphere(rock, 0.45, U.unlit(Color(1, 0.55, 0.2)))
	U.sphere(rock, 0.3, U.unlit(Color(1, 0.95, 0.7)))
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", spot + Vector3.UP * 0.3, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		rock.queue_free()
		mark.queue_free()
		Fx.shockwave(spot, Color(1, 0.55, 0.2), 2.4)
		Fx.magic(spot + Vector3.UP * 0.5, Color(1, 0.6, 0.2), 20)
		Sfx.play("boom", 0.7)
		Game.shake(0.2)
		for a: Actor in Actor.all.duplicate():
			if a.team == Team.UNDEAD and a.can_be_hit() and a.global_position.distance_to(spot) < 2.2 + a.radius:
				_special_hit(a, damage * 3.0, spot, 8.0)
				if not a.dead:
					Burning.apply(a, maxf(burn_dps, 8.0), 3.0)
		if perks.has("meteors"):
			_crater(spot))


## Meteor Storm (version 308): a scorched crater where the meteor struck, burning for a while.
func _crater(spot: Vector3) -> void:
	if Room.current == null:
		return
	FirePatch.spawn_hero(spot, CRATER_R, CRATER_TIME, maxf(burn_dps, 8.0 + 0.4 * damage))
	var scorch := U.floor_quad(Room.current, Vector2(CRATER_R * 2.6, CRATER_R * 2.6), U.unlit(Color(0.1, 0.05, 0.03, 0.7), U.soft_circle()).duplicate(), spot + Vector3.UP * 0.02)
	var mat := scorch.material_override as StandardMaterial3D
	var tw := scorch.create_tween()
	tw.tween_interval(CRATER_TIME - 0.8)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(scorch.queue_free)
	Game._teach("meteors", "METEOR STORM: meteors leave burning craters!")


func _whirlwind(delta: float) -> void:
	_spin_left -= delta
	visual.rotation.y += delta * 22.0
	_spin_tick -= delta
	if _spin_tick <= 0.0:
		_spin_tick = 0.16
		Fx.trail(center(), Color(1, 0.7, 0.4))
		var hit_any := false
		for a: Actor in Actor.all.duplicate():
			if a.team == Team.UNDEAD and a.can_be_hit() and a.global_position.distance_to(global_position) < 2.8 + a.radius:
				_special_hit(a, damage * 0.75, global_position, 5.0)   # (0.8 of 16 before version 234)
				hit_any = true
		# One heal per spin tick, not one per enemy caught (a big crowd healed to full).
		if hit_any:
			heal(1.0)
		if perks.has("whirl"):
			_whirl_pull()
	if _spin_left <= 0.0:
		visual.rotation.y = 0.0


## Endless Whirl (version 308): the whirlwind drags skeletons (not bosses) in towards the
## Barbarian, harder the closer they are, so a crowd is pulled into the blades.
func _whirl_pull() -> void:
	for a: Actor in Actor.all:
		if a.team != Team.UNDEAD or not a.can_be_hit() or not a is Enemy or (a as Enemy).is_boss:
			continue
		var to := global_position - a.global_position
		to.y = 0.0
		var d := to.length()
		if d > WHIRL_PULL_R or d < 1.3:
			continue
		a.knockback += to / d * WHIRL_PULL * (a as Enemy).knockback_scale * (1.2 - 0.6 * d / WHIRL_PULL_R)
	Game._teach("whirl", "ENDLESS WHIRL: your whirlwind drags skeletons in!")


## Kill healing. Only what actually heals is taken from the room's allowance, so kills at
## full health don't use it up (three Bone Harvests used to heal about 13 a floor).
func on_kill() -> void:
	var missing := max_health - health
	var amount := minf(minf(heal_on_kill, kill_heal_left), missing)
	kill_heal_left -= amount
	if Game.chain >= 2.0 and harvest_left > 0.0:
		# Version 213: 1% of max health per kill per pick (a flat 2 was nothing deep down).
		var h := minf(minf(max_health * 0.005 * harvest_heal, harvest_left), missing - amount)
		harvest_left -= h
		amount += h
	if amount > 0.0:
		heal(amount)


## Version 336 (visual review fix 1): the run camera looks down on the hero, and the Mage's
## own hat brim covered the whole body: from above the Mage was a lilac disc. In a run the
## brim draws narrower (the cone keeps its height); on the title, where the camera sees the
## Mage from the front, it eases back to full size (Game._lobby).
const RUN_BRIM := 0.68
var _brim: Node3D
var _brim_base := Vector3.ONE
var _brim_looked := false

func _update_brim() -> void:
	if not _brim_looked:
		_brim_looked = true
		if visual:
			var hats := visual.find_children("Mage_Hat", "MeshInstance3D", true, false)
			if not hats.is_empty():
				_brim = hats[0] as Node3D
				_brim_base = _brim.scale
	if _brim == null or not is_instance_valid(_brim):
		return
	var k := lerpf(RUN_BRIM, 1.0, clampf(Game._lobby, 0.0, 1.0))
	_brim.scale = Vector3(_brim_base.x * k, _brim_base.y, _brim_base.z * k)


func _process(delta: float) -> void:
	_update_brim()
	delta = minf(delta, MAX_STEP)   # v282 (Tweaks report #7): a long frame is a short slow-down, never a jump
	if dead:
		return
	if down_left > 0.0:
		_lie_down(delta)
		return
	_update_ward_bubble()
	_update_dash_ring()
	_update_guard_mark(delta)
	_update_charge(delta)
	_thunder_cd -= delta
	if perks.has("frost_orbit"):
		_update_orbit(delta)
	if perks.has("orbit"):
		_update_bones(delta)
	if is_instance_valid(_aura_fx):
		_aura_fx.rotation.y = -rotation.y
	if _chain_mat:
		_update_chain_aura(delta)
	_dash_cooldown -= delta
	if _dash_wanted_t > 0.0:
		_dash_wanted_t -= delta
		if dash_ready() and _dash_wanted_t > 0.0:
			dash(_dash_wanted)
	if _safe_left > 0.0 and _dash_left <= 0.0:
		_safe_left -= delta
	if _dash_left > 0.0:
		_dash_left -= delta
		move_by(_dash_dir * DASH_SPEED * delta, delta)
		if perks.has("phantom"):
			_phantom_cuts()
		if _dash_left <= 0.0:
			_ice_vel = _dash_dir * move_speed * 1.3   # v290: a dash that ends on ice slides on
			if perks.has("blaze_dash"):
				_blaze_trail()
		visual.set_moving(true)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.025
			Fx.trail(center(), _trail_color())
		_shot_timer = maxf(_shot_timer, 0.1)
		_check_perfect(0.0)
		return
	if fling_left > 0.0:
		# v292: flying from a bounce cap: carried along an arc, then a stamp on landing.
		fling_left -= delta
		move_by(_fling_vel * delta, delta)
		visual.position.y = sin(PI * clampf(1.0 - fling_left / _fling_dur, 0.0, 1.0)) * BounceCap.HEIGHT
		visual.set_moving(false)
		_shot_timer = maxf(_shot_timer, 0.1)
		if fling_left <= 0.0:
			visual.position.y = 0.0
			_ice_vel = Vector3.ZERO
			BounceCap.land(self)
		return
	if _invulnerable > 0.0:
		_invulnerable -= delta
		visual.set_visible_blink(_invulnerable <= 0.0 or fmod(_invulnerable, 0.12) > 0.05)

	var playing := Game.state == Game.State.PLAYING
	if _spin_left > 0.0 and playing:
		_whirlwind(delta)
		_shot_timer = maxf(_shot_timer, 0.1)
	var stick := Vector2.ZERO
	if playing:
		stick = Game.hud.joystick + Game.keyboard_move()
		stick = stick.limit_length(1.0)
	var move := Vector3(stick.x, 0, stick.y)
	_moving = move.length_squared() > 0.02
	visual.set_moving(_moving)

	if chill_left > 0.0:
		chill_left -= delta
		if randf() < delta * 8.0:
			Fx.magic(center(), Color(0.6, 0.9, 1.0), 2)
	_mired_said -= delta
	if mired_left > 0.0:
		mired_left -= delta
		if _moving and randf() < delta * 10.0:
			Fx.dust(global_position, 2)
	_hush_said -= delta
	if hush_left > 0.0:
		hush_left -= delta
		if randf() < delta * 7.0:
			Fx.magic(global_position + Vector3.UP * 1.6, HushCircle.TEAL, 1)
	if snare_guard > 0.0:
		snare_guard -= delta
	if snare_left > 0.0:
		snare_left -= delta
		if snare_left <= 0.0:
			snare_guard = SNARE_GUARD
			_thaw()
		if _moving:
			# Held by the roots: it can turn and strain, but not move (shooting goes on).
			face(move, 18.0, delta)
			_moving = false
			visual.set_moving(false)
	var want := Vector3.ZERO
	if _moving:
		want = move * move_speed * (1.3 if _spin_left > 0.0 else 1.0) * (0.6 if chill_left > 0.0 else 1.0) * (SandMound.SLOW if mired_left > 0.0 else 1.0) * (1.0 - Blizzard.SLOW * cold)
	var on_ice := not IcePatch.all.is_empty() and _dash_left <= 0.0 and snare_left <= 0.0 and IcePatch.under(global_position) != null
	if on_ice:
		# v290: on ice the stick only slowly changes the slide, and a slide carries on.
		if _ice_vel.length() > 1.0:
			Game.danger_warn("ice", "ICE!", "BLACK ICE: you slide and keep gliding on it!", IcePatch.ICE)
		_ice_vel = _ice_vel.move_toward(want, (IcePatch.GRIP if _moving else IcePatch.DRAG) * delta)
		if not _moving and _ice_vel.length() > 0.3:
			move_by(_ice_vel * delta, delta)
			if randf() < delta * 12.0:
				Fx.magic(global_position + Vector3.UP * 0.1, IcePatch.ICE, 1)
	else:
		_ice_vel = want
	if _moving:
		move_by((_ice_vel if on_ice else want) * delta, delta)
		face(move, 18.0, delta)
		# The reload keeps counting while you move (it used to wait), and firing resumes
		# shortly after you stop.
		_shot_timer = maxf(_shot_timer - delta, 0.12)
		_retarget = 0.0   # and aims from where you stopped
		if run_fire > 0.0 and playing:
			_run_knives(delta)
	else:
		move_by(Vector3.ZERO, delta)
		if playing:
			_auto_attack(delta)

	if playing and Room.current and Room.current.is_at_exit(global_position):
		Game.enter_next_room()


func _auto_attack(delta: float) -> void:
	_shot_timer -= delta
	# Checking every skeleton's line of fire is costly, so the target is re-picked a few
	# times a second, or straight away when it dies.
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_target) or not _target.can_be_hit():
		_target = _pick_target()
		_retarget = 0.15
	var target := _target
	if target == null:
		return
	var to := target.global_position - global_position
	face(to, 30.0, delta)
	if hush_left > 0.0:
		# Hushed (version 271): it still turns to its target but can't fire, and fires
		# almost at once after stepping out.
		_shot_timer = maxf(_shot_timer, 0.15)
		return
	if _shot_timer > 0.0:
		return
	# The time left over this frame counts toward the next shot (at most 0.1 s of it, so a
	# long wait doesn't fire a burst). Resetting to a full gap threw away about half a frame a
	# shot: 3-11% fewer shots at 30 FPS on cheap phones (audit fix 3).
	_shot_timer = maxf(_shot_timer, -0.1) + 1.0 / shots_per_second
	to.y = 0.0
	if melee_reach > 0.0 and to.length() < melee_reach + target.radius:
		_swing(to.normalized())
	else:
		_shoot(to.normalized())


## The nearest skeleton the hero can actually hit; if every one is behind cover, just the nearest.
## Lines of fire are checked nearest first, so usually only one is.
func _pick_target() -> Actor:
	var near: Array = []
	for a: Actor in Actor.all:
		if a.team == Team.UNDEAD and a.can_be_hit():
			near.append([(a.global_position - global_position).length_squared(), a])
	if near.is_empty():
		return null
	near.sort_custom(func(x, y): return x[0] < y[0])
	if Room.current:
		for n in near:
			if Room.current.clear_shot(global_position, n[1].global_position):
				return n[1]
	return near[0][1]


func _shoot(fwd: Vector3) -> void:
	visual.attack()
	var shot := "shoot_" + hero_id
	Sfx.play(shot if Sfx.has(shot) else "shoot", 0.5)
	var right := fwd.cross(Vector3.UP).normalized()
	var origin := global_position + Vector3.UP * 1.1 + fwd * 0.6
	# Version 174: a Frostforged, Emberforged, Gilded or Voidsteel weapon throws sparks of its
	# own colour as it fires (at most four times a second).
	if _finish_col != null and Time.get_ticks_msec() - _finish_ms > 250:
		_finish_ms = Time.get_ticks_msec()
		Fx.sparks(origin, _finish_col)
	var col := Color(1.0, 0.55, 0.2) if burn_dps > 0.0 else bolt_color
	if boomerang > 0.0:
		# Axes fly 2.5 m past the target (never short of `boomerang`), so a miss still turns
		# behind it and can cut it from behind on the way back.
		var far := 0.0
		if is_instance_valid(_target):
			far = Vector2(_target.global_position.x - global_position.x, _target.global_position.z - global_position.z).length()
		_throw_reach = clampf(far + 2.5, boomerang, 14.0)
	var share := front_share()
	# The Mage's charged orb: the volley straight ahead carries the charge (in quarter steps,
	# so the orb looks stay few and pooled).
	var boost := 0.0
	if charges and arcane >= CHARGE_MIN:
		boost = snappedf(arcane, 0.25)
		arcane = 0.0
		_charge_full = false
		charged_shots += 1
		Sfx.play("cast", 0.4 + 0.3 * boost, 1.15 - 0.2 * boost)
		Fx.magic(origin, bolt_color, int(8 + 14 * boost))
		Game._teach("mage_charge", "CHARGE: move to charge, stop for a big blast!")
	for i in front_bolts:
		var offset := (i - (front_bolts - 1) * 0.5) * 0.35
		_fire(origin + right * offset, fwd, col, share, boost)
	for i in diagonal_bolts:
		var angle := deg_to_rad(30.0 + i * 15.0)
		_fire(origin, fwd.rotated(Vector3.UP, angle), col)
		_fire(origin, fwd.rotated(Vector3.UP, -angle), col)
	for i in rear_bolts:
		_fire(global_position + Vector3.UP * 1.1 - fwd * 0.6, -fwd, col)
	_bone_storm(fwd, origin)


## The Rogue's knives on the run: one at the nearest skeleton in sight whenever the knife
## hand is ready. The body keeps facing the way it runs.
func _run_knives(delta: float) -> void:
	_knife_timer -= delta
	if hush_left > 0.0:
		return
	if _knife_timer > 0.0:
		return
	var t := _pick_target()
	if t == null:
		_knife_timer = 0.1
		return
	var to := t.global_position - global_position
	to.y = 0.0
	if to.length() > 13.0:
		_knife_timer = 0.1
		return
	_knife_timer = 1.0 / maxf(shots_per_second * run_fire, 0.1)
	knives += 1
	var d := to.normalized()
	var origin := global_position + Vector3.UP * 1.1 + d * 0.5
	var p := Projectile.fire(Team.HERO, origin, d, damage * KNIFE_SHARE * pow(TWIN_GAIN, front_bolts - 1) * Game.chain_damage(), bolt_speed * 1.15, Color(0.86, 0.92, 1.0), bolt_size * 0.85, "Shot", "shard")
	p.pierce = pierce
	p.push = bolt_push * 0.5
	p.crit_chance = crit_chance
	p.crit_mult = crit_mult
	p.burn_dps = burn_dps
	p.frost = frost
	p.bounce = int(perks.get("ricochet", 0))
	p.wall_bounce = int(perks.get("bounce", 0))
	Sfx.play("swing", 0.25, 1.6)
	Game._teach("rogue_knives", "KNIVES: knives on the run, crossbow standing!")


## Bone Storm: every third volley (or swing) also throws a ring of piercing bone shards.
func _bone_storm(fwd: Vector3, origin: Vector3) -> void:
	_volleys += 1
	if perks.has("bonestorm") and _volleys % 3 == 0:
		for i in 10:
			var d := fwd.rotated(Vector3.UP, TAU * (i + 0.5) / 10.0)
			var p := Projectile.fire(Team.HERO, origin - fwd * 0.6 + d * 0.5, d, damage * 0.7 * Game.chain_damage(), bolt_speed * 0.85, Color(0.95, 0.92, 0.8), bolt_size * 0.9, "Shot", "shard")
			p.pierce = 2
			p.push = bolt_push * 0.5


## The Knight's sword swing (version 233): every skeleton within reach in the arc in front
## is hit at once, for more than a sword wave. Blessings still count: each Twin Shots adds
## the same 40% it adds to a volley and a little reach, each Side Shots widens the arc, Back
## Shots cuts behind too; crits, burning, frost and Bone Storm work as they do on shots.
func _swing(fwd: Vector3) -> void:
	visual.attack()
	Sfx.play("swing", 0.7, randf_range(0.92, 1.08))
	var half := deg_to_rad(minf(SWING_ARC + 15.0 * diagonal_bolts, 180.0))
	var reach := melee_reach + 0.25 * (front_bolts - 1)
	var col := Color(1.0, 0.55, 0.2) if burn_dps > 0.0 else bolt_color
	_slash(fwd, half, reach, col)
	var back_cos := cos(deg_to_rad(50.0))
	if rear_bolts > 0:
		_slash(-fwd, deg_to_rad(50.0), reach, col)
	if _finish_col != null and Time.get_ticks_msec() - _finish_ms > 250:
		_finish_ms = Time.get_ticks_msec()
		Fx.sparks(global_position + Vector3.UP * 1.1 + fwd * 0.8, _finish_col)
	var dmg := damage * SWING_MULT * pow(TWIN_GAIN, front_bolts - 1) * Game.chain_damage()
	var cos_half := cos(half)
	var hits := 0
	var cut: Array[Actor] = []
	for a: Actor in Actor.all.duplicate():
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		if dist > reach + a.radius:
			continue
		var dn := d / maxf(dist, 0.001)
		var ahead := dn.dot(fwd)
		# (Anything pressed right against him is hit whichever side it is on.)
		if dist > a.radius + radius + 0.2 and ahead < cos_half and not (rear_bolts > 0 and ahead < -back_cos):
			continue
		# Version 272: a Geode Guard's shield turns the blade from the front too.
		if a is Enemy and (a as Enemy).blocks_shot(dn):
			(a as Enemy).on_block(a.center() - dn * a.radius)
			continue
		var crit := randf() < crit_chance
		Fx.impact(a.center(), Color.WHITE.lerp(col, 0.5) if crit else col, 1.6 if crit else 1.1)
		a.take_damage(dmg * crit_mult if crit else dmg, dn, bolt_push * 1.4, crit)
		hits += 1
		cut.append(a)
		if burn_dps > 0.0 and not a.dead:
			Burning.apply(a, burn_dps, 2.5)
		elif crit and perks.has("flashfire") and not a.dead:
			Burning.apply(a, 8.0, 2.5)   # Flashfire
		if (frost or Blizzard.heart_chill()) and not a.dead and a is Enemy:
			(a as Enemy).frost_hit(frost_time, self)
	if hits > 0:
		spark_from(cut[0])
		Sfx.play("hit", 0.7)
		Game.shake(0.05 + 0.03 * mini(hits, 4))
	# The blade knocks enemy shots out of the air.
	for p: Projectile in Projectile.danger.duplicate():
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() < reach + 0.4 and (d.length() < 0.9 or d.normalized().dot(fwd) >= cos_half):
			p.shatter()
	if perks.has("cutting_wind"):
		_cutting_wind(fwd, col, cut)
	_bone_storm(fwd, global_position + Vector3.UP * 1.1 + fwd * 0.6)
	Game._teach("knight_swing", "SWORD: up close, one swing cuts them all!")


## Cutting Wind: the swing's arc flies on as a wide sword wave through every skeleton behind
## the ones the blade cut (those it already cut are skipped).
func _cutting_wind(fwd: Vector3, col: Color, cut: Array[Actor]) -> void:
	var origin := global_position + Vector3.UP * 1.1 + fwd * 0.9
	var w := Projectile.fire(Team.HERO, origin, fwd, damage * WIND_SHARE * pow(TWIN_GAIN, front_bolts - 1) * Game.chain_damage(),
		bolt_speed * 1.15, col.lerp(Color.WHITE, 0.25), bolt_size * 1.7)
	w.radius = bolt_size * 3.2   # it hits as wide as it looks (a plain wave is a narrow one)
	w.pierce = 99
	w.life = WIND_LIFE
	w.push = bolt_push * 0.6
	w.crit_chance = crit_chance
	w.crit_mult = crit_mult
	w.burn_dps = burn_dps
	w.frost = frost
	for a in cut:
		w._hit[a] = true


## A bright arc of the blade's path, swept round and faded in a fifth of a second.
func _slash(fwd: Vector3, half: float, reach: float, col: Color) -> void:
	var world := Game.world
	if world == null:
		return
	var m := MeshInstance3D.new()
	m.mesh = _arc_mesh(half, 0.5, true)
	var mat := _arc_material(Color(col.r, col.g, col.b, 1.0).lerp(Color.WHITE, 0.35))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	m.global_position = global_position + Vector3.UP * 0.9
	var face_y := atan2(-fwd.x, -fwd.z)
	m.rotation.y = face_y + 0.7
	m.scale = Vector3.ONE * reach * 0.8
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "rotation:y", face_y, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector3.ONE * reach, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	tw.chain().tween_callback(m.queue_free)


## A flat arc round -Z from -half to +half, between `inner` and 1 m. `sweep` brightens it
## toward the leading edge and the rim, like a blade's path; otherwise it is even.
static func _arc_mesh(half: float, inner: float, sweep: bool) -> Mesh:
	var key := "%d_%d_%s" % [int(rad_to_deg(half)), int(inner * 100.0), sweep]
	if _arc_meshes.has(key):
		return _arc_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var k0 := float(i) / n
		var k1 := float(i + 1) / n
		var a0 := lerpf(half, -half, k0)
		var a1 := lerpf(half, -half, k1)
		var o0 := Vector3(-sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(-sin(a1), 0.0, -cos(a1))
		var e0 := (0.15 + 0.85 * k0) if sweep else 1.0
		var e1 := (0.15 + 0.85 * k1) if sweep else 1.0
		var ci := Color(1, 1, 1, 0.0 if sweep else 0.55)
		for v in [[o0 * inner, ci], [o0, Color(1, 1, 1, e0)], [o1, Color(1, 1, 1, e1)],
				[o0 * inner, ci], [o1, Color(1, 1, 1, e1)], [o1 * inner, ci]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var mesh := st.commit()
	_arc_meshes[key] = mesh
	return mesh


static func _arc_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = col
	return mat


## The Knight's guard: a faint arc on the floor in front of him while he stands still,
## showing where his shield covers. It flashes when a shot clangs off it.
func _build_guard_mark() -> void:
	_guard_mark = MeshInstance3D.new()
	_guard_mark.mesh = _arc_mesh(acos(GUARD_COS), 0.84, false)
	_guard_mat = _arc_material(Color(1.0, 0.9, 0.6, 0.0))
	_guard_mark.material_override = _guard_mat
	_guard_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guard_mark.position = Vector3(0, 0.07, 0)
	_guard_mark.scale = Vector3(1.75, 1.0, 1.75)   # just past his body as the run camera sees it
	add_child(_guard_mark)
	_rings.append(_guard_mark)


func _update_guard_mark(delta: float) -> void:
	if _guard_mark == null:
		return
	_guard_flash = maxf(_guard_flash - delta * 3.0, 0.0)
	var up := guarding()
	var goal := (0.5 if up else 0.0) + _guard_flash * 0.5
	_guard_mat.albedo_color.a = move_toward(_guard_mat.albedo_color.a, goal, delta * 4.0)
	var k := 1.75 + _guard_flash * 0.25
	_guard_mark.scale = Vector3(k, 1.0, k)


## The Mage's charge: a magic orb over the hat that swells with moving, and pulses once
## it is full.
func _build_charge_orb() -> void:
	_charge_orb = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_charge_orb.mesh = q
	_charge_orb.material_override = ShotLook.hero_mat(ShotLook.K_ORB, Color(bolt_color.r * 0.8, bolt_color.g * 0.6, bolt_color.b, 1.0), true)
	_charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_charge_orb.position = Vector3(0, 3.0, 0)
	_charge_orb.visible = false
	add_child(_charge_orb)


func _update_charge(delta: float) -> void:
	if not charges:
		return
	if (_moving or _dash_left > 0.0) and Game.state == Game.State.PLAYING and Game.alive_enemies > 0:
		arcane = minf(arcane + delta / CHARGE_TIME, 1.0)
		if arcane >= 1.0 and not _charge_full:
			_charge_full = true
			Fx.magic(global_position + Vector3.UP * 3.0, bolt_color, 10)
	if _charge_orb == null:
		return
	_charge_orb.visible = arcane >= CHARGE_MIN and not dead
	if _charge_orb.visible:
		var k := 0.5 + 0.8 * arcane
		if _charge_full:
			k *= 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
		_charge_orb.scale = Vector3(k, k, k)


## Whether the shield is up: the Knight standing still in a fight (not dashing, spinning
## or knocked down).
func guarding() -> bool:
	return guard and not _moving and _dash_left <= 0.0 and down_left <= 0.0 and _spin_left <= 0.0 \
		and not dead and Game.state == Game.State.PLAYING and Game.alive_enemies > 0


## Whether a shot flying along `dir` hits the shield: the shield is up and the shot comes
## from in front of him.
func blocks_shot(dir: Vector3) -> bool:
	if not guarding():
		return false
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var from := -dir
	from.y = 0.0
	return from.normalized().dot(fwd.normalized()) > GUARD_COS


func on_block(at: Vector3) -> void:
	blocked += 1
	_guard_flash = 1.0
	Fx.sparks(at, Color(1.0, 0.92, 0.6))
	Sfx.play("block", 0.75, randf_range(0.94, 1.08))
	add_charge(0.03)   # every blocked shot builds a little toward Shield Slam
	Game._teach("knight_shield", "SHIELD: stand still to block front shots!")
	if perks.has("riposte"):
		_riposte(at)


## Riposte: the blocked shot flies back as a bright sword wave, at the nearest skeleton in
## front of the shield (or straight ahead if there is none).
func _riposte(at: Vector3) -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var aim := fwd
	var best := 16.0 * 16.0
	for a: Actor in Actor.all:
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		var l2 := d.length_squared()
		if l2 < best and l2 > 0.01 and d.normalized().dot(fwd) > GUARD_COS:
			best = l2
			aim = d.normalized()
	var origin := Vector3(at.x, global_position.y + 1.1, at.z) + aim * 0.3
	var p := Projectile.fire(Team.HERO, origin, aim, damage * pow(TWIN_GAIN, front_bolts - 1) * Game.chain_damage(), bolt_speed * 1.3, RIPOSTE_COL, bolt_size * 1.15)
	p.pierce = pierce
	p.push = bolt_push
	p.crit_chance = crit_chance
	p.crit_mult = crit_mult
	p.burn_dps = burn_dps
	p.frost = frost
	Fx.sparks(origin, RIPOSTE_COL)
	Game._teach("knight_riposte", "RIPOSTE: blocked shots fly straight back!")


## Twin Shots: each pick adds a forward shot and 40% to the forward volley, shared between
## its shots (2 shots hit 70% each, 3 hit 65%, 4 hit 69%). Each pick used to add about 80%,
## four times a Sharpened Shots.
func front_share() -> float:
	return pow(TWIN_GAIN, front_bolts - 1) / front_bolts


func _fire(origin: Vector3, d: Vector3, col: Color, share := 1.0, boost := 0.0) -> void:
	var p := Projectile.fire(Team.HERO, origin, d, damage * share * (1.0 + 1.2 * boost) * Game.chain_damage(), bolt_speed * (1.0 - 0.25 * boost), col, bolt_size * (1.0 + 0.9 * boost))
	p.pierce = pierce
	p.push = bolt_push * (1.0 + boost)
	p.splash = splash * (1.0 + 0.7 * boost)
	p.charged = boost
	p.crit_chance = crit_chance
	p.crit_mult = crit_mult
	p.burn_dps = burn_dps
	p.frost = frost
	p.bounce = int(perks.get("ricochet", 0))
	p.wall_bounce = int(perks.get("bounce", 0))
	if boomerang > 0.0:
		p.boomerang = _throw_reach
		p._cuts = pierce
		p.life = 6.0
		if perks.has("buzzsaw"):
			p.hang = BUZZ_HANG


## A returning axe is back in the Barbarian's hand.
func catch_axe(at: Vector3) -> void:
	caught += 1
	Sfx.play("catch", 0.35, randf_range(0.9, 1.1))
	Fx.impact(at, Color(1.0, 0.8, 0.5), 0.5)
	if perks.has("thunder_catch") and _thunder_cd <= 0.0:
		_thunder_catch()


## Thunder Catch: the caught axe comes down on the floor. Skeletons close round him are hurt
## and thrown back (only when there are some: an empty slam would just be noise).
func _thunder_catch() -> void:
	var near: Array[Actor] = []
	for a: Actor in Actor.all:
		if a.team == Team.UNDEAD and a.can_be_hit() and a.global_position.distance_to(global_position) < THUNDER_R + a.radius:
			near.append(a)
	if near.is_empty() or dead or Game.state != Game.State.PLAYING:
		return
	_thunder_cd = 0.35
	visual.attack()
	Fx.shockwave(global_position, Color(1.0, 0.72, 0.38), THUNDER_R + 0.4)
	Fx.shockwave(global_position, Color(1.0, 0.95, 0.8), THUNDER_R * 0.6)
	Fx.impact(global_position + Vector3.UP * 0.2, Color(1.0, 0.8, 0.5), 1.8)
	Fx.dust(global_position, 18)
	Sfx.play("slam", 0.45, 1.25)
	Game.shake(0.08)
	var dmg := damage * THUNDER_SHARE * Game.chain_damage()
	for a in near:
		var d := a.global_position - global_position
		d.y = 0.0
		a.take_damage(dmg, d.normalized() if d.length_squared() > 0.01 else -global_transform.basis.z, 12.0)
		Fx.sparks(a.center(), Color(1.0, 0.85, 0.55))
	Game._teach("barbarian_thunder", "THUNDER CATCH: catch your axe by skeletons!")


## Shadow Step: the shadow stands where this dash began.
func _shadow_step() -> void:
	if not is_instance_valid(_shadow):
		_shadow = ShadowStep.make(self)
	_shadow.appear(global_position, rotation.y)
	Game._teach("rogue_shadow", "SHADOW STEP: each dash leaves a knife shadow!")


## Frost Orbit: while the Mage moves in a fight, ice orbs circle round, chilling and hurting
## every skeleton they pass through (each skeleton at most twice a second).
func _update_orbit(delta: float) -> void:
	var on := (_moving or _dash_left > 0.0) and not dead and down_left <= 0.0 and Game.state == Game.State.PLAYING and Game.alive_enemies > 0
	_orbit_on = move_toward(_orbit_on, 1.0 if on else 0.0, delta * (5.0 if on else 3.0))
	if _orbit == null:
		if not on:
			return
		_build_orbit()
	_orbit.visible = _orbit_on > 0.02
	if not _orbit.visible:
		return
	_orbit_a = fmod(_orbit_a + ORBIT_SPIN * delta, TAU)
	_orbit.global_rotation = Vector3(0, _orbit_a, 0)
	var k := 0.4 + 0.6 * _orbit_on
	_orbit.scale = Vector3(k, 1.0, k)
	if _orbit_on < 0.6:
		return
	var now := Time.get_ticks_msec()
	var dmg := damage * ORBIT_SHARE * Game.chain_damage()
	for m: Node3D in _orbit.get_children():
		var at := m.global_position
		for a: Actor in Actor.all:
			if a.team != Team.UNDEAD or not a.can_be_hit():
				continue
			var d := a.global_position - at
			d.y = 0.0
			if d.length() > 0.45 + a.radius:
				continue
			var key := a.get_instance_id()
			if int(_orbit_next.get(key, 0)) > now:
				continue
			_orbit_next[key] = now + 500
			var away := a.global_position - global_position
			away.y = 0.0
			a.take_damage(dmg, away.normalized() if away.length_squared() > 0.01 else d, 2.5)
			if not a.dead and a is Enemy:
				(a as Enemy).chill(1.2)
			Fx.sparks(at, ORBIT_COL)
			Game._teach("mage_orbit", "FROST ORBIT: keep moving to chill skeletons!")
			break   # (an orb can't spend itself on one crowd in a single frame)


func _build_orbit() -> void:
	_orbit = Node3D.new()
	_orbit.name = "FrostOrbit"
	_orbit.position = Vector3(0, 1.0, 0)
	add_child(_orbit)
	var orb := ShotLook.hero_mat(ShotLook.K_ORB, ORBIT_COL, true)
	var tail := ShotLook.hero_mat(ShotLook.K_TAIL, Color(ORBIT_COL.r, ORBIT_COL.g, ORBIT_COL.b, 0.65))
	for i in ORBIT_N:
		var a := TAU * i / ORBIT_N
		var m := Node3D.new()
		_orbit.add_child(m)
		m.position = Vector3(cos(a), 0, sin(a)) * ORBIT_R
		m.rotation.y = -a   # its tail trails round the circle behind it
		ShotLook._put(m, ShotLook._card, orb, Vector3(0.62, 0.62, 1.0))
		ShotLook._put(m, ShotLook._flat, tail, Vector3(0.34, 1.0, 1.3), Vector3(0, 0, 0.62))

## Static Shots (version 307): a spark of lightning jumps from `a` to the nearest other
## skeleton (and on again with a second pick). Called on a hero shot's or swing's hit.
func spark_from(a: Actor) -> void:
	var jumps := int(perks.get("spark", 0))
	if jumps <= 0 or a == null or not is_instance_valid(a) or Game.state != Game.State.PLAYING:
		return
	var now := Time.get_ticks_msec()
	if now - _spark_ms < SPARK_GAP_MS:
		return
	var from := a.center()
	var done: Array[Actor] = [a]
	var dmg := damage * SPARK_SHARE * Game.chain_damage()
	for j in jumps:
		var best: Actor = null
		var best_d := SPARK_R * SPARK_R
		for b: Actor in Actor.all:
			if b.team != Team.UNDEAD or not b.can_be_hit() or done.has(b):
				continue
			var dd := Vector2(b.global_position.x - from.x, b.global_position.z - from.z).length_squared()
			if dd < best_d:
				best_d = dd
				best = b
		if best == null:
			break
		_spark_ms = now
		var to := best.center()
		Fx.zap(from, to, SPARK_COL)
		var push_dir := Vector3(to.x - from.x, 0.0, to.z - from.z)
		best.take_damage(dmg, push_dir.normalized() if push_dir.length_squared() > 0.01 else Vector3.FORWARD, 1.5)
		done.append(best)
		from = to
	if done.size() > 1:
		Sfx.play("zap", 0.35, randf_range(0.9, 1.15))
		Game._teach("spark", "STATIC SHOTS: hits throw lightning onward!")


## Storm Bounce (version 308): a shot bouncing off a wall or pillar throws lightning at the
## two skeletons nearest the spot.
func storm_bounce(at: Vector3) -> void:
	if not perks.has("storm_bounce") or Game.state != Game.State.PLAYING:
		return
	var now := Time.get_ticks_msec()
	if now - _storm_ms < STORM_GAP_MS:
		return
	var near: Array = Actor.all.filter(func(b: Actor) -> bool:
		return b.team == Team.UNDEAD and b.can_be_hit() and Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length() < STORM_R)
	if near.is_empty():
		return
	near.sort_custom(func(x: Actor, y: Actor) -> bool: return x.global_position.distance_squared_to(at) < y.global_position.distance_squared_to(at))
	_storm_ms = now
	var from := Vector3(at.x, 1.0, at.z)
	var dmg := damage * SPARK_SHARE * 1.5 * Game.chain_damage()
	for b: Actor in near.slice(0, 2):
		var to := b.center()
		Fx.zap(from, to, SPARK_COL)
		var push_dir := Vector3(to.x - from.x, 0.0, to.z - from.z)
		b.take_damage(dmg, push_dir.normalized() if push_dir.length_squared() > 0.01 else Vector3.FORWARD, 2.0)
	Sfx.play("zap", 0.45, 0.85)
	Game._teach("storm_bounce", "STORM BOUNCE: bounced shots throw lightning!")


## Spinning Bones (version 307): bone blades circling the hero in every fight, each cutting a
## skeleton it touches at most every BONES_EVERY_MS.
func _update_bones(delta: float) -> void:
	var on := not dead and down_left <= 0.0 and Game.state == Game.State.PLAYING and Game.alive_enemies > 0
	var n := 1 + int(perks.get("orbit", 0))
	if _bones == null or _bones_n != n:
		if not on and _bones == null:
			return
		_build_bones(n)
	_bones.visible = on
	if not on:
		return
	_bones_a = fmod(_bones_a - BONES_SPIN * delta, TAU)
	_bones.global_rotation = Vector3(0, _bones_a, 0)
	var now := Time.get_ticks_msec()
	var dmg := damage * BONES_SHARE * Game.chain_damage()
	for m: Node3D in _bones.get_children():
		var at := m.global_position
		for a: Actor in Actor.all:
			if a.team != Team.UNDEAD or not a.can_be_hit():
				continue
			var d := a.global_position - at
			d.y = 0.0
			if d.length() > 0.5 + a.radius:
				continue
			var key := a.get_instance_id()
			if int(_bones_next.get(key, 0)) > now:
				continue
			_bones_next[key] = now + BONES_EVERY_MS
			var away := a.global_position - global_position
			away.y = 0.0
			a.take_damage(dmg, away.normalized() if away.length_squared() > 0.01 else d, 2.0)
			if perks.has("thunder_bones"):
				spark_from(a)   # Thunder Bones (version 308)
			Fx.sparks(at, BONE_COL)
			Sfx.play("swing", 0.2, 1.7)
			Game._teach("orbit", "SPINNING BONES: walk into skeletons to cut!")
			break


func _build_bones(n: int) -> void:
	if _bones:
		_bones.queue_free()
	_bones_n = n
	_bones = Node3D.new()
	_bones.name = "SpinningBones"
	_bones.position = Vector3(0, 0.9, 0)
	add_child(_bones)
	ShotLook._shaders()
	# A cartoon bone (a shaft with two knobs at each end) lying along the circle, with a
	# pale streak trailing behind it so the spin reads.
	var bone := U.mat(BONE_COL, 0.6, 0.6)
	var tail := ShotLook.hero_mat(ShotLook.K_TAIL, Color(BONE_COL.r, BONE_COL.g, BONE_COL.b, 0.6))
	for i in n:
		var ang := TAU * i / n
		var m := Node3D.new()
		_bones.add_child(m)
		m.position = Vector3(cos(ang), 0, sin(ang)) * BONES_R
		m.rotation.y = -ang   # its length along the circle
		var shaft := U.cylinder(m, 0.08, 0.64, bone)
		shaft.rotation.x = PI / 2.0
		shaft.position = Vector3.ZERO
		for z in [-0.32, 0.32]:
			for x in [-0.08, 0.08]:
				U.sphere(m, 0.105, bone, Vector3(x, 0, z))
		ShotLook._put(m, ShotLook._flat, tail, Vector3(0.36, 1.0, 1.1), Vector3(0, -0.05, 0.75))


## Phantom Dash (version 307): each skeleton the dash passes through is cut once.
func _phantom_cuts() -> void:
	for a: Actor in Actor.all.duplicate():
		if a.team != Team.UNDEAD or not a.can_be_hit() or _phantom_cut.has(a):
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		if d.length() > radius + a.radius + 0.45:
			continue
		_phantom_cut.append(a)
		var side := d - _dash_dir * d.dot(_dash_dir)
		a.take_damage(damage * PHANTOM_MULT * Game.chain_damage(), side.normalized() if side.length_squared() > 0.01 else _dash_dir, 6.0)
		if perks.has("frost_ghost") and a is Enemy and not a.dead:
			(a as Enemy).freeze_solid(FROST_GHOST_TIME)   # Frost Ghost (version 308)
		Fx.impact(a.center(), Color(0.75, 0.6, 1.0), 1.6)
		Sfx.play("swing", 0.6, 1.3)
		Game._teach("phantom", "PHANTOM DASH: dash through skeletons to cut!")


## Blazing Dash (version 307): a line of fire patches from where the dash began to where it ended.
func _blaze_trail() -> void:
	var path := global_position - _dash_from
	path.y = 0.0
	var steps := maxi(1, int(path.length() / BLAZE_STEP))
	var dps := maxf(burn_dps, 6.0 + 0.4 * damage)
	for i in steps + 1:
		FirePatch.spawn_hero(_dash_from + path * (float(i) / steps), 0.8, 2.5, dps)
	Game._teach("blaze_dash", "BLAZING DASH: lead skeletons over the fire!")


## Cold Snap (version 307): the special freezes every skeleton near the hero solid.
func _cold_snap() -> void:
	Fx.shockwave(global_position, Enemy.ICE_COL, COLD_SNAP_R)
	Fx.magic(center(), Enemy.ICE_COL, 20)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and a.can_be_hit() and a.global_position.distance_to(global_position) < COLD_SNAP_R + a.radius:
			(a as Enemy).freeze_solid(COLD_SNAP_TIME)


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	if Game.bench:
		health = max_health   # the SPEED TEST hero takes hits (and shows them) but can't fall
	if ward > 0:
		ward -= 1
		Game.report_event("ward")
		_invulnerable = 0.7
		Fx.magic(center(), Color(0.8, 0.9, 1.0), 24)
		if perks.has("glacier"):
			# Glacier: the blocked hit freezes every skeleton nearby.
			Fx.shockwave(global_position, Color(0.6, 0.9, 1.0), 5.0)
			for a: Actor in Actor.all:
				if a is Enemy and a.can_be_hit() and a.global_position.distance_to(global_position) < 5.0 + a.radius:
					(a as Enemy).chill(2.5)
		Sfx.play("upgrade", 0.6)
		Game.shake(0.2)
		return
	# Version 295 (deep review fix 2): no single hit takes more than 45% of the hero's full
	# health. On the deep floors one bomber blast was 86 against a Mage's 80: dead from full,
	# with nothing learned. Now it takes at least three hits to fall from full health.
	var scaled := minf(amount * Game.damage_scale() * (1.0 - armor), max_health * HIT_CAP)
	if second_wind and scaled >= health:
		second_wind = false
		Game.report_event("second_wind")
		health = max_health * 0.5
		_invulnerable = 2.0
		Fx.magic(center(), Color(1, 0.9, 0.5), 50)
		Sfx.play("victory", 0.6)
		Game.shake(0.4)
		Game.hud.banner("Second Wind!", Color(1, 0.9, 0.5))
		return
	if Game.race and scaled >= health:
		_knock_down()
		return
	# Version 169 (teaching review, change 2): nobody falls in the tutorial. A hit that would
	# end it leaves the hero on 1 health instead, so the first run always ends in a win.
	if Game.first_run and Game.floor_num == 1 and scaled >= health:
		scaled = maxf(0.0, health - 1.0)
	var before := health
	super.take_damage(scaled, direction, push, crit)
	Game.report_damage(before - health)
	if health < before:
		_hurt_ms = Time.get_ticks_msec()
	if dead:
		return
	Sfx.play("hurt")
	if before - health >= max_health * 0.12:
		Music.duck(7.0)
	if Game.vibration:
		Input.vibrate_handheld(45)
	Game.shake(0.35)
	Game.hit_stop(0.06)
	_invulnerable = 0.7


## Crypt Race: a hit that would end the run knocks the hero down instead. They lie still for
## Race.DOWN_TIME (the rival keeps going), then get up with Race.GET_UP of their health and
## a shove that clears the skeletons round them.
func _knock_down() -> void:
	health = 0.0
	down_left = Race.DOWN_TIME
	_dash_left = 0.0
	_spin_left = 0.0
	knockback = Vector3.ZERO
	visual.set_visible_blink(true)
	visual.knock_down()
	Sfx.play("hurt")
	Sfx.play("vo_lose", 0.6)
	if Game.vibration:
		Input.vibrate_handheld(120)
	Game.shake(0.6)
	Game.race_knocked_down()


func _lie_down(delta: float) -> void:
	var was := ceili(down_left)
	down_left -= delta
	# The getting-up count ticks down on screen: 3, 2, 1.
	if ceili(down_left) < was and down_left > 0.0:
		Game.race_down_tick(ceili(down_left))
	move_by(Vector3.ZERO, delta)
	# The health bar fills as they get their breath back.
	health = max_health * Race.GET_UP * clampf(1.0 - down_left / Race.DOWN_TIME, 0.0, 1.0)
	if down_left > 0.0:
		return
	down_left = 0.0
	health = max_health * Race.GET_UP
	_invulnerable = 1.6
	visual.stand_up()
	Fx.shockwave(global_position, Color(0.4, 0.95, 1.0), 4.0)
	Fx.magic(center(), Color(0.5, 0.95, 1.0), 30)
	Sfx.play("upgrade", 0.7)
	for a: Actor in Actor.all:
		if a is Enemy and not a.dead and not (a as Enemy).is_boss:
			var d := a.global_position - global_position
			d.y = 0.0
			if d.length() < 4.0:
				a.knockback += (d.normalized() if d.length() > 0.01 else Vector3.FORWARD) * 10.0
	Game.race_got_up()


## Grave Aura (a Curse mastery reward): a slow red glow on the floor under the hero.
func _build_aura() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.02
	disc.radial_segments = 32
	var m := MeshInstance3D.new()
	m.mesh = disc
	var mat := U.unlit(Color(0.9, 0.12, 0.15, 0.22))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.03, 0)
	add_child(m)
	_aura = m


## A dark disc with a ring in the hero's own colour at their feet, so you can always find
## your hero from above, even in a crowd of skeletons on a bright floor.
func _build_feet_marker(col: Color, col2: Variant = null, fx := "flow", tier := 0, power := 1.0) -> void:
	var disc := U.cylinder(self, 0.6, 0.01, U.unlit(Color(0, 0, 0, 0.4)), Vector3(0, 0.02, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.append(disc)
	# Version 172: a ring of light with its Glow's own shape (LookFx.ring), not a flat hoop.
	var ring := LookFx.ring(col, col2, fx, 1.15, 0.48, power, tier)
	ring.position = Vector3(0, 0.04, 0)
	add_child(ring)
	_rings.append(ring)


## Hero Mastery level 10: a thin gold ring just inside the one in the hero's colour.
func _build_gold_ring(col := Color(1.0, 0.82, 0.32)) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.46
	torus.rings = 32
	torus.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = U.unlit(Color(col.r, col.g, col.b, 0.95))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.045, 0)
	ring.scale = Vector3(1, 0.12, 1)
	add_child(ring)
	_rings.append(ring)


## Gold sparkles that drift up from the hero and hang in the air behind them as they
## run: a Master can be told apart at a glance. One small emitter, so it costs little.
func _build_sparkles() -> void:
	var p := Fx.sparkle_trail(Color(1.0, 0.86, 0.45))
	p.position = Vector3(0, 0.15, 0)   # rising from the rings at the hero's feet
	add_child(p)
	_rings.append(p)


## A Master aura's trail of light (Fx.motif).
func _build_motif() -> void:
	var p := Fx.motif(str(_master_aura.get("motif", "wisps")), _master_aura.get("spark", Color.WHITE), 1.4)   # bigger: seen from far above
	add_child(p)
	_rings.append(p)
	for c in p.get_children():
		if c is MultiMeshInstance3D and str(_master_aura.get("motif", "")) == "bonechain":
			_chain_mat = (c as MultiMeshInstance3D).material_override as ShaderMaterial
	# Versions 172-174: the aura's light round the hero, grander with its grade (LookFx.aura_fx).
	var fx := LookFx.aura_fx(_master_aura)
	add_child(fx)
	_rings.append(fx)
	_aura_fx = fx
	# (Version 182: no second floor shape here. LookFx.aura_fx's mark() is the aura's shape;
	# both drawn on the same spot cost twice the drawing and flickered.)


## Version 254: the Bone Chain aura burns as far as the run's Bone Chain has climbed (gold,
## then red-hot, like the spine on the screen). Off a run (the title) it lights link by link.
func _update_chain_aura(delta: float) -> void:
	var playing := Game.state == Game.State.PLAYING
	_chain_mat.set_shader_parameter("demo", 0.0 if playing else 1.0)
	var want := clampf((Game.chain - 1.0) / maxf(Game.chain_max() - 1.0, 0.01), 0.0, 1.0) if playing else 0.0
	_chain_lit = move_toward(_chain_lit, want, delta * (3.0 if want > _chain_lit else 1.5))
	_chain_mat.set_shader_parameter("lit", _chain_lit)


## The dash trail: the aura's colour (as its outline is drawing it right now), gold for a
## Master, otherwise blue.
func _trail_color() -> Color:
	if not _master_aura.is_empty():
		return HeroStyle.aura_ink(_master_aura, Time.get_ticks_msec() / 1000.0)
	return Color(1.0, 0.8, 0.35) if _master else Color(0.45, 0.8, 1.0)


## The dash ring's colour: a Master aura's first colour, otherwise light blue.
func _dash_color() -> Color:
	return _master_aura.get("ink", Color(0.5, 0.85, 1.0)) if not _master_aura.get("cycle", false) else Color(0.62, 0.7, 1.0)


## A ring around that one: bright when the dash is ready, faint while it recharges.
func _build_dash_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.72
	torus.rings = 32
	torus.ring_segments = 4
	_dash_ring = MeshInstance3D.new()
	_dash_ring.mesh = torus
	_ring_mat = U.unlit(Color(_dash_color(), 0.55)).duplicate()   # its own: its glow is animated
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_dash_ring.material_override = _ring_mat
	_dash_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dash_ring.position = Vector3(0, 0.05, 0)
	_dash_ring.scale = Vector3(1, 0.15, 1)
	add_child(_dash_ring)


func _update_dash_ring() -> void:
	if _aura:
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.08
		_aura.scale = Vector3(s, 1, s)
	if _dash_ring == null:
		return
	var can_dash := dash_ready()
	var a := 0.12 + 0.12 * (1.0 - clampf(_dash_cooldown / dash_cooldown_time, 0.0, 1.0))
	if can_dash:
		a = 0.45 + sin(Time.get_ticks_msec() * 0.006) * 0.1
	_ring_mat.albedo_color.a = a
	var was_ready := _ring_was_ready
	_ring_was_ready = can_dash
	if can_dash and not was_ready:
		Fx.magic(global_position + Vector3.UP * 0.2, _dash_color(), 10)


## Slowed to 60% speed for a moment (Frost Wraith beams).
func chill(seconds: float) -> void:
	if chill_left <= 0.0:
		Fx.magic(center(), Color(0.6, 0.9, 1.0), 16)
		Game.hud.callout("CHILLED!", Color(0.6, 0.9, 1.0), true)
	chill_left = maxf(chill_left, seconds)


## Silenced inside a Hush Keeper's circle (version 271): no shots or swings while
## `hush_left` lasts. The circle tops it up every frame the hero is inside.
func hush(seconds: float) -> void:
	if dead:
		return
	if hush_left <= 0.0:
		Fx.magic(global_position + Vector3.UP * 1.3, HushCircle.TEAL, 10)
		if _hush_said <= 0.0:
			Game.hud.callout("HUSHED! STEP OUT!", HushCircle.TEAL, true)
		_hush_said = 3.0
	hush_left = maxf(hush_left, seconds)


## Wading in the Sand Pharaoh's sand (version 274): slower while `mired_left` lasts. The
## sand tops it up every frame the hero is in it.
func mire(seconds: float) -> void:
	if dead:
		return
	if mired_left <= 0.0 and _mired_said <= 0.0:
		Game.hud.callout("SINKING IN SAND! GET OUT!", SandMound.SAND, true)
		_mired_said = 4.0
	mired_left = maxf(mired_left, seconds)


## Held in place by roots for a moment (Rootbinders and the Sporemother). A dash tears free.
func snare(seconds: float) -> void:
	if not can_be_snared():
		return
	if snare_left <= 0.0:
		Game.hud.callout("ROOTED! DASH FREE!", RootCrawl.LIME, true)
	snare_left = maxf(snare_left, seconds)
	Game.buzz(30)


## Frozen solid in the Blizzard (version 243): held like roots, in a block of ice. A dash
## breaks it.
func freeze(seconds: float) -> void:
	if not can_be_snared() or dead:
		return
	snare_left = maxf(snare_left, seconds)
	if _ice == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.9, 1.0, 0.45)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.35, 0.6, 0.85)
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.1
		m.metallic_specular = 1.0
		_ice = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.25, 2.0, 1.25)
		_ice.mesh = b
		_ice.material_override = m
		_ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ice.position = Vector3(0, 1.0, 0)
		add_child(_ice)
	_ice.visible = true
	_ice.rotation.y = randf_range(-0.4, 0.4)
	Fx.magic(center(), Color(0.75, 0.92, 1.0), 22)
	Sfx.play("crack", 0.7, 0.8)
	Game.hud.callout("FROZEN! DASH FREE!", Color(0.6, 0.9, 1.0), true)
	Game.buzz(40)


func _thaw() -> void:
	if _ice:
		_ice.visible = false


## False while held already, or just after getting free (see snare_guard).
func can_be_snared() -> bool:
	return snare_left <= 0.0 and snare_guard <= 0.0


## Refills Bone Ward and the healing allowances at the start of each room.
func new_room() -> void:
	ward = ward_max
	harvest_left = max_health * 0.02 * harvest_heal   # harvest_heal is 2 per pick
	kill_heal_left = max_health * 0.04 * heal_on_kill   # heal_on_kill: 2 for the Barbarian
	siphon_left = max_health * 0.12 * perks.get("siphon", 0)
	_orbit_next.clear()


## A faint bubble around the hero while Bone Ward is up.
func _update_ward_bubble() -> void:
	if ward <= 0 or dead:
		if _ward_bubble:
			_ward_bubble.visible = false
		return
	if _ward_bubble == null:
		var mat := U.unlit(Color(0.7, 0.85, 1.0, 0.18))
		_ward_bubble = U.sphere(self, 0.95, mat, Vector3(0, 1.0, 0))
		_ward_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward_bubble.visible = true
	var s := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
	_ward_bubble.scale = Vector3(s, s, s)


func _on_death() -> void:
	# The rings at the hero's feet go with them, so none is left floating on the end screen.
	for r in _rings:
		r.visible = false
	if _dash_ring:
		_dash_ring.visible = false
	if _aura:
		_aura.visible = false
	visual.set_visible_blink(true)
	visual.die()
	Sfx.play("hurt")
	Game.shake(0.6)
	Game.on_hero_died()
