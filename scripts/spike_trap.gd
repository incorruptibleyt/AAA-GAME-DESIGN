class_name SpikeTrap
extends Node3D
## A floor tile that shoots up spikes every few seconds. It glows red just before,
## so watch the floor.

const DAMAGE := 14.0
const HALF := 0.62
const REST := 1.8
const WARN := 0.6
const UP := 0.8

var _t := 0.0
var _hit_this_time := false
var _spikes: Node3D
var _glow_mat: StandardMaterial3D


func _ready() -> void:
	# Neighbouring traps fire at slightly different times.
	_t = fmod(absf(global_position.x * 0.37 + global_position.z * 0.21), 1.0) * REST
	U.floor_quad(self, Vector2(HALF * 2, HALF * 2), U.mat(Color(0.12, 0.11, 0.13), 0.6), Vector3(0, 0.02, 0))
	_glow_mat = U.unlit(Color(1, 0.15, 0.1, 0.0), U.soft_circle()).duplicate()
	var glow := U.floor_quad(self, Vector2(HALF * 2.4, HALF * 2.4), _glow_mat, Vector3(0, 0.04, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spikes = Node3D.new()
	add_child(_spikes)
	var steel := U.mat(Color(0.7, 0.7, 0.75), 0.3)
	for x in 3:
		for z in 3:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.1
			cone.height = 0.55
			cone.radial_segments = 6
			var m := MeshInstance3D.new()
			m.mesh = cone
			m.material_override = steel
			m.position = Vector3((x - 1) * 0.38, 0.27, (z - 1) * 0.38)
			_spikes.add_child(m)
	_spikes.position.y = -0.6


func _process(delta: float) -> void:
	_t += delta
	var cycle := REST + WARN + UP
	var k := fmod(_t, cycle)
	if k < REST:
		_spikes.position.y = move_toward(_spikes.position.y, -0.6, delta * 3.0)
		_glow_mat.albedo_color.a = 0.0
		_hit_this_time = false
	elif k < REST + WARN:
		var w := (k - REST) / WARN
		_glow_mat.albedo_color.a = 0.35 + 0.35 * sin(w * 25.0)
		_spikes.position.y = -0.45
	else:
		_glow_mat.albedo_color.a = 0.25
		_spikes.position.y = move_toward(_spikes.position.y, 0.0, delta * 12.0)
		if not _hit_this_time and _spikes.position.y > -0.2:
			var hero := Game.hero
			if hero and hero.can_be_hit():
				var d := hero.global_position - global_position
				if absf(d.x) < HALF + hero.radius * 0.5 and absf(d.z) < HALF + hero.radius * 0.5:
					_hit_this_time = true
					Game.hit_source = "Spike trap"
					hero.take_damage(DAMAGE, Vector3.ZERO, 0.0)
