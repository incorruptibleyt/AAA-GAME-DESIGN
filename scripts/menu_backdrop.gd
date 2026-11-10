class_name MenuBackdrop
extends Control
## The lit crypt behind every full-screen menu (version 130), in place of the flat purple
## glow: a stone wall with real bumps (one small picture whose colours hold each stone's
## slope, so lights catch the edges of the blocks), lit by a coloured key light, two
## flickering torches and a soft shaft of light from above, with dust (or embers) drifting
## through it. A screen that shows something (a hero on a pedestal, the Bone Drop chest)
## gets a stone archway behind it and a floor under it, the key light on it and the torches
## on the wall beside the arch; a screen of lists gets the light from above and torches
## just off the sides. Each screen has its own colour of light (gold for rewards, forge
## orange in the Armory, the hero's own colour on the hero screens...).
##
## Cheap on a phone: one picture lookup and four lights a pixel, no 3D, and nothing runs
## while the menu is closed. On Low graphics the lights skip the stones' slopes and the
## shaft of light (set_cheap).

const WALL := preload("res://art/ui/crypt_wall.png")
## Canvas pixels per repeat of the wall picture (five rows of stones).
const TILE := 300.0

const THEMES := {
	"crypt": {"key": Color(0.55, 0.45, 1.0), "stone": Color(0.62, 0.58, 0.78), "ambient": Color(0.075, 0.06, 0.13), "dust": Color(1.0, 0.85, 0.65)},
	"gold": {"key": Color(1.0, 0.72, 0.32), "stone": Color(0.7, 0.6, 0.72), "ambient": Color(0.085, 0.06, 0.12), "dust": Color(1.0, 0.85, 0.45)},
	"forge": {"key": Color(1.0, 0.42, 0.14), "stone": Color(0.7, 0.56, 0.58), "ambient": Color(0.09, 0.05, 0.07), "dust": Color(1.0, 0.55, 0.2), "embers": true},
	"teal": {"key": Color(0.3, 0.9, 1.0), "stone": Color(0.56, 0.64, 0.74), "ambient": Color(0.05, 0.075, 0.11), "dust": Color(0.65, 1.0, 1.0)},
	"blood": {"key": Color(1.0, 0.28, 0.3), "stone": Color(0.66, 0.56, 0.64), "ambient": Color(0.09, 0.04, 0.07), "dust": Color(1.0, 0.6, 0.55)},
	"bone": {"key": Color(0.8, 0.86, 1.0), "stone": Color(0.62, 0.62, 0.74), "ambient": Color(0.07, 0.065, 0.12), "dust": Color(0.9, 0.95, 1.0)},
}
const TORCH := Color(1.0, 0.52, 0.2)

var look := "crypt"
var _rect: ColorRect
var _mat: ShaderMaterial
var _dust: CPUParticles2D
var _torches: Array[_Torch] = []
## What the key light shines on (a hero's pedestal, a chest); null on a screen of lists.
var _foci: Array[Control] = []
var _focus: Control
var _light_at := Vector2(0.5, 0.45)   # where in the focus the light points
var _floor_at := 0.86                 # where in the focus the floor meets the wall
var _arch := 0.0                      # the archway's width, as a part of the focus's width
var _key := Color.WHITE
var _key_to := Color.WHITE
var _t := 0.0

static var _shader: Shader
static var _dot: GradientTexture2D
static var _cheap := false
static var _all: Array[MenuBackdrop] = []


## Low graphics: flatter, cheaper light on every backdrop.
static func set_cheap(on: bool) -> void:
	_cheap = on
	for b in _all:
		if is_instance_valid(b):
			b._mat.set_shader_parameter("cheap", on)


## Puts a lit backdrop at the back of `r` (a full-screen menu).
static func add_to(r: Control, theme_name := "crypt") -> MenuBackdrop:
	var b := MenuBackdrop.new()
	b.look = theme_name
	r.add_child(b)
	r.move_child(b, 0)
	return b


