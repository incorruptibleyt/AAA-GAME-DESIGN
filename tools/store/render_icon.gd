extends SceneTree
## Renders the 3D part of an app icon: one skeleton up close, with a thick burning chain of
## real 3D links wrapped round it, on a transparent background (tools/store/icon_compose.py
## adds the background, glow and outline).
## Run under a display:
##   godot --rendering-driver opengl3 -s tools/store/render_icon.gd -- look=warrior out=<file.png>
## look = warrior (the horned Skeleton Warrior), king (the same with a gold crown) or
## mage (the hooded Skeleton Mage). nochain leaves the chain out; anims lists the animations.
## For the Bone King icon: jaw=<degrees> opens the jaw, nosword drops the blade, lights=king
## lights it from behind in purple, and only=chain renders just the chain (icon_compose.py
## uses that picture to make the chain glow).
## The app icon since version 84 (the roaring Bone King) is these two renders:
##   ... -- look=king lights=king nosword cam=0.2,1.2,6 tgt=-0.06,1.68,0 fov=19 crowny=0.84
##          crowns=0.82 yaw=-4 anim=Idle_Combat@0.3 chainy=0.62 jaw=38 headtilt=18 out=king.png
##   (the same with only=chain, out=king_chain.png)
## then: python3 tools/store/icon_compose.py king.png royal <dir> chain=king_chain.png sparks
## and copy icon-512.png to icon.png and store/, the other layers to art/launcher/.

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
var _jaw := 0.0
var _sword := true
var _lights := ""
var _only := ""
var _yaw := -12.0
var _chain_glow := 0.35
var _head_tilt := 0.0


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
		elif a.begins_with("jaw="):
			_jaw = float(a.substr(4))
		elif a == "nosword":
			_sword = false
		elif a.begins_with("lights="):
			_lights = a.substr(7)
		elif a.begins_with("only="):
			_only = a.substr(5)
		elif a.begins_with("yaw="):
			_yaw = float(a.substr(4))
		elif a.begins_with("headtilt="):
			_head_tilt = float(a.substr(9))
		elif a.begins_with("glow="):
			_chain_glow = float(a.substr(5))
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
	var sk := _model(world, key, Vector3.ZERO, deg_to_rad(_yaw), _anim, _anim_at)
	if list:
		var ap := _find_anim(sk)
		print(ap.get_animation_list())
	if not _sword:
		pass
	elif _look == "mage":
		Art.attach_to_bone(sk, "handslot.r", "Skeleton_Staff")
	else:
		Art.attach_to_bone(sk, "handslot.r", "Skeleton_Blade")
	if _look == "king":
		_crown(sk)
	if _jaw != 0.0:
		_open_jaw(sk)
	if _head_tilt != 0.0:
		# Hold the pose and tip the head back, as if roaring.
		await process_frame
		_find_anim(sk).pause()
		var skel := Art._find_skeleton(sk)
		var hb := skel.find_bone("head")
		skel.set_bone_pose_rotation(hb, skel.get_bone_pose_rotation(hb) * Quaternion(Vector3.RIGHT, deg_to_rad(-_head_tilt)))
	# Head and shoulders, from a little below, so the skull looms.
	cam.fov = _fov
	cam.look_at_from_position(_cam, _tgt)
	if _lights == "king":
		# Warm gold from the front, purple and pink rims from behind so the skull's edge glows
		# against the purple background.
		_light(world, Vector3(-1.2, 2.8, 3.0), Color(1.0, 0.93, 0.82), 1.9)
		_light(world, Vector3(1.6, 1.2, 2.2), Color(1.0, 0.6, 0.3), 1.0)
		_light(world, Vector3(2.2, 2.6, -1.4), Color(1.0, 0.45, 0.9), 4.0)
		_light(world, Vector3(-2.2, 2.6, -1.4), Color(0.55, 0.45, 1.0), 4.0)
		_light(world, Vector3(0.0, 4.0, -0.5), Color(1.0, 0.85, 0.6), 1.5)
	else:
		_light(world, Vector3(-1.8, 2.6, 2.6), Color(1.0, 0.92, 0.82), 1.6)
		_light(world, Vector3(2.2, 2.0, -1.6), Color(1.0, 0.45, 0.15), 3.2)
		_light(world, Vector3(-2.2, 2.4, -1.8), Color(0.6, 0.45, 1.0), 2.4)
	if _chain:
		_wrap_chain(world)
	if _only == "chain":
		sk.visible = false
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
	var metal := U.mat(LINK, 0.35, _chain_glow)
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


