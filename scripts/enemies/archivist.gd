class_name Archivist
extends Enemy
## The Whispering Library's own boss (floor 8, version 276; hard review of build 267, fix 11).
## Until then the Library ended with the Lich, the boss of floor 2, back again.
##
## The keeper of the forbidden books: a tall skeleton scholar in a square scholar's cap with a
## gold tassel, great round spectacles glowing with the whispering, an ink-blue stole down its
## front, a padlocked tome swinging from its fist on a chain, and wings of loose pages fanned
## out from its back, more pages circling it. It reads, and what it reads comes true. Every
## attack has a warning:
## - Burning Words: it speaks a word, and the word writes itself across the floor where you
##   stand, stroke by stroke, in letters taller than you; then the letters burn. Step into a
##   gap inside a letter or between two, or out of the word.
## - Retelling: it reads your story back. The steps you took in the last few seconds glow as
##   inky footprints, then burst one after another, oldest first, chasing you along the way
##   you came. Keep going: don't turn back over your own path, and don't stand still.
## - Bookstorm: books burst out of the shelves on the walls and flap across the room at you,
##   one after another from every side. Sidestep each strip, or keep a pillar between.
## - Mirror Page (phase 2's own move): it tears a page out of its tome, and your ink double
##   climbs out of it on the far side of the room (InkDouble). It copies your every step as
##   in a mirror and hurts to touch, so keep off the middle of the room, and when you stand
##   still to fight it throws ink back at you. Break it, or it dries up after a while.
## - Turning Page (version 302, its encore in the endless loops): the floor becomes an open
##   book. A giant page lifts from the far half of the room and turns over onto the half you
##   stand on, slamming down. Cross the spine to the side it lifts from; below half health it
##   turns back again straight after.
## Below half health its pages blaze, two Hush Keepers step out of the stacks, and it reads
## harder: "THE END" in two lines, a longer story, more books.

const DISPLAY_NAME := "The Archivist"
const TEAL := Color(0.35, 1.0, 0.82)
const PALE := Color(0.78, 1.0, 0.92)
const INK := Color(0.07, 0.09, 0.18)
const GOLD := Color(0.88, 0.67, 0.27)

## Burning Words: the size of its letters (metres), how thick their strokes, how long the
## last stroke's warning lasts and how quickly it writes them.
const LETTER_W := 1.5
const LETTER_H := 2.7
const LETTER_GAP := 0.55
const LINE_GAP := 0.9
const STROKE := 0.5
const WORD_TIME := 1.2
const WORD_WRITE := 0.035
const WORD_DAMAGE := 16.0
const WORDS := ["SHH", "OUT", "HUSH"]
const ANGRY_WORDS := ["SHH", "HUSH", "THE END"]
## Each letter as strokes across a box 1 wide and 1 high, (0, 0) its bottom left.
const GLYPHS := {
	"H": [[0, 0, 0, 1], [1, 0, 1, 1], [0, 0.5, 1, 0.5]],
	"U": [[0, 1, 0, 0], [0, 0, 1, 0], [1, 0, 1, 1]],
	"S": [[1, 1, 0, 1], [0, 1, 0, 0.5], [0, 0.5, 1, 0.5], [1, 0.5, 1, 0], [1, 0, 0, 0]],
	"O": [[0, 0, 0, 1], [0, 1, 1, 1], [1, 1, 1, 0], [1, 0, 0, 0]],
	"T": [[0, 1, 1, 1], [0.5, 1, 0.5, 0]],
	"E": [[0, 0, 0, 1], [0, 1, 1, 1], [0, 0.5, 0.75, 0.5], [0, 0, 1, 0]],
	"N": [[0, 0, 0, 1], [0, 1, 1, 0], [1, 0, 1, 1]],
	"D": [[0, 0, 0, 1], [0, 1, 0.6, 1], [0.6, 1, 1, 0.72], [1, 0.72, 1, 0.28], [1, 0.28, 0.6, 0], [0.6, 0, 0, 0]],
}

## Retelling: how far back it reads, how far apart the footprints are, how long before the
## oldest bursts and between one and the next (0.75 m every 0.14 s: about the hero's walk).
const RETELL_SPAN := 2.8
const RETELL_STEP := 0.75
const RETELL_R := 0.72
const RETELL_LEAD := 0.95
const RETELL_GAP := 0.14
const RETELL_MAX := 16
const RETELL_DAMAGE := 14.0

## Bookstorm: each book's warning, the gap before the next, how fast it flies, its strip.
const BOOK_AIM := 0.85
const BOOK_GAP := 0.32
const BOOK_SPEED := 13.0
const BOOK_WIDTH := 1.0
const BOOK_HALF_W := 0.5
const BOOK_HALF_L := 0.35
const BOOK_DAMAGE := 14.0
const BOOK_SCALE := 2.3

## Mirror Page: the warning where the double climbs out.
const MIRROR_WARN := 0.8

static var _meshes := {}

var _enraged := false
var _started := false
var _busy := false
var _t := 0.0
var _face_to := Vector3.ZERO
var _wing_l: Node3D
var _wing_r: Node3D
var _wings: Node3D
var _specs: Node3D
var _cap: Node3D
var _tome: Node3D
var _orbit: Node3D
var _flap := 1.0                  # how hard its wings beat (phase 2: harder)
var _trail: Array = []            # the hero's last few seconds: [position, time], newest last
var _trail_tick := 0.0
var _books: Array = []            # each {node, start, dir, s, run, wait, hit, flap}
var _marks: Array = []            # footprints and burnt words on the floor
var _double: Enemy
var _last_word := ""


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_archivist"
	init_health(800.0)
	drop_chance = 0.0
	move_speed = 1.3
	contact_damage = 16.0
	radius = 1.1
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_ROGUE, 4.3, TEAL)
	look.hide = ["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"]
	look.body = Color(0.92, 0.86, 0.7)   # bones yellowed like old paper
	look.accent = INK
	look.attack_anim = "Spellcast_Shoot"
	look.shape = {"scale": {"chest": 0.85, "head": 0.95, "upperarm.l": 1.35, "upperarm.r": 1.35, "upperleg.l": 1.35, "upperleg.r": 1.35},
		"turn": {"spine": Vector3(12, 0, 0), "head": Vector3(-8, 0, 0)}}   # (v351: a tall stooped scholar)
	look.parts = "scholar"
	make_visual(look)
	_page_mat().set_shader_parameter("blaze", 0.0)
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


