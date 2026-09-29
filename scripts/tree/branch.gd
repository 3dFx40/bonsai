class_name BonsaiBranch
extends RefCounted

var id: int
var parent_id := -1
var attachment := 1.0
var direction := Vector3.UP
var length := 0.3
var thickness := 0.02
var age := 0.0
var health := 1.0
var energy := 0.4
var buds := 2
var bud_charge := 0.0
var pruned := false
var bend := Vector3.ZERO
var wiring: Dictionary = {}
var leaves: Array = []

func to_data() -> Dictionary:
	return {"id": id, "parent": parent_id, "attachment": attachment,
		"direction": [direction.x, direction.y, direction.z], "length": length,
		"thickness": thickness, "age": age, "health": health, "energy": energy,
		"buds": buds, "bud_charge": bud_charge, "pruned": pruned,
		"bend": [bend.x, bend.y, bend.z], "wiring": wiring.duplicate(true),
		"leaves": leaves.duplicate(true)}

static func from_data(data: Dictionary) -> BonsaiBranch:
	var b := BonsaiBranch.new()
	b.id = int(data.id)
	b.parent_id = int(data.parent)
	b.attachment = float(data.attachment)
	b.direction = Vector3(data.direction[0], data.direction[1], data.direction[2])
	b.length = float(data.length)
	b.thickness = float(data.thickness)
	b.age = float(data.age)
	b.health = float(data.health)
	b.energy = float(data.energy)
	b.buds = int(data.buds)
	b.bud_charge = float(data.get("bud_charge", 0))
	b.pruned = bool(data.pruned)
	b.bend = Vector3(data.bend[0], data.bend[1], data.bend[2])
	b.wiring = data.get("wiring", {}).duplicate(true)
	b.leaves = data.leaves.duplicate(true)
	return b
