class_name BonsaiStudio
extends Node3D

signal daylight_changed(amount: float)

var soil: MeshInstance3D
var sun: DirectionalLight3D
var room_environment: Environment
var fill: OmniLight3D
var window_material: StandardMaterial3D
var time_override := -1.0
var _light_elapsed := 0.0
var daylight_factor := 1.0
var planter: MeshInstance3D
var pebbles: MultiMeshInstance3D
var pot_id := ""
var moisture_tween: Tween
var visible_moisture := 0.66
var watering := false
var feet: Array[MeshInstance3D] = []
const WINDOW_CENTER := Vector3(-4.3, 3.15, -8.0)
const WINDOW_SIZE := Vector2(3.6, 4.6)

static func glaze(color: Color, matte := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/ceramic.gdshader")
	mat.set_shader_parameter("glaze_color", color)
	mat.set_shader_parameter("matte", 1.0 if matte else 0.0)
	return mat

static func material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return put(mesh, at, mat)

func put(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	return node

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	room_environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e3dfd3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e3e8e4")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.position = WINDOW_CENTER
	sun.light_color = Color("fff0d9")
	sun.light_energy = 1.10
	sun.shadow_blur = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 15.0
	add_child(sun)
	# One source of truth: rays travel from the visible window towards the tree.
	sun.look_at(Vector3(0, 0.45, 0))
	fill = OmniLight3D.new()
	fill.position = Vector3(2.4, 3.0, 3.0)
	fill.light_color = Color("dbe6de")
	fill.light_energy = 0.80
	fill.omni_range = 7.0
	fill.shadow_enabled = false
	add_child(fill)
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://assets/shaders/wood.gdshader")
	_build_room(wood)
	box(Vector3(0, -0.12, 0), Vector3(3.6, 0.12, 2.15), wood)
	box(Vector3(0, -0.055, 0), Vector3(3.56, 0.015, 2.11), wood)
	box(Vector3(0, -0.23, 0), Vector3(3.15, 0.07, 1.9), material(Color("302d26")))
	for x in [-1.35, 1.35]:
		for z in [-0.7, 0.7]:
			box(Vector3(x, -0.46, z), Vector3(0.15, 0.6, 0.15), wood)
	# Raised, open ceramic planter; the procedural tree starts at y=0.3.
	var ceramic := glaze(Color("495551"))
	planter = put(_pot_mesh(), Vector3.ZERO, ceramic)
	for x in [-0.48, 0.48]:
		for z in [-0.25, 0.25]:
			feet.append(box(Vector3(x, -0.01, z), Vector3(0.15, 0.065, 0.12), ceramic))
	soil = box(Vector3(0, 0.28, 0), Vector3(1.38, 0.035, 0.79), material(Color("302920")))
	pebbles = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var grain := SphereMesh.new()
	grain.radius = 1
	grain.height = 1.4
	grain.radial_segments = 6
	grain.rings = 3
	mm.mesh = grain
	mm.instance_count = 520
	var rng := RandomNumberGenerator.new()
	rng.seed = 8271
	for i in mm.instance_count:
		var size := rng.randf_range(0.006, 0.017)
		var pos := Vector3(rng.randf_range(-0.66, 0.66), 0.303, rng.randf_range(-0.37, 0.37))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), pos))
		mm.set_instance_color(i, Color("484133").lerp(Color("9b8c66"), rng.randf()))
	pebbles.multimesh = mm
	var gravel_mat := material(Color.WHITE)
	gravel_mat.vertex_color_use_as_albedo = true
	pebbles.material_override = gravel_mat
	add_child(pebbles)
	update_local_time()

func _process(delta: float) -> void:
	_light_elapsed += delta
	if _light_elapsed >= 1.0:
		_light_elapsed = 0
		update_local_time()

func update_local_time() -> void:
	var local := Time.get_time_dict_from_system()
	var hour := time_override if time_override >= 0 else float(local.hour) + float(local.minute) / 60.0 + float(local.second) / 3600.0
	set_hour(hour)

