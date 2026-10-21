class_name NovaEncounter
extends Encounter
## An Encounter whose spawn rows may carry EnemySpawner opts ({"type", "pos", "opts": {...}}), spawned through
## NovaSpawn (exact BS_ENEMIES ids; a stub stands in until builder D's enemy exists). The Zoning Board's
## controller is not damageable itself, so a wave counts it alive while its is_alive() says so.


func _next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		done = true
		cleared.emit(self)
		return
	alive.clear()
	for row: Variant in waves[wave_index]:
		var r: Dictionary = row
		var e: Node3D = NovaSpawn.spawn(StringName(str(r.get("type", ""))), LevelKit.v3(r.get("pos")), self, r.get("opts", {}))
		if e != null:
			alive.append(e)
			spawned_total += 1
	wave_started.emit(self, wave_index)
	if alive.is_empty():
		_next_wave.call_deferred()
