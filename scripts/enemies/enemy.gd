class_name Enemy
extends Actor
## Shared skeleton behaviour: rising out of the floor, pushing apart from each other,
## contact damage, health bar and death. Each type overrides _setup() and _think().

var move_speed := 2.5
var contact_damage := 10.0
var knockback_scale := 1.0
## Chance of dropping a healing heart when destroyed.
var drop_chance := 0.09
## Bosses use the big bar at the top of the screen instead of a little one.
var is_boss := false
## Version 424 (fix 3): how far a boss's drawn body reaches past `radius` (its crystals,
## its cloak): the hero is kept out to here (Hero.move_by), so it is never seen inside.
var body_extra := 0.2
## Version 251 (review fix 11): each skeleton family dies with its own sound and each boss
## roars in its own voice (audio/sfx/die_<family>_N.ogg and roar_<boss>_N.ogg, made by
## tools/audio/voices.py). Set in a kind's _setup; a name with no files falls back to the
## shared bone crunch ("die") and roar ("roar") in Sfx.play.
var die_sound := "die"
var roar_sound := "roar"
## Elite skeletons are purple, bigger and tougher, and drop more coins.
var elite := false
## Version 237 (whole-game review fix 7): an elite used to be only x2.2 health and a purple
## tint, so a player never had to fight one any differently. Now each elite also has one move
## of its own from ELITE_MOVES, named over its head in that move's colour:
## split: breaks into two small skeletons when it dies.
## burst: a fan of warning strips when it dies, then a bone dart flies down each one (not
## called shards: the Blood Moon's prize is Moon shards, which elites drop).
## fury: at half health it roars, turns red, runs FURY_SPEED times as fast and can hardly be
## pushed back. (Not a faster brain: wind-ups are timed in _think, but their warnings on the
## floor are not, so a faster brain struck before its warning filled in.)
## mender: every MEND_EVERY seconds heals the hurt skeletons around it.
## ward: a bubble that stops WARD_HITS hits, breaks, and grows back WARD_REGROW s later.
var elite_move := ""
const ELITE_MOVES := {
	"split": {"tag": "SPLITTER", "word": "Splitter", "col": Color(0.82, 1.0, 0.2),
		"tip": "SPLITTER ELITE: breaks into 2 skeletons when it dies!"},
	"burst": {"tag": "BURST", "word": "Burst", "col": Color(1.0, 0.58, 0.14),
		"tip": "BURST ELITE: fires darts as it dies. Leave the lines!"},
	"fury": {"tag": "FURY", "word": "Fury", "col": Color(1.0, 0.36, 0.22),
		"tip": "FURY ELITE: fast at half health. Finish it quick!"},
	"mender": {"tag": "MENDER", "word": "Mender", "col": Color(1.0, 0.4, 0.6),
		"tip": "MENDER ELITE: heals the others. Kill it first!"},
	"ward": {"tag": "WARDED", "word": "Warded", "col": Color(0.72, 0.88, 1.0),
		"tip": "WARDED ELITE: its bubble stops 3 hits, then regrows."},
}
const ELITE_HEALTH := 2.2
const WARD_HEALTH := 1.8   # the bubble is extra toughness, so a little less health under it
const SPLIT_HEALTH := 0.5
const DART_LINES := 6
const DART_LENGTH := 7.0
const DART_WARN := 0.8
const DART_SPEED := 9.0
const DART_DAMAGE := 10.0
const FURY_AT := 0.5
const FURY_SPEED := 1.6
const MEND_EVERY := 1.25
const MEND_RANGE := 5.0
const MEND_SHARE := 0.12
const WARD_HITS := 3
const WARD_REGROW := 5.0
const WARD_REGROWS := 2   # v298: then it stays broken (a slow hero was stuck on one for 10 min)
var _ward_regrown := 0
var _tag: Label3D
var _tag_pill: Sprite3D   # v404: its dark pill and picture (children of _tag)
var _tag_icon: Sprite3D
var _tag_tick: Sprite3D   # (a thin line up to its owner when the pill had to step away)
var _tag_shift := 0.0
var _tag_y := 0.0
var _tag_a := 1.0   # the tag's own fade (under the top bar), before the fade by the hero
var _furious := false
var _mend_left := MEND_EVERY
var _mended_at := -100.0   # (Game._run_time of the last mend it got: menders don't stack)
var _ward_hits := 0
var _ward_left := 0.0
var _bubble: MeshInstance3D
var _pool: MeshInstance3D
var _parts := {}
var _bubble_mat: StandardMaterial3D
## Set when it falls because its boss fell: no split or burst then.
var _crumbling := false

var _slow_left := 0.0

## Seconds a melee skeleton winds up a swipe before its touch hurts: a small warning circle
## fills in front of it, so a step aside or a Grave Dash answers it (and dashing out of it
## is a PERFECT). 0 = the old instant touch, for attacks that have their own warning
## (a warrior's lunge, a spider's leap, a boss's rush, a Drowned Skeleton's burst).
var swipe_time := 0.0
## A swipe starts this much further out than the touch itself.
const SWIPE_REACH := 0.35
const SWIPE_RADIUS := 0.75
var _swipe: Telegraph
## A big hit staggers a skeleton briefly: it stands still and starts no new attack.
const FLINCH_TIME := 0.12
var _flinch_left := 0.0
var _swipe_dir := Vector3.FORWARD

var _spawn_timer := 0.9
var _contact_cooldown := 0.0
var _bar: HealthBar
var _telegraphs: Array[Telegraph] = []
## Seconds spent somewhere the hero's shots can't reach (past a wall or inside a pillar).
var _out_time := 0.0

## Version 171: the stuck watch. Players told Jesse that skeletons sometimes get stuck in
## places. Every STUCK_WINDOW seconds a skeleton checks how far it got: one that spent most
## of that time walking at the hero, is still out of reach of the hero, and moved less than
## STUCK_MOVE metres (with no friends crowding it) is stuck. Each one goes on the run report
## ("Stuck: ..."), and a skeleton stuck twice in a row climbs out nearer the hero, so the
## player isn't left waiting.
const STUCK_WINDOW := 4.0
const STUCK_MOVE := 0.5
var _stuck_win := 0.0
var _stuck_chase := 0.0
var _stuck_from := Vector3.ZERO
var _stuck_count := 0
var _chasing_now := false
## Version 180: seconds the hero has had no line of fire to this skeleton. Jesse saw one
## stand behind a pillar in a corner of floor 4 that the hero could never shoot. Bone
## Spitters never walk and Archers back away, so the stuck watch (which only looks at
## skeletons walking at the hero) never saw it. After HIDE_LIMIT seconds it steps out.
const HIDE_LIMIT := 7.0
var _cover_time := 0.0
var _cover_check := randf() * 0.5   # spread out, so a whole wave doesn't check in the same frame


## Bosses wear the cartoon outline, like the hero (character_visual.gd).
func wants_outline() -> bool:
	return is_boss


