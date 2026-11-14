class_name FeelConfig
extends Resource
## Every tunable "feel" value lives here so the game can be tuned without
## touching code. Units: meters, seconds, degrees.
## Launch/spin/stick values move into per-skin SkinData in Phase 4.

@export_group("Simulation")
@export var sim_step: float = 1.0 / 120.0
@export var gravity: float = 22.0

@export_group("Launch")
@export var launch_speed_x: float = 5.0
@export var launch_speed_y: float = 11.0
@export var spin_speed_deg: float = 495.0
## Extra launches allowed while airborne (0 = only from a stuck state).
@export var max_air_launches: int = 1

@export_group("Hold to charge")
@export var hold_to_charge: bool = false
@export var charge_time: float = 0.7
@export var charge_min_scale: float = 0.75
@export var charge_max_scale: float = 1.25

@export_group("Stick")
@export var stick_half_angle_deg: float = 35.0
@export var perfect_half_angle_deg: float = 10.0
## How deep the tip sinks into the surface.
@export var stick_depth: float = 0.18
## 0 = keep the impact angle, 1 = snap fully perpendicular to the surface.
@export_range(0.0, 1.0) var stick_settle: float = 0.5

@export_group("Bounce")
@export var bounce_restitution: float = 0.35
@export var bounce_spin_factor: float = 0.5
@export var bounce_pop_speed: float = 1.5
## An object that bounces on a top face more than this many times in one
## flight, or too slowly to pop back up, comes to rest there and the run ends.
@export var max_bounces: int = 3
## Height of the resting object's pivot above the surface it lies on.
@export var rest_height: float = 0.1

@export_group("Object shape")
## Distance from the pivot to the tip / to the handle end.
@export var tip_offset: float = 0.6
@export var tail_offset: float = 0.5
@export var body_sample_count: int = 6

@export_group("Camera")
@export var camera_half_width: float = 3.7
@export var camera_fov_deg: float = 30.0
@export var camera_follow_speed: float = 6.0
## How far below screen center the object rests, as a fraction of half the view height.
@export_range(0.0, 0.9) var camera_anchor: float = 0.35
## While flying, the camera trails this many meters behind the object.
@export var camera_flight_slack: float = 1.5
## Distance below the bottom screen edge at which the run ends.
@export var death_margin: float = 0.8

@export_group("Flow")
@export var restart_delay: float = 0.25

@export_group("Haptics")
@export var stick_vibrate_ms: int = 20
@export var perfect_vibrate_ms: int = 40
@export var bounce_vibrate_ms: int = 12
