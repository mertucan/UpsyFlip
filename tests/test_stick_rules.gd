extends "res://tests/test_case.gd"

const INTO_TOP: Vector2 = Vector2(0.0, -1.0)


func _evaluate(deviation_deg: float) -> StickRules.Quality:
	var direction: Vector2 = INTO_TOP.rotated(deg_to_rad(deviation_deg))
	return StickRules.evaluate(direction, INTO_TOP, 35.0, 10.0)


func test_straight_impact_is_perfect() -> void:
	assert_eq(_evaluate(0.0), StickRules.Quality.PERFECT, "0 deg")
	assert_eq(_evaluate(9.5), StickRules.Quality.PERFECT, "9.5 deg")
	assert_eq(_evaluate(-9.5), StickRules.Quality.PERFECT, "-9.5 deg")


func test_angled_impact_sticks() -> void:
	assert_eq(_evaluate(10.5), StickRules.Quality.STICK, "10.5 deg")
	assert_eq(_evaluate(-34.5), StickRules.Quality.STICK, "-34.5 deg")


func test_bad_angle_bounces() -> void:
	assert_eq(_evaluate(35.5), StickRules.Quality.BOUNCE, "35.5 deg")
	assert_eq(_evaluate(90.0), StickRules.Quality.BOUNCE, "90 deg")
	assert_eq(_evaluate(180.0), StickRules.Quality.BOUNCE, "180 deg")


func test_entry_face_detection() -> void:
	var surface: SurfaceRect = SurfaceRect.new(Rect2(0.0, 0.0, 2.0, 1.0))
	assert_eq(surface.find_entry(Vector2(1.0, 1.2), Vector2(1.0, 0.9)).face, SurfaceRect.Face.TOP, "from above")
	assert_eq(surface.find_entry(Vector2(1.0, -0.2), Vector2(1.0, 0.1)).face, SurfaceRect.Face.BOTTOM, "from below")
	assert_eq(surface.find_entry(Vector2(-0.2, 0.5), Vector2(0.1, 0.5)).face, SurfaceRect.Face.LEFT, "from left")
	assert_eq(surface.find_entry(Vector2(2.2, 0.5), Vector2(1.9, 0.5)).face, SurfaceRect.Face.RIGHT, "from right")
	var diagonal: SurfaceRect.Hit = surface.find_entry(Vector2(-0.1, 1.3), Vector2(0.5, 0.9))
	assert_eq(diagonal.face, SurfaceRect.Face.TOP, "diagonal entry crosses the top last")
	assert_true(is_equal_approx(diagonal.point.y, 1.0), "entry point lies on the top face")
