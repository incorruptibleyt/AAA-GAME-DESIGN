class_name Joystick
extends Control
## The floating thumb stick, drawn wherever the thumb first touches the screen.

var radius := 70.0
var knob := Vector2.ZERO:
	set(v):
		knob = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * 1.1, Color(1, 1, 1, 0.1))
	draw_arc(Vector2.ZERO, radius * 1.1, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
	draw_circle(knob, radius * 0.45, Color(1, 1, 1, 0.75))