# --- How it looks ----------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		match key:
			"cloth": _meshes[k] = U.mat(Color(0.06, 0.07, 0.13), 0.75)
			"stole": _meshes[k] = U.mat(Color(0.08, 0.2, 0.3), 0.7)
			"gold": _meshes[k] = U.mat(GOLD, 0.3, 0.25)
			"brass": _meshes[k] = U.mat(Color(0.7, 0.52, 0.22), 0.3)
			"lens": _meshes[k] = U.mat(TEAL, 0.15, 2.4)
			"bone": _meshes[k] = U.mat(Color(0.9, 0.85, 0.7), 0.8)
			"leather": _meshes[k] = U.mat(Color(0.3, 0.05, 0.06), 0.65)
			"paper": _meshes[k] = U.mat(Color(0.86, 0.8, 0.64), 0.9)
			"iron": _meshes[k] = U.mat(Color(0.2, 0.2, 0.23), 0.45)
			"eye": _meshes[k] = U.mat(TEAL, 0.3, 3.0)
			"glow":
				var g := StandardMaterial3D.new()
				g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				g.billboard_keep_scale = true
				g.albedo_texture = U.soft_circle()
				g.albedo_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.5)
				_meshes[k] = g
	return _meshes[k]


## A rod from `a` to `b`, `r` thick (a cylinder turned to lie along it).
static func _rod(parts: Array, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	parts.append([Props._cone(r, r, 1.0, 6), Transform3D(Basis(x, y * d.length(), z), (a + b) * 0.5), m])


## A loose page: paper written over in lines of ink that glow as a whisper runs up them, its
## edges glowing (its UVs: x across, y from its root to its tip). `blaze`: phase 2.
static func _page_mat() -> ShaderMaterial:
	if not _meshes.has("page_mat"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float blaze = 0.0;
void fragment() {
	vec2 uv = UV;
	float row = uv.y * 11.0;
	float fr = fract(row);
	float line = smoothstep(0.3, 0.38, fr) * (1.0 - smoothstep(0.56, 0.64, fr));
	float w = uv.x * 6.0 + floor(row) * 1.7;
	float word = step(0.3, fract(w)) * step(0.12, uv.x) * step(uv.x, 0.88) * step(0.06, uv.y) * step(uv.y, 0.93);
	float wave = pow(0.5 + 0.5 * sin(uv.y * 6.0 - TIME * 3.0), 6.0);
	float edge = 1.0 - smoothstep(0.0, 0.08, min(min(uv.x, 1.0 - uv.x), 1.0 - uv.y));
	vec3 paper = vec3(0.9, 0.84, 0.68) * (0.85 + 0.15 * uv.y);
	ALBEDO = mix(paper, vec3(0.1, 0.09, 0.12), line * word * 0.85);
	ROUGHNESS = 0.9;
	EMISSION = vec3(0.35, 1.0, 0.82) * (edge * (0.55 + 0.7 * blaze) + line * word * wave * (0.6 + 1.2 * blaze));
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes["page_mat"] = m
	return _meshes["page_mat"]


## One page as two triangles: from `root` `length` along `along`, `width` across, narrowing
## to `tip` of its width at the far end.
static func _page(st: SurfaceTool, root: Vector3, along: Vector3, across: Vector3, length: float, width: float, tip := 0.8) -> void:
	var n := across.cross(along).normalized()
	var a := root - across * width * 0.5
	var b := root + across * width * 0.5
	var c := root + along * length + across * width * 0.5 * tip
	var d := root + along * length - across * width * 0.5 * tip
	for v: Array in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c, Vector2(1, 1)], [a, Vector2(0, 0)], [c, Vector2(1, 1)], [d, Vector2(0, 1)]]:
		st.set_normal(n)
		st.set_uv(v[1])
		st.add_vertex(v[0])


## One wing (its root at 0, spreading out along +X, up and back): a bone arm, and a fan of
## six long pages, longest in the middle, tilted to face up and forward so they read from
## above. The other wing is this one mirrored.
static func _wing_mesh() -> ArrayMesh:
	if _meshes.has("wing"):
		return _meshes["wing"]
	var out := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt := 1.0
	var spread := Vector3(1, 0, 0)
	var rise := Vector3(0, cos(tilt), -sin(tilt))
	var normal := spread.cross(rise)
	var lengths := [0.8, 1.06, 1.24, 1.22, 1.05, 0.82]
	for i in 6:
		var a := deg_to_rad(80.0 - i * 18.0)
		var along := (spread * cos(a) + rise * sin(a)).normalized()
		var across := along.cross(normal).normalized()
		_page(st, along * 0.06 + normal * (0.006 * i), along, across, lengths[i], 0.32)
	st.generate_tangents()
	st.commit(out)
	out.surface_set_material(0, _page_mat())
	# The bone arm along the top of the fan, with a knuckle at its bend.
	var parts := []
	var elbow := (spread * cos(1.0) + rise * sin(1.0)) * 0.55 + normal * 0.03
	var tip := (spread * cos(0.55) + rise * sin(0.55)) * 1.25 + normal * 0.03
	_rod(parts, Vector3.ZERO, elbow, 0.03, _mat("bone"))
	_rod(parts, elbow, tip, 0.022, _mat("bone"))
	parts.append([Props._knob(), Props._xf(elbow, Vector3.ONE * 0.045), _mat("bone")])
	parts.append([Props._knob(), Props._xf(tip, Vector3.ONE * 0.03), _mat("bone")])
	var arm := Props._bake(parts)
	for s in arm.get_surface_count():
		var st2 := SurfaceTool.new()
		st2.create_from(arm, s)
		st2.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, arm.surface_get_material(s))
	_meshes["wing"] = out
	return out


## Its spectacles (head-bone space, +Z the face; the skull 0.92 tall, its front at z 0.45):
## two great round brass rims with lenses that glow, a bridge and arms back to the ears.
static func _specs_mesh() -> ArrayMesh:
	if _meshes.has("specs"):
		return _meshes["specs"]
	var parts := []
	var rim := TorusMesh.new()
	rim.inner_radius = 0.125
	rim.outer_radius = 0.165
	rim.rings = 16
	rim.ring_segments = 6
	var lens := Props._cone(0.13, 0.13, 0.02, 14)
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for sx in [-1.0, 1.0]:
		parts.append([rim, Transform3D(face, Vector3(sx * 0.18, 0.47, 0.47)), _mat("brass")])
		parts.append([lens, Transform3D(face, Vector3(sx * 0.18, 0.47, 0.46)), _mat("lens")])
		_rod(parts, Vector3(sx * 0.34, 0.49, 0.45), Vector3(sx * 0.44, 0.47, 0.06), 0.014, _mat("brass"))
	_rod(parts, Vector3(-0.05, 0.5, 0.48), Vector3(0.05, 0.5, 0.48), 0.016, _mat("brass"))
	_meshes["specs"] = Props._bake(parts)
	return _meshes["specs"]


