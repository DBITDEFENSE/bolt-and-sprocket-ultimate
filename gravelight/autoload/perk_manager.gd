extends Node
## Perk tonics: ownership per player, the cap, loss on down, Second Wind solo self-revives.
## PUBLIC API (used by Player / WeaponHolder / MapRoot / machines / dev console):
##   stat(player, key, default) -> Variant   aggregated effect value from owned perks (data/perks.json "effects")
##       keys: max_health, revive_speed_mult, reload_time_mult, fire_rate_mult, unlimited_sprint, move_speed_mult,
##             sway_mult, ads_time_mult, head_damage_mult, weapon_slots, self_explosive_immune,
##             fall_damage_immune, slide_shockwave_damage, slide_shockwave_radius
##   has_perk(player, perk_id) -> bool
##   owned(player) -> Array
##   can_buy(player, perk_id) -> StringName    &"ok", &"owned", &"cap", &"no_power", &"gone"
##   try_buy(player: Player, perk_id) -> StringName   check + spend + grant immediately (+ &"no_scrip")
##   grant(player, perk_id) -> void            gives the perk (no cost); used after the machine's drink beat
##   price(perk_id) -> int                     solo/co-op aware
##   try_self_revive(player) -> bool           consumes a Second Wind solo use if available
##   on_player_downed(player) -> void          co-op rule: every perk is lost (a bot's bonus perk stays)
##   grant_bonus(player, perk_id) / bonus_perk(player) / is_bonus(player, perk_id) / capped_count(player):
##       a bot's random bonus perk (U02 section 5, BotSquad): owned like any perk, outside the cap, kept on going down
##   reset_match() -> void
##   overclock_reload(player: Player, spent: float) -> bool   Overclock Cordial hook (WEAPONS.md section 20.2):
##       call at the START of a reload (or an overheat vent, spent = 1.0) with spent = 1 - mag / mag_size.
##       Returns true when a burst was scheduled (it lands overclock_delay later at the player's position).
##       WeaponHolder.start_reload calls it; a bot's own reload code can call it the same way.
##   overclock_spent(mag, mag_size) / overclock_radius(spent) / overclock_damage(spent, round_health, boss,
##       repossessor) / overclock_staggers(spent): the pure rules, for tests and bots.

## Emitted when the solo Second Wind machine has used its last self-revive and should leave.
signal second_wind_retired
## Overclock Cordial accepted a reload (before the 0.15 s delay). GLBus.overclock_burst fires when it lands.
signal overclock_triggered(player: int, spent: float)

const OVERCLOCK: StringName = &"overclock_cordial"
## Bosses take the flat boss damage and are never staggered by the burst.
const OVERCLOCK_BOSSES: PackedStringArray = ["foreman", "underwriter"]

var _owned: Dictionary = {}        # player -> Array[StringName]
var _bonus_slots: Dictionary = {}  # player -> int (Map 1 egg reward)
var _bonus_perk: Dictionary = {}   # player -> StringName: a bot's bonus perk (outside the cap, kept on a down)
var solo_self_revives_left: int = 3
var second_wind_gone: bool = false
var _hud: CanvasLayer = null
var _overclock_ready_at: Dictionary = {}   # player -> msec when the 3 s cooldown ends


func _ready() -> void:
	GLBus.match_started.connect(_on_match_started)


func reset_match() -> void:
	_owned.clear()
	_bonus_slots.clear()   # the Map 1 egg slot is re-applied on match_started
	_bonus_perk.clear()
	_overclock_ready_at.clear()
	solo_self_revives_left = int(GLData.table("perks").get("solo_self_revives", 3))
	second_wind_gone = false


func _on_match_started(_map_id: StringName) -> void:
	# The HUD lives under this autoload (the map may not be current_scene yet when the match starts).
	if _hud == null or not is_instance_valid(_hud):
		_hud = (load("res://gravelight/ui/perk_hud.gd") as GDScript).new() as CanvasLayer
		add_child(_hud)
	_hud.call("_rebuild")


func _process(_delta: float) -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = GameState.phase != GameState.Phase.MENU


func perk_data(perk_id: StringName) -> Dictionary:
	return GLData.table("perks")["perks"].get(String(perk_id), {})


func display_name(perk_id: StringName) -> String:
	return str(perk_data(perk_id).get("name", perk_id))


func owned(player: int) -> Array:
	return _owned.get(player, [])


func has_perk(player: int, perk_id: StringName) -> bool:
	return owned(player).has(perk_id)


func cap_for(player: int) -> int:
	return int(GLData.table("perks")["cap"]) + int(_bonus_slots.get(player, 0))


func add_bonus_slot(player: int, count: int = 1) -> void:
	_bonus_slots[player] = int(_bonus_slots.get(player, 0)) + count


## Aggregates effects across every owned perk (a later perk overrides an earlier one for the same key).
func stat(player: int, key: String, default: Variant) -> Variant:
	var perks: Dictionary = GLData.table("perks")["perks"]
	var value: Variant = default
	for perk_id: Variant in owned(player):
		var effects: Dictionary = perks.get(String(perk_id), {}).get("effects", {})
		if effects.has(key):
			value = effects[key]
	return value


