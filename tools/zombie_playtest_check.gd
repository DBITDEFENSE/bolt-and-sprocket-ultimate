extends Node
## Startup check with explicit teardown; --quit-after bypasses the menu's tool-owned caches.
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var menu: Node = load("res://gravelight/ui/main_menu.tscn").instantiate()
	add_child(menu)
	for frame: int in 180:
		await get_tree().process_frame
	var info: Dictionary = ZombieClips.mocap_info()
	var expected: int = (GLData.load_json("res://data/gravelight/zombie_mocap.json")["clips"] as Array).size()
	var okay: bool = info["loaded"].size() == expected and info["errors"].is_empty()
	print("ZOMBIE_PLAYTEST_CHECK menu loaded; licensed clips ", info["loaded"].size(), "/", expected, "; ", "PASS" if okay else "FAIL")
	menu.queue_free()
	AudioDirector.stop_all_music()
	for frame: int in 3:
		await get_tree().process_frame
	for template: Node in WeaponModels._templates.values():
		if is_instance_valid(template): template.free()
	WeaponModels._templates.clear()
	for scene: Node in Arms._scenes.values():
		if is_instance_valid(scene): scene.free()
	Arms._scenes.clear()
	await get_tree().process_frame
	get_tree().quit(0 if okay else 1)
