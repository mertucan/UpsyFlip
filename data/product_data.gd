class_name ProductData
extends Resource
## One in-app product. `id` must match the product ID in Play Console;
## prices are never stored here, they come from the store.

@export var id: StringName = &""
@export var title: String = ""
## Consumables can be bought repeatedly; non-consumables only once.
@export var consumable: bool = true

@export_group("Grants")
@export var coins: int = 0
@export var gems: int = 0
@export var removes_ads: bool = false
@export var skin_id: StringName = &""


## Short English summary of what the product gives.
func grants_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if removes_ads:
		parts.append(tr("No ads"))
	if skin_id != &"":
		parts.append(tr("Exclusive skin"))
	if coins > 0:
		parts.append(tr("%d coins") % coins)
	if gems > 0:
		parts.append(tr("%d gems") % gems)
	return " + ".join(parts)
