class_name AmmoBox
extends Interactable
## An ammo box (Update 02 section 4, DECISIONS T-049): an olive-drab small-arms crate with a lantern on top.
## Hold [interact] to refill the weapon in your hands (magazine and reserve to full, a rifle's grenades too) and
## your lethal grenades (never tacticals). The price follows what you hold (data/gravelight/economy.json
## "ammo_box"): normal / Crucible-upgraded, wonder weapons (class "wonder") wonder / wonder-upgraded. A gun that is
## already full with full grenades shows "Ammo full" and costs nothing. Each player has a short cooldown after a buy.
##
## Who can use it: players (interact), bots (BotBrain's "ammo_box" errand calls interact like any buy), and any
## other user through use_by() / use_holder() with a price multiplier and a payer (e.g. the companion buying at
## half price from someone else's Scrip, section 6).
##
## Co-op: the prompt is built on each machine from its own inventory and Scrip; the purchase runs on the host with
## the buyer's puppet (its mirror holder forwards the refill to the owner), and the cooldown is mirrored back so a
## client's prompt shows it too. Origin: floor centre; local -Z is the front.

const AmmoBoxArt: GDScript = preload("res://gravelight/world/ammo_box_art.gd")

## Collision footprint (the body and lid; the lantern on top is not solid).
const FOOTPRINT: Vector3 = Vector3(1.04, 0.62, 0.6)

## Optional label for tools and logs ("taproom", "rail_yard").
@export var box_name: String = ""

var _used_at: Dictionary = {}     # player_id -> seconds (_now) of their last purchase here
var _lamp: FlickerLight
var _glass: MeshInstance3D


# ---------------------------------------------------------------- pricing (pure, for tests and other users)

## The ammo_box table from economy.json.
static func cfg() -> Dictionary:
	return GLData.table("economy").get("ammo_box", {})


## The price of refilling a weapon with this data row, upgraded (Crucible-taught) or not.
## Wonder weapons are the rows whose class is "wonder" (their upgraded rows keep the class).
static func price_for(weapon_data: Dictionary, upgraded: bool, box_cfg: Dictionary) -> int:
	var wonder: bool = str(weapon_data.get("class", "")) == "wonder"
	if wonder:
		return int(box_cfg.get("wonder_upgraded", 4000)) if upgraded else int(box_cfg.get("wonder", 1000))
	return int(box_cfg.get("upgraded", 2500)) if upgraded else int(box_cfg.get("normal", 250))


## What a box does for this holder right now: {"refill_weapon": bool, "refill_grenades": bool, "price": int,
## "weapon": WeaponInstance or null}. Nothing to refill = both false, price 0.
static func quote(holder: WeaponHolder, box_cfg: Dictionary, price_mult: float = 1.0) -> Dictionary:
	var w: WeaponInstance = holder.current() if holder != null else null
	var need_w: bool = w != null and not w.is_full()
	var need_g: bool = holder != null and holder.grenades < holder.grenade_max()
	var p: int = 0
	if need_w:
		p = price_for(w.data, w.upgraded, box_cfg)
	elif need_g:
		p = int(box_cfg.get("grenades_only", 250))
	if holder != null and holder.player != null:
		price_mult *= PerkManager.ammo_price_mult(holder.player.player_id)   # Packmule II: half price (T-075)
		price_mult *= Muster.mult(holder.player.player_id, "ammo_price_mult")   # Scrounger (T-079)
	return {"refill_weapon": need_w, "refill_grenades": need_g, "weapon": w, "price": int(round(float(p) * price_mult))}


# ---------------------------------------------------------------- Interactable

