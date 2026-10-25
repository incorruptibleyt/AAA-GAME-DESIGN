extends SceneTree
## Renders the 3D parts of the store art (icon and banner) and the Crypt Pass screen's
## pictures (tile_floors, tile_heroes, tile_daily, tile_curses) with a transparent background.
## Run under a display:  godot --rendering-driver opengl3 -s tools/store/render_art.gd -- shot=icon out=<file.png>

const KNIGHT_HIDE := ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"]

var _shot := "icon"
var _out := "user://art.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			_shot = a.substr(5)
		elif a.begins_with("out="):
			_out = a.substr(4)
	# Render in our own transparent viewport so the game's own scene never shows up.
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024) if _shot == "icon" else (Vector2i(936, 448) if _shot.begins_with("tile_") else Vector2i(2048, 1000))
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.4, 0.6)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	if _shot == "icon":
		var sk := _model(world, "Skeleton_Warrior", Vector3.ZERO, deg_to_rad(-15.0), "1H_Melee_Attack_Chop", 0.35)
		Art.attach_to_bone(sk, "handslot.r", "Skeleton_Blade")
		cam.fov = 30.0
		cam.look_at_from_position(Vector3(0.7, 2.5, 5.2), Vector3(0.0, 1.65, 0.0))
		_light(world, Vector3(-2.0, 3.0, 3.0), Color(1.0, 0.9, 0.8), 1.4)
		_light(world, Vector3(2.5, 2.0, -2.0), Color(1.0, 0.45, 0.15), 3.0)
		_light(world, Vector3(-2.5, 2.5, -2.0), Color(0.6, 0.4, 1.0), 2.5)
	elif _shot.begins_with("tile_"):
		_tile(world, cam)
	else:
		var hero := _model(world, "Rogue_Hooded", Vector3(-1.0, 0.0, 0.6), deg_to_rad(55.0), "1H_Ranged_Shoot", 0.25)
		Art.hide_parts(hero, ["Knife", "Knife_Offhand", "2H_Crossbow", "Throwable"])
		var w := _model(world, "Skeleton_Warrior", Vector3(1.1, 0.0, -0.6), deg_to_rad(-40.0), "1H_Melee_Attack_Chop", 0.3)
		Art.attach_to_bone(w, "handslot.r", "Skeleton_Blade")
		var m := _model(world, "Skeleton_Mage", Vector3(2.7, 0.0, -1.8), deg_to_rad(-45.0), "Spellcast_Shoot", 0.4)
		Art.attach_to_bone(m, "handslot.r", "Skeleton_Staff")
		cam.fov = 32.0
		cam.look_at_from_position(Vector3(0.3, 1.6, 7.0), Vector3(0.6, 1.0, 0.0))
		_light(world, Vector3(-3.0, 4.0, 4.0), Color(1.0, 0.92, 0.85), 1.3)
		_light(world, Vector3(3.0, 2.5, -3.0), Color(1.0, 0.45, 0.15), 3.0)
		_light(world, Vector3(-3.0, 3.0, -3.0), Color(0.55, 0.4, 1.0), 2.5)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	quit()


