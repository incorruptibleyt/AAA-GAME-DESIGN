class_name FungalLook
## The Glowcap Grotto's skeletons (the Sporeling, the Rootbinder and the Sporemother): bones
## grown over with dusky moss, dotted with little glowing fungus spots that pulse pink and
## lime, drawn over a model as its overlay. Kept apart from the skeletons (like WetLook) so
## the store art tool can use it without the running game.

## One material per glow strength.
static var _mats := {}


## Moss patches darken the bones a little; then glowing spots (in the moss) and a soft rim,
## pink unless `rim` says otherwise (the Rootbinder's is lime). `glow` lifts the whole body
## towards the rim colour (the Sporemother is big and needs to stand out on the floor).
static func overlay(glow := 0.0, rim := Color(1.0, 0.36, 0.78)) -> ShaderMaterial:
	var key := "%.2f/%s" % [glow, rim.to_html()]
	if _mats.has(key):
		return _mats[key]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float vn(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void fragment() {
	// Multiplied in linear light: the moss stays light so the bones still read as bones.
	float moss = smoothstep(0.5, 0.72, vn(p * 4.5) * 0.7 + vn(p * 10.0) * 0.3);
	ALBEDO = mix(vec3(0.97, 0.94, 1.0), vec3(0.6, 0.55, 0.72), moss);
}
"""
	var spots := Shader.new()
	spots.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 pink : source_color = vec4(1.0, 0.36, 0.78, 1.0);
uniform vec4 lime : source_color = vec4(0.72, 1.0, 0.3, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.36, 0.78, 1.0);
uniform float glow = 0.0;
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
void fragment() {
	// Little round spots: one in some cells of a 3D grid, each pulsing at its own pace.
	vec3 q = p * 7.0;
	vec3 c = floor(q);
	float r = h(c);
	vec3 centre = c + 0.5 + (vec3(h(c + 1.3), h(c + 2.7), h(c + 4.1)) - 0.5) * 0.5;
	float d = length(q - centre);
	float spot = (1.0 - smoothstep(0.16, 0.3, d)) * step(0.55, r);
	float pulse = 0.55 + 0.45 * sin(TIME * (1.6 + r * 1.4) + r * 40.0);
	vec3 col = mix(pink.rgb, lime.rgb, step(0.82, r));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	ALBEDO = col * spot * pulse * 1.3 + rim_col.rgb * (rim * 0.4 + glow * 0.4);
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	m.render_priority = 1
	var glowing := ShaderMaterial.new()
	glowing.shader = spots
	glowing.render_priority = 2
	glowing.set_shader_parameter("glow", glow)
	glowing.set_shader_parameter("rim_col", rim)
	m.next_pass = glowing
	_mats[key] = m
	return m


static var _cap_mats := {}
static var _caps := {}


static func _own(color: Color, roughness: float, glow: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	return m


## A mushroom's materials: [cap top (glowing pink), gills underneath, lime spots, stem].
## Shared by every Sporeling, the Sporemother and the grotto's props, so there is only one
## of each to prepare.
static func cap_materials() -> Array:
	if _cap_mats.is_empty():
		_cap_mats["top"] = _own(Color(0.95, 0.32, 0.7), 0.45, Color(1.0, 0.3, 0.72), 0.75)
		_cap_mats["gills"] = _own(Color(0.42, 0.2, 0.44), 0.8, Color(0.7, 0.25, 0.6), 0.45)
		_cap_mats["spot"] = _own(Color(0.82, 1.0, 0.45), 0.5, Color(0.72, 1.0, 0.3), 1.8)
		_cap_mats["stem"] = _own(Color(0.9, 0.86, 0.78), 0.75, Color(1.0, 0.8, 0.95), 0.08)
	return [_cap_mats["top"], _cap_mats["gills"], _cap_mats["spot"], _cap_mats["stem"]]


## One mushroom cap, `radius` across the middle: a flattened dome with gills underneath and
## lime spots on top, baked into one mesh (one surface per material) and kept for reuse.
## The cap's middle is at the origin; the dome rises from y = 0.
static func cap_mesh(radius: float, spots := 5) -> ArrayMesh:
	var key := "%.3f/%d" % [radius, spots]
	if _caps.has(key):
		return _caps[key]
	var mats := cap_materials()
	var parts := []
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 5
	parts.append([dome, Transform3D(Basis.from_scale(Vector3(radius, radius * 0.85, radius)), Vector3.ZERO), mats[0]])
	var under := CylinderMesh.new()
	under.top_radius = radius * 0.98
	under.bottom_radius = radius * 0.32
	under.height = radius * 0.18
	under.radial_segments = 16
	under.rings = 1
	parts.append([under, Transform3D(Basis.IDENTITY, Vector3(0, -radius * 0.09, 0)), mats[1]])
	var bump := SphereMesh.new()
	bump.radius = 1.0
	bump.height = 2.0
	bump.radial_segments = 8
	bump.rings = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 1000.0) + spots
	for i in spots:
		var a := i / float(spots) * TAU + rng.randf() * 0.6
		var up := rng.randf_range(0.4, 0.75)
		var flat := sqrt(1.0 - up * up)
		var at := Vector3(cos(a) * flat * radius, up * radius * 0.85, sin(a) * flat * radius)
		# Bigger spots on small caps, so a Sporeling's still read on a phone.
		var s := radius * rng.randf_range(0.12, 0.17) * clampf(0.5 / radius, 1.0, 1.4)
		parts.append([bump, Transform3D(Basis.from_scale(Vector3(s, s * 0.55, s)), at), mats[2]])
	parts.append([bump, Transform3D(Basis.from_scale(Vector3(radius * 0.17, radius * 0.07, radius * 0.17)), Vector3(0, radius * 0.84, 0)), mats[2]])
	_caps[key] = Props._bake(parts)
	return _caps[key]


## A whole mushroom (stem and cap) baked into one mesh: `h` tall to the top of its cap,
## leaning `lean` radians towards +X. Its foot is at the origin.
static func mushroom_parts(h: float, cap_r: float, lean: float, at: Vector3, turn: float, spots := 5) -> Array:
	var mats := cap_materials()
	var b := Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, -lean)
	var stem_h := h - cap_r * 0.6
	var stem := CylinderMesh.new()
	stem.top_radius = cap_r * 0.22
	stem.bottom_radius = cap_r * 0.32
	stem.height = 1.0
	stem.radial_segments = 8
	stem.rings = 1
	var parts := []
	parts.append([stem, Transform3D(b * Basis.from_scale(Vector3(1, stem_h, 1)), at + b * Vector3(0, stem_h * 0.5, 0)), mats[3]])
	var cap := cap_mesh(cap_r, spots)
	for si in cap.get_surface_count():
		parts.append([_surface_mesh(cap, si), Transform3D(b, at + b * Vector3(0, stem_h, 0)), cap.surface_get_material(si)])
	return parts


## One surface of a baked mesh as a mesh of its own (so it can be baked again with others).
static func _surface_mesh(m: ArrayMesh, surface: int) -> ArrayMesh:
	var key := "s%d/%d" % [m.get_instance_id(), surface]
	if _caps.has(key):
		return _caps[key]
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(surface))
	_caps[key] = out
	return out
