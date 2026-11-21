class_name Ambience
extends Node
## Room tone under the music, one for each floor theme: a slow cold draught in the Bone
## Crypt with water dripping somewhere, a thin whistling wind in the Frozen Ossuary with
## ice ticking now and then, a low fire roar in the Ember Catacomb with embers popping, and
## water lapping in the Drowned Vault with bubbles rising, and in the Glowcap Grotto a soft
## hollow cave air with a faint shimmer, where the fungus chimes now and then. Frostfall Hall
## (the winter event, version 243): a storm howling outside, a fire crackling close by, and
## now and then Krampus's bells jingling somewhere far off. The Sandfall Tomb (version 247):
## a dry desert wind moaning over the tomb, sand hissing as it pours in, and now and then a
## slide of sand somewhere in the walls. The Amethyst Mine (version 248): the deep rumble
## of the mountain, timbers creaking, crystals humming faintly, and now and then the clink
## of a pick far off down a tunnel. The Whispering Library (version 249): still air, a tall
## clock ticking, voices whispering just too low to make out, and now and then the pages of
## a book riffling by themselves. The Clockwork Foundry (version 250): the deep drone of the
## furnaces, gears ticking round and a hammer far off, and now and then steam blowing off.
## All of it is made in code. The draught loops play on the Music bus, so they muffle with
## the music when the game is paused; the drips and pops go through the Effects echo. It
## follows the Sounds setting, and is silent on the title screen.
##
## The loops take a moment to make, so a worker thread builds them at launch, and the
## first room plays without one if the phone isn't done yet.

const RATE := 11025          # the loops are all low sounds, so half the effects' rate
const LOOP_SECONDS := 6.0
const FADE := 1.2            # seconds to fade between floors, in and out
## The loops sit about 10 dB under the music. Phone speakers barely play anything below
## 150 Hz, so each loop also has some sound higher up.
const VOLUME_DB := -19.0
## The bed of each theme, then its one-off sound and how often that comes (seconds).
const EVERY := [Vector2(3.0, 8.0), Vector2(4.0, 9.0), Vector2(1.2, 3.5), Vector2(2.0, 5.5), Vector2(3.5, 8.0), Vector2(2.5, 5.0), Vector2(5.0, 11.0), Vector2(3.0, 7.0), Vector2(4.0, 9.0), Vector2(4.0, 10.0), Vector2(3.5, 8.0)]

