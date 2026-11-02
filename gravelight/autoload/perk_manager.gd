extends Node
## Perk tonics: ownership per player, the cap, loss on down, Second Wind solo self-revives.
## PUBLIC API (used by Player / WeaponHolder / MapRoot / machines / dev console):
##   stat(player, key, default) -> Variant   aggregated effect value from owned perks (data/perks.json "effects")
##       keys: max_health, revive_speed_mult, reload_time_mult, fire_rate_mult, unlimited_sprint, move_speed_mult,
##             sway_mult, ads_time_mult, head_damage_mult, weapon_slots, self_explosive_immune,
##             fall_damage_immune, slide_shockwave_damage, slide_shockwave_radius
##   has_perk(player, perk_id) -> bool
##   owned(player) -> Array
##   base_cap() -> int                        the match's tonic cap: perks.json "cap" (6), "classic_cap" (4) with Classic Rules
##   cap_for(player) -> int                   base_cap() + that player's bonus slots (the Map 1 egg)
##   can_buy(player, perk_id) -> StringName    &"ok", &"owned", &"cap", &"no_power", &"gone"
##   try_buy(player: Player, perk_id) -> StringName   check + spend + grant immediately (+ &"no_scrip")
##   grant(player, perk_id) -> void            gives the perk (no cost); used after the machine's drink beat
##   price(perk_id) -> int                     solo/co-op aware
##   try_self_revive(player) -> bool           consumes a Second Wind solo use if available
##   on_player_downed(player) -> void          co-op rule: every perk is lost (a bot's bonus perk and sealed tonics stay)
##   seal(player, perk_id) / is_sealed / sealed(player): a tonic kept through every down (tonic bottle, T-121)
##   grant_bonus(player, perk_id) / bonus_perk(player) / is_bonus(player, perk_id) / capped_count(player):
##       a bot's random bonus perk (U02 section 5, BotSquad): owned like any perk, outside the cap, kept on going down
##   reset_match() -> void
##   overclock_reload(player: Player, spent: float) -> bool   Overclock Cordial hook (WEAPONS.md section 20.2):
##       call at the START of a reload (or an overheat vent, spent = 1.0) with spent = 1 - mag / mag_size.
##       Returns true when a burst was scheduled (it lands overclock_delay later at the player's position).
##       WeaponHolder.start_reload calls it; a bot's own reload code can call it the same way.
##   overclock_spent(mag, mag_size) / overclock_radius(spent) / overclock_damage(spent, round_health, boss,
##       repossessor) / overclock_staggers(spent): the pure rules, for tests and bots.
## PERK UPGRADES (tiers II / III, DECISIONS T-075, docs/gravelight/PERKS_LORE.md section 1; perks.json "tiers" + "upgrades"):
##   tier_of(player, perk) -> int (0 not owned, 1 base, 2, 3)   tiers(player) -> {perk: tier}   tier_name(perk, tier)
##   can_upgrade(player, perk) -> &"ok" / &"none" / &"max" / &"no_power" / &"round" / &"locked" / &"gone"
##   tier_price(perk, tier)   upgrade_for(pid, perk) (check + spend + apply now)   set_tier(pid, perk, tier) (no cost;
##       PerkMachine calls it after the drink beat)   mastery(perk) / mastery_needed(tier) / tier_unlocked(perk, tier)
##   Effect hooks (call sites in Player, WeaponHolder, BotAim, Explosion, WallBuy, AmmoBox): filter_hit(player, amount),
##   shot_mult(pid, aimed), round_saved(pid, w), on_bullet_kill(pid, w, head), reload_finished(pid),
##   ammo_price_mult(pid), grenade_bonus(pid), blast_heal(player, pos, radius), slide_shock_damage(pid, base),
##   slide_hit(player, zombie, dmg). stat(pid, "move_speed_mult") includes the revive / dodge speed boosts.

## Emitted when the solo Second Wind machine has used its last self-revive and should leave.
signal second_wind_retired
## Overclock Cordial accepted a reload (before the 0.15 s delay). GLBus.overclock_burst fires when it lands.
signal overclock_triggered(player: int, spent: float)
## A perk was upgraded (tier 2 or 3) for a player.
signal perk_tier_changed(player: int, perk_id: StringName, tier: int)
## A tier effect fired (iron skin, a dodge, a refund...): the HUD cap pops. `effect` names it.
signal perk_proc(player: int, perk_id: StringName, effect: StringName)

const OVERCLOCK: StringName = &"overclock_cordial"
## Bosses take the flat boss damage and are never staggered by the burst.
const OVERCLOCK_BOSSES: PackedStringArray = ["foreman", "underwriter"]

var _owned: Dictionary = {}        # player -> Array[StringName]
var _bonus_slots: Dictionary = {}  # player -> int (Map 1 egg reward)
var _bonus_perk: Dictionary = {}   # player -> StringName: a bot's bonus perk (outside the cap, kept on a down)
var _slotless: Dictionary = {}     # player -> StringName: PAUL'S LAST ROUND's free Ironhide (outside the cap, lost on a down; T-159)
var _overshield: Dictionary = {}   # player -> float: PAUL'S LAST ROUND's one-time overshield (absorbs hits first; T-159)
## The match's base cap (T-081), read from the data + Classic Rules on first use after reset_match (-1 = not yet);
## a co-op client takes the host's from the state snapshot ("cb").
var _base_cap: int = -1
var solo_self_revives_left: int = 3
var second_wind_gone: bool = false
var _hud: CanvasLayer = null
var _overclock_ready_at: Dictionary = {}   # player -> msec when the 3 s cooldown ends
var _tiers: Dictionary = {}        # player -> {perk_id String: tier int >= 2} (tier 1 = owned, not stored)
var _kept_tiers: Dictionary = {}   # player -> {perk_id String: tier}: Second Wind's tier through a solo self-revive
var _sealed: Dictionary = {}       # player -> {perk_id String: true}: kept through a down (a tonic bottle's free measure, T-121)
var _revive_tier: Dictionary = {}  # player -> the Second Wind tier that is getting them up (solo self-revive)
var _until: Dictionary = {}        # "pid:key" -> msec: iron_skin / invuln / boost / fresh_clip windows, dodge cooldown
var _boost_mult: Dictionary = {}   # player -> the speed multiplier of their running boost
var _last_shot_ms: Dictionary = {} # player -> msec of their last shot (Hawkeye III)
var _vo_said: Dictionary = {}      # "pid:what" -> true: first-of-match lines
var _fx_cache: Dictionary = {}     # "perk:tier" -> merged effects
var _last_stand_round: Dictionary = {}   # player -> the round Ironhide IV last held them up (once a round, T-129)
var _shock_left: Dictionary = {}   # player -> shock rounds left (Trigger Tonic IV)
var _shots_fired: Dictionary = {}  # player -> bullets fired this match (Twin Barrel IV's every 10th)
var _knock_at: Dictionary = {}     # zombie instance id -> msec it may be knocked down again (Marathon IV)
var _knock_tick: float = 0.0
## Tests / dev: -1 = the data's upgrades.meta_gate, 0 = no mastery gate, 1 = gated.
var meta_gate_override: int = -1
## Co-op client: the host's unlocked tiers (perk -> highest unlocked tier), from the state snapshot.
var host_unlocks: Dictionary = {}


