class_name WeaponParcel
extends Interactable
## A wall weapon a bot bought for a teammate (Update 04 section 3, "Buy for teammate", DECISIONS T-069). While the
## bot carries it, it hangs at the bot's side and the player can take it off them (hold Use looking at the bot);
## once the bot reaches the player it lies at their feet until they pick it up. Only the player it was bought for
## can take it (paid with the bot's Scrip); taking it is like a wall-buy (a free slot, or the gun in hand goes).

signal taken(by_pid: int)

var weapon_id: StringName = &""
var for_pid: int = 0
var from_pid: int = 0
var carried: bool = false
var _model: Node3D = null
var _label: Label3D = null
var _t: float = 0.0


static func make(wid: StringName, for_player: int, from_player: int) -> WeaponParcel:
	var p: WeaponParcel = WeaponParcel.new()
	p.name = "WeaponParcel_%s" % String(wid)
	p.weapon_id = wid
	p.for_pid = for_player
	p.from_pid = from_player
	p.interact_size = Vector3(1.0, 1.4, 1.0)
	p.add_to_group(&"weapon_parcels")
	return p


func _gun_name() -> String:
	var row: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(weapon_id), {})
	return str(row.get("name", String(weapon_id).capitalize()))


func build_greybox() -> void:
	_model = WeaponModels.build(weapon_id)
	if _model != null:
		add_child(_model)
	_label = add_label(self, "", Vector3(0, 0.45, 0), 18, Color(1.0, 0.92, 0.7, 0.95))
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	if for_pid <= 0:
		_label.text = "%s (dropped)" % _gun_name() if not carried else ""   # T-142: a fallen soldier's gun, anyone's
		return
	var who: String = Net.display_name(from_pid)
	_label.text = "%s from %s" % [_gun_name(), who] if not carried else ""


## Hangs it on the bot that bought it (the player can take it from them).
func carry_on(bot: Player) -> void:
	carried = true
	if get_parent() != bot:
		if get_parent() != null:
			get_parent().remove_child(self)
		bot.add_child(self)
	position = Vector3(0.32, 1.0, 0.1)
	rotation = Vector3(0.0, PI * 0.5, deg_to_rad(-70.0))
	scale = Vector3.ONE * 0.8
	_refresh_label()


## Lays it on the floor at `at` (the player's feet), in the level.
func drop_at(at: Vector3) -> void:
	carried = false
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var p: Node = get_parent()
	if p != null:
		p.remove_child(self)
	root.add_child(self)
	global_position = at + Vector3.UP * 0.12
	rotation = Vector3(0.0, randf() * TAU, PI * 0.5)
	scale = Vector3.ONE
	_refresh_label()


func _process(delta: float) -> void:
	_t += delta
	if not carried and _model != null:
		_model.position.y = 0.05 + sin(_t * 2.0) * 0.02


func get_prompt(player: Player) -> String:
	if for_pid <= 0:
		return "Hold [%s] to take the dropped %s" % [prompt_key(&"interact"), _gun_name()]   # T-142
	if player.player_id != for_pid:
		return ""
	return "Hold [%s] to take the %s (%s bought it for you)" % [prompt_key(&"interact"), _gun_name(), Net.display_name(from_pid)]


func can_interact(player: Player) -> bool:
	return (for_pid <= 0 or player.player_id == for_pid) and player.weapons != null


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	player.weapons.give_weapon(weapon_id)
	GLBus.weapon_acquired.emit(player.player_id, weapon_id, &"teammate" if for_pid > 0 else &"pickup")
	AudioDirector.play_3d("buy", global_position, -6.0)
	taken.emit(player.player_id)
	queue_free()
