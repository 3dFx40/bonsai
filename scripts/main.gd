extends Node3D

var tree := BonsaiTree.starter()
var trees: Array = []
var sim := BonsaiSimulation.new()
var clock := BonsaiClock.new()
var saves := BonsaiSave.new()
var platform: BonsaiPlatform
var renderer: BonsaiTreeRenderer
var studio: BonsaiStudio
var sound: BonsaiSound
var orbit: BonsaiCamera
var hud: BonsaiHUD
var debug_panel: BonsaiDebugPanel
var settings := {"sound": false, "quality": "Medium", "real_seconds_per_day": 3600.0}
var mode := "inspect"
var last_wall := 0.0
var last_tick := 0
var save_elapsed := 0.0
var undo_data: Dictionary = {}
var undo_until := 0
var suspended := false
var automation := false
var reset_armed := false
var file_dialog: FileDialog
var pending_restore: Dictionary = {}
var comparison_index := -1
var showing_memory := false
var comparison_memory: Dictionary = {}
var creator: BonsaiCreator
var creating := false
var creation_camera: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	automation = "--capture" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args() or "--integration" in OS.get_cmdline_user_args()
	platform = BonsaiPlatform.new()
	add_child(platform)
	platform.suspend_requested.connect(_suspend)
	platform.resumed.connect(_resume)
	platform.quit_requested.connect(_quit)
	platform.back_requested.connect(_back)
	settings.real_seconds_per_day = clampf(ProjectSettings.get_setting("bonsai/real_seconds_per_day", 3600), 60, 86400)
	if automation:
		saves.path = "user://automation-grove.json"
	var loaded := {} if automation else saves.load_document()
	var first_visit: bool = loaded.is_empty() and not saves.read_only
	creating = first_visit and not automation
	if first_visit: settings.onboarded = false
	var welcome := "A little attention, every day."
	var welcome_args: Array = []
	if not loaded.is_empty():
		settings = loaded.settings
		for row: Dictionary in loaded.trees:
			if row.species not in BonsaiCatalog.SPECIES:
				saves.read_only = true
				welcome = "This tree needs a species pack that is not installed. Save preserved."
				trees.clear()
				break
			trees.append(BonsaiTree.from_data(row))
		if not trees.is_empty():
			for item: BonsaiTree in trees:
				if item.id == loaded.active_tree: tree = item
			clock.pending_days = loaded.pending_days
			last_wall = loaded.last_real_timestamp
	sim.species = BonsaiCatalog.profile(tree.species_id)
	if trees.is_empty():
		tree.acquired_at = platform.unix_time()
		trees = [tree]
	var previous_leaves := tree.leaf_count()
	var default_language := "he" if OS.get_locale_language() in ["he", "iw"] else "en"
	settings.language = settings.get("language", default_language)
	if automation:
		for argument in OS.get_cmdline_user_args():
			if argument in ["--language=he", "--language=en"]:
				settings.language = argument.get_slice("=", 1)
	TranslationServer.set_locale(settings.language)
	clock.real_seconds_per_day = settings.real_seconds_per_day
	var now := platform.unix_time()
	if last_wall > 0:
		var result := clock.advance(tree, sim, maxf(0, now - last_wall), true)
		if result.dormant_days > 0:
			welcome = "Welcome back. Your tree rested through the long absence."
		elif result.days > 0:
			welcome = "Welcome back. %.1f days have passed for your tree."
			welcome_args = [result.days]
	last_wall = maxf(last_wall, now)
	last_tick = Time.get_ticks_msec()
	studio = BonsaiStudio.new()
	add_child(studio)
	sound = BonsaiSound.new()
	add_child(sound)
	sound.enabled = settings.sound
	renderer = BonsaiTreeRenderer.new()
	add_child(renderer)
	renderer.rebuild(tree)
	orbit = BonsaiCamera.new()
	add_child(orbit)
	orbit.tapped.connect(_tap)
	hud = BonsaiHUD.new()
	add_child(hud)
	hud.tool_selected.connect(_tool)
	hud.action_requested.connect(_action)
	hud.undo_requested.connect(_undo)
	hud.debug_requested.connect(_toggle_debug)
	hud.sound_requested.connect(_toggle_sound)
	hud.quality_requested.connect(_quality)
	hud.language_requested.connect(_language)
	hud.preview_changed.connect(_preview)
	hud.name_requested.connect(_rename)
	hud.tutorial_finished.connect(func(): settings.onboarded = true; _save())
	hud.backup_requested.connect(_backup_dialog)
	hud.restore_confirmed.connect(_restore_backup)
	hud.recovery_requested.connect(_recover_previous)
	hud.portrait_requested.connect(_portrait)
	hud.memory_selected.connect(_show_memory)
	hud.comparison_requested.connect(_compare)
	hud.overlay_changed.connect(_overlay)
	hud.creation_requested.connect(_begin_creation)
	hud.quit_requested.connect(_quit)
	creator = BonsaiCreator.new()
	add_child(creator)
	creator.preview_requested.connect(_creation_preview)
	creator.confirmed.connect(_finish_creation)
	creator.canceled.connect(_cancel_creation)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.use_native_dialog = true
	file_dialog.filters = PackedStringArray(["*.json ; Bonsai backup"])
	file_dialog.file_selected.connect(_backup_selected)
	file_dialog.canceled.connect(func(): orbit.set_input_enabled(not hud.modal.visible))
	add_child(file_dialog)
	if OS.is_debug_build() and ProjectSettings.get_setting("bonsai/developer_tools", false):
		debug_panel = BonsaiDebugPanel.new()
		hud.root.add_child(debug_panel)
		debug_panel.visible = false
		debug_panel.command.connect(_debug)
	_apply_quality()
	_refresh()
	if tree.memories.is_empty() and not saves.read_only and not creating: tree.remember("First portrait")
	if not first_visit and last_wall > 0:
		hud.welcome("Since your last visit: %d new leaves.", [maxi(0, tree.leaf_count() - previous_leaves)])
	if saves.last_error.is_empty(): hud.message(welcome, welcome_args)
	else: hud.message(saves.last_error, saves.last_error_args)
	_save()
	if creating:
		_begin_creation()
	elif not settings.get("onboarded", true) and not automation: hud.open_panel("guide", true)
	if "--capture" in OS.get_cmdline_user_args():
		if "--capture-debug" in OS.get_cmdline_user_args(): _toggle_debug()
		for i in range(30):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/studio.png")
		get_viewport().get_texture().get_image().save_png("res://builds/studio-%s%s.png" % [settings.language, "-debug" if "--capture-debug" in OS.get_cmdline_user_args() else ""])
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		_smoke()