func _ready() -> void:
	GLBus.enemy_killed.connect(_on_enemy_killed_magpie)
	GLBus.enemy_killed_at.connect(_on_enemy_killed_at_magpie)
	GLBus.match_started.connect(_on_match_started)
	GLBus.enemy_killed.connect(_on_enemy_killed_mastery)
	GLBus.round_ended.connect(_on_round_ended_mastery)
	GLBus.round_started.connect(_on_round_started_tiers)
	GLBus.player_revived.connect(_on_player_revived_tiers)


func reset_match() -> void:
	_last_stand_round.clear()
	_shock_left.clear()
	_shots_fired.clear()
	_knock_at.clear()
	_owned.clear()
	_bonus_slots.clear()   # the Map 1 egg slot is re-applied on match_started
	_base_cap = -1         # Classic Rules is read again for the new match
	_bonus_perk.clear()
	_slotless.clear()
	_overshield.clear()
	_overclock_ready_at.clear()
	_tiers.clear()
	_kept_tiers.clear()
	_sealed.clear()
	_revive_tier.clear()
	_until.clear()
	_boost_mult.clear()
	_last_shot_ms.clear()
	_vo_said.clear()
	_fx_cache.clear()
	host_unlocks.clear()
	solo_self_revives_left = int(GLData.table("perks").get("solo_self_revives", 3))
	second_wind_gone = false


func _on_match_started(_map_id: StringName) -> void:
	# The HUD lives under this autoload (the map may not be current_scene yet when the match starts).
	if _hud == null or not is_instance_valid(_hud):
		_hud = (load("res://gravelight/ui/perk_hud.gd") as GDScript).new() as CanvasLayer
		add_child(_hud)
	_hud.offset = Vector2.ZERO   # T-122: a transition that hid the row never leaves it hidden in the next match
	_hud.call("_rebuild")


func _process(_delta: float) -> void:
	_tick_knockdown(_delta)
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


## The tonic cap for this match (T-081): perks.json "cap", or "classic_cap" when Classic Rules is on. Latched for the
## match (toggling Classic Rules mid-match doesn't move it; reset_match re-reads it).
func base_cap() -> int:
	if _base_cap < 0:
		_base_cap = data_cap(bool(GLSettings.values.get("classic_rules", false)))
	return _base_cap


## Pure: the data's cap with Classic Rules on or off.
static func data_cap(classic: bool) -> int:
	var t: Dictionary = GLData.table("perks")
	if classic and t.has("classic_cap"):
		return int(t["classic_cap"])
	return int(t.get("cap", 6))


func cap_for(player: int) -> int:
	return base_cap() + int(_bonus_slots.get(player, 0))


func add_bonus_slot(player: int, count: int = 1) -> void:
	_bonus_slots[player] = int(_bonus_slots.get(player, 0)) + count


## Aggregates effects across every owned perk at its tier (a later perk overrides an earlier one for the same key;
## a tier's effects override its own perk's). "move_speed_mult" includes a running revive / dodge boost.
func stat(player: int, key: String, default: Variant) -> Variant:
	var value: Variant = default
	var tiers_p: Dictionary = _tiers.get(player, {})
	for perk_id: Variant in owned(player):
		var effects: Dictionary = effects_for(StringName(perk_id), int(tiers_p.get(String(perk_id), 1)))
		if effects.has(key):
			value = effects[key]
	if key == "move_speed_mult" and _active(player, "boost"):
		value = float(value) * float(_boost_mult.get(player, 1.0))
	return value


## Ledger Lager III (T-141): the tip a Marke kill pays on top of the Marke bonus (UPDATE 09 contract C1/C6; 0 without it).
func marke_tip(player: int) -> int:
	return maxi(0, int(stat(player, "marke_tip", 0)))


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
	# a solo self-revive used Second Wind up, but the cabinet remembers the tier you had (PERKS_LORE.md 1.1)
	var kept: Dictionary = _kept_tiers.get(player, {})
	if kept.has(String(perk_id)):
		_tier_dict(player)[String(perk_id)] = int(kept[String(perk_id)])
		kept.erase(String(perk_id))
	# UPDATE 07 (T-114): a tier the egg made free for the match (Skyhook II after the wind tunnel ran)
	var free_tier: int = int(GameState.flags.get(StringName("perk_tier_free_" + String(perk_id)), 0))
	if free_tier > tier_of(player, perk_id):
		_tier_dict(player)[String(perk_id)] = free_tier
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
		_tier_dict(player).erase(String(perk_id))
		(_sealed.get(player, {}) as Dictionary).erase(String(perk_id))
		GLBus.perks_changed.emit(player)


# ---- kept tonics (T-121): a tonic bottle that finds the cap full raises a carried tonic a tier and seals it: from
# then on that tonic (at its tier) survives every down, solo and co-op. Lost only by remove() or a new match.

func seal(player: int, perk_id: StringName) -> void:
	if not Net.is_authority() or not has_perk(player, perk_id):
		return
	if not _sealed.has(player):
		_sealed[player] = {}
	(_sealed[player] as Dictionary)[String(perk_id)] = true
	GLBus.perks_changed.emit(player)


func is_sealed(player: int, perk_id: StringName) -> bool:
	return (_sealed.get(player, {}) as Dictionary).has(String(perk_id))


## The player's sealed tonics (perk ids as Strings).
func sealed(player: int) -> Array:
	return (_sealed.get(player, {}) as Dictionary).keys()


