class_name WeaponHolder
extends Node3D
## Lives under the player's camera. Owns the weapon slots, grenades and melee, fires hitscan shots,
## and animates the greybox viewmodel. Input arrives as an "intent" Dictionary from the Player each frame,
## so a network layer can feed the same intents later.
##
## Co-op (M7): a teammate's puppet carries a `mirror` holder: no viewmodel, never ticks, its slots are the
## owner's replicated inventory (apply_net). Host-side world code reads it as usual; the mutating calls
## (give_weapon, refill..., remove_current) also go to the owner's real holder (D-065). Shots made by the
## local player are reported to the session for remote muzzle flashes and host-validated hits.

const MASK_SHOT: int = 1 | (1 << 3) | (1 << 8) | DecorHit.LAYER   # world | zombie_hitbox | door | decor (T-053)
const SHOT_RANGE: float = 220.0
const RECOIL: Dictionary = {&"pistol": 1.3, &"rifle": 2.4, &"bolt": 3.4, &"smg": 0.55, &"assault": 0.75,
	&"shotgun": 4.2, &"lmg": 0.9, &"sniper": 4.5}
const ADS_ZOOM: Dictionary = {&"pistol": 0.9, &"rifle": 0.75, &"bolt": 0.72, &"smg": 0.85, &"assault": 0.8,
	&"shotgun": 0.9, &"lmg": 0.85, &"sniper": 0.45}
const SOUND: Dictionary = {&"pistol": "gun_pistol", &"rifle": "gun_rifle", &"bolt": "gun_bolt", &"smg": "gun_smg",
	&"assault": "gun_assault", &"shotgun": "gun_shotgun", &"lmg": "gun_lmg", &"sniper": "gun_sniper"}
## Reload sound cues per viewmodel reload kind: [progress 0..1, key]. "<kind>_empty" cues are appended on an empty
## reload; "<kind>_round" replaces the list for one-round-at-a-time loading. Phases match _animate_reload().
const RELOAD_CUES: Dictionary = {
	"mag": [[0.08, "reload_mag_out"], [0.74, "reload_mag_in"]], "mag_empty": [[0.93, "reload_bolt_fwd"]],
	"pistol": [[0.08, "reload_mag_out"], [0.74, "reload_mag_in"]], "pistol_empty": [[0.93, "reload_bolt_fwd"]],
	"capsule": [[0.08, "reload_mag_out"], [0.74, "reload_mag_in"]],
	"drum": [[0.08, "reload_mag_out"], [0.74, "reload_drum_in"]], "drum_empty": [[0.93, "reload_bolt_fwd"]],
	"belt": [[0.06, "reload_cover_open"], [0.5, "reload_belt"], [0.8, "reload_cover_close"]],
	"bolt": [[0.03, "reload_bolt_back"], [0.5, "reload_stripper_clip"], [0.8, "reload_bolt_fwd"]],
	"bolt_round": [[0.7, "reload_shell_insert"]],
	"shell": [[0.7, "reload_shell_insert"]],
	"enbloc": [[0.55, "reload_mag_in"], [0.68, "reload_bolt_fwd"]],
	"break": [[0.06, "reload_cover_open"], [0.6, "reload_shell_insert"], [0.86, "reload_cover_close"]],
	"rocket": [[0.45, "reload_rocket_load"]],
}
const FIRE_BUFFER: float = 0.12    # seconds a too-early semi-auto click is remembered
const SWAP_TIME: float = 0.42      # raise time after a weapon swap (firing is blocked meanwhile)

var player: Player
var slots: Array[WeaponInstance] = []
var current_index: int = 0
var melee_id: StringName = &"trench_knife"
var grenades: int = 2
var tactical_id: StringName = &""
var tactical_count: int = 0

# timers / state
var ads_t: float = 0.0
var bloom: float = 0.0
var _fire_cd: float = 0.0
var _reload_t: float = 0.0
var _reloading: bool = false
var _reload_per_round: bool = false
var _swap_t: float = 0.0
var _melee_t: float = 0.0
var _melee_hit_pending: bool = false
var _sprint_out_t: float = 0.0
var _cooking: bool = false
var _cook_t: float = 0.0
var _kick: float = 0.0             # 1 on a shot, decays (kept for tools; motion comes from the springs)

# viewmodel
var _vm: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _flash_light: OmniLight3D
var _flash_mesh: MeshInstance3D
var _knife: Node3D
var _flash_t: float = 0.0
var _flame: CPUParticles3D
var _flame_t: float = 0.0
var _flame_snd_t: float = 0.0
var _burst_left: int = 0
var _burst_cd: float = 0.0
var _ground_t: float = 0.0
var _fired_this_frame: bool = false
var _bell: Totenglocke = null      # Totenglocke wind-and-toll logic (gravelight/weapons/totenglocke.gd), made on first use
var _bell_crank: Node3D = null
var _fire_keys: Dictionary = {}    # base weapon id -> fire sound key (cached: "fire_<id>" or the class key)
var _fire_buffer: float = 0.0      # a semi-auto click that arrived slightly early fires as soon as it can
var _look_in: Vector2 = Vector2.ZERO
var _feel: Dictionary = {}         # resolved feel/viewmodel tuning for the held weapon (feel_for)
var _cues: Array = []              # sound cues of the reload in progress (RELOAD_CUES)
var _cue_i: int = 0
var _sprinting: bool = false       # from this frame's intent: sprinting interrupts reloads unless sprint_reload_allowed (see _tick_reload)
# Update 02 §1 gunplay feel
const MOVE_FIRE_BUFFER: float = 0.75   # a fire press during sprint-out / an early slide / a mantle waits this long at most
var _sprint_out_total: float = 0.3     # this weapon's sprint-out time (movement.json sprint_out), for the pose blend
var _move_fire_buffer: float = 0.0     # a fire press that arrived while sprinting / sprinting out / sliding early / mantling
var _since_shot: float = 99.0
var _shot_i: int = 0                   # shots in the current burst (recoil pattern index)
var _recoil: Dictionary = {}           # resolved recoil pattern for the held weapon (recoil_for), cached by id
var _recoil_id: StringName = &""
var _vel_prev: Vector3 = Vector3.ZERO  # weapon inertia: the player's velocity last frame
var _inertia: Vector3 = Vector3.ZERO   # weapon inertia offset (camera space, m) and its velocity
var _inertia_v: Vector3 = Vector3.ZERO
var _reload_queued: bool = false   # a reload asked for while sprinting starts once the sprint ends
## Co-op puppet inventory (see the class doc). Set before setup().
var mirror: bool = false
var _last_stand_stash: Dictionary = {}   # co-op downed: the loadout put away while crawling with the pistol


func setup(owner_player: Player) -> void:
	player = owner_player
	_set_start_loadout()
	if mirror:
		set_process(false)
		set_physics_process(false)
		return
	_build_viewmodel()
	GLBus.round_started.connect(_on_round_started)


func _set_start_loadout() -> void:
	var loadout: Dictionary = GLData.table("player")["start_loadout"]
	var pid: int = _muster_pid()
	slots = [WeaponInstance.create(Muster.start_pistol(pid) if pid > 0 else StringName(loadout["primary"]))]   # the Muster's sidearm (T-079)
	_apply_profile_kit(slots[0])
	melee_id = StringName(loadout["melee"])
	grenades = int(loadout["lethal_count"])
	tactical_id = &""
	tactical_count = 0
	current_index = 0
	if pid > 0:
		Muster.apply_start_kit(self, pid)   # Field Habits: reserve, a grenade, a gramophone


## The player id whose Muster kit this holder starts with (T-079); 0 for bots, Jakub and holders without a player.
func _muster_pid() -> int:
	if player == null or player.is_bot or player.is_companion:
		return 0
	return player.player_id


## The local human's starting M1911 gets their Loadout Pick and finish (UPDATE_04 section 6, M1911Kit). Bots, Jakub,
## mirrors and tools (a Player outside the tree) start plain.
func _apply_profile_kit(w: WeaponInstance) -> void:
	if player == null or mirror or player.is_bot or player.is_companion or not player.is_local or not player.is_inside_tree():
		return
	M1911Kit.apply_start(w, M1911Kit.equipped_pick(), M1911Kit.equipped_finish())


# ---------------------------------------------------------------- queries

func current() -> WeaponInstance:
	if slots.is_empty():
		return null
	return slots[clampi(current_index, 0, slots.size() - 1)]


func find_weapon(weapon_id: StringName) -> WeaponInstance:
	for w: WeaponInstance in slots:
		if w.id == weapon_id:
			return w
	return null


## The held weapon whose base is `base` (e.g. mp40_up for the MP40 wall).
func find_weapon_base(base: StringName) -> WeaponInstance:
	for w: WeaponInstance in slots:
		if w.id == base or w.base_id() == base:
			return w
	return null


## Takes the current weapon out of the slots (the Crucible). The player may end up holding nothing.
func remove_current() -> WeaponInstance:
	_forward_op(&"remove_current", [])
	var w: WeaponInstance = current()
	if w == null:
		return null
	slots.erase(w)
	_cancel_reload()
	_burst_left = 0
	current_index = clampi(current_index, 0, maxi(0, slots.size() - 1))
	_swap_t = SWAP_TIME
	_rebuild_gun()
	return w


func max_slots() -> int:
	return int(PerkManager.stat(player.player_id, "weapon_slots", int(GLData.table("player")["weapon_slots"])))


## Drops weapons beyond the slot limit (e.g. Packmule Porter lost on down).
func enforce_slot_limit() -> void:
	while slots.size() > max_slots():
		slots.pop_back()
	if current_index >= slots.size():
		current_index = slots.size() - 1
		_rebuild_gun()


func grenade_max() -> int:
	var lethal: Dictionary = GLData.table("weapons")["lethal"]["frag"]
	var m: int = int(lethal["max"])
	if GameState.player_has_trait(player.player_id if player != null else 1, &"peg"):
		m += int(GLData.table("player")["traits"]["peg_extra_grenades"])
	if player != null:
		m += PerkManager.grenade_bonus(player.player_id)   # Packmule II (T-075)
	return m


func is_reloading() -> bool:
	return _reloading


func is_busy() -> bool:
	return _swap_t > 0.0 or _melee_t > 0.0


func cook_left() -> float:
	if not _cooking:
		return -1.0
	return float(GLData.table("weapons")["lethal"]["frag"]["fuse"]) - _cook_t


## True while aiming a scoped rifle: the HUD draws the scope picture and the viewmodel hides.
func scoped() -> bool:
	return _model != null and _model.has_meta("scope") and ads_t > 0.9 and not _reloading


func spread_deg() -> float:
	var w: WeaponInstance = current()
	if w == null:
		return 0.0
	var sway: float = float(PerkManager.stat(player.player_id, "sway_mult", 1.0))
	var mv: Dictionary = GLData.table("movement")
	var hip: float = w.f("spread_hip", 3.0)
	if player.crouching or player.prone:
		hip *= float(mv.get("crouch_spread_mult", 0.8))
	var base: float = lerpf(hip, w.f("spread_ads", 0.5) * sway, ads_t)
	# walking fire: allowed, with a cone penalty that grows with speed (up to walk_spread_deg at walk speed)
	var walk: float = float(GLData.table("player")["walk_speed"])
	var move_pen: float = clampf(player.horizontal_speed() / walk, 0.0, 1.3) * float(mv.get("walk_spread_deg", 2.2)) * (1.0 - ads_t)
	return base + bloom * (1.0 - 0.7 * ads_t) + move_pen + (0.0 if player.is_on_floor() else 4.0)


func fov_mult() -> float:
	var w: WeaponInstance = current()
	if w == null:
		return 1.0
	return lerpf(1.0, ads_zoom(w), ads_t)


var _zoom_cache: Dictionary = {}   # weapon id -> ADS FOV multiplier


## ADS FOV multiplier for a weapon (T-047): weapons.json feel "ads_zoom" (per weapon, upgraded rows inherit
## the base row's, class value as the fallback), else the old per-class ADS_ZOOM table.
func ads_zoom(w: WeaponInstance) -> float:
	var key: String = String(w.id) + w.kit_sig()
	if not _zoom_cache.has(key):
		var fallback: float = float(ADS_ZOOM.get(w.weapon_class(), 0.8))
		_zoom_cache[key] = clampf(float(feel_for(w).get("ads_zoom", fallback)), 0.1, 1.0)
	return float(_zoom_cache[key])


func move_mult() -> float:
	var w: WeaponInstance = current()
	return 1.0 if w == null else w.f("move_mult", 1.0)


## ADS-walk speed as a share of the walk speed: the weapon row's ads_move_mult, else movement.json's (0.6).
func ads_move_mult() -> float:
	var dflt: float = float(GLData.table("movement").get("ads_move_mult", 0.6))
	var w: WeaponInstance = current()
	return dflt if w == null else w.f("ads_move_mult", dflt)


## Seconds from leaving a sprint until `w` can fire (movement.json sprint_out: per class, per-weapon overrides).
static func sprint_out_time(w: WeaponInstance) -> float:
	var so: Dictionary = GLData.table("movement").get("sprint_out", {})
	var dflt: float = float(so.get("default", 0.3))
	if w == null:
		return dflt
	var per: Dictionary = so.get("weapons", {})
	if per.has(String(w.base_id())):
		return float(per[String(w.base_id())])
	return float(so.get(String(w.weapon_class()), dflt))


## May `w` start and keep a reload while its holder sprints (T-083)? SMGs and pistols by class
## (movement.json "sprint_reload": default, per class, "weapons" per base id), and any gun wearing a bench part
## whose props set sprint_reload (the Paratrooper Sling). Firing still waits for the sprint-out.
static func sprint_reload_allowed(w: WeaponInstance) -> bool:
	if w == null:
		return false
	if bool(w.property("sprint_reload", false)):
		return true
	var sr: Dictionary = GLData.table("movement").get("sprint_reload", {})
	var per: Dictionary = sr.get("weapons", {})
	if per.has(String(w.base_id())):
		return bool(per[String(w.base_id())])
	return bool(sr.get(String(w.weapon_class()), sr.get("default", false)))


## True while a fire press is waiting for the sprint-out / slide / mantle to finish (the Player keeps the
## sprint off meanwhile so the shot is never lost).
func fire_pending() -> bool:
	return _move_fire_buffer > 0.0


# ---------------------------------------------------------------- inventory

func give_weapon(weapon_id: StringName) -> void:
	_forward_op(&"give_weapon", [weapon_id])
	var have: WeaponInstance = find_weapon(weapon_id)
	if have != null:
		have.refill()
		return
	var w: WeaponInstance = WeaponInstance.create(weapon_id)
	if slots.size() < max_slots():
		slots.append(w)
		current_index = slots.size() - 1
	else:
		slots[current_index] = w
	_cancel_reload()
	_swap_t = SWAP_TIME
	_rebuild_gun()


## Puts an existing weapon (with its ammo and attachments) into the hands: the gun Jakub hands back. Takes the
## current slot when the slots are full, like a wall-buy.
func give_instance(w: WeaponInstance) -> void:
	if w == null:
		return
	if slots.size() < max_slots():
		slots.append(w)
		current_index = slots.size() - 1
	else:
		slots[current_index] = w
	_cancel_reload()
	_swap_t = SWAP_TIME * w.draw_mult()
	_rebuild_gun()


## Fits one attachment to the held weapon `weapon_id` (the Armorer's Bench, any gun: WeaponKit; "" clears the slot). Co-op: the
## host's puppet forwards it to the owner's real holder like the other inventory ops.
func fit_attachment(weapon_id: StringName, slot: String, option: String) -> void:
	_forward_op(&"fit_attachment", [weapon_id, slot, option])
	var w: WeaponInstance = find_weapon(weapon_id)
	if w == null or not WeaponKit.accepts(w):
		return
	WeaponKit.install(w, slot, option)
	_kit_changed(w)


## Replaces the whole kit (and finish) of `weapon_id`, full ammo (the Crucible hands Last Rites back with the
## pistol's attachments, each one now its upgraded version).
func set_kit(weapon_id: StringName, kit_list: Array, finish: String) -> void:
	_forward_op(&"set_kit", [weapon_id, kit_list, finish])
	var w: WeaponInstance = find_weapon(weapon_id)
	if w == null or not WeaponKit.accepts(w):
		return
	w.kit = WeaponKit.decode(kit_list, w)
	w.finish = StringName(finish)
	w.refresh_kit()
	w.refill()
	_kit_changed(w)


func _kit_changed(w: WeaponInstance) -> void:
	if w == current():
		_rebuild_gun()
	if player != null and player.remote_body != null and is_instance_valid(player.remote_body):
		player.remote_body.refresh_weapon()


func set_melee(weapon_id: StringName) -> void:
	_forward_op(&"set_melee", [weapon_id])
	melee_id = weapon_id
	_rebuild_knife()


func refill_grenades() -> void:
	_forward_op(&"refill_grenades", [])
	grenades = grenade_max()


## Ammo for one held weapon (wall-buy ammo, the Crucible's upgraded-ammo refill).
func refill_weapon(base: StringName) -> void:
	_forward_op(&"refill_weapon", [base])
	var w: WeaponInstance = find_weapon_base(base)
	if w != null:
		w.refill()


