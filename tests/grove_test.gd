extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game = scene.instantiate()
	var filename := "user://grove-test-%d.json" % Time.get_ticks_usec()
	game.saves.path = filename
	root.add_child(game)
	await process_frame
	game.settings.onboarded = true
	game._finish_creation("ficus_microcarpa", "slate_rectangle", "")
	game._begin_creation()
	game._finish_creation("olea_europaea", "ivory_round", "הזית שלי")
	var olive: BonsaiTree = game.tree
	game._begin_creation()
	game._finish_creation("salix_babylonica", "blue_rectangle", "הערבה שלי")
	var willow: BonsaiTree = game.tree
	check(game.trees.size() == 3, "Creating trees retains every existing tree")
	check(olive.branches[0].thickness > willow.branches[0].thickness, "Olive has a visibly heavier trunk")
	check(olive.branches[3].direction.y > willow.branches[3].direction.y, "Willow starts with cascading branches")
	var olive_length: float = olive.branches[11].length
	var willow_length: float = willow.branches[11].length
	var previous_pending: float = game.clock.pending_days
	var result: Dictionary = game.clock.advance_grove(game.trees, willow, 8 * 3600, true)
	check(is_equal_approx(result.days + game.clock.pending_days - previous_pending, 8.0 / 3.0), "Eight hours equal 2.67 biological days including remainder")
	check(is_equal_approx(olive.age_days, willow.age_days), "Inactive trees age alongside the active tree")
	check(olive.moisture > willow.moisture, "Willow consumes noticeably more water than olive")
	check(willow.branches[11].length - willow_length > olive.branches[11].length - olive_length, "Willow grows faster than olive")
	for specimen: BonsaiTree in game.trees:
		check(specimen.root_health > 0.95 and specimen.stress < 0.15, "Healthy trees remain healthy after eight hours asleep")
	game._language("he")
	game.hud.open_panel("collection")
	await process_frame
	check(game.hud.collection_list.get_child_count() == 3 and not game.orbit.input_enabled, "Collection shows all trees and blocks room input")
	check(game.hud.modal_title.text == "האוסף שלי", "Collection is translated")
	# Invoke the actual gallery action to cover signal binding and per-card identity.
	var card: Node = game.hud.collection_list.get_child(1)
	var caption: Node = card.get_child(0).get_child(1)
	caption.get_child(3).pressed.emit()
	check(game.tree == olive and game.sim.species.id == "olea_europaea", "Gallery selects the correct tree and simulation profile")
	check(game.studio.pot_id == "ivory_round" and game.hud.title.text == "הזית שלי", "Switch restores planter and personal name")
	check(game.renderer.selected_id == -1 and not game.hud.modal.visible, "Switch clears branch selection and closes the collection")
	var willow_water := willow.moisture
	game._tool("water")
	game._action()
	check(is_equal_approx(willow.moisture, willow_water), "Care affects only the selected tree")
	game._select_tree(willow.id)
	check(game.tree == willow and game.hud.title.text == "הערבה שלי", "Switching back retains the other tree")
	# Persist a grove with shared partial time and reopen without replaying that time.
	game._save()
	var age := willow.age_days
	var pending: float = game.clock.pending_days
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.saves.path = filename
	root.add_child(game)
	await process_frame
	check(game.trees.size() == 3 and game.tree.id == willow.id, "Reopening retains the whole collection and selected tree")
	check(is_equal_approx(game.tree.age_days, age) and absf(game.clock.pending_days - pending) < 0.01, "Reopening does not repeat simulation or lose partial time")
	# Incoming backups advance the whole grove at the migrated default rate.
	game.pending_restore = game.saves.load_document()
	game.pending_restore.settings.real_seconds_per_day = 3600
	game.pending_restore.last_real_timestamp -= 10800
	game._restore_backup()
	check(game.clock.real_seconds_per_day == 10800, "Imported legacy saves adopt the new default")
	for specimen: BonsaiTree in game.trees:
		check(specimen.age_days >= age + 1, "Every imported tree receives offline time")
	# Rate migration preserves explicitly customized pacing.
	var custom := {"real_seconds_per_day": 7200.0}
	BonsaiClock.upgrade_rate(custom)
	check(custom.real_seconds_per_day == 7200, "Customized time rates remain intact")
	var daylight = game.studio
	daylight.time_override = 8
	daylight.update_local_time()
	var morning_direction: Vector3 = -daylight.sun.global_basis.z
	var morning_energy: float = daylight.sun.light_energy
	daylight.time_override = 12
	daylight.update_local_time()
	check(daylight.sun.light_energy > morning_energy, "Noon sunlight is brighter than morning")
	var noon_direction: Vector3 = -daylight.sun.global_basis.z
	daylight.time_override = 17
	daylight.update_local_time()
	check(not morning_direction.is_equal_approx(-daylight.sun.global_basis.z) and not noon_direction.is_equal_approx(morning_direction), "Sun direction and shadows move throughout the day")
	daylight.time_override = 23
	daylight.update_local_time()
	check(is_zero_approx(daylight.sun.light_energy) and daylight.fill.light_energy > 0, "Night disables sunlight and preserves room lighting")
	check(daylight.window_material.albedo_color.r < 0.2, "Window darkens at night")
	var environment_before: Dictionary = game.tree.environment.duplicate(true)
	daylight.set_hour(12)
	check(game.tree.environment == environment_before, "Visual time never penalizes nighttime care")
	if "--visual" in OS.get_cmdline_user_args():
		for hour in [8, 12, 17, 23]:
			daylight.time_override = hour
			daylight.update_local_time()
			await capture("light-%02d" % hour)
		game.hud.open_panel("collection")
		await capture("collection")
		game.hud.close_panel()
		game._select_tree(olive.id)
		daylight.time_override = 12
		daylight.update_local_time()
		await capture("olive")
		game._select_tree(willow.id)
		await capture("willow")
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp", ".before-restore"]:
		if FileAccess.file_exists(filename + suffix): DirAccess.remove_absolute(filename + suffix)
	print("Grove and daylight tests: %d failures" % failures)
	quit(1 if failures else 0)

func capture(label: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/%s.png" % label)
