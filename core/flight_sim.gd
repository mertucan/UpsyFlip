class_name FlightSim
extends RefCounted
## Deterministic, engine-physics-free flight of the thrown object in the X-Y
## plane. Pure logic: no nodes, so it runs in headless tests.
##
## Collision rule: tips are checked first. A tip entering a stickable face
## within the skin's stick angle sticks; any other contact (bad angle,
## non-stickable face, or the body touching first) bounces.

enum State { STUCK, FLYING, FALLING, RETURNING, DEAD }
enum DeathReason { NONE, FELL, LANDED_FLAT }

signal launched(direction: int, power: float)
signal shot_fired(muzzle: Vector2, direction: Vector2)
signal stuck(quality: int, surface: SurfaceRect)
signal bounced(point: Vector2, normal: Vector2)
signal return_started
signal returned
signal pickup_collected(pickup: Pickup)
signal died

var config: FeelConfig
var skin: SkinData
var surfaces: Array[SurfaceRect] = []
var pickups: Array[Pickup] = []
## Simulation clock in seconds; drives moving surfaces.
var time: float = 0.0
var state: State = State.STUCK
var position: Vector2 = Vector2.ZERO
## Radians; direction of the object's forward axis (0 = +X, counter-clockwise positive).
var angle: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
## The run ends when the pivot drops below this height.
var kill_y: float = -INF
var stuck_surface: SurfaceRect = null
var air_launches_used: int = 0
## Remaining ability charges (shots) for this flight.
var charges_left: int = 0
var death_reason: DeathReason = DeathReason.NONE
## Velocity just before the most recent stick.
var last_impact_velocity: Vector2 = Vector2.ZERO
## Surface a RETURN_ONCE skin flies back to; must not be culled while set.
var return_surface: SurfaceRect = null

var _ignored_surface: SurfaceRect = null
var _bounce_count: int = 0
var _active_tip: int = 0
var _return_available: bool = true
var _return_offset: Vector2 = Vector2.ZERO
var _return_angle: float = 0.0
var _return_from: Vector2 = Vector2.ZERO
var _return_elapsed: float = 0.0


func _init(p_config: FeelConfig, p_skin: SkinData = null) -> void:
	config = p_config
	skin = p_skin if p_skin != null else SkinData.new()
	charges_left = skin.ability_charges


func place_stuck(p_position: Vector2, p_angle: float, surface: SurfaceRect) -> void:
	state = State.STUCK
	position = p_position
	angle = p_angle
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	stuck_surface = surface
	_ignored_surface = null
	air_launches_used = 0
	charges_left = skin.ability_charges
	_bounce_count = 0
	death_reason = DeathReason.NONE


## Places the object stuck with its first tip sunk into `surface` at
## `surface_point`, pointing along `inward_angle`.
func place_stuck_in(surface_point: Vector2, inward_angle: float, surface: SurfaceRect) -> void:
	_active_tip = 0
	var body_angle: float = inward_angle - _tip_direction_offset(0)
	var tip: Vector2 = surface_point + Vector2.from_angle(inward_angle) * config.stick_depth
	place_stuck(tip - _tip_local(0).rotated(body_angle), body_angle, surface)


func can_launch() -> bool:
	if state == State.STUCK:
		return true
	if state == State.FLYING or state == State.FALLING:
		if skin.ability == SkinData.Ability.RECOIL_SHOT:
			return charges_left > 0
		return air_launches_used < skin.max_air_launches
	return false


## A tap. `direction` is -1 (left) or +1 (right); `power` is 0..1 and only
## matters when hold-to-charge is enabled. Airborne RECOIL_SHOT skins fire
## instead of relaunching.
func launch(direction: int, power: float = 1.0) -> bool:
	if not can_launch():
		return false
	if state != State.STUCK and skin.ability == SkinData.Ability.RECOIL_SHOT:
		_fire_shot()
		return true
	var speed_scale: float = 1.0
	if config.hold_to_charge:
		speed_scale = lerpf(config.charge_min_scale, config.charge_max_scale, clampf(power, 0.0, 1.0))
	if state == State.STUCK:
		return_surface = stuck_surface
		if stuck_surface != null:
			_return_offset = position - stuck_surface.rect.position
		_return_angle = angle
		_ignored_surface = stuck_surface
		stuck_surface = null
	else:
		air_launches_used += 1
	velocity = Vector2(direction * skin.launch_speed_x, skin.launch_speed_y) * speed_scale
	angular_velocity = -direction * deg_to_rad(skin.spin_speed_deg)
	_bounce_count = 0
	state = State.FLYING
	launched.emit(direction, power)
	return true


