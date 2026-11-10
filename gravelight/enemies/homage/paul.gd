class_name Paul
extends HomageBoss
## PAUL (HB2, docs/HOMAGE_BOSSES.md section 5; DECISIONS T-159): Pvt. Paul, a US Army combat engineer dosed past
## any limit with Ironhide Stout at Kaltenbrunn. Powerful, heroic, never a joke: a strongman and a protector whose
## last impulse is "protect my guys". Iron-red skin (never green), riveted bone plates like the Ironhide barrel
## mascot, a cracked rack of six Helvetia bottles on his back feeding IV lines into his neck, a big beard, a torn
## wool cap, rolled sleeves, dog tags and the crushed tin cup in his left hand.
## Body: the MZ humanoid (ZombieBody "soldier", heavy, male) on the shared rig, scaled to 2.5 m and grown per rage
## stage (x1.00 / x1.15 / x1.30), with the plates, the rack, the bottles (each its own hitbox, limbs bottle1..6) and
## the IV lines as costume pieces on bone attachments; the HomagePoseMod layer gives his poses.
## The rage system (PaulRage): damage, fleeing and downed players fill it; cooling, broken bottles and the tin-cup
## idle drain it; the stage sets his size, speed and move set. Moves (pose + sound + light telegraphs, data in
## bosses/map01.json "moves"): Haymaker, Zombie Throw, Grab & Squeeze (Calm+); Ground Pound Combo, Rip & Throw
## (Angry+); Leap Slam, Thunderclap, Charge, Headframe Climb & Dive (BERSERK). Hit rules: head x1.25, arms/legs x0.8,
## the back of the neck x2 from behind (> 120 deg), no flinch from small hits, a big explosive (>= 3% max HP in one
## blast) drops him to one knee for 2.5 s (x1.5), a Charge into a wall stuns him 2 s (x1.5).
## Arena: he follows anywhere (surface leaps; down the lift shaft into F; never into the Core Vault: he waits in G).
## Death and the twist (section 5.6): to his knees, the rage drains, he shrinks a little and the red fades, he looks
## at the nearest player, knows them for one of ours, says his last line, presses the tin cup into their hand and
## falls forward like a tree. Never undone (PaulEncounter: gone for the match).
## Pure rules are static for the tests (moves_for_stage, neck_mult, staggers, cooldowns, last_line_for).
##
## T-232 (docs/BOSS_REWORK.md 4.1, the boss rework): the model on the kit's helpers: iron-red skin with a wet sheen
## (`wet`), the plates rust-rough metal with a darker rim and rivet shadows (`mat_ex`), the six bottles lit from inside
## (emissive glass and an amber rack light that dim as each breaks), the IV lines as `cable`s with a faint violet
## emission and stout `drips` at the neck, `steam` on every exhale (the breath clock; constant at BERSERK), eyes that
## read (`eye_glow`, warm amber, a slow blink), the tin cup and dog tags catching light. Effects: the "dread" block
## (boss_stomp footfalls with a shake that grows per stage), `fx.tele` on every telegraph, paul_roar / paul_plate_grind
## / paul_bottle_break / boss_breath, a ground crack decal under each BERSERK footfall, the yard's floods dying under
## his BERSERK roar (BossFx.lights_dim + flicker; the encounter swings the headframe's floods). Battle: the third-stage
## "protect my guys" turn (`guard`: he stands over a downed player's body and slams anyone who comes near, in front of
## him only, so the body can be revived from behind), the rage spike when a player runs out of his sight
## (PaulRage.on_flee_break), and the squad rules (a hurt player becomes his target; a lone player gets pressure but a
## shorter, easier grab). Every existing move, the rage system, the fail-safe and the death are unchanged.

const IRON_RED: Color = Color(1.55, 0.6, 0.48, 1.0)   # inst_tint over the grey-green skin: iron-red like the stout
const HUMAN_TINT: Color = Color(1.18, 0.92, 0.84, 1.0)
const PLATE: Color = Color(0.36, 0.17, 0.13)
const PLATE_RIM: Color = Color(0.16, 0.08, 0.06)
const RUST: Color = Color(0.46, 0.2, 0.09)
const RIVET: Color = Color(0.66, 0.54, 0.38)
const GLASS: Color = Color(0.32, 0.2, 0.1)
const GLASS_LIT: Color = Color(0.5, 0.28, 0.12)
const STOUT_GLOW: Color = Color(1.0, 0.5, 0.16)
const STOUT: Color = Color(0.12, 0.05, 0.03)
const IV_LINE: Color = Color(0.16, 0.09, 0.12)
const IV_GLOW: Color = Color(0.62, 0.36, 0.92)
const TIN: Color = Color(0.6, 0.6, 0.58)
const BEARD: Color = Color(0.22, 0.14, 0.09)
const WOOL: Color = Color(0.3, 0.3, 0.22)
const LABEL: Color = Color(0.78, 0.7, 0.52)
const VIOLET: Color = Color(0.7, 0.35, 1.0)
const EYE_AMBER: Color = Color(1.0, 0.72, 0.36)
const EYE_RAGE: Color = Color(1.0, 0.5, 0.22)
const TELE_COLOR: Color = Color(1.0, 0.46, 0.2)       # his telegraph light: the stout's glow, not the Nachtglas violet
const MAX_CRACKS: int = 24
const LAST_LINES: Dictionary = {&"dutch": "PAU_LAST_DUT_01", &"peg": "PAU_LAST_PEG_01", &"deacon": "PAU_LAST_DEA_01",
	&"wren": "PAU_LAST_WRN_01", &"bolt": "PAU_LAST_BLT_01", &"vendelin": "PAU_LAST_VEN_01"}

var rage: PaulRage
var stage_scale: float = 1.0
var bottles_hp: Array[float] = []
var bottles_broken: int = 0
var bottle_nodes: Array[Node3D] = []
var bottle_boxes: Array[Hitbox] = []
var knee_t: float = 0.0              # > 0: the knee-down stagger (x1.5)
var stun_t: float = 0.0              # > 0: stunned against a wall after a Charge (x1.5)
var staggers_taken: int = 0
var wall_stuns: int = 0
var doors_smashed: Array[StringName] = []
var boards_stripped: int = 0
var berserk_seen: bool = false
var cup_given_to: int = -1
var death_line: String = ""
var fallen: bool = false
var climbing: bool = false
var in_shaft: bool = false
var taunts: int = 0
var throws_done: int = 0
var grabs_done: int = 0
var dive_target: Vector3 = Vector3.ZERO
var _arena: Dictionary = {}
var _grow_t: float = 0.0
var _grow_from: float = 1.0
var _grow_to: float = 1.0
var _stage_seen: int = 0
var _hit_from: Vector3 = Vector3.INF
var _quiet_t: float = 0.0
var _taunt_cd: float = 8.0
var _fleeing_t: Dictionary = {}       # pid -> seconds he has targeted them
var _downed_seen: Dictionary = {}     # pid -> true (already counted the burst)
var _proj: Node3D = null              # the thrown zombie / cart in flight
var _proj_from: Vector3
var _proj_to: Vector3
var _proj_t: float = 0.0
var _proj_dur: float = 1.0
var _proj_kind: String = ""
var _shadow: MeshInstance3D = null
var _leap_from: Vector3
var _leap_to: Vector3
var _ring_r: float = -1.0
var _ring_hit: Dictionary = {}
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_run: float = 0.0
var _charge_hit: Dictionary = {}
var _cup: Node3D = null
var _plates: Array[Node3D] = []
var _steam: GPUParticles3D = null
var _drips: GPUParticles3D = null
var _glow: OmniLight3D = null
var _rack_light: OmniLight3D = null
var _bottle_mat: StandardMaterial3D = null
var _eyes: BossFx.EyeGlow = null
var _death_phase: int = 0
var _death_from_tint: Color = IRON_RED
var _held_lift: Dictionary = {}       # the grab being lifted
var _shaft_t: float = 0.0
var _shaft_from: Vector3
var _shaft_to: Vector3
var _cleanup_after: float = -1.0
# T-232: the breath clock, the floods beat, the crack decals, the guard, the flee spike and the squad read
var _breath_t: float = 1.5
var _steam_until: float = 0.0
var _floods_out: bool = false
var _floods_t: float = 0.0
var _cracks: Array[Node3D] = []
var guard_pid: int = -1               # the downed player he stands over (-1: not guarding)
var guard_t: float = 0.0
var guard_slams: int = 0
var guards_done: int = 0
var _guard_cd: float = 0.0
var _guard_tele: float = -1.0
var _guard_posed: bool = false
var flee_breaks: int = 0
var _was_seen: Dictionary = {}        # pid -> he had line of sight last tick
var _flee_break_t: Dictionary = {}    # pid -> clock time of the last spike
var squad_state: Dictionary = {"alone": false, "hurt": null, "downed": 0}
var _squad_t: float = 0.0
var _hurt_say_t: float = -99.0
var _retreat_roared: bool = false


func _init() -> void:
	boss_key = "paul"


func _ready() -> void:
	super._ready()
	ecfg = GLData.table("bosses/map01")
	bcfg = HomageEncounter.block(ecfg, "paul")
	_arena = bcfg.get("arena", {})
	rage = PaulRage.new(bcfg.get("rage", {}))
	# T-232: the base built the kit from the Cousins' table (his block lives in map01.json): give it his dread block
	if fx != null:
		for k: Variant in (bcfg.get("dread", {}) as Dictionary).keys():
			fx.cfg[k] = bcfg["dread"][k]


func modelled() -> bool:
	return false


func person_id() -> String:
	return "paul"


# ================================================================== pure rules (unit-tested)

