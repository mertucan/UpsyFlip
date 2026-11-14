extends Node
## Headless test runner. Usage:
##   godot --headless --path . res://tests/test_runner.tscn
## Exit code is 0 when all tests pass, 1 otherwise.

const TestCase := preload("res://tests/test_case.gd")
const TEST_DIR: String = "res://tests/"


func _ready() -> void:
	var total: int = 0
	var failed: int = 0
	for file_name: String in _find_test_files():
		var script: GDScript = load(TEST_DIR + file_name) as GDScript
		if script == null:
			failed += 1
			print("FAIL  %s: could not load script" % file_name)
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new() as TestCase
			case.tree = get_tree()
			case.call(method_name)
			total += 1
			if case.failures.is_empty():
				print("PASS  %s::%s" % [file_name, method_name])
			else:
				failed += 1
				for failure: String in case.failures:
					print("FAIL  %s::%s: %s" % [file_name, method_name, failure])
	print("TESTS: %d run, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 or total == 0 else 0)


func _find_test_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") \
				and file_name != "test_case.gd" and file_name != "test_runner.gd":
			result.append(file_name)
	result.sort()
	return result
