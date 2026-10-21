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
	"death": ["Death_A", "Death_B", "Death"],
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


## look: {key, height, body, accent, eyes, hat, horns, crown, hood}
func build(look: Dictionary) -> void:
	var scene := Art.get_model(look.get("key", ""))
	if scene:
		_model = scene.instantiate() as Node3D
		add_child(_model)
		Art.fit_height(_model, look.height)
		_model.rotation.y = PI   # KayKit models face +Z; our "forward" is -Z
		_anim = _find_anim(_model)
		if _anim:
			for action in ANIMS:
				for n in ANIMS[action]:
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
	U.box(root, Vector3(h * 0.05, h * 0.05, h * 0.45), accent, Vector3(h * 0.3, h * 0.38, -h * 0.18))

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