## The moves his stage allows (a move's "stage" is the lowest stage it unlocks at).
static func moves_for_stage(c: Dictionary, stage: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in (c.get("moves", {}) as Dictionary).keys():
		if not (c["moves"][k] is Dictionary):
			continue
		if int((c["moves"][k] as Dictionary).get("stage", 0)) <= stage:
			out.append(str(k))
	return out


static func start_cooldown(cds: Dictionary, id: String, seconds: float, mult: float = 1.0) -> void:
	cds[id] = seconds * mult


static func tick_cooldowns(cds: Dictionary, delta: float) -> void:
	for k: Variant in cds.keys():
		cds[k] = maxf(0.0, float(cds[k]) - delta)


static func cooldown_ready(cds: Dictionary, id: String) -> bool:
	return float(cds.get(id, 0.0)) <= 0.0


## The back of the neck: x`mult` when the attacker is more than `angle_deg` off his facing (from behind).
static func neck_mult(limb: StringName, facing: Vector3, to_attacker: Vector3, angle_deg: float, mult: float) -> float:
	if limb != &"neck":
		return 1.0
	var f: Vector2 = Vector2(facing.x, facing.z)
	var a: Vector2 = Vector2(to_attacker.x, to_attacker.z)
	if f.length_squared() < 1e-6 or a.length_squared() < 1e-6:
		return 1.0
	return mult if rad_to_deg(f.angle_to(a)) > angle_deg or rad_to_deg(f.angle_to(a)) < -angle_deg else 1.0


## A big explosive staggers him: one blast of `fraction` or more of his max HP.
static func staggers(amount: float, max_health: float, kind: StringName, fraction: float) -> bool:
	return kind == &"explosive" and amount >= max_health * fraction


## PAUL'S LAST ROUND: free Ironhide (no perk slot) until downed, or +100 overshield if you already have it.
static func last_round_effect(has_ironhide: bool) -> String:
	return "overshield" if has_ironhide else "ironhide"


static func last_line_for(character: StringName) -> String:
	return str(LAST_LINES.get(character, "PAU_LAST_DUT_01"))


# ================================================================== spawn and the body

func spawn_paul(at: Vector3, health: float) -> void:
	spawn_homage(at, health)


## The arrival: he has been up the headframe the whole time; he leaps down and lands in the crater.
func arrive_leap(from: Vector3, to: Vector3, seconds: float) -> void:
	_leap_from = from
	_leap_to = to
	_arrive_s = maxf(0.2, seconds)
	global_position = from
	_special_id = "arrive"
	_go(B.SPECIAL, "arrive")
	pose_anim()
	_pose.set_bone("LeftUpperArm", Vector3(2.4, 0, 0.6))
	_pose.set_bone("RightUpperArm", Vector3(2.4, 0, -0.6))
	_show_shadow(to, 2.5)


var _arrive_s: float = 1.1


func _on_spawned() -> void:
	enemy_id = &"paul"
	_female = false
	_build = "heavy"
	_body.mesh = ZombieBody.build_skinned("soldier", "heavy", false)
	_set_inst("inst_tint", IRON_RED)
	_set_inst("inst_dirt", 0.35)
	_look.primary_limit_angle = deg_to_rad(80.0)
	rage = PaulRage.new(bcfg.get("rage", {}))
	_stage_seen = PaulRage.CALM
	stage_scale = 1.0
	_grow_t = 0.0
	_apply_scale(1.0)
	knee_t = 0.0
	stun_t = 0.0
	fallen = false
	climbing = false
	in_shaft = false
	_death_phase = 0
	_quiet_t = 0.0
	_taunt_cd = 8.0
	_downed_seen.clear()
	_fleeing_t.clear()
	_was_seen.clear()
	_flee_break_t.clear()
	guard_pid = -1
	_guard_tele = -1.0
	_floods_out = false
	_breath_t = 1.5
	_steam_until = 0.0
	_retreat_roared = false
	_regrow_bottles()
	if _steam != null:
		_steam.emitting = false
	if _drips != null:
		_drips.emitting = true
	if _glow != null:
		_glow.light_energy = 0.0
	if _eyes != null:
		_eyes.lit = true
		_eyes.color = EYE_AMBER
	_apply_stage_look(PaulRage.CALM)


func _apply_scale(s: float) -> void:
	_pivot.scale = Vector3.ONE * float(bcfg.get("height", 1.38)) * s
	stage_scale = s


## The rage bottle on his boss bar (0..1).
func gauge_value() -> float:
	return rage.fill() if rage != null else 0.0


func stage() -> int:
	return rage.stage if rage != null else PaulRage.CALM


## All six bottles back on the rack (a return visit regrows them), each with its scaled HP.
func _regrow_bottles() -> void:
	var r: Dictionary = bcfg.get("rage", {})
	var hpb: float = HomageBoss.scaled_hp(float(r.get("bottle_hp", 400.0)), RoundManager.players, float(bcfg.get("hp_player_step", 0.75)))
	bottles_hp.clear()
	for i: int in int(r.get("bottles", 6)):
		bottles_hp.append(hpb)
	bottles_broken = 0
	for n: Node3D in bottle_nodes:
		n.show()
	for hb: Hitbox in bottle_boxes:
		hb.collision_layer = Hitbox.LAYER_HITBOX
	_update_bottle_glow()


## T-232: the bottles are lit from inside; the glass and the rack's amber light dim as the rack empties.
func _update_bottle_glow() -> void:
	var k: float = float(bottles_left()) / maxf(1.0, float(bottles_hp.size()))
	if _bottle_mat != null:
		_bottle_mat.emission_energy_multiplier = 1.6 * (0.3 + 0.7 * k)
	if _rack_light != null:
		_rack_light.light_energy = 0.9 * k


func bottles_left() -> int:
	var n: int = 0
	for h: float in bottles_hp:
		if h > 0.0:
			n += 1
	return n


## One costume piece in one material (T-232: the kit's `mat_ex` surfaces, where `costume()` gives the greybox matte).
## `parts` are [primitive, Transform3D, colour] like costume()'s; the colour is ignored for `m`.
func _piece(parent: Node3D, parts: Array, m: Material) -> MeshInstance3D:
	if parent == null or parts.is_empty():
		return null
	var mesh: ArrayMesh = ArrayMesh.new()
	var st: SurfaceTool = SurfaceTool.new()
	for p: Array in parts:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	st.commit(mesh)
	mesh.surface_set_material(0, m)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _build_costume() -> void:
	# the beard (wet at the tips) and the torn wool cap
	costume("Head", [
		sph(0.13, Vector3(0, -0.06, -0.07), BEARD, Vector3(1.0, 1.05, 0.75)),
		sph(0.11, Vector3(0, -0.12, -0.05), BEARD, Vector3(0.9, 0.9, 0.7)),
		cyl(0.125, 0.13, 0.08, Vector3(0, 0.15, 0.0), WOOL),
		boxp(Vector3(0.06, 0.03, 0.05), Vector3(0.09, 0.19, -0.02), WOOL, Vector3(0, 0, 0.4)),   # the torn edge
	])
	_piece(bone_attachment("Head"), [sph(0.1, Vector3(0, -0.17, -0.06), BEARD, Vector3(0.8, 0.5, 0.6))], mat_ex(Color(0.14, 0.09, 0.06), 0.25, 0.1))
	# the dog tags on their chain: tin that catches the light
	_piece(bone_attachment("Neck"), [cyl(0.075, 0.075, 0.01, Vector3(0, -0.02, 0), TIN)], mat_ex(Color(0.36, 0.36, 0.35), 0.45, 0.8))
	_piece(bone_attachment("Neck"), [
		boxp(Vector3(0.025, 0.04, 0.004), Vector3(0.0, -0.13, -0.12), TIN),
		boxp(Vector3(0.025, 0.04, 0.004), Vector3(0.012, -0.14, -0.125), TIN, Vector3(0, 0, 0.3)),
	], mat_ex(TIN, 0.28, 0.9))
	# the riveted bone plates: rust-rough iron, a darker rim where they push out of the skin, rivets with their
	# shadows, rust streaks running down from the rivets (each plate one group that extrudes per stage)
	var m_plate: StandardMaterial3D = mat_ex(PLATE, 0.78, 0.35)
	var m_rim: StandardMaterial3D = mat_ex(PLATE_RIM, 0.9, 0.25)
	var m_rivet: StandardMaterial3D = mat_ex(RIVET, 0.36, 0.9)
	var m_shadow: StandardMaterial3D = mat_ex(Color(0.1, 0.05, 0.04), 0.95, 0.0)
	var m_rust: StandardMaterial3D = mat_ex(RUST, 0.95, 0.15)
	_plates.clear()
	for spec: Array in [["Chest", Vector3(0.0, 0.18, -0.15), Vector3(0.34, 0.16, 0.05)], ["Chest", Vector3(0.0, 0.06, -0.16), Vector3(0.3, 0.1, 0.05)],
			["LeftUpperArm", Vector3(0.0, -0.06, 0.0), Vector3(0.15, 0.18, 0.15)], ["RightUpperArm", Vector3(0.0, -0.06, 0.0), Vector3(0.15, 0.18, 0.15)],
			["Spine", Vector3(0.0, 0.1, 0.15), Vector3(0.3, 0.14, 0.05)], ["LeftLowerArm", Vector3(0.0, -0.12, -0.02), Vector3(0.12, 0.16, 0.12)],
			["RightLowerArm", Vector3(0.0, -0.12, -0.02), Vector3(0.12, 0.16, 0.12)]]:
		var at: Node3D = bone_attachment(str(spec[0]))
		if at == null:
			continue
		var pos: Vector3 = spec[1]
		var sz: Vector3 = spec[2]
		var n: Vector3 = Vector3(0, 0, signf(pos.z)) if pos.z != 0.0 else Vector3(0, 0, -1)   # the plate's outward face
		var grp: Node3D = Node3D.new()
		grp.name = "Plate"
		at.add_child(grp)
		_piece(grp, [boxp(sz, pos, PLATE)], m_plate)
		_piece(grp, [boxp(Vector3(sz.x * 1.12, sz.y * 1.12, sz.z * 0.5), pos - n * sz.z * 0.3, PLATE_RIM)], m_rim)
		var rivets: Array = []
		var shadows: Array = []
		var streaks: Array = []
		for rx: float in [-0.4, 0.4]:
			for ry: float in [-0.35, 0.35]:
				var rp: Vector3 = pos + Vector3(sz.x * rx, sz.y * ry, 0.0) + n * (sz.z * 0.5 + 0.004)
				rivets.append(sph(0.012, rp, RIVET))
				shadows.append(sph(0.017, rp - n * 0.006 + Vector3(0, -0.004, 0), PLATE_RIM, Vector3(1.0, 0.8, 0.3)))
				if ry < 0.0:
					streaks.append(boxp(Vector3(0.008, sz.y * 0.35, 0.003), rp + Vector3(0.0, -sz.y * 0.2, 0.0) + n * 0.001, RUST))
		_piece(grp, rivets, m_rivet)
		_piece(grp, shadows, m_shadow)
		_piece(grp, streaks, m_rust)
		_plates.append(grp)
	# the cracked rack of six Helvetia bottles on his back, each its own hitbox, lit from inside, IV lines over the
	# shoulders into the back of the neck
	var rack_at: BoneAttachment3D = bone_attachment("Chest")
	_piece(rack_at, [
		boxp(Vector3(0.46, 0.05, 0.12), Vector3(0, 0.3, 0.2), Color(0.3, 0.22, 0.14)),
		boxp(Vector3(0.46, 0.05, 0.12), Vector3(0, -0.02, 0.2), Color(0.3, 0.22, 0.14)),
		boxp(Vector3(0.04, 0.36, 0.1), Vector3(-0.23, 0.14, 0.2), Color(0.3, 0.22, 0.14)),
		boxp(Vector3(0.04, 0.36, 0.1), Vector3(0.23, 0.14, 0.2), Color(0.3, 0.22, 0.14)),
	], mat_ex(Color(0.3, 0.22, 0.14), 0.85, 0.0))
	_piece(rack_at, [boxp(Vector3(0.5, 0.03, 0.03), Vector3(0, 0.14, 0.14), Color(0.25, 0.25, 0.25), Vector3(0, 0, 0.15))], mat_ex(Color(0.22, 0.2, 0.19), 0.7, 0.3))   # the strap
	_piece(rack_at, [boxp(Vector3(0.05, 0.02, 0.13), Vector3(-0.2, 0.33, 0.2), RUST), boxp(Vector3(0.03, 0.02, 0.09), Vector3(0.21, 0.0, 0.2), RUST)], m_rust)   # the rack's rust
	_bottle_mat = mat_ex(GLASS_LIT, 0.22, 0.0, 1.6, STOUT_GLOW).duplicate() as StandardMaterial3D   # his own: it dims
	var m_cap: StandardMaterial3D = mat_ex(TIN, 0.4, 0.85)
	var m_label: StandardMaterial3D = mat_ex(LABEL, 0.9, 0.0)
	bottle_nodes.clear()
	bottle_boxes.clear()
	var i: int = 0
	for row: float in [0.22, 0.06]:
		for col: float in [-0.15, 0.0, 0.15]:
			i += 1
			var b: Node3D = Node3D.new()
			b.name = "Bottle%d" % i
			b.position = Vector3(col, row, 0.21)
			rack_at.add_child(b)
			_piece(b, [cyl(0.035, 0.035, 0.12, Vector3(0, 0, 0), GLASS), cyl(0.015, 0.025, 0.05, Vector3(0, 0.08, 0), GLASS)], _bottle_mat)
			_piece(b, [cyl(0.016, 0.016, 0.012, Vector3(0, 0.108, 0), TIN)], m_cap)
			_piece(b, [cyl(0.037, 0.037, 0.04, Vector3(0, -0.01, 0), LABEL)], m_label)
			var hb: Hitbox = Hitbox.new()
			hb.name = "BottleHit"
			hb.setup(self, StringName("bottle%d" % i), Vector3(0.09, 0.15, 0.09))
			hb.bone = "Chest"
			b.add_child(hb)
			_hitboxes.append(hb)
			bottle_boxes.append(hb)
			bottle_nodes.append(b)
			# its IV line: out of the bottle's neck, up over the shoulder, into the back of the neck (a faint violet
			# runs in it: the Nachtglas in the stout)
			cable("Chest", [Vector3(col, row + 0.12, 0.21), Vector3(col * 0.7, row + 0.26, 0.19), Vector3(col * 0.35, 0.44, 0.11),
				Vector3(col * 0.12, 0.5, 0.05)], 0.007, IV_LINE, 0.45, IV_GLOW)
	_rack_light = OmniLight3D.new()
	_rack_light.light_color = STOUT_GLOW
	_rack_light.omni_range = 2.6
	_rack_light.omni_attenuation = 1.4
	_rack_light.light_energy = 0.9
	_rack_light.shadow_enabled = false
	_rack_light.position = Vector3(0, 0.14, 0.3)
	rack_at.add_child(_rack_light)
	# the crushed tin cup in his left hand (tin that catches light)
	_cup = _piece(bone_attachment("LeftHand"), [cyl(0.045, 0.04, 0.07, Vector3(0.0, -0.08, -0.03), TIN, Vector3(0.2, 0, 0.3)),
		boxp(Vector3(0.01, 0.04, 0.03), Vector3(0.05, -0.08, -0.03), TIN)], mat_ex(TIN, 0.38, 0.85))
	# the kit's emitters: steam off the plates on every exhale, stout drips where the lines go into the neck
	_steam = BossFx.emitter("steam", bone_attachment("Chest"), Vector3(0, 0.24, -0.04), 1.1)
	_drips = BossFx.emitter("drips", bone_attachment("Neck"), Vector3(0, -0.04, 0.09), 0.5)
	# the BERSERK glow, the eyes (warm amber, a slow blink), the wet sheen
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.35, 0.2)
	_glow.omni_range = 5.0
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	bone_attachment("Chest").add_child(_glow)
	_eyes = eye_glow(EYE_AMBER, 1.0, 4.5) as BossFx.EyeGlow
	wet(0.35)