func price(perk_id: StringName) -> int:
	return cost_for(perk_data(perk_id), GameState.is_solo())


func needs_power(perk_id: StringName) -> bool:
	var p: Dictionary = perk_data(perk_id)
	if GameState.is_solo() and bool(p.get("solo_no_power", false)):
		return false
	return bool(p.get("needs_power", true))


func can_buy(player: int, perk_id: StringName) -> StringName:
	if perk_id == &"second_wind" and GameState.is_solo() and second_wind_gone:
		return &"gone"
	if has_perk(player, perk_id):
		return &"owned"
	if needs_power(perk_id) and not GameState.power_on:
		return &"no_power"
	if capped_count(player) >= cap_for(player):
		return &"cap"
	return &"ok"


func try_buy(player: Player, perk_id: StringName) -> StringName:
	return buy_for(player.player_id, perk_id)


## Same as try_buy, by player id (tests, dev console).
func buy_for(player_id: int, perk_id: StringName) -> StringName:
	if not Net.is_authority():
		return &"no_scrip"
	var reason: StringName = can_buy(player_id, perk_id)
	if reason != &"ok":
		GLBus.perk_denied.emit(player_id, perk_id, reason)
		return reason
	if not Economy.spend(player_id, perk_id, price(perk_id)):
		GLBus.perk_denied.emit(player_id, perk_id, &"no_scrip")
		return &"no_scrip"
	grant(player_id, perk_id)
	return &"ok"


func grant(player: int, perk_id: StringName) -> void:
	if not Net.is_authority():
		return
	if has_perk(player, perk_id) or perk_data(perk_id).is_empty():
		return
	if not _owned.has(player):
		_owned[player] = []
	(_owned[player] as Array).append(perk_id)
	GLBus.perk_bought.emit(player, perk_id)
	GLBus.perks_changed.emit(player)


## Dev console: every perk, ignoring the cap, power and cost.
func grant_all(player: int) -> void:
	if not Net.is_authority():
		return
	for perk_id: Variant in GLData.table("perks")["perks"].keys():
		if not has_perk(player, StringName(perk_id)):
			if not _owned.has(player):
				_owned[player] = []
			(_owned[player] as Array).append(StringName(perk_id))
			GLBus.perk_bought.emit(player, StringName(perk_id))
	GLBus.perks_changed.emit(player)


func remove(player: int, perk_id: StringName) -> void:
	if has_perk(player, perk_id):
		(_owned[player] as Array).erase(perk_id)
		GLBus.perks_changed.emit(player)


## Solo: going down with Second Wind uses it up (other perks are kept). Three uses per game.
func try_self_revive(player: int) -> bool:
	if not Net.is_authority() or not GameState.is_solo() or not has_perk(player, &"second_wind") or solo_self_revives_left <= 0:
		return false
	solo_self_revives_left -= 1
	(_owned[player] as Array).erase(&"second_wind")
	GLBus.self_revive.emit(player, solo_self_revives_left)
	GLBus.perks_changed.emit(player)
	if solo_self_revives_left <= 0:
		second_wind_gone = true
		second_wind_retired.emit()
	return true


## A bot's bonus perk (U02 section 5): granted free and quietly (no drink line, no machine), outside the cap,
## and kept when the bot goes down. One per player; a second call replaces the mark (not the old perk).
func grant_bonus(player: int, perk_id: StringName) -> void:
	if not Net.is_authority() or perk_data(perk_id).is_empty():
		return
	_bonus_perk[player] = perk_id
	if not has_perk(player, perk_id):
		if not _owned.has(player):
			_owned[player] = []
		(_owned[player] as Array).append(perk_id)
	GLBus.perks_changed.emit(player)


## The player's bonus perk (&"" for none: humans, bots with the setting off).
func bonus_perk(player: int) -> StringName:
	return StringName(_bonus_perk.get(player, &""))


func is_bonus(player: int, perk_id: StringName) -> bool:
	return perk_id != &"" and bonus_perk(player) == perk_id


## Owned perks that count toward the cap (the bonus perk doesn't).
func capped_count(player: int) -> int:
	var n: int = owned(player).size()
	if is_bonus(player, bonus_perk(player)) and has_perk(player, bonus_perk(player)):
		n -= 1
	return n


## Co-op rule (and solo without Second Wind): every perk is lost on going down, except a bot's bonus perk.
func on_player_downed(player: int) -> void:
	if not Net.is_authority() or owned(player).is_empty():
		return
	var keep: StringName = bonus_perk(player)
	_owned[player] = [keep] if keep != &"" and has_perk(player, keep) else []
	GLBus.perks_lost.emit(player)
	GLBus.perks_changed.emit(player)


static func cost_for(perk: Dictionary, solo: bool) -> int:
	if not solo and perk.has("cost_coop"):
		return int(perk["cost_coop"])
	return int(perk.get("cost", 0))


# ---------------------------------------------------------------- Overclock Cordial (WEAPONS.md section 20.2)

