class_name Sheet
extends Control
## Bottom sheet: a dimmed backdrop with a titled panel anchored to the bottom
## of the screen, where the thumb reaches. Subclasses fill `body` in
## _build() and update it in _refresh().

signal closed

var body: VBoxContainer

var _title: String = ""


func _init(title: String = "") -> void:
	_title = title


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim: ColorRect = ColorRect.new()
	scrim.color = UiKit.COLOR_SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UiKit.box(UiKit.COLOR_PANEL, 44, 40.0)
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_bottom = 110.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	panel.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title_label: Label = UiKit.label(_title, 60)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button: Button = UiKit.button("X", UiKit.COLOR_SECONDARY, 40)
	close_button.custom_minimum_size = Vector2(110.0, 110.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	_build()


func open() -> void:
	_refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build() -> void:
	pass


func _refresh() -> void:
	pass


func _on_scrim_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed:
		close()
