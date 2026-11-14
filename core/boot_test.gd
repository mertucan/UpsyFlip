extends Node3D
## Phase 0 smoke-test scene: verifies 3D rendering, touch input and haptics
## on device. Replaced by the real game scene in Phase 1.

const SPIN_SPEED: float = 2.5
const COLOR_IDLE: Color = Color(0.91, 0.93, 0.97)
const COLOR_LEFT: Color = Color(1.0, 0.35, 0.37)
const COLOR_RIGHT: Color = Color(0.25, 0.75, 1.0)
const VIBRATE_MS: int = 30

var _box: MeshInstance3D
var _material: StandardMaterial3D
var _info_label: Label
var _touch_label: Label
var _spin_direction: float = 1.0
var _touch_count: int = 0


func _ready() -> void:
	_build_world()
	_build_ui()


func _process(delta: float) -> void:
	_box.rotate_z(-_spin_direction * SPIN_SPEED * delta)
	_info_label.text = "Upsy Flip %s\nGodot %s\n%s\n%d FPS" % [
		ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_method(),
		Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var is_left: bool = touch.position.x < get_viewport().get_visible_rect().size.x * 0.5
	_spin_direction = -1.0 if is_left else 1.0
	_material.albedo_color = COLOR_LEFT if is_left else COLOR_RIGHT
	_touch_count += 1
	_touch_label.text = "%s  (%d)" % ["LEFT" if is_left else "RIGHT", _touch_count]
	Haptics.vibrate(VIBRATE_MS)


func _build_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.11, 0.14, 0.25)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	environment.ambient_light_energy = 0.6
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera: Camera3D = Camera3D.new()
	camera.fov = 40.0
	camera.position = Vector3(0.0, 0.0, 10.0)
	add_child(camera)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	add_child(light)

	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_IDLE
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 2.4, 0.5)
	mesh.material = _material
	_box = MeshInstance3D.new()
	_box.mesh = mesh
	add_child(_box)


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 44)
	_info_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 48)
	_info_label.offset_top = 140.0
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_info_label)

	_touch_label = Label.new()
	_touch_label.text = "TAP LEFT / RIGHT"
	_touch_label.add_theme_font_size_override("font_size", 64)
	_touch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_touch_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 48)
	_touch_label.offset_top = -360.0
	_touch_label.offset_bottom = -260.0
	_touch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_touch_label)
