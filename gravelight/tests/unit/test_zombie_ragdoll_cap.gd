extends GutTest
## The ragdoll budget (anim.json ragdoll.max_live): a burst of deaths must not freeze bodies that are still falling.
## A full budget only happens when max_live deaths came within settle_freeze_seconds (settled bodies are frozen and
## pruned), so the oldest is evicted only once it is past evict_after_seconds; until then the new death keeps its clip.

var _host: Node3D
var _sims: Array[PhysicalBoneSimulator3D] = []


func before_each() -> void:
	# bodies another test left simulating would count against the budget
	for e: Array in ZombieRagdoll._live:
		ZombieRagdoll.freeze(e[0] as PhysicalBoneSimulator3D)
	_host = Node3D.new()
	add_child_autofree(_host)
	_sims.clear()


func after_each() -> void:
	for sim: PhysicalBoneSimulator3D in _sims:
		ZombieRagdoll.stop(sim)
	ZombieRagdoll.clear_parked()   # T-281: stop() keeps rigs for the next death; none outlive the test
	await get_tree().process_frame
	await get_tree().process_frame


func _start(i: int) -> PhysicalBoneSimulator3D:
	var sk: Skeleton3D = ZombieRig.build_skeleton()
	_host.add_child(sk)
	sk.position = Vector3(i * 2.0, 2.0, 0.0)
	var sim: PhysicalBoneSimulator3D = ZombieRagdoll.start(sk, Vector3(0, 2, 0))
	if sim != null:
		_sims.append(sim)
	return sim


func test_burst_at_the_cap_keeps_falling_bodies_simulating() -> void:
	if not ZombieRagdoll.enabled():
		pending("ragdolls disabled")
		return
	var cap: int = int(ZombieRagdoll.cfg()["max_live"])
	for i: int in cap:
		assert_not_null(_start(i), "death %d within the budget gets a ragdoll" % i)
	assert_eq(ZombieRagdoll.live_count(), cap)
	assert_null(_start(cap), "a death in the same burst keeps its clip (every live body is still falling)")
	for i: int in _sims.size():
		assert_true(_sims[i].is_simulating_physics(), "body %d is not frozen mid-fall" % i)
	assert_eq(ZombieRagdoll.live_count(), cap, "the budget holds")


func test_full_budget_evicts_a_body_that_has_had_time_to_land() -> void:
	if not ZombieRagdoll.enabled():
		pending("ragdolls disabled")
		return
	var cap: int = int(ZombieRagdoll.cfg()["max_live"])
	for i: int in cap:
		_start(i)
	assert_eq(ZombieRagdoll.live_count(), cap)
	# the oldest started evict_after_seconds ago (but not yet settle_freeze_seconds, which would free it anyway)
	var evict_ms: int = int(float(ZombieRagdoll.cfg().get("evict_after_seconds", 1.5)) * 1000.0)
	ZombieRagdoll._live[0][1] = Time.get_ticks_msec() - evict_ms - 100
	var oldest: PhysicalBoneSimulator3D = _sims[0]
	assert_not_null(_start(cap), "the newest death takes the landed body's simulation")
	assert_false(oldest.is_simulating_physics(), "the oldest is frozen where it lies")
	assert_eq(ZombieRagdoll.live_count(), cap, "the budget holds")
