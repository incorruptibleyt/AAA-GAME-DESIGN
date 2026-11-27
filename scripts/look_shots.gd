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
var _stage: Node3D   # (the pivot's parent, as on a HeroStage: a Legend throne stands on it)
var _pivot: Node3D
var _ring: MeshInstance3D
var _queue: Array = []   # [key, def, slot, Callable]
var _waiting := {}   # key -> Array of Callables
var _mem := {}   # key -> ImageTexture
var _order: Array = []   # keys, oldest first
var _busy := false
var _blank := 0   # pictures that came out blank; after 3 the shots stop for this session
var _pre: Array = []   # v375: [id, slot, key] still to make ahead of time (prewarm)
var _pre_wait := 0.0
const PRE_GAP := 0.3   # seconds between two pictures made ahead (a slow phone keeps its frames)


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


## Version 363 (visual review v357 fix 5): a picture of a prize that isn't a look: "coins"
## (a heap of skull coins), "coin" (one), "drop" (the Bone Drop's bone reliquary) or "lucky"
## (a Lucky Start's green star). Kept like the looks' pictures.
static func want_prize(kind: String, done: Callable) -> void:
	want("", "prize", kind, done)


## A square picture of prize `kind` (want_prize), `px` points across, for a row or a button;
## empty until the picture is ready. `dim`: a prize not reached yet, darker.
static func prize_rect(kind: String, px: float, dim := false) -> TextureRect:
	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.custom_minimum_size = Vector2(px, px)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.material = HeroStage._see_through()
	if dim:
		pic.modulate = Color(0.5, 0.48, 0.56)
	want_prize(kind, func(t: Texture2D) -> void:
		if is_instance_valid(pic):
			pic.texture = t)
	return pic


## Version 375 (visual review of 366, fix 8): pictures made ahead of time. `jobs` is a list
## of [hero id, slot, key]; they are taken quietly, one at a time with a pause between,
## while the title screen or a menu is up (never in a run), and only saved (not kept in
## memory), so a list opened later shows real pictures at once. The Legend Vault's twelve
## each need a second or so for the look to play before its picture: its list opened on
## drawn symbols that turned into pictures one by one.
static func prewarm(jobs: Array, wait := 1.5) -> void:
	if _me == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		_me = LookShots.new()
		tree.root.add_child.call_deferred(_me)
	_me._pre = jobs.duplicate()
	_me._pre_wait = wait


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
	if slot == "prize":
		_queue.append([k, {}, "prize:" + key])
		return
	var base := Heroes.get_hero(id)
	if base.is_empty():
		return
	var def := _def_for(base, slot, key)
	if def.is_empty():
		return
	_queue.append([k, def, slot])


## The hero to draw for a picture of [slot, key]. Slot "set" (version 397) is the whole Crypt
## King set, cut for that hero: outfit, crown, arms and glow together.
static func _def_for(base: Dictionary, slot: String, key: String) -> Dictionary:
	if slot == "legend":
		return legend_def(base, key)
	if slot == "set":
		var picks := {}
		for s: String in ["outfit", "head", "hold", "glow"]:
			picks[s] = HeroStyle.pass_key(s)
		return HeroStyle.dressed(base, picks)
	return HeroStyle.dressed(base, {slot: key})


## Version 362 (visual review v357 fix 5): hero `base` in their classic look wearing Legend
## Vault look `id` (as in the Vault's preview, game.gd _legend_preview).
static func legend_def(base: Dictionary, id: String) -> Dictionary:
	var d := Legends.def(id)
	if d.is_empty():
		return {}
	var legend := {str(d.slot): id}
	var def := HeroStyle.dressed(base, HeroStyle.grand_head({}, legend))
	def.style.legend = legend
	HeroStyle.crown_grand(def, legend)
	return def


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
	_stage = Node3D.new()
	_vp.add_child(_stage)
	_pivot = Node3D.new()
	_pivot.rotation.y = HeroStage.FRONT
	_stage.add_child(_pivot)
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


func _process(delta: float) -> void:
	if _busy or _vp == null:
		return
	if _queue.is_empty():
		_pre_tick(delta)
		return
	_busy = true
	_take(_queue.pop_front())


