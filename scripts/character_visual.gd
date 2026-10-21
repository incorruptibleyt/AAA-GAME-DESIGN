class_name CharacterVisual
extends Node3D
## The look of a character. Uses the KayKit model (and its animations) when one has been
## uploaded; otherwise builds a stylised placeholder from simple shapes and animates it in
## code. Gameplay scripts only call set_moving / attack / hit / die, so they work either way.

## Animation names to try for each action, best first (KayKit naming).
const ANIMS := {
	"idle": ["Idle", "Idle_A", "Unarmed_Idle"],
	"run": ["Running_A", "Running_B", "Run", "Walking_A"],
	"attack": ["1H_Ranged_Shoot", "2H_Ranged_Shoot", "1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A", "Attack"],
	"cast": ["Spellcast_Shoot", "Spellcasting", "Spellcast_Long"],
	"hit": ["Hit_A", "Hit_B", "Hit"],
	"death": ["Death_C_Skeletons", "Death_A", "Death_B", "Death"],
}

var _model: Node3D
var _anim: AnimationPlayer
var _anim_names := {}
var _moving := false
var _bob := 0.0
var _punch := 0.0
var _dead := false
var _flash := 0.0
var _meshes: Array[GeometryInstance3D] = []
static var _flash_mat: StandardMaterial3D


## look: {key, height, body, accent, eyes, hat, horns, crown, hood, helmet, shield, bow, bomb}
func build(look: Dictionary) -> void:
	var scene := Art.get_model(look.get("key", ""))
	if scene:
		_model = scene.instantiate() as Node3D
		add_child(_model)
		Art.fit_height(_model, look.height)
		_model.rotation.y = PI   # KayKit models face +Z; our "forward" is -Z
		_anim = _find_anim(_model)
		_dress_model(look)
		if _anim:
			for action in ANIMS:
				var names: Array = ANIMS[action]
				if action == "attack" and look.has("attack_anim"):
					names = [look.attack_anim] + names
				for n in names:
					if _anim.has_animation(n):
						_anim_names[action] = n
						break
			for loop_action in ["idle", "run"]:
				if _anim_names.has(loop_action):
					var a := _anim.get_animation(_anim_names[loop_action])
					a.loop_mode = Animation.LOOP_LINEAR
	else:
		_model = _placeholder(look)
	_collect_meshes(_model)
	_play("idle")


## Weapons, shields and extras for KayKit models.
func _dress_model(look: Dictionary) -> void:
	Art.hide_parts(_model, look.get("hide", []))
	if look.has("weapon"):
		Art.attach_to_bone(_model, "handslot.r", look.weapon)
	if look.has("offhand"):
		Art.attach_to_bone(_model, "handslot.l", look.offhand)
	var skel := Art._find_skeleton(_model)
	if skel == null:
		return
	if look.get("crown", false) and skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		var gold := U.mat(Color(1.0, 0.78, 0.25), 0.3, 0.8)
		var s := 0.45
		U.cylinder(att, s * 0.5, s * 0.15, gold, Vector3(0, s * 1.1, 0))
		for i in 5:
			var a := i / 5.0 * TAU
			U.box(att, Vector3.ONE * s * 0.18, gold, Vector3(cos(a) * s * 0.42, s * 1.32, sin(a) * s * 0.42))
	if look.get("bomb", false) and skel.find_bone("chest") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "chest"
		U.sphere(att, 0.42, U.mat(Color(0.08, 0.08, 0.1), 0.4), Vector3(0, 0.25, -0.45))
		U.sphere(att, 0.1, U.mat(Color(1.0, 0.6, 0.1), 0.5, 4.0), Vector3(0, 0.72, -0.5))


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _collect_meshes(n: Node) -> void:
	if n is GeometryInstance3D:
		_meshes.append(n)
	for c in n.get_children():
		_collect_meshes(c)


# ---------------------------------------------------------------- API

func set_moving(m: bool) -> void:
	if _dead:
		return
	_moving = m
	if _anim and _anim.current_animation in [_anim_names.get("idle", ""), _anim_names.get("run", ""), ""]:
		_play("run" if m else "idle")


func attack(spell := false) -> void:
	if _dead:
		return
	_punch = 1.0
	_play("cast" if spell and _anim_names.has("cast") else "attack", true)


func hit() -> void:
	if _dead:
		return
	_flash = 0.07
	_set_flash(true)


func die() -> void:
	if _dead:
		return
	_dead = true
	_set_flash(false)
	if _anim and _anim_names.has("death"):
		_play("death", true)
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(_model, "position:y", -1.5, 0.8)
	else:
		var tw := create_tween()
		tw.tween_property(_model, "rotation:x", -1.45, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.4)
		tw.tween_property(_model, "position:y", -1.5, 0.8)


func set_visible_blink(v: bool) -> void:
	_model.visible = v


# ---------------------------------------------------------------- internals

