class_name SandPharaoh
extends Enemy
## The Sandfall Tomb's own boss (floor 5, version 274; hard review of build 267, fix 11). Until
## then floor 5, the last free floor, ended with the Skeleton King and the Lich together, the
## same two bosses as floors 1 and 2.
##
## A giant mummy king: linen wound round its bones with bands of gold in the wraps, a striped
## headcloth of lapis and gold with a cobra rearing on the brow, a false beard, a broad
## collar and a winged scarab on its chest, a gold crook in its hand and a sun disc floating
## over its head. The colossus heads in the Tomb's halls are its statues. Every attack has
## a warning:
## - Royal Bandages: three strips fan out across the floor, then its own wrappings lash out
##   along them. Caught, you are reeled in to be struck; dash to snap the bandage (the
##   Knight's raised shield turns one away).
## - Sandfall: sand pours from the ceiling on you and round you. Each pour leaves a mound of
##   sand on the floor that slows you while you wade through it, until it sinks again.
## - Scarab Swarm: streams of scarabs pour out of it in turning spokes. Keep to the gaps.
## - Sunbeam (phase 2's own move): the sun over its head burns a beam along the floor that
##   sweeps round the room. Dash through it, or hide behind a pillar.
## - Hourglass (version 300, its encore when it comes back in the endless loops): sand floods
##   the whole floor from the walls inwards, leaving only three gold sun plates clear. Be on
##   one when the flood fills, or the sand swallows you; a dash doesn't help.
## Below half health the sun blazes, two Tomb Mummies climb out of the sand, and it attacks
## faster: more bandages, more sand, more spokes.

const DISPLAY_NAME := "The Sand Pharaoh"
const GOLD := Color(1.0, 0.76, 0.3)
const SUN := Color(1.0, 0.7, 0.25)
const TURQUOISE := Color(0.3, 0.95, 0.85)
const LAPIS := Color(0.1, 0.2, 0.58)
const SAND := Color(0.98, 0.82, 0.5)

## Royal Bandages: the fan, how far and fast they lash, and the leash (as the Tomb Mummy's,
## a little stronger).
const FAN := 0.42
const LASH_LEN := 9.5
const LASH_WIDTH := 1.1
const LASH_SPEED := 19.0
const LASH_AIM := 1.0
const REEL_SPEED := 3.4
const REEL_TIME := 2.8
const GRAB := 2.3
const STRIKE := 20.0
const MAX_LASHES := 5
## Sandfall: each pour's size, and how long it takes to land.
const FALL_R := 1.15
const FALL_TIME := 1.1
## Scarab Swarm.
const SWARM_MAX := 160
const SCARAB_SPEED := 4.2
const SCARAB_R := 0.3
const SCARAB_DAMAGE := 9.0
## Sunbeam.
const BEAM_WIDTH := 1.0
const BEAM_DAMAGE := 13.0
const BEAM_SWEEP := 4.36   # radians (250 degrees)
const BEAM_TURN := 1.05    # radians a second

static var _meshes := {}

var _enraged := false
var _started := false
var _busy := false
var _t := 0.0
var _face_to := Vector3.ZERO   # while it aims, it faces this way
var _sun: Node3D
var _sun_glow: MeshInstance3D
var _rays: MeshInstance3D
var _charge := 0.0             # the sun gathering light for its beam (0 to 1)
var _ribbons: Array[MeshInstance3D] = []
var _knots: Array[MeshInstance3D] = []
var _held := false
var _swarm: MultiMeshInstance3D
var _bugs: Array = []          # each [where, which way, seconds old]
var _beam: Node3D
var _strip: MeshInstance3D
var _shaft: MeshInstance3D
var _beam_mat: ShaderMaterial
var _rim: MeshInstance3D


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_pharaoh"
	# Version 295 (deep review fix 2): 880 made it 2.5 times the floor 4 boss's health, a long
	# slog at the end of the free game. 640 is about 1.8 times.
	init_health(640.0)
	drop_chance = 0.0
	move_speed = 1.3
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_WARRIOR, 4.6, TURQUOISE)
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _royal_wraps()
	look.shape = {"scale": {"chest": Vector3(1.25, 1.05, 1.0), "head": 0.9, "upperarm.l": 1.15, "upperarm.r": 1.15, "upperleg.l": 1.3, "upperleg.r": 1.3}}   # (v350: tall, broad-shouldered)
	look.parts = "pharaoh"
	look.attack_anim = "1H_Melee_Attack_Chop"
	make_visual(look)
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


## Holding the hero on a bandage right now (the test robot dashes to snap it).
func holding() -> bool:
	return _held and not dead


# --- How it looks ----------------------------------------------------------------------------

