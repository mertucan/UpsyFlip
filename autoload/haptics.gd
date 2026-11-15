extends Node
## Vibration feedback. No-op on platforms without a vibrator.

const SAVE_KEY_ENABLED: String = "haptics_enabled"

var enabled: bool = true

var _pattern_id: int = 0


func _ready() -> void:
	enabled = SaveService.get_bool(SAVE_KEY_ENABLED, true)


func set_enabled(value: bool) -> void:
	enabled = value
	SaveService.set_value(SAVE_KEY_ENABLED, value)
	SaveService.save_to_disk()


func vibrate(duration_ms: int) -> void:
	if not enabled or duration_ms <= 0:
		return
	Input.vibrate_handheld(duration_ms)


## Plays alternating vibrate/pause durations (milliseconds), starting with a
## vibration. A new pattern cancels the one in progress.
func play_pattern(pattern: PackedInt32Array) -> void:
	if not enabled:
		return
	_pattern_id += 1
	var id: int = _pattern_id
	for index: int in pattern.size():
		if id != _pattern_id:
			return
		if index % 2 == 0:
			Input.vibrate_handheld(pattern[index])
		await get_tree().create_timer(pattern[index] / 1000.0, true, false, true).timeout
