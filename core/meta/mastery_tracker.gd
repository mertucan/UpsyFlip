class_name MasteryTracker
extends RefCounted
## Per-skin mastery: playing a skin earns XP and levels it up. Pure logic.
## Levels are 1-based; thresholds[i] is the total XP needed for level i + 1.

var xp: Dictionary[StringName, int] = {}


static func level_for(total_xp: int, thresholds: PackedInt32Array) -> int:
	var level: int = 1
	for index: int in thresholds.size():
		if total_xp >= thresholds[index]:
			level = index + 1
	return level


func xp_of(skin_id: StringName) -> int:
	return xp.get(skin_id, 0)


func level_of(skin_id: StringName, thresholds: PackedInt32Array) -> int:
	return level_for(xp_of(skin_id), thresholds)


## Progress toward the next level, 0..1 (1 at max level).
func fraction_to_next(skin_id: StringName, thresholds: PackedInt32Array) -> float:
	var level: int = level_of(skin_id, thresholds)
	if level >= thresholds.size():
		return 1.0
	var floor_xp: int = thresholds[level - 1]
	var span: int = thresholds[level] - floor_xp
	return clampf(float(xp_of(skin_id) - floor_xp) / float(maxi(span, 1)), 0.0, 1.0)


## Adds XP and returns the new level if the skin levelled up, otherwise 0.
func add_xp(skin_id: StringName, amount: int, thresholds: PackedInt32Array) -> int:
	var before: int = level_of(skin_id, thresholds)
	xp[skin_id] = xp_of(skin_id) + maxi(amount, 0)
	var after: int = level_of(skin_id, thresholds)
	return after if after > before else 0


func to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for skin_id: StringName in xp:
		saved[String(skin_id)] = xp[skin_id]
	return saved


func from_dict(data: Dictionary) -> void:
	xp.clear()
	for key: Variant in data:
		xp[StringName(str(key))] = int(data[key])
