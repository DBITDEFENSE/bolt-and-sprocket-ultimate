extends GutTest
## Peg's choice and the carry (UPDATE 07, docs/MAP4_FERNFLUG.md §5.6; gravelight/world/map04/pegs_choice.gd,
## carry_object.gd, carry_cradle.gd): who decides, which flag a choice sets, the carry's status and the cradle's
## acceptance, and a live choice by console (keep → peg_resigned, the core bound for the rocket).

var _host: Node3D


func before_each() -> void:
	_host = Node3D.new()
	add_child_autofree(_host)
	GameState.player_ids = [1]
	Economy.reset([1])


func after_each() -> void:
	for f: StringName in [&"peg_resigned", &"peg_delivered", &"peg_choice_done", &"core_in_rocket"]:
		GameState.flags.erase(f)
	var pc: Node = get_tree().root.get_node_or_null("PegsChoice")
	if pc != null:
		pc.free()


func test_decider_is_pegs_player_else_the_first_human() -> void:
	assert_eq(PegsChoice.decider_of({1: &"dutch", 2: &"peg", 3: &"deacon"}, [1, 2, 3]), 2, "Peg's player decides")
	assert_eq(PegsChoice.decider_of({1: &"dutch", 2: &"peg"}, [1]), 1, "a bot playing Peg never decides: the first human")
	assert_eq(PegsChoice.decider_of({3: &"wren", 4: &"dutch"}, [4, 3]), 4, "the first human in the list")
	assert_eq(PegsChoice.decider_of({}, []), 1, "nobody: player 1")


func test_flag_for_each_choice() -> void:
	assert_eq(PegsChoice.flag_for(PegsChoice.KEEP), &"peg_resigned")
	assert_eq(PegsChoice.flag_for(PegsChoice.DELIVER), &"peg_delivered")


func test_choice_by_console_sets_the_flag_once() -> void:
	var got: Array = []
	var pc: PegsChoice = PegsChoice.start(get_tree(), func(opt: String) -> void: got.append(opt))
	assert_eq(pc.decider, 1)
	pc.choose("nonsense")
	assert_eq(pc.chosen, "", "an unknown option is ignored")
	pc.choose(PegsChoice.KEEP)
	assert_eq(pc.chosen, PegsChoice.KEEP)
	assert_true(GameState.has_flag(&"peg_resigned") and GameState.has_flag(&"peg_choice_done"))
	assert_false(GameState.has_flag(&"peg_delivered"))
	assert_eq(got, [PegsChoice.KEEP], "the host callback ran once")
	pc.choose(PegsChoice.DELIVER)
	assert_eq(pc.chosen, PegsChoice.KEEP, "a second choice changes nothing")
	assert_eq(got.size(), 1)


func test_carry_object_and_cradle_acceptance() -> void:
	var core: CarryObject = CarryObject.new()
	core.carry_id = &"impeller_core"
	core.deliver_to = &"hangar_cradle"
	_host.add_child(core)
	assert_false(CarryObject.someone_carrying(1))
	assert_null(CarryObject.carried_by(1))
	core.lift(1)
	assert_eq(core.carrier, 1)
	assert_true(CarryObject.someone_carrying(1))
	assert_eq(CarryObject.carried_by(1), core)
	assert_eq(core.area.collision_layer, 0, "no prompt on the ground while carried")
	core.set_down(Vector3(3, 0, 3), &"hangar_cradle")
	assert_eq(core.carrier, 0)
	assert_eq(core.trips, 1, "set down once: the next carry is heavier")
	assert_eq(core.global_position, Vector3(3, 0, 3))
	assert_eq(core.area.collision_layer, Interactable.LAYER_INTERACTABLE, "liftable again")
	core.lift(1)
	core.deliver_to = &"rocket_cradle"
	var hatch: CarryCradle = CarryCradle.new()
	hatch.cradle_id = &"hangar_cradle"
	hatch.accepts = &"impeller_core"
	_host.add_child(hatch)
	var rocket: CarryCradle = CarryCradle.new()
	rocket.cradle_id = &"rocket_cradle"
	rocket.accepts = &"impeller_core"
	rocket.delivered_flag = &"core_in_rocket"
	_host.add_child(rocket)
	var p: Player = Player.new()
	p.player_id = 1
	_host.add_child(p)
	p.set_physics_process(false)
	assert_false(hatch.can_interact(p), "the hatch is not where the core is bound")
	assert_true(rocket.can_interact(p), "the rocket's bay is")
	rocket._take(core)
	assert_true(core.delivered and rocket.taken and GameState.has_flag(&"core_in_rocket"))
	assert_false(rocket.can_interact(p), "taken once")
	p.free()


func test_carry_status_is_the_ballast_rule() -> void:
	var core: CarryObject = CarryObject.new()
	_host.add_child(core)
	assert_eq(core.carry_status, &"ballast")
	var st: Dictionary = GLData.table("enemies")["status"]
	assert_true(st.has("ballast") and float(st["ballast"]["move_mult"]) < 1.0, "no sprint, slow while carrying")
