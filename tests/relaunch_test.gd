extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var saves := BonsaiSave.new()
	saves.path = "user://relaunch-%d.json" % Time.get_ticks_usec()
	var tree := BonsaiTree.starter()
	tree.id = "relaunch-fixture"
	tree.prune(3)
	var settings := {"sound": true, "quality": "Low", "real_seconds_per_day": 3600}
	check(saves.write_document(saves.make_document([tree], tree.id, settings, Time.get_unix_time_from_system() - 3600, 0)), "Seed closed-app save")
	var scene := load("res://scenes/main.tscn")
	var first = scene.instantiate()
	first.saves.path = saves.path
	root.add_child(first)
	await process_frame
	check(first.tree.id == tree.id, "Reopened app must load same tree")
	check(not first.tree.branches.has(3), "Reopened app must preserve cut")
	check(first.settings.real_seconds_per_day == 10800, "Legacy default upgrades to three real hours per day")
	check(first.tree.age_days >= 0.25 and first.tree.age_days < 0.5, "Reopened app processes one hour offline at the new rate")
	check(first.settings.sound and first.settings.quality == "Low", "Reopened app must restore player settings")
	check(first.settings.language in ["en", "he"], "Legacy saves must receive a supported language")
	first._language("he")
	first._save()
	var age: float = first.tree.age_days
	first.queue_free()
	await process_frame
	var second = scene.instantiate()
	second.saves.path = saves.path
	root.add_child(second)
	await process_frame
	check(is_equal_approx(second.tree.age_days, age), "Second launch must not replay offline time twice")
	check(second.settings.language == "he" and TranslationServer.get_locale().begins_with("he"), "Selected Hebrew must survive reopening")
	second.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(saves.path + suffix): DirAccess.remove_absolute(saves.path + suffix)
	print("Relaunch tests: %d failures" % failures)
	quit(1 if failures else 0)
