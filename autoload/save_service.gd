extends Node
## Persistent player progress as versioned JSON under user://.
## Integrity check and migrations are added in Phase 5.

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save.json"

signal loaded
signal saved

## Overridable so tests never touch the real save file.
var save_path: String = DEFAULT_SAVE_PATH

var _data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _data.get(key, fallback)


## JSON stores every number as a float, so integers are read through this.
func get_int(key: String, fallback: int = 0) -> int:
	return int(_data.get(key, fallback))


func set_value(key: String, value: Variant) -> void:
	_data[key] = value


func save_to_disk() -> bool:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: cannot write %s" % save_path)
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "data": _data}))
	file.close()
	saved.emit()
	return true


func load_from_disk() -> void:
	_data = {}
	if FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary and (parsed as Dictionary).get("data") is Dictionary:
			_data = (parsed as Dictionary)["data"]
	loaded.emit()