# Artistic local day, 06:00–18:00. Visual light is independent of biological time.
func set_hour(hour: float) -> void:
	var phase := (fposmod(hour, 24.0) - 6.0) / 12.0
	var daylight := sin(clampf(phase, 0, 1) * PI)
	var day := smoothstep(0.0, 0.22, daylight)
	daylight_factor = day
	var warm := 1.0 - smoothstep(0.15, 0.8, daylight)
	# Rays always enter through the rear opening; lateral sweep moves the lattice
	# and tree shadows. The wall masks direct sunlight outside the opening.
	var target := Vector3(lerpf(1.2, -1.2, clampf(phase, 0, 1)), 0.45 - daylight * 0.9, 0)
	sun.look_at(target)
	sun.light_energy = 1.15 * daylight
	sun.light_color = Color("fff4df").lerp(Color("ffb86f"), warm)
	room_environment.ambient_light_color = Color("8e9cb9").lerp(Color("e3e8e4"), day)
	room_environment.ambient_light_energy = lerpf(0.36, 0.72, day)
	room_environment.background_color = Color("32394b").lerp(Color("e3dfd3"), day)
	# The existing room lamp becomes warm at night, keeping care readable.
	fill.light_color = Color("ffd6a0").lerp(Color("dbe6de"), day)
	fill.light_energy = lerpf(1.65, 0.65, day)
	if window_material != null:
		window_material.albedo_color = Color("202c49").lerp(Color("e2eee5"), day)
	daylight_changed.emit(day)

func _build_room(wood: Material) -> void:
	var plaster := material(Color("d2c9b9"))
	var oak := wood.duplicate() as ShaderMaterial
	oak.set_shader_parameter("wood_color", Color("786044"))
	var dark_wood := material(Color("493e31"))
	box(Vector3(0, -0.68, 0), Vector3(20, 0.12, 20), oak)
	# The opening is real: the wall and deep frame cast shadows around the
	# incoming daylight. All architecture stays outside the camera orbit.
	var left := WINDOW_CENTER.x - WINDOW_SIZE.x / 2
	var right := WINDOW_CENTER.x + WINDOW_SIZE.x / 2
	var low := WINDOW_CENTER.y - WINDOW_SIZE.y / 2
	var high := WINDOW_CENTER.y + WINDOW_SIZE.y / 2
	box(Vector3((-10 + left) / 2, 3, -8), Vector3(left + 10, 8, 0.18), plaster)
	box(Vector3((right + 10) / 2, 3, -8), Vector3(10 - right, 8, 0.18), plaster)
	box(Vector3(WINDOW_CENTER.x, (low - 1) / 2, -8), Vector3(WINDOW_SIZE.x, low + 1, 0.18), plaster)
	box(Vector3(WINDOW_CENTER.x, (high + 7) / 2, -8), Vector3(WINDOW_SIZE.x, 7 - high, 0.18), plaster)
	for x in [-9.0, 9.0]:
		box(Vector3(x, 3, 0), Vector3(0.18, 8, 20), plaster)
		box(Vector3(x * 0.99, -0.42, 0), Vector3(0.08, 0.3, 20), dark_wood)
	box(Vector3(0, -0.42, -7.85), Vector3(18, 0.3, 0.12), dark_wood)
	for x in [left, right]:
		box(Vector3(x, WINDOW_CENTER.y, -7.87), Vector3(0.13, WINDOW_SIZE.y + 0.2, 0.34), oak)
	for y in [low, high]:
		box(Vector3(WINDOW_CENTER.x, y, -7.87), Vector3(WINDOW_SIZE.x + 0.24, 0.13, 0.34), oak)
	box(Vector3(WINDOW_CENTER.x, low - 0.03, -7.67), Vector3(WINDOW_SIZE.x + 0.38, 0.14, 0.6), oak)
	# Soft frosted glazing glows, while the timber lattice throws real shadows.
	var glass := material(Color("e2eee5"))
	window_material = glass
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pane := box(WINDOW_CENTER + Vector3(0, 0, -0.14), Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, 0.025), glass)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(1, 4):
		box(Vector3(left + WINDOW_SIZE.x * i / 4, WINDOW_CENTER.y, -7.82), Vector3(0.055, WINDOW_SIZE.y, 0.1), oak)
	for i in range(1, 5):
		box(Vector3(WINDOW_CENTER.x, low + WINDOW_SIZE.y * i / 5, -7.82), Vector3(WINDOW_SIZE.x, 0.045, 0.1), oak)
	# Woven tatami, bordered in muted charcoal, grounds the low worktable.
	var tatami := ShaderMaterial.new()
	tatami.shader = preload("res://assets/shaders/tatami.gdshader")
	for x in [-1.04, 1.04]:
		box(Vector3(x, -0.60, 0.2), Vector3(2.04, 0.04, 3.6), tatami)
		for edge in [-1.0, 1.0]:
			box(Vector3(x + edge, -0.575, 0.2), Vector3(0.045, 0.012, 3.6), material(Color("66695a")))
	# Floating oak cabinet and an ink-circle print balance the bright window.
	box(Vector3(0.15, 0.16, -7.55), Vector3(2.2, 0.9, 0.65), oak)
	box(Vector3(0.15, 0.63, -7.54), Vector3(2.32, 0.06, 0.72), dark_wood)
	for x in [-0.57, 0.15, 0.87]:
		box(Vector3(x, 0.15, -7.20), Vector3(0.018, 0.78, 0.025), dark_wood)
	box(Vector3(0.15, 2.05, -7.82), Vector3(1.05, 1.35, 0.08), dark_wood)
	box(Vector3(0.15, 2.05, -7.76), Vector3(0.92, 1.22, 0.025), material(Color("eee8d9")))
	var ink := TorusMesh.new()
	ink.inner_radius = 0.27
	ink.outer_radius = 0.30
	ink.rings = 48
	ink.ring_segments = 6
	var circle := put(ink, Vector3(0.15, 2.10, -7.72), material(Color("565a4c")))
	circle.rotation.x = PI / 2
	circle.scale.x = 0.9
	var vase := CylinderMesh.new()
	vase.top_radius = 0.11
	vase.bottom_radius = 0.20
	vase.height = 0.55
	vase.radial_segments = 32
	put(vase, Vector3(-0.5, 0.94, -7.50), glaze(Color("9caa9c"), true))
	for i in 3:
		var stem := box(Vector3(-0.5 + i * 0.06, 1.48, -7.5), Vector3(0.016, 0.7 + i * 0.14, 0.016), dark_wood)
		stem.rotation.z = (i - 1) * 0.18
	for i in 3:
		box(Vector3(0.75, 0.70 + i * 0.075, -7.5), Vector3(0.6 - i * 0.06, 0.07, 0.36), material(Color("8b8c73") if i == 1 else Color("c1b69f")))
	for i in 12:
		box(Vector3(5.1 + i * 0.16, 3.0, -7.78), Vector3(0.075, 7.2, 0.13), oak)