## The backdrop that add_to gave `r`, or null.
static func of(r: Control) -> MenuBackdrop:
	for c in r.get_children():
		if c is MenuBackdrop:
			return c
	return null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = shader()
	_mat.set_shader_parameter("wall", WALL)
	_mat.set_shader_parameter("cheap", _cheap)
	_rect.material = _mat
	add_child(_rect)
	_all.append(self)
	tree_exiting.connect(func(): _all.erase(self))
	_dust = CPUParticles2D.new()
	_dust.texture = dot()
	_dust.amount = 26
	_dust.lifetime = 7.0
	_dust.preprocess = 7.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(0, -1)
	_dust.spread = 180.0
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 12.0
	_dust.gravity = Vector2(0, -5)
	_dust.scale_amount_min = 0.12
	_dust.scale_amount_max = 0.42
	_dust.local_coords = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_dust.material = add
	add_child(_dust)
	for i in 2:
		var t := _Torch.new()
		t.visible = false
		add_child(t)
		_torches.append(t)
	resized.connect(_layout)


func _ready() -> void:
	var th: Dictionary = THEMES.get(look, THEMES.crypt)
	_key = th.key
	_key_to = th.key
	_mat.set_shader_parameter("stone", th.stone)
	_mat.set_shader_parameter("ambient", th.ambient)
	var ramp := Gradient.new()
	var dc: Color = th.dust
	ramp.set_color(0, Color(dc, 0.0))
	ramp.add_point(0.2, Color(dc, 0.55))
	ramp.add_point(0.75, Color(dc, 0.4))
	ramp.set_color(ramp.get_point_count() - 1, Color(dc, 0.0))
	_dust.color_ramp = ramp
	if th.get("embers", false):
		# The forge: sparks rising from below instead of dust hanging in the air.
		_dust.amount = 34
		_dust.lifetime = 4.5
		_dust.preprocess = 4.5
		_dust.gravity = Vector2(0, -26)
		_dust.initial_velocity_min = 8.0
		_dust.initial_velocity_max = 26.0
		_dust.scale_amount_min = 0.1
		_dust.scale_amount_max = 0.28
	_on_shown()
	_layout()


func _notification(what: int) -> void:
	# (Not the menu's visibility_changed signal: during it, this still reads as hidden.)
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_on_shown()


## Lights `c` (a hero's pedestal, a chest) as the thing this screen shows: the key light at
## `light_at` (a point inside it, 0-1), the floor meeting the wall at `floor_at` of its
## height, and an archway `arch` times its width behind it (0 for none).
## `c` can be a list: the first one showing is lit (the Bone Drop's chest, then its prize).
func show_off(c, light_at := Vector2(0.5, 0.45), floor_at := 0.86, arch := 0.62) -> void:
	_foci.clear()
	for f in (c if c is Array else [c]):
		_foci.append(f)
	_light_at = light_at
	_floor_at = floor_at
	_arch = arch
	_layout()


## Turns the key light toward `c` over a moment (a new hero picked).
func set_key(c: Color, now := false) -> void:
	_key_to = c
	if now:
		_key = c


func _on_shown() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	_dust.emitting = on
	if on:
		_dust.restart()
		_layout()
	for t in _torches:
		t.set_process(on and t.visible)


