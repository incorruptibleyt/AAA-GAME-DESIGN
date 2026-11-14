class_name U
## Small helpers for building the game world from code: materials, simple shapes and
## generated textures. Because everything is made here, the game runs with no art imported.

static var _mat_cache := {}
static var _soft_circle: ImageTexture
static var _ring: ImageTexture
static var _glint: ImageTexture
static var _dot: ImageTexture
static var _noise_cache := {}


## `x` rounded up or down at random, in proportion (2.3 is 3 three times in ten), so many
## small amounts add up to the right total.
static func round_random(x: float) -> int:
	var whole := floori(x)
	return whole + (1 if randf() < x - whole else 0)


## Shuffle `list` in place with `rng`, like Array.shuffle (the Daily Crypt's rng is seeded).
static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t


## A solid, lit material. Emission above zero makes it glow (eyes, flames, bolts).
static func mat(color: Color, roughness := 0.8, emission := 0.0) -> StandardMaterial3D:
	var key := "L%s%.2f%.2f" % [color.to_html(), roughness, emission]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


## Unlit and see-through: warning markers, health bars, particles.
static func unlit(color: Color, tex: Texture2D = null, billboard := false) -> StandardMaterial3D:
	var key := "U%s%s%s" % [color.to_html(), str(tex.get_instance_id()) if tex else "", billboard]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	if tex:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	_mat_cache[key] = m
	return m


static func _place(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Shapes of the same kind and size share one mesh (coins and hearts used to build 2-4
## new meshes per drop). Nothing may change a mesh from these helpers afterwards: duplicate
## it first (hero_stage.gd does). Past MESH_CACHE_MAX sizes, new sizes just aren't kept.
const MESH_CACHE_MAX := 512
static var _mesh_cache := {}


static func _cached(key: String, make: Callable) -> Mesh:
	var m: Mesh = _mesh_cache.get(key)
	if m == null:
		m = make.call()
		if _mesh_cache.size() < MESH_CACHE_MAX:
			_mesh_cache[key] = m
	return m


static func box(parent: Node3D, size: Vector3, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := _cached("box%.3f/%.3f/%.3f" % [size.x, size.y, size.z], func():
		var b := BoxMesh.new()
		b.size = size
		return b)
	return _place(parent, m, material, pos)


## A cylinder standing on the ground at `base`.
static func cylinder(parent: Node3D, radius: float, height: float, material: Material, base := Vector3.ZERO) -> MeshInstance3D:
	var m := _cached("cyl%.3f/%.3f" % [radius, height], func():
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		c.radial_segments = 16
		return c)
	return _place(parent, m, material, base + Vector3.UP * height * 0.5)


static func sphere(parent: Node3D, radius: float, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := _cached("sph%.3f" % radius, func():
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius * 2.0
		s.radial_segments = 16
		s.rings = 8
		return s)
	return _place(parent, m, material, pos)


static func capsule(parent: Node3D, radius: float, height: float, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := _cached("cap%.3f/%.3f" % [radius, height], func():
		var c := CapsuleMesh.new()
		c.radius = radius
		c.height = max(height, radius * 2.0)
		c.radial_segments = 16
		c.rings = 6
		return c)
	return _place(parent, m, material, pos)


## A flat square lying on the floor.
static func floor_quad(parent: Node3D, size: Vector2, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := _cached("quad%.3f/%.3f" % [size.x, size.y], func():
		var q := PlaneMesh.new()
		q.size = size
		return q)
	var mi := _place(parent, m, material, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- generated textures

static func soft_circle() -> ImageTexture:
	if _soft_circle:
		return _soft_circle
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_soft_circle = ImageTexture.create_from_image(img)
	return _soft_circle


## A four-pointed star with a round heart (Master aura sparkles: Fx.motif).
static func glint() -> ImageTexture:
	if _glint:
		return _glint
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0) / (n / 2.0)
			var heart := clampf((0.2 - p.length()) / 0.08, 0.0, 1.0)
			# Thin rays along the two axes, tapering to the tips.
			var ray := maxf(clampf(1.0 - absf(p.x) / maxf(0.02, 0.09 * (1.0 - absf(p.y))), 0.0, 1.0) * (1.0 - absf(p.y)),
				clampf(1.0 - absf(p.y) / maxf(0.02, 0.09 * (1.0 - absf(p.x))), 0.0, 1.0) * (1.0 - absf(p.x)))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(heart, ray * 1.6), 0.0, 1.0)))
	_glint = ImageTexture.create_from_image(img)
	return _glint


## A small round spark with a crisp edge (embers).
static func dot() -> ImageTexture:
	if _dot:
		return _dot
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) / 0.25, 0.0, 1.0)))
	_dot = ImageTexture.create_from_image(img)
	return _dot


## A filled disc with a bright rim, for "danger here" circles.
static func ring() -> ImageTexture:
	if _ring:
		return _ring
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var fill := 0.3 if d < 1.0 else 0.0
			var rim := clampf(1.0 - absf(d - 0.93) / 0.07, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(fill, rim)))
	_ring = ImageTexture.create_from_image(img)
	return _ring


## A tiling grey noise for shaders (the room floor uses three): bigger frequency means
## smaller blobs. Made once per kind and kept.
static func noise_tex(frequency: float, noise_seed: int, octaves := 3) -> ImageTexture:
	var key := "%s/%d/%d" % [frequency, noise_seed, octaves]
	if _noise_cache.has(key):
		return _noise_cache[key]
	var fn := FastNoiseLite.new()
	fn.frequency = frequency
	fn.seed = noise_seed
	fn.fractal_octaves = octaves
	var img := fn.get_seamless_image(256, 256)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_noise_cache[key] = tex
	return tex
