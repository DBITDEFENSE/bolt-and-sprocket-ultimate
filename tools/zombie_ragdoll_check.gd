extends Node
## Regression: a full ragdoll budget stays capped; a burst never freezes a body that is still falling (the new death
## keeps its clip), and a body past evict_after_seconds gives its simulation to the newest death.
var failures: Array[String] = []

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var host := Node3D.new()
	add_child(host)
	var cap: int = int(ZombieRagdoll.cfg()["max_live"])
	var evict_ms: int = int(float(ZombieRagdoll.cfg().get("evict_after_seconds", 1.5)) * 1000.0)
	var sims: Array[PhysicalBoneSimulator3D] = []
	var peak: int = 0
	var denied: int = 0
	for i: int in cap + 3:
		var sk := ZombieRig.build_skeleton()
		host.add_child(sk)
		sk.position = Vector3(i * 2, 2, 0)
		if i == cap + 2:
			# the last death comes after the oldest has had time to land
			ZombieRagdoll._live[0][1] = Time.get_ticks_msec() - evict_ms - 100
		var sim := ZombieRagdoll.start(sk, Vector3(0, 2, 0))
		if sim == null:
			denied += 1
			if i < cap: failures.append("death %d within the budget denied a ragdoll" % i)
			if i == cap + 2: failures.append("a landed body did not give way to the newest death")
		else:
			sims.append(sim)
			if i == cap or i == cap + 1: failures.append("death %d in the burst evicted a falling body" % i)
		peak = maxi(peak, ZombieRagdoll.live_count())
		if peak > cap: failures.append("live cap exceeded")
	if sims.size() > cap and sims[0].is_simulating_physics():
		failures.append("the landed oldest corpse still simulates")
	for i: int in range(1, mini(cap, sims.size())):
		if not sims[i].is_simulating_physics(): failures.append("body %d frozen mid-fall" % i)
	for sim: PhysicalBoneSimulator3D in sims:
		ZombieRagdoll.freeze(sim)
	if ZombieRagdoll.live_count() != 0:
		failures.append("frozen corpses still consume live budget")
	for sim: PhysicalBoneSimulator3D in sims:
		ZombieRagdoll.stop(sim)
	host.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if ZombieRagdoll.live_count() != 0: failures.append("freed corpses remain registered")
	print("ZOMBIE_RAGDOLL_CHECK ", JSON.stringify({"cap": cap, "peak": peak, "admitted": sims.size(), "denied": denied, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