## Solo: going down with Second Wind uses it up (other perks are kept). Three uses per game.
func try_self_revive(player: int) -> bool:
	if not Net.is_authority() or not GameState.is_solo() or not has_perk(player, &"second_wind") or solo_self_revives_left <= 0:
		return false
	solo_self_revives_left -= 1
	var t: int = int(_tier_dict(player).get("second_wind", 1))
	_revive_tier[player] = t
	if (is_sealed(player, &"second_wind") or is_permanent(player, &"second_wind")) and solo_self_revives_left > 0:
		# a sealed Second Wind is not used up by the self-revive (the three uses per game still count down)
		GLBus.self_revive.emit(player, solo_self_revives_left)
		GLBus.perks_changed.emit(player)
		return true
	(_owned[player] as Array).erase(&"second_wind")
	(_sealed.get(player, {}) as Dictionary).erase("second_wind")
	if t > 1:
		_tier_dict(player).erase("second_wind")
		if not _kept_tiers.has(player):
			_kept_tiers[player] = {}
		(_kept_tiers[player] as Dictionary)["second_wind"] = t
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


## Owned perks that count toward the cap (the bonus perk doesn't, nor PAUL'S LAST ROUND's free tonic).
func capped_count(player: int) -> int:
	var n: int = owned(player).size()
	if is_bonus(player, bonus_perk(player)) and has_perk(player, bonus_perk(player)):
		n -= 1
	if _slotless.has(player) and has_perk(player, StringName(_slotless[player])) and not is_bonus(player, StringName(_slotless[player])):
		n -= 1
	return n


## PAUL'S LAST ROUND (T-159): a tonic free and outside the cap, until the player goes down.
func grant_slotless(player: int, perk_id: StringName) -> void:
	if not Net.is_authority() or perk_data(perk_id).is_empty() or has_perk(player, perk_id):
		return
	_slotless[player] = perk_id
	if not _owned.has(player):
		_owned[player] = []
	(_owned[player] as Array).append(perk_id)
	GLBus.perks_changed.emit(player)


func slotless_perk(player: int) -> StringName:
	return StringName(_slotless.get(player, &""))


## PAUL'S LAST ROUND (T-159): a one-time overshield that takes hits before health.
func add_overshield(player: int, amount: float) -> void:
	_overshield[player] = float(_overshield.get(player, 0.0)) + maxf(0.0, amount)


func overshield(player: int) -> float:
	return float(_overshield.get(player, 0.0))


## Pure: what is left of a hit after an overshield, and the shield left: [hit, shield].
static func absorb(amount: float, shield: float) -> Array:
	var used: float = minf(maxf(0.0, shield), amount)
	return [amount - used, shield - used]


## Co-op rule (and solo without Second Wind): every perk is lost on going down, except a bot's bonus perk.
func on_player_downed(player: int) -> void:
	if Net.is_authority() and _slotless.has(player):
		(_owned.get(player, []) as Array).erase(StringName(_slotless[player]))
		_slotless.erase(player)
		GLBus.perks_changed.emit(player)
	if not Net.is_authority() or owned(player).is_empty():
		return
	if GameState.retained:
		return   # the Retained state (Map 4 Act IV's renewal, T-113): the Plan keeps your tonics; nobody is let go
	var keep_ids: Array = kept_on_down(owned(player), bonus_perk(player), sealed(player) + permanent(player))
	var old_tiers: Dictionary = _tier_dict(player)
	var new_tiers: Dictionary = {}
	for k: Variant in keep_ids:
		if int(old_tiers.get(String(k), 1)) > 1:
			new_tiers[String(k)] = int(old_tiers[String(k)])
	_owned[player] = keep_ids
	_tiers[player] = new_tiers
	GLBus.perks_lost.emit(player)
	GLBus.perks_changed.emit(player)


## Pure: the tonics a down leaves in the player's system, in their order: a bot's bonus perk and every sealed one.
static func kept_on_down(owned_ids: Array, bonus: StringName, sealed_ids: Array) -> Array:
	var out: Array = []
	for p: Variant in owned_ids:
		var id: StringName = StringName(str(p))
		if (bonus != &"" and id == bonus) or sealed_ids.has(String(id)):
			out.append(id)
	return out


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
	_overclock_ready_at[player.player_id] = now + int(float(stat(player.player_id, "overclock_cooldown", _oc("overclock_cooldown", 3.0))) * 1000.0)
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
func _overclock_burst(player_ref: Variant, e: float, aftershock: bool = false) -> void:
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
		_overclock_arcs(player, e, radius, in_range.slice(0, mini(in_range.size(), max_targets)), health_r)
	Effects.static_burst(pos, radius)
	AudioDirector.play_3d("perk_overclock_burst", pos, lerpf(-6.0, 0.0, e), 0.08)
	GLBus.overclock_burst.emit(pid, pos, e, radius)
	# Overclock III (Aftershock): a burst from a magazine 75%+ empty rings again, once, at half strength
	var after_e: float = float(stat(pid, "overclock_aftershock_spent", 0.0))
	if not aftershock and after_e > 0.0 and e >= after_e - 0.0001 and is_inside_tree():
		perk_proc.emit(pid, OVERCLOCK, &"aftershock")
		get_tree().create_timer(float(stat(pid, "overclock_aftershock_delay", 0.8))).timeout.connect(
			_overclock_burst.bind(player, e * float(stat(pid, "overclock_aftershock_mult", 0.5)), true))



# ---------------------------------------------------------------- perk upgrades: tiers II / III (DECISIONS T-075)

static func upgrades_cfg() -> Dictionary:
	return GLData.table("perks").get("upgrades", {})


static func max_tier() -> int:
	return int(upgrades_cfg().get("max_tier", 3))


## U08 (T-129): the tier from which a tonic is permanent ("perma perk"; perks.json upgrades.permanent_tier, 4).
static func permanent_tier() -> int:
	return int(upgrades_cfg().get("permanent_tier", 999))


## A tonic the player holds at its permanent tier: kept through every down, bleed-out and self-revive.
func is_permanent(player: int, perk_id: StringName) -> bool:
	return tier_of(player, perk_id) >= permanent_tier()


## The player's permanent tonics (perk ids as Strings).
func permanent(player: int) -> Array:
	var out: Array = []
	for k: Variant in (_tiers.get(player, {}) as Dictionary).keys():
		if int((_tiers[player] as Dictionary)[k]) >= permanent_tier() and has_perk(player, StringName(str(k))):
			out.append(str(k))
	return out


## "II" / "III" ("" for tier 1).
static func tier_mark(tier: int) -> String:
	return str((upgrades_cfg().get("marks", {}) as Dictionary).get(str(tier), "")) if tier > 1 else ""


func _tier_dict(player: int) -> Dictionary:
	if not _tiers.has(player):
		_tiers[player] = {}
	return _tiers[player]


