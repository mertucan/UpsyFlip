extends Node
## Coin and gem balances. Skeleton; implemented in Phase 5.

signal coins_changed(new_amount: int)
signal gems_changed(new_amount: int)

var coins: int = 0
var gems: int = 0


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)