func set_pot(id: String) -> void:
	if pot_id == id: return
	pot_id = id
	var rounded := id in ["terracotta_round", "ivory_round"]
	planter.mesh = _pot_mesh(rounded)
	planter.material_override = glaze(BonsaiCatalog.POT_COLORS.get(id, Color("495551")), id == "terracotta_round")
	for foot in feet: foot.material_override = planter.material_override
	if rounded:
		var disk := CylinderMesh.new()
		disk.top_radius = 0.5
		disk.bottom_radius = 0.5
		disk.height = 0.035
		disk.radial_segments = 48
		soil.mesh = disk
		soil.scale = Vector3(1.38, 1, 0.79)
	else:
		var rectangle := BoxMesh.new()
		rectangle.size = Vector3(1.38, 0.035, 0.79)
		soil.mesh = rectangle
		soil.scale = Vector3.ONE
	# Keep the same gravel positions between previews; mask the round edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8271
	for i in pebbles.multimesh.instance_count:
		var size := rng.randf_range(0.006, 0.017)
		var pos := Vector3(rng.randf_range(-0.66, 0.66), 0.303, rng.randf_range(-0.37, 0.37))
		if rounded and pow(pos.x / 0.66, 2) + pow(pos.z / 0.37, 2) > 1: size = 0
		pebbles.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), pos))
		rng.randf()

func _pot_mesh(rounded := false) -> ArrayMesh:
	var profile := [Vector3(1.40, 0.02, 0.80), Vector3(1.48, 0.06, 0.88), Vector3(1.63, 0.29, 1.03), Vector3(1.61, 0.34, 1.01), Vector3(1.46, 0.34, 0.86), Vector3(1.43, 0.12, 0.83)]
	var rings: Array = []
	for dimensions: Vector3 in profile:
		var ring: Array[Vector3] = []
		if rounded:
			for j in 24:
				var angle := j * TAU / 24
				ring.append(Vector3(cos(angle) * dimensions.x * 0.5, dimensions.y, sin(angle) * dimensions.z * 0.5))
			rings.append(ring)
			continue
		var radius := 0.12
		for corner in 4:
			var angle := corner * PI * 0.5
			var center := Vector3((dimensions.x * 0.5 - radius) * (1 if corner in [0, 3] else -1), dimensions.y, (dimensions.z * 0.5 - radius) * (1 if corner < 2 else -1))
			for step in 6:
				var a := angle + step * PI * 0.1
				ring.append(center + Vector3(cos(a), 0, sin(a)) * radius)
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		for j in 24:
			var next := (j + 1) % 24
			for pair in [[i, j], [i, next], [i + 1, j], [i, next], [i + 1, next], [i + 1, j]]:
				st.add_vertex(rings[pair[0]][pair[1]])
	st.index()
	st.generate_normals()
	return st.commit()

