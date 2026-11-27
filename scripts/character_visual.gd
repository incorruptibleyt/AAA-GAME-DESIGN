class_name CharacterVisual
extends Node3D
## The look of a character. Uses the KayKit model (and its animations) when one has been
## uploaded; otherwise builds a stylised placeholder from simple shapes and animates it in
## code. Gameplay scripts only call set_moving / attack / hit / die, so they work either way.

## Animation names to try for each action, best first (KayKit naming).
const ANIMS := {
	"idle": ["Idle", "Idle_A", "Unarmed_Idle"],
	"run": ["Running_A", "Running_B", "Run", "Walking_A"],
	"attack": ["1H_Ranged_Shoot", "2H_Ranged_Shoot", "1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A", "Attack"],
	"cast": ["Spellcast_Shoot", "Spellcasting", "Spellcast_Long"],
	"hit": ["Hit_A", "Hit_B", "Hit"],
	"death": ["Death_C_Skeletons", "Death_A", "Death_B", "Death"],
}

var _model: Node3D
var _anim: AnimationPlayer
var _anim_names := {}
var _moving := false
var _bob := 0.0
var _punch := 0.0
var _dead := false
var _flash := 0.0
var _last_flash_ms := -100000
var _meshes: Array[GeometryInstance3D] = []
## Version 354: an outfit's own solid parts (meta "mark", OutfitShapes): they keep their
## colours, but count as the hero for the see-through silhouette. (A long mantle covered the
## hero's body, so the silhouette drew the body through it, a ghost over the cape.)
var _marked: Array[GeometryInstance3D] = []
static var _flash_mat: StandardMaterial3D
static var _soft_flash_mat: StandardMaterial3D
## Bosses take many hits a second, so theirs is a soft glow, less often (see hit()).
var soft_flash := false
## Version 213: the hero's hit flash is a red glow (HERO_FLASH), not white.
var hero_flash := false
static var _hero_flash_mat: ShaderMaterial
var _tint_mat: Material
static var _rim_shader: Shader
## A dark cartoon outline (High graphics) around the hero and the bosses, so they stand
## out from the floor. It is drawn as part of the overlay, ahead of the tint or flash. Plain
## skeletons don't get one: drawing every skeleton twice cost a Galaxy S23 Ultra a quarter
## of its frame rate in version 91 (see actor.gd), and the brighter rooms make them read.
static var outlines := true
## Set before build(): this character gets the outline.
var outline_me := false
static var _outline_shader: Shader
const OUTLINE_INK := Color(0.07, 0.035, 0.1)
## Outline width as a share of the screen height (about 3 pixels on a 1200-pixel screen).
const OUTLINE_WIDTH := 0.0026
var _outlined := {}
## Only the biggest parts get the outline (body, head, hat, big weapon): they make the
## silhouette, and small pieces would cost an extra draw each for no visible line.
const OUTLINE_PARTS := 5
var _outline_set := {}
## Version 305 (Supercell review fix 3): the hero in a run wears a bright line in the
## heroes' own colour instead of the dark ink, on every graphics setting, so a blue Rogue on
## the blue Abyss or a purple Mage among purple elites is still found at a glance (a Master
## aura keeps its own colours). Only the hero, so it costs one character's few extra draws.
var team_line := false
const TEAM_INK := Color(0.72, 0.96, 1.0)
const TEAM_WIDTH := 0.0052   # v336: was 0.004, lost on busy floors
## Version 305: while the hero can't be hurt after a hit, they flicker pale instead of
## vanishing (the blink used to hide the whole model, leaving only a dark ring).
var _blink_off := false
static var _blink_mat: ShaderMaterial
## Version 296 (deep review fix 4): the hero is drawn again wherever something stands in
## front of them (a boss, a crowd, a pillar), as a bright see-through silhouette, so the
## player never loses their hero. It only shows where the hero is hidden (a
## test through a stencil mark, see _with_xray).
var xray := false
## The colour of that silhouette: the hero's own (ring) colour (version 401).
var xray_color := Color(0.4, 0.95, 1.0)
## Its edge colour, when the body colour isn't the ring's (the Knight: silver, gold edge).
var xray_rim := Color(0, 0, 0, 0)
static var _xray_mat: ShaderMaterial
static var _xray_mark: ShaderMaterial
static var _edge_shader: Shader
const XRAY_COL := Color(0.4, 0.95, 1.0)
var _xrayed := {}
## A Master aura (hero_style.gd): a brighter, slightly wider outline in the aura's colours.
var _aura := {}
const AURA_WIDTH := 0.0036
## How much wider the aura's outline is drawn (the big hero on the Style screen's pedestal).
var aura_boost := 1.0


