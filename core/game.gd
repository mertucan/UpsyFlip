extends Node3D
## Main gameplay scene: endless seeded climb with themes, moving and target
## platforms, pickups, score and a persistent best-score line.

enum ControlMode { AIR, HOLD, TAP }

const FEEL_CONFIG_PATH: String = "res://data/feel_config.tres"
const LEVEL_CONFIG_PATH: String = "res://data/level_config.tres"
const MODE_NAMES: PackedStringArray = ["AIR", "HOLD", "TAP"]
const SAVE_KEY_BEST_SCORE: String = "best_score"
const SAVE_KEY_BEST_HEIGHT: String = "best_height"

const SPAWN_AHEAD: float = 6.0
const CULL_BELOW: float = 4.0
const PLANK_DEPTH: float = 1.4
const BACKDROP_Z: float = -1.2
const STRIPE_COUNT: int = 16
const MAX_FRAME_DELTA: float = 0.1
const THEME_VIBRATE_MS: int = 60

const COLOR_BLADE: Color = Color(0.93, 0.95, 0.98)
const COLOR_TIP: Color = Color(1.0, 0.82, 0.25)
const COLOR_HANDLE: Color = Color(1.0, 0.33, 0.36)
const COLOR_BEST_LINE: Color = Color(1.0, 0.86, 0.3)
const COLOR_BALLOON: Color = Color(1.0, 0.4, 0.55)
const COLOR_WATERMELON: Color = Color(0.3, 0.75, 0.35)
const COLOR_WATERMELON_FLESH: Color = Color(0.95, 0.3, 0.35)
const COLOR_TARGET_CENTER: Color = Color(0.97, 0.97, 0.97)
const COLOR_COIN_TEXT: Color = Color(1.0, 0.86, 0.3)

var _feel: FeelConfig
var _level: LevelConfig
var _sim: FlightSim
var _generator: LevelGenerator
var _score: ScoreKeeper
var _camera: ClimbCamera
var _hud: Hud
var _knife: Node3D
var _environment: Environment
var _wall_material: StandardMaterial3D
var _stripe_material: StandardMaterial3D
var _walls: Array[MeshInstance3D] = []
var _stripes: Array[MeshInstance3D] = []
var _best_line: Node3D
var _surface_nodes: Dictionary[SurfaceRect, Node3D] = {}
var _pickup_nodes: Dictionary[Pickup, Node3D] = {}
var _static_materials: Dictionary[Color, StandardMaterial3D] = {}

var _control_mode: ControlMode = ControlMode.AIR
var _accumulator: float = 0.0
var _theme_ordinal: int = 0
var _dead_time: float = 0.0
var _charging: bool = false
var _charge_direction: int = 1
var _charge_elapsed: float = 0.0


func _ready() -> void:
	_feel = (load(FEEL_CONFIG_PATH) as FeelConfig).duplicate() as FeelConfig
	_level = load(LEVEL_CONFIG_PATH) as LevelConfig
	_build_world()
	_hud = Hud.new()
	add_child(_hud)
	_hud.mode_pressed.connect(_on_mode_pressed)
	_apply_control_mode()
	_reset_run()


func _process(delta: float) -> void:
	delta = minf(delta, MAX_FRAME_DELTA)
	if _charging:
		_charge_elapsed += delta
		_hud.show_power(true, _charge_power())

	_accumulator += delta
	while _accumulator >= _feel.sim_step:
		_accumulator -= _feel.sim_step
		_sim.step(_feel.sim_step)

	_knife.position = Vector3(_sim.position.x, _sim.position.y, 0.0)
	_knife.rotation.z = _sim.angle

	var anchor_offset: float = _camera.half_height() * _feel.camera_anchor
	if _sim.state == FlightSim.State.STUCK:
		_camera.follow(_sim.position.y + anchor_offset, delta)
	elif _sim.state == FlightSim.State.FLYING:
		_camera.follow(_sim.position.y + anchor_offset - _feel.camera_flight_slack, delta)
	else:
		_camera.follow(-INF, delta)
	_sim.kill_y = _camera.bottom_y() - _feel.death_margin

	_spawn_rows()
	_cull_below_view()
	_sync_level_nodes()
	_update_backdrop()

	if _sim.state == FlightSim.State.DEAD:
		_dead_time += delta


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or _hud.blocks_touch(touch.position):
		return
	var direction: int = -1 if touch.position.x < get_viewport().get_visible_rect().size.x * 0.5 else 1

	if _sim.state == FlightSim.State.DEAD:
		if touch.pressed and _dead_time >= _feel.restart_delay:
			_reset_run()
		return

	if _feel.hold_to_charge:
		if touch.pressed and _sim.can_launch():
			_charging = true
			_charge_direction = direction
			_charge_elapsed = 0.0
			_hud.show_power(true, 0.0)
		elif not touch.pressed and _charging:
			_charging = false
			_hud.show_power(false)
			_sim.launch(_charge_direction, _charge_power())
	elif touch.pressed:
		_sim.launch(direction)


