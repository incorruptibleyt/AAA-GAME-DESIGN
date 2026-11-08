class_name FeatHeads
extends Node3D
## Headwear won by Feats or found in Bone Drops (hero_style.gd EXTRA "head"), built in the
## head bone's space like the crowns: the Storm Halo, Star Circlet, Flame Crown and Skull
## Helm (Feats), and Antlers, Phantom Horns and the Bone Crown (Legendary drops). The ones
## that move (lightning, orbiting stars, flames) animate themselves.

var kind := ""
var _t := 0.0
var _spin: Node3D        # turned slowly (halo, circlet's stars)
var _arcs: Array = []    # the Storm Halo's lightning, flickering
var _arc_left := 0.0
var _stars: Array = []
var _orbit_r := 0.7

static var _flame_shader: Shader
static var _ghost_shader: Shader
static var _bone: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _gold: StandardMaterial3D


static func make(what: String, id: String, y: float, hat: bool, style: Dictionary) -> FeatHeads:
	_materials()
	var h := FeatHeads.new()
	h.kind = what
	h.name = "FeatHead_" + what
	var eye: Color = style.get("eye", Color(0.6, 0.8, 1.0))
	var hat_h: float = style.get("hat_h", 0.45)
	match what:
		"storm_halo": h._storm_halo(y + (hat_h if hat else 0.22))
		"star_circlet": h._star_circlet(id, y, hat)
		"flame_crown": h._flame_crown(id, y, hat, Color(1.0, 0.55, 0.12), Color(1.0, 0.95, 0.6))
		"skull_helm": h._skull_helm(eye)
		"antlers": h._antlers(y)
		"phantom_horns": h._phantom_horns(id, y, hat)
		"bone_crown": h._bone_crown(id, y, hat)
	return h


static func _materials() -> void:
	if _bone:
		return
	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(0.93, 0.9, 0.8)
	_bone.roughness = 0.55
	_bone.rim_enabled = true
	_bone.rim = 0.4
	_dark = StandardMaterial3D.new()
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark.albedo_color = Color(0.04, 0.03, 0.05)
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.8, 0.34)
	_gold.metallic = 0.7
	_gold.roughness = 0.25
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.72, 0.25)
	_gold.emission_energy_multiplier = 0.35
	_flame_shader = Shader.new()
	_flame_shader.code = FLAME
	_ghost_shader = Shader.new()
	_ghost_shader.code = GHOST


## Where a crown sits: [height of its base, radius], over the hero's own hat or helmet when
## `hat` (round the Mage's hat, just above the brim), as hero_style.gd _crown.
static func _fit(id: String, y: float, hat: bool) -> Vector2:
	if hat:
		match id:
			"knight": return Vector2(y + 0.02, 0.56)
			"barbarian": return Vector2(y + 0.06, 0.56)
			"mage": return Vector2(y + 0.16, 0.4)
	return Vector2(y - 0.08, 0.5)


