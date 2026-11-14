extends Node3D
## Phase 1 core-feel prototype: greybox climb with tap-to-flip, stick/bounce
## rule, upward-only camera, death and instant restart.

enum ControlMode { TAP, HOLD, AIR }

const FEEL_CONFIG_PATH: String = "res://data/feel_config.tres"
const MODE_NAMES: PackedStringArray = ["TAP", "HOLD", "AIR"]
const SPAWN_AHEAD: float = 6.0
const CULL_BELOW: float = 4.0
const PLANK_DEPTH: float = 1.4
const MAX_FRAME_DELTA: float = 0.1

const COLOR_BACKGROUND: Color = Color(0.13, 0.16, 0.27)
const COLOR_WALL: Color = Color(0.22, 0.26, 0.4)
const COLOR_PLANK: Color = Color(0.78, 0.56, 0.34)
const COLOR_PLANK_UNDERSIDE: Color = Color(0.36, 0.38, 0.46)
const COLOR_BLADE: Color = Color(0.93, 0.95, 0.98)
const COLOR_TIP: Color = Color(1.0, 0.82, 0.25)
const COLOR_HANDLE: Color = Color(1.0, 0.33, 0.36)

var _config: FeelConfig
var _sim: FlightSim
var _camera: ClimbCamera
var _knife: Node3D
var _walls: Array[MeshInstance3D] = []
var _surface_nodes: Dictionary[SurfaceRect, Node3D] = {}
var _materials: Dictionary[Color, StandardMaterial3D] = {}

var _control_mode: ControlMode = ControlMode.TAP
var _accumulator: float = 0.0
var _next_plank_index: int = 0
var _next_plank_top: float = 0.0
var _height: int = 0
var _best_height: int = 0
var _dead_time: float = 0.0
var _charging: bool = false
var _charge_direction: int = 1
var _charge_elapsed: float = 0.0

var _height_label: Label
var _best_label: Label
var _flash_label: Label
var _retry_label: Label
var _mode_button: Button
var _power_bar: ProgressBar
var _flash_tween: Tween


func _ready() -> void:
	_config = (load(FEEL_CONFIG_PATH) as FeelConfig).duplicate() as FeelConfig
	_build_world()
	_build_hud()
	_apply_control_mode()
	_reset_run()


func _process(delta: float) -> void:
	delta = minf(delta, MAX_FRAME_DELTA)
	if _charging:
		_charge_elapsed += delta
		_power_bar.value = _charge_power()

	_accumulator += delta
	while _accumulator >= _config.sim_step:
		_accumulator -= _config.sim_step
		_sim.step(_config.sim_step)

	_knife.position = Vector3(_sim.position.x, _sim.position.y, 0.0)
	_knife.rotation.z = _sim.angle

	var anchor_offset: float = _camera.half_height() * _config.camera_anchor
	if _sim.state == FlightSim.State.STUCK:
		_camera.follow(_sim.position.y + anchor_offset, delta)
	elif _sim.state == FlightSim.State.FLYING:
		_camera.follow(_sim.position.y + anchor_offset - _config.camera_flight_slack, delta)
	else:
		_camera.follow(-INF, delta)
	_sim.kill_y = _camera.bottom_y() - _config.death_margin

	for wall: MeshInstance3D in _walls:
		wall.position.y = _camera.position.y
	_spawn_planks()
	_cull_surfaces()

	if _sim.state == FlightSim.State.DEAD:
		_dead_time += delta


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	if _mode_button.get_global_rect().has_point(touch.position):
		return
	var direction: int = -1 if touch.position.x < get_viewport().get_visible_rect().size.x * 0.5 else 1

	if _sim.state == FlightSim.State.DEAD:
		if touch.pressed and _dead_time >= _config.restart_delay:
			_reset_run()
		return

	if _config.hold_to_charge:
		if touch.pressed and _sim.can_launch():
			_charging = true
			_charge_direction = direction
			_charge_elapsed = 0.0
			_power_bar.value = 0.0
			_power_bar.visible = true
		elif not touch.pressed and _charging:
			_charging = false
			_power_bar.visible = false
			_sim.launch(_charge_direction, _charge_power())
	elif touch.pressed:
		_sim.launch(direction)