## 0 = not owned, 1 = the tonic itself, 2 / 3 = upgraded.
func tier_of(player: int, perk_id: StringName) -> int:
	if not has_perk(player, perk_id):
		return 0
	return int((_tiers.get(player, {}) as Dictionary).get(String(perk_id), 1))


## The player's upgraded perks: {perk_id String: tier} (tier 1 perks are not listed).
func tiers(player: int) -> Dictionary:
	return (_tiers.get(player, {}) as Dictionary).duplicate()


func tier_data(perk_id: StringName, tier: int) -> Dictionary:
	return (perk_data(perk_id).get("tiers", {}) as Dictionary).get(str(tier), {})


## The tonic's effects at a tier: the base effects with every tier up to `tier` merged over them.
func effects_for(perk_id: StringName, tier: int) -> Dictionary:
	if tier <= 1:
		return perk_data(perk_id).get("effects", {})
	var key: String = "%s:%d" % [perk_id, tier]
	if _fx_cache.has(key):
		return _fx_cache[key]
	var fx: Dictionary = (perk_data(perk_id).get("effects", {}) as Dictionary).duplicate()
	for t: int in range(2, tier + 1):
		fx.merge(tier_data(perk_id, t).get("effects", {}), true)
	_fx_cache[key] = fx
	return fx


## "Ironhide Stout II".
func tier_name(perk_id: StringName, tier: int) -> String:
	var mark: String = tier_mark(tier)
	return display_name(perk_id) + ((" " + mark) if mark != "" else "")


func tier_price(perk_id: StringName, tier: int) -> int:
	return int(tier_data(perk_id, tier).get("cost", 0))


static func tier_min_round(tier: int) -> int:
	return int((upgrades_cfg().get("min_round", {}) as Dictionary).get(str(tier), 0))


# ---- mastery: the profile-wide gate (points with the tonic in your system)

func meta_gate_on() -> bool:
	if meta_gate_override >= 0:
		return meta_gate_override == 1
	return bool(upgrades_cfg().get("meta_gate", true))


static func mastery_needed(tier: int) -> int:
	return int(((upgrades_cfg().get("mastery", {}) as Dictionary).get("unlock", {}) as Dictionary).get(str(tier), 0))


func mastery(perk_id: StringName) -> int:
	return int((ProfileSave.profile.get("perk_mastery", {}) as Dictionary).get(String(perk_id), 0))


func add_mastery(perk_id: StringName, points: int) -> void:
	if points <= 0 or perk_data(perk_id).is_empty():
		return
	var pm: Dictionary = ProfileSave.profile.get("perk_mastery", {})
	pm[String(perk_id)] = int(pm.get(String(perk_id), 0)) + points
	ProfileSave.profile["perk_mastery"] = pm


## Whether the profile has unlocked this tier (on a co-op client: the host's profile, from the snapshot).
func tier_unlocked(perk_id: StringName, tier: int) -> bool:
	if tier <= 1 or not meta_gate_on():
		return true
	if Net.is_client() and not host_unlocks.is_empty():
		return int(host_unlocks.get(String(perk_id), 1)) >= tier
	return mastery(perk_id) >= mastery_needed(tier)


## perk -> the highest tier this (host) profile has unlocked: sent to co-op clients in the snapshot.
func unlocked_tiers() -> Dictionary:
	var out: Dictionary = {}
	for pk: Variant in GLData.table("perks")["perks"].keys():
		var best: int = 1
		for t: int in range(2, max_tier() + 1):
			if tier_unlocked(StringName(pk), t):
				best = t
		out[String(pk)] = best
	return out


func _mastery_pid(pid: int) -> bool:
	return pid == ProfileSave.local_id() and bool(ProfileSave.call("_tracked")) and not GameState.god_mode


func _on_enemy_killed_mastery(_enemy_id: StringName, _limb: StringName, _weapon_id: StringName, by_player: int) -> void:
	if not _mastery_pid(by_player):
		return
	var per: int = int((upgrades_cfg().get("mastery", {}) as Dictionary).get("per_kill", 1))
	for pk: Variant in owned(by_player):
		add_mastery(StringName(pk), per)


func _on_round_ended_mastery(_round_number: int) -> void:
	var pid: int = ProfileSave.local_id()
	if not _mastery_pid(pid):
		return
	var per: int = int((upgrades_cfg().get("mastery", {}) as Dictionary).get("per_round", 20))
	for pk: Variant in owned(pid):
		add_mastery(StringName(pk), per)


# ---- buying a tier

## Can this player brew the next tier of a tonic they carry? &"ok", &"none" (not carried, or no tiers), &"max",
## &"no_power", &"round" (the round is under the tier's min_round), &"locked" (mastery), &"gone" (solo Second Wind
## retired). Scrip is checked by the purchase.
func can_upgrade(player: int, perk_id: StringName) -> StringName:
	if bool(GLSettings.values.get("classic_rules", false)):
		return &"classic"   # U08 (T-129): Classic Rules keeps every tier off
	if perk_id == &"second_wind" and GameState.is_solo() and second_wind_gone:
		return &"gone"
	var t: int = tier_of(player, perk_id)
	if t <= 0 or tier_data(perk_id, 2).is_empty():
		return &"none"
	if t >= max_tier() or tier_data(perk_id, t + 1).is_empty():
		return &"max"
	if bool(upgrades_cfg().get("needs_power", true)) and not GameState.power_on:
		return &"no_power"
	if RoundManager.current_round < tier_min_round(t + 1):
		return &"round"
	if not tier_unlocked(perk_id, t + 1) and not GameState.is_bot(player):
		return &"locked"   # T-121: a squad bot has no profile to earn mastery in, so the lock is the humans' only
	return &"ok"


## Check + spend + upgrade at once (dev console, tests). The machine itself spends through Interactable.try_purchase
## and calls set_tier after its drink beat.
func upgrade_for(player_id: int, perk_id: StringName) -> StringName:
	if not Net.is_authority():
		return &"no_scrip"
	var reason: StringName = can_upgrade(player_id, perk_id)
	if reason != &"ok":
		return reason
	var next: int = tier_of(player_id, perk_id) + 1
	if not Economy.spend(player_id, StringName("%s_t%d" % [perk_id, next]), tier_price(perk_id, next)):
		return &"no_scrip"
	set_tier(player_id, perk_id, next)
	return &"ok"


