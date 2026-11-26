class_name Art
## Finds KayKit models (glTF files) anywhere under res://art and hands them to the game.
## Upload the KayKit .zip files to the ArtZips folder on GitHub and the cloud build unpacks
## them into res://art/kaykit. Anything missing falls back to the built-in placeholder shapes.

const KNIGHT := "Knight"
const ROGUE := "Rogue_Hooded"
const RANGER := "Ranger"
const SKELETON_MINION := "Skeleton_Minion"
const SKELETON_WARRIOR := "Skeleton_Warrior"
const SKELETON_ROGUE := "Skeleton_Rogue"
const SKELETON_MAGE := "Skeleton_Mage"
const SKELETON_GOLEM := "Skeleton_Golem"
const PILLAR := "pillar"
const BARREL := "barrel_large"
const CRATES := "crates_stacked"
const TORCH := "torch_mounted"

## File-name alternatives, best first (KayKit renamed some files between versions).
const ALIASES := {
	"Rogue_Hooded": ["Rogue_Hooded", "Rogue"],
	"barrel_large": ["barrel_large", "barrel"],
	"crates_stacked": ["crates_stacked", "box_stacked", "crate"],
	"torch_mounted": ["torch_mounted", "torch_lit", "torch"],
	"Skeleton_Golem": ["Skeleton_Golem", "Golem"],
}

static var _index := {}       # lower-case file name (no extension) -> res path
static var _scanned := false
static var _cache := {}


static func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if not f.begins_with("."):
				_scan(dir_path.path_join(f))
		else:
			# In an exported app the originals are listed as "<name>.import".
			var file := f.trim_suffix(".import")
			var ext := file.get_extension().to_lower()
			if ext == "gltf" or ext == "glb":
				# Some KayKit files are named like "pillar.gltf.glb".
				var key := file.get_basename().trim_suffix(".gltf").to_lower()
				if not _index.has(key) or ext == "glb":
					_index[key] = dir_path.path_join(file)
		f = dir.get_next()


static func get_model(key: String) -> PackedScene:
	if not _scanned:
		_scanned = true
		_scan("res://art")
	if _cache.has(key):
		return _cache[key]
	var scene: PackedScene = null
	for name in ALIASES.get(key, [key]):
		var path: String = _index.get(String(name).to_lower(), "")
		if path != "" and ResourceLoader.exists(path):
			scene = load(path) as PackedScene
			if scene:
				break
	if scene:
		_share_textures(scene)
	_cache[key] = scene
	return scene


## KayKit gives every model file its own copy of its pack's colour texture: the 14 dungeon
## props all carry the same 1024 px picture, and so do the 5 skeleton files. Each copy took
## about 5 MB of graphics memory (over 90 MB in all), enough to run cheap phones out of
## memory. Point every material at one copy, so the others are freed.
## The copy named here is the one imported "VRAM compressed" (ETC2 on phones): about 0.7 MB
## of graphics memory instead of 5.6, with colours within 8/255 of the original. Only these
## (and the 4 hero textures) are compressed, so the download doesn't carry 23 big copies.
const SHARED_TEXTURES := {
	"dungeon_texture.png": "res://art/kaykit/dungeon/wall_dungeon_texture.png",
	"skeleton_texture.png": "res://art/kaykit/weapons/skeleton_texture.png",
}
static var _shared := {}


static func _share_textures(scene: PackedScene) -> void:
	var root := scene.instantiate()
	_share_in(root)
	root.free()


static func _share_in(n: Node) -> void:
	var mi := n as MeshInstance3D
	if mi:
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				_share_material(m)
				var bone := _bone_material(m)
				if bone:
					mi.mesh.surface_set_material(i, bone)
		_share_material(mi.material_override)
	for c in n.get_children():
		_share_in(c)


static func _share_material(m: Material) -> void:
	var bm := m as BaseMaterial3D
	if bm == null or bm.albedo_texture == null:
		return
	var tex := bm.albedo_texture
	var file := tex.resource_path.get_file().to_lower()
	for k: String in SHARED_TEXTURES:
		if file.ends_with(k):
			var first: Texture2D = _shared.get(k)
			if first == null:
				var path: String = SHARED_TEXTURES[k]
				if ResourceLoader.exists(path):
					first = load(path) as Texture2D
				if first == null or first.get_size() != tex.get_size():
					first = tex   # the named copy is missing: share the first one met instead
				_shared[k] = first
			if first != tex and first.get_size() == tex.get_size():
				bm.albedo_texture = first
			return


## Version 367 (visual review of 366, fix 1): the skeletons' bone (bodies and their
## weapons, all on the one skeleton texture) blew out to flat white under the room lights and
## glow, so a crowd was one white blob. Their own material now keeps the bone a little darker,
## with soft shine, and inks the edges that turn away from the camera: each skull and rib cage
## keeps its shape, and overlapping skeletons split apart. It replaces the material (no extra
## pass), so it costs nothing per skeleton.
const BONE_TONE := 0.8
const BONE_INK := 0.62
static var _bone_shader: Shader
static var _bone_mats := {}
static var _bone_src := {}

