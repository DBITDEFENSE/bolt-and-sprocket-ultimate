class_name BankBranch
extends Node3D
## T-136: a savings bank branch (data/gravelight/bank.json "branches"): the Crossroads' Darlehenskasse in the old
## woodshed (its walls: gen_map00 build_bank_shed) and the pay office in Kaltenbrunn's administration block. Built
## at load, in the branch's own frame (origin = the counter's centre on the floor, +z = the customers' side): a walnut
## counter with a green baize top and a brass grille with the teller's window, a ledger, a bell, a safe behind, a
## lamp; the teller, Erwin Lassmann, a junior clerk scared out of his wits (a PatronBody: he clutches the counter,
## cowers when the dead come near, flinches at shots); and the counter (BankCounter) that opens the BankCard.
## MapRoot attaches it (and a BankLedger, the interest, on every map).

var cfgb: Dictionary = {}         # this branch's bank.json row
var map: MapRoot
var teller: PatronBody
var counter: BankCounter
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _said_at: Dictionary = {}
var _last_line: String = ""
var _scared_t: float = 0.0
var _check_t: float = 0.0
var _greeted: bool = false
var lines_said: int = 0


static func branch_for(map_id: String) -> Dictionary:
	var all: Dictionary = BankAccount.cfg().get("branches", {})
	for k: Variant in all.keys():
		if map_id.begins_with(str(k)):
			return all[k]
	return {}


static func attach(m: MapRoot) -> void:
	var led: BankLedger = BankLedger.new()
	led.name = "BankLedger"
	m.add_child(led)
	led.setup(m)
	var row: Dictionary = branch_for(String(m.map_id))
	if row.is_empty():
		return
	var b: BankBranch = BankBranch.new()
	b.name = "BankBranch"
	b.cfgb = row
	b.map = m
	m.add_child(b)


func _ready() -> void:
	add_to_group(&"bank_branch")
	_rng.seed = 7151
	var a: Array = cfgb.get("at", [0, 0, 0])
	global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(cfgb.get("yaw", 0.0)))), Vector3(float(a[0]), float(a[1]), float(a[2])))
	_build_furniture()
	var tc: Dictionary = BankAccount.cfg().get("teller", {})
	teller = PatronBody.new()
	teller.name = "Teller"
	add_child(teller)
	teller.position = Vector3(0.0, 0.0, float(cfgb.get("teller_z", -0.75)))
	teller.setup({"id": str(tc.get("id", "teller")), "pose": "clutch"})
	counter = BankCounter.new()
	counter.name = "Counter"
	counter.branch = self
	add_child(counter)
	counter.position = Vector3(0.0, 0.0, 0.55)
	GLBus.weapon_fired.connect(_on_shot)


# ================================================================== the room

func _build_furniture() -> void:
	_batch = {}   # T-139: the boxes and cylinders below merge into one mesh per material (was ~65 draw calls + casters)
	_build_pieces()
	_flush_batch()


