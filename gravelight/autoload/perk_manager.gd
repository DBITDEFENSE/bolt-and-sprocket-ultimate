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
##   on_player_downed(player) -> void          co-op rule: every perk is lost
##   reset_match() -> void

## Emitted when the solo Second Wind machine has used its last self-revive and should leave.
signal second_wind_retired

var _owned: Dictionary = {}        # player -> Array[StringName]
var _bonus_slots: Dictionary = {}  # player -> int (Map 1 egg reward)
var solo_self_revives_left: int = 3
var second_wind_gone: bool = false
var _hud: CanvasLayer = null


func _ready() -> void:
	GLBus.match_started.connect(_on_match_started)


func reset_match() -> void:
	_owned.clear()
	_bonus_slots.clear()   # the Map 1 egg slot is re-applied on match_started
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
	if owned(player).size() >= cap_for(player):
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


## Co-op rule (and solo without Second Wind): every perk is lost on going down.
func on_player_downed(player: int) -> void:
	if not Net.is_authority() or owned(player).is_empty():
		return
	_owned[player] = []
	GLBus.perks_lost.emit(player)
	GLBus.perks_changed.emit(player)


static func cost_for(perk: Dictionary, solo: bool) -> int:
	if not solo and perk.has("cost_coop"):
		return int(perk["cost_coop"])
	return int(perk.get("cost", 0))
