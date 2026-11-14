class_name LevelConfig
extends Resource
## World layout, difficulty curve and theme sequence for the endless climb.
## "easy" values apply at height 0, "hard" values at max_difficulty_height.

@export_group("Themes")
@export var themes: Array[ThemeData] = []
## Colors blend into the next theme over the last meters of a theme.
@export var theme_transition_m: float = 10.0

@export_group("Layout")
@export var wall_x: float = 3.2
@export var wall_thickness: float = 4.0
@export var plank_thickness: float = 0.4
@export var start_x: float = -1.9

@export_group("Intro")
## The first rows are always the same easy zigzag.
@export var intro_rows: int = 4
@export var intro_step: float = 2.0
@export var intro_length: float = 2.3

@export_group("Difficulty curve")
@export var max_difficulty_height: float = 400.0
@export var step_min_easy: float = 1.7
@export var step_max_easy: float = 2.2
@export var step_min_hard: float = 1.5
@export var step_max_hard: float = 3.0
@export var length_min_easy: float = 2.0
@export var length_max_easy: float = 2.4
@export var length_min_hard: float = 1.1
@export var length_max_hard: float = 1.7
@export var same_side_chance_easy: float = 0.08
@export var same_side_chance_hard: float = 0.3
@export var same_side_min_step: float = 2.3

@export_group("Moving platforms")
@export var moving_start_height: float = 20.0
@export var moving_chance_easy: float = 0.1
@export var moving_chance_hard: float = 0.35
@export var moving_length: float = 1.8
@export var moving_amplitude_easy: float = 0.6
@export var moving_amplitude_hard: float = 1.3
## Radians per second of the sine motion.
@export var moving_speed_easy: float = 1.2
@export var moving_speed_hard: float = 2.2

@export_group("Target platforms")
@export var target_start_height: float = 8.0
@export var target_chance_easy: float = 0.12
@export var target_chance_hard: float = 0.18
@export var target_length: float = 0.9
@export var target_bonus_points: int = 5
@export var target_center_bonus_points: int = 10
## Half-width of the bullseye zone in the middle of a target.
@export var target_center_zone: float = 0.15

@export_group("Pickups")
@export var pickup_chance: float = 0.35
@export var watermelon_share: float = 0.3
@export var balloon_coins: int = 1
@export var balloon_radius: float = 0.35
@export var watermelon_coins: int = 3
@export var watermelon_radius: float = 0.42


func difficulty_at(height: float) -> float:
	return clampf(height / max_difficulty_height, 0.0, 1.0)


func floor_rect() -> Rect2:
	return Rect2(-wall_x, -1.0, wall_x * 2.0, 1.0)


func wall_rect(side: int) -> Rect2:
	var left: float = wall_x if side > 0 else -wall_x - wall_thickness
	return Rect2(left, -1000.0, wall_thickness, 1000000.0)


# --- Themes -----------------------------------------------------------------

func cycle_length() -> float:
	var total: float = 0.0
	for theme: ThemeData in themes:
		total += theme.length_m
	return total


## Number of theme boundaries passed at `height`; keeps counting across cycles.
func theme_ordinal_at(height: float) -> int:
	var cycle: float = cycle_length()
	if themes.is_empty() or cycle <= 0.0:
		return 0
	var clamped: float = maxf(height, 0.0)
	var cycles: int = floori(clamped / cycle)
	var local: float = clamped - cycles * cycle
	var index: int = 0
	while index < themes.size() - 1 and local >= themes[index].length_m:
		local -= themes[index].length_m
		index += 1
	return cycles * themes.size() + index


func theme_by_ordinal(ordinal: int) -> ThemeData:
	return themes[posmod(ordinal, themes.size())]


func theme_start_height(ordinal: int) -> float:
	var cycles: int = floori(float(ordinal) / themes.size())
	var height: float = cycles * cycle_length()
	for index: int in posmod(ordinal, themes.size()):
		height += themes[index].length_m
	return height


## A ThemeData color property at `height`, blended toward the next theme near
## the end of the current one.
func blended_color(height: float, property: StringName) -> Color:
	var ordinal: int = theme_ordinal_at(height)
	var current: Color = theme_by_ordinal(ordinal).get(property)
	var blend_start: float = theme_start_height(ordinal + 1) - theme_transition_m
	var weight: float = clampf((height - blend_start) / theme_transition_m, 0.0, 1.0)
	if weight <= 0.0:
		return current
	var next: Color = theme_by_ordinal(ordinal + 1).get(property)
	return current.lerp(next, smoothstep(0.0, 1.0, weight))
