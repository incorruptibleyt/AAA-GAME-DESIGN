class_name MageHood
extends Node3D
## The Shadow Hood (a Mage head look, hero_style.gd HEADS): a deep cloth cowl in the Mage's
## outfit colours that drapes onto the shoulders, with a peak falling back off the crown, a
## trim round the opening, and no face inside: only shadow and two eyes glowing in the
## hero's glow colour. Built in the head bone's space (the Mage's own head is hidden).

const SEGS := 40

static var _shader: Shader


## The hood in `cloth` with `trim` round the opening and `eyes` glowing inside.
static func make(cloth: Color, trim: Color, eyes: Color) -> MageHood:
	var h := MageHood.new()
	h.name = "MageHood"
	# Version 191 (Jesse: "Shadow hood looks like trash"): it was a near-black blob bigger
	# than the Mage's body. Now it is smaller, in the outfit's real colour with a lighter
	# crown, a smaller face opening, a trim seam over the top, and never a red-pink trim.
	if HeroStyle._reddish(trim):
		trim = Color(1.0, 0.78, 0.32)
	h._build(cloth, trim, eyes)
	h.scale = Vector3.ONE * 0.86
	h.position = Vector3(0, 0.03, 0)
	return h


func _build(cloth: Color, trim: Color, eyes: Color) -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("cloth", cloth)
	m.set_shader_parameter("trim", trim)
	var mi := MeshInstance3D.new()
	mi.mesh = _cowl()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# The shadow where the face would be: a dark egg that fills the opening.
	var void_mat := StandardMaterial3D.new()
	void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_mat.albedo_color = (cloth * 0.16).lerp(Color(0.05, 0.04, 0.12), 0.6)
	void_mat.albedo_color.a = 1.0
	var face := SphereMesh.new()
	face.radius = 0.46
	face.height = 0.92
	face.radial_segments = 16
	face.rings = 8
	var fm := MeshInstance3D.new()
	fm.mesh = face
	fm.material_override = void_mat
	fm.position = Vector3(0, 0.2, -0.04)
	fm.scale = Vector3(1.0, 1.0, 1.08)
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fm)
	# Two eyes, bright enough to read from the top-down camera, with a soft glow round them.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = eyes.lightened(0.35) * 1.6
	var halo := U.unlit(Color(eyes.r, eyes.g, eyes.b, 0.45)).duplicate()
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for side in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radius = 0.085
		e.height = 0.12
		e.radial_segments = 10
		e.rings = 5
		var em := MeshInstance3D.new()
		em.mesh = e
		em.material_override = eye_mat
		em.position = Vector3(side * 0.15, 0.22, 0.47)
		em.scale = Vector3(1.35, 0.6, 0.8)   # narrow and slanted: watchful, not cute
		em.rotation.z = side * -0.32
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(em)
		var g := SphereMesh.new()
		g.radius = 0.12
		g.height = 0.14
		g.radial_segments = 10
		g.rings = 5
		var gm := MeshInstance3D.new()
		gm.mesh = g
		gm.material_override = halo
		gm.position = em.position + Vector3(0, 0, 0.02)
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(gm)
		em.set_meta("fx", true)   # (v195) no rim light or white hit flash on the glowing parts
		gm.set_meta("fx", true)
	# Version 196: a long tail to the hood (a liripipe) that hangs down the back and ends in a
	# glowing tassel, and a thick rim of trim round the face. The run's camera looks down from
	# behind: the hood was a plain ball there, and the "third eye" painted on it in version
	# 195 read as a letter T. The tail changes the outline, and it points away from where the
	# hero faces, so it also shows which way that is.
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = cloth * 0.8
	tail_mat.albedo_color.a = 1.0
	tail_mat.roughness = 0.85
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = trim
	trim_mat.roughness = 0.5
	trim_mat.emission_enabled = true
	trim_mat.emission = trim
	trim_mat.emission_energy_multiplier = 0.35
	var pts := [Vector3(0, 0.74, -0.5), Vector3(0, 0.7, -0.95), Vector3(0, 0.42, -1.3), Vector3(0, 0.02, -1.42)]
	var radii := [0.3, 0.2, 0.13, 0.08]
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var cm := CylinderMesh.new()
		cm.top_radius = radii[i + 1]
		cm.bottom_radius = radii[i]
		cm.height = a.distance_to(b) + 0.04
		cm.radial_segments = 10
		cm.rings = 1
		var ti := MeshInstance3D.new()
		ti.mesh = cm
		ti.material_override = tail_mat
		ti.position = (a + b) * 0.5
		ti.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		ti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ti)
		if i > 0:
			var band := SphereMesh.new()   # a band of trim at each bend
			band.radius = float(radii[i]) * 1.18
			band.height = float(radii[i]) * 1.5
			band.radial_segments = 10
			band.rings = 5
			var bi := MeshInstance3D.new()
			bi.mesh = band
			bi.material_override = trim_mat
			bi.position = a
			bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bi)
	var tassel := SphereMesh.new()
	tassel.radius = 0.15
	tassel.height = 0.3
	tassel.radial_segments = 10
	tassel.rings = 6
	var ts := MeshInstance3D.new()
	ts.mesh = tassel
	ts.material_override = eye_mat
	ts.position = pts[3]
	ts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ts.set_meta("fx", true)
	add_child(ts)