## The rule numbers live in perks.json "effects" of overclock_cordial (fallbacks are the doc's values).
static func _oc(key: String, fallback: float) -> float:
	var effects: Dictionary = (GLData.table("perks")["perks"] as Dictionary).get("overclock_cordial", {}).get("effects", {})
	return float(effects.get(key, fallback))


## Spent fraction e = 1 - rounds_in_mag / mag_size, clamped to 0..1.
static func overclock_spent(mag: int, mag_size: int) -> float:
	if mag_size <= 0:
		return 1.0
	return clampf(1.0 - float(mag) / float(mag_size), 0.0, 1.0)


## Radius 2.5 + 3.5 * e metres (6.0 m on an empty mag).
static func overclock_radius(spent: float) -> float:
	return _oc("overclock_radius_base", 2.5) + _oc("overclock_radius_per_spent", 3.5) * clampf(spent, 0.0, 1.0)


## Non-boss: 0.6 * health(r) * e (Repossessors x2). Boss: a flat 1500 * e.
static func overclock_damage(spent: float, round_health: float, boss: bool, repossessor: bool = false) -> float:
	var e: float = clampf(spent, 0.0, 1.0)
	if boss:
		return _oc("overclock_boss_damage", 1500.0) * e
	var dmg: float = _oc("overclock_damage_health_mult", 0.6) * round_health * e
	if repossessor:
		dmg *= _oc("overclock_repossessor_mult", 2.0)
	return dmg


## Every non-boss enemy in the radius is staggered when e >= 0.75.
static func overclock_staggers(spent: float) -> bool:
	return spent >= _oc("overclock_stagger_spent", 0.75) - 0.0001


## Hook for the start of a reload (manual, automatic, bolt / shell-by-shell once, or an overheat vent with
## spent = 1.0). Needs the perk, e >= 0.25 and the 3 s cooldown to be over. The burst lands 0.15 s later
## (overclock_delay) around the player, so a player who dropped in the meantime releases nothing.
func overclock_reload(player: Player, spent: float) -> bool:
	if player == null or not is_instance_valid(player) or not has_perk(player.player_id, OVERCLOCK):
		return false
	var e: float = clampf(spent, 0.0, 1.0)
	if e < _oc("overclock_min_spent", 0.25) - 0.0001:
		return false
	var now: int = Time.get_ticks_msec()
	if now < int(_overclock_ready_at.get(player.player_id, 0)):
		return false
	_overclock_ready_at[player.player_id] = now + int(_oc("overclock_cooldown", 3.0) * 1000.0)
	overclock_triggered.emit(player.player_id, e)
	var delay: float = _oc("overclock_delay", 0.15)
	if delay <= 0.0 or not is_inside_tree():
		_overclock_burst(player, e)
	else:
		get_tree().create_timer(delay).timeout.connect(_overclock_burst.bind(player, e))
	return true


## Tests / dev: forget the cooldown so the next reload can burst.
func overclock_clear_cooldown(player_id: int) -> void:
	_overclock_ready_at.erase(player_id)


## The burst itself: the nearest 10 enemies in the radius take electrical damage (no armour, no self, team or
## barricade damage), bosses take the flat amount, everyone else staggers at e >= 0.75. Presentation: a
## teal-violet ring, a ZAP, and GLBus.overclock_burst (the cabinet's gauge needle listens).
func _overclock_burst(player_ref: Variant, e: float) -> void:
	# untyped on purpose: the bound Player may have been freed during the delay (a typed parameter would
	# refuse the call with an error instead of letting us check)
	if not is_instance_valid(player_ref) or not (player_ref is Player):
		return
	var player: Player = player_ref as Player
	if not player.is_inside_tree() or player.downed:
		return
	var radius: float = overclock_radius(e)
	var pos: Vector3 = player.global_position + Vector3.UP * 0.9
	var pid: int = player.player_id
	var director: Node = get_tree().get_first_node_in_group(&"director")
	if director != null and director.has_method("active_zombies"):
		var in_range: Array = []
		for z: Zombie in director.call("active_zombies"):
			var d: float = z.global_position.distance_to(player.global_position)
			if d <= radius:
				in_range.append([d, z])
		in_range.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var health_r: float = float(RoundManager.current_health())
		var max_targets: int = int(_oc("overclock_max_targets", 10))
		var stagger: bool = overclock_staggers(e)
		for i: int in mini(in_range.size(), max_targets):
			var z: Zombie = in_range[i][1]
			var boss: bool = OVERCLOCK_BOSSES.has(String(z.enemy_id))
			var dmg: float = overclock_damage(e, health_r, boss, z.enemy_id == &"repossessor")
			var killed: bool = z.take_damage(dmg, &"torso", OVERCLOCK, pid, &"electric", true)
			if stagger and not boss and not killed and z.is_active():
				z.force_stagger()
	Effects.static_burst(pos, radius)
	AudioDirector.play_3d("perk_overclock_burst", pos, lerpf(-6.0, 0.0, e), 0.08)
	GLBus.overclock_burst.emit(pid, pos, e, radius)
