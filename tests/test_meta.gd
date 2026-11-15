extends "res://tests/test_case.gd"

const TEST_SAVE_PATH: String = "user://test_meta_save.json"


func _config() -> MetaConfig:
	return load("res://data/meta_config.tres") as MetaConfig


func _catalog() -> SkinCatalog:
	return load("res://skins/skin_catalog.tres") as SkinCatalog


func _summary(skin_id: StringName, height: int, perfects: int, sticks: int, coins: int) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary.skin_id = skin_id
	summary.height = height
	summary.height_gain = height
	summary.score = height
	summary.perfects = perfects
	summary.sticks = sticks
	summary.coins = coins
	return summary


func _mission(id: StringName, type: MissionData.Type, target: int, skin_id: StringName = &"") -> MissionData:
	var mission: MissionData = MissionData.new()
	mission.id = id
	mission.type = type
	mission.target = target
	mission.skin_id = skin_id
	return mission


## Points the autoloads at an empty throwaway save file.
func _use_test_save() -> String:
	var save: Node = tree.root.get_node("SaveService")
	var original_path: String = save.get("save_path")
	_delete_test_save()
	save.set("save_path", TEST_SAVE_PATH)
	save.call("load_from_disk")
	tree.root.get_node("Economy").call("reload")
	tree.root.get_node("PlayerProgress").call("reload")
	return original_path


func _restore_save(original_path: String) -> void:
	var save: Node = tree.root.get_node("SaveService")
	_delete_test_save()
	save.set("save_path", original_path)
	save.call("load_from_disk")
	tree.root.get_node("Economy").call("reload")
	tree.root.get_node("PlayerProgress").call("reload")


func _delete_test_save() -> void:
	for suffix: String in ["", ".bak"]:
		var path: String = ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- Save integrity ---------------------------------------------------------

func test_save_hash_detects_tampering() -> void:
	var save_script: GDScript = load("res://autoload/save_service.gd") as GDScript
	var text: String = save_script.call("encode_save", {"coins": 120, "best_score": 44})
	var parsed: Variant = save_script.call("parse_save", text)
	assert_true(parsed is Dictionary and int((parsed as Dictionary)["coins"]) == 120, "untouched save loads")
	var tampered: String = text.replace("120", "999999")
	assert_true(save_script.call("parse_save", tampered) == null, "edited save is rejected")
	assert_true(save_script.call("parse_save", "{not json") == null, "garbage is rejected")


func test_legacy_v1_save_is_accepted() -> void:
	var save_script: GDScript = load("res://autoload/save_service.gd") as GDScript
	var parsed: Variant = save_script.call("parse_save", '{"version":1,"data":{"best_score":13}}')
	assert_true(parsed is Dictionary and int((parsed as Dictionary)["best_score"]) == 13, "pre-hash prototype saves still load")


func test_corrupt_save_falls_back_to_backup() -> void:
	var original_path: String = _use_test_save()
	var save: Node = tree.root.get_node("SaveService")
	save.call("set_value", "coins", 50)
	save.call("save_to_disk")
	save.call("set_value", "coins", 75)
	save.call("save_to_disk")
	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("corrupted")
	file.close()
	save.call("load_from_disk")
	assert_eq(save.call("get_int", "coins"), 50, "backup holds the previous good save")
	assert_true(not save.get("was_reset"), "recovered, not reset")
	_restore_save(original_path)


# --- Economy ----------------------------------------------------------------

func test_economy_spend_rules() -> void:
	var original_path: String = _use_test_save()
	var economy: Node = tree.root.get_node("Economy")
	assert_eq(economy.get("coins"), 0, "fresh save starts with no coins")
	economy.call("add_coins", 100)
	economy.call("add_coins", -50)
	assert_eq(economy.get("coins"), 100, "negative amounts are ignored")
	assert_true(not economy.call("spend_coins", 101), "cannot overspend")
	assert_true(economy.call("spend_coins", 60), "can spend within balance")
	assert_eq(economy.get("coins"), 40, "balance after spending")
	assert_true(not economy.call("spend_gems", 1), "no gems to spend")
	economy.call("reload")
	assert_eq(economy.get("coins"), 40, "balance survives a reload")
	_restore_save(original_path)


