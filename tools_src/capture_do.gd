class_name CaptureDo
extends RefCounted
## A capture camera's `do` list (data/gravelight/capture_cams.json): world states to show before the shot, in
## order. Shared by tools_src/capture.gd (stills) and gravelight/tools_src/clip_tour.gd (the walked clips).
## Verbs (T-094 ... T-147, T-167):
##   power                        the lights on without the lever's burst (the switch's own sweep, GameState.power_on)
##   open:<door node>             a door for free
##   tear:<window node>[:n]       n boards off a window
##   exfil                        the campaign beacon (campaign runs only)
##   call:<node>:<method>[:wait]  a set-piece by its own entry point (no arguments); shot `wait` s in (default 1)
##   callv:<node>:<method>[:a,b][:wait]   the same with arguments: true/false, numbers, &name, else a string
##   tide:<stage>[:hold_s][:wait_s]       TideController.force_stage (the Totenhafen water; wait defaults to rise+2)
##   flag:<name>[:value]          GameState.set_flag (value true/false/number; default true)
##   skipto:<quest>:<step>        QuestManager.debug_skipto
##   use:<node>                   Interactable.interact(player) on a Gameplay node (no hold timer: the smokes' _use)
##   start:<node>[:pid]           HoldoutStation.start(pid) (a crank, a diesel hold)
##   give:<weapon id>             the weapon in the player's hands (the viewmodel shots)
##   round:<n>                    RoundManager.debug_set_round
##   wait:<s>                     just wait
## Nodes are found by name anywhere under the map (Gameplay/<name> first).


static func find(map: Node, nm: String) -> Node:
	if map == null:
		return null
	var n: Node = map.get_node_or_null("Gameplay/" + nm)
	return n if n != null else map.find_child(nm, true, false)


