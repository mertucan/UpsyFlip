class_name DailySheet
extends Sheet
## 7-day login streak with one claim per day.

var _days: HBoxContainer
var _claim_button: Button
var _status: Label


func _init() -> void:
	super("DAILY REWARD")


func _build() -> void:
	_days = HBoxContainer.new()
	_days.add_theme_constant_override("separation", 10)
	body.add_child(_days)
	_status = UiKit.label("", 34, UiKit.COLOR_DIM_TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	_claim_button = UiKit.button("CLAIM", UiKit.COLOR_PRIMARY, 52)
	_claim_button.pressed.connect(_on_claim)
	body.add_child(_claim_button)


func _refresh() -> void:
	var config: MetaConfig = PlayerProgress.config
	var can_claim: bool = PlayerProgress.can_claim_daily()
	var current: int = PlayerProgress.daily.display_index(PlayerProgress.today(), config.cycle_length())
	for child: Node in _days.get_children():
		child.queue_free()
	for index: int in config.cycle_length():
		_days.add_child(_make_day(index, current, can_claim))
	_claim_button.disabled = not can_claim
	_claim_button.text = "CLAIM" if can_claim else "CLAIMED"
	_status.text = "Come back every day for bigger rewards" if can_claim else "Next reward tomorrow"


func _make_day(index: int, current: int, can_claim: bool) -> Control:
	var config: MetaConfig = PlayerProgress.config
	var is_current: bool = index == current
	var is_claimed: bool = index < current or (is_current and not can_claim)
	var color: Color = UiKit.COLOR_ROW
	if is_claimed:
		color = UiKit.COLOR_GOOD.darkened(0.5)
	elif is_current:
		color = UiKit.COLOR_PRIMARY.darkened(0.2)

	var cell: PanelContainer = PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", UiKit.box(color, 18, 10.0))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(column)

	var day_label: Label = UiKit.label(tr("DAY %d") % (index + 1), 22, UiKit.COLOR_DIM_TEXT)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(day_label)
	var gems: int = config.daily_gems[index]
	var amount: Label = UiKit.label(
			str(gems) if gems > 0 else str(config.daily_coins[index]), 40,
			UiKit.COLOR_GEM if gems > 0 else UiKit.COLOR_COIN)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(amount)
	var unit: Label = UiKit.label("GEMS" if gems > 0 else "COINS", 20, UiKit.COLOR_DIM_TEXT)
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(unit)
	return cell


func _on_claim() -> void:
	if PlayerProgress.claim_daily() >= 0:
		AudioService.play_sfx(&"coin")
		Haptics.vibrate(40)
		_refresh()
