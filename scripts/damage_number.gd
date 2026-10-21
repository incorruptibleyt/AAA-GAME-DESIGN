class_name DamageNumber
extends Label3D
## Numbers that pop out of whatever got hit and float away.

var _age := 0.0
var _drift := Vector3.ZERO
var _size := 1.0
const LIFE := 0.75


static func spawn(pos: Vector3, text_value: String, col: Color, big: bool) -> void:
	if Game.world == null:
		return
	var n := DamageNumber.new()
	n.text = text_value
	n.modulate = col
	n.outline_modulate = Color(0, 0, 0, 0.85)
	n.outline_size = 10
	n.font_size = 64
	n.pixel_size = 0.009
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.fixed_size = false
	n._size = 1.5 if big else 1.0
	n._drift = Vector3(randf_range(-0.6, 0.6), 1.6, 0)
	n.position = pos
	Game.world.add_child(n)


func _process(delta: float) -> void:
	_age += delta
	var k := _age / LIFE
	if k >= 1.0:
		queue_free()
		return
	position += _drift * delta / LIFE
	var pop := lerpf(1.6, 1.0, k / 0.15) if k < 0.15 else 1.0
	scale = Vector3.ONE * _size * pop
	modulate.a = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	outline_modulate.a = modulate.a * 0.85
