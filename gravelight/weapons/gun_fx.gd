class_name GunFx
extends Node3D
## The WeaponHolder's gun-effect facade. Since T-095 the pools live in the Effects autoload (data in
## data/gravelight/vfx.json): ejected casings are the real cartridge models (CasingPool), the muzzle smoke, the
## impact debris and the blood mist come from Effects' pools, and surface_of() is Effects' data-driven table. This
## class keeps the calls WeaponHolder makes (get_for / eject / smoke / impact / nachtglas_spark / blood_mist /
## surface_of) so the holder needs no change; one instance per scene, created on first use.
##
## TODO (the guns builder, one line): WeaponHolder._eject_casing should pass the weapon id,
##   fx.eject(kind, from, vel, basis, w.id)
## so a bot-driven viewmodel's casing matches the gun the brain holds; until then the local holder's current() is used.

## Impact dust tint per surface (kept for readers of the old table; the live colours are vfx.json "impacts").
const DUST_TINT: Dictionary = {
	"snow": [Color(0.92, 0.94, 0.98, 0.85), Color(0.85, 0.88, 0.94, 0.0)],
	"wood": [Color(0.5, 0.36, 0.22, 0.8), Color(0.42, 0.32, 0.22, 0.0)],
	"hay": [Color(0.78, 0.66, 0.34, 0.8), Color(0.7, 0.6, 0.35, 0.0)],
	"stone": [Color(0.62, 0.6, 0.56, 0.8), Color(0.5, 0.49, 0.47, 0.0)],
	"metal": [Color(0.4, 0.38, 0.36, 0.5), Color(0.35, 0.34, 0.33, 0.0)],
}


static func get_for(n: Node) -> GunFx:
	if n == null or not n.is_inside_tree():
		return null
	var tree: SceneTree = n.get_tree()
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	var fx: GunFx = host.get_node_or_null("GunFx") as GunFx
	if fx == null:
		fx = GunFx.new()
		fx.name = "GunFx"
		host.add_child(fx)
	return fx


func _ready() -> void:
	top_level = true


## Throws one casing from `from` with world velocity `vel`, oriented by `basis` (casing axis = basis Z). `kind` is
## the holder's casing kind (pistol / rifle / shell); `weapon_id` picks the exact cartridge model when given.
func eject(kind: String, from: Vector3, vel: Vector3, basis: Basis, weapon_id: StringName = &"") -> void:
	Effects.casing(kind, from, vel, basis, weapon_id)


func smoke(at: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	Effects.muzzle_smoke(at, dir, strength)


## Bullet strike on world geometry. The debris now comes with Effects.impact() (the holder calls both; this is a
## no-op kept for the call site).
func impact(_at: Vector3, _normal: Vector3, _collider: Object, _surface: String = "") -> void:
	pass


## A bullet glancing off Nachtglas (a Glasshide's crystal plates): teal-violet glints instead of blood.
func nachtglas_spark(at: Vector3, toward: Vector3) -> void:
	Effects.nachtglas_spark(at, toward)


## The mist now comes with Effects.blood() (gore-gated); kept for the call site.
func blood_mist(_at: Vector3, _toward: Vector3) -> void:
	pass


## What a bullet hit is made of, for decals and dust (Effects.surface_of: the "surface" meta, vfx.json name hints,
## then the map's defaults by facing).
static func surface_of(collider: Object, at: Vector3, normal: Vector3, space: PhysicsDirectSpaceState3D) -> String:
	return Effects.surface_of(collider, at, normal, space)
