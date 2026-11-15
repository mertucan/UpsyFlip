class_name MissionsSheet
extends Sheet
## Today's missions with progress. Rewards are paid automatically when a run
## completes a mission.

var _rows: VBoxContainer


func _init() -> void:
	super("DAILY MISSIONS")


func _build() -> void:
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 16)
	body.add_child(_rows)
	body.add_child(UiKit.label("New missions every day", 30, UiKit.COLOR_DIM_TEXT))


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for mission: MissionData in PlayerProgress.todays_missions():
		_rows.add_child(_make_row(mission))


func _make_row(mission: MissionData) -> Control:
	var board: MissionBoard = PlayerProgress.missions
	var done: bool = board.is_completed(mission)
	var row: PanelContainer = UiKit.row()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)

	var line: HBoxContainer = HBoxContainer.new()
	column.add_child(line)
	var text: Label = UiKit.label(mission.text(), 38)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(text)
	line.add_child(UiKit.label(
			"DONE" if done else tr("+%d COINS") % mission.reward_coins, 34,
			UiKit.COLOR_GOOD if done else UiKit.COLOR_COIN))

	var bar: ProgressBar = UiKit.progress_bar(UiKit.COLOR_GOOD if done else UiKit.COLOR_PRIMARY)
	bar.value = float(board.progress_of(mission)) / float(maxi(mission.target, 1))
	column.add_child(bar)
	column.add_child(UiKit.label(
			"%d / %d" % [board.progress_of(mission), mission.target], 28, UiKit.COLOR_DIM_TEXT))
	return row