## A king's crown on the head bone: a flared gold band, five spikes with a ball on each tip,
## a red gem in front and two blue ones, worn at a slight tilt.
func _crown(sk: Node3D) -> void:
	var skel := Art._find_skeleton(sk)
	if skel == null or skel.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	var crown := Node3D.new()
	att.add_child(crown)
	crown.position = Vector3(0.0, _crown_y, 0.02)
	crown.rotation = Vector3(deg_to_rad(-6.0), 0.0, deg_to_rad(-9.0))
	crown.scale = Vector3.ONE * _crown_s
	var gold := U.mat(Color(1.0, 0.76, 0.24), 0.28, 0.18)
	gold.metallic = 0.45
	var dark_gold := U.mat(Color(0.75, 0.45, 0.1), 0.4, 0.05)
	dark_gold.metallic = 0.45
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.bottom_radius = 0.47
	bm.top_radius = 0.53
	bm.height = 0.24
	bm.radial_segments = 28
	band.mesh = bm
	band.material_override = gold
	crown.add_child(band)
	# A darker rim round the bottom of the band, for shape at small sizes.
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.44
	rm.outer_radius = 0.52
	rim.mesh = rm
	rim.material_override = dark_gold
	rim.position.y = -0.11
	crown.add_child(rim)
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	for i in 5:
		var ang := PI * 0.5 + i / 5.0 * TAU   # the first spike is right over the face
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.15
		sm.height = 0.42 if i == 0 else 0.34
		sm.radial_segments = 4
		spike.mesh = sm
		spike.material_override = gold
		spike.position = dir * 0.48 + Vector3(0, 0.12 + sm.height * 0.5, 0)
		spike.rotation.y = -ang + PI * 0.25
		crown.add_child(spike)
		var tip := MeshInstance3D.new()
		tip.mesh = ball
		tip.material_override = gold
		tip.position = dir * 0.48 + Vector3(0, 0.12 + sm.height + 0.03, 0)
		crown.add_child(tip)
	var red := U.mat(Color(0.95, 0.1, 0.18), 0.15, 0.9)
	var blue := U.mat(Color(0.2, 0.55, 1.0), 0.15, 0.9)
	U.sphere(crown, 0.085, red, Vector3(0, 0.0, 0.5))
	for side: float in [-1.0, 1.0]:
		var ang := PI * 0.5 + side * 0.75
		U.sphere(crown, 0.055, blue, Vector3(cos(ang) * 0.5, 0.0, sin(ang) * 0.5))
	Art.hide_parts(sk, ["Skeleton_Warrior_Helmet"])


## Opens the jaw: the jaw's mesh is copied onto the head bone, swung down round its hinge,
## and the skinned original hidden.
func _open_jaw(sk: Node3D) -> void:
	var skel := Art._find_skeleton(sk)
	var jaw: MeshInstance3D = sk.find_child("*_Jaw", true, false)
	if skel == null or jaw == null:
		return
	var head := skel.find_bone("head")
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	var copy := MeshInstance3D.new()
	copy.mesh = jaw.mesh
	att.add_child(copy)
	var to_bone := skel.get_bone_global_rest(head).affine_inverse()
	var hinge := to_bone * Vector3(0.0, 1.43, -0.06)
	var swing := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_jaw)), Vector3.ZERO)
	copy.transform = Transform3D(Basis(), hinge) * swing * Transform3D(Basis(), -hinge) * to_bone
	jaw.visible = false
	# Darkness inside the skull, seen through the open mouth.
	var mouth := U.sphere(att, 0.2, U.mat(Color(0.06, 0.02, 0.08), 1.0), to_bone * Vector3(0.0, 1.42, 0.12))
	mouth.scale = Vector3(1.3, 0.7, 0.9)


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