## look: {key, height, body, accent, eyes, hat, horns, crown, hood, helmet, shield, bow, bomb, tint, rim,
## overlay, hide}
func build(look: Dictionary) -> void:
	var scene := Art.get_model(look.get("key", ""))
	if scene:
		_model = scene.instantiate() as Node3D
		Art.bind_skins(_model)
		add_child(_model)
		Art.fit_height(_model, look.height)
		_model.rotation.y = PI   # KayKit models face +Z; our "forward" is -Z
		_anim = _find_anim(_model)
		_dress_model(look)
		if _anim:
			for action in ANIMS:
				var names: Array = ANIMS[action]
				if action == "attack" and look.has("attack_anim"):
					names = [look.attack_anim] + names
				for n in names:
					if _anim.has_animation(n):
						_anim_names[action] = n
						break
			for loop_action in ["idle", "run"]:
				if _anim_names.has(loop_action):
					var a := _anim.get_animation(_anim_names[loop_action])
					a.loop_mode = Animation.LOOP_LINEAR
	else:
		_model = _placeholder(look)
	_collect_meshes(_model)
	if look.has("overlay"):
		# A ready-made material drawn over the whole model (the Cinder Skeleton's charring).
		_tint_mat = look.overlay
		_body_overlay = true
	elif look.has("tint"):
		# A coloured glow over the whole model, so look-alike skeletons stand apart.
		_tint_mat = U.unlit(look.tint)
		_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	elif look.has("rim"):
		_tint_mat = rim_material(look.rim, float(look.get("rim_power", 2.2)), look.get("rim2", look.rim))
	_set_flash(false)
	_play("idle")


var _rim_alpha := -1.0
var _aura_width := -1.0

## Version 382: the hero's run marks on or off: the bright "this is you" line (off = the dark
## ink line) and the see-through ghost when something hides them. Off on the title, where
## the hero stands close: the bright line looked like a sticker's edge, and the ghost drew a
## cyan seam where the helmet overlaps the face.
func set_run_marks(on: bool) -> void:
	if team_line == on and xray == on:
		return
	team_line = on
	xray = on
	_outlined.clear()
	_set_flash(false)


## A look's reveal on the pedestal (version 131): the hero's edge glow `k` times as bright,
## and a Master aura's line a little wider while it's brighter than usual.
func rim_boost(k: float) -> void:
	var m := _tint_mat as ShaderMaterial
	if m and m.shader == _rim_shader:
		var c: Color = m.get_shader_parameter("rim")
		if _rim_alpha < 0.0:
			_rim_alpha = c.a
		c.a = _rim_alpha * k
		m.set_shader_parameter("rim", c)
	if not _aura.is_empty():
		for o: ShaderMaterial in _outlined.values():
			if _aura_width < 0.0:
				_aura_width = float(o.get_shader_parameter("width"))
			o.set_shader_parameter("width", _aura_width * (1.0 + 0.25 * (k - 1.0)))


## A bright glow around a model's edges (heroes), so they stand out from above on any floor.
## `col2` (version 132, the Legend road's glows): the glow shimmers between the two colours.
static func rim_material(col: Color, power := 2.2, col2: Variant = null) -> ShaderMaterial:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 rim : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform vec3 rim2 : source_color = vec3(0.4, 0.7, 1.0);
uniform float power = 2.2;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	// a slow wave of the second colour running up the hero (the same colour twice: no change)
	float w = 0.5 + 0.5 * sin(TIME * 2.4 - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y * 3.0);
	ALBEDO = mix(rim.rgb, rim2, w) * f * rim.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _rim_shader
	m.set_shader_parameter("rim", col)
	var c2: Color = col2 if col2 is Color else col
	m.set_shader_parameter("rim2", Vector3(c2.r, c2.g, c2.b))
	m.set_shader_parameter("power", power)
	return m


## Weapons, shields and extras for KayKit models.
func _dress_model(look: Dictionary) -> void:
	Art.hide_parts(_model, look.get("hide", []))
	if look.has("weapon"):
		Art.attach_to_bone(_model, "handslot.r", look.weapon)
	if look.has("offhand"):
		Art.attach_to_bone(_model, "handslot.l", look.offhand)
	if look.has("style"):
		HeroStyle.dress(_model, look.style)   # a hero's chosen look (hero_style.gd)
		if look.style.has("legend"):
			Legends.dress(self, _model, look.style.legend)   # the Legend Vault's (version 312)
	_aura = look.get("aura", {})
	var skel := Art._find_skeleton(_model)
	if skel == null:
		return
	if look.get("crown", false) and skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		_boss_crown(att, float(look.get("crown_s", 0.6)), float(look.get("crown_y", 1.25)), float(look.get("crown_tall", 1.0)))   # (v348: lower on a bare skull)
	if look.get("bomb", false) and skel.find_bone("chest") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "chest"
		U.sphere(att, 0.42, U.mat(Color(0.08, 0.08, 0.1), 0.4), Vector3(0, 0.25, -0.45))
		U.sphere(att, 0.1, U.mat(Color(1.0, 0.6, 0.1), 0.5, 4.0), Vector3(0, 0.72, -0.5))
	# Version 343 (visual review fix 7): a skeleton kind's own parts and build.
	if look.has("skull_paint"):
		Art.dress_skulls(_model, look.skull_paint)   # version 376: each kind's own skull
	if look.has("parts"):
		FoeBodies.dress(_model, look.parts)
	if look.has("shape"):
		BodyShape.apply(_model, look.shape)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _collect_meshes(n: Node) -> void:
	if n is GeometryInstance3D and not n.has_meta("fx"):   # not glow quads: the hit flash made them white squares
		_meshes.append(n)
	elif n is GeometryInstance3D and n.has_meta("mark"):
		_marked.append(n)
	for c in n.get_children():
		_collect_meshes(c)