func _mi(m: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _add_mat(c: Color) -> StandardMaterial3D:
	var m := _glow_mat(c)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


func _torus(inner: float, outer: float, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 8
	return _mi(t, mat, pos, parent)


## A tapered rod from `a` to `b` (a cone when r2 is 0).
func _rod(a: Vector3, b: Vector3, r1: float, r2: float, mat: Material, parent: Node3D = null, seg := 8) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r1
	c.top_radius = r2
	c.height = a.distance_to(b)
	c.radial_segments = seg
	c.rings = 1
	var mi := _mi(c, mat, (a + b) * 0.5, parent)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, up, side.cross(up)).orthonormalized()
	return mi


func _sphere(r: float, mat: Material, pos: Vector3, scale_by := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := _mi(s, mat, pos, parent)
	mi.scale = scale_by
	return mi


# ---------------------------------------------------------------- Storm Halo

func _storm_halo(top: float) -> void:
	_spin = Node3D.new()
	_spin.position = Vector3(0, top, 0)
	add_child(_spin)
	var core := _glow_mat(Color(0.75, 0.9, 1.0) * 2.0)
	var ring := _torus(0.4, 0.54, core, Vector3.ZERO, _spin)
	ring.scale = Vector3(1, 0.55, 1)
	var dark := _torus(0.53, 0.6, _glow_mat(Color(0.12, 0.22, 0.55)), Vector3(0, -0.015, 0), _spin)
	dark.scale = Vector3(1, 0.45, 1)
	# A soft glow hugging the ring (kept narrow: from the game camera above, a wide one
	# would cover the head like a plate).
	var halo := _torus(0.36, 0.64, _add_mat(Color(0.35, 0.6, 1.0, 0.3)), Vector3.ZERO, _spin)
	halo.scale = Vector3(1, 0.1, 1)
	# Lightning that jumps off the ring: jagged four-part arcs, a few at a time.
	var bolt := _glow_mat(Color(0.85, 0.95, 1.0) * 2.4)
	var glow := _add_mat(Color(0.45, 0.7, 1.0, 0.35))
	for i in 7:
		var arc := Node3D.new()
		_spin.add_child(arc)
		var p := Vector3(0.5, 0, 0)
		for k in 4:
			var q := p + Vector3(0.09 + randf() * 0.08, randf_range(-0.16, 0.2), randf_range(-0.12, 0.12))
			_rod(p, q, 0.034, 0.024, bolt, arc, 5)
			_rod(p, q, 0.075, 0.06, glow, arc, 5)
			p = q
		_arcs.append(arc)
	_flicker()


func _flicker() -> void:
	for arc: Node3D in _arcs:
		arc.visible = randf() < 0.45
		arc.rotation.y = randf() * TAU
		arc.scale = Vector3.ONE * randf_range(0.8, 1.25)
	_arc_left = randf_range(0.05, 0.13)


# ---------------------------------------------------------------- Star Circlet

func _star_circlet(id: String, y: float, hat: bool) -> void:
	var f := _fit(id, y, hat)
	var band_y := f.x + 0.06
	var band_r := f.y * 1.02
	_orbit_r = 0.78
	var orbit_y := y - 0.05
	if hat and id == "mage":
		_orbit_r = 1.15   # round the wizard's brim
		orbit_y = y + 0.02
	elif not hat:
		band_y = y - 0.3
		band_r = 0.56
		orbit_y = y - 0.12
	# A thin gold band with a gem at the front.
	var band := _torus(band_r - 0.025, band_r + 0.03, _gold, Vector3(0, band_y, 0))
	band.scale = Vector3(1, 0.7, 1)
	_sphere(0.07, _glow_mat(Color(0.6, 0.85, 1.0) * 1.5), Vector3(0, band_y + 0.02, band_r + 0.02))
	# Three stars orbiting, each with a soft glow.
	_spin = Node3D.new()
	_spin.position = Vector3(0, orbit_y, 0)
	add_child(_spin)
	var star := _glow_mat(Color(1.0, 0.95, 0.75) * 1.8)
	var glow := _add_mat(Color(1.0, 0.85, 0.45, 0.4))
	for i in 3:
		var s := Node3D.new()
		var a := TAU * i / 3.0
		s.position = Vector3(sin(a), 0.08 * sin(a * 2.0), cos(a)) * _orbit_r
		_spin.add_child(s)
		for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var long := 0.23 if absf(d.y) > 0.5 else 0.16
			_rod(d * 0.02, d * long, 0.065, 0.0, star, s, 4)
		_sphere(0.06, star, Vector3.ZERO, Vector3.ONE, s)
		_sphere(0.18, glow, Vector3.ZERO, Vector3.ONE, s)
		_stars.append(s)


# ---------------------------------------------------------------- Flame Crown

func _flame_crown(id: String, y: float, hat: bool, hot: Color, core: Color) -> void:
	var f := _fit(id, y, hat)
	var base := f.x
	var r := f.y
	# A blackened iron band with glowing seams...
	var band := CylinderMesh.new()
	band.top_radius = r * 1.1
	band.bottom_radius = r
	band.height = 0.18
	band.radial_segments = 20
	band.cap_top = false
	band.cap_bottom = false
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.1, 0.1)
	iron.metallic = 0.6
	iron.roughness = 0.35
	iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	iron.emission_enabled = true
	iron.emission = hot
	iron.emission_energy_multiplier = 0.25
	_mi(band, iron, Vector3(0, base + 0.09, 0))
	for yy in [base, base + 0.18]:
		var rr := r if yy == base else r * 1.1
		_torus(rr - 0.02, rr + 0.03, _glow_mat(hot * 1.4), Vector3(0, yy, 0))
	# ...crowned with flames, tall and short in turn.
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector3(sin(a), 0, cos(a))
		var h := 0.5 if i % 2 == 0 else 0.34
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.12 if i % 2 == 0 else 0.1
		c.height = h
		c.radial_segments = 8
		c.rings = 4
		var m := ShaderMaterial.new()
		m.shader = _flame_shader
		m.set_shader_parameter("seed", float(i) * 1.37)
		m.set_shader_parameter("hot", hot)
		m.set_shader_parameter("core", core)
		m.set_shader_parameter("height", h)
		_mi(c, m, Vector3(0, base + 0.16 + h * 0.5, 0) + dir * r * 1.08)
	var glow := _torus(r * 0.95, r * 1.25, _add_mat(Color(hot, 0.28)), Vector3(0, base + 0.2, 0))
	glow.scale = Vector3(1, 0.12, 1)


# ---------------------------------------------------------------- Skull Helm

## The hero's head is hidden (hero_style.gd "hide_head"): the skull is their head now, with
## their glow colour burning in its eyes.
func _skull_helm(eye: Color) -> void:
	_sphere(0.6, _bone, Vector3(0, 0.24, -0.06), Vector3(0.98, 0.92, 1.06))   # the cranium
	_sphere(0.4, _bone, Vector3(0, -0.12, 0.1), Vector3(0.9, 0.62, 0.95))     # the jaw
	for s in [-1.0, 1.0]:
		_sphere(0.15, _bone, Vector3(s * 0.33, 0.02, 0.36))                     # cheekbones
		_sphere(0.17, _dark, Vector3(s * 0.21, 0.2, 0.47), Vector3(1.0, 0.85, 0.6))   # eye sockets
		_sphere(0.065, _glow_mat(eye.lightened(0.3) * 1.7), Vector3(s * 0.21, 0.19, 0.53))
		_sphere(0.12, _add_mat(Color(eye, 0.45)), Vector3(s * 0.21, 0.19, 0.55))
	# The nose: a dark upside-down heart.
	for s in [-1.0, 1.0]:
		_sphere(0.05, _dark, Vector3(s * 0.035, 0.03, 0.57), Vector3(0.8, 1.3, 0.6))
	# Teeth: a dark line with bone teeth over it.
	var gap := BoxMesh.new()
	gap.size = Vector3(0.36, 0.035, 0.05)
	_mi(gap, _dark, Vector3(0, -0.11, 0.47))
	for i in 6:
		var t := BoxMesh.new()
		t.size = Vector3(0.05, 0.09, 0.05)
		_mi(t, _bone, Vector3(-0.15 + i * 0.06, -0.09, 0.485))
	# A crest of three bone spikes, and a crack over one eye.
	for i in 3:
		var z := -0.3 + i * 0.22
		_rod(Vector3(0, 0.74 - absf(z + 0.08) * 0.25, z), Vector3(0, 0.98 - i * 0.05, z - 0.12), 0.07, 0.0, _bone)
	var crack := BoxMesh.new()
	crack.size = Vector3(0.025, 0.2, 0.02)
	var cm := _mi(crack, _dark, Vector3(0.12, 0.45, 0.5))
	cm.rotation = Vector3(-0.5, 0, 0.35)


# ---------------------------------------------------------------- Antlers

func _antlers(y: float) -> void:
	var horn := StandardMaterial3D.new()
	horn.albedo_color = Color(0.82, 0.72, 0.56)
	horn.roughness = 0.6
	horn.rim_enabled = true
	horn.rim = 0.3
	var tip := _glow_mat(Color(0.55, 1.0, 0.85) * 1.6)
	var tip_glow := _add_mat(Color(0.4, 1.0, 0.8, 0.4))
	for s in [-1.0, 1.0]:
		# The main beam curves out, up and back; tines reach up and forward from it.
		var pts := [Vector3(s * 0.26, y - 0.08, -0.04), Vector3(s * 0.46, y + 0.18, -0.1),
			Vector3(s * 0.62, y + 0.5, -0.2), Vector3(s * 0.7, y + 0.82, -0.34), Vector3(s * 0.66, y + 1.06, -0.5)]
		for i in pts.size() - 1:
			_rod(pts[i], pts[i + 1], 0.075 - i * 0.012, 0.065 - i * 0.012, horn)
			_sphere(0.068 - i * 0.012, horn, pts[i + 1])
		var tines := [[1, Vector3(s * 0.62, y + 0.5, 0.18)], [2, Vector3(s * 0.95, y + 0.78, -0.12)], [3, Vector3(s * 0.84, y + 1.08, -0.18)]]
		for t: Array in tines:
			var from: Vector3 = pts[t[0]]
			_rod(from, t[1], 0.05, 0.02, horn)
			_sphere(0.04, tip, t[1])
			_sphere(0.09, tip_glow, t[1])
		_sphere(0.04, tip, pts[4])
		_sphere(0.09, tip_glow, pts[4])


# ---------------------------------------------------------------- Phantom Horns

func _phantom_horns(id: String, y: float, hat: bool) -> void:
	var k := 1.0
	if hat and id != "rogue":
		y += 0.12
	if hat and id == "mage":
		k = 1.6   # clear of the wide brim from above
		y += 0.12
	var m := ShaderMaterial.new()
	m.shader = _ghost_shader
	for s in [-1.0, 1.0]:
		# Big ram-like horns sweeping out, back and curling up at the ends.
		var pts := [Vector3(s * 0.34, y - 0.22, 0.02), Vector3(s * 0.62, y - 0.02, -0.12), Vector3(s * 0.86, y + 0.2, -0.32),
			Vector3(s * 0.98, y + 0.48, -0.5), Vector3(s * 0.92, y + 0.74, -0.6)]
		for i in pts.size() - 1:
			var a: Vector3 = pts[i] * Vector3(k, 1, k)
			var b: Vector3 = pts[i + 1] * Vector3(k, 1, k)
			a.y = y + (pts[i].y - y) * k
			b.y = y + (pts[i + 1].y - y) * k
			_rod(a, b, (0.13 - i * 0.028) * k, (0.105 - i * 0.026) * k, m, null, 10)


# ---------------------------------------------------------------- Bone Crown

func _bone_crown(id: String, y: float, hat: bool) -> void:
	var f := _fit(id, y, hat)
	var base := f.x
	var r := f.y
	var band := _torus(r - 0.02, r + 0.06, _bone, Vector3(0, base + 0.06, 0))
	band.scale = Vector3(1, 1.4, 1)
	var soul := Color(0.35, 1.0, 0.55)
	for i in 10:
		var a := TAU * i / 10.0
		var dir := Vector3(sin(a), 0, cos(a))
		var tall := i % 2 == 0
		var h := 0.46 if tall else 0.28
		var p := Vector3(0, base + 0.08, 0) + dir * r * 1.05
		_rod(p, p + Vector3(0, h, 0) + dir * 0.08, 0.07, 0.018, _bone)
		if tall:
			# Green soul fire on the tall bones.
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.06
			c.height = 0.24
			c.radial_segments = 8
			c.rings = 3
			var m := ShaderMaterial.new()
			m.shader = _flame_shader
			m.set_shader_parameter("seed", float(i) * 2.1)
			m.set_shader_parameter("hot", soul)
			m.set_shader_parameter("core", Color(0.85, 1.0, 0.85))
			m.set_shader_parameter("height", 0.24)
			_mi(c, m, p + Vector3(0, h + 0.1, 0) + dir * 0.08)
	# Three little skulls round the front.
	for i in [-1, 0, 1]:
		var a := float(i) * 0.62
		var p := Vector3(sin(a), 0, cos(a)) * (r + 0.07) + Vector3(0, base + 0.1, 0)
		_sphere(0.085, _bone, p)
		for s in [-1.0, 1.0]:
			var side: Vector3 = Vector3(cos(a), 0, -sin(a)) * s * 0.03
			_sphere(0.022, _glow_mat(soul * 1.4), p + side + Vector3(sin(a), 0.01, cos(a)) * 0.07)


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"storm_halo":
			_spin.rotation.y += delta * 0.8
			_spin.position.y += sin(_t * 2.0) * 0.0006
			_arc_left -= delta
			if _arc_left <= 0.0:
				_flicker()
		"star_circlet":
			_spin.rotation.y += delta * 1.1
			for s: Node3D in _stars:
				s.rotate_y(delta * 2.5)
				s.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 4.0 + s.position.x * 3.0))
		_:
			set_process(false)