func _begin_creation() -> void:
	if saves.read_only or trees.size() >= 32: return
	var first := creating
	if not first: _save()
	hud.close_panel()
	_clear_undo()
	comparison_index = -1
	showing_memory = false
	comparison_memory.clear()
	hud.comparison.hide()
	renderer.select(-1)
	renderer.cut_fraction = -1
	creating = true
	hud.root.hide()
	creation_camera = {"yaw": orbit.yaw, "pitch": orbit.pitch, "distance": orbit.distance, "target": orbit.target}
	orbit.yaw = 0.2
	orbit.pitch = 0.17
	orbit.distance = 7.0
	orbit.target = Vector3(0, 0.55, 0)
	orbit.cinematic = false
	orbit.set_input_enabled(true)
	creator.open(hud.root.theme, not first)
	_creation_preview("ficus_microcarpa", "slate_rectangle")

func _creation_preview(species: String, pot: String) -> void:
	if not creating: return
	var preview := BonsaiCatalog.create(species, pot)
	if preview == null: return
	renderer.rebuild(preview)
	studio.set_pot(pot)
	studio.set_moisture(preview.moisture)

func _finish_creation(species: String, pot: String, tree_name: String) -> void:
	if not creating: return
	var created := BonsaiCatalog.create(species, pot)
	if created == null: return
	created.id = "%s-%d" % [species, Time.get_ticks_usec()]
	created.display_name = tree_name.substr(0, 40)
	created.acquired_at = platform.unix_time()
	# The initial placeholder has never been saved or cared for.
	if not creator.can_cancel: trees.clear()
	trees.append(created)
	tree = created
	clock.pending_days = 0
	last_wall = platform.unix_time()
	last_tick = Time.get_ticks_msec()
	save_elapsed = 0
	creating = false
	creator.hide()
	hud.root.show()
	_restore_creation_camera()
	tree.remember("First portrait")
	_tool("inspect")
	_refresh()
	_save()
	if not settings.get("onboarded", true): hud.open_panel("guide", true)

