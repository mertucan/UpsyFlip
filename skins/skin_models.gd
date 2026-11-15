class_name SkinModels
extends RefCounted
## Procedural low-poly models for skins. Local +X is forward and the origin is
## the pivot, matching the SkinData shape values.
##
## A user-drawn pattern at res://art/user/skins/<skin id>.png replaces the
## flat placeholder colors. See docs/ART_GUIDE.md for sizes.

const USER_TEXTURE_PATTERN: String = "res://art/user/skins/%s.png"

## Side-view bounds (meters) each model's texture is mapped onto.
const UV_BOUNDS: Dictionary[StringName, Rect2] = {
	&"knife": Rect2(-0.5, -0.15, 1.1, 0.3),
	&"axe": Rect2(-0.5, -0.32, 1.1, 0.44),
	&"shuriken": Rect2(-0.42, -0.42, 0.84, 0.84),
	&"boomerang": Rect2(-0.45, -0.45, 0.95, 0.9),
	&"pistol": Rect2(-0.12, -0.42, 0.7, 0.54),
}


static func build(skin: SkinData) -> Node3D:
	if skin.model_scene != null:
		return skin.model_scene.instantiate() as Node3D
	var builder: LowPoly = LowPoly.new(UV_BOUNDS.get(skin.model_id, UV_BOUNDS[&"knife"]))
	match skin.model_id:
		&"axe":
			_axe(builder, skin)
		&"shuriken":
			_shuriken(builder, skin)
		&"boomerang":
			_boomerang(builder, skin)
		&"pistol":
			_pistol(builder, skin)
		_:
			_knife(builder, skin)
	var model: Node3D = Node3D.new()
	model.add_child(builder.build(user_texture(skin)))
	return model


static func user_texture(skin: SkinData) -> Texture2D:
	var path: String = USER_TEXTURE_PATTERN % skin.id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _knife(builder: LowPoly, skin: SkinData) -> void:
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.05, 0.08), Vector2(0.4, 0.08), Vector2(0.5, 0.045),
		Vector2(0.5, -0.03), Vector2(0.38, -0.08), Vector2(-0.05, -0.08),
	]), 0.04, skin.primary_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.5, 0.045), Vector2(0.6, 0.0), Vector2(0.5, -0.03),
	]), 0.04, skin.accent_color)
	builder.add_box(Rect2(-0.1, -0.13, 0.06, 0.26), 0.1, skin.accent_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.1, 0.09), Vector2(-0.44, 0.09), Vector2(-0.5, 0.04),
		Vector2(-0.5, -0.04), Vector2(-0.44, -0.09), Vector2(-0.1, -0.09),
	]), 0.12, skin.secondary_color)


static func _axe(builder: LowPoly, skin: SkinData) -> void:
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.5, 0.05), Vector2(0.5, 0.045), Vector2(0.5, -0.045), Vector2(-0.5, -0.05),
	]), 0.08, skin.secondary_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.2, 0.12), Vector2(0.48, 0.12), Vector2(0.5, -0.06),
		Vector2(0.56, -0.24), Vector2(0.12, -0.24), Vector2(0.18, -0.06),
	]), 0.1, skin.primary_color)
	# Cutting edge.
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.12, -0.24), Vector2(0.56, -0.24), Vector2(0.34, -0.3),
	]), 0.05, skin.accent_color)


static func _shuriken(builder: LowPoly, skin: SkinData) -> void:
	var star: PackedVector2Array = PackedVector2Array()
	for index: int in 8:
		var radius: float = 0.42 if index % 2 == 0 else 0.15
		star.append(Vector2.from_angle(index * TAU / 8.0) * radius)
	builder.add_extrusion(star, 0.04, skin.primary_color)
	builder.add_extrusion(LowPoly.regular_polygon(Vector2.ZERO, 0.11, 8), 0.07, skin.accent_color)


static func _boomerang(builder: LowPoly, skin: SkinData) -> void:
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.45, 0.38), Vector2(-0.3, 0.45), Vector2(0.5, 0.0),
		Vector2(-0.3, -0.45), Vector2(-0.45, -0.38), Vector2(0.15, 0.0),
	]), 0.06, skin.primary_color)
	# Painted bands near the arm ends and on the nose.
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.45, 0.38), Vector2(-0.3, 0.45), Vector2(-0.18, 0.38), Vector2(-0.32, 0.3),
	]), 0.07, skin.accent_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.45, -0.38), Vector2(-0.32, -0.3), Vector2(-0.18, -0.38), Vector2(-0.3, -0.45),
	]), 0.07, skin.accent_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.34, 0.09), Vector2(0.5, 0.0), Vector2(0.34, -0.09), Vector2(0.28, 0.0),
	]), 0.07, skin.secondary_color)


## Deliberately toy-like: chunky, brightly colored, with an orange muzzle cap
## and an oversized grapple hook under the barrel.
static func _pistol(builder: LowPoly, skin: SkinData) -> void:
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.12, 0.11), Vector2(0.44, 0.11), Vector2(0.44, -0.09), Vector2(-0.12, -0.09),
	]), 0.14, skin.primary_color)
	builder.add_box(Rect2(0.44, -0.08, 0.06, 0.18), 0.16, skin.secondary_color)
	builder.add_box(Rect2(-0.06, 0.11, 0.38, 0.03), 0.08, skin.accent_color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(-0.1, -0.09), Vector2(0.08, -0.09), Vector2(0.03, -0.22), Vector2(-0.12, -0.22),
	]), 0.12, skin.secondary_color)
	# Grapple hook: the part that catches on surfaces.
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.3, -0.09), Vector2(0.44, -0.09), Vector2(0.42, -0.3), Vector2(0.38, -0.42), Vector2(0.33, -0.3),
	]), 0.06, skin.accent_color)
