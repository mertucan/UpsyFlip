class_name ComboTracker
extends RefCounted
## PERFECT streak, combo multiplier and FEVER mode rules. Pure logic.
##
## - Each consecutive PERFECT raises the streak; a plain stick or a miss resets it.
## - A PERFECT awards perfect_points x min(streak, combo_max_multiplier).
## - fever_perfects_needed consecutive PERFECTs start FEVER for fever_duration
##   seconds, during which coins are multiplied.

signal fever_started
signal fever_ended

var config: FeelConfig
var streak: int = 0
var fever_time_left: float = 0.0

var _fever_progress: int = 0


func _init(p_config: FeelConfig) -> void:
	config = p_config


func is_fever() -> bool:
	return fever_time_left > 0.0


func multiplier() -> int:
	return clampi(streak, 1, config.combo_max_multiplier)


func coin_multiplier() -> int:
	return config.fever_coin_multiplier if is_fever() else 1


## Fraction of FEVER time remaining, 0..1.
func fever_fraction() -> float:
	return clampf(fever_time_left / config.fever_duration, 0.0, 1.0)


## Returns the bonus points earned by this stick.
func register_stick(quality: int) -> int:
	if quality != StickRules.Quality.PERFECT:
		streak = 0
		_fever_progress = 0
		return 0
	streak += 1
	if not is_fever():
		_fever_progress += 1
		if _fever_progress >= config.fever_perfects_needed:
			_fever_progress = 0
			fever_time_left = config.fever_duration
			fever_started.emit()
	return config.perfect_points * multiplier()


func register_miss() -> void:
	streak = 0
	_fever_progress = 0


func advance(delta: float) -> void:
	if fever_time_left <= 0.0:
		return
	fever_time_left = maxf(fever_time_left - delta, 0.0)
	if fever_time_left == 0.0:
		fever_ended.emit()
