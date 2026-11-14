class_name Pickup
extends RefCounted
## Floating bonus object collected when the thrown object touches it.

enum Kind { BALLOON, WATERMELON }

var kind: Kind = Kind.BALLOON
var position: Vector2 = Vector2.ZERO
var radius: float = 0.35
var coins: int = 1
var collected: bool = false
