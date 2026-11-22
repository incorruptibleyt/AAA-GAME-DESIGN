class_name HushKeeper
extends Enemy
## The Whispering Library's own skeleton (floor 8, version 271; hard review of build 267, fix 3).
## Until then the Library borrowed the Frozen Ossuary's Frost Wraiths and the Ember
## Catacomb's Cinder Skeletons.
##
## A skeleton librarian, its bones written all over in glowing script, a candle burning on
## its skull, a great open book floating before it and a quill in its hand. It keeps its
## distance and writes: a circle of letters writes itself round the floor where you stand,
## one letter after another (the warning), and once the ring closes the floor inside goes
## dark as spilt ink and your weapon falls silent while you stay in it (HushCircle). Step
## out to fight again, or kill the Hush Keeper and its circle fades at once. It hardly hurts
## on its own: it holds you quiet while the others close in.

const TEAL := HushCircle.TEAL
const INK := Color(0.1, 0.15, 0.22)
## Its robe: a cool grey-teal that stands out from the Library's warm wood floors.
const ROBE := Color(0.26, 0.4, 0.44)

static var _meshes := {}

var _timer := randf_range(2.0, 3.0)
var _writing := 0.0
var _circle: HushCircle
var _book: Node3D
var _page: Node3D
var _page_t := randf_range(1.0, 2.5)
var _flip := -1.0
var _bob := randf() * TAU
var _quill: Node3D


func _setup() -> void:
	die_sound = "die_hush"
	init_health(34.0)
	move_speed = 2.0
	contact_damage = 6.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_MAGE, 2.05, TEAL)
	look.hide = ["Skeleton_Mage_Hat"]
	look.overlay = _script_bones()
	look.accent = ROBE
	look.attack_anim = "Spellcast_Shoot"
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Hush Keeper"


# --- How it looks ----------------------------------------------------------------------------

