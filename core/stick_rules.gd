class_name StickRules
extends RefCounted
## The single rule deciding whether a tip impact sticks.

enum Quality { BOUNCE, STICK, PERFECT }


## `tip_direction` is where the tip points; `inward_normal` points into the surface.
static func evaluate(
		tip_direction: Vector2,
		inward_normal: Vector2,
		stick_half_angle_deg: float,
		perfect_half_angle_deg: float) -> Quality:
	var deviation: float = absf(rad_to_deg(tip_direction.angle_to(inward_normal)))
	if deviation <= perfect_half_angle_deg:
		return Quality.PERFECT
	if deviation <= stick_half_angle_deg:
		return Quality.STICK
	return Quality.BOUNCE


## CLUTCH: the object was coming down and stuck within `zone` meters of the
## bottom screen edge.
static func is_clutch(height_above_bottom: float, impact_velocity_y: float, zone: float) -> bool:
	return impact_velocity_y < 0.0 and height_above_bottom <= zone
