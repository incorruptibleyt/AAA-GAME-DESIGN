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
	"forge": {"key": Color(1.0, 0.42, 0.14), "stone": Color(0.7, 0.56, 0.58), "ambient": Color(0.09, 0.05, 0.07), "dust": Color(1.0, 0.55, 0.2), "embers": true, "wall": 1, "pieces": "chains"},
	"teal": {"key": Color(0.3, 0.9, 1.0), "stone": Color(0.56, 0.64, 0.74), "ambient": Color(0.05, 0.075, 0.11), "dust": Color(0.65, 1.0, 1.0)},
	"blood": {"key": Color(1.0, 0.28, 0.3), "stone": Color(0.66, 0.56, 0.64), "ambient": Color(0.09, 0.04, 0.07), "dust": Color(1.0, 0.6, 0.55)},
	"frost": {"key": Color(0.5, 0.82, 1.0), "stone": Color(0.6, 0.66, 0.8), "ambient": Color(0.045, 0.065, 0.12), "dust": Color(0.92, 0.97, 1.0)},   # v243: Frostfall
	"bone": {"key": Color(0.8, 0.86, 1.0), "stone": Color(0.62, 0.62, 0.74), "ambient": Color(0.07, 0.065, 0.12), "dust": Color(0.9, 0.95, 1.0), "wall": 3},
	# Version 357 (visual review fix 10, "menus with places of their own"): every screen sat
	# on the same stone wall. Now some are places: the Armory a forge of riveted iron plates
	# with glowing seams and chains, the Crypt Pass a vault of gold bricks with vault wheels,
	# the Bone Road an ossuary wall of skulls and bones, Records a library's shelves, the
	# Crypt Race strung with pennants, Mastery hung with banners in the hero's colour.
	"vault": {"key": Color(1.0, 0.78, 0.4), "stone": Color(0.7, 0.6, 0.72), "ambient": Color(0.09, 0.065, 0.06), "dust": Color(1.0, 0.88, 0.5), "wall": 2, "pieces": "wheels"},
	"library": {"key": Color(1.0, 0.72, 0.42), "stone": Color(0.7, 0.6, 0.6), "ambient": Color(0.08, 0.06, 0.07), "dust": Color(1.0, 0.9, 0.7), "wall": 4},
	"race": {"key": Color(0.3, 0.9, 1.0), "stone": Color(0.56, 0.64, 0.74), "ambient": Color(0.05, 0.075, 0.11), "dust": Color(0.65, 1.0, 1.0), "pieces": "pennants"},
	"hall": {"key": Color(0.55, 0.45, 1.0), "stone": Color(0.62, 0.58, 0.78), "ambient": Color(0.075, 0.06, 0.13), "dust": Color(1.0, 0.85, 0.65), "pieces": "banners"},
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
## On a screen of lists with a big empty stretch below them (version 136): a shrine fills
## it, the Bone Chain carved in the wall and glowing, with candles on the floor before it.
var _shrine: _Shrine
var _pieces: _Pieces   # version 357: a place's own things (chains, vault wheels, pennants, banners)
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
	if theme_name == "crypt" and Events.active():
		theme_name = str(EventArt.pal().menu)   # an event takes the menus over while it's on (version 134)
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
	_shrine = _Shrine.new()
	_shrine.visible = false
	add_child(_shrine)
	_pieces = _Pieces.new()
	add_child(_pieces)
	resized.connect(_layout)


func _ready() -> void:
	var th: Dictionary = THEMES.get(look, THEMES.crypt)
	_key = th.key
	_key_to = th.key
	_mat.set_shader_parameter("stone", th.stone)
	_mat.set_shader_parameter("ambient", th.ambient)
	_mat.set_shader_parameter("kind", int(th.get("wall", 0)))
	_pieces.kind = str(th.get("pieces", ""))
	_pieces.visible = _pieces.kind != ""
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
	_pieces.key = c
	_pieces.queue_redraw()
	if now:
		_key = c


func _on_shown() -> void:
	var on := is_visible_in_tree()
	set_process(on)
	_dust.emitting = on
	if on:
		_dust.restart()
		_layout()
		# Lists fill in as the screen opens, so look at the empty space again a moment later.
		get_tree().create_timer(0.15).timeout.connect(_layout)
	_shrine.set_process(on and _shrine.visible)
	for t in _torches:
		t.set_process(on and t.visible)


