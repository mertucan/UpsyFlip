extends Node
## Global run/session state. Skeleton for Phase 0; filled in from Phase 1 on.

signal run_started
signal run_ended(score: int)

var is_run_active: bool = false
var current_score: int = 0
## Level seed of the current run.
var run_seed: int = 0
## Set to a non-negative value to force the next run's seed (weekly challenge).
var forced_seed: int = -1


## Picks the seed for a new run: the forced one if set, otherwise random.
func next_run_seed() -> int:
	return forced_seed if forced_seed >= 0 else int(randi())


func start_run(level_seed: int = 0) -> void:
	run_seed = level_seed
	is_run_active = true
	current_score = 0
	run_started.emit()


func end_run() -> void:
	if not is_run_active:
		return
	is_run_active = false
	run_ended.emit(current_score)
