class_name LegendEmperor
extends RefCounted
## Version 316 (Legend Vault, legends.gd): The Bone Emperor, the dearest look in the crypt
## (1,000,000 coins). A grand set: legend_grand.gd puts it on the hero.
##   The spine cape: an emperor's spine hanging down the back from a gilded skull at the nape,
##     twelve vertebrae with gold rings between them and gold-tipped spines, and seven pairs
##     of ribs fanning out to each side, longer towards the hem, ending in gold claws. It
##     sways, blows back as the hero runs and, in a run, streams out behind (legend_grand.gd).
##   Golden bone armour: on each shoulder a pauldron of three overlapping bone plates edged in
##     gold, with three bone spikes rising from it.
##   The crown of skulls (HeroStyle._extra "emperor_crown"): a cap of imperial purple velvet
##     crossed by two gold arches with a gold skull on top, and a gold band round it set with
##     five little skulls whose eyes burn amber, gold spikes between them.
##   The bone throne: on the title screen (and on the vault's pedestal) a throne of bones
##     stands behind the hero: a fan of long bones topped with skulls, a velvet back, skull
##     armrests and a gold-trimmed step.
## Its solid parts are marked in the stencil as the hero's own body (see
## CharacterVisual._with_xray), so in a run the hero's see-through silhouette is not drawn
## over them.

const LEN := 1.1   # the spine cape's length (the Starfall Mantle's)

static var _bone: StandardMaterial3D
static var _gold: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _velvet: StandardMaterial3D
static var _eye: StandardMaterial3D
static var _stone: StandardMaterial3D


static func _mats() -> void:
	if _bone:
		return
	_bone = _hero_mat(Color(0.93, 0.88, 0.76), 0.55, 0.0)
	_bone.rim_enabled = true
	_bone.rim = 0.3
	_bone.rim_tint = 0.4
	_gold = _hero_mat(Color(1.0, 0.77, 0.3), 0.28, 0.85)
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.62, 0.18)
	_gold.emission_energy_multiplier = 0.3
	_gold.cull_mode = BaseMaterial3D.CULL_DISABLED   # (the open crown band is seen from inside)
	_dark = _hero_mat(Color(0.07, 0.04, 0.03), 0.85, 0.0)
	_velvet = _hero_mat(Color(0.27, 0.07, 0.45), 1.0, 0.0)
	_velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	_eye = _hero_mat(Color(1.0, 0.62, 0.16), 1.0, 0.0)
	_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.17, 0.13, 0.16)
	_stone.roughness = 0.9


## Marked in the stencil as the hero's own body (the x-ray mark's value).
static func _hero_mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 2
	return m


## No outline, rim light or hit flash over these (CharacterVisual._collect_meshes).
static func _fx(n: Node) -> void:
	if n is MeshInstance3D:
		n.set_meta("fx", true)
	for c in n.get_children():
		_fx(c)


# ---------------------------------------------------------------- shapes

## A little skull facing +Z, `size` across (about), its eyes burning amber when `glow`.
static func skull(parent: Node3D, size: float, pos: Vector3, glow := true, mat: Material = null) -> Node3D:
	_mats()
	var s := Node3D.new()
	s.position = pos
	s.scale = Vector3.ONE * size
	parent.add_child(s)
	var m: Material = mat if mat else _bone
	var head := U.sphere(s, 0.5, m, Vector3(0, 0.1, 0))
	head.scale = Vector3(1.0, 0.92, 1.05)
	var jaw := U.sphere(s, 0.3, m, Vector3(0, -0.26, 0.14))
	jaw.scale = Vector3(1.15, 0.7, 1.0)
	for sd in [-1.0, 1.0]:
		U.sphere(s, 0.15, _dark, Vector3(0.19 * sd, 0.0, 0.4))
		if glow:
			var e := U.sphere(s, 0.085, _eye, Vector3(0.19 * sd, 0.0, 0.47))
			e.set_meta("fx", true)
	var nose := U.sphere(s, 0.07, _dark, Vector3(0, -0.15, 0.5))
	nose.scale = Vector3(0.8, 1.3, 0.6)
	for k in 4:
		U.box(s, Vector3(0.06, 0.09, 0.05), _dark, Vector3(-0.15 + 0.1 * k, -0.33, 0.39))   # teeth gaps
	return s