func _cancel_creation() -> void:
	if not creating or not creator.can_cancel: return
	creating = false
	creator.hide()
	hud.root.show()
	_restore_creation_camera()
	last_tick = Time.get_ticks_msec()
	last_wall = platform.unix_time()
	_tool("inspect")
	_refresh()

func _restore_creation_camera() -> void:
	if creation_camera.is_empty(): return
	orbit.yaw = creation_camera.yaw
	orbit.pitch = creation_camera.pitch
	orbit.distance = creation_camera.distance
	orbit.target = creation_camera.target
	creation_camera.clear()

func _process(delta: float) -> void:
	if hud == null or suspended or creating: return
	if not undo_data.is_empty() and Time.get_ticks_msec() >= undo_until:
		undo_data.clear()
		hud.undo.visible = false
	var ticks := Time.get_ticks_msec()
	if ticks - last_tick >= 1000 and undo_data.is_empty():
		var result := clock.advance(tree, sim, (ticks - last_tick) / 1000.0)
		last_tick = ticks
		last_wall = maxf(last_wall, platform.unix_time())
		if result.steps > 0: _refresh()
	save_elapsed += delta
	if save_elapsed >= 20:
		_save()
		save_elapsed = 0

func _refresh() -> void:
	sim.species = BonsaiCatalog.profile(tree.species_id)
	if not showing_memory: renderer.rebuild(tree)
	studio.set_pot(str(comparison_memory.tree.pot) if showing_memory else tree.pot_id)
	studio.set_moisture(float(comparison_memory.tree.moisture) if showing_memory else tree.moisture)
	hud.update_state(tree)
	hud.creation_button.disabled = saves.read_only or trees.size() >= 32
	if mode == "prune" and comparison_index < 0: _preview()
	if debug_panel != null: debug_panel.update_state(tree)

func _tool(value: String) -> void:
	if creating: return
	comparison_index = -1
	comparison_memory.clear()
	showing_memory = false
	hud.comparison.hide()
	renderer.cut_fraction = -1
	renderer.rebuild(tree)
	studio.set_moisture(tree.moisture)
	studio.set_pot(tree.pot_id)
	mode = value
	hud.set_tool(mode)
	orbit.cinematic = mode == "camera"
	if mode == "prune":
		hud.message("Amber shows the cut. Tap again to select an overlapping branch.")
		_selection()
	elif mode == "water": hud.message("Water slowly. Let the soil breathe between visits.")
	elif mode == "fertilize": hud.message("A small dose supports growth. Too much stresses roots.")
	elif mode == "inspect": hud.message("Hold a branch to inspect. Drag to turn your tree.")

func _tap(at: Vector2, held: bool) -> void:
	if creating or hud.modal.visible or comparison_index >= 0: return
	if debug_panel != null and debug_panel.visible: return
	if mode == "camera": return
	if mode == "water" or mode == "fertilize":
		# The explicit action button avoids accidental care while navigating.
		return
	renderer.select(renderer.pick(at, orbit.camera))
	_selection(held)

func _selection(held := false) -> void:
	var selected := renderer.selected_id
	if selected < 0:
		if mode == "prune":
			hud.action.disabled = true
			hud.set_action("Select a branch to cut")
		return
	var b: BonsaiBranch = tree.branches[selected]
	if mode == "prune":
		hud.action.disabled = b.parent_id < 0
		if b.parent_id < 0: hud.set_action("Keep the main trunk")
		else: hud.set_action("Cut branch · %d segments", [tree.descendants(selected).size()])
		_preview()
	else:
		var condition := "Healthy" if b.health > 0.7 else "Under stress"
		if held: hud.message("Branch %d · %s · Leaves: %d · Age: %.1f days", [b.id, condition, b.leaves.size(), b.age])
		else: hud.message("Branch %d · %s · Leaves: %d", [b.id, condition, b.leaves.size()])

