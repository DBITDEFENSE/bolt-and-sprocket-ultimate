extends Node
## Dev tool (T-183): the left-side squad panel, the player's own perk caps and the tonic icons. Map 0 with three
## bots and Trudi (the map companion) joined: every bot holds tonics at mixed tiers (one with its bonus perk), one
## bot is down (the bleed-out clock), one has bled out, the boss bar is forced on; then the hold-to-show scoreboard
## (the squad's full numbers) and a contact sheet of all twelve tonic caps at every size the game draws them
## (the squad panel's tiny caps, the nameplates, the HUD row, the pause list, the cabinet sign) on dark and pale grounds.
## Rendered: run it ONLY under WSL + Xvfb (tools/wsl_godot.sh, software GL = the Compatibility renderer), never a
## Windows window (CLAUDE.md):
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/shots_squad_hud.tscn -- --out=<dir> --tag=1080
##   (21:9: --res=2520x1080; 1440p: XVFB_SCREEN=2560x1440x24 ... --res=2560x1440; --icons-only: just the icon sheet,
##   no map, a few seconds)
## -> <dir>/squad_NN_<name>_<tag>.png. The profile and settings are never written (temp paths). Prints "[squad] done".

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const HUMAN_PERKS: Array = [&"ironhide_stout", &"second_wind", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"hawkeye_brandy"]
## per bot: [perks..], its tiers {perk: tier}, its bonus perk
const BOT_KITS: Array = [
	[[&"ironhide_stout", &"second_wind", &"packmule_porter", &"blastproof_bock"], {&"ironhide_stout": 3, &"second_wind": 2}, &"overclock_cordial"],
	[[&"ironhide_stout", &"skyhook_sekt", &"magpie_mead"], {&"magpie_mead": 4}, &"ledger_lager"],
	[[&"ironhide_stout", &"second_wind", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"hawkeye_brandy"], {&"twin_barrel": 2}, &""],
]
const VIEWS: Array = [
	["taproom", Vector3(20.0, 0.1, 13.0), 40.0, -6.0],
	["snow", Vector3(4.0, 0.1, -20.0), -90.0, 0.0],
]

var _out: String = "user://shots_squad"
var _tag: String = ""
var _n: int = 0
var _map: MapRoot
var _icons_only: bool = false


class FakeBoss extends Node:
	func hp_fraction() -> float:
		return 0.62


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a == "--icons-only":
			_icons_only = true
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_squad_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_shots_squad_settings.cfg"
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	if _icons_only:
		_sheet_only.call_deferred()
		return
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _shot(label: String) -> void:
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if _n == 0:
		print("[squad] window %s, capture %s" % [DisplayServer.window_get_size(), img.get_size()])
	var fn: String = "squad_%02d_%s%s.png" % [_n, label, ("_" + _tag) if _tag != "" else ""]
	img.save_png(_out.path_join(fn))
	print("[squad] %02d %s" % [_n, label])
	_n += 1


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		var p: Player = n as Player
		if p != null and not p.is_companion:
			out.append(p)
	out.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	return out


