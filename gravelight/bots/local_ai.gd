class_name LocalAI
extends Node
## A local LLM served by Ollama (https://ollama.com), for the bot objective planner (BotPlanner). Never blocks
## the game: every call is an HTTPRequest child; one chat request is in flight at a time and the answer comes
## back through a callback (or null on any failure: offline, timeout, bad JSON). Tuning: bots.json "local_ai".
##
## Life cycle: probe GET /api/tags -> (down: `ollama serve`, hidden, once, then probe again) -> pick the first
## installed model from `models` -> one tiny warm-up chat so the weights are loaded -> READY. While not READY the
## planner uses its own scores; an OFFLINE client probes again every 30 s.

enum State { IDLE, PROBING, STARTING, WARMING, READY, OFFLINE }

const RETRY_OFFLINE_S: float = 30.0
const START_PROBES: int = 10

var state: State = State.IDLE
var model: String = ""
var last_error: String = ""
var last_latency_ms: int = 0
var requests: int = 0
var answered: int = 0
var failed: int = 0
var started_server: bool = false

var _cfg: Dictionary = {}
var _endpoint: String = "http://127.0.0.1:11434"
var _busy: bool = false
var _retry_t: float = 0.0
var _start_probes: int = 0


func setup(cfg: Dictionary) -> void:
	_cfg = cfg
	_endpoint = str(cfg.get("endpoint", _endpoint)).trim_suffix("/")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps probing / answering while the game is paused


func start() -> void:
	if state == State.PROBING or state == State.WARMING or state == State.READY:
		return
	_probe()


func is_ready() -> bool:
	return state == State.READY


func busy() -> bool:
	return _busy


func status_text() -> String:
	match state:
		State.READY:
			return "local AI %s (%d ms)" % [model, last_latency_ms] if last_latency_ms > 0 else "local AI %s" % model
		State.WARMING:
			return "loading %s" % model
		State.PROBING, State.STARTING:
			return "looking for Ollama"
		State.OFFLINE:
			return "Ollama offline (%s)" % last_error if last_error != "" else "Ollama offline"
	return "idle"


func _process(delta: float) -> void:
	if state == State.OFFLINE:
		_retry_t -= delta
		if _retry_t <= 0.0:
			_retry_t = RETRY_OFFLINE_S
			_probe()


# ------------------------------------------------------------------ probing and start-up

func _probe() -> void:
	if state != State.STARTING:
		state = State.PROBING
	_get_json("/api/tags", 2.5, _on_tags)


func _on_tags(data: Variant, err: String) -> void:
	if data == null:
		if state == State.STARTING:
			_start_probes += 1
			if _start_probes < START_PROBES:
				get_tree().create_timer(1.5, true).timeout.connect(_probe)
				return
		elif not started_server and bool(_cfg.get("autostart_ollama", true)) and _start_server():
			state = State.STARTING
			_start_probes = 0
			get_tree().create_timer(1.5, true).timeout.connect(_probe)
			return
		_go_offline(err)
		return
	var installed: Array = []
	for m: Variant in (data as Dictionary).get("models", []):
		if m is Dictionary:
			installed.append(str((m as Dictionary).get("name", (m as Dictionary).get("model", ""))))
	model = pick_model(_cfg.get("models", []), installed)
	if model == "":
		_go_offline("none of %s installed (have %s)" % [str(_cfg.get("models", [])), str(installed)])
		return
	state = State.WARMING
	var body: Dictionary = chat_body(model, [{"role": "user", "content": "Reply with the JSON {\"ok\": true}."}], {}, _cfg)
	_post_json("/api/chat", body, float(_cfg.get("warmup_timeout_s", 120.0)), func(d: Variant, e: String) -> void:
		if d == null:
			_go_offline("warm-up failed: " + e)
			return
		state = State.READY
		print("[local_ai] ready: %s at %s" % [model, _endpoint]))


func _go_offline(why: String) -> void:
	state = State.OFFLINE
	last_error = why
	_retry_t = RETRY_OFFLINE_S
	print("[local_ai] offline: %s" % why)