## The next picture to make ahead of time, if this is a quiet moment.
func _pre_tick(delta: float) -> void:
	if _pre.is_empty() or _blank >= 3:
		return
	if Game.state != Game.State.TITLE:
		_pre_wait = 1.0   # (in a run: wait for the title to come back)
		return
	_pre_wait -= delta
	if _pre_wait > 0.0:
		return
	# (skips the ones already made: a few file checks a frame at most)
	for n in 6:
		if _pre.is_empty():
			return
		var j: Array = _pre.pop_front()
		var id := str(j[0])
		var slot := str(j[1])
		var key := str(j[2])
		var k := shot_key(id, slot, key)
		if _mem.has(k) or _waiting.has(k) or FileAccess.file_exists(_path(k)):
			continue
		var base := Heroes.get_hero(id)
		if base.is_empty():
			continue
		var def := _def_for(base, slot, key)
		if def.is_empty():
			continue
		_waiting[k] = []
		_queue.append([k, def, slot])
		_pre_wait = PRE_GAP
		return


func _take(job: Array) -> void:
	var k: String = job[0]
	var def: Dictionary = job[1]
	var slot: String = job[2]
	if slot.begins_with("prize:"):
		_take_prize(k, slot.substr(6))
		return
	var v := CharacterVisual.new()
	v.outline_me = true
	v.aura_boost = 1.8
	_pivot.add_child(v)
	v.build(Heroes.look(def, true))
	if def.has("aura") and slot == "aura":
		v.add_child(LookFx.aura_fx(def.aura, true))
		if not def.aura.get("sigil", false):
			# (Version 362: the aura's own mark on the floor, again and bolder: on a small card
			# it is what tells one aura from the next.)
			var mk := LookFx.mark(def.aura, 1.5, 1.05, true)
			mk.position = Vector3(0, 0.036, 0)
			v.add_child(mk)
	var lslot := ""
	if slot == "legend":
		lslot = str(def.style.legend.keys()[0])
	if lslot == "" and slot != "hold":
		v.attack(def.id == "mage")
	if slot == "hold" and not OS.has_environment("LS_BODY"):
		# Version 407 (re-review of v400, fix 7): a weapon's card shows the weapon, not a small
		# hero holding it: the hero's body is left out and the camera fills the card with what
		# the hands hold (the hero standing at ease, hands low, so the pair sits close).
		var pre := str(HeroStyle.PREFIX.get(str(def.id), "-"))
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			if (str(mi.name).begins_with(pre) and not "Shield" in str(mi.name)) or not _in_hand(mi):
				(mi as Node3D).visible = false
	if v._anim:
		v._anim.advance(0.0)
	var col: Color = def.ring
	# (Version 362: no glow ring under an aura: every aura card showed the same yellow ring,
	# over the aura's own mark on the floor, which is what tells one aura from another.)
	_ring.visible = slot in ["glow", "outfit", "set"]
	LookFx.set_ring(_ring.material_override, col, def.get("ring2"), str(def.get("ring_fx", "flow")), int(def.get("ring_tier", 0)))
	_pivot.rotation.y = HeroStage.FRONT + (PI * 0.78 if lslot == "wings" else 0.0)   # (wings: seen from behind)
	# (Version 388, fix 9: the Starfall Mantle from the side, its starry mantle sweeping out
	# behind; from the front it was a hat over a Knight, like the Bone Emperor's card.)
	if lslot == "grand" and str(def.style.legend.values()[0]) == "starfall":
		_pivot.rotation.y = HeroStage.FRONT + PI * 0.5
	# (Version 397: a shield is turned to the camera; edge-on, three shields looked like one.)
	var shield := false
	if slot == "hold":
		for n in v.find_children("*Shield*", "MeshInstance3D", true, false):
			shield = shield or (n as Node3D).is_visible_in_tree()
		if shield:
			_pivot.rotation.y = HeroStage.FRONT + float(OS.get_environment("LS_TURN") if OS.has_environment("LS_TURN") else "-0.65")
	var f := _frame(slot, v, def)
	if shield:
		f = [Vector3(0.15, 1.5, 4.9), Vector3(0.1, 1.08, 0)]
	elif slot == "hold":
		# (v407 critic: the two hands are far apart, so a pair of small things shrank to specks
		# with empty card between them: turned three-quarters, the hands come together)
		_pivot.rotation.y = HeroStage.FRONT + 0.8
		v.force_update_transform()
		# Version 407 (re-review of v400, fix 7: "weapon cards are tiny full-body pictures"):
		# the camera finds what is held in the hands and fills the card with it.
		var box := _held_box(v)
		if box.size != Vector3.ZERO:
			f = _frame_box(box)
	if OS.has_environment("LS_FRAME"):   # (lab only)
		var n := Array(OS.get_environment("LS_FRAME").split(",")).map(func(x: String) -> float: return float(x))
		f = [Vector3(n[0], n[1], n[2]), Vector3(n[3], n[4], n[5])]
	_cam.transform = Transform3D(Basis.looking_at(f[1] - f[0]), f[0])
	# A Legend look moves: its pet flies in, its steps are put down, its finisher bursts.
	# Let it play a moment before the picture (nodes run while the viewport isn't drawn).
	if lslot != "":
		if lslot == "finisher":
			for sh in v.find_children("*", "Node3D", false, false):
				if sh is LegendFinish.Show:
					sh._t = 0.88   # (its burst comes at 0.95 in each 2.2 s)
		var lid := str(def.style.legend.values()[0])
		var wait: float = {"pet": 1.0, "steps": 1.75, "finisher": 1.0, "wings": 0.6, "grand": 0.8}.get(lslot, 0.6)
		wait = {"wisp": 0.4, "gold_rush": 0.55}.get(lid, wait)
		if OS.has_environment("LS_WAIT"):
			wait = float(OS.get_environment("LS_WAIT"))
		await get_tree().create_timer(wait, true).timeout
		if not is_instance_valid(v):
			_busy = false
			return
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	for c in _pivot.get_children():
		c.queue_free()   # (the hero, and whatever a finisher left flying)
	var cbs: Array = _waiting.get(k, [])
	_waiting.erase(k)
	_busy = false
	if img == null or img.is_empty() or _empty(img):
		_blank += 1
		return
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(_path(k))
	if cbs.is_empty():
		return   # (v375: made ahead of time: saved, and loaded when a list asks for it)
	var tex := ImageTexture.create_from_image(img)
	_keep(k, tex)
	for cb: Callable in cbs:
		# (by id first: a card closed while its picture was made leaves a freed object, and
		# asking that Callable is_valid() prints an engine error)
		if is_instance_id_valid(cb.get_object_id()) and cb.is_valid():
			cb.call(tex)