func refill_all() -> void:
	_forward_op(&"refill_all", [])
	if not _last_stand_stash.is_empty():
		for sw: WeaponInstance in _last_stand_stash.get("slots", []):
			sw.refill()
	for w: WeaponInstance in slots:
		w.refill()
	grenades = grenade_max()
	if tactical_id != &"":
		tactical_count = int(GLData.table("weapons")["tactical"][String(tactical_id)]["max"])


## Crate tacticals (Siren Gramophone) go in the tactical slot instead of a weapon slot.
func give_tactical(id: StringName) -> void:
	_forward_op(&"give_tactical", [id])
	var t: Dictionary = GLData.table("weapons")["tactical"][String(id)]
	if tactical_id == id:
		tactical_count = mini(int(t["max"]), tactical_count + int(t["per_pickup"]))
	else:
		tactical_id = id
		tactical_count = int(t["per_pickup"])


# ---------------------------------------------------------------- co-op (M7)

## Puppet holder on the host: the change must also happen on the owner's machine. Returns true if sent.
func _forward_op(op: StringName, args: Array) -> bool:
	if mirror and Net.replicating() and player != null and not player.is_bot:

		player._forward(&"inv", [op, args])
		return true
	return false


## Co-op downed: crawl with a pistol. Your own pistol if you carry one (its ammo is kept), else the
## data's last-stand pistol; either way with at least `pistol_min_reserve` spare rounds.
func enter_last_stand() -> void:
	var dcfg: Dictionary = GLData.table("player").get("downed", {})
	_cancel_reload()
	_reload_queued = false
	_burst_left = 0
	_cooking = false
	_melee_t = 0.0
	_melee_hit_pending = false
	ads_t = 0.0
	var pistol: WeaponInstance = null
	for w: WeaponInstance in slots:
		if w.weapon_class() == &"pistol":
			pistol = w
			break
	var keep: Array[WeaponInstance] = []
	keep.assign(slots)
	_last_stand_stash = {"slots": keep, "current": current_index}
	if pistol == null:
		var own: int = _muster_pid()
		pistol = WeaponInstance.create(Muster.start_pistol(own) if own > 0 else StringName(str(dcfg.get("pistol", "m1911"))))
	pistol.reserve = maxi(pistol.reserve, mini(pistol.reserve_max(), int(dcfg.get("pistol_min_reserve", 32))))
	slots = [pistol]
	current_index = 0
	_swap_t = SWAP_TIME
	_rebuild_gun()


## Revived: the loadout comes back (Packmule's third gun is gone with the perks: enforce_slot_limit).
func exit_last_stand() -> void:
	if _last_stand_stash.is_empty():
		return
	_cancel_reload()
	var keep: Array = _last_stand_stash.get("slots", [])
	slots.clear()
	for w: Variant in keep:
		slots.append(w as WeaponInstance)
	current_index = clampi(int(_last_stand_stash.get("current", 0)), 0, maxi(0, slots.size() - 1))
	_last_stand_stash = {}
	enforce_slot_limit()
	_swap_t = SWAP_TIME
	_rebuild_gun()


func in_last_stand() -> bool:
	return not _last_stand_stash.is_empty()


## Bled out: everything is gone until the respawn.
func clear_for_spectate() -> void:
	_cancel_reload()
	_cooking = false
	slots.clear()
	grenades = 0
	tactical_id = &""
	tactical_count = 0
	_last_stand_stash = {}
	current_index = 0
	_rebuild_gun()
	visible = false


## Respawn at a new round: the starting loadout (GDD §3: M1911, trench knife, 2 frags).
func reset_loadout() -> void:
	_cancel_reload()
	_last_stand_stash = {}
	_set_start_loadout()
	ads_t = 0.0
	_swap_t = SWAP_TIME
	visible = true
	_rebuild_gun()
	_rebuild_knife()


## Owner -> host inventory snapshot (and host -> teammates, for the third-person weapon model).
func to_net() -> Dictionary:
	var s: Array = []
	for w: WeaponInstance in slots:
		s.append(net_entry(w))
	return {"s": s, "c": current_index, "m": String(melee_id), "g": grenades, "t": String(tactical_id), "tc": tactical_count}


## One weapon in to_net shape: [id, mag, reserve, fire mode, underbarrel on, underbarrel ammo, tier, attachments
## (WeaponKit.encode), finish].
static func net_entry(w: WeaponInstance) -> Array:
	return [String(w.id), w.mag, w.reserve, w.fire_mode, w.underbarrel_active, w.underbarrel_ammo, w.tier,
		WeaponKit.encode(w.kit), String(w.finish)]


## Mirror only: becomes the owner's inventory.
func apply_net(d: Dictionary) -> void:
	slots.clear()
	for e: Variant in d.get("s", []):
		var a: Array = e
		var t: Dictionary = GLData.table("weapons")
		var wid: String = str(a[0])
		if not (t["weapons"] as Dictionary).has(wid) and not (t.get("upgraded", {}) as Dictionary).has(wid):
			continue
		var w: WeaponInstance = WeaponInstance.create(StringName(wid))
		w.mag = int(a[1])
		w.reserve = int(a[2])
		w.fire_mode = str(a[3])
		w.underbarrel_active = bool(a[4])
		w.underbarrel_ammo = int(a[5])
		if a.size() > 6:
			w.tier = maxi(w.tier, int(a[6]))
		if a.size() > 7 and WeaponKit.accepts(w):
			w.kit = WeaponKit.decode(a[7], w)
			w.finish = StringName(str(a[8])) if a.size() > 8 else &""
			w.refresh_kit()
			w.mag = int(a[1])
			w.reserve = int(a[2])
		slots.append(w)
	current_index = clampi(int(d.get("c", 0)), 0, maxi(0, slots.size() - 1))
	melee_id = StringName(str(d.get("m", "trench_knife")))
	grenades = int(d.get("g", 0))
	tactical_id = StringName(str(d.get("t", "")))
	tactical_count = int(d.get("tc", 0))


## Campaign carry-over (T-033): the kit this holder left the last map with (to_net shape) comes back on the
## next one, on the owner's own holder (so the viewmodel is rebuilt) or a bot's mirror.
func apply_carry(d: Dictionary) -> void:
	_cancel_reload()
	_last_stand_stash = {}
	_cooking = false
	apply_net(d)
	if slots.is_empty():
		_set_start_loadout()
	ads_t = 0.0
	_swap_t = SWAP_TIME
	visible = true
	if not mirror:
		_rebuild_gun()
		_rebuild_knife()


## What changed since the last send: [structure (send now), ammo (send soon)].
func net_signature() -> Array:
	var ids: PackedStringArray = []
	var ammo: int = 0
	for w: WeaponInstance in slots:
		ids.append(String(w.id) + w.kit_sig())
		ammo = ammo * 31 + w.mag * 1000 + w.reserve
	return ["%s|%d|%s|%d|%s|%d" % [",".join(ids), current_index, melee_id, grenades, tactical_id, tactical_count], ammo]


func _report_fire(kind: int, weapon_id: StringName, origin: Vector3, end: Vector3) -> void:
	if Net.session != null and not mirror:
		Net.session.local_fired(kind, weapon_id, origin, end)


func _throw_tactical() -> void:
	if tactical_id == &"" or tactical_count <= 0 or _melee_t > 0.0 or _cooking:
		return
	tactical_count -= 1
	var t: Dictionary = GLData.table("weapons")["tactical"][String(tactical_id)]
	var g: Gramophone = Gramophone.new()
	g.cfg = t
	g.by_player = player.player_id
	player.get_parent().add_child(g)
	var cam: Camera3D = player.camera
	g.global_position = cam.global_position - cam.global_basis.z * 0.7
	g.linear_velocity = -cam.global_basis.z * float(t["throw_speed"]) + Vector3.UP * 2.5
	g.add_collision_exception_with(player)
	if Net.is_client() and Net.session != null:
		# The lure has to exist where the zombies are simulated: the host throws the real one (D-068).
		g.visual_only = true
		Net._rpc_fx.rpc_id(1, &"gramophone", [g.global_position, g.linear_velocity, String(tactical_id)])
	AudioDirector.play_2d("gramophone_windup" if tactical_id == &"gramophone" else "grenade_pin", -6.0)
	if tactical_count <= 0:
		tactical_id = &""


func _on_round_started(round_number: int, _special: bool) -> void:
	if round_number > 1 and not player.spectating:
		grenades = mini(grenade_max(), grenades + int(GLData.table("weapons")["lethal"]["frag"]["per_round"]))
		if tactical_id != &"":
			var t: Dictionary = GLData.table("weapons")["tactical"][String(tactical_id)]
			tactical_count = mini(int(t["max"]), tactical_count + int(t["per_round"]))


# ---------------------------------------------------------------- per-frame

func tick(delta: float, intent: Dictionary) -> void:
	# The cooldown may run slightly negative so automatic fire keeps its exact cadence at any frame rate
	# (the overshoot carries into the next interval instead of being lost each shot).
	_fire_cd = maxf(-0.05, _fire_cd - delta)
	_fire_buffer = maxf(0.0, _fire_buffer - delta)
	_swap_t = maxf(0.0, _swap_t - delta)
	_since_shot += delta
	_move_fire_buffer = maxf(0.0, _move_fire_buffer - delta)
	_tick_bloom(delta)
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	var sprinting: bool = bool(intent.get("sprinting", false))
	_sprinting = sprinting
	var w: WeaponInstance = current()
	if sprinting:
		_sprint_out_total = sprint_out_time(w) * float(PerkManager.stat(player.player_id, "sprint_out_mult", 1.0))   # Marathon II
		_sprint_out_t = _sprint_out_total     # held full while sprinting; runs down from the moment the sprint ends
	else:
		_sprint_out_t = maxf(0.0, _sprint_out_t - delta)
	var fire_block: bool = bool(intent.get("fire_block", false))
	# ADS
	var want_ads: bool = bool(intent.get("ads", false)) and not sprinting and _melee_t <= 0.0 and not bool(intent.get("mantle", false))
	var ads_time: float = 0.25 if w == null else maxf(0.05, w.f("ads_time", 0.25) * float(PerkManager.stat(player.player_id, "ads_time_mult", 1.0)))
	ads_t = move_toward(ads_t, 1.0 if want_ads else 0.0, delta / ads_time)
	# Swap
	if bool(intent.get("swap", false)) and slots.size() > 1 and _melee_t <= 0.0:
		_select((current_index + 1) % slots.size())
	var slot_req: int = int(intent.get("slot", -1))
	if slot_req >= 0 and slot_req < slots.size() and slot_req != current_index:
		_select(slot_req)
	# Melee
	_tick_melee(delta, bool(intent.get("melee", false)))
	# Grenades / tactical
	_tick_grenade(delta, bool(intent.get("lethal_held", false)))
	if bool(intent.get("tactical", false)):
		_throw_tactical()
	# Reload
	if bool(intent.get("reload", false)):
		start_reload()
	elif _reload_queued and not sprinting:
		_reload_queued = false
		start_reload()
	_tick_reload(delta, bool(intent.get("fire_pressed", false)))
	# Alt-fire (fire-mode selector / underbarrel / volley). Read from the intent, or Input as a fallback.
	var alt: bool = bool(intent.get("alt_fire", false))
	if not intent.has("alt_fire") and InputMap.has_action(&"alt_fire") and not GameState.input_blocked:
		alt = Input.is_action_just_pressed(&"alt_fire")
	if alt and w != null and _swap_t <= 0.0 and _melee_t <= 0.0:
		_alt_fire(w)
	# Fire
	_fired_this_frame = false
	_burst_cd = maxf(0.0, _burst_cd - delta)
	var can_shoot: bool = w != null and not sprinting and _sprint_out_t <= 0.0 and _swap_t <= 0.0 and _melee_t <= 0.0 and not _cooking and not fire_block
	# A press while the gun is still coming out of a sprint (or early in a slide, or mid-mantle) is remembered and
	# fires the moment it can: the input is never eaten.
	if bool(intent.get("fire_pressed", false)) and w != null and (sprinting or _sprint_out_t > 0.0 or fire_block) and _swap_t <= 0.0 and _melee_t <= 0.0:
		_move_fire_buffer = MOVE_FIRE_BUFFER
	if w != null and w.data.has("bell"):
		_tick_bell(w, delta, can_shoot and bool(intent.get("fire_held", false)), bool(intent.get("fire_pressed", false)))
	elif can_shoot and _burst_left > 0 and _burst_cd <= 0.0 and w.mag > 0:
		_burst_left -= 1
		_burst_cd = 60.0 / 900.0
		_fire(w)
	elif can_shoot and w.can_fire_heat():
		var mode: String = w.fire_mode
		var pressed: bool = bool(intent.get("fire_pressed", false))
		if pressed and mode != "auto" and _fire_cd > 0.0 and _fire_cd <= FIRE_BUFFER:
			_fire_buffer = FIRE_BUFFER
		var trigger: bool = bool(intent.get("fire_held", false)) if mode == "auto" else (pressed or _fire_buffer > 0.0)
		trigger = trigger or _move_fire_buffer > 0.0
		if trigger and _fire_cd <= 0.0:
			_fire_buffer = 0.0
			_move_fire_buffer = 0.0
			if w.underbarrel_active:
				_fire_underbarrel(w)
			elif w.mag > 0 and (not _reloading or _reload_per_round):
				_cancel_reload()
				if mode == "burst3":
					_burst_left = 2
					_burst_cd = 60.0 / 900.0
				_fire(w)
			elif w.mag <= 0 and bool(intent.get("fire_pressed", false)):
				AudioDirector.play_2d("gun_dry", -4.0)
				_fire_cd = 0.25
				start_reload()
	if w != null:
		var was_hot: bool = w.overheat_lockout > 0.0
		w.tick_heat(delta, _fired_this_frame or (bool(intent.get("fire_held", false)) and _fire_cd > 0.0 and w.can_fire_heat()))
		if not was_hot and w.overheat_lockout > 0.0:
			AudioDirector.play_2d("weapon_overheat", 0.0, 0.0)
			# Overclock Cordial: a heat-bar weapon's overheat vent counts as a full-empty reload (WEAPONS.md 20.2;
			# the OMNI-BLASTER, "heat_per_shot"). A belt gun's overheat is a jam, not a vent, and stays out.
			if w.data.has("heat_per_shot"):
				PerkManager.overclock_reload(player, 1.0)
	if not (bool(intent.get("fire_held", false)) and w != null and w.fire_mode == "auto") and not _fired_this_frame:
		_fire_cd = maxf(_fire_cd, 0.0)
	_look_in += intent.get("look_delta", Vector2.ZERO) as Vector2
	_animate(delta, sprinting)


func _select(index: int) -> void:
	current_index = index
	_cancel_reload()
	_reload_queued = false
	_swap_t = SWAP_TIME * (current().draw_mult() if current() != null else 1.0) * float(PerkManager.stat(player.player_id, "swap_time_mult", 1.0))
	if current() != null and current().weapon_class() == &"pistol":
		_swap_t *= Muster.mult(_muster_pid(), "pistol_draw_mult")   # Quick Holster (T-079)
	ads_t = 0.0
	AudioDirector.play_2d("weapon_raise", -6.0)
	_rebuild_gun()


# ---------------------------------------------------------------- firing