## Gives a carried tonic its tier (no cost, no checks but ownership). First upgrade of the match: the squad member
## and the Operator say something (VO_SCRIPT section 20).
func set_tier(player: int, perk_id: StringName, tier: int) -> void:
	if not Net.is_authority() or not has_perk(player, perk_id):
		return
	tier = clampi(tier, 1, max_tier())
	if tier <= 1:
		_tier_dict(player).erase(String(perk_id))
	else:
		_tier_dict(player)[String(perk_id)] = tier
	perk_tier_changed.emit(player, perk_id, tier)
	GLBus.perks_changed.emit(player)
	if tier >= permanent_tier():   # U08 (T-129): "This one's mine for good." (every time a tonic becomes permanent)
		GLVO.say_as(player, "PERK_TIER4", 1.0)
		_vo_said["%d:tier" % player] = true
		if not _vo_said.has("opr:tier%d" % tier):
			_vo_said["opr:tier%d" % tier] = true
			GLVO.play_category(&"OPR", "PERK_TIER%d" % tier)
	elif tier > 1:
		_first_vo(player, "tier", "PERK_TIER")
		if not _vo_said.has("opr:tier%d" % tier):
			_vo_said["opr:tier%d" % tier] = true
			GLVO.play_category(&"OPR", "PERK_TIER%d" % tier)


func _first_vo(player: int, what: String, category: String) -> void:
	var k: String = "%d:%s" % [player, what]
	if _vo_said.has(k):
		return
	_vo_said[k] = true
	GLVO.say_as(player, category, 1.0)


# ---- timed windows and cooldowns ("pid:key" -> msec)

func _active(pid: int, key: String) -> bool:
	return Time.get_ticks_msec() < int(_until.get("%d:%s" % [pid, key], 0))


func _open_window(pid: int, key: String, seconds: float) -> void:
	_until["%d:%s" % [pid, key]] = Time.get_ticks_msec() + int(seconds * 1000.0)


func _proc(pid: int, perk_id: StringName, effect: StringName) -> void:
	perk_proc.emit(pid, perk_id, effect)
	_first_vo(pid, "proc", "PERK_PROC")


## A perk effect fired for `pid` (world code: Skyhook's hop, the Lodestone's Ballast...): the proc signal and the
## survivor's first-of-match line.
func note_proc(pid: int, perk_id: StringName, effect: StringName) -> void:
	_proc(pid, perk_id, effect)


# ---------------------------------------------------------------- Skyhook Sekt III: the stomp (UPDATE 07, T-105)

## Damage one stomp does to a zombie of this round's health (hop_stomp_health_mult x health(r)); bosses take the
## flat hop_stomp_boss_damage.
static func stomp_damage(round_health: float, boss: bool, effects: Dictionary) -> float:
	if boss:
		return float(effects.get("hop_stomp_boss_damage", 400.0))
	return float(effects.get("hop_stomp_health_mult", 0.4)) * round_health


## Landing from a Skyhook hop with Stall Turn: every zombie within hop_stomp_radius is hurt and staggered
## (hop_stomp_max_targets, nearest first). Lifted zombies are left to the Lodestone.
func hop_stomp(p: Player) -> void:
	var fx: Dictionary = effects_for(&"skyhook_sekt", tier_of(p.player_id, &"skyhook_sekt"))
	var radius: float = float(fx.get("hop_stomp_radius", 2.5))
	var director: Node = get_tree().get_first_node_in_group(&"director")
	if director == null or not director.has_method("active_zombies"):
		return
	var hr: float = float(RoundManager.zombie_health(maxi(1, RoundManager.current_round), GLData.table("rounds")))
	var cands: Array = []
	for z: Zombie in director.call("active_zombies"):
		if not z.is_active() or z.is_lifted():
			continue
		var d: float = z.global_position.distance_to(p.global_position)
		if d <= radius:
			cands.append([d, z])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var n: int = mini(int(fx.get("hop_stomp_max_targets", 8)), cands.size())
	for i: int in n:
		var z: Zombie = cands[i][1] as Zombie
		var boss: bool = OVERCLOCK_BOSSES.has(String(z.enemy_id)) or z is HomageBoss
		if not z.take_damage(stomp_damage(hr, boss, fx), &"torso", &"skyhook_sekt", p.player_id, &"explosive", true) and not boss:
			z.force_stagger()
	if n > 0:
		Effects.explosion(p.global_position + Vector3.UP * 0.2, radius * 0.5)
		AudioDirector.play_3d("perk_skyhook_stomp", p.global_position, -4.0, 0.1)
		_proc(p.player_id, &"skyhook_sekt", &"stomp")


# ---------------------------------------------------------------- Magpie Mead (UPDATE 07, T-105)

var _magpie_last: Dictionary = {}     # pid -> {limb, weapon, kind} of the kill that enemy_killed_at follows
var _magpie_cd: Dictionary = {}       # pid -> ms until the next roll
var _magpie_count: Dictionary = {}    # pid -> drops so far this match (Pawn Shop's every-25th)
var magpie_rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The drop chance of one kill: magpie_head_chance on a head or melee kill, else magpie_chance.
static func magpie_chance(effects: Dictionary, limb: StringName, melee: bool) -> float:
	if limb == &"head" or melee:
		return float(effects.get("magpie_head_chance", 0.0))
	return float(effects.get("magpie_chance", 0.0))


## What a drop is: "ammo" / "scrip" / "grenade" by the magpie_w_* weights, from one roll in [0, 1).
static func magpie_kind(effects: Dictionary, roll: float) -> StringName:
	var wa: float = float(effects.get("magpie_w_ammo", 0.5))
	var ws: float = float(effects.get("magpie_w_scrip", 0.35))
	var wg: float = float(effects.get("magpie_w_grenade", 0.15))
	var tot: float = maxf(0.001, wa + ws + wg)
	var r: float = roll * tot
	if r < wa:
		return &"ammo"
	if r < wa + ws:
		return &"scrip"
	return &"grenade"


## Scrip in a Scrip drop on this round.
static func magpie_scrip(effects: Dictionary, round_number: int) -> int:
	return mini(int(effects.get("magpie_scrip_max", 250)), int(effects.get("magpie_scrip_base", 60)) + int(effects.get("magpie_scrip_per_round", 10)) * maxi(1, round_number))


func _on_enemy_killed_magpie(_enemy_id: StringName, limb: StringName, weapon_id: StringName, by_player: int) -> void:
	if by_player <= 0 or not has_perk(by_player, &"magpie_mead"):
		return
	_magpie_last[by_player] = {"limb": limb, "weapon": weapon_id}