static var _instance: Ambience
## Version 243: Frostfall's Blizzard turns the storm up (0..1, blizzard.gd).
static var gust := 0.0
var _beds: Array = [null, null, null, null, null, null, null, null, null, null, null]
var _ones: Array = [null, null, null, null, null, null, null, null, null, null, null]
var _task := -1
var _player: AudioStreamPlayer
var _theme := -1
var _level := 0.0            # 0 silent .. 1 full, eased
var _next_one := 4.0


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = -80.0
	add_child(_player)
	_task = WorkerThreadPool.add_task(_build_all, false, "ambience")


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(delta: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	# Which loop should be playing: the floor's, or none (title screen, sounds off, or the
	# loops aren't made yet).
	var want := -1
	if _task == -1 and Sfx.enabled and Game.state != Game.State.TITLE and Game.floor_num >= 1:
		want = Floors.index(Game.floor_num)
	if want != _theme:
		# Fade the old one out first, then start the new one somewhere in its loop.
		_level = move_toward(_level, 0.0, delta / FADE)
		if _level <= 0.0:
			_player.stop()
			_theme = want
			if want >= 0:
				_player.stream = _beds[want]
				_player.play(randf() * LOOP_SECONDS * 0.9)
	else:
		_level = move_toward(_level, 1.0 if _theme >= 0 else 0.0, delta / FADE)
	_player.volume_db = VOLUME_DB + linear_to_db(maxf(_level, 0.0001)) + 12.0 * gust
	# Now and then a drip, a tick of ice, a popping ember or a bubble, but only while fighting.
	if Game.state == Game.State.PLAYING and _theme >= 0 and _level > 0.5:
		_next_one -= delta
		if _next_one <= 0.0:
			var every: Vector2 = EVERY[_theme]
			_next_one = randf_range(every.x, every.y)
			Sfx.play_stream(_ones[_theme], randf_range(0.18, 0.32), randf_range(0.8, 1.3))


# ---------------------------------------------------------------- making the sounds
# Everything below runs on the worker thread: it only fills arrays and makes streams.

func _build_all() -> void:
	_beds[0] = _loop(_crypt_bed)
	_ones[0] = _one(0.5, _drip)
	_beds[1] = _loop(_ice_bed)
	_ones[1] = _one(0.6, _tick)
	_beds[2] = _loop(_ember_bed)
	_ones[2] = _one(0.35, _pop)
	_beds[3] = _loop(_water_bed)
	_ones[3] = _one(0.4, _bubble)
	_beds[4] = _loop(_grotto_bed)
	_ones[4] = _one(1.2, _glimmer)
	# The Blood Moon Crypt (version 134): the crypt's draught, lower, and a slow heartbeat.
	_beds[5] = _loop(_moon_bed)
	_ones[5] = _one(0.9, _heartbeat)
	_beds[6] = _loop(_storm_bed)
	_ones[6] = _one(1.1, _bells)
	_beds[7] = _loop(_sand_bed)
	_ones[7] = _one(1.3, _sand_slide)
	_beds[8] = _loop(_mine_bed)
	_ones[8] = _one(1.6, _clink)
	_beds[9] = _loop(_library_bed)
	_ones[9] = _one(1.3, _pages)
	_beds[10] = _loop(_foundry_bed)
	_ones[10] = _one(1.4, _steam)


## A seamless loop: makes a little more than LOOP_SECONDS and fades the extra into the start.
func _loop(make: Callable) -> AudioStreamWAV:
	var n := int(LOOP_SECONDS * RATE)
	var tail := int(0.75 * RATE)
	var x: PackedFloat32Array = make.call(n + tail)
	for i in tail:
		var k := float(i) / tail
		x[i] = x[i] * k + x[n + i] * (1.0 - k)
	x.resize(n)
	var s := _wav(x, RATE)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s


func _one(seconds: float, make: Callable) -> AudioStreamWAV:
	return _wav(make.call(int(seconds * Sfx.RATE)), Sfx.RATE)


func _wav(x: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


## Noise through a one-pole low-pass whose corner drifts between two frequencies, with
## a slow swell in loudness: the sound of air moving through stone.
func _wind(n: int, low_hz: float, high_hz: float, swell_s: float, gain: float, rng_seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var x := PackedFloat32Array()
	x.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var drift := 0.5 + 0.5 * sin(TAU * t / swell_s) * sin(TAU * t / (swell_s * 0.37) + 1.3)
		var hz := lerpf(low_hz, high_hz, drift)
		var a := 1.0 - exp(-TAU * hz / RATE)
		y += a * (rng.randf() * 2.0 - 1.0 - y)
		y2 += a * (y - y2)
		x[i] = y2 * gain * (0.55 + 0.45 * drift)
	return x


func _crypt_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 120.0, 480.0, 6.0, 2.0, 7)
	for i in n:
		x[i] += sin(TAU * 41.0 * i / RATE) * 0.025   # a faint hum from deep below
	return x


func _ice_bed(n: int) -> PackedFloat32Array:
	# Two layers: a low draught and a thin, whistling high one (a band of noise).
	var low := _wind(n, 90.0, 300.0, 5.0, 1.8, 11)
	var a := _wind(n, 700.0, 1500.0, 3.0, 1.0, 12)
	var b := _wind(n, 450.0, 1000.0, 3.0, 1.0, 12)
	for i in n:
		low[i] += (a[i] - b[i]) * 1.4
	return low


func _ember_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 70.0, 230.0, 4.0, 2.6, 21)   # the roar of a big fire far off
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var crackle := 0.0
	for i in n:
		# Little crackles in the fire: a click that dies away in a few milliseconds.
		if rng.randf() < 0.0009:
			crackle = rng.randf_range(0.08, 0.25) * (1.0 if rng.randf() < 0.5 else -1.0)
		x[i] += crackle * (rng.randf() * 2.0 - 1.0)
		crackle *= 0.86
	return x


## Water lapping at stone: a low wash that rises and falls with the swell (two waves out of
## step), and a faint high trickle running somewhere.
func _water_bed(n: int) -> PackedFloat32Array:
	var wash := _wind(n, 160.0, 650.0, 3.0, 1.6, 31)
	var a := _wind(n, 1300.0, 2400.0, 2.0, 1.0, 32)
	var b := _wind(n, 900.0, 1700.0, 2.0, 1.0, 32)
	for i in n:
		var t := float(i) / RATE
		# 2 and 3 seconds: the loop is 6, so both swells meet up again at its seam.
		var swell := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * t / 2.0) * sin(TAU * t / 3.0 + 0.8), 2.0)
		wash[i] = wash[i] * swell + (a[i] - b[i]) * 0.5
	return wash


