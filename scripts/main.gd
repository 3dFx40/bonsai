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

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Engine.max_fps = 60
	automation = "--capture" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_user_args() or "--integration" in OS.get_cmdline_user_args()
	platform = BonsaiPlatform.new()
	add_child(platform)
	platform.suspend_requested.connect(_suspend)
	platform.resumed.connect(_resume)
	platform.quit_requested.connect(_quit)
	settings.real_seconds_per_day = clampf(ProjectSettings.get_setting("bonsai/real_seconds_per_day", 3600), 60, 86400)
	if automation:
		saves.path = "user://automation-grove.json"
	var loaded := {} if automation else saves.load_document()
	var welcome := "A little attention, every day."
	var welcome_args: Array = []
	if not loaded.is_empty():
		settings = loaded.settings
		for row: Dictionary in loaded.trees:
			if row.species != sim.species.id:
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
	if trees.is_empty():
		tree.acquired_at = platform.unix_time()
		trees = [tree]
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
	if OS.is_debug_build() and ProjectSettings.get_setting("bonsai/developer_tools", false):
		debug_panel = BonsaiDebugPanel.new()
		hud.root.add_child(debug_panel)
		debug_panel.visible = false
		debug_panel.command.connect(_debug)
	_apply_quality()
	_refresh()
	if saves.last_error.is_empty(): hud.message(welcome, welcome_args)
	else: hud.message(saves.last_error, saves.last_error_args)
	_save()
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

func _process(delta: float) -> void:
	if hud == null or suspended: return
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
	renderer.rebuild(tree)
	studio.set_moisture(tree.moisture)
	hud.update_state(tree)
	if debug_panel != null: debug_panel.update_state(tree)

func _tool(value: String) -> void:
	mode = value
	hud.set_tool(mode)
	orbit.cinematic = mode == "camera"
	if mode == "prune":
		hud.message("Tap a branch. The cut removes it and all its shoots.")
		_selection()
	elif mode == "water": hud.message("Water slowly. Let the soil breathe between visits.")
	elif mode == "fertilize": hud.message("A small dose supports growth. Too much stresses roots.")
	elif mode == "inspect": hud.message("Hold a branch to inspect. Drag to turn your tree.")

func _tap(at: Vector2, held: bool) -> void:
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
	else:
		var condition := "Healthy" if b.health > 0.7 else "Under stress"
		if held: hud.message("Branch %d · %s · Leaves: %d · Age: %.1f days", [b.id, condition, b.leaves.size(), b.age])
		else: hud.message("Branch %d · %s · Leaves: %d", [b.id, condition, b.leaves.size()])

func _clear_undo() -> void:
	undo_data.clear()
	hud.undo.visible = false

func _action() -> void:
	_clear_undo()
	match mode:
		"water":
			sim.water(tree)
			sound.play_cue("water")
			hud.message("Water settles into the soil." if tree.moisture < 1 else "The soil is saturated. Give it time to drain.")
		"fertilize":
			sim.fertilize(tree)
			sound.play_cue("fertilize")
			hud.message("A small dose, for the days ahead." if tree.nutrients < 1 else "There is already plenty of food in this soil.")
		"prune":
			var snapshot := tree.to_data()
			if tree.prune(renderer.selected_id):
				sound.play_cue("prune")
				undo_data = snapshot
				undo_until = Time.get_ticks_msec() + 8000
				hud.undo.visible = true
				renderer.select(-1)
				hud.action.disabled = true
				hud.set_action("Select another branch")
				hud.message("A little space for new growth. Undo is available for 8 seconds.")
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
	if automation: return
	# Account for time since the latest tick before stamping the snapshot.
	var ticks := Time.get_ticks_msec()
	if not suspended and undo_data.is_empty():
		clock.advance(tree, sim, maxf(0, ticks - last_tick) / 1000.0)
		last_tick = ticks
		last_wall = maxf(last_wall, platform.unix_time())
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
	var now := platform.unix_time()
	clock.advance(tree, sim, maxf(0, now - last_wall), true)
	last_wall = maxf(last_wall, now)
	last_tick = Time.get_ticks_msec()
	suspended = false
	_refresh()
	_save()

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
	assert(debug_panel.visible and not debug_panel.graph.text.is_empty())
	print("PASS gameplay smoke: watering, fertilizer, prune, undo, time, graph panel")
	get_tree().quit()