static func _arg(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.begins_with("&"):
		return StringName(s.substr(1))
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	return s


static func run(tree: SceneTree, map: Node, player: Player, ops: Array) -> void:
	for op_v: Variant in ops:
		var op: PackedStringArray = str(op_v).split(":")
		match op[0]:
			"power":
				print("[capture] power: was %s, switch %s" % [str(GameState.power_on), str(tree.get_first_node_in_group(&"power_switch"))])
				if not GameState.power_on:
					var sw: Node = tree.get_first_node_in_group(&"power_switch")
					GameState.power_on = true
					GameState.set_flag(&"power_on", true)
					if sw != null and sw.has_method("_sequence_visual"):
						sw.call("_sequence_visual")
					GLBus.power_activated.emit()
					await tree.create_timer(2.5).timeout
			"open":
				var d: Node = find(map, op[1])
				if d != null and d.has_method("open"):
					d.call("open", 0)
					await tree.create_timer(float(GLData.table("world")["door"]["open_seconds"]) + 1.0).timeout
			"tear":
				var w: Node = find(map, op[1])
				if w != null and w.has_method("tear_board"):
					for k: int in (int(op[2]) if op.size() > 2 else 3):
						w.call("tear_board")
					await tree.create_timer(0.6).timeout
			"exfil":
				if map.find_child("ExfilPoint", true, false) == null and map is MapRoot:
					ExfilPoint.spawn(map as MapRoot)
					await tree.create_timer(0.5).timeout
			"call":
				# "call:<node>:<method>[:<wait s>]" (T-147): a set-piece by its own entry point, e.g. the Kranich's
				# London window (FlightController.start_london), shot `wait` seconds in
				var cn: Node = find(map, op[1]) if op.size() > 2 else null
				if cn != null and cn.has_method(op[2]):
					cn.call(op[2])
					await tree.create_timer(float(op[3]) if op.size() > 3 else 1.0).timeout
				else:
					print("[capture] call: no %s.%s" % [op[1] if op.size() > 1 else "?", op[2] if op.size() > 2 else "?"])
			"callv":
				var cv: Node = find(map, op[1]) if op.size() > 2 else null
				if cv != null and cv.has_method(op[2]):
					var args: Array = []
					if op.size() > 3 and op[3] != "":
						for a: String in op[3].split(","):
							args.append(_arg(a))
					cv.callv(op[2], args)
					await tree.create_timer(float(op[4]) if op.size() > 4 else 1.0).timeout
				else:
					print("[capture] callv: no %s.%s" % [op[1] if op.size() > 1 else "?", op[2] if op.size() > 2 else "?"])
			"tide":
				var tc: Node = tree.get_first_node_in_group(&"tide")
				if tc != null and tc.has_method("force_stage"):
					var hold: float = float(op[2]) if op.size() > 2 else 240.0
					tc.call("force_stage", StringName(op[1]), hold)
					var rise: float = float((tc.get("_cfg") as Dictionary).get("rise_seconds", 24.0)) if tc.get("_cfg") is Dictionary else 24.0
					await tree.create_timer(float(op[3]) if op.size() > 3 else rise + 2.0).timeout
				else:
					print("[capture] tide: no TideController on this map")
			"flag":
				GameState.set_flag(StringName(op[1]), _arg(op[2]) if op.size() > 2 else true)
				await tree.process_frame
			"skipto":
				if op.size() > 2:
					QuestManager.debug_skipto(StringName(op[1]), StringName(op[2]))
					for i: int in 5:
						await tree.process_frame
			"use":
				var un: Node = find(map, op[1])
				if un != null and un.has_method("interact") and player != null:
					un.call("interact", player)
					for i: int in 5:
						await tree.process_frame
				else:
					print("[capture] use: no interactable %s" % (op[1] if op.size() > 1 else "?"))
			"start":
				var sn: Node = find(map, op[1])
				if sn != null and sn.has_method("start"):
					sn.call("start", int(op[2]) if op.size() > 2 else 1)
					await tree.create_timer(1.0).timeout
				else:
					print("[capture] start: no station %s" % (op[1] if op.size() > 1 else "?"))
			"give":
				if player != null and player.weapons != null:
					var wid: StringName = StringName(op[1])
					player.weapons.give_weapon(wid)
					var idx: int = player.weapons.slots.find(player.weapons.find_weapon(wid))
					if idx >= 0:
						player.weapons.current_index = idx
						player.weapons.call("_rebuild_gun")
					await tree.create_timer(0.6).timeout
			"round":
				RoundManager.debug_set_round(int(op[1]))
				await tree.process_frame
			"wait":
				await tree.create_timer(float(op[1])).timeout
			"hud_off":
				# T-221 b (the trailer set): the HUD, crosshair and viewmodel gone (the console's `hud off` path)
				TrailerCommands.hud(tree, PackedStringArray(["off"]))
				await tree.process_frame
			"noclip":
				# T-221 b: the camera may hang anywhere (under the belly, in line with the sun), never falls
				if player != null:
					player.noclip = true
					player.collision_mask = 0
			"pos":
				# T-221 b: "pos:x,y,z,yaw,pitch": stand the camera now (before the ops that follow: a clip's action plays
				# in front of it; the cam's own pos is applied only after every op)
				if player != null and op.size() > 1:
					var v: PackedStringArray = op[1].split(",")
					if v.size() >= 3:
						player.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
						player.velocity = Vector3.ZERO
					if v.size() >= 4:
						player.rotation.y = deg_to_rad(float(v[3]))
					if v.size() >= 5:
						player.set("_pitch", deg_to_rad(float(v[4])))
			"timescale":
				Engine.time_scale = clampf(float(op[1]) if op.size() > 1 else 1.0, 0.05, 4.0)
			_:
				print("[capture] unknown do verb '%s'" % op[0])


## The yaw / pitch (degrees) that aims an eye at `eye_from` on `target`; forward is -Z.
static func aim(eye_from: Vector3, target: Vector3) -> Vector2:
	var d: Vector3 = target - eye_from
	var yaw: float = rad_to_deg(atan2(-d.x, -d.z))
	var pitch: float = rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	return Vector2(yaw, pitch)
