class_name WallBuy
extends Interactable
## Chalk outline on a wall. Buys the weapon, or ammo for it if you already own it.
## Special ids: "frag" refills grenades, "etool" swaps the knife for the E-Tool.
## With Jakub (U02 section 6.2) standing beside it and no gun of his own, a gun wall-buy sells to him instead.
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
	var mult: float = PerkManager.ammo_price_mult(player.player_id)   # Packmule II: half price (T-075)
	if inst != null and inst.upgraded:
		return int(round(int(GLData.table("economy")["wallbuy_upgraded_ammo"]) * mult))
	return int(round(price() * float(GLData.table("economy")["wallbuy_ammo_fraction"]) * mult))


func _mode(player: Player) -> StringName:
	if weapon_id == &"frag":
		return &"frag"
	if weapon_id == &"etool":
		return &"owned_melee" if player.weapons.melee_id == &"etool" else &"melee"
	if player.weapons.find_weapon_base(weapon_id) != null:
		return &"ammo"
	return &"buy"


func get_prompt(player: Player) -> String:
	var p: String = _prompt(player)
	if p == "" or player.is_bot:
		return p
	# the chalk under the gun (T-075, PERKS_LORE.md: Standing Order 17): its line, and the map's chalk entry is filed
	var line: String = MachineLore.plate(MachineLore.here(), "chalk." + String(weapon_id))
	if line != "":
		MachineLore.file_once(MachineLore.here(), "chalk")
		return p + "\n" + line
	return p


func _prompt(player: Player) -> String:
	var d: Dictionary = _weapon_data()

	var key: String = prompt_key(&"interact")
	if JakubCompanion.buys_here(self, player):
		return "Hold [%s] to buy the %s for Jakub [%s]" % [key, d.get("name", ""), price_str(player, price())]
	match _mode(player):
		&"frag":
			if player.weapons.grenades >= player.weapons.grenade_max():
				return "Grenades full"
			return "Hold [%s] to buy %s [%s]" % [key, d.get("name", "Frags"), price_str(player, price())]
		&"owned_melee":
			return ""
		&"melee":
			return "Hold [%s] to buy %s [%s]" % [key, d.get("name", ""), price_str(player, price())]
		&"ammo":
			if player.weapons.find_weapon_base(weapon_id).is_full():
				return "%s ammo full" % d.get("name", "")
			return "Hold [%s] for Ammo [%s]" % [key, price_str(player, ammo_price(player))]
	return "Hold [%s] to buy %s [%s]" % [key, d.get("name", ""), price_str(player, price())]


func can_interact(player: Player) -> bool:
	if JakubCompanion.buys_here(self, player):
		return true
	match _mode(player):
		&"frag":
			return player.weapons.grenades < player.weapons.grenade_max()
		&"owned_melee":
			return false
		&"ammo":
			return not player.weapons.find_weapon_base(weapon_id).is_full()
	return true


func interact(player: Player) -> void:
	if JakubCompanion.buys_here(self, player):
		# Jakub beside you and no gun of his own: you buy this one for him at the normal price (U02 section 6.2)
		if try_purchase(player, StringName(String(weapon_id) + "_for_jakub"), price()):
			JakubCompanion.bought_for_him(self, player)
		return
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
	# the green board (the readability cue): our painted planks (T-094), the flat greybox board when absent
	var board_mesh: Mesh = WorldArt.part_mesh("wall_mount", "Board")
	if board_mesh != null:
		var bm: MeshInstance3D = MeshInstance3D.new()
		bm.name = "Board"
		bm.mesh = board_mesh
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bm)
	else:
		var board: StandardMaterial3D = greybox_mat(Color(0.18, 0.45, 0.2))
		add_box(self, Vector3(1.3, 0.55, 0.04), Vector3(0, 0, 0.02), board)
	# Chalk outline traced from the weapon's real model (a flattened, glowing white silhouette).
	var d: Dictionary = _weapon_data()
	# 2026-11-12 (the owner: "wall guns all fucked up"): build_chalk lays the outline from the gun's grip, so its centre sat
	# up to 0.45 m off the board's (a Kar98k's ran 0.25 m past the 1.3 m board's end, the mounted gun with it). The
	# outline is kept inside the board now (1.05 m at most, 0.12 m of plank at each end) and centred on it.
	var chalk_model: Node3D = WeaponModels.build_chalk(weapon_id, CHALK_MAX_LEN if board_mesh != null else 1.15)
	chalk_model.position = Vector3(0, -0.02, -0.012)
	add_child(chalk_model)
	var ca: AABB = chalk_model.transform * WorldArt.local_aabb(chalk_model)
	if ca.size.x > 0.01:
		chalk_model.position += Vector3(-ca.get_center().x, -0.02 - ca.get_center().y, 0.0)
	if board_mesh != null:
		_mount_gun(chalk_model)
	var lbl: Label3D = add_label(self, "%s  %d" % [d.get("name", weapon_id), price()], Vector3(0, 0.38, -0.03), 20, Color(0.8, 1, 0.8, 0.85))
	if board_mesh != null:
		lbl.font = MenuKit.font("stamp")
	interact_offset = Vector3(0, 0, -0.12)
	if area != null:
		(area.get_child(0) as CollisionShape3D).position = interact_offset


