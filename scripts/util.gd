class_name U
## Small helpers for building the game world from code: materials, simple shapes and
## generated textures. Because everything is made here, the game runs with no art imported.

static var _mat_cache := {}
static var _soft_circle: ImageTexture
static var _ring: ImageTexture
static var _stone: ImageTexture


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


static func box(parent: Node3D, size: Vector3, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _place(parent, m, material, pos)


## A cylinder standing on the ground at `base`.
static func cylinder(parent: Node3D, radius: float, height: float, material: Material, base := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	return _place(parent, m, material, base + Vector3.UP * height * 0.5)


static func sphere(parent: Node3D, radius: float, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	return _place(parent, m, material, pos)


static func capsule(parent: Node3D, radius: float, height: float, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = max(height, radius * 2.0)
	m.radial_segments = 16
	m.rings = 6
	return _place(parent, m, material, pos)


## A flat square lying on the floor.
static func floor_quad(parent: Node3D, size: Vector2, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := PlaneMesh.new()
	m.size = size
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


## Flagstone floor: 4x4 slabs with dark grout and gentle colour variation.
static func stone() -> ImageTexture:
	if _stone:
		return _stone
	var n := 256
	var slabs := 4
	var s := n / slabs
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tint := []
	for i in slabs * slabs:
		tint.append(0.85 + rng.randf() * 0.3)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var base := Color(0.36, 0.33, 0.38)
	for y in n:
		for x in n:
			var lx := x % s
			var ly := y % s
			var edge := mini(mini(lx, s - 1 - lx), mini(ly, s - 1 - ly))
			var grout := 0.35 if edge < 2 else (0.75 if edge < 4 else 1.0)
			var nz := 0.88 + noise.get_noise_2d(x, y) * 0.2
			var c: Color = base * tint[(y / s) * slabs + (x / s)] * nz * grout
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_stone = ImageTexture.create_from_image(img)
	return _stone