# ---------------------------------------------------------------- API

func set_moving(m: bool) -> void:
	if _dead or _held:
		return
	_moving = m
	if _anim and _anim.current_animation in [_anim_names.get("idle", ""), _anim_names.get("run", ""), ""]:
		_play("run" if m else "idle")


func attack(spell := false) -> void:
	if _dead or _held:
		return
	_queue.clear()
	_punch = 1.0
	_play("cast" if spell and _anim_names.has("cast") else "attack", true)


## A hero's emote (version 129): the model's own animations, one after another, then back
## to idle. Names the model doesn't have are skipped.
var _queue: Array = []

func emote(names: Array) -> void:
	_queue = names.filter(func(n): return _anim != null and _anim.has_animation(n))
	if not _queue.is_empty():
		play_named(_queue.pop_front())


## Plays one of the model's own animations once, by name (a boss's leap or summon).
## Returns false when the model doesn't have it.
func play_named(n: String) -> bool:
	if _dead or _anim == null or not _anim.has_animation(n):
		return false
	_punch = 1.0
	_anim.play(n, 0.1)
	_anim.seek(0.0, true)
	return true


## The white hit flash. It runs on real time, not game time, and starts again at most
## every FLASH_GAP seconds: in slow motion (the dash lesson, perfect dodges, specials) a
## boss hit by a ring of bolts used to stay white the whole time, a flat white blob.
## A boss (soft_flash) is struck nearly every frame in a fight, and a solid white flash four
## times a second looked like flickering, so a boss gets a faint glow added over
## its colours (it lifts bone, it does not white it out), at most twice a second.
const FLASH_TIME := 0.07
## The hero's red flush lasts longer (version 403), so a hit is seen on the hero.
const HERO_FLASH_TIME := 0.16
const FLASH_GAP := 0.25
const SOFT_FLASH_GAP := 0.5

func hit() -> void:
	if _dead or _held:
		return
	var now := Time.get_ticks_msec()
	_hit_punch(now)
	if now - _last_flash_ms < int((SOFT_FLASH_GAP if soft_flash else FLASH_GAP) * 1000.0):
		return
	_last_flash_ms = now
	_flash = HERO_FLASH_TIME if hero_flash else FLASH_TIME
	_set_flash(true)
	# Version 218 (review 4): the hero's hit starts white for 0.04 s, so it isn't told by
	# red alone (red bats, red Shades and red bars all around in the Blood Moon).
	# Version 403 (critic of fix 3): only on the red floors and the Blood Moon now; elsewhere
	# the hit is red from its first frame (white read as a dash or a heal, not a hurt).
	if hero_flash and _hero_flash_mat:
		_hero_flash_mat.set_shader_parameter("white", 1.0 if (Floors.hot() or Floors.blood_moon()) else 0.0)


## Version 339 (visual review fix 4, "kills that pop"): a hit squashes the body for a blink
## (wider and shorter, then a springy bounce back), so every hit lands with a jolt as well as
## the glow. Skeletons with real animations only (the simple models already squash); bosses
## a little, the hero not at all. At most about 8 times a second.
var _punch_tw: Tween
var _punch_ms := -100000
var _base_scale := Vector3.ZERO

func _hit_punch(now: int) -> void:
	if _anim == null or _model == null or hero_flash or now - _punch_ms < 120:
		return
	_punch_ms = now
	if _base_scale == Vector3.ZERO:
		_base_scale = _model.scale
	if _punch_tw and _punch_tw.is_valid():
		_punch_tw.kill()
	var k := 0.06 if soft_flash else 0.16
	_model.scale = _base_scale * Vector3(1.0 + k, 1.0 - k, 1.0 + k)
	_punch_tw = create_tween()
	_punch_tw.tween_property(_model, "scale", _base_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func die() -> void:
	if _dead:
		return
	_dead = true
	if _punch_tw and _punch_tw.is_valid():
		_punch_tw.kill()
	if _base_scale != Vector3.ZERO and _model:
		_model.scale = _base_scale
	_set_flash(false)
	_calm(true)
	if _anim and _anim_names.has("death"):
		_play("death", true)
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(_model, "position:y", -1.5, 0.8)
	else:
		var tw := create_tween()
		tw.tween_property(_model, "rotation:x", -1.45, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.4)
		tw.tween_property(_model, "position:y", -1.5, 0.8)


## Version 403 (re-review of v400, fix 3, "real kill bursts"): a plain skeleton doesn't fall
## over and sink for two seconds; it breaks apart. The body jolts up and wide, then caves in
## flat to the floor in a fifth of a second and is gone, while its bones fly (Enemy._on_death).
func crumble() -> void:
	if _dead:
		return
	_dead = true
	if _punch_tw and _punch_tw.is_valid():
		_punch_tw.kill()
	if _model == null:
		return
	if _base_scale != Vector3.ZERO:
		_model.scale = _base_scale
	_set_flash(false)
	var s := _model.scale
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(s.x * 1.25, s.y * 1.12, s.z * 1.25), 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "scale", Vector3(s.x * 1.5, s.y * 0.06, s.z * 1.5), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _model.visible = false)


