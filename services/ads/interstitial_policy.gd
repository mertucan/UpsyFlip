class_name InterstitialPolicy
extends RefCounted
## Decides when an interstitial ad may be shown. Pure logic.
##
## Rules:
## - never during the first `free_runs` runs of a session;
## - never right after a run shorter than `min_run_seconds`;
## - otherwise at most once every `runs_between` runs or every
##   `seconds_between` seconds, whichever comes first.
## All values are remotely configurable.

var free_runs: int = 3
var runs_between: int = 3
var seconds_between: float = 120.0
var min_run_seconds: float = 15.0

var runs_completed: int = 0
var runs_since_last: int = 0
var last_shown_time: float = 0.0
var last_run_duration: float = 0.0


func register_run(duration: float) -> void:
	runs_completed += 1
	runs_since_last += 1
	last_run_duration = duration


## `now` is session time in seconds. Call after register_run().
func should_show(now: float) -> bool:
	if runs_completed <= free_runs:
		return false
	if last_run_duration < min_run_seconds:
		return false
	return runs_since_last >= runs_between or now - last_shown_time >= seconds_between


func mark_shown(now: float) -> void:
	runs_since_last = 0
	last_shown_time = now