## The plates push out and the glow per stage (growth itself is the pivot scale in _tick_growth). T-232: the kit's
## footfall shake and radius grow with him, the eyes burn harder and redder, the steam runs at BERSERK.
func _apply_stage_look(s: int) -> void:
	for p: Node3D in _plates:
		p.scale = Vector3.ONE * (1.0 + 0.12 * float(s))
	if _steam != null:
		_steam.emitting = s == PaulRage.BERSERK
	if _glow != null:
		_glow.light_energy = 1.6 if s == PaulRage.BERSERK else 0.0
	_set_inst("inst_tint", IRON_RED * Color(1.0 + 0.12 * float(s), 1.0, 1.0, 1.0) if s == PaulRage.BERSERK else IRON_RED)
	if _eyes != null:
		_eyes.energy = 1.0 + 0.6 * float(s)
		_eyes.color = EYE_AMBER.lerp(EYE_RAGE, float(s) * 0.5)
	if fx != null:
		var d: Dictionary = bcfg.get("dread", {})
		fx.cfg["step_shake"] = float(d.get("step_shake", 0.45)) + float(d.get("stage_step_shake", 0.2)) * float(s)
		fx.cfg["step_radius"] = float(d.get("step_radius", 16.0)) + float(d.get("stage_step_radius", 4.0)) * float(s)


# ================================================================== the brain

func move_speed() -> float:
	var st: Array = bcfg.get("stages", [])
	var base: float = float((st[stage()] as Dictionary).get("speed", 2.6)) if stage() < st.size() else 2.6
	return base * squad_speed_mult


func _tick(delta: float) -> void:
	_tick_squad(delta)
	_tick_rage(delta)
	_tick_growth(delta)
	_tick_projectile(delta)
	_tick_ring(delta)
	_tick_lift(delta)
	_tick_breath(delta)
	_tick_floods(delta)
	_quiet_t += delta
	_taunt_cd = maxf(0.0, _taunt_cd - delta)
	_guard_cd = maxf(0.0, _guard_cd - delta)
	if guard_pid >= 0 and not (bstate == B.SPECIAL and _special_id == "guard"):
		guard_pid = -1   # a stagger or a stun broke the guard
	if knee_t > 0.0:
		knee_t -= delta
		stand(delta, false)
		if knee_t <= 0.0:
			_pose.clear()
			_go(B.RECOVER)
		return
	if stun_t > 0.0:
		stun_t -= delta
		stand(delta, false)
		if stun_t <= 0.0:
			_pose.clear()
			_go(B.RECOVER)
		return
	match bstate:
		B.ARRIVE:
			stand(delta)
			if _bt >= float(bcfg.get("arrive_hold", 1.0)):
				_go(B.MOVE)
		B.MOVE:
			_think(delta)
		B.TELEGRAPH:
			_telegraph(delta)
		B.ACTIVE:
			_active(delta)
		B.RECOVER:
			stand(delta)
			if _bt >= 0.45:
				_go(B.MOVE)
		B.SPECIAL:
			_special(delta)


