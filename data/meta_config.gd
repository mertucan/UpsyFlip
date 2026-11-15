class_name MetaConfig
extends Resource
## Tunable values for the meta game: daily rewards, missions and mastery.

@export_group("Daily login streak")
## One entry per day of the cycle.
@export var daily_coins: PackedInt32Array = [20, 30, 40, 50, 60, 80, 100]
@export var daily_gems: PackedInt32Array = [0, 0, 0, 0, 0, 0, 5]

@export_group("Daily missions")
@export var missions_per_day: int = 3
@export var mission_pool: Array[MissionData] = []

@export_group("Skin mastery")
## Total XP needed for each level; index 0 is level 1.
@export var mastery_thresholds: PackedInt32Array = [0, 150, 500, 1200, 2500]
## XP per run, on top of 1 XP per meter climbed.
@export var mastery_xp_per_run: int = 10
## Trail color unlocked at each mastery level.
@export var mastery_trail_colors: PackedColorArray = [
	Color(0.93, 0.95, 0.98), Color(0.45, 0.85, 1.0), Color(0.55, 1.0, 0.55),
	Color(1.0, 0.6, 0.9), Color(1.0, 0.86, 0.3),
]


func cycle_length() -> int:
	return daily_coins.size()
