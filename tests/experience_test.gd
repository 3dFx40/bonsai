extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var initial: Dictionary = game.tree.to_data()
	game._tool("prune")
	game.renderer.select(3)
	game.hud.set_cut_mode(1)
	game.hud.cut_slider.value = 60
	game._preview()
	check(game.tree.to_data() == initial, "Cut preview cannot change the tree")
	check(is_equal_approx(game.renderer.cut_fraction, 0.6), "Cut marker matches requested length")
	game._action()
	check(game.tree.branches.has(3) and not game.tree.branches.has(5), "UI action shortens chosen branch")
	game._undo()
	check(game.tree.to_data() == initial, "Partial cut undo includes removed shoots")
	game._rename("העץ שלי")
	check(game.hud.title.text == "העץ שלי", "Personal name displays verbatim")
	game._portrait()
	var before_compare: Dictionary = game.tree.to_data()
	game._show_memory(0)
	check(game.showing_memory and game.hud.comparison.visible, "Journal opens historical portrait")
	var portrait_moisture: float = game.tree.memories[0].tree.moisture
	game.tree.moisture = 0.1
	game._refresh()
	check(game.studio.soil.material_override.albedo_color.is_equal_approx(Color("897356").lerp(Color("29281f"), portrait_moisture)), "Historical portrait retains its own soil color while live tree changes")
	game.tree.moisture = float(before_compare.moisture)
	game._compare()
	game._tool("inspect")
	check(game.tree.to_data() == before_compare, "Comparing portraits never restores old state")
	game.hud.open_panel("settings")
	check(not game.orbit.input_enabled, "Modal blocks camera input")
	game._back()
	check(game.orbit.input_enabled, "Closing modal restores camera input")
	check(not game.hud.modal.visible, "Android back closes settings before exiting")
	game.hud.open_panel("guide", true)
	game.hud.close_panel()
	check(game.settings.onboarded, "Onboarding completion persists in settings")
	var saves := BonsaiSave.new()
	var filename := "user://backup-test-%d.json" % Time.get_ticks_usec()
	var document := saves.make_document([game.tree], game.tree.id, game.settings, Time.get_unix_time_from_system(), 0)
	check(saves.export_backup(filename, document), "Export produces a valid backup")
	check(not saves.export_backup(ProjectSettings.globalize_path(saves.path + ".bak"), document), "Export cannot overwrite internal recovery files through absolute paths")
	var imported := saves.read_backup(filename)
	check(imported.trees[0].display_name == "העץ שלי", "Backup preserves name and portraits")
	var alien := document.duplicate(true)
	alien.trees[0].species = "missing-species"
	check(saves.export_backup(filename, alien), "Write structurally valid unknown species fixture")
	check(saves.read_backup(filename).is_empty(), "Refuse backup that needs missing species")
	check(saves.export_backup(filename, document), "Restore valid fixture")
	game.saves.path = "user://restore-test-%d.json" % Time.get_ticks_usec()
	check(game.saves.write_document(document), "Seed original before restore")
	game.hud.open_panel("restore")
	game.pending_restore = saves.read_backup(filename)
	game.pending_restore.trees[0].display_name = "Restored"
	game._restore_backup()
	check(game.tree.display_name == "Restored", "Confirmed restore loads selected tree")
	check(game.saves._read(game.saves.path + ".bak").trees[0].display_name == "העץ שלי", "Previous tree remains in backup")
	check(game.saves.write_document(game.saves.make_document(game.trees, game.tree.id, game.settings, game.last_wall, game.clock.pending_days)), "Autosave after restore")
	check(game.saves.read_backup(game.saves.path + ".before-restore").trees[0].display_name == "העץ שלי", "Autosave cannot erase recovery before restore")
	for path in [filename, game.saves.path, game.saves.path + ".bak", game.saves.path + ".tmp", game.saves.path + ".before-restore"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# Capture production UI states through the real renderer when requested.
	if "--visual" in OS.get_cmdline_user_args():
		game.tree.display_name = ""
		game._refresh()
		for language in ["he", "en"]:
			game._language(language)
			for state in ["inspect", "water", "prune", "guide", "settings", "journal"]:
				game.hud.close_panel()
				game._tool(state if state in ["inspect", "water", "prune"] else "inspect")
				if state == "prune":
					game.renderer.select(3)
					game._selection()
				if state in ["guide", "settings", "journal"]: game.hud.open_panel(state)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://builds/ready-%s-%s.png" % [language, state])
	print("Experience tests: %d failures" % failures)
	quit(1 if failures else 0)
