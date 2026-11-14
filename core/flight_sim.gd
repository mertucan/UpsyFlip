class_name FlightSim
extends RefCounted
## Deterministic, engine-physics-free flight of the thrown object in the X-Y
## plane. Pure logic: no nodes, so it runs in headless tests.
##
## Collision rule: the tip is checked first. A tip entering a stickable face
## within the stick angle sticks; any other contact (bad angle, non-stickable
## face, or body/handle touching first) bounces.

enum State { STUCK, FLYING, FALLING, DEAD }

signal launched(direction: int, power: float)
signal stuck(quality: int, surface: SurfaceRect)
signal bounced(point: Vector2, normal: Vector2)
signal died

var config: FeelConfig
var surfaces: Array[SurfaceRect] = []
var state: State = State.STUCK
var position: Vector2 = Vector2.ZERO
## Radians; direction the tip points (0 = +X, counter-clockwise positive).
var angle: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
## The run ends when the pivot drops below this height.
var kill_y: float = -INF
var stuck_surface: SurfaceRect = null
var air_launches_used: int = 0

var _ignored_surface: SurfaceRect = null
var _bounce_count: int = 0
var _ghost: bool = false


func _init(p_config: FeelConfig) -> void:
	config = p_config


func place_stuck(p_position: Vector2, p_angle: float, surface: SurfaceRect) -> void:
	state = State.STUCK
	position = p_position
	angle = p_angle
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	stuck_surface = surface
	_ignored_surface = null
	air_launches_used = 0
	_bounce_count = 0
	_ghost = false


func can_launch() -> bool:
	if state == State.STUCK:
		return true
	if state == State.FLYING or state == State.FALLING:
		return not _ghost and air_launches_used < config.max_air_launches
	return false


## `direction` is -1 (left) or +1 (right); `power` is 0..1 and only matters
## when hold-to-charge is enabled.
func launch(direction: int, power: float = 1.0) -> bool:
	if not can_launch():
		return false
	var speed_scale: float = 1.0
	if config.hold_to_charge:
		speed_scale = lerpf(config.charge_min_scale, config.charge_max_scale, clampf(power, 0.0, 1.0))
	if state == State.STUCK:
		_ignored_surface = stuck_surface
		stuck_surface = null
	else:
		air_launches_used += 1
	velocity = Vector2(direction * config.launch_speed_x, config.launch_speed_y) * speed_scale
	angular_velocity = -direction * deg_to_rad(config.spin_speed_deg)
	_bounce_count = 0
	state = State.FLYING
	launched.emit(direction, power)
	return true


func tip_point() -> Vector2:
	return _tip_at(position, angle)


func step(delta: float) -> void:
	if state == State.STUCK or state == State.DEAD:
		return
	var previous_position: Vector2 = position
	var previous_angle: float = angle
	velocity.y -= config.gravity * delta
	position += velocity * delta
	angle += angular_velocity * delta

	if position.y < kill_y:
		state = State.DEAD
		died.emit()
		return
	if _ghost:
		return
	if _ignored_surface != null and not _touches(_ignored_surface):
		_ignored_surface = null

	var tip: Vector2 = _tip_at(position, angle)
	var previous_tip: Vector2 = _tip_at(previous_position, previous_angle)
	for surface: SurfaceRect in surfaces:
		if surface == _ignored_surface or not surface.contains(tip):
			continue
		var hit: SurfaceRect.Hit = surface.find_entry(previous_tip, tip)
		var quality: StickRules.Quality = StickRules.Quality.BOUNCE
		if surface.is_stickable(hit.face):
			quality = StickRules.evaluate(
					Vector2.from_angle(angle), -hit.normal,
					config.stick_half_angle_deg, config.perfect_half_angle_deg)
		if quality == StickRules.Quality.BOUNCE:
			_bounce(previous_position, previous_angle, hit)
		else:
			_stick(surface, hit, quality)
		return

	for index: int in config.body_sample_count:
		var sample: Vector2 = _body_sample_at(position, angle, index)
		for surface: SurfaceRect in surfaces:
			if surface == _ignored_surface or not surface.contains(sample):
				continue
			var previous_sample: Vector2 = _body_sample_at(previous_position, previous_angle, index)
			_bounce(previous_position, previous_angle, surface.find_entry(previous_sample, sample))
			return


func _stick(surface: SurfaceRect, hit: SurfaceRect.Hit, quality: StickRules.Quality) -> void:
	var inward_angle: float = (-hit.normal).angle()
	angle = lerp_angle(angle, inward_angle, config.stick_settle)
	position = hit.point + Vector2.from_angle(angle) * (config.stick_depth - config.tip_offset)
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	state = State.STUCK
	stuck_surface = surface
	_ignored_surface = null
	air_launches_used = 0
	_bounce_count = 0
	stuck.emit(quality, surface)


func _bounce(previous_position: Vector2, previous_angle: float, hit: SurfaceRect.Hit) -> void:
	position = previous_position
	angle = previous_angle
	var normal_speed: float = velocity.dot(hit.normal)
	if normal_speed < 0.0:
		velocity -= (1.0 + config.bounce_restitution) * normal_speed * hit.normal
	if velocity.dot(hit.normal) < config.bounce_pop_speed:
		velocity += hit.normal * (config.bounce_pop_speed - velocity.dot(hit.normal))
	angular_velocity *= -config.bounce_spin_factor
	state = State.FALLING
	_bounce_count += 1
	if _bounce_count > config.max_bounces:
		_ghost = true
	bounced.emit(hit.point, hit.normal)


func _touches(surface: SurfaceRect) -> bool:
	if surface.contains(_tip_at(position, angle)):
		return true
	for index: int in config.body_sample_count:
		if surface.contains(_body_sample_at(position, angle, index)):
			return true
	return false


func _tip_at(at_position: Vector2, at_angle: float) -> Vector2:
	return at_position + Vector2.from_angle(at_angle) * config.tip_offset


## Body samples run from the handle end (index 0) toward, but excluding, the tip.
func _body_sample_at(at_position: Vector2, at_angle: float, index: int) -> Vector2:
	var along: float = lerpf(
			-config.tail_offset, config.tip_offset,
			float(index) / float(config.body_sample_count))
	return at_position + Vector2.from_angle(at_angle) * along
