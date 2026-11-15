class_name FeelConfig
extends Resource
## Every tunable "feel" value lives here so the game can be tuned without
## touching code. Units: meters, seconds, degrees.
## Per-object values (launch, spin, stick angles, shape) live in SkinData.

@export_group("Simulation")
@export var sim_step: float = 1.0 / 120.0
@export var gravity: float = 22.0

@export_group("Hold to charge")
@export var hold_to_charge: bool = false
@export var charge_time: float = 0.7
@export var charge_min_scale: float = 0.75
@export var charge_max_scale: float = 1.25

@export_group("Stick")
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

@export_group("Combo and fever")
## Bonus points per PERFECT, multiplied by the current streak.
@export var perfect_points: int = 2
@export var combo_max_multiplier: int = 5
@export var fever_perfects_needed: int = 5
@export var fever_duration: float = 6.0
@export var fever_coin_multiplier: int = 2

@export_group("Clutch")
## A stick this close (meters) above the bottom screen edge while coming down is a CLUTCH.
@export var clutch_zone: float = 2.5
@export var clutch_points: int = 10

@export_group("Slow motion")
@export var clutch_slowmo_scale: float = 0.25
@export var clutch_slowmo_time: float = 0.6
@export var fever_slowmo_scale: float = 0.4
@export var fever_slowmo_time: float = 0.35
## Brief slow motion on each PERFECT while FEVER is active.
@export var fever_perfect_slowmo_time: float = 0.15
## How quickly time returns to normal speed.
@export var slowmo_recover_speed: float = 14.0

@export_group("Screen shake")
@export var shake_max_offset: float = 0.22
@export var shake_decay: float = 2.6
@export_range(0.0, 1.0) var shake_stick: float = 0.3
@export_range(0.0, 1.0) var shake_perfect: float = 0.5
@export_range(0.0, 1.0) var shake_bounce: float = 0.35
@export_range(0.0, 1.0) var shake_clutch: float = 0.8
@export_range(0.0, 1.0) var shake_death: float = 0.7

@export_group("Stick wobble")
@export var wobble_angle_deg: float = 9.0
@export var wobble_frequency: float = 30.0
@export var wobble_damping: float = 9.0

@export_group("Haptic patterns")
## Alternating vibrate/pause durations in milliseconds, starting with vibrate.
@export var clutch_haptic_pattern: PackedInt32Array = [40, 40, 90]
@export var fever_haptic_pattern: PackedInt32Array = [30, 30, 30, 30, 100]
@export var death_vibrate_ms: int = 70