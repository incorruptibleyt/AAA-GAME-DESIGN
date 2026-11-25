class_name BellRinger
extends Enemy
## The Bell Ringer (version 243, the Frostfall event): a skeleton in a frosted hood with a
## great gold handbell. It keeps back and swings the bell, which glows as it winds up; then
## it rings, and a ring of frost spreads out from it across the hall. The ring can't be
## walked round: get far enough away, or dash through it as it passes (a dash can't be hit).
## Caught by it, you are hurt and chilled.

const EVERY := 4.2
const WIND := 0.8
const ICE := Color(0.55, 0.88, 1.0)
const GOLD := Color(1.0, 0.8, 0.35)

var _ring := 2.2
var _winding := 0.0
var _bell: Node3D


func _setup() -> void:
	die_sound = "die_bell"
	init_health(36.0)
	move_speed = 1.7
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	_ring = randf_range(1.8, 3.0)
	var look := bones(Art.SKELETON_MAGE, 2.0, ICE)
	look.hood = true
	look.accent = Color(0.25, 0.4, 0.55)
	look.attack_anim = "Spellcast_Shoot"
	look.hide = ["Skeleton_Mage_Hat"]
	look.shape = {"scale": {"chest": 0.85, "head": 0.9, "upperarm.l": 1.2, "upperarm.r": 1.2, "upperleg.l": 1.4, "upperleg.r": 1.4}}   # (v347: tall and thin)
	look.parts = "yoke"
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Bell Ringer"


static var _bell_mesh: ArrayMesh


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null or skel.find_bone("handslot.r") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "handslot.r"
	_bell = Node3D.new()
	att.add_child(_bell)
	var m := MeshInstance3D.new()
	m.mesh = _mesh()
	_bell.add_child(m)


## A great gold handbell on a wooden handle, mouth down.
static func _mesh() -> ArrayMesh:
	if _bell_mesh:
		return _bell_mesh
	var gold := U.mat(GOLD, 0.3, 1.0)
	var wood := U.mat(Color(0.35, 0.2, 0.1), 0.8)
	var parts := []
	parts.append([Props._cone(0.05, 0.05, 0.5, 8), Props._xf(Vector3(0, 0.1, 0), Vector3.ONE), wood])
	parts.append([Props._cone(0.1, 0.3, 0.42, 12), Props._xf(Vector3(0, -0.32, 0), Vector3.ONE), gold])
	parts.append([Props._cone(0.32, 0.32, 0.05, 12), Props._xf(Vector3(0, -0.53, 0), Vector3.ONE), gold])
	parts.append([Props._sphere(), Props._xf(Vector3(0, -0.6, 0), Vector3.ONE * 0.08), gold])
	_bell_mesh = Props._bake(parts)
	return _bell_mesh


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _winding > 0.0:
		_winding -= delta
		stand(delta)
		face(to, 8.0, delta)
		if _bell:
			_bell.rotation.z = sin(_winding * 26.0) * 0.6
		if randf() < delta * 30.0:
			Fx.magic(center() + Vector3.UP * 0.6, GOLD if randf() < 0.5 else ICE, 1)
		if _winding <= 0.0:
			if _bell:
				_bell.rotation.z = 0.0
			FrostRing.ring(global_position, ICE, kind_name())
		return
	_ring -= delta
	if to.length() > 8.0:
		walk(to, delta)
	elif to.length() < 5.0:
		walk(-to, delta)
	else:
		stand(delta)
		face(to, 8.0, delta)
	if _ring <= 0.0 and to.length() < 10.0:
		_ring = EVERY + randf() * 0.8
		_winding = WIND
		visual.attack(true)
		Sfx.play("shimmer", 0.5, 1.4)