func _tick_rage(delta: float) -> void:
	var fleeing: int = 0
	var downed_seen: int = 0
	var rc: Dictionary = bcfg.get("rage", {})
	var flee_r: float = float(rc.get("flee_radius", 20.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null:
			continue
		if p.downed:
			if p.global_position.distance_to(global_position) < 30.0 and has_los(p, 2.2, 0.4):
				downed_seen += 1
				if not _downed_seen.has(p.player_id):
					_downed_seen[p.player_id] = true
					rage.on_player_down()
					say("PAU_DOWN_01")
			continue
		_downed_seen.erase(p.player_id)
		if not p.is_alive():
			_was_seen.erase(p.player_id)
			continue
		if p == target:
			_fleeing_t[p.player_id] = float(_fleeing_t.get(p.player_id, 0.0)) + delta
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		var running_off: bool = p.sprinting and d.length() < flee_r and p.velocity.dot(d) > 0.5
		if running_off and float(_fleeing_t.get(p.player_id, 0.0)) > 0.0:
			fleeing += 1
		# T-232: the spike. He could see them a moment ago; now they have sprinted out of his sight.
		var seen: bool = d.length() < flee_r + 6.0 and has_los(p, 2.2, 1.2)
		if bool(_was_seen.get(p.player_id, false)) and not seen and running_off and _clock - float(_flee_break_t.get(p.player_id, -99.0)) >= float(rc.get("flee_break_every", 3.0)):
			_flee_break_t[p.player_id] = _clock
			flee_breaks += 1
			rage.on_flee_break()
			say("PAU_FLEE_01")
			sfx("boss_roar_low", 0.0, 0.9)
		_was_seen[p.player_id] = seen
	var before: int = rage.stage
	rage.tick(delta, fleeing, downed_seen)
	if fleeing > 0 and randf() < delta * 0.05:
		say("PAU_FLEE_01")
	if rage.stage != before:
		_on_stage_changed(before, rage.stage)


## T-232: reads the squad every quarter second: alone (one player on their feet), the hurt one (the lowest health
## fraction under the threshold, within range, in his sight) and how many are down. A hurt player becomes his target
## while he is choosing a move, and the dread layer reads him looking at them.
func _tick_squad(delta: float) -> void:
	_squad_t -= delta
	var sq: Dictionary = bcfg.get("squad", {})
	if _squad_t <= 0.0:
		_squad_t = 0.25
		squad_state = read_squad(alive_players(), sq)
	var hurt: Player = squad_state.get("hurt") as Player
	if hurt != null and is_instance_valid(hurt) and hurt.is_alive():
		if bstate == B.MOVE:
			target = hurt
			if _clock - _hurt_say_t >= float(sq.get("hurt_say_every", 20.0)):
				_hurt_say_t = _clock
				say("PAU_CALM_03")
		if fx != null and hurt.is_local and not hurt.is_bot:
			fx.extra_dread = maxf(fx.extra_dread, float(sq.get("hurt_dread", 0.25)))
	else:
		squad_state["hurt"] = null


## The squad read, pure for the tests: {"alone": one player standing, "hurt": the hurt player (or null), "downed": n}.
## `los` decides sight (the live boss passes its ray; a test passes a lambda).
func read_squad(alive: Array, sq: Dictionary, los: Callable = Callable()) -> Dictionary:
	var hurt: Player = null
	var hurt_k: float = float(sq.get("hurt_fraction", 0.35))
	var rng_m: float = float(sq.get("hurt_range", 25.0))
	var downed: int = 0
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.downed and not p.spectating:
				downed += 1
	for v: Variant in alive:
		var p: Player = v as Player
		if p == null or p.max_hp <= 0.0:
			continue
		var k: float = p.hp / p.max_hp
		if k < hurt_k and dist_to(p) <= rng_m and (los.call(p) if los.is_valid() else has_los(p, 2.2, 1.2)):
			if hurt == null or k < hurt.hp / hurt.max_hp:
				hurt = p
	return {"alone": alive.size() == 1, "hurt": hurt, "downed": downed}


## T-232: the breath clock: a low breath and a puff of steam off the plates on every exhale (faster and harder as he
## rages; at BERSERK the steam never stops).
func _tick_breath(delta: float) -> void:
	_breath_t -= delta
	if _breath_t <= 0.0:
		var s: int = stage()
		_breath_t = randf_range(2.2, 3.4) / (1.0 + 0.35 * float(s))
		sfx("boss_breath", -10.0 + 2.5 * float(s), 0.9 - 0.08 * float(s))
		_steam_puff(0.45 + 0.15 * float(s))
	if _steam != null and stage() != PaulRage.BERSERK:
		_steam.emitting = _clock < _steam_until


## Steam off the plates for `seconds` (constant at BERSERK).
func _steam_puff(seconds: float) -> void:
	_steam_until = maxf(_steam_until, _clock + seconds)
	if _steam != null:
		_steam.emitting = true


## T-232: the arena beat. The yard's lights die under his BERSERK roar and gutter again every `again_s` while he stays
## BERSERK; they come back when he shrinks, leaves or dies.
func _tick_floods(delta: float) -> void:
	if not _floods_out or fx == null:
		return
	_floods_t -= delta
	if _floods_t <= 0.0:
		var fl: Dictionary = bcfg.get("floods", {})
		_floods_t = float(fl.get("again_s", 18.0))
		fx.lights_flicker(float(fl.get("flicker_s", 2.5)) * 0.6, 0.7)
		sfx("paul_roar", -2.0, 0.85)


func _floods_die() -> void:
	var fl: Dictionary = bcfg.get("floods", {})
	if fx != null:
		fx.lights_dim(global_position, float(fl.get("radius", 32.0)), float(fl.get("level", 0.12)), 1.0)
		fx.lights_flicker(float(fl.get("flicker_s", 2.5)), 0.85)
	_floods_out = true
	_floods_t = float(fl.get("again_s", 18.0))
	print("[paul] BERSERK: the yard's floods die under his roar (%d lights)" % (fx.dimmed_count() if fx != null else 0))


func _floods_back(seconds: float = -1.0) -> void:
	if not _floods_out:
		return
	_floods_out = false
	if fx != null:
		fx.lights_restore(float((bcfg.get("floods", {}) as Dictionary).get("restore_s", 5.0)) if seconds < 0.0 else seconds)


## A stage change: the growth (or the shrink back, with a hiss of steam), the speed and the moves follow. T-232: the
## plates grind as they push out, his own roar, the telegraph light flares through the growth; BERSERK kills the
## yard's floods (the encounter swings the headframe's lamps); shrinking out of BERSERK brings the light back.
func _on_stage_changed(from: int, to: int) -> void:
	var st: Array = bcfg.get("stages", [])
	_grow_from = stage_scale
	_grow_to = float((st[to] as Dictionary).get("scale", 1.0)) if to < st.size() else 1.0
	_grow_t = float(bcfg.get("grow_seconds", 1.2))
	_apply_stage_look(to)
	if fx != null:
		fx.tele(TELE_COLOR, 3.0 + float(to), _grow_t, false)
	if to > from:
		sfx("paul_roar", 2.0, 1.0 - 0.08 * float(to))
		sfx("paul_plate_grind", 0.0, 1.0 - 0.1 * float(to))
		_steam_puff(1.2)
		if to == PaulRage.ANGRY:
			say("PAU_ANGRY_01")
			if event != null and event.has_method("on_paul_stage"):
				event.call("on_paul_stage", to)
		elif to == PaulRage.BERSERK:
			berserk_seen = true
			say("PAU_BERSERK_01")
			_floods_die()
			if event != null and event.has_method("on_paul_stage"):
				event.call("on_paul_stage", to)
	else:
		sfx("boss_breath", 2.0, 0.6)   # the hiss of steam as he shrinks
		_steam_puff(1.5)
		if from == PaulRage.BERSERK:
			_floods_back()
	print("[paul] stage %s -> %s (rage %.0f)" % [PaulRage.STAGE_NAMES[from], PaulRage.STAGE_NAMES[to], rage.value])


func _tick_growth(delta: float) -> void:
	if _grow_t <= 0.0:
		return
	_grow_t = maxf(0.0, _grow_t - delta)
	var k: float = 1.0 - _grow_t / maxf(0.01, float(bcfg.get("grow_seconds", 1.2)))
	_apply_scale(lerpf(_grow_from, _grow_to, k))


func _think(delta: float) -> void:
	if target == null:
		stand(delta, false)
		return
	# T-232: "protect my guys". At BERSERK a downed player in his sight pulls him to the body.
	if stage() == PaulRage.BERSERK and cd_ready("guard"):
		var body: Player = _downed_to_guard()
		if body != null:
			_start_guard(body)
			return
	# the arena: never into the Core Vault (he waits in G, roaring)
	if _in_vault(target.global_position):
		var wait: Vector3 = _v(_arena.get("wait_point", [0, 0, 0]))
		if global_position.distance_to(wait) > 2.0:
			walk_to(wait, delta)
		else:
			stand(delta)
			if _taunt_cd <= 0.0:
				_taunt_cd = 6.0
				sfx("paul_roar", 0.0, 0.85)
				say("PAU_CALM_01")
		return
	# down the lift shaft when the target is in the depths and he is on the surface (or back up)
	if _wants_shaft(target.global_position):
		_go_shaft(delta)
		return
	var dist: float = dist_to(target)
	# the taunt: Calm, unhurt for 4 s, at most every 20 s
	if stage() == PaulRage.CALM and _quiet_t >= 4.0 and _taunt_cd <= 0.0 and dist > 5.0:
		_start("taunt")
		return
	var pick: String = _pick_move(dist)
	if pick != "":
		_start(pick)
		return
	walk_to(target.global_position, delta)


# ================================================================== T-232: the guard ("protect my guys")

## The downed player he goes to stand over: the nearest one down (not bled out) within `search` m in his sight.
func _downed_to_guard() -> Player:
	var g: Dictionary = bcfg.get("guard", {})
	var best: Player = null
	var bd: float = float(g.get("search", 30.0))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.downed or p.spectating:
			continue
		var d: float = dist_to(p)
		if d < bd and has_los(p, 2.2, 0.4):
			bd = d
			best = p
	return best


func _start_guard(body: Player) -> void:
	guard_pid = body.player_id
	guard_t = 0.0
	_guard_cd = 0.6
	_guard_tele = -1.0
	_guard_posed = false
	guards_done += 1
	_special_id = "guard"
	_go(B.SPECIAL, "guard")
	say("PAU_CALM_03")
	sfx("paul_roar", 0.0, 0.9)
	print("[paul] guards player %d's body (BERSERK)" % guard_pid)


func _player_by_id(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


## Standing over the body: anyone who comes within `approach` m gets the slam, a telegraph (pose + roar + light), then
## damage and a knockdown in the half-circle in FRONT of him. He faces the comer only when a slam starts, so a
## teammate can revive from the far side between slams. Not a grab: nothing chains.
func _tick_guard(delta: float) -> void:
	var g: Dictionary = bcfg.get("guard", {})
	var body: Player = _player_by_id(guard_pid)
	guard_t += delta
	if body == null or not body.downed or body.spectating or guard_t >= float(g.get("max", 12.0)):
		_end_guard("revived" if body != null and not body.downed else "done")
		return
	if dist_to(body) > 1.3 * stage_scale and _guard_tele < 0.0:
		walk_to(body.global_position, delta)
		return
	stand(delta, false)
	if not _guard_posed:
		_guard_posed = true
		pose_anim()
		_pose.set_bone("LeftUpperArm", Vector3(0.9, 0, 1.3))    # arms spread over the body
		_pose.set_bone("RightUpperArm", Vector3(0.9, 0, -1.3))
		_pose.set_bone("Spine", Vector3(0.35, 0, 0))
	if _guard_tele >= 0.0:
		_guard_tele -= delta
		if _guard_tele <= 0.0:
			_guard_tele = -1.0
			_guard_slam(g)
		return
	if _guard_cd > 0.0:
		return
	var near: Player = null
	var nd: float = float(g.get("approach", 4.5)) * stage_scale
	for p: Player in alive_players():
		var d: float = dist_to(p)
		if d < nd:
			nd = d
			near = p
	if near != null:
		_face(near.global_position)
		_guard_tele = tele_len(float(g.get("telegraph", 0.6)))
		_pose.set_bone("LeftUpperArm", Vector3(2.9, 0, 0.2))     # both fists up
		_pose.set_bone("RightUpperArm", Vector3(2.9, 0, -0.2))
		if fx != null:
			fx.tele(TELE_COLOR, 3.5, _guard_tele)
		sfx("paul_roar", -2.0, 1.05)


func _guard_slam(g: Dictionary) -> void:
	guard_slams += 1
	moves_used["guard"] = int(moves_used.get("guard", 0)) + 1
	var r: float = float(g.get("radius", 3.5)) * stage_scale
	var half: float = float(g.get("arc_deg", 180.0)) * 0.5
	for p: Player in alive_players():
		if p.player_id != guard_pid and _in_arc(p, r, half):
			hit_player(p, float(g.get("damage", 60)))
			p.apply_status(&"knockdown", 0.8)
			p.apply_knockback(_away(p) * 4.0)
	var at: Vector3 = global_position + basis_fwd() * 1.2 * stage_scale
	sfx("boss_stomp", 6.0, 0.6, at)
	sfx("boss_bone_crack", -2.0, 0.8, at)
	BossFx.burst("dust", at, get_tree(), 2.5, 1.8)
	_crack_decal(_snap_floor(at), 1.6)
	if fx != null:
		fx.shake_all(at, 0.7, 14.0)
	_guard_cd = float(g.get("cooldown", 2.5))
	_pose.set_bone("LeftUpperArm", Vector3(0.9, 0, 1.3))
	_pose.set_bone("RightUpperArm", Vector3(0.9, 0, -1.3))


func _end_guard(why: String) -> void:
	print("[paul] guard over (%s, %d slams)" % [why, guard_slams])
	guard_pid = -1
	_guard_tele = -1.0
	_pose.clear()
	set_cd("guard", float((bcfg.get("guard", {}) as Dictionary).get("again_after", 8.0)))
	_go(B.RECOVER)


func _pick_move(dist: float) -> String:
	var mv: Dictionary = bcfg.get("moves", {})
	var allowed: PackedStringArray = moves_for_stage(bcfg, stage())
	var los: bool = has_los(target, 2.4, 1.2)
	var order: Array = ["headframe_dive", "charge", "leap_slam", "thunderclap", "ground_pound", "rip_throw", "grab", "haymaker", "zombie_throw"]
	for id: String in order:
		if not allowed.has(id) or not cd_ready(id):
			continue
		var m: Dictionary = mv[id]
		var lo: float = float(m.get("min_range", 0.0))
		var hi: float = float(m.get("range", 3.0))
		match id:
			"headframe_dive":
				if _in_yard(global_position) and _in_yard(target.global_position) and not _arena.get("headframe", []).is_empty():
					return id
			"charge", "rip_throw", "thunderclap", "zombie_throw":
				if dist >= lo and dist <= hi and los:
					if id == "zombie_throw" and _nearest_horde(float(m.get("grab_radius", 6.0))) == null:
						continue
					return id
			"grab":
				if dist <= hi and can_grab(target):
					return id
			_:
				if dist >= lo and dist <= hi:
					return id
	return ""


var _tele_len: float = 0.8
var _special_id: String = ""


func _start(id: String) -> void:
	var m: Dictionary = (bcfg.get("moves", {}) as Dictionary).get(id, {})
	_tele_len = float(m.get("telegraph", 1.0)) if id != "taunt" else 3.5
	_go(B.TELEGRAPH, id)
	_hit_done = false
	pose_anim()
	if target != null:
		_face(target.global_position)
	if id != "taunt" and id != "headframe_dive" and fx != null:
		fx.tele(TELE_COLOR, 3.5, tele_len(_tele_len))   # T-232: the kit's one telegraph shape, with its rising sound
	match id:
		"haymaker":
			_pose.set_bone("RightUpperArm", Vector3(0.6, 0.0, -1.6))   # the arm drawn all the way back
			_pose.set_bone("Spine", Vector3(0.0, 0.7, 0.0))
			sfx("dog_tags" if AudioDirector.has_sound("dog_tags") else "shell_ping", -2.0, 1.3)
			sfx("boss_roar_low", -6.0, 1.2)   # the grunt
		"zombie_throw":
			var z: Zombie = _nearest_horde(float(m.get("grab_radius", 6.0)))
			if z == null:
				_go(B.MOVE)
				return
			_proj_kind = "zombie"
			_lift_zombie(z)
			_pose.set_bone("LeftUpperArm", Vector3(2.9, 0, 0.2))
			_pose.set_bone("RightUpperArm", Vector3(2.9, 0, -0.2))
			say("PAU_THROW_01")
		"grab":
			_pose.set_bone("RightUpperArm", Vector3(1.5, 0, -0.2))
			sfx("paul_roar", 0.0, 1.1)
		"ground_pound":
			_pose.set_bone("LeftUpperArm", Vector3(3.0, 0, 0.1))
			_pose.set_bone("RightUpperArm", Vector3(3.0, 0, -0.1))
			sfx("boss_breath", -2.0, 0.75)
			_steam_puff(1.0)
		"rip_throw":
			_proj_kind = "cart" if randf() < 0.6 else "rail"
			_pose.set_bone("Spine", Vector3(0.9, 0, 0))
			_pose.set_bone("LeftUpperArm", Vector3(1.2, 0, 0.2))
			_pose.set_bone("RightUpperArm", Vector3(1.2, 0, -0.2))
			sfx("metal_wrench" if AudioDirector.has_sound("metal_wrench") else "door_creak", 2.0, 0.6)
			sfx("paul_plate_grind", -4.0, 0.8)
		"leap_slam":
			_pose.set_bone("Spine", Vector3(0.5, 0, 0))
			_pose.set_bone("LeftUpperLeg", Vector3(-0.9, 0, 0))
			_pose.set_bone("RightUpperLeg", Vector3(-0.9, 0, 0))
			_leap_to = _landing_near(target.global_position)
			_show_shadow(_leap_to, 2.0)
			sfx("boss_bone_crack", -6.0, 0.8)
			sfx("boss_breath", -4.0, 0.7)
		"thunderclap":
			_pose.set_bone("LeftUpperArm", Vector3(1.4, 0, 1.4))
			_pose.set_bone("RightUpperArm", Vector3(1.4, 0, -1.4))
			sfx("boss_breath", 3.0, 0.55)   # the huge inhale
			_steam_puff(1.2)
		"charge":
			_pose.set_bone("Spine", Vector3(0.7, 0, 0))
			_pose.set_bone("Head", Vector3(0.4, 0, 0))
			sfx("boss_stomp", 2.0, 0.7)   # the knuckles paw the ground (twice: the second in _telegraph)
		"headframe_dive":
			_special_id = "climb"
			_go(B.SPECIAL, id)
			climbing = true
			_bt = 0.0
			_leap_from = global_position
			sfx("paul_roar", 4.0, 0.8)
		"taunt":
			_pose.set_bone("LeftUpperArm", Vector3(1.5, 0, 0.6))
			_pose.set_bone("RightUpperArm", Vector3(1.5, 0, -0.6))
			taunts += 1
			_taunt_cd = float((bcfg.get("taunt", {}) as Dictionary).get("every", 20.0))


## T-232: the kit's tele() drives the light with its own shape during a telegraph (and the climb's perch); the base
## eases toward this each frame, so returning the light's own energy leaves the shape alone.
func _tele_glow() -> float:
	if bstate == B.TELEGRAPH or (bstate == B.SPECIAL and (_special_id == "climb" or _guard_tele >= 0.0)):
		return _tele_light.light_energy
	return 0.0


func _telegraph(delta: float) -> void:
	stand(delta, move_id != "leap_slam")
	if move_id == "zombie_throw" and _proj != null:
		_proj.global_position = global_position + Vector3.UP * (2.6 * stage_scale * float(bcfg.get("height", 1.38)) / 1.38)
	if move_id == "charge" and _bt >= 0.45 and _bt - delta < 0.45:
		sfx("boss_stomp", 2.0, 0.75)
	if move_id == "taunt":
		# the chest beat, then the tin-cup look (the meter dips 5)
		if _bt > 1.4 and _bt - delta <= 1.4:
			_pose.set_bone("LeftUpperArm", Vector3(0.9, 0, 0.3))
			_pose.set_bone("RightUpperArm", Vector3(0.2, 0, 0))
			_pose.set_bone("Head", Vector3(0.5, 0, 0))
			rage.on_cup()
			say("PAU_CUP_01")
		elif _bt < 1.4 and fmod(_bt, 0.35) < delta:
			sfx("boss_stomp", -10.0, 1.4)   # the chest beat
			sfx("dog_tags" if AudioDirector.has_sound("dog_tags") else "shell_ping", -8.0, 1.2)
		if _bt >= _tele_len:
			_pose.clear()
			_go(B.RECOVER)
		return
	if _bt >= tele_len(_tele_len):
		_go(B.ACTIVE, move_id)
		_on_active_start()


func _on_active_start() -> void:
	var m: Dictionary = (bcfg.get("moves", {}) as Dictionary).get(move_id, {})
	set_cd(move_id, float(m.get("cooldown", 5.0)))
	match move_id:
		"haymaker":
			attack_anim("swipe_r", 0.15)
			sfx("boss_roar_low", -3.0, 1.1)
			for p: Player in alive_players():
				if _in_arc(p, float(m.get("range", 2.8)) * stage_scale, 70.0):
					hit_player(p, float(m["damage"]))
					p.apply_knockback(_away(p) * float(m.get("knockback", 6.0)))
					sfx("boss_bone_crack", -4.0, 0.9, p.global_position + Vector3.UP)
		"zombie_throw":
			_throw_proj(target.global_position if target != null else global_position - basis_fwd() * 10.0, float(m.get("speed", 14.0)), false)
			throws_done += 1
		"grab":
			attack_anim("grab", 0.15)
			if target != null and dist_to(target) <= float(m.get("range", 2.5)) * stage_scale and can_grab(target):
				var need: Dictionary = {"mash": int(m.get("mash", 8)), "team": max_hp * float(m.get("team_fraction", 0.06)),
					"max": float(m.get("max", 5.0))}
				if bool(squad_state.get("alone", false)):
					# T-232: a lone player's grab is shorter and breaks sooner (fair in solo; the pressure is elsewhere)
					var sq: Dictionary = bcfg.get("squad", {})
					need["max"] = float(sq.get("alone_grab_max", 3.5))
					need["mash"] = int(sq.get("alone_grab_mash", 6))
				var g: Dictionary = grab_start(target, "squeeze", need, _bottle_limbs())
				g["weak_need"] = 1.0   # breaking a bottle frees the held player
				_held_lift = g
				grabs_done += 1
				say("PAU_GRAB_01")
		"ground_pound":
			sfx("explosion_small" if AudioDirector.has_sound("explosion_small") else "boss_stomp", 4.0, 0.6)
			sfx("boss_stomp", 6.0, 0.65)
			var fists: Vector3 = global_position + basis_fwd() * 1.4 * stage_scale
			BossFx.burst("dust", fists, get_tree(), 3.0, 2.0)
			_crack_decal(_snap_floor(fists), 1.8)
			if fx != null:
				fx.shake_all(global_position, 0.8, 16.0)
			_ring_r = 0.0
			_ring_hit.clear()
		"rip_throw":
			_throw_proj(target.global_position if target != null else global_position, 0.0, true)
			say("PAU_THROW_01")
			throws_done += 1
		"leap_slam":
			_special_id = "leap"
			_leap_from = global_position
			_go(B.SPECIAL, move_id)
		"thunderclap":
			_thunderclap(m)
		"charge":
			_special_id = "charge"
			_charge_dir = basis_fwd()
			_charge_run = 0.0
			_charge_hit.clear()
			_go(B.SPECIAL, move_id)


func _active(delta: float) -> void:
	stand(delta, false)
	var hold: float = 0.45
	if move_id == "grab" and not _held_lift.is_empty() and grabs().has(_held_lift):
		hold = 99.0
	if _bt >= hold:
		_pose.clear()
		_go(B.RECOVER)


## Grab & Squeeze: the held player is lifted in one fist in front of his face, 25 / s, up to 5 s.
func _tick_lift(delta: float) -> void:
	if _held_lift.is_empty():
		return
	if not grabs().has(_held_lift):
		_held_lift = {}
		return
	var p: Player = _held_lift["p"]
	if p == null or not is_instance_valid(p):
		return
	var m: Dictionary = (bcfg.get("moves", {}) as Dictionary).get("grab", {})
	var hand: Vector3 = global_position + basis_fwd() * (0.9 * stage_scale) + Vector3.UP * (float(m.get("lift", 1.6)) * stage_scale)
	if p.is_local or p.is_bot:
		p.global_position = hand
		p.velocity = Vector3.ZERO
	hit_player(p, float(m.get("damage", 25.0)) * delta)
	if fmod(float(_held_lift["t"]), 1.2) < delta:
		sfx("boss_roar_low", -4.0, 1.05)   # he roars in your face
		_steam_puff(0.4)
	if fx != null and p.is_local and not p.is_bot:
		fx.extra_dread = 1.0


func _on_grab_released(g: Dictionary, reason: String) -> void:
	if g == _held_lift:
		_held_lift = {}
	var p: Player = g["p"]
	if p != null and is_instance_valid(p) and (p.is_local or p.is_bot):
		p.global_position = _snap_floor(global_position + basis_fwd() * 1.8 * stage_scale)
	print("[paul] grab released (%s)" % reason)
	if bstate == B.ACTIVE and move_id == "grab":
		_pose.clear()
		_go(B.RECOVER)


func _bottle_limbs() -> Array:
	var out: Array = []
	for i: int in bottles_hp.size():
		out.append(StringName("bottle%d" % (i + 1)))
	return out


func _special(delta: float) -> void:
	match _special_id:
		"arrive":
			var ka: float = clampf(_bt / _arrive_s, 0.0, 1.0)
			global_position = _leap_from.lerp(_leap_to, ka) + Vector3.UP * sin(ka * PI) * 3.0
			velocity = Vector3.ZERO
			if ka >= 1.0:
				global_position = _leap_to
				_hide_shadow()
				_pose.clear()
				sfx("paul_roar", 4.0, 0.9)
				BossFx.burst("dust", _leap_to, get_tree(), 4.0, 2.6)
				_steam_puff(1.5)
				if event != null and event.has_method("on_arrived"):
					event.call("on_arrived", _leap_to)
				_go(B.ARRIVE)
		"leap":
			var dur: float = float((bcfg["moves"]["leap_slam"] as Dictionary).get("flight", 0.9))
			var k: float = clampf(_bt / dur, 0.0, 1.0)
			global_position = _leap_from.lerp(_leap_to, k) + Vector3.UP * sin(k * PI) * 6.0
			velocity = Vector3.ZERO
			if k >= 1.0:
				_land(_leap_to, bcfg["moves"]["leap_slam"])
				_go(B.RECOVER)
		"charge":
			var m: Dictionary = bcfg["moves"]["charge"]
			var step: Vector3 = _charge_dir * float(m.get("speed", 11.0)) * squad_speed_mult * delta
			var col: KinematicCollision3D = move_and_collide(step)
			_charge_run += step.length()
			_smash_doors()
			for p: Player in alive_players():
				if not _charge_hit.has(p.player_id) and p.global_position.distance_to(global_position) < 1.6 * stage_scale:
					_charge_hit[p.player_id] = true
					hit_player(p, float(m["damage"]))
					p.apply_knockback((_charge_dir + Vector3.UP * 0.2) * float(m.get("knockback", 9.0)))
			if col != null and absf(col.get_normal().y) < 0.5 and not (col.get_collider() is Player) and not (col.get_collider() is Zombie):
				# a solid wall: stunned 2 s, a x1.5 window
				stun_t = float((bcfg.get("wall_stun", {}) as Dictionary).get("seconds", 2.0))
				wall_stuns += 1
				_pose.set_bone("Head", Vector3(-0.4, 0, 0))
				sfx("boss_stomp", 6.0, 0.5)
				sfx("boss_bone_crack", 0.0, 0.7)
				BossFx.burst("chips", col.get_position(), get_tree(), 2.0, 1.4)
				BossFx.burst("dust", col.get_position(), get_tree(), 2.0, 1.6)
				if fx != null:
					fx.shake_all(global_position, 0.6, 12.0)
				print("[paul] charge into a wall: stunned")
				_go(B.RECOVER)
				return
			if _charge_run >= float(m.get("distance", 20.0)):
				_pose.clear()
				_go(B.RECOVER)
		"climb":
			_tick_headframe(delta)
		"guard":
			_tick_guard(delta)
		"shaft":
			var k2: float = clampf(_shaft_t / 1.3, 0.0, 1.0)
			_shaft_t += delta
			global_position = _shaft_from.lerp(_shaft_to, k2 * k2)
			velocity = Vector3.ZERO
			if k2 >= 1.0:
				in_shaft = false
				_land(_shaft_to, {"damage_in": 0, "damage_out": 0, "r_in": 0.0, "r_out": 0.0})
				_crater(_shaft_to)
				_go(B.RECOVER)
		_:
			_go(B.MOVE)


## The Headframe Climb & Dive: 3 s up the steel like a gorilla, a perch, his shadow under the target for 1.2 s
## (following for 0.6 s, then locked), then the dive.
func _tick_headframe(_delta: float) -> void:
	var m: Dictionary = bcfg["moves"]["headframe_dive"]
	var hf: Vector3 = _v(_arena.get("headframe", [0, 0, 0]))
	var top: Vector3 = hf + Vector3.UP * float(_arena.get("headframe_height", 20.0))
	var climb_s: float = float(m.get("climb", 3.0))
	var tele: float = float(m.get("telegraph", 1.2))
	var follow: float = float(m.get("follow", 0.6))
	velocity = Vector3.ZERO
	if _bt < climb_s:
		global_position = _leap_from.lerp(top, _bt / climb_s)
		_pose.set_bone("LeftUpperArm", Vector3(2.8, 0, 0.3) if fmod(_bt, 0.6) < 0.3 else Vector3(2.2, 0, 0.3))
		_pose.set_bone("RightUpperArm", Vector3(2.2, 0, -0.3) if fmod(_bt, 0.6) < 0.3 else Vector3(2.8, 0, -0.3))
		return
	if _bt < climb_s + tele:
		global_position = top
		if _bt < climb_s + follow and target != null:
			dive_target = _landing_near(target.global_position)
		_show_shadow(dive_target, 3.0)
		_tele_light.light_energy = 3.0
		return
	var k: float = clampf((_bt - climb_s - tele) / 0.5, 0.0, 1.0)
	global_position = top.lerp(dive_target, k * k)
	if k >= 1.0:
		climbing = false
		_land(dive_target, m)
		_crater(dive_target)
		_pose.clear()
		_go(B.RECOVER)


## A landing: inner and outer damage rings, knockdown, the crater shake.
func _land(at: Vector3, m: Dictionary) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_hide_shadow()
	sfx("explosion_small" if AudioDirector.has_sound("explosion_small") else "boss_stomp", 6.0, 0.55)
	sfx("boss_stomp", 8.0, 0.6)
	BossFx.burst("dust", at, get_tree(), 4.0, 2.6)
	BossFx.burst("chips", at + Vector3.UP * 0.2, get_tree(), 1.5, 1.5)
	_crack_decal(at, 2.2)
	_steam_puff(1.0)
	if fx != null:
		fx.shake_all(at, 1.0, 22.0)
	for p: Player in alive_players():
		var d: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d <= float(m.get("r_in", 3.0)):
			hit_player(p, float(m.get("damage_in", m.get("damage", 100))))
			p.apply_status(&"knockdown", 0.8)
		elif d <= float(m.get("r_out", 6.0)):
			hit_player(p, float(m.get("damage_out", 50)))
			p.apply_status(&"knockdown", 0.8)


## The Thunderclap: a 60 deg cone 14 m long; 40 + knockback 6 m; every board torn off the barricades in the cone.
func _thunderclap(m: Dictionary) -> void:
	sfx("paul_roar", 6.0, 0.9)
	sfx("boss_roar_low", 4.0, 0.7)
	_steam_puff(1.2)
	BossFx.burst("steam", global_position + Vector3.UP * 1.8 * stage_scale + basis_fwd() * 1.0, get_tree(), 3.0, 2.0)
	if fx != null:
		fx.shake_all(global_position, 0.7, 16.0)
	var half: float = float(m.get("cone_deg", 60.0)) * 0.5
	var length: float = float(m.get("length", 14.0))
	for p: Player in alive_players():
		if _in_cone(p.global_position, length, half):
			hit_player(p, float(m["damage"]))
			p.apply_knockback(_away(p) * float(m.get("knockback", 6.0)))
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Node3D = n as Node3D
		if b != null and _in_cone(b.global_position, length, half):
			var torn: int = 0
			if b.has_method("strip_all"):
				torn = int(b.call("strip_all"))
			elif b.has_method("tear_board"):
				for i: int in 8:
					if b.call("tear_board"):
						torn += 1
			boards_stripped += torn


## Charge: an unbought door he crashes through opens for free and stays open.
func _smash_doors() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open:
			continue
		var dp: Vector3 = d.global_position
		if Vector2(dp.x - global_position.x, dp.z - global_position.z).length() < 2.2 * maxf(1.0, stage_scale) and absf(dp.y - global_position.y) < 3.0:
			d.open(0)
			doors_smashed.append(d.door_id)
			sfx("door_open", 6.0, 0.6)
			print("[paul] charged door %s open" % d.door_id)


## Dev / smoke: start a move now against the nearest player (its cooldown is ignored).
func debug_move(id: String) -> void:
	target = _nearest_player()
	_cds.erase(id)
	_start(id)


## Dev / smoke: run the Charge straight at `at` (doors on the line open).
func debug_charge_at(at: Vector3) -> void:
	_face(at)
	rage.set_value(maxf(rage.value, 70.0))
	_on_stage_changed(PaulRage.CALM, rage.stage) if stage_scale < 1.29 else null
	_special_id = "charge"
	var d: Vector3 = at - global_position
	d.y = 0.0
	_charge_dir = d.normalized()
	_charge_run = 0.0
	_charge_hit.clear()
	move_id = "charge"
	set_cd("charge", 12.0)
	_go(B.SPECIAL, "charge")


# ================================================================== projectiles and the ring

func _nearest_horde(radius: float) -> Zombie:
	if director == null:
		return null
	var best: Zombie = null
	var bd: float = radius
	for z: Zombie in (director as ZombieDirector).active_zombies():
		if z is HomageBoss or not z.is_active():
			continue
		var d: float = z.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = z
	return best


## The zombie he picks up: it dies in his hands (counted as a kill for nobody) and a body proxy flies.
func _lift_zombie(z: Zombie) -> void:
	z.take_damage(z.hp + 1.0, &"torso", &"paul", 0, &"world")
	_make_proj("zombie")


func _make_proj(kind: String) -> void:
	if _proj != null and is_instance_valid(_proj):
		_proj.queue_free()
	_proj = Node3D.new()
	_proj.name = "PaulThrow"
	get_parent().add_child(_proj)
	var mi: MeshInstance3D = MeshInstance3D.new()
	match kind:
		"cart":
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(1.0, 0.8, 1.5)
			mi.mesh = bm
			mi.material_override = mat(Color(0.3, 0.26, 0.22))
		"rail":
			var bm2: BoxMesh = BoxMesh.new()
			bm2.size = Vector3(0.6, 0.2, 4.0)
			mi.mesh = bm2
			mi.material_override = mat(Color(0.35, 0.3, 0.28))
		_:
			var cm: CapsuleMesh = CapsuleMesh.new()
			cm.radius = 0.3
			cm.height = 1.7
			mi.mesh = cm
			mi.rotation.x = PI * 0.5
			mi.material_override = mat(Color(0.4, 0.42, 0.38))
	_proj.add_child(mi)
	_proj.global_position = global_position + Vector3.UP * 2.6 * stage_scale


## Throws: a bowled zombie along the ground (speed m/s) or a ripped cart / rail in an arc with a landing shadow.
func _throw_proj(to: Vector3, spd: float, arc: bool) -> void:
	if _proj == null or not is_instance_valid(_proj):
		_make_proj(_proj_kind)
	_proj_from = _proj.global_position
	_proj_to = _snap_floor(to)
	_proj_t = 0.0
	var d: float = _proj_from.distance_to(_proj_to)
	_proj_dur = clampf(d / maxf(1.0, spd), 0.3, 2.5) if not arc else float((bcfg["moves"]["rip_throw"] as Dictionary).get("flight", 1.3))
	_proj_kind = ("arc_" if arc else "roll_") + _proj_kind
	if arc:
		_show_shadow(_proj_to, 2.5)


func _tick_projectile(delta: float) -> void:
	if _proj == null or not is_instance_valid(_proj) or _proj_kind == "" or bstate == B.TELEGRAPH:
		return
	if _proj_t >= _proj_dur and _proj_dur > 0.0:
		return
	if _proj_dur <= 0.0:
		return
	_proj_t += delta
	var k: float = clampf(_proj_t / _proj_dur, 0.0, 1.0)
	var arc: bool = _proj_kind.begins_with("arc_")
	var pos: Vector3 = _proj_from.lerp(_proj_to, k)
	if arc:
		pos.y += sin(k * PI) * 7.0
	else:
		pos.y = lerpf(_proj_from.y, _proj_to.y + 0.4, minf(1.0, k * 4.0))
	_proj.global_position = pos
	_proj.rotate_y(delta * 6.0)
	if not arc:
		# a bowled zombie hits the first player in its path for 60
		var m: Dictionary = bcfg["moves"]["zombie_throw"]
		for p: Player in alive_players():
			if p.global_position.distance_to(pos) < 1.1:
				hit_player(p, float(m["damage"]))
				k = 1.0
				_proj_t = _proj_dur
				break
	if k >= 1.0:
		_proj_impact(arc)


func _proj_impact(arc: bool) -> void:
	var at: Vector3 = _proj.global_position
	_hide_shadow()
	if arc:
		var m: Dictionary = bcfg["moves"]["rip_throw"]
		sfx("explosion_small" if AudioDirector.has_sound("explosion_small") else "boss_stomp", 6.0, 0.5, at)
		sfx("boss_stomp", 6.0, 0.55, at)
		BossFx.burst("dust", at, get_tree(), 3.5, 2.4)
		BossFx.burst("chips", at + Vector3.UP * 0.3, get_tree(), 1.5, 1.4)
		_crack_decal(at, 2.0)
		if fx != null:
			fx.shake_all(at, 0.8, 16.0)
		for p: Player in alive_players():
			if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= float(m.get("radius", 2.5)):
				hit_player(p, float(m["damage"]))
				p.apply_status(&"knockdown", 0.8)
	else:
		# it explodes into shards at the end of its run
		var m2: Dictionary = bcfg["moves"]["zombie_throw"]
		sfx("boss_bone_crack", 4.0, 0.8, at)
		BossFx.burst("mist", at + Vector3.UP * 0.5, get_tree(), 2.5, 1.6)
		for p: Player in alive_players():
			if p.global_position.distance_to(at) <= float(m2.get("shard_radius", 2.0)):
				hit_player(p, float(m2.get("shard_damage", 30.0)))
	var gone: Node3D = _proj
	_proj = null
	_proj_kind = ""
	_proj_dur = 0.0
	get_tree().create_timer(1.5).timeout.connect(gone.queue_free)


## The Ground Pound's ring shockwave: expands to 8 m at 10 m/s; a player on the ground when it passes is hit
## (50 + knockdown); a jumping player clears it.
func _tick_ring(delta: float) -> void:
	if _ring_r < 0.0:
		return
	var m: Dictionary = bcfg["moves"]["ground_pound"]
	_ring_r += float(m.get("ring_speed", 10.0)) * delta
	for p: Player in alive_players():
		if _ring_hit.has(p.player_id):
			continue
		var d: float = Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if absf(d - _ring_r) <= float(m.get("ring_band", 0.8)):
			_ring_hit[p.player_id] = true
			if p.is_on_floor():
				hit_player(p, float(m["damage"]))
				p.apply_status(&"knockdown", 0.8)
	if _ring_r >= float(m.get("ring_radius", 8.0)):
		_ring_r = -1.0


# ================================================================== the arena

func _in_vault(p: Vector3) -> bool:
	var v: Array = _arena.get("vault_box", [])
	return v.size() == 6 and p.x >= float(v[0]) and p.x <= float(v[3]) and p.y >= float(v[1]) and p.y <= float(v[4]) and p.z >= float(v[2]) and p.z <= float(v[5])


func _in_yard(p: Vector3) -> bool:
	var hf: Array = _arena.get("headframe", [])
	if hf.size() < 3:
		return false
	return Vector2(p.x - float(hf[0]), p.z - float(hf[2])).length() <= float(_arena.get("yard_radius", 22.0)) and absf(p.y - float(hf[1])) < 4.0


## True when the target is down in the depths and he is up top (or the other way round) and the lift shaft is the
## way: he drops the 40 m into F's lift mouth with the crater (or leaps back up it).
func _wants_shaft(p: Vector3) -> bool:
	var top: Array = _arena.get("lift_top", [])
	var bottom: Array = _arena.get("lift_bottom", [])
	if top.size() < 3 or bottom.size() < 3:
		return false
	var depth_y: float = (float(top[1]) + float(bottom[1])) * 0.5
	return (global_position.y > depth_y) != (p.y > depth_y)


func _go_shaft(delta: float) -> void:
	var top: Vector3 = _v(_arena["lift_top"])
	var bottom: Vector3 = _v(_arena["lift_bottom"])
	var down: bool = global_position.y > (top.y + bottom.y) * 0.5
	var mouth: Vector3 = top if down else bottom
	if Vector2(global_position.x - mouth.x, global_position.z - mouth.z).length() > 2.5:
		walk_to(mouth, delta)
		return
	in_shaft = true
	_shaft_from = global_position
	_shaft_to = bottom if down else top
	_shaft_t = 0.0
	_special_id = "shaft"
	_go(B.SPECIAL, "shaft")
	sfx("paul_roar", 4.0, 0.8)
	print("[paul] %s the lift shaft" % ("down" if down else "up"))


func _crater(at: Vector3) -> void:
	if event != null and event.has_method("crater"):
		event.call("crater", at, false)


func _landing_near(p: Vector3) -> Vector3:
	return _snap_floor(p)


func _snap_floor(p: Vector3) -> Vector3:
	var w: World3D = get_world_3d()
	if w == null:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(w.navigation_map, p)
	return c if c != Vector3.ZERO and c.distance_to(p) < 6.0 else p


func _show_shadow(at: Vector3, r: float) -> void:
	if _shadow == null or not is_instance_valid(_shadow):
		_shadow = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		_shadow.mesh = cm
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.albedo_color = Color(0, 0, 0, 0.55)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow.material_override = sm
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(_shadow)
	_shadow.show()
	_shadow.global_position = at + Vector3.UP * 0.04
	_shadow.scale = Vector3(r, 1.0, r)


func _hide_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.hide()


## T-232: the kit's footfall (HomageBoss._footstep: dust, boss_stomp, the view shake by stage) plus, at BERSERK, the
## ground cracking under each step: a dark decal at the foot.
func _footstep(left: bool) -> void:
	super._footstep(left)
	if stage() == PaulRage.BERSERK and is_active() and bstate != B.SPECIAL:
		var foot: Node3D = bone_attachment("LeftFoot" if left else "RightFoot")
		_crack_decal(_snap_floor(foot.global_position if foot != null else global_position), 1.1)


## A cracked-ground decal at `at`: a dark quad with four crack lines through it, fading out over 25 s (at most
## MAX_CRACKS on the ground; the oldest goes first). Cosmetic: no collision, no gameplay.
func _crack_decal(at: Vector3, size: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	while _cracks.size() >= MAX_CRACKS:
		var old: Node3D = _cracks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var root: Node3D = Node3D.new()
	root.name = "PaulCrack"
	root.top_level = true
	host.add_child(root)
	root.global_position = at + Vector3.UP * 0.025
	root.rotation.y = randf() * TAU
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.045, 0.04, 0.62)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(size, size * randf_range(0.7, 0.95))
	q.mesh = qm
	q.rotation.x = -PI * 0.5
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	for i: int in 4:
		var c: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.04, 0.004, size * randf_range(0.7, 1.3))
		c.mesh = bm
		c.material_override = m
		c.rotation.y = TAU * float(i) / 4.0 + randf_range(-0.4, 0.4)
		c.position = Vector3(0, 0.003, 0)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(c)
	_cracks.append(root)
	var tw: Tween = root.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 17.0)
	tw.tween_callback(func() -> void:
		_cracks.erase(root)
		root.queue_free())


# ================================================================== geometry helpers

func basis_fwd() -> Vector3:
	var f: Vector3 = -_pivot.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-6 else Vector3(0, 0, -1)


func _away(p: Node3D) -> Vector3:
	var d: Vector3 = p.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 1e-6 else basis_fwd()


func _in_arc(p: Node3D, r: float, half_deg: float) -> bool:
	var d: Vector3 = p.global_position - global_position
	d.y = 0.0
	return d.length() <= r and rad_to_deg(absf(basis_fwd().angle_to(d.normalized()))) <= half_deg


func _in_cone(at: Vector3, length: float, half_deg: float) -> bool:
	var d: Vector3 = at - global_position
	d.y = 0.0
	return d.length() <= length and d.length() > 0.01 and rad_to_deg(absf(basis_fwd().angle_to(d.normalized()))) <= half_deg


func _v(a: Variant) -> Vector3:
	var arr: Array = a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2])) if arr != null and arr.size() >= 3 else Vector3.ZERO