func _fire(w: WeaponInstance) -> void:
	if not PerkManager.round_saved(player.player_id, w):   # Twin Barrel III: one shot in four is free (T-075)
		w.mag -= 1
	_fired_this_frame = true
	if w.mag == 0 and w.mag_size() > 1 and not w.data.has("stream"):
		AudioDirector.play_2d("last_round_click", -3.0, 0.0)   # the "last bullet" tell: a light hollow click
	if player.camera != null:
		GLBus.mark_shot(player.player_id, w.is_suppressed())   # read by weapon_fired listeners (the minimap's reveal)
		GLBus.weapon_fired.emit(player.player_id, w.id, w.upgraded, player.camera.global_position, -player.camera.global_basis.z)
	var rpm: float = maxf(1.0, w.f("rpm", 300.0) * float(PerkManager.stat(player.player_id, "fire_rate_mult", 1.0)))
	_fire_cd = minf(_fire_cd, 0.0) + 60.0 / rpm
	if w.data.has("stream"):
		_fire_stream(w)
		_ammo_warnings(w)
		if w.mag <= 0 and w.reserve > 0:
			start_reload()
		return
	if w.data.has("projectile"):
		_fire_projectile(w)
		_shot_feedback(w)
		AudioDirector.play_2d(_fire_key(w), -2.0, 0.1)
		if w.mag <= 0 and w.reserve > 0:
			get_tree().create_timer(0.3).timeout.connect(start_reload)
		_ammo_warnings(w)
		return
	var pellets: int = maxi(1, int(w.data.get("pellets", 1)))
	var cam: Camera3D = player.camera
	var hits: Dictionary = {}   # Zombie -> {dmg, limb, mult}
	var spread: float = spread_deg() * (0.6 if w.fire_mode == "burst3" else 1.0)
	for i: int in pellets:
		var dir: Vector3 = _spread_dir(cam.global_basis, spread)
		_trace(cam.global_position, dir, w, hits)
	var pid: int = player.player_id
	var piercing: bool = bool(w.property("armor_piercing", false)) or bool(w.property("armor_ignore", false))
	var tier_mult: float = PerkManager.shot_mult(pid, ads_t >= 0.95)   # Trigger Tonic III / Hawkeye III (T-075)
	NetMatch.shot_origin = cam.global_position
	NetMatch.shot_dir = -cam.global_basis.z
	for z: Variant in hits.keys():
		var zz: Zombie = z as Zombie
		var h: Dictionary = hits[z]
		var limb: StringName = StringName(h["limb"])
		var pos: Vector3 = zz.global_position + Vector3.UP * 1.6
		zz.last_hit_bone = str(h.get("bone", ""))
		var killed: bool = zz.take_damage(float(h["dmg"]) * tier_mult, limb, w.id, pid, &"bullet", piercing)
		var head: bool = limb == &"head"
		if killed:
			PerkManager.on_bullet_kill(pid, w, head)   # Hawkeye II: a headshot kill refunds a round
		GLBus.enemy_hit_feedback.emit(pid, killed, head)
		AudioDirector.play_2d("headshot" if head else "hitmarker", -3.0 if head else -4.0)
		_on_hit_effects(w, zz, limb, killed, pos)
	if w.has_property("ricochet"):
		_ricochet(w, hits)
	NetMatch.shot_dir = Vector3.ZERO
	_report_fire(0, w.id, cam.global_position, _last_impact)
	var rc: Dictionary = recoil_cfg(w)
	bloom = minf(bloom + float(rc.get("bloom", 1.0)) * (1.0 if pellets == 1 else 0.35), float(rc.get("bloom_max", 6.0)))
	AudioDirector.play_2d(_fire_key(w), float(_feel.get("fire_db", -2.0)))
	if not w.kit.is_empty():
		_kit_fire_layer(w)
	_glassy_layer(w)
	_shot_feedback(w)
	var cyc_mode: String = str(w.data.get("mode", ""))
	if cyc_mode == "bolt":
		get_tree().create_timer(0.25).timeout.connect(func() -> void: AudioDirector.play_2d("bolt_cycle", -6.0))
	elif cyc_mode == "pump":
		get_tree().create_timer(0.25).timeout.connect(func() -> void: AudioDirector.play_2d("reload_pump", -6.0))
	_after_shot_anim(w)
	if w.mag <= 0 and w.reserve > 0:
		get_tree().create_timer(0.2).timeout.connect(start_reload)
	_ammo_warnings(w)


var _warned_low: Dictionary = {}


## "fire_<base id>" when the bank has it, else the class sound. Cached per weapon so firing builds no strings.
func _fire_key(w: WeaponInstance) -> String:
	if w.is_suppressed():
		var sk: String = WeaponKit.suppressed_sound(w)
		if sk != "":
			return sk
	var base: StringName = w.base_id()
	var k: Variant = _fire_keys.get(base)
	if k == null:
		var own: String = "fire_" + String(base)
		var fallback: String = "gun_launcher" if w.data.has("projectile") else str(SOUND.get(w.weapon_class(), "gun_rifle"))
		k = own if AudioDirector.has_sound(own) else fallback
		_fire_keys[base] = k
	return str(k)


## The compensator's side blast under the shot (attachments).
func _kit_fire_layer(w: WeaponInstance) -> void:
	var fl: String = str(w.kit_mods().get("flash", ""))
	if fl == "comp" or fl == "censer":
		AudioDirector.play_2d(WeaponKit.sound("comp_layer", "kit_comp_blast"), -5.0, 0.06)


func _ammo_warnings(w: WeaponInstance) -> void:
	var total: int = w.mag + w.reserve
	if total == 0:
		GLBus.no_ammo.emit(player.player_id, w.id)
	elif total <= int(ceil((w.mag_size() + w.reserve_max()) * 0.15)) and not _warned_low.get(w.id, false):
		_warned_low[w.id] = true
		GLBus.low_ammo.emit(player.player_id, w.id)
	elif total > int(ceil((w.mag_size() + w.reserve_max()) * 0.15)):
		_warned_low[w.id] = false


func _fire_projectile(w: WeaponInstance) -> void:
	var pd: Dictionary = w.data["projectile"]
	var cam: Camera3D = player.camera
	var dir: Vector3 = _spread_dir(cam.global_basis, spread_deg())
	var p: Projectile = Projectile.new()
	p.kind = StringName(str(pd["kind"]))
	p.weapon_id = w.id
	p.by_player = player.player_id
	p.velocity = dir * float(pd["speed"])
	p.exclude = [player.get_rid()]
	if p.kind == &"bolt":
		p.direct_damage = w.f("damage", 900.0)
		p.ricochets = int(pd.get("ricochets", 1))
		p.chain = int(w.property("chain", 0))
		var chain_cfg: Dictionary = GLData.table("weapons").get("chain", {})
		p.chain_radius = float(chain_cfg.get("radius", 6.0))
		p.chain_mult = float(chain_cfg.get("mult", 0.7))
		p.cfg = {"damage": float(w.property("splash", pd["splash"])), "radius": float(pd["radius"]), "edge_mult": float(pd["edge_mult"]),
			"self_damage_near": float(pd["self_damage"]), "self_near_m": float(pd["self_radius"]), "self_damage_far": 0,
			"sound": "ashlight_splash", "sound_db": 0.0}
	else:
		p.cfg = {"damage": w.f("damage", 1000.0), "radius": float(pd["radius"]), "edge_mult": float(pd["edge_mult"]),
			"self_damage_near": float(pd["self_damage"]), "self_near_m": float(pd["self_radius"]), "self_damage_far": 0,
			"sound": "explosion_large"}
		if w.has_property("cluster"):
			p.cluster = w.property("cluster") as Dictionary
	player.get_parent().add_child(p)
	_glassy_layer(w)
	p.global_position = cam.global_position + dir * 0.7
	_report_fire(1, w.id, cam.global_position, cam.global_position + dir * 2.0)


func _fire_stream(w: WeaponInstance) -> void:
	var sd: Dictionary = w.data["stream"]
	var reach: float = float(w.property("reach", sd["reach"]))
	_fired_this_frame = true
	var cos_cone: float = cos(deg_to_rad(float(sd["cone_deg"]) * 0.5))
	var cam: Camera3D = player.camera
	var fwd: Vector3 = -cam.global_basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z: Zombie in _director_zombies():
		var chest: Vector3 = z.global_position + Vector3.UP * 1.0
		var to_z: Vector3 = chest - cam.global_position
		var d: float = to_z.length()
		if d > reach or fwd.dot(to_z / maxf(d, 0.01)) < cos_cone:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, chest, 1 | (1 << 8))
		if not space.intersect_ray(q).is_empty():
			continue
		var killed: bool = z.take_damage(w.f("damage", 40.0), &"torso", w.id, player.player_id, &"fire")
		if not killed:
			z.ignite(float(sd["burn_dps"]), float(sd["burn_seconds"]), player.player_id)
		else:
			GLBus.enemy_hit_feedback.emit(player.player_id, true, false)
	_flame_t = 0.12
	if w.has_property("burning_ground"):
		_ground_t -= 1.0 / 20.0
		if _ground_t <= 0.0:
			_ground_t = float(GLData.table("weapons").get("burning_ground", {}).get("interval", 0.5))
			_spawn_burning_ground(w, cam.global_position, fwd, reach)
	_flame_snd_t -= 1.0 / 20.0
	if _flame_snd_t <= 0.0:
		_flame_snd_t = 0.25
		AudioDirector.play_2d(_fire_key(w), -6.0, 0.1)
		_report_fire(2, w.id, cam.global_position, cam.global_position + fwd * reach)


# ---------------------------------------------------------------- upgraded-weapon behavior (Crucible)

func _alt_fire(w: WeaponInstance) -> void:
	if w.data.has("bell"):
		bell_logic().alt_fire(w)   # the Bell Dome
		return
	if w.has_property("volley"):
		_volley(w)
		return
	var what: StringName = w.toggle_alt()
	if what != &"":
		AudioDirector.play_2d("bolt_cycle", -6.0, 0.0)


## Twin Coffins: alt-fire dumps every loaded barrel at once.
func _volley(w: WeaponInstance) -> void:
	if w.mag <= 0 or _fire_cd > 0.0:
		return
	var shots: int = w.mag
	for i: int in shots:
		_fire(w)
	_fire_cd = 60.0 / maxf(1.0, w.f("rpm", 400.0)) * 2.0
	player.add_recoil(float(RECOIL.get(w.weapon_class(), 4.0)) * float(shots) * 0.5)


## Eight-Ping Benediction underbarrel: a rifle grenade (rocket-style projectile).
func _fire_underbarrel(w: WeaponInstance) -> void:
	if w.underbarrel_ammo <= 0:
		AudioDirector.play_2d("gun_dry", -4.0)
		_fire_cd = 0.3
		return
	var rg: Dictionary = GLData.table("weapons").get("rifle_grenade", {})
	w.underbarrel_ammo -= 1
	_fire_cd = 0.9
	_fired_this_frame = true
	var cam: Camera3D = player.camera
	var dir: Vector3 = _spread_dir(cam.global_basis, 0.5)
	var p: Projectile = Projectile.new()
	p.kind = &"rocket"
	p.weapon_id = w.id
	p.by_player = player.player_id
	p.velocity = dir * float(rg.get("speed", 30.0))
	p.exclude = [player.get_rid()]
	p.cfg = {"damage": float(rg.get("damage", 300)), "radius": float(rg.get("radius", 3.5)), "edge_mult": float(rg.get("edge_mult", 0.3)),
		"self_damage_near": float(rg.get("self_damage", 50)), "self_near_m": float(rg.get("self_radius", 3.0)), "self_damage_far": 0,
		"sound": "explosion_large"}
	player.get_parent().add_child(p)
	p.global_position = cam.global_position + dir * 0.7
	_report_fire(1, w.id, cam.global_position, cam.global_position + dir * 2.0)
	_vm_kick(1.6)
	player.add_recoil(3.0)
	AudioDirector.play_2d("gun_launcher", -4.0, 0.1)
	_glassy_layer(w)


## Per-zombie on-hit bonuses for upgraded bullets.
func _on_hit_effects(w: WeaponInstance, z: Zombie, limb: StringName, killed: bool, head_pos: Vector3) -> void:
	if not w.kit.is_empty():
		var eye: Vector3 = player.camera.global_position if player.camera != null else player.global_position
		WeaponKit.on_hit(w, z, killed, eye.distance_to(head_pos), player.player_id)
	if not w.upgraded:
		return
	var pid: int = player.player_id
	if killed:
		var pop: Variant = w.property("headshot_pop")
		if pop is Dictionary and limb == &"head":
			var pd: Dictionary = pop
			Explosion.detonate(player, head_pos, {"damage": float(pd.get("dmg", 300)), "radius": float(pd.get("r", 2.0)),
				"edge_mult": 0.5, "self_damage_near": 0, "self_damage_far": 0, "sound": "headshot", "sound_db": -2.0}, pid, w.id)
		return
	var inc: Variant = w.property("incendiary")
	if inc is Dictionary:
		z.ignite(float((inc as Dictionary).get("dps", 60)), float((inc as Dictionary).get("dur", 3.0)), pid)
	var frost: Variant = w.property("frost")
	if frost is Dictionary:
		z.apply_frost(float((frost as Dictionary).get("slow", 0.3)), float((frost as Dictionary).get("dur", 2.0)))
	if randf() < float(w.property("stagger", 0.0)):
		z.force_stagger()
	if randf() < float(w.property("sever_chance", 0.0)):
		z.become_crawler()
	if w.has_property("hollow_point") and limb == &"legs" and randf() < 0.35:
		z.become_crawler()


## Last Rites: each round bounces once toward the nearest other zombie within 8 m, at 50% damage.
func _ricochet(w: WeaponInstance, hits: Dictionary) -> void:
	var cfg: Dictionary = GLData.table("weapons").get("ricochet", {})
	var radius: float = float(cfg.get("radius", 8.0))
	var mult: float = float(cfg.get("mult", 0.5))
	var origin: Vector3 = _last_impact
	var best: Zombie = null
	var best_d: float = radius
	for z: Zombie in _director_zombies():
		if hits.has(z):
			continue
		var d: float = origin.distance_to(z.global_position + Vector3.UP)
		if d < best_d:
			best_d = d
			best = z
	if best == null:
		return
	var killed: bool = best.take_damage(w.f("damage", 120.0) * mult, &"torso", w.id, player.player_id, &"bullet")
	GLBus.enemy_hit_feedback.emit(player.player_id, killed, false)
	Effects.tracer(origin, best.global_position + Vector3.UP)
	Effects.blood(best.global_position + Vector3.UP * 1.2, Vector3.UP)


## Furnace Warrant: leaves a patch of burning ground where the stream lands.
func _spawn_burning_ground(w: WeaponInstance, from: Vector3, fwd: Vector3, reach: float) -> void:
	var bg: Variant = w.property("burning_ground")
	if not (bg is Dictionary):
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var aim_end: Vector3 = from + fwd * reach
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, aim_end, 1)
	var hit: Dictionary = space.intersect_ray(q)
	var point: Vector3 = hit["position"] if not hit.is_empty() else aim_end
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 4.0, 1)
	var floor_hit: Dictionary = space.intersect_ray(down)
	if floor_hit.is_empty():
		return
	var g: BurningGround = BurningGround.new()
	g.dps = float((bg as Dictionary).get("dps", 150))
	g.duration = float((bg as Dictionary).get("dur", 4.0))
	g.radius = float(GLData.table("weapons").get("burning_ground", {}).get("radius", 1.6))
	g.by_player = player.player_id
	g.weapon_id = w.id
	player.get_parent().add_child(g)
	g.global_position = floor_hit["position"]


## Upgraded weapons get a low glassy hum under every shot.
func _glassy_layer(w: WeaponInstance) -> void:
	if not w.upgraded:
		return
	var sl: Dictionary = GLData.table("weapons").get("sound_layer", {})
	var ap: AudioStreamPlayer = AudioDirector.play_2d(str(sl.get("name", "nachtglas_layer")), float(sl.get("db", -10.0)), 0.0)
	var pitch: float = float(sl.get("pitch", 1.0))
	if ap != null and pitch != 1.0:   # 1.0 keeps the bank's own pitch range
		ap.pitch_scale = pitch


func _spread_dir(basis: Basis, spread: float) -> Vector3:
	var fwd: Vector3 = -basis.z
	if spread <= 0.001:
		return fwd
	var r: float = sqrt(randf()) * deg_to_rad(spread)
	var a: float = randf() * TAU
	return (fwd + basis.x * sin(a) * tan(r) + basis.y * cos(a) * tan(r)).normalized()


var _last_impact: Vector3 = Vector3.ZERO


## One ray with penetration. Accumulates damage per zombie into `hits`.
func _trace(origin: Vector3, dir: Vector3, w: WeaponInstance, hits: Dictionary) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var pierce: int = int(w.data.get("penetration", 0)) + int(w.property("kit_penetration", 0))
	var from: Vector3 = origin
	var end_point: Vector3 = origin + dir * SHOT_RANGE
	var last_hit: Vector3 = end_point
	var fx: GunFx = GunFx.get_for(self)
	var passes: int = pierce + 1
	var decor_passes: int = 0
	while passes > 0:
		passes -= 1
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, end_point, MASK_SHOT, exclude)
		q.collide_with_areas = true
		var res: Dictionary = space.intersect_ray(q)
		if res.is_empty():
			break
		var pos: Vector3 = res["position"]
		last_hit = pos
		var col: Object = res["collider"]
		if DecorHit.is_decor(col):
			# set dressing that reacts (a bottle shatters, a lamp swings; T-053): local presentation, and the shot
			# carries on through it without spending a penetration
			DecorHit.hit(col, pos, dir)
			exclude.append((col as CollisionObject3D).get_rid())
			from = pos + dir * 0.02
			decor_passes += 1
			if decor_passes <= DecorHit.MAX_PER_SHOT:
				passes += 1
			continue
		if col is Hitbox:
			var hb: Hitbox = col as Hitbox
			var z: Zombie = hb.enemy as Zombie
			if z == null or not z.is_active():
				exclude.append(hb.get_rid())
				continue
			var mult: float = w.limb_mult(hb.limb)
			if hb.limb == &"head":
				mult *= float(PerkManager.stat(player.player_id, "head_damage_mult", 1.0))
			var dmg: float = w.f("damage", 50.0) * w.falloff(origin.distance_to(pos)) * mult
			var cur: Dictionary = hits.get(z, {"dmg": 0.0, "limb": "torso", "mult": 0.0})
			cur["dmg"] = float(cur["dmg"]) + dmg
			if mult > float(cur["mult"]):
				cur["mult"] = mult
				cur["limb"] = String(hb.limb)
				cur["bone"] = hb.bone
			hits[z] = cur
			if z.enemy_id == &"glasshide" and (hb.limb == &"torso" or hb.limb == &"arms"):
				if fx != null:
					fx.nachtglas_spark(pos, -dir)       # the crystal plates throw glints, not blood
			else:
				Effects.zombie_hit(pos, -dir, w.id, w.upgraded)   # T-095: blood + the Nachtglas spark on a taught gun
				if fx != null:
					fx.blood_mist(pos, -dir)
			for rid: RID in z.hitbox_rids():
				exclude.append(rid)
			from = pos + dir * 0.05
		else:
			var target: Node = shootable_of(col)
			if target != null:
				notify_shot(target, w.id, w.upgraded, player.player_id)
			var surf: String = GunFx.surface_of(col, pos, res["normal"], space)
			Effects.impact(pos, res["normal"], surf, col)
			if fx != null:
				fx.impact(pos, res["normal"], col, surf)
			break
	_last_impact = last_hit
	Effects.tracer(_muzzle_world().origin, last_hit)


