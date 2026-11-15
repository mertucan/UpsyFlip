extends Node
## Remote-tunable values with built-in defaults. A real backend (Firebase
## Remote Config) calls apply_remote() when it has fetched values; until
## then, and always on desktop, the defaults are used.

signal changed

const DEFAULTS: Dictionary[String, Variant] = {
	"interstitial_free_runs": 3,
	"interstitial_runs_between": 3,
	"interstitial_seconds_between": 120.0,
	"interstitial_min_run_seconds": 15.0,
	"free_coins_amount": 50,
	"continue_min_height": 10,
	# v1.1 weekly challenge; -1 means no active challenge.
	"weekly_seed": -1,
	"weekly_twist": "",
}

var _remote: Dictionary = {}


func get_value(key: String, fallback: Variant = null) -> Variant:
	if _remote.has(key):
		return _remote[key]
	return DEFAULTS.get(key, fallback)


func get_int(key: String) -> int:
	return int(get_value(key, 0))


func get_float(key: String) -> float:
	return float(get_value(key, 0.0))


## Replaces remote overrides. Unknown keys are ignored.
func apply_remote(values: Dictionary) -> void:
	_remote.clear()
	for key: Variant in values:
		if DEFAULTS.has(str(key)):
			_remote[str(key)] = values[key]
	changed.emit()
