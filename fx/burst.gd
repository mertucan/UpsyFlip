class_name Burst
extends RefCounted
## One-shot low-poly particle bursts (wood chips, pops, sparks) and the
## flight trail. CPU particles: cheap and free of shader-compile hitches.

const GRAVITY: Vector3 = Vector3(0.0, -14.0, 0.0)


static func spawn(
		parent: Node3D, at: Vector3, color: Color, amount: int, speed: float,
		direction: Vector3 = Vector3.UP, spread_deg: float = 70.0,
		lifetime: float = 0.5, size: float = 0.09) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.mesh = _chip_mesh(color, size)
	particles.amount = maxi(1, roundi(amount * GraphicsSettings.particle_scale()))
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = direction
	particles.spread = spread_deg
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = GRAVITY
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.scale_amount_curve = _shrink_curve()
	particles.position = at
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Continuous trail that follows `target`; toggle `emitting` to use it.
static func make_trail(target: Node3D, color: Color) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.mesh = _chip_mesh(color, 0.11)
	particles.amount = 28
	particles.lifetime = 0.35
	particles.local_coords = false
	particles.emitting = false
	particles.spread = 180.0
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.5
	particles.gravity = Vector3.ZERO
	particles.scale_amount_curve = _shrink_curve()
	target.add_child(particles)
	return particles


static func set_color(particles: CPUParticles3D, color: Color) -> void:
	((particles.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = color


static func _chip_mesh(color: Color, size: float) -> BoxMesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	mesh.material = material
	return mesh


static func _shrink_curve() -> Curve:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
