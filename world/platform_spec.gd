class_name PlatformSpec
extends RefCounted
## One generated row of the level: a platform plus an optional pickup.

enum Kind { NORMAL, MOVING, TARGET }

var index: int = 0
var kind: Kind = Kind.NORMAL
## Rest position; `rect.end.y` is the stickable top.
var rect: Rect2 = Rect2()
var move_amplitude: float = 0.0
var move_speed: float = 0.0
var move_phase: float = 0.0
var bonus_points: int = 0
var center_bonus_points: int = 0
var center_zone: float = 0.0
var pickup: Pickup = null
