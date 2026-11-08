extends Node
## Regression: a full ragdoll budget must freeze the oldest, admit the newest and stay capped.
var failures: Array[String] = []

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var host := Node3D.new()
	add_child(host)
	var cap: int = int(ZombieRagdoll.cfg()["max_live"])
	var sims: Array[PhysicalBoneSimulator3D] = []
	var peak: int = 0
	for i: int in cap + 3:
		var sk := ZombieRig.build_skeleton()
		host.add_child(sk)
		sk.position = Vector3(i * 2, 2, 0)
		var sim := ZombieRagdoll.start(sk, Vector3(0, 2, 0))
		if sim == null:
			failures.append("new death %d denied a ragdoll" % i)
		else:
			sims.append(sim)
		peak = maxi(peak, ZombieRagdoll.live_count())
		if peak > cap: failures.append("live cap exceeded")
	if sims.size() > cap and sims[0].is_simulating_physics():
		failures.append("oldest corpse still simulates")
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
	print("ZOMBIE_RAGDOLL_CHECK ", JSON.stringify({"cap": cap, "peak": peak, "admitted": sims.size(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