func _charge_power() -> float:
	return clampf(_charge_elapsed / _config.charge_time, 0.0, 1.0)


# --- Run flow ---------------------------------------------------------------

func _reset_run() -> void:
	for node: Node3D in _surface_nodes.values():
		node.queue_free()
	_surface_nodes.clear()

	_sim = FlightSim.new(_config)
	_sim.stuck.connect(_on_stuck)
	_sim.bounced.connect(_on_bounced)
	_sim.died.connect(_on_died)

	for side: int in [-1, 1]:
		var wall: SurfaceRect = SurfaceRect.new(TestCourse.wall_rect(side), SurfaceRect.FACES_NONE)
		wall.permanent = true
		_sim.surfaces.append(wall)

	var floor_surface: SurfaceRect = _add_surface(TestCourse.floor_rect())
	var start_angle: float = -PI * 0.5
	var start_tip: Vector2 = Vector2(TestCourse.START_X, -_config.stick_depth)
	_sim.place_stuck(
			start_tip - Vector2.from_angle(start_angle) * _config.tip_offset,
			start_angle, floor_surface)

	_next_plank_index = 0
	_next_plank_top = 0.0
	_height = 0
	_dead_time = 0.0
	_accumulator = 0.0
	_charging = false
	_power_bar.visible = false
	_retry_label.visible = false
	_camera.snap_to(_sim.position.y + _camera.half_height() * _config.camera_anchor)
	_spawn_planks()
	_update_score_labels()
	GameState.start_run()


func _on_stuck(quality: int, _surface: SurfaceRect) -> void:
	_height = maxi(_height, floori(_sim.tip_point().y))
	GameState.current_score = _height
	_update_score_labels()
	if quality == StickRules.Quality.PERFECT:
		_flash("PERFECT", COLOR_TIP)
		Haptics.vibrate(_config.perfect_vibrate_ms)
	else:
		Haptics.vibrate(_config.stick_vibrate_ms)


func _on_bounced(_point: Vector2, _normal: Vector2) -> void:
	_flash("MISS", COLOR_HANDLE)
	Haptics.vibrate(_config.bounce_vibrate_ms)


func _on_died() -> void:
	_best_height = maxi(_best_height, _height)
	_update_score_labels()
	_charging = false
	_power_bar.visible = false
	_retry_label.visible = true
	GameState.end_run()


func _on_mode_button_pressed() -> void:
	_control_mode = ((_control_mode + 1) % ControlMode.size()) as ControlMode
	_apply_control_mode()
	_reset_run()


func _apply_control_mode() -> void:
	_config.hold_to_charge = _control_mode == ControlMode.HOLD
	_config.max_air_launches = 1 if _control_mode == ControlMode.AIR else 0
	_mode_button.text = "MODE: " + MODE_NAMES[_control_mode]


# --- Level ------------------------------------------------------------------

func _spawn_planks() -> void:
	while _next_plank_top < _camera.top_y() + SPAWN_AHEAD:
		_next_plank_top += TestCourse.step_height(_next_plank_index)
		_add_surface(TestCourse.plank_rect(_next_plank_index, _next_plank_top))
		_next_plank_index += 1


func _cull_surfaces() -> void:
	var limit: float = _camera.bottom_y() - CULL_BELOW
	for surface: SurfaceRect in _surface_nodes.keys():
		if surface.rect.end.y < limit and surface != _sim.stuck_surface:
			_surface_nodes[surface].queue_free()
			_surface_nodes.erase(surface)
			_sim.surfaces.erase(surface)


func _add_surface(rect: Rect2) -> SurfaceRect:
	var surface: SurfaceRect = SurfaceRect.new(rect)
	_sim.surfaces.append(surface)

	var node: Node3D = Node3D.new()
	var center: Vector2 = rect.get_center()
	node.position = Vector3(center.x, center.y, 0.0)
	# Wood-colored body with a darker underside strip: tops and ends stick,
	# undersides bounce.
	var underside_height: float = minf(0.1, rect.size.y * 0.25)
	var body: MeshInstance3D = _make_box(
			Vector3(rect.size.x, rect.size.y - underside_height, PLANK_DEPTH), COLOR_PLANK)
	body.position.y = underside_height * 0.5
	node.add_child(body)
	var underside: MeshInstance3D = _make_box(
			Vector3(rect.size.x, underside_height, PLANK_DEPTH), COLOR_PLANK_UNDERSIDE)
	underside.position.y = (underside_height - rect.size.y) * 0.5
	node.add_child(underside)
	add_child(node)
	_surface_nodes[surface] = node
	return surface