func _layout() -> void:
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		return
	_mat.set_shader_parameter("size", s)
	_mat.set_shader_parameter("tile", TILE)
	_pieces.size = s
	_pieces.key = _key_to
	_pieces.queue_redraw()
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
	var gap := _empty_band(s) if _focus == null else Vector2(-1, -1)
	_shrine.visible = gap.y - gap.x > 300.0
	_shrine.set_process(_shrine.visible and is_visible_in_tree())
	if _shrine.visible:
		horizon = gap.y - 64.0
		_shrine.place(Rect2(0, gap.x, s.x, gap.y - gap.x), horizon, _key_to)
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


## The empty stretch on a screen of lists, between the bottom of what it shows and the top
## of its buttons at the bottom (top, bottom), or (-1, -1) if there is none.
func _empty_band(s: Vector2) -> Vector2:
	var host := get_parent() as Control
	if host == null:
		return Vector2(-1, -1)
	var o := get_global_rect().position
	var low := 0.0
	var high := s.y
	var stack: Array = host.get_children()
	var seen := 0
	while not stack.is_empty() and seen < 400:
		seen += 1
		var c = stack.pop_back()
		if c == self or not (c is Control) or not c.visible:
			continue
		var r: Rect2 = c.get_global_rect()
		r.position -= o
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		if c is Container and not c is ScrollContainer and r.size.y > s.y * 0.4:
			stack.append_array(c.get_children())   # a frame around everything: look inside
			continue
		if c.get_class() == "Control" or c is ColorRect and c.color.a > 0.9 and r.size.y > s.y * 0.9:
			stack.append_array(c.get_children())
			continue
		if c is Label and c.text == "":
			continue
		if r.get_center().y < s.y * 0.72:
			low = maxf(low, r.end.y)
		else:
			high = minf(high, r.position.y)
	if low <= 0.0:
		return Vector2(-1, -1)
	return Vector2(low + 28.0, high - 16.0)


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
uniform int kind = 0;   // the wall: 0 crypt stones, 1 forge plates, 2 gold bricks, 3 skulls and bones, 4 bookshelves

float h1(vec2 c) { return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453); }

// A bevelled block of size cs at f (pixels inside it): its edge distance and slope.
float block(vec2 f, vec2 cs, float bev, out vec2 nn) {
	vec2 e2 = min(f, cs - f);
	float e = min(e2.x, e2.y);
	vec2 dir = vec2(f.x < cs.x * 0.5 ? -1.0 : 1.0, f.y < cs.y * 0.5 ? -1.0 : 1.0);
	nn = (e2.x < e2.y ? vec2(dir.x, 0.0) : vec2(0.0, dir.y)) * (1.0 - smoothstep(0.0, bev, e)) * 0.75;
	return e;
}

