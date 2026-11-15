class_name SkinCatalog
extends Resource
## Ordered list of every skin in the game. The first one is the starter skin.

@export var skins: Array[SkinData] = []


func find(skin_id: StringName) -> SkinData:
	for skin: SkinData in skins:
		if skin.id == skin_id:
			return skin
	return skins[0]


func index_of(skin_id: StringName) -> int:
	for index: int in skins.size():
		if skins[index].id == skin_id:
			return index
	return 0
