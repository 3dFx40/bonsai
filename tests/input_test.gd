extends SceneTree

var failures := 0
var game: Node3D

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	root.push_input(event, true)

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event, true)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var orbit: BonsaiCamera = game.orbit
	# Background geometry must never block the tree during a full orbit.
	for zoom in [2.65, 7.0]:
		for tilt in [0.07, 0.68]:
			for angle in range(-360, 361, 30):
				orbit.distance = zoom
				orbit.pitch = tilt
				orbit.yaw = deg_to_rad(angle)
				orbit._update_camera(1)
				for mesh: MeshInstance3D in game.studio.find_children("*", "MeshInstance3D", true, false):
					var bounds: AABB = mesh.global_transform * mesh.get_aabb()
					check(bounds.intersects_segment(orbit.camera.global_position, orbit.target) == null,
						"Studio must not hide the tree at %d degrees, zoom %.2f, tilt %.2f" % [angle, zoom, tilt])
	orbit.yaw = 0.2
	orbit.pitch = 0.17
	orbit.distance = 7.0
	orbit._update_camera(1)
	var start_yaw := orbit.yaw
	touch(0, Vector2(300, 400), true)
	drag(0, Vector2(400, 430), Vector2(100, 30))
	touch(0, Vector2(400, 430), false)
	check(orbit.yaw != start_yaw, "One-finger drag must orbit")
	check(orbit.fingers.is_empty(), "Release must clear touch state")
	var distance := orbit.distance
	touch(0, Vector2(250, 400), true)
	touch(1, Vector2(450, 400), true)
	drag(1, Vector2(550, 400), Vector2(100, 0))
	check(orbit.distance < distance, "Spreading fingers must zoom in")
	touch(1, Vector2(550, 400), false)
	touch(0, Vector2(250, 400), false)
	check(game.renderer.selected_id == -1, "Pinch must not also select a branch")
	# Reset view for a projected tap on an actual rendered branch.
	orbit.yaw = 0.2
	orbit.distance = 7
	orbit._update_camera(1)
	var point: Vector2 = orbit.camera.unproject_position(game.tree.point(3, 0.65))
	touch(0, point, true)
	touch(0, point, false)
	check(game.renderer.selected_id >= 0, "Touch tap must select procedural geometry")
	var old_yaw := orbit.yaw
	var water_button: Button = game.hud.buttons.water
	var button_point := water_button.get_global_rect().get_center()
	touch(0, button_point, true)
	touch(0, button_point, false)
	await process_frame
	check(game.mode == "water", "Touch on toolbar must change tool")
	check(orbit.yaw == old_yaw and orbit.fingers.is_empty(), "UI touch must not leak into camera")
	var moisture: float = game.tree.moisture
	button_point = game.hud.action.get_global_rect().get_center()
	touch(0, button_point, true)
	touch(0, button_point, false)
	await process_frame
	check(game.tree.moisture > moisture, "Touch action must actually water")
	game._tool("prune")
	game.renderer.select(3)
	game._selection()
	await process_frame
	await process_frame
	var prune_snapshot: Dictionary = game.tree.to_data()
	for index in [1, 0, 1, 0, 1, 0]:
		button_point = game.hud.cut_buttons[index].get_global_rect().get_center()
		touch(0, button_point, true)
		touch(0, button_point, false)
		await process_frame
		await process_frame
		check(game.hud.cut_mode == index, "Touch must select both pruning modes without a popup")
		check(game.hud.cut_buttons[index].button_pressed and not game.hud.cut_buttons[1 - index].button_pressed, "Exactly one pruning mode remains selected")
		check(game.hud.cut_slider.visible == (index == 1), "Segment mode reveals length control")
		check(is_equal_approx(game.renderer.cut_fraction, game.hud.cut_slider.value / 100.0 if index == 1 else 0.0), "Touch mode selection updates cut preview")
		check(orbit.fingers.is_empty() and not orbit.mouse_down, "Pruning UI does not capture camera touches")
	check(game.tree.to_data() == prune_snapshot, "Changing pruning mode never cuts a branch")
	button_point = game.hud.buttons.inspect.get_global_rect().get_center()
	touch(0, button_point, true)
	touch(0, button_point, false)
	await process_frame
	check(game.mode == "inspect", "Toolbar remains responsive after repeated pruning mode changes")
	game._tool("inspect")
	var before: Dictionary = game.tree.to_data()
	game._suspend()
	game.last_wall -= 3600
	game._resume()
	check(game.tree.age_days >= float(before.age_days) + 1, "Resume must simulate elapsed wall time")
	print("Touch/lifecycle tests: %d failures" % failures)
	quit(1 if failures else 0)
