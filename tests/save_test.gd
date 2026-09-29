extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var saves := BonsaiSave.new()
	saves.path = "user://test-%d.json" % Time.get_ticks_usec()
	var tree := BonsaiTree.starter()
	var second := BonsaiTree.starter()
	second.id = "second"
	var settings := {"sound": false, "quality": "Medium", "real_seconds_per_day": 3600}
	var doc := saves.make_document([tree, second], tree.id, settings, 1000, 0.1)
	check(saves.valid(doc), "Starter document valid")
	check(saves.write_document(doc), "Write save: " + saves.last_error)
	var loaded := saves.load_document()
	check(loaded.get("trees", []).size() == 2, "Multiple trees roundtrip")
	check(_equivalent(loaded, doc), "All fields persist")
	tree.prune(3)
	var cut := saves.make_document([tree, second], tree.id, settings, 2000, 0.1)
	check(saves.write_document(cut), "Atomic replacement")
	loaded = saves.load_document()
	check(loaded.trees[0].branches.size() == 31, "Pruned topology survives reload")
	var file := FileAccess.open(saves.path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	loaded = saves.load_document()
	check(saves.recovered and loaded.trees[0].branches.size() == 35, "Recover previous valid generation")
	check(saves.write_document(cut), "Repair primary without destroying valid backup")
	var cyclic := doc.duplicate(true)
	cyclic.trees[0].branches[1].parent = 2
	check(not saves.valid(cyclic), "Reject topology cycle")
	var bad_leaf := doc.duplicate(true)
	bad_leaf.trees[0].branches[4].leaves[0].erase("age")
	check(not saves.valid(bad_leaf), "Reject malformed leaf")
	file = FileAccess.open(saves.path, FileAccess.WRITE)
	file.store_string('{"version":999}')
	file.close()
	check(saves.load_document().is_empty() and saves.read_only, "Preserve future-version saves")
	check(not saves.write_document(doc), "Block overwriting newer saves")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(saves.path + suffix): DirAccess.remove_absolute(saves.path + suffix)
	print("Save tests: %d failures" % failures)
	quit(1 if failures else 0)

func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not _equivalent(a[i], b[i]): return false
		return true
	return a == b
