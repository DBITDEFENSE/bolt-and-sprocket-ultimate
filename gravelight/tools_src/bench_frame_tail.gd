extends Node
## T-283: bench_blast_deaths' last node in every process step: when the step ended (microseconds).

var end_us: int = 0


func _process(_delta: float) -> void:
	end_us = Time.get_ticks_usec()
