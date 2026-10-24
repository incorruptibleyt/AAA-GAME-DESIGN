class_name Flicker
extends OmniLight3D
## Makes a light flicker like a flame.

var _base := 0.0
var _seed := 0.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	var n := sin(_t * 9.0 + _seed) * 0.5 + sin(_t * 23.0 + _seed * 2.0) * 0.3
	light_energy = _base * (0.85 + n * 0.18)
