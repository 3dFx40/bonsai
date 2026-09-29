extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var sim := BonsaiSimulation.new()
	var tree := BonsaiTree.starter()
	var original_length: float = tree.branches[4].length
	var original_radius: float = tree.branches[0].thickness
	sim.advance_days(tree, 3)
	check(tree.branches[4].length > original_length, "Branch must extend")
	check(tree.branches[0].thickness > original_radius, "Trunk must thicken")
	check(tree.leaf_count() > 192, "Leaves must appear")
	check(tree.moisture < 0.66, "Moisture must decline")
	sim.water(tree)
	check(tree.moisture > 0.66, "Water must replenish soil")
	var dry := BonsaiTree.starter()
	dry.moisture = 0
	sim.advance_days(dry, 12)
	check(dry.root_health < 0.9 and dry.stress > 0.8, "Drought must stress roots gradually")
	var wet := BonsaiTree.starter()
	wet.nutrients = 2
	for i in range(12):
		sim.water(wet, 2)
		sim.advance_days(wet, 1)
	check(wet.root_health < 0.9, "Repeated overwatering and overfeeding must harm roots")
	var cut := BonsaiTree.starter()
	cut.prune(3)
	var next := cut.next_id
	for i in range(7):
		cut.moisture = 0.65
		sim.advance_days(cut, 1)
	check(cut.next_id > next, "Pruning must activate nearby buds")
	var online := BonsaiTree.starter()
	var offline := BonsaiTree.starter()
	var a := BonsaiClock.new()
	var b := BonsaiClock.new()
	for i in range(720):
		a.advance(online, sim, 60)
	b.advance(offline, sim, 43200, true)
	check(is_equal_approx(online.moisture, offline.moisture), "Online/offline step equivalence")
	check(online.branches.size() == offline.branches.size(), "Online/offline topology equivalence")
	var result := b.advance(offline, sim, 86400 * 365 * 10, true)
	check(result.steps <= 112, "Ten-year absence must use bounded work")
	check(offline.root_health >= 0.18 and offline.branches.size() > 0, "Long absence must preserve recoverable tree")
	var age := offline.age_days
	b.advance(offline, sim, -100, true)
	check(offline.age_days == age, "Clock rollback cannot age tree")
	print("Simulation tests: %d failures" % failures)
	quit(1 if failures else 0)
