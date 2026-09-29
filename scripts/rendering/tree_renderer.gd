class_name BonsaiTreeRenderer
extends Node3D

var tree: BonsaiTree
var selected_id := -1
var branches_mesh: MeshInstance3D
var highlight: MeshInstance3D
var foliage: MultiMeshInstance3D
var leaf_mesh: ArrayMesh
var samples: Dictionary = {}

func _ready() -> void:
	branches_mesh = MeshInstance3D.new()
	branches_mesh.material_override = BonsaiStudio.material(Color("766e53"))
	add_child(branches_mesh)
	highlight = MeshInstance3D.new()
	var selection := BonsaiStudio.material(Color("b5ba83"))
	selection.emission_enabled = true
	selection.emission = Color("6e774d")
	selection.emission_energy_multiplier = 0.25
	highlight.material_override = selection
	add_child(highlight)
	foliage = MultiMeshInstance3D.new()
	var mat := BonsaiStudio.material(Color.WHITE, 0.72)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage.material_override = mat
	add_child(foliage)
	leaf_mesh = _make_leaf()

func _make_leaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [Vector3(0, 0, 0), Vector3(-0.042, 0.008, 0.075), Vector3(0, 0.018, 0.095), Vector3(0.042, 0.008, 0.075), Vector3(0, 0, 0.185)]
	for index in [0, 2, 1, 0, 3, 2, 1, 2, 4, 2, 3, 4]:
		st.add_vertex(vertices[index])
	st.generate_normals()
	return st.commit()

func _tube(st: SurfaceTool, points: Array[Vector3], radius: float, sides: int = 8) -> void:
	var rings: Array = []
	var normals: Array = []
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
		var axis := Vector3.FORWARD
		if absf(tangent.dot(axis)) > 0.95: axis = Vector3.RIGHT
		var u := tangent.cross(axis).normalized()
		var v := tangent.cross(u).normalized()
		var ring: Array[Vector3] = []
		var normal_ring: Array[Vector3] = []
		var r := radius * lerpf(1.0, 0.45, float(i) / (points.size() - 1))
		for j in sides:
			var a := float(j) * TAU / sides
			var n := u * cos(a) + v * sin(a)
			ring.append(points[i] + n * r)
			normal_ring.append(n)
		rings.append(ring)
		normals.append(normal_ring)
	for s in range(points.size() - 1):
		for j in range(sides):
			var next := (j + 1) % sides
			for pair in [[s, j], [s, next], [s + 1, j], [s, next], [s + 1, next], [s + 1, j]]:
				st.set_normal(normals[pair[0]][pair[1]])
				st.add_vertex(rings[pair[0]][pair[1]])
	var end := points.size() - 1
	for j in sides:
		st.set_normal((points[end] - points[end - 1]).normalized())
		st.add_vertex(points[end])
		st.add_vertex(rings[end][j])
		st.add_vertex(rings[end][(j + 1) % sides])

func rebuild(state: BonsaiTree) -> void:
	tree = state
	samples.clear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for b: BonsaiBranch in tree.branches.values():
		var points: Array[Vector3] = []
		for step in range(7):
			points.append(tree.point(b.id, step / 6.0))
		samples[b.id] = points
		_tube(st, points, b.thickness)
		for leaf: Dictionary in b.leaves:
			var health: float = leaf.health
			var angle: float = leaf.angle
			var tilt := -0.25 - (1.0 - health) * 0.9 - maxf(0, 0.3 - tree.moisture)
			var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, tilt)
			basis = basis.scaled(Vector3.ONE * float(leaf.size))
			transforms.append(Transform3D(basis, tree.point(b.id, leaf.at)))
			var green := Color("354c27").lerp(Color("688141"), (sin(angle * 6) + 1) * 0.5)
			green = green.lerp(Color("b7a051"), clampf((1 - health) * 1.5 + maxf(0, 0.4 - float(tree.environment.light)), 0, 0.9))
			colors.append(green)
	for root: Dictionary in tree.roots:
		var root_points: Array[Vector3] = [Vector3(0, 0.36, 0), Vector3(cos(root.angle) * root.length * 0.5, 0.32, sin(root.angle) * root.length * 0.5), Vector3(cos(root.angle) * root.length, 0.3, sin(root.angle) * root.length)]
		_tube(st, root_points, root.thickness)
	branches_mesh.mesh = st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = leaf_mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	foliage.multimesh = mm
	select(selected_id)

func select(id: int) -> void:
	selected_id = id if tree != null and tree.branches.has(id) else -1
	highlight.visible = selected_id >= 0
	if selected_id < 0:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, samples[selected_id], tree.branches[selected_id].thickness * 1.10)
	highlight.mesh = st.commit()

func pick(screen: Vector2, camera: Camera3D) -> int:
	var best := -1
	var best_score := INF
	for id: int in samples:
		var points: Array = samples[id]
		for i in range(points.size() - 1):
			var a: Vector3 = to_global(points[i])
			var b: Vector3 = to_global(points[i + 1])
			if camera.is_position_behind(a) or camera.is_position_behind(b):
				continue
			var sa := camera.unproject_position(a)
			var sb := camera.unproject_position(b)
			var nearest := Geometry2D.get_closest_point_to_segment(screen, sa, sb)
			var d := screen.distance_to(nearest)
			var score := d + camera.global_position.distance_to(a) * 0.5
			if d < 24 and score < best_score:
				best_score = score
				best = id
	return best
