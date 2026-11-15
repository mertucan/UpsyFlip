class_name MissionBoard
extends RefCounted
## Daily missions: a deterministic pick from the pool each day, progress
## tracking and one-time completion. Pure logic.

var day: int = -1
var active_ids: Array[StringName] = []
var progress: Dictionary[StringName, int] = {}
var completed: Array[StringName] = []


## Picks today's missions if the day changed. Skin-specific missions are only
## offered for owned skins, and no two missions share a type. Returns true
## when a new set was rolled.
func roll_if_needed(today: int, pool: Array[MissionData], owned_skins: Array[StringName], count: int) -> bool:
	if today == day and not active_ids.is_empty():
		return false
	day = today
	active_ids.clear()
	progress.clear()
	completed.clear()

	var candidates: Array[MissionData] = []
	for mission: MissionData in pool:
		if mission.type != MissionData.Type.RUNS_WITH_SKIN or owned_skins.has(mission.skin_id):
			candidates.append(mission)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = today * 7919 + 13
	for index: int in range(candidates.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: MissionData = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap

	var used_types: Array[int] = []
	for mission: MissionData in candidates:
		if active_ids.size() >= count:
			break
		if used_types.has(mission.type):
			continue
		used_types.append(mission.type)
		active_ids.append(mission.id)
	return true


func active_missions(pool: Array[MissionData]) -> Array[MissionData]:
	var result: Array[MissionData] = []
	for mission: MissionData in pool:
		if active_ids.has(mission.id):
			result.append(mission)
	return result


func progress_of(mission: MissionData) -> int:
	return mini(progress.get(mission.id, 0), mission.target)


func is_completed(mission: MissionData) -> bool:
	return completed.has(mission.id)


## Applies a finished run and returns the missions it completed.
func apply_run(summary: RunSummary, pool: Array[MissionData]) -> Array[MissionData]:
	var newly_completed: Array[MissionData] = []
	for mission: MissionData in active_missions(pool):
		if is_completed(mission):
			continue
		var current: int = progress.get(mission.id, 0)
		match mission.type:
			MissionData.Type.PERFECTS:
				current += summary.perfects
			MissionData.Type.STICKS:
				current += summary.sticks
			MissionData.Type.RUNS:
				if not summary.is_continuation:
					current += 1
			MissionData.Type.RUNS_WITH_SKIN:
				if summary.skin_id == mission.skin_id and not summary.is_continuation:
					current += 1
			MissionData.Type.COINS:
				current += summary.coins
			MissionData.Type.HEIGHT_SINGLE:
				current = maxi(current, summary.height)
			MissionData.Type.HEIGHT_TOTAL:
				current += summary.height_gain
		progress[mission.id] = current
		if current >= mission.target:
			completed.append(mission.id)
			newly_completed.append(mission)
	return newly_completed


func to_dict() -> Dictionary:
	var saved_progress: Dictionary = {}
	for mission_id: StringName in progress:
		saved_progress[String(mission_id)] = progress[mission_id]
	return {
		"day": day,
		"active": _to_strings(active_ids),
		"progress": saved_progress,
		"completed": _to_strings(completed),
	}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", -1))
	active_ids = _to_names(data.get("active"))
	completed = _to_names(data.get("completed"))
	progress.clear()
	var saved_progress: Variant = data.get("progress")
	if saved_progress is Dictionary:
		for key: Variant in saved_progress:
			progress[StringName(str(key))] = int(saved_progress[key])


static func _to_strings(names: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for item: StringName in names:
		result.append(String(item))
	return result


static func _to_names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for item: Variant in values:
			result.append(StringName(str(item)))
	return result
