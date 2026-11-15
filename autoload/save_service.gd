extends Node
## Persistent player progress as versioned JSON under user://.
##
## File format: {"version": N, "hash": sha256(salt + payload), "payload": "<data as JSON text>"}.
## The hash catches corruption and casual tampering; when it does not match,
## the previous good save (backup) is used, otherwise progress starts fresh.

const SAVE_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://save.json"
const BACKUP_SUFFIX: String = ".bak"
## Version 1 files (pre-integrity prototype saves) carry no hash and are trusted.
const FIRST_HASHED_VERSION: int = 2
const HASH_SALT: String = "upsy-flip::save::7f3a91c2"

signal loaded
signal saved

## Overridable so tests never touch the real save file.
var save_path: String = DEFAULT_SAVE_PATH
## True when the last load found a damaged file and could not recover it.
var was_reset: bool = false

var _data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


func _notification(what: int) -> void:
	# Persist whenever the app goes to the background or is closed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_to_disk()


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _data.get(key, fallback)


## JSON stores every number as a float, so integers are read through this.
func get_int(key: String, fallback: int = 0) -> int:
	return int(_data.get(key, fallback))


func get_bool(key: String, fallback: bool = false) -> bool:
	return bool(_data.get(key, fallback))


func get_dict(key: String) -> Dictionary:
	var value: Variant = _data.get(key)
	return value if value is Dictionary else {}


func set_value(key: String, value: Variant) -> void:
	_data[key] = value


func save_to_disk() -> bool:
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + BACKUP_SUFFIX)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: cannot write %s" % save_path)
		return false
	file.store_string(encode_save(_data))
	file.close()
	saved.emit()
	return true


func load_from_disk() -> void:
	was_reset = false
	_data = {}
	var had_file: bool = false
	for path: String in [save_path, save_path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(path):
			continue
		had_file = true
		var parsed: Variant = parse_save(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_data = parsed
			loaded.emit()
			return
	was_reset = had_file
	loaded.emit()


## Serializes `data` into the save file text. The data is stored as a JSON
## string ("payload") so the hash covers the exact bytes that are read back.
static func encode_save(data: Dictionary) -> String:
	var payload: String = JSON.stringify(data)
	return JSON.stringify({
		"version": SAVE_VERSION,
		"hash": compute_hash(payload),
		"payload": payload,
	})


## Returns the data dictionary of a valid save file, or null if it is damaged.
static func parse_save(text: String) -> Variant:
	var root: Variant = _parse_json(text)
	if not root is Dictionary:
		return null
	var version: int = int((root as Dictionary).get("version", 1))
	var data: Variant = (root as Dictionary).get("data")
	if version >= FIRST_HASHED_VERSION:
		var payload: String = str((root as Dictionary).get("payload", ""))
		if str((root as Dictionary).get("hash", "")) != compute_hash(payload):
			return null
		data = _parse_json(payload)
	if not data is Dictionary:
		return null
	return _migrate(version, data)


static func compute_hash(payload: String) -> String:
	return (HASH_SALT + payload).sha256_text()


## JSON parse that returns null on malformed input without logging an error.
static func _parse_json(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## Upgrades data written by an older game version to the current layout.
static func _migrate(_from_version: int, data: Dictionary) -> Dictionary:
	# v1 -> v2 only added the integrity hash; the data layout is unchanged.
	return data
