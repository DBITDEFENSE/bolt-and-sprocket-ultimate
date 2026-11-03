class_name LetzteFahrtGuide
extends Node
## Letzte Fahrt, findable (UPDATE 10 s10, DECISIONS T-173): the owner played Totenhafen and never found the egg. The
## pattern copied from Kaltenbrunn's Requiem (its pylons hum and its radios crackle, Fasbender's lines name the next
## place, the pause OBJECTIVES' current line names the egg's first step) and from Act I's Jette (SightNote):
##   * the Operator's pointers at round starts (`NUDGES`, one per round at most, each once per match, only while its
##     step is active and untouched): the crane hook from round 2, the radios and the sea stairs after the power, the
##     log pages from round 5. Host-only (GLVO.play replicates the line).
##   * a soft amber lamp pulsing on the empty crane hook (BallastHook) with the crane's cable creaking now and then,
##     until the first coffin hangs there (the flag `ballast_loaded`): the egg's first step and the power's gate.
##   * a SightNote: a personal minimap note the first time the player sees the hook, a coffin pallet, the sea stairs,
##     each radio and the rotor machine.
## Presentation only: no step, timing, prompt gate or reward changes (the quest's banners name the next step).

const QUEST: StringName = &"map02_letzte_fahrt"
const SAY_DELAY_S: float = 6.0   # after the round's own Operator line
const CREAK_EVERY_S: Vector2 = Vector2(7.0, 12.0)
## The Operator's pointers, in priority order: the line, the step it points at (active and not done), the first round
## it may play, and `untouched`: only while that step has no progress yet (no radio heard, no page found).
const NUDGES: Array = [
	{"id": "OPR_LF_HINT_HOOK_01", "step": "s0a_load", "round": 2},
	{"id": "OPR_LF_HINT_HOOK_02", "step": "s0a_load", "round": 4},
	{"id": "OPR_LF_HINT_RADIO_01", "step": "s2a_radios", "round": 2, "untouched": true},
	{"id": "OPR_LF_HINT_STAIRS_01", "step": "s1_ballast", "round": 3},
	{"id": "OPR_LF_HINT_LOG_01", "step": "s3_log", "round": 5, "untouched": true},
]
## SightNote targets (Gameplay node names) and their notes.
const SIGHTS: Array = [
	["BallastHook", "Crane hook: it wants ballast"],
	["Coffin_0", "Lead coffins on a pallet"],
	["Coffin_1", "Lead coffins on a pallet"],
	["BallastDump", "The sea stairs"],
	["Radio_radio_cannery", "A radio keying traffic"],
	["Radio_radio_workshop", "A radio keying traffic"],
	["Radio_radio_uboat", "A radio keying traffic"],
	["CipherMachine", "A machine with three wheels"],
]

var t: Totenhafen
var said: Dictionary = {}          # line id -> true (this match)
var beacon: MeshInstance3D = null
var sight: SightNote = null
var _beacon_mat: StandardMaterial3D
var _clock: float = 0.0
var _creak_in: float = 9.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func attach(owner_t: Totenhafen) -> LetzteFahrtGuide:
	var g: LetzteFahrtGuide = LetzteFahrtGuide.new()
	g.name = "LetzteFahrtGuide"
	owner_t.add_child(g)
	g.setup(owner_t)
	return g


func setup(owner_t: Totenhafen) -> void:
	t = owner_t
	add_to_group(&"letzte_fahrt_guide")
	_rng.seed = 1047
	GLBus.round_started.connect(_on_round_started)
	GLBus.flag_changed.connect(_on_flag)
	_build_beacon()
	_build_sight()


# ------------------------------------------------------------------ pure rules (the tests)

