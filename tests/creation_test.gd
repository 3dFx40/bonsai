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
	var filename := "user://creation-test-%d.json" % Time.get_ticks_usec()
	var game = scene.instantiate()
	game.saves.path = filename
	root.add_child(game)
	await process_frame
	if "--visual" in OS.get_cmdline_user_args(): game._language("he")
	check(game.creating and game.creator.visible and not game.hud.root.visible, "First visit begins with creation, not care")
	check(game.hud.quit_button.is_visible_in_tree(), "Close app control remains visible during creation")
	check(game.creator.next_button.disabled, "Plant selection is required")
	game._save()
	check(not FileAccess.file_exists(filename), "Incomplete creation cannot save a placeholder")
	var initial: Dictionary = game.tree.to_data()
	game.creator.choose("portulacaria_afra")
	await capture("plant")
	check(game.renderer.tree.species_id == "portulacaria_afra", "Plant selection changes real 3D preview")
	check(game.tree.to_data() == initial, "Preview cannot mutate live tree")
	game._action()
	check(game.tree.to_data() == initial, "Care is blocked before creation finishes")
	game.creator.next_button.pressed.emit()
	check(game.creator.step == 1 and game.creator.next_button.disabled, "Planter must be explicitly selected")
	game.creator.choose("terracotta_round")
	await capture("planter")
	check(game.studio.pot_id == "terracotta_round" and game.studio.soil.mesh is CylinderMesh, "Round planter updates soil and mesh")
	game._back()
	check(game.creator.step == 0 and game.creator.species_id == "portulacaria_afra", "Back preserves plant choice")
	game.creator.next_button.pressed.emit()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = game.creator.name_edit.get_parent().get_parent()
	scroll.ensure_control_visible(game.creator.name_edit)
	await process_frame
	var tap := InputEventScreenTouch.new()
	tap.position = game.creator.name_edit.get_global_rect().get_center()
	tap.pressed = true
	root.push_input(tap, true)
	tap.pressed = false
	root.push_input(tap, true)
	check(game.creator.name_edit.has_focus() and game.creator.name_edit.is_editing(), "Native touch must focus the creator name field and enter editing")
	for character in "העץ שלי":
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		root.push_input(key, true)
	check(game.creator.name_edit.text == "העץ שלי", "Creator accepts actual keyboard events after native touch")
	game.creator.next_button.pressed.emit()
	check(not game.creating and game.hud.root.visible, "Finish enters game")
	check(game.tree.species_id == "portulacaria_afra" and game.tree.pot_id == "terracotta_round", "Both choices become active tree")
	check(game.sim.species.id == game.tree.species_id, "Simulation uses selected species")
	check(game.tree.display_name == "העץ שלי" and game.tree.memories.size() == 1, "Name and first portrait belong to selected tree")
	check(game.trees.size() == 1, "Initial placeholder is replaced")
	var chosen_id: String = game.tree.id
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	game.saves.path = filename
	root.add_child(game)
	await process_frame
	check(not game.creating and not game.saves.read_only, "Selected species can reopen normally")
	check(game.tree.id == chosen_id and game.tree.pot_id == "terracotta_round" and game.tree.display_name == "העץ שלי", "Choices and typed name persist on restart")
	check(game.sim.species.id == "portulacaria_afra" and game.studio.pot_id == "terracotta_round", "Reopen restores simulation and planter")
	check(not game.saves.read_backup(filename).is_empty(), "New species supports backup import")
	game._begin_creation()
	check(game.creator.can_cancel, "Existing player can cancel creation")
	game.creator.choose("ulmus_parvifolia")
	game._cancel_creation()
	check(game.tree.id == chosen_id and game.renderer.tree == game.tree, "Cancel restores original tree and preview")
	game._begin_creation()
	game.creator.choose("ulmus_parvifolia")
	game.creator.next_button.pressed.emit()
	game.creator.choose("blue_rectangle")
	game.creator.next_button.pressed.emit()
	check(game.trees.size() == 2 and game.trees[0].id == chosen_id, "Adding another tree preserves existing tree")
	check(game.sim.species.id == "ulmus_parvifolia", "New tree changes simulation profile")
	for species: String in BonsaiCatalog.SPECIES:
		for pot: String in BonsaiCatalog.POTS:
			var candidate := BonsaiCatalog.create(species, pot)
			check(candidate != null, "Every catalog combination is creatable")
			var sim := BonsaiSimulation.new(BonsaiCatalog.profile(species))
			sim.advance_days(candidate, 2)
			check(game.saves.valid(game.saves.make_document([candidate], candidate.id, game.settings, 1000, 0)), "Every combination remains saveable after growth")
	game.hud.open_panel("settings")
	check(game.hud.settings_body.get_child(0) == game.hud.creation_button, "Create tree is first in settings")
	check(game.hud.quit_button.is_visible_in_tree(), "Close app control remains visible above settings")
	game.tree.display_name = "Saved on close"
	game.hud.quit_button.pressed.emit()
	check(game.saves.load_document().trees.back().display_name == "Saved on close", "Close app button saves latest changes before quitting")
	game.queue_free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(filename + suffix): DirAccess.remove_absolute(filename + suffix)
	print("Creation tests: %d failures" % failures)
	quit(1 if failures else 0)

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/creation-%s.png" % label)