## Lying down (dead or knocked down): outfit bands measured by height above the floor are
## turned off (hero_style.gd "calm"), on this hero's own copies of its outfit materials (the
## materials are shared between heroes dressed alike). Version 200.
var _calm_mats := {}

func _calm(on: bool) -> void:
	if _model == null:
		return
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override
		if on and m is ShaderMaterial and (m as ShaderMaterial).shader and (m as ShaderMaterial).shader.code.contains("uniform float calm"):
			_calm_mats[mi] = m
			var c := (m as ShaderMaterial).duplicate() as ShaderMaterial
			c.set_shader_parameter("calm", 1.0)
			(mi as MeshInstance3D).material_override = c
		elif not on and _calm_mats.has(mi):
			(mi as MeshInstance3D).material_override = _calm_mats[mi]
	if not on:
		_calm_mats.clear()


## Crypt Race (version 153): knocked down, lying still until stand_up(). Held on the death
## animation's last pose, so it looks like a fall, not a death (the model doesn't sink).
var _held := false

func knock_down() -> void:
	if _dead:
		return
	_queue.clear()
	_held = true
	_set_flash(false)
	_calm(true)
	if _anim and _anim.has_animation("Death_A"):
		_anim.play("Death_A", 0.1)
		_anim.seek(0.0, true)
	else:
		var tw := create_tween()
		tw.tween_property(_model, "rotation:x", -1.45, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func stand_up() -> void:
	if not _held:
		return
	_held = false
	_calm(false)
	if _anim and _anim.has_animation("Lie_StandUp"):
		_anim.play("Lie_StandUp", 0.15)
		_anim.seek(0.0, true)
	elif _anim == null:
		var tw := create_tween()
		tw.tween_property(_model, "rotation:x", 0.0, 0.25)


func set_visible_blink(v: bool) -> void:
	_model.visible = true
	if _blink_off == (not v):
		return
	_blink_off = not v
	# Version 403 (re-review of v400, fix 3): the hit's red flush is not cut short by the
	# blink that starts on the same frame (it was, so a hit showed as a white wash, never red).
	if _flash <= 0.0:
		_set_flash(false)


# ---------------------------------------------------------------- internals

func _play(action: String, restart := false) -> void:
	if _anim == null or not _anim_names.has(action):
		return
	var n: String = _anim_names[action]
	if _anim.current_animation == n and not restart:
		return
	_anim.play(n, 0.1)
	if restart:
		_anim.seek(0.0, true)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta / maxf(Engine.time_scale, 0.01)   # real seconds, even in slow motion
		# v220 (v219 review): on the red and orange floors the hit stays white all the way (red
		# on red could not be seen).
		if hero_flash and _hero_flash_mat and _flash < HERO_FLASH_TIME - 0.04 and not (Floors.hot() or Floors.blood_moon()):
			_hero_flash_mat.set_shader_parameter("white", 0.0)   # v218: white, then red
		if _flash <= 0.0:
			_set_flash(false)

	if _anim:
		# Return to idle/run once a one-shot (attack, hit) finishes.
		if not _dead and not _held and (_anim.current_animation == "" or (not _anim.is_playing())):
			if not _queue.is_empty():
				play_named(_queue.pop_front())
			else:
				_play("run" if _moving else "idle", true)
		return
	if _dead:
		return
	# Placeholder animation: bob while walking, squash on attack.
	_bob += delta * (14.0 if _moving else 3.0)
	var bob_y := absf(sin(_bob)) * 0.12 if _moving else sin(_bob) * 0.02
	_punch = move_toward(_punch, 0.0, delta * 6.0)
	var squash := 1.0 + _punch * 0.2
	_model.position = Vector3(0, bob_y, -_punch * 0.15)
	_model.rotation = Vector3(-0.14 if _moving else 0.0, 0, sin(_bob * 0.5) * (0.07 if _moving else 0.0))
	_model.scale = Vector3(squash, 1.0 / squash, squash)


## Give the model a coloured glow after it's built (used for elite skeletons).
func set_tint(col: Color) -> void:
	_tint_mat = U.unlit(col)
	_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_set_flash(false)


## Version 372: an elite's glow round its edges in `col`, on top of the overlay its kind
## already wears; the skeleton keeps its own colours (it used to be washed purple). Set
## again (a Fury elite raging), the new glow takes the old one's place.
var _under_rim: Material
var _has_rim := false

func set_rim(col: Color, power := 1.6) -> void:
	if not _has_rim:
		_under_rim = _tint_mat
		_has_rim = true
	var rim := rim_material(col, power)
	if _under_rim == null:
		_tint_mat = rim
	else:
		var m: Material = _under_rim.duplicate()
		m.next_pass = rim
		_tint_mat = m
	_set_flash(false)


## A boss's second phase (version 121): a lasting glow in `col` round its edges, on top of
## whatever tint or overlay it already wears.
func enrage(col: Color) -> void:
	var rim := rim_material(Color(col, 0.75), 1.6)
	if _tint_mat == null:
		_tint_mat = rim
	else:
		var m: Material = _tint_mat.duplicate()
		m.next_pass = rim
		_tint_mat = m
	_set_flash(false)


var _body_overlay := false
var _hit_over := {}


func _set_flash(on: bool) -> void:
	if _flash_mat == null:
		# Version 296 (deep review fix 4): the skeletons' hit flash brightens them instead of
		# painting them solid white: a crowd hit by a volley turned into one white blob.
		# Version 386 (visual review of v383, fix 5): a warm hot-orange tint, not near-white:
		# added to pale bone, white made a hit skull one bright blob with no face.
		_flash_mat = U.unlit(Color(0.5, 0.26, 0.08)).duplicate() as StandardMaterial3D
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_soft_flash_mat = _flash_mat.duplicate()
		_soft_flash_mat.albedo_color = Color(0.24, 0.13, 0.05)
		_soft_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if _hero_flash_mat == null:
		# Version 216 (review 2 fix #4): a red edge round the hero, painted over (not added
		# to) the outfit, so a blue hero doesn't turn purple like an elite skeleton.
		# Version 403 (re-review of v400, fix 3): the whole body flushes red now (0.42 over
		# the body, the edge stronger), held a little longer: the hurt shows on the hero.
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, cull_back, depth_draw_never;\n" \
			+ "uniform float white = 0.0;\n" \
			+ "void fragment() {\n\tfloat rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);\n" \
			+ "\tALBEDO = mix(vec3(1.0, 0.16, 0.1), vec3(1.0), white);\n\tALPHA = clamp(pow(rim, 1.6) * 1.2 + 0.42 + white * 0.2, 0.0, 0.9);\n}\n"
		_hero_flash_mat = ShaderMaterial.new()
		_hero_flash_mat.shader = sh
	var hit_mat: Material = _hero_flash_mat if hero_flash else (_soft_flash_mat if soft_flash else _flash_mat)
	if on and _body_overlay and _tint_mat != null:
		# Version 387 (visual review of v383, fix 7): a body drawn by its overlay (the Star
		# Eater's night sky, the Cinder Skeleton's charring) keeps it when hit, with the flash
		# added on top; the flash used to replace it, so the bare bone showed for a moment.
		var key := [_tint_mat, hit_mat]
		if not _hit_over.has(key):
			var chained: Material = _tint_mat.duplicate()
			var last := chained
			while last.next_pass != null:
				last.next_pass = last.next_pass.duplicate()
				last = last.next_pass
			last.next_pass = hit_mat
			_hit_over[key] = chained
		hit_mat = _hit_over[key]
	var mat: Material = hit_mat if on else (_blink_material() if _blink_off else _tint_mat)
	var lined: Material = _with_outline(mat) if outline_me and (outlines or team_line) and not _dead else mat
	if _outline_set.is_empty():
		_pick_outline_meshes()
	var seen: Material = _with_xray(lined) if xray and not _dead else lined
	# Version 361 (review of 357, fix 4): the hero's other pieces (shield, weapon, small
	# parts with no outline) mark where they are seen too. Unmarked, the ghost was drawn
	# over the hero's own shield and sword, so the hero looked see-through cyan with
	# nothing in front of them.
	var plain: Material = _marked_chain(mat) if xray and not _dead else mat
	# Version 401: the weapon is not part of the solid figure (a staff or crossbow drawn over
	# the heads of a pile looked pasted on): it keeps its line and its mark only.
	var arm: Material = _marked_chain(lined) if xray and not _dead else lined
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = (arm if m.has_meta("big") else seen) if _outline_set.has(m) else plain
	for m in _marked:
		if is_instance_valid(m):
			m.material_overlay = _xray_mark if xray and not _dead else null


