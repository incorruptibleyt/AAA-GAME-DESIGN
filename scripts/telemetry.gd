class_name Telemetry
extends Node
## Automatic, anonymous reports. At the end of every run (and when the game hits an
## error, or seems to have crashed last time) it posts a short text report to a Google
## Form, whose answers land in a Google Sheet. No account, ad ID or personal data:
## just a random install number made on the phone, the build, the phone model and
## the run report. Players can switch it off in the pause menu ("Send reports").
##
## To point it at a different form, change FORM_ID and ENTRY (from the form's
## "Get pre-filled link"). Leaving FORM_ID empty switches reports off completely.

const FORM_ID := "1FAIpQLSfn55v80P_BKC4IcLw9wsS7d9d2618GsHbo8ktg1IbYK3eogw"
const ENTRY := "entry.999248691"
const QUEUE_PATH := "user://report_queue.json"
const MAX_QUEUE := 20
const MAX_ERRORS := 5   # error reports per session, so one bug can't spam

static var instance: Telemetry

var _http: HTTPRequest
var _queue: Array = []
var _busy := false
var _errors: Array = []
var _errors_sent := 0
var _mutex := Mutex.new()
var _seen := {}


class ErrorCatcher extends Logger:
	var owner: Telemetry

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return   # warnings are noise on players' phones
		var text := "ERROR %s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function]
		if not script_backtraces.is_empty():
			text += "\n" + script_backtraces[0].format()
		owner.catch_error(text)

	func _log_message(_message: String, _error: bool) -> void:
		pass


static func configured() -> bool:
	return FORM_ID != "" and ENTRY != ""


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_done)
	add_child(_http)
	if not active():
		return
	var catcher := ErrorCatcher.new()
	catcher.owner = self
	OS.add_logger(catcher)
	_load_queue()
	_check_last_session()
	session_open(true)


## Reports go out only from a real install with a form set up, and never from the test robot.
func active() -> bool:
	return configured() and not "autoplay" in OS.get_cmdline_user_args() and OS.has_feature("template")


func enabled() -> bool:
	return active() and bool(Game._load_save().get_value("settings", "reports", true))


func send(kind: String, body: String) -> void:
	if not enabled():
		return
	var cfg := Game._load_save()
	var head := "%s | build %s | install %s | %s | Android %s | %s" % [kind, Game.BUILD, install_id(cfg),
		OS.get_model_name(), OS.get_version(), RenderingServer.get_video_adapter_name()]
	_queue.append(head + "\n" + body)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()
	_save_queue()
	_flush()


## Called by the logger, possibly from another thread: just remember it for _process.
func catch_error(text: String) -> void:
	_mutex.lock()
	if _errors.size() < MAX_ERRORS and not _seen.has(text):
		_seen[text] = true   # the same error every frame is reported once
		_errors.append(text)
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _errors.is_empty():
		return
	_mutex.lock()
	var list := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	for e in list:
		if _errors_sent < MAX_ERRORS:
			_errors_sent += 1
			send("error", e + "\nWhere: " + Game.where_text())


## Marks the game as running. If it's still marked next launch, the game didn't close
## normally (a crash, or Android killing it while open), so the next launch reports it.
func session_open(open: bool) -> void:
	if not active():
		return
	var cfg := Game._load_save()
	cfg.set_value("telemetry", "open", open)
	cfg.set_value("telemetry", "where", Game.where_text())
	cfg.save(Game.SAVE_PATH)


func _check_last_session() -> void:
	var cfg := Game._load_save()
	if not bool(cfg.get_value("telemetry", "open", false)):
		return
	send("possible crash", "The game didn't close normally last time.\nLast seen: %s\n%s" % [cfg.get_value("telemetry", "where", "?"), _last_log()])


## The end of the previous session's log file, if Godot kept one.
func _last_log() -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var files := Array(dir.get_files()).filter(func(f: String): return f.ends_with(".log") and f != "godot.log")
	if files.is_empty():
		return ""
	files.sort()
	var text := FileAccess.get_file_as_string("user://logs/" + files[-1])
	var lines := text.split("\n")
	return "Log tail:\n" + "\n".join(lines.slice(maxi(0, lines.size() - 30)))


static func install_id(cfg: ConfigFile) -> String:
	var id := str(cfg.get_value("telemetry", "id", ""))
	if id == "":
		id = "%08x" % (randi() & 0x7fffffff)
		cfg.set_value("telemetry", "id", id)
		cfg.save(Game.SAVE_PATH)
	return id


func _flush() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var url := "https://docs.google.com/forms/d/e/%s/formResponse" % FORM_ID
	var data := "%s=%s" % [ENTRY, (_queue[0] as String).uri_encode()]
	if _http.request(url, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, data) != OK:
		_busy = false


func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code < 400:
		_queue.pop_front()
		_save_queue()
		_flush()
	# Otherwise (offline, say) it stays queued and goes with the next report or launch.


func _load_queue() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH)) if FileAccess.file_exists(QUEUE_PATH) else null
	_queue = parsed if parsed is Array else []
	_flush()


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_queue))