func _layout() -> void:
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		return
	_mat.set_shader_parameter("size", s)
	_mat.set_shader_parameter("tile", TILE)
	_dust.position = s * 0.5
	_dust.emission_rect_extents = s * 0.5
	var key_pos: Vector3
	var torch_l: Vector2
	var torch_r: Vector2
	var show_torches := false
	var horizon := -1.0
	var arch := Vector3(0, 0, 0)   # centre x, spring line y, half width
	_focus = null
	for f in _foci:
		if is_instance_valid(f) and f.is_visible_in_tree():
			_focus = f
			break
	if _focus and is_instance_valid(_focus) and _focus.is_visible_in_tree() and _focus.size.y > 4.0:
		var r := _focus.get_global_rect()
		var o := get_global_rect().position
		r.position -= o
		var lp := r.position + r.size * _light_at
		key_pos = Vector3(lp.x, lp.y, 150.0)
		horizon = r.position.y + r.size.y * _floor_at
		if _arch > 0.0:
			var hw := r.size.x * _arch * 0.5
			var top := maxf(r.position.y + hw * 0.55, horizon - r.size.y * 1.1 + hw)
			arch = Vector3(lp.x, top, hw)
			var ty := clampf(top - hw * 0.4, 60.0, horizon - 40.0)
			torch_l = Vector2(lp.x - hw - 48.0, ty)
			torch_r = Vector2(lp.x + hw + 48.0, ty)
			show_torches = torch_l.x > 28.0 and torch_r.x < s.x - 28.0
		else:
			torch_l = Vector2(-30.0, r.position.y)
			torch_r = Vector2(s.x + 30.0, r.position.y)
	else:
		key_pos = Vector3(s.x * 0.5, -s.y * 0.04, 260.0)
		torch_l = Vector2(-26.0, s.y * 0.16)
		torch_r = Vector2(s.x + 26.0, s.y * 0.16)
	_mat.set_shader_parameter("key_pos", key_pos)
	_mat.set_shader_parameter("key_radius", s.y * (0.42 if horizon > 0.0 else 0.75))
	_mat.set_shader_parameter("torch_l", Vector3(torch_l.x, torch_l.y, 46.0))
	_mat.set_shader_parameter("torch_r", Vector3(torch_r.x, torch_r.y, 46.0))
	_mat.set_shader_parameter("torch_radius", s.x * (0.55 if show_torches else 0.75))
	_mat.set_shader_parameter("horizon", horizon)
	_mat.set_shader_parameter("arch", arch)
	_torches[0].position = torch_l
	_torches[1].position = torch_r
	for t in _torches:
		t.visible = show_torches
		t.set_process(show_torches and is_visible_in_tree())


func _process(delta: float) -> void:
	_t += delta
	_key = _key.lerp(_key_to, minf(1.0, delta * 4.0))
	# Torch flicker: a few slow waves on top of each other, a different mix for each torch.
	var f1 := 1.0 + 0.09 * sin(_t * 7.3) + 0.06 * sin(_t * 13.1 + 1.7) + 0.04 * sin(_t * 23.0)
	var f2 := 1.0 + 0.09 * sin(_t * 6.1 + 2.0) + 0.06 * sin(_t * 14.7) + 0.04 * sin(_t * 21.0 + 0.5)
	_mat.set_shader_parameter("key_col", Vector3(_key.r, _key.g, _key.b) * (1.0 + 0.03 * sin(_t * 1.3)))
	_mat.set_shader_parameter("torch_col_l", Vector3(TORCH.r, TORCH.g, TORCH.b) * f1)
	_mat.set_shader_parameter("torch_col_r", Vector3(TORCH.r, TORCH.g, TORCH.b) * f2)
	_torches[0].flicker = f1
	_torches[1].flicker = f2
	if not _foci.is_empty():
		_layout()   # the pedestal or chest can move as the screen settles


static func dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


static func shader() -> Shader:
	if _shader:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type canvas_item;
uniform sampler2D wall : repeat_enable, filter_linear;
uniform vec2 size = vec2(540.0, 1200.0);
uniform float tile = 300.0;
uniform vec3 stone = vec3(0.62, 0.58, 0.78);
uniform vec3 ambient = vec3(0.075, 0.06, 0.13);
uniform vec3 key_pos = vec3(270.0, -40.0, 260.0);
uniform vec3 key_col = vec3(0.55, 0.45, 1.0);
uniform float key_radius = 800.0;
uniform vec3 torch_l = vec3(-26.0, 190.0, 46.0);
uniform vec3 torch_r = vec3(566.0, 190.0, 46.0);
uniform vec3 torch_col_l = vec3(1.0, 0.52, 0.2);
uniform vec3 torch_col_r = vec3(1.0, 0.52, 0.2);
uniform float torch_radius = 400.0;
uniform float horizon = -1.0;
uniform vec3 arch = vec3(0.0);
uniform bool cheap = false;

