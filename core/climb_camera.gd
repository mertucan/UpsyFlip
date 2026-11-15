class_name ClimbCamera
extends Camera3D
## Side-on perspective camera that keeps a fixed world width on every screen
## aspect and only ever moves upward.

var half_width: float = 3.7
var follow_speed: float = 6.0

var shake_max_offset: float = 0.22
var shake_decay: float = 2.6

var _target_y: float = 0.0
var _trauma: float = 0.0


func _process(delta: float) -> void:
	# Screen shake only offsets the rendered frame; position (and so the
	# death line) is unaffected.
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var strength: float = _trauma * _trauma * shake_max_offset
	h_offset = randf_range(-strength, strength)
	v_offset = randf_range(-strength, strength)


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func setup(p_half_width: float, fov_deg: float, p_follow_speed: float) -> void:
	half_width = p_half_width
	follow_speed = p_follow_speed
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = fov_deg
	position.z = half_width / tan(deg_to_rad(fov_deg) * 0.5)


## Half of the visible height at the gameplay plane (z = 0).
func half_height() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return half_width * size.y / maxf(size.x, 1.0)


func bottom_y() -> float:
	return position.y - half_height()


func top_y() -> float:
	return position.y + half_height()


func snap_to(y: float) -> void:
	_target_y = y
	position.y = y


func follow(y: float, delta: float) -> void:
	_target_y = maxf(_target_y, y)
	position.y = lerpf(position.y, _target_y, 1.0 - exp(-follow_speed * delta))