func _run() -> void:
	await _wait(9.0)
	var human: Player = _map.player
	for pk: StringName in HUMAN_PERKS:
		PerkManager.grant(1, pk)
	PerkManager.set_tier(1, &"ironhide_stout", 2)
	PerkManager.set_tier(1, &"second_wind", 3)
	PerkManager.set_tier(1, &"twin_barrel", PerkManager.permanent_tier())
	var bots: Array[Player] = _bots()
	for i: int in mini(bots.size(), BOT_KITS.size()):
		var pid: int = bots[i].player_id
		var kit: Array = BOT_KITS[i]
		for pk2: Variant in PerkManager.owned(pid).duplicate():
			PerkManager.remove(pid, StringName(pk2))
		for pk3: StringName in kit[0]:
			PerkManager.grant(pid, pk3)
		if StringName(kit[2]) != &"":
			PerkManager.grant_bonus(pid, kit[2])
		for t: Variant in (kit[1] as Dictionary).keys():
			PerkManager.set_tier(pid, StringName(t), int(kit[1][t]))
	# Trudi, the map companion, joins (she would turn up in the stable from round 2)
	for mc: MapCompanion in MapCompanion.instances(get_tree()):
		if mc.player == null:
			mc.call("_appear")
		mc.choose(human, false)
	await _wait(1.0)
	# one bot down (its bleed-out clock), one bled out
	if bots.size() >= 3:
		bots[1].take_hit(9999.0, null)
		await _wait(0.5)
		bots[2].take_hit(9999.0, null)
		await _wait(1.0)
		if _map.session != null and _map.session.coop.is_downed(bots[2].player_id):
			(_map.session.coop.players[bots[2].player_id] as Dictionary)["bleed"] = 0.05   # its clock runs out next tick
		await _wait(1.0)
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.call("_on_round_started", 7, false)
	var boss_hud: BossHud = BossHud.new()
	_map.add_child(boss_hud)
	var fake: FakeBoss = FakeBoss.new()
	_map.add_child(fake)
	var tl: PackedStringArray = HomageBoss.title_for("cousin_1", true)
	boss_hud.add_bar("cousin_1", fake, tl[0], tl[1])
	for v: Array in VIEWS:
		human.global_position = v[1]
		human.velocity = Vector3.ZERO
		human.rotation.y = deg_to_rad(float(v[2]))
		human.set("_pitch", deg_to_rad(float(v[3])))
		await _wait(0.8)
		await _shot(str(v[0]))
	# the hold-to-show scoreboard (T-183; the old build has none and shows the plain panel)
	var coop: Node = null
	for c: Node in _map.get_children():
		if c is CanvasLayer and (c as CanvasLayer).get_script() != null and str(((c as CanvasLayer).get_script() as Script).resource_path).ends_with("coop_hud.gd"):
			coop = c
	if coop != null:
		coop.set("force_board", true)
		await _wait(0.3)
		await _shot("scoreboard")
		coop.set("force_board", false)
	await _sheet_only()


## The tonic icon sheet, then quit.
func _sheet_only() -> void:
	var sheet: IconSheet = IconSheet.new()
	add_child(sheet)
	await _wait(0.3)
	await _shot("icons")
	sheet.queue_free()
	print("[squad] done -> ", _out)
	get_tree().quit()


## Every tonic in perks.json order, one row each: the cap at the sizes the game uses (tier I, II, III, IV and the
## bonus ring at the HUD size), on a dark half (the cellar) and a pale half (snow).
class IconSheet extends CanvasLayer:
	func _init() -> void:
		layer = 120
		var c: Sheet = Sheet.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)

	class Sheet extends Control:
		func _draw() -> void:
			var vp: Vector2 = get_viewport_rect().size
			draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x * 0.5, vp.y)), Color(0.07, 0.065, 0.06))
			draw_rect(Rect2(Vector2(vp.x * 0.5, 0.0), Vector2(vp.x * 0.5, vp.y)), Color(0.86, 0.87, 0.88))
			var f: Font = MenuKit.stamp_font()
			var mono: Font = MenuKit.mono_font()
			var ids: Array = (GLData.table("perks")["perks"] as Dictionary).keys()
			var row_h: float = minf(84.0, (vp.y - 40.0) / float(ids.size()))
			for half: int in 2:
				var x0: float = 20.0 + half * vp.x * 0.5
				for i: int in ids.size():
					var id: StringName = StringName(str(ids[i]))
					var y: float = 30.0 + row_h * (float(i) + 0.5)
					var txt: Color = Color(0.9, 0.86, 0.78) if half == 0 else Color(0.1, 0.08, 0.06)
					if half == 0:
						draw_string(mono, Vector2(x0, y + 5.0), str(ids[i]).left(15), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, txt)
					var x: float = x0 + (150.0 if half == 0 else 10.0)
					# squad panel (8), plates (9), HUD now/then (20/27), pause (27), sign (38): tier I
					for r: float in [8.0, 9.0, 14.0, 20.0, 27.0, 38.0]:
						x += r + 4.0
						PerkCap.draw_cap(self, Vector2(x, y), r, id, false, f, 1.0, 1)
						x += r + 6.0
					x += 10.0
					for t: int in [2, 3, 4]:
						x += 20.0 + 4.0
						PerkCap.draw_cap(self, Vector2(x, y), 20.0, id, false, f, 1.0, t)
						x += 20.0 + 6.0
					for t2: int in [2, 3, 4]:
						x += 8.0 + 4.0
						PerkCap.draw_cap(self, Vector2(x, y), 8.0, id, false, f, 1.0, t2)
						x += 8.0 + 4.0
					x += 14.0
					PerkCap.draw_cap(self, Vector2(x, y), 9.0, id, true, f, 1.0, 1)
					x += 30.0
					PerkCap.draw_cap(self, Vector2(x, y), 20.0, id, false, f, 1.0, 1, true)
