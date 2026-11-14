class_name TestCourse
extends RefCounted
## Hand-laid greybox climb used to tune core feel in Phase 1.
## Replaced by the seeded procedural generator in Phase 2.

const WALL_X: float = 3.2
const WALL_THICKNESS: float = 4.0
const PLANK_THICKNESS: float = 0.4
const START_X: float = -1.9
const NOMINAL_STEP: float = 2.0
const NOMINAL_COUNT: int = 4
const VARIED_STEPS: PackedFloat32Array = [1.8, 2.2, 2.0, 1.7, 2.3]
const LENGTHS: PackedFloat32Array = [2.3, 2.0, 2.3, 1.8]


## Vertical distance from the previous surface top to plank `index`'s top.
static func step_height(index: int) -> float:
	if index < NOMINAL_COUNT:
		return NOMINAL_STEP
	return VARIED_STEPS[(index - NOMINAL_COUNT) % VARIED_STEPS.size()]


## Planks alternate sides, starting on the right, and are attached to the wall.
static func plank_rect(index: int, top_y: float) -> Rect2:
	var length: float = LENGTHS[index % LENGTHS.size()]
	var left: float = WALL_X - length if index % 2 == 0 else -WALL_X
	return Rect2(left, top_y - PLANK_THICKNESS, length, PLANK_THICKNESS)


static func floor_rect() -> Rect2:
	return Rect2(-WALL_X, -1.0, WALL_X * 2.0, 1.0)


static func wall_rect(side: int) -> Rect2:
	var left: float = WALL_X if side > 0 else -WALL_X - WALL_THICKNESS
	return Rect2(left, -1000.0, WALL_THICKNESS, 1000000.0)