func _clear_undo() -> void:
	undo_data.clear()
	hud.undo.visible = false

func _action() -> void:
	if creating: return
	if saves.read_only or comparison_index >= 0:
		hud.message("Save is protected. Restore a compatible version before making changes.")
		return
	var snapshot := tree.to_data() if mode == "prune" else {}
	_clear_undo()
	match mode:
		"water":
			sim.water(tree)
			studio.pour()
			tree.record("water")
			sound.play_cue("water")
			hud.message("Water settles into the soil." if tree.moisture < 1 else "The soil is saturated. Give it time to drain.")
		"fertilize":
			sim.fertilize(tree)
			tree.record("feed")
			sound.play_cue("fertilize")
			hud.message("A small dose, for the days ahead." if tree.nutrients < 1 else "There is already plenty of food in this soil.")
		"prune":
			var changed := tree.prune(renderer.selected_id) if hud.cut_mode.selected == 0 else tree.trim(renderer.selected_id, hud.cut_slider.value / 100)
			if changed:
				sound.play_cue("prune")
				_offer_undo(snapshot)
				renderer.select(-1)
				hud.action.disabled = true
				hud.set_action("Select another branch")
				hud.message("Space for new growth. You can undo this change for 15 seconds.")
	_refresh()
	_save()

func _undo() -> void:
	if undo_data.is_empty() or Time.get_ticks_msec() > undo_until: return
	var restored := BonsaiTree.from_data(undo_data)
	trees[trees.find(tree)] = restored
	tree = restored
	_clear_undo()
	_refresh()
	hud.message("The branch is back.")
	_save()

func _save() -> void:
	if automation or creating: return
	# Account for time since the latest tick before stamping the snapshot.
	var ticks := Time.get_ticks_msec()
	if not suspended and undo_data.is_empty():
		clock.advance(tree, sim, maxf(0, ticks - last_tick) / 1000.0)
		last_tick = ticks
		last_wall = maxf(last_wall, platform.unix_time())
	# One portrait per real day at most, captured on the next save after returning.
	if not saves.read_only and (tree.memories.is_empty() or tree.age_days - float(tree.memories.back().day) >= 86400 / clock.real_seconds_per_day):
		tree.remember("Daily portrait")
	var document := saves.make_document(trees, tree.id, settings, last_wall, clock.pending_days)
	if not saves.write_document(document) and hud != null:
		hud.message(saves.last_error, saves.last_error_args)

func _suspend() -> void:
	if suspended: return
	_clear_undo()
	_save()
	suspended = true

func _resume() -> void:
	if not suspended: return
	if creating:
		last_tick = Time.get_ticks_msec()
		suspended = false
		return
	var now := platform.unix_time()
	clock.advance(tree, sim, maxf(0, now - last_wall), true)
	last_wall = maxf(last_wall, now)
	last_tick = Time.get_ticks_msec()
	suspended = false
	_refresh()
	_save()

func _back() -> void:
	if creating:
		if creator.step == 0 and not creator.can_cancel: _quit()
		else: creator.go_back()
		return
	if hud.modal.visible:
		hud.close_panel()
		return
	if comparison_index >= 0 or mode != "inspect":
		_tool("inspect")
		return
	_quit()

func _quit() -> void:
	_save()
	get_tree().quit()

func _toggle_debug() -> void:
	if debug_panel != null:
		debug_panel.visible = not debug_panel.visible
		debug_panel.update_state(tree)

