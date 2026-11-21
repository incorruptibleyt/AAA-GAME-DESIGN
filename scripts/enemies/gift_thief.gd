class_name GiftThief
extends Enemy
## The Gift Thief (version 243, the Frostfall event): a little hunched skeleton in a red
## cap with a sack of stolen gifts over its shoulder. It never fights. It runs from you, and
## after a few seconds it dives into the floor with its sack and is gone. Catch it first and
## the sack bursts: snowflakes and a shower of coins. Krampus's thrown sack lets them out.

const FLEE := 7.0        # seconds before it gets away
const SHARDS := 4        # snowflakes in its sack
const GOLD := Color(1.0, 0.8, 0.3)

var _left := FLEE
var _gone := false
var _blink := 0.0
var _swerve := 0.0


func _setup() -> void:
	init_health(26.0)
	move_speed = 3.7      # the hero walks 5.2: it can be caught, not without trying
	contact_damage = 0.0  # it only runs
	drop_chance = 0.2
	radius = 0.45
	center_height = 0.75
	_swerve = randf() * TAU
	var look := bones(Art.SKELETON_MINION, 1.4, GOLD)
	look.accent = Color(0.6, 0.08, 0.08)
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Gift Thief"


func coin_value() -> int:
	return 6 + Game.floor_num


static var _sack_mesh: ArrayMesh


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("chest") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "chest"
		var m := MeshInstance3D.new()
		m.mesh = _sack()
		att.add_child(m)
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		# A floppy red cap with a white bobble.
		var red := U.mat(Color(0.7, 0.07, 0.08), 0.7)
		var cap := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.42
		cone.height = 0.75
		cone.radial_segments = 10
		cap.mesh = cone
		cap.material_override = red
		cap.position = Vector3(0, 0.95, -0.1)
		cap.rotation.x = -0.7
		head.add_child(cap)
		U.sphere(head, 0.12, U.mat(Color(0.92, 0.94, 0.98), 0.7), Vector3(0, 1.2, -0.5))
		U.cylinder(head, 0.44, 0.1, U.mat(Color(0.92, 0.94, 0.98), 0.8), Vector3(0, 0.62, -0.02))


## The sack over its shoulder: bigger than its body, tied with gold, gifts poking out.
static func _sack() -> ArrayMesh:
	if _sack_mesh:
		return _sack_mesh
	var parts := []
	var sack := U.mat(Color(0.5, 0.1, 0.1), 0.9)
	var gold := U.mat(GOLD, 0.35, 1.0)
	parts.append([Props._sphere(), Props._xf(Vector3(0.1, 0.45, -0.55), Vector3(0.55, 0.6, 0.5)), sack])
	parts.append([Props._cone(0.08, 0.2, 0.22, 8), Props._xf(Vector3(0.12, 1.1, -0.6), Vector3.ONE), sack])
	parts.append([Props._cone(0.1, 0.1, 0.06, 8), Props._xf(Vector3(0.12, 1.02, -0.6), Vector3.ONE), gold])
	parts.append([Props._cube(), Props._xf(Vector3(0.3, 1.18, -0.5), Vector3.ONE * 0.24, Basis(Vector3(1, 1, 0).normalized(), 0.5)), U.mat(Color(0.1, 0.4, 0.22), 0.6)])
	parts.append([Props._cube(), Props._xf(Vector3(0.3, 1.18, -0.5), Vector3(0.06, 0.25, 0.25), Basis(Vector3(1, 1, 0).normalized(), 0.5)), gold])
	parts.append([Props._cube(), Props._xf(Vector3(-0.06, 1.2, -0.64), Vector3.ONE * 0.2, Basis(Vector3(0, 1, 1).normalized(), 0.6)), U.mat(Color(0.85, 0.88, 0.95), 0.6)])
	_sack_mesh = Props._bake(parts)
	return _sack_mesh


func can_be_hit() -> bool:
	return super.can_be_hit() and not _gone


func _think(hero: Hero, delta: float) -> void:
	_left -= delta
	if hero.perks.has("gifthunter"):
		_left = maxf(_left, 2.5)   # Gift Hunter (a Frostfall blessing): it never gets away
	if _left <= 0.0:
		_get_away()
		return
	# Away from the hero, swerving, and round the walls rather than into them.
	var away := global_position - hero.global_position
	away.y = 0.0
	_swerve += delta * 2.2
	var dir := away.normalized() + away.normalized().cross(Vector3.UP) * sin(_swerve) * 0.6
	var p := global_position
	if absf(p.x) > Room.HALF_W - 1.6:
		dir.x -= signf(p.x) * 1.2
		dir.z += signf(dir.z if absf(dir.z) > 0.1 else -p.z + 0.01) * 0.8
	if absf(p.z) > Room.HALF_L - 1.6:
		dir.z -= signf(p.z) * 1.2
		dir.x += signf(dir.x if absf(dir.x) > 0.1 else -p.x + 0.01) * 0.8
	walk(dir, delta)
	if randf() < delta * 6.0:
		Fx.magic(global_position + Vector3.UP * 1.1, GOLD, 1)
	# The last two seconds it blinks: about to get away.
	if _left < 2.0 and visual:
		_blink += delta * 10.0
		visual.visible = sin(_blink) > -0.3


## Dives into the floor with the sack: gone, and the room no longer waits for it.
func _get_away() -> void:
	if _gone:
		return
	_gone = true
	dead = true
	if visual:
		visual.visible = true
		var tw := visual.create_tween()
		tw.tween_property(visual, "position:y", -1.6, 0.35)
	if _bar:
		_bar.queue_free()
	Fx.dust(global_position, 18)
	Sfx.play("pff", 0.6, 1.3)
	Game.hud.callout("A GIFT THIEF GOT AWAY", GOLD, true)
	Game.enemy_escaped(self)
	get_tree().create_timer(0.6, false).timeout.connect(queue_free)


func _on_death() -> void:
	if visual:
		visual.visible = true
	Fx.magic(center(), GOLD, 26)
	Sfx.play("coin", 0.8, 1.2)
	super._on_death()
