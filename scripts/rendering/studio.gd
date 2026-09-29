class_name BonsaiStudio
extends Node3D

var soil: MeshInstance3D
var sun: DirectionalLight3D

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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c5c4b6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e8e4d5")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff9ed")
	sun.light_energy = 0.85
	sun.shadow_blur = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 15.0
	add_child(sun)
	var wall := material(Color("999d91"))
	box(Vector3(0, -0.68, 0), Vector3(20, 0.12, 20), material(Color("a9a392")))
	box(Vector3(0, 3, -3.6), Vector3(20, 8, 0.12), wall)
	var wood := material(Color("514539"))
	box(Vector3(0, -0.12, 0), Vector3(3.6, 0.16, 2.15), wood)
	box(Vector3(0, -0.23, 0), Vector3(3.15, 0.07, 1.9), material(Color("302d26")))
	for x in [-1.35, 1.35]:
		for z in [-0.7, 0.7]:
			box(Vector3(x, -0.46, z), Vector3(0.15, 0.6, 0.15), wood)
	# Raised, open ceramic planter; the procedural tree starts at y=0.3.
	var ceramic := material(Color("495551"), 0.42)
	put(_pot_mesh(), Vector3.ZERO, ceramic)
	soil = box(Vector3(0, 0.28, 0), Vector3(1.38, 0.035, 0.79), material(Color("302920")))
	var pebbles := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var grain := SphereMesh.new()
	grain.radius = 1
	grain.height = 1.4
	grain.radial_segments = 6
	grain.rings = 3
	mm.mesh = grain
	mm.instance_count = 220
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
	# Shoji-inspired window, deliberately geometry rather than a large texture.
	var paper := material(Color("e9e7d4"))
	box(Vector3(-3.6, 2.7, -3.5), Vector3(2.5, 4.1, 0.08), paper)
	var frame := material(Color("777765"))
	for x in [-4.85, -4.02, -3.19, -2.35]:
		box(Vector3(x, 2.7, -3.42), Vector3(0.045, 4.15, 0.045), frame)
	for y in [0.65, 1.68, 2.71, 3.74, 4.77]:
		box(Vector3(-3.6, y, -3.42), Vector3(2.55, 0.045, 0.045), frame)

func _pot_mesh() -> ArrayMesh:
	var profile := [Vector3(1.40, 0.02, 0.80), Vector3(1.48, 0.06, 0.88), Vector3(1.63, 0.29, 1.03), Vector3(1.61, 0.34, 1.01), Vector3(1.46, 0.34, 0.86), Vector3(1.43, 0.12, 0.83)]
	var rings: Array = []
	for dimensions: Vector3 in profile:
		var ring: Array[Vector3] = []
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

func set_moisture(value: float) -> void:
	soil.material_override.albedo_color = Color("897356").lerp(Color("29281f"), clampf(value, 0, 1))

func pour() -> void:
	var drops := MultiMeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.048
	mesh.radial_segments = 6
	mesh.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 24
	drops.multimesh = mm
	drops.material_override = material(Color("a7cbd0"), 0.2)
	add_child(drops)
	var animate := func(t: float):
		for i in mm.instance_count:
			var phase := fmod(t * 2 + i / 24.0, 1.0)
			var at := Vector3(0.4 + sin(i * 2.4) * 0.2, 0.32 + (1 - phase) * 0.65, cos(i * 2.4) * 0.18)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	animate.call(0.0)
	var tween := create_tween()
	tween.tween_method(animate, 0.0, 1.0, 0.85)
	tween.tween_callback(drops.queue_free)
