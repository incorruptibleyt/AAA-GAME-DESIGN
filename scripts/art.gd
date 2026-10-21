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
	_cache[key] = scene
	return scene


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


## Hide parts of a model by node name (KayKit heroes come holding every weapon at once).
static func hide_parts(model: Node, names: Array) -> void:
	if model.name in names and model is Node3D:
		(model as Node3D).visible = false
	for c in model.get_children():
		hide_parts(c, names)


## Instance a model under `parent`, scaled so it is `height` tall and standing on the floor.
static func place_prop(scene: PackedScene, parent: Node3D, height: float) -> Node3D:
	var node := scene.instantiate() as Node3D
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
