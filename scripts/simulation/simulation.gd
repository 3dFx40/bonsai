class_name BonsaiSimulation
extends RefCounted

const STEP_DAYS := 0.25
const MAX_ACTIVE_OFFLINE_DAYS := 28.0
var species: BonsaiSpecies

func _init(profile: BonsaiSpecies = null) -> void:
	species = profile if profile != null else load("res://resources/species/ficus_microcarpa.tres")

func water(tree: BonsaiTree, amount: float = 0.38) -> void:
	tree.moisture = clampf(tree.moisture + maxf(amount, 0) / tree.water_capacity, 0, 1.8)

func fertilize(tree: BonsaiTree, amount: float = 0.30) -> void:
	tree.nutrients = clampf(tree.nutrients + maxf(amount, 0), 0, 2)

func advance_days(tree: BonsaiTree, days: float) -> int:
	var remaining := clampf(days, 0, 366)
	var steps := 0
	while remaining > 0.0000001:
		var dt := minf(STEP_DAYS, remaining)
		_step(tree, dt)
		remaining -= dt
		steps += 1
	return steps

func _step(tree: BonsaiTree, dt: float) -> void:
	tree.age_days += dt
	var light: float = clampf(tree.environment.light, 0, 1.5)
	var temperature: float = tree.environment.temperature
	var humidity: float = tree.environment.humidity
	var canopy := clampf(tree.leaf_count() / 192.0, 0.15, 2.5)
	var evaporation := 0.023 * (1.4 - humidity) * (0.5 + light)
	var uptake := species.water_use * canopy * tree.root_health
	var excess := maxf(0, tree.moisture - species.moisture_max)
	tree.moisture = maxf(0, tree.moisture - (evaporation + uptake + excess * tree.drainage) * dt)
	var drought := clampf((species.moisture_min - tree.moisture) / species.moisture_min, 0, 1)
	var waterlogged := clampf((tree.moisture - 0.95) / 0.65, 0, 1)
	var salt := clampf((tree.nutrients - 0.95) / 0.85, 0, 1)
	var thermal := clampf(maxf(species.temperature_min - temperature, temperature - species.temperature_max) / 12, 0, 1)
	var humidity_stress := maxf(0, species.humidity_preference - humidity - 0.2) * 0.3
	var pressure := clampf(drought + waterlogged * 0.8 + salt * 0.7 + thermal + humidity_stress, 0, 1)
	tree.stress = lerpf(tree.stress, pressure, 1 - exp(-dt * 0.3))
	# A recoverable floor is intentional: absence never deletes a cared-for tree.
	var damage := pressure * (1.0 - species.stress_tolerance * 0.6) * 0.035
	tree.root_health = clampf(tree.root_health + (0.013 * (1 - pressure) - damage) * dt, 0.18, 1)
	var nutrition := clampf(0.18 + tree.nutrients * species.fertilizer_response * 1.8, 0.12, 1)
	var illumination := clampf(light / species.light_requirement, 0, 1)
	var vigor := (1 - tree.stress) * tree.root_health * illumination * nutrition * (1 - tree.pruning_stress * 0.65)
	var season := 1.0 - species.seasonality * (0.5 + 0.5 * cos(tree.age_days * TAU / 365))
	vigor *= season
	var photosynthesis := illumination * canopy * (1 - tree.stress) * 0.05
	tree.energy = clampf(tree.energy + (photosynthesis - 0.012 - vigor * 0.02) * dt, 0.05, 1.5)
	vigor *= clampf(tree.energy * 1.5, 0.1, 1)
	tree.nutrients = maxf(0, tree.nutrients - (0.004 * vigor + 0.001) * dt)
	tree.root_mass = clampf(tree.root_mass + species.root_growth * vigor * dt, 0.1, 2)
	tree.pruning_stress = maxf(0, tree.pruning_stress - 0.04 * dt)
	var counts: Dictionary = {}
	for branch: BonsaiBranch in tree.branches.values():
		counts[branch.parent_id] = int(counts.get(branch.parent_id, 0)) + 1
	# Snapshot: new buds participate starting with the next step.
	for b: BonsaiBranch in tree.branches.values():
		b.age += dt
		b.health = clampf(b.health + ((1 - pressure) * 0.015 - damage) * dt, 0.15, 1)
		b.energy = clampf(b.energy + (vigor * 0.06 - 0.02) * dt, 0, 1.5)
		var is_tip := not counts.has(b.id)
		var extension := species.growth_speed * vigor * (1.0 if is_tip else 0.08)
		var max_length := 0.95 if b.parent_id < 0 else species.internode_length * 7
		var low_light_stretch := 1.0 + (1 - illumination) * 0.75
		if b.length < max_length * low_light_stretch:
			b.length = minf(max_length * low_light_stretch, b.length + extension * low_light_stretch * dt)
		b.thickness = minf(0.24 if b.parent_id < 0 else 0.11, b.thickness + vigor * dt * (0.00045 if b.parent_id < 0 else 0.00016))
		for leaf: Dictionary in b.leaves:
			leaf.age += dt
			leaf.size = minf(species.leaf_size, leaf.size + vigor * dt * 0.15)
			leaf.health = clampf(leaf.health + ((1 - pressure) * 0.02 - damage * 1.4 - maxf(0, 0.25 - light) * 0.04) * dt, 0, 1)
		b.leaves = b.leaves.filter(func(leaf: Dictionary) -> bool: return leaf.age < species.leaf_lifespan_days and leaf.health > 0.16)
		if is_tip and b.leaves.size() < BonsaiTree.MAX_LEAVES and b.energy > 0.5 and vigor > 0.15:
			tree.add_leaf(b, clampf(0.4 + b.leaves.size() * 0.034, 0.2, 0.98))
			b.energy -= 0.13
		if b.buds > 0 and (is_tip or b.pruned) and int(counts.get(b.id, 0)) < 4:
			b.bud_charge += species.branching_tendency * vigor * dt * (species.pruning_response if b.pruned else 1.0)
			if b.bud_charge >= 1 and b.energy > 0.2 and tree.branches.size() < BonsaiTree.MAX_BRANCHES:
				_sprout(tree, b)

func _sprout(tree: BonsaiTree, parent: BonsaiBranch) -> void:
	var angle := tree.next_id * 2.399
	var light: Array = tree.environment.light_direction
	var direction := (parent.direction * 0.35 + Vector3(cos(angle) * 0.7, 0.8, sin(angle) * 0.7) + Vector3(light[0], light[1], light[2]) * 0.18).normalized()
	var b := tree.add_branch(parent.id, 0.7 if parent.pruned else 0.95, direction, species.internode_length, maxf(0.005, parent.thickness * 0.3))
	tree.add_leaf(b, 0.6)
	tree.add_leaf(b, 0.95)
	parent.bud_charge -= 1
	parent.buds -= 1
	parent.energy -= 0.2
	parent.pruned = false
