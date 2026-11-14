class_name Hud
extends CanvasLayer
## In-run HUD, built from code: score, best, coins, flash texts, theme banner,
## retry prompt, charge bar and the debug control-mode switch.

signal mode_pressed

const OUTLINE_COLOR: Color = Color(0.05, 0.06, 0.12)

var _score_label: Label
var _best_label: Label
var _coins_label: Label
var _flash_label: Label
var _banner_label: Label
var _retry_label: Label
var _mode_button: Button
var _power_bar: ProgressBar
var _flash_tween: Tween
var _banner_tween: Tween


func _ready() -> void:
	_score_label = _make_label(120, Control.PRESET_TOP_WIDE, 150.0)
	_best_label = _make_label(40, Control.PRESET_TOP_WIDE, 310.0)
	_coins_label = _make_label(44, Control.PRESET_TOP_LEFT, 170.0)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coins_label.grow_horizontal = Control.GROW_DIRECTION_END
	_coins_label.offset_left = 40.0
	_flash_label = _make_label(96, Control.PRESET_CENTER_TOP, 520.0)
	_flash_label.modulate.a = 0.0
	_banner_label = _make_label(120, Control.PRESET_CENTER_TOP, 760.0)
	_banner_label.modulate.a = 0.0
	_retry_label = _make_label(72, Control.PRESET_CENTER, 0.0)
	_retry_label.text = "TAP TO RETRY"
	_retry_label.visible = false

	_power_bar = ProgressBar.new()
	_power_bar.min_value = 0.0
	_power_bar.max_value = 1.0
	_power_bar.step = 0.0
	_power_bar.show_percentage = false
	_power_bar.visible = false
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_power_bar.offset_left = 160.0
	_power_bar.offset_right = -160.0
	_power_bar.offset_top = -330.0
	_power_bar.offset_bottom = -280.0
	add_child(_power_bar)

	# Debug-only control mode switch for feel tuning.
	_mode_button = Button.new()
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.add_theme_font_size_override("font_size", 34)
	_mode_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_button.offset_left = -300.0
	_mode_button.offset_right = -30.0
	_mode_button.offset_top = 160.0
	_mode_button.offset_bottom = 240.0
	_mode_button.pressed.connect(func() -> void: mode_pressed.emit())
	add_child(_mode_button)


func set_score(total: int) -> void:
	_score_label.text = str(total)


func set_best(best: int) -> void:
	_best_label.text = "BEST %d" % best


func set_coins(coins: int) -> void:
	_coins_label.text = "COINS %d" % coins


func set_mode_text(text: String) -> void:
	_mode_button.text = text


func show_retry(shown: bool) -> void:
	_retry_label.visible = shown


func show_power(shown: bool, value: float = 0.0) -> void:
	_power_bar.visible = shown
	_power_bar.value = value


## True when a screen position is over a HUD button and must not launch.
func blocks_touch(screen_position: Vector2) -> bool:
	return _mode_button.get_global_rect().has_point(screen_position)


## Short pop-up text for moment-to-moment feedback.
func flash(text: String, color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_label.text = text
	_flash_label.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.6).set_delay(0.25)


## Large, slower banner for milestones such as entering a new theme.
func show_banner(text: String, color: Color) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.modulate = Color(color, 0.0)
	_banner_label.pivot_offset = _banner_label.size * 0.5
	_banner_label.scale = Vector2(0.6, 0.6)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 1.0, 0.2)
	_banner_tween.parallel().tween_property(_banner_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 0.6).set_delay(1.2)


func _make_label(font_size: int, preset: Control.LayoutPreset, top: float) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", floori(font_size / 6.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = top
	label.offset_bottom = top + font_size * 1.4
	add_child(label)
	return label
