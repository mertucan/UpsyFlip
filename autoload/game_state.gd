extends Node
## Global run/session state. Skeleton for Phase 0; filled in from Phase 1 on.

signal run_started
signal run_ended(score: int)

var is_run_active: bool = false
var current_score: int = 0


func start_run() -> void:
	is_run_active = true
	current_score = 0
	run_started.emit()


func end_run() -> void:
	if not is_run_active:
		return
	is_run_active = false
	run_ended.emit(current_score)