func _charge_power() -> float:
	return clampf(_charge_elapsed / _feel.charge_time, 0.0, 1.0)


# --- Run flow ---------------------------------------------------------------

func _reset_run() -> void:
	for node: Node3D in _surface_nodes.values():
		node.queue_free()
	_surface_nodes.clear()
	for node: Node3D in _pickup_nodes.values():
		node.queue_free()
	_pickup_nodes.clear()

	var run_seed: int = GameState.next_run_seed()
	_generator = LevelGenerator.new(_level, run_seed)
	_score = ScoreKeeper.new()
	_sim = FlightSim.new(_feel)
	_sim.stuck.connect(_on_stuck)
	_sim.bounced.connect(_on_bounced)
	_sim.pickup_collected.connect(_on_pickup_collected)
	_sim.died.connect(_on_died)

	for side: int in [-1, 1]:
		var wall: SurfaceRect = SurfaceRect.new(_level.wall_rect(side), SurfaceRect.FACES_NONE)
		wall.permanent = true
		_sim.surfaces.append(wall)

	var floor_surface: SurfaceRect = SurfaceRect.new(_level.floor_rect())
	_add_surface(floor_surface, 0.0)
	var start_angle: float = -PI * 0.5
	var start_tip: Vector2 = Vector2(_level.start_x, -_feel.stick_depth)
	_sim.place_stuck(
			start_tip - Vector2.from_angle(start_angle) * _feel.tip_offset,
			start_angle, floor_surface)

	_theme_ordinal = 0
	_dead_time = 0.0
	_accumulator = 0.0
	_charging = false
	_camera.snap_to(_sim.position.y + _camera.half_height() * _feel.camera_anchor)
	_spawn_rows()
	_place_best_line()

	_hud.show_power(false)
	_hud.show_retry(false)
	_hud.set_score(0)
	_hud.set_coins(0)
	_hud.set_best(SaveService.get_int(SAVE_KEY_BEST_SCORE))
	GameState.start_run(run_seed)


func _on_stuck(quality: int, surface: SurfaceRect) -> void:
	var tip: Vector2 = _sim.tip_point()
	_score.register_height(tip.y)

	var spec: PlatformSpec = surface.spec
	var is_target_hit: bool = spec != null and spec.kind == PlatformSpec.Kind.TARGET \
			and not surface.bonus_claimed
	if is_target_hit:
		surface.bonus_claimed = true
		var points: int = spec.bonus_points
		var is_center: bool = absf(tip.x - surface.rect.get_center().x) <= spec.center_zone
		if is_center:
			points += spec.center_bonus_points
		_score.add_bonus(points)
		_hud.flash(("BULLSEYE +%d" if is_center else "+%d") % points, COLOR_TIP)
		Haptics.vibrate(_feel.perfect_vibrate_ms)
	elif quality == StickRules.Quality.PERFECT:
		_hud.flash("PERFECT", COLOR_TIP)
		Haptics.vibrate(_feel.perfect_vibrate_ms)
	else:
		Haptics.vibrate(_feel.stick_vibrate_ms)

	var ordinal: int = _level.theme_ordinal_at(float(_score.height))
	if ordinal > _theme_ordinal:
		_theme_ordinal = ordinal
		_hud.show_banner(_level.theme_by_ordinal(ordinal).display_name, Color.WHITE)
		Haptics.vibrate(THEME_VIBRATE_MS)

	GameState.current_score = _score.total()
	_hud.set_score(_score.total())


func _on_bounced(_point: Vector2, _normal: Vector2) -> void:
	_hud.flash("MISS", COLOR_HANDLE)
	Haptics.vibrate(_feel.bounce_vibrate_ms)


func _on_pickup_collected(pickup: Pickup) -> void:
	_score.add_coins(pickup.coins)
	_hud.set_coins(_score.coins)
	_hud.flash("+%d" % pickup.coins, COLOR_COIN_TEXT)
	Haptics.vibrate(_feel.stick_vibrate_ms)
	# The sim is iterating its pickup list right now; it is pruned in
	# _cull_below_view instead.
	if _pickup_nodes.has(pickup):
		_pickup_nodes[pickup].queue_free()
		_pickup_nodes.erase(pickup)


