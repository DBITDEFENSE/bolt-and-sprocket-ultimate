extends "res://gravelight/tools_src/smoke_cinema_online.gd"
## T-209 (UPDATE 12 s3): the online smoke (smoke_cinema_online.gd) with the archive reel of STAUB ("reel:staub") and a
## clip for every reel shot (the committed fixture, in a user:// folder both peers read): host and client each play
## their own copy with the film treatment and the clips on their own clock; the co-op skip vote and the host's end work
## as for an in-engine cut; input and round 1 come back on both.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_cinema_reels_online.tscn


func _default_cut() -> String:
	return "reel:staub"


func _scene_path() -> String:
	return "res://gravelight/tools_src/smoke_cinema_reels_online.tscn"


func _wants_clips() -> bool:
	return true