static func _bone_material(m: Material) -> Material:
	var bm := m as BaseMaterial3D
	if bm == null or bm.albedo_texture == null:
		return null
	if not bm.albedo_texture.resource_path.get_file().to_lower().ends_with("skeleton_texture.png"):
		return null
	if _bone_mats.has(bm):
		return _bone_mats[bm]
	if _bone_shader == null:
		_bone_shader = Shader.new()
		_bone_shader.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tone = 0.8;
uniform float ink = 0.62;
void fragment() {
	vec3 c = texture(tex, UV).rgb * tint.rgb * tone;
	// Edges turning away from the camera go dark, like a soft cartoon line.
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	c *= 1.0 - ink * smoothstep(0.5, 0.95, edge);
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _bone_shader
	sm.set_shader_parameter("tex", bm.albedo_texture)
	sm.set_shader_parameter("tint", bm.albedo_color)
	sm.set_shader_parameter("tone", BONE_TONE)
	sm.set_shader_parameter("ink", BONE_INK)
	_bone_mats[bm] = sm
	_bone_src[sm] = bm
	return sm


## Version 376 (visual review of 375, fix 1): skulls. Seen from above, a skeleton's head
## was the back of a smooth, plain cranium: the biggest, brightest, emptiest shape on screen,
## the same on every kind, so a crowd was a clump of white balls and swallowed the hero. A
## bare head (the KayKit "_Head" / "_Skull" mesh) now gets its own material: old ivory that
## darkens toward the back and sides, one dark crack across the crown, and a painted band
## round the brow in the skeleton kind's own colour, so a crowd reads as many different
## skulls. (Stripes and seams over the crown were tried first: from above they read as
## watermelons.) The pattern sits on the skull's rest shape (stored in the
## vertex colours of a copy of the head mesh), so it stays put while the head moves.
const SKULL_PAINT_MIX := 0.62
static var _skull_shader: Shader
static var _skull_meshes := {}
static var _skull_mats := {}


static func is_skull_mesh(mi: MeshInstance3D) -> bool:
	var n := String(mi.name)
	return n.ends_with("_Head") or n.ends_with("_Skull")


## A copy of a skull mesh whose vertex colours hold each vertex's rest position, scaled into
## the head's box (0..1), for the skull shader's pattern. One copy per head mesh.
static func skull_mesh(mesh: Mesh) -> Mesh:
	if _skull_meshes.has(mesh):
		return _skull_meshes[mesh]
	var out := ArrayMesh.new()
	var box := mesh.get_aabb()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for v in verts.size():
			var q := (verts[v] - box.position) / box.size
			cols[v] = Color(q.x, q.y, q.z, 1.0)
		arrays[Mesh.ARRAY_COLOR] = cols
		var fmt: int = mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		out.surface_set_material(i, mesh.surface_get_material(i))
	_skull_meshes[mesh] = out
	return out


## The skull material for one skeleton kind: `paint` is that kind's colour.
static func skull_material(base: Material, paint: Color) -> Material:
	var key := "%s|%s" % [base.get_instance_id(), paint.to_html()]
	if _skull_mats.has(key):
		return _skull_mats[key]
	var bm := base_material(base)
	if bm == null or bm.albedo_texture == null:
		return base
	if _skull_shader == null:
		_skull_shader = Shader.new()
		_skull_shader.code = """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 paint : source_color = vec4(0.5, 0.8, 0.4, 1.0);
uniform float tone = 0.8;
uniform float ink = 0.62;
uniform float paint_mix = 0.72;
varying vec3 rest;
void vertex() {
	rest = COLOR.rgb * 2.0 - 1.0;   // -1..1 across the head's box; +z is the face
}
float seam(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w, abs(d));
}
void fragment() {
	vec3 c = texture(tex, UV).rgb * tint.rgb * tone;
	vec3 p = rest;
	// Version 384 (review of v383, fix 1): bone, not bread. The warm ivory and the coloured
	// band round the brow read as a burger bun from the run camera, so the skull is a cooler,
	// greyer bone, shaded darker toward the back and down the sides like a real cranium.
	c *= vec3(0.93, 0.92, 0.88);
	float back = smoothstep(0.2, -0.9, p.z);
	float low = smoothstep(0.1, -0.7, p.y);
	c *= 1.0 - 0.36 * back - 0.3 * low;
	// The kind's colour is a small glowing rune on the forehead (a diamond), seen from above.
	float rune_d = abs(p.x) * 1.25 + abs(p.y - 0.34) - 0.17;
	float front = smoothstep(0.05, 0.35, p.z);
	float rune = (1.0 - smoothstep(0.0, 0.05, rune_d)) * front;
	float rune_core = (1.0 - smoothstep(-0.1, -0.05, rune_d)) * front;
	c = mix(c, vec3(0.1, 0.07, 0.08), rune * paint_mix);
	c = mix(c, paint.rgb, rune_core * paint_mix);
	// One thin old crack across the crown.
	float crown = smoothstep(0.1, 0.4, p.y);
	float k1 = seam(p.x - 0.18 + 0.35 * p.z + 0.07 * sin(p.z * 17.0), 0.045) * crown * smoothstep(0.75, 0.35, p.z) * smoothstep(-0.7, -0.3, p.z);
	c = mix(c, vec3(0.22, 0.17, 0.15), clamp(k1, 0.0, 1.0) * 0.55);
	EMISSION = paint.rgb * rune_core * paint_mix * 0.9;
	// Edges turning away from the camera go dark, like a soft cartoon line.
	float edge = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	c *= 1.0 - ink * smoothstep(0.5, 0.95, edge);
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _skull_shader
	sm.set_shader_parameter("tex", bm.albedo_texture)
	sm.set_shader_parameter("tint", bm.albedo_color)
	sm.set_shader_parameter("tone", BONE_TONE)
	sm.set_shader_parameter("ink", BONE_INK)
	sm.set_shader_parameter("paint", paint)
	sm.set_shader_parameter("paint_mix", SKULL_PAINT_MIX)
	_skull_mats[key] = sm
	_bone_src[sm] = bm
	return sm


## Give every bare skull under `model` the skull look in the kind's colour (see above).
static func dress_skulls(model: Node, paint: Color) -> void:
	var mi := model as MeshInstance3D
	if mi and mi.visible and mi.mesh and is_skull_mesh(mi):
		var base := mi.mesh.surface_get_material(0)
		if _bone_src.has(base) or _bone_material(base) != null:
			mi.mesh = skull_mesh(mi.mesh)
			for i in mi.mesh.get_surface_count():
				mi.set_surface_override_material(i, skull_material(mi.mesh.surface_get_material(i), paint))
	for c in model.get_children():
		dress_skulls(c, paint)


## The plain material a bone material was made from (for code that dyes weapons).
static func base_material(m: Material) -> BaseMaterial3D:
	return _bone_src.get(m, m as BaseMaterial3D)


static func has_model(key: String) -> bool:
	return get_model(key) != null


## Hold a KayKit weapon (or shield) in a character's hand. `side` is "r" or "l".
static func attach_to_bone(model: Node, bone: String, scene_key: String) -> Node3D:
	var scene := get_model(scene_key)
	var skel := _find_skeleton(model)
	if scene == null or skel == null or skel.find_bone(bone) < 0:
		return null
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = bone
	var item := scene.instantiate() as Node3D
	att.add_child(item)
	if scene_key == "Skeleton_Staff":
		item.rotation.x = PI   # the staff file points down from the hand; hold it skull-up
	return item


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null


## Godot 4.7 imports KayKit meshes without a link to their skeleton, so they would stand
## frozen in a T-pose while the bones animate. Link every skinned mesh to the skeleton
## it sits under.
static func bind_skins(n: Node) -> void:
	if n is MeshInstance3D and n.get_parent() is Skeleton3D and (n as MeshInstance3D).skeleton.is_empty():
		(n as MeshInstance3D).skeleton = NodePath("..")
	for c in n.get_children():
		bind_skins(c)


## Hide parts of a model by node name (KayKit heroes come holding every weapon at once).
static func hide_parts(model: Node, names: Array) -> void:
	if model.name in names and model is Node3D:
		(model as Node3D).visible = false
	for c in model.get_children():
		hide_parts(c, names)


## Instance a model under `parent`, scaled so it is `height` tall and standing on the floor.
static func place_prop(scene: PackedScene, parent: Node3D, height: float) -> Node3D:
	var node := scene.instantiate() as Node3D
	bind_skins(node)
	parent.add_child(node)
	fit_height(node, height)
	return node


static func fit_height(node: Node3D, height: float) -> void:
	node.transform = Transform3D.IDENTITY
	var box := _bounds(node, Transform3D.IDENTITY)
	if box.size.y > 0.01:
		var s := height / box.size.y
		node.scale = Vector3.ONE * s
		node.position.y -= box.position.y * s


## The widest side of a placed model, in metres, as it stands.
static func width_of(node: Node3D) -> float:
	var box := _bounds(node, Transform3D.IDENTITY)
	return maxf(box.size.x, box.size.z)


static func _bounds(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	var t := xf
	if node is Node3D:
		t = xf * (node as Node3D).transform
	if node is VisualInstance3D:
		var b: AABB = t * (node as VisualInstance3D).get_aabb()
		result = b
		first = false
	for c in node.get_children():
		var cb := _bounds(c, t)
		if cb.size != Vector3.ZERO:
			result = cb if first else result.merge(cb)
			first = false
	return result
