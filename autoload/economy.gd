extends Node
## Coin (earned by playing) and gem (premium) balances, persisted via SaveService.

signal coins_changed(new_amount: int)
signal gems_changed(new_amount: int)

const SAVE_KEY_COINS: String = "coins"
const SAVE_KEY_GEMS: String = "gems"

var coins: int = 0
var gems: int = 0


func _ready() -> void:
	reload()


func reload() -> void:
	coins = maxi(SaveService.get_int(SAVE_KEY_COINS), 0)
	gems = maxi(SaveService.get_int(SAVE_KEY_GEMS), 0)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_set_coins(coins + amount)


func add_gems(amount: int) -> void:
	if amount <= 0:
		return
	_set_gems(gems + amount)


## Returns false and changes nothing when the balance is too low.
func spend_coins(amount: int) -> bool:
	if amount < 0 or amount > coins:
		return false
	_set_coins(coins - amount)
	return true


func spend_gems(amount: int) -> bool:
	if amount < 0 or amount > gems:
		return false
	_set_gems(gems - amount)
	return true


func _set_coins(value: int) -> void:
	coins = value
	SaveService.set_value(SAVE_KEY_COINS, coins)
	coins_changed.emit(coins)


func _set_gems(value: int) -> void:
	gems = value
	SaveService.set_value(SAVE_KEY_GEMS, gems)
	gems_changed.emit(gems)
