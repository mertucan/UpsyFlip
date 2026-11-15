extends Node
## Analytics facade. Events are kept in a small in-memory log (the mock) and
## forwarded to a real backend (Firebase Analytics) when one is attached.

const MAX_RECENT: int = 100

## Most recent events, oldest first: {"name": String, "params": Dictionary}.
var recent_events: Array[Dictionary] = []

## Object with a log_event(name: String, params: Dictionary) method, or null.
var _backend: Object = null


func set_backend(backend: Object) -> void:
	_backend = backend


func log_event(event_name: String, params: Dictionary = {}) -> void:
	recent_events.append({"name": event_name, "params": params})
	if recent_events.size() > MAX_RECENT:
		recent_events.pop_front()
	if _backend != null:
		_backend.call("log_event", event_name, params)


func count(event_name: String) -> int:
	var total: int = 0
	for event: Dictionary in recent_events:
		if event["name"] == event_name:
			total += 1
	return total
