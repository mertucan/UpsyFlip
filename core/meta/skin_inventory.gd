class_name SkinInventory
extends RefCounted
## Which skins the player owns and which one is selected. Pure logic.

var owned: Array[StringName] = []
var selected: StringName = &""


## Guarantees the starter skin is owned and the selection is valid.
func ensure_valid(starter_id: StringName) -> void:
	if not owned.has(starter_id):
		owned.append(starter_id)
	if not owned.has(selected):
		selected = starter_id


func owns(skin_id: StringName) -> bool:
	return owned.has(skin_id)


func add(skin_id: StringName) -> void:
	if not owned.has(skin_id):
		owned.append(skin_id)


func select(skin_id: StringName) -> bool:
	if not owned.has(skin_id):
		return false
	selected = skin_id
	return true


## Price of `skin` in the chosen currency; 0 means not sold for that currency.
static func price_of(skin: SkinData, with_gems: bool) -> int:
	return skin.price_gems if with_gems else skin.price_coins


func can_buy(skin: SkinData, with_gems: bool, balance: int) -> bool:
	var price: int = price_of(skin, with_gems)
	return not owns(skin.id) and not skin.exclusive and price > 0 and balance >= price


## The cheapest coin-priced skin not yet owned, or null when all are owned.
func next_coin_goal(skins: Array[SkinData]) -> SkinData:
	var goal: SkinData = null
	for skin: SkinData in skins:
		if owns(skin.id) or skin.exclusive or skin.price_coins <= 0:
			continue
		if goal == null or skin.price_coins < goal.price_coins:
			goal = skin
	return goal


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for skin_id: StringName in owned:
		ids.append(String(skin_id))
	return {"owned": ids, "selected": String(selected)}


func from_dict(data: Dictionary) -> void:
	owned.clear()
	var ids: Variant = data.get("owned")
	if ids is Array:
		for skin_id: Variant in ids:
			add(StringName(str(skin_id)))
	selected = StringName(str(data.get("selected", "")))