## Its scholar's cap (head-bone space): a dark skullcap, a flat square board on it worn point
## forward (a diamond from above) with a gold edge, a gold button and a tassel on a cord.
static func _cap_mesh() -> ArrayMesh:
	if _meshes.has("cap"):
		return _meshes["cap"]
	var parts := []
	var turn := Basis(Vector3.UP, PI * 0.25)
	parts.append([Props._cone(0.36, 0.39, 0.17, 12), Props._xf(Vector3(0, 0.83, -0.03), Vector3.ONE), _mat("cloth")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.925, -0.03), Vector3(1.0, 0.03, 1.0), turn), _mat("gold")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.945, -0.03), Vector3(0.94, 0.04, 0.94), turn), _mat("cloth")])
	parts.append([Props._knob(), Props._xf(Vector3(0, 0.97, -0.03), Vector3(0.06, 0.035, 0.06)), _mat("gold")])
	var corner := Vector3(0.64, 0.968, -0.03)
	_rod(parts, Vector3(0, 0.972, -0.03), corner, 0.014, _mat("gold"))
	_rod(parts, corner, corner + Vector3(0.03, -0.3, 0.02), 0.016, _mat("gold"))
	parts.append([Props._cone(0.02, 0.055, 0.16, 8), Props._xf(corner + Vector3(0.03, -0.36, 0.02), Vector3.ONE), _mat("gold")])
	_meshes["cap"] = Props._bake(parts)
	return _meshes["cap"]


## Its stole (chest-bone space, +Z its front): two strips of ink-blue cloth over its
## shoulders and down its front, edged in gold, a gold open book at the foot of each.
static func _stole_mesh() -> ArrayMesh:
	if _meshes.has("stole"):
		return _meshes["stole"]
	var parts := []
	for sx in [-1.0, 1.0]:
		var top := Vector3(sx * 0.13, 0.43, 0.15)
		var foot := Vector3(sx * 0.12, -0.5, 0.33)
		var y := (foot - top)
		var b := Basis(Vector3.RIGHT, -atan2(y.z, -y.y))
		var mid := (top + foot) * 0.5
		parts.append([Props._cube(), Transform3D(b * Basis.from_scale(Vector3(0.13, y.length(), 0.025)), mid), _mat("stole")])
		for ex in [-1.0, 1.0]:
			parts.append([Props._cube(), Transform3D(b * Basis.from_scale(Vector3(0.016, y.length(), 0.03)), mid + b * Vector3(ex * 0.065, 0, 0.004)), _mat("gold")])
		parts.append([Props._cube(), Transform3D(b * Basis(Vector3.UP, 0.25) * Basis.from_scale(Vector3(0.075, 0.06, 0.012)), foot + b * Vector3(-0.02, 0.07, 0.02)), _mat("gold")])
		parts.append([Props._cube(), Transform3D(b * Basis(Vector3.UP, -0.25) * Basis.from_scale(Vector3(0.075, 0.06, 0.012)), foot + b * Vector3(0.02, 0.07, 0.02)), _mat("gold")])
	_meshes["stole"] = Props._bake(parts)
	return _meshes["stole"]


