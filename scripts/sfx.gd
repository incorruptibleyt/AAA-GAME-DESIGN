class_name Sfx
extends Node
## Sound effects: real CC0 recordings in audio/sfx (Kenney's packs, plus creature cries and
## fire from OpenGameArt; see audio/sfx/CREDITS.md), named <sound>_<n>.ogg, one picked at
## random each time. The code-made sounds below are only fallbacks for a sound with no files;
## the Frost Wraith's cry and beam and the Cinder Skeleton's burst ("wraith", "beam",
## "ignite") are files only. The low-health heartbeat ("heart") is code-made on purpose.
## Game sounds play through the "Effects" bus (a short crypt echo); menu sounds and the
## announcer skip it (see make_buses).

const RATE := 22050

static var _instance: Sfx
var _clips := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


static var enabled := true

## Most copies of one sound allowed to start in a single frame. A big crowd dying at once
## used to start ten copies of "die" and cut off every other sound in the 10-player pool.
const PER_FRAME := {"hit": 2, "shoot": 2, "die": 3}
static var _frame := -1
static var _started := {}

## Sounds that are the game talking to the player (menus, the announcer) skip the echo.
const DRY := ["click", "upgrade", "victory", "vo_prepare", "vo_win", "vo_lose", "vo_combo"]


static func play(sound: String, volume := 1.0, pitch := 1.0) -> void:
	if not enabled or _instance == null or not _instance._clips.has(sound):
		return
	if PER_FRAME.has(sound):
		var f := Engine.get_process_frames()
		if f != _frame:
			_frame = f
			_started.clear()
		var n: int = _started.get(sound, 0)
		if n >= PER_FRAME[sound]:
			return
		_started[sound] = n + 1
	var clip = _instance._clips[sound]
	_instance._start(clip.pick_random() if clip is Array else clip, &"Master" if sound in DRY else &"Effects", volume, pitch)


## Plays a sound made elsewhere (the room tone's drips and pops) through the echo.
static func play_stream(stream: AudioStream, volume := 1.0, pitch := 1.0) -> void:
	if enabled and _instance != null and stream != null:
		_instance._start(stream, &"Effects", volume, pitch)


