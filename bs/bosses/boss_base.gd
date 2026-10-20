class_name BossBase
extends EnemyBase
## Shared boss rules (BS_ENEMIES §4.0) on top of the enemy framework. Group "bosses".
##
## BREAK meter (v13, exact source numbers from damageEnemy / bossBreak / updateEnemies):
##   damage fills it, weak-point crits count double; threshold 12% max HP; decays 3.5% max HP/s;
##   BREAK = 3.2 s helpless stagger, windup cancelled, +50% damage taken, 0.28 s slow-mo, banner, bark;
##   14 s cooldown. Armour: 45% damage taken except weak-point crits.
## Phases: 3, HP-gated by `phases` thresholds; a change cancels the attack and grants 1.2 s of invulnerability.
##   A burst can't skip a phase: a hit that crosses a threshold stops just under it.
## Immune to freeze, dance, root, clump, launch, stun (except BREAK), acquire; SERVED works.
## Events: EventBus.boss_started / boss_health (every physics frame while fighting) / boss_defeated.
## The title card plays once per save (flag "boss_intro_<id>").

signal phase_changed(phase: int)
signal broke
signal fight_started

var boss_id: StringName = &""
var display_name: String = ""
var bdef: Dictionary = {}
var BR: Dictionary = {}
var phase: int = 1
var break_acc: float = 0.0
var break_cd: float = 0.0
var break_t: float = 0.0
var breaks: int = 0
var phase_invuln: float = 0.0
var started: bool = false
var defeated: bool = false
var player_hurt_during_fight: bool = false
var _line_queue: Array = []       # [[seconds_left, line_id], ...]


## Copies new bs.boss.* lines from bosses.json into VOManager when its index doesn't have them yet.
static func register_lines() -> void:
	var t: Dictionary = Data.table("bs/bosses")
	var lines: Dictionary = t.get("lines", {})
	var store: Variant = VOManager.get("_lines")
	if not store is Dictionary:
		return
	for k: Variant in lines.keys():
		if not VOManager.has_line(str(k)):
			(store as Dictionary)[str(k)] = lines[k]


static func line_text(line_id: String) -> String:
	return str(VOManager.line(line_id).get("text", ""))


func _load_tables() -> void:
	super._load_tables()
	var t: Dictionary = Data.table("bs/bosses")
	BR = t["break"]
	if bdef.is_empty():
		bdef = t.get(String(boss_id), {})
		def = bdef.duplicate()
		def["arch"] = "boss"
		display_name = str(bdef.get("name", String(boss_id)))


func _build_body() -> void:
	add_to_group(&"bosses")
	super._build_body()
	register_lines()


func _on_activate() -> void:
	phase = 1
	break_acc = 0.0
	break_cd = 0.0
	break_t = 0.0
	breaks = 0
	phase_invuln = 0.0
	started = false
	defeated = false
	player_hurt_during_fight = false
	aggro_radius = float(bdef.get("aggro_radius", 24.0))
	gravity_on = true
	if not EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.connect(_on_player_damaged)
	_boss_activate()


func _exit_tree() -> void:
	if EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.disconnect(_on_player_damaged)


func _on_player_damaged(_amount: float, _hp: float) -> void:
	if started and not defeated:
		player_hurt_during_fight = true


func immune(sid: StringName) -> bool:
	if sid == &"stun":
		return true                   # only BREAK staggers a boss
	return super.immune(sid)


func break_threshold() -> float:
	return max_hp * float(BR["threshold_frac"])


func break_frac() -> float:
	if break_t > 0.0:
		return clampf(break_t / float(BR["stagger"]), 0.0, 1.0)
	return clampf(break_acc / break_threshold(), 0.0, 1.0)


## Starts the fight: boss_started, title card (once per save), banner, aggro bark.
func start_fight() -> void:
	if started or defeated:
		return
	started = true
	aggro = true
	player_hurt_during_fight = false
	EventBus.boss_started.emit(boss_id, display_name)
	var L: Dictionary = bdef.get("lines", {})
	var flag_id: String = "boss_intro_%s" % boss_id
	if L.has("intro") and not BS.flag(flag_id):
		BS.set_flag(flag_id)
		var intro: Array = L["intro"]
		for i: int in intro.size():
			queue_line(str(intro[i]), float(L.get("intro_gap", 6.0)) * i)
	EventBus.banner.emit(display_name, line_text(str(L.get("start_banner_sub", "code.bossStart.01"))), 2.2)
	if L.has("aggro"):
		queue_line(str(L["aggro"]), 0.0 if not L.has("intro") else float(L.get("intro_gap", 6.0)) * (L["intro"] as Array).size())
	fight_started.emit()


