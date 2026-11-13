class_name BotProf
extends RefCounted
## T-237: a section profiler for the bots' per-tick work, off unless a measuring tool turns it on
## (perf_marks --hitch sets BotProf.on). The brain and its layers wrap their steps:
##     var t0: int = BotProf.t()
##     ...the step...
##     BotProf.add(&"sense", t0)
## Off, t() returns 0 and add() returns at once (one static bool read each). On, every section keeps its total, its
## call count, its worst single call, its calls over 2 ms, and its time in the current physics tick (begin_tick() clears that), so a slow
## tick can be named by what ran in it.

static var on: bool = false
## T-237's optimisations (the think turn, the reachability memory, the kept gun models, the pose rate, the squad's
## player list per frame). On; a measuring tool turns them off for the "before" side of a before / after taken
## from one build in one session (perf_marks --ab=t237_off; any other tool: the environment variable CZ_T237_OFF=1,
## which also keeps StreamWarm off).
static var opt: bool = OS.get_environment("CZ_T237_OFF") == ""
static var _tot: Dictionary = {}    # section -> microseconds in all
static var _n: Dictionary = {}      # section -> calls
static var _max: Dictionary = {}    # section -> the worst single call
static var _tick: Dictionary = {}   # section -> microseconds in this tick
static var _slow: Dictionary = {}   # section -> calls over SLOW_US
const SLOW_US: int = 2000
static var _ticks: int = 0


static func t() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(section: StringName, t0: int) -> void:
	if not on:
		return
	var us: int = Time.get_ticks_usec() - t0
	_tot[section] = int(_tot.get(section, 0)) + us
	_n[section] = int(_n.get(section, 0)) + 1
	_tick[section] = int(_tick.get(section, 0)) + us
	if us > int(_max.get(section, 0)):
		_max[section] = us
	if us > SLOW_US:
		_slow[section] = int(_slow.get(section, 0)) + 1


## NavigationServer3D.map_get_path for the bots' layers, counted as the section "nav.path" while measuring.
static func nav_path(map: RID, from: Vector3, to: Vector3, optimize: bool, mask: int) -> PackedVector3Array:
	if not on:
		return NavigationServer3D.map_get_path(map, from, to, optimize, mask)
	var t0: int = Time.get_ticks_usec()
	var p: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, optimize, mask)
	add(&"nav.path", t0)
	return p


static func reset() -> void:
	_tot.clear()
	_n.clear()
	_max.clear()
	_slow.clear()
	_tick.clear()
	_ticks = 0


static func begin_tick() -> void:
	_tick.clear()
	_ticks += 1


## This tick's `top` biggest sections, "name ms" each ("" when nothing ran or it is off).
static func tick_text(top: int = 5) -> String:
	if _tick.is_empty():
		return ""
	var keys: Array = _tick.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return int(_tick[a]) > int(_tick[b]))
	var out: PackedStringArray = []
	for k: StringName in keys.slice(0, top):
		out.append("%s %.2f" % [k, int(_tick[k]) / 1000.0])
	return "prof: " + ", ".join(out)


## One line per section, biggest total first: ms per tick, calls, ms per call, the worst call.
static func report() -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Array = _tot.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return int(_tot[a]) > int(_tot[b]))
	for k: StringName in keys:
		out.append("prof %-22s %.4f ms/tick, %d calls, %.4f ms each, worst %.3f ms, over 2 ms %d" % [k, int(_tot[k]) / 1000.0 / float(maxi(1, _ticks)),
			int(_n[k]), int(_tot[k]) / 1000.0 / float(maxi(1, int(_n[k]))), int(_max[k]) / 1000.0, int(_slow.get(k, 0))])
	return out