func _build_pieces() -> void:
	var w: float = float(cfgb.get("width", 4.5))
	var d: float = 0.5
	var h: float = 1.05
	_solid_box(Vector3(0, h * 0.5, 0), Vector3(w, h, d))   # one collider for the counter (the grille above is open)
	_box(Vector3(0, h * 0.5 - 0.02, 0), Vector3(w, h - 0.04, d), "walnut")
	_box(Vector3(0, h - 0.015, 0.02), Vector3(w + 0.06, 0.03, d + 0.1), "walnut")
	_box(Vector3(0, h + 0.004, 0.0), Vector3(w - 0.1, 0.008, d - 0.08), "felt_green")
	for i: int in int(w / 0.8):   # the front's panels
		var x: float = -w * 0.5 + 0.4 + i * 0.8
		_box(Vector3(x, h * 0.5, d * 0.5 + 0.006), Vector3(0.62, h - 0.3, 0.012), "frame_walnut")
	_box(Vector3(0, 0.05, d * 0.5 + 0.01), Vector3(w, 0.1, 0.02), "beam")   # the kick plate
	# the brass grille, the teller's window in the middle
	var top: float = 1.95
	var win: float = 0.36
	var x0: float = -w * 0.5 + 0.03
	while x0 < w * 0.5:
		if absf(x0) > win:
			_box(Vector3(x0, (h + top) * 0.5, -0.05), Vector3(0.012, top - h, 0.012), "brass")
		x0 += 0.11
	_box(Vector3(0, top, -0.05), Vector3(w, 0.03, 0.03), "brass")
	_box(Vector3(0, h + 0.5, -0.05), Vector3(w, 0.02, 0.02), "brass")
	_box(Vector3(0, h + 0.46, -0.05), Vector3(win * 2.0, 0.02, 0.03), "brass")   # the window's arch rail
	_box(Vector3(0, h + 0.012, 0.12), Vector3(win * 1.6, 0.012, 0.22), "brass_plate")   # the brass money tray
	# a ledger, an ink pot, the bell, the stamp; a lamp hanging over the window
	_box(Vector3(-0.55, h + 0.03, -0.12), Vector3(0.34, 0.04, 0.26), "leather")
	_box(Vector3(-0.55, h + 0.052, -0.12), Vector3(0.32, 0.004, 0.24), "paper_old")
	_box(Vector3(0.45, h + 0.03, -0.1), Vector3(0.05, 0.06, 0.05), "bottle_green")
	_cyl(Vector3(0.62, h + 0.03, 0.18), 0.045, 0.05, "brass")
	_cyl(Vector3(0.62, h + 0.065, 0.18), 0.008, 0.03, "iron")
	_box(Vector3(0.3, h + 0.04, 0.05), Vector3(0.06, 0.08, 0.04), "walnut")
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "BankLamp"
	lamp.light_color = Color(1.0, 0.74, 0.46)
	lamp.light_energy = 1.6
	lamp.omni_range = 5.5
	lamp.omni_attenuation = 1.3
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.position = Vector3(0, 2.05, -0.2)
	_cyl(Vector3(0, 2.2, -0.2), 0.12, 0.14, "lantern_glass")
	_cyl(Vector3(0, 2.32, -0.2), 0.008, 0.2, "iron")
	# the safe behind him
	var sf: Array = cfgb.get("safe", [1.6, -1.0])
	var sp: Vector3 = Vector3(float(sf[0]), 0.0, float(sf[1]))
	_solid_box(sp + Vector3(0, 0.55, 0), Vector3(0.75, 1.1, 0.6))
	_box(sp + Vector3(0, 0.55, 0), Vector3(0.75, 1.1, 0.6), "loco_black")
	_box(sp + Vector3(0, 0.55, 0.302), Vector3(0.6, 0.92, 0.01), "steel")
	_cyl(sp + Vector3(0, 0.62, 0.32), 0.07, 0.03, "brass", Vector3(90, 0, 0))
	_box(sp + Vector3(0.18, 0.45, 0.32), Vector3(0.03, 0.14, 0.03), "brass")
	# a sign over his head, where the branch has a wall for it (the Crossroads' is painted outside)
	if cfgb.has("sign"):
		var sa: Array = cfgb["sign"]
		var sp2: Vector3 = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
		_box(sp2 + Vector3(0, 0, -0.02), Vector3(2.9, 0.34, 0.03), "paint_green")
		var l: Label3D = Label3D.new()
		l.text = str(cfgb.get("title", "BANK"))
		l.font_size = 30
		l.pixel_size = 0.0034
		l.modulate = Color(0.92, 0.84, 0.6)
		l.outline_size = 0
		l.shaded = true
		add_child(l)
		l.position = sp2 + Vector3(0, 0, 0.005)


## T-139: material -> SurfaceTool while the furniture is built (null = add each piece as its own node).
var _batch: Variant = null


func _add_piece(mesh: PrimitiveMesh, mat: String, xf: Transform3D) -> bool:
	if not (_batch is Dictionary):
		return false
	var b: Dictionary = _batch
	if not b.has(mat):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[mat] = st
	(b[mat] as SurfaceTool).append_from(mesh, 0, xf)
	return true


