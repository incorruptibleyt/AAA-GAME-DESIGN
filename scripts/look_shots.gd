class_name LookShots
extends Node
## Version 340 (visual review fix 5, "real pictures of looks"): a small 3D picture of a look,
## taken by the game itself: the hero in their classic look wearing just that one outfit,
## headwear, weapon, glow or aura, framed on what changes (the head for headwear, the hands
## for a weapon, the whole hero for the rest). The Style cards showed flat drawn symbols
## (a circle with two colours for every outfit) before.
##
## One hidden SubViewport takes the pictures one at a time, a frame or two each, in the
## order asked. Each picture is kept in memory (the most recent MEM_MAX) and saved as a PNG
## under user://look_shots/<build>/, so the next opening shows it at once. A picture that
## comes out blank (a phone whose graphics chip draws nothing into a hidden viewport) is
## thrown away and the card keeps its drawn symbol.

const SIZE := Vector2i(224, 224)   # the kept picture; drawn at twice this and shrunk, for smooth edges
const DRAW := 2
const MEM_MAX := 100
const DIR := "user://look_shots"

static var _me: LookShots

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _ring: MeshInstance3D
var _queue: Array = []   # [key, def, slot, Callable]
var _waiting := {}   # key -> Array of Callables
var _mem := {}   # key -> ImageTexture
var _order: Array = []   # keys, oldest first
var _busy := false
var _blank := 0   # pictures that came out blank; after 3 the shots stop for this session


## Asks for the picture of hero `id` wearing `key` in `slot`; `done` is called with the
## texture (at once if it is ready). Nothing is called if the picture can't be taken.
static func want(id: String, slot: String, key: String, done: Callable) -> void:
	if _me == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		_me = LookShots.new()
		tree.root.add_child.call_deferred(_me)
	_me._want(id, slot, key, done)


static func shot_key(id: String, slot: String, key: String) -> String:
	return "%s_%s_%s" % [id, slot, key if key != "" else "classic"]


func _want(id: String, slot: String, key: String, done: Callable) -> void:
	var k := shot_key(id, slot, key)
	if _mem.has(k):
		_touch(k)
		done.call(_mem[k])
		return
	var path := _path(k)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			_keep(k, ImageTexture.create_from_image(img))
			done.call(_mem[k])
			return
	if _blank >= 3:
		return
	if _waiting.has(k):
		_waiting[k].append(done)
		return
	_waiting[k] = [done]
	var base := Heroes.get_hero(id)
	if base.is_empty():
		return
	var def := HeroStyle.dressed(base, {slot: key})
	_queue.append([k, def, slot])


func _path(k: String) -> String:
	return "%s/%s/%s.png" % [DIR, Game.BUILD, k.validate_filename()]


func _keep(k: String, tex: ImageTexture) -> void:
	_mem[k] = tex
	_touch(k)
	while _order.size() > MEM_MAX:
		_mem.erase(_order.pop_front())


func _touch(k: String) -> void:
	_order.erase(k)
	_order.append(k)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE * DRAW
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.74)
	env.ambient_light_energy = 0.75
	_cam.environment = env
	_vp.add_child(_cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-30), 0)
	key.light_energy = 1.35
	key.light_color = Color(1.0, 0.93, 0.82)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()   # a cool light from behind, so the edges show on a dark card
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(160), 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.7, 0.8, 1.0)
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_pivot.rotation.y = HeroStage.FRONT
	_vp.add_child(_pivot)
	# A glow's ring of light at the feet, as on the pedestal and in a run.
	_ring = LookFx.ring(Color.WHITE, null, "flow", 1.5, 0.52)
	_ring.position = Vector3(0, 0.02, 0)
	_vp.add_child(_ring)
	# Old builds' pictures are stale (a look may have changed): only this build's are kept.
	var d := DirAccess.open(DIR)
	if d:
		for sub in d.get_directories():
			if sub != Game.BUILD:
				_wipe(DIR.path_join(sub))
	DirAccess.make_dir_recursive_absolute(DIR.path_join(Game.BUILD))


static func _wipe(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty() or _vp == null:
		return
	_busy = true
	_take(_queue.pop_front())


func _take(job: Array) -> void:
	var k: String = job[0]
	var def: Dictionary = job[1]
	var slot: String = job[2]
	var v := CharacterVisual.new()
	v.outline_me = true
	v.aura_boost = 1.8
	_pivot.add_child(v)
	v.build(Heroes.look(def, true))
	if def.has("aura") and slot == "aura":
		v.add_child(LookFx.aura_fx(def.aura, true))
	v.attack(def.id == "mage")
	if v._anim:
		v._anim.advance(0.0)
	var col: Color = def.ring
	_ring.visible = slot in ["glow", "aura", "outfit"]
	LookFx.set_ring(_ring.material_override, col, def.get("ring2"), str(def.get("ring_fx", "flow")), int(def.get("ring_tier", 0)))
	var f := _frame(slot, v, def)
	_cam.transform = Transform3D(Basis.looking_at(f[1] - f[0]), f[0])
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	v.queue_free()
	var cbs: Array = _waiting.get(k, [])
	_waiting.erase(k)
	_busy = false
	if img == null or img.is_empty() or _empty(img):
		_blank += 1
		return
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(_path(k))
	var tex := ImageTexture.create_from_image(img)
	_keep(k, tex)
	for cb: Callable in cbs:
		if cb.is_valid():
			cb.call(tex)


## Where the camera stands and what it looks at, for each slot. A weapon is looked at from
## the side it is held on; anything worn on the head from close up.
func _frame(slot: String, v: CharacterVisual, def: Dictionary) -> Array:
	var tall := false
	var extras: Array = def.get("style", {}).get("extras", [])
	for x in ["crown", "crypt_crown", "storm_halo", "flame_crown", "antlers", "phantom_horns", "bone_crown", "star_circlet", "moon_crown", "candle_crown", "halo", "horns", "starfall_crown", "emperor_crown"]:
		tall = tall or extras.has(x)
	match slot:
		"head":
			var y := 1.72 if tall else 1.55
			return [Vector3(0.0, y + 0.25, 3.3 if tall else 2.9), Vector3(0, y, 0)]
		"hold":
			var wide := false
			for n in v.find_children("2H_*", "MeshInstance3D", true, false):
				if str(n.name) in ["2H_Sword", "2H_Axe"] and (n as Node3D).is_visible_in_tree():
					wide = true
			if wide:
				return [Vector3(-0.55, 1.35, 4.6), Vector3(-0.5, 0.95, 0)]
			return [Vector3(0.2, 1.2, 3.0), Vector3(-0.05, 0.95, 0)]
		"aura":
			return [Vector3(0, 2.3, 5.4), Vector3(0, 0.75, 0)]
	return [Vector3(0, 1.4, 4.9), Vector3(0, 0.9, 0)]


## True when (almost) nothing was drawn: fewer than 2% of the pixels are seen.
static func _empty(img: Image) -> bool:
	var seen := 0
	var step := 4
	var n := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			n += 1
			if img.get_pixel(x, y).a > 0.3:
				seen += 1
	return seen < n * 0.02