## The Tomb Mummy's wrappings (see TombMummy._wrapped_bones), wider, with every few strips
## of beaten gold, and fewer torn to the bone: a king's.
static func _royal_wraps() -> ShaderMaterial:
	if _meshes.has("wraps"):
		return _meshes["wraps"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float wind = lp.y * 9.0 + (lp.x * 0.9 - lp.z * 0.55) * 2.4;
	float band = floor(wind);
	float fr = fract(wind);
	float seam = 1.0 - smoothstep(0.0, 0.06, fr) * (1.0 - smoothstep(0.9, 0.98, fr));
	float ang = atan(lp.z, lp.x);
	float torn = step(0.92, hash(vec2(band, floor(ang * 1.6 + band * 0.7))));
	float gold = step(0.78, hash(vec2(band, 3.0)));
	float stain = smoothstep(0.65, 0.98, hash(floor(lp.xz * 6.0) + band * 0.13));
	vec3 linen = vec3(0.93, 0.88, 0.76) * (0.88 + 0.12 * hash(vec2(band, 1.0)));
	linen = mix(linen, vec3(0.62, 0.5, 0.34), stain * 0.35);
	vec3 col = mix(linen, vec3(1.0, 0.72, 0.26), gold);
	col = mix(col, vec3(0.36, 0.27, 0.18), seam * 0.7);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	ALBEDO = col;
	METALLIC = gold * 0.55;
	ROUGHNESS = mix(0.95, 0.35, gold);
	EMISSION = col * 0.12 + vec3(0.55, 0.36, 0.08) * gold * 0.45 + vec3(0.3, 0.95, 0.85) * rim * 0.3;
	ALPHA = (1.0 - torn) * 0.97;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_meshes["wraps"] = m
	return m


static func _mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		match key:
			"gold": _meshes[k] = U.mat(GOLD, 0.3, 0.3)
			"turquoise": _meshes[k] = U.mat(TURQUOISE, 0.35, 0.9)
			"lapis": _meshes[k] = U.mat(LAPIS, 0.4, 0.2)
			"eye": _meshes[k] = U.unlit(Color(0.55, 1.0, 0.92))
			"sun": _meshes[k] = U.mat(Color(1.0, 0.6, 0.18), 0.3, 0.8)
			"core": _meshes[k] = U.mat(Color(1.0, 0.8, 0.42), 0.3, 0.45)
			"shell": _meshes[k] = U.mat(Color(0.07, 0.42, 0.4), 0.3, 0.7)
			"leg": _meshes[k] = U.mat(Color(0.1, 0.08, 0.06), 0.7)
			"glow":
				var g := StandardMaterial3D.new()
				g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				g.billboard_keep_scale = true
				g.albedo_texture = U.soft_circle()
				g.albedo_color = Color(SUN.r, SUN.g, SUN.b, 0.3)
				_meshes[k] = g
			"stripes":
				# Lapis and gold bands, as on a royal headcloth.
				var sh := Shader.new()
				sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float s = step(0.5, fract((lp.y - lp.z * 0.3) * 6.5));
	vec3 lapis = vec3(0.1, 0.2, 0.62);
	vec3 gold = vec3(1.0, 0.76, 0.3);
	ALBEDO = mix(lapis, gold, s);
	METALLIC = s * 0.6;
	ROUGHNESS = mix(0.45, 0.3, s);
	EMISSION = mix(lapis * 0.3, gold * 0.3, s);
}
"""
				var m := ShaderMaterial.new()
				m.shader = sh
				_meshes[k] = m
			"stream":
				# A column of pouring sand: streaks falling down it, thinner at its edges.
				var sh := Shader.new()
				sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float st = fract(UV.y * 9.0 - TIME * 3.5 + sin(UV.x * 31.4) * 0.25);
	float streak = 0.78 + 0.22 * smoothstep(0.2, 0.8, st);
	float edge = abs(dot(NORMAL, VIEW));
	ALBEDO = vec3(0.98, 0.82, 0.5) * streak;
	ALPHA = 0.9 * smoothstep(0.0, 0.5, edge);
}
"""
				var m := ShaderMaterial.new()
				m.shader = sh
				_meshes[k] = m
			"beam":
				# The sunbeam on the floor: a white-gold core in an orange glow, light running
				# out along it.
				var sh := Shader.new()
				sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float len = 8.0;
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.4, x);
	float glow = 1.0 - smoothstep(0.25, 1.0, x);
	float flow = 0.7 + 0.3 * sin(UV.y * len * 2.5 - TIME * 16.0);
	ALBEDO = vec3(1.0, 0.95, 0.75) * core * 1.5 + vec3(1.0, 0.6, 0.16) * glow * flow * 1.2;
}
"""
				var m := ShaderMaterial.new()
				m.shader = sh
				_meshes[k] = m
			"shaft":
				var s := StandardMaterial3D.new()
				s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				s.cull_mode = BaseMaterial3D.CULL_DISABLED
				s.albedo_color = Color(1.0, 0.8, 0.4, 0.75)
				_meshes[k] = s
	return _meshes[k]


## The striped headcloth (head-bone space, +Z the face): a cap over the skull with a gold
## band across the brow, broad flaps falling to the shoulders each side of the face, a tail
## at the back, a gold cobra rearing on the brow, and the long false beard.
static func _nemes_mesh() -> ArrayMesh:
	if _meshes.has("nemes"):
		return _meshes["nemes"]
	var parts := []
	var stripes := _mat("stripes")
	var cap := SphereMesh.new()
	cap.radius = 1.0
	cap.height = 1.0
	cap.is_hemisphere = true
	cap.radial_segments = 20
	cap.rings = 8
	parts.append([cap, Props._xf(Vector3(0, 0.5, -0.04), Vector3(0.52, 0.46, 0.58)), stripes])
	var band := TorusMesh.new()
	band.inner_radius = 0.5
	band.outer_radius = 0.57
	band.rings = 22
	band.ring_segments = 6
	parts.append([band, Props._xf(Vector3(0, 0.52, -0.04), Vector3(1.0, 0.7, 1.02)), _mat("gold")])
	# The flaps, drawn as you see them from the front and stood up, as deep as the skull.
	var stand := Basis(Vector3.RIGHT, -PI * 0.5)
	for sd in [-1.0, 1.0]:
		var flap := [Vector2(0.36, 0.52), Vector2(0.55, 0.52), Vector2(0.74, -0.14), Vector2(0.44, -0.14), Vector2(0.36, 0.2)]
		var pts := []
		for p: Vector2 in flap:
			pts.append(Vector2(p.x * sd, p.y))
		parts.append([Props._poly_slab(pts, -0.12, 0.38), Transform3D(stand, Vector3.ZERO), stripes])
	parts.append(StarEater._rod(Vector3(0, 0.6, -0.52), Vector3(0, 0.0, -0.5), 0.16, 0.08, 8) + [stripes])
	# The cobra on the brow: its body rising from the band, its hood spread, a turquoise eye.
	parts.append(StarEater._rod(Vector3(0, 0.5, 0.56), Vector3(0, 0.74, 0.6), 0.05, 0.035, 6) + [_mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.79, 0.6), Vector3(0.08, 0.1, 0.035)), _mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.8, 0.63), Vector3(0.035, 0.035, 0.02)), _mat("turquoise")])
	# The false beard under the jaw, striped, with a gold tip.
	parts.append(StarEater._rod(Vector3(0, 0.2, 0.34), Vector3(0, -0.16, 0.44), 0.07, 0.055, 6) + [stripes])
	parts.append([Props._sphere(), Props._xf(Vector3(0, -0.18, 0.445), Vector3(0.065, 0.04, 0.065)), _mat("gold")])
	_meshes["nemes"] = Props._bake(parts)
	return _meshes["nemes"]


## The sun disc over its head (facing +Z): a burning disc in a gold rim, rays round it.
static func _sun_mesh() -> ArrayMesh:
	if _meshes.has("sun"):
		return _meshes["sun"]
	var parts := []
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	parts.append([Props._cone(0.42, 0.42, 0.08, 24), Transform3D(face, Vector3.ZERO), _mat("sun")])
	parts.append([Props._cone(0.28, 0.28, 0.1, 20), Transform3D(face, Vector3(0, 0, 0.01)), _mat("core")])
	var rim := TorusMesh.new()
	rim.inner_radius = 0.4
	rim.outer_radius = 0.48
	rim.rings = 24
	rim.ring_segments = 6
	parts.append([rim, Transform3D(face, Vector3.ZERO), _mat("gold")])
	_meshes["sun"] = Props._bake(parts)
	return _meshes["sun"]


## The sun's rays, long and short by turns (they turn round it).
static func _rays_mesh() -> ArrayMesh:
	if _meshes.has("rays"):
		return _meshes["rays"]
	var parts := []
	for i in 12:
		var a := TAU * i / 12.0
		var out := Vector3(cos(a), sin(a), 0.0)
		var tip := 0.82 if i % 2 == 0 else 0.66
		parts.append(StarEater._rod(out * 0.46, out * tip, 0.07, 0.0, 4) + [_mat("gold" if i % 2 == 0 else "sun")])
	_meshes["rays"] = Props._bake(parts)
	return _meshes["rays"]


## The crook (its staff up +Y): banded gold and lapis, the hook curling over to +X.
static func _crook_mesh() -> ArrayMesh:
	if _meshes.has("crook"):
		return _meshes["crook"]
	var parts := []
	parts.append(StarEater._rod(Vector3(0, -0.2, 0), Vector3(0, 0.78, 0), 0.045, 0.045, 8) + [_mat("stripes")])
	var prev := Vector3(0, 0.78, 0)
	for i in range(1, 9):
		var k := float(i) / 8.0 * 1.3
		var p := Vector3(0.14 - 0.14 * cos(k * PI), 0.78 + 0.14 * sin(k * PI), 0)
		parts.append(StarEater._rod(prev, p, 0.048, 0.045, 6) + [_mat("gold")])
		prev = p
	parts.append([Props._sphere(), Props._xf(Vector3(0, -0.2, 0), Vector3.ONE * 0.07), _mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.78, 0), Vector3.ONE * 0.06), _mat("turquoise")])
	_meshes["crook"] = Props._bake(parts)
	return _meshes["crook"]


## The flail (its staff up +Y): a short banded staff, and three strands of gold and lapis beads
## hanging from its top along `down` (the way down once it is laid across the chest).
static func _flail_mesh(down: Vector3) -> ArrayMesh:
	if _meshes.has("flail"):
		return _meshes["flail"]
	var parts := []
	parts.append(StarEater._rod(Vector3(0, -0.2, 0), Vector3(0, 0.6, 0), 0.04, 0.04, 8) + [_mat("stripes")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.62, 0), Vector3.ONE * 0.07), _mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, -0.2, 0), Vector3.ONE * 0.065), _mat("gold")])
	for s in 3:
		var spread := Vector3(0, 0, (s - 1) * 0.07) + Vector3(-down.y, down.x, 0) * (s - 1) * 0.05
		for b in 5:
			var at := Vector3(0, 0.62, 0) + (down * (0.08 + b * 0.075) + spread * (0.4 + b * 0.15))
			parts.append([Props._sphere(), Props._xf(at, Vector3(0.045, 0.045, 0.045) * (1.0 if b % 2 == 0 else 0.8)), _mat("gold" if b % 2 == 0 else "lapis")])
	_meshes["flail"] = Props._bake(parts)
	return _meshes["flail"]


## A scarab of the swarm, its head to -Z: a turquoise shell split by a gold line, six legs.
static func _beetle_mesh() -> ArrayMesh:
	if _meshes.has("beetle"):
		return _meshes["beetle"]
	var parts := []
	var sp := Props._sphere()
	parts.append([sp, Props._xf(Vector3(0, 0.07, 0.03), Vector3(0.13, 0.075, 0.17)), _mat("shell")])
	parts.append([sp, Props._xf(Vector3(0, 0.06, -0.16), Vector3(0.075, 0.05, 0.06)), _mat("leg")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.14, 0.04), Vector3(0.014, 0.02, 0.28)), _mat("gold")])
	for sd in [-1.0, 1.0]:
		for z in [-0.09, 0.02, 0.12]:
			parts.append([Props._cube(), Props._xf(Vector3(sd * 0.15, 0.03, z), Vector3(0.14, 0.018, 0.022), Basis(Vector3.UP, sd * z * 2.2)), _mat("leg")])
		parts.append([Props._cube(), Props._xf(Vector3(sd * 0.04, 0.05, -0.23), Vector3(0.018, 0.018, 0.08), Basis(Vector3.UP, -sd * 0.4)), _mat("leg")])
	_meshes["beetle"] = Props._bake(parts)
	return _meshes["beetle"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var nemes := MeshInstance3D.new()
		nemes.mesh = _nemes_mesh()
		head.add_child(nemes)
		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.mesh = Props._sphere()
			eye.material_override = _mat("eye")
			eye.scale = Vector3.ONE * 0.065
			eye.position = Vector3(sx * 0.14, 0.42, 0.39)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(eye)
		# The sun floats over the headcloth, tipped back to face the camera above the hero.
		_sun = Node3D.new()
		_sun.position = Vector3(0, 1.3, -0.1)
		_sun.scale = Vector3.ONE * 0.72
		_sun.rotation.x = -0.7
		head.add_child(_sun)
		var disc := MeshInstance3D.new()
		disc.mesh = _sun_mesh()
		_sun.add_child(disc)
		_rays = MeshInstance3D.new()
		_rays.mesh = _rays_mesh()
		_sun.add_child(_rays)
		_sun_glow = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.0, 2.0)
		_sun_glow.mesh = q
		_sun_glow.material_override = (_mat("glow") as StandardMaterial3D).duplicate()
		_sun_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sun_glow.position.z = -0.05
		_sun.add_child(_sun_glow)
	if skel and skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var collar := MeshInstance3D.new()
		collar.mesh = TombMummy._collar_mesh()
		collar.position = Vector3(0, 0.3, 0.04)
		collar.rotation.x = 0.42
		collar.scale = Vector3(1.4, 1.0, 1.25)
		chest.add_child(collar)
		var scarab := MeshInstance3D.new()
		scarab.mesh = TombMummy._scarab_mesh()
		scarab.position = Vector3(0, -0.34, 0.36)
		scarab.rotation.x = PI * 0.5 - 0.75
		scarab.scale = Vector3.ONE * 1.5
		chest.add_child(scarab)
		# The crook and the flail crossed on its chest, as a pharaoh lies in his coffin.
		var tilt := 0.62
		var lean := Basis(Vector3.RIGHT, -0.32)
		var cross := Vector3(0, 0.0, 0.62)
		var crook := MeshInstance3D.new()
		crook.mesh = _crook_mesh()
		var cb := lean * Basis(Vector3.BACK, -tilt)
		crook.transform = Transform3D(cb, cross - cb * Vector3(0, 0.22, 0))
		chest.add_child(crook)
		var flail := MeshInstance3D.new()
		flail.mesh = _flail_mesh(Vector3(-sin(tilt), -cos(tilt), 0.0))
		var fb := lean * Basis(Vector3.BACK, tilt)
		flail.transform = Transform3D(fb, cross + Vector3(0, 0, 0.06) - fb * Vector3(0, 0.15, 0))
		chest.add_child(flail)
	if skel and skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		# A scrap of the bandage's own material, too small to see, so its shader is ready
		# (warm-up) before the first lash.
		var scrap := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(0.02, 0.02)
		scrap.mesh = sq
		scrap.material_override = TombMummy._mat("rope")
		scrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(scrap)
	# Its bandages, drawn in the room's space each frame, a knot at each loose end.
	for i in MAX_LASHES:
		var r := MeshInstance3D.new()
		r.mesh = ImmediateMesh.new()
		r.top_level = true
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.extra_cull_margin = 16.0
		add_child(r)
		_ribbons.append(r)
		var k := MeshInstance3D.new()
		k.mesh = Props._sphere()
		k.material_override = TombMummy._mat("linen")
		k.scale = Vector3(0.26, 0.18, 0.26)
		k.top_level = true
		k.visible = false
		add_child(k)
		_knots.append(k)
	# The scarab swarm: one mesh drawn many times.
	_swarm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _beetle_mesh()
	mm.instance_count = SWARM_MAX
	mm.visible_instance_count = 0
	_swarm.multimesh = mm
	_swarm.top_level = true
	_swarm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swarm.custom_aabb = AABB(Vector3(-9, -1, -13), Vector3(18, 4, 26))
	add_child(_swarm)
	# The sunbeam: a strip of light on the floor, and a shaft down to it from the sun.
	_beam = Node3D.new()
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	_strip = MeshInstance3D.new()
	var sq2 := QuadMesh.new()
	sq2.orientation = PlaneMesh.FACE_Y
	sq2.size = Vector2(BEAM_WIDTH * 1.4, 1.0)
	sq2.center_offset = Vector3(0, 0, -0.5)
	_strip.mesh = sq2
	_beam_mat = (_mat("beam") as ShaderMaterial).duplicate()
	_strip.material_override = _beam_mat
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strip.position.y = 0.07
	_beam.add_child(_strip)
	_rim = ShotLook.beam_rim(_beam, BEAM_WIDTH * 2.0, 1.0, Vector3(0, 0.05, 0))   # v402: the enemy rim
	_shaft = MeshInstance3D.new()
	_shaft.mesh = Props._cone(0.14, 0.3, 1.0, 10)
	_shaft.material_override = _mat("shaft")
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shaft.top_level = true
	_shaft.visible = false
	add_child(_shaft)


## For the shader warm-up (warmup.gd): a pour of sand, a sunbeam and a scarab, still.
static func warm(parent: Node3D, at: Vector3) -> void:
	var s := MeshInstance3D.new()
	s.mesh = Props._cone(1.0, 1.0, 1.0, 10)
	s.material_override = _mat("stream")
	parent.add_child(s)
	s.position = at + Vector3(0, 0.5, 0)
	s.scale = Vector3(0.2, 1.0, 0.2)
	var b := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(0.8, 0.8)
	b.mesh = q
	b.material_override = (_mat("beam") as ShaderMaterial).duplicate()
	parent.add_child(b)
	b.position = at + Vector3(0.8, 0.05, 0)
	var sh := MeshInstance3D.new()
	sh.mesh = Props._cone(0.1, 0.1, 0.6, 8)
	sh.material_override = _mat("shaft")
	parent.add_child(sh)
	sh.position = at + Vector3(-0.8, 0.3, 0)
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _beetle_mesh()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	mmi.multimesh = mm
	parent.add_child(mmi)
	mmi.position = at + Vector3(0, 0, 0.8)


## Phase 2: the sun blazes, bigger and white-hot.
func _blaze() -> void:
	if _sun:
		_sun.create_tween().tween_property(_sun, "scale", Vector3.ONE * 1.35, 0.3)
	if _sun_glow:
		(_sun_glow.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.5, 0.7)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	_t += delta
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Sfx.play("sandfall", 0.7, 0.8)
		Game.shake(0.5)
		_brain()
	if _rays:
		_rays.rotation.z += delta * (0.9 if _enraged else 0.45) * (4.0 if _charge > 0.0 else 1.0)
	if _sun_glow:
		var k := (1.0 + 0.08 * sin(_t * 2.6)) * (1.0 + _charge * 0.8)
		_sun_glow.scale = Vector3.ONE * k
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.25
		phase_two(SUN, "sunbeam", "Sunbeam")
		_blaze()
		_raise_mummies()
	if randf() < delta * 3.0:
		# Sand trickles out of its wrappings.
		Fx.magic(center() + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 1.2), randf_range(-0.8, 0.8)), SAND if randf() < 0.7 else SUN, 2)
	if _busy:
		stand(delta)
		if _face_to != Vector3.ZERO:
			face(_face_to, 12.0, delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 4.5:
		walk(to, delta)
	else:
		stand(delta)
		face(to, 6.0, delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	encore_first()
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["bandages", "sandfall", "scarabs", "sandfall"]
		if _enraged:
			moves.append("sunbeam")   # phase 2's own move
		if returning():
			moves.append("encore")   # Hourglass (version 300)
		match next_move(moves):
			"bandages": await _bandages()
			"sandfall": await _sandfall()
			"scarabs": await _scarabs()
			"sunbeam": await _sunbeam()
			"encore": await _hourglass()
		_busy = false
		_face_to = Vector3.ZERO
		await _wait(1.0 if _enraged else 1.5)


func _room() -> Node:
	return Room.current if is_instance_valid(Room.current) else get_parent()


func _in_room(p: Vector3, r := 0.6) -> Vector3:
	p.x = clampf(p.x, -Room.HALF_W + r + 0.4, Room.HALF_W - r - 0.4)
	p.z = clampf(p.z, -Room.HALF_L + r + 0.4, Room.HALF_L - r - 0.4)
	p.y = 0.0
	return Room.current.resolve_move(p, Vector3.ZERO, r) if is_instance_valid(Room.current) else p


func _cast() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)


# Royal Bandages --------------------------------------------------------------------------------

## Strips fan out on the floor at the hero, then its wrappings lash out along them. One that
## catches the hero holds on and reels them in; a dash snaps it.
func _bandages() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var base := to.normalized() if to.length() > 0.1 else Vector3.BACK
	var n := 5 if _enraged else 3
	var fan := 0.34 if _enraged else FAN
	var dirs: Array[Vector3] = []
	for i in n:
		dirs.append(base.rotated(Vector3.UP, (i - (n - 1) * 0.5) * fan))
	_face_to = base
	_cast()
	Sfx.play("lash", 0.6, 0.75)
	for i in n:
		track(Telegraph.line(global_position, dirs[i], LASH_LEN, LASH_WIDTH, LASH_AIM, Callable(), 0.6 if i == 0 else 0.0))
	await _wait(LASH_AIM)
	if not _alive():
		return
	if not visual.play_named("1H_Ranged_Shoot"):
		visual.attack(true)
	Sfx.play("lash", 0.85, 0.8)
	var reach: Array[float] = []
	var back: Array[bool] = []
	for i in n:
		reach.append(0.6)
		back.append(false)
	var caught := -1
	var leash := 0.0
	var hold := 0.0
	var source := kind_name()
	while _alive():
		if not is_instance_valid(hero):
			hero = null
		var dt := get_process_delta_time()
		var from := global_position + Vector3.UP * 1.4
		var any := false
		for i in n:
			if i == caught or reach[i] <= 0.0:
				continue
			any = true
			var d := dirs[i]
			if back[i]:
				reach[i] -= LASH_SPEED * 1.5 * dt
				if reach[i] <= 0.6:
					reach[i] = 0.0
					_clear_ribbon(i)
					continue
			else:
				var was := reach[i]
				reach[i] = minf(reach[i] + LASH_SPEED * dt, LASH_LEN)
				var end := from + d * reach[i]
				if reach[i] >= LASH_LEN or (is_instance_valid(Room.current) and Room.current.blocks_shot(end, 0.15)):
					back[i] = true
				elif caught < 0 and hero and not hero.dead:
					var h := hero.global_position
					var rel := Vector3(h.x - from.x, 0.0, h.z - from.z)
					var along := rel.dot(d)
					var across := (rel - d * along).length()
					if along > was - hero.radius and along < reach[i] + hero.radius and across < LASH_WIDTH * 0.5 + hero.radius * 0.6:
						if hero.blocks_shot(d):
							hero.on_block(end)
							back[i] = true
						elif hero.can_be_hit():
							caught = i
							_held = true
							_knots[i].visible = false
							var gap := hero.global_position - global_position
							gap.y = 0.0
							leash = maxf(gap.length(), GRAB)
							hold = REEL_TIME
							Game.hit_source = source
							hero.take_damage(6.0, d, 0.0)
							Fx.magic(hero.global_position + Vector3.UP * 0.9, TURQUOISE, 14)
							Sfx.play("lash", 0.7, 0.65)
							if Time.get_ticks_msec() - TombMummy._said > 3000:
								TombMummy._said = Time.get_ticks_msec()
								Game.hud.callout("CAUGHT! DASH TO SNAP IT!", TURQUOISE, true)
							continue
			var tip := from + d * reach[i]
			tip.y = lerpf(from.y, 0.8, minf(reach[i] / 3.0, 1.0))
			TombMummy.ribbon(_ribbons[i].mesh as ImmediateMesh, _lash_root(i, n), tip, 0.3, _t + i, 0.2)
			_knots[i].visible = true
			_knots[i].global_position = tip
			_knots[i].rotation.y += dt * 9.0
		if caught >= 0:
			any = true
			if hero == null or hero.dead or Game.state != Game.State.PLAYING:
				_let_go(caught)
				caught = -1
			elif hero.is_dashing():
				_snap(hero, caught, n)
				caught = -1
			else:
				hold -= dt
				leash = maxf(GRAB, leash - REEL_SPEED * dt)
				var gap := hero.global_position - global_position
				gap.y = 0.0
				var dist := gap.length()
				if dist > leash and dist > 0.01:
					var step := -gap / dist * (dist - leash)
					hero.global_position = Room.current.resolve_move(hero.global_position, step, hero.radius) if is_instance_valid(Room.current) else hero.global_position + step
					dist = leash
				_face_to = gap
				if dist <= GRAB + 0.1:
					_strike(hero, gap, source)
					_let_go(caught)
					caught = -1
				elif hold <= 0.0:
					_let_go(caught)
					caught = -1
				else:
					TombMummy.ribbon(_ribbons[caught].mesh as ImmediateMesh, _lash_root(caught, n), hero.global_position + Vector3.UP * 0.8, 0.05, _t, 0.2)
		if not any:
			break
		await frame()
	for i in MAX_LASHES:
		_clear_ribbon(i)
	_held = false
	await _wait(0.3)


## Where lash `i` of `n` unwinds from: across its chest.
func _lash_root(i: int, n: int) -> Vector3:
	var side := global_transform.basis.x
	return center() + Vector3.UP * 0.3 + side * (i - (n - 1) * 0.5) * 0.32


func _clear_ribbon(i: int) -> void:
	if i >= 0 and i < _ribbons.size():
		(_ribbons[i].mesh as ImmediateMesh).clear_surfaces()
		_knots[i].visible = false


func _let_go(i: int) -> void:
	_held = false
	_clear_ribbon(i)


## Reeled in close: it strikes with its crook.
func _strike(hero: Hero, gap: Vector3, source: String) -> void:
	face(gap, 40.0, 0.1)
	visual.attack(true)
	Game.hit_source = source
	hero.take_damage(STRIKE, gap.normalized() if gap.length() > 0.01 else Vector3.BACK, 9.0)
	Game.shake(0.25)
	Sfx.play("lash", 0.6, 0.55)
	Fx.impact(hero.global_position + Vector3.UP * 0.8, GOLD, 1.0)


## The hero dashed: the bandage tears, and the Pharaoh reels back a moment.
func _snap(hero: Hero, i: int, n: int) -> void:
	var mid := (_lash_root(i, n) + hero.global_position + Vector3.UP * 0.8) * 0.5
	Fx.impact(mid, TURQUOISE, 1.0)
	Fx.magic(mid, Color(0.86, 0.82, 0.7), 26)
	Fx.magic(mid, TURQUOISE, 12)
	Sfx.play("snap", 0.9, randf_range(0.86, 0.94))
	_let_go(i)
	_flinch_left = maxf(_flinch_left, 1.0)
	if not visual.play_named("Hit_A"):
		visual.attack(false)
	Game._teach("mummy_snap", "SNAPPED! A dash tears a mummy's bandage.")


# Sandfall --------------------------------------------------------------------------------------

## Sand pours from the ceiling on the hero and round them, each pour leaving a mound.
func _sandfall() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.45, 1.15)
	var n := 8 if _enraged else 6
	var c := hero.global_position
	var start := randf() * TAU
	var spots: Array[Vector3] = [_in_room(c, FALL_R)]
	for i in n - 1:
		var a := start + TAU * i / (n - 1) + randf_range(-0.25, 0.25)
		var r := randf_range(2.6, 3.4)
		spots.append(_in_room(c + Vector3(cos(a) * r, 0.0, sin(a) * r), FALL_R))
	var source := kind_name()
	for p in spots:
		if not _alive():
			return
		_pour(p, FALL_TIME)
		track(Telegraph.circle(p, FALL_R, FALL_TIME, _land.bind(p, source)))
		await _wait(0.16)
	await _wait(FALL_TIME + 0.2)


## A column of sand pours from high up onto `spot`, thickening until it lands.
func _pour(spot: Vector3, seconds: float) -> void:
	var s := MeshInstance3D.new()
	s.mesh = _stream_mesh()
	s.material_override = _mat("stream")
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room().add_child(s)
	s.global_position = spot + Vector3.UP * 4.5
	s.scale = Vector3(0.05, 1.0, 0.05)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3(0.3, 1.0, 0.3), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "scale", Vector3(0.62, 1.0, 0.62), 0.08)
	tw.tween_property(s, "scale", Vector3(0.0, 1.0, 0.0), 0.4)
	tw.tween_callback(s.queue_free)


static func _stream_mesh() -> CylinderMesh:
	if not _meshes.has("stream"):
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 9.0
		c.radial_segments = 10
		c.rings = 1
		c.cap_top = false
		c.cap_bottom = false
		_meshes["stream"] = c
	return _meshes["stream"]


func _land(spot: Vector3, source: String) -> void:
	Fx._burst(spot + Vector3.UP * 0.3, 22, Color(0.95, 0.8, 0.5, 0.75), 0.5, 3.2, 0.7, 6.0)
	Fx.dust(spot, 14)
	Sfx.play("sandfall", 0.5, randf_range(0.92, 1.08))
	Game.shake(0.08)
	SandMound.spawn(spot, FALL_R)
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - spot
	d.y = 0.0
	if d.length() < FALL_R + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(14.0, d, 6.0)


# Scarab Swarm ----------------------------------------------------------------------------------

## Streams of scarabs pour out of it along turning spokes; the hero starts in a gap.
func _scarabs() -> void:
	var here := global_position
	var spokes := 5 if _enraged else 4
	var way := 1.0 if randf() < 0.5 else -1.0
	var start := randf() * TAU
	if Game.hero:
		var to := Game.hero.global_position - here
		start = atan2(to.z, to.x) + PI / spokes
	_cast()
	Sfx.play("scarab", 0.8)
	for i in spokes:
		var a := start + TAU * i / spokes
		track(Telegraph.line(here, Vector3(cos(a), 0.0, sin(a)), 5.0, 0.8, 0.9, Callable(), 0.5 if i == 0 else 0.0))
	await _wait(0.9)
	var turn := (0.42 if _enraged else 0.34) * way
	var dur := 3.4
	var t := 0.0
	var emit := 0.0
	var skitter := 0.0
	var source := kind_name()
	while _alive() and (t < dur or not _bugs.is_empty()):
		var dt := get_process_delta_time()
		t += dt
		if t < dur:
			emit -= dt
			if emit <= 0.0:
				emit = 0.1
				var ang := start + turn * t
				for i in spokes:
					if _bugs.size() >= SWARM_MAX:
						break
					var a := ang + TAU * i / spokes
					var d := Vector3(cos(a), 0.0, sin(a))
					_bugs.append([here + d * 1.1, d, 0.0])
		skitter -= dt
		if skitter <= 0.0 and t < dur:
			skitter = 0.5
			Sfx.play("scarab", 0.35, randf_range(0.9, 1.15))
		_move_bugs(dt, source)
		await frame()
	_bugs.clear()
	_draw_bugs()
	await _wait(0.3)


func _move_bugs(dt: float, source: String) -> void:
	var room := Room.current
	var h := Game.hero
	var keep: Array = []
	for b: Array in _bugs:
		var d: Vector3 = b[1]
		var p: Vector3 = b[0] + d * SCARAB_SPEED * dt
		b[0] = p
		b[2] = float(b[2]) + dt
		if is_instance_valid(room) and room.blocks_shot(p, 0.12):
			continue
		if h and h.can_be_hit():
			var off := h.global_position - p
			off.y = 0.0
			if off.length() < SCARAB_R + h.radius * 0.6:
				Game.hit_source = source
				h.take_damage(SCARAB_DAMAGE, d, 5.0)
				Fx.magic(p + Vector3.UP * 0.2, TURQUOISE, 4)
				continue
		keep.append(b)
	_bugs = keep
	_draw_bugs()


func _draw_bugs() -> void:
	if _swarm == null:
		return
	_swarm.global_transform = Transform3D.IDENTITY
	var mm := _swarm.multimesh
	var n := mini(_bugs.size(), SWARM_MAX)
	for i in n:
		var b: Array = _bugs[i]
		var d: Vector3 = b[1]
		var age: float = b[2]
		var basis := Basis.looking_at(d, Vector3.UP).rotated(Vector3.UP, sin(age * 26.0 + i) * 0.3)
		var s := minf(age / 0.15, 1.0) * 1.8
		var p: Vector3 = b[0]
		p.y = 0.04 + absf(sin(age * 18.0 + i)) * 0.04
		mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * s), p))
	mm.visible_instance_count = n


# Sunbeam ---------------------------------------------------------------------------------------

## Phase 2's own move: the sun burns a beam along the floor that sweeps round the room. Cover
## stops it; a dash goes through it.
func _sunbeam() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var way := 1.0 if randf() < 0.5 else -1.0
	var a := atan2(to.z, to.x) - way * 0.9
	var d := Vector3(cos(a), 0.0, sin(a))
	_face_to = d
	_cast()
	Sfx.play(roar_sound, 0.55, 1.2)
	Sfx.play("shimmer", 0.8, 0.6)
	track(Telegraph.line(global_position, d, _beam_length(global_position, d), BEAM_WIDTH, 1.2, Callable()))
	var t := 0.0
	while t < 1.2 and _alive():
		t += get_process_delta_time()
		_charge = t / 1.2
		await frame()
	if not _alive():
		_charge = 0.0
		return
	Sfx.play("beam", 0.8, 0.8)
	_beam.visible = true
	_shaft.visible = true
	var gone := 0.0
	var cool := 0.0
	var spark := 0.0
	var hum := 0.0
	var source := kind_name()
	while _alive() and gone < BEAM_SWEEP:
		var dt := get_process_delta_time()
		var step := BEAM_TURN * dt
		a += way * step
		gone += step
		d = Vector3(cos(a), 0.0, sin(a))
		_face_to = d
		var here := global_position
		var length := _beam_length(here, d)
		_beam_at(here, d, length)
		cool -= dt
		var h := Game.hero
		if cool <= 0.0 and h and h.can_be_hit() and Enemy.in_strip(h.global_position, here, d, length, BEAM_WIDTH, h.radius * 0.6):
			cool = 0.6
			Game.hit_source = source
			h.take_damage(BEAM_DAMAGE, d.cross(Vector3.UP) * -way, 6.0)
			Fx.impact(h.global_position + Vector3.UP * 0.8, SUN, 0.9)
		spark -= dt
		if spark <= 0.0:
			spark = 0.07
			Fx.magic(here + d * length + Vector3.UP * 0.3, SUN, 3)
		hum -= dt
		if hum <= 0.0:
			hum = 0.9
			Sfx.play("beam", 0.35, randf_range(0.75, 0.85))
		await frame()
	_beam_off()
	await _wait(0.5)


## How far the beam reaches along `d` before a wall or a pillar stops it.
func _beam_length(here: Vector3, d: Vector3) -> float:
	var length := 1.2
	while length < 24.0:
		var p := here + d * (length + 0.3)
		if is_instance_valid(Room.current) and Room.current.blocks_shot(p, 0.1):
			break
		length += 0.3
	return length


func _beam_at(here: Vector3, d: Vector3, length: float) -> void:
	_beam.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), Vector3(here.x, 0.0, here.z))
	_strip.scale = Vector3(1.0, 1.0, length)
	_rim.scale.z = length
	_rim.position.z = -length * 0.5
	_beam_mat.set_shader_parameter("len", length)
	if _sun:
		var top := _sun.global_position
		var foot := Vector3(here.x, 0.1, here.z) + d * 1.6
		var axis := foot - top
		var basis := Basis(Quaternion(Vector3.DOWN, axis.normalized())) if axis.normalized().cross(Vector3.DOWN).length() > 0.001 else Basis.IDENTITY
		_shaft.global_transform = Transform3D(basis.scaled(Vector3(1.0, axis.length(), 1.0)), (top + foot) * 0.5)


func _beam_off() -> void:
	_charge = 0.0
	if _beam:
		_beam.visible = false
	if _shaft:
		_shaft.visible = false


# Hourglass -------------------------------------------------------------------------------------

const GLASS_FILL := 3.0      # seconds for the sand to reach the middle
const GLASS_FILL_MAD := 2.5
const PLATE_R := 1.15
const GLASS_DAMAGE := 22.0
var _flood: MeshInstance3D
var _plates: Array[Node3D] = []

## Sand floods the floor from the walls inwards; only three gold sun plates stay clear.
func _hourglass() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.5, 0.9)
	Sfx.play("sandfall", 0.8, 0.75)
	Game.shake(0.3)
	# Three plates within reach of the hero (one near, two further), clear of the boss.
	var spots: Array[Vector3] = []
	var start := randf() * TAU
	for i in 3:
		var best := Vector3.ZERO
		for tries in 12:
			var a := start + TAU * i / 3.0 + randf_range(-0.5, 0.5)
			var r := randf_range(2.0, 3.0) if i == 0 else randf_range(3.2, 4.6)
			var p := _in_room(hero.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r), PLATE_R + 0.3)
			var ok := p.distance_to(global_position) > 2.6
			for q in spots:
				ok = ok and p.distance_to(q) > PLATE_R * 2.6
			best = p
			if ok:
				break
		spots.append(best)
	for p in spots:
		_plates.append(_sun_plate(p))
	var fill := GLASS_FILL_MAD if _enraged else GLASS_FILL
	_flood = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Room.HALF_W * 2.0, Room.HALF_L * 2.0)
	_flood.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = _flood_shader()
	mat.render_priority = 2
	var arr := PackedVector3Array()
	for p in spots:
		arr.append(Vector3(p.x, p.z, PLATE_R))
	mat.set_shader_parameter("spots", arr)
	mat.set_shader_parameter("half_size", Vector2(Room.HALF_W, Room.HALF_L))
	mat.set_shader_parameter("fill", 0.0)
	_flood.material_override = mat
	_flood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room().add_child(_flood)
	_flood.global_position = Vector3(0, 0.05, 0)
	Game.hud.callout("GET ON A SUN PLATE!", GOLD)
	var t := 0.0
	while t < fill:
		if not _alive():
			_end_glass()
			return
		var dt := get_process_delta_time()
		t += dt
		mat.set_shader_parameter("fill", t / fill)
		if randf() < dt * 8.0:
			Sfx.play("sandfall", 0.25, randf_range(0.8, 1.1))
		await get_tree().process_frame
	# Full: whoever is not on a plate is swallowed.
	Game.shake(0.35)
	Sfx.play("sandfall", 0.9, 0.6)
	if hero and not hero.dead:
		var safe := false
		for p in spots:
			var d := hero.global_position - p
			d.y = 0.0
			safe = safe or d.length() < PLATE_R + hero.radius * 0.4
		if safe:
			Fx.magic(hero.center(), GOLD, 18)
		else:
			Game.hit_source = kind_name()
			hero.take_damage(GLASS_DAMAGE, Vector3.ZERO, 0.0)
			Fx._burst(hero.global_position + Vector3.UP * 0.4, 26, Color(0.95, 0.8, 0.5, 0.8), 0.5, 3.0, 0.8, 5.0)
	for a: Actor in Actor.all:
		if a is Enemy and not (a as Enemy).is_boss and not a.dead:
			Fx.dust(a.global_position, 6)
	await _wait(0.5)
	_end_glass()


## The sand sinks away and the plates go out.
func _end_glass() -> void:
	if is_instance_valid(_flood):
		var mat := _flood.material_override as ShaderMaterial
		var f := _flood
		var tw := f.create_tween()
		tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.5)
		tw.tween_callback(f.queue_free)
	_flood = null
	for p in _plates:
		if is_instance_valid(p):
			var tw := p.create_tween()
			tw.tween_property(p, "scale", Vector3(0.01, 1.0, 0.01), 0.35)
			tw.tween_callback(p.queue_free)
	_plates.clear()


## A gold disc with a sun on it, raised a hair off the floor, and a ring of light around it.
func _sun_plate(at: Vector3) -> Node3D:
	var n := Node3D.new()
	_room().add_child(n)
	n.global_position = at + Vector3.UP * 0.07
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = PLATE_R
	c.bottom_radius = PLATE_R * 1.04
	c.height = 0.12
	c.radial_segments = 28
	disc.mesh = c
	disc.material_override = _mat("gold")
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(disc)
	# A white-hot sun in the middle and eight rays round it, all inside the plate.
	var sun := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = PLATE_R * 0.34
	sc.bottom_radius = PLATE_R * 0.34
	sc.height = 0.04
	sc.radial_segments = 20
	sun.mesh = sc
	sun.material_override = U.unlit(Color(1.0, 0.95, 0.7))
	sun.position.y = 0.08
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sun)
	var rays := Node3D.new()
	rays.position.y = 0.08
	n.add_child(rays)
	for k in 8:
		var ray := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, 0.03, PLATE_R * 0.42)
		ray.mesh = b
		ray.material_override = U.unlit(Color(1.0, 0.62, 0.15))
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * k / 8.0
		ray.position = Vector3(sin(a), 0.0, cos(a)) * PLATE_R * 0.62
		ray.rotation.y = a
		rays.add_child(ray)
	rays.create_tween().set_loops().tween_property(rays, "rotation:y", TAU, 4.0).from(0.0)
	n.scale = Vector3(0.01, 1.0, 0.01)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.magic(at + Vector3.UP * 0.4, GOLD, 14)
	return n


static func _flood_shader() -> Shader:
	if not _meshes.has("flood"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 spots[3];
uniform vec2 half_size;
uniform float fill = 0.0;
uniform float fade = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float edge = min(half_size.x - abs(wp.x), half_size.y - abs(wp.z));
	float front = fill * half_size.x * 1.15;
	float sand = 1.0 - smoothstep(front - 0.5, front, edge);
	float m = 100.0;
	for (int i = 0; i < 3; i++) { m = min(m, distance(wp.xz, spots[i].xy) - spots[i].z); }
	sand *= smoothstep(0.0, 0.2, m);
	float ripple = 0.5 + 0.5 * sin(edge * 5.0 - TIME * 4.0 + sin(wp.x * 1.7 + wp.z * 0.9) * 1.5);
	vec3 col = mix(vec3(0.62, 0.45, 0.22), vec3(0.98, 0.82, 0.5), ripple * 0.7 + 0.15);
	float lip = (1.0 - smoothstep(0.0, 0.35, abs(edge - front))) * step(0.02, fill);
	col = mix(col, vec3(1.0, 0.93, 0.7), lip * 0.8);
	float rim = (1.0 - smoothstep(0.0, 0.16, abs(m))) * (0.55 + 0.45 * sin(TIME * 8.0));
	col = mix(col, vec3(1.0, 0.78, 0.3), rim);
	ALBEDO = col;
	ALPHA = max(sand * 0.88, rim * 0.9 * step(0.01, fill)) * fade;
}
"""
		_meshes["flood"] = sh
	return _meshes["flood"]


