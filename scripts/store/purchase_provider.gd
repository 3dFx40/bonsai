class_name PurchaseProvider
extends RefCounted

## Platform billing adapters will implement this boundary. Disabled in the slice.
func available() -> bool:
	return false

func purchase(_product_id: String) -> Dictionary:
	return {"ok": false, "reason": "Purchases are not enabled in this prototype."}

func restore() -> Array[String]:
	return []
