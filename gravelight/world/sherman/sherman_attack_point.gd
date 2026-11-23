class_name ShermanAttackPoint
extends Node3D
## Where one of the dead stands to beat on the Sherman (T-249). A zombie given this as its `prey` (Zombie._update_prey,
## the hook the Inn's round-1 opening uses for the fleeing patrons) walks to it on the navmesh, stops at its reach and
## swipes; each swipe lands on the tank (`struck`). Set 0.6 m inside the hull's edge, so a zombie at its reach stands
## against the armour. Nothing changes in the zombie's code.

var tank: ShermanTank = null
var holders: int = 0   # zombies sent here (the event spreads them over the points)


## The prey hook: true while the tank can be hit (the assault, or a player driving it; not a wreck).
func is_catchable() -> bool:
	return tank != null and is_instance_valid(tank) and tank.can_be_attacked()


## How many of the dead are on this point now (T-261: the ones that come for a driver are spread over the points).
func holders_now(dir: ZombieDirector) -> int:
	var n: int = 0
	for z: Zombie in dir.active_zombies():
		if z.prey == self and z.is_active():
			n += 1
	return n


## The prey hook: a swipe landed.
func struck(by: Node) -> void:
	if tank != null and is_instance_valid(tank):
		tank.take_swipe(by, global_position)
