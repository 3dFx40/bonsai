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
	env.ambient_light_energy = 0.70
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff9ed")
	sun.light_energy = 0.55
	sun.shadow_blur = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 15.0
	add_child(sun)
	var wall := material(Color("b9b9a9"))
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
	box(Vector3(0, 0.05, 0), Vector3(1.55, 0.16, 0.98), ceramic)
	for z in [-0.48, 0.48]:
		box(Vector3(0, 0.18, z), Vector3(1.62, 0.3, 0.07), ceramic)
	for x in [-0.78, 0.78]:
		box(Vector3(x, 0.18, 0), Vector3(0.07, 0.3, 0.98), ceramic)
	soil = box(Vector3(0, 0.28, 0), Vector3(1.48, 0.035, 0.89), material(Color("302920")))
	# Shoji-inspired window, deliberately geometry rather than a large texture.
	var paper := material(Color("e9e7d4"))
	box(Vector3(-2.45, 2.7, -3.5), Vector3(2.5, 4.1, 0.08), paper)
	var frame := material(Color("777765"))
	for x in [-3.7, -2.87, -2.04, -1.2]:
		box(Vector3(x, 2.7, -3.42), Vector3(0.045, 4.15, 0.045), frame)
	for y in [0.65, 1.68, 2.71, 3.74, 4.77]:
		box(Vector3(-2.45, y, -3.42), Vector3(2.55, 0.045, 0.045), frame)

func set_moisture(value: float) -> void:
	soil.material_override.albedo_color = Color("897356").lerp(Color("29281f"), clampf(value, 0, 1))
