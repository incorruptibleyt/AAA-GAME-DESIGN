extends SceneTree
## Renders the 3D parts of the store art (icon and banner) with a transparent background.
## Run under a display:  godot --rendering-driver opengl3 -s tools/store/render_art.gd -- shot=icon out=<file.png>

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
	vp.size = Vector2i(1024, 1024) if _shot == "icon" else Vector2i(2048, 1000)
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
