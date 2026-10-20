extends LobbedWeapon
## B.O.O.M. BOX (BS_WEAPONS §8.4). fireBoomBox (index.html:4574): a subwoofer lobbed at 15 m/s forward + 5 up,
## gravity 16, every 0.95 s. detonateRave (4614): every non-boss enemy within 5.5 m DANCES for 1.6 s, then takes
## 45 on the next music beat (held up to 2.5 s waiting for it); bosses take 70% immediately. Ammo 8 (+4 per tier).
## Alt-fire DROP THE BASS: everyone dancing to the most recent box takes the drop now at 80%.
## V3: radius 6.5 m, each dancer drops +1 bolt. V5: the drop knocks dancers up 6 m/s.
## Ω HEADLINER: radius 7.5 m, ravers drop double bolts, the drop is a full launch (11 m/s), one encore beat at 50%.
## Signatures: extended_mix (dance 3 s, drop x1.3), radio_edit (drop 0.8 s after landing, no beat, radius x0.8).

var last_device: BoomBoxDevice = null


func radius() -> float:
	var r: float = P("radius", 5.5)
	if omega():
		r = P("radius_omega", 7.5)
	elif level() >= 3:
		r = P("radius_v3", 6.5)
	if sig() == &"radio_edit":
		r *= P("radio_radius_mul", 0.8)
	return r


func on_land(pos: Vector3, _direct: Node3D, data: Dictionary) -> void:
	var dev: BoomBoxDevice = BoomBoxDevice.new()
	dev.weapon = self
	dev.amount = float(data.get("dmg", dmg(45.0)))
	dev.radius = radius()
	var ext: bool = sig() == &"extended_mix"
	dev.dance_time = P("extended_dance", 3.0) if ext else P("dance_time", 1.6)
	dev.drop_mul = P("extended_mul", 1.3) if ext else 1.0
	dev.beat_wait_max = P("beat_wait_max", 2.5)
	dev.radio_delay = P("radio_delay", 0.8) if sig() == &"radio_edit" else -1.0
	dev.boss_mul = P("boss_mul", 0.7)
	dev.launch = P("omega_launch", 11.0) if omega() else (P("v5_launch", 6.0) if level() >= 5 else 0.0)
	dev.encore_mul = P("encore_mul", 0.5) if omega() else 0.0
	dev.bonus_drops = 1 if level() >= 3 else 0
	dev.double_drops = omega()
	mgr.world().add_child(dev)
	dev.global_position = pos
	last_device = dev
	if mgr.bolt != null and mgr.bolt.camera != null:
		mgr.bolt.camera.shake(0.35)


## DROP THE BASS: remote-detonate the newest box early.
func _on_alt_pressed() -> void:
	if last_device != null and is_instance_valid(last_device) and last_device.has_dancers():
		last_device.drop_now(P("drop_bass_mul", 0.8))
		popup.emit("bs.weapon.fx.drop", last_device.global_position)
