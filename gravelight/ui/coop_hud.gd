class_name CoopHud
extends CanvasLayer
## Co-op HUD (M7), added by the MapRoot in online matches, with AI teammates (T-031) and once a companion joins a
## solo match (T-183). Original, in the Ledger style of ui/hud.gd:
##  - the squad panel (left, under the minimap): one row per teammate (co-op humans, bots, companions such as Jakub
##    or Trudi; not you): the name in their colour, their state and a row of small bottle caps for the tonics they
##    hold (the bonus perk first, gold-ringed; tiers as strokes on a brass tab, gold crimp at III, gold rim at IV).
##    T-183 (the owner: "we don't need to see the kills ... the scores all the time; just their names, whether or not
##    they're down, and really small logos for what perks they have"): no kills or health bars on it. T-243 (the owner:
##    "make sure the player is able to see other players score without going into score board"): each teammate's
##    Scrip is back, in gold in its own column after the name (a companion shows its own once its kills opened an
##    account, T-245; blank before).
##    States: DOWN with the bleed-out clock and a pulsing red cross, REVIVING (someone holds use on them), BLED OUT
##    (a human or bot, back next round), OUT COLD (a companion who bled out: gone for the match).
##  - the scoreboard (hold ui_scoreboard, Ctrl / Back): the full ledger, everyone including you: name, state, Scrip,
##    kills and the tonics with their tier bands. The pause LOADOUT tab lists the squad's Scrip, kills and caps too.
##  - "<name> is down" markers on screen (clamped to the edges) with the distance, so a teammate can be found
##  - your own last stand: the bleed-out bar and "being revived by ..."; spectating after bleeding out

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const SCRIP_COL: Color = Color(0.95, 0.86, 0.55)
const OUT_COL: Color = Color(0.55, 0.53, 0.5)
const DOWN_COL: Color = Color(0.95, 0.32, 0.24)
const REVIVE_COL: Color = Color(0.98, 0.84, 0.4)
## Jakub and the map companions draw in a warm brown (as on the pause map's chips), not a squad slot's colour.
const COMPANION_COL: Color = Color("#c79a5a")

## Tools / tests: show the scoreboard without the key.
var force_board: bool = false

var _font: Font
var _stamp: Font
var _panel: SquadPanel
var _board: Scoreboard
var _center: Label
var _bar: ProgressBar
var _markers: Markers


func _init() -> void:
	layer = 11
	add_to_group(&"coop_hud")


func _ready() -> void:
	_font = MenuKit.mono_font()
	_stamp = MenuKit.stamp_font()
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	add_child(root)
	_markers = Markers.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.font = _font
	root.add_child(_markers)
	_panel = SquadPanel.new()
	_panel.font = _font
	_panel.cap_font = _stamp
	_panel.position = Vector2(28, 300)
	root.add_child(_panel)
	_board = Scoreboard.new()
	_board.font = _font
	_board.stamp = _stamp
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.visible = false
	root.add_child(_board)
	_center = Label.new()
	_center.add_theme_font_override("font", _stamp)
	_center.add_theme_font_size_override("font_size", MenuKit.size("coop_banner"))
	_center.add_theme_color_override("font_color", PAPER)
	MenuKit.outline(_center, "banner")
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.anchor_left = 0.0
	_center.anchor_right = 1.0
	_center.anchor_top = 0.62
	_center.anchor_bottom = 0.62
	_center.offset_top = 0.0
	_center.offset_bottom = 90.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.62
	_bar.anchor_bottom = 0.62
	_bar.offset_left = -170.0
	_bar.offset_right = 170.0
	_bar.offset_top = 96.0
	_bar.offset_bottom = 106.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = INK.lightened(0.15)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	_bar.add_theme_stylebox_override("background", bg)
	root.add_child(_bar)
	GLBus.player_downed.connect(_on_downed)
	GLBus.player_revived.connect(_on_revived)


func _on_downed(pid: int) -> void:
	if pid != Net.local_player_id():
		_banner("%s is down!" % Net.display_name(pid))


func _on_revived(pid: int, by: int) -> void:
	if pid != Net.local_player_id() and by != Net.local_player_id():
		_banner("%s is back up" % Net.display_name(pid))


func _banner(text: String) -> void:
	var hud: Hud = get_tree().get_first_node_in_group(&"hud") as Hud
	if hud != null:
		hud.show_banner(text, 1.6)


