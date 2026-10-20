class_name Encounter
extends Node3D
## A data-driven fight: waves of enemies spawned through EnemyBridge (EnemySpawner when present). The next
## wave spawns when the current one is down; `cleared` fires after the last. Started by a trigger action
## {"encounter": id}. Each spawn row: {"type": "scrap_mutt", "pos": [x, y, z]}.

signal wave_started(enc: Encounter, index: int)
signal cleared(enc: Encounter)

var encounter_id: String = ""
var waves: Array = []
var on_clear: Array = []
var started: bool = false
var done: bool = false
var wave_index: int = -1
var alive: Array[Node3D] = []
var spawned_total: int = 0


func start() -> void:
	if started:
		return
	started = true
	_next_wave()


func _next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		done = true
		cleared.emit(self)
		return
	alive.clear()
	for row: Variant in waves[wave_index]:
		var r: Dictionary = row
		var e: Node3D = EnemyBridge.spawn(StringName(str(r.get("type", ""))), LevelKit.v3(r.get("pos")), self)
		if e != null:
			alive.append(e)
			spawned_total += 1
	wave_started.emit(self, wave_index)
	if alive.is_empty():
		_next_wave.call_deferred()


func living() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in alive:
		if is_instance_valid(e) and (not e.has_method("is_alive") or bool(e.call("is_alive"))):
			out.append(e)
	return out


func _physics_process(_delta: float) -> void:
	if not started or done:
		return
	if living().is_empty():
		_next_wave()
