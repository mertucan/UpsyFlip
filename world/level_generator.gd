class_name LevelGenerator
extends RefCounted
## Seeded, deterministic endless level generator: the same seed and config
## always produce the same sequence of rows.

const FLOATING_WALL_MARGIN: float = 0.25
const PICKUP_WALL_MARGIN: float = 0.6

var config: LevelConfig
## Top height of the most recently generated platform.
var last_top: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _index: int = 0
var _side: int = -1
var _previous_center_x: float = 0.0


func _init(p_config: LevelConfig, level_seed: int) -> void:
	config = p_config
	_rng.seed = level_seed
	_previous_center_x = config.start_x


func next() -> PlatformSpec:
	var spec: PlatformSpec = PlatformSpec.new()
	spec.index = _index
	if _index < config.intro_rows:
		_side = -_side
		last_top += config.intro_step
		spec.rect = _wall_attached_rect(config.intro_length)
	else:
		_fill_random_row(spec)
	_previous_center_x = spec.rect.get_center().x
	_index += 1
	return spec


func _fill_random_row(spec: PlatformSpec) -> void:
	var difficulty: float = config.difficulty_at(last_top)
	var same_side: bool = _rng.randf() < lerpf(
			config.same_side_chance_easy, config.same_side_chance_hard, difficulty)
	if not same_side:
		_side = -_side
	var step: float = _rng.randf_range(
			lerpf(config.step_min_easy, config.step_min_hard, difficulty),
			lerpf(config.step_max_easy, config.step_max_hard, difficulty))
	if same_side:
		step = maxf(step, config.same_side_min_step)
	last_top += step

	var moving_chance: float = 0.0
	if last_top >= config.moving_start_height:
		moving_chance = lerpf(config.moving_chance_easy, config.moving_chance_hard, difficulty)
	var target_chance: float = 0.0
	if last_top >= config.target_start_height:
		target_chance = lerpf(config.target_chance_easy, config.target_chance_hard, difficulty)

	var roll: float = _rng.randf()
	if roll < moving_chance:
		spec.kind = PlatformSpec.Kind.MOVING
		spec.move_amplitude = lerpf(
				config.moving_amplitude_easy, config.moving_amplitude_hard, difficulty)
		spec.move_speed = lerpf(config.moving_speed_easy, config.moving_speed_hard, difficulty)
		spec.move_phase = _rng.randf_range(0.0, TAU)
		var reach: float = config.wall_x - config.moving_length * 0.5 \
				- spec.move_amplitude - FLOATING_WALL_MARGIN
		spec.rect = _floating_rect(_rng.randf_range(-reach, reach), config.moving_length)
	elif roll < moving_chance + target_chance:
		spec.kind = PlatformSpec.Kind.TARGET
		spec.bonus_points = config.target_bonus_points
		spec.center_bonus_points = config.target_center_bonus_points
		spec.center_zone = config.target_center_zone
		var reach: float = config.wall_x - config.target_length * 0.5 - FLOATING_WALL_MARGIN
		spec.rect = _floating_rect(_side * _rng.randf_range(0.6, reach), config.target_length)
	else:
		spec.rect = _wall_attached_rect(_rng.randf_range(
				lerpf(config.length_min_easy, config.length_min_hard, difficulty),
				lerpf(config.length_max_easy, config.length_max_hard, difficulty)))

	if _rng.randf() < config.pickup_chance:
		spec.pickup = _make_pickup(spec.rect)


func _wall_attached_rect(length: float) -> Rect2:
	var left: float = config.wall_x - length if _side > 0 else -config.wall_x
	return Rect2(left, last_top - config.plank_thickness, length, config.plank_thickness)


func _floating_rect(center_x: float, length: float) -> Rect2:
	return Rect2(
			center_x - length * 0.5, last_top - config.plank_thickness,
			length, config.plank_thickness)


## Pickups float along the flight path from the previous platform to this one.
func _make_pickup(platform_rect: Rect2) -> Pickup:
	var pickup: Pickup = Pickup.new()
	if _rng.randf() < config.watermelon_share:
		pickup.kind = Pickup.Kind.WATERMELON
		pickup.coins = config.watermelon_coins
		pickup.radius = config.watermelon_radius
	else:
		pickup.kind = Pickup.Kind.BALLOON
		pickup.coins = config.balloon_coins
		pickup.radius = config.balloon_radius
	var limit: float = config.wall_x - PICKUP_WALL_MARGIN
	var x: float = lerpf(_previous_center_x, platform_rect.get_center().x, 0.5) \
			+ _rng.randf_range(-0.5, 0.5)
	pickup.position = Vector2(clampf(x, -limit, limit), last_top + _rng.randf_range(0.9, 1.6))
	return pickup
