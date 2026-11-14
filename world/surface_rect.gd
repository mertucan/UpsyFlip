class_name SurfaceRect
extends RefCounted
## Axis-aligned collision rectangle in the X-Y gameplay plane (Y up).
## Each face is either stickable or bouncy.

enum Face { TOP = 1, BOTTOM = 2, LEFT = 4, RIGHT = 8 }

const FACES_NONE: int = 0
const FACES_TOP_AND_SIDES: int = Face.TOP | Face.LEFT | Face.RIGHT


class Hit:
	extends RefCounted
	var face: int = Face.TOP
	var point: Vector2 = Vector2.ZERO
	## Points away from the surface.
	var normal: Vector2 = Vector2.UP


var rect: Rect2
var stick_faces: int = FACES_TOP_AND_SIDES
## Permanent surfaces (side walls) are never culled.
var permanent: bool = false


func _init(p_rect: Rect2 = Rect2(), p_stick_faces: int = FACES_TOP_AND_SIDES) -> void:
	rect = p_rect
	stick_faces = p_stick_faces


func is_stickable(face: int) -> bool:
	return (stick_faces & face) != 0


func contains(point: Vector2) -> bool:
	return rect.has_point(point)


static func face_normal(face: int) -> Vector2:
	match face:
		Face.TOP:
			return Vector2(0.0, 1.0)
		Face.BOTTOM:
			return Vector2(0.0, -1.0)
		Face.LEFT:
			return Vector2(-1.0, 0.0)
		_:
			return Vector2(1.0, 0.0)


## Finds where a point moving from `from` (outside) to `to` (inside) crossed
## the rectangle boundary.
func find_entry(from: Vector2, to: Vector2) -> Hit:
	var hit: Hit = Hit.new()
	var low: Vector2 = rect.position
	var high: Vector2 = rect.end
	if rect.has_point(from):
		hit.face = _nearest_face(to)
		hit.point = to
		hit.normal = face_normal(hit.face)
		return hit

	var travel: Vector2 = to - from
	var time_x: float = -INF
	var face_x: int = Face.LEFT
	if travel.x > 0.0:
		time_x = (low.x - from.x) / travel.x
	elif travel.x < 0.0:
		time_x = (high.x - from.x) / travel.x
		face_x = Face.RIGHT
	var time_y: float = -INF
	var face_y: int = Face.BOTTOM
	if travel.y > 0.0:
		time_y = (low.y - from.y) / travel.y
	elif travel.y < 0.0:
		time_y = (high.y - from.y) / travel.y
		face_y = Face.TOP

	var time: float = time_x
	hit.face = face_x
	if time_y > time_x:
		time = time_y
		hit.face = face_y
	hit.point = from + travel * clampf(time, 0.0, 1.0)
	hit.normal = face_normal(hit.face)
	return hit


func _nearest_face(point: Vector2) -> int:
	var best_face: int = Face.TOP
	var best_distance: float = absf(rect.end.y - point.y)
	var candidates: Dictionary[int, float] = {
		Face.BOTTOM: absf(point.y - rect.position.y),
		Face.LEFT: absf(point.x - rect.position.x),
		Face.RIGHT: absf(rect.end.x - point.x),
	}
	for face: int in candidates:
		if candidates[face] < best_distance:
			best_distance = candidates[face]
			best_face = face
	return best_face
