class_name WatchRoom
extends Node3D
## The Watch Room (HB3, docs/HOMAGE_BOSSES.md section 6.3; DECISIONS T-160): where THE SLENDER takes a player "for
## review" at 100 LOGGED. A small dark pocket room built off-map below the harbour, shaped like the pens' night-watch
## booth: shelves of watch-books, a desk with a green-shaded lamp, a clock stuck at 3:00 AM that never ticks, a
## dark doorway he walks in from at 1.0 m/s.
## To escape: find your page in one of 3 books (seeded per player; the right one glows a little when you're near and
## its prompt names your character) and tear it out (hold Use, 1.5 s) before he reaches the desk (25 s; 35 s solo).
## Torn in time: back where you were taken, standing, 3 s invulnerable, the meter 0 with 10 s immunity. Too late:
## you are returned downed. Co-op: teammates' lantern hits on him fill a release bar (20% a hit); full = returned
## standing. One player at a time. Pure timing rules are static for the tests.

signal released(pid: int, how: String)

var cfg: Dictionary = {}
var occupant: Player = null
var origin: Vector3 = Vector3.ZERO
var seconds: float = 25.0
var t: float = 0.0
var release_bar: float = 0.0
var right_book: int = 0
var books: Array[Node3D] = []
var escapes: int = 0
var fails: int = 0
var _figure: Node3D
var _door_pos: Vector3 = Vector3(0, 0, 4.0)
var _desk_pos: Vector3 = Vector3(0, 0, -1.6)
var _said_12: bool = false
var _say: Callable = Callable()


## The room's time limit: 25 s, or 35 s for a solo player (no teammates to shoot the lantern).
static func time_limit(c: Dictionary, solo: bool) -> float:
	return float(c.get("room_seconds_solo", 35.0)) if solo else float(c.get("room_seconds", 25.0))


## Where his walk-in figure is at `t` (from the doorway to the desk, reaching it just before the limit).
static func figure_progress(t_now: float, limit: float) -> float:
	return clampf(t_now / maxf(1.0, limit - 1.0), 0.0, 1.0)


## The outcome at a tick: "" (still in), "release" (the bar is full), "fail" (time is up).
static func outcome(t_now: float, limit: float, bar: float) -> String:
	if bar >= 0.999:
		return "release"
	if t_now >= limit:
		return "fail"
	return ""


func _ready() -> void:
	name = "WatchRoom"
	_build()


func busy() -> bool:
	return occupant != null and is_instance_valid(occupant)


func _build() -> void:
	var dark: StandardMaterial3D = HomageBoss.mat(Color(0.08, 0.07, 0.07))
	var wood: StandardMaterial3D = HomageBoss.mat(Color(0.25, 0.17, 0.1))
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for spec: Array in [[Vector3(6, 0.2, 9), Vector3(0, -0.1, 0)], [Vector3(6, 0.2, 9), Vector3(0, 3.1, 0)],
			[Vector3(0.2, 3.2, 9), Vector3(-3.0, 1.5, 0)], [Vector3(0.2, 3.2, 9), Vector3(3.0, 1.5, 0)],
			[Vector3(6, 3.2, 0.2), Vector3(0, 1.5, -4.5)], [Vector3(2.2, 3.2, 0.2), Vector3(-1.9, 1.5, 4.5)], [Vector3(2.2, 3.2, 0.2), Vector3(1.9, 1.5, 4.5)]]:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = spec[0]
		cs.shape = bs
		cs.position = spec[1]
		body.add_child(cs)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = spec[0]
		mi.mesh = bm
		mi.material_override = dark
		mi.position = spec[1]
		add_child(mi)
	# the desk, the green-shaded lamp, the clock at 3:00
	var desk: MeshInstance3D = MeshInstance3D.new()
	var dm: BoxMesh = BoxMesh.new()
	dm.size = Vector3(1.8, 0.8, 0.9)
	desk.mesh = dm
	desk.material_override = wood
	desk.position = _desk_pos + Vector3(0, 0.4, -1.0)
	add_child(desk)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(0.55, 0.9, 0.55)
	lamp.omni_range = 4.0
	lamp.light_energy = 0.9
	lamp.shadow_enabled = false
	lamp.position = _desk_pos + Vector3(0.5, 1.2, -1.0)
	add_child(lamp)
	var clock: Label3D = Label3D.new()
	clock.text = "3:00"
	clock.font_size = 64
	clock.modulate = Color(0.9, 0.85, 0.7)
	clock.position = Vector3(0, 2.3, -4.38)
	add_child(clock)
	# three shelves, one book each that might be yours
	for i: int in 3:
		var b: WatchRoomBook = WatchRoomBook.new()
		b.room = self
		b.index = i
		b.position = Vector3(-2.4 + 2.4 * float(i), 1.0, -4.1) if i != 1 else Vector3(2.6, 1.0, 0.0)
		add_child(b)
		books.append(b)
	# his figure in the doorway
	_figure = Node3D.new()
	var coat: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.34
	cm.height = 2.3
	coat.mesh = cm
	coat.material_override = HomageBoss.mat(Slender.COAT)
	coat.position = Vector3(0, 1.15, 0)
	_figure.add_child(coat)
	var lantern: OmniLight3D = OmniLight3D.new()
	lantern.light_color = Slender.VIOLET
	lantern.omni_range = 4.0
	lantern.light_energy = 1.2
	lantern.position = Vector3(0.4, 1.3, -0.3)
	_figure.add_child(lantern)
	_figure.position = _door_pos + Vector3(0, 0, 2.0)
	add_child(_figure)