## World position of the tip that is (or was last) stuck.
func tip_point() -> Vector2:
	return _tip_at(position, angle, _active_tip)


## Offset from the pivot to the active tip, in the object's local frame.
func active_tip_local() -> Vector2:
	return _tip_local(_active_tip)


func step(delta: float) -> void:
	time += delta
	for surface: SurfaceRect in surfaces:
		surface.advance(time)
	if state == State.STUCK:
		# Ride along with a moving surface.
		if stuck_surface != null:
			position += stuck_surface.last_delta
		return
	if state == State.DEAD:
		return
	if state == State.RETURNING:
		_step_return(delta)
		return

	var previous_position: Vector2 = position
	var previous_angle: float = angle
	velocity.y -= config.gravity * skin.gravity_scale * delta
	position += velocity * delta
	angle += angular_velocity * delta

	if position.y < kill_y:
		if _try_start_return():
			return
		state = State.DEAD
		death_reason = DeathReason.FELL
		died.emit()
		return
	if _ignored_surface != null and not _touches(_ignored_surface):
		_ignored_surface = null

	_collect_pickups()

	for tip_index: int in skin.tip_count:
		var tip: Vector2 = _tip_at(position, angle, tip_index)
		for surface: SurfaceRect in surfaces:
			if surface == _ignored_surface or not surface.contains(tip):
				continue
			# Previous points are shifted by the surface's own motion so entry
			# is measured relative to the surface.
			var previous_tip: Vector2 = _tip_at(previous_position, previous_angle, tip_index)
			var hit: SurfaceRect.Hit = surface.find_entry(previous_tip + surface.last_delta, tip)
			var quality: StickRules.Quality = StickRules.Quality.BOUNCE
			if surface.is_stickable(hit.face):
				quality = StickRules.evaluate(
						Vector2.from_angle(angle + _tip_direction_offset(tip_index)), -hit.normal,
						skin.stick_half_angle_deg, skin.perfect_half_angle_deg)
			if quality == StickRules.Quality.BOUNCE:
				_bounce(previous_position, previous_angle, hit)
			else:
				_stick(surface, hit, quality, tip_index)
			return

	for index: int in skin.body_sample_count:
		var sample: Vector2 = _body_sample_at(position, angle, index)
		for surface: SurfaceRect in surfaces:
			if surface == _ignored_surface or not surface.contains(sample):
				continue
			var previous_sample: Vector2 = _body_sample_at(previous_position, previous_angle, index)
			_bounce(previous_position, previous_angle,
					surface.find_entry(previous_sample + surface.last_delta, sample))
			return


func _fire_shot() -> void:
	charges_left -= 1
	var barrel: Vector2 = Vector2.from_angle(angle)
	velocity = -barrel * skin.recoil_speed
	_bounce_count = 0
	state = State.FLYING
	shot_fired.emit(position + barrel * skin.front_offset, barrel)


func _collect_pickups() -> void:
	var forward: Vector2 = Vector2.from_angle(angle)
	var reach: float = maxf(skin.front_offset, skin.tip_local.length())
	var back: Vector2 = position - forward * maxf(skin.tail_offset, 0.0)
	var front: Vector2 = position + forward * reach
	for pickup: Pickup in pickups:
		if pickup.collected:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pickup.position, back, front)
		if closest.distance_to(pickup.position) <= pickup.radius:
			pickup.collected = true
			pickup_collected.emit(pickup)


func _stick(surface: SurfaceRect, hit: SurfaceRect.Hit, quality: StickRules.Quality, tip_index: int) -> void:
	_active_tip = tip_index
	var direction_offset: float = _tip_direction_offset(tip_index)
	var inward_angle: float = (-hit.normal).angle()
	var tip_angle: float = lerp_angle(angle + direction_offset, inward_angle, config.stick_settle)
	angle = tip_angle - direction_offset
	position = hit.point + Vector2.from_angle(tip_angle) * config.stick_depth \
			- _tip_local(tip_index).rotated(angle)
	last_impact_velocity = velocity
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	state = State.STUCK
	stuck_surface = surface
	_ignored_surface = null
	air_launches_used = 0
	charges_left = skin.ability_charges
	_bounce_count = 0
	_return_available = true
	return_surface = null
	stuck.emit(quality, surface)


