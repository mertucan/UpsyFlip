extends "res://tests/test_case.gd"

const EXPECTED_SKINS: Array[StringName] = [&"knife", &"pistol", &"axe", &"shuriken", &"boomerang", &"gold_knife"]
const MAX_STEPS: int = 3000


func _config() -> FeelConfig:
	return (load("res://data/feel_config.tres") as FeelConfig).duplicate() as FeelConfig


func _catalog() -> SkinCatalog:
	return load("res://skins/skin_catalog.tres") as SkinCatalog


func _skin(skin_id: StringName) -> SkinData:
	return _catalog().find(skin_id).duplicate() as SkinData


## Sim standing on the real level floor with walls and the intro rows.
func _course_sim(skin: SkinData) -> FlightSim:
	var level: LevelConfig = load("res://data/level_config.tres") as LevelConfig
	var sim: FlightSim = FlightSim.new(_config(), skin)
	for side: int in [-1, 1]:
		sim.surfaces.append(SurfaceRect.new(level.wall_rect(side), SurfaceRect.FACES_NONE))
	var floor_surface: SurfaceRect = SurfaceRect.new(level.floor_rect())
	sim.surfaces.append(floor_surface)
	var generator: LevelGenerator = LevelGenerator.new(level, 1)
	for index: int in level.intro_rows:
		sim.surfaces.append(SurfaceRect.from_spec(generator.next()))
	sim.place_stuck_in(Vector2(level.start_x, 0.0), -PI * 0.5, floor_surface)
	sim.kill_y = -6.0
	return sim


## Drops the object straight down onto a wide floor with the given body angle.
func _drop(skin: SkinData, angle: float) -> FlightSim:
	var config: FeelConfig = _config()
	config.gravity = 0.0
	var sim: FlightSim = FlightSim.new(config, skin)
	sim.surfaces.append(SurfaceRect.new(Rect2(-3.0, -1.0, 6.0, 1.0)))
	sim.state = FlightSim.State.FLYING
	sim.position = Vector2(0.0, 1.5)
	sim.angle = angle
	sim.velocity = Vector2(0.0, -6.0)
	for step: int in 200:
		sim.step(config.sim_step)
	return sim


func _run_until_settled(sim: FlightSim) -> void:
	for step: int in MAX_STEPS:
		if sim.state == FlightSim.State.STUCK or sim.state == FlightSim.State.DEAD:
			return
		sim.step(sim.config.sim_step)


func test_catalog_lists_the_v1_skins() -> void:
	var ids: Array[StringName] = []
	for skin: SkinData in _catalog().skins:
		ids.append(skin.id)
	assert_eq(ids, EXPECTED_SKINS, "catalog order and content")
	assert_eq(_catalog().find(&"does_not_exist").id, &"knife", "unknown id falls back to the starter skin")


func test_every_skin_builds_a_model_and_survives_a_launch() -> void:
	for skin: SkinData in _catalog().skins:
		var model: Node3D = SkinModels.build(skin)
		assert_true(model != null and model.get_child_count() > 0, "%s has a model" % skin.id)
		model.free()
		var sim: FlightSim = _course_sim(skin.duplicate() as SkinData)
		assert_true(sim.launch(1), "%s launches" % skin.id)
		_run_until_settled(sim)
		assert_true(
				sim.state == FlightSim.State.STUCK or sim.state == FlightSim.State.DEAD,
				"%s flight settles" % skin.id)


func test_starting_pose_points_the_tip_into_the_floor() -> void:
	for skin: SkinData in _catalog().skins:
		var sim: FlightSim = _course_sim(skin.duplicate() as SkinData)
		assert_true(is_equal_approx(sim.tip_point().y, -sim.config.stick_depth), "%s tip is sunk into the floor" % skin.id)
		assert_true(sim.position.y > -0.05, "%s body rests above the floor" % skin.id)


func test_axe_sticks_at_angles_where_the_knife_bounces() -> void:
	# 50 degrees away from a straight, tip-first hit on the floor.
	var knife: FlightSim = _drop(_skin(&"knife"), -PI * 0.5 + deg_to_rad(50.0))
	assert_eq(knife.state, FlightSim.State.FALLING, "knife bounces at 50 degrees")
	var axe: FlightSim = _drop(_skin(&"axe"), deg_to_rad(-50.0))
	assert_eq(axe.state, FlightSim.State.STUCK, "axe sticks at 50 degrees")


