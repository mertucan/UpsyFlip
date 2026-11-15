class_name LowPoly
extends RefCounted
## Builds flat-shaded low-poly meshes in code from extruded 2D outlines.
## Outlines are drawn in the X-Y gameplay plane and extruded along Z.
## UVs map `uv_bounds` (the model's side view) onto the whole texture, so a
## user-drawn PNG lines up with the silhouette.

var _tool: SurfaceTool = SurfaceTool.new()
var _uv_bounds: Rect2


func _init(uv_bounds: Rect2) -> void:
	_uv_bounds = uv_bounds
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


func add_box(rect: Rect2, depth: float, color: Color, z_center: float = 0.0) -> void:
	add_extrusion(PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y),
	]), depth, color, z_center)


## Extrudes a simple (non self-intersecting) polygon. Point order does not matter.
func add_extrusion(points: PackedVector2Array, depth: float, color: Color, z_center: float = 0.0) -> void:
	var front_z: float = z_center + depth * 0.5
	var back_z: float = z_center - depth * 0.5
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	for index: int in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[index]]
		var b: Vector2 = points[indices[index + 1]]
		var c: Vector2 = points[indices[index + 2]]
		_add_triangle(_at(a, front_z), _at(b, front_z), _at(c, front_z), Vector3.BACK, color)
		_add_triangle(_at(a, back_z), _at(b, back_z), _at(c, back_z), Vector3.FORWARD, color)

	var winding: float = 1.0 if _signed_area(points) >= 0.0 else -1.0
	# Sides are slightly darker so edges read clearly without textures.
	var side_color: Color = color.darkened(0.18)
	for index: int in points.size():
		var from: Vector2 = points[index]
		var to: Vector2 = points[(index + 1) % points.size()]
		var edge: Vector2 = to - from
		var outward: Vector2 = Vector2(edge.y, -edge.x).normalized() * winding
		var normal: Vector3 = Vector3(outward.x, outward.y, 0.0)
		_add_triangle(_at(from, front_z), _at(to, front_z), _at(to, back_z), normal, side_color)
		_add_triangle(_at(from, front_z), _at(to, back_z), _at(from, back_z), normal, side_color)


## `texture` is an optional pattern; with one, vertex colors are ignored so
## the drawing shows exactly as painted.
func build(texture: Texture2D = null) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if texture != null:
		material.albedo_texture = texture
	else:
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
	var mesh: ArrayMesh = _tool.commit()
	mesh.surface_set_material(0, material)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func regular_polygon(center: Vector2, radius: float, sides: int, rotation: float = 0.0) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in sides:
		points.append(center + Vector2.from_angle(rotation + index * TAU / sides) * radius)
	return points


## Adds one triangle facing `normal`, fixing the winding as needed
## (Godot front faces are clockwise).
func _add_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
	for vertex: Vector3 in [a, b, c]:
		_tool.set_color(color)
		_tool.set_normal(normal)
		_tool.set_uv(Vector2(
				(vertex.x - _uv_bounds.position.x) / _uv_bounds.size.x,
				1.0 - (vertex.y - _uv_bounds.position.y) / _uv_bounds.size.y))
		_tool.add_vertex(vertex)


static func _at(point: Vector2, z: float) -> Vector3:
	return Vector3(point.x, point.y, z)


static func _signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for index: int in points.size():
		var from: Vector2 = points[index]
		var to: Vector2 = points[(index + 1) % points.size()]
		area += from.x * to.y - to.x * from.y
	return area * 0.5