static func create(kind: String, parent: Node, pos: Vector3) -> Enemy:
	var e: Enemy
	match kind:
		"w": e = SkeletonWarrior.new()
		"a": e = SkeletonArcher.new()
		"g": e = SkeletonMage.new()
		"K": e = SkeletonKing.new()
		"L": e = Lich.new()
		"C": e = CinderColossus.new()
		"x": e = SkeletonBomber.new()
		"t": e = BoneSpitter.new()
		"s": e = BoneSpider.new()
		"f": e = FrostWraith.new()
		"e": e = CinderSkeleton.new()
		"d": e = DrownedSkeleton.new()
		"T": e = Tidecaller.new()
		"p": e = Sporeling.new()
		"r": e = Rootbinder.new()
		"S": e = Sporemother.new()
		"A": e = StarEater.new()   # the Starfall Abyss's own boss (version 268)
		"v": e = VoidWalker.new()   # the Starfall Abyss's own skeleton (version 269)
		"u": e = ClockworkSkeleton.new()   # the Clockwork Foundry's own skeleton (version 270)
		"l": e = HushKeeper.new()   # the Whispering Library's own skeleton (version 271)
		"z": e = GeodeGuard.new()   # the Amethyst Mine's own skeleton (version 272)
		"y": e = TombMummy.new()   # the Sandfall Tomb's own skeleton (version 273)
		"P": e = SandPharaoh.new()   # the Sandfall Tomb's own boss (version 274)
		"M": e = CrystalTyrant.new()   # the Amethyst Mine's own boss (version 275)
		"B": e = Archivist.new()   # the Whispering Library's own boss (version 276)
		"k": e = InkDouble.new()   # the Archivist's Mirror Page: the hero's ink double (version 276)
		"F": e = Forgemaster.new()   # the Clockwork Foundry's own boss (version 281)
		# The Blood Moon event (events.gd, version 134).
		"b": e = Bloodbat.new()
		"h": e = MoonHowler.new()
		"Q": e = BloodQueen.new()
		"q": e = QueenShade.new()
		# The Frostfall event (version 243).
		"o": e = SnowRoller.new()
		"n": e = BellRinger.new()
		"i": e = GiftThief.new()
		"Y": e = Krampus.new()
		_: e = SkeletonMinion.new()
	e.team = Team.UNDEAD
	parent.add_child(e)
	e.global_position = pos
	e._setup()
	if not e.is_boss and e.visual:
		# Version 365 (visual review v357 fix 7): skeletons a fifth bigger, near the hero's
		# size; from the run camera they were small grey shapes. (Their reach is unchanged.)
		e.visual.scale *= FOE_GROW
		e.center_height *= FOE_GROW
	# Deeper floors make skeletons tougher and a little quicker.
	# Bosses get an extra 30% per floor on top, up to 2.2x from floor 5 (version 124: uncapped,
	# the floor 20 King took 18 minutes). The tutorial's King has 50% (version 169, was 70%).
	# (Game.strength_floor(): floor 3's strength in the Free Dive's floor 6, version 280.)
	var boss_scale := minf(2.2, 1.0 + 0.3 * (Game.strength_floor() - 1)) * (0.5 if Game.first_run else 1.0)
	e.init_health(e.max_health * Game.health_scale() * (boss_scale if e.is_boss else 1.0))
	e.move_speed *= Game.speed_scale()
	e._bar = HealthBar.attach(e)
	Fx.dust(pos, 18)
	return e


## How much bigger than their build every skeleton but a boss is drawn (version 365).
const FOE_GROW := 1.2

var _live_t := randf() * 10.0
var _live_step := 0.0
var _live_rear := 0.0


## Version 365 (visual review v357 fix 7, "livelier skeletons"): a skeleton bounces on each
## step and leans into its run, swaying side to side; standing, it breathes; winding up a
## swipe, it rears back. (Bosses have their own moves.) Scripts that lift the body (a
## hover, a hop) set or add to visual.position.y after this.
func _liven(delta: float) -> void:
	if is_boss or visual == null:
		return
	_live_t += delta
	var moving := visual._moving and _frozen_left <= 0.0
	_live_step = move_toward(_live_step, 1.0 if moving else 0.0, delta * 5.0)
	_live_rear = move_toward(_live_rear, 1.0 if is_instance_valid(_swipe) else 0.0, delta * 4.0)
	visual.position.y = absf(sin(_live_t * 8.5)) * 0.11 * _live_step + sin(_live_t * 2.4) * 0.02 * (1.0 - _live_step)
	visual.rotation.x = -0.17 * _live_step + 0.3 * _live_rear
	visual.rotation.z = sin(_live_t * 4.25) * 0.09 * _live_step


func _setup() -> void:
	pass


func display_name() -> String:
	return "Skeleton"


## A readable name for this kind of skeleton, e.g. "Skeleton Warrior" (for the run report).
func kind_name() -> String:
	if is_boss:
		return display_name()
	var n := str(get_script().get_global_name())
	var out := ""
	for i in n.length():
		if i > 0 and n[i] == n[i].to_upper() and n[i] != n[i].to_lower():
			out += " "
		out += n[i]
	if elite and elite_move != "":
		return "Elite %s %s" % [ELITE_MOVES[elite_move].word, out]
	return ("Elite " if elite else "") + out


## Turns this skeleton into a purple elite (gold until version 116, the colour of coins and
## of the Crypt Pass hero). `pick` chooses its move (ELITE_MOVES); left empty, one is drawn
## from the room's dice, so the Daily Crypt's elites are the same for everyone.
func make_elite(pick := "") -> void:
	elite = true
	elite_move = pick if pick != "" else _pick_move()
	init_health(max_health * (WARD_HEALTH if elite_move == "ward" else ELITE_HEALTH))
	contact_damage *= 1.3
	knockback_scale *= 0.5
	radius *= 1.15
	drop_chance = maxf(drop_chance, 0.5)
	# Version 404 (re-review of v400, fix 4): a third bigger (was 1.22), and its edges glow
	# in its own kind's colour, wider, so a Fury, Splitter or Burst reads from across the room
	# (all five had the same faint purple edge).
	visual.scale *= 1.32
	# Version 372 (visual review fix 5): no purple wash. A purple glow round its edges and a
	# purple pool with the kind's sign on the floor, and the kind's own pieces (EliteParts).
	var own: Color = ELITE_MOVES[elite_move].col if ELITE_MOVES.has(elite_move) else Color(0.78, 0.38, 1.0)
	visual.set_rim(Color(own, 0.85), 2.3)
	_pool = U.floor_quad(self, Vector2(EliteParts.SIGN, EliteParts.SIGN), EliteParts.sign_mat(elite_move), Vector3(0, 0.05, 0))
	_parts = EliteParts.dress(self, elite_move)
	if elite_move != "" and elite_move != "mender":
		_parts["crown"] = EliteParts.crown(self, elite_move)   # v424: the kind's crown over its head
	if _bar:
		_bar.queue_free()
		_bar = HealthBar.attach(self)
	if elite_move == "":
		return
	var info: Dictionary = ELITE_MOVES[elite_move]
	_tag = Label3D.new()
	_tag.text = info.tag
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0006
	_tag.font_size = 25   # (v395: was 34, and it sat on the elite's own helmet)
	_tag.outline_size = 13   # (a heavy dark edge: green on a green floor still reads)
	_tag.modulate = info.col
	_tag.outline_modulate = Color(0.06, 0.02, 0.08)
	if Hud.UI_FONT:
		_tag.font = Hud.UI_FONT
	# Version 395 (visual review of v388, fix 8): the tag is smaller and lies at its feet, on
	# the screen under the body (see _place_tag), not on its head: the body parts name it.
	_tag.top_level = true
	# Version 387 (visual review of v383, fix 7): drawn after the bodies and shots, so a
	# skeleton walking past never covers it.
	_tag.render_priority = 30
	_tag.outline_render_priority = 29
	_tag.visible = false   # shown once it has climbed out of the floor
	add_child(_tag)
	# Version 404 (re-review of v400, fix 4): the name sits on a dark pill with the kind's
	# own little picture (tags in colour straight on the floor were unreadable on some floors).
	var font: Font = Hud.UI_FONT if Hud.UI_FONT else ThemeDB.fallback_font
	var tw := font.get_string_size(str(info.tag), HORIZONTAL_ALIGNMENT_LEFT, -1, _tag.font_size).x + float(_tag.outline_size)
	_tag_pill = Sprite3D.new()
	_tag_pill.texture = _pill_texture(int(tw) + 64, info.col)
	_tag_icon = Sprite3D.new()
	var icon := Hud.tip_picture("elite_" + elite_move)
	_tag_icon.texture = icon
	for sp: Sprite3D in [_tag_pill, _tag_icon]:
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.fixed_size = true
		sp.top_level = true
		sp.shaded = false
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_tag.add_child(sp)
	_tag_pill.pixel_size = _tag.pixel_size
	_tag_pill.render_priority = 28
	_tag_icon.render_priority = 31
	_tag_icon.visible = icon != null
	if icon:
		_tag_icon.pixel_size = _tag.pixel_size * 44.0 / float(icon.get_height())
	_tag_shift = 22.0   # the name moves right of the picture
	_tag_tick = Sprite3D.new()
	_tag_tick.texture = _tick_texture()
	_tag_tick.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag_tick.no_depth_test = true
	_tag_tick.fixed_size = true
	_tag_tick.top_level = true
	_tag_tick.shaded = false
	_tag_tick.pixel_size = _tag.pixel_size
	_tag_tick.render_priority = 27
	_tag_tick.modulate = Color(info.col, 1.0)
	_tag_tick.visible = false
	_tag.add_child(_tag_tick)
	if elite_move == "ward":
		_ward_hits = WARD_HITS
		# (v372: clear in the middle, bright at the edge, so the skeleton inside still shows)
		_bubble_mat = U.unlit(Color(info.col, 0.14)).duplicate() as StandardMaterial3D
		# Version 387 (fix 7): a solid band of the ward's colour round the bubble's edge,
		# painted over the floor (added light vanished on pale floors), with a dark line out.
		_bubble_mat.next_pass = EliteParts.ward_rim(Color(0.3, 0.68, 1.0))   # (deeper than the pale tag, so it reads on pale floors)
		_bubble = U.sphere(self, maxf(0.85, radius * 1.55), _bubble_mat, Vector3(0, center_height * 1.05, 0))
		_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bubble.visible = false   # with the tag, once it is out of the floor


