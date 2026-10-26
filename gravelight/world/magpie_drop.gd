class_name MagpieDrop
extends Node3D
## Magpie Mead's drop (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 7.2): what a kill leaves at the body for the
## tonic's holder: a clip for the gun in hand (`ammo`: `mags` magazines; a wonder weapon gets one charge), a few
## Scrip (`scrip`), a grenade (`grenade`), or, every N-th drop on Pawn Shop, a power-up (`powerup`, handed to
## PowerupManager when picked up). Only the holder may take it (any teammate on Pawn Shop: `shared`). It glints,
## bobs, blinks in its last 5 s and is gone after `life` s. Walk over it. Bots take theirs too.

const PICK_RADIUS: float = 1.4
const COLORS: Dictionary = {&"ammo": Color(0.85, 0.72, 0.3), &"scrip": Color(0.95, 0.8, 0.25),
	&"grenade": Color(0.45, 0.6, 0.3), &"powerup": Color(0.75, 0.45, 1.0)}

var kind: StringName = &"ammo"
var amount: int = 1            # magazines, Scrip, grenades
var owner_pid: int = 0
var shared: bool = false
var upgraded_ammo: bool = false
var powerup_id: StringName = &"resupply"
var life: float = 20.0
var _t: float = 0.0
var _vis: Node3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(&"magpie_drops")
	var col: Color = COLORS.get(kind, Color.WHITE)
	_vis = Node3D.new()
	add_child(_vis)
	var mat: Material = Interactable.greybox_mat(col, 1.6)
	match kind:
		&"ammo":
			for i: int in 3:
				Interactable.add_box(_vis, Vector3(0.05, 0.14, 0.05), Vector3((i - 1) * 0.06, 0.07, 0.0), mat)
		&"scrip":
			for i: int in 3:
				var c: MeshInstance3D = MeshInstance3D.new()
				var cm: CylinderMesh = CylinderMesh.new()
				cm.top_radius = 0.07
				cm.bottom_radius = 0.07
				cm.height = 0.02
				cm.material = mat
				c.mesh = cm
				c.position = Vector3(0, 0.02 + i * 0.025, 0)
				_vis.add_child(c)
		&"grenade":
			Interactable.add_box(_vis, Vector3(0.09, 0.12, 0.09), Vector3(0, 0.07, 0), mat)
			Interactable.add_box(_vis, Vector3(0.04, 0.05, 0.04), Vector3(0, 0.15, 0), mat)
		_:
			Interactable.add_box(_vis, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.1, 0), mat)
	# the magpie's eye: a dark bead with a bright glint on top
	var eye: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.material = Interactable.greybox_mat(Color(0.08, 0.08, 0.1), 0.0)
	eye.mesh = sm
	eye.position = Vector3(0, 0.26, 0)
	_vis.add_child(eye)
	_light = OmniLight3D.new()
	_light.light_color = col.lightened(0.2)
	_light.omni_range = 2.4
	_light.light_energy = 1.2
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_vis.rotation.y = _t * 1.8
	_vis.position.y = 0.06 * sin(_t * 3.2)
	var left: float = life - _t
	visible = left > 5.0 or fmod(left, 0.4) > 0.15
	_light.light_energy = 0.9 + 0.5 * absf(sin(_t * 4.0))   # the glint
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or not (p.is_local or p.is_bot):
			continue
		if not shared and p.player_id != owner_pid:
			continue
		var d: Vector3 = p.global_position - global_position
		if Vector2(d.x, d.z).length() > PICK_RADIUS or absf(d.y) > 2.2:
			continue
		if give(p):
			if p.is_bot:
				AudioDirector.play_3d("perk_magpie_pick", global_position, -2.0)
			else:
				AudioDirector.play_2d("perk_magpie_pick", -2.0)
			PerkManager.magpie_taken(p.player_id, kind)
			queue_free()
			return


## Hands the drop to `p`. False when it can't take it (a full reserve, full grenades): the drop stays.
func give(p: Player) -> bool:
	match kind:
		&"ammo":
			var w: WeaponInstance = p.weapons.current()
			if w == null or w.weapon_class() == &"melee":
				return false
			return give_ammo(w, amount, upgraded_ammo)
		&"scrip":
			Economy.award(p.player_id, amount)
			return true
		&"grenade":
			if p.weapons.grenades >= p.weapons.grenade_max():
				return false
			p.weapons.grenades = mini(p.weapons.grenade_max(), p.weapons.grenades + amount)
			return true
		&"powerup":
			PowerupManager.apply(powerup_id, p.player_id)
			return true
	return false


## Ammo into `w`: `mags` magazines of reserve (a wonder weapon: one charge into the mag, then the reserve), never
## past the gun's reserve. `upgraded` is only a label (a taught gun's reserve is already its upgraded row's).
static func give_ammo(w: WeaponInstance, mags: int, _upgraded: bool) -> bool:
	if w == null:
		return false
	var cap: int = w.reserve_max()
	if w.weapon_class() == &"wonder":
		if w.mag < w.mag_size():
			w.mag += 1
			return true
		if w.reserve >= cap:
			return false
		w.reserve = mini(cap, w.reserve + 1)
		return true
	if w.reserve >= cap:
		return false
	w.reserve = mini(cap, w.reserve + w.mag_size() * maxi(1, mags))
	return true