# ------------------------------------------------------------------ the mounted gun (UPDATE_05 section 5, T-094)

## How much of the chalk outline the gun covers: a little smaller, so the chalk still frames it.
const MOUNT_FILL: float = 0.92
## The longest chalk outline on the painted board (1.3 m wide): its ends stay on the planks.
const CHALK_MAX_LEN: float = 1.05
static var _dust: StandardMaterial3D = null
static var _clean: Dictionary = {}   # a downloaded material -> its opaque, non-glowing copy


## The real gun on two nails over its chalk (the same model the chalk is traced from), centred on the outline, a
## touch smaller, resting on its nails a few centimetres off the board, dusty.
func _mount_gun(chalk: Node3D) -> void:
	var gun: Node3D = _gun_model()
	if gun == null:
		return
	gun.name = "MountedGun"
	add_child(gun)
	var cb: AABB = chalk.transform * WorldArt.local_aabb(chalk)
	var gb: AABB = WorldArt.local_aabb(gun)
	if gb.size.x < 0.01 or cb.size.x < 0.01:
		gun.queue_free()
		return
	var k: float = cb.size.x * MOUNT_FILL / gb.size.x
	gun.scale *= k
	gb = gun.transform * WorldArt.local_aabb(gun)   # (the gun's own transform applied: rescaled, still unmoved)
	var depth: float = gb.size.z
	var want: Vector3 = Vector3(cb.get_center().x, cb.get_center().y, -0.022 - depth * 0.5)
	gun.position += want - gb.get_center()
	for mi: MeshInstance3D in WorldArt.meshes(gun):
		_sanitize(mi)
		mi.material_overlay = _dust_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# two forged nails under it, a quarter in from each end
	var nail: Mesh = WorldArt.part_mesh("wall_mount", "Nail")
	if nail != null:
		var bottom: float = cb.get_center().y - gb.size.y * 0.5 - 0.006
		for f: float in [-0.27, 0.27]:
			var n: MeshInstance3D = MeshInstance3D.new()
			n.mesh = nail
			n.position = Vector3(cb.get_center().x + f * gb.size.x, bottom, 0.0)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(n)


## The weapon as a display model: WeaponModels.build, which since T-089 is the downloaded gun normalised to the
## viewmodel frame with the shared weapon shader (procedural for the six greybox ids), laid along the wall exactly as
## build_chalk lays the outline it traces (barrel toward -X).
func _gun_model() -> Node3D:
	var holder: Node3D = Node3D.new()
	var m: Node3D = WeaponModels.build(weapon_id, false, &"")
	m.rotation_degrees = Vector3(0, 90, 0)
	holder.add_child(m)
	_strip_lights(holder)
	for n: String in ["KitFlash", "MuzzleFlash", "Flash"]:
		var f: Node = holder.find_child(n, true, false)
		if f is Node3D:
			(f as Node3D).hide()
	return holder


static func _strip_lights(n: Node) -> void:
	for c: Node in n.get_children():
		if c is Light3D or c is GPUParticles3D or c is CPUParticles3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_lights(c)


## A thin film of dust over the mounted guns (a material overlay: their own textures stay).
static func _dust_mat() -> StandardMaterial3D:
	if _dust == null:
		_dust = StandardMaterial3D.new()
		_dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust.albedo_color = Color(0.62, 0.6, 0.55, 0.16)
		_dust.roughness = 1.0
	return _dust


## Some intake GLBs carry glTF defaults that look wrong on a wall: Kar98k's materials are emissive (1, 1, 1) with no
## emissive map, so the gun glows white, and alpha-blended. The mounted copy gets an opaque, non-glowing duplicate
## (the asset itself is the gun builders', T-087).
static func _sanitize(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for si: int in mi.mesh.get_surface_count():
		var m: StandardMaterial3D = mi.mesh.surface_get_material(si) as StandardMaterial3D
		if m == null or (not m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED):
			continue
		if not _clean.has(m):
			var c: StandardMaterial3D = m.duplicate() as StandardMaterial3D
			c.emission_enabled = false
			c.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			_clean[m] = c
		mi.set_surface_override_material(si, _clean[m])