## The tutorial's elites stay plain. Bloodbats come in threes and never split.
func _pick_move() -> String:
	if Game.first_run:
		return ""
	var bag := ELITE_MOVES.keys()
	if self is Bloodbat:
		bag.erase("split")
	# Version 278: a move already on the field is drawn last, so the elites of a wave differ
	# (floor 10's 30% elites drew four Menders at once in the review run).
	var fresh := bag.duplicate()
	for a: Actor in Actor.all:
		if a != self and a is Enemy and not a.dead:
			fresh.erase((a as Enemy).elite_move)
	if not fresh.is_empty():
		bag = fresh
	return bag[Game._room_rng.randi() % bag.size()]


## Each frame once it is up and the fight is on: the move's own timers.
func _elite_tick(delta: float) -> void:
	if _tag and not _tag.visible:
		# Version 296: the tag only until this kind of elite has been explained once.
		_tag.visible = not Game.taught("elite_" + elite_move)
		if not _tag.visible:
			_tag.queue_free()
			_tag = null
		if _bubble and _ward_hits > 0:
			_bubble.visible = true
		Game._teach("elite_" + elite_move, ELITE_MOVES[elite_move].tip, 4.0, "elite_" + elite_move)
	elif _tag and Engine.get_process_frames() % 15 == 0 and not Game.taught("elite_" + elite_move):
		# Version 298: the line may have waited for a calmer moment (Game.TIP_GAP); try again.
		Game._teach("elite_" + elite_move, ELITE_MOVES[elite_move].tip, 4.0, "elite_" + elite_move)
	if _tag:
		_place_tag()
		_fade_tag(delta)
	if _parts.has("crown"):
		var cr := _parts.crown as Node3D
		# leaned back toward the camera's slant so it reads side-on as a crown (from above it
		# was a ring), turning slowly on its own axis whichever way the elite faces
		cr.global_basis = Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.UP, Time.get_ticks_msec() * 0.0009) * Basis.from_scale(Vector3.ONE * 1.0)
		cr.position.y = float(cr.get_meta("base_y", 3.0)) + sin(Time.get_ticks_msec() * 0.0025 + get_instance_id()) * 0.07
	if _parts.has("plates"):   # (v395) the Warded elite's shield plates are up while its bubble is
		(_parts.plates as Node3D).visible = _bubble != null and _bubble.visible
	match elite_move:
		"fury":
			if not _furious and health < max_health * FURY_AT:
				_fury()
			elif _furious and randf() < delta * 10.0:
				Fx.magic(center(), ELITE_MOVES.fury.col, 1)
		"mender":
			if _parts.has("halo"):
				var halo := _parts.halo as Node3D
				halo.position.y = float(halo.get_meta("base_y", center_height * 2.0 + EliteParts.HALO_Y)) + sin(Time.get_ticks_msec() * 0.003 + get_instance_id()) * 0.06
			_mend_left -= delta
			if _mend_left <= 0.0:
				_mend_left = MEND_EVERY
				_mend()
		"ward":
			if _ward_hits <= 0 and _ward_regrown < WARD_REGROWS:
				_ward_left -= delta
				if _ward_left <= 0.0:
					_ward_up()
			elif _bubble:
				var s := 1.0 + sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 0.04
				_bubble.scale = Vector3(s, s, s)


## Version 278: the name tag fades out while it is up under the top bar (health, room and
## chain), so elites at the far wall don't write over the Bone Chain; it comes back as
## they walk down the room.
## The tag's place: on the floor just in front of its feet (toward the camera), whichever
## way the elite faces.
func _place_tag() -> void:
	# Version 424 (re-review of v420, fix 5): over its head (over its crown), where the eye looks
	# for a name; on the floor at its feet it slid under the hero and the thumb buttons.
	var over := (float((_parts.crown as Node3D).get_meta("base_y", 0.0)) + 1.35) if _parts.has("crown") and is_instance_valid(_parts.crown) \
		else ((float((_parts.halo as Node3D).get_meta("base_y", 0.0)) + 1.3) if _parts.has("halo") and is_instance_valid(_parts.halo) else center_height * 2.0 + 0.8)
	_tag.global_position = global_position + Vector3(0, over, 0)
	if _tag_pill:
		_tag_pill.global_position = _tag.global_position
		_tag_icon.global_position = _tag.global_position
		_tag_tick.global_position = _tag.global_position


static var _pills := {}
static var _tick: ImageTexture

