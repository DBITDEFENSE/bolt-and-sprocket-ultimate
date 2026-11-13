class_name TrailerCommands
extends RefCounted
## Dev-console commands for recording a trailer (T-221; the owner is cutting one). Registered by the console with
## the built-ins:
##   hud off [subs] | hud on   the whole HUD (every CanvasLayer but the look's post stack and the console), the
##                             crosshair and the viewmodel; `subs` keeps the subtitles
##   flyspeed <m/s> [game]     noclip's fly speed (default 12), eased; it flies in real time under `timescale` unless
##                             `game` (so a 0.2 slow-motion fly-through still moves at the set speed)
##   tod <0..1|night|dawn|golden|auto>   hold der Kranich's time of day (Act II): 0 night, 0.6 dawn, 1 the golden hour
##                             of the bomb run; auto gives it back to the act's clock
##   bombrun now|drop|fx [rack] [dud]   the bomb run (Act II): `now` starts the real run (as act round 5 would),
##                             `drop` releases the next rack at once, `fx` only shows a rack's casing falling away (no
##                             gameplay, any number of takes)

const VM_LAYER: int = 1 << 19

static var _hidden: Array = []


static func register_all(c: Node) -> void:
	c.call("register", "hud", func(a: PackedStringArray) -> String: return hud(c.get_tree(), a), "hud off [subs] | hud on: hide / show the whole HUD, crosshair and viewmodel (trailer shots)")
	c.call("register", "flyspeed", func(a: PackedStringArray) -> String: return flyspeed(c.get_tree(), a), "flyspeed <m/s> [game]: noclip's fly speed (eased; real time under timescale unless 'game')")
	c.call("register", "tod", func(a: PackedStringArray) -> String: return tod(c.get_tree(), a), "tod <0..1|night|dawn|golden|auto>: der Kranich's time of day (Act II)")
	c.call("register", "bombrun", func(a: PackedStringArray) -> String: return bombrun(c.get_tree(), a), "bombrun now|drop|fx [rack 1-6] [dud]: the bomb run (Act II); fx = the falling casing only")


static func _local_player(tree: SceneTree) -> Player:
	for n: Node in tree.get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local:
			return n as Player
	return null


static func hud(tree: SceneTree, a: PackedStringArray) -> String:
	var off: bool = a.size() == 0 or a[0] != "on"
	var keep_subs: bool = a.has("subs")
	var p: Player = _local_player(tree)
	if off:
		_hidden.clear()
		var subs: Node = GLVO.get("_subtitles") as Node
		for n: Node in tree.root.find_children("*", "CanvasLayer", true, false):
			var cl: CanvasLayer = n as CanvasLayer
			if cl is LookPost or cl == GLConsole or GLSettings.is_ancestor_of(cl) or not cl.visible:
				continue
			if keep_subs and subs != null and cl == subs:
				continue
			cl.visible = false
			_hidden.append(cl)
		if p != null and p.camera != null:
			p.camera.cull_mask = p.camera.cull_mask & ~VM_LAYER
		return "HUD off (%d layers%s)" % [_hidden.size(), ", subtitles kept" if keep_subs else ""]
	for cl2: Variant in _hidden:
		if is_instance_valid(cl2):
			(cl2 as CanvasLayer).visible = true
	_hidden.clear()
	if p != null and p.camera != null:
		p.camera.cull_mask = p.camera.cull_mask | VM_LAYER
	return "HUD on"


static func flyspeed(tree: SceneTree, a: PackedStringArray) -> String:
	var p: Player = _local_player(tree)
	if p == null:
		return "No player"
	if a.size() > 0:
		p.noclip_speed = clampf(float(a[0]), 0.2, 200.0)
	p.noclip_realtime = not a.has("game")
	return "Fly speed %.1f m/s (%s time)%s" % [p.noclip_speed, "real" if p.noclip_realtime else "game", "" if p.noclip else "; noclip is off (type noclip)"]


static func tod(tree: SceneTree, a: PackedStringArray) -> String:
	var ks: Node = tree.get_first_node_in_group(&"kranich_sunset")
	if ks == null:
		return "tod: only on der Kranich (Fernflug Act II)"
	var arg: String = a[0] if a.size() > 0 else "golden"
	var k: float
	match arg:
		"night":
			k = 0.0
		"dawn":
			k = 0.6
		"golden", "sunset":
			k = 1.0
		"auto":
			k = -1.0
		_:
			if not arg.is_valid_float():
				return "tod <0..1|night|dawn|golden|auto>"
			k = clampf(float(arg), 0.0, 1.0)
	ks.call("hold_tod", k)
	return "Time of day: the act's own clock" if k < 0.0 else "Time of day held at %.2f (golden %.2f)" % [k, float(ks.get("golden_override"))]


static func bombrun(tree: SceneTree, a: PackedStringArray) -> String:
	var fc: Node = tree.get_first_node_in_group(&"flight_controller")
	var ks: Node = tree.get_first_node_in_group(&"kranich_sunset")
	if fc == null or ks == null:
		return "bombrun: only on der Kranich (Fernflug Act II)"
	var what: String = a[0] if a.size() > 0 else "now"
	match what:
		"now":
			if bool(fc.get("run_on")) or bool(fc.get("run_done")):
				return "The bomb run is on or done already (bombrun fx shows a drop without it)"
			fc.call("start_bomb_run")
			return "Zielanflug: the bomb run started (rack 1 in 3 s)"
		"drop":
			if not bool(fc.get("run_on")):
				return "No bomb run on (bombrun now)"
			fc.call("_drop_next")
			return "The next rack released"
		"fx":
			var idx: int = clampi(int(a[1]) if a.size() > 1 and a[1].is_valid_int() else 1, 1, 6)
			ks.call("drop_fx", idx, not a.has("dud"))
			return "Rack %d's casing falls away (visual only)" % idx
	return "bombrun now|drop|fx [rack] [dud]"
