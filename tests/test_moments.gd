extends "res://tests/test_case.gd"

const PERFECT: int = StickRules.Quality.PERFECT
const STICK: int = StickRules.Quality.STICK


func _config() -> FeelConfig:
	return (load("res://data/feel_config.tres") as FeelConfig).duplicate() as FeelConfig


func test_perfect_streak_scales_points() -> void:
	var config: FeelConfig = _config()
	var combo: ComboTracker = ComboTracker.new(config)
	assert_eq(combo.register_stick(PERFECT), config.perfect_points, "first PERFECT pays x1")
	assert_eq(combo.register_stick(PERFECT), config.perfect_points * 2, "second PERFECT pays x2")
	assert_eq(combo.streak, 2, "streak counts consecutive PERFECTs")


func test_multiplier_is_capped() -> void:
	var config: FeelConfig = _config()
	config.fever_perfects_needed = 1000
	var combo: ComboTracker = ComboTracker.new(config)
	var points: int = 0
	for index: int in config.combo_max_multiplier + 3:
		points = combo.register_stick(PERFECT)
	assert_eq(points, config.perfect_points * config.combo_max_multiplier, "multiplier stops at the cap")


func test_plain_stick_and_miss_reset_streak() -> void:
	var combo: ComboTracker = ComboTracker.new(_config())
	combo.register_stick(PERFECT)
	combo.register_stick(PERFECT)
	assert_eq(combo.register_stick(STICK), 0, "plain stick pays no combo points")
	assert_eq(combo.streak, 0, "plain stick resets the streak")
	combo.register_stick(PERFECT)
	combo.register_miss()
	assert_eq(combo.streak, 0, "miss resets the streak")


func test_fever_needs_consecutive_perfects() -> void:
	var config: FeelConfig = _config()
	var combo: ComboTracker = ComboTracker.new(config)
	for index: int in config.fever_perfects_needed - 1:
		combo.register_stick(PERFECT)
	combo.register_stick(STICK)
	for index: int in config.fever_perfects_needed - 1:
		combo.register_stick(PERFECT)
	assert_true(not combo.is_fever(), "broken streak does not start FEVER")
	combo.register_stick(PERFECT)
	assert_true(combo.is_fever(), "enough consecutive PERFECTs start FEVER")


func test_fever_doubles_coins_and_expires() -> void:
	var config: FeelConfig = _config()
	var combo: ComboTracker = ComboTracker.new(config)
	var events: Array[String] = []
	combo.fever_started.connect(func() -> void: events.append("start"))
	combo.fever_ended.connect(func() -> void: events.append("end"))
	assert_eq(combo.coin_multiplier(), 1, "no coin bonus outside FEVER")
	for index: int in config.fever_perfects_needed:
		combo.register_stick(PERFECT)
	assert_eq(combo.coin_multiplier(), config.fever_coin_multiplier, "coins multiplied during FEVER")
	combo.advance(config.fever_duration * 0.5)
	assert_true(combo.is_fever() and is_equal_approx(combo.fever_fraction(), 0.5), "FEVER half way")
	combo.advance(config.fever_duration)
	assert_true(not combo.is_fever(), "FEVER expires")
	assert_eq(events, ["start", "end"] as Array[String], "start and end are signalled once each")


func test_clutch_rule() -> void:
	assert_true(StickRules.is_clutch(1.0, -5.0, 2.5), "falling stick near the bottom is a CLUTCH")
	assert_true(not StickRules.is_clutch(4.0, -5.0, 2.5), "stick high on screen is not")
	assert_true(not StickRules.is_clutch(1.0, 3.0, 2.5), "stick while rising is not")


func test_sim_records_impact_velocity() -> void:
	var config: FeelConfig = _config()
	config.gravity = 0.0
	var sim: FlightSim = FlightSim.new(config)
	sim.surfaces.append(SurfaceRect.new(Rect2(-1.0, -1.0, 2.0, 1.0)))
	sim.state = FlightSim.State.FLYING
	sim.position = Vector2(0.0, 1.0)
	sim.angle = -PI * 0.5
	sim.velocity = Vector2(0.0, -6.0)
	for step: int in 200:
		sim.step(config.sim_step)
	assert_eq(sim.state, FlightSim.State.STUCK, "object sticks")
	assert_true(is_equal_approx(sim.last_impact_velocity.y, -6.0), "impact velocity is kept for CLUTCH detection")


func test_all_sound_effects_are_synthesized() -> void:
	var sounds: Dictionary[StringName, AudioStreamWAV] = SfxSynth.build_all()
	for sfx_name: StringName in SfxSynth.SFX_NAMES:
		assert_true(sounds.has(sfx_name), "missing sound: " + sfx_name)
		if sounds.has(sfx_name):
			assert_true(sounds[sfx_name].data.size() > 400, "sound is empty: " + sfx_name)
	assert_eq(sounds.size(), SfxSynth.SFX_NAMES.size(), "no unnamed sounds")
