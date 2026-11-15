class_name SettingsSheet
extends Sheet
## Sound, vibration, graphics quality, battery saver and language.

## Quality or battery saver changed; the game re-applies them.
signal graphics_changed
signal language_changed

var _sound_button: Button
var _haptics_button: Button
var _quality_button: Button
var _battery_button: Button
var _language_button: Button
var _version_label: Label


func _init() -> void:
	super("SETTINGS")


func _build() -> void:
	_sound_button = _add_button(_on_sound_pressed)
	_haptics_button = _add_button(_on_haptics_pressed)
	_quality_button = _add_button(_on_quality_pressed)
	_battery_button = _add_button(_on_battery_pressed)
	_language_button = _add_button(_on_language_pressed)
	_version_label = UiKit.label("", 28, UiKit.COLOR_DIM_TEXT)
	body.add_child(_version_label)


func _refresh() -> void:
	_sound_button.text = tr("SOUND: %s") % tr("ON" if AudioService.sfx_enabled else "OFF")
	_haptics_button.text = tr("VIBRATION: %s") % tr("ON" if Haptics.enabled else "OFF")
	_quality_button.text = tr("QUALITY: %s") % tr(
			GraphicsSettings.QUALITY_NAMES[GraphicsSettings.quality()])
	_battery_button.text = tr("BATTERY SAVER: %s") % tr(
			"ON" if GraphicsSettings.battery_saver() else "OFF")
	_language_button.text = tr("LANGUAGE: %s") % GraphicsSettings.LOCALE_NAMES[
			GraphicsSettings.locale_index()]
	_version_label.text = tr("Version %s") % ProjectSettings.get_setting("application/config/version")


func _add_button(handler: Callable) -> Button:
	var setting_button: Button = UiKit.button("")
	# Values such as language names are already final; do not translate again.
	setting_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	setting_button.custom_minimum_size.y = 110.0
	setting_button.pressed.connect(handler)
	body.add_child(setting_button)
	return setting_button


func _on_sound_pressed() -> void:
	AudioService.set_enabled(not AudioService.sfx_enabled)
	_refresh()


func _on_haptics_pressed() -> void:
	Haptics.set_enabled(not Haptics.enabled)
	Haptics.vibrate(30)
	_refresh()


func _on_quality_pressed() -> void:
	var next: int = (GraphicsSettings.quality() + 1) % GraphicsSettings.Quality.size()
	GraphicsSettings.set_quality(next as GraphicsSettings.Quality)
	graphics_changed.emit()
	_refresh()


func _on_battery_pressed() -> void:
	GraphicsSettings.set_battery_saver(not GraphicsSettings.battery_saver())
	graphics_changed.emit()
	_refresh()


func _on_language_pressed() -> void:
	var next: int = (GraphicsSettings.locale_index() + 1) % GraphicsSettings.LOCALES.size()
	GraphicsSettings.set_locale(GraphicsSettings.LOCALES[next])
	language_changed.emit()
	_refresh()
