class_name ShopSheet
extends Sheet
## Skin shop: buy skins directly with coins or gems, and pick the one to play.

signal skin_changed
## The player asked to try a locked skin for one run (rewarded ad).
signal try_requested(skin: SkinData)

var _balance_label: Label
var _rows: VBoxContainer


func _init() -> void:
	super("SKINS")


func _build() -> void:
	_balance_label = UiKit.label("", 40, UiKit.COLOR_COIN)
	body.add_child(_balance_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 16)
	body.add_child(_rows)


func _refresh() -> void:
	_balance_label.text = UiKit.currency_text(Economy.coins, Economy.gems)
	for child: Node in _rows.get_children():
		child.queue_free()
	for skin: SkinData in PlayerProgress.catalog.skins:
		_rows.add_child(_make_row(skin))


func _make_row(skin: SkinData) -> Control:
	var row: PanelContainer = UiKit.row(20.0)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)

	var swatch: ColorRect = ColorRect.new()
	swatch.color = skin.primary_color
	swatch.custom_minimum_size = Vector2(24.0, 0.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(swatch)

	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiKit.label(skin.display_name, 40))
	line.add_child(names)

	var owned: bool = PlayerProgress.inventory.owns(skin.id)
	if owned:
		names.add_child(UiKit.label(
				tr("MASTERY LV %d") % PlayerProgress.mastery_level(skin), 28, UiKit.COLOR_DIM_TEXT))
		var is_selected: bool = PlayerProgress.inventory.selected == skin.id
		var select_button: Button = UiKit.button(
				"SELECTED" if is_selected else "SELECT",
				UiKit.COLOR_GOOD.darkened(0.35) if is_selected else UiKit.COLOR_PRIMARY, 36)
		select_button.custom_minimum_size.x = 300.0
		select_button.disabled = is_selected
		select_button.pressed.connect(_on_select.bind(skin))
		line.add_child(select_button)
	else:
		names.add_child(UiKit.label(
				"STARTER PACK" if skin.exclusive else "LOCKED", 28, UiKit.COLOR_DIM_TEXT))
		var try_button: Button = UiKit.button("TRY", UiKit.COLOR_SECONDARY, 30)
		try_button.custom_minimum_size.x = 130.0
		try_button.disabled = not AdsService.is_rewarded_ready()
		try_button.pressed.connect(func() -> void: try_requested.emit(skin))
		line.add_child(try_button)
		if skin.exclusive:
			return row
		if skin.price_gems > 0:
			line.add_child(_make_buy_button(skin, true))
		if skin.price_coins > 0:
			line.add_child(_make_buy_button(skin, false))
	return row


func _make_buy_button(skin: SkinData, with_gems: bool) -> Button:
	var price: int = SkinInventory.price_of(skin, with_gems)
	var balance: int = Economy.gems if with_gems else Economy.coins
	var buy_button: Button = UiKit.button(
			tr("%d GEMS" if with_gems else "%d COINS") % price,
			UiKit.COLOR_GEM.darkened(0.45) if with_gems else UiKit.COLOR_COIN.darkened(0.5), 28)
	buy_button.custom_minimum_size.x = 200.0
	buy_button.disabled = balance < price
	buy_button.pressed.connect(_on_buy.bind(skin, with_gems))
	return buy_button


func _on_select(skin: SkinData) -> void:
	if PlayerProgress.select_skin(skin):
		skin_changed.emit()
		_refresh()


func _on_buy(skin: SkinData, with_gems: bool) -> void:
	if PlayerProgress.buy_skin(skin, with_gems):
		AudioService.play_sfx(&"fever")
		skin_changed.emit()
		_refresh()