# --- Scene construction -----------------------------------------------------

func _build_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = COLOR_BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	environment.ambient_light_energy = 0.7
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	add_child(light)

	_camera = ClimbCamera.new()
	add_child(_camera)
	_camera.setup(_config.camera_half_width, _config.camera_fov_deg, _config.camera_follow_speed)

	for side: int in [-1, 1]:
		var wall: MeshInstance3D = _make_box(Vector3(TestCourse.WALL_THICKNESS, 80.0, 3.0), COLOR_WALL)
		wall.position.x = side * (TestCourse.WALL_X + TestCourse.WALL_THICKNESS * 0.5)
		add_child(wall)
		_walls.append(wall)

	_knife = _build_knife()
	add_child(_knife)


## Greybox knife along local +X: red handle, white blade, yellow tip.
func _build_knife() -> Node3D:
	var knife: Node3D = Node3D.new()
	var guard_x: float = -0.05
	var tip_size: float = 0.14

	var handle_length: float = _config.tail_offset + guard_x
	var handle: MeshInstance3D = _make_box(Vector3(handle_length, 0.2, 0.14), COLOR_HANDLE)
	handle.position.x = guard_x - handle_length * 0.5
	knife.add_child(handle)

	var blade_length: float = _config.tip_offset - guard_x - tip_size
	var blade: MeshInstance3D = _make_box(Vector3(blade_length, 0.15, 0.05), COLOR_BLADE)
	blade.position.x = guard_x + blade_length * 0.5
	knife.add_child(blade)

	var tip: MeshInstance3D = _make_box(Vector3(tip_size, 0.1, 0.05), COLOR_TIP)
	tip.position.x = _config.tip_offset - tip_size * 0.5
	knife.add_child(tip)
	return knife


func _make_box(size: Vector3, color: Color) -> MeshInstance3D:
	if not _materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _materials[color]
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	_height_label = _make_label(layer, 120, Control.PRESET_TOP_WIDE, 150.0)
	_best_label = _make_label(layer, 40, Control.PRESET_TOP_WIDE, 310.0)
	_flash_label = _make_label(layer, 96, Control.PRESET_CENTER_TOP, 520.0)
	_flash_label.modulate.a = 0.0
	_retry_label = _make_label(layer, 72, Control.PRESET_CENTER, 0.0)
	_retry_label.text = "TAP TO RETRY"

	_power_bar = ProgressBar.new()
	_power_bar.min_value = 0.0
	_power_bar.max_value = 1.0
	_power_bar.step = 0.0
	_power_bar.show_percentage = false
	_power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_power_bar.offset_left = 160.0
	_power_bar.offset_right = -160.0
	_power_bar.offset_top = -330.0
	_power_bar.offset_bottom = -280.0
	layer.add_child(_power_bar)

	# Debug-only control mode switch for feel tuning.
	_mode_button = Button.new()
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.add_theme_font_size_override("font_size", 34)
	_mode_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_button.offset_left = -340.0
	_mode_button.offset_right = -30.0
	_mode_button.offset_top = 150.0
	_mode_button.offset_bottom = 240.0
	_mode_button.pressed.connect(_on_mode_button_pressed)
	layer.add_child(_mode_button)


func _make_label(layer: CanvasLayer, font_size: int, preset: Control.LayoutPreset, top: float) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.12))
	label.add_theme_constant_override("outline_size", font_size / 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = top
	label.offset_bottom = top + font_size * 1.4
	layer.add_child(label)
	return label


func _update_score_labels() -> void:
	_height_label.text = "%d m" % _height
	_best_label.text = "BEST %d m" % _best_height


func _flash(text: String, color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_label.text = text
	_flash_label.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.6).set_delay(0.25)
