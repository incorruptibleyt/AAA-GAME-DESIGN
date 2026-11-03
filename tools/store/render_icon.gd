extends SceneTree
## Renders the 3D part of an app icon: one skeleton up close, with a thick burning chain of
## real 3D links wrapped round it, on a transparent background (tools/store/icon_compose.py
## adds the background, glow and outline).
## Run under a display:
##   godot --rendering-driver opengl3 -s tools/store/render_icon.gd -- look=warrior out=<file.png>
## look = warrior (the horned Skeleton Warrior), king (the same with a gold crown) or
## mage (the hooded Skeleton Mage). nochain leaves the chain out; anims lists the animations.

const LINK := Color(1.0, 0.62, 0.2)   # the burning chain: the gold and ember of the logo

var _look := "warrior"
var _out := "user://icon3d.png"
var _chain := true
var _cam := Vector3(0.5, 1.9, 6.4)
var _tgt := Vector3(0.0, 1.95, 0.0)
var _fov := 26.0
var _chain_y := 0.75
var _chain_tilt := 0.5
var _anim := "Idle_Combat"
var _anim_at := 0.3
var _crown_y := 0.72
var _crown_s := 0.8


func _initialize() -> void:
	var list := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			_look = a.substr(5)
		elif a.begins_with("out="):
			_out = a.substr(4)
		elif a == "nochain":
			_chain = false
		elif a == "anims":
			list = true
		elif a.begins_with("cam="):
			_cam = _vec(a.substr(4))
		elif a.begins_with("tgt="):
			_tgt = _vec(a.substr(4))
		elif a.begins_with("fov="):
			_fov = float(a.substr(4))
		elif a.begins_with("anim="):
			_anim = a.substr(5).get_slice("@", 0)
			_anim_at = float(a.substr(5).get_slice("@", 1))
		elif a.begins_with("crowns="):
			_crown_s = float(a.substr(7))
		elif a.begins_with("crowny="):
			_crown_y = float(a.substr(7))
		elif a.begins_with("tilt="):
			_chain_tilt = float(a.substr(5))
		elif a.begins_with("chainy="):
			_chain_y = float(a.substr(7))
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
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
	env.environment.ambient_light_color = Color(0.5, 0.45, 0.6)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	var key := "Skeleton_Mage" if _look == "mage" else "Skeleton_Warrior"
	var sk := _model(world, key, Vector3.ZERO, deg_to_rad(-12.0), _anim, _anim_at)
	if list:
		var ap := _find_anim(sk)
		print(ap.get_animation_list())
	if _look == "mage":
		Art.attach_to_bone(sk, "handslot.r", "Skeleton_Staff")
	else:
		Art.attach_to_bone(sk, "handslot.r", "Skeleton_Blade")
	if _look == "king":
		_crown(sk)
	# Head and shoulders, from a little below, so the skull looms.
	cam.fov = _fov
	cam.look_at_from_position(_cam, _tgt)
	_light(world, Vector3(-1.8, 2.6, 2.6), Color(1.0, 0.92, 0.82), 1.6)
	_light(world, Vector3(2.2, 2.0, -1.6), Color(1.0, 0.45, 0.15), 3.2)
	_light(world, Vector3(-2.2, 2.4, -1.8), Color(0.6, 0.45, 1.0), 2.4)
	if _chain:
		_wrap_chain(world)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	quit()


## A thick chain sweeping across the chest, in front of the body and back round behind it.
func _wrap_chain(world: Node3D) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.06
	mesh.outer_radius = 0.13
	mesh.rings = 24
	mesh.ring_segments = 10
	var metal := U.mat(LINK, 0.35, 0.35)
	metal.metallic = 0.5
	var pts: Array[Vector3] = []
	# An ellipse round the body, tilted so it rises from the lower left to the upper right.
	var n := 16
	for i in n:
		var t := TAU * i / n
		var p := Vector3(cos(t) * 0.74, 0.0, sin(t) * 0.52)
		p.y = _chain_y + p.x * _chain_tilt
		pts.append(p)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var link := MeshInstance3D.new()
		link.mesh = mesh
		link.material_override = metal
		world.add_child(link)
		# A torus lies flat (in its XZ plane), so after look_at it already runs along the
		# chain; every other link is turned a quarter round the chain so they interlock.
		link.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		link.rotate_object_local(Vector3.FORWARD, PI * 0.5 * (i % 2))
		link.scale = Vector3(1.0, 1.0, 1.5)


func _vec(t: String) -> Vector3:
	var f := t.split_floats(",")
	return Vector3(f[0], f[1], f[2])


func _crown(sk: Node3D) -> void:
	var skel := Art._find_skeleton(sk)
	if skel == null or skel.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	var gold := U.mat(Color(1.0, 0.74, 0.22), 0.3, 0.12)
	gold.metallic = 0.85
	var gem := U.mat(Color(0.9, 0.12, 0.2), 0.2, 0.6)
	var s := _crown_s
	var y := _crown_y
	U.cylinder(att, s * 0.5, s * 0.22, gold, Vector3(0, y, 0))
	for i in 7:
		var a := i / 7.0 * TAU
		var spike := U.box(att, Vector3(0.12, 0.34, 0.12) * s / 0.6, gold, Vector3(cos(a) * s * 0.46, y + s * 0.34, sin(a) * s * 0.46))
		spike.rotation.y = -a
		spike.scale = Vector3(1.0, 1.0, 0.6)
	U.sphere(att, 0.07, gem, Vector3(0, y + s * 0.11, s * 0.5))
	Art.hide_parts(sk, ["Skeleton_Warrior_Helmet"])


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
		ap.speed_scale = 0.0
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
