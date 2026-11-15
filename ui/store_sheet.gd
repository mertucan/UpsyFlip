class_name StoreSheet
extends Sheet
## Real-money store: remove ads, starter pack, coin and gem packs.
## Prices come from the store backend, never from the game.

var _balance_label: Label
var _rows: VBoxContainer
var _status: Label


func _init() -> void:
	super("STORE")


func _build() -> void:
	_balance_label = UiKit.label("", 40, UiKit.COLOR_COIN)
	body.add_child(_balance_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	body.add_child(_rows)
	_status = UiKit.label("", 30, UiKit.COLOR_DIM_TEXT)
	body.add_child(_status)
	BillingService.purchase_completed.connect(_on_purchase_result.bind("Thank you!"))
	BillingService.purchase_pending.connect(_on_purchase_result.bind("Payment pending..."))
	BillingService.purchase_failed.connect(_on_purchase_result.bind("Purchase not completed"))


func open() -> void:
	_status.text = "" if BillingService.is_available() else tr("Store not available")
	super()


func _refresh() -> void:
	_balance_label.text = UiKit.currency_text(Economy.coins, Economy.gems)
	for child: Node in _rows.get_children():
		child.queue_free()
	for product: ProductData in BillingService.catalog.products:
		_rows.add_child(_make_row(product))


func _make_row(product: ProductData) -> Control:
	var row: PanelContainer = UiKit.row(16.0)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	row.add_child(line)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(product.title, 38))
	texts.add_child(UiKit.label(product.grants_text(), 26, UiKit.COLOR_DIM_TEXT))
	line.add_child(texts)

	var available: bool = BillingService.can_purchase(product)
	var store_open: bool = BillingService.is_available()
	var price: String = BillingService.price_text(product)
	var buy_button: Button = UiKit.button(
			(price if price != "" else "...") if available else "OWNED",
			UiKit.COLOR_PRIMARY if available else UiKit.COLOR_GOOD.darkened(0.35), 34)
	buy_button.custom_minimum_size = Vector2(240.0, 100.0)
	buy_button.disabled = not available or not store_open
	buy_button.pressed.connect(func() -> void: BillingService.purchase(product.id))
	line.add_child(buy_button)
	return row


func _on_purchase_result(_product_id: StringName, message: String) -> void:
	if not visible:
		return
	_refresh()
	_status.text = message