## Quest objects (bells, the drummer) are Area3Ds on the hitbox layer with an on_shot() method on
## themselves or their parent. Returns that node, or null.
static func shootable_of(col: Object) -> Node:
	var n: Node = col as Node
	if n == null:
		return null
	if n.has_method("on_shot"):
		return n
	if n.get_parent() != null and n.get_parent().has_method("on_shot"):
		return n.get_parent()
	return null


static func notify_shot(target: Node, weapon_id: StringName, upgraded: bool, by_player: int) -> void:
	if Net.is_client():
		if Net.session != null:
			Net.session.send_shootable(target, weapon_id, upgraded)   # quest targets live on the host
		return
	target.call("on_shot", weapon_id, upgraded, by_player)
	var tid: StringName = StringName(str(target.get("target_id"))) if target.get("target_id") != null else StringName(target.name)
	GLBus.shootable_hit.emit(tid, weapon_id, upgraded, by_player)


# ---------------------------------------------------------------- Totenglocke (wind and toll, T-048)

## The bell's logic lives in Totenglocke (tap = toll, hold = wind for the Great Toll, alt = Bell Dome).
func _tick_bell(w: WeaponInstance, delta: float, held: bool, pressed: bool) -> void:
	bell_logic().tick(w, delta, held, pressed)


func bell_logic() -> Totenglocke:
	if _bell == null:
		_bell = Totenglocke.new(self)
	return _bell


func start_reload() -> void:
	var w: WeaponInstance = current()
	if w == null or _reloading or w.reserve <= 0 or w.mag >= w.mag_size() or _melee_t > 0.0:
		return
	if _sprinting and not sprint_reload_allowed(w):
		# Sprinting and reloading don't mix for this gun: remember the request and start when the sprint ends.
		# (An SMG, a pistol or a gun on a Paratrooper Sling reloads on the run, T-083.)
		_reload_queued = true
		return
	_reload_queued = false
	_reloading = true
	ads_t = minf(ads_t, 0.4)
	# Overclock Cordial: the start of any reload may release a static burst (once per reload, so a bolt or
	# shell-by-shell reload counts on its first round only; later rounds go through _tick_reload).
	PerkManager.overclock_reload(player, PerkManager.overclock_spent(w.mag, w.mag_size()))
	var mult: float = player.reload_mult() * float(w.property("reload_mult", 1.0))
	if bool(w.data.get("per_round_reload", false)) and not (w.mag == 0 and w.weapon_class() == &"bolt"):
		_reload_per_round = true
		_reload_t = w.f("reload_partial", 0.5) * mult
	else:
		_reload_per_round = false
		_reload_t = (w.f("reload_empty", 2.5) if w.mag == 0 else w.f("reload_partial", 2.0)) * mult
	_on_reload_started(w)
	_set_reload_cues()
	if WeaponKit.has_option(w, "mag", "drum"):
		AudioDirector.play_2d(WeaponKit.sound("drum_reload", "kit_drum_wind"), -4.0, 0.0)
	if _cues.is_empty():
		AudioDirector.play_2d("reload_start", -5.0)


func _tick_reload(delta: float, fire_pressed: bool) -> void:
	if not _reloading:
		return
	var w: WeaponInstance = current()
	if w == null:
		_cancel_reload()
		return
	if _reload_per_round and fire_pressed and w.mag > 0:
		_cancel_reload()
		return
	if _sprinting and not sprint_reload_allowed(w):
		# Sprint cancels the reload. Ammo only moves when a step completes, so nothing is lost or duplicated:
		# a magazine-style reload keeps the old mag's count, a round-by-round reload keeps the shells
		# already inserted (the one in hand goes back to the reserve). SMGs, pistols and slung guns carry on.
		_cancel_reload()
		return
	_reload_t -= delta
	_tick_reload_cues()
	if _reload_t > 0.0:
		return
	_flush_reload_cues()
	if _reload_per_round:
		var add: int = mini(1, w.reserve)
		w.mag += add
		w.reserve -= add
		if _cues.is_empty():
			AudioDirector.play_2d("reload_end", -8.0)
		if w.mag < w.mag_size() and w.reserve > 0:
			_reload_t = w.f("reload_partial", 0.5) * player.reload_mult() * float(w.property("reload_mult", 1.0))
			_on_round_loaded()
			_cue_i = 0
			return
	else:
		var take: int = mini(w.mag_size() - w.mag, w.reserve)
		w.mag += take
		w.reserve -= take
		if _cues.is_empty():
			AudioDirector.play_2d("reload_end", -4.0)
	_reloading = false
	_reload_per_round = false
	PerkManager.reload_finished(player.player_id)   # Trigger Tonic III's fresh clip
	_on_reload_finished()


func _cancel_reload() -> void:
	var was: bool = _reloading
	_reloading = false
	_reload_per_round = false
	# Pending cues (mag in, bolt forward...) must not play for a reload that never finished.
	_cues = []
	_cue_i = 0
	if was:
		_on_reload_cancelled()


## Picks the sound cues for the reload that just started (kind from the viewmodel, see RELOAD_CUES).
func _set_reload_cues() -> void:
	_cue_i = 0
	if _reload_per_round:
		_cues = RELOAD_CUES.get(_reload_kind + "_round", RELOAD_CUES.get(_reload_kind, [])) as Array
		return
	_cues = RELOAD_CUES.get(_reload_kind, []) as Array
	if _reload_started_empty and RELOAD_CUES.has(_reload_kind + "_empty"):
		_cues = _cues + (RELOAD_CUES[_reload_kind + "_empty"] as Array)


func _tick_reload_cues() -> void:
	if _cue_i >= _cues.size():
		return
	var p: float = 1.0 - _reload_t / maxf(0.05, _reload_total)
	while _cue_i < _cues.size() and p >= float((_cues[_cue_i] as Array)[0]):
		AudioDirector.play_2d(str((_cues[_cue_i] as Array)[1]), -4.0)
		_cue_i += 1


## A reload can finish within one long frame: play whatever cues are still pending.
func _flush_reload_cues() -> void:
	while _cue_i < _cues.size():
		AudioDirector.play_2d(str((_cues[_cue_i] as Array)[1]), -4.0)
		_cue_i += 1


# ---------------------------------------------------------------- melee

func _melee_data() -> Dictionary:
	return GLData.table("weapons")["melee"][String(melee_id)]


func _tick_melee(delta: float, pressed: bool) -> void:
	if _melee_t > 0.0:
		_melee_t -= delta
		var md: Dictionary = _melee_data()
		if _melee_hit_pending and _melee_t <= float(md["swing"]) - 0.13:
			_melee_hit_pending = false
			_melee_strike(md)
		return
	if not pressed or _cooking:
		return
	var md2: Dictionary = _melee_data()
	_cancel_reload()
	_melee_t = float(md2["swing"])
	_melee_hit_pending = true
	AudioDirector.play_2d("knife_swing", -4.0)
	_report_fire(3, melee_id, player.camera.global_position, player.camera.global_position - player.camera.global_basis.z)
	var target: Zombie = _melee_target(float(md2["lunge_range"]), 40.0)
	if target != null:
		var d: float = player.global_position.distance_to(target.global_position)
		if d > float(md2["reach"]) * 0.8:
			player.lunge_toward(target.global_position, minf(float(md2["lunge_distance"]), d - 0.9))


func _melee_strike(md: Dictionary) -> void:
	var reach: float = float(md["reach"]) + 0.4
	var cos_arc: float = cos(deg_to_rad(float(md["arc_deg"]) * 0.5))
	var dmg: float = float(md["damage"])
	if GameState.player_has_trait(player.player_id, &"dutch"):
		dmg *= float(GLData.table("player")["traits"]["dutch_melee_mult"])
	dmg *= Muster.mult(_muster_pid(), "melee_damage_mult")   # Whetstone (T-079)
	var fwd: Vector3 = -player.global_basis.z
	var candidates: Array = []
	for z: Zombie in _director_zombies():
		var to_z: Vector3 = z.global_position - player.global_position
		var flat: Vector3 = Vector3(to_z.x, 0, to_z.z)
		if flat.length() > reach + 0.3 or absf(to_z.y) > 1.6:
			continue
		if flat.length() > 0.4 and fwd.dot(flat.normalized()) < cos_arc:
			continue
		candidates.append([flat.length(), z])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var hit_any: bool = false
	for i: int in mini(int(md["targets"]), candidates.size()):
		var z2: Zombie = candidates[i][1]
		var killed: bool = z2.take_damage(dmg, &"torso", melee_id, player.player_id, &"melee")
		GLBus.enemy_hit_feedback.emit(player.player_id, killed, false)
		Effects.blood(z2.global_position + Vector3.UP * 1.2, fwd)
		hit_any = true
	if hit_any:
		AudioDirector.play_2d("knife_hit", -2.0)


func _melee_target(max_range: float, cone_deg: float) -> Zombie:
	var best: Zombie = null
	var best_d: float = max_range
	var fwd: Vector3 = -player.camera.global_basis.z
	for z: Zombie in _director_zombies():
		var to_z: Vector3 = (z.global_position + Vector3.UP) - player.camera.global_position
		var d: float = to_z.length()
		if d < best_d and fwd.dot(to_z.normalized()) > cos(deg_to_rad(cone_deg)):
			best_d = d
			best = z
	return best


func _director_zombies() -> Array[Zombie]:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return []
	return dir.active_zombies()


# ---------------------------------------------------------------- grenades

func _tick_grenade(delta: float, held: bool) -> void:
	var cfg: Dictionary = GLData.table("weapons")["lethal"]["frag"]
	if _cooking:
		_cook_t += delta
		if _cook_t >= float(cfg["fuse"]):
			_cooking = false
			Explosion.detonate(player, player.global_position + Vector3.UP, cfg, player.player_id)
			return
		if not held:
			_cooking = false
			_throw(cfg)
		return
	if held and grenades > 0 and _melee_t <= 0.0:
		_cooking = true
		_cook_t = 0.0
		grenades -= 1
		_cancel_reload()
		AudioDirector.play_2d("grenade_pin", -4.0)


func _throw(cfg: Dictionary) -> void:
	var g: Grenade = Grenade.new()
	g.fuse = float(cfg["fuse"]) - _cook_t
	g.cfg = cfg
	g.by_player = player.player_id
	player.get_parent().add_child(g)
	var cam: Camera3D = player.camera
	g.global_position = cam.global_position - cam.global_basis.z * 0.6 + Vector3.DOWN * 0.1
	g.linear_velocity = -cam.global_basis.z * float(cfg["throw_speed"]) + Vector3.UP * 3.0 + player.velocity * 0.5
	g.add_collision_exception_with(player)
	_throw_t = 0.25
	_report_fire(4, &"frag", cam.global_position, cam.global_position - cam.global_basis.z)


# ---------------------------------------------------------------- viewmodel
# The viewmodel is a WeaponModels model held by two procedurally posed arms (two-bone IK to fixed
# shoulders). Reloads, bolt/pump cycling and slide blowback are procedural part animations driven by
# the gameplay timers above, which stay authoritative.

const SHOULDER_R: Vector3 = Vector3(0.24, -0.4, 0.16)
const SHOULDER_L: Vector3 = Vector3(-0.27, -0.48, 0.1)
const UPPER_ARM: float = 0.34
const FOREARM: float = 0.34

var _model: Node3D
var _parts: Dictionary = {}          # name -> Node3D (moving parts)
var _rest: Dictionary = {}           # name -> Transform3D
var _reload_kind: String = "mag"
var _reload_total: float = 1.0
var _reload_started_empty: bool = false
var _bolt_open: float = 0.0          # 0..1 (bolt rifles hold the bolt open while loading rounds)
var _cycle_t: float = 0.0            # post-shot bolt / pump cycle
var _cycle_total: float = 0.0
var _cycle_ejected: bool = false
var _blowback_t: float = 0.0
var _throw_t: float = 0.0
var _hand_r: Node3D
var _hand_l: Node3D
var _arm_r: Array[MeshInstance3D] = []
var _arm_l: Array[MeshInstance3D] = []
var _prop: Node3D                    # the thing in the support hand during a reload (mag, shell, clip, rocket)
var _prop_kind: String = ""
var _frag_prop: Node3D
var _debris: Array = []              # [{node, vel, floor_y, t}]
var _hip: Vector3 = Vector3(0.16, -0.19, -0.3)
var _hip_rot: Vector3 = Vector3.ZERO     # extra hip-only rotation (radians), from data vm_hip_rot
var _reload_tilt: float = 1.0            # how far the gun rolls toward the face while reloading (data vm_reload_tilt)
var _ads: Vector3 = Vector3(0.0, -0.06, -0.2)
var _ads_rot: Vector3 = Vector3.ZERO       # ADS turn that lines the front sight up with the rear (_compute_ads_pose)
## Tools only (ads_check, vm_shots): pose the viewmodel without sway, bob, breathing or kick.
var steady: bool = false
var _sprint_style: String = "rifle"
var _rig: Node3D                            # viewmodel-FOV scale node (see _build_viewmodel)
var _sprint_b: float = 0.0
var _crouch_b: float = 0.0
var _cook_b: float = 0.0
var _bob_amt: float = 0.0
var _idle_t: float = 0.0
var _tilt_s: float = 0.0
var _sway: Vector2 = Vector2.ZERO           # look-lag (yaw, pitch) radians
var _sway_v: Vector2 = Vector2.ZERO
var _vk_p: Vector3 = Vector3.ZERO           # shot kick / landing spring: position offset and velocity
var _vk_pv: Vector3 = Vector3.ZERO
var _vk_r: Vector3 = Vector3.ZERO           # ... and rotation offset (pitch, yaw, roll)
var _vk_rv: Vector3 = Vector3.ZERO
var _forearm_r: MeshInstance3D
var _forearm_l: MeshInstance3D
var _grip_r: Transform3D = Transform3D.IDENTITY   # firing-hand fist in model space
var _grip_r_radius: float = WeaponModels.HAND_R0
var _lh_axis: String = "z"
var _lh_radius: float = 0.024
const VM_LAYER: int = 1 << 19            # render layer 20: first-person viewmodel
const VM_COMPRESS: float = 0.25          # viewmodel shrink toward the eye (anti-clipping, see _update_rig_scale)
const WALL_PULL_REACH: float = 0.85      # wall closer than this along the view: the gun starts to pull back
const WALL_PULL_FULL: float = 0.4        # ... fully pulled back at this distance (the capsule radius is 0.35)
var _vm_compress: float = VM_COMPRESS
var _eye_off: Vector3 = Vector3.ZERO     # camera shake h/v offset: the point the rig is compressed toward
var _wall_b: float = 0.0
var _muzzle_proxy: Node3D                # top-level, at the true muzzle: hosts the flame particles
const FLASH_SCALE: Dictionary = {&"pistol": 0.7, &"smg": 0.85, &"assault": 0.95, &"rifle": 1.05, &"bolt": 1.1,
	&"sniper": 1.1, &"shotgun": 1.35, &"lmg": 1.15, &"launcher": 1.5, &"wonder": 1.2}


func _build_viewmodel() -> void:
	# Everything first-person lives under _rig, which is scaled (k, k, 1) in camera space. That projects
	# exactly like rendering the viewmodel with its own narrower FOV (data: feel.viewmodel_fov), so guns
	# keep the same size and framing whatever the FOV setting or ADS zoom, and the sight line (the camera
	# axis) is unaffected.
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_vm = Node3D.new()
	_vm.name = "Viewmodel"
	_rig.add_child(_vm)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.75, 0.4)
	_flash_light.omni_range = 7.0
	_flash_light.omni_attenuation = 1.4
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	_flash_light.light_cull_mask = 0xFFFFF & ~VM_LAYER    # lights the world, not the gun in your hands
	add_child(_flash_light)
	_muzzle_proxy = Node3D.new()
	_muzzle_proxy.name = "MuzzleProxy"
	_muzzle_proxy.top_level = true
	add_child(_muzzle_proxy)
	_hand_r = WeaponModels.build_hand(false)
	_hand_l = WeaponModels.build_hand(true)
	_rig.add_child(_hand_r)
	_rig.add_child(_hand_l)
	_forearm_r = WeaponModels.build_forearm()
	_forearm_l = WeaponModels.build_forearm()
	_rig.add_child(_forearm_r)
	_rig.add_child(_forearm_l)
	for i: int in 2:
		var a: MeshInstance3D = WeaponModels.build_limb(0.037 if i == 0 else 0.044, 0.044 if i == 0 else 0.05)
		_rig.add_child(a)
		_arm_r.append(a)
		var b: MeshInstance3D = WeaponModels.build_limb(0.037 if i == 0 else 0.044, 0.044 if i == 0 else 0.05)
		_rig.add_child(b)
		_arm_l.append(b)
	_frag_prop = WeaponModels.build(&"frag")
	_rig.add_child(_frag_prop)
	_frag_prop.hide()
	for n: Node in [_hand_r, _hand_l, _forearm_r, _forearm_l, _frag_prop]:
		_set_vm_layer(n)
	for a2: MeshInstance3D in _arm_r + _arm_l:
		_set_vm_layer(a2)
	_rebuild_gun()
	_rebuild_knife()
	_vm.position = _hip