# --- Skin inventory ---------------------------------------------------------

func test_inventory_purchase_rules() -> void:
	var catalog: SkinCatalog = _catalog()
	var inventory: SkinInventory = SkinInventory.new()
	inventory.ensure_valid(catalog.skins[0].id)
	assert_true(inventory.owns(&"knife") and inventory.selected == &"knife", "starter skin owned and selected")
	var axe: SkinData = catalog.find(&"axe")
	assert_true(not inventory.can_buy(axe, false, axe.price_coins - 1), "too few coins")
	assert_true(inventory.can_buy(axe, false, axe.price_coins), "exact coins is enough")
	assert_true(not inventory.can_buy(axe, true, 9999), "axe is not sold for gems")
	assert_true(not inventory.select(&"axe"), "cannot select a locked skin")
	inventory.add(&"axe")
	assert_true(not inventory.can_buy(axe, false, 9999), "cannot buy twice")
	assert_true(inventory.select(&"axe"), "owned skin can be selected")
	assert_eq(inventory.next_coin_goal(catalog.skins).id, &"shuriken", "next goal is the cheapest locked skin")

	var restored: SkinInventory = SkinInventory.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(inventory.to_dict())))
	assert_true(restored.owns(&"axe") and restored.selected == &"axe", "inventory survives a JSON round trip")


func test_buying_a_skin_spends_coins_and_selects_it() -> void:
	var original_path: String = _use_test_save()
	var economy: Node = tree.root.get_node("Economy")
	var progress: Node = tree.root.get_node("PlayerProgress")
	var axe: SkinData = _catalog().find(&"axe")
	assert_true(not progress.call("buy_skin", axe, false), "cannot buy without coins")
	economy.call("add_coins", axe.price_coins + 10)
	assert_true(progress.call("buy_skin", axe, false), "purchase succeeds with enough coins")
	assert_eq(economy.get("coins"), 10, "price is deducted")
	assert_eq((progress.call("selected_skin") as SkinData).id, &"axe", "bought skin is selected")
	progress.call("reload")
	assert_eq((progress.call("selected_skin") as SkinData).id, &"axe", "purchase is persisted")
	_restore_save(original_path)


# --- Daily streak -----------------------------------------------------------

func test_daily_streak_cycle() -> void:
	var streak: DailyStreak = DailyStreak.new()
	assert_true(streak.can_claim(100), "first day is claimable")
	assert_eq(streak.claim(100, 7), 0, "first claim gives day 1")
	assert_eq(streak.claim(100, 7), -1, "only one claim per day")
	assert_eq(streak.claim(101, 7), 1, "consecutive day advances")
	assert_eq(streak.claim(103, 7), 0, "a missed day restarts the cycle")
	for day: int in range(104, 110):
		streak.claim(day, 7)
	assert_eq(streak.day_index, 6, "seven consecutive days reach the last slot")
	assert_eq(streak.claim(110, 7), 0, "the cycle wraps around")


func test_daily_rewards_include_gems_on_last_day() -> void:
	var config: MetaConfig = _config()
	assert_eq(config.daily_coins.size(), 7, "seven-day cycle")
	assert_eq(config.daily_gems.size(), 7, "gem table matches the cycle")
	assert_true(config.daily_gems[6] > 0, "day 7 pays gems")
	for index: int in range(1, 6):
		assert_true(config.daily_coins[index] > config.daily_coins[index - 1], "coin reward grows on day %d" % (index + 1))


# --- Missions ---------------------------------------------------------------

func test_mission_roll_is_deterministic_and_respects_ownership() -> void:
	var config: MetaConfig = _config()
	var owned: Array[StringName] = [&"knife"]
	var first: MissionBoard = MissionBoard.new()
	var second: MissionBoard = MissionBoard.new()
	for day: int in range(20000, 20030):
		first.day = -1
		first.active_ids.clear()
		second.day = -1
		second.active_ids.clear()
		first.roll_if_needed(day, config.mission_pool, owned, config.missions_per_day)
		second.roll_if_needed(day, config.mission_pool, owned, config.missions_per_day)
		assert_eq(first.active_ids, second.active_ids, "same day gives the same missions")
		assert_eq(first.active_ids.size(), config.missions_per_day, "three missions on day %d" % day)
		var types: Array[int] = []
		for mission: MissionData in first.active_missions(config.mission_pool):
			assert_true(mission.type != MissionData.Type.RUNS_WITH_SKIN, "no missions for locked skins")
			assert_true(not types.has(mission.type), "no duplicate mission types")
			types.append(mission.type)