func _debug(command: String, value: float) -> void:
	if debug_panel == null: return
	if command == "close":
		debug_panel.hide()
		return
	if command == "reset" and not reset_armed:
		reset_armed = true
		hud.message("Reset replaces this tree. Tap Reset tree again to confirm.")
		return
	_clear_undo()
	match command:
		"pause":
			clock.paused = not clock.paused
			last_tick = Time.get_ticks_msec()
			debug_panel.pause_button.text = "Resume simulation" if clock.paused else "Pause simulation"
		"time": sim.advance_days(tree, value)
		"moisture": tree.moisture = value
		"nutrients": tree.nutrients = value
		"light": tree.environment.light = value
		"damage":
			tree.root_health = 0.35
			tree.stress = 0.7
			for b: BonsaiBranch in tree.branches.values():
				for leaf: Dictionary in b.leaves: leaf.health = 0.35
		"restore":
			tree.root_health = 1
			tree.moisture = 0.65
			tree.nutrients = 0.55
			tree.stress = 0
			tree.energy = 1
			for b: BonsaiBranch in tree.branches.values():
				b.health = 1
				for leaf: Dictionary in b.leaves: leaf.health = 1
		"grow":
			for b: BonsaiBranch in tree.branches.values():
				if tree.children(b.id).is_empty() and tree.branches.size() < BonsaiTree.MAX_BRANCHES:
					b.bud_charge = 1
					b.energy = 1
					sim._sprout(tree, b)
		"reset":
			var replacement := BonsaiTree.starter()
			replacement.id = tree.id
			replacement.acquired_at = platform.unix_time()
			trees[trees.find(tree)] = replacement
			tree = replacement
			clock.pending_days = 0
			saves.read_only = false
			renderer.select(-1)
	reset_armed = false
	_refresh()
	_save()

func _toggle_sound() -> void:
	settings.sound = not settings.sound
	sound.enabled = settings.sound
	hud.sound_button.text = "Sound on" if settings.sound else "Sound off"
	_save()

func _language(language: String) -> void:
	if language not in ["he", "en"]: return
	settings.language = language
	TranslationServer.set_locale(language)
	_save()

func _quality() -> void:
	var levels := ["Low", "Medium", "High"]
	settings.quality = levels[(levels.find(settings.quality) + 1) % 3]
	_apply_quality()
	_save()

func _apply_quality() -> void:
	Engine.max_fps = 30 if settings.quality == "Low" else 60
	hud.quality_button.text = settings.quality
	hud.sound_button.text = "Sound on" if settings.sound else "Sound off"
	studio.sun.shadow_enabled = settings.quality != "Low"
	get_viewport().msaa_3d = Viewport.MSAA_4X if settings.quality == "High" else (Viewport.MSAA_2X if settings.quality == "Medium" else Viewport.MSAA_DISABLED)

func _smoke() -> void:
	var before := tree.moisture
	_tool("water")
	_action()
	assert(tree.moisture > before)
	_tool("fertilize")
	_action()
	assert(tree.nutrients > 0.55)
	var count := tree.branches.size()
	_tool("prune")
	renderer.select(3)
	_selection()
	_action()
	assert(tree.branches.size() < count)
	_undo()
	assert(tree.branches.size() == count)
	_debug("time", 1)
	assert(tree.age_days >= 1)
	_toggle_debug()
	if debug_panel != null: assert(debug_panel.visible and not debug_panel.graph.text.is_empty())
	print("PASS gameplay smoke: watering, fertilizer, prune, undo, time, graph panel")
	get_tree().quit()

func _offer_undo(snapshot: Dictionary) -> void:
	undo_data = snapshot
	undo_until = Time.get_ticks_msec() + 15000
	hud.undo.visible = true

func _preview() -> void:
	var selected := renderer.selected_id
	if selected < 0 or not tree.branches.has(selected): return
	var b: BonsaiBranch = tree.branches[selected]
	if mode == "prune":
		renderer.cut_fraction = (0.0 if hud.cut_mode.selected == 0 else hud.cut_slider.value / 100.0) if b.parent_id >= 0 else -1.0
		renderer.select(selected)
		if hud.cut_mode.selected == 1 and b.parent_id >= 0:
			hud.action.disabled = b.length * renderer.cut_fraction < 0.025
			hud.set_action("Shorten branch · remove %d shoots", [tree.cut_descendants(selected, renderer.cut_fraction).size()])
		elif b.parent_id >= 0:
			hud.action.disabled = false
			hud.set_action("Cut branch · %d segments", [tree.descendants(selected).size()])

func _overlay(open: bool) -> void:
	orbit.set_input_enabled(not open)
	if open:
		renderer.cut_fraction = -1
		renderer.rebuild(tree)
		pending_restore.clear()
	else:
		_preview()