## `inner` (may be null) after the stencil mark that says "the hero is seen here".
func _marked_chain(inner: Material) -> Material:
	_with_xray(null if inner == null else inner)   # makes the shared materials
	if inner == null:
		return _xray_mark
	var key := "mark:%d" % inner.get_instance_id()
	if not _xrayed.has(key):
		var head := _xray_mark.duplicate() as ShaderMaterial
		head.next_pass = inner
		_xrayed[key] = head
	return _xrayed[key]


## The pale flicker of a hero who can't be hurt just now (see _blink_off): a see-through
## white-cyan wash, brightest at the edges, over the outfit. (Version 401: a third as
## strong over the body; just after a hit, in a pile, the hero turned into a white ghost.
## Version 403: only a pale edge now, nothing over the body.)
static func _blink_material() -> ShaderMaterial:
	if _blink_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, cull_back, depth_draw_never;\n" \
			+ "void fragment() {\n\tfloat rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);\n" \
			+ "\tALBEDO = vec3(0.85, 0.98, 1.0);\n\tALPHA = clamp(pow(rim, 2.0) * 0.5, 0.0, 0.45);\n}\n"
		_blink_mat = ShaderMaterial.new()
		_blink_mat.shader = sh
	return _blink_mat


## `inner` with the see-through silhouette (see xray). Two passes head the chain: the first
## marks every pixel where the hero can be seen (a stencil mark, drawing nothing), the second
## draws the silhouette with no depth test, but only on unmarked pixels: so it shows where
## something hides the hero, and never over the hero's own visible body.
func _with_xray(inner: Material) -> Material:
	if _xray_mat == null:
		var mark := Shader.new()
		mark.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back, shadows_disabled;
