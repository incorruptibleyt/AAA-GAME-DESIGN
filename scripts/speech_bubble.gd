class_name SpeechBubble
extends Control
## A hero's speech bubble (version 129): a cream card with the hero's name on a little tag in
## their colour, the line typing out letter by letter to the hero's own chatter (Sfx "voice"
## at the hero's pitch), and a tail pointing at whoever is talking. It pops in, holds long
## enough to read, then fades. It can follow a 3D node (the hero in a run) or point at a
## fixed spot on screen (the hero on the Heroes screen).

const PAPER := Color(1.0, 0.97, 0.9)
const TEXT_SIZE := 23
const MAX_WIDTH := 330.0
## Where the tail comes out: under the card (pointing down at the speaker, the usual), or
## from its right side (the card sits to the left of the speaker's head: the Heroes screen,
## where there is no room above the pedestal).
enum Side { BELOW, RIGHT }
var side := Side.BELOW
var max_width := MAX_WIDTH
var text_size := TEXT_SIZE
const TAIL := 14.0
## Letters typed per second, and one syllable of chatter for every few letters.
const SPEED := 34.0
const LETTERS_PER_SOUND := 3

var _card: PanelContainer
var _text: Label
var _tag: Label
var _tag_box: PanelContainer
var _follow: Node3D
var _height := 2.5
var _point := Vector2.ZERO
var _shown := 0.0
var _sounded := 0
var _hold := 0.0
var _pitch := 1.0
var _border := Color.WHITE
var _tw: Tween
var _last_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_text = Hud.label("", TEXT_SIZE, Hud.INK)
	_text.label_settings.outline_size = 0
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_card.add_child(_text)
	_tag_box = PanelContainer.new()
	_tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag_box)
	_tag = Hud.label("", 17, Color.WHITE)
	_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tag.label_settings.outline_size = 5
	_tag.label_settings.outline_color = Color(0, 0, 0, 0.55)
	_tag_box.add_child(_tag)


## Says `text` as `who`, in `col`, at `pitch`. `follow`: the 3D node to point at (with the
## tail `height` metres above its feet); without one, set `point` (the tail's tip on screen).
func say(who: String, text: String, col: Color, pitch: float, follow: Node3D = null, height := 2.5) -> void:
	if text == "":
		return
	_follow = follow
	_height = height
	_pitch = pitch
	_border = col
	_card.add_theme_stylebox_override("panel", _card_style(col))
	_tag_box.add_theme_stylebox_override("panel", _tag_style(col))
	_tag.text = who.to_upper()
	_text.text = text
	_text.label_settings.font_size = text_size
	# One line when it fits; wrapped at MAX_WIDTH when it doesn't.
	var font := _text.get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x if font else MAX_WIDTH
	if width > max_width:
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = max_width
	else:
		_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		_text.custom_minimum_size.x = 0.0
	_text.visible_characters = 0
	_last_ms = 0
	_shown = 0.0
	_sounded = 0
	_hold = 1.6 + text.length() * 0.045
	_card.reset_size()
	_tag_box.reset_size()
	visible = true
	modulate.a = 1.0
	_place()
	pivot_offset = Vector2(_card.size.x * 0.5, _card.size.y + TAIL) if side == Side.BELOW else Vector2(_card.size.x + TAIL, _card.size.y * 0.5)
	scale = Vector2(0.55, 0.55)
	if _tw:
		_tw.kill()
	_tw = create_tween().set_ignore_time_scale(true)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Where the tail points, on screen, when nothing is followed.
func point_at(p: Vector2) -> void:
	_point = p
	if visible:
		_place()


func hide_now() -> void:
	if _tw:
		_tw.kill()
	visible = false
	_follow = null


func talking() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not visible:
		return
	# Real seconds (hit-stops and slow-motion finishes don't stretch or squeeze the line).
	var now := Time.get_ticks_msec()
	var d := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else 0.0
	_last_ms = now
	var total := _text.text.length()
	if _shown < total:
		_shown = minf(_shown + d * SPEED, float(total))
		var n := int(_shown)
		_text.visible_characters = n
		# A syllable every few letters (never on a space or a mark).
		var letters := 0
		for i in n:
			if _text.text[i] not in [" ", ".", ",", "!", "?", "'"]:
				letters += 1
		if letters >= (_sounded + 1) * LETTERS_PER_SOUND:
			_sounded = letters / LETTERS_PER_SOUND
			Sfx.play("voice", 0.55, _pitch * randf_range(0.93, 1.08))
	else:
		_text.visible_characters = -1
		_hold -= d
		if _hold <= 0.0 and (_tw == null or not _tw.is_running()):
			_tw = create_tween().set_ignore_time_scale(true)
			_tw.tween_property(self, "modulate:a", 0.0, 0.3)
			_tw.tween_callback(hide_now)
	_place()


func _place() -> void:
	var tip := _point
	if _follow:
		if not is_instance_valid(_follow) or not _follow.is_inside_tree():
			hide_now()
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		tip = cam.unproject_position(_follow.global_position + Vector3.UP * _height)
	var vp := get_viewport_rect().size
	var w := _card.size.x
	var h := _card.size.y
	_card.position = Vector2.ZERO
	_tag_box.position = Vector2(14.0, -_tag_box.size.y * 0.62)
	if side == Side.RIGHT:
		# The card ends just left of the tip, centred on it, kept on screen.
		position = Vector2(maxf(8.0, tip.x - TAIL - w), clampf(tip.y - h * 0.5, 8.0, vp.y - h - 8.0))
		_tail_y = clampf(tip.y - position.y, 18.0, h - 18.0)
		_tail_tip = tip - position
	else:
		# The card sits centred over the tail, kept on screen with a little room at the sides.
		var x := clampf(tip.x - w * 0.5, 12.0, maxf(12.0, vp.x - w - 12.0))
		position = Vector2(x, tip.y - h - TAIL)
		_tail_x = clampf(tip.x - x, 22.0, w - 22.0)
	queue_redraw()


var _tail_x := 0.0
var _tail_y := 0.0
var _tail_tip := Vector2.ZERO

func _draw() -> void:
	# The tail: a little triangle from the card's edge to the speaker, in the border colour
	# with a paper middle.
	if side == Side.RIGHT:
		var x := _card.size.x - 3.0
		var tip := Vector2(minf(_tail_tip.x, x + TAIL + 6.0), _tail_tip.y)
		draw_colored_polygon(PackedVector2Array([Vector2(x, _tail_y - 12.0), Vector2(x, _tail_y + 12.0), tip]), _border)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.0, _tail_y - 7.5), Vector2(x - 1.0, _tail_y + 7.5), tip.lerp(Vector2(x, _tail_y), 0.35)]), PAPER)
		return
	var y := _card.size.y - 3.0
	var pts := PackedVector2Array([Vector2(_tail_x - 12.0, y), Vector2(_tail_x + 12.0, y), Vector2(_tail_x, y + TAIL + 3.0)])
	draw_colored_polygon(pts, _border)
	var inner := PackedVector2Array([Vector2(_tail_x - 7.5, y - 1.0), Vector2(_tail_x + 7.5, y - 1.0), Vector2(_tail_x, y + TAIL - 2.5)])
	draw_colored_polygon(inner, PAPER)


static func _card_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = col
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func _tag_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.25)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	return sb
