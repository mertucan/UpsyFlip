class_name ScoreKeeper
extends RefCounted
## Per-run score: maximum height reached (whole meters) plus bonus points.

var height: int = 0
var bonus: int = 0
var coins: int = 0


## Returns true when `y` is a new maximum height.
func register_height(y: float) -> bool:
	var meters: int = maxi(floori(y), 0)
	if meters <= height:
		return false
	height = meters
	return true


func add_bonus(points: int) -> void:
	bonus += maxi(points, 0)


func add_coins(amount: int) -> void:
	coins += maxi(amount, 0)


func total() -> int:
	return height + bonus