func test_mission_progress_and_completion() -> void:
	var pool: Array[MissionData] = [
		_mission(&"perfects", MissionData.Type.PERFECTS, 5),
		_mission(&"height", MissionData.Type.HEIGHT_SINGLE, 50),
		_mission(&"axe", MissionData.Type.RUNS_WITH_SKIN, 2, &"axe"),
	]
	var board: MissionBoard = MissionBoard.new()
	board.roll_if_needed(1, pool, [&"knife", &"axe"] as Array[StringName], 3)
	assert_eq(board.active_ids.size(), 3, "all three missions active")

	assert_eq(board.apply_run(_summary(&"knife", 30, 3, 10, 2), pool).size(), 0, "nothing completed yet")
	assert_eq(board.progress_of(pool[0]), 3, "perfects accumulate")
	assert_eq(board.progress_of(pool[1]), 30, "single-run height keeps the best run")
	assert_eq(board.progress_of(pool[2]), 0, "wrong skin does not count")

	var completed: Array[MissionData] = board.apply_run(_summary(&"axe", 20, 2, 5, 0), pool)
	assert_eq(completed.size(), 1, "perfects mission completes")
	assert_eq(board.progress_of(pool[1]), 30, "a lower run does not reduce single-run height")
	completed = board.apply_run(_summary(&"axe", 55, 9, 9, 0), pool)
	assert_eq(completed.size(), 2, "height and axe missions complete")
	assert_eq(board.apply_run(_summary(&"axe", 99, 9, 9, 0), pool).size(), 0, "missions pay only once")

	var restored: MissionBoard = MissionBoard.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(board.to_dict())))
	assert_true(restored.is_completed(pool[0]) and restored.day == 1, "board survives a JSON round trip")
	assert_true(not restored.roll_if_needed(1, pool, [&"knife"] as Array[StringName], 3), "same day does not re-roll")
	assert_true(restored.roll_if_needed(2, pool, [&"knife"] as Array[StringName], 3), "a new day rolls new missions")
	assert_eq(restored.completed.size(), 0, "new day clears progress")


# --- Mastery ----------------------------------------------------------------

func test_mastery_levels() -> void:
	var thresholds: PackedInt32Array = [0, 100, 300]
	var mastery: MasteryTracker = MasteryTracker.new()
	assert_eq(mastery.level_of(&"knife", thresholds), 1, "new skin is level 1")
	assert_eq(mastery.add_xp(&"knife", 60, thresholds), 0, "no level up yet")
	assert_true(is_equal_approx(mastery.fraction_to_next(&"knife", thresholds), 0.6), "progress toward level 2")
	assert_eq(mastery.add_xp(&"knife", 50, thresholds), 2, "level up is reported")
	assert_eq(mastery.add_xp(&"knife", 1000, thresholds), 3, "can skip to the top level")
	assert_true(is_equal_approx(mastery.fraction_to_next(&"knife", thresholds), 1.0), "max level shows a full bar")
	assert_eq(mastery.level_of(&"axe", thresholds), 1, "skins level independently")


# --- Whole run --------------------------------------------------------------

func test_record_run_banks_coins_and_mastery() -> void:
	var original_path: String = _use_test_save()
	var economy: Node = tree.root.get_node("Economy")
	var progress: Node = tree.root.get_node("PlayerProgress")
	var rewards: RunRewards = progress.call("record_run", _summary(&"knife", 300, 0, 0, 7))
	assert_eq(rewards.run_coins, 7, "run coins reported")
	assert_eq(economy.get("coins"), 7 + rewards.mission_coins, "coins and mission rewards are banked")
	assert_true(rewards.mastery_level_up >= 2, "a long run levels the skin up")
	progress.call("reload")
	economy.call("reload")
	assert_eq(economy.get("coins"), 7 + rewards.mission_coins, "banked coins are persisted")
	_restore_save(original_path)
