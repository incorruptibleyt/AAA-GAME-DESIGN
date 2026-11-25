class_name HeroBadge
extends Control
## Version 338 (visual review fix 3, clean HUD): the hero's face in a round frame at the
## left end of the health bar, in a ring of the hero's own colour, so the top bar says whose
## health it is at a glance (the way Supercell games put a portrait by the health).

const HEAD := Rect2(0.24, 0.06, 0.5, 0.5)   # the head in art/ui/heroes pictures (as RaceScreen)

var _pic: TextureRect
var _rim: Control
var _hero_id := ""
var _ring := Color(0.6, 0.9, 1.0)
static var _mask: Shader


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic = TextureRect.new()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	if _mask == null:
		_mask = Shader.new()
		_mask.code = """
shader_type canvas_item;
uniform vec2 box = vec2(46.0);
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length(lp / box - 0.5) * 2.0;
	c.a *= 1.0 - smoothstep(0.86, 0.92, d);
	COLOR = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _mask
	_pic.material = m
	add_child(_pic)
	# The coloured ring and ink edge, drawn over the picture.
	_rim = Control.new()
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim.draw.connect(func():
		var cc := _rim.size * 0.5
		var rr := minf(_rim.size.x, _rim.size.y) * 0.5
		_rim.draw_arc(cc, rr * 0.93, 0.0, TAU, 40, _ring.lightened(0.25), 3.5, true)
		_rim.draw_arc(cc, rr, 0.0, TAU, 40, Hud.INK, 3.0, true))
	add_child(_rim)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	_pic.position = Vector2.ZERO
	_pic.size = size
	(_pic.material as ShaderMaterial).set_shader_parameter("box", size)
	_rim.position = Vector2.ZERO
	_rim.size = size
	_rim.queue_redraw()
	queue_redraw()


func _process(_delta: float) -> void:
	var h := Game.hero
	if h == null or h.hero_id == _hero_id:
		return
	_hero_id = h.hero_id
	var def := Heroes.get_hero(_hero_id)
	_ring = def.get("ring", Color(0.6, 0.9, 1.0))
	var path := "res://art/ui/heroes/%s.png" % _hero_id
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var at := AtlasTexture.new()
		at.atlas = tex
		var s := tex.get_size()
		at.region = Rect2(HEAD.position * s, HEAD.size * s)
		_pic.texture = at
	_rim.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.35))
	draw_circle(c, r, _ring.darkened(0.55))
	draw_circle(c, r * 0.9, _ring.darkened(0.25))