func _on_enemy_killed_at_magpie(_enemy_id: StringName, position: Vector3, by_player: int) -> void:
	if by_player <= 0 or not _magpie_last.has(by_player) or not Net.is_authority():
		return
	var last: Dictionary = _magpie_last[by_player]
	_magpie_last.erase(by_player)
	var now: int = Time.get_ticks_msec()
	if int(_magpie_cd.get(by_player, 0)) > now:
		return
	var fx: Dictionary = effects_for(&"magpie_mead", tier_of(by_player, &"magpie_mead"))
	var melee: bool = String(last.get("weapon", "")) in ["trench_knife", "etool", "mallet", "kinderhammer", "service_key"]
	if magpie_rng.randf() >= magpie_chance(fx, StringName(last.get("limb", &"torso")), melee):
		return
	_magpie_cd[by_player] = now + int(float(fx.get("magpie_cooldown", 1.5)) * 1000.0)
	spawn_magpie_drop(by_player, position, fx, StringName(last.get("weapon", "")))


## Places one drop at `position` for `pid` (every 25th on Pawn Shop is a power-up). Returns the drop node.
func spawn_magpie_drop(pid: int, position: Vector3, fx: Dictionary, weapon_id: StringName = &"") -> Node3D:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if parent is MapRoot:
		position = (parent as MapRoot).clamp_inside(position)
	var count: int = int(_magpie_count.get(pid, 0)) + 1
	_magpie_count[pid] = count
	var drop: MagpieDrop = MagpieDrop.new()
	var every: int = int(fx.get("magpie_powerup_every", 0))
	if every > 0 and count % every == 0:
		drop.kind = &"powerup"
		drop.powerup_id = &"resupply" if magpie_rng.randf() < 0.5 else &"double_scrip"
	else:
		drop.kind = magpie_kind(fx, magpie_rng.randf())
	match drop.kind:
		&"ammo":
			drop.amount = int(fx.get("magpie_mags", 1))
			var near: float = float(fx.get("magpie_upgraded_near_m", 0.0))
			drop.upgraded_ammo = near > 0.0 and String(weapon_id).ends_with("_up")
		&"scrip":
			drop.amount = magpie_scrip(fx, RoundManager.current_round)
		_:
			drop.amount = 1
	drop.owner_pid = pid
	drop.shared = bool(fx.get("magpie_shared", false))
	drop.life = float(fx.get("magpie_life", 20.0))
	parent.add_child(drop)
	drop.global_position = position + Vector3.UP * 0.25
	AudioDirector.play_3d("perk_magpie_drop", drop.global_position, -6.0, 0.1)
	GLBus.magpie_drop.emit(pid, drop.kind, drop.global_position)
	return drop


## A drop was picked up: the proc line (once a match) and the tonic's signal.
func magpie_taken(pid: int, kind: StringName) -> void:
	_proc(pid, &"magpie_mead", kind)


## Scavenger (Magpie II): the economy's salvage (dog tag) chance for this killer is multiplied.
func salvage_mult(pid: int) -> float:
	return float(stat(pid, "salvage_mult", 1.0))


## Tests: forget every window and cooldown.
func clear_tier_timers() -> void:
	_magpie_cd.clear()
	_magpie_count.clear()
	_magpie_last.clear()
	_until.clear()
	_last_shot_ms.clear()


# ---- effect hooks

## Player.take_hit (the owner's machine, bots on the host): what is left of a hit. Second Wind III's revive window
## and Ironhide III's iron skin stop it; Marathon III sidesteps one swipe every 8 s while sprinting. Ironhide III's
## skin is opened by the hit that leaves you under 30% (that hit still lands, and a fatal one is not stopped).
func filter_hit(p: Player, amount: float) -> float:
	if p == null or amount <= 0.0:
		return amount
	var pid: int = p.player_id
	if _active(pid, "invuln") or _active(pid, "iron_skin"):
		return 0.0
	if float(_overshield.get(pid, 0.0)) > 0.0:
		var ab: Array = absorb(amount, float(_overshield[pid]))
		_overshield[pid] = float(ab[1])
		amount = float(ab[0])
		if amount <= 0.0:
			return 0.0
	var dodge_cd: float = float(stat(pid, "sprint_dodge_cooldown", 0.0))
	if dodge_cd > 0.0 and p.sprinting and not _active(pid, "dodge_cd"):
		_open_window(pid, "dodge_cd", dodge_cd)
		_boost(pid, float(stat(pid, "sprint_dodge_boost_mult", 1.15)), float(stat(pid, "sprint_dodge_boost_seconds", 1.5)))
		_proc(pid, &"marathon_malt", &"dodge")
		return 0.0
	# Ironhide IV (T-129): once a round, the hit that would put you down leaves you on 1 hp with a window of iron
	var last: float = float(stat(pid, "last_stand_invuln_seconds", 0.0))
	if last > 0.0 and amount >= p.hp and int(_last_stand_round.get(pid, -1)) != RoundManager.current_round:
		_last_stand_round[pid] = RoundManager.current_round
		_open_window(pid, "iron_skin", last)
		_proc(pid, &"ironhide_stout", &"last_stand")
		return maxf(0.0, p.hp - 1.0)
	var thr: float = float(stat(pid, "iron_skin_threshold", 0.0))
	if thr > 0.0 and not _active(pid, "iron_cd"):
		var left: float = p.hp - amount
		if left > 0.0 and left < p.max_hp * thr:
			_open_window(pid, "iron_skin", float(stat(pid, "iron_skin_seconds", 2.0)))
			_open_window(pid, "iron_cd", float(stat(pid, "iron_skin_cooldown", 40.0)))
			_proc(pid, &"ironhide_stout", &"iron_skin")
	return amount


func _boost(pid: int, mult: float, seconds: float) -> void:
	if mult <= 1.0 or seconds <= 0.0:
		return
	_boost_mult[pid] = mult
	_open_window(pid, "boost", seconds)


## True while a tier window protects the player from damage (HUD / tests).
func is_protected(pid: int) -> bool:
	return _active(pid, "invuln") or _active(pid, "iron_skin")