## The pointer for `round_number`, or "" (one per round). `steps`: step id -> {"active": bool, "progress": int}.
static func pick(round_number: int, said_ids: Dictionary, steps: Dictionary) -> String:
	for n: Variant in NUDGES:
		var nd: Dictionary = n
		var id: String = str(nd["id"])
		if said_ids.has(id) or round_number < int(nd["round"]):
			continue
		var st: Dictionary = steps.get(str(nd["step"]), {})
		if not bool(st.get("active", false)):
			continue
		if bool(nd.get("untouched", false)) and int(st.get("progress", 0)) > 0:
			continue
		return id
	return ""


## The step states `pick` reads, from QuestManager.
static func step_states() -> Dictionary:
	var out: Dictionary = {}
	if not QuestManager.has_quest(QUEST):
		return out
	for n: Variant in NUDGES:
		var sid: StringName = StringName(str((n as Dictionary)["step"]))
		var p: Variant = QuestManager.progress(QUEST, sid)
		out[String(sid)] = {"active": QuestManager.is_active(QUEST, sid), "progress": (p as Array).size() if p is Array else (int(p) if (p is int or p is float) else 0)}
	return out


## Does the empty hook still call for its first coffin?
static func hook_waiting() -> bool:
	return not GameState.has_flag(&"ballast_loaded")


# ------------------------------------------------------------------ the pointers

func _on_round_started(round_number: int, special: bool) -> void:
	if special or not Net.is_authority():
		return
	var id: String = pick(round_number, said, step_states())
	if id == "":
		return
	said[id] = true
	get_tree().create_timer(SAY_DELAY_S).timeout.connect(func() -> void:
		# still pointing somewhere useful when it comes due (the coffin may have gone up meanwhile)
		var others: Dictionary = said.duplicate()
		others.erase(id)
		if is_inside_tree() and pick(round_number, others, step_states()) == id:
			say(id))


## Plays a pointer line now (the smoke's way in too).
func say(id: String) -> void:
	said[id] = true
	print("[lf_guide] %s" % id)
	GLVO.play(StringName(id))


# ------------------------------------------------------------------ the hook's lamp

func _build_beacon() -> void:
	var hook: Node3D = t.gameplay.get_node_or_null("BallastHook") as Node3D if t.gameplay != null else null
	if hook == null:
		return
	beacon = MeshInstance3D.new()
	beacon.name = "LfHookLamp"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 12
	sm.rings = 6
	beacon.mesh = sm
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.albedo_color = Color(1.0, 0.72, 0.32)
	_beacon_mat.emission_enabled = true
	_beacon_mat.emission = Color(1.0, 0.62, 0.22)
	_beacon_mat.emission_energy_multiplier = 1.5
	beacon.material_override = _beacon_mat
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.position = Vector3(0, 2.62, 0.3)   # where the slings meet (BallastHook's art: the ropes from (0, 2.5, 0.3))
	hook.add_child(beacon)
	beacon.visible = hook_waiting()


func _process(delta: float) -> void:
	if beacon == null or not beacon.visible:
		return
	_clock += delta
	_beacon_mat.emission_energy_multiplier = 1.0 + 1.6 * (0.5 + 0.5 * sin(_clock * 2.2))
	_creak_in -= delta
	if _creak_in <= 0.0:
		_creak_in = _rng.randf_range(CREAK_EVERY_S.x, CREAK_EVERY_S.y)
		AudioDirector.play_3d("amb_m4c_metal_creak", beacon.global_position + Vector3.UP * 1.5, -10.0)


func _on_flag(flag: StringName, _value: Variant) -> void:
	if flag == &"ballast_loaded" and beacon != null:
		beacon.visible = hook_waiting()


# ------------------------------------------------------------------ first sight

func _build_sight() -> void:
	if t.gameplay == null:
		return
	sight = SightNote.new()
	sight.name = "SightNote_LF"
	var targets: Array = []
	var labels: PackedStringArray = PackedStringArray()
	for s: Variant in SIGHTS:
		var row: Array = s
		if t.gameplay.get_node_or_null(str(row[0])) == null:
			continue
		targets.append("../" + str(row[0]))
		labels.append(str(row[1]))
	sight.targets = targets
	sight.labels = labels
	t.gameplay.add_child(sight)