# ================================================================== damage

func limb_mult(limb: StringName) -> float:
	var base: float = super.limb_mult(limb)
	if limb == &"neck" and _hit_from != Vector3.INF:
		var nb: Dictionary = bcfg.get("neck_back", {})
		base *= neck_mult(limb, basis_fwd(), _hit_from - global_position, float(nb.get("angle_deg", 120.0)), float(nb.get("mult", 2.0)))
	return base


func damage_taken_mult() -> float:
	if knee_t > 0.0:
		return float((bcfg.get("stagger", {}) as Dictionary).get("mult", 1.5))
	if stun_t > 0.0:
		return float((bcfg.get("wall_stun", {}) as Dictionary).get("mult", 1.5))
	return 1.0


func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if puppet:
		return super.take_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	if not is_active() or retreating:
		return false
	var ls: String = String(limb)
	if ls.begins_with("bottle"):
		return _hit_bottle(int(ls.trim_prefix("bottle")) - 1, amount, by_player)
	_hit_from = _attacker_pos(by_player)
	var r: bool = super.take_damage(amount, limb, weapon_id, by_player, kind, armor_piercing)
	_hit_from = Vector3.INF
	return r


func _attacker_pos(pid: int) -> Vector3:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p.global_position
	return Vector3.INF


func _on_damaged(amount: float, _limb: StringName, _by_player: int, kind: StringName) -> void:
	super._on_damaged(amount, _limb, _by_player, kind)
	_quiet_t = 0.0
	var before: int = rage.stage
	rage.on_damage(amount, max_hp)
	if rage.stage != before:
		_on_stage_changed(before, rage.stage)
	if knee_t <= 0.0 and staggers(amount, max_hp, kind, float((bcfg.get("stagger", {}) as Dictionary).get("blast_fraction", 0.03))):
		_knee_down()


