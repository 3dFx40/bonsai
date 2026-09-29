class_name StoreService
extends RefCounted

var provider := PurchaseProvider.new()
var entitlements := EntitlementService.new()
var catalog: Array[Dictionary] = [
	{"id": "ficus_microcarpa", "kind": "species", "included": true},
	{"id": "slate_rectangle", "kind": "pot", "included": true},
	{"id": "daylight_studio", "kind": "environment", "included": true}
]

func request_purchase(product_id: String) -> Dictionary:
	return provider.purchase(product_id)
