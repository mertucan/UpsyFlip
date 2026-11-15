extends "res://tests/test_case.gd"
## Localization completeness, language matching, quality rules and auto-pause.

const CSV_PATH: String = "res://localization/strings.csv"


func _read_csv() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1:
			rows.append(row)
	return rows


func _keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in _read_csv().slice(1):
		keys.append(row[0])
	return keys


## Format specifiers of a string in order of appearance, e.g. ["%s", "%d"].
func _placeholders(text: String) -> PackedStringArray:
	var regex: RegEx = RegEx.new()
	regex.compile("%[sd%]")
	var found: PackedStringArray = PackedStringArray()
	for result: RegExMatch in regex.search_all(text):
		found.append(result.get_string())
	found.sort()
	return found


func test_csv_covers_all_ten_languages() -> void:
	var header: PackedStringArray = _read_csv()[0]
	var expected: PackedStringArray = PackedStringArray(["keys"])
	expected.append_array(GraphicsSettings.LOCALES)
	assert_eq(header, expected, "CSV columns match the supported languages")
	assert_eq(GraphicsSettings.LOCALES.size(), 10, "ten languages")
	assert_eq(GraphicsSettings.LOCALE_NAMES.size(), 10, "a display name per language")


func test_every_string_is_translated_with_matching_placeholders() -> void:
	var rows: Array[PackedStringArray] = _read_csv()
	var header: PackedStringArray = rows[0]
	var seen: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in rows.slice(1):
		var key: String = row[0]
		assert_eq(row.size(), header.size(), "column count for '%s'" % key)
		assert_true(not seen.has(key), "duplicate key '%s'" % key)
		seen.append(key)
		if row.size() != header.size():
			continue
		assert_eq(row[1], key, "English text equals its key for '%s'" % key)
		for column: int in range(1, row.size()):
			assert_true(row[column].strip_edges() != "", "'%s' is missing in %s" % [key, header[column]])
			assert_eq(
					_placeholders(row[column]), _placeholders(key),
					"placeholders of '%s' in %s" % [key, header[column]])
	assert_true(seen.size() >= 90, "the string table is populated")


func test_data_driven_texts_have_translation_keys() -> void:
	var keys: PackedStringArray = _keys()
	for skin: SkinData in PlayerProgress.catalog.skins:
		assert_true(keys.has(skin.display_name), "skin name '%s'" % skin.display_name)
	for mission: MissionData in PlayerProgress.config.mission_pool:
		assert_true(keys.has(mission.description), "mission text '%s'" % mission.description)
	for product: ProductData in BillingService.catalog.products:
		assert_true(keys.has(product.title), "product title '%s'" % product.title)
	var level: LevelConfig = load("res://data/level_config.tres") as LevelConfig
	for theme: ThemeData in level.themes:
		assert_true(keys.has(theme.display_name), "theme name '%s'" % theme.display_name)


func test_translation_server_serves_each_language() -> void:
	var original: String = TranslationServer.get_locale()
	var expected: Dictionary[String, String] = {
		"en": "SETTINGS", "es": "AJUSTES", "pt_BR": "AJUSTES", "de": "EINSTELLUNGEN",
		"fr": "RÉGLAGES", "ru": "НАСТРОЙКИ", "ja": "設定", "ko": "설정", "tr": "AYARLAR",
		"id": "PENGATURAN",
	}
	for locale: String in expected:
		TranslationServer.set_locale(locale)
		assert_eq(String(TranslationServer.translate("SETTINGS")), expected[locale], "SETTINGS in " + locale)
	TranslationServer.set_locale("tr")
	var mission: MissionData = MissionData.new()
	mission.description = "Play %d runs"
	mission.target = 5
	assert_eq(mission.text(), "5 el oyna", "mission text is translated and formatted")
	TranslationServer.set_locale(original)


func test_system_locale_matching() -> void:
	assert_eq(GraphicsSettings.match_locale("tr_TR"), "tr", "regional Turkish")
	assert_eq(GraphicsSettings.match_locale("pt_PT"), "pt_BR", "any Portuguese maps to pt_BR")
	assert_eq(GraphicsSettings.match_locale("pt_BR"), "pt_BR", "exact match")
	assert_eq(GraphicsSettings.match_locale("ja_JP"), "ja", "regional Japanese")
	assert_eq(GraphicsSettings.match_locale("zh_CN"), "en", "unsupported language falls back to English")


func test_main_font_covers_latin_cyrillic_japanese_and_korean() -> void:
	var font: Font = load("res://ui/fonts/main_font.tres") as Font
	assert_true(font != null, "main font loads")
	for sample: String in ["A", "İ", "ğ", "ñ", "ß", "Ж", "я", "設", "ブ", "설"]:
		assert_true(font.has_char(sample.unicode_at(0)), "font has a glyph for '%s'" % sample)


func test_quality_rules() -> void:
	assert_true(GraphicsSettings.resolve_low(GraphicsSettings.Quality.LOW, false), "LOW is low")
	assert_true(not GraphicsSettings.resolve_low(GraphicsSettings.Quality.HIGH, true), "HIGH ignores the auto drop")
	assert_true(not GraphicsSettings.resolve_low(GraphicsSettings.Quality.AUTO, false), "AUTO starts high")
	assert_true(GraphicsSettings.resolve_low(GraphicsSettings.Quality.AUTO, true), "AUTO drops on slow devices")
	assert_true(GraphicsSettings.should_count_as_slow(30.0), "30 FPS is slow")
	assert_true(not GraphicsSettings.should_count_as_slow(59.0), "59 FPS is fine")
	assert_true(not GraphicsSettings.should_count_as_slow(0.0), "no measurement yet is not slow")


func test_run_pauses_in_background_and_counts_down() -> void:
	var game: Node = (load("res://core/game.tscn") as PackedScene).instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	game.call("_pause_run")
	assert_true(not game.call("_is_frozen"), "the menu is never paused")

	game.call("_start_play")
	var sim: FlightSim = game.get("_sim")
	sim.launch(1)
	game.call("_pause_run")
	assert_true(game.call("_is_frozen"), "an active run freezes when the app loses focus")
	var frozen_time: float = sim.time
	for frame: int in 5:
		await tree.process_frame
	assert_eq(sim.time, frozen_time, "the simulation does not advance while paused")

	game.call("_resume_run")
	assert_true(game.get("_resume_countdown") > 0.0, "returning starts the countdown")
	assert_true(game.call("_is_frozen"), "still frozen during the countdown")
	await tree.process_frame
	assert_eq(sim.time, frozen_time, "the simulation waits for the countdown")
	game.set("_resume_countdown", 0.01)
	for frame: int in 3:
		await tree.process_frame
	assert_true(not game.call("_is_frozen"), "play resumes after the countdown")
	assert_true(sim.time > frozen_time, "the simulation advances again")

	game.queue_free()
	await tree.process_frame
