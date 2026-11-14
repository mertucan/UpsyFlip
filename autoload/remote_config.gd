extends Node
## Remote-tunable values with local defaults. Skeleton; backend arrives in Phase 6.

var _defaults: Dictionary = {}


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _defaults.get(key, fallback)
