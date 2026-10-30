class_name Floors
## Each floor of the crypt has its own look, made from colours, lights, particles and its
## own props (props.gd): the Bone Crypt, the Frozen Ossuary and the Ember Catacomb, then
## round again. Each endless loop below floor 5 darkens them. To add a theme, copy an
## entry in THEMES.

const THEMES := [
	{"name": "Bone Crypt", "floor": Color(1, 1, 1), "wall": Color(0.15, 0.14, 0.19), "trim": Color(0.27, 0.25, 0.31),
		"ambient": Color(0.2, 0.19, 0.28), "fog": Color(0.03, 0.03, 0.06), "background": Color(0.02, 0.02, 0.035),
		"moon": Color(0.55, 0.6, 0.9), "torch": Color(1.0, 0.62, 0.3), "torch_energy": 1.4,
		"motes": [Color(1.0, 0.55, 0.2, 0.9), Color(0.7, 0.6, 1.0, 0.35)], "motes_fall": false, "banner": Color(1, 0.7, 0.4),
		"props": "bone"},
	{"name": "Frozen Ossuary", "floor": Color(0.74, 0.86, 1.0), "wall": Color(0.12, 0.16, 0.23), "trim": Color(0.3, 0.38, 0.48),
		"ambient": Color(0.24, 0.3, 0.44), "fog": Color(0.05, 0.08, 0.13), "background": Color(0.02, 0.035, 0.06),
		"moon": Color(0.6, 0.8, 1.0), "torch": Color(0.55, 0.8, 1.0), "torch_energy": 1.5,
		"motes": [Color(0.95, 0.98, 1.0, 0.9), Color(0.6, 0.8, 1.0, 0.4)], "motes_fall": true, "banner": Color(0.6, 0.9, 1.0),
		"props": "ice"},
	# Charcoal slabs with fire in the gaps ("seams"), so fire and warnings stand out on them.
	{"name": "Ember Catacomb", "floor": Color(0.34, 0.3, 0.3), "seams": Color(1.0, 0.28, 0.04), "wall": Color(0.19, 0.1, 0.08), "trim": Color(0.35, 0.18, 0.12),
		"ambient": Color(0.27, 0.15, 0.12), "fog": Color(0.09, 0.03, 0.02), "background": Color(0.05, 0.015, 0.01),
		"moon": Color(1.0, 0.55, 0.35), "torch": Color(1.0, 0.45, 0.18), "torch_energy": 1.7,
		# Embers stay small, dim and deep red so they never look like coins or enemy shots.
		"motes": [Color(0.95, 0.38, 0.16, 0.5), Color(0.7, 0.15, 0.06, 0.2)], "motes_fall": false, "motes_size": 0.5,
		"banner": Color(1, 0.55, 0.3), "props": "ember"},
]


static func theme(floor_num: int) -> Dictionary:
	var t: Dictionary = THEMES[(maxi(floor_num, 1) - 1) % THEMES.size()]
	var loop := Loops.loop_of(floor_num)
	return t if loop <= 1 else _deeper(t, loop)


## Every endless loop is a little darker and redder than the one before (down to loop 4).
static func _deeper(t: Dictionary, loop: int) -> Dictionary:
	var steps := mini(loop - 1, 3)
	var dark := pow(0.86, steps)
	var red := 0.14 * steps
	var d := t.duplicate()
	for key in ["ambient", "moon", "fog", "background", "wall", "trim", "torch"]:
		var c: Color = t[key]
		var blood := Color(c.get_luminance() * 1.6, c.get_luminance() * 0.4, c.get_luminance() * 0.35)
		c = c.lerp(blood, red)
		if key in ["ambient", "moon"]:
			c = Color(c.r * dark, c.g * dark, c.b * dark)
		d[key] = c
	d["banner"] = (t.banner as Color).lerp(Color(1, 0.3, 0.25), red)
	return d


static func current() -> Dictionary:
	return theme(Game.floor_num)


## The Ember Catacomb, where red warnings would melt into the floor.
static func hot() -> bool:
	return current().name == "Ember Catacomb"
