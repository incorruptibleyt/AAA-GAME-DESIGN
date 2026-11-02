class_name Ambience
extends Node
## Room tone under the music, one for each floor theme: a slow cold draught in the Bone
## Crypt with water dripping somewhere, a thin whistling wind in the Frozen Ossuary with
## ice ticking now and then, and a low fire roar in the Ember Catacomb with embers popping.
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
const EVERY := [Vector2(3.0, 8.0), Vector2(4.0, 9.0), Vector2(1.2, 3.5)]

static var _instance: Ambience
var _beds: Array = [null, null, null]
var _ones: Array = [null, null, null]
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
		want = (Game.floor_num - 1) % 3
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
	_player.volume_db = VOLUME_DB + linear_to_db(maxf(_level, 0.0001))
	# Now and then a drip, a tick of ice or a popping ember, but only while fighting.
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
func _wind(n: int, low_hz: float, high_hz: float, swell_s: float, gain: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
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
