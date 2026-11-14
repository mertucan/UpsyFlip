class_name ThemeData
extends Resource
## Visual theme for a height band of the climb. Adding a theme means adding
## a new ThemeData file to LevelConfig.themes; no code changes.

@export var id: StringName = &""
@export var display_name: String = ""
## How many meters of climb this theme covers before the next one starts.
@export var length_m: float = 100.0

@export_group("Colors")
@export var background_color: Color = Color(0.13, 0.16, 0.27)
@export var wall_color: Color = Color(0.22, 0.26, 0.4)
@export var stripe_color: Color = Color(0.18, 0.21, 0.33)
@export var platform_color: Color = Color(0.78, 0.56, 0.34)
@export var platform_underside_color: Color = Color(0.36, 0.38, 0.46)
@export var moving_platform_color: Color = Color(0.55, 0.75, 0.85)
@export var target_color: Color = Color(0.9, 0.25, 0.25)

@export_group("Background")
## Vertical spacing of the horizontal background stripes, in meters.
@export var stripe_spacing: float = 2.5