func _take_prize(k: String, kind: String) -> void:
	var img: Image
	if kind == "drop":
		# The Bone Drop's own chest, as on its screen: its viewport is borrowed for one picture.
		var r := Reliquary.new()
		r.reset()
		var vp: SubViewport = r._vp
		r.remove_child(vp)
		add_child(vp)
		vp.size = SIZE * DRAW
		vp.msaa_3d = Viewport.MSAA_DISABLED
		r.cam_eye = Vector3(0, 1.75, 3.1)
		r.cam_at = Vector3(0, 0.55, 0)
		r.cam_zoom = 1.45
		r._place_camera()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		img = vp.get_texture().get_image()
		vp.queue_free()
		r.queue_free()
	else:
		_ring.visible = false
		_pivot.rotation.y = 0.0
		var thing := Node3D.new()
		_pivot.add_child(thing)
		var cm := LegendFinish.coin_mesh()
		var mat := LegendFinish.coin_material()
		match kind:
			"coins":
				# A heap: coins lying in a mound, two standing up in front.
				var rng := RandomNumberGenerator.new()
				rng.seed = 7
				for i in 14:
					var a := TAU * i / 7.0 + rng.randf() * 0.4
					var rr := 0.06 + 0.17 * float(i % 7) / 6.0 if i < 7 else 0.1 * rng.randf()
					var c := MeshInstance3D.new()
					c.mesh = cm
					c.material_override = mat
					c.position = Vector3(cos(a) * rr, 0.03 + (0.0 if i < 7 else 0.07 + 0.03 * (i % 3)), sin(a) * rr)
					c.rotation = Vector3(-PI / 2.0 + rng.randf_range(-0.35, 0.35), rng.randf() * TAU, 0)
					thing.add_child(c)
				for x in [-0.12, 0.14]:
					var c := MeshInstance3D.new()
					c.mesh = cm
					c.material_override = mat
					c.position = Vector3(x, 0.13, 0.24)
					c.rotation = Vector3(-0.55, x * 2.5, x)
					c.scale = Vector3.ONE * 0.8
					thing.add_child(c)
				_cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.1, 0.03) - Vector3(0, 0.78, 1.1)), Vector3(0, 0.78, 1.1))
			"coin":
				var c := MeshInstance3D.new()
				c.mesh = cm
				c.material_override = mat
				c.position = Vector3(0, 0.15, 0)
				c.rotation = Vector3(0, 0.45, 0)
				thing.add_child(c)
				_cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.15, 0) - Vector3(0, 0.2, 0.75)), Vector3(0, 0.2, 0.75))
			_:
				# A Lucky Start: a cut star of green glass with a gold rim light.
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var sp := PackedVector2Array()
				for i in 10:
					sp.append(Vector2.from_angle(PI / 2.0 + TAU * i / 10.0) * (0.36 if i % 2 == 0 else 0.155))
				ChestShow._extrude(st, sp, Vector2.ZERO, 0.05, 0.1)
				st.generate_normals()
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.35, 0.95, 0.45)
				m.metallic = 0.35
				m.roughness = 0.16
				m.emission_enabled = true
				m.emission = Color(0.15, 0.6, 0.2)
				m.rim_enabled = true
				m.rim = 0.8
				var mi := MeshInstance3D.new()
				mi.mesh = st.commit()
				mi.material_override = m
				mi.position = Vector3(0, 0.4, 0)
				mi.rotation = Vector3(-0.15, 0.45, 0.15)
				thing.add_child(mi)
				_cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.4, 0) - Vector3(0, 0.62, 1.75)), Vector3(0, 0.62, 1.75))
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		img = _vp.get_texture().get_image()
		thing.queue_free()
	var cbs: Array = _waiting.get(k, [])
	_waiting.erase(k)
	_busy = false
	if img == null or img.is_empty() or _empty(img):
		_blank += 1
		return
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(_path(k))
	if cbs.is_empty():
		return   # (v375: made ahead of time: saved, and loaded when a list asks for it)
	var tex := ImageTexture.create_from_image(img)
	_keep(k, tex)
	for cb: Callable in cbs:
		# (by id first: a card closed while its picture was made leaves a freed object, and
		# asking that Callable is_valid() prints an engine error)
		if is_instance_id_valid(cb.get_object_id()) and cb.is_valid():
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
			# (Version 397: a little further back, so no hat or horn is cut off by the card.)
			var y := 1.74 if tall else 1.55
			if extras.has("crypt_crown"):   # (the tallest: its wings, horns and soul flame)
				return [Vector3(0.0, 2.2, 4.7), Vector3(0, 1.95, 0)]
			return [Vector3(0.0, y + 0.25, 3.7 if tall else 3.2), Vector3(0, y, 0)]
		"hold":
			var wide := false
			for n in v.find_children("2H_*", "MeshInstance3D", true, false):
				if str(n.name) in ["2H_Sword", "2H_Axe"] and (n as Node3D).is_visible_in_tree():
					wide = true
			# (Version 397: the whole hero holding it; the close-up cut their head off.)
			if wide:
				return [Vector3(-0.55, 1.5, 5.5), Vector3(-0.5, 1.02, 0)]
			return [Vector3(0.05, 1.6, 4.5), Vector3(-0.1, 1.36, 0)]
		"aura":
			# (Version 362: from higher up, so the aura's own mark on the floor shows whole.)
			# (v407: further back, so the head no longer pokes out of the top of the card)
			return [Vector3(0, 3.5, 6.1), Vector3(0, 0.62, 0)]
		"set":
			return [Vector3(0, 1.9, 7.2), Vector3(0, 1.22, 0)]
		"glow":
			# (Version 397: a glow is told by its ring's outline, so its card looks down on the
			# ring, whole, with the whole hero standing in it.)
			# (Version 415, re-review of v410 fix 5: "six glows look the same except the ring
			# colour": closer and more from above, so the ring's outline fills the card.)
			return [Vector3(0, 5.0, 2.5), Vector3(0, 0.25, 0)]
		"legend":
			# Close on the prize itself (a pet flies, and a finisher bursts, at the hero's right on
			# the screen); the hero is half in the picture, to show it is worn.
			var lid := str(def.style.legend.values()[0])
			# Version 383 (visual review of 375, fix 8): closer still, on the item: a card's
			# picture is small, and the whole Knight with a tiny lantern beside him read as
			# "the same Knight again" on every card.
			var own := {
				"wisp": [Vector3(0.45, 1.5, 2.8), Vector3(0.4, 1.05, 0)],
				"raven": [Vector3(0.55, 2.05, 2.5), Vector3(0.45, 1.65, 0)],
				"mimic": [Vector3(0.7, 1.15, 2.4), Vector3(0.6, 0.45, 0)],
				"wyrm": [Vector3(1.0, 2.1, 3.3), Vector3(0.85, 1.55, 0)],
				# (Version 397: wider, on the skeleton the finisher bursts out of.)
				"gold_rush": [Vector3(1.4, 1.7, 4.0), Vector3(1.3, 0.62, 0)],
				"soul_harvest": [Vector3(1.3, 1.7, 4.0), Vector3(1.2, 0.68, 0)],
			}
			if own.has(lid):
				return own[lid]
			match str(def.style.legend.keys()[0]):
				"steps":
					return [Vector3(0.0, 2.7, 2.2), Vector3(0, 0.0, 0.4)]
				"wings":
					return [Vector3(-0.2, 1.65, 3.5), Vector3(-0.25, 1.3, 0)]
				"grand":
					return [Vector3(0.0, 1.52, 4.64), Vector3(0, 1.0, 0)]
	# (Version 397: the whole hero, plume to boots: the Knight's crest was cut off the card.)
	return [Vector3(0, 1.5, 5.5), Vector3(0, 1.02, 0)]


