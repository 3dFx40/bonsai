class_name BonsaiTree
extends RefCounted

const MAX_BRANCHES := 180
const MAX_LEAVES := 18
var id := "ficus-001"
var species_id := "ficus_microcarpa"
var acquired_at := 0.0
var age_days := 0.0
var branches: Dictionary = {}
var next_id := 0
var moisture := 0.66
var nutrients := 0.55
var root_health := 1.0
var root_mass := 0.5
var energy := 0.8
var stress := 0.0
var pruning_stress := 0.0
var water_capacity := 1.0
var drainage := 0.22
var environment := {"id": "daylight_studio", "light": 0.8, "temperature": 24.0, "humidity": 0.6, "light_direction": [-0.6, 0.8, -0.2]}
var pot_id := "slate_rectangle"
var history: Array = []
var roots: Array = []

func add_branch(parent: int, at: float, dir: Vector3, size: float, radius: float) -> BonsaiBranch:
	var b := BonsaiBranch.new()
	b.id = next_id
	next_id += 1
	b.parent_id = parent
	b.attachment = at
	b.direction = dir.normalized()
	b.length = size
	b.thickness = radius
	b.bend = Vector3(sin(b.id * 2.1), 0.2, cos(b.id * 1.7)) * size * 0.12
	branches[b.id] = b
	return b

func add_leaf(b: BonsaiBranch, at: float) -> void:
	if b.leaves.size() >= MAX_LEAVES:
		return
	b.leaves.append({"at": at, "age": 0.0, "health": 1.0,
		"angle": fmod(b.id * 2.399 + b.leaves.size() * 2.399 + age_days * 0.13, TAU), "size": 0.5})

static func starter() -> BonsaiTree:
	var tree := BonsaiTree.new()
	var trunk := tree.add_branch(-1, 0, Vector3(0.17, 1, 0), 0.70, 0.145)
	trunk.bend = Vector3(-0.13, 0.02, 0.03)
	var leader := tree.add_branch(trunk.id, 1, Vector3(-0.27, 1, 0.05), 0.64, 0.087)
	var crown := tree.add_branch(leader.id, 1, Vector3(0.4, 1, -0.08), 0.43, 0.049)
	for i in range(8):
		var parent: int = trunk.id if i < 3 else (leader.id if i < 6 else crown.id)
		var angle := i * 2.399 + 0.4
		var dir := Vector3(cos(angle), 0.38 + 0.08 * (i % 3), sin(angle))
		var arm := tree.add_branch(parent, 0.60 + 0.18 * (i % 3), dir, 0.70 - i * 0.045, 0.041 - i * 0.0025)
		for j in range(3):
			var twig_dir := (dir.normalized() * 0.4 + Vector3(cos(angle + j - 1), 0.85, sin(angle + j - 1))).normalized()
			var twig := tree.add_branch(arm.id, 0.48 + j * 0.24, twig_dir, 0.28 + 0.06 * j, 0.015)
			for k in range(8):
				tree.add_leaf(twig, 0.25 + k * 0.10)
				twig.leaves[k].size = 1.0
	for i in range(7):
		tree.roots.append({"angle": i * TAU / 7, "length": 0.24 + 0.07 * sin(i * 3.0), "thickness": 0.035})
	return tree

func origin(branch_id: int) -> Vector3:
	var b: BonsaiBranch = branches[branch_id]
	if b.parent_id < 0:
		return Vector3(0, 0.3, 0)
	return point(b.parent_id, b.attachment)

func point(branch_id: int, t: float) -> Vector3:
	var b: BonsaiBranch = branches[branch_id]
	return origin(branch_id) + b.direction * b.length * t + b.bend * sin(t * PI)

func children(branch_id: int) -> Array[int]:
	var result: Array[int] = []
	for b: BonsaiBranch in branches.values():
		if b.parent_id == branch_id:
			result.append(b.id)
	return result

func descendants(branch_id: int) -> Array[int]:
	var result: Array[int] = [branch_id]
	var cursor := 0
	while cursor < result.size():
		result.append_array(children(result[cursor]))
		cursor += 1
	return result

func prune(branch_id: int) -> bool:
	if not branches.has(branch_id) or branches[branch_id].parent_id < 0:
		return false
	var parent: BonsaiBranch = branches[branches[branch_id].parent_id]
	var removed := descendants(branch_id)
	for key in removed:
		branches.erase(key)
	parent.pruned = true
	parent.buds = mini(parent.buds + 2, 5)
	parent.bud_charge = maxf(parent.bud_charge, 0.8)
	parent.energy = minf(1.5, parent.energy + 0.35)
	pruning_stress = minf(1, pruning_stress + 0.12 + removed.size() * 0.008)
	history.append({"day": age_days, "action": "prune", "branch": branch_id, "removed": removed.size()})
	if history.size() > 256:
		history.pop_front()
	return true

func leaf_count() -> int:
	var count := 0
	for b: BonsaiBranch in branches.values():
		count += b.leaves.size()
	return count

func to_data() -> Dictionary:
	var rows: Array = []
	for b: BonsaiBranch in branches.values():
		rows.append(b.to_data())
	return {"id": id, "species": species_id, "acquired_at": acquired_at,
		"age_days": age_days, "next_id": next_id, "branches": rows,
		"moisture": moisture, "nutrients": nutrients, "root_health": root_health,
		"root_mass": root_mass, "energy": energy, "stress": stress,
		"pruning_stress": pruning_stress, "water_capacity": water_capacity,
		"drainage": drainage, "environment": environment.duplicate(true),
		"pot": pot_id, "history": history.duplicate(true), "roots": roots.duplicate(true)}

static func from_data(data: Dictionary) -> BonsaiTree:
	var tree := BonsaiTree.new()
	tree.id = data.id
	tree.species_id = data.species
	tree.acquired_at = float(data.acquired_at)
	tree.age_days = float(data.age_days)
	tree.next_id = int(data.next_id)
	for row in data.branches:
		var b := BonsaiBranch.from_data(row)
		tree.branches[b.id] = b
	for key in ["moisture", "nutrients", "root_health", "root_mass", "energy", "stress", "pruning_stress", "water_capacity", "drainage"]:
		tree.set(key, float(data[key]))
	tree.environment = data.environment.duplicate(true)
	tree.pot_id = data.pot
	tree.history = data.history.duplicate(true)
	tree.roots = data.roots.duplicate(true)
	return tree
