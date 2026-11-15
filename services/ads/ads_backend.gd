class_name AdsBackend
extends Node
## Interface every ad provider implements. Game code never talks to a
## backend directly; it goes through the AdsService autoload.

## The consent flow (UMP) finished; ads may now be initialized.
signal consent_resolved
signal rewarded_closed(earned: bool)
signal interstitial_closed


## Runs the privacy consent flow, then emits consent_resolved.
func request_consent() -> void:
	consent_resolved.emit()


## Starts the ad SDK and begins loading ads. Called after consent.
func initialize() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


func show_rewarded() -> void:
	rewarded_closed.emit(false)


func is_interstitial_ready() -> bool:
	return false


func show_interstitial() -> void:
	interstitial_closed.emit()