func _knee_down() -> void:
	knee_t = float((bcfg.get("stagger", {}) as Dictionary).get("seconds", 2.5))
	staggers_taken += 1
	_release_all_grabs("stagger")
	_charge_run = 1e9
	pose_anim()
	_pose.set_bone("LeftUpperLeg", Vector3(-1.3, 0, 0))
	_pose.set_bone("LeftLowerLeg", Vector3(1.4, 0, 0))
	_pose.set_bone("Spine", Vector3(0.4, 0, 0))
	say("PAU_KNEE_01")
	sfx("boss_bone_crack", 0.0, 0.75)
	sfx("boss_stomp", 2.0, 0.7)
	BossFx.burst("dust", global_position + basis_fwd() * 0.5, get_tree(), 2.0, 1.6)
	_steam_puff(1.5)
	print("[paul] knee-down stagger (x1.5 for %.1f s)" % knee_t)


## A shot bottle: its own HP; broken, it cools him 20 with a stout splash and frees anyone he holds.
func _hit_bottle(i: int, amount: float, by_player: int) -> bool:
	if i < 0 or i >= bottles_hp.size() or bottles_hp[i] <= 0.0:
		return false
	bottles_hp[i] -= amount
	GLBus.enemy_damaged.emit(enemy_id, StringName("bottle%d" % (i + 1)), amount, by_player)
	var at: Vector3 = bottle_nodes[i].global_position if i < bottle_nodes.size() else global_position + Vector3.UP * 1.6
	AudioDirector.play_3d("boss_hit_glass", at, -2.0, 0.05)
	BossFx.burst("motes", at, get_tree(), 0.4, 0.6)
	if bottles_hp[i] > 0.0:
		return false
	break_bottle(i)
	return false


