class_name GraphicsSettings
extends RefCounted
## Quality level, automatic quality drop on slow devices, battery saver and
## language. Stored in the SaveService; applied to a viewport on demand.

enum Quality { AUTO, HIGH, LOW }

const SAVE_KEY_QUALITY: String = "quality"
const SAVE_KEY_BATTERY_SAVER: String = "battery_saver"
const SAVE_KEY_LOCALE: String = "locale"
const QUALITY_NAMES: PackedStringArray = ["AUTO", "HIGH", "LOW"]

## Locale codes in menu order, with the name each language calls itself.
const LOCALES: PackedStringArray = ["en", "es", "pt_BR", "de", "fr", "ru", "ja", "ko", "tr", "id"]
const LOCALE_NAMES: PackedStringArray = [
	"English", "Español", "Português", "Deutsch", "Français",
	"Русский", "日本語", "한국어", "Türkçe", "Bahasa Indonesia",
]

const GAMEPLAY_FPS: int = 60
const BATTERY_SAVER_MENU_FPS: int = 30
const LOW_RENDER_SCALE: float = 0.75
## AUTO drops to low quality when the average FPS stays below this...
const AUTO_DROP_FPS: float = 48.0
## ...for this many seconds of play.
const AUTO_DROP_SECONDS: float = 4.0

## Set once AUTO has decided this device needs low quality (kept for the session).
static var auto_dropped: bool = false

static var _slow_time: float = 0.0


static func quality() -> Quality:
	return clampi(SaveService.get_int(SAVE_KEY_QUALITY, Quality.AUTO), 0, Quality.size() - 1) as Quality


static func set_quality(value: Quality) -> void:
	SaveService.set_value(SAVE_KEY_QUALITY, value)
	SaveService.save_to_disk()
	auto_dropped = false
	_slow_time = 0.0


static func is_low() -> bool:
	return resolve_low(quality(), auto_dropped)


## Pure rule: is the effective quality low?
static func resolve_low(selected: Quality, has_auto_dropped: bool) -> bool:
	return selected == Quality.LOW or (selected == Quality.AUTO and has_auto_dropped)


static func battery_saver() -> bool:
	return SaveService.get_bool(SAVE_KEY_BATTERY_SAVER, false)


static func set_battery_saver(value: bool) -> void:
	SaveService.set_value(SAVE_KEY_BATTERY_SAVER, value)
	SaveService.save_to_disk()


## Particle count multiplier for the current quality.
static func particle_scale() -> float:
	return 0.5 if is_low() else 1.0


## Applies render scale and anti-aliasing for the current quality.
static func apply_to(viewport: Viewport) -> void:
	var low: bool = is_low()
	viewport.scaling_3d_scale = LOW_RENDER_SCALE if low else 1.0
	viewport.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X


## Caps the frame rate: full speed while playing; a low cap in menus when
## battery saver is on.
static func apply_frame_cap(in_menu: bool) -> void:
	Engine.max_fps = BATTERY_SAVER_MENU_FPS if (in_menu and battery_saver()) else GAMEPLAY_FPS


## Feed gameplay frame times while quality is AUTO. Returns true at the
## moment quality should drop to low.
static func track_performance(delta: float, fps: float) -> bool:
	if quality() != Quality.AUTO or auto_dropped:
		return false
	if should_count_as_slow(fps):
		_slow_time += delta
	else:
		_slow_time = maxf(_slow_time - delta, 0.0)
	if _slow_time >= AUTO_DROP_SECONDS:
		auto_dropped = true
		return true
	return false


static func should_count_as_slow(fps: float) -> bool:
	return fps > 0.0 and fps < AUTO_DROP_FPS


# --- Language ---------------------------------------------------------------

## Applies the saved language, or the best match for the device language.
static func apply_saved_locale() -> void:
	var saved: String = str(SaveService.get_value(SAVE_KEY_LOCALE, ""))
	TranslationServer.set_locale(saved if LOCALES.has(saved) else match_locale(OS.get_locale()))


## Maps a system locale such as "pt_PT" or "tr_TR" to a supported one.
static func match_locale(system_locale: String) -> String:
	if LOCALES.has(system_locale):
		return system_locale
	var language: String = system_locale.split("_")[0]
	for locale: String in LOCALES:
		if locale.split("_")[0] == language:
			return locale
	return "en"


static func locale_index() -> int:
	return maxi(LOCALES.find(match_locale(TranslationServer.get_locale())), 0)


static func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	SaveService.set_value(SAVE_KEY_LOCALE, locale)
	SaveService.save_to_disk()
