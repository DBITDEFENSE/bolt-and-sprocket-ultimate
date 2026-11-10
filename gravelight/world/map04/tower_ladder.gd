class_name TowerLadder
extends LadderClimb
## The radar tower's ladder (UPDATE 10 §3 Act III, row 8 "verticality"; DECISIONS T-157): the sniper perch on the
## lattice's 16 m deck. Holding Use at the foot climbs the player up the south-face ladder (`climb_s`, the view
## rising with them, weapons down), at the top it sets them on the deck; the same ladder at the top (a second
## TowerLadder with `down` set) climbs them back down. The zombies get up there too, by their own climb link
## (map04c.json climb_links "TowerPerch"), so the perch is a good spot, not a safe one.
## T-229: a LadderClimb (every map's ladders work the same way now); this keeps its name, group and prompt.


func _init() -> void:
	climb_s = 3.0
	target = "the radar tower"


func _ready() -> void:
	super._ready()
	add_to_group(&"tower_ladders")