## Once per shot, before its damage (WeaponHolder._fire, BotAim.fire): Trigger Tonic III's fresh clip and Hawkeye
## III's patience (an aimed shot 1.2 s or more after the last one). Also records the shot's time.
func shot_mult(pid: int, aimed: bool) -> float:
	var now: int = Time.get_ticks_msec()
	var m: float = 1.0
	if _active(pid, "fresh_clip"):
		m *= float(stat(pid, "fresh_clip_damage_mult", 1.0))
	var patience: float = float(stat(pid, "patience_seconds", 0.0))
	if patience > 0.0 and aimed and now - int(_last_shot_ms.get(pid, -1000000)) >= int(patience * 1000.0):
		m *= float(stat(pid, "patience_damage_mult", 1.0))
		perk_proc.emit(pid, &"hawkeye_brandy", &"patience")
	_last_shot_ms[pid] = now
	var shock: int = int(_shock_left.get(pid, 0))
	if shock > 0:   # Trigger Tonic IV: a shock round
		_shock_left[pid] = shock - 1
		m *= float(stat(pid, "shock_damage_mult", 1.6))
		_last_shock_ms[pid] = now
	var every: int = int(stat(pid, "double_hit_every", 0))
	if every > 0:   # Twin Barrel IV: every nth bullet hits twice
		_shots_fired[pid] = int(_shots_fired.get(pid, 0)) + 1
		if int(_shots_fired[pid]) % every == 0:
			m *= 2.0
			perk_proc.emit(pid, &"twin_barrel", &"double")
	return m


## Trigger Tonic IV: the shot just taken was a shock round (WeaponHolder / BotAim stagger what it hits).
var _last_shock_ms: Dictionary = {}
func shot_is_shock(pid: int) -> bool:
	return bool(stat(pid, "shock_stagger", false)) and Time.get_ticks_msec() - int(_last_shock_ms.get(pid, -100000)) < 50


## Pure: Twin Barrel IV doubles every `every`th bullet (n counted from 1).
static func double_hit(n: int, every: int) -> bool:
	return every > 0 and n > 0 and n % every == 0


## Twin Barrel III: this shot costs no round (never for wonder weapons).
func round_saved(pid: int, w: WeaponInstance) -> bool:
	var chance: float = float(stat(pid, "ammo_save_chance", 0.0))
	if chance <= 0.0 or w == null or w.weapon_class() == &"wonder":
		return false
	return randf() < chance


## A bullet kill: Hawkeye II puts a round back in the magazine for a headshot kill.
func on_bullet_kill(pid: int, w: WeaponInstance, head: bool, at: Vector3 = Vector3.INF) -> void:
	if not head or w == null:
		return
	var chain: float = float(stat(pid, "headshot_chain_mult", 0.0))
	if chain > 0.0 and at.is_finite() and Net.is_authority():
		_headshot_chain(pid, w, at, chain)
	var n: int = int(stat(pid, "headshot_kill_refund", 0))
	if n > 0 and w.mag < w.mag_size():
		w.mag = mini(w.mag_size(), w.mag + n)
		perk_proc.emit(pid, &"hawkeye_brandy", &"refund")


## Hawkeye IV (T-129): a headshot kill at `at` sends a `mult`-strength shot of the same gun on to the nearest
## active zombie within headshot_chain_range (a tracer shows it).
func _headshot_chain(pid: int, w: WeaponInstance, at: Vector3, mult: float) -> void:
	var director: Node = get_tree().get_first_node_in_group(&"director") if is_inside_tree() else null
	if director == null or not director.has_method("active_zombies"):
		return
	var reach: float = float(stat(pid, "headshot_chain_range", 15.0))
	var best: Zombie = null
	var best_d: float = reach
	for z: Zombie in director.call("active_zombies"):
		var dd: float = z.global_position.distance_to(at)
		if z.is_active() and dd > 0.5 and dd < best_d:
			best_d = dd
			best = z
	if best == null:
		return
	var to: Vector3 = best.global_position + Vector3.UP * 1.5
	Effects.tracer(at, to, w.upgraded, w.weapon_class())
	best.take_damage(w.f("damage", 50.0) * mult, &"head", w.id, pid, &"bullet")
	perk_proc.emit(pid, &"hawkeye_brandy", &"chain")


## A reload completed: Trigger Tonic III opens its fresh-clip window; Trigger Tonic IV loads shock rounds when the
## magazine had `shock_reload_frac` or less left in it (`frac_before`: what was left over the mag size).
func reload_finished(pid: int, frac_before: float = 1.0) -> void:
	var secs: float = float(stat(pid, "fresh_clip_seconds", 0.0))
	if secs > 0.0:
		_open_window(pid, "fresh_clip", secs)
	var n: int = int(stat(pid, "shock_rounds", 0))
	if n > 0 and frac_before <= float(stat(pid, "shock_reload_frac", 0.34)):
		_shock_left[pid] = n
		_proc(pid, &"trigger_tonic", &"shock")


## Packmule II: ammo bought at the chalk or an ammo box costs this much of the price.
func ammo_price_mult(pid: int) -> float:
	return float(stat(pid, "ammo_price_mult", 1.0))


## Packmule II: extra lethal grenades carried.
func grenade_bonus(pid: int) -> int:
	return int(stat(pid, "grenade_bonus", 0))


## Blastproof II: an explosion that reaches a Blastproof player heals instead (Explosion.detonate, local players).
func blast_heal(p: Player, pos: Vector3, radius: float) -> void:
	var heal: float = float(stat(p.player_id, "blast_heal", 0.0))
	if heal <= 0.0 or p.downed or pos.distance_to(p.global_position + Vector3.UP) > radius:
		return
	p.hp = minf(p.max_hp, p.hp + heal)
	_proc(p.player_id, &"blastproof_bock", &"blast_heal")


## Blastproof III: the slide shockwave's damage grows with the round (at least slide_shockwave_round_mult x a
## zombie's health this round).
func slide_shock_damage(pid: int, base: float) -> float:
	var m: float = float(stat(pid, "slide_shockwave_round_mult", 0.0))
	var mult: float = float(stat(pid, "slide_shockwave_mult", 1.0))   # Blastproof IV: twice as hard
	if m <= 0.0:
		return base * mult
	return maxf(base, m * float(RoundManager.zombie_health(maxi(1, RoundManager.current_round), GLData.table("rounds")))) * mult


## One zombie in a slide shockwave: the damage, and Blastproof III knocks down what survives it (not bosses).
func slide_hit(p: Player, z: Zombie, dmg: float) -> void:
	if z.is_crawler and bool(stat(p.player_id, "slide_kills_crawlers", false)) and not OVERCLOCK_BOSSES.has(String(z.enemy_id)):
		dmg = maxf(dmg, z.hp + 1.0)   # Blastproof IV: a crawler doesn't get up from it
	var killed: bool = z.take_damage(dmg, &"torso", &"blastproof_bock", p.player_id, &"explosive")
	if not killed and z.is_active() and bool(stat(p.player_id, "slide_shockwave_stagger", false)) and not OVERCLOCK_BOSSES.has(String(z.enemy_id)):
		z.force_stagger()