func _on_died() -> void:
	_charging = false
	_hud.show_power(false)
	_hud.show_retry(true)
	Economy.add_coins(_score.coins)
	if _score.total() > SaveService.get_int(SAVE_KEY_BEST_SCORE):
		SaveService.set_value(SAVE_KEY_BEST_SCORE, _score.total())
		SaveService.set_value(SAVE_KEY_BEST_HEIGHT, _score.height)
		SaveService.save_to_disk()
		_hud.set_best(_score.total())
	GameState.end_run()


func _on_mode_pressed() -> void:
	_control_mode = ((_control_mode + 1) % ControlMode.size()) as ControlMode
	_apply_control_mode()
	_reset_run()


func _apply_control_mode() -> void:
	_feel.hold_to_charge = _control_mode == ControlMode.HOLD
	_feel.max_air_launches = 1 if _control_mode == ControlMode.AIR else 0
	_hud.set_mode_text("MODE: " + MODE_NAMES[_control_mode])


# --- Level ------------------------------------------------------------------

func _spawn_rows() -> void:
	while _generator.last_top < _camera.top_y() + SPAWN_AHEAD:
		var spec: PlatformSpec = _generator.next()
		var surface: SurfaceRect = SurfaceRect.from_spec(spec)
		surface.advance(_sim.time)
		_add_surface(surface, spec.rect.end.y)
		if spec.pickup != null:
			_add_pickup(spec.pickup)


func _cull_below_view() -> void:
	var limit: float = _camera.bottom_y() - CULL_BELOW
	for surface: SurfaceRect in _surface_nodes.keys():
		if surface.rect.end.y < limit and surface != _sim.stuck_surface:
			_surface_nodes[surface].queue_free()
			_surface_nodes.erase(surface)
			_sim.surfaces.erase(surface)
	for index: int in range(_sim.pickups.size() - 1, -1, -1):
		var pickup: Pickup = _sim.pickups[index]
		if pickup.collected or pickup.position.y < limit:
			_sim.pickups.remove_at(index)
			if _pickup_nodes.has(pickup):
				_pickup_nodes[pickup].queue_free()
				_pickup_nodes.erase(pickup)


func _sync_level_nodes() -> void:
	for surface: SurfaceRect in _surface_nodes:
		if surface.is_moving():
			_surface_nodes[surface].position.x = surface.rect.get_center().x
	for pickup: Pickup in _pickup_nodes:
		var bob: float = sin(_sim.time * 2.5 + pickup.position.x * 3.0) * 0.08
		_pickup_nodes[pickup].position.y = pickup.position.y + bob


## Platform colors come from the theme at the platform's own height, so a
## theme change scrolls into view gradually.
func _add_surface(surface: SurfaceRect, theme_height: float) -> void:
	_sim.surfaces.append(surface)
	var rect: Rect2 = surface.rect
	var spec: PlatformSpec = surface.spec
	var color_property: StringName = &"platform_color"
	if spec != null and spec.kind == PlatformSpec.Kind.MOVING:
		color_property = &"moving_platform_color"
	elif spec != null and spec.kind == PlatformSpec.Kind.TARGET:
		color_property = &"target_color"

	var node: Node3D = Node3D.new()
	var center: Vector2 = rect.get_center()
	node.position = Vector3(center.x, center.y, 0.0)
	# Colored body with a darker underside strip: tops and ends stick,
	# undersides bounce.
	var underside_height: float = minf(0.1, rect.size.y * 0.25)
	var body: MeshInstance3D = _make_box(
			Vector3(rect.size.x, rect.size.y - underside_height, PLANK_DEPTH),
			_new_material(_level.blended_color(theme_height, color_property)))
	body.position.y = underside_height * 0.5
	node.add_child(body)
	var underside: MeshInstance3D = _make_box(
			Vector3(rect.size.x, underside_height, PLANK_DEPTH),
			_new_material(_level.blended_color(theme_height, &"platform_underside_color")))
	underside.position.y = (underside_height - rect.size.y) * 0.5
	node.add_child(underside)
	if spec != null and spec.kind == PlatformSpec.Kind.TARGET:
		var bullseye: MeshInstance3D = _make_box(
				Vector3(spec.center_zone * 2.0, rect.size.y + 0.04, PLANK_DEPTH + 0.04),
				_static_material(COLOR_TARGET_CENTER))
		node.add_child(bullseye)
	add_child(node)
	_surface_nodes[surface] = node