## The Crypt Pass screen's four pictures.
func _tile(world: Node3D, cam: Camera3D) -> void:
	cam.fov = 30.0
	match _shot:
		"tile_floors":
			# A crowd of skeletons climbing out of the dark: the floors never end.
			_skeleton(world, "Skeleton_Warrior", Vector3(0.0, 0.0, 0.4), -5.0, "Walking_D_Skeletons", 0.2, "Skeleton_Blade")
			_skeleton(world, "Skeleton_Minion", Vector3(-1.9, 0.0, -0.4), 15.0, "Walking_D_Skeletons", 0.6, "Skeleton_Axe")
			_skeleton(world, "Skeleton_Rogue", Vector3(1.9, 0.0, -0.3), -20.0, "Walking_D_Skeletons", 0.9, "Skeleton_Crossbow")
			_skeleton(world, "Skeleton_Mage", Vector3(-0.9, 0.0, -2.4), 5.0, "Walking_D_Skeletons", 0.4, "Skeleton_Staff")
			_skeleton(world, "Skeleton_Warrior", Vector3(1.1, 0.0, -2.8), -10.0, "Walking_D_Skeletons", 0.0, "Skeleton_Blade")
			cam.look_at_from_position(Vector3(-0.4, 2.4, 7.0), Vector3(-0.4, 1.0, -0.6))
			_light(world, Vector3(0.0, 1.0, 3.0), Color(1.0, 0.55, 0.2), 2.6)
			_light(world, Vector3(-3.0, 3.0, -3.0), Color(0.55, 0.4, 1.0), 2.5)
			_light(world, Vector3(3.0, 3.0, 2.0), Color(1.0, 0.9, 0.8), 0.8)
		"tile_heroes":
			# Every hero, side by side.
			# (Heroes.LIST can't be used here: it needs the running game. These match its "hide" lists.)
			var heroes := [
				["Rogue_Hooded", "Cheer", ["Knife", "Knife_Offhand", "2H_Crossbow", "Throwable"]],
				["Knight", "Idle", KNIGHT_HIDE],
				["Barbarian", "2H_Melee_Idle", ["1H_Axe_Offhand", "Barbarian_Round_Shield", "2H_Axe", "Mug"]],
				["Mage", "Spellcast_Raise", ["Spellbook", "Spellbook_open", "1H_Wand"]],
			]
			for i in heroes.size():
				var x := -2.55 + i * 1.7
				var n := _model(world, heroes[i][0], Vector3(x, 0.0, absf(x) * -0.15), deg_to_rad(-x * 6.0), heroes[i][1], 0.45)
				Art.hide_parts(n, heroes[i][2])
			cam.look_at_from_position(Vector3(0.0, 1.8, 7.0), Vector3(0.0, 1.0, 0.0))
			_light(world, Vector3(-3.0, 4.0, 4.0), Color(1.0, 0.92, 0.85), 1.4)
			_light(world, Vector3(3.0, 2.5, -2.5), Color(0.4, 0.7, 1.0), 2.8)
			_light(world, Vector3(-3.0, 2.5, -2.5), Color(0.7, 0.45, 1.0), 2.8)
		"tile_daily":
			# The Knight against a skeleton: a new fight every day.
			var k := _model(world, "Knight", Vector3(-1.0, 0.0, 0.3), deg_to_rad(60.0), "1H_Melee_Attack_Slice_Horizontal", 0.35)
			Art.hide_parts(k, KNIGHT_HIDE)
			_skeleton(world, "Skeleton_Warrior", Vector3(1.0, 0.0, -0.3), -60.0, "Block_Attack", 0.3, "Skeleton_Blade")
			_skeleton(world, "Skeleton_Minion", Vector3(2.6, 0.0, -1.8), -40.0, "Running_C", 0.2, "Skeleton_Axe")
			cam.look_at_from_position(Vector3(0.3, 1.8, 7.3), Vector3(0.4, 1.0, 0.0))
			_light(world, Vector3(-2.5, 3.5, 3.5), Color(1.0, 0.92, 0.8), 1.4)
			_light(world, Vector3(0.0, 3.0, -2.5), Color(1.0, 0.75, 0.25), 3.5)
			_light(world, Vector3(3.0, 2.0, 1.0), Color(1.0, 0.6, 0.2), 1.5)
		"tile_curses":
			# A skeleton mage casting a curse between its two guards.
			_skeleton(world, "Skeleton_Mage", Vector3(0.0, 0.0, 0.0), 0.0, "Spellcast_Summon", 0.6, "Skeleton_Staff")
			_skeleton(world, "Skeleton_Warrior", Vector3(-1.9, 0.0, -0.8), 25.0, "Idle_Combat", 0.3, "Skeleton_Blade")
			_skeleton(world, "Skeleton_Warrior", Vector3(1.9, 0.0, -0.8), -25.0, "Idle_Combat", 0.8, "Skeleton_Blade")
			cam.look_at_from_position(Vector3(0.0, 1.6, 6.8), Vector3(0.0, 1.15, -0.3))
			_light(world, Vector3(0.0, 1.2, 1.6), Color(1.0, 0.15, 0.12), 3.0)
			_light(world, Vector3(-3.0, 3.0, -2.5), Color(0.8, 0.2, 0.3), 3.0)
			_light(world, Vector3(3.0, 3.0, -2.5), Color(0.6, 0.3, 1.0), 2.2)
			_light(world, Vector3(0.0, 4.0, 4.0), Color(1.0, 0.9, 0.85), 0.6)


func _skeleton(parent: Node3D, key: String, pos: Vector3, yaw_deg: float, anim: String, at: float, weapon: String) -> Node3D:
	var n := _model(parent, key, pos, deg_to_rad(yaw_deg), anim, at)
	Art.attach_to_bone(n, "handslot.r", weapon)
	return n


func _model(parent: Node3D, key: String, pos: Vector3, yaw: float, anim: String, at := 0.0) -> Node3D:
	var scene := Art.get_model(key)
	var node := scene.instantiate() as Node3D
	Art.bind_skins(node)
	parent.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	var ap := _find_anim(node)
	if ap and ap.has_animation(anim):
		ap.play(anim)
		ap.seek(at, true)
		ap.speed_scale = 1.0
	return node


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _light(parent: Node3D, pos: Vector3, color: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	parent.add_child(l)
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 12.0