func _process(_delta: float) -> void:
	var s: NetMatch = Net.session
	if s == null:
		return
	visible = GameState.phase != GameState.Phase.MENU
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sq: BotSquad = get_tree().get_first_node_in_group(&"bot_squad") as BotSquad
	_panel.position = Vector2(MenuKit.hud_margin(vp).x, panel_top())   # the HUD grid (T-096), clear of the minimap
	_panel.set_rows(squad_rows(s, Net.local_player_id()))
	var show_board: bool = force_board or (InputMap.has_action(&"ui_scoreboard") and Input.is_action_pressed(&"ui_scoreboard")
		and not get_tree().paused)
	if show_board != _board.visible:
		_board.visible = show_board
	if show_board:
		_board.rows = board_rows(s, sq)
		_board.queue_redraw()
	_update_center(s)
	_markers.session = s
	_markers.queue_redraw()


## The panel's top: under the minimap with its stamp and floor line (Update 04, T-065) and under the debug lines
## when they show (hud.gd puts them under the minimap).
func panel_top() -> float:
	var y: float = maxf(300.0, Minimap.layout_bottom + 50.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	var dbg: Label = hud.get("_debug_label") as Label if hud != null else null
	if dbg != null and dbg.visible and dbg.text != "":
		y = maxf(y, dbg.position.y + dbg.get_minimum_size().y + 10.0)
	return y


## One row per teammate of `me` (humans and bots by pid, then the companions with the squad): {pid, name, color,
## state ("up" / "down" / "reviving" / "out" / "cold"), bleed (seconds), companion, scrip (-1: no account),
## caps [[perk, tier, bonus]]}.
static func squad_rows(s: NetMatch, me: int) -> Array:
	var out: Array = []
	if s == null:
		return out
	var ids: Array[int] = []
	for pid: Variant in s.players.keys():
		if int(pid) != me:
			ids.append(int(pid))
	ids.sort()
	var cids: Array[int] = []
	for cid: Variant in s.companions.keys():
		if not ids.has(int(cid)) and int(cid) != me:
			cids.append(int(cid))
	cids.sort()
	for pid2: int in ids:
		out.append(_row(s, pid2, false))
	for cid2: int in cids:
		out.append(_row(s, cid2, true))
	return out


static func _row(s: NetMatch, pid: int, companion: bool) -> Dictionary:
	var state: String = "up"
	if s.coop.is_downed(pid):
		state = "reviving" if s.coop.reviver_of(pid) != 0 else "down"
	elif s.coop.is_dead(pid):
		state = "cold" if companion else "out"
	return {"pid": pid, "name": Net.display_name(pid), "color": COMPANION_COL if companion else Net.player_color(pid),
		"state": state, "bleed": s.coop.bleed_left(pid), "companion": companion,
		"scrip": Economy.get_scrip(pid) if not companion or Economy.has_account(pid) else -1, "caps": caps_of(pid)}   # (T-245: a companion's own Scrip, T-177)


## A survivor's tonics as [[perk, tier, bonus]], the bonus perk first (as on the nameplates).
static func caps_of(pid: int) -> Array:
	var out: Array = []
	var bonus: StringName = PerkManager.bonus_perk(pid)
	var owned: Array = PerkManager.owned(pid)
	if bonus != &"" and owned.has(bonus):
		out.append([bonus, PerkManager.tier_of(pid, bonus), true])
	for pk: Variant in owned:
		if StringName(pk) != bonus:
			out.append([StringName(pk), PerkManager.tier_of(pid, StringName(pk)), false])
	return out


## The scoreboard: everyone (you first), with the numbers: {..row.., you, scrip, kills (-1: not counted)}.
static func board_rows(s: NetMatch, sq: BotSquad) -> Array:
	var me: int = Net.local_player_id()
	var out: Array = []
	if s == null:
		return out
	if s.players.has(me):
		out.append(_row(s, me, false))
	out.append_array(squad_rows(s, me))
	for r: Dictionary in out:
		var pid: int = int(r["pid"])
		r["you"] = pid == me
		var k: int = -1
		if sq != null:
			k = int(sq.kills.get(pid, 0))
		elif pid == me:
			k = int(GameState.stats.get(&"kills", 0))
		r["kills"] = k
	return out


func _update_center(s: NetMatch) -> void:
	var me: int = Net.local_player_id()
	_bar.visible = false
	if s.coop.is_downed(me):
		var by: int = s.coop.reviver_of(me)
		if by != 0:
			_center.text = "%s is reviving you..." % Net.display_name(by)
		else:
			_center.text = "YOU'RE DOWN  ·  keep firing, crawl to cover"
		_bar.visible = true
		_bar.value = s.coop.bleed_left(me) / maxf(1.0, float(GLData.table("player")["bleedout_seconds"]))
	elif s.coop.is_dead(me):
		var who: String = s.spectate_name()
		_center.text = "BLED OUT  ·  back next round" + (("\nwatching %s   [%s] next" % [who, Interactable.prompt_key(&"fire")]) if who != "" else "")
	else:
		_center.text = ""


## The status word for a row's state ("" while standing). Shared by the panel and the scoreboard.
static func state_text(r: Dictionary) -> String:
	match str(r.get("state", "up")):
		"down":
			return "DOWN %d" % int(ceil(float(r.get("bleed", 0.0))))
		"reviving":
			return "REVIVING"
		"out":
			return "BLED OUT"
		"cold":
			return "OUT COLD"
	return ""


static func state_color(r: Dictionary) -> Color:
	match str(r.get("state", "up")):
		"down":
			return DOWN_COL
		"reviving":
			return REVIVE_COL
		"out", "cold":
			return OUT_COL
	return PAPER


## The squad panel (T-183): drawn, not Labels (re-theming a Label per change cost frames, T-070). A row is
## [state mark] NAME ǂSCRIP [DOWN 23] (caps...). Sizes from ui.json hud: squad_row (the name's font size), squad_cap (a cap's
## diameter), squad_row_h.
class SquadPanel extends Control:
	var font: Font
	var cap_font: Font
	var rows: Array = []
	var _sig: String = ""
	var _pulse: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_rows(r: Array) -> void:
		var sig: String = var_to_str(r)
		_pulse = false
		for row: Dictionary in r:
			if str(row["state"]) == "down":
				_pulse = true
		if sig == _sig and not _pulse:
			return   # (while someone is down the cross pulses: CoopHud calls this every frame, so it redraws)
		_sig = sig
		rows = r
		var rh: float = float(MenuKit.hud("squad_row_h", 24.0))
		size = Vector2(width(), rh * float(rows.size()))
		queue_redraw()

	## The name column: the widest name in the squad, so the caps line up.
	func name_w() -> float:
		var fs: int = MenuKit.size("coop_row")
		var w: float = 0.0
		for r: Dictionary in rows:
			w = maxf(w, font.get_string_size(str(r["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 60.0)
		return w

	## The Scrip column (T-243): as wide as the squad's biggest balance, so the state words and caps line up.
	static func scrip_text(r: Dictionary) -> String:
		var scrip: int = int(r.get("scrip", -1))
		return ("ǂ%d" % scrip) if scrip >= 0 else ""

	func scrip_w() -> float:
		var fs: int = MenuKit.size("coop_row") - 2
		var w: float = 0.0
		for r: Dictionary in rows:
			var t: String = scrip_text(r)
			if t != "":
				w = maxf(w, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 50.0)
		return w + 10.0 if w > 0.0 else 0.0

	func width() -> float:
		var cd: float = float(MenuKit.hud("squad_cap", 16.0))
		var most: int = 0
		for r: Dictionary in rows:
			most = maxi(most, (r["caps"] as Array).size())
		return 22.0 + name_w() + 12.0 + scrip_w() + 80.0 + float(most) * (cd + 3.0) + 3.0

	func _draw() -> void:
		var fs: int = MenuKit.size("coop_row")
		var rh: float = float(MenuKit.hud("squad_row_h", 24.0))
		var cd: float = float(MenuKit.hud("squad_cap", 16.0))
		var nw: float = name_w()
		var scw: float = scrip_w()
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		for i: int in rows.size():
			var r: Dictionary = rows[i]
			var y: float = float(i) * rh
			var mid: float = y + rh * 0.5
			var st: String = str(r["state"])
			var col: Color = r["color"] as Color
			var out: bool = st == "out" or st == "cold"
			var caps: Array = r["caps"]
			# a soft backing strip, so the row holds on bright snow
			var tw: String = CoopHud.state_text(r)
			var sw: float = font.get_string_size(tw, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4).x + 10.0 if tw != "" and font != null else 0.0
			var strip_w: float = 22.0 + nw + 10.0 + scw + sw + float(caps.size()) * (cd + 3.0) + 9.0
			draw_rect(Rect2(-6.0, y + 2.0, strip_w, rh - 4.0), Color(0.04, 0.03, 0.02, 0.36))
			# the state mark: a colour chip while standing, a red cross while down (gold while being revived), a dash out
			var mc: Vector2 = Vector2(6.0, mid)
			match st:
				"down", "reviving":
					var cc: Color = CoopHud.DOWN_COL if st == "down" else CoopHud.REVIVE_COL
					if st == "down":
						cc.a = pulse
					draw_rect(Rect2(mc - Vector2(2.0, 7.0), Vector2(4.0, 14.0)), cc)
					draw_rect(Rect2(mc - Vector2(7.0, 2.0), Vector2(14.0, 4.0)), cc)
				"out", "cold":
					draw_rect(Rect2(mc - Vector2(6.0, 1.5), Vector2(12.0, 3.0)), CoopHud.OUT_COL)
				_:
					draw_rect(Rect2(mc - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), Color(0, 0, 0, 0.7))
					draw_rect(Rect2(mc - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), col)
			# the name
			var x: float = 22.0
			var ncol: Color = col.lightened(0.2) if not out else CoopHud.OUT_COL
			if font != null:
				var base: float = mid + float(fs) * 0.34
				draw_string_outline(font, Vector2(x, base), str(r["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.78))
				draw_string(font, Vector2(x, base), str(r["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ncol)
			x += nw + 10.0
			# the Scrip (T-243), dimmed with the row while they are out
			var scrip_t: String = scrip_text(r)
			if scrip_t != "" and font != null:
				var base3: float = mid + float(fs - 2) * 0.34
				var scol: Color = CoopHud.SCRIP_COL if not out else CoopHud.OUT_COL
				draw_string_outline(font, Vector2(x, base3), scrip_t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, 4, Color(0, 0, 0, 0.8))
				draw_string(font, Vector2(x, base3), scrip_t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, scol)
			x += scw
			# the state word (DOWN 23 / REVIVING / BLED OUT / OUT COLD)
			if tw != "" and font != null:
				var base2: float = mid + float(fs - 4) * 0.34
				draw_string_outline(font, Vector2(x, base2), tw, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, 4, Color(0, 0, 0, 0.8))
				draw_string(font, Vector2(x, base2), tw, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, CoopHud.state_color(r))
				x += sw
			# the tonics
			for k: int in caps.size():
				var cap: Array = caps[k]
				var cc2: Vector2 = Vector2(x + cd * 0.5, mid)
				draw_circle(cc2 + Vector2(0.8, 1.5), cd * 0.5 + 0.5, Color(0, 0, 0, 0.45))
				PerkCap.draw_cap(self, cc2, cd * 0.5, cap[0], bool(cap[2]), cap_font, 0.55 if out else 1.0, int(cap[1]))
				x += cd + (6.0 if bool(cap[2]) else 3.0)   # the bonus perk's gold ring needs a little room


## The scoreboard (T-183, hold ui_scoreboard): a ruled ledger plate in the middle of the screen.
class Scoreboard extends Control:
	var font: Font
	var stamp: Font
	var rows: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		var fs: int = MenuKit.size("coop_row")
		var rh: float = 44.0
		var w: float = 760.0
		var cap_r: float = 15.0
		var h: float = 96.0 + rh * float(rows.size())
		var o: Vector2 = Vector2(roundf((vp.x - w) * 0.5), roundf(vp.y * 0.22))
		draw_rect(Rect2(o + Vector2(4, 6), Vector2(w, h)), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(o, Vector2(w, h)), Color(0.07, 0.055, 0.045, 0.9))
		draw_rect(Rect2(o, Vector2(w, h)), Color(0.72, 0.55, 0.25, 0.9), false, 2.0)
		draw_rect(Rect2(o + Vector2(5, 5), Vector2(w - 10, h - 10)), Color(0.72, 0.55, 0.25, 0.35), false, 1.0)
		if stamp != null:
			var title: String = "SQUAD LEDGER  ·  ROUND %d" % RoundManager.current_round
			draw_string(stamp, o + Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, CoopHud.PAPER)
		var cols: Array = [["SURVIVOR", 24.0], ["SCRIP", 250.0], ["KILLS", 360.0], ["TONICS", 450.0]]
		if font != null:
			for c: Array in cols:
				draw_string(font, o + Vector2(float(c[1]), 74), str(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MenuKit.DIM)
		draw_line(o + Vector2(16, 84), o + Vector2(w - 16, 84), Color(0.72, 0.55, 0.25, 0.6), 1.0)
		for i: int in rows.size():
			var r: Dictionary = rows[i]
			var y: float = o.y + 92.0 + rh * float(i)
			var mid: float = y + rh * 0.5
			if bool(r.get("you", false)):
				draw_rect(Rect2(o.x + 8, y + 2, w - 16, rh - 4), Color(0.95, 0.86, 0.55, 0.08))
			var st: String = str(r["state"])
			var out: bool = st == "out" or st == "cold"
			var col: Color = (r["color"] as Color).lightened(0.2) if not out else CoopHud.OUT_COL
			var base: float = mid + float(fs) * 0.34
			if font != null:
				var nm: String = str(r["name"]) + ("  (you)" if bool(r.get("you", false)) else "")
				draw_string(font, Vector2(o.x + 24, base), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				var sw: String = CoopHud.state_text(r)
				if sw != "":
					draw_string(font, Vector2(o.x + 24, base + 15), sw, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CoopHud.state_color(r))
				var scrip: int = int(r.get("scrip", -1))
				draw_string(font, Vector2(o.x + 250, base), ("ǂ%d" % scrip) if scrip >= 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CoopHud.SCRIP_COL)
				var kills: int = int(r.get("kills", -1))
				draw_string(font, Vector2(o.x + 360, base), str(kills) if kills >= 0 else "—", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CoopHud.PAPER)
			var x: float = o.x + 450.0 + cap_r
			for cap: Array in r["caps"]:
				PerkCap.draw_cap(self, Vector2(x, mid), cap_r, cap[0], bool(cap[2]), stamp, 1.0, int(cap[1]))
				x += cap_r * 2.0 + 5.0
			if i < rows.size() - 1:
				draw_line(Vector2(o.x + 16, y + rh), Vector2(o.x + w - 16, y + rh), Color(0.72, 0.55, 0.25, 0.18), 1.0)
		if font != null:
			var hint: String = "hold [%s]" % Interactable.prompt_key(&"ui_scoreboard")
			draw_string(font, o + Vector2(w - 24 - font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 40), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuKit.DIM)


## Downed-teammate markers drawn over the 3D view.
class Markers extends Control:
	var session: NetMatch
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if session == null:
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			return
		var sz: Vector2 = get_viewport_rect().size
		for pid: Variant in session.players.keys():
			if int(pid) == Net.local_player_id() or not session.coop.is_downed(int(pid)):
				continue
			var p: Player = session.players[pid]
			var world: Vector3 = p.global_position + Vector3.UP * 0.8
			var behind: bool = cam.is_position_behind(world)
			var sp: Vector2 = cam.unproject_position(world)
			if behind:
				sp = sz - sp
			# T-218: the cross AND its name stay on screen (the name is 120 px wide, centred under the cross; at the
			# old 48 px margin "Deacon 5m" ran off the left edge), inside the HUD's own margins
			var hm: Vector2 = MenuKit.hud_margin(sz)
			var mx: float = hm.x + 24.0   # the 120 px name box starts ~20 px in
			var my: float = maxf(hm.y, 48.0)
			var clamped: Vector2 = Vector2(clampf(sp.x, mx, sz.x - mx), clampf(sp.y, my, sz.y - my - 40.0))
			if behind:
				clamped.y = sz.y - my - 40.0
			var col: Color = Color(0.85, 0.15, 0.1, 0.9)
			var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
			draw_circle(clamped, 15.0 * pulse, Color(0, 0, 0, 0.55))
			draw_rect(Rect2(clamped - Vector2(3, 10), Vector2(6, 20)), col)
			draw_rect(Rect2(clamped - Vector2(10, 3), Vector2(20, 6)), col)
			var d: float = cam.global_position.distance_to(p.global_position)
			if font != null:
				draw_string(font, clamped + Vector2(-60, 34), "%s  %dm" % [Net.display_name(int(pid)), int(d)], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 0.85, 0.8))