## Where the hands are, in the picture's world, as a box grown round them by what they hold
## (KayKit's weapons are skinned to the hand bone, so their own boxes don't show where they are).
func _held_box(v: CharacterVisual) -> AABB:
	var skel := Art._find_skeleton(v)
	if skel == null:
		return AABB()
	var pts: Array[Vector3] = []
	for bn in ["handslot.r", "handslot.l"]:
		var bi := skel.find_bone(bn)
		if bi >= 0:
			pts.append(skel.global_transform * skel.get_bone_global_pose(bi).origin)
	if pts.is_empty():
		return AABB()
	var wide := false
	for n in v.find_children("2H_*", "MeshInstance3D", true, false):
		wide = wide or (n as Node3D).is_visible_in_tree()
	var grow := 0.5 if wide else 0.32   # (v415: tighter, so the weapon fills its card)
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	box = box.grow(grow)
	# (the great made weapons hang off the hand bones as plain meshes: their own boxes are
	# true, so a long blade or a big axe head is taken in whole)
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		# (only what the game built: the model's own weapons give boxes far off their shape)
		if m.owner != null or not m.is_visible_in_tree() or m.mesh == null or not _in_hand(m):
			continue
		var b := m.global_transform * m.get_aabb()
		if b.size.length() < 3.2:   # (not a glow quad or a trail)
			box = box.merge(b.grow(0.06))
			if OS.has_environment("LS_DEBUG"):
				print("  in hand ", m.name, " ", b.size)
	box.position.y = maxf(box.position.y, 0.05)
	if OS.has_environment("LS_DEBUG"):
		print("HELD ", box, " wide=", wide)
	return box


## True for a mesh held in a hand: KayKit's own weapons (skinned, right under the skeleton)
## and anything hung on a hand bone; false for what hangs on the head, back or shoulders.
static func _in_hand(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is Skeleton3D:
			return true
		if p is BoneAttachment3D:
			var bn := str((p as BoneAttachment3D).bone_name)
			return bn.begins_with("handslot") or bn.begins_with("hand") or bn.begins_with("wrist")
		p = p.get_parent()
	return false


## The camera for a card filled by `box`: in front of it and a little above, far enough back
## that its longest side fits the card with a margin.
func _frame_box(box: AABB) -> Array:
	var c := box.get_center()
	var reach := maxf(maxf(box.size.x, box.size.y), 0.45)
	var dist := reach * 0.5 / tan(deg_to_rad(_cam.fov * 0.5)) * 1.04 + box.size.z * 0.5
	return [c + Vector3(0.0, dist * 0.18, dist), c]


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