func set_moisture(value: float, animate := false) -> void:
	if moisture_tween != null: moisture_tween.kill()
	if animate:
		moisture_tween = create_tween()
		moisture_tween.tween_method(_soil_color, visible_moisture, clampf(value, 0, 1), 1.3)
	else:
		_soil_color(clampf(value, 0, 1))

func _soil_color(value: float) -> void:
	visible_moisture = value
	soil.material_override.albedo_color = Color("897356").lerp(Color("29281f"), value)
	pebbles.material_override.albedo_color = Color.WHITE.lerp(Color("887f71"), value * 0.6)

func pour() -> void:
	if watering: return
	watering = true
	var can := Node3D.new()
	add_child(can)
	can.position = Vector3(0.72, 1.0, 0.05)
	var metal := material(Color("586d64"), 0.35)
	metal.metallic = 0.35
	var body := CylinderMesh.new()
	body.top_radius = 0.13
	body.bottom_radius = 0.16
	body.height = 0.24
	var vessel := MeshInstance3D.new()
	vessel.mesh = body
	vessel.material_override = metal
	can.add_child(vessel)
	var spout := CylinderMesh.new()
	spout.top_radius = 0.025
	spout.bottom_radius = 0.04
	spout.height = 0.36
	var nozzle := MeshInstance3D.new()
	nozzle.mesh = spout
	nozzle.material_override = metal
	nozzle.position = Vector3(-0.22, 0.015, 0)
	nozzle.rotation.z = -PI / 2.5
	can.add_child(nozzle)
	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.08
	handle_mesh.outer_radius = 0.11
	var handle := MeshInstance3D.new()
	handle.mesh = handle_mesh
	handle.material_override = metal
	handle.position.x = 0.18
	handle.rotation.x = PI / 2
	can.add_child(handle)
	var drops := MultiMeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.048
	mesh.radial_segments = 6
	mesh.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 40
	drops.multimesh = mm
	drops.material_override = material(Color("a7cbd0"), 0.2)
	add_child(drops)
	var animate := func(t: float):
		for i in mm.instance_count:
			var phase := fmod(t * 3 + i / 40.0, 1.0)
			var at := Vector3(0.38 + sin(i * 2.4) * 0.10 * phase, 0.32 + (1 - phase) * 0.64, 0.05 + cos(i * 2.4) * 0.09 * phase)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		can.rotation.z = sin(t * PI) * 0.16
	animate.call(0.0)
	var tween := create_tween()
	tween.tween_method(animate, 0.0, 1.0, 1.4)
	tween.tween_callback(drops.queue_free)
	tween.tween_callback(can.queue_free)
	tween.tween_callback(func(): watering = false)

func snip(at: Vector3) -> void:
	var tool := Node3D.new()
	tool.position = at
	add_child(tool)
	var steel := material(Color("b5bbb6"), 0.23)
	steel.metallic = 0.8
	var blades: Array[MeshInstance3D] = []
	for side in [-1, 1]:
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.018, 0.035, 0.3)
		blade.mesh = mesh
		blade.material_override = steel
		blade.position.z = 0.10
		blade.rotation.y = side * 0.42
		tool.add_child(blade)
		blades.append(blade)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.045
		torus.outer_radius = 0.06
		ring.mesh = torus
		ring.material_override = material(Color("333e36"))
		ring.position = Vector3(side * 0.08, 0, 0.31)
		tool.add_child(ring)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		blades[0].rotation.y = -lerpf(0.42, 0.04, t)
		blades[1].rotation.y = lerpf(0.42, 0.04, t), 0.0, 1.0, 0.18)
	tween.tween_interval(0.2)
	tween.tween_callback(tool.queue_free)

func feed() -> void:
	var dose := Node3D.new()
	add_child(dose)
	for i in 14:
		var grain := SphereMesh.new()
		grain.radius = 0.009
		grain.height = 0.018
		grain.radial_segments = 6
		grain.rings = 3
		var pellet := MeshInstance3D.new()
		pellet.mesh = grain
		pellet.material_override = material(Color("b7a17b"))
		pellet.position = Vector3(sin(i * 2.4) * 0.28, 0.65 + i * 0.02, cos(i * 2.4) * 0.2)
		dose.add_child(pellet)
		var tween := create_tween()
		tween.tween_property(pellet, "position:y", 0.31, 0.3 + i * 0.015).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var finish := create_tween()
	finish.tween_interval(1.0)
	finish.tween_callback(dose.queue_free)