## `ollama serve` in the background with no console window. True when a process started.
func _start_server() -> bool:
	started_server = true
	for raw: Variant in _cfg.get("ollama_paths", ["ollama"]):
		var path: String = str(raw).replace("{LOCALAPPDATA}", OS.get_environment("LOCALAPPDATA")).replace("\\", "/")
		if path.contains("/") and not FileAccess.file_exists(path):
			continue
		var pid: int = OS.create_process(path, PackedStringArray(["serve"]), false)
		if pid > 0:
			print("[local_ai] started `%s serve` (pid %d)" % [path, pid])
			return true
	return false


# ------------------------------------------------------------------ chat

## One chat turn. `schema` = a JSON schema for the reply (Ollama structured outputs), {} = any JSON object.
## `done` gets (Dictionary reply, latency_ms) or (null, 0). False (and no callback) when not ready or busy.
func ask(messages: Array, schema: Dictionary, done: Callable) -> bool:
	if state != State.READY or _busy:
		return false
	_busy = true
	requests += 1
	var t0: int = Time.get_ticks_msec()
	_post_json("/api/chat", chat_body(model, messages, schema, _cfg), float(_cfg.get("timeout_s", 10.0)), func(d: Variant, e: String) -> void:
		_busy = false
		var reply: Variant = null
		if d is Dictionary:
			reply = parse_reply(d as Dictionary)
		if reply == null:
			failed += 1
			last_error = e if e != "" else "unreadable reply"
			done.call(null, 0)
			return
		answered += 1
		last_latency_ms = Time.get_ticks_msec() - t0
		done.call(reply, last_latency_ms))
	return true


## The /api/chat request body (pure, unit-tested).
static func chat_body(model_name: String, messages: Array, schema: Dictionary, cfg: Dictionary) -> Dictionary:
	return {
		"model": model_name,
		"messages": messages,
		"stream": false,
		"format": schema if not schema.is_empty() else "json",
		"keep_alive": str(cfg.get("keep_alive", "30m")),
		"options": {"temperature": float(cfg.get("temperature", 0.3)), "num_predict": int(cfg.get("max_tokens", 90))},
	}


## The JSON object in an /api/chat answer's message content, or null (pure, unit-tested).
static func parse_reply(response: Dictionary) -> Variant:
	var msg: Variant = response.get("message", {})
	if not msg is Dictionary:
		return null
	var content: String = str((msg as Dictionary).get("content", "")).strip_edges()
	if content.begins_with("```"):
		content = content.trim_prefix("```json").trim_prefix("```").trim_suffix("```").strip_edges()
	var a: int = content.find("{")
	var b: int = content.rfind("}")
	if a < 0 or b <= a:
		return null
	var parsed: Variant = JSON.parse_string(content.substr(a, b - a + 1))
	return parsed if parsed is Dictionary else null


## The first wanted model that is installed ("gemma3:4b" also matches "gemma3:4b-it-q4"), or "" (pure).
static func pick_model(wanted: Array, installed: Array) -> String:
	for w: Variant in wanted:
		var ws: String = str(w)
		for i: Variant in installed:
			var s: String = str(i)
			if s == ws or s == ws + ":latest" or s.begins_with(ws + "-"):
				return s
	return ""


# ------------------------------------------------------------------ http

func _get_json(path: String, timeout: float, done: Callable) -> void:
	_request(path, HTTPClient.METHOD_GET, "", timeout, done)


func _post_json(path: String, body: Dictionary, timeout: float, done: Callable) -> void:
	_request(path, HTTPClient.METHOD_POST, JSON.stringify(body), timeout, done)


func _request(path: String, method: int, body: String, timeout: float, done: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = timeout
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			done.call(null, "http result %d" % result)
			return
		if code < 200 or code >= 300:
			done.call(null, "HTTP %d %s" % [code, raw.get_string_from_utf8().left(120)])
			return
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if parsed == null:
			done.call(null, "bad JSON")
			return
		done.call(parsed, ""))
	var err: int = http.request(_endpoint + path, PackedStringArray(["Content-Type: application/json"]), method, body)
	if err != OK:
		http.queue_free()
		done.call(null, "request error %d" % err)