func _play(action: String, restart := false) -> void:
	if _anim == null or not _anim_names.has(action):
		return
	var n: String = _anim_names[action]
	if _anim.current_animation == n and not restart:
		return
	_anim.play(n, 0.1)
	if restart:
		_anim.seek(0.0, true)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)

	if _anim:
		# Return to idle/run once a one-shot (attack, hit) finishes.
		if not _dead and (_anim.current_animation == "" or (not _anim.is_playing())):
			_play("run" if _moving else "idle", true)
		return
	if _dead:
		return
	# Placeholder animation: bob while walking, squash on attack.
	_bob += delta * (14.0 if _moving else 3.0)
	var bob_y := absf(sin(_bob)) * 0.12 if _moving else sin(_bob) * 0.02
	_punch = move_toward(_punch, 0.0, delta * 6.0)
	var squash := 1.0 + _punch * 0.2
	_model.position = Vector3(0, bob_y, -_punch * 0.15)
	_model.rotation = Vector3(-0.14 if _moving else 0.0, 0, sin(_bob * 0.5) * (0.07 if _moving else 0.0))
	_model.scale = Vector3(squash, 1.0 / squash, squash)


func _set_flash(on: bool) -> void:
	if _flash_mat == null:
		_flash_mat = U.unlit(Color.WHITE)
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _flash_mat if on else null


func _placeholder(look: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var h: float = look.height
	var body := U.mat(look.body, 0.8)
	var accent := U.mat(look.accent, 0.6)
	var eyes := U.mat(look.eyes, 0.5, 3.0)

	U.capsule(root, h * 0.19, h * 0.5, body, Vector3(0, h * 0.36, 0))
	U.box(root, Vector3(h * 0.42, h * 0.08, h * 0.36), accent, Vector3(0, h * 0.26, 0))
	var head := U.sphere(root, h * 0.18, body, Vector3(0, h * 0.74, 0))
	U.sphere(root, h * 0.035, eyes, Vector3(-h * 0.07, h * 0.76, -h * 0.15))
	U.sphere(root, h * 0.035, eyes, Vector3(h * 0.07, h * 0.76, -h * 0.15))
	U.capsule(root, h * 0.06, h * 0.32, body, Vector3(-h * 0.25, h * 0.4, 0))
	U.capsule(root, h * 0.06, h * 0.32, body, Vector3(h * 0.25, h * 0.4, 0))
	var steel := U.mat(Color(0.55, 0.57, 0.62), 0.35)
	if look.get("bow", false):
		# A bow held out in front: short segments bent into an arc, plus a string.
		var wood := U.mat(Color(0.45, 0.28, 0.14), 0.7)
		var r := h * 0.24
		var c := Vector3(h * 0.3, h * 0.45, -h * 0.1)
		for i in 5:
			var a := (i - 2) * 0.38
			var seg := U.capsule(root, h * 0.022, h * 0.13, wood, c + Vector3(0, sin(a) * r, -cos(a) * r))
			seg.rotation.x = a
		U.box(root, Vector3(h * 0.008, r * 1.7, h * 0.008), U.unlit(Color(0.9, 0.9, 0.85)), c + Vector3(0, 0, -r * 0.55))
	else:
		var blade_len := 0.6 if look.get("shield", false) else 0.45
		U.box(root, Vector3(h * 0.05, h * 0.05, h * blade_len), steel if look.get("shield", false) else accent, Vector3(h * 0.3, h * 0.38, -h * blade_len * 0.4))
	if look.get("shield", false):
		var shield := U.cylinder(root, h * 0.2, h * 0.05, U.mat(look.accent.lightened(0.15), 0.5), Vector3(-h * 0.3, h * 0.28, -h * 0.12))
		shield.rotation.x = PI / 2
		U.sphere(root, h * 0.045, steel, Vector3(-h * 0.3, h * 0.48, -h * 0.17))
	if look.get("bomb", false):
		# A round black bomb strapped to the back, with a glowing fuse.
		U.sphere(root, h * 0.2, U.mat(Color(0.08, 0.08, 0.1), 0.4), Vector3(0, h * 0.5, h * 0.24))
		U.sphere(root, h * 0.05, U.mat(Color(1.0, 0.6, 0.1), 0.5, 4.0), Vector3(0, h * 0.74, h * 0.26))
	if look.get("helmet", false):
		var helm := U.sphere(root, h * 0.2, steel, Vector3(0, h * 0.78, 0.0))
		helm.scale = Vector3(1, 0.75, 1)
		U.box(root, Vector3(h * 0.04, h * 0.14, h * 0.04), steel, Vector3(0, h * 0.74, -h * 0.18))

	if look.get("hat", false):
		U.cylinder(root, h * 0.22, h * 0.03, accent, Vector3(0, h * 0.88, 0))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = h * 0.13
		cone.height = h * 0.35
		var c := MeshInstance3D.new()
		c.mesh = cone
		c.material_override = accent
		c.position = Vector3(0, h * 1.07, 0)
		root.add_child(c)
	if look.get("hood", false):
		var hood := U.sphere(root, h * 0.21, accent, Vector3(0, h * 0.8, h * 0.04))
		hood.scale = Vector3(1, 0.9, 1)
	if look.get("horns", false):
		for side in [-1.0, 1.0]:
			var horn := U.capsule(head, h * 0.035, h * 0.2, accent, Vector3(side * h * 0.15, h * 0.13, 0))
			horn.rotation.z = -side * 0.6
	if look.get("crown", false):
		var gold := U.mat(Color(1.0, 0.78, 0.25), 0.3, 0.8)
		U.cylinder(root, h * 0.15, h * 0.05, gold, Vector3(0, h * 0.9, 0))
		for i in 5:
			var a := i / 5.0 * TAU
			U.box(root, Vector3.ONE * h * 0.06, gold, Vector3(cos(a) * h * 0.13, h * 0.97, sin(a) * h * 0.13))
	return root
