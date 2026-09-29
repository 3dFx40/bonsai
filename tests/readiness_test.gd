extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var tree := BonsaiTree.starter()
	if not tree.has_method("trim"):
		check(false, "Partial pruning must be available")
		quit(1)
		return
	var origin_before := tree.point(3, 0.4)
	var twig_before := tree.point(4, 0)
	check(tree.call("trim", 3, 0.65), "Shorten a branch")
	check(tree.branches.has(3) and tree.branches.has(4), "Retain cut branch and proximal shoot")
	check(not tree.branches.has(5) and not tree.branches.has(6), "Remove distal shoots")
	check(tree.point(3, 0.4 / 0.65).is_equal_approx(origin_before), "Keep the retained curve in place")
	check(tree.point(4, 0).is_equal_approx(twig_before), "Keep proximal shoot attachment in place")
	check(not tree.call("trim", 0, 0.5), "Protect main trunk")
	check(not tree.call("trim", 3, 0.0), "Reject degenerate cuts")
	var before := tree.to_data()
	check(tree.call("shape", 3, 0.3, 0.2), "Shape the branch and its subtree")
	check(not tree.point(3, 1).is_equal_approx(BonsaiTree.from_data(before).point(3, 1)), "Shaping changes the silhouette")
	check(tree.point(4, 0).is_equal_approx(tree.point(3, tree.branches[4].attachment)), "Shaped child remains attached")
	check(tree.call("remember", "First portrait"), "Save first portrait")
	for i in range(20):
		tree.age_days += 1
		tree.call("remember", "Portrait")
	check(tree.get("memories").size() == 12, "Portrait history stays bounded")
	var saves := BonsaiSave.new()
	var settings := {"sound": false, "quality": "Medium", "real_seconds_per_day": 3600}
	var doc := saves.make_document([tree], tree.id, settings, 1000, 0)
	check(saves.valid(doc), "Shaped tree and portraits can be saved")
	var legacy := doc.duplicate(true)
	legacy.version = 1
	legacy.trees[0].erase("memories")
	legacy.trees[0].erase("display_name")
	for b in legacy.trees[0].branches: b.erase("curve_span")
	check(saves.valid(saves.migrate(legacy)), "Migrate version 1 without losing the original tree")
	var clone := BonsaiTree.from_data(tree.to_data())
	check(clone.to_data() == tree.to_data(), "Shaping and portraits roundtrip")
	var invalid := doc.duplicate(true)
	invalid.trees[0].memories[0].tree.branches[1].parent = 1
	check(not saves.valid(invalid), "Imported portraits must reject cycles")
	check(tree.call("care_advice") is String, "Care advice available")
	tree.moisture = 1.3
	check(String(tree.call("care_advice")).contains("drain"), "Explain overwatering")
	tree.moisture = 0.1
	check(String(tree.call("care_advice")).contains("dry"), "Explain drought")
	var mature := BonsaiTree.starter()
	var sim := BonsaiSimulation.new()
	for day in range(730):
		mature.moisture = 0.65
		mature.nutrients = 0.55
		if day % 30 == 0:
			for key in mature.branches.keys():
				if key != 0 and mature.children(key).is_empty():
					mature.trim(key, 0.7)
					break
		sim.advance_days(mature, 1)
		if day % 60 == 0: mature.remember("Portrait")
	check(mature.branches.size() <= BonsaiTree.MAX_BRANCHES, "Two years of care respect geometry budget")
	check(saves.valid(saves.make_document([mature], mature.id, settings, 1000, 0)), "Mature tree stays saveable after repeated trimming")
	check(JSON.stringify(mature.to_data()).length() < 16000000, "Portrait history stays inside save file budget")
	print("Readiness tests: %d failures" % failures)
	quit(1 if failures else 0)
