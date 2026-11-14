extends Node
## Vibration feedback. No-op on platforms without a vibrator.

var enabled: bool = true


func vibrate(duration_ms: int) -> void:
	if not enabled or duration_ms <= 0:
		return
	Input.vibrate_handheld(duration_ms)