func _rebuild_gun() -> void:
	if mirror or _vm == null:
		return
	if _gun != null:
		_gun.queue_free()
	_gun = Node3D.new()
	_gun.name = "Gun"
	_vm.add_child(_gun)
	_parts.clear()
	_rest.clear()
	_clear_prop()
	_bolt_open = 0.0
	_cycle_t = 0.0
	_bell_crank = null
	if _flame != null and is_instance_valid(_flame):
		_flame.queue_free()
	_flame = null
	var w: WeaponInstance = current()
	if w == null:
		# Empty hands (e.g. the only gun is in the Crucible): keep a muzzle node for effects.
		_model = null
		_muzzle = Node3D.new()
		_gun.add_child(_muzzle)
		_flash_mesh = Interactable.add_box(_muzzle, Vector3(0.01, 0.01, 0.01), Vector3.ZERO, Interactable.greybox_mat(Color(0, 0, 0)))
		_flash_mesh.hide()
		_flame = null
		return
	var camo: StringName = &"" if w.upgraded else ProfileSave.camo_for(w.base_id())
	_model = WeaponModels.build(w.base_id(), w.upgraded, camo, WeaponKitModels.look_of(w))
	_gun.add_child(_model)
	for part: String in ["Mag", "Bolt", "Slide", "Pump", "Cover", "Barrels", "Crank", "Rocket", "Valve"]:
		var n: Node3D = _model.get_node_or_null(part) as Node3D
		if n != null:
			_parts[part] = n
			_rest[part] = n.transform
	var bolt: Node3D = _parts.get("Bolt") as Node3D
	if bolt != null and bolt.get_node_or_null("Handle") != null:
		_parts["Handle"] = bolt.get_node("Handle")
		_rest["Handle"] = (_parts["Handle"] as Node3D).transform
	_bell_crank = _parts.get("Crank") as Node3D
	_reload_kind = str(_model.get_meta("reload", "mag"))
	_feel = feel_for(w)
	_hip = _v3(_feel.get("hip", [0.1, -0.1, -0.24]))
	_hip_rot = _v3(_feel.get("hip_rot", [0, 0, 0])) * (PI / 180.0)
	_reload_tilt = float(_feel.get("reload_tilt", 1.0))
	_sprint_style = str(_feel.get("sprint", "rifle"))
	_compute_ads_pose()
	_grip_r = _model.get_meta("grip_r", Transform3D(Basis(), Vector3(0, -0.04, 0.05)))
	_grip_r_radius = float(_model.get_meta("grip_r_radius", WeaponModels.HAND_R0))
	_lh_axis = str(_model.get_meta("lh_axis", "z"))
	_lh_radius = float(_model.get_meta("lh_radius", 0.024))
	(_hand_r.get_node("Mesh") as MeshInstance3D).mesh = WeaponModels.hand_mesh(false, _grip_r_radius)
	(_hand_l.get_node("Mesh") as MeshInstance3D).mesh = WeaponModels.hand_mesh(true, _lh_radius)
	_muzzle = _model.get_node("Muzzle") as Node3D
	# One flash mesh per gun, reused for every shot (re-aimed and re-scaled per shot in _on_shot_fx).
	_flash_t = 0.0
	_flash_mesh = MeshInstance3D.new()
	_flash_mesh.name = "Flash"
	_flash_mesh.mesh = WeaponModels.muzzle_flash_mesh()
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mesh.set_meta("size", float(FLASH_SCALE.get(w.weapon_class(), 1.0)) * WeaponKitModels.flash_scale(w))
	_muzzle.add_child(_flash_mesh)
	_flash_mesh.hide()
	_flame = CPUParticles3D.new()
	_flame.emitting = false
	_flame.amount = 60
	_flame.lifetime = 0.35
	_flame.direction = Vector3(0, 0, -1)
	_flame.spread = 8.0
	_flame.initial_velocity_min = 14.0
	_flame.initial_velocity_max = 20.0
	_flame.gravity = Vector3(0, 1.5, 0)
	_flame.scale_amount_min = 0.6
	_flame.scale_amount_max = 2.2
	var fm: SphereMesh = SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.24
	fm.material = Interactable.greybox_mat(Color(1.0, 0.5, 0.15), 6.0)
	_flame.mesh = fm
	_flame.local_coords = false
	_flame.name = "Flame"
	_set_vm_layer(_model)
	_muzzle_proxy.add_child(_flame)   # a world effect (layer 1): lit by the flash light, depth-tested against walls
	# The Nachtglas glow lives in compressed space; shrink its reach to match.
	var glow: OmniLight3D = _model.get_node_or_null("Nachtglow") as OmniLight3D
	if glow != null:
		glow.omni_range = 0.7 * _vm_compress
	# Empty Garand: the clip is gone and the bolt is locked back until a new en-bloc goes in.
	if _reload_kind == "enbloc" and w.mag == 0 and _parts.has("Mag"):
		(_parts["Mag"] as Node3D).hide()


## ADS pose (T-047): the gun is placed so its SightPoint marker sits exactly on the camera's center ray at
## the weapon's eye relief (data: weapons.json feel.eye_relief), turned so its FrontSight marker lies on the
## same ray. Nothing else offsets the aimed pose: a model only has to build its sights with the WeaponModels
## sight helpers. The viewmodel FOV scale and the anti-clipping compression (_update_rig_scale) scale about
## the eye, which maps the center ray onto itself, so they cannot move the sight picture.
func _compute_ads_pose() -> void:
	var marks: Array = sight_marks_model()
	var sight: Vector3 = marks[0]
	var d: Vector3 = (marks[1] as Vector3) - sight
	var relief: float = maxf(0.05, float(_feel.get("eye_relief", 0.25)))
	var b: Basis = Basis.IDENTITY
	if d.length() > 0.01:
		b = Basis.looking_at(d.normalized(), Vector3.UP).inverse()   # sight line (rear -> front) onto -Z, no roll
	_ads_rot = b.get_euler()
	_ads = Vector3(0, 0, -relief) - b * sight


## The held model's [SightPoint, FrontSight] in model space. `rest`: as built (moving parts at rest), else
## as they are this frame. Without markers (no gun): a point above the grip and one straight ahead.
func sight_marks_model(rest: bool = true) -> Array:
	var out: Array = [Vector3(0, 0.05, 0), Vector3(0, 0.05, -0.5)]
	if _model == null:
		return out
	var names: Array = ["SightPoint", "FrontSight"]
	for i: int in 2:
		var n: Node3D = _model.find_child(names[i], true, false) as Node3D
		if n == null:
			continue
		var xf: Transform3D = n.transform
		var p: Node = n.get_parent()
		while p != null and p != _model:
			var pxf: Transform3D = (p as Node3D).transform
			if rest and _rest.has(String(p.name)):
				pxf = _rest[String(p.name)]
			xf = pxf * xf
			p = p.get_parent()
		out[i] = xf.origin
	return out


## Camera-space [SightPoint, FrontSight]. `live`: where the viewmodel draws them this frame (sway, kick and
## all); otherwise the pure ADS pose through the same rig transform (what the alignment math promises).
func sight_marks_camera(live: bool = false) -> Array:
	if _model == null or _rig == null:
		return []
	_update_rig_scale()
	var vm_xf: Transform3D = _vm.transform if live else Transform3D(Basis.from_euler(_ads_rot), _ads)
	var xf: Transform3D = _rig.transform * vm_xf * _gun.transform * _model.transform
	var m: Array = sight_marks_model(not live)
	return [xf * (m[0] as Vector3), xf * (m[1] as Vector3)]


## Pixel offset from the screen center (+x right, +y down) of a camera-space point, for a camera with vertical
## FOV `fov_deg` drawing `height` px tall (Camera3D keep-height). Used by the ADS checks.
static func project_offset_px(p: Vector3, fov_deg: float, height: float) -> Vector2:
	if p.z > -0.0001:
		return Vector2(INF, INF)
	var f: float = height * 0.5 / tan(deg_to_rad(fov_deg) * 0.5)
	return Vector2(p.x / -p.z, -p.y / -p.z) * f


func _rebuild_knife() -> void:
	if mirror or _rig == null:
		return
	if _knife != null:
		_knife.queue_free()
	_knife = WeaponModels.build(melee_id)
	_set_vm_layer(_knife)
	_rig.add_child(_knife)
	_knife.hide()


# ---- animation helpers

## 0..1 ramp of `p` across [a, b] with smoothstep easing.
static func _seg(p: float, a: float, b: float) -> float:
	return smoothstep(0.0, 1.0, clampf((p - a) / maxf(0.0001, b - a), 0.0, 1.0))


## Up-then-down bump across [a, b] (0 -> 1 -> 0).
static func _bump(p: float, a: float, b: float) -> float:
	var t: float = clampf((p - a) / maxf(0.0001, b - a), 0.0, 1.0)
	return sin(t * PI)


func _part(n: String) -> Node3D:
	return _parts.get(n) as Node3D


func _reset_parts() -> void:
	for k: Variant in _rest.keys():
		var n: Node3D = _parts[k] as Node3D
		if is_instance_valid(n):
			n.transform = _rest[k]


## Called by start_reload(): remember what kind of reload this is so the animation can match it.
func _on_reload_started(w: WeaponInstance) -> void:
	_reload_total = maxf(0.05, _reload_t)
	_reload_started_empty = w.mag == 0
	if _reload_kind == "bolt" or _reload_kind == "shell":
		_bolt_open = 1.0 if _reload_kind == "bolt" else 0.0
	_clear_prop()


func _on_round_loaded() -> void:
	_reload_total = maxf(0.05, _reload_t)
	_clear_prop()


## A reload was interrupted (sprint, melee, grenade, a shot during round-by-round loading): put the gun
## back the way its ammo says it is, e.g. the magazine dropped mid-reload is back in the well.
func _on_reload_cancelled() -> void:
	_clear_prop()
	var mag: Node3D = _part("Mag")
	if mag != null and is_instance_valid(mag):
		var w: WeaponInstance = current()
		mag.visible = not (_reload_kind == "enbloc" and w != null and w.mag == 0)


func _on_reload_finished() -> void:
	_clear_prop()
	if _reload_kind == "shell" and _reload_started_empty:
		_start_cycle(0.55)
		AudioDirector.play_2d("reload_pump", -4.0)
	if _reload_kind == "enbloc" and _parts.has("Mag"):
		(_parts["Mag"] as Node3D).show()


func _start_cycle(seconds: float) -> void:
	_cycle_total = seconds
	_cycle_t = seconds
	_cycle_ejected = false


## Post-shot mechanical feedback: bolt cycling, pumping, blowback, brass.
func _after_shot_anim(w: WeaponInstance) -> void:
	var mode: String = str(w.data.get("mode", "semi"))
	if mode == "bolt":
		_start_cycle(clampf(60.0 / maxf(1.0, w.f("rpm", 50.0)) * 0.9, 0.35, 1.1))
	elif mode == "pump":
		_start_cycle(clampf(60.0 / maxf(1.0, w.f("rpm", 60.0)) * 0.8, 0.3, 0.8))
	else:
		_blowback_t = 0.07
		if _model != null and _reload_kind in ["mag", "pistol", "drum", "belt", "enbloc"]:
			_eject_casing()
	if _reload_kind == "enbloc" and w.mag == 0 and _parts.has("Mag"):
		# The famous ping: the empty en-bloc flies out of the receiver.
		var clip: Node3D = _part("Mag")
		_spawn_debris(clip, Vector3(0.6, 2.4, 0.3), true)
		clip.hide()
		AudioDirector.play_2d("reload_clip_ping", 0.0, 0.0)


func _eject_casing() -> void:
	if _model == null or not is_inside_tree():
		return
	var kind: String = str(_feel.get("casing", "rifle"))
	if kind == "none":
		return
	var fx: GunFx = GunFx.get_for(self)
	if fx == null:
		return
	var gb: Basis = _vm_true_xf().basis * _model.global_basis
	var port: Vector3 = _model.get_meta("port", Vector3(0.012, 0.04, -0.03))
	var from: Vector3 = _vm_world(_model.global_transform * port)
	var right: Vector3 = gb.x.normalized()
	var up: Vector3 = gb.y.normalized()
	var back: Vector3 = gb.z.normalized()
	var vel: Vector3 = right * randf_range(1.6, 2.6) + up * randf_range(1.3, 2.2) + back * randf_range(-0.2, 0.5) + player.velocity
	fx.eject(kind, from, vel, Basis(right, up, back).orthonormalized() * Basis(Vector3.UP, PI * 0.5), current().id)


## Drops a copy of a part (empty mag, en-bloc clip, shells) that falls to the floor and disappears.
func _spawn_debris(src: Node3D, local_vel: Vector3, from_gun: bool) -> void:
	var host: Node = player.get_parent()
	if host == null or src == null:
		return
	var copy: Node3D = src.duplicate() as Node3D
	copy.show()
	_set_vm_layer(copy, 1)
	host.add_child(copy)
	copy.global_transform = Transform3D(src.global_basis.orthonormalized(), _vm_world(src.global_position))
	var basis: Basis = _vm_true_xf().basis * (_model.global_basis if from_gun and _model != null else global_basis)
	_debris.append({"node": copy, "vel": basis * local_vel + player.velocity, "floor_y": _floor_below(copy.global_position), "t": 2.0,
		"spin": Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))})


func _floor_below(p: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 4.0, 1)
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return float((res["position"] as Vector3).y) if not res.is_empty() else p.y - 4.0