## A big hollow cave: a slow low draught, a faint hum, and a soft shimmer up high that
## swells and fades (two close notes beating slowly against each other).
func _grotto_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 90.0, 360.0, 6.0, 1.9, 41)
	for i in n:
		var t := float(i) / RATE
		# 1.5 and 3 seconds, so the swells meet again at the loop's seam (6 s).
		var swell := 0.5 + 0.5 * sin(TAU * t / 3.0)
		var shimmer := (sin(TAU * 1567.0 * t) + sin(TAU * 1568.5 * t)) * 0.5
		x[i] += sin(TAU * 55.0 * t) * 0.02 + shimmer * 0.012 * swell * swell
	return x


## The fungus chiming: three soft bell notes falling (a little pentatonic tune), each
## fading in gently instead of striking.
func _glimmer(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var notes := [1760.0, 1480.0, 1175.0]
	for k in notes.size():
		var start := 0.16 * k
		var hz: float = notes[k]
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t < 0.0:
				continue
			var env := minf(t / 0.03, 1.0) * exp(-t * 5.0)
			x[i] += (sin(TAU * hz * t) + sin(TAU * hz * 2.01 * t) * 0.25) * env * (0.32 - 0.06 * k)
	return x


## Two bubbles rising out of deep water: low "bloops" that slide up.
func _bubble(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for k in 2:
		var start := 0.0 if k == 0 else 0.13
		var base := 260.0 if k == 0 else 340.0
		var phase := 0.0
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t < 0.0:
				continue
			var hz := base * (1.0 + 1.6 * minf(t / 0.07, 1.0))
			phase += TAU * hz / Sfx.RATE
			x[i] += sin(phase) * exp(-t * 30.0) * minf(t / 0.004, 1.0) * (0.6 - 0.2 * k)
	return x


## A water drop into a puddle: a quick rising "plink".
func _drip(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / Sfx.RATE
		var hz := 700.0 + 1500.0 * minf(t / 0.05, 1.0)
		phase += TAU * hz / Sfx.RATE
		x[i] = sin(phase) * exp(-t * 28.0) * minf(t / 0.002, 1.0) * 0.7
	return x


func _moon_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 80.0, 300.0, 7.0, 2.2, 31)
	for i in n:
		x[i] += sin(TAU * 36.7 * i / RATE) * 0.03 * (0.6 + 0.4 * sin(TAU * i / RATE / 9.0))
	return x


## A heartbeat far below: two soft low thumps.
func _heartbeat(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for k in 2:
		var start := 0.28 * k
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t >= 0.0:
				var hz := 58.0 - 18.0 * minf(t / 0.12, 1.0)
				x[i] += sin(TAU * hz * t) * exp(-t * 16.0) * minf(t / 0.004, 1.0) * (0.9 - 0.3 * k)
	return x


## Ice settling: two or three glassy high notes close together.
func _tick(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for k in 3:
		var start := 0.045 * k
		var hz: float = [2637.0, 3520.0, 3136.0][k]
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t >= 0.0:
				x[i] += sin(TAU * hz * t) * exp(-t * 22.0) * (0.45 - 0.1 * k)
	return x


## An ember popping: a short burst of noise over a soft thump.
func _pop(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in n:
		var t := float(i) / Sfx.RATE
		x[i] = (rng.randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.8 + sin(TAU * (110.0 - t * 200.0) * t) * exp(-t * 25.0) * 0.4
	return x


## Frostfall Hall: a storm howling outside the walls (a high moaning band of wind that
## swells and falls) over a low draught, with a hearth crackling close by.
func _storm_bed(n: int) -> PackedFloat32Array:
	var low := _wind(n, 80.0, 260.0, 6.0, 1.7, 61)
	var a := _wind(n, 500.0, 1100.0, 2.0, 1.0, 62)
	var b := _wind(n, 330.0, 760.0, 2.0, 1.0, 62)
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	var crackle := 0.0
	for i in n:
		var t := float(i) / RATE
		# 3 and 6 second swells meet again at the loop's seam.
		var howl := 0.3 + 0.7 * pow(0.5 + 0.5 * sin(TAU * t / 3.0 + 0.4) * sin(TAU * t / 6.0), 2.0)
		low[i] += (a[i] - b[i]) * 1.6 * howl
		if rng.randf() < 0.0005:
			crackle = rng.randf_range(0.05, 0.16) * (1.0 if rng.randf() < 0.5 else -1.0)
		low[i] += crackle * (rng.randf() * 2.0 - 1.0)
		crackle *= 0.85
	return low


## Sleigh bells far off: a short shaken run of small bright jingles, fading away.
func _bells(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for k in 9:
		var start := k * 0.085 + rng.randf() * 0.03
		var hz := rng.randf_range(2600.0, 3300.0)
		var amp := 0.22 * (1.0 - k / 10.0)
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t >= 0.0:
				x[i] += (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.76 * t)) * exp(-t * 18.0) * minf(t / 0.002, 1.0) * amp
	return x



## The Sandfall Tomb: a dry wind moaning low over the desert above (two close bands of wind,
## out of step), and the fine hiss of sand pouring in through the cracks, swelling and
## thinning as the streams shift.
func _sand_bed(n: int) -> PackedFloat32Array:
	var low := _wind(n, 110.0, 380.0, 6.0, 1.8, 81)
	var a := _wind(n, 1400.0, 2600.0, 3.0, 1.0, 82)
	var b := _wind(n, 1000.0, 1900.0, 3.0, 1.0, 82)
	var c := _wind(n, 420.0, 900.0, 2.0, 1.0, 83)
	var d := _wind(n, 300.0, 640.0, 2.0, 1.0, 83)
	for i in n:
		var t := float(i) / RATE
		# 2, 3 and 6 second swells all meet again at the loop's seam.
		var pour := 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TAU * t / 2.0 + 0.7) * sin(TAU * t / 3.0), 2.0)
		var moan := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * t / 6.0 + 1.1), 2.0)
		low[i] += (a[i] - b[i]) * 0.9 * pour + (c[i] - d[i]) * 1.1 * moan
	return low


## A slide of sand somewhere in the walls: a hiss that swells and runs out, with a few grains
## and pebbles ticking down at its end.
func _sand_slide(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / Sfx.RATE
		var env := minf(t / 0.25, 1.0) * exp(-maxf(t - 0.25, 0.0) * 3.2)
		# Noise through two high-passes of a low-pass: a band from about 1.5 to 5 kHz.
		var w := rng.randf() * 2.0 - 1.0
		y += 0.5 * (w - y)
		y2 += 0.18 * (y - y2)
		x[i] = (y - y2) * env * 0.9
	for k in 5:
		var start := 0.55 + k * 0.11 + rng.randf() * 0.05
		var hz := rng.randf_range(1800.0, 3200.0)
		for i in n:
			var t := float(i) / Sfx.RATE - start
			if t >= 0.0:
				x[i] += sin(TAU * hz * t) * exp(-t * 60.0) * minf(t / 0.001, 1.0) * 0.18 * (1.0 - k * 0.15)
	return x


## The Amethyst Mine: the low rumble of the rock above, a timber creaking now and then (a
## slow, rough rising tone), and a faint hum from the crystals (two close high notes beating).
func _mine_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 60.0, 200.0, 6.0, 2.3, 101)
	var rng := RandomNumberGenerator.new()
	rng.seed = 102
	var creak_at := [0.8, 3.9]
	for i in n:
		var t := float(i) / RATE
		var hum := (sin(TAU * 988.0 * t) + sin(TAU * 990.0 * t)) * 0.5
		x[i] += hum * 0.008 * (0.6 + 0.4 * sin(TAU * t / 3.0))
		for c: float in creak_at:
			var ct := t - c
			if ct > 0.0 and ct < 0.7:
				var hz := 95.0 + 60.0 * ct
				var buzz := signf(sin(TAU * hz * ct)) * (0.6 + 0.4 * rng.randf())
				x[i] += buzz * 0.025 * sin(PI * ct / 0.7)
	return x


## A pick striking rock far off down a tunnel: three ringing clinks, each with its echo.
func _clink(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for k in 3:
		for e in 2:
			var start := k * 0.45 + e * 0.16
			var amp := (0.32 - k * 0.04) * (1.0 if e == 0 else 0.3)
			for i in n:
				var t := float(i) / Sfx.RATE - start
				if t >= 0.0:
					x[i] += (sin(TAU * 2350.0 * t) + 0.6 * sin(TAU * 3910.0 * t) + 0.4 * sin(TAU * 1270.0 * t)) * exp(-t * 26.0) * minf(t / 0.001, 1.0) * amp
	return x


## The Whispering Library: still air, a tall clock (tick and a lower tock, one a second, so
## six meet the loop's seam) and whispering: breathy noise shaped into syllables that come
## and go, high enough for a phone's speaker.
func _library_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 90.0, 260.0, 6.0, 1.2, 111)
	var a := _wind(n, 2200.0, 4200.0, 2.0, 1.0, 112)
	var b := _wind(n, 1500.0, 2800.0, 2.0, 1.0, 112)
	var rng := RandomNumberGenerator.new()
	rng.seed = 113
	# The syllables: short swells at their own times, in two bursts of "speech" a loop.
	var sy: Array = []
	for burst: float in [0.6, 3.5]:
		var t0 := burst
		for k in rng.randi_range(5, 8):
			var d := rng.randf_range(0.09, 0.2)
			sy.append(Vector2(t0, d))
			t0 += d + rng.randf_range(0.02, 0.12)
	var env := PackedFloat32Array()
	env.resize(n)
	for s: Vector2 in sy:
		for i in range(int(s.x * RATE), mini(int((s.x + s.y) * RATE), n)):
			env[i] = maxf(env[i], sin(PI * (float(i) / RATE - s.x) / s.y))
	for i in n:
		var t := float(i) / RATE
		x[i] += (a[i] - b[i]) * 2.2 * env[i]
		# The clock: a woody knock each second, a little lower every other one.
		var ct := fmod(t, 1.0)
		var hz := 1900.0 if int(t) % 2 == 0 else 1500.0
		x[i] += sin(TAU * hz * ct) * exp(-ct * 90.0) * 0.06 + sin(TAU * hz * 0.5 * ct) * exp(-ct * 50.0) * 0.03
	return x


## A book's pages riffling by themselves: a run of quick papery flicks that slows, and a soft
## thump as it falls shut.
func _pages(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 114
	var t0 := 0.02
	for k in 14:
		var gap := 0.025 + k * 0.006
		var y := 0.0
		var y2 := 0.0
		var len_s := 0.03
		var amp := 0.5 * (1.0 - k * 0.04)
		var start := int(t0 * Sfx.RATE)
		for i in int(len_s * Sfx.RATE):
			if start + i >= n:
				break
			var t := float(i) / Sfx.RATE
			var w := rng.randf() * 2.0 - 1.0
			y += 0.6 * (w - y)
			y2 += 0.15 * (y - y2)
			x[start + i] += (y - y2) * amp * sin(PI * t / len_s)
		t0 += gap
	var th := int((t0 + 0.05) * Sfx.RATE)
	for i in n - th:
		var t := float(i) / Sfx.RATE
		x[th + i] += sin(TAU * 110.0 * t) * exp(-t * 30.0) * 0.4 * minf(t / 0.003, 1.0)
	return x


## The Clockwork Foundry: the furnaces' low roar, a machine hum (two close low notes beating),
## the gears' ticking (a dry tick every quarter second, every fourth louder) and a hammer
## striking twice a loop far off.
func _foundry_bed(n: int) -> PackedFloat32Array:
	var x := _wind(n, 70.0, 240.0, 3.0, 2.0, 121)
	for i in n:
		var t := float(i) / RATE
		x[i] += (sin(TAU * 110.0 * t) + sin(TAU * 111.0 * t)) * 0.01 + sin(TAU * 220.0 * t) * 0.004
		var tt := fmod(t, 0.25)
		var loud := 1.6 if int(t / 0.25) % 4 == 0 else 1.0
		x[i] += sin(TAU * 2600.0 * tt) * exp(-tt * 220.0) * 0.035 * loud
		for hit: float in [1.0, 4.0]:
			var ht := t - hit
			if ht > 0.0 and ht < 0.6:
				x[i] += (sin(TAU * 820.0 * ht) + 0.7 * sin(TAU * 1370.0 * ht) + 0.5 * sin(TAU * 2210.0 * ht)) * exp(-ht * 9.0) * 0.05
	return x


## Steam blowing off a valve: a sharp hiss that swells and fades, with a clank as it opens.
func _steam(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 122
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / Sfx.RATE
		var env := minf(t / 0.12, 1.0) * exp(-maxf(t - 0.25, 0.0) * 2.6)
		var w := rng.randf() * 2.0 - 1.0
		y += 0.7 * (w - y)
		y2 += 0.3 * (y - y2)
		x[i] = (y - y2) * env * 0.7
		x[i] += sin(TAU * 640.0 * t) * exp(-t * 40.0) * 0.3 * minf(t / 0.002, 1.0)
	return x