## The forbidden tome on its chain (hand-slot space: the chain hangs along -Y from the
## fist): a heavy oxblood book bound in iron, a padlock on its clasp, an eye on its cover.
static func _tome_mesh() -> ArrayMesh:
	if _meshes.has("tome"):
		return _meshes["tome"]
	var parts := []
	for i in 3:
		var link := Basis(Vector3.UP, PI * 0.5 * (i % 2))
		parts.append([Props._cube(), Transform3D(link * Basis.from_scale(Vector3(0.04, 0.09, 0.014)), Vector3(0, -0.05 - i * 0.07, 0)), _mat("iron")])
	var c := Vector3(0, -0.4, 0)
	parts.append([Props._cube(), Props._xf(c, Vector3(0.32, 0.38, 0.16)), _mat("leather")])
	parts.append([Props._cube(), Props._xf(c + Vector3(0.012, 0, 0), Vector3(0.31, 0.36, 0.12)), _mat("paper")])
	for sy in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			parts.append([Props._cube(), Props._xf(c + Vector3(sx * 0.14, sy * 0.17, 0), Vector3(0.07, 0.07, 0.175)), _mat("iron")])
	parts.append([Props._cube(), Props._xf(c + Vector3(0.17, 0, 0), Vector3(0.04, 0.09, 0.18)), _mat("iron")])
	parts.append([Props._cube(), Props._xf(c + Vector3(0.2, -0.03, 0), Vector3(0.05, 0.08, 0.06)), _mat("brass")])
	for sz in [-1.0, 1.0]:
		parts.append([Props._sphere(), Props._xf(c + Vector3(0, 0.02, sz * 0.083), Vector3(0.075, 0.045, 0.01)), _mat("eye")])
	_meshes["tome"] = Props._bake(parts)
	return _meshes["tome"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		_specs = Node3D.new()
		head.add_child(_specs)
		var specs := MeshInstance3D.new()
		specs.mesh = _specs_mesh()
		_specs.add_child(specs)
		_cap = Node3D.new()
		head.add_child(_cap)
		var cap := MeshInstance3D.new()
		cap.mesh = _cap_mesh()
		_cap.add_child(cap)
	if skel and skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var stole := MeshInstance3D.new()
		stole.mesh = _stole_mesh()
		chest.add_child(stole)
		_wings = Node3D.new()
		chest.add_child(_wings)
		_wing_r = Node3D.new()
		_wing_r.position = Vector3(0.14, 0.32, -0.22)
		_wings.add_child(_wing_r)
		_wing_l = Node3D.new()
		_wing_l.position = Vector3(-0.14, 0.32, -0.22)
		_wing_l.scale = Vector3(-1, 1, 1)
		_wings.add_child(_wing_l)
		for w: Node3D in [_wing_r, _wing_l]:
			var m := MeshInstance3D.new()
			m.mesh = _wing_mesh()
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.add_child(m)
	if skel and skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		_tome = Node3D.new()
		hand.add_child(_tome)
		var tome := MeshInstance3D.new()
		tome.mesh = _tome_mesh()
		# The slot's +X runs down the fingers (its +Y is where a blade would point): the chain
		# hangs that way.
		tome.rotation = Vector3(0, 0, PI * 0.5)
		_tome.add_child(tome)
	# Loose pages circling it at chest height (in the room's metres, not the bones').
	_orbit = Node3D.new()
	add_child(_orbit)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := TAU * i / 6.0
		var at := Vector3(cos(a), 0.0, sin(a)) * (2.0 + 0.25 * (i % 2)) + Vector3.UP * (2.0 + 0.55 * ((i * 7) % 3))
		var along := Vector3(-sin(a), 0.35, cos(a)).normalized()
		var across := Vector3(0, 1, 0).cross(along).normalized().rotated(along, 0.6)
		_page(st, at, along, across, 0.55, 0.4, 1.0)
	st.generate_tangents()
	var orbit := MeshInstance3D.new()
	orbit.mesh = st.commit()
	orbit.material_override = _page_mat()
	orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orbit.add_child(orbit)


## A flying book (+Z its way): two covers flapping like wings on its spine, pages inside
## with glowing writing, a glow round it so it reads against the floor.
static func _book_node(colour: String) -> Node3D:
	var n := Node3D.new()
	for sd in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "L" if sd < 0.0 else "R"
		n.add_child(hinge)
		var parts := []
		parts.append([Props._cube(), Props._xf(Vector3(sd * 0.16, 0, 0), Vector3(0.32, 0.025, 0.42)), Props._lib_mat(colour)])
		parts.append([Props._cube(), Props._xf(Vector3(sd * 0.15, 0.03, 0), Vector3(0.28, 0.035, 0.38)), Props._lib_mat("paper")])
		for k in 3:
			parts.append([Props._cube(), Props._xf(Vector3(sd * 0.15, 0.05, -0.1 + k * 0.1), Vector3(0.2, 0.006, 0.02)), Props._lib_mat("ghost")])
		var key := "book_" + colour + ("_l" if sd < 0.0 else "_r")
		if not _meshes.has(key):
			_meshes[key] = Props._bake(parts)
		var m := MeshInstance3D.new()
		m.mesh = _meshes[key]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hinge.add_child(m)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	glow.mesh = q
	glow.material_override = _mat("glow")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(glow)
	n.scale = Vector3.ONE * BOOK_SCALE
	return n


## For the shader warm-up (warmup.gd): a wing, a flying book, a footprint and a burnt stroke.
static func warm(parent: Node3D, at: Vector3) -> void:
	var w := MeshInstance3D.new()
	w.mesh = _wing_mesh()
	parent.add_child(w)
	w.position = at
	var b := _book_node("red")
	parent.add_child(b)
	b.position = at + Vector3(1.0, 1.0, 0)
	var f := _footprint()
	parent.add_child(f)
	f.position = at + Vector3(-1.0, 0.04, 0)
	var s := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(STROKE, 1.5)
	s.mesh = pm
	s.material_override = _scorch_mat()
	parent.add_child(s)
	s.position = at + Vector3(0, 0.04, 1.0)


## Phase 2: its pages blaze and its wings spread wider and beat harder.
func _blaze() -> void:
	_page_mat().set_shader_parameter("blaze", 1.0)
	_flap = 1.8
	if _wings:
		_wings.create_tween().tween_property(_wings, "scale", Vector3.ONE * 1.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	_t += delta
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Sfx.play("flutter", 0.6, 0.8)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.2
		phase_two(TEAL, "mirror", "Mirror Page")
		_blaze()
		_raise_keepers()
	_remember(hero, delta)
	if randf() < delta * 2.0:
		# Motes of the whispering drift off its pages.
		Fx.magic(center() + Vector3(randf_range(-1.2, 1.2), randf_range(-0.2, 1.6), randf_range(-1.2, 1.2)), TEAL if randf() < 0.6 else PALE, 1)
	if _busy:
		stand(delta)
		if _face_to != Vector3.ZERO:
			face(_face_to, 12.0, delta)
		return
	# It keeps a reader's distance: closes in when far, steps back when crowded.
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 6.0:
		walk(to, delta)
	elif to.length() < 3.0:
		walk(-to, delta, 0.8)
		face(to, 6.0, delta)
	else:
		stand(delta)
		face(to, 6.0, delta)


func _process(delta: float) -> void:
	super._process(delta)
	if dead:
		return
	# Its wings beat, its pages circle (also while it roars), and its books fly.
	var beat := sin(Time.get_ticks_msec() * 0.001 * 2.2 * _flap) * 0.16 * _flap
	if _wing_r:
		_wing_r.rotation = Vector3(0, -0.15 + beat * 0.5, beat)
		_wing_l.rotation = Vector3(0, 0.15 - beat * 0.5, -beat)
	if _orbit:
		_orbit.rotation.y += delta * 0.5 * _flap
	if not _books.is_empty() and Game.state == Game.State.PLAYING:
		_fly_books(delta)


## Writes down where the hero is a dozen times a second (the story it reads back).
func _remember(hero: Hero, delta: float) -> void:
	_trail_tick -= delta
	if _trail_tick > 0.0:
		return
	_trail_tick = 0.08
	_trail.append([hero.global_position, _t])
	while not _trail.is_empty() and float(_trail[0][1]) < _t - 4.0:
		_trail.pop_front()


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
		var moves := ["words", "retell", "books", "words", "retell"]
		if _enraged:
			moves.append("mirror")   # phase 2's own move
		if returning():
			moves.append("encore")   # Turning Page (version 302)
		match next_move(moves):
			"words": await _words()
			"retell": await _retell()
			"books": await _bookstorm()
			"mirror": await _mirror_page()
			"encore": await _turning_page()
		_busy = false
		_face_to = Vector3.ZERO
		await _wait(0.9 if _enraged else 1.4)


func _room() -> Node:
	return Room.current if is_instance_valid(Room.current) else get_parent()


func _cast() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)


# Burning Words ---------------------------------------------------------------------------------

## How wide and tall `word` is written on the floor (a space breaks it into two lines).
func _word_size(word: String) -> Vector2:
	var lines := word.split(" ")
	var w := 0.0
	for line in lines:
		w = maxf(w, line.length() * LETTER_W + (line.length() - 1) * LETTER_GAP)
	return Vector2(w, lines.size() * LETTER_H + (lines.size() - 1) * LINE_GAP)


## The strokes of `word` written round `c`, each [from, to] on the floor. Its letters read
## from the hero's side: left to right across the room, their tops towards the far end.
func _word_strokes(word: String, c: Vector3) -> Array:
	var lines := word.split(" ")
	var h := _word_size(word).y
	var out: Array = []
	for li in lines.size():
		var line: String = lines[li]
		var w := line.length() * LETTER_W + (line.length() - 1) * LETTER_GAP
		var top := c.z - h * 0.5 + li * (LETTER_H + LINE_GAP)
		for k in line.length():
			var left := c.x - w * 0.5 + k * (LETTER_W + LETTER_GAP)
			for s: Array in GLYPHS.get(line[k], []):
				var a := Vector3(left + float(s[0]) * LETTER_W, 0.0, top + (1.0 - float(s[1])) * LETTER_H)
				var b := Vector3(left + float(s[2]) * LETTER_W, 0.0, top + (1.0 - float(s[3])) * LETTER_H)
				out.append([a, b])
	return out


## Whether `p` (a body `r` round) is on any of the strokes.
func _on_stroke(strokes: Array, p: Vector3, r: float) -> bool:
	for s: Array in strokes:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := b - a
		var ln := d.length()
		if ln < 0.01:
			continue
		d /= ln
		if Enemy.in_strip(p, a - d * STROKE * 0.5, d, ln + STROKE, STROKE, r):
			return true
	return false


## Where to write the word: on the hero, inside the room, and nudged so a stroke runs right
## under them (so they always have to move).
func _place_word(word: String, h: Vector3) -> Vector3:
	var size := _word_size(word)
	var lim_x := maxf(Room.HALF_W - 0.35 - size.x * 0.5, 0.0)
	var lim_z := maxf(Room.HALF_L - 0.6 - size.y * 0.5, 0.0)
	var base := Vector3(clampf(h.x, -lim_x, lim_x), 0.0, clampf(h.z, -lim_z, lim_z))
	for dz: float in [0.0, 0.45, -0.45, 0.9, -0.9]:
		for dx: float in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9, 1.2, -1.2]:
			var c := Vector3(clampf(base.x + dx, -lim_x, lim_x), 0.0, clampf(base.z + dz, -lim_z, lim_z))
			if _on_stroke(_word_strokes(word, c), h, 0.1):
				return c
	return base