func _tick_debris(delta: float) -> void:
	for i: int in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		var n: Node3D = d["node"] as Node3D
		d["t"] = float(d["t"]) - delta
		if not is_instance_valid(n) or float(d["t"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_debris.remove_at(i)
			continue
		var v: Vector3 = d["vel"]
		if n.global_position.y > float(d["floor_y"]) + 0.01:
			v.y -= 9.8 * delta
			n.global_position += v * delta
			n.rotation += (d["spin"] as Vector3) * delta
			if n.global_position.y < float(d["floor_y"]):
				n.global_position.y = float(d["floor_y"]) + 0.005
				v = Vector3.ZERO
		d["vel"] = v


## Puts a model of what the support hand is carrying into the scene (in the gun's space).
func _set_prop(kind: String) -> void:
	if _prop_kind == kind and _prop != null:
		return
	_clear_prop()
	_prop_kind = kind
	if _model == null:
		return
	match kind:
		"mag", "drum", "belt", "capsule":
			var src: Node3D = _part("Mag")
			if src != null:
				_prop = src.duplicate() as Node3D
		"shell":
			_prop = Node3D.new()
			var s: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.0105
			cm.bottom_radius = 0.0105
			cm.height = 0.065
			s.mesh = cm
			s.rotation_degrees = Vector3(90, 0, 0)
			s.material_override = WeaponModels.base_mat("red_paint")
			_prop.add_child(s)
			var cap: MeshInstance3D = MeshInstance3D.new()
			var cm2: CylinderMesh = CylinderMesh.new()
			cm2.top_radius = 0.0112
			cm2.bottom_radius = 0.0112
			cm2.height = 0.014
			cap.mesh = cm2
			cap.rotation_degrees = Vector3(90, 0, 0)
			cap.position = Vector3(0, 0, 0.03)
			cap.material_override = WeaponModels.base_mat("brass")
			_prop.add_child(cap)
		"rounds6":
			_prop = Node3D.new()
			# six revolver rounds in a ring (hand-loaded together), noses forward (-z)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				var at: Vector3 = Vector3(0.0112 * cos(a), 0.0112 * sin(a), 0.0)
				var body: MeshInstance3D = MeshInstance3D.new()
				var bm: CylinderMesh = CylinderMesh.new()
				bm.top_radius = 0.005
				bm.bottom_radius = 0.005
				bm.height = 0.02
				bm.radial_segments = 10
				body.mesh = bm
				body.rotation_degrees = Vector3(90, 0, 0)
				body.position = at
				body.material_override = WeaponModels.base_mat("brass")
				_prop.add_child(body)
				var nose: MeshInstance3D = MeshInstance3D.new()
				var nm: CylinderMesh = CylinderMesh.new()
				nm.top_radius = 0.0045
				nm.bottom_radius = 0.0022
				nm.height = 0.01
				nm.radial_segments = 10
				nose.mesh = nm
				nose.rotation_degrees = Vector3(90, 0, 0)
				nose.position = at + Vector3(0, 0, -0.015)
				nose.material_override = WeaponModels.base_mat("steel")
				_prop.add_child(nose)
		"clip":
			_prop = Node3D.new()
			# five rounds stacked in a stripper clip, pointing forward
			for i: int in 5:
				var r: MeshInstance3D = MeshInstance3D.new()
				var rm: CylinderMesh = CylinderMesh.new()
				rm.top_radius = 0.0055
				rm.bottom_radius = 0.0035
				rm.height = 0.075
				r.mesh = rm
				r.position = Vector3(0, i * 0.0095, -0.01)
				r.rotation_degrees = Vector3(90, 0, 0)
				r.material_override = WeaponModels.base_mat("brass")
				_prop.add_child(r)
			var strip: MeshInstance3D = MeshInstance3D.new()
			var sm2: BoxMesh = BoxMesh.new()
			sm2.size = Vector3(0.014, 0.05, 0.006)
			strip.mesh = sm2
			strip.position = Vector3(0, 0.019, 0.026)
			strip.material_override = WeaponModels.base_mat("blued")
			_prop.add_child(strip)
		"enbloc", "rocket":
			var src2: Node3D = _part("Mag") if kind == "enbloc" else _part("Rocket")
			if src2 != null:
				_prop = src2.duplicate() as Node3D
	if _prop != null:
		_prop.show()
		_set_vm_layer(_prop)
		_model.add_child(_prop)


func _clear_prop() -> void:
	if _prop != null and is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null
	_prop_kind = ""


## Puts viewmodel geometry on its own render layer so the muzzle-flash light can skip it.
static func _set_vm_layer(n: Node, layer: int = VM_LAYER) -> void:
	if n is VisualInstance3D and not (n is Light3D):
		(n as VisualInstance3D).layers = layer
	for c: Node in n.get_children():
		_set_vm_layer(c, layer)


## Muzzle flash for one shot: the single reused flash mesh gets a fresh random roll and size, then shows
## for `seconds`. Nothing re-randomizes it while it is up, so a shot reads as exactly one flash.
func _on_shot_fx(seconds: float) -> void:
	_flash_t = seconds
	if _flash_mesh == null or not is_instance_valid(_flash_mesh):
		return
	var k: float = float(_flash_mesh.get_meta("size", 1.0)) * randf_range(0.8, 1.15)
	_flash_mesh.transform = Transform3D(Basis(Vector3.BACK, randf() * TAU).scaled(Vector3(k, k, k * randf_range(0.75, 1.3))), Vector3(0, 0, -0.015))
	# T-095: Effects draws the first-person flash when vfx.json flash.first_person is "effects"; the holder's own star only otherwise
	if str((Effects.vfx.get("flash", {}) as Dictionary).get("first_person", "effects")) != "effects":
		_flash_mesh.show()
	if _model != null and _model.has_node("KitFlash"):
		M1911KitModels.pulse_flash(_model.get_node("KitFlash") as Node3D, seconds)


## Support-hand orientation for the held part: along the barrel (palm under, fingers up the right side)
## or an upright grip (palm on the left/back, fingers around the front).
func _lh_basis() -> Basis:
	if _lh_axis == "y":
		return Basis(Vector3.UP, 0.25)
	var b: Basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
	return Basis(Vector3.BACK, -0.45) * b


## Two-bone IK: returns the elbow position for a shoulder->hand chain with a pole direction.
static func _solve_elbow(shoulder: Vector3, hand: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d: Vector3 = hand - shoulder
	var dist: float = clampf(d.length(), 0.05, l1 + l2 - 0.001)
	var dir: Vector3 = d.normalized()
	var a: float = (l1 * l1 + dist * dist - l2 * l2) / (2.0 * dist)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var p: Vector3 = (pole - dir * pole.dot(dir))
	p = p.normalized() if p.length_squared() > 0.0001 else Vector3.DOWN
	return shoulder + dir * a + p * h


static func _place_limb(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var v: Vector3 = b - a
	var seg_len: float = maxf(0.01, v.length())
	var y: Vector3 = v / seg_len
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	m.transform = Transform3D(Basis(x, y * seg_len, z), (a + b) * 0.5)


## Poses one arm: hand at `hand_xf` (fist frame, see WeaponModels.hand_mesh), forearm cuff/rolled sleeve
## from the wrist toward the IK elbow, then sleeve limbs to the fixed shoulder.
func _pose_arm(hand_node: Node3D, limbs: Array[MeshInstance3D], forearm: MeshInstance3D, hand_xf: Transform3D,
		shoulder: Vector3, side: float, grip_radius: float) -> void:
	hand_node.transform = hand_xf
	var wrist: Vector3 = hand_xf * WeaponModels.hand_wrist(side < 0.0, grip_radius)
	var elbow: Vector3 = _solve_elbow(shoulder, wrist, UPPER_ARM, FOREARM, Vector3(side * 0.8, -1.0, 0.3))
	var dir: Vector3 = (elbow - wrist).normalized()
	var fx: Transform3D = WeaponModels._seg_xf(wrist, wrist + dir)
	forearm.transform = Transform3D(fx.basis, wrist)
	_place_limb(limbs[0], wrist + dir * WeaponModels.FOREARM_BARE, elbow)
	_place_limb(limbs[1], elbow, shoulder)


func _animate(delta: float, sprinting: bool) -> void:
	_tick_debris(delta)
	_update_rig_scale()
	_feel_rig(delta)
	var w: WeaponInstance = current()
	var ads_e: float = smoothstep(0.0, 1.0, ads_t)
	var hip_k: float = 1.0 - ads_e
	# ---- eased blends: sprint, crouch, grenade cook, reload tilt
	# sprint-out: the pose comes down over exactly the weapon's sprint-out time, so the gun is up when it can fire
	if sprinting:
		_sprint_b = move_toward(_sprint_b, 1.0, delta * 4.5)
	else:
		_sprint_b = minf(move_toward(_sprint_b, 0.0, delta * 6.5), _sprint_out_t / maxf(0.05, _sprint_out_total))
	var sprint_e: float = smoothstep(0.0, 1.0, _sprint_b)
	# Reloading on the run (T-083: SMGs, pistols, the Paratrooper Sling): the sprint pose gives most of itself up
	# to the reload (feel "sprint_reload_pose" = the share kept, 0.35) and the bob keeps running, eased by the
	# reload tilt (last frame's _tilt_s) so the gun never snaps between the two poses.
	if _reloading and sprint_e > 0.0:
		sprint_e *= lerpf(1.0, clampf(float(_feel.get("sprint_reload_pose", 0.35)), 0.0, 1.0), _tilt_s)
	_crouch_b = move_toward(_crouch_b, 1.0 if (player.crouching or player.sliding) else 0.0, delta * 4.0)
	var crouch_e: float = smoothstep(0.0, 1.0, _crouch_b) * hip_k
	_cook_b = move_toward(_cook_b, 1.0 if (_cooking or _throw_t > 0.0) else 0.0, delta * 7.0)
	# ---- walk bob on the footstep cadence (the gun dips on every footfall) + idle breathing
	var on_floor: bool = player.is_on_floor()
	var moving: float = clampf(player.horizontal_speed() / 5.0, 0.0, 1.2) if on_floor else 0.0
	_bob_amt = move_toward(_bob_amt, moving, delta * 5.0)
	var ph: float = player.step_phase() * PI
	var sw: float = sin(ph)
	var dip: float = 1.0 - absf(sw)
	var bob_k: float = _bob_amt * lerpf(1.0, 0.12, ads_e) * float(_feel.get("bob_mult", 1.0))
	var bob_pos: Vector3 = Vector3(sw * 0.009, -dip * 0.011 + 0.005, 0.0) * bob_k * (1.0 + sprint_e * 0.9)
	var bob_rot: Vector3 = Vector3(-dip * 0.012, sw * 0.012, sw * 0.022) * bob_k + Vector3(-dip * 0.03, sw * 0.06, sw * 0.05) * sprint_e * _bob_amt
	_idle_t += delta
	var idle_k: float = (1.0 - ads_e) * (1.0 - _bob_amt * 0.7)
	var breathe_pos: Vector3 = Vector3(sin(_idle_t * 0.83) * 0.0016, sin(_idle_t * 1.61) * 0.0022, 0.0) * idle_k
	var breathe_rot: Vector3 = Vector3(sin(_idle_t * 1.21) * 0.004, sin(_idle_t * 0.7) * 0.005, 0.0) * idle_k
	# ---- look sway: the gun lags behind fast turns on a spring and overshoots a little when you stop
	var rate: Vector2 = _look_in / maxf(delta, 0.001)
	_look_in = Vector2.ZERO
	# ADS sway (T-047) scales with the weapon's "sway" stat (x the perk sway_mult): aimed, the turn lag is a
	# fraction of the hip's, and the gun traces a slow figure-8 (idle) / a stride-paced one (walking).
	var ads_sway: float = 0.3 if w == null else w.f("sway", 0.3) * float(PerkManager.stat(player.player_id, "sway_mult", 1.0))
	var sway_k: float = lerpf(1.0, 0.3 * ads_sway, ads_e) * float(_feel.get("sway_mult", 1.0))
	var idle8: Vector2 = Vector2(sin(_idle_t * 0.9), sin(_idle_t * 1.8) * 0.5) * 0.005 * (1.0 - _bob_amt * 0.6)
	var walk8: Vector2 = Vector2(sin(ph), sin(ph * 2.0) * 0.5) * 0.028 * _bob_amt
	var s8: Vector2 = (idle8 + walk8) * ads_sway * ads_e * float(_feel.get("ads_sway_mult", 1.0))
	var target: Vector2 = (rate * 0.000045 * sway_k).limit_length(0.075)
	var spr: Array = _spring2(_sway, _sway_v, target, 13.0, 0.55, delta)
	_sway = spr[0]
	_sway_v = spr[1]
	# ---- shot kick + landing dip: spring-damper offsets (position and rotation)
	var kw: float = float(_feel.get("vm_spring", 20.0))
	var kz: float = float(_feel.get("vm_damp", 0.55))
	var r1: Array = _spring3(_vk_p, _vk_pv, kw, kz, delta)
	_vk_p = r1[0]
	_vk_pv = r1[1]
	var r2: Array = _spring3(_vk_r, _vk_rv, kw * 0.9, kz, delta)
	_vk_r = r2[0]
	_vk_rv = r2[1]
	# ---- base pose: hip <-> ADS, sprint, crouch
	var pos: Vector3 = _hip.lerp(_ads, ads_e)
	var rot: Vector3 = _hip_rot.lerp(_ads_rot, ads_e)
	pos += _v3(_feel.get("sprint_pos", [-0.03, -0.035, 0.02])) * sprint_e
	rot += _v3(_feel.get("sprint_rot", [-18, 34, 16])) * (PI / 180.0) * sprint_e
	pos += Vector3(-0.012, -0.008, 0.008) * crouch_e
	rot += Vector3(0.0, 0.02, 0.09) * crouch_e
	# ---- swap: the new gun rises from below the frame
	if _swap_t > 0.0:
		var k: float = clampf(_swap_t / SWAP_TIME, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		pos += Vector3(0.02, -0.17, 0.05) * k
		rot += Vector3(-0.85, 0.15, 0.35) * k
	_reset_parts()
	if _bell != null:
		_bell.pose_parts(_bell_crank, _model)   # wind-up crank spin, the bell's ring-out vibration
	var lh_override: Variant = null      # support-hand target in gun space, if a reload moves it
	var tilt: float = 0.0
	if _reloading and w != null:
		var p: float = 1.0 - _reload_t / maxf(0.05, _reload_total)
		lh_override = _animate_reload(p)
		tilt = _seg(p, 0.0, 0.14) * (1.0 - _seg(p, 0.84, 1.0))
		if _reload_per_round:
			tilt = 1.0
	else:
		_clear_prop()
		if _bolt_open > 0.0:
			_bolt_open = maxf(0.0, _bolt_open - delta * 4.0)
	_tilt_s = move_toward(_tilt_s, tilt, delta * 5.0) if tilt < _tilt_s else tilt
	# Reload: the gun rolls toward the face and comes up and in a little, so the mag well / port reads,
	# with the muzzle kept pointing up-forward rather than at the sky.
	var rl: Vector3 = _v3(_feel.get("reload_rot", [-4, 16, 30])) * (PI / 180.0)
	rot += rl * _tilt_s * _reload_tilt
	pos += _v3(_feel.get("reload_pos", [-0.035, 0.03, 0.02])) * _tilt_s * _reload_tilt
	var cyc: float = _animate_cycle(delta)
	if cyc > 0.0:
		# working a bolt / pump: the gun cants and dips while the hand works it
		var ck: float = lerpf(1.0, 0.45, ads_e)
		rot += Vector3(-0.05, 0.06, 0.24) * cyc * ck
		pos += Vector3(-0.008, -0.014, 0.012) * cyc * ck
	pos += Vector3(0.0, -0.09, 0.03) * _cook_b
	rot += Vector3(-0.35, 0.1, 0.0) * _cook_b
	# facing a wall: ease the gun back and tip the muzzle up. Aiming only draws it back a little along the
	# sight line, so the sight picture stays lined up.
	var wall_k: float = _tick_wall_pull(delta)
	pos += Vector3(-0.01 * hip_k, -0.025 * hip_k, 0.06 * lerpf(1.0, 0.35, ads_e)) * wall_k
	rot += Vector3(0.22, 0.12, 0.08) * wall_k * hip_k * float(_feel.get("wall_rot", 1.0))   # launchers: less, so the shield stays out of view
	_rig.visible = not scoped()
	_vm.position = pos + bob_pos + breathe_pos + _vk_p + Vector3(-_sway.x * 0.045, _sway.y * 0.04, 0.0)
	_vm.rotation = rot + bob_rot + breathe_rot + _vk_r + Vector3(_sway.y * 0.8, _sway.x * 0.8, _sway.x * 0.6)
	_vm.rotation += Vector3(s8.y, s8.x, 0.0)                     # ADS figure-8 (pitch, yaw)
	if steady:   # check tools (ads_check): the bare pose, no sway / bob / breathing / kick
		_vm.position = pos
		_vm.rotation = rot
	# ---- arms
	var melee: bool = _melee_t > 0.0
	_gun.visible = not melee
	if melee:
		var md: Dictionary = _melee_data()
		var mp: float = 1.0 - _melee_t / float(md["swing"])
		_knife.show()
		_knife.position = Vector3(lerpf(0.32, -0.12, mp), lerpf(-0.12, -0.2, mp), lerpf(-0.32, -0.45, _bump(mp, 0.2, 0.8)))
		_knife.rotation = Vector3(lerpf(-0.1, -0.35, mp), lerpf(1.0, -1.1, mp), lerpf(0.3, -0.5, mp))
		_pose_arm(_hand_r, _arm_r, _forearm_r, _knife.transform * Transform3D(Basis(Vector3.RIGHT, -1.45), Vector3(0, 0.0, 0.035)),
			SHOULDER_R, 1.0, 0.013)
	else:
		_knife.hide()
		if _model != null:
			var grip: Transform3D = _grip_r
			var handle: Node3D = _part("Handle")
			if handle != null and _reload_kind == "bolt" and _cycle_t > 0.0:
				# bolt action: the firing hand leaves the grip, works the handle, and comes back
				var cp: float = 1.0 - _cycle_t / maxf(0.01, _cycle_total)
				var reach: float = _seg(cp, 0.0, 0.16) * (1.0 - _seg(cp, 0.8, 1.0))
				var knob: Vector3 = (_model.global_transform.affine_inverse() * handle.global_transform) * Vector3(0.05, 0, 0)
				var at_bolt: Transform3D = Transform3D(Basis(Vector3.BACK, -1.35) * Basis(Vector3.UP, 0.4), knob + Vector3(0.012, 0.004, 0.006))
				grip = grip.interpolate_with(at_bolt, reach)
			_pose_arm(_hand_r, _arm_r, _forearm_r, _vm.transform * _gun.transform * _model.transform * grip, SHOULDER_R, 1.0, _grip_r_radius)
	# support hand: on the gun, carrying a reload prop, or holding the grenade
	var lh: Transform3D
	if _cooking or _throw_t > 0.0:
		_throw_t = maxf(0.0, _throw_t - delta)
		var back: float = 1.0 if _cooking else _throw_t / 0.25
		# cooking: the grenade is held up on the left, then the arm snaps forward on the throw
		lh = Transform3D(Basis.from_euler(Vector3(0.5, 0.35, 0.25)), Vector3(lerpf(-0.05, -0.095, back), lerpf(-0.02, -0.07, back), lerpf(-0.5, -0.26, back)))
		_frag_prop.show()
		_frag_prop.transform = lh * Transform3D(Basis(), Vector3(-0.01, 0.03, -0.03))
		_hand_l.visible = true
	else:
		_frag_prop.hide()
		var gun_xf: Transform3D = _vm.transform * _gun.transform
		if _model != null:
			gun_xf = gun_xf * _model.transform
			var lh_local: Vector3 = (_model.get_node("LeftHand") as Node3D).position
			var pump: Node3D = _part("Pump")
			if pump != null:
				lh_local += pump.position - (_rest["Pump"] as Transform3D).origin
			if lh_override != null:
				lh_local = lh_override
			lh = gun_xf * Transform3D(_lh_basis(), lh_local)
		else:
			lh = Transform3D(Basis(), Vector3(-0.2, -0.35, -0.2))
		if melee:
			lh = Transform3D(Basis(), Vector3(-0.22, -0.32, -0.25))
	_pose_arm(_hand_l, _arm_l, _forearm_l, lh, SHOULDER_L, -1.0, _lh_radius if not (_cooking or _throw_t > 0.0) else 0.03)
	_hand_r.visible = _model != null or melee
	_forearm_r.visible = _hand_r.visible
	for a: MeshInstance3D in _arm_r:
		a.visible = _hand_r.visible
	# ---- Nachtglas: the upgraded glow breathes
	if _model != null and _model.has_node("Nachtglow"):
		# Omni falloff is in absolute units, so in compressed space the same glow is far too strong on the
		# sleeve. compress^2 matches the uncompressed render (checked side by side with vm_shots --compress=1).
		var glow: OmniLight3D = _model.get_node("Nachtglow") as OmniLight3D
		glow.light_energy = (0.32 + 0.16 * sin(_idle_t * 2.3) + _flash_t * 6.0) * _vm_compress * _vm_compress
		var cw: WeaponInstance = current()
		if cw != null and cw.tier >= 2:   # re-taught (T-037): the veins run amber at II and white-hot at III
			glow.light_color = Color(1.0, 0.62, 0.3) if cw.tier == 2 else Color(1.0, 0.92, 0.85)
			glow.light_energy *= 1.4
	# ---- flamethrower stream
	var flaming: bool = _flame != null and is_instance_valid(_flame) and _flame_t > 0.0
	var mxf: Transform3D = _muzzle_world() if (_flash_t > 0.0 or flaming) else global_transform.orthonormalized()
	if flaming:
		# the proxy keeps the old (uncompressed) scale so the stream's size and speed are unchanged
		_muzzle_proxy.global_transform = Transform3D(_vm_true_xf().basis * _muzzle.global_basis, mxf.origin)
	if _flame != null and is_instance_valid(_flame):
		_flame_t -= delta
		_flame.emitting = _flame_t > 0.0
		if _flame_t > 0.0:
			_flash_light.global_position = mxf.origin - mxf.basis.z
			_flash_light.light_energy = 3.0
	# ---- muzzle flash
	if _flash_t > 0.0:
		_flash_t -= delta
		# Ahead of the muzzle so it lights the world, not the gun's own top surfaces.
		_flash_light.global_position = mxf.origin - mxf.basis.z * 0.6
		_flash_light.light_energy = float(_feel.get("flash_light", 2.0)) * clampf(_flash_t / 0.03, 0.3, 1.0)
		if _flash_t <= 0.0:
			_flash_mesh.hide()
	else:
		_flash_mesh.hide()
		if _flame_t <= 0.0:
			_flash_light.light_energy = 0.0


# ---- feel: data lookup, springs, shot feedback

## Resolved feel / viewmodel tuning for a weapon: data/weapons.json feel.classes[<class>], overlaid by the
## base row's "feel" and then the upgraded row's "feel". Legacy vm_hip / vm_hip_rot / vm_reload_tilt keys
## on the base row still apply.
static func feel_for(w: WeaponInstance) -> Dictionary:
	var t: Dictionary = GLData.table("weapons")
	var root: Dictionary = t.get("feel", {})
	var out: Dictionary = {}
	var classes: Dictionary = root.get("classes", {})
	out.merge(classes.get("default", {}) as Dictionary, true)
	out.merge(classes.get(String(w.weapon_class()), {}) as Dictionary, true)
	var base_row: Dictionary = (t["weapons"] as Dictionary).get(String(w.base_id()), {})
	if base_row.has("vm_hip"):
		out["hip"] = base_row["vm_hip"]
	if base_row.has("vm_hip_rot"):
		out["hip_rot"] = base_row["vm_hip_rot"]
	if base_row.has("vm_reload_tilt"):
		out["reload_tilt"] = base_row["vm_reload_tilt"]
	out.merge(base_row.get("feel", {}) as Dictionary, true)
	if w.upgraded:
		out.merge(w.data.get("feel", {}) as Dictionary, true)
	if not w.kit.is_empty():
		out.merge(w.kit_mods().get("feel", {}) as Dictionary, true)   # attachments (zoom, flash, sound)
	return out


static func _v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a as Array
	if arr == null or arr.size() < 3:
		return Vector3.ZERO
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


## Viewmodel FOV: scale the rig (k, k, 1) so it projects as if drawn with feel.viewmodel_fov.
## Anti-clipping (D-062): the whole rig is also shrunk uniformly toward the eye by VM_COMPRESS. A uniform
## scale about the projection center leaves every pixel where it was (x/z and y/z are unchanged), so the
## gun looks identical, but it now physically sits within ~0.25 m of the eye, inside the player's 0.35 m
## collision capsule, and the ordinary depth test keeps walls from cutting through it.
func _update_rig_scale() -> void:
	var cam_fov: float = 75.0
	if player != null and player.camera != null:
		cam_fov = player.camera.fov
	var feel_root: Dictionary = GLData.table("weapons").get("feel", {}) as Dictionary
	var vm_fov: float = float(feel_root.get("viewmodel_fov", 56.0))
	_vm_compress = clampf(float(feel_root.get("viewmodel_compress", VM_COMPRESS)), 0.05, 1.0)
	var k: float = tan(deg_to_rad(clampf(cam_fov, 20.0, 150.0)) * 0.5) / tan(deg_to_rad(vm_fov) * 0.5)
	_rig.scale = Vector3(k, k, 1.0) * _vm_compress
	# Camera shake moves the rendered eye by h/v_offset; shrink about that point, not the camera node, or the
	# compressed gun would shake 1/compress times harder than before.
	_eye_off = Vector3.ZERO
	if player != null and player.camera != null:
		_eye_off = Vector3(player.camera.h_offset, player.camera.v_offset, 0.0)
	# Aimed, the rig rides the shaken eye fully (T-047), so screen shake can't knock the sights off the
	# center ray; at the hip it keeps the D-062 behaviour.
	_rig.position = _eye_off * (1.0 - _vm_compress * (1.0 - smoothstep(0.0, 1.0, ads_t)))


## Maps compressed viewmodel space back to where the viewmodel visually is in the world (undoes the
## VM_COMPRESS shrink about the eye). World-space effects that start at the gun (tracers, smoke, brass,
## dropped mags, the flash light, the flame stream) use this so they keep their size and placement.
func _vm_true_xf() -> Transform3D:
	var eye: Transform3D = global_transform * Transform3D(Basis(), _eye_off)
	return eye * Transform3D(Basis.from_scale(Vector3.ONE / _vm_compress), Vector3.ZERO) * eye.affine_inverse()


## A viewmodel point (global, compressed) at its true world position, pulled back out of any wall between
## the eye and it, so effects never spawn on the far side of the geometry the player is pressed against.
func _vm_world(p_global: Vector3) -> Vector3:
	var p: Vector3 = _vm_true_xf() * p_global
	if not is_inside_tree():
		return p
	var eye: Vector3 = global_transform * _eye_off
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, p, 1)
	if player != null:
		q.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return p
	var to: Vector3 = (hit["position"] as Vector3) - eye
	return eye + to * maxf(0.0, 1.0 - 0.04 / maxf(0.04, to.length()))


## The muzzle at its true world position / orientation (unscaled basis), wall-clamped.
func _muzzle_world() -> Transform3D:
	if _muzzle == null or not is_instance_valid(_muzzle):
		return global_transform.orthonormalized()
	return Transform3D(_muzzle.global_basis.orthonormalized(), _vm_world(_muzzle.global_position))


## Wall proximity: one short ray along the view; the gun eases back and tips up when you face a wall.
func _tick_wall_pull(delta: float) -> float:
	var target: float = 0.0
	if is_inside_tree():
		var eye: Vector3 = global_transform * _eye_off
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye - global_basis.z.normalized() * WALL_PULL_REACH, 1)
		if player != null:
			q.exclude = [player.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var d: float = eye.distance_to(hit["position"] as Vector3)
			target = clampf((WALL_PULL_REACH - d) / (WALL_PULL_REACH - WALL_PULL_FULL), 0.0, 1.0)
	_wall_b = move_toward(_wall_b, target, delta * 4.0)
	return smoothstep(0.0, 1.0, _wall_b)


## Damped spring toward `target` (2D), angular frequency w, damping ratio z. Returns [x, v].
static func _spring2(x: Vector2, v: Vector2, target: Vector2, w: float, z: float, dt: float) -> Array:
	var n: int = 1 if dt <= 1.0 / 55.0 else ceili(dt * 60.0)
	var h: float = dt / float(n)
	for i: int in mini(n, 6):
		v += ((target - x) * w * w - v * 2.0 * z * w) * h
		x += v * h
	return [x, v]


## Damped spring back to zero (3D). Returns [x, v].
static func _spring3(x: Vector3, v: Vector3, w: float, z: float, dt: float) -> Array:
	var n: int = 1 if dt <= 1.0 / 55.0 else ceili(dt * 60.0)
	var h: float = dt / float(n)
	for i: int in mini(n, 6):
		v += (-x * w * w - v * 2.0 * z * w) * h
		x += v * h
	return [x, v]


## Everything a shot does to the player's view: camera kick (pitch + random yaw, part of it recovering on a
## spring), viewmodel kick-back / climb / roll on its own spring, shake and FOV punch, flash, smoke, brass.
func _shot_feedback(w: WeaponInstance) -> void:
	_kick = 1.0
	var f: Dictionary = _feel
	var ads_k: float = lerpf(1.0, float(f.get("ads_recoil", 0.65)), ads_t)
	# Aim recoil = the weapon's pattern (_apply_recoil_pattern); the camera kick on top is a short visual punch
	# that springs fully back (punch share of the feel numbers), and the viewmodel kick is separate again.
	var punch: float = float(recoil_cfg(w).get("punch", 0.45))
	player.kick_camera(float(f.get("cam_pitch", 1.0)) * ads_k * punch, float(f.get("cam_yaw", 0.3)) * ads_k * punch, 0.0,
		float(f.get("cam_recover", 12.0)), float(f.get("shake", 0.05)) * ads_k, float(f.get("fov_punch", 0.5)) * ads_k)
	_apply_recoil_pattern(w, ads_k)
	_vm_kick(1.0)
	_on_shot_fx(float(f.get("flash_time", 0.05)))
	if bool(f.get("smoke", false)) and _muzzle != null and is_inside_tree():
		var fx: GunFx = GunFx.get_for(self)
		if fx != null:
			var mx: Transform3D = _muzzle_world()
			fx.smoke(mx.origin - mx.basis.z * 0.05, -mx.basis.z, float(f.get("smoke_k", 1.0)))


## Viewmodel kick impulse (scaled by `strength`): back along the barrel, muzzle climb, random roll / yaw.
func _vm_kick(strength: float) -> void:
	var f: Dictionary = _feel
	var ads_k: float = lerpf(1.0, float(f.get("ads_kick", 0.5)), ads_t) * strength
	var wv: float = float(f.get("vm_spring", 20.0))
	var amp: float = wv * 1.15 * ads_k   # velocity impulse: peak displacement ~= vm_back at vm_damp 0.5
	var back: float = float(f.get("vm_back", 0.03))
	var climb: float = deg_to_rad(float(f.get("vm_climb", 4.0)))
	var roll: float = deg_to_rad(float(f.get("vm_roll", 2.0)))
	_vk_pv += Vector3(randf_range(-0.15, 0.15) * back, back * float(f.get("vm_lift", 0.12)), back) * amp
	_vk_rv += Vector3(climb, randf_range(-0.4, 0.4) * roll, randf_range(-1.0, 1.0) * roll) * amp


## Resolved recoil pattern for a weapon: weapons.json recoil.classes.default < classes[<class>] <
## recoil.weapons[<base id>] < the weapon row's "recoil" (base row, then the upgraded row).
static func recoil_for(w: WeaponInstance) -> Dictionary:
	var t: Dictionary = GLData.table("weapons")
	var root: Dictionary = t.get("recoil", {})
	var classes: Dictionary = root.get("classes", {})
	var out: Dictionary = {}
	out.merge(classes.get("default", {}) as Dictionary, true)
	out.merge(classes.get(String(w.weapon_class()), {}) as Dictionary, true)
	out.merge((root.get("weapons", {}) as Dictionary).get(String(w.base_id()), {}) as Dictionary, true)
	var base_row: Dictionary = (t["weapons"] as Dictionary).get(String(w.base_id()), {})
	out.merge(base_row.get("recoil", {}) as Dictionary, true)
	if w.upgraded:
		out.merge(w.data.get("recoil", {}) as Dictionary, true)
	if not w.kit.is_empty():
		out = WeaponKit.apply_recoil(out, w)   # attachments (compensator, stock, bipod)
	return out


func recoil_cfg(w: WeaponInstance) -> Dictionary:
	if w == null:
		return {}
	var key: StringName = StringName(String(w.id) + w.kit_sig())
	if key != _recoil_id:
		_recoil_id = key
		_recoil = recoil_for(w)
	return _recoil


## The per-weapon recoil pattern (deterministic per shot index; separate from the viewmodel's visual kick):
## shot i climbs v x min(v_max_mult, 1 + v_growth x i) degrees, swings sideways along h_swing x sin(i x h_freq
## + phase) plus a small random +-h, and (1 - keep) of the burst drifts back after recover_delay. The index
## resets after `reset` seconds without a shot.
func _apply_recoil_pattern(w: WeaponInstance, ads_k: float) -> void:
	var rc: Dictionary = recoil_cfg(w)
	if _since_shot > float(rc.get("reset", 0.35)):
		_shot_i = 0
	var i: float = float(_shot_i)
	var v: float = float(rc.get("v", 0.6)) * minf(float(rc.get("v_max_mult", 1.5)), 1.0 + float(rc.get("v_growth", 0.0)) * i)
	var phase: float = float(absi(hash(String(w.base_id()))) % 628) * 0.01
	var h: float = float(rc.get("h_swing", 0.0)) * sin(i * float(rc.get("h_freq", 0.7)) + phase) + randf_range(-1.0, 1.0) * float(rc.get("h", 0.15))
	var crouch_k: float = float(rc.get("crouch_mult", 0.85)) if (player.crouching or player.prone) else 1.0
	crouch_k *= float(PerkManager.stat(player.player_id, "recoil_mult", 1.0))   # Twin Barrel II (T-075)
	player.apply_recoil_pattern(v * ads_k * crouch_k, h * ads_k * crouch_k, float(rc.get("keep", 0.3)), float(rc.get("recover", 7.0)),

		float(rc.get("recover_delay", 0.12)))
	_shot_i += 1
	_since_shot = 0.0


## Hip bloom: grows with each shot (recoil "bloom"), holds while you keep firing, then shrinks: fast standing
## still, slower on the move, faster again crouched.
func _tick_bloom(delta: float) -> void:
	if bloom <= 0.0 or _since_shot < 0.09:
		return
	var rc: Dictionary = recoil_cfg(current())
	var still: bool = player == null or player.horizontal_speed() < 0.6
	var rate: float = float(rc.get("bloom_still", 9.0)) if still else float(rc.get("bloom_move", 4.5))
	if player != null and (player.crouching or player.prone):
		rate *= 1.4
	bloom = move_toward(bloom, 0.0, rate * delta)


## Movement feel on the whole first-person rig (on top of the hip / ADS pose, so the sight picture is untouched
## when aimed): weapon inertia (the gun lags changes of velocity), and the mantle dip / roll.
func _feel_rig(delta: float) -> void:
	if player == null or _rig == null:
		return
	var C: Dictionary = GLData.table("movement").get("camera", {})
	var hip_k: float = 1.0 - smoothstep(0.0, 1.0, ads_t)
	var dv: Vector3 = (player.velocity - _vel_prev)
	_vel_prev = player.velocity
	var local_dv: Vector3 = global_basis.inverse() * dv          # camera space: x right, y up, z back
	var push: Vector3 = Vector3(-local_dv.x, -local_dv.y * 0.6, -local_dv.z * 0.5) * float(C.get("inertia", 0.0042))
	_inertia_v += push * 40.0
	var r: Array = _spring3(_inertia, _inertia_v, 11.0, 0.7, delta)
	_inertia = (r[0] as Vector3).limit_length(float(C.get("inertia_max", 0.03)))
	_inertia_v = r[1]
	var mk: float = player.mantle_k() if player.has_method("mantle_k") else 0.0
	var off: Vector3 = (_inertia + Vector3(0.015, -0.07, 0.03) * mk) * hip_k
	_rig.position += off * _vm_compress
	_rig.rotation = Vector3(-0.35 * mk, 0.0, 0.25 * mk) * hip_k


## Jump take-off: the gun dips (and a hair of roll) on the same spring as the shot kick.
func on_jump() -> void:
	var wv: float = float(_feel.get("vm_spring", 20.0))
	var k: float = float((GLData.table("movement").get("jump", {}) as Dictionary).get("takeoff_dip", 0.6))
	_vk_pv += Vector3(0.0, -0.03, 0.006) * k * wv * 2.0
	_vk_rv += Vector3(-0.05, 0.0, -0.02) * k * wv * 2.0


## Landing: a dip proportional to the fall speed, on the same spring as the shot kick.
func on_landed(fall_speed: float) -> void:
	var k: float = clampf((fall_speed - 2.0) / 8.0, 0.0, 1.0)
	if k <= 0.0:
		return
	var wv: float = float(_feel.get("vm_spring", 20.0))
	_vk_pv += Vector3(0.0, -0.045, 0.01) * k * wv * 2.0
	_vk_rv += Vector3(-0.09, 0.0, 0.03) * k * wv * 2.0


## Bolt / pump cycling after a shot, and pistol slide blowback. Returns 0..1, how far into a bolt / pump
## stroke the hand is (the viewmodel cants with it).
func _animate_cycle(delta: float) -> float:
	var bolt: Node3D = _part("Bolt")
	var handle: Node3D = _part("Handle")
	var pump: Node3D = _part("Pump")
	var slide: Node3D = _part("Slide")
	var cp: float = -1.0
	if _cycle_t > 0.0:
		_cycle_t = maxf(0.0, _cycle_t - delta)
		cp = 1.0 - _cycle_t / maxf(0.01, _cycle_total)
	# bolt rifles: handle up, back, forward, down (also held open while loading)
	if bolt != null and (_reload_kind == "bolt"):
		var up: float = 0.0
		var back: float = 0.0
		if cp >= 0.0:
			up = _seg(cp, 0.05, 0.25) * (1.0 - _seg(cp, 0.75, 0.95))
			back = _seg(cp, 0.25, 0.45) * (1.0 - _seg(cp, 0.5, 0.72))
			if cp >= 0.45 and not _cycle_ejected:
				_cycle_ejected = true
				_eject_casing()
		up = maxf(up, _bolt_open)
		back = maxf(back, _bolt_open)
		bolt.position = (_rest["Bolt"] as Transform3D).origin + Vector3(0, 0, 0.075 * back)
		if handle != null:
			handle.rotation_degrees.z = lerpf((_rest["Handle"] as Transform3D).basis.get_euler().z * 57.2958, 25.0, up)
	if pump != null and cp >= 0.0:
		var pb: float = _seg(cp, 0.05, 0.4) * (1.0 - _seg(cp, 0.45, 0.85))
		pump.position = (_rest["Pump"] as Transform3D).origin + Vector3(0, 0, 0.09 * pb)
		if cp >= 0.4 and not _cycle_ejected:
			_cycle_ejected = true
			_eject_casing()
	if slide != null:
		var w: WeaponInstance = current()
		var locked: bool = w != null and w.mag == 0
		var sb: float = 1.0 if locked else 0.0
		if _blowback_t > 0.0:
			_blowback_t = maxf(0.0, _blowback_t - delta)
			sb = maxf(sb, sin((1.0 - _blowback_t / 0.07) * PI))
			slide.position = (_rest["Slide"] as Transform3D).origin + Vector3(0, 0, 0.03 * sb)
	elif _blowback_t > 0.0:
		_blowback_t = maxf(0.0, _blowback_t - delta)
		if bolt != null and _reload_kind != "bolt":
			bolt.position = (_rest["Bolt"] as Transform3D).origin + Vector3(0, 0, 0.03 * sin((1.0 - _blowback_t / 0.07) * PI))
	if cp >= 0.0 and (pump != null or (bolt != null and _reload_kind == "bolt")):
		return _bump(cp, 0.0, 1.0)
	return 0.0


## Reload part animation for progress p (0..1). Returns the support hand's target in gun space,
## or null to keep it on the weapon.
func _animate_reload(p: float) -> Variant:
	var mag: Node3D = _part("Mag")
	var lh_home: Vector3 = (_model.get_node("LeftHand") as Node3D).position
	var pouch: Vector3 = Vector3(-0.05, -0.35, 0.15)
	match _reload_kind:
		"mag", "pistol", "drum", "capsule":
			if mag == null:
				return null
			var mrest: Vector3 = (_rest["Mag"] as Transform3D).origin
			var out_dir: Vector3 = Vector3(0, -1, 0) if _reload_kind != "capsule" else Vector3(0, 0, 1)
			if _reload_kind == "drum":
				out_dir = Vector3(0, -0.6, 0.3)
			var well: Vector3 = mrest + out_dir * 0.02 + Vector3(0, -0.04, 0)
			# old mag out
			var o: float = _seg(p, 0.06, 0.22)
			mag.position = mrest + out_dir * 0.12 * o
			if p >= 0.24:
				if mag.visible:
					_spawn_debris(mag, Vector3(0, -1.0, 0.1), true)
				mag.hide()
			else:
				mag.show()
			# hand to pouch and back with a fresh one
			if p < 0.24:
				return lh_home.lerp(well, _seg(p, 0.0, 0.18))
			if p < 0.5:
				return well.lerp(pouch, _seg(p, 0.26, 0.42))
			_set_prop("mag" if _reload_kind != "capsule" else "capsule")
			var ins: float = _seg(p, 0.5, 0.72)
			var seat: float = _seg(p, 0.72, 0.8)
			var mag_pos: Vector3 = (mrest + out_dir * 0.25).lerp(mrest + out_dir * 0.04, ins).lerp(mrest, seat)
			if _prop != null:
				_prop.position = mag_pos
			if p >= 0.8:
				mag.show()
				mag.position = mrest
				_clear_prop()
			var hand: Vector3 = mag_pos + Vector3(-0.02, -0.04, 0)
			if p < 0.8:
				return pouch.lerp(hand, _seg(p, 0.48, 0.6))
			if _reload_started_empty:
				# rack the bolt / slide
				var rack_target: Node3D = _part("Slide") if _part("Slide") != null else _part("Bolt")
				if rack_target != null:
					var r: float = _bump(p, 0.84, 0.97)
					rack_target.position = (_rest[String(rack_target.name)] as Transform3D).origin + Vector3(0, 0, 0.04 * r)
					return hand.lerp(rack_target.position + Vector3(-0.03, 0.0, 0.02), _seg(p, 0.8, 0.86) * (1.0 - _seg(p, 0.95, 1.0)))
			return hand.lerp(lh_home, _seg(p, 0.82, 0.98))
		"belt":
			var cover: Node3D = _part("Cover")
			if cover != null:
				cover.rotation.x = -1.1 * _seg(p, 0.05, 0.18) * (1.0 - _seg(p, 0.72, 0.84))
			if mag != null:
				var br: Vector3 = (_rest["Mag"] as Transform3D).origin
				var out: float = _seg(p, 0.18, 0.32)
				var back_in: float = _seg(p, 0.48, 0.68)
				mag.position = br + Vector3(0, -0.3, 0.0) * (out * (1.0 - back_in))
				if p > 0.3 and p < 0.48:
					mag.hide()
				else:
					mag.show()
				if p < 0.5:
					return lh_home.lerp(br + Vector3(0, -0.05, 0), _seg(p, 0.1, 0.2)).lerp(pouch, _seg(p, 0.3, 0.45))
				return pouch.lerp(mag.position + Vector3(0, -0.05, 0), _seg(p, 0.45, 0.6)).lerp(lh_home, _seg(p, 0.85, 0.98))
		"bolt":
			# Empty: stripper clip from above. Per-round: one cartridge at a time (bolt held open).
			var feed: Node3D = _part("Mag")
			var feed_pos: Vector3 = feed.position if feed != null else Vector3(0, 0.055, -0.03)
			_bolt_open = 1.0
			if _reload_per_round:
				var hand_r: Vector3 = pouch.lerp(feed_pos + Vector3(-0.03, 0.07, 0.01), _seg(p, 0.0, 0.45)).lerp(feed_pos + Vector3(-0.03, 0.03, 0.0), _seg(p, 0.5, 0.85))
				_set_prop("shell")
				if _prop != null:
					_prop.scale = Vector3(0.55, 0.55, 1.1)
					_prop.position = hand_r + Vector3(0.03, -0.02, 0.0)
					_prop.visible = p < 0.88
				return hand_r
			if p > 0.72:
				_bolt_open = 1.0 - _seg(p, 0.75, 0.92)
			if p < 0.2:
				return lh_home.lerp(pouch, _seg(p, 0.0, 0.18))
			var above: Vector3 = feed_pos + Vector3(-0.03, 0.09, 0.0)
			var press: Vector3 = feed_pos + Vector3(-0.03, 0.035, 0.0)
			var hand_c: Vector3 = pouch.lerp(above, _seg(p, 0.2, 0.42)).lerp(press, _seg(p, 0.45, 0.66))
			if p < 0.7:
				_set_prop("clip")
				if _prop != null:
					_prop.position = hand_c + Vector3(0.03, -0.03, 0.0)
				return hand_c
			_clear_prop()
			return press.lerp(lh_home, _seg(p, 0.7, 0.95))
		"shell":
			var port: Vector3 = (_model.get_node("Mag") as Node3D).position if _model.get_node_or_null("Mag") != null else Vector3(0, -0.01, -0.03)
			var hand_s: Vector3 = pouch.lerp(port + Vector3(-0.02, -0.07, 0.04), _seg(p, 0.0, 0.45)).lerp(port + Vector3(-0.02, -0.035, -0.01), _seg(p, 0.5, 0.82))
			_set_prop("shell")
			if _prop != null:
				_prop.position = hand_s + Vector3(0.02, 0.03, -0.01)
				_prop.visible = p < 0.86
			return hand_s
		"enbloc":
			var clip: Node3D = mag
			var crest: Vector3 = (_rest["Mag"] as Transform3D).origin if clip != null else Vector3(0, 0.04, -0.02)
			if clip != null:
				clip.hide()
			_set_prop("enbloc")
			var thumb: Vector3 = pouch.lerp(crest + Vector3(-0.02, 0.1, 0.0), _seg(p, 0.15, 0.42)).lerp(crest + Vector3(-0.02, 0.05, 0.0), _seg(p, 0.45, 0.62))
			if _prop != null:
				_prop.position = (thumb + Vector3(0.02, -0.05, 0.0)) if p < 0.62 else crest
			var opr: Node3D = _part("Bolt")
			if opr != null:
				opr.position = (_rest["Bolt"] as Transform3D).origin + Vector3(0, 0, 0.06 * (1.0 - _seg(p, 0.66, 0.72)))
			if p < 0.15:
				return lh_home.lerp(pouch, _seg(p, 0.0, 0.14))
			if p < 0.62:
				return thumb
			return (crest + Vector3(-0.02, 0.05, 0.0)).lerp(lh_home, _seg(p, 0.7, 0.95))
		"break":
			var br2: Node3D = _part("Barrels")
			if br2 != null:
				br2.rotation.x = -0.6 * _seg(p, 0.03, 0.18) * (1.0 - _seg(p, 0.8, 0.92))
			if p > 0.2 and p < 0.24 and _prop_kind != "ejected":
				_prop_kind = "ejected"
				_eject_casing()
				_eject_casing()
			if p > 0.35 and p < 0.75 and _model != null and _model.has_meta("cylinder"):
				# six rounds pushed into the tipped-up cylinder's rear face (Barrels tip -0.6 rad about the hinge)
				_set_prop("rounds6")
				if _prop != null:
					_prop.position = Vector3(0, -0.05, 0.12).lerp(Vector3(-0.016, 0.066, 0.05), _seg(p, 0.4, 0.7))
					_prop.rotation_degrees = Vector3(rad_to_deg(-0.6), 0, 0)
				return pouch.lerp(Vector3(-0.02, 0.02, 0.04), _seg(p, 0.3, 0.55))
			if p > 0.35 and p < 0.75:
				_set_prop("shell")
				if _prop != null:
					_prop.position = Vector3(0, -0.05, 0.12).lerp(Vector3(0, 0.035, -0.04), _seg(p, 0.4, 0.7))
					_prop.rotation_degrees = Vector3(-30, 0, 0)
				return pouch.lerp(Vector3(-0.02, 0.01, 0.0), _seg(p, 0.3, 0.55))
			return lh_home.lerp(pouch, _seg(p, 0.15, 0.3)) if p < 0.4 else lh_home
		"rocket":
			_set_prop("rocket")
			if _prop != null:
				var rr: Vector3 = (_rest["Rocket"] as Transform3D).origin if _rest.has("Rocket") else Vector3(0, 0.07, 0.62)
				_prop.position = (rr + Vector3(-0.15, -0.3, 0.2)).lerp(rr, _seg(p, 0.15, 0.5)).lerp(rr + Vector3(0, 0, -0.3), _seg(p, 0.5, 0.75))
				_prop.visible = p < 0.76
				return pouch.lerp(_prop.position + Vector3(-0.04, -0.04, 0.12), _seg(p, 0.0, 0.3)) if p < 0.76 else lh_home
		"fuel":
			var valve: Node3D = _part("Valve")
			if valve != null:
				valve.rotation.z = TAU * 1.5 * _seg(p, 0.2, 0.8)
				return lh_home.lerp(valve.position + Vector3(-0.03, 0.0, 0.0), _seg(p, 0.05, 0.2) * (1.0 - _seg(p, 0.85, 0.98)))
		"bell":
			return bell_logic().reload_hand(p, _part("Crank"), lh_home)   # the crank IS the reload
	return null


# ---------------------------------------------------------------- player bot mode (T-071)

var _bot_view_index: int = -1

## Player bot mode (T-071): the local human's own holder while the bots' brain plays them. The brain (BotAim) owns
## firing, reloads and the ammo; this only keeps the first-person view honest: the gun in hand (rebuilt after the
## brain swaps), the raise, the sprint pose, the reload animation and its sound cues, the bob and sway. It never
## moves ammo (the brain's reload does).
func bot_view_tick(delta: float, sprinting: bool, reloading: bool, reload_left: float) -> void:
	if mirror:
		return
	_swap_t = maxf(0.0, _swap_t - delta)
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	_tick_bloom(delta)
	_sprinting = sprinting
	var w: WeaponInstance = current()
	if sprinting:
		_sprint_out_total = sprint_out_time(w)
		_sprint_out_t = _sprint_out_total
	else:
		_sprint_out_t = maxf(0.0, _sprint_out_t - delta)
	if _bot_view_index != current_index:
		var first: bool = _bot_view_index < 0
		_bot_view_index = current_index
		if _reloading:
			_reloading = false
			_cues = []
			_cue_i = 0
		if not first:
			_swap_t = SWAP_TIME * (w.draw_mult() if w != null else 1.0)
			AudioDirector.play_2d("weapon_raise", -6.0)
		_rebuild_gun()
	ads_t = move_toward(ads_t, 0.0, delta / 0.25)
	if w != null:
		if reloading and not _reloading:
			_reloading = true
			_reload_per_round = false
			_reload_t = maxf(0.05, reload_left)
			_on_reload_started(w)
			_set_reload_cues()
		elif reloading:
			if reload_left > _reload_t + 0.05:
				_reload_total = maxf(0.05, reload_left)   # a round-by-round reload's next shell
				_cue_i = 0
			_reload_t = maxf(0.0, reload_left)
			_tick_reload_cues()
		elif _reloading:
			_reloading = false
			_flush_reload_cues()
			_on_reload_finished()
	_animate(delta, sprinting)


## The control came back to the player: the holder picks up where the brain left the guns (the gun in hand is
## the one shown; no half-finished reload animation).
func bot_view_release() -> void:
	if _reloading:
		_cancel_reload()
	if _bot_view_index >= 0 and _bot_view_index != current_index:
		_rebuild_gun()
	_bot_view_index = -1
	_reload_queued = false


## One shot the player bot's brain fired (BotAim.fire): the viewmodel kick, the muzzle flash, the 2D fire sound,
## the bolt / brass, a visual-only camera punch (no aim change: the brain aims), the hitmarker, and the co-op relay
## (Net.session.local_fired) so the other peers see the shot.
func bot_shot_fx(w: WeaponInstance, origin: Vector3, end: Vector3, hit: bool) -> void:
	if mirror or w == null:
		return
	_fired_this_frame = true
	_since_shot = 0.0
	_kick = 1.0
	var ads_k: float = lerpf(1.0, float(_feel.get("ads_recoil", 0.65)), ads_t)
	var punch: float = float(recoil_cfg(w).get("punch", 0.45))
	if player != null:
		player.kick_camera(float(_feel.get("cam_pitch", 1.0)) * ads_k * punch, float(_feel.get("cam_yaw", 0.3)) * ads_k * punch, 0.0,
			float(_feel.get("cam_recover", 12.0)), float(_feel.get("shake", 0.05)) * ads_k, float(_feel.get("fov_punch", 0.5)) * ads_k)
	_vm_kick(1.0)
	_on_shot_fx(float(_feel.get("flash_time", 0.05)))
	AudioDirector.play_2d(_fire_key(w), float(_feel.get("fire_db", -2.0)))
	if w.mag == 0 and w.mag_size() > 1:
		AudioDirector.play_2d("last_round_click", -3.0, 0.0)
	if hit:
		AudioDirector.play_2d("hitmarker", -6.0)
	_after_shot_anim(w)
	_last_impact = end
	_report_fire(0, w.id, origin, end)