## A thin line 6 x 32 pixels, pale in the middle with dark edges (tinted by the elite's colour).
static func _tick_texture() -> ImageTexture:
	if _tick == null:
		var img := Image.create(6, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 6:
				img.set_pixel(x, y, Color(1, 1, 1, 1) if x in [2, 3] else Color(0.05, 0.03, 0.08, 0.85))
		_tick = ImageTexture.create_from_image(img)
	return _tick


## How far (pill pixels) this pill must move so it isn't on the hero (0 if it isn't): up over
## the elite's own head.
func _tag_off_hero(cam: Camera3D, base: float) -> float:
	var hero := Game.hero
	if hero == null or not is_instance_valid(hero) or hero.dead:
		return 0.0
	var vh := get_viewport().get_visible_rect().size.y
	var k := _tag.pixel_size * vh * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var me := cam.unproject_position(_tag.global_position) + Vector2(base * k, 0.0)
	var feet := cam.unproject_position(hero.global_position)
	var head := cam.unproject_position(hero.global_position + Vector3.UP * 2.2)
	var half_w := float(_tag_pill.texture.get_width()) * k * 0.5
	if absf(me.x - feet.x) > half_w + 34.0:
		return 0.0
	if me.y + 20.0 * k < head.y or me.y - 20.0 * k > feet.y + 14.0:
		return 0.0
	# Version 414 (re-review of v410, fix 4): up over the elite's own head, away from the hero
	# (under the hero's feet, it lay in the hero's ring)
	var top := cam.unproject_position(global_position + Vector3.UP * (center_height * 2.0 * visual.scale.y / 1.32 + 0.5))
	return (me.y - top.y) / k + 24.0

## A dark rounded pill `w` x 40 pixels with a thin edge in `col` (version 404).
static func _pill_texture(w: int, col: Color) -> ImageTexture:
	var key := "%d%s" % [w, col.to_html()]
	if _pills.has(key):
		return _pills[key]
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var fill := Color(0.05, 0.03, 0.08, 0.9)
	var edge := Color(col.r, col.g, col.b, 0.85)
	for y in h:
		for x in w:
			var cx := clampf(float(x) + 0.5, r, float(w) - r)
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			if a <= 0.0:
				continue
			var c := edge if d > r - 2.5 else fill
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	var t := ImageTexture.create_from_image(img)
	_pills[key] = t
	return t


func _fade_tag(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hud == null:
		return
	var under := cam.unproject_position(_tag.global_position).y < Game.hud.top_band()
	_tag_a = move_toward(_tag_a, 0.0 if under else 1.0, delta * 6.0)
	# Version 387 (fix 7): by the side of the screen the tag slides in, so it is never cut off.
	var vw := get_viewport().get_visible_rect().size.x
	if vw > 0.0:
		var sx := cam.unproject_position(_tag.global_position).x / vw
		var half := _tag.text.length() * 11.0 + 12.0
		_tag.offset.x = half if sx < 0.2 else (-half if sx > 0.8 else 0.0)
	if _tag_pill:
		var base := _tag.offset.x
		_tag.offset.x = base + _tag_shift
		_tag_pill.offset.x = base
		var icon_k := maxf(_tag_icon.pixel_size / _tag.pixel_size, 0.001)
		_tag_icon.offset.x = (base - _tag_pill.texture.get_width() * 0.5 + 26.0) / icon_k
		# Two elites side by side: the later one's pill steps down a row, so the names
		# never run into each other.
		# And a pill that would lie on the hero moves down under the hero's feet instead
		# (it used to fade over the hero, unreadable, and hid the hero's ring).
		var goal := 46.0 * _tag_row(cam)   # (v424: a second elite's pill one row higher)
		_tag_y = move_toward(_tag_y, goal, delta * 400.0)
		_tag.offset.y = _tag_y
		_tag_pill.offset.y = _tag_y
		_tag_icon.offset.y = _tag_y / icon_k
		var gap := -_tag_y - 20.0
		_tag_tick.visible = gap > 6.0
		if _tag_tick.visible:
			_tag_tick.scale = Vector3(1.0, gap / 32.0, 1.0)
			_tag_tick.offset = Vector2(base, (_tag_y + 20.0) * 0.5 * 32.0 / gap)
	# Version 386 (fix 3): see-through right by the hero, so a crowd's tags don't bury it.
	# (v424: it stays over the head and fades as the hero comes close, so it never covers them)
	_tag.modulate.a = _tag_a * (1.0 - 0.3 * HealthBar.near_hero(global_position))   # (only a little: over the head it is off the hero)
	_tag.outline_modulate.a = _tag.modulate.a
	if _tag_pill:
		_tag_pill.modulate.a = _tag.modulate.a
		_tag_icon.modulate.a = _tag.modulate.a
		_tag_tick.modulate.a = _tag.modulate.a * 0.9


## How many rows down this elite's pill sits: the first row where no earlier elite's pill
## would overlap it on the screen (version 404).
func _tag_row(cam: Camera3D) -> int:
	var vh := get_viewport().get_visible_rect().size.y
	var k := _tag.pixel_size * vh * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var me := cam.unproject_position(_tag.global_position) + Vector2(_tag_pill.offset.x * k, 0.0)   # (with its slide in from the screen edge)
	var my_w := float(_tag_pill.texture.get_width()) * k
	var gaps: Array[float] = []
	for a: Actor in Actor.all:
		if a == self or not (a is Enemy):
			continue
		var o := a as Enemy
		if o.dead or o._tag == null or o._tag_pill == null or not o._tag.visible or o.get_instance_id() > get_instance_id():
			continue
		var p := cam.unproject_position(o._tag.global_position) + Vector2(o._tag_pill.offset.x * k, 0.0)
		if absf(p.x - me.x) < (my_w + float(o._tag_pill.texture.get_width()) * k) * 0.5 + 4.0:
			gaps.append(me.y - (p.y - o._tag_y * k))   # (screen y grows down; offset y grows up)
	for r in 4:
		var clash := false
		for g in gaps:
			if absf(g - 46.0 * r * k) < 44.0 * k:
				clash = true
				break
		if not clash:
			return r
	return 0


## Fury: half health. It stops to roar, turns red and from then on runs FURY_SPEED times as
## fast, and shrugs off most of the push of a hit.
func _fury() -> void:
	var col: Color = ELITE_MOVES.fury.col
	_furious = true
	move_speed *= FURY_SPEED
	knockback_scale *= 0.5
	_flinch_left = maxf(_flinch_left, 0.35)
	Sfx.play("roar", 0.4, 1.5)
	Fx.magic(center(), col, 26)
	Fx.shockwave(global_position, col, 2.2)
	if visual:
		visual.set_rim(Color(col, 1.0), 1.8)   # its purple edge turns to an angry red
		_punch_scale(1.14, 0.08, 0.25)
	if _parts.has("flames"):
		(_parts.flames as Node3D).visible = true   # (v372) a mane of flames
	if _pool:
		_pool.material_override = EliteParts.sign_mat("fury_hot")
	if _tag:
		_tag.text = "FURY!"


## Mender: heals each hurt skeleton within MEND_RANGE (never a boss, never itself) by
## MEND_SHARE of its health, with a green ring out of the mender so you can see who did it.
## Version 278: never another mender, and a skeleton is mended once a beat however many
## menders stand near it. Before, two or more menders healed each other faster than a
## hero could hurt them and the wave never ended (floor 10 review run, 7 minutes in room 1).
func _mend() -> void:
	var col: Color = ELITE_MOVES.mender.col
	var healed := 0
	for a: Actor in Actor.all:
		if a == self or a.team != team or a.dead or not (a is Enemy) or (a as Enemy).is_boss or not a.can_be_hit():
			continue
		if a.health >= a.max_health - 0.5 or (a as Enemy).elite_move == "mender":
			continue
		if Game._run_time - (a as Enemy)._mended_at < MEND_EVERY * 0.9:
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		if d.length() > MEND_RANGE + a.radius:
			continue
		a.heal(a.max_health * MEND_SHARE)
		(a as Enemy)._mended_at = Game._run_time
		Fx.magic(a.center(), col, 10)
		healed += 1
	if healed == 0:
		return
	Fx.shockwave(global_position, col, MEND_RANGE)
	Fx.magic(center() + Vector3.UP * 0.5, col, 14)
	Sfx.play("shimmer", 0.25, 1.5)
	_punch_scale(1.06, 0.06, 0.2)


## Ward: a hit on the bubble does nothing but use up one of its WARD_HITS.
func _ward_block() -> void:
	var col: Color = ELITE_MOVES.ward.col
	_ward_hits -= 1
	Game.note_progress()
	Fx.sparks(center(), col)
	if _bar:
		_bar.reveal()
	if _ward_hits > 0:
		Sfx.play("block", 0.4, 1.3)
		_bubble_mat.albedo_color.a = 0.05 + 0.03 * _ward_hits
		if _bubble:
			var tw := _bubble.create_tween()
			_bubble.scale = Vector3.ONE * 1.15
			tw.tween_property(_bubble, "scale", Vector3.ONE, 0.15)
		return
	# Broken: now it can be hurt, until the bubble grows back.
	_ward_left = WARD_REGROW
	Sfx.play("crack", 0.7, 1.25)
	Fx.magic(center(), col, 28)
	Fx.shockwave(global_position, col, 1.8)
	if _bubble:
		_bubble.visible = false
	if _tag:
		_tag.modulate = Color(col, 0.45)


func _ward_up() -> void:
	var col: Color = ELITE_MOVES.ward.col
	_ward_regrown += 1
	_ward_hits = WARD_HITS
	_bubble_mat.albedo_color.a = 0.14
	Sfx.play("shimmer", 0.3, 1.2)
	Fx.magic(center(), col, 16)
	if _bubble:
		_bubble.visible = true
		_bubble.scale = Vector3.ONE * 0.3
		_bubble.create_tween().tween_property(_bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _tag:
		_tag.modulate = col


## Splitter: two small, half-health skeletons pop out either side of it, across the hero's
## line of fire, so both can be seen at once.
func _split() -> void:
	var at := global_position
	var side := Vector3.RIGHT
	if Game.hero:
		var to := Game.hero.global_position - at
		to.y = 0.0
		if to.length_squared() > 0.01:
			side = to.normalized().cross(Vector3.UP)
	Fx.magic(center(), ELITE_MOVES.split.col, 24)
	Sfx.play("crack", 0.6, 0.8)
	for k in [-1.0, 1.0]:
		var off: Vector3 = side * k * 0.8
		var spot: Vector3 = Room.current.resolve_move(at, off, 0.4) if Room.current else at + off
		var m := Game.spawn_enemy("m", spot)
		m.init_health(m.max_health * SPLIT_HEALTH)
		m._spawn_timer = 0.3   # pops up, rather than climbing out
		m.radius *= 0.85
		m.visual.scale *= 0.8
		m.drop_chance = 0.0
		m.rotation.y = rotation.y


## Burst: DART_LINES strips fan out from where it fell, one straight at the hero, and a
## bone dart flies down each when they fill. Static, so the darts still fly once the body
## has gone.
static func _dart_fan(at: Vector3, hero_at: Vector3, src: String) -> void:
	var col: Color = ELITE_MOVES.burst.col
	var to := hero_at - at
	to.y = 0.0
	var turn := atan2(-to.x, -to.z) if to.length_squared() > 0.01 else randf() * TAU
	for i in DART_LINES:
		var d := Vector3.FORWARD.rotated(Vector3.UP, turn + TAU * i / DART_LINES)
		var fly := func():
			var p := Projectile.fire(Team.UNDEAD, at + Vector3.UP * 0.9 + d * 0.4, d, DART_DAMAGE, DART_SPEED, col, 0.24, src, "dart")
			p.life = DART_LENGTH / DART_SPEED
		Telegraph.line(at + d * 0.3, d, DART_LENGTH, 0.45, DART_WARN, fly, 0.6 if i == 0 else 0.0)


## Elites hit 30% harder (make_elite). Skeletons that change their touch damage mid-fight
## (a pounce, a lunge, coming up out of the water) multiply by this so elites keep it.
func elite_mult() -> float:
	return 1.3 if elite else 1.0


## Its boss has fallen: it crumbles at once, even while still climbing out of the floor
## (or, for a Drowned Skeleton, under the water), when it can't otherwise be hit.
func crumble() -> void:
	if dead:
		return
	_crumbling = true
	_spawn_timer = 0.0
	visual.position.y = 0.0
	_surface()
	take_damage(Actor.KILL, Vector3.ZERO, 0.0)


## Back up where it can be hit (only Drowned Skeletons ever go under).
func _surface() -> void:
	pass


## Pyre and Shatter: burning or chilled skeletons take their neighbours with them.
func _death_burst(h: Hero) -> void:
	var burning := get_node_or_null("Burning") != null
	# Version 307: Kindling, a burning skeleton leaves a patch of fire where it falls.
	if burning and h.perks.has("kindling") and Room.current:
		FirePatch.spawn_hero(global_position, 1.1, 3.0, maxf(h.burn_dps, 6.0))
	var pyre := burning and h.perks.has("pyre")
	var shatter := _slow_left > 0.0 and h.perks.has("shatter")
	if not pyre and not shatter:
		return
	var at := global_position
	var col := Color(1, 0.5, 0.15) if pyre else Color(0.6, 0.92, 1.0)
	Fx.shockwave(at, col, 2.4)
	Fx.magic(center(), col, 18)
	Sfx.play("boom" if pyre else "crack", 0.5)
	for a: Actor in Actor.all.duplicate():
		if a == self or a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var d := a.global_position - at
		d.y = 0.0
		if d.length() > 2.4 + a.radius:
			continue
		a.take_damage(15.0 + h.damage * 0.8, d, 3.0)
		if a.dead:
			continue
		if pyre:
			Burning.apply(a, h.burn_dps, 2.5)
		if shatter and a is Enemy:
			(a as Enemy).chill(h.frost_time)


## Bone Splinters: three bone shards fly out of a destroyed skeleton.
func _splinters(h: Hero) -> void:
	var turn := randf() * TAU
	for i in 3:
		var d := Vector3.FORWARD.rotated(Vector3.UP, turn + TAU * i / 3.0)
		var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 0.9 + d * 0.4, d, h.damage * 0.6 * Game.chain_damage(),
			h.bolt_speed * 0.8, Color(0.95, 0.92, 0.8), h.bolt_size * 0.8, "Shot", "shard")
		p.pierce = 1


## Version 307: frozen solid (Frostbite, Cold Snap): shut in a block of ice for `seconds`, it
## can't move or attack (the flinch keeps it standing). Bosses are only chilled.
var _frozen_left := 0.0
var _frost_hits := 0
var _ice_block: MeshInstance3D
static var _ice_mat: StandardMaterial3D
const ICE_COL := Color(0.62, 0.92, 1.0)

func freeze_solid(seconds: float) -> void:
	if dead or not can_be_hit():
		return
	chill(seconds + 1.0)
	if is_boss:
		return
	_frozen_left = maxf(_frozen_left, seconds)
	_flinch_left = maxf(_flinch_left, seconds)
	_cancel_attacks()
	if _ice_block == null:
		if _ice_mat == null:
			_ice_mat = U.unlit(Color(0.72, 0.95, 1.0, 0.45)).duplicate() as StandardMaterial3D
		_ice_block = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * 2.6, 2.0, radius * 2.6)
		_ice_block.mesh = box
		_ice_block.material_override = _ice_mat
		_ice_block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ice_block.position = Vector3(0, 1.0, 0)
		_ice_block.rotation.y = randf() * TAU
		add_child(_ice_block)
		# A frosted white lid: the camera looks down on the block, so its top is what shows.
		U.box(_ice_block, Vector3(radius * 2.3, 0.08, radius * 2.3), U.unlit(Color(0.94, 0.99, 1.0, 0.7)), Vector3(0, 1.0, 0))
	_ice_block.visible = true
	Fx.impact(center(), ICE_COL, 1.6)
	Fx.magic(center(), ICE_COL, 14)
	Sfx.play("crack", 0.45, 1.4)


## A hero's frost hit (Frost Shots, the Blizzard's Winter's Heart): it chills, and with
## Frostbite every 3rd hit on a skeleton that is already chilled freezes it solid.
func frost_hit(seconds: float, h: Hero) -> void:
	if h and h.perks.has("frostbite") and _slow_left > 0.0 and _frozen_left <= 0.0:
		_frost_hits += 1
		if _frost_hits >= 3:
			_frost_hits = 0
			freeze_solid(1.5)
			Game._teach("frostbite", "FROSTBITE: every 3rd hit on a chilled skeleton freezes it solid!")
	chill(seconds)


## Frost Shots: walk slower for a moment.
func chill(seconds: float) -> void:
	if _slow_left <= 0.0:
		Fx.magic(center(), Color(0.6, 0.9, 1.0), 8)
	_slow_left = maxf(_slow_left, seconds)


## Every drop is cut to 60%, rounded up or down at random so a single coin keeps its
## worth on average. Before, one full run of floors 1-5 bought the whole Armory.
const COIN_RATE := 0.6
## The tutorial drops hearts a third more often (as every floor did before the Nov 2 update).
const FIRST_RUN_HEARTS := 4.0 / 3.0


## Coins dropped when destroyed. Deeper floors pay a little more.
func coin_value() -> int:
	if elite:
		return 4 + Game.strength_floor()
	if is_boss:
		return 15 + 5 * (Game.strength_floor() - 1)
	return 1


func _think(_hero: Hero, _delta: float) -> void:
	pass


static func bones(key: String, height: float, eyes: Color) -> Dictionary:
	return {"key": key, "height": height, "body": Color(0.88, 0.86, 0.78), "accent": Color(0.3, 0.27, 0.3), "eyes": eyes, "skull_paint": eyes}


func ready_to_fight() -> bool:
	return _spawn_timer <= 0.0


## Version 272: whether a shot (or the Knight's sword) travelling along `dir` is stopped
## before it hurts: the Geode Guard's shield. Most skeletons block nothing.
func blocks_shot(_dir: Vector3) -> bool:
	return false


## A blocked shot's spark and sound (see blocks_shot).
func on_block(_at: Vector3) -> void:
	pass


## Can't be hit (or targeted) while still climbing out of the floor.
func can_be_hit() -> bool:
	return not dead and ready_to_fight()


func _process(delta: float) -> void:
	delta = minf(delta, MAX_STEP)   # v282 (Tweaks report #7): a long frame is a short slow-down, never a jump
	if dead:
		if visual and visual.rotation.x != 0.0:
			visual.rotation = Vector3(0.0, visual.rotation.y, 0.0)
		return
	if _entrance_held:
		return
	if _spawn_timer > 0.0:
		_spawn_timer -= delta
		var k := 1.0 - clampf(_spawn_timer / 0.9, 0.0, 1.0)
		# (Version 365: it bursts up out of the floor and overshoots a little, a hop.)
		var e := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
		visual.position.y = -(1.0 - e) * 1.8
		return
	visual.position.y = 0.0
	_liven(delta)
	_slow_left -= delta
	if _frozen_left > 0.0:
		_frozen_left -= delta
		if _frozen_left <= 0.0 and _ice_block:
			_ice_block.visible = false
			Fx.sparks(center(), ICE_COL)
	_roar_left -= delta
	_guard_left -= delta

	var hero := Game.hero
	if Game.state != Game.State.PLAYING or hero == null or hero.dead:
		stand(delta)
		return
	if elite_move != "":
		_elite_tick(delta)
	if _flinch_left > 0.0:
		_flinch_left -= delta
		stand(delta)
	elif is_instance_valid(_swipe):
		# Rooted while the swipe winds up, facing where it will land.
		stand(delta)
		face(_swipe_dir, 20.0, delta)
	else:
		_think(hero, delta)
	_separate()
	_touch(hero, delta)
	_check_reach(delta)
	_stuck_watch(hero, delta)
	_hide_watch(hero, delta)


## Version 238 (whole-game review fix 5): ten floors share five bosses, so the King came back
## on floors 5 and 7, the Lich on 5 and 8, the Colossus on 9, the Sporemother on 10 and the
## Tidecaller on 11, each the very same fight. A boss met again (past the floor it is first
## met on in a normal run; never in an event) brings an attack of its own that it never used
## before (ENCORES): its first move, then one more in its shuffled bag.
const BOSS_FIRST := {"SkeletonKing": 1, "Lich": 2, "CinderColossus": 3, "Sporemother": 4, "Tidecaller": 6, "StarEater": 10, "SandPharaoh": 5, "CrystalTyrant": 7, "Archivist": 8, "Forgemaster": 9}
const ENCORES := {"SkeletonKing": "King's Leap", "Lich": "Seeking Souls", "CinderColossus": "Flame Wheel",
	"Sporemother": "Deep Breath", "Tidecaller": "Geyser Chase", "StarEater": "Black Hole", "SandPharaoh": "Hourglass", "CrystalTyrant": "Rolling Geode", "Archivist": "Turning Page", "Forgemaster": "Iron Casting"}


func returning() -> bool:
	if not is_boss or Game.event != "" or Game.first_run:
		return false
	# Two bosses at once (floor 5, or Twin Wardens): only the first brings its new attack,
	# or the hardest free fight got both at once (the robot lasted 20 s there, was 34 s).
	if is_instance_valid(Game.boss) and Game.boss != self:
		return false
	var first: int = BOSS_FIRST.get(str(get_script().get_global_name()), 0)
	return first > 0 and Game.floor_num > first


## The new attack's name when this boss is back (for its title card), or "".
## Version 366 (visual review fix 8, boss entrances): a boss waits under the floor while
## the ground shakes (hold_under), then bursts up out of it (burst_up). The entrance runs on
## real time, like the rest of the boss intro, so a slow phone can't leave it half-risen.
var _entrance_held := false
var _rise_depth := 1.8

func hold_under() -> void:
	_entrance_held = true
	# (v411 re-review: the Skeleton King rose with his back to the camera, his new face unseen:
	# a boss rises facing the hero, who stands nearer the camera)
	if is_instance_valid(Game.hero):
		var d := Game.hero.global_position - global_position
		d.y = 0.0
		if d.length() > 0.1:
			rotation.y = atan2(-d.x, -d.z)
	_rise_depth = maxf(3.0, center_height * 3.2)
	_spawn_timer = 1.0   # (can't be hit while it is down there)
	visual.position.y = -_rise_depth


func burst_up(rise: float, delay := 0.0) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_property(visual, "position:y", 0.0, rise).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(release_up)


func release_up() -> void:
	_entrance_held = false
	_spawn_timer = 0.0
	if visual:
		visual.position.y = 0.0


## Each boss's own colour, for its entrance (the light, the rings and its name card).
const BOSS_COLORS := {"SkeletonKing": Color(1.0, 0.36, 0.26), "Lich": Color(0.5, 1.0, 0.55),
	"CinderColossus": Color(1.0, 0.52, 0.16), "Sporemother": Color(1.0, 0.45, 0.82),
	"Tidecaller": Color(0.32, 0.9, 1.0), "StarEater": Color(0.62, 0.55, 1.0),
	"SandPharaoh": Color(1.0, 0.77, 0.3), "CrystalTyrant": Color(0.9, 0.45, 1.0),
	"Archivist": Color(0.35, 1.0, 0.82), "Forgemaster": Color(1.0, 0.64, 0.26),
	"BloodQueen": Color(1.0, 0.24, 0.2), "Krampus": Color(0.55, 0.9, 1.0)}

func boss_color() -> Color:
	return BOSS_COLORS.get(str(get_script().get_global_name()), Color(1.0, 0.36, 0.26))


func encore_name() -> String:
	return str(ENCORES.get(str(get_script().get_global_name()), "")) if returning() else ""


## A returning boss opens with its new attack (call at the start of its brain).
func encore_first() -> void:
	if returning():
		_bag = ["encore"]


## Is `p` (radius `r`) on a strip from `origin` going `length` along `dir`, `width` wide?
static func in_strip(p: Vector3, origin: Vector3, dir: Vector3, length: float, width: float, r: float) -> bool:
	var d := p - origin
	d.y = 0.0
	dir.y = 0.0
	dir = dir.normalized()
	var along := d.dot(dir)
	if along < -r or along > length + r:
		return false
	return absf(d.dot(dir.cross(Vector3.UP))) <= width * 0.5 + r


## A strip warning has filled in: the hero standing on it is hit.
static func strike_strip(origin: Vector3, dir: Vector3, length: float, width: float, dmg: float, source: String) -> void:
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	if in_strip(hero.global_position, origin, dir, length, width, hero.radius * 0.6):
		Game.hit_source = source
		hero.take_damage(dmg, dir, 7.0)


## Bosses (version 119): the next move comes from a shuffled bag instead of a fixed loop,
## so the order changes every fight, and never the same move twice in a row.
var _bag: Array = []
var _last_move := ""


func next_move(moves: Array) -> String:
	if _bag.is_empty():
		_bag = moves.duplicate()
		for tries in 12:   # a few shuffles until no move follows itself
			_bag.shuffle()
			var ok: bool = _bag[0] != _last_move
			for i in _bag.size() - 1:
				if _bag[i] == _bag[i + 1]:
					ok = false
			if ok:
				break
	_last_move = str(_bag.pop_front())
	if _guard_move != "" and _last_move == _guard_move:
		# Phase 2's own move has begun: the boss can fall once players have seen it start.
		_guard_move = ""
		_guard_left = minf(_guard_left, GUARD_AFTER_MOVE)
	return _last_move


## Half health: the boss's second phase begins. Version 121 makes it a moment: the boss
## stops and roars for a second under a big PHASE 2 banner, glows in its colour for the rest
## of the fight, and its new move (`move`, called `move_name` on the banner) comes next.
var _roar_left := 0.0
## Version 147 (hard review of the Tweaks report, #4): strong heroes killed bosses in 6-11 s,
## often before phase 2's own move ever came. Now a boss can't fall below 1 health until
## that move has started (and GUARD_AFTER_MOVE more), and never for more than GUARD_TIME;
## during the roar shots still hit but do a quarter of their damage.
const GUARD_TIME := 5.0
const GUARD_AFTER_MOVE := 1.5
const ROAR_DAMAGE := 0.25
var _guard_left := 0.0
var _guard_move := ""


func phase_two(col: Color, move := "", move_name := "") -> void:
	_bag.clear()
	if move != "":
		_bag = [move]   # the new attack comes right after the roar
		_guard_move = move
		_guard_left = GUARD_TIME
	_roar_left = 1.0
	Game.buzz(70)
	_flinch_left = maxf(_flinch_left, 1.0)   # stands still while it roars
	Sfx.play(roar_sound)
	Game.shake(0.5)
	Game.hit_stop(0.12)
	Fx.magic(center(), col, 40)
	Fx.shockwave(global_position, col, 3.5)
	if visual:
		visual.enrage(col)
		_punch_scale(1.15, 0.12, 0.35)
	Game.hud.phase_banner(move_name, col)
	if is_boss:
		Game.boss_turned()   # v297: the floor's danger joins the fight


var _big_hit_at := -10000
var _vis_scale := Vector3.ZERO
var _scale_tw: Tween

## Grows the model by `k` and settles it back (always to its own size, even if punches overlap).
func _punch_scale(k: float, up: float, down: float) -> void:
	if visual == null:
		return
	if _vis_scale == Vector3.ZERO:
		_vis_scale = visual.scale
	if _scale_tw:
		_scale_tw.kill()
	_scale_tw = visual.create_tween()
	_scale_tw.tween_property(visual, "scale", _vis_scale * k, up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tw.tween_property(visual, "scale", _vis_scale, down)


## A boss's brain waits here before choosing a move, so nothing new starts during the roar.
func roar_done() -> void:
	while is_instance_valid(self) and not dead and _roar_left > 0.0:
		await get_tree().process_frame


## Version 282 (Tweaks report #1): one frame, and as long as the game is paused. A boss's
## move in flight (saws, belts, beams, carts, a wind-up) waits on the pause menu and carries
## on after RESUME. (The tree's process_frame still fires while paused, so a move that just
## awaited it used to see the PAUSED state and end, or let its wind-up run on.)
func frame() -> void:
	await get_tree().process_frame
	while is_instance_valid(self) and not dead and Game.state == Game.State.PAUSED:
		await get_tree().process_frame


## Watchdog: a skeleton that ends up past a wall or inside a pillar for over a second climbs
## back out at a free spot in the room, so a room can always be cleared.
func _check_reach(delta: float) -> void:
	var room := Room.current
	if room == null or room.is_walkable(global_position, radius):
		_out_time = 0.0
		return
	_out_time += delta
	if _out_time > 1.0:
		_out_time = 0.0
		var spot: Vector3 = Game.rescue_spot(global_position)
		print("[watchdog] %s moved from (%.2f, %.2f) back into the room" % [kind_name(), global_position.x, global_position.z])
		Game.report_stuck(self, Game.hero, 0.0, true, "inside a wall or pillar 1 s, moved")
		global_position = spot
		knockback = Vector3.ZERO
		_cancel_attacks()   # its warning would stay at the old spot
		Fx.dust(spot, 10)


## True while the hero's shots can't reach it (a pillar, crate or wall in between).
func hidden_from_hero() -> bool:
	return _cover_time >= 1.0


func _hide_watch(hero: Hero, delta: float) -> void:
	var room := Room.current
	if room == null or is_boss or not can_be_hit():
		_cover_time = 0.0
		return
	_cover_check -= delta
	if _cover_check > 0.0:
		_cover_time += delta if _cover_time > 0.0 else 0.0
	else:
		_cover_check = 0.5
		if room.clear_shot(hero.global_position, global_position):
			_cover_time = 0.0
		else:
			_cover_time += delta if _cover_time > 0.0 else 0.001
	if _cover_time < HIDE_LIMIT:
		return
	_cover_time = 0.0
	var spot: Vector3 = Game.rescue_spot(global_position.lerp(hero.global_position, 0.4), true)
	if spot == Vector3.ZERO:
		return
	Game.report_stuck(self, hero, 0.0, true, "behind cover %d s, moved" % int(HIDE_LIMIT))
	Fx.dust(global_position, 8)
	global_position = spot
	knockback = Vector3.ZERO
	_cancel_attacks()
	Fx.dust(spot, 10)


func _stuck_watch(hero: Hero, delta: float) -> void:
	var chased := _chasing_now
	_chasing_now = false
	if _stuck_win <= 0.0:
		_stuck_from = global_position
		_stuck_chase = 0.0
	_stuck_win += delta
	if chased:
		_stuck_chase += delta
	if _stuck_win < STUCK_WINDOW:
		return
	_stuck_win = 0.0
	var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	var gap := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
	if _stuck_chase < STUCK_WINDOW * 0.75 or moved >= STUCK_MOVE or gap < radius + hero.radius + 1.0 or _crowded():
		_stuck_count = 0
		return
	_stuck_count += 1
	var freed := false
	if _stuck_count >= 2 and not is_boss:
		# Stuck for about 8 seconds: climb out a few steps nearer the hero.
		var toward := global_position + (hero.global_position - global_position) * 0.5
		var spot: Vector3 = Game.rescue_spot(toward)
		if spot != Vector3.ZERO:
			Fx.dust(global_position, 8)
			global_position = spot
			knockback = Vector3.ZERO
			_cancel_attacks()
			Fx.dust(spot, 10)
			_stuck_count = 0
			freed = true
	Game.report_stuck(self, hero, moved, freed)


## Two or more friends pressed up against it: it is waiting its turn, not stuck on the room.
func _crowded() -> bool:
	var n := 0
	for a in Actor.all:
		if a == self or a.team != team or a.dead:
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		var m := radius + a.radius + 0.25
		if d.length_squared() < m * m:
			n += 1
			if n >= 2:
				return true
	return false


func _cancel_attacks() -> void:
	for t in _telegraphs:
		if is_instance_valid(t):
			t.cancel()
	_telegraphs.clear()
	if _swipe != null and is_instance_valid(_swipe):
		_swipe.cancel()
	_swipe = null


func _separate() -> void:
	# Version 126 (audit #6): in a big crowd each skeleton makes room every other frame (half
	# of them on even frames, half on odd), which halves this all-against-all check.
	if Game.alive_enemies > 16 and (Engine.get_process_frames() + get_instance_id()) % 2 == 1:
		return
	# Add up the push from every overlapping ally, then check the walls once (a pile of 6
	# used to run the wall check 5 times per enemy per frame).
	var push := Vector3.ZERO
	for a in Actor.all:
		if a == self or a.team != team or a.dead:
			continue
		var d := global_position - a.global_position
		d.y = 0.0
		var m := radius + a.radius
		var sq := d.length_squared()
		if sq < m * m and sq > 0.0001:
			var dist := sqrt(sq)
			push += d / dist * (m - dist) * 0.5
	if push != Vector3.ZERO:
		global_position = Room.current.resolve_move(global_position, push, radius) if Room.current else global_position + push


func _touch(hero: Hero, delta: float) -> void:
	_contact_cooldown -= delta
	if contact_damage <= 0.0 or _contact_cooldown > 0.0 or is_instance_valid(_swipe) or (_flinch_left > 0.0 and not is_boss):
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	var reach := radius + (body_extra if is_boss else 0.0) + hero.radius + 0.1   # (v424: a solid boss still hurts at its edge)
	if swipe_time > 0.0:
		if d.length_squared() < (reach + SWIPE_REACH) * (reach + SWIPE_REACH):
			_start_swipe(d)
		return
	if d.length_squared() < reach * reach:
		_contact_cooldown = 0.8
		Game.hit_source = kind_name()
		hero.take_damage(contact_damage, d, 9.0)


func _start_swipe(d: Vector3) -> void:
	_swipe_dir = d.normalized() if d.length_squared() > 0.0001 else -global_basis.z
	var at := global_position + _swipe_dir * (radius + 0.3)
	_swipe = track(Telegraph.circle(at, SWIPE_RADIUS, swipe_time, _land_swipe, 0.22))
	_swipe.perfectable = elite or is_boss
	_swipe.light = not is_boss
	visual.attack()
	Game.on_swipe_warning()


## The swipe lands where its circle was: only a hero still inside it is hurt.
func _land_swipe() -> void:
	var t := _swipe
	_swipe = null
	_contact_cooldown = 0.8
	var hero := Game.hero
	if dead or hero == null or hero.dead or not is_instance_valid(t):
		return
	if t._covers(hero.global_position, hero.radius * 0.6):
		Game.hit_source = kind_name()
		hero.take_damage(contact_damage, _swipe_dir, 9.0)


func walk(dir: Vector3, delta: float, speed_scale := 1.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		stand(delta)
		return
	dir = dir.normalized()
	if Room.current:
		# Version 165: walking at the hero (not backing off or circling), it finds the way
		# round props instead of only bending at the one in front.
		var routed := false
		var hero := Game.hero
		if hero and radius <= 0.8:
			var at := hero.global_position - global_position
			at.y = 0.0
			if at.length_squared() > 0.01 and dir.dot(at.normalized()) > 0.6:
				_chasing_now = true
				var way: Vector3 = Room.current.route(global_position, hero.global_position, radius)
				if not Room.current.last_clear:
					dir = way
					routed = true
		if not routed:
			dir = Room.current.steer(global_position, dir, radius)
	if _slow_left > 0.0:
		speed_scale *= 0.55
	if not IcePatch.all.is_empty() and IcePatch.under(global_position):
		speed_scale *= IcePatch.FOE_SLOW   # v290: slipping on the Frozen Ossuary's ice
	speed_scale *= Game.surge_mult()   # a Blood Moon surge (events)
	move_by(dir * move_speed * speed_scale * delta, delta)
	face(dir, 10.0, delta)
	visual.set_moving(true)


func stand(delta: float) -> void:
	visual.set_moving(false)
	move_by(Vector3.ZERO, delta)


func track(t: Telegraph) -> Telegraph:
	_telegraphs = _telegraphs.filter(func(x): return is_instance_valid(x))
	_telegraphs.append(t)
	return t


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	if _ward_hits > 0 and amount < Actor.KILL:
		_ward_block()
		return
	# Version 307: Deep Freeze shatters a chilled skeleton that falls to 20% health (a boss
	# only takes +30%, as the card used to give everyone).
	var shatter := false
	if _slow_left > 0.0 and Game.hero and Game.hero.perks.has("deepfreeze") and amount < Actor.KILL:
		if is_boss:
			amount *= 1.3
		elif health - amount <= max_health * 0.2:
			amount = maxf(amount, health)
			shatter = true
	if health < max_health * 0.3 and Game.hero and Game.hero.perks.has("executioner"):
		amount *= 1.5
	if is_boss:
		if _roar_left > 0.0:
			amount *= ROAR_DAMAGE
		if _guard_left > 0.0:
			amount = minf(amount, health - 1.0)
			if amount <= 0.0:
				Fx.sparks(center())   # still answers the hit, but holds on to its last health
				if visual:
					visual.hit()
				return
	super.take_damage(amount, direction, push * knockback_scale, crit)
	Game.note_progress()
	if shatter and dead:
		Fx.impact(center(), ICE_COL, 2.2)
		Fx.magic(center(), Color(0.85, 0.97, 1.0), 22)
		Sfx.play("crack", 0.6, 1.15)
	if _bar:
		_bar.reveal()
	# A hit worth a quarter of its health staggers it and breaks a swing still winding up.
	# Bosses never flinch, and fast weak shots can't lock a skeleton in place.
	# Version 122: a boss shows a big hit (8% of its health or more): a quick size punch and
	# a burst of sparks, at most every 0.4 s.
	if not dead and is_boss and amount >= max_health * 0.08 and Time.get_ticks_msec() - _big_hit_at > 400:
		_big_hit_at = Time.get_ticks_msec()
		_punch_scale(1.08, 0.06, 0.18)
		Fx.magic(center(), Color(1.0, 0.9, 0.6), 18)
		Sfx.play("crack", 0.5)
		Game.shake(0.15)
	if not dead and not is_boss and amount >= max_health * 0.25:
		_flinch_left = FLINCH_TIME
		if is_instance_valid(_swipe):
			_swipe.cancel()
			_swipe = null
			_contact_cooldown = 0.4


static var _deaths_frame := -1
static var _deaths_n := 0

func _on_death() -> void:
	if _ice_block:
		_ice_block.visible = false
	for t in _telegraphs:
		if is_instance_valid(t):
			t.cancel()
	_telegraphs.clear()
	# Version 403 (re-review of v400, fix 3): a plain skeleton breaks apart (CharacterVisual.
	# crumble) with a ring on the floor; bosses keep their long fall.
	if is_boss:
		visual.die()
	else:
		visual.crumble()
		# (critic: a filled pale disc per kill fogged the floor in a group kill; a thin ring in
		# the chain's colour that rushes out and is gone in a quarter second)
		Fx.shockwave(global_position, ChainSpine.color_for(Game.chain), 1.6 if radius < 0.8 else 2.4, 0.26)
	# Several kills in one frame (a pierce, a special) throw half the bones each, so a group
	# kill doesn't bury the hero in white.
	var frame := Engine.get_process_frames()
	_deaths_n = _deaths_n + 1 if frame == _deaths_frame else 1
	_deaths_frame = frame
	var bones_k := 1.0 if _deaths_n <= 1 else 0.5
	# Version 339 (visual review fix 4): real bones fly, and a pop of light at the body.
	# Version 386 (visual review of v383, fix 5): a kill read as a white puff (a big white pop
	# and 22 white dots). Now it is mostly bones: more of them, fewer dots, and a smaller pop
	# in the chain's colour (bone, then gold, then red-hot), so a streak shows in every kill.
	Fx.bones(global_position, int(9 * bones_k))
	Fx.bone_chunks(global_position, int((12 if radius < 0.8 else 17) * bones_k))
	Fx.impact(center(), ChainSpine.color_for(Game.chain).lerp(Color.WHITE, 0.15), 1.5 if radius < 0.8 else 2.4)
	# The crunch climbs as the chain grows (x3 is about two semitones up), so a good streak
	# sounds like one.
	Sfx.play(die_sound, 0.8, 1.0 + 0.065 * clampf(Game.chain - 1.0, 0.0, 3.0))
	Game.hit_stop(0.055)   # v339: a tiny freeze you can feel (was 0.035)
	Game.shake(0.14)
	if _bar:
		_bar.queue_free()
	if Game.hero:
		Game.hero.on_kill()
		_death_burst(Game.hero)
		if Game.hero.perks.has("splinters"):
			_splinters(Game.hero)
	if _tag:
		_tag.visible = false
	if _bubble:
		_bubble.visible = false
	if _parts.has("halo"):
		(_parts.halo as Node3D).visible = false
	if _parts.has("plates"):
		(_parts.plates as Node3D).visible = false
	if _pool:
		_pool.visible = false
	# An elite's last move (not when it crumbles because its boss fell). Before the game
	# counts it as gone, so its split skeletons keep the room from ending.
	if not _crumbling and Game.state == Game.State.PLAYING and Room.current:
		if elite_move == "split":
			_split()
		elif elite_move == "burst":
			_dart_fan(global_position, Game.hero.global_position if Game.hero else global_position, kind_name())
	var hearts := (FIRST_RUN_HEARTS if Game.first_run else 1.0) * Game.assist_hearts()
	if randf() < drop_chance * hearts + (Game.heart_bonus if drop_chance > 0.0 else 0.0) and not Game.curses.has("famine"):
		Pickup.drop(global_position)
	var coins := coin_value()
	if Game.hero and coins > 0:
		coins = U.round_random(coins * COIN_RATE * (1.0 + Game.hero.coin_bonus) * Game.chain_coins() * Game.coin_mult())
	Pickup.drop_coins(global_position, coins)
	Game.on_enemy_died(self)
	get_tree().create_timer(2.5, false).timeout.connect(queue_free)