func _rename(value: String) -> void:
	if saves.read_only: return
	_clear_undo()
	tree.display_name = value.substr(0, 40)
	_refresh()
	_save()
	hud.close_panel()

func _portrait() -> void:
	if saves.read_only: return
	_clear_undo()
	tree.remember("Portrait")
	_save()
	hud.update_journal()

func _show_memory(index: int) -> void:
	if index < 0 or index >= tree.memories.size(): return
	hud.close_panel()
	_tool("camera")
	comparison_index = index
	comparison_memory = tree.memories[index].duplicate(true)
	showing_memory = false
	orbit.cinematic = false
	hud.comparison.show()
	_compare()

func _compare() -> void:
	if comparison_memory.is_empty(): return
	showing_memory = not showing_memory
	var memory: Dictionary = comparison_memory
	var displayed := BonsaiTree.from_data(memory.tree) if showing_memory else tree
	renderer.select(-1)
	renderer.rebuild(displayed)
	studio.set_moisture(displayed.moisture)
	studio.set_pot(displayed.pot_id)
	hud.comparison.text = tr("Day %d · Show today's tree") % (int(memory.day) + 1) if showing_memory else tr("Today · Show saved portrait")

func _backup_dialog(importing: bool) -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_file = "" if importing else "bonsai-backup.json"
	orbit.set_input_enabled(false)
	file_dialog.popup_centered_ratio(0.85)

func _backup_selected(filename: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		var document := saves.read_backup(filename)
		if document.is_empty():
			hud.close_panel()
			hud.message("This backup is invalid or needs another version. Your tree was not changed.")
			return
		hud.open_panel("restore")
		pending_restore = document
	else:
		_save()
		var document := saves.make_document(trees, tree.id, settings, last_wall, clock.pending_days)
		var ok := saves.export_backup(filename, document)
		hud.close_panel()
		hud.message("Backup exported. Keep it somewhere safe." if ok else "Could not export the backup. Try another location.")

func _restore_backup() -> void:
	if pending_restore.is_empty(): return
	var document := pending_restore.duplicate(true)
	# Advance the imported active tree once, before persisting its new timestamp.
	var restored_clock := BonsaiClock.new()
	restored_clock.real_seconds_per_day = document.settings.real_seconds_per_day
	restored_clock.pending_days = document.pending_days
	var now := platform.unix_time()
	for i in document.trees.size():
		if document.trees[i].id == document.active_tree:
			var active := BonsaiTree.from_data(document.trees[i])
			restored_clock.advance(active, BonsaiSimulation.new(BonsaiCatalog.profile(active.species_id)), maxf(0, now - document.last_real_timestamp), true)
			document.trees[i] = active.to_data()
	document.last_real_timestamp = maxf(now, document.last_real_timestamp)
	document.pending_days = restored_clock.pending_days
	# Keep a separate recovery copy that the next autosave cannot rotate away.
	if not saves.preserve_before_restore():
		hud.close_panel()
		hud.message("Could not preserve previous save.")
		return
	if not saves.write_document(document):
		hud.close_panel()
		hud.message(saves.last_error, saves.last_error_args)
		return
	_clear_undo()
	trees.clear()
	for row: Dictionary in document.trees:
		var restored := BonsaiTree.from_data(row)
		trees.append(restored)
		if restored.id == document.active_tree: tree = restored
	settings = document.settings
	settings.language = settings.get("language", "en")
	TranslationServer.set_locale(settings.language)
	clock.real_seconds_per_day = settings.real_seconds_per_day
	clock.pending_days = document.pending_days
	last_wall = document.last_real_timestamp
	last_tick = Time.get_ticks_msec()
	sound.enabled = settings.sound
	_apply_quality()
	hud.close_panel()
	pending_restore.clear()
	renderer.select(-1)
	_tool("inspect")
	_refresh()
	hud.message("Your tree has been restored.")

func _recover_previous() -> void:
	var document := saves.read_backup(saves.path + ".before-restore")
	if document.is_empty():
		hud.close_panel()
		hud.message("No previous restore is available.")
		return
	hud.open_panel("restore")
	pending_restore = document