func _words() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var pool: Array = ANGRY_WORDS if _enraged else WORDS
	var word: String = pool[randi() % pool.size()]
	for tries in 4:
		if word != _last_word:
			break
		word = pool[randi() % pool.size()]
	_last_word = word
	var c := _place_word(word, hero.global_position)
	var strokes := _word_strokes(word, c)
	_face_to = c - global_position
	_cast()
	Sfx.play(roar_sound, 0.4, 1.25)
	var source := kind_name()
	var total := WORD_TIME + strokes.size() * WORD_WRITE
	# It writes stroke after stroke; every warning lands together.
	var el := 0.0
	var i := 0
	var scratch := 0.0
	while i < strokes.size():
		if not _alive():
			return
		while i < strokes.size() and el >= i * WORD_WRITE:
			var a: Vector3 = strokes[i][0]
			var b: Vector3 = strokes[i][1]
			var d := (b - a).normalized()
			var ln := a.distance_to(b)
			track(Telegraph.line(a - d * STROKE * 0.5, d, ln + STROKE, STROKE, total - el,
				_burn_word.bind(strokes, source) if i == 0 else Callable(), 0.55 if i == 0 else 0.0))
			i += 1
		scratch -= get_process_delta_time()
		if scratch <= 0.0:
			scratch = 0.12
			Sfx.play("quill", 0.45, randf_range(0.8, 0.95))
		await frame()
		el += get_process_delta_time()
	await _wait(maxf(total - el, 0.0) + 0.4)


## The letters burn: the hero on any stroke is hit (once), and the word stays burnt into the
## floor for a moment, its edges still burning.
func _burn_word(strokes: Array, source: String) -> void:
	if not _alive():
		return
	var hero := Game.hero
	if hero and hero.can_be_hit():
		for s: Array in strokes:
			var a: Vector3 = s[0]
			var b: Vector3 = s[1]
			var d := (b - a).normalized()
			if Enemy.in_strip(hero.global_position, a - d * STROKE * 0.5, d, a.distance_to(b) + STROKE, STROKE, hero.radius * 0.3):
				Game.hit_source = source
				var side := d.cross(Vector3.UP)
				hero.take_damage(WORD_DAMAGE, side * (1.0 if side.dot(hero.global_position - a) >= 0.0 else -1.0), 6.0)
				Fx.impact(hero.global_position + Vector3.UP * 0.8, TEAL, 1.0)
				break
	Sfx.play("burn_word", 0.9, randf_range(0.95, 1.05))
	Game.shake(0.22)
	_scorch(strokes)