// A place's own wall (version 357), in place of the crypt stones.
void place_wall(vec2 p, inout float alb, inout vec2 nn, inout vec3 tint, inout vec3 emit) {
	if (kind == 1) {
		// The forge: riveted iron plates, some seams glowing hot.
		vec2 cs = vec2(tile * 0.62, tile * 0.42);
		float row = floor(p.y / cs.y);
		vec2 q = vec2(p.x + mod(row, 2.0) * cs.x * 0.5, p.y);
		vec2 cell = floor(q / cs);
		vec2 f = q - cell * cs;
		float r = h1(cell);
		float e = block(f, cs, 10.0, nn);
		alb = 0.62 + 0.16 * r + 0.05 * sin(f.x * 0.07 + r * 6.0) * sin(f.y * 0.09);
		float seam = 1.0 - smoothstep(2.0, 5.0, e);
		alb = mix(alb, 0.03, seam);
		float hot = step(0.35, h1(cell + 7.0));
		emit += vec3(1.0, 0.4, 0.08) * seam * hot * (0.6 + 0.4 * sin(TIME * 1.6 + r * 9.0)) * 1.3;
		vec2 rp = vec2(f.x < cs.x * 0.5 ? 15.0 : cs.x - 15.0, f.y < cs.y * 0.5 ? 15.0 : cs.y - 15.0);
		vec2 d = (f - rp) / 6.5;
		if (dot(d, d) < 1.0) { nn = d * 0.85; alb = 0.95; }
		tint = vec3(0.72, 0.7, 0.76);
	} else if (kind == 2) {
		// The vault: gold bricks with a slow shine passing over them.
		vec2 cs = vec2(tile * 0.4, tile * 0.16);
		float row = floor(p.y / cs.y);
		vec2 q = vec2(p.x + mod(row, 2.0) * cs.x * 0.5, p.y);
		vec2 cell = floor(q / cs);
		vec2 f = q - cell * cs;
		float r = h1(cell);
		float e = block(f, cs, 7.0, nn);
		float joint = 1.0 - smoothstep(1.5, 3.0, e);
		alb = mix(0.62 + 0.18 * r, 0.06, joint);
		float sh = smoothstep(0.93, 1.0, sin((p.x + p.y * 0.6) * 0.008 - TIME * 0.5));
		emit += vec3(1.0, 0.85, 0.5) * sh * 0.22 * (1.0 - joint);
		tint = vec3(1.0, 0.74, 0.32);
	} else if (kind == 3) {
		// An ossuary: rows of skulls between rows of stacked long bones.
		float H = tile * 0.26;
		float row = floor(p.y / H);
		float fy = (p.y - row * H) / H;
		alb = 0.1;
		nn = vec2(0.0);
		if (mod(row, 2.0) < 1.0) {
			float W = H * 0.92;
			float x = p.x + mod(row, 4.0) * W * 0.25;
			float cx = floor(x / W);
			vec2 u = vec2((x - cx * W) / W, fy);
			vec2 c = u - vec2(0.5, 0.42);
			float R = 0.36;
			bool jaw = abs(u.x - 0.5) < 0.2 && u.y > 0.6 && u.y < 0.88;
			if (dot(c, c) < R * R || jaw) {
				alb = 0.58 + 0.08 * h1(vec2(cx, row));
				nn = jaw ? vec2(0.0, 0.3) : c / R * 0.8;
				vec2 el = u - vec2(0.36, 0.5);
				vec2 er = u - vec2(0.64, 0.5);
				if (dot(el, el) < 0.011 || dot(er, er) < 0.011) { alb = 0.04; nn = -nn * 0.5; }
				vec2 no = (u - vec2(0.5, 0.66)) * vec2(1.0, 0.7);
				if (dot(no, no) < 0.0016) alb = 0.05;
				if (jaw && abs(fract(u.x * 10.0) - 0.5) < 0.08) alb = 0.25;
			}
		} else {
			float sub = floor(fy * 2.0);
			float sy = fract(fy * 2.0);
			float W = H * 2.4;
			float x = p.x + h1(vec2(row, sub)) * W;
			float cx = floor(x / W);
			float ux = (x - cx * W) / W;
			float shaft = abs(sy - 0.5);
			float k1 = length(vec2((ux - 0.07) * 4.0, (sy - 0.5) * 1.1));
			float k2 = length(vec2((ux - 0.93) * 4.0, (sy - 0.5) * 1.1));
			if ((ux > 0.07 && ux < 0.93 && shaft < 0.27) || k1 < 0.5 || k2 < 0.5) {
				alb = 0.5 + 0.08 * h1(vec2(cx, row + sub));
				nn = vec2(0.0, (sy - 0.5) * 1.5);
			}
		}
		tint = vec3(0.95, 0.9, 0.8);
	} else if (kind == 4) {
		// A library: shelves of books, a board under each row.
		float H = tile * 0.42;
		float row = floor(p.y / H);
		float fy = p.y - row * H;
		if (fy > H - 14.0) {
			alb = 0.55;
			nn = vec2(0.0, fy > H - 4.0 ? 0.5 : -0.25);
			tint = vec3(0.55, 0.35, 0.2);
		} else {
			float w = 23.0;
			float x = p.x + row * 41.0;
			float bi = floor(x / w);
			float u = (x - bi * w) / w;
			float r = h1(vec2(bi, row));
			float top = 8.0 + 30.0 * h1(vec2(row, bi + 3.0));
			if (fy < top || u < 0.05 || u > 0.95) {
				alb = 0.06;
				tint = vec3(0.4, 0.3, 0.25);
			} else {
				alb = 0.72;
				nn = vec2((u - 0.5) * 1.3, 0.0);
				float pick = floor(r * 6.0);
				tint = pick < 1.0 ? vec3(0.7, 0.16, 0.13) : pick < 2.0 ? vec3(0.16, 0.45, 0.24) : pick < 3.0 ? vec3(0.2, 0.28, 0.62)
					: pick < 4.0 ? vec3(0.55, 0.34, 0.16) : pick < 5.0 ? vec3(0.42, 0.2, 0.55) : vec3(0.15, 0.48, 0.5);
				float b = fy - top;
				if ((b > 9.0 && b < 13.0) || (fy > H - 32.0 && fy < H - 28.0)) tint = vec3(1.0, 0.78, 0.36);
			}
		}
	}
}

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
	vec3 tint = stone;     // the wall's own colour
	vec3 emit = vec3(0.0); // what glows by itself (the forge's hot seams, the vault's shine)
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
		if (kind > 0) {
			place_wall(p, alb, nn, tint, emit);
		}
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
	vec3 c = alb * tint * light * (1.0 - depth) + emit;
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


