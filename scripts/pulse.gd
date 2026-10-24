class_name Pulse
extends Label
## Gently pulses a label ("Tap to begin").

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	modulate.a = 0.55 + 0.45 * sin(_t * 3.0)