func _add_pickup(pickup: Pickup) -> void:
	_sim.pickups.append(pickup)
	var node: Node3D = Node3D.new()
	node.position = Vector3(pickup.position.x, pickup.position.y, 0.0)
	var is_watermelon: bool = pickup.kind == Pickup.Kind.WATERMELON
	var body: MeshInstance3D = _make_sphere(
			pickup.radius, COLOR_WATERMELON if is_watermelon else COLOR_BALLOON)
	node.add_child(body)
	if is_watermelon:
		body.scale = Vector3(1.2, 1.0, 1.0)
		var flesh: MeshInstance3D = _make_box(
				Vector3(pickup.radius * 0.9, pickup.radius * 0.9, 0.05),
				_static_material(COLOR_WATERMELON_FLESH))
		flesh.position.z = pickup.radius
		node.add_child(flesh)
	else:
		body.scale = Vector3(1.0, 1.2, 1.0)
		var knot: MeshInstance3D = _make_box(
				Vector3(0.1, 0.1, 0.1), _static_material(COLOR_BALLOON))
		knot.position.y = -pickup.radius * 1.25
		node.add_child(knot)
	add_child(node)
	_pickup_nodes[pickup] = node


func _place_best_line() -> void:
	var best_height: int = SaveService.get_int(SAVE_KEY_BEST_HEIGHT)
	_best_line.visible = best_height > 0
	_best_line.position.y = float(best_height)


func _update_backdrop() -> void:
	var height: float = _camera.position.y
	_environment.background_color = _level.blended_color(height, &"background_color")
	_wall_material.albedo_color = _level.blended_color(height, &"wall_color")
	_stripe_material.albedo_color = _level.blended_color(height, &"stripe_color")
	for wall: MeshInstance3D in _walls:
		wall.position.y = height
	var spacing: float = _level.theme_by_ordinal(_level.theme_ordinal_at(height)).stripe_spacing
	var first: float = floorf(_camera.bottom_y() / spacing) * spacing
	for index: int in _stripes.size():
		_stripes[index].position.y = first + index * spacing


# --- Scene construction -----------------------------------------------------

func _build_world() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.78, 0.8, 0.9)
	_environment.ambient_light_energy = 0.7
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	add_child(light)

	_camera = ClimbCamera.new()
	add_child(_camera)
	_camera.setup(_feel.camera_half_width, _feel.camera_fov_deg, _feel.camera_follow_speed)

	_wall_material = StandardMaterial3D.new()
	for side: int in [-1, 1]:
		var wall: MeshInstance3D = _make_box(Vector3(_level.wall_thickness, 80.0, 3.0), _wall_material)
		wall.position.x = side * (_level.wall_x + _level.wall_thickness * 0.5)
		add_child(wall)
		_walls.append(wall)

	_stripe_material = StandardMaterial3D.new()
	_stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index: int in STRIPE_COUNT:
		var stripe: MeshInstance3D = _make_box(
				Vector3(_level.wall_x * 2.0 + 2.0, 0.12, 0.05), _stripe_material)
		stripe.position.z = BACKDROP_Z
		add_child(stripe)
		_stripes.append(stripe)

	_best_line = _build_best_line()
	add_child(_best_line)
	_knife = _build_knife()
	add_child(_knife)


func _build_best_line() -> Node3D:
	var line: Node3D = Node3D.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLOR_BEST_LINE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bar: MeshInstance3D = _make_box(Vector3(_level.wall_x * 2.0, 0.07, 0.05), material)
	bar.position.z = BACKDROP_Z + 0.2
	line.add_child(bar)
	var label: Label3D = Label3D.new()
	label.text = "BEST"
	label.font_size = 96
	label.pixel_size = 0.004
	label.modulate = COLOR_BEST_LINE
	label.outline_modulate = Color(0.05, 0.06, 0.12)
	label.position = Vector3(0.0, 0.3, BACKDROP_Z + 0.2)
	line.add_child(label)
	return line


## Greybox knife along local +X: red handle, white blade, yellow tip.
func _build_knife() -> Node3D:
	var knife: Node3D = Node3D.new()
	var guard_x: float = -0.05
	var tip_size: float = 0.14

	var handle_length: float = _feel.tail_offset + guard_x
	var handle: MeshInstance3D = _make_box(
			Vector3(handle_length, 0.2, 0.14), _static_material(COLOR_HANDLE))
	handle.position.x = guard_x - handle_length * 0.5
	knife.add_child(handle)

	var blade_length: float = _feel.tip_offset - guard_x - tip_size
	var blade: MeshInstance3D = _make_box(
			Vector3(blade_length, 0.15, 0.05), _static_material(COLOR_BLADE))
	blade.position.x = guard_x + blade_length * 0.5
	knife.add_child(blade)

	var tip: MeshInstance3D = _make_box(Vector3(tip_size, 0.1, 0.05), _static_material(COLOR_TIP))
	tip.position.x = _feel.tip_offset - tip_size * 0.5
	knife.add_child(tip)
	return knife


func _make_box(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _make_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _static_material(color)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _new_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material


## Shared material for colors that never change at runtime.
func _static_material(color: Color) -> StandardMaterial3D:
	if not _static_materials.has(color):
		_static_materials[color] = _new_material(color)
	return _static_materials[color]