const FLAME := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float seed = 0.0;
uniform vec4 hot : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform float height = 0.4;
varying float up;
void vertex() {
	up = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	float sway = up * up;
	VERTEX.x += sin(TIME * 8.0 + seed * 7.0 + up * 4.0) * 0.05 * sway;
	VERTEX.z += cos(TIME * 6.5 + seed * 5.0 + up * 3.0) * 0.05 * sway;
	VERTEX.y *= 1.0 + 0.18 * sin(TIME * 10.0 + seed * 3.0);
}
void fragment() {
	float fl = 0.75 + 0.25 * sin(TIME * 13.0 + seed * 11.0);
	vec3 c = mix(core.rgb, hot.rgb, smoothstep(0.1, 0.7, up));
	ALBEDO = c * (1.0 - up * 0.65) * fl * 1.6;
}
"""

const GHOST := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	// Ghost light: bright at the edges and pulsing, violet shading to cyan.
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float p = 0.75 + 0.25 * sin(TIME * 3.0);
	vec3 c = mix(vec3(0.55, 0.35, 1.0), vec3(0.4, 1.0, 0.95), 0.5 + 0.5 * sin(TIME * 1.3 + UV.y * 4.0));
	ALBEDO = c * (0.35 + edge * 1.4) * p;
}
"""