## The burnt word: dark ink strokes with burning teal edges, fading out, and flames along
## them.
static func _scorch_mat() -> ShaderMaterial:
	if not _meshes.has("scorch"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float fade = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float n = hash(floor(vec2(UV.x * 5.0, UV.y * 24.0 - TIME * 7.0)));
	float body = 1.0 - smoothstep(0.72, 1.0, x + n * 0.18);
	float rim = smoothstep(0.35, 0.8, x + n * 0.1) * body;
	float flick = 0.7 + 0.3 * sin(TIME * 31.0 + UV.y * 37.0);
	ALBEDO = mix(vec3(0.02, 0.03, 0.05), vec3(0.45, 1.0, 0.85) * 1.7 * flick, rim * (0.4 + 0.6 * fade));
	ALPHA = body * fade * mix(0.8, 1.0, rim);
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes["scorch"] = m
	return _meshes["scorch"]


func _scorch(strokes: Array) -> void:
	var room := _room()
	if room == null:
		return
	var holder := Node3D.new()
	room.add_child(holder)
	_marks.append(holder)
	var m: ShaderMaterial = _scorch_mat().duplicate()
	var bursts := 0
	for s: Array in strokes:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := (b - a).normalized()
		var ln := a.distance_to(b) + STROKE
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(STROKE * 1.1, ln)
		q.mesh = pm
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(q)
		q.global_position = (a + b) * 0.5 + Vector3.UP * 0.04
		q.rotation.y = atan2(-d.x, -d.z)
		var k := 0.0
		while k < ln and bursts < 30:
			var p := a - d * STROKE * 0.5 + d * k
			Fx._burst(p + Vector3.UP * 0.2, 5, Color(0.45, 1.0, 0.85, 0.9), 0.3, 2.6, 0.5, -2.0)
			bursts += 1
			k += 1.3
	var tw := holder.create_tween()
	tw.tween_method(func(f: float) -> void: m.set_shader_parameter("fade", f), 1.0, 0.0, 1.6).set_delay(0.3)
	tw.tween_callback(holder.queue_free)


# Retelling -------------------------------------------------------------------------------------

## The hero's path over the last `span` seconds, as points `RETELL_STEP` apart along the way
## they walked, oldest first, ending where they stand now.
func _story(span: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for e: Array in _trail:
		if float(e[1]) >= _t - span:
			pts.append(e[0])
	if Game.hero:
		pts.append(Game.hero.global_position)
	var out: Array[Vector3] = []
	if pts.is_empty():
		return out
	out.append(pts[0])
	var gone := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var at := 0.0
		while gone + (seg - at) >= RETELL_STEP:
			at += RETELL_STEP - gone
			gone = 0.0
			out.append(a.lerp(b, at / seg))
		gone += seg - at
	if out.back().distance_to(pts.back()) > RETELL_STEP * 0.4:
		out.append(pts.back())
	while out.size() > RETELL_MAX:
		out.pop_front()
	return out


## A glowing inky footprint (a QuadMesh lying flat; its toes towards -Z).
static func _footprint_mat() -> ShaderMaterial:
	if not _meshes.has("foot"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
float ell(vec2 p, vec2 c, vec2 r) { return length((p - c) / r) - 1.0; }
void fragment() {
	vec2 p = UV;
	float d = min(ell(p, vec2(0.5, 0.45), vec2(0.33, 0.27)), ell(p, vec2(0.52, 0.8), vec2(0.25, 0.17)));
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		d = min(d, ell(p, vec2(0.25 + 0.165 * fi, 0.11 + 0.025 * abs(fi - 0.6)), vec2(0.085 - 0.01 * fi, 0.08 - 0.008 * fi)));
	}
	float inside = 1.0 - smoothstep(-0.06, 0.04, d);
	float rim = smoothstep(-0.22, -0.02, d);
	float pulse = 0.8 + 0.2 * sin(TIME * 7.0);
	ALBEDO = mix(vec3(0.45, 1.0, 0.85) * 1.5 * pulse, vec3(0.02, 0.03, 0.06), rim);
	ALPHA = inside * 0.95;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes["foot"] = m
	return _meshes["foot"]


static func _footprint() -> MeshInstance3D:
	if not _meshes.has("foot_mesh"):
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.62, 1.0)
		_meshes["foot_mesh"] = pm
	var f := MeshInstance3D.new()
	f.mesh = _meshes["foot_mesh"]
	f.material_override = _footprint_mat()
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return f


## It reads the hero's story back: their last steps glow as inky footprints, then burst one
## after another, oldest first, chasing them along the way they came.
func _retell() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var steps := _story(RETELL_SPAN * (1.25 if _enraged else 1.0))
	if steps.is_empty():
		return
	_face_to = hero.global_position - global_position
	_cast()
	Sfx.play("flutter", 0.6, 1.2)
	Sfx.play(roar_sound, 0.35, 1.4)
	var source := kind_name()
	var gap := RETELL_GAP * (0.85 if _enraged else 1.0)
	var room := _room()
	for k in steps.size():
		var p := steps[k]
		var at := RETELL_LEAD + k * gap
		track(Telegraph.circle(p, RETELL_R, at, _ink_burst.bind(p, source), 0.55 if k == 0 else 0.0))
		if room:
			var f := _footprint()
			room.add_child(f)
			_marks.append(f)
			var ahead := (steps[k + 1] if k + 1 < steps.size() else p + (p - steps[k - 1] if k > 0 else Vector3.FORWARD)) - p
			ahead.y = 0.0
			if ahead.length() < 0.05:
				ahead = Vector3.FORWARD
			var side := ahead.normalized().cross(Vector3.UP) * (0.13 if k % 2 == 0 else -0.13)
			f.global_position = p + side + Vector3.UP * 0.045
			f.rotation.y = atan2(-ahead.x, -ahead.z)
			if k % 2 == 1:
				f.scale = Vector3(-1, 1, 1)
			var tw := f.create_tween()
			f.scale *= 0.2
			tw.tween_property(f, "scale", Vector3(-1 if k % 2 == 1 else 1, 1, 1), 0.12).set_delay(k * 0.025)
			tw.tween_interval(maxf(at - k * 0.025 - 0.12, 0.0))
			tw.tween_callback(f.queue_free)
	await _wait(RETELL_LEAD + steps.size() * gap + 0.3)


func _ink_burst(p: Vector3, source: String) -> void:
	if not _alive():
		return
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - p
		d.y = 0.0
		if d.length() < RETELL_R + hero.radius * 0.4:
			Game.hit_source = source
			hero.take_damage(RETELL_DAMAGE, d if d.length() > 0.05 else Vector3.BACK, 6.0)
	Fx._burst(p + Vector3.UP * 0.25, 10, Color(0.45, 1.0, 0.85, 0.95), 0.28, 3.2, 0.5, 6.0)
	Fx._burst(p + Vector3.UP * 0.2, 8, Color(0.03, 0.04, 0.08, 0.95), 0.32, 2.6, 0.55, 9.0)
	Sfx.play("ink", 0.5, randf_range(0.9, 1.15))


# Bookstorm -------------------------------------------------------------------------------------

## How far a book flies from `start` along `dir` before cover (or the far wall) stops it.
func _flight(start: Vector3, dir: Vector3) -> float:
	var run := 0.0
	var room := Room.current
	while run < Room.HALF_L * 2.0:
		var p := start + dir * (run + BOOK_HALF_L + 0.2)
		if absf(p.x) > Room.HALF_W - 0.2 or absf(p.z) > Room.HALF_L - 0.2:
			break
		if is_instance_valid(room) and room.blocks_shot(p, BOOK_HALF_W * 0.7):
			break
		run += 0.25
	return run


## Where on the walls a book bursts out to fly at `h` coming from direction `a`: the shelf
## that way from the hero.
func _shelf_spot(h: Vector3, d: Vector3) -> Vector3:
	var t := INF
	if absf(d.x) > 0.001:
		t = minf(t, ((Room.HALF_W - 0.35) * signf(d.x) - h.x) / d.x)
	if absf(d.z) > 0.001:
		t = minf(t, ((Room.HALF_L - 0.35) * signf(d.z) - h.z) / d.z)
	return h + d * t


## Books burst out of the shelves and flap across the room at the hero, one after another.
func _bookstorm() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.45, 1.15)
	var n := 6 if _enraged else 4
	var base := randf() * TAU
	var source := kind_name()
	var made := 0
	var k := 0
	while made < n and k < n * 3 and _alive() and Game.hero:
		var h := Game.hero.global_position
		var a := base + k * 2.4   # about 137 degrees on each time, so they come from all sides
		k += 1
		var d := Vector3(cos(a), 0.0, sin(a))
		var start := _shelf_spot(h, d)
		var dir := -d
		var run := _flight(start, dir)
		if run < start.distance_to(h) * 0.5 or run < 2.5:
			continue   # cover right in front of that shelf
		made += 1
		track(Telegraph.line(start, dir, run + BOOK_HALF_L, BOOK_WIDTH, BOOK_AIM, Callable(), 0.5 if made == 1 else 0.25))
		var colour: String = Props.BOOK_COLOURS[randi() % Props.BOOK_COLOURS.size()]
		var node := _book_node(colour)
		_room().add_child(node)
		node.global_position = start + Vector3.UP * 1.1
		node.rotation.y = atan2(dir.x, dir.z)
		Fx._burst(start + Vector3.UP * 1.1, 10, Color(0.9, 0.85, 0.7, 0.9), 0.22, 2.4, 0.5, 4.0)
		Sfx.play("flutter", 0.5, randf_range(1.0, 1.2))
		_books.append({"node": node, "start": start, "dir": dir, "s": 0.0, "run": run, "wait": BOOK_AIM, "hit": false, "t": randf() * 5.0})
		await _wait(BOOK_GAP)
	var guard := 0.0
	while _alive() and not _books.is_empty() and guard < 4.0:
		guard += get_process_delta_time()
		await frame()
	await _wait(0.2)


func _fly_books(dt: float) -> void:
	var h := Game.hero
	var source := kind_name()
	var keep: Array = []
	for b: Dictionary in _books:
		var n: Node3D = b.node
		if not is_instance_valid(n):
			continue
		b.t = float(b.t) + dt
		var dir: Vector3 = b.dir
		var flap := 0.35 + 0.5 * absf(sin(float(b.t) * (9.0 if float(b.wait) > 0.0 else 16.0)))
		(n.get_node("L") as Node3D).rotation.z = -flap
		(n.get_node("R") as Node3D).rotation.z = flap
		if float(b.wait) > 0.0:
			# Hovering out of its shelf, shaking, until its strip has filled.
			b.wait = float(b.wait) - dt
			n.global_position = b.start + Vector3.UP * (1.1 + sin(float(b.t) * 6.0) * 0.06) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.03
			if float(b.wait) <= 0.0:
				Sfx.play("flutter", 0.7, randf_range(1.1, 1.3))
			keep.append(b)
			continue
		b.s = float(b.s) + BOOK_SPEED * dt
		var p: Vector3 = b.start + dir * float(b.s)
		n.global_position = p + Vector3.UP * (1.0 + sin(float(b.t) * 16.0) * 0.08)
		if randf() < dt * 20.0:
			Fx._burst(p + Vector3.UP * 1.0, 1, Color(0.45, 1.0, 0.85, 0.8), 0.2, 0.6, 0.35, 0.0)
		if not bool(b.hit) and h and h.can_be_hit():
			var off := h.global_position - p
			off.y = 0.0
			var across := off.dot(dir.cross(Vector3.UP))
			if absf(off.dot(dir)) < BOOK_HALF_L + h.radius * 0.6 and absf(across) < BOOK_HALF_W + h.radius * 0.6:
				b.hit = true
				Game.hit_source = source
				h.take_damage(BOOK_DAMAGE, (dir + dir.cross(Vector3.UP) * signf(across) * 0.5).normalized(), 8.0)
				Fx.impact(h.global_position + Vector3.UP * 0.8, TEAL, 0.9)
		if float(b.s) >= float(b.run):
			_book_burst(n)
			continue
		keep.append(b)
	_books = keep


## A book smacks into cover or the far wall and bursts into loose pages.
func _book_burst(n: Node3D) -> void:
	var at := n.global_position
	Sfx.play("flutter", 0.6, randf_range(0.7, 0.85))
	Fx._burst(at, 16, Color(0.92, 0.87, 0.72, 0.95), 0.3, 3.4, 0.7, 5.0)
	Fx._burst(at, 6, Color(0.45, 1.0, 0.85, 0.9), 0.25, 2.0, 0.5, 2.0)
	n.queue_free()


func _clear_books() -> void:
	for b: Dictionary in _books:
		if is_instance_valid(b.node):
			(b.node as Node).queue_free()
	_books.clear()


# Mirror Page -----------------------------------------------------------------------------------

## Phase 2's own move: it tears a page out of its tome and the hero's ink double climbs out of
## it on the far side of the room, mirrored (InkDouble).
# Turning Page -----------------------------------------------------------------------------------

const TURN_LIFT := 1.5       # seconds for the page to rise up on its spine (the warning)
const TURN_SLAM := 0.28      # seconds to fall onto the other half
const TURN_DAMAGE := 24.0
var _big_page: Node3D

## A giant page turns over onto the half of the room the hero stands on.
func _turning_page() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.5, 1.15)
	# It lands where the hero is now: it lifts from the other half.
	var onto := 1.0 if hero.global_position.x >= 0.0 else -1.0
	var turns := 2 if _enraged else 1
	var source := kind_name()
	for i in turns:
		if not _alive():
			break
		await _turn_once(onto, source)
		onto = -onto
		await _wait(0.35)
	_drop_page()


