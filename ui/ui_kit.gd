class_name UiKit
extends RefCounted
## Shared look for code-built UI: colors, labels, buttons and panels.

const COLOR_TEXT: Color = Color(0.97, 0.97, 1.0)
const COLOR_DIM_TEXT: Color = Color(0.72, 0.76, 0.86)
const COLOR_OUTLINE: Color = Color(0.05, 0.06, 0.12)
const COLOR_PANEL: Color = Color(0.1, 0.12, 0.22, 0.97)
const COLOR_ROW: Color = Color(0.17, 0.2, 0.34)
const COLOR_PRIMARY: Color = Color(1.0, 0.33, 0.36)
const COLOR_SECONDARY: Color = Color(0.25, 0.3, 0.5)
const COLOR_COIN: Color = Color(1.0, 0.86, 0.3)
const COLOR_GEM: Color = Color(0.45, 0.85, 1.0)
const COLOR_GOOD: Color = Color(0.45, 0.9, 0.5)
const COLOR_SCRIM: Color = Color(0.0, 0.0, 0.05, 0.55)
const CORNER_RADIUS: int = 28
const BUTTON_HEIGHT: float = 130.0


static func label(text: String, font_size: int, color: Color = COLOR_TEXT, outlined: bool = false) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if outlined:
		result.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		result.add_theme_constant_override("outline_size", floori(font_size / 6.0))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func box(color: Color, radius: int = CORNER_RADIUS, padding: float = 0.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func button(text: String, color: Color = COLOR_SECONDARY, font_size: int = 44) -> Button:
	var result: Button = Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", COLOR_TEXT)
	result.add_theme_color_override("font_disabled_color", COLOR_DIM_TEXT)
	result.add_theme_stylebox_override("normal", box(color, CORNER_RADIUS, 18.0))
	result.add_theme_stylebox_override("hover", box(color, CORNER_RADIUS, 18.0))
	result.add_theme_stylebox_override("pressed", box(color.darkened(0.25), CORNER_RADIUS, 18.0))
	result.add_theme_stylebox_override("disabled", box(color.darkened(0.45), CORNER_RADIUS, 18.0))
	result.pressed.connect(func() -> void: AudioService.play_sfx(&"button"))
	return result


static func progress_bar(fill: Color, height: float = 26.0) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", box(COLOR_OUTLINE, 13))
	bar.add_theme_stylebox_override("fill", box(fill, 13))
	return bar


## Rounded row container used for list entries.
static func row(padding: float = 24.0) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(COLOR_ROW, CORNER_RADIUS, padding))
	return panel


static func currency_text(coins: int, gems: int) -> String:
	return TranslationServer.translate("COINS %d    GEMS %d") % [coins, gems]