## Takes `p` in from `from` (the spot on the map). solo: 35 s.
func take(p: Player, from: Vector3, solo: bool, say: Callable = Callable()) -> void:
	occupant = p
	origin = from
	seconds = time_limit(cfg, solo)
	t = 0.0
	release_bar = 0.0
	_said_12 = false
	_say = say
	right_book = absi(hash(str(RoundManager.rng.seed) + str(p.player_id) + str(escapes + fails))) % 3
	for b: Node3D in books:
		(b as WatchRoomBook).reset()
	if p.is_local or p.is_bot:
		p.global_position = global_position + Vector3(0, 0.1, 1.8)
		p.velocity = Vector3.ZERO
	if _say.is_valid():
		_say.call("SLN_ROOM_01")
	print("[slender] player %d taken in for review (%.0f s, page in book %d)" % [p.player_id, seconds, right_book])


func _physics_process(delta: float) -> void:
	if not busy():
		return
	t += delta
	_figure.position = (_door_pos + Vector3(0, 0, 2.0)).lerp(_desk_pos + Vector3(0, 0, 0.8), figure_progress(t, seconds))
	if t >= 12.0 and not _said_12:
		_said_12 = true
		if _say.is_valid():
			_say.call("SLN_ROOM_02")
	var o: String = outcome(t, seconds, release_bar)
	if o == "release":
		_let_go("released")
	elif o == "fail":
		_let_go("fail")


## A teammate hit his lantern in the real world: the release bar fills (the window lightens).
func lantern_hit() -> void:
	if busy():
		release_bar = minf(1.0, release_bar + float(cfg.get("release_per_lantern_hit", 0.2)))


## The page is torn out: returned standing.
func tear(index: int) -> bool:
	if not busy() or index != right_book:
		return false
	_let_go("page")
	return true


func _let_go(how: String) -> void:
	var p: Player = occupant
	occupant = null
	if p == null or not is_instance_valid(p):
		return
	if p.is_local or p.is_bot:
		p.global_position = origin
		p.velocity = Vector3.ZERO
	if how == "fail":
		fails += 1
		if _say.is_valid():
			_say.call("SLN_ROOM_FAIL_01")
	else:
		escapes += 1
		PerkManager._open_window(p.player_id, "invuln", float(cfg.get("return_invuln", 3.0)))
		if _say.is_valid():
			_say.call("SLN_ROOM_ESCAPE_01")
	print("[slender] player %d returned (%s, %.1f s)" % [p.player_id, how, t])
	released.emit(p.player_id, how)
	if how == "fail":
		p.down()


## One of the room's three watch-books (a page headed with your character's name in the right one).
class WatchRoomBook extends Interactable:
	var room: WatchRoom
	var index: int = 0
	var _glow: OmniLight3D

	func build_greybox() -> void:
		interact_size = Vector3(0.9, 0.9, 0.9)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.4, 0.08, 0.3)
		mi.mesh = bm
		mi.material_override = HomageBoss.mat(Slender.BOOK)
		add_child(mi)
		_glow = OmniLight3D.new()
		_glow.light_color = Color(0.9, 0.8, 0.6)
		_glow.omni_range = 1.2
		_glow.light_energy = 0.0
		_glow.shadow_enabled = false
		add_child(_glow)

	func reset() -> void:
		if _glow != null:
			_glow.light_energy = 0.35 if room != null and index == room.right_book else 0.0

	func hold_time(_player: Player) -> float:
		return float(room.cfg.get("tear_hold", 1.5)) if room != null else 1.5

	func get_prompt(player: Player) -> String:
		if room == null or not room.busy() or room.occupant != player:
			return ""
		if index == room.right_book:
			return "Hold [%s] to tear out your page (%s)" % [prompt_key(&"interact"), String(player.character_id).capitalize()]
		return "A watch-book. Not your page."

	func can_interact(player: Player) -> bool:
		return room != null and room.busy() and room.occupant == player and index == room.right_book

	func interact(_player: Player) -> void:
		if room != null:
			room.tear(index)