stencil_mode write, compare_always, 2;
void fragment() { ALBEDO = vec3(0.0); ALPHA = 0.0; }
"""
		_xray_mark = ShaderMaterial.new()
		_xray_mark.shader = mark
		_xray_mark.render_priority = 9
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;
stencil_mode read, write, compare_not_equal, 2;
uniform vec4 col : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform vec4 rimc : source_color = vec4(0.94, 1.0, 1.0, 1.0);
// Version 361 (review of 357, fix 4): a bright edge with only a faint fill (it was a
// solid cyan body at 38% that hid the outfit), so a hidden hero reads as an outline.
void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = 1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	// Version 377: thinner still, no fill (a hidden Rogue read as a see-through blue egg).
	// v390 (review v388 fix 2): a light fill again, now that the outline drawn on top gives
	// the hidden hero its real shape (no egg), so a hero under a crowd is a solid shape.
	// Version 401 (re-review of v400, fix 1): the 30% cyan fill read as a pale glass ghost
	// smeared over a pile of skeletons. A hidden hero is a solid figure in the hero's own
	// colour now: lit from above, darker below, a pale edge, nothing seen through it.
	float up = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 body = mix(col.rgb * 0.42, col.rgb * 1.05, smoothstep(0.3, 0.8, up));
	ALBEDO = mix(body, rimc.rgb, smoothstep(0.62, 0.92, rim) * rimc.a);
	ALPHA = 0.86;   // (a little of the attacker in front still shows)
}
"""
		_xray_mat = ShaderMaterial.new()
		_xray_mat.shader = sh
		_xray_mat.render_priority = 10
	if _xrayed.has(inner):
		return _xrayed[inner]
	var head := _xray_mark.duplicate() as ShaderMaterial
	var ghost := _xray_mat.duplicate() as ShaderMaterial
	ghost.set_shader_parameter("col", xray_color)
	ghost.set_shader_parameter("rimc", Color(0.94, 1.0, 1.0, 0.55) if xray_rim.a <= 0.0 else xray_rim)
	head.next_pass = ghost
	ghost.next_pass = inner   # the flash and outline follow unchanged
	# v390 (review v388 fix 2, always see your hero): the outline itself is drawn on top of
	# whatever stands in front (a boss, a crowd, a pillar), in the line's own colour, so the
	# hero's whole shape shows through. The ghost above marks the hidden body, so the line
	# only draws outside the hero's shape, never across it.
	var lined := inner as ShaderMaterial
	if lined != null and lined.shader == _outline_shader:
		var edge := ShaderMaterial.new()
		edge.shader = _edge()
		edge.render_priority = 11
		for p in ["ink", "ink2", "cycle", "shine"]:
			edge.set_shader_parameter(p, lined.get_shader_parameter(p))
		var w = lined.get_shader_parameter("width")
		edge.set_shader_parameter("width", (float(w) if w != null else OUTLINE_WIDTH) * 1.25)   # a little bolder than the line it covers
		ghost.next_pass = edge
		edge.next_pass = inner
	_xrayed[inner] = head
	return head


## The outline's shader drawn with no depth test, only where the hero's shape isn't (the
## stencil mark of 2), as a see-through pass after the marks and the ghost.
static func _edge() -> Shader:
	if _edge_shader == null:
		outline_material()
		var code := _outline_shader.code
		code = code.replace("render_mode unshaded, cull_front, shadows_disabled;",
			"render_mode unshaded, cull_front, shadows_disabled, depth_test_disabled, depth_draw_never;\nstencil_mode read, compare_not_equal, 2;")
		code = code.replace("\tALBEDO = c;\n}", "\tALBEDO = c;\n\tALPHA = 0.96;\n}")
		_edge_shader = Shader.new()
		_edge_shader.code = code
	return _edge_shader