vec3 lamp(vec3 lp, vec3 col, float radius, vec3 p, vec3 n) {
	vec3 l = lp - p;
	float d = length(l.xy) / radius;
	float att = clamp(1.0 - d, 0.0, 1.0);
	att = att * att + 0.06 / (1.0 + d * d * 8.0);
	if (cheap) {
		return col * att * (0.75 + 0.3 * (n.x * sign(l.x) + n.y * sign(l.y)));
	}
	float ndl = max(dot(n, normalize(l)), 0.0);
	return col * att * (0.3 + 0.9 * ndl);
}

void fragment() {
	vec2 p = UV * size;
	vec3 n = vec3(0.0, 0.0, 1.0);
	float alb;
	float depth = 0.0;     // how far back (the floor's far end, the arch's inside)
	float lift = 0.0;      // light that the floor pool and the arch rim add
	if (horizon > 0.0 && p.y > horizon) {
		// The floor: the same stones laid flat, in perspective, fading into the dark far off.
		float dy = p.y - horizon;
		float z = 90.0 / (dy + 6.0);
		vec2 fuv = vec2((p.x - arch.x) * z, z * 260.0) / tile;
		vec3 t = texture(wall, fuv).rgb;
		float far = clamp(1.0 - dy / 90.0, 0.0, 1.0);
		alb = mix(t.r, 0.3, far * 0.85);
		vec2 nn = t.gb * 2.0 - 1.0;
		n = normalize(vec3(nn.x, 0.55, nn.y * 0.5 + 0.8));
		depth = far * 0.55;
		// a pool of light on the floor under the key light
		vec2 q = (p - vec2(key_pos.x, horizon + 34.0)) / vec2(size.x * 0.38, 70.0);
		lift = exp(-dot(q, q) * 1.6) * 0.75;
	} else {
		vec3 t = texture(wall, p / tile).rgb;
		alb = t.r;
		vec2 nn = t.gb * 2.0 - 1.0;
		n = vec3(nn, sqrt(max(1.0 - dot(nn, nn), 0.0)));
		if (arch.z > 0.0) {
			vec2 q = p - arch.xy;
			float d = q.y > 0.0 ? abs(q.x) - arch.z : length(q) - arch.z;
			float band = 22.0;
			if (d < 0.0) {
				// Inside the archway: the back of the niche, further away and darker at its edges.
				vec3 b = texture(wall, p / (tile * 0.8) + vec2(0.37, 0.11)).rgb;
				alb = b.r * 0.9;
				vec2 bn = b.gb * 2.0 - 1.0;
				n = vec3(bn, sqrt(max(1.0 - dot(bn, bn), 0.0)));
				depth = 0.25 + 0.5 * (1.0 - smoothstep(0.0, 42.0, -d));
			} else if (d < band) {
				// The arch's own stones: a rounded frame with joints like the spokes of a wheel.
				float k = d / band;
				vec2 g = q.y > 0.0 ? vec2(sign(q.x), 0.0) : normalize(q);
				float slope = cos(k * 3.14159) * 1.2;
				n = normalize(vec3(g * slope, 1.0));
				// (an odd number of stones over the top, so one keystone sits in the middle)
				float seg = q.y > 0.0 ? q.y / 40.0 + 0.5 : atan(q.x, -q.y) / 0.2856 + 0.5;
				float sid = floor(seg);
				float joint = smoothstep(0.36, 0.46, abs(fract(seg) - 0.5));
				joint = max(joint, smoothstep(0.8, 1.0, k));
				float tone = 0.5 + 0.22 * fract(sin(sid * 12.9898) * 43758.5453);
				tone += q.y <= 0.0 && abs(sid) < 0.5 ? 0.12 : 0.0;
				alb = mix(tone + t.r * 0.2, 0.08, joint);
				lift = 0.05;
			} else {
				// the arch's shadow on the wall just outside it
				alb *= mix(0.55, 1.0, smoothstep(0.0, 26.0, d - band));
			}
		}
	}
	vec3 p3 = vec3(p, 0.0);
	vec3 light = ambient * 2.2;
	light += lamp(key_pos, key_col, key_radius, p3, n);
	light += lamp(torch_l, torch_col_l, torch_radius, p3, n);
	light += lamp(torch_r, torch_col_r, torch_radius, p3, n);
	light += key_col * lift;
	vec3 c = alb * stone * light * (1.0 - depth);
	// A soft shaft of light from above, in the air in front of the wall.
	if (!cheap) {
		float sx = abs(p.x - size.x * 0.5) / (size.x * 0.16 + p.y * 0.3);
		float shaft = (1.0 - smoothstep(0.35, 1.0, sx)) * pow(1.0 - clamp(p.y / size.y, 0.0, 1.0), 1.6);
		shaft *= 0.8 + 0.2 * sin((p.x - size.x * 0.5) / (p.y + 120.0) * 30.0 + TIME * 0.35);
		c += key_col * shaft * 0.07;
	}
	// The corners fall away into the dark.
	vec2 v = (UV - 0.5) * vec2(1.25, 1.0);
	c *= 1.0 - 0.6 * smoothstep(0.32, 0.78, length(v));
	COLOR = vec4(c, 1.0);
}
"""
	return _shader


## A torch on the wall: an iron cup on a bracket, a flame of sparks and a warm glow.
class _Torch extends Node2D:
	var flicker := 1.0
	var _flame: CPUParticles2D
	var _glow: Sprite2D

	func _init() -> void:
		_glow = Sprite2D.new()
		_glow.texture = MenuBackdrop.dot()
		_glow.scale = Vector2(4.4, 4.4)
		_glow.position = Vector2(0, -22)
		_glow.modulate = Color(1.0, 0.55, 0.2, 0.32)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = add
		add_child(_glow)
		_flame = CPUParticles2D.new()
		_flame.texture = MenuBackdrop.dot()
		_flame.amount = 26
		_flame.lifetime = 0.6
		_flame.position = Vector2(0, -12)
		_flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_flame.emission_sphere_radius = 6.0
		_flame.direction = Vector2(0, -1)
		_flame.spread = 14.0
		_flame.gravity = Vector2(0, -70)
		_flame.initial_velocity_min = 14.0
		_flame.initial_velocity_max = 30.0
		_flame.scale_amount_min = 0.75
		_flame.scale_amount_max = 1.15
		var sc := Curve.new()
		sc.add_point(Vector2(0, 1))
		sc.add_point(Vector2(1, 0.15))
		_flame.scale_amount_curve = sc
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
		g.add_point(0.3, Color(1.0, 0.7, 0.25, 0.9))
		g.set_color(g.get_point_count() - 1, Color(0.9, 0.2, 0.05, 0.0))
		_flame.color_ramp = g
		_flame.material = add
		_flame.local_coords = false
		add_child(_flame)

	func _process(_delta: float) -> void:
		_glow.scale = Vector2.ONE * 4.4 * flicker
		_glow.modulate.a = 0.3 * flicker

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			_flame.emitting = is_visible_in_tree()

	func _draw() -> void:
		var iron := Color(0.11, 0.08, 0.08)
		var edge := Color(0.55, 0.36, 0.24)   # lit by its own flame
		# the plate on the wall, the arm out to the cup, and the cup
		draw_rect(Rect2(-6, 10, 12, 30), iron)
		draw_rect(Rect2(-6, 10, 12, 30), edge, false, 1.5)
		draw_circle(Vector2(0, 16), 2.0, edge)
		draw_circle(Vector2(0, 34), 2.0, edge)
		draw_line(Vector2(0, 28), Vector2(0, 4), iron, 6.0)
		var cup := PackedVector2Array([Vector2(-15, -8), Vector2(15, -8), Vector2(9, 8), Vector2(-9, 8)])
		draw_colored_polygon(cup, iron)
		cup.append(cup[0])
		draw_polyline(cup, edge, 2.0)
		draw_line(Vector2(-14, -8), Vector2(14, -8), Color(1.0, 0.7, 0.3, 0.9), 3.0)