## Old yellowed bone written all over in lines of glowing script, a whisper running up
## through the words. One see-through pass over the model (a multiply pass followed by an
## added one came out nearly black on this rig).
static func _script_bones() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float row = lp.y * 15.0;
	float fr = fract(row);
	float line = smoothstep(0.36, 0.43, fr) * (1.0 - smoothstep(0.55, 0.62, fr));
	float w = (lp.x - lp.z * 0.7) * 14.0;
	float word = step(0.5, hash(vec2(floor(row), floor(w))));
	float marks = step(0.35, fract(w * 4.0 + hash(vec2(floor(row), 7.0)) * 3.0));
	float wave = pow(0.5 + 0.5 * sin(lp.y * 4.0 - TIME * 2.4), 5.0);
	float ink = line * word * marks * (0.75 + 0.25 * wave);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = mix(vec3(0.8, 0.7, 0.52), vec3(0.35, 1.0, 0.82) * (1.0 + 0.7 * wave), clamp(ink + rim * 0.5, 0.0, 1.0));
	ALPHA = clamp(max(ink, 0.12) + rim * 0.3, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_meshes["overlay"] = m
	return m


static func _mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		match key:
			"leather": _meshes[k] = U.mat(INK, 0.6)
			"page": _meshes[k] = U.mat(Color(0.86, 0.81, 0.67), 0.9, 0.35)
			"words": _meshes[k] = U.unlit(TEAL)
			"eye": _meshes[k] = U.unlit(Color(0.6, 1.0, 0.9))
			"brass": _meshes[k] = U.mat(Color(0.75, 0.57, 0.25), 0.35)
			"ribbon": _meshes[k] = U.mat(Color(0.55, 0.1, 0.12), 0.7)
			"wax": _meshes[k] = U.mat(Color(0.9, 0.86, 0.72), 0.7, 0.25)
			"flame": _meshes[k] = U.mat(Color(1.0, 0.75, 0.35), 0.5, 3.0)
			"feather": _meshes[k] = U.mat(Color(0.88, 0.97, 0.94), 0.5, 0.7)
			"halo":
				var g := U.unlit(Color(1.0, 0.7, 0.35, 0.55), U.soft_circle(), true).duplicate()
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				_meshes[k] = g
			"glow":
				var g := U.unlit(Color(TEAL.r, TEAL.g, TEAL.b, 0.5), U.soft_circle(), true).duplicate()
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_meshes[k] = g
	return _meshes[k]


## The great open book, lying open with its pages up and its spine running away from the
## reader (along Z): an ink-blue cover with brass corners, two fans of pages with glowing
## lines of writing, and a red ribbon hanging out of it.
static func _book_mesh() -> ArrayMesh:
	if _meshes.has("book"):
		return _meshes["book"]
	var parts := []
	var cube := Props._cube()
	parts.append([cube, Props._xf(Vector3(0, -0.02, 0), Vector3(1.0, 0.035, 0.68)), _mat("leather")])
	for c in [Vector3(-0.48, 0, -0.32), Vector3(0.48, 0, -0.32), Vector3(-0.48, 0, 0.32), Vector3(0.48, 0, 0.32)]:
		parts.append([cube, Props._xf(c + Vector3(0, -0.005, 0), Vector3(0.09, 0.045, 0.09)), _mat("brass")])
	for sd in [-1.0, 1.0]:
		# Each fan of pages rises a little from the spine, leaving a gutter down the middle.
		var pb := Basis(Vector3.BACK, sd * 0.12)
		parts.append([cube, Transform3D(pb * Basis.from_scale(Vector3(0.46, 0.05, 0.62)), Vector3(sd * 0.235, 0.035, 0)), _mat("page")])
		# Lines of glowing writing, each a few words long.
		for k in 9:
			var x := -0.17
			var j := 0
			while x < 0.15:
				var w := minf(0.04 + 0.09 * fposmod(sin(k * 7.1 + j * 3.3 + sd) * 43.7, 1.0), 0.17 - x)
				if w > 0.02 and not (k % 4 == 3 and x > 0.0):
					var off := pb * Vector3(x + w * 0.5, 0.028, 0)
					parts.append([cube, Transform3D(pb * Basis.from_scale(Vector3(w, 0.006, 0.016)),
						Vector3(sd * 0.235, 0.035, -0.25 + k * 0.0625) + off), _mat("words")])
				x += w + 0.025
				j += 1
	# The ribbon, out of the spine at the near end and hanging down over the edge.
	parts.append([cube, Props._xf(Vector3(0.02, 0.03, 0.36), Vector3(0.045, 0.01, 0.12)), _mat("ribbon")])
	parts.append([cube, Props._xf(Vector3(0.02, -0.1, 0.42), Vector3(0.045, 0.24, 0.01)), _mat("ribbon")])
	_meshes["book"] = Props._bake(parts)
	return _meshes["book"]


## One loose page, hinged at the spine (x = 0), lying over the right-hand pages.
static func _page_mesh() -> ArrayMesh:
	if _meshes.has("leaf"):
		return _meshes["leaf"]
	var parts := []
	parts.append([Props._cube(), Props._xf(Vector3(0.22, 0, 0), Vector3(0.44, 0.008, 0.6)), _mat("page")])
	for k in 8:
		parts.append([Props._cube(), Props._xf(Vector3(0.2 + 0.02 * (k % 3), 0.006, -0.23 + k * 0.065), Vector3(0.3 - 0.04 * (k % 3), 0.004, 0.015)), _mat("words")])
	_meshes["leaf"] = Props._bake(parts)
	return _meshes["leaf"]


## A melted candle to stand on the skull, its wax running down, and its flame.
static func _candle_mesh() -> ArrayMesh:
	if _meshes.has("candle"):
		return _meshes["candle"]
	var parts := []
	var sp := Props._sphere()
	parts.append([Props._cone(0.075, 0.085, 0.34, 10), Props._xf(Vector3(0, 0.17, 0), Vector3.ONE), _mat("wax")])
	parts.append([sp, Props._xf(Vector3(0, 0.34, 0), Vector3(0.078, 0.03, 0.078)), _mat("wax")])
	# Drips down its side, and pools of wax spread on the skull round its foot.
	for i in 4:
		var a := i * 1.7 + 0.4
		parts.append([sp, Props._xf(Vector3(cos(a) * 0.075, 0.12 + 0.05 * (i % 2), sin(a) * 0.075), Vector3(0.024, 0.07, 0.024)), _mat("wax")])
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		var r := 0.13 + 0.05 * (i % 2)
		parts.append([sp, Props._xf(Vector3(cos(a) * r, 0.0, sin(a) * r), Vector3(0.07, 0.025, 0.06)), _mat("wax")])
	parts.append([Props._cone(0.005, 0.005, 0.05, 4), Props._xf(Vector3(0, 0.37, 0), Vector3.ONE), _mat("leather")])
	parts.append([sp, Props._xf(Vector3(0, 0.45, 0), Vector3(0.05, 0.1, 0.05)), _mat("flame")])
	_meshes["candle"] = Props._bake(parts)
	return _meshes["candle"]


## A long quill, held point down: a white feather with a glowing teal edge and a brass nib.
static func _quill_mesh() -> ArrayMesh:
	if _meshes.has("quill"):
		return _meshes["quill"]
	var poly := []
	var n := 10
	for i in n + 1:   # up the right side of the vane
		var t := float(i) / n
		poly.append(Vector2(0.09 * pow(sin(PI * minf(t * 1.15, 1.0)), 0.7) + 0.01, 0.2 + 0.62 * t))
	for i in n + 1:   # and down the left, a little narrower
		var t := 1.0 - float(i) / n
		poly.append(Vector2(-0.065 * pow(sin(PI * minf(t * 1.1, 1.0)), 0.7) - 0.01, 0.2 + 0.62 * t))
	var parts := []
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	parts.append([Props._poly_slab(poly, -0.012, 0.012), Transform3D(up, Vector3.ZERO), _mat("feather")])
	parts.append([Props._cone(0.012, 0.016, 0.85, 6), Props._xf(Vector3(0, 0.4, 0), Vector3.ONE), _mat("brass")])
	parts.append([Props._cone(0.02, 0.002, 0.14, 6), Props._xf(Vector3(0, -0.06, 0), Vector3.ONE), _mat("brass")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, -0.13, 0), Vector3.ONE * 0.035), _mat("words")])
	_meshes["quill"] = Props._bake(parts)
	return _meshes["quill"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		# Its eyes, two teal lights in the sockets (the rig's own are lost under the script).
		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.mesh = Props._sphere()
			eye.material_override = _mat("eye")
			eye.scale = Vector3.ONE * 0.06
			eye.position = Vector3(sx * 0.13, 0.42, 0.38)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(eye)
		var candle := MeshInstance3D.new()
		candle.mesh = _candle_mesh()
		candle.position = Vector3(0.06, 0.74, -0.04)
		candle.rotation.z = -0.12
		head.add_child(candle)
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		halo.mesh = q
		halo.material_override = _mat("halo")
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = Vector3(0, 0.45, 0)
		candle.add_child(halo)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var quill := MeshInstance3D.new()
		quill.mesh = _quill_mesh()
		quill.position = Vector3(0, 0.1, 0)
		hand.add_child(quill)
		_quill = quill
	# The book floats before it (the visual's -Z is the way it faces), tipped towards you.
	_book = Node3D.new()
	_book.position = Vector3(0, 1.05, -0.72)
	_book.rotation.x = -0.75
	visual.add_child(_book)
	var b := MeshInstance3D.new()
	b.mesh = _book_mesh()
	_book.add_child(b)
	var glow := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(1.5, 1.2)
	glow.mesh = gq
	glow.material_override = _mat("glow")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.rotation.x = -PI * 0.5
	glow.position.y = 0.09
	_book.add_child(glow)
	_page = Node3D.new()
	_page.position = Vector3(0, 0.04, 0)
	_page.rotation.z = 0.12
	_book.add_child(_page)
	var leaf := MeshInstance3D.new()
	leaf.mesh = _page_mesh()
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_page.add_child(leaf)


func _process(delta: float) -> void:
	super._process(delta)
	if dead or _book == null:
		return
	_bob += delta * 1.8
	_book.position.y = 1.05 + sin(_bob) * 0.05
	_book.rotation.z = sin(_bob * 0.5) * 0.06
	# A page turns now and then; fast, one after another, while it writes.
	_page_t -= delta * (4.0 if _writing > 0.0 else 1.0)
	if _flip < 0.0 and _page_t <= 0.0:
		_flip = 0.0
		_page_t = randf_range(1.8, 3.2)
	if _flip >= 0.0:
		_flip += delta * (3.0 if _writing > 0.0 else 1.6)
		_page.rotation.z = lerpf(0.12, PI - 0.12, smoothstep(0.0, 1.0, minf(_flip, 1.0)))
		if _flip >= 1.0:
			_flip = -1.0
			_page.rotation.z = 0.12


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _writing > 0.0:
		_writing -= delta
		stand(delta)
		face(to, 6.0, delta)
		if randf() < delta * 12.0 and _quill:
			Fx.magic(_quill.global_position, TEAL, 1)
		return
	if to.length() > 8.0:
		walk(to, delta)
	elif to.length() < 4.5:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 8.0, delta)
	_timer -= delta
	if _timer <= 0.0 and not is_instance_valid(_circle) and to.length() < 11.0:
		_write(hero)


## Writes a circle of letters round the floor where the hero stands.
func _write(hero: Hero) -> void:
	_writing = HushCircle.WRITE
	_timer = randf_range(5.6, 6.6)
	_page_t = 0.0
	visual.attack(true)
	_circle = HushCircle.spawn(hero.global_position, self)
	Fx.magic(_book.global_position if _book else center(), TEAL, 10)


func _on_death() -> void:
	super._on_death()
	if _book:
		var tw := _book.create_tween()
		tw.tween_property(_book, "scale", Vector3(1, 0.1, 1), 0.2)
		tw.tween_property(_book, "scale", Vector3.ZERO, 0.25)
	Fx.magic(center(), TEAL, 18)
