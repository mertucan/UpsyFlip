extends "res://tests/test_case.gd"

const MAX_STEPS: int = 2000


func _config() -> FeelConfig:
	return (load("res://data/feel_config.tres") as FeelConfig).duplicate() as FeelConfig


func _level() -> LevelConfig:
	return load("res://data/level_config.tres") as LevelConfig


## Sim with the real level: walls, floor and the first `row_count` generated rows.
func _course_sim(config: FeelConfig, row_count: int) -> FlightSim:
	var level: LevelConfig = _level()
	var sim: FlightSim = FlightSim.new(config)
	for side: int in [-1, 1]:
		sim.surfaces.append(SurfaceRect.new(level.wall_rect(side), SurfaceRect.FACES_NONE))
	var floor_surface: SurfaceRect = SurfaceRect.new(level.floor_rect())
	sim.surfaces.append(floor_surface)
	var generator: LevelGenerator = LevelGenerator.new(level, 1)
	for index: int in row_count:
		sim.surfaces.append(SurfaceRect.from_spec(generator.next()))
	var angle: float = -PI * 0.5
	var tip: Vector2 = Vector2(level.start_x, -config.stick_depth)
	sim.place_stuck(tip - Vector2.from_angle(angle) * config.tip_offset, angle, floor_surface)
	return sim


func _run_until_settled(sim: FlightSim) -> void:
	for step: int in MAX_STEPS:
		if sim.state == FlightSim.State.STUCK or sim.state == FlightSim.State.DEAD:
			return
		sim.step(sim.config.sim_step)


## Free-flying sim with a single surface, for isolated collision cases.
func _single_surface_sim(surface: SurfaceRect, position: Vector2, angle: float, velocity: Vector2) -> FlightSim:
	var config: FeelConfig = _config()
	config.gravity = 0.0
	var sim: FlightSim = FlightSim.new(config)
	sim.surfaces.append(surface)
	sim.state = FlightSim.State.FLYING
	sim.position = position
	sim.angle = angle
	sim.velocity = velocity
	return sim


func test_nominal_zigzag_climb_sticks() -> void:
	var sim: FlightSim = _course_sim(_config(), 4)
	var direction: int = 1
	for jump: int in 4:
		assert_true(sim.launch(direction), "launch %d accepted" % jump)
		_run_until_settled(sim)
		assert_eq(sim.state, FlightSim.State.STUCK, "jump %d should stick" % jump)
		var expected_top: float = _level().intro_step * (jump + 1)
		assert_true(absf(sim.tip_point().y - expected_top) < 0.5, "jump %d lands on plank %d" % [jump, jump])
		direction = -direction


func test_simulation_is_deterministic() -> void:
	var results: Array[Vector3] = []
	for run: int in 2:
		var sim: FlightSim = _course_sim(_config(), 4)
		sim.launch(1)
		_run_until_settled(sim)
		sim.launch(-1)
		_run_until_settled(sim)
		results.append(Vector3(sim.position.x, sim.position.y, sim.angle))
	assert_true(results[0] == results[1], "same inputs must give identical results")


func test_tip_first_straight_impact_is_perfect() -> void:
	var surface: SurfaceRect = SurfaceRect.new(Rect2(-1.0, -1.0, 2.0, 1.0))
	var sim: FlightSim = _single_surface_sim(surface, Vector2(0.0, 1.0), -PI * 0.5, Vector2(0.0, -6.0))
	var qualities: Array[int] = []
	sim.stuck.connect(func(quality: int, _surface: SurfaceRect) -> void: qualities.append(quality))
	_run_until_settled(sim)
	assert_eq(sim.state, FlightSim.State.STUCK, "tip-first impact sticks")
	assert_eq(qualities, [StickRules.Quality.PERFECT] as Array[int], "straight impact is PERFECT")
	assert_true(is_equal_approx(sim.tip_point().y, -sim.config.stick_depth), "tip sinks to stick depth")


func test_handle_first_impact_bounces() -> void:
	var surface: SurfaceRect = SurfaceRect.new(Rect2(-1.0, -1.0, 2.0, 1.0))
	var sim: FlightSim = _single_surface_sim(surface, Vector2(0.0, 1.0), PI * 0.5, Vector2(0.0, -6.0))
	for step: int in 60:
		sim.step(sim.config.sim_step)
	assert_eq(sim.state, FlightSim.State.FALLING, "handle-first impact bounces")
	assert_true(sim.velocity.y > 0.0, "bounce sends the object away from the surface")