func _pick_outline_meshes() -> void:
	var sized: Array = []
	for m in _meshes:
		if is_instance_valid(m) and m is MeshInstance3D and (m as MeshInstance3D).mesh and (m as MeshInstance3D).visible:
			var size := (m as MeshInstance3D).mesh.get_aabb().size * _scale_in_model(m)
			if m.has_meta("big"):   # weapons are drawn bigger in a run: rank them at their own size
				size /= maxf((m as MeshInstance3D).scale.x, 1.0)
			sized.append([size.x * size.y + size.y * size.z + size.x * size.z, m])
	sized.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(OUTLINE_PARTS, sized.size()):
		_outline_set[sized[i][1]] = true
	if _outline_set.is_empty():
		_outline_set[null] = true   # nothing to outline: don't look again


## A part's size relative to this character (the parts are scaled inside the model).
func _scale_in_model(n: Node) -> Vector3:
	var k := Vector3.ONE
	while n != null and n != self:
		if n is Node3D:
			k *= (n as Node3D).scale.abs()
		n = n.get_parent()
	return k


## Graphics changed (Settings or the automatic switch): redraw with or without outlines.
func refresh_outline() -> void:
	_set_flash(false)


## The outline pass with `inner` (the tint, rim or flash) drawn after it. Cached per
## visual, so a flash doesn't build a new material every hit.
func _with_outline(inner: Material) -> Material:
	if _outlined.has(inner):
		return _outlined[inner]
	var m := outline_material()
	if team_line and _aura.is_empty():
		m.set_shader_parameter("ink", TEAM_INK)
		m.set_shader_parameter("ink2", TEAM_INK)
		m.set_shader_parameter("width", TEAM_WIDTH)
	if not _aura.is_empty():
		var ink: Color = _aura.ink
		m.set_shader_parameter("ink", ink)
		m.set_shader_parameter("ink2", _aura.get("ink2", ink))
		m.set_shader_parameter("cycle", 1.0 if _aura.get("cycle", false) else 0.0)
		m.set_shader_parameter("shine", 1.0 if _aura.get("shine", false) else 0.0)
		m.set_shader_parameter("width", AURA_WIDTH * aura_boost)
	m.next_pass = inner
	_outlined[inner] = m
	return m


## The mesh drawn again, inside out and pushed out a few pixels along its normals, in dark
## ink: only the rim shows around the model. The push is measured on screen, so near and
## far characters get the same line.
static func outline_material() -> ShaderMaterial:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 ink : source_color = vec4(0.07, 0.035, 0.1, 1.0);
uniform vec4 ink2 : source_color = vec4(0.07, 0.035, 0.1, 1.0);
uniform float cycle = 0.0;
uniform float shine = 0.0;
uniform float width = 0.0026;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 d = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(d);
	if (len > 0.0001) {
		d /= len;
	}
	d.x *= VIEWPORT_SIZE.y / max(VIEWPORT_SIZE.x, 1.0);
	clip.xy += d * width * 2.0 * clip.w;
	POSITION = clip;
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	// A Master aura pulses between its two colours, or runs through gold, green, blue and
	// violet (never red-pink). The plain ink has ink2 the same, so it stays still.
	vec3 c = mix(ink.rgb, ink2.rgb, 0.5 + 0.5 * sin(TIME * 3.0));
	if (cycle > 0.5) {
		c = hsv2rgb(vec3(mix(0.12, 0.78, 0.5 + 0.5 * sin(TIME * 1.6)), 0.7, 1.0));
	}
	// The Crypt King's gold line: white glints sweep across it.
	if (shine > 0.5) {
		float s = pow(max(0.0, sin(dot(FRAGCOORD.xy, vec2(0.011, 0.017)) - TIME * 4.0)), 24.0);
		c = mix(c, vec3(1.0, 0.98, 0.9), s * 0.85);
	}
	ALBEDO = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("ink", OUTLINE_INK)
	m.set_shader_parameter("ink2", OUTLINE_INK)
	m.set_shader_parameter("width", OUTLINE_WIDTH)
	return m


