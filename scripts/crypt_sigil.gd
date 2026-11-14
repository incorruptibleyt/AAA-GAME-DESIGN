class_name CryptSigil
## The Crypt King aura's sigil (hero_style.gd PASS_AURA): a circle of gold runes on the floor
## under the hero, its rings turning opposite ways, with a six-pointed star in the middle and a
## slow pulse. Drawn by one shader on one flat quad, added to the floor (so it glows on dark
## floors and never hides the hero), the size of the dash ring and a bit more.

static var _shader: Shader


static func make(parent: Node3D, size := 2.4, strength := 1.0) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("strength", strength)
	var q := U.floor_quad(parent, Vector2(size, size), m, Vector3(0, 0.03, 0))
	q.name = "CryptSigil"
	return q


const CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.76, 0.26, 1.0);
uniform float strength = 1.0;

float line(float d, float w, float aa) {
	return 1.0 - smoothstep(w, w + aa, abs(d));
}

// Distance from p to the edges of a triangle pointing at angle `a`, `r` from the middle.
float tri(vec2 p, float a, float r) {
	float d = -1.0;
	for (int i = 0; i < 3; i++) {
		float b = a + float(i) * 2.0943951;
		d = max(d, dot(p, vec2(cos(b), sin(b))));
	}
	return d - r * 0.5;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float aa = max(fwidth(r) * 1.5, 0.004);
	float a = atan(p.y, p.x);
	float t = TIME;
	float outer = line(r - 0.93, 0.018, aa) + line(r - 0.985, 0.008, aa) * 0.7;
	float inner = line(r - 0.64, 0.012, aa);
	// A ring of rune marks turning one way...
	float a1 = a + t * 0.45;
	float f = fract(a1 * 14.0 / 6.2831853);
	float g = fract(a1 * 42.0 / 6.2831853);
	float runes = line(r - 0.785, 0.06, aa) * step(0.18, f) * step(f, 0.82) * (0.55 + 0.45 * step(0.4, g));
	runes *= 1.0 - line(r - 0.785, 0.018, aa) * step(0.5, fract(a1 * 7.0 / 6.2831853));
	// ...ticks round the outside turning the other...
	float a2 = a - t * 0.7;
	float ticks = step(0.955, r) * step(fract(a2 * 36.0 / 6.2831853), 0.22);
	// ...and a six-pointed star inside, turning slowly.
	float a3 = t * 0.3;
	vec2 q = p;
	float star = max(line(tri(q, a3, 0.62), 0.012, aa), line(tri(q, a3 + 3.14159265, 0.62), 0.012, aa));
	star *= step(r, 0.64);
	float centre = (1.0 - smoothstep(0.0, 0.62, r)) * 0.22;
	float pulse = 0.78 + 0.22 * sin(t * 2.4);
	float v = (outer + inner * 0.9 + runes * 0.75 + ticks * 0.8 + star * 0.7) * pulse + centre;
	// Fades out at the very edge so the quad never shows.
	v *= 1.0 - smoothstep(0.97, 1.0, r);
	ALBEDO = col.rgb * v * strength * 0.8;
}
"""
