class_name ResultsPanel
extends Control
## End-of-run screen. Everything except the HOME button lets touches through,
## so tapping anywhere restarts instantly.

signal home_pressed
signal continue_pressed
signal double_pressed

var _score_label: Label
var _best_label: Label
var _lines: VBoxContainer
var _goal_label: Label
var _goal_bar: ProgressBar
var _coins_line: Label
var _continue_button: Button
var _double_button: Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scrim: ColorRect = ColorRect.new()
	scrim.color = UiKit.COLOR_SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 330.0
	column.offset_left = 70.0
	column.offset_right = -70.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	_score_label = _centered(UiKit.label("", 190, UiKit.COLOR_TEXT, true))
	column.add_child(_score_label)
	_best_label = _centered(UiKit.label("", 48, UiKit.COLOR_DIM_TEXT, true))
	column.add_child(_best_label)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 8)
	column.add_child(_lines)
	_goal_label = _centered(UiKit.label("", 38, UiKit.COLOR_TEXT, true))
	column.add_child(_goal_label)
	_goal_bar = UiKit.progress_bar(UiKit.COLOR_COIN, 34.0)
	column.add_child(_goal_bar)

	var retry: Label = _centered(UiKit.label("TAP TO RETRY", 76, UiKit.COLOR_TEXT, true))
	retry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	retry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry.offset_top = -640.0
	retry.offset_bottom = -530.0
	add_child(retry)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(retry, "modulate:a", 0.35, 0.6)
	pulse.tween_property(retry, "modulate:a", 1.0, 0.6)

	# Optional rewarded-ad offers, stacked in thumb reach on the right.
	var offers: VBoxContainer = VBoxContainer.new()
	offers.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offers.grow_vertical = Control.GROW_DIRECTION_BEGIN
	offers.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offers.offset_right = -40.0
	offers.offset_left = -620.0
	offers.offset_bottom = -110.0
	offers.add_theme_constant_override("separation", 16)
	add_child(offers)
	_continue_button = UiKit.button("CONTINUE  (AD)", UiKit.COLOR_PRIMARY, 38)
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	offers.add_child(_continue_button)
	_double_button = UiKit.button("DOUBLE COINS  (AD)", UiKit.COLOR_COIN.darkened(0.45), 38)
	_double_button.pressed.connect(func() -> void: double_pressed.emit())
	offers.add_child(_double_button)

	var home: Button = UiKit.button("HOME", UiKit.COLOR_SECONDARY, 40)
	home.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	home.offset_left = 40.0
	home.offset_right = 300.0
	home.offset_top = -240.0
	home.offset_bottom = -110.0
	home.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home)


func show_results(
		summary: RunSummary, rewards: RunRewards, is_new_best: bool, best: int,
		can_continue: bool = false, can_double: bool = false) -> void:
	_continue_button.visible = can_continue
	_double_button.visible = can_double
	_score_label.text = str(summary.score)
	_best_label.text = "NEW BEST!" if is_new_best else tr("BEST %d") % best
	_best_label.add_theme_color_override(
			"font_color", UiKit.COLOR_COIN if is_new_best else UiKit.COLOR_DIM_TEXT)

	for child: Node in _lines.get_children():
		child.queue_free()
	_coins_line = _add_line(tr("+%d COINS") % rewards.run_coins, UiKit.COLOR_COIN)
	for mission: MissionData in rewards.completed_missions:
		_add_line(tr("MISSION DONE  +%d COINS") % mission.reward_coins, UiKit.COLOR_GOOD)
	if rewards.mastery_level_up > 0:
		_add_line(tr("MASTERY LEVEL %d") % rewards.mastery_level_up, UiKit.COLOR_GEM)

	var goal: SkinData = PlayerProgress.next_skin_goal()
	_goal_label.visible = goal != null
	_goal_bar.visible = goal != null
	if goal != null:
		var fraction: float = clampf(float(Economy.coins) / float(goal.price_coins), 0.0, 1.0)
		_goal_bar.value = fraction
		if fraction >= 1.0:
			_goal_label.text = tr("%s READY TO UNLOCK!") % tr(goal.display_name)
		else:
			_goal_label.text = tr("NEXT SKIN: %s  %d%%") % [tr(goal.display_name), floori(fraction * 100.0)]
	visible = true


## The double-coins ad paid out: show the new amount and retire the offer.
func show_doubled(total_coins: int) -> void:
	_double_button.visible = false
	if _coins_line != null:
		_coins_line.text = tr("+%d COINS  (x2)") % total_coins


func hide_offers() -> void:
	_continue_button.visible = false
	_double_button.visible = false


func _add_line(text: String, color: Color) -> Label:
	var line: Label = _centered(UiKit.label(text, 44, color, true))
	_lines.add_child(line)
	return line


static func _centered(text_label: Label) -> Label:
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return text_label