func _turn_once(onto: float, source: String) -> void:
	var w := Room.HALF_W
	var l := Room.HALF_L * 2.0
	# The warning: the half it will land on.
	track(Telegraph.line(Vector3(onto * w * 0.5, 0.0, Room.HALF_L), Vector3.FORWARD, l, w, TURN_LIFT + TURN_SLAM, func():
		_slam(onto, source)))
	_drop_page()
	_big_page = Node3D.new()
	_room().add_child(_big_page)
	_big_page.global_position = Vector3(0, 0.06, 0)
	var sheet := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w - 0.1, l - 0.4)
	sheet.mesh = pm
	sheet.material_override = _page_mat()
	sheet.position = Vector3(-onto * w * 0.5, 0.0, 0.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_big_page.add_child(sheet)
	Sfx.play("flutter", 0.8, 0.7)
	Fx.magic(Vector3(-onto * w * 0.5, 0.5, 0.0), TEAL, 24)
	# Up onto its spine, slowly (it lifts from the hero's far side, so it never covers them)...
	var tw := _big_page.create_tween()
	tw.tween_property(_big_page, "rotation:z", -onto * PI * 0.45, TURN_LIFT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ...then over and down.
	tw.tween_property(_big_page, "rotation:z", -onto * PI, TURN_SLAM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(TURN_LIFT + TURN_SLAM + 0.05)


func _slam(onto: float, source: String) -> void:
	Game.shake(0.45)
	Sfx.play("book_slam", 0.9, 0.6)
	var w := Room.HALF_W
	for i in 6:
		Fx._burst(Vector3(onto * w * 0.5 + randf_range(-2, 2), 0.3, randf_range(-8, 8)), 10, Color(0.86, 0.8, 0.64, 0.9), 0.3, 3.0, 0.5, 5.0)
	Fx.magic(Vector3(onto * w * 0.5, 0.4, 0.0), TEAL, 30)
	Enemy.strike_strip(Vector3(onto * w * 0.5, 0.0, Room.HALF_L), Vector3.FORWARD, Room.HALF_L * 2.0, w, TURN_DAMAGE, source)
	# Skeletons caught under it are hurt too.
	for a: Actor in Actor.all:
		if a is Enemy and not (a as Enemy).is_boss and not a.dead and a.global_position.x * onto > 0.0:
			a.take_damage(a.max_health * 0.3, Vector3.UP, 0.0)


func _drop_page() -> void:
	if is_instance_valid(_big_page):
		var p := _big_page
		var tw := p.create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(p, "scale", Vector3(1.0, 1.0, 0.01), 0.3)
		tw.tween_callback(p.queue_free)
	_big_page = null


func _mirror_page() -> void:
	var hero := Game.hero
	if hero == null:
		return
	if is_instance_valid(_double) and not _double.dead:
		await _bookstorm()
		return
	_face_to = hero.global_position - global_position
	_cast()
	Sfx.play("tear", 0.9)
	Sfx.play(roar_sound, 0.5, 1.1)
	var at := Vector3(-hero.global_position.x, 0.0, hero.global_position.z)
	if is_instance_valid(Room.current):
		at = Room.current.resolve_move(at, Vector3.ZERO, 0.5)
	# The torn page flies out of its tome to where the double will rise.
	var from := _tome.global_position if _tome else center()
	var room := _room()
	if room:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_page(st, Vector3(0, 0, -0.35), Vector3.BACK, Vector3.RIGHT, 0.7, 0.5, 1.0)
		var page := MeshInstance3D.new()
		page.mesh = st.commit()
		page.material_override = _page_mat()
		room.add_child(page)
		_marks.append(page)
		page.global_position = from
		var tw := page.create_tween().set_parallel()
		tw.tween_property(page, "global_position", at + Vector3.UP * 0.15, MIRROR_WARN * 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(page, "rotation", Vector3(0, TAU * 1.5, 0), MIRROR_WARN * 0.9)
		tw.chain().tween_callback(page.queue_free)
	track(Telegraph.circle(at, 0.95, MIRROR_WARN, _spawn_double.bind(at), 0.6))
	await _wait(MIRROR_WARN + 0.6)


func _spawn_double(at: Vector3) -> void:
	if not _alive() or Game.hero == null:
		return
	Sfx.play("ink", 0.9, 0.7)
	Fx._burst(at + Vector3.UP * 0.3, 24, Color(0.03, 0.04, 0.08, 0.95), 0.4, 3.0, 0.7, 7.0)
	Fx.magic(at + Vector3.UP * 0.6, TEAL, 16)
	Fx.shockwave(at, TEAL, 1.6)
	_double = Game.spawn_enemy("k", at)


# Phase 2 ---------------------------------------------------------------------------------------

## Two Hush Keepers step out of the stacks beside it (after its roar).
func _raise_keepers() -> void:
	await _wait(1.0)
	for i in 2:
		if not _alive() or Game.alive_enemies >= 6:
			return
		var spot := _open_spot(global_transform.basis.x * (1.0 if i == 0 else -1.0))
		Fx._burst(spot + Vector3.UP * 0.6, 18, Color(0.92, 0.87, 0.72, 0.9), 0.3, 3.0, 0.7, 4.0)
		Fx.magic(spot + Vector3.UP * 0.8, TEAL, 12)
		Sfx.play("flutter", 0.6, 0.9)
		Game.spawn_enemy("l", spot)
		await _wait(0.3)


## Open floor about three metres from it, `side` first.
func _open_spot(side: Vector3) -> Vector3:
	var room := Room.current
	var base := atan2(side.z, side.x)
	for k in 12:
		var a := base + int((k + 1) / 2.0) * (TAU / 12.0) * (1.0 if k % 2 == 0 else -1.0)
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * 3.0
		p.y = 0.0
		if room == null or room.is_walkable(p, 1.0):
			return p
	return room.resolve_move(global_position + side * 3.0, Vector3.ZERO, 0.6) if room else global_position + side * 3.0


func _clear_all() -> void:
	_clear_books()
	_drop_page()
	for m in _marks:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_marks.clear()


func _exit_tree() -> void:
	_clear_all()
	super._exit_tree()


func _on_death() -> void:
	_clear_all()
	if is_instance_valid(_double) and not _double.dead:
		_double.crumble()
	_page_mat().set_shader_parameter("blaze", 0.0)
	Sfx.play(roar_sound, 0.8, 0.85)
	Sfx.play("tear", 1.0, 0.8)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	# Its wings come apart into a storm of loose pages.
	for n: Node3D in [_wings, _orbit, _cap, _specs]:
		if n:
			var tw := n.create_tween()
			tw.tween_property(n, "scale", n.scale * 1.3, 0.2)
			tw.tween_property(n, "scale", Vector3.ZERO, 0.4)
	Fx._burst(center() + Vector3.UP * 0.6, 60, Color(0.92, 0.87, 0.72, 0.95), 0.4, 5.0, 1.4, 2.5)
	Fx._burst(center(), 30, Color(0.45, 1.0, 0.85, 0.9), 0.35, 4.0, 0.9, 3.0)
	Fx.magic(center(), PALE, 36)
	Fx.shockwave(global_position, TEAL, 5.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
