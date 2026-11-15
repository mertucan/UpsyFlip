class_name SkinData
extends Resource
## A throwable object: look, flight parameters, stick rule and special ability.
## Adding a skin means adding a SkinData file to the SkinCatalog; no code changes.
## Defaults describe the Knife. Local +X is "forward".

enum Ability {
	NONE,
	## After a miss, flies back once to where it was last stuck.
	RETURN_ONCE,
	## Airborne taps fire a shot; recoil pushes the object away from its barrel.
	RECOIL_SHOT,
}

@export var id: StringName = &"knife"
@export var display_name: String = "KNIFE"

@export_group("Shop")
## 0 means the skin cannot be bought with that currency. Both 0 = owned from the start.
@export var price_coins: int = 0
@export var price_gems: int = 0
## Exclusive skins are never sold for currency (e.g. the starter pack skin).
@export var exclusive: bool = false

@export_group("Look")
## Procedural model built by SkinModels.
@export var model_id: StringName = &"knife"
## Optional authored model (e.g. a .glb scene) that replaces the procedural one.
@export var model_scene: PackedScene
@export var primary_color: Color = Color(0.93, 0.95, 0.98)
@export var secondary_color: Color = Color(1.0, 0.33, 0.36)
@export var accent_color: Color = Color(1.0, 0.82, 0.25)

@export_group("Launch")
@export var launch_speed_x: float = 5.0
@export var launch_speed_y: float = 11.0
@export var spin_speed_deg: float = 495.0
@export var gravity_scale: float = 1.0
## Extra launches allowed while airborne.
@export var max_air_launches: int = 1

@export_group("Stick")
@export var stick_half_angle_deg: float = 35.0
@export var perfect_half_angle_deg: float = 10.0

@export_group("Shape")
## Sticking point relative to the pivot.
@export var tip_local: Vector2 = Vector2(0.6, 0.0)
## Direction the tip points, relative to forward (e.g. -90 for a downward hook).
@export var tip_direction_deg: float = 0.0
## Number of identical tips spread evenly around the pivot (4 for a throwing star).
@export var tip_count: int = 1
## Body collision samples run along the forward axis from -tail_offset to front_offset.
@export var tail_offset: float = 0.5
@export var front_offset: float = 0.417
@export var body_sample_count: int = 6

@export_group("Ability")
@export var ability: Ability = Ability.NONE
## RECOIL_SHOT: shots per flight, refilled on every stick.
@export var ability_charges: int = 0
@export var recoil_speed: float = 10.5
## RETURN_ONCE: flight time and arc height of the return trip.
@export var return_time: float = 0.55
@export var return_arc_height: float = 1.2