# Phase 2 ---------------------------------------------------------------------------------------

## Two Tomb Mummies climb out of the sand beside it (after its roar).
func _raise_mummies() -> void:
	await _wait(1.0)
	for i in 2:
		if not _alive() or Game.alive_enemies >= 6:
			return
		var side := global_transform.basis.x * (3.0 if i == 0 else -3.0)
		var spot := _in_room(global_position + side, 0.5)
		Fx.dust(spot, 20)
		Fx._burst(spot + Vector3.UP * 0.3, 18, Color(0.95, 0.8, 0.5, 0.75), 0.5, 2.6, 0.7, 5.0)
		Sfx.play("sandfall", 0.45, 1.2)
		Game.spawn_enemy("y", spot)
		await _wait(0.3)


func _clear_all() -> void:
	for i in _ribbons.size():
		_clear_ribbon(i)
	_held = false
	_bugs.clear()
	if _swarm:
		_swarm.multimesh.visible_instance_count = 0
	_beam_off()
	_end_glass()


func _exit_tree() -> void:
	_clear_all()
	super._exit_tree()


func _on_death() -> void:
	_clear_all()
	Sfx.play(roar_sound, 0.8, 0.85)
	Sfx.play("sandfall", 0.9, 0.7)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _sun:
		var tw := _sun.create_tween()
		tw.tween_property(_sun, "scale", Vector3.ONE * 1.9, 0.25)
		tw.tween_property(_sun, "scale", Vector3.ZERO, 0.4)
	Fx._burst(center(), 50, Color(0.95, 0.8, 0.5, 0.8), 0.6, 4.5, 1.0, 5.0)
	Fx.magic(center(), GOLD, 40)
	Fx.shockwave(global_position, SUN, 5.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
