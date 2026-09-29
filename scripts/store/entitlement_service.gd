class_name EntitlementService
extends RefCounted

var owned_items: Array[String] = ["ficus_microcarpa", "slate_rectangle", "daylight_studio"]
var owned_trees: Array[String] = ["ficus-001"]

func owns(item_id: String) -> bool:
	return item_id in owned_items

func restore_local(items: Array, trees: Array) -> void:
	owned_items.assign(items)
	owned_trees.assign(trees)
