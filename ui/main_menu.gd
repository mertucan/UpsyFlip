class_name MainMenu
extends Control
## Main menu drawn over the live game scene. Tapping anywhere above the
## bottom button row starts a run; meta screens sit in thumb reach.

signal play_pressed
signal shop_pressed
signal store_pressed
signal free_coins_pressed
signal missions_pressed
signal daily_pressed
signal settings_pressed

var _balance_label: Label
var _best_label: Label
var _daily_button: Button
var _missions_button: Button
var _free_coins_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Invisible full-screen play button; the bottom bar sits on top of it.
	var play_area: Button = Button.new()
	play_area.flat = true
	play_area.focus_mode = Control.FOCUS_NONE
	play_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	play_area.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	play_area.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	play_area.pressed.connect(func() -> void: play_pressed.emit())
	add_child(play_area)

	var top: VBoxContainer = VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 150.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	_balance_label = UiKit.label("", 40, UiKit.COLOR_COIN, true)
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_balance_label)
	var title: Label = UiKit.label("UPSY FLIP", 150, UiKit.COLOR_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	_best_label = UiKit.label("", 44, UiKit.COLOR_DIM_TEXT, true)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_best_label)

	var prompt: Label = UiKit.label("TAP TO PLAY", 76, UiKit.COLOR_TEXT, true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.offset_top = 80.0
	prompt.offset_bottom = 190.0
	add_child(prompt)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 0.7)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.7)

	var bar: GridContainer = GridContainer.new()
	bar.columns = 2
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = 40.0
	bar.offset_right = -40.0
	bar.offset_bottom = -110.0
	bar.add_theme_constant_override("h_separation", 20)
	bar.add_theme_constant_override("v_separation", 20)
	add_child(bar)
	_add_bar_button(bar, "SKINS", UiKit.COLOR_PRIMARY, shop_pressed)
	var store_button: Button = _add_bar_button(
			bar, "STORE", UiKit.COLOR_COIN.darkened(0.45), store_pressed)
	store_button.disabled = not BillingService.is_available()
	_missions_button = _add_bar_button(bar, "MISSIONS", UiKit.COLOR_SECONDARY, missions_pressed)
	_daily_button = _add_bar_button(bar, "DAILY", UiKit.COLOR_SECONDARY, daily_pressed)
	_free_coins_button = _add_bar_button(bar, "", UiKit.COLOR_SECONDARY, free_coins_pressed)
	_add_bar_button(bar, "SETTINGS", UiKit.COLOR_SECONDARY, settings_pressed)

	Economy.coins_changed.connect(func(_amount: int) -> void: refresh())
	Economy.gems_changed.connect(func(_amount: int) -> void: refresh())
	PlayerProgress.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_balance_label.text = UiKit.currency_text(Economy.coins, Economy.gems)
	_best_label.text = tr("BEST %d") % SaveService.get_int("best_score")
	_daily_button.text = "DAILY  !" if PlayerProgress.can_claim_daily() else "DAILY"
	var done: int = 0
	var missions: Array[MissionData] = PlayerProgress.todays_missions()
	for mission: MissionData in missions:
		if PlayerProgress.missions.is_completed(mission):
			done += 1
	_missions_button.text = tr("MISSIONS %d/%d") % [done, missions.size()]
	var can_claim_free: bool = PlayerProgress.can_claim_free_coins()
	_free_coins_button.disabled = not can_claim_free
	_free_coins_button.text = (tr("FREE +%d  (AD)") % RemoteConfig.get_int("free_coins_amount")) if can_claim_free else "FREE: TOMORROW"


func _add_bar_button(bar: GridContainer, text: String, color: Color, target: Signal) -> Button:
	var bar_button: Button = UiKit.button(text, color, 36)
	bar_button.custom_minimum_size.y = 110.0
	bar_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_button.pressed.connect(func() -> void: target.emit())
	bar.add_child(bar_button)
	return bar_button