func test_flat_impact_bounces() -> void:
	var surface: SurfaceRect = SurfaceRect.new(Rect2(-1.0, -1.0, 2.0, 1.0))
	var sim: FlightSim = _single_surface_sim(surface, Vector2(0.0, 1.0), 0.0, Vector2(0.0, -6.0))
	for step: int in 60:
		sim.step(sim.config.sim_step)
	assert_eq(sim.state, FlightSim.State.FALLING, "flat impact bounces")


func test_flat_landing_rests_on_surface_and_ends_run() -> void:
	var config: FeelConfig = _config()
	config.max_air_launches = 0
	var sim: FlightSim = FlightSim.new(config)
	sim.surfaces.append(SurfaceRect.new(Rect2(-3.0, -1.0, 6.0, 1.0)))
	sim.state = FlightSim.State.FLYING
	sim.position = Vector2(0.0, 2.0)
	sim.angle = 0.0
	sim.kill_y = -10.0
	_run_until_settled(sim)
	assert_eq(sim.state, FlightSim.State.DEAD, "flat landing ends the run")
	assert_eq(sim.death_reason, FlightSim.DeathReason.LANDED_FLAT, "death reason is landed flat")
	assert_true(sim.position.y > 0.0, "object stays on top of the surface, never falls through")


func test_underside_is_not_stickable() -> void:
	var surface: SurfaceRect = SurfaceRect.new(Rect2(-1.0, 2.0, 2.0, 0.4))
	var sim: FlightSim = _single_surface_sim(surface, Vector2(0.0, 0.5), PI * 0.5, Vector2(0.0, 6.0))
	for step: int in 60:
		sim.step(sim.config.sim_step)
	assert_eq(sim.state, FlightSim.State.FALLING, "tip into the underside bounces")


func test_falling_below_kill_line_dies() -> void:
	var sim: FlightSim = _course_sim(_config(), 0)
	sim.kill_y = -5.0
	sim.surfaces.clear()
	sim.launch(1)
	_run_until_settled(sim)
	assert_eq(sim.state, FlightSim.State.DEAD, "object below kill line is dead")
	assert_true(not sim.launch(1), "cannot launch when dead")


func test_air_launches_are_limited() -> void:
	var config: FeelConfig = _config()
	config.max_air_launches = 0
	var sim: FlightSim = _course_sim(config, 0)
	assert_true(sim.launch(1), "launch from stuck")
	assert_true(not sim.launch(1), "no air launch when disabled")
	config.max_air_launches = 1
	assert_true(sim.launch(-1), "one air launch when enabled")
	assert_true(not sim.launch(1), "air launch budget is spent")


func test_charge_power_scales_launch() -> void:
	var config: FeelConfig = _config()
	config.hold_to_charge = true
	var weak: FlightSim = _course_sim(config, 0)
	weak.launch(1, 0.0)
	var strong: FlightSim = _course_sim(config, 0)
	strong.launch(1, 1.0)
	assert_true(is_equal_approx(weak.velocity.y, config.launch_speed_y * config.charge_min_scale), "min charge")
	assert_true(is_equal_approx(strong.velocity.y, config.launch_speed_y * config.charge_max_scale), "max charge")


func test_stuck_object_rides_moving_surface() -> void:
	var config: FeelConfig = _config()
	var sim: FlightSim = FlightSim.new(config)
	var surface: SurfaceRect = SurfaceRect.new(Rect2(-1.0, -0.4, 2.0, 0.4))
	surface.move_amplitude = 1.0
	surface.move_speed = 2.0
	sim.surfaces.append(surface)
	sim.place_stuck(Vector2(0.0, 0.4), -PI * 0.5, surface)
	var offset_before: float = sim.position.x - surface.rect.position.x
	for step: int in 90:
		sim.step(config.sim_step)
	assert_true(absf(surface.rect.position.x + 1.0) > 0.2, "surface actually moved")
	assert_true(is_equal_approx(sim.position.x - surface.rect.position.x, offset_before), "object keeps its place on the surface")


func test_pickup_is_collected_once_in_flight() -> void:
	var sim: FlightSim = _course_sim(_config(), 0)
	var pickup: Pickup = Pickup.new()
	pickup.position = sim.position + Vector2(0.5, 1.2)
	pickup.radius = 0.6
	sim.pickups.append(pickup)
	var collected: Array[Pickup] = []
	sim.pickup_collected.connect(func(item: Pickup) -> void: collected.append(item))
	sim.launch(1)
	for step: int in 60:
		sim.step(sim.config.sim_step)
	assert_true(pickup.collected, "pickup on the flight path is collected")
	assert_eq(collected.size(), 1, "pickup is reported exactly once")