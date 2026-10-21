class_name Music
extends Node
## Background music: a calm dungeon theme and a driving boss theme, cross-faded.
## The tracks are made by tools/make_music.py.

const DUNGEON := preload("res://audio/music_dungeon.ogg")
const BOSS := preload("res://audio/music_boss.ogg")
const VOLUME_DB := -6.0

static var _instance: Music
static var enabled := true

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: AudioStream


static func play(track: String) -> void:
	if _instance:
		_instance._switch(BOSS if track == "boss" else DUNGEON)


static func set_enabled(on: bool) -> void:
	enabled = on
	if _instance:
		for p in [_instance._a, _instance._b]:
			p.stream_paused = not on


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s: AudioStreamOggVorbis in [DUNGEON, BOSS]:
		s.loop = true
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.volume_db = -60.0
		add_child(p)


func _switch(stream: AudioStream) -> void:
	if stream == _current:
		return
	_current = stream
	# Fade the old track out on one player while the new one fades in on the other.
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.play()
	_a.stream_paused = not enabled
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_a, "volume_db", VOLUME_DB, 1.2).from(-40.0)
	tw.tween_property(_b, "volume_db", -60.0, 1.2)
	tw.chain().tween_callback(_b.stop)