## Plays a line after `delay` seconds of fight time (0 = now).
func queue_line(line_id: String, delay: float = 0.0) -> void:
	if delay <= 0.0:
		VOManager.play(line_id)
	else:
		_line_queue.append([delay, line_id])


func banner_lines(ids: Array, seconds: float = 2.0) -> void:
	if ids.size() >= 2:
		EventBus.banner.emit(line_text(str(ids[0])), line_text(str(ids[1])), seconds)


func _timers(delta: float) -> void:
	super._timers(delta)
	for i: int in range(_line_queue.size() - 1, -1, -1):
		_line_queue[i][0] = float(_line_queue[i][0]) - delta
		if float(_line_queue[i][0]) <= 0.0:
			VOManager.play(str(_line_queue[i][1]))
			_line_queue.remove_at(i)
	phase_invuln -= delta
	break_cd -= delta
	if break_t > 0.0:
		break_t -= delta
	elif break_acc > 0.0:
		break_acc = maxf(0.0, break_acc - max_hp * float(BR["decay_frac_per_s"]) * delta)
	if started and not defeated:
		EventBus.boss_health.emit(boss_id, clampf(hp / max_hp, 0.0, 1.0), break_frac())


func _modify_damage(amount: float, hit: Combat.Hit, crit: bool) -> float:
	if phase_invuln > 0.0 or not started:
		if not started:
			start_fight()
		if phase_invuln > 0.0:
			return 0.0
	var a: float = amount
	if not crit:
		a *= float(BR["armor"])
	if status.has(&"dancing"):
		a *= float(S["dancing"]["boss_damage_mult"])
	if break_t > 0.0:
		a *= float(BR["damage_mult"])
	elif break_cd <= 0.0:
		break_acc += a * (float(BR["crit_fill_mult"]) if crit else 1.0)
		if break_acc >= break_threshold():
			do_break()
	return _boss_modify(a, hit, crit)


## Adds directly to the BREAK meter (arena feeders). Ignored while broken or cooling down.
func add_break(amount: float) -> void:
	if break_t > 0.0 or break_cd > 0.0 or defeated:
		return
	break_acc += amount
	if break_acc >= break_threshold():
		do_break()


func do_break() -> void:
	break_acc = 0.0
	break_t = float(BR["stagger"])
	break_cd = float(BR["cooldown"])
	breaks += 1
	cancel_attack()
	stun_t = maxf(stun_t, float(BR["stagger"]))
	_set_state(State.STAGGER)
	Game.slowmo(float(BR["slowmo"]))
	banner_lines(BR["banner"], 1.6)
	if randf() < float(BR["bark_chance"]):
		var b: Array = BR["barks"]
		VOManager.play(str(b[randi() % b.size()]))
	telegraphed.emit(&"break", &"boss_break", float(BR["stagger"]))
	broke.emit()
	_on_break()


func _on_hurt(hit: Combat.Hit, amount: float, crit: bool) -> void:
	var th: Array = bdef.get("phases", [0.66, 0.33])
	# never skip a phase in one burst: a hit that crosses a threshold stops just under it
	if phase - 1 < th.size():
		var thr: float = float(th[phase - 1]) * max_hp
		if hp < thr:
			hp = maxf(hp, thr - 1.0)
			_enter_phase(phase + 1)
	_boss_on_hurt(hit, amount, crit)


func _enter_phase(p: int) -> void:
	phase = p
	cancel_attack()
	phase_invuln = float(BR["phase_invuln"])
	phase_changed.emit(p)
	_on_phase(p)


func _on_died(hit: Combat.Hit) -> void:
	defeated = true
	EventBus.boss_health.emit(boss_id, 0.0, 0.0)
	EventBus.boss_defeated.emit(boss_id)
	var L: Dictionary = bdef.get("lines", {})
	if L.has("defeat_banner"):
		banner_lines(L["defeat_banner"], 3.0)
	if L.has("defeat"):
		VOManager.play(str(L["defeat"]))
	if not player_hurt_during_fight:
		var trophy: String = str(bdef.get("trophy", ""))
		if trophy != "":
			BS.set_flag("trophy_" + trophy)
			EventBus.unlock_granted.emit("bs.trophy." + trophy)
	_boss_died(hit)


func _update_lod() -> void:
	lod = 0


# ------------------------------------------------------------------ boss hooks

func _boss_activate() -> void:
	pass


func _boss_modify(amount: float, _hit: Combat.Hit, _crit: bool) -> float:
	return amount


func _boss_on_hurt(_hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	pass


func _on_phase(_p: int) -> void:
	pass


func _on_break() -> void:
	pass


func _boss_died(_hit: Combat.Hit) -> void:
	pass