func break_bottle(i: int) -> void:
	if i < 0 or i >= bottles_hp.size():
		return
	bottles_hp[i] = 0.0
	bottles_broken += 1
	if i < bottle_nodes.size():
		bottle_nodes[i].hide()
	if i < bottle_boxes.size():
		bottle_boxes[i].collision_layer = 0
	var before: int = rage.stage
	rage.on_bottle()
	if rage.stage != before:
		_on_stage_changed(before, rage.stage)
	var at: Vector3 = bottle_nodes[i].global_position if i < bottle_nodes.size() else global_position + Vector3.UP * 1.6
	sfx("paul_bottle_break", 2.0, 1.0, at)
	BossFx.burst("drips", at, get_tree(), 3.0, 1.6)   # the stout splash
	BossFx.burst("motes", at, get_tree(), 1.2, 1.0)
	_update_bottle_glow()
	_steam_puff(0.8)
	if fx != null:
		fx.tele(VIOLET, 2.5, 0.35, false)
	say("PAU_BOTTLE_01" if bottles_broken % 2 == 1 else "PAU_BOTTLE_02")
	for g: Dictionary in grabs().duplicate():
		grab_release(g, "bottle")
	if event != null and event.has_method("on_bottle_broken"):
		event.call("on_bottle_broken", bottles_broken)
	print("[paul] bottle %d broken (rage %.0f, %d left)" % [i + 1, rage.value, bottles_left()])