## Overclock II (Live Wire): arcs jump from the burst to the nearest zombies outside it, out to arc_reach x radius.
func _overclock_arcs(player: Player, e: float, radius: float, hit: Array, health_r: float) -> void:
	var n: int = int(stat(player.player_id, "overclock_arcs", 0))
	if n <= 0:
		return
	var director: Node = get_tree().get_first_node_in_group(&"director")
	if director == null or not director.has_method("active_zombies"):
		return
	var done: Array = hit.map(func(x: Array) -> Variant: return x[1])
	var reach: float = radius * float(stat(player.player_id, "overclock_arc_reach_mult", 2.0))
	var cands: Array = []
	for z: Zombie in director.call("active_zombies"):
		if done.has(z) or not z.is_active():
			continue
		var d: float = z.global_position.distance_to(player.global_position)
		if d <= reach:
			cands.append([d, z])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var mult: float = float(stat(player.player_id, "overclock_arc_damage_mult", 0.5))
	for i: int in mini(n, cands.size()):
		var z2: Zombie = cands[i][1]
		var boss: bool = OVERCLOCK_BOSSES.has(String(z2.enemy_id))
		z2.take_damage(overclock_damage(e, health_r, boss, z2.enemy_id == &"repossessor") * mult, &"torso", OVERCLOCK,
			player.player_id, &"electric", true)
		Effects.static_burst(z2.global_position + Vector3.UP * 0.9, 0.8)
	if cands.size() > 0:
		perk_proc.emit(player.player_id, OVERCLOCK, &"arcs")


## Packmule III (Training Load): every round from the second, each gun a Packmule III player carries gets a share of
## its reserve back, and a grenade. Runs where the inventory lives: the local player, and bots on the host.
func _on_round_started_tiers(round_number: int, _special: bool) -> void:
	if round_number <= 1 or not is_inside_tree():
		return
	_refill_self_revive(round_number)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.weapons == null or p.spectating or not (p.is_local or (p.is_bot and Net.is_authority())):
			continue
		resupply(p)


## Packmule III's round-start share for one player (public for tests). True when it gave anything.
func resupply(p: Player) -> bool:
	var frac: float = float(stat(p.player_id, "round_resupply_frac", 0.0))
	if frac <= 0.0:
		return false
	var mags: bool = bool(stat(p.player_id, "round_resupply_mags", false))   # Packmule IV: and a full magazine
	for w: WeaponInstance in p.weapons.slots:
		if w != null and w.weapon_class() != &"wonder":
			w.reserve = mini(w.reserve_max(), w.reserve + ceili(float(w.reserve_max()) * frac))
			if mags:
				w.mag = w.mag_size()
	p.weapons.grenades = mini(p.weapons.grenade_max(), p.weapons.grenades + int(stat(p.player_id, "round_resupply_grenades", 0)))
	perk_proc.emit(p.player_id, &"packmule_porter", &"resupply")
	return true


## Second Wind IV (T-129): in solo, a spent self-revive comes back every self_revive_refill_rounds rounds (to the
## starting three at most) while a survivor holds Second Wind IV (it is permanent, so the tonic is still there).
func _refill_self_revive(round_number: int) -> void:
	if not GameState.is_solo() or not Net.is_authority():
		return
	for pid: Variant in _owned.keys():
		var every: int = int(stat(int(pid), "self_revive_refill_rounds", 0))
		if every > 0 and round_number % every == 0:
			var most: int = int(GLData.table("perks").get("solo_self_revives", 3))
			if solo_self_revives_left < most:
				solo_self_revives_left += 1
				second_wind_gone = false
				_proc(int(pid), &"second_wind", &"refill")
			return


## Marathon IV (T-129): a sprinting survivor knocks down every (non-boss) zombie within sprint_knockdown_radius in
## front of them; each zombie once per sprint_knockdown_cooldown. Ticked ~10 times a second, on the host.
func _tick_knockdown(delta: float) -> void:
	_knock_tick -= delta
	if _knock_tick > 0.0 or not Net.is_authority() or not is_inside_tree():
		return
	_knock_tick = 0.1
	var director: Node = get_tree().get_first_node_in_group(&"director")
	if director == null or not director.has_method("active_zombies"):
		return
	var now: int = Time.get_ticks_msec()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.sprinting or p.downed:
			continue
		var r: float = float(stat(p.player_id, "sprint_knockdown_radius", 0.0))
		if r <= 0.0:
			continue
		var fwd: Vector3 = -p.global_basis.z
		for z: Zombie in director.call("active_zombies"):
			var to: Vector3 = z.global_position - p.global_position
			to.y = 0.0
			if to.length() > r or (to.length() > 0.3 and fwd.dot(to.normalized()) < 0.2) or OVERCLOCK_BOSSES.has(String(z.enemy_id)):
				continue
			var key: int = z.get_instance_id()
			if now < int(_knock_at.get(key, 0)):
				continue
			_knock_at[key] = now + int(float(stat(p.player_id, "sprint_knockdown_cooldown", 2.0)) * 1000.0)
			z.force_stagger()
			_proc(p.player_id, &"marathon_malt", &"knockdown")


## Second Wind II / III on a revive: the reviver's tier (or, for a solo self-revive, the tier that was used up) gives
## the revived player a speed boost (II) and a few seconds nothing can hurt them, and knocks down every zombie close by
## (III).
func _on_player_revived_tiers(pid: int, by_player: int) -> void:
	var t: int = int(_revive_tier.get(pid, 1)) if by_player == pid else tier_of(by_player, &"second_wind")
	_revive_tier.erase(pid)
	if t <= 1:
		return
	var fx: Dictionary = effects_for(&"second_wind", t)
	_boost(pid, float(fx.get("revive_boost_mult", 1.0)), float(fx.get("revive_boost_seconds", 0.0)))
	var inv: float = float(fx.get("revive_invuln_seconds", 0.0))
	if inv > 0.0:
		_open_window(pid, "invuln", inv)
	var r: float = float(fx.get("revive_stagger_radius", 0.0))
	if r > 0.0 and Net.is_authority() and is_inside_tree():
		var director: Node = get_tree().get_first_node_in_group(&"director")
		var who: Node3D = null
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			if n is Player and (n as Player).player_id == pid:
				who = n as Node3D
		if director != null and who != null and director.has_method("active_zombies"):
			for z: Zombie in director.call("active_zombies"):
				if z.global_position.distance_to(who.global_position) <= r and not OVERCLOCK_BOSSES.has(String(z.enemy_id)):
					z.force_stagger()
	_proc(by_player if by_player > 0 else pid, &"second_wind", &"revive")
