extends "res://tests/test_case.gd"

const ROWS: int = 400


func _level() -> LevelConfig:
	return load("res://data/level_config.tres") as LevelConfig


func _generate(level_seed: int, count: int) -> Array[PlatformSpec]:
	var generator: LevelGenerator = LevelGenerator.new(_level(), level_seed)
	var rows: Array[PlatformSpec] = []
	for index: int in count:
		rows.append(generator.next())
	return rows


func _signature(rows: Array[PlatformSpec]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: PlatformSpec in rows:
		var pickup_text: String = "-"
		if row.pickup != null:
			pickup_text = "%d@%s" % [row.pickup.kind, str(row.pickup.position)]
		parts.append("%d|%s|%f|%f|%s" % [row.kind, str(row.rect), row.move_amplitude, row.move_phase, pickup_text])
	return "\n".join(parts)


func test_same_seed_gives_same_level() -> void:
	assert_eq(_signature(_generate(1234, ROWS)), _signature(_generate(1234, ROWS)), "same seed, same level")


func test_different_seeds_give_different_levels() -> void:
	assert_true(_signature(_generate(1, ROWS)) != _signature(_generate(2, ROWS)), "different seeds differ")


func test_intro_rows_are_fixed_zigzag() -> void:
	var level: LevelConfig = _level()
	var rows: Array[PlatformSpec] = _generate(99, level.intro_rows)
	for index: int in rows.size():
		var row: PlatformSpec = rows[index]
		assert_eq(row.kind, PlatformSpec.Kind.NORMAL, "intro row %d is a normal plank" % index)
		assert_true(is_equal_approx(row.rect.end.y, level.intro_step * (index + 1)), "intro row %d height" % index)
		var on_right: bool = row.rect.get_center().x > 0.0
		assert_eq(on_right, index % 2 == 0, "intro row %d side" % index)


func test_rows_climb_and_stay_inside_walls() -> void:
	var level: LevelConfig = _level()
	var previous_top: float = 0.0
	for row: PlatformSpec in _generate(7, ROWS):
		var step: float = row.rect.end.y - previous_top
		assert_true(step >= level.step_min_hard - 0.001, "row %d step too small: %f" % [row.index, step])
		assert_true(step <= level.step_max_hard + 0.001, "row %d step too large: %f" % [row.index, step])
		previous_top = row.rect.end.y
		var left: float = row.rect.position.x - row.move_amplitude
		var right: float = row.rect.end.x + row.move_amplitude
		assert_true(left >= -level.wall_x - 0.001 and right <= level.wall_x + 0.001, "row %d leaves the play area" % row.index)
		if row.pickup != null:
			assert_true(absf(row.pickup.position.x) < level.wall_x, "row %d pickup outside walls" % row.index)


func test_special_platforms_respect_start_heights() -> void:
	var level: LevelConfig = _level()
	var kinds: Dictionary[int, int] = {}
	for row: PlatformSpec in _generate(21, ROWS):
		kinds[row.kind] = kinds.get(row.kind, 0) + 1
		if row.kind == PlatformSpec.Kind.MOVING:
			assert_true(row.rect.end.y >= level.moving_start_height, "moving platform too early")
		if row.kind == PlatformSpec.Kind.TARGET:
			assert_true(row.rect.end.y >= level.target_start_height, "target platform too early")
	assert_true(kinds.get(PlatformSpec.Kind.MOVING, 0) > 0, "level contains moving platforms")
	assert_true(kinds.get(PlatformSpec.Kind.TARGET, 0) > 0, "level contains target platforms")


func test_difficulty_grows_with_height() -> void:
	var level: LevelConfig = _level()
	var early_total: float = 0.0
	var early_count: int = 0
	var late_total: float = 0.0
	var late_count: int = 0
	for row: PlatformSpec in _generate(5, ROWS):
		if row.kind != PlatformSpec.Kind.NORMAL or row.index < level.intro_rows:
			continue
		if row.rect.end.y < 60.0:
			early_total += row.rect.size.x
			early_count += 1
		elif row.rect.end.y > level.max_difficulty_height:
			late_total += row.rect.size.x
			late_count += 1
	assert_true(early_count > 0 and late_count > 0, "samples at both ends of the curve")
	assert_true(late_total / maxi(late_count, 1) < early_total / maxi(early_count, 1), "planks get shorter with height")
	assert_true(level.difficulty_at(0.0) == 0.0 and level.difficulty_at(1e6) == 1.0, "difficulty is clamped to 0..1")


func test_theme_sequence_and_cycle() -> void:
	var level: LevelConfig = _level()
	assert_eq(level.themes.size(), 2, "two themes in v1.0")
	assert_eq(level.theme_by_ordinal(level.theme_ordinal_at(0.0)).id, &"kitchen", "0 m is kitchen")
	assert_eq(level.theme_by_ordinal(level.theme_ordinal_at(99.0)).id, &"kitchen", "99 m is kitchen")
	assert_eq(level.theme_by_ordinal(level.theme_ordinal_at(100.0)).id, &"forest", "100 m is forest")
	assert_eq(level.theme_by_ordinal(level.theme_ordinal_at(249.0)).id, &"forest", "249 m is forest")
	assert_eq(level.theme_by_ordinal(level.theme_ordinal_at(250.0)).id, &"kitchen", "250 m cycles back to kitchen")
	assert_eq(level.theme_ordinal_at(250.0), 2, "ordinal keeps counting across cycles")
	assert_true(is_equal_approx(level.theme_start_height(3), 350.0), "second forest starts at 350 m")


func test_theme_colors_blend_near_boundary() -> void:
	var level: LevelConfig = _level()
	var kitchen: Color = level.themes[0].background_color
	var forest: Color = level.themes[1].background_color
	assert_true(level.blended_color(50.0, &"background_color").is_equal_approx(kitchen), "mid-theme color is pure")
	var blended: Color = level.blended_color(95.0, &"background_color")
	assert_true(not blended.is_equal_approx(kitchen) and not blended.is_equal_approx(forest), "color blends before the boundary")
	assert_true(level.blended_color(100.0, &"background_color").is_equal_approx(forest), "next theme color after the boundary")


func test_score_keeper() -> void:
	var score: ScoreKeeper = ScoreKeeper.new()
	assert_true(score.register_height(12.7), "new max height registers")
	assert_true(not score.register_height(8.0), "lower height is ignored")
	assert_true(not score.register_height(-3.0), "negative height is ignored")
	score.add_bonus(15)
	score.add_bonus(-5)
	score.add_coins(4)
	assert_eq(score.height, 12, "height is whole meters")
	assert_eq(score.total(), 27, "total is height plus bonus")
	assert_eq(score.coins, 4, "coins are tracked separately")


func test_save_service_round_trip() -> void:
	var save: Node = tree.root.get_node("SaveService")
	var original_path: String = save.get("save_path")
	save.set("save_path", "user://test_save.json")
	save.call("load_from_disk")
	save.call("set_value", "best_score", 42)
	assert_true(save.call("save_to_disk"), "save file is written")
	save.call("set_value", "best_score", 0)
	save.call("load_from_disk")
	assert_eq(save.call("get_int", "best_score"), 42, "value survives a save/load cycle")
	assert_eq(save.call("get_int", "missing", 7), 7, "missing key returns the fallback")
	for suffix: String in ["", ".bak"]:
		var path: String = ProjectSettings.globalize_path("user://test_save.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.set("save_path", original_path)
	save.call("load_from_disk")
