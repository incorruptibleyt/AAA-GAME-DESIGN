class_name WetLook
## The Drowned Vault's skeletons (the Drowned Skeleton and the Tidecaller): weed-green bones
## that shine wet, drawn over a model as its overlay. Kept apart from the skeletons so the
## store art tool (tools/store/render_art.gd) can use it without the running game.

## One material per glow strength.
static var _mats := {}


## Weed-green bones that shine wet: a darkening pass with patches of weed, then a cold sheen
## at the edges and drops running down. `glow` lifts the whole body towards sea-green (the
## Tidecaller's dark hood needs it to stand out on the water).
static func overlay(glow := 0.0) -> ShaderMaterial:
	if _mats.has(glow):
		return _mats[glow]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float vn(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1, 0, 0)), f.x), mix(h(i + vec3(0, 1, 0)), h(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h(i + vec3(0, 0, 1)), h(i + vec3(1, 0, 1)), f.x), mix(h(i + vec3(0, 1, 1)), h(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void fragment() {
	// Multiplied in linear light, so even 0.6 darkens a lot: the weed stays light.
	float weed = smoothstep(0.55, 0.75, vn(p * 5.0) * 0.7 + vn(p * 11.0) * 0.3);
	ALBEDO = mix(vec3(0.92, 1.0, 0.97), vec3(0.55, 0.82, 0.6), weed);
}
"""
	var wet := Shader.new()
	wet.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 sheen : source_color = vec4(0.35, 0.9, 0.85, 1.0);
uniform float glow = 0.0;
varying vec3 p;
void vertex() {
	p = VERTEX;
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float lane = floor(p.x * 9.0 + p.z * 7.0);
	float drop = smoothstep(0.92, 1.0, fract(p.y * 1.5 + TIME * 0.6 + fract(sin(lane * 91.3) * 437.5)));
	ALBEDO = sheen.rgb * (rim * 0.75 + drop * 0.35 + glow);
}
"""
	# Drawn after everything see-through (the Tidecaller's hood is), or the hood can end
	# up drawn over its own glow depending on where the camera is.
	var m := ShaderMaterial.new()
	m.shader = dark
	m.render_priority = 1
	var shine := ShaderMaterial.new()
	shine.shader = wet
	shine.render_priority = 2
	shine.set_shader_parameter("glow", glow)
	m.next_pass = shine
	_mats[glow] = m
	return m
