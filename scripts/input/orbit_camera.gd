class_name BonsaiCamera
extends Node3D

signal tapped(position: Vector2, held: bool)
var camera: Camera3D
var yaw := 0.2
var pitch := 0.17
var distance := 5.0
var target := Vector3(0, 1.20, 0)
var fingers: Dictionary = {}
var start := Vector2.ZERO
var previous := Vector2.ZERO
var start_ms := 0
var moved := false
var mouse_down := false
var cinematic := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 39
	camera.near = 0.08
	camera.far = 30
	add_child(camera)
	camera.current = true
	_update_camera(1.0)

func _process(delta: float) -> void:
	if cinematic:
		yaw += delta * 0.07
	_update_camera(1.0 - exp(-delta * 12.0))

func _update_camera(weight: float) -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.position = camera.position.lerp(target + offset, weight)
	camera.look_at(target)

func _orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.006
	pitch = clampf(pitch + delta.y * 0.004, 0.07, 0.68)

func _begin(pos: Vector2) -> void:
	start = pos
	previous = pos
	start_ms = Time.get_ticks_msec()
	moved = false

func _finish(pos: Vector2) -> void:
	if not moved and pos.distance_to(start) < 18:
		tapped.emit(pos, Time.get_ticks_msec() - start_ms > 500)

func _input(event: InputEvent) -> void:
	# Always release tracked touches, including releases over UI controls.
	if event is InputEventScreenTouch and not event.pressed:
		if fingers.has(event.index):
			if fingers.size() == 1:
				_finish(event.position)
			fingers.erase(event.index)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if mouse_down:
			_finish(event.position)
		mouse_down = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		fingers[event.index] = event.position
		if fingers.size() == 1:
			_begin(event.position)
		else:
			moved = true
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var old: Vector2 = fingers[event.index]
		if fingers.size() == 2:
			var other: Vector2 = fingers.values()[1] if fingers.keys()[0] == event.index else fingers.values()[0]
			var before := old.distance_to(other)
			var after: float = event.position.distance_to(other)
			if after > 5:
				distance = clampf(distance * before / after, 2.65, 7.0)
			moved = true
		else:
			if event.position.distance_to(start) > 18:
				moved = true
			if moved:
				_orbit(event.relative)
		fingers[event.index] = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mouse_down = true
			_begin(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.65, distance - 0.25)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(7, distance + 0.25)
	elif event is InputEventMouseMotion and mouse_down:
		if event.position.distance_to(start) > 18:
			moved = true
		if moved:
			_orbit(event.relative)