func _bounce(previous_position: Vector2, previous_angle: float, hit: SurfaceRect.Hit) -> void:
	position = previous_position
	angle = previous_angle
	if _try_start_return():
		return
	var normal_speed: float = velocity.dot(hit.normal)
	_bounce_count += 1
	if hit.face == SurfaceRect.Face.TOP:
		var rebound_speed: float = -normal_speed * config.bounce_restitution
		var is_settling: bool = _bounce_count > config.max_bounces or rebound_speed < config.bounce_pop_speed
		if normal_speed <= 0.0 and is_settling:
			_land_flat(hit)
			return
	if normal_speed < 0.0:
		velocity -= (1.0 + config.bounce_restitution) * normal_speed * hit.normal
	if velocity.dot(hit.normal) < config.bounce_pop_speed:
		velocity += hit.normal * (config.bounce_pop_speed - velocity.dot(hit.normal))
	angular_velocity *= -config.bounce_spin_factor
	state = State.FALLING
	bounced.emit(hit.point, hit.normal)


## The object came to rest lying on top of a surface without sticking: the run ends there.
func _land_flat(hit: SurfaceRect.Hit) -> void:
	angle = 0.0 if cos(angle) >= 0.0 else PI
	position.y = hit.point.y + config.rest_height
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	state = State.DEAD
	death_reason = DeathReason.LANDED_FLAT
	died.emit()


# --- RETURN_ONCE ability ----------------------------------------------------

## A miss (bounce or falling off-screen) sends a RETURN_ONCE skin back to where
## it was last stuck. The second chance is refilled only by a real stick.
func _try_start_return() -> bool:
	if skin.ability != SkinData.Ability.RETURN_ONCE or not _return_available:
		return false
	if return_surface == null or not surfaces.has(return_surface):
		return false
	_return_available = false
	_return_from = position
	_return_elapsed = 0.0
	velocity = Vector2.ZERO
	state = State.RETURNING
	return_started.emit()
	return true


func _step_return(delta: float) -> void:
	_return_elapsed += delta
	var progress: float = clampf(_return_elapsed / skin.return_time, 0.0, 1.0)
	var target: Vector2 = return_surface.rect.position + _return_offset
	position = _return_from.lerp(target, smoothstep(0.0, 1.0, progress)) \
			+ Vector2(0.0, sin(PI * progress) * skin.return_arc_height)
	angle += deg_to_rad(skin.spin_speed_deg) * delta
	if progress >= 1.0:
		var surface: SurfaceRect = return_surface
		return_surface = null
		place_stuck(target, _return_angle, surface)
		returned.emit()


# --- Shape helpers ----------------------------------------------------------

func _touches(surface: SurfaceRect) -> bool:
	for tip_index: int in skin.tip_count:
		if surface.contains(_tip_at(position, angle, tip_index)):
			return true
	for index: int in skin.body_sample_count:
		if surface.contains(_body_sample_at(position, angle, index)):
			return true
	return false


func _tip_local(tip_index: int) -> Vector2:
	return skin.tip_local.rotated(tip_index * TAU / skin.tip_count)


## Direction a tip points, relative to the object's forward axis.
func _tip_direction_offset(tip_index: int) -> float:
	return deg_to_rad(skin.tip_direction_deg) + tip_index * TAU / skin.tip_count


func _tip_at(at_position: Vector2, at_angle: float, tip_index: int) -> Vector2:
	return at_position + _tip_local(tip_index).rotated(at_angle)


## Body samples run along the forward axis from -tail_offset to front_offset.
func _body_sample_at(at_position: Vector2, at_angle: float, index: int) -> Vector2:
	var along: float = skin.front_offset
	if skin.body_sample_count > 1:
		along = lerpf(-skin.tail_offset, skin.front_offset,
				float(index) / float(skin.body_sample_count - 1))
	return at_position + Vector2.from_angle(at_angle) * along