func _flush_batch() -> void:
	if not (_batch is Dictionary):
		return
	var b: Dictionary = _batch
	_batch = null
	for mat: String in b:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Furniture_" + mat
		mi.mesh = (b[mat] as SurfaceTool).commit()
		mi.material_override = Mats.get_mat(mat)
		add_child(mi)


func _box(c: Vector3, sz: Vector3, mat: String) -> void:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	if _add_piece(bm, mat, Transform3D(Basis(), c)):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Mats.get_mat(mat)
	mi.position = c
	add_child(mi)


func _cyl(c: Vector3, r: float, h: float, mat: String, rot: Vector3 = Vector3.ZERO) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	if _add_piece(cm, mat, Transform3D(Basis.from_euler(rot * (PI / 180.0)), c)):
		mi.free()
		return
	mi.mesh = cm
	mi.material_override = Mats.get_mat(mat)
	mi.position = c
	mi.rotation_degrees = rot
	add_child(mi)


func _solid_box(c: Vector3, sz: Vector3) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("no_mantle", true)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.position = c


# ================================================================== the teller

func _physics_process(delta: float) -> void:
	_check_t -= delta
	_scared_t = maxf(0.0, _scared_t - delta)
	if _check_t > 0.0 or teller == null:
		return
	_check_t = 0.4
	var near: bool = _dead_near(float(BankAccount.cfg().get("teller_scared_m", 12.0)))
	teller.set_pose(&"cower" if near or _scared_t > 0.0 else &"clutch")
	if near:
		say("BANK_SCARED")
	var h: Player = _human_near(5.0)
	if h != null and not _greeted:
		_greeted = true
		say(str(cfgb.get("greet", "BANK_GREET")))


func _on_shot(_p: int, _w: StringName, _u: bool, origin: Vector3, _d: Vector3) -> void:
	if teller != null and origin.distance_to(global_position) < 9.0:
		_scared_t = 2.5
		teller.flinch()


func _dead_near(r: float) -> bool:
	if map == null or map.director == null:
		return false
	for z: Variant in map.director.active_zombies():
		if is_instance_valid(z) and (z as Node3D).global_position.distance_to(global_position) < r:
			return true
	return false


func _human_near(r: float) -> Player:
	if map == null:
		return null
	for k: Variant in map.players.keys():
		var p: Player = map.players[k] as Player
		if p != null and not p.is_bot and p.global_position.distance_to(global_position) < r:
			return p
	return null


## One of his lines for a category (bank.json line_cooldown_s), positional at him, subtitled with his name.
func say(category: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var cds: Dictionary = BankAccount.cfg().get("line_cooldown_s", {})
	if now < float(_said_at.get(category, -INF)) + float(cds.get(category, 8.0)):
		return
	var spk: String = str((BankAccount.cfg().get("teller", {}) as Dictionary).get("speaker", "TEL"))
	var pool: Array = []
	for id: String in GLVO.lines.keys():
		var rec: Dictionary = GLVO.lines[id]
		if str(rec.get("speaker", "")) == spk and str(rec.get("category", "")) == category and id != _last_line:
			pool.append(id)
	if pool.is_empty():
		return
	_said_at[category] = now
	var line: String = str(pool[_rng.randi_range(0, pool.size() - 1)])
	_last_line = line
	var rec2: Dictionary = GLVO.lines[line]
	var text: String = GLVO.strip_tags(str(rec2.get("text", "")))
	var dur: float = GLVO.duration_for(text, GLVO.rules)
	var path: String = GLVO.audio_path(StringName(line))
	if path != "":
		var stream: AudioStream = GLVO.load_stream(path)
		if stream != null:
			var ap: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			ap.bus = &"VO"
			ap.stream = stream
			ap.unit_size = 5.0
			ap.max_distance = 30.0
			add_child(ap)
			ap.position = teller.position + Vector3(0, 1.6, 0)
			ap.play()
			ap.finished.connect(ap.queue_free)
			dur = maxf(dur, stream.get_length())
	lines_said += 1
	GLBus.vo_line_started.emit(StringName(line), StringName(str((BankAccount.cfg().get("teller", {}) as Dictionary).get("display", "TELLER"))), text, dur)
