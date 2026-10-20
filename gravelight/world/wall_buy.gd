class_name WallBuy
extends Interactable
## Chalk outline on a wall. Buys the weapon, or ammo for it if you already own it.
## Special ids: "frag" refills grenades, "etool" swaps the knife for the E-Tool.
## Local -Z faces out of the wall toward the player.

@export var weapon_id: StringName = &"kar98k"


func _weapon_data() -> Dictionary:
	var w: Dictionary = GLData.table("weapons")
	if w["weapons"].has(String(weapon_id)):
		return w["weapons"][String(weapon_id)]
	if w["melee"].has(String(weapon_id)):
		return w["melee"][String(weapon_id)]
	if w["lethal"].has(String(weapon_id)):
		return w["lethal"][String(weapon_id)]
	push_error("WallBuy: unknown weapon %s" % weapon_id)
	return {}


func price() -> int:
	return int(_weapon_data().get("wall_price", 0))


func ammo_price(player: Player) -> int:
	var inst: WeaponInstance = player.weapons.find_weapon_base(weapon_id)
	if inst != null and inst.upgraded:
		return int(GLData.table("economy")["wallbuy_upgraded_ammo"])
	return int(round(price() * float(GLData.table("economy")["wallbuy_ammo_fraction"])))


func _mode(player: Player) -> StringName:
	if weapon_id == &"frag":
		return &"frag"
	if weapon_id == &"etool":
		return &"owned_melee" if player.weapons.melee_id == &"etool" else &"melee"
	if player.weapons.find_weapon_base(weapon_id) != null:
		return &"ammo"
	return &"buy"


func get_prompt(player: Player) -> String:
	var d: Dictionary = _weapon_data()
	var key: String = prompt_key(&"interact")
	match _mode(player):
		&"frag":
			if player.weapons.grenades >= player.weapons.grenade_max():
				return "Grenades full"
			return "Hold [%s] to buy %s [%d]" % [key, d.get("name", "Frags"), price()]
		&"owned_melee":
			return ""
		&"melee":
			return "Hold [%s] to buy %s [%d]" % [key, d.get("name", ""), price()]
		&"ammo":
			if player.weapons.find_weapon_base(weapon_id).is_full():
				return "%s ammo full" % d.get("name", "")
			return "Hold [%s] for Ammo [%d]" % [key, ammo_price(player)]
	return "Hold [%s] to buy %s [%d]" % [key, d.get("name", ""), price()]


func can_interact(player: Player) -> bool:
	match _mode(player):
		&"frag":
			return player.weapons.grenades < player.weapons.grenade_max()
		&"owned_melee":
			return false
		&"ammo":
			return not player.weapons.find_weapon_base(weapon_id).is_full()
	return true


func interact(player: Player) -> void:
	match _mode(player):
		&"frag":
			if try_purchase(player, weapon_id, price()):
				player.weapons.refill_grenades()
				GLBus.ammo_bought.emit(player.player_id, weapon_id)
		&"melee":
			if try_purchase(player, weapon_id, price()):
				player.weapons.set_melee(weapon_id)
				GLBus.weapon_acquired.emit(player.player_id, weapon_id, &"wall")
		&"ammo":
			if try_purchase(player, StringName(String(weapon_id) + "_ammo"), ammo_price(player)):
				player.weapons.refill_weapon(weapon_id)
				feedback_2d(player, "reload_end")
				GLBus.ammo_bought.emit(player.player_id, weapon_id)
		&"buy":
			if try_purchase(player, weapon_id, price()):
				player.weapons.give_weapon(weapon_id)
				GLBus.weapon_acquired.emit(player.player_id, weapon_id, &"wall")


func _ready() -> void:
	interact_size = Vector3(1.4, 0.9, 0.22)
	super._ready()


func build_greybox() -> void:
	var board: StandardMaterial3D = greybox_mat(Color(0.18, 0.45, 0.2))
	add_box(self, Vector3(1.3, 0.55, 0.04), Vector3(0, 0, 0.02), board)
	# Chalk outline traced from the weapon's real model (a flattened, glowing white silhouette).
	var d: Dictionary = _weapon_data()
	var chalk_model: Node3D = WeaponModels.build_chalk(weapon_id, 1.15)
	chalk_model.position = Vector3(0, -0.02, -0.012)
	add_child(chalk_model)
	add_label(self, "%s  %d" % [d.get("name", weapon_id), price()], Vector3(0, 0.38, -0.03), 20, Color(0.8, 1, 0.8, 0.85))
	interact_offset = Vector3(0, 0, -0.12)
	if area != null:
		(area.get_child(0) as CollisionShape3D).position = interact_offset