## A long bone from `a` to `b` (in `parent`'s space), `r` thick, with knobs at both ends.
static func long_bone(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material = null) -> Node3D:
	_mats()
	var m: Material = mat if mat else _bone
	var n := Node3D.new()
	parent.add_child(n)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD) if absf(y.dot(Vector3.FORWARD)) < 0.9 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	n.transform = Transform3D(Basis(x, y, x.cross(y)), a)
	var length := a.distance_to(b)
	U.cylinder(n, r, length, m, Vector3.ZERO)
	for end in [0.0, length]:
		for sd in [-1.0, 1.0]:
			U.sphere(n, r * 1.35, m, Vector3(r * 0.75 * sd, end, 0))
	return n


## A tube along `pts` with radius `rad[i]` at each point, gold where `gold[i]` is 1 (the
## vertex colour's red), into `st`. UV.y is how far down the cape a point hangs (0 at the top,
## 1 at the hem): the cape's shader sways and blows the lower end.
static func _tube(st: SurfaceTool, pts: Array, rad: Array, gold: Array, sides := 7) -> void:
	var n := pts.size()
	var rings := []
	for i in n:
		var p: Vector3 = pts[i]
		var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var a := t.cross(Vector3.FORWARD) if absf(t.dot(Vector3.FORWARD)) < 0.9 else t.cross(Vector3.RIGHT)
		a = a.normalized()
		var b := t.cross(a).normalized()
		var ring := []
		for k in sides:
			var ang := TAU * k / sides
			var nrm := a * cos(ang) + b * sin(ang)
			ring.append([p + nrm * float(rad[i]), nrm])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			# (front faces turn clockwise as seen from outside)
			var quad := [[i, k], [i + 1, k], [i + 1, k2], [i, k2]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for q: int in tri:
					var ri: int = quad[q][0]
					var v: Array = rings[ri][quad[q][1]]
					st.set_color(Color(float(gold[ri]), 0.0, 0.0))
					st.set_normal(v[1])
					st.set_uv(Vector2(0.0, clampf(-(v[0] as Vector3).y / LEN, 0.0, 1.0)))
					st.add_vertex(v[0])


## The cape's surface: how far out (+Z) it lies at `u` across (0..1) and `v` down (0..1).
static func _surf_z(u: float, v: float) -> float:
	var wrap := 1.0 - pow(2.0 * u - 1.0, 2.0)
	return 0.11 * wrap * (1.0 - v * 0.5) + 0.3 * v * v


static func _width(v: float) -> float:
	return lerpf(0.66, 1.75, pow(v, 1.2))


static var _cape: Mesh

## The spine cape, in the mantle's space (legend_grand.gd: the top in the middle at the origin,
## hanging down -Y, the outside towards +Z).
static func cape_mesh() -> Mesh:
	if _cape:
		return _cape
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The spine: twelve vertebrae, smaller towards the tail, gold rings between them, and a
	# spine standing out from each, gold at the tip.
	for j in 12:
		var k := j / 11.0
		var v0 := 0.03 + j * 0.081
		var r := lerpf(0.078, 0.04, k)
		var at := func(v: float) -> Vector3: return Vector3(0, -LEN * v, _surf_z(0.5, v) + 0.06)
		_tube(st, [at.call(v0 - 0.004), at.call(v0 + 0.008), at.call(v0 + 0.046), at.call(v0 + 0.058)],
			[r * 0.55, r, r, r * 0.55], [0.0, 0.0, 0.0, 0.0])
		_tube(st, [at.call(v0 + 0.056), at.call(v0 + 0.07), at.call(v0 + 0.082)], [r * 0.6, r * 0.72, r * 0.6], [1.0, 1.0, 1.0], 6)
		var base: Vector3 = at.call(v0 + 0.027)
		_tube(st, [base + Vector3(0, 0, r * 0.5), base + Vector3(0, -0.02, r + 0.05), base + Vector3(0, -0.05, r + 0.11)],
			[0.032, 0.022, 0.003], [0.0, 0.3, 1.0], 5)
	# The ribs: seven pairs, longer towards the hem, curving down at their ends into gold claws.
	for i in 7:
		var v := 0.08 + i * 0.125
		var half := _width(v + 0.04) * 0.5 * 0.95
		for sd in [-1.0, 1.0]:
			var pts := []
			var rad := []
			var gold := []
			for s in 9:
				var t := s / 8.0
				var u: float = 0.5 + sd * 0.5 * 0.95 * t
				var vv := v - 0.015 * t + 0.08 * t * t
				pts.append(Vector3(sd * half * t, -LEN * vv, _surf_z(u, vv) + 0.04))
				rad.append(lerpf(0.046, 0.026, t))
				gold.append(smoothstep(0.72, 0.86, t))
			var last: Vector3 = pts[-1]
			pts.append(last + Vector3(sd * 0.02, -0.08, 0.01))
			rad.append(0.002)
			gold.append(1.0)
			_tube(st, pts, rad, gold)
	_cape = st.commit()
	return _cape


static var _cape_shader: Shader

## The cape's bone and gold (gold where the vertex colour's red is 1), swaying and blowing
## back like the Starfall Mantle (same uniforms: legend_grand.gd drives them).
static func cape_material() -> ShaderMaterial:
	if _cape_shader == null:
		_cape_shader = Shader.new()
		_cape_shader.code = """
shader_type spatial;
render_mode cull_disabled;
stencil_mode write, compare_always, 2;
uniform float blow = 0.0;
uniform float reach = 0.34;
uniform float rise = 0.14;
void vertex() {
	float k = UV.y;
	float ripple = sin(TIME * 3.0 - UV.y * 5.0 + VERTEX.x * 2.0) * (0.02 + blow * 0.04);
	VERTEX.z += ripple * k * k + blow * reach * pow(k, 1.4);
	VERTEX.y += blow * rise * k * k;
}
void fragment() {
	float g = COLOR.r;
	vec3 au = vec3(1.0, 0.76, 0.3);
	ALBEDO = mix(vec3(0.92, 0.87, 0.75), au, g);
	METALLIC = 0.85 * g;
	ROUGHNESS = mix(0.55, 0.28, g);
	EMISSION = au * g * 0.3;
	RIM = 0.3;
	RIM_TINT = 0.4;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _cape_shader
	return m


## The gilded skull at the nape, where the spine cape hangs from (in the mantle's space).
static func nape(holder: Node3D) -> void:
	_mats()
	var s := skull(holder, 0.34, Vector3(0, -0.02, 0.14), true, _gold)
	_fx(s)


## A pauldron on each shoulder, on the upper arm bones so they follow the arms. Placed in the
## skeleton's own space at rest (KayKit: the shoulder joints at x 0.21, y 1.11).
static func pauldrons(skel: Skeleton3D) -> void:
	_mats()
	for bone_side in [["upperarm.l", 1.0], ["upperarm.r", -1.0]]:
		var bi := skel.find_bone(bone_side[0])
		if bi < 0:
			continue
		var sd: float = bone_side[1]
		var att := HeroStyle._attachment(skel, bone_side[0])
		var p := Node3D.new()
		p.name = "EmperorPauldron"
		att.add_child(p)
		p.transform = skel.get_bone_global_rest(bi).affine_inverse() * Transform3D(Basis.IDENTITY, Vector3(0.31 * sd, 1.19, 0.0))
		# Three plates, a gold one on top and two of bone edged in gold below it.
		for k in 3:
			var lame := Node3D.new()
			lame.position = Vector3(sd * 0.09 * k, -0.06 * k, 0.0)
			lame.rotation.z = -sd * (0.32 + 0.16 * k)
			p.add_child(lame)
			var rr := 0.265 - 0.035 * k
			var dome := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rr
			sm.height = rr
			sm.is_hemisphere = true
			sm.radial_segments = 14
			sm.rings = 5
			dome.mesh = sm
			dome.material_override = _gold if k == 0 else _bone
			dome.scale = Vector3(1.0, 0.62, 1.08)
			lame.add_child(dome)
			var rim := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = rr - 0.012
			tor.outer_radius = rr + 0.024
			tor.rings = 16
			tor.ring_segments = 5
			rim.mesh = tor
			rim.material_override = _bone if k == 0 else _gold
			rim.scale = Vector3(1.0, 1.0, 1.08)
			lame.add_child(rim)
			if k == 0:
				# Three bone spikes rising from the gold plate, gold at their tips.
				for q in 3:
					var sp := Node3D.new()
					sp.position = Vector3(sd * 0.03, 0.11, -0.1 + 0.1 * q)
					sp.rotation = Vector3((q - 1) * 0.25, 0, -sd * 0.25)
					lame.add_child(sp)
					var tall := 0.27 if q == 1 else 0.2
					U.cone(sp, 0.05, tall * 0.8, _bone, Vector3.ZERO, 0.02)
					U.cone(sp, 0.022, tall * 0.25, _gold, Vector3(0, tall * 0.8, 0))
				# A skull on the front of the gold plate, looking forward and a little up.
				var sk := skull(lame, 0.2, Vector3(sd * 0.02, 0.05, 0.25))
				sk.rotation = Vector3(-0.35, sd * 0.3, 0.0)
		_fx(p)


# ---------------------------------------------------------------- the crown of skulls

## The crown of skulls, in the head bone's space (`y` the top of the head; HeroStyle._extra).
static func crown(id: String, y: float) -> Node3D:
	_mats()
	var c := Node3D.new()
	c.name = "EmperorCrown"
	c.position = Vector3(0, 0, -0.06)
	var dome_r := 0.6 if id != "mage" else 0.54
	var dome_h := dome_r * (1.0 if id == "knight" else 0.88)
	var base := y - 0.2   # (where the coif sits, see HeroStyle.CAP_Y)
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = dome_r
	sm.height = dome_h
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 8
	cap.mesh = sm
	cap.material_override = _velvet
	cap.position = Vector3(0, base, 0)
	c.add_child(cap)
	var band_y := base + 0.1
	var r := dome_r * sqrt(1.0 - pow(0.1 / dome_h, 2.0)) + 0.03
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 0.97
	cyl.height = 0.17
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	band.mesh = cyl
	band.material_override = _gold
	band.position = Vector3(0, band_y, 0)
	c.add_child(band)
	# Five little skulls round the band, the front one biggest; gold spikes between them.
	for i in 5:
		var a := TAU * i / 5.0
		var out := Vector3(sin(a), 0, cos(a))
		var holder := Node3D.new()
		holder.position = out * (r + 0.03) + Vector3(0, band_y + 0.04, 0)
		holder.rotation.y = a
		c.add_child(holder)
		skull(holder, 0.3 if i == 0 else 0.24, Vector3.ZERO)
		var b := a + TAU / 10.0
		var spike := Node3D.new()
		spike.position = Vector3(sin(b), 0, cos(b)) * r + Vector3(0, band_y + 0.07, 0)
		spike.rotation.y = b
		c.add_child(spike)
		spike.rotate_object_local(Vector3.RIGHT, 0.18)
		U.cone(spike, 0.05, 0.3, _gold, Vector3.ZERO)
	# Two gold arches crossing over the cap, and a gold skull where they meet.
	var top := base + dome_h + 0.05
	for turn in [0.0, PI / 2.0]:
		var arch := MeshInstance3D.new()
		arch.mesh = _arch_mesh(r * 0.97, top - band_y)
		arch.material_override = _gold
		arch.position = Vector3(0, band_y, 0)
		arch.rotation.y = turn
		c.add_child(arch)
	skull(c, 0.24, Vector3(0, top + 0.1, 0.02), true, _gold)
	_fx(c)
	return c


static var _arches := {}

## A half-ellipse of gold tube over the cap, from -X to +X, `h` high.
static func _arch_mesh(r: float, h: float) -> Mesh:
	var key := "%.3f/%.3f" % [r, h]
	if _arches.has(key):
		return _arches[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var rad := []
	var gold := []
	for i in 15:
		var a := PI * i / 14.0
		pts.append(Vector3(-cos(a) * r, sin(a) * h, 0.0))
		rad.append(0.032)
		gold.append(1.0)
	_tube(st, pts, rad, gold, 6)
	var m := st.commit()
	_arches[key] = m
	return m


# ---------------------------------------------------------------- the bone throne

## The bone throne, its front towards -Z (the way the hero faces), its floor at y 0.
static func throne() -> Node3D:
	_mats()
	var t := Node3D.new()
	t.name = "BoneThrone"
	# The step: dark stone, edged in gold at the front.
	U.box(t, Vector3(1.9, 0.14, 1.3), _stone, Vector3(0, 0.07, 0.15))
	U.box(t, Vector3(1.92, 0.045, 0.05), _gold, Vector3(0, 0.15, -0.5))
	# The seat with a velvet cushion, a gold skull on its front.
	U.box(t, Vector3(1.25, 0.5, 0.78), _stone, Vector3(0, 0.39, 0.2))
	U.box(t, Vector3(1.16, 0.12, 0.7), _velvet, Vector3(0, 0.7, 0.2))
	U.box(t, Vector3(1.27, 0.05, 0.05), _gold, Vector3(0, 0.64, -0.19))
	skull(t, 0.26, Vector3(0, 0.42, -0.2), true, _gold)
	# The back: a velvet panel in a gold frame, and a fan of long bones rising behind it, each
	# topped with a skull; the middle one tallest, with the biggest skull.
	U.box(t, Vector3(1.2, 1.55, 0.08), _velvet, Vector3(0, 1.45, 0.55))
	for x in [-0.62, 0.62]:
		U.box(t, Vector3(0.06, 1.6, 0.1), _gold, Vector3(x, 1.45, 0.55))
	U.box(t, Vector3(1.3, 0.06, 0.1), _gold, Vector3(0, 2.24, 0.55))
	for i in 7:
		var k := (i - 3) / 3.0
		var top := Vector3(k * 0.95, 2.62 - absf(k) * 0.45, 0.62 + absf(k) * 0.05)
		long_bone(t, Vector3(k * 0.42, 0.66, 0.62), top, 0.055 if i != 3 else 0.07)
		skull(t, 0.42 if i == 3 else 0.27, top + Vector3(0, 0.14 if i == 3 else 0.1, -0.04), i == 3 or i % 2 == 0)
	# The armrests: a bone on two bone legs each side, a skull on a gold cap at the front.
	for sd in [-1.0, 1.0]:
		var x: float = sd * 0.72
		long_bone(t, Vector3(x, 0.92, -0.18), Vector3(x, 0.92, 0.5), 0.05)
		long_bone(t, Vector3(x, 0.14, -0.1), Vector3(x, 0.9, -0.1), 0.045)
		long_bone(t, Vector3(x, 0.14, 0.45), Vector3(x, 0.9, 0.45), 0.045)
		U.cylinder(t, 0.09, 0.05, _gold, Vector3(x, 0.94, -0.24))
		skull(t, 0.24, Vector3(x, 1.08, -0.26))
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return t