## No flinch from small hits (the big blast stagger is the knee-down).
func _play_flinch(_limb: StringName, _side: String) -> void:
	pass


## Dev: rage N (the stage that goes with it).
func set_rage(v: float) -> void:
	var before: int = rage.stage
	rage.set_value(v)
	if rage.stage != before:
		_on_stage_changed(before, rage.stage)


## T-232: the squad's state the brain read last (the smoke / tests): {"alone", "hurt", "downed"}.
func squad_read() -> Dictionary:
	return squad_state


## T-232: a lone player feels the pressure: Haymaker and Zombie Throw come back sooner.
func set_cd(id: String, seconds: float) -> void:
	super.set_cd(id, seconds)
	if bool(squad_state.get("alone", false)) and (id == "haymaker" or id == "zombie_throw"):
		_cds[id] = float(_cds[id]) * float((bcfg.get("squad", {}) as Dictionary).get("alone_cd_mult", 0.8))


## Dev / capture (T-232): stands him still at the stage that goes with `rage_v`, facing `yaw` degrees, the growth
## applied at once; the brain is off so a camera can frame him.
func debug_pose(yaw_deg: float, rage_v: float = 0.0) -> void:
	set_rage(rage_v)
	_grow_t = 0.0
	_apply_scale(_grow_to if rage_v > 0.0 else 1.0)
	rotation.y = deg_to_rad(yaw_deg)
	_pivot.rotation = Vector3.ZERO
	pose_anim()
	_pose.set_bone("LeftUpperArm", Vector3(0.35, 0, 0.35))
	_pose.set_bone("RightUpperArm", Vector3(0.35, 0, -0.35))
	_pose.set_bone("Spine", Vector3(0.12, 0, 0))
	if stage() == PaulRage.BERSERK and _steam != null:
		_steam.emitting = true
	set_physics_process(false)


# ================================================================== retreat (the fail-safe) and death

func _on_retreat() -> void:
	say("PAU_LEAVE_01")
	_hide_shadow()
	_bt = 0.0
	guard_pid = -1
	_floods_back(3.0)
	if _drips != null:
		_drips.emitting = false


## He roars, climbs the headframe and leaps away north.
func _tick_retreat(delta: float) -> void:
	velocity = Vector3.ZERO
	var hf: Vector3 = _v(_arena.get("headframe", [global_position.x, global_position.y, global_position.z]))
	var top: Vector3 = hf + Vector3.UP * float(_arena.get("headframe_height", 20.0))
	if _bt < 1.0:
		_halt(delta)
		if not _retreat_roared and _bt > 0.3:
			_retreat_roared = true
			sfx("paul_roar", 4.0, 0.85)
		return
	if _bt < 3.5:
		global_position = global_position.lerp(top, clampf(delta * 1.6, 0.0, 1.0))
		return
	global_position += (Vector3(0, 0.6, -1.0).normalized() * 18.0) * delta
	if _bt >= 6.0:
		_vanish()


func _start_authored_death() -> void:
	_death_phase = 0
	_death_from_tint = IRON_RED
	_hide_shadow()
	_ring_r = -1.0
	if _proj != null and is_instance_valid(_proj):
		_proj.queue_free()
		_proj = null
	_tree_play("Spawn", "idle", 1.0)   # (not pose_anim: that would put the state back to ATTACK)
	_pose.clear()
	_pose.set_bone("LeftUpperLeg", Vector3(-1.4, 0, 0))
	_pose.set_bone("RightUpperLeg", Vector3(-1.4, 0, 0))
	_pose.set_bone("LeftLowerLeg", Vector3(1.6, 0, 0))
	_pose.set_bone("RightLowerLeg", Vector3(1.6, 0, 0))
	if _steam != null:
		_steam.restart()
		_steam.emitting = true
	guard_pid = -1
	_floods_back(6.0)   # the yard's light comes back as the rage drains out of him
	sfx("boss_breath", 0.0, 0.6)
	sfx("boss_stomp", 2.0, 0.6)
	BossFx.burst("dust", global_position, get_tree(), 2.0, 1.8)
	print("[paul] to his knees: the rage drains")


## The death sequence (section 5.6): knees (0-2 s, the rage drains, the shrink, the red fades), the look and the
## last line (2-5.5 s), the cup (5.5-8 s), the slow fall forward like a tree (8-11 s).
func _death_tick(delta: float) -> void:
	var t: float = _death_t
	var k: float = clampf(t / 2.0, 0.0, 1.0)
	rage.value = lerpf(rage.value, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	_apply_scale(lerpf(stage_scale, 0.92, clampf(delta * 1.5, 0.0, 1.0)))
	_set_inst("inst_tint", _death_from_tint.lerp(HUMAN_TINT, k))
	if _glow != null:
		_glow.light_energy = lerpf(_glow.light_energy, 0.0, clampf(delta * 2.0, 0.0, 1.0))
	if _eyes != null:
		_eyes.energy = lerpf(_eyes.energy, 0.5, clampf(delta * 1.0, 0.0, 1.0))
		_eyes.color = _eyes.color.lerp(EYE_AMBER, clampf(delta * 1.5, 0.0, 1.0))
	if _rack_light != null:
		_rack_light.light_energy = lerpf(_rack_light.light_energy, 0.0, clampf(delta * 1.2, 0.0, 1.0))
	if t >= 2.0 and _death_phase == 0:
		_death_phase = 1
		if _steam != null:
			_steam.emitting = false
		if _drips != null:
			_drips.emitting = false
		var p: Player = _nearest_player_any()
		if p != null:
			_face(p.global_position)
			cup_given_to = p.player_id
			death_line = last_line_for(p.character_id)
		else:
			death_line = "PAU_LAST_DUT_01"
		_pose.set_bone("Head", Vector3(-0.2, 0, 0))
		say(death_line)
	if t >= 5.5 and _death_phase == 1:
		_death_phase = 2
		# he holds out the crushed tin cup and presses it into that player's hand
		_pose.set_bone("LeftUpperArm", Vector3(1.4, 0, 0.1))
		_pose.set_bone("LeftLowerArm", Vector3(0.2, 0, 0))
		if event != null and event.has_method("on_cup_given"):
			event.call("on_cup_given", cup_given_to)
	if t >= 8.0 and _death_phase == 2:
		_death_phase = 3
		if _cup != null:
			_cup.hide()
		_pose.clear()
		_pose.set_bone("LeftUpperArm", Vector3(0.1, 0, 0.1))
		_pose.set_bone("RightUpperArm", Vector3(0.1, 0, -0.1))
	if _death_phase >= 3:
		# the fall: forward, slowly, arms at his sides, like a tree going down
		var f: float = clampf((t - 8.0) / 3.0, 0.0, 1.0)
		_pivot.rotation.x = -PI * 0.5 * f * f
		_pivot.position.y = 0.0
		if f >= 1.0 and not fallen:
			fallen = true
			sfx("boss_stomp", 4.0, 0.5)
			BossFx.burst("dust", global_position + basis_fwd() * 1.5, get_tree(), 3.0, 2.4)
			if fx != null:
				fx.shake_all(global_position, 0.5, 18.0)
			if _eyes != null:
				_eyes.lit = false
			if event != null and event.has_method("on_paul_fallen"):
				event.call("on_paul_fallen", global_position)


func _nearest_player_any() -> Player:
	var best: Player = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.spectating:
			continue
		var d: float = p.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = p
	return best


## No pose freeze in his death (the fall is driven by the pivot).
func _hold_after() -> float:
	return 9999.0


## His body stays where he fell for the rest of the match (the encounter never cleans it up; 120 s safety off).
func _update_dead(delta: float) -> void:
	_death_t += delta
	_death_tick(delta)
