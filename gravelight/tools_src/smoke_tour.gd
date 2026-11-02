extends "res://gravelight/tools_src/clip_tour.gd"
## Headless smoke for the tour clip tool (T-167): u09_ref's Crossroads cameras walked for 10 s with 2 bots and the
## round running; the command-line arguments of clip_tour.gd still apply on top.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/smoke_tour.tscn


func _init() -> void:
	_sets = PackedStringArray(["u09_ref"])
	_secs_total = 10.0