func test_shuriken_sticks_at_any_angle() -> void:
	for degrees: int in range(0, 360, 25):
		var sim: FlightSim = _drop(_skin(&"shuriken"), deg_to_rad(float(degrees)))
		assert_eq(sim.state, FlightSim.State.STUCK, "shuriken sticks at %d degrees" % degrees)


func test_pistol_fires_instead_of_relaunching() -> void:
	var skin: SkinData = _skin(&"pistol")
	var sim: FlightSim = _course_sim(skin)
	var shots: Array[Vector2] = []
	sim.shot_fired.connect(func(_muzzle: Vector2, direction: Vector2) -> void: shots.append(direction))
	sim.launch(1)
	for step: int in 20:
		sim.step(sim.config.sim_step)
	assert_eq(sim.charges_left, skin.ability_charges, "full magazine after launch")
	var barrel: Vector2 = Vector2.from_angle(sim.angle)
	assert_true(sim.launch(1), "airborne tap fires")
	assert_eq(shots.size(), 1, "one shot fired")
	assert_true(sim.velocity.is_equal_approx(-barrel * skin.recoil_speed), "recoil pushes away from the barrel")
	assert_true(sim.launch(-1), "second shot fires")
	assert_true(not sim.launch(1), "magazine is empty after %d shots" % skin.ability_charges)
	assert_eq(sim.charges_left, 0, "no charges left")


func test_pistol_reloads_when_it_hooks_on() -> void:
	var skin: SkinData = _skin(&"pistol")
	var config: FeelConfig = _config()
	config.gravity = 0.0
	var sim: FlightSim = FlightSim.new(config, skin)
	sim.surfaces.append(SurfaceRect.new(Rect2(-3.0, -1.0, 6.0, 1.0)))
	sim.state = FlightSim.State.FLYING
	sim.position = Vector2(0.0, 1.5)
	sim.angle = 0.0
	sim.velocity = Vector2(0.0, -6.0)
	sim.charges_left = 0
	for step: int in 200:
		sim.step(config.sim_step)
	assert_eq(sim.state, FlightSim.State.STUCK, "level pistol hooks onto the floor")
	assert_eq(sim.charges_left, skin.ability_charges, "hooking on reloads")


func test_boomerang_returns_once_after_a_miss() -> void:
	var sim: FlightSim = _course_sim(_skin(&"boomerang"))
	sim.skin.max_air_launches = 0
	var events: Array[String] = []
	sim.return_started.connect(func() -> void: events.append("return_started"))
	sim.returned.connect(func() -> void: events.append("returned"))
	sim.died.connect(func() -> void: events.append("died"))
	var start_position: Vector2 = sim.position
	var start_angle: float = sim.angle

	# Throwing left from the start slams into the left wall: a miss.
	sim.launch(-1)
	_run_until_settled(sim)
	assert_eq(events, ["return_started", "returned"] as Array[String], "first miss triggers the return")
	assert_eq(sim.state, FlightSim.State.STUCK, "boomerang is stuck again")
	assert_true(sim.position.is_equal_approx(start_position), "it returns to where it was thrown from")
	assert_true(is_equal_approx(sim.angle, start_angle), "it returns in its original pose")

	# The second chance is spent until a real stick happens.
	sim.launch(-1)
	for step: int in MAX_STEPS:
		if sim.state != FlightSim.State.FLYING:
			break
		sim.step(sim.config.sim_step)
	assert_eq(sim.state, FlightSim.State.FALLING, "second miss in a row just bounces")
	assert_eq(events.count("return_started"), 1, "no second return")


func test_boomerang_returns_when_falling_off_screen() -> void:
	var sim: FlightSim = _course_sim(_skin(&"boomerang"))
	sim.skin.max_air_launches = 0
	var floor_surface: SurfaceRect = sim.stuck_surface
	sim.surfaces.assign([floor_surface])
	sim.kill_y = -0.5
	sim.launch(1)
	# Remove everything else so the throw just falls past the kill line... but
	# keep the floor it should fly back to.
	for step: int in MAX_STEPS:
		if sim.state != FlightSim.State.FLYING:
			break
		sim.step(sim.config.sim_step)
	assert_true(sim.state == FlightSim.State.RETURNING or sim.state == FlightSim.State.STUCK, "falling off-screen triggers the return")
