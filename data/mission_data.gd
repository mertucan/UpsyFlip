class_name MissionData
extends Resource
## One daily mission. Adding a mission means adding a MissionData file to
## MetaConfig.mission_pool.

enum Type {
	## Total PERFECT sticks.
	PERFECTS,
	## Total sticks of any quality.
	STICKS,
	## Runs played.
	RUNS,
	## Runs played with `skin_id`.
	RUNS_WITH_SKIN,
	## Coins collected in runs.
	COINS,
	## Height reached in a single run.
	HEIGHT_SINGLE,
	## Height summed over all runs.
	HEIGHT_TOTAL,
}

@export var id: StringName = &""
@export var type: Type = Type.RUNS
@export var target: int = 1
@export var reward_coins: int = 30
## Only for RUNS_WITH_SKIN.
@export var skin_id: StringName = &""
## English text with one %d for the target.
@export var description: String = ""


func text() -> String:
	var translated: String = tr(description)
	return translated % target if translated.contains("%d") else translated
