extends "res://tests/test_case.gd"

const AUTOLOADS: PackedStringArray = [
	"GameState", "SaveService", "Economy", "AdsService", "BillingService",
	"Analytics", "RemoteConfig", "AudioService", "Haptics",
]


func test_autoloads_are_registered() -> void:
	for autoload_name: String in AUTOLOADS:
		assert_true(tree.root.has_node(autoload_name), "missing autoload: " + autoload_name)


func test_portrait_viewport() -> void:
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_true(height > width, "viewport must be portrait")
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "orientation must be portrait")


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(path), "main scene missing: " + path)
	var scene: PackedScene = load(path) as PackedScene
	assert_true(scene != null and scene.can_instantiate(), "main scene must instantiate")


func test_game_state_run_cycle() -> void:
	var game_state: Node = tree.root.get_node("GameState")
	game_state.call("start_run")
	assert_true(game_state.get("is_run_active"), "run should be active after start_run")
	game_state.call("end_run")
	assert_true(not game_state.get("is_run_active"), "run should be inactive after end_run")
