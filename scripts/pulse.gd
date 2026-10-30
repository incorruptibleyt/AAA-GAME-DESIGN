class_name Pulse
extends Label
## Gently pulses a label ("Tap to begin"). Runs on real time so it keeps pulsing in slow
## motion.

## How faint it gets at the bottom of each pulse.
var low := 0.1


func _process(_delta: float) -> void:
	modulate.a = lerpf(low, 1.0, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0))