## The cowl: cloth turned round the head from a side profile (the peak at the top falls
## back like a real hood's, it narrows at the neck and spreads over the shoulders), with the
## face opening cut by the shader, so its edge and trim are smooth at any size.
## Profile rows: [height, radius, how far back].
const PROFILE := [[0.84, 0.0, -0.95], [0.86, 0.13, -0.7], [0.82, 0.32, -0.38], [0.7, 0.5, -0.17],
	[0.52, 0.64, -0.08], [0.3, 0.68, -0.05], [0.08, 0.64, -0.03], [-0.12, 0.6, -0.02],
	[-0.26, 0.63, -0.02], [-0.37, 0.72, -0.03], [-0.46, 0.8, -0.05]]
const DEEP := 1.12   # front to back, the hood is deeper than it is wide


func _cowl() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []
	var n := PROFILE.size()
	var steps := 4   # rows between two profile rows, smoothed
	for i in (n - 1) * steps + 1:
		var f := float(i) / steps
		var a: int = mini(int(f), n - 2)
		var t := f - a
		var p0: Array = PROFILE[maxi(a - 1, 0)]
		var p1: Array = PROFILE[a]
		var p2: Array = PROFILE[a + 1]
		var p3: Array = PROFILE[mini(a + 2, n - 1)]
		var row := []
		for k in 3:
			row.append(_spline(p0[k], p1[k], p2[k], p3[k], t))
		rows.append(row)
	for i in rows.size():
		for j in SEGS + 1:
			var lon := float(j) / SEGS * TAU
			var y: float = rows[i][0]
			var r: float = rows[i][1]
			var pos := Vector3(sin(lon) * r, y, cos(lon) * r * DEEP + rows[i][2])
			# The face opening: an oval on the front, from the chin to the brow.
			var l := wrapf(lon, -PI, PI)
			var o := pow(l / 0.74, 2.0) + pow((y - 0.2) / 0.37, 2.0)
			st.set_uv(Vector2(o, float(i) / (rows.size() - 1)))
			st.set_uv2(Vector2(absf(sin(lon)) * r, 0.0))   # distance from the middle seam
			st.add_vertex(pos)
	for i in rows.size() - 1:
		for j in SEGS:
			var a := i * (SEGS + 1) + j
			var b := a + SEGS + 1
			for k in [a, a + 1, b, a + 1, b + 1, b]:
				st.add_index(k)
	st.generate_normals()
	return st.commit()


static func _spline(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


const CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth : source_color;
uniform vec4 trim : source_color;
varying vec2 around;
void vertex() {
	around = VERTEX.xz;   // (v196) the angle is taken per pixel: per vertex it wrapped into stripes at the back seam
}
void fragment() {
	// UV.x < 1 is the face opening; a band just outside it is the trim.
	if (UV.x < 1.0) {
		discard;
	}
	float edge = 1.0 - smoothstep(1.62, 1.72, UV.x);
	// A seam of trim over the top and down the back, and a hem round the bottom.
	float seam = (1.0 - smoothstep(0.05, 0.075, UV2.x)) * step(1.6, UV.x);
	edge = max(edge, max(seam, smoothstep(0.955, 0.965, UV.y)));
	// Cloth soaks up light (the game's lights are bright); the trim shines a little.
	vec3 c = mix(cloth.rgb * 0.95, trim.rgb, edge);
	// A little darker towards the bottom, so the drape reads as folded cloth.
	c *= mix(1.18, 0.74, UV.y);
	// (v195) Folds down the drape, deeper towards the hem: from the side it was a flat slab.
	c *= 1.0 - 0.2 * smoothstep(0.3, 0.9, UV.y) * (0.5 + 0.5 * sin(atan(around.x, around.y) * 11.0));
	// Outside: the cloth. Inside: deep shadow, so the opening looks deep.
	ALBEDO = FRONT_FACING ? c : c * 0.1;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.85;
	METALLIC = edge * 0.3;
	RIM = 0.12;
	RIM_TINT = 0.5;
}
"""