func _placeholder(look: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var h: float = look.height
	var body := U.mat(look.body, 0.8)
	var accent := U.mat(look.accent, 0.6)
	var eyes := U.mat(look.eyes, 0.5, 3.0)

	U.capsule(root, h * 0.19, h * 0.5, body, Vector3(0, h * 0.36, 0))
	U.box(root, Vector3(h * 0.42, h * 0.08, h * 0.36), accent, Vector3(0, h * 0.26, 0))
	var head := U.sphere(root, h * 0.18, body, Vector3(0, h * 0.74, 0))
	U.sphere(root, h * 0.035, eyes, Vector3(-h * 0.07, h * 0.76, -h * 0.15))
	U.sphere(root, h * 0.035, eyes, Vector3(h * 0.07, h * 0.76, -h * 0.15))
	U.capsule(root, h * 0.06, h * 0.32, body, Vector3(-h * 0.25, h * 0.4, 0))
	U.capsule(root, h * 0.06, h * 0.32, body, Vector3(h * 0.25, h * 0.4, 0))
	var steel := U.mat(Color(0.55, 0.57, 0.62), 0.35)
	if look.get("bow", false):
		# A bow held out in front: short segments bent into an arc, plus a string.
		var wood := U.mat(Color(0.45, 0.28, 0.14), 0.7)
		var r := h * 0.24
		var c := Vector3(h * 0.3, h * 0.45, -h * 0.1)
		for i in 5:
			var a := (i - 2) * 0.38
			var seg := U.capsule(root, h * 0.022, h * 0.13, wood, c + Vector3(0, sin(a) * r, -cos(a) * r))
			seg.rotation.x = a
		U.box(root, Vector3(h * 0.008, r * 1.7, h * 0.008), U.unlit(Color(0.9, 0.9, 0.85)), c + Vector3(0, 0, -r * 0.55))
	else:
		var blade_len := 0.6 if look.get("shield", false) else 0.45
		U.box(root, Vector3(h * 0.05, h * 0.05, h * blade_len), steel if look.get("shield", false) else accent, Vector3(h * 0.3, h * 0.38, -h * blade_len * 0.4))
	if look.get("shield", false):
		var shield := U.cylinder(root, h * 0.2, h * 0.05, U.mat(look.accent.lightened(0.15), 0.5), Vector3(-h * 0.3, h * 0.28, -h * 0.12))
		shield.rotation.x = PI / 2
		U.sphere(root, h * 0.045, steel, Vector3(-h * 0.3, h * 0.48, -h * 0.17))
	if look.get("bomb", false):
		# A round black bomb strapped to the back, with a glowing fuse.
		U.sphere(root, h * 0.2, U.mat(Color(0.08, 0.08, 0.1), 0.4), Vector3(0, h * 0.5, h * 0.24))
		U.sphere(root, h * 0.05, U.mat(Color(1.0, 0.6, 0.1), 0.5, 4.0), Vector3(0, h * 0.74, h * 0.26))
	if look.get("helmet", false):
		var helm := U.sphere(root, h * 0.2, steel, Vector3(0, h * 0.78, 0.0))
		helm.scale = Vector3(1, 0.75, 1)
		U.box(root, Vector3(h * 0.04, h * 0.14, h * 0.04), steel, Vector3(0, h * 0.74, -h * 0.18))

	if look.get("hat", false):
		U.cylinder(root, h * 0.22, h * 0.03, accent, Vector3(0, h * 0.88, 0))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = h * 0.13
		cone.height = h * 0.35
		var c := MeshInstance3D.new()
		c.mesh = cone
		c.material_override = accent
		c.position = Vector3(0, h * 1.07, 0)
		root.add_child(c)
	if look.get("hood", false):
		var hood := U.sphere(root, h * 0.21, accent, Vector3(0, h * 0.8, h * 0.04))
		hood.scale = Vector3(1, 0.9, 1)
	if look.get("horns", false):
		for side in [-1.0, 1.0]:
			var horn := U.capsule(head, h * 0.035, h * 0.2, accent, Vector3(side * h * 0.15, h * 0.13, 0))
			horn.rotation.z = -side * 0.6
	if look.get("crown", false):
		var gold := U.mat(Color(1.0, 0.78, 0.25), 0.3, 0.8)
		U.cylinder(root, h * 0.15, h * 0.05, gold, Vector3(0, h * 0.9, 0))
		for i in 5:
			var a := i / 5.0 * TAU
			U.box(root, Vector3.ONE * h * 0.06, gold, Vector3(cos(a) * h * 0.13, h * 0.97, sin(a) * h * 0.13))
	return root


## Version 219 (review 4 fix 31): the bosses' crown, made like the one on the game's icon
## (store/icon-512.png): a gold band that flares out a little, five tall points each with a
## gold ball on top, a red jewel in front and blue ones at the sides, over a dark red cap.
## (It was a flat cylinder with six gold blocks.) `s` is its radius, `y` its height.
static func _boss_crown(att: Node3D, s: float, y: float, tall_k := 1.0) -> void:
	var gold := U.mat(Color(1.0, 0.76, 0.22), 0.25, 0.5)
	var velvet := U.mat(Color(0.45, 0.04, 0.06), 0.9)
	U.sphere(att, s * 0.42, velvet, Vector3(0, y + s * 0.12, 0)).scale = Vector3(1, 0.55, 1)
	U.cone(att, s * 0.5, s * 0.26, gold, Vector3(0, y, 0), s * 0.56)
	for i in 5:
		var a := (i / 5.0) * TAU + PI * 0.5
		var at := Vector3(cos(a) * s * 0.47, y + s * 0.2, sin(a) * s * 0.47)
		var tall := (0.62 if i == 0 else 0.46) * tall_k
		U.cone(att, s * 0.15, s * tall, gold, at)
		U.sphere(att, s * 0.075, gold, at + Vector3.UP * s * (tall + 0.03))
	var red := U.mat(Color(1.0, 0.1, 0.12), 0.2, 0.6)
	var blue := U.mat(Color(0.25, 0.7, 1.0), 0.2, 0.6)
	U.sphere(att, s * 0.09, red, Vector3(0, y + s * 0.13, s * 0.55))
	for side in [-1.0, 1.0]:
		U.sphere(att, s * 0.06, blue, Vector3(side * s * 0.44, y + s * 0.13, s * 0.33))
