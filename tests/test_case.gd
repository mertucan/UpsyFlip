extends RefCounted
## Base class for headless tests. Subclasses live in res://tests/test_*.gd
## and define methods whose names start with "test_".

var tree: SceneTree
var failures: PackedStringArray = PackedStringArray()


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