func _start(stream: AudioStream, bus: StringName, volume: float, pitch: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.bus = bus
	p.volume_db = linear_to_db(volume * randf_range(0.85, 1.0))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_clips["shoot"] = _synth(0.12, func(t): return _sweep(t, 900, 300) * _env(t, 0.12) * 0.3)
	_clips["hit"] = _synth(0.1, func(t): return (_noise() * 0.6 + _square(t, 140) * 0.4) * _env(t, 0.1) * 0.45)
	_clips["die"] = _synth(0.3, func(t): return (_noise() * 0.7 + _sweep(t, 400, 60) * 0.3) * _env(t, 0.3) * 0.5)
	_clips["hurt"] = _synth(0.25, func(t): return _square(t, 110 - t * 200) * _env(t, 0.25) * 0.35)
	_clips["door"] = _synth(0.6, func(t): return (_noise() * 0.3 + _square(t, 55) * 0.2) * _env(t, 0.6) * 0.5)
	_clips["upgrade"] = _synth(0.45, func(t): return (_sine(t, 523) + _sine(t, 784 if t > 0.15 else 659)) * _env(t, 0.45) * 0.22)
	_clips["warn"] = _synth(0.15, func(t): return _sine(t, 1200) * _env(t, 0.15) * 0.12)
	_clips["boom"] = _synth(0.5, func(t): return _noise() * _env(t, 0.5) * 0.55)
	_clips["roar"] = _synth(1.1, func(t): return (_square(t, 70 + sin(t * 30) * 8) * 0.5 + _noise() * 0.3) * _env(t, 1.1) * 0.5)
	_clips["coin"] = _synth(0.18, func(t): return (_sine(t, 1320 if t > 0.05 else 990)) * _env(t, 0.18) * 0.25)
	_clips["click"] = _synth(0.06, func(t): return _sine(t, 700) * _env(t, 0.06) * 0.25)
	_clips["dash"] = _synth(0.22, func(t): return (_noise() * 0.6 + _sweep(t, 300, 1400) * 0.25) * _env(t, 0.22) * 0.4)
	_clips["slam"] = _synth(0.9, func(t): return (_sweep(t, 120, 35) * 0.7 + _noise() * 0.35 * exp(-t * 8.0)) * _env(t, 0.9) * 0.6)
	_clips["crack"] = _synth(0.35, func(t): return (_noise() * exp(-t * 30.0) * 0.9 + _square(t, 220 - t * 300) * 0.3 * exp(-t * 10.0) + _sine(t, 1760) * 0.25 * exp(-t * 12.0)) * _env(t, 0.35) * 0.6)
	# A heartbeat for low health (code-made on purpose: two soft low thumps).
	# Water: a wash of noise that dies away with a little rising bloop (the Drowned Vault).
	_clips["splash"] = _synth(0.5, func(t): return (_noise() * exp(-t * 7.0) * 0.55 + _sweep(t, 260, 760) * exp(-t * 16.0) * 0.3) * _env(t, 0.5) * 0.5)
	_clips["heart"] = _synth(0.5, func(t): return (_thump(t) + _thump(t - 0.17) * 0.7) * 0.8)
	_clips["victory"] = _synth(1.2, func(t): return (_sine(t, 523) + _sine(t, 659) * float(t > 0.3) + _sine(t, 784) * float(t > 0.6)) * _env(t, 1.2) * 0.2)
	_load_samples()


## Looks for audio/sfx/<name>_0.ogg, _1.ogg ... and uses them instead of the synth.
func _load_samples() -> void:
	for sound in ["shoot", "hit", "die", "hurt", "door", "upgrade", "coin", "click", "dash", "slam", "crack", "pickup",
			"warn", "boom", "roar", "victory", "wraith", "beam", "ignite", "vo_prepare", "vo_win", "vo_lose", "vo_combo"]:
		var found := []
		for i in 10:
			var path := "res://audio/sfx/%s_%d.ogg" % [sound, i]
			if not ResourceLoader.exists(path):
				break
			found.append(load(path))
		if not found.is_empty():
			_clips[sound] = found


func _synth(seconds: float, wave: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(wave.call(i / float(RATE)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Coins picked up in quick succession chime up a major scale; a pause starts it again.
const COIN_SCALE := [0, 2, 4, 5, 7, 9, 11, 12]
static var _coin_step := 0
static var _coin_at := -10.0

static func coin(volume := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_coin_step = mini(_coin_step + 1, COIN_SCALE.size() - 1) if now - _coin_at < 0.45 else 0
	_coin_at = now
	play("coin", volume, pow(2.0, COIN_SCALE[_coin_step] / 12.0))


## Two buses under Master. "Effects" has a short, quiet echo, as if the sounds bounce off
## crypt stone, then a low-pass filter that dulls everything for a moment in slow motion.
## "Music" has a low-pass filter that Music turns down to muffle the music (and the room
## tone) while the game is paused, a blessing is being picked or the death screen shows.
## Music works both filters and switches each off when it's not in use.
static func make_buses() -> void:
	if AudioServer.get_bus_index(&"Effects") == -1:
		var echo := AudioEffectReverb.new()
		echo.room_size = 0.5
		echo.damping = 0.6
		echo.spread = 0.6
		echo.hipass = 0.2
		echo.predelay_msec = 35.0
		echo.predelay_feedback = 0.15
		echo.dry = 1.0
		echo.wet = 0.14
		_add_bus(&"Effects", echo)
		var dull := AudioEffectLowPassFilter.new()
		dull.cutoff_hz = 20000.0
		var fx := AudioServer.get_bus_index(&"Effects")
		AudioServer.add_bus_effect(fx, dull)
		AudioServer.set_bus_effect_enabled(fx, 1, false)
	if AudioServer.get_bus_index(&"Music") == -1:
		var low := AudioEffectLowPassFilter.new()
		low.cutoff_hz = 20000.0
		_add_bus(&"Music", low)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(&"Music"), 0, false)


static func _add_bus(bus_name: StringName, effect: AudioEffect) -> void:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Master")
	AudioServer.add_bus_effect(i, effect)


static func _thump(t: float) -> float:
	if t < 0.0:
		return 0.0
	# 62 Hz is felt in headphones; the overtones keep it audible on a phone speaker.
	return (sin(TAU * 62.0 * t) * 0.8 + sin(TAU * 124.0 * t) * 0.35 + sin(TAU * 190.0 * t) * 0.15) \
		* clampf(t / 0.004, 0.0, 1.0) * exp(-t * 22.0)


static func _noise() -> float: return randf() * 2.0 - 1.0
static func _sine(t: float, hz: float) -> float: return sin(TAU * hz * t)
static func _square(t: float, hz: float) -> float: return signf(sin(TAU * hz * t))
static func _sweep(t: float, from: float, to: float) -> float: return sin(TAU * lerpf(from, to, t * 4.0) * t)
static func _env(t: float, length: float) -> float: return clampf(t / 0.005, 0.0, 1.0) * pow(1.0 - clampf(t / length, 0.0, 1.0), 2.0)
