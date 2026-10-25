class_name Sfx
extends Node
## Sound effects: real CC0 recordings in audio/sfx (Kenney's packs, plus creature roars from
## OpenGameArt; see audio/sfx/CREDITS.md), named <sound>_<n>.ogg, one picked at random each
## time. The code-made sounds below are only fallbacks for a sound with no files.

const RATE := 22050

static var _instance: Sfx
var _clips := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


static var enabled := true


static func play(sound: String, volume := 1.0) -> void:
	if not enabled or _instance == null or not _instance._clips.has(sound):
		return
	var p := _instance._players[_instance._next]
	_instance._next = (_instance._next + 1) % _instance._players.size()
	var clip = _instance._clips[sound]
	p.stream = clip.pick_random() if clip is Array else clip
	p.volume_db = linear_to_db(volume * randf_range(0.85, 1.0))
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_clips["victory"] = _synth(1.2, func(t): return (_sine(t, 523) + _sine(t, 659) * float(t > 0.3) + _sine(t, 784) * float(t > 0.6)) * _env(t, 1.2) * 0.2)
	_load_samples()


## Looks for audio/sfx/<name>_0.ogg, _1.ogg ... and uses them instead of the synth.
func _load_samples() -> void:
	for name in ["shoot", "hit", "die", "hurt", "door", "upgrade", "coin", "click", "dash", "slam", "crack", "pickup",
			"warn", "boom", "roar", "victory", "vo_prepare", "vo_win", "vo_lose", "vo_combo"]:
		var found := []
		for i in 10:
			var path := "res://audio/sfx/%s_%d.ogg" % [name, i]
			if not ResourceLoader.exists(path):
				break
			found.append(load(path))
		if not found.is_empty():
			_clips[name] = found


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


static func _noise() -> float: return randf() * 2.0 - 1.0
static func _sine(t: float, hz: float) -> float: return sin(TAU * hz * t)
static func _square(t: float, hz: float) -> float: return signf(sin(TAU * hz * t))
static func _sweep(t: float, from: float, to: float) -> float: return sin(TAU * lerpf(from, to, t * 4.0) * t)
static func _env(t: float, length: float) -> float: return clampf(t / 0.005, 0.0, 1.0) * pow(1.0 - clampf(t / length, 0.0, 1.0), 2.0)