## The shrine under a short list: the Bone Chain (a ring of linked bones around two crossed
## ones) carved in the wall and glowing in the screen's light, and a row of candles on the
## floor in front of it.
class _Shrine extends Control:
	const CANDLES := [Vector3(-0.30, 34, 0), Vector3(-0.19, 50, 18), Vector3(-0.08, 28, 6), Vector3(0.08, 30, 8),
		Vector3(0.19, 46, 20), Vector3(0.30, 36, 2)]   # x (part of the width), height, how far forward
	var _emblem: ColorRect
	var _mat: ShaderMaterial
	var _glows: _Glows
	var _floor := 0.0
	var _t := 0.0
	static var _shader: Shader

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_emblem = ColorRect.new()
		_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _shader == null:
			_shader = Shader.new()
			_shader.code = EMBLEM
		_mat = ShaderMaterial.new()
		_mat.shader = _shader
		_emblem.material = _mat
		add_child(_emblem)
		_glows = _Glows.new()
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glows.material = add
		add_child(_glows)

	## Fills `band` (in the backdrop's space), with the floor at `floor_y`, lit in `key`.
	func place(band: Rect2, floor_y: float, key: Color) -> void:
		position = Vector2.ZERO
		size = band.end
		_floor = floor_y
		var d := minf(band.size.x * 0.6, (floor_y - band.position.y) * 0.92)
		_emblem.size = Vector2(d, d)
		_emblem.position = Vector2(band.size.x * 0.5 - d * 0.5, band.position.y + (floor_y - band.position.y - d) * 0.45)
		_mat.set_shader_parameter("col", Vector3(key.r, key.g, key.b).lerp(Vector3(1.0, 0.9, 0.75), 0.45))
		_glows.spots.clear()
		for c in CANDLES:
			_glows.spots.append(Vector3(band.size.x * (0.5 + c.x), floor_y + 14.0 + c.z, c.y))
		_glows.queue_redraw()
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_glows.t = _t
		_glows.queue_redraw()

	func _draw() -> void:
		# the candles' wax, lit warm on one side
		for c in _glows.spots:
			var w := 12.0
			var base := Vector2(c.x, c.y)
			draw_rect(Rect2(base.x - w * 0.5, base.y - c.z, w, c.z), Color(0.78, 0.68, 0.55))
			draw_rect(Rect2(base.x - w * 0.5, base.y - c.z, w * 0.35, c.z), Color(0.95, 0.86, 0.68))
			draw_circle(base + Vector2(0, -c.z), w * 0.5, Color(0.9, 0.8, 0.62))
			draw_rect(Rect2(base.x - w * 0.5 - 2, base.y - 3, w + 4, 4), Color(0.3, 0.24, 0.2))   # a drip of wax at the foot
			draw_line(base + Vector2(0, -c.z), base + Vector2(0, -c.z - 6), Color(0.12, 0.08, 0.06), 2.0)

	const EMBLEM := """
shader_type canvas_item;
render_mode blend_add;
uniform vec3 col = vec3(1.0, 0.85, 0.6);

float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}
// A bone along x: a shaft with two knobs at each end.
float bone(vec2 p, float len, float w) {
	float d = capsule(p, vec2(-len * 0.5, 0.0), vec2(len * 0.5, 0.0), w * 0.42);
	d = min(d, length(p - vec2(-len * 0.5, w * 0.48)) - w * 0.55);
	d = min(d, length(p - vec2(-len * 0.5, -w * 0.48)) - w * 0.55);
	d = min(d, length(p - vec2(len * 0.5, w * 0.48)) - w * 0.55);
	d = min(d, length(p - vec2(len * 0.5, -w * 0.48)) - w * 0.55);
	return d;
}
vec2 rot(vec2 p, float a) { return vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float spin = TIME * 0.06;
	float N = 11.0;
	float seg = 6.2831853 / N;
	float a = atan(p.y, p.x) + spin;
	float k = floor(a / seg + 0.5);
	vec2 q = rot(p, -(k * seg - spin));       // this bone's own frame: x out from the middle
	float R = 0.74;
	float d = bone(vec2(q.y, q.x - R), 2.0 * 3.14159 * R / N * 0.86, 0.085);
	// the next bone over, so the links overlap like a chain
	d = min(d, length(vec2(q.y - 3.14159 * R / N, q.x - R)) - 0.05);
	// two crossed bones in the middle, and a thin ring around them
	d = min(d, bone(rot(p, 0.785), 0.62, 0.11));
	d = min(d, bone(rot(p, -0.785), 0.62, 0.11));
	d = min(d, abs(length(p) - 0.52) - 0.012);
	d = min(d, abs(length(p) - 0.95) - 0.01);
	float aa = fwidth(d) * 1.2;
	float body = 1.0 - smoothstep(0.0, aa, d);
	float rim = (1.0 - smoothstep(0.0, aa, abs(d + 0.012))) * 0.8;   // a lit edge round each carving
	float glow = exp(-max(d, 0.0) * 14.0) * 0.35;
	float pulse = 0.82 + 0.18 * sin(TIME * 1.4);
	float fade = 1.0 - smoothstep(0.9, 1.0, length(p));
	COLOR = vec4(col * (body * 0.32 + rim * 0.5 + glow) * pulse * fade, 1.0);
}
"""


