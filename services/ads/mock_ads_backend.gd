class_name MockAdsBackend
extends AdsBackend
## Stand-in ad provider for desktop and tests; only created in debug builds.
## Shows a plain "TEST AD" card instead of a real ad and always rewards.

const REWARDED_SECONDS: float = 1.5
const INTERSTITIAL_SECONDS: float = 1.5

## When true, ads finish instantly without any UI (headless tests).
var instant: bool = false
var rewarded_shown: int = 0
var interstitials_shown: int = 0

var _initialized: bool = false


func _ready() -> void:
	instant = DisplayServer.get_name() == "headless"


func initialize() -> void:
	_initialized = true


func is_rewarded_ready() -> bool:
	return _initialized


func show_rewarded() -> void:
	rewarded_shown += 1
	if not instant:
		await _show_card("TEST AD\nReward incoming...", REWARDED_SECONDS)
	rewarded_closed.emit(true)


func is_interstitial_ready() -> bool:
	return _initialized


func show_interstitial() -> void:
	interstitials_shown += 1
	if not instant:
		await _show_card("TEST AD\n(interstitial)", INTERSTITIAL_SECONDS)
	interstitial_closed.emit()


func _show_card(text: String, seconds: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.04, 0.04, 0.08)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(background)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(label)
	await get_tree().create_timer(seconds, true, false, true).timeout
	layer.queue_free()
