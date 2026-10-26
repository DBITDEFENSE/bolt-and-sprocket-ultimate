extends GutTest
## Bots are seen aiming down the sights (the user: "I'd like the bot to aim down sights; it seems not to sometimes").
## The aim layer already scored its shots as aimed (ads_amount 1.0) while the first-person view of the player bot
## was forced to the hip and the third-person body ignored PF_ADS. Now: BotAim.ads_visual() raises PF_ADS and the
## player bot's viewmodel; RemoteBody shoulders the gun on PF_ADS.

const FLOOR: int = 16   # NetMatch.PF_FLOOR


func _body() -> RemoteBody:
	var b: RemoteBody = RemoteBody.new()
	add_child_autofree(b)
	b.setup(&"dutch", 41)
	return b


func _gun_y(b: RemoteBody, flags: int) -> float:
	for i: int in 60:
		b.update_pose(1.0 / 60.0, 0.0, 0.0, flags)
	var gp: Node3D = b.get("_gun_pivot") as Node3D
	return b.to_local(gp.global_position).y


func test_ads_flag_shoulders_the_gun_on_the_third_person_body() -> void:
	var hip: float = _gun_y(_body(), FLOOR)
	var aimed: float = _gun_y(_body(), FLOOR | NetMatch.PF_ADS)
	assert_gt(aimed - hip, 0.05, "PF_ADS raises the gun to the shoulder (%.3f -> %.3f m)" % [hip, aimed])


func test_sprint_or_reload_overrides_ads() -> void:
	var hip: float = _gun_y(_body(), FLOOR)
	var sprint: float = _gun_y(_body(), FLOOR | NetMatch.PF_ADS | NetMatch.PF_SPRINT)
	var sprint_only: float = _gun_y(_body(), FLOOR | NetMatch.PF_SPRINT)
	assert_almost_eq(sprint, sprint_only, 0.005, "sprinting wins over ADS")
	var reload: float = _gun_y(_body(), FLOOR | NetMatch.PF_ADS | NetMatch.PF_RELOAD)
	var reload_only: float = _gun_y(_body(), FLOOR | NetMatch.PF_RELOAD)
	assert_almost_eq(reload, reload_only, 0.005, "reloading wins over ADS")
	assert_true(hip > 0.0 or hip <= 0.0, "hip pose measured")


func test_ads_visual_follows_the_aim_layer() -> void:
	var src: String = (load("res://gravelight/bots/bot_aim.gd") as GDScript).source_code
	assert_true(src.contains("func ads_visual() -> bool:"), "BotAim.ads_visual exists")
	var brain: String = (load("res://gravelight/bots/bot_brain.gd") as GDScript).source_code
	assert_true(brain.contains("flags |= NetMatch.PF_ADS"), "the brain raises PF_ADS")
	assert_true(brain.contains("aim.ads_visual())"), "the player bot's view gets the ADS state")
	var holder: String = (load("res://gravelight/weapons/weapon_holder.gd") as GDScript).source_code
	assert_false(holder.contains("ads_t = move_toward(ads_t, 0.0, delta / 0.25)\n\tif w != null:\n\t\tif reloading and not _reloading:"), "the bot view is no longer forced to the hip")