func _ready() -> void:
	interact_size = Vector3(1.25, 1.0, 0.95)
	interact_offset = Vector3(0, 0.5, -0.12)
	super._ready()
	add_to_group(&"ammo_boxes")
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = FOOTPRINT
	cs.shape = bs
	cs.position = Vector3(0, FOOTPRINT.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func get_prompt(player: Player) -> String:
	var q: Dictionary = quote(player.weapons, cfg())
	if not bool(q["refill_weapon"]) and not bool(q["refill_grenades"]):
		return "Ammo full"
	var left: float = cooldown_left(player.player_id)
	if left > 0.0:
		return "Restocking... %.0f" % ceilf(left)
	var key: String = prompt_key(&"interact")
	if bool(q["refill_weapon"]):
		var w: WeaponInstance = q["weapon"]
		return "Hold [%s] for %s ammo [%s]" % [key, _weapon_label(w), Economy.price_text(player.player_id, int(q["price"]))]
	return "Hold [%s] for Grenades [%s]" % [key, Economy.price_text(player.player_id, int(q["price"]))]


func can_interact(player: Player) -> bool:
	var q: Dictionary = quote(player.weapons, cfg())
	return (bool(q["refill_weapon"]) or bool(q["refill_grenades"])) and cooldown_left(player.player_id) <= 0.0


func interact(player: Player) -> void:
	use_by(player)


## A player (or a bot) buys a refill, paying `price_mult` x the price from their own Scrip. Returns the result:
## &"ok", &"full" (nothing to refill, nothing charged), &"cooldown", or &"no_scrip".
func use_by(player: Player, price_mult: float = 1.0) -> StringName:
	var res: StringName = use_holder(player.weapons, player.player_id, player.player_id, price_mult)
	if res == &"ok":
		feedback_2d(player, "reload_end")
	elif res == &"no_scrip":
		if player.is_local:
			AudioDirector.play_2d("deny", -2.0)
		player.flash_prompt_denied()
	return res


## The general form: refills `holder` (the user's weapons), charging `payer_id`'s Scrip; the cooldown is kept per
## `user_id`. A companion that is not a Player passes its own holder and the party member who pays.
func use_holder(holder: WeaponHolder, user_id: int, payer_id: int, price_mult: float = 1.0) -> StringName:
	var q: Dictionary = quote(holder, cfg(), price_mult)
	if not bool(q["refill_weapon"]) and not bool(q["refill_grenades"]):
		return &"full"
	if cooldown_left(user_id) > 0.0:
		return &"cooldown"
	var w: WeaponInstance = q["weapon"]
	var item: StringName = StringName(String(w.id) + "_box_ammo") if bool(q["refill_weapon"]) else &"ammo_box_grenades"
	if not Economy.spend(payer_id, item, int(q["price"])):
		return &"no_scrip"
	if bool(q["refill_weapon"]):
		holder.refill_weapon(w.base_id())
	if bool(q["refill_grenades"]):
		holder.refill_grenades()
	_used_at[user_id] = _now()
	Net.mirror(self, &"_net_used", [user_id])
	AudioDirector.play_3d("buy", global_position, -4.0)
	Net.sfx_all("buy", global_position, -4.0)
	AudioDirector.play_3d("reload_stripper_clip", global_position + Vector3.UP * 0.7, -2.0)
	Net.sfx_all("reload_stripper_clip", global_position + Vector3.UP * 0.7, -2.0)
	GLBus.ammo_bought.emit(user_id, w.base_id() if bool(q["refill_weapon"]) else &"frag")
	return &"ok"


## Seconds until `user_id` may buy here again (0 when ready).
func cooldown_left(user_id: int) -> float:
	if not _used_at.has(user_id):
		return 0.0
	return maxf(0.0, float(cfg().get("cooldown_s", 3.0)) - (_now() - float(_used_at[user_id])))


## Co-op client: the host sold a refill to `user_id` (their prompt shows the cooldown).
func _net_used(user_id: int) -> void:
	_used_at[user_id] = _now()


## Clock for the cooldown (seconds; real time, so it also runs while the round is paused between waves).
func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _weapon_label(w: WeaponInstance) -> String:
	return str(w.data.get("name", w.id)) + str(w.tier_cfg().get("suffix", ""))


# ---------------------------------------------------------------- art

func build_greybox() -> void:
	# our model (UPDATE_05 section 5, T-094: the olive crate, lid open on its cartons); AmmoBoxArt when absent
	var art: Node3D = WorldArt.instance("ammo_crate", "Model")
	if art != null:
		add_child(art)
	else:
		InteractableArt.place(self, "ammo_box", func(r: Node3D) -> void: AmmoBoxArt.body(r))
	# stencils (painted through a card: no outline), front and ends
	var s1: Label3D = add_label(self, "AMMUNITION", Vector3(0, 0.39, -0.286), 30, Color(0.86, 0.84, 0.7, 0.88))
	s1.outline_size = 0
	var s2: Label3D = add_label(self, "SMALL ARMS  ·  MIXED LOTS", Vector3(0, 0.3, -0.286), 13, Color(0.86, 0.84, 0.7, 0.75))
	s2.outline_size = 0
	s2.pixel_size = 0.0028
	var s3: Label3D = add_label(self, "CAL .30  ·  7,92  ·  .45", Vector3(0, 0.21, -0.286), 13, Color(0.86, 0.84, 0.7, 0.7))
	s3.outline_size = 0
	s3.pixel_size = 0.0028
	var s4: Label3D = add_label(self, "LOT 44-ZK-12", Vector3(0, 0.127, -0.292), 10, Color(0.08, 0.07, 0.03, 0.95))
	s4.outline_size = 0
	s4.pixel_size = 0.0025
	for sx: float in [-1.0, 1.0]:
		var e: Label3D = add_label(self, "AMMO", Vector3(sx * 0.523, 0.46, 0.0), 18, Color(0.86, 0.84, 0.7, 0.75))
		e.outline_size = 0
		e.rotation.y = sx * PI * 0.5   # read from outside each end
	# the lantern's glass and its flickering light (the frame is in the merged mesh)
	var lp: Vector3 = AmmoBoxArt.lantern_pos()
	_glass = MeshInstance3D.new()
	_glass.name = "LampGlass"
	var gm: CylinderMesh = CylinderMesh.new()
	gm.top_radius = 0.036
	gm.bottom_radius = 0.042
	gm.height = 0.13
	gm.radial_segments = 12
	_glass.mesh = gm
	_glass.material_override = Mats.get_mat("lantern_glass")
	_glass.position = lp
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	_lamp = FlickerLight.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Color(1.0, 0.74, 0.44)
	_lamp.base_energy = 1.3
	_lamp.amount = 0.3
	_lamp.speed = 7.5
	_lamp.omni_range = 3.6
	_lamp.omni_attenuation = 1.3
	_lamp.shadow_enabled = false
	_lamp.position = lp + Vector3(0, 0.05, 0)
	add_child(_lamp)