## The candle flames and their warm glow, added on top.
class _Glows extends Node2D:
	var spots: Array = []
	var t := 0.0

	func _draw() -> void:
		var dot := MenuBackdrop.dot()
		for i in spots.size():
			var c: Vector3 = spots[i]
			var f := 1.0 + 0.12 * sin(t * 9.0 + i * 1.7) + 0.07 * sin(t * 17.0 + i)
			var tip := Vector2(c.x, c.y - c.z - 13.0)
			var g := 110.0 * f
			draw_texture_rect(dot, Rect2(tip - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1.0, 0.5, 0.18, 0.28))
			draw_texture_rect(dot, Rect2(tip - Vector2(7, 11) * f, Vector2(14, 22) * f), false, Color(1.0, 0.72, 0.3, 0.95))
			draw_texture_rect(dot, Rect2(tip - Vector2(3.5, 5) * f + Vector2(0, 3), Vector2(7, 10) * f), false, Color(1.0, 0.97, 0.85, 1.0))


## Version 357: a place's own things at the top of the screen, over its wall and behind the
## menu: the forge's hanging chains, the vault's great wheels, the race's pennants, the hall's
## banners in the hero's colour (`key`).
class _Pieces extends Control:
	var kind := ""
	var key := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		match kind:
			"chains":
				for side in [0.045, 0.955]:
					_chain(Vector2(s.x * side, -10.0), s.y * 0.34)
			"wheels":
				_wheel(Vector2(0.0, s.y * 0.07), s.x * 0.17)
				_wheel(Vector2(s.x, s.y * 0.07), s.x * 0.17)
			"pennants":
				_string(Vector2(-10.0, s.y * 0.005), Vector2(s.x + 10.0, s.y * 0.005), s.y * 0.035, 0)
				_string(Vector2(-10.0, s.y * 0.04), Vector2(s.x + 10.0, s.y * 0.04), s.y * 0.03, 1)
			"banners":
				for side in [0.1, 0.9]:
					_banner(Vector2(s.x * side, 0.0), s.x * 0.075, s.y * 0.085)

	## An iron chain hanging from `top`, `length` long, a hook at its end.
	func _chain(top: Vector2, length: float) -> void:
		var iron := Color(0.13, 0.1, 0.1)
		var lit := Color(0.85, 0.42, 0.18)   # the forge's light on its edges
		var y := top.y
		var i := 0
		while y < top.y + length:
			if i % 2 == 0:   # a link seen face on: an open oval
				draw_set_transform(Vector2(top.x, y + 16.0), 0.0, Vector2(0.62, 1.0))
				draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 20, iron, 10.0)
				draw_arc(Vector2.ZERO, 17.0, PI * 0.85, PI * 1.65, 8, lit, 3.5)
				draw_set_transform(Vector2.ZERO)
			else:   # side on: a bar
				draw_rect(Rect2(top.x - 4.5, y + 2.0, 9.0, 28.0), iron)
				draw_rect(Rect2(top.x - 4.5, y + 2.0, 3.0, 28.0), lit)
			y += 25.0
			i += 1
		draw_arc(Vector2(top.x + 9.0, y + 14.0), 12.0, PI * 0.1, PI * 1.25, 12, iron, 7.0)
		draw_arc(Vector2(top.x + 9.0, y + 14.0), 12.0, PI * 0.8, PI * 1.25, 6, lit, 2.0)

	## A vault door's great gold handwheel, centred at `c`.
	func _wheel(c: Vector2, r: float) -> void:
		var dark := Color(0.35, 0.22, 0.06)
		var gold := Color(0.95, 0.72, 0.3)
		var hi := Color(1.0, 0.92, 0.6)
		draw_arc(c, r * 1.25, 0.0, TAU, 48, Color(0.1, 0.07, 0.05, 0.85), r * 0.18)   # the door's rim
		for k in 12:   # its bolts
			var a := TAU * k / 12.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 1.25, r * 0.05, gold.darkened(0.2))
		for k in 6:
			var a := TAU * k / 6.0 + 0.26
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * r * 0.2, c + d * r, dark, r * 0.12)
			draw_line(c + d * r * 0.2, c + d * r, gold, r * 0.07)
			draw_circle(c + d * r * 1.05, r * 0.1, gold)   # a grip on each spoke
			draw_circle(c + d * r * 1.05 + Vector2(-0.3, -0.3) * r * 0.05, r * 0.04, hi)
		draw_arc(c, r, 0.0, TAU, 48, dark, r * 0.14)
		draw_arc(c, r, 0.0, TAU, 48, gold, r * 0.09)
		draw_arc(c, r, PI * 1.05, PI * 1.45, 12, hi, r * 0.03)
		draw_circle(c, r * 0.22, dark)
		draw_circle(c, r * 0.17, gold)

	## A string of pennants from `a` to `b`, sagging `sag` in the middle.
	func _string(a: Vector2, b: Vector2, sag: float, row: int) -> void:
		var cols := [Color(0.25, 0.85, 0.95), Color(1.0, 0.78, 0.3), Color(0.95, 0.35, 0.4), Color(0.65, 0.5, 1.0)]
		var n := 30
		var pts := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			pts.append(a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
		draw_polyline(pts, Color(0.12, 0.1, 0.12), 3.0)
		var step := 2
		for i in range(1, n, step):
			var p0: Vector2 = pts[i - 1].lerp(pts[i], 0.5)
			var p1: Vector2 = pts[i].lerp(pts[i + 1], 0.5)
			var mid := (p0 + p1) * 0.5 + Vector2(0, 28.0)
			var col: Color = cols[(i / step + row) % cols.size()]
			draw_colored_polygon(PackedVector2Array([p0, p1, mid]), col.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([p0, p0.lerp(p1, 0.45), mid]), col)

	## A hanging banner in the hero's colour, `w` wide and `h` long, from `top`.
	func _banner(top: Vector2, w: float, h: float) -> void:
		var cloth := key.darkened(0.25)
		var gold := Color(1.0, 0.8, 0.35)
		draw_line(top + Vector2(-w * 0.75, 6.0), top + Vector2(w * 0.75, 6.0), Color(0.3, 0.2, 0.12), 7.0)
		var pts := PackedVector2Array([top + Vector2(-w * 0.5, 6.0), top + Vector2(w * 0.5, 6.0), top + Vector2(w * 0.5, h),
			top + Vector2(0.0, h - w * 0.45), top + Vector2(-w * 0.5, h)])
		draw_colored_polygon(pts, cloth)
		draw_colored_polygon(PackedVector2Array([pts[0], top + Vector2(-w * 0.2, 6.0), top + Vector2(-w * 0.2, h - w * 0.3), pts[4]]), cloth.lightened(0.12))
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, gold, 3.0)
		var c := top + Vector2(0.0, h * 0.45)
		draw_circle(c, w * 0.3, gold)
		draw_circle(c, w * 0.22, cloth.darkened(0.3))
		draw_line(c + Vector2(-w * 0.13, -w * 0.13), c + Vector2(w * 0.13, w * 0.13), gold, 4.0)   # crossed bones
		draw_line(c + Vector2(w * 0.13, -w * 0.13), c + Vector2(-w * 0.13, w * 0.13), gold, 4.0)
