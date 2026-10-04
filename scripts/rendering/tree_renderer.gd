class_name BonsaiTreeRenderer
extends Node3D

var tree: BonsaiTree
var selected_id := -1
var branches_mesh: MeshInstance3D
var highlight: MeshInstance3D
var foliage: MultiMeshInstance3D
var leaf_mesh: ArrayMesh
var samples: Dictionary = {}
var tip_radii: Dictionary = {}
var cut_fraction := -1.0
var _last_pick := Vector2(-1000, -1000)
var _pick_index := 0
var _leaf_species := ""

func _ready() -> void:
	branches_mesh = MeshInstance3D.new()
	var bark := ShaderMaterial.new()
	bark.shader = preload("res://assets/shaders/bark.gdshader")
	branches_mesh.material_override = bark
	add_child(branches_mesh)
	highlight = MeshInstance3D.new()
	var selection := BonsaiStudio.material(Color("b5ba83"))
	selection.emission_enabled = true
	selection.emission = Color("6e774d")
	selection.emission_energy_multiplier = 0.25
	highlight.material_override = selection
	add_child(highlight)
	foliage = MultiMeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/leaf.gdshader")
	foliage.material_override = mat
	add_child(foliage)
	leaf_mesh = _make_leaf()

func _make_leaf(succulent := false, elm := false, narrow := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Curved blade with a central ridge, rather than a flat triangle fan.
	for row in range(8):
		for col in range(2):
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]:
				var uv := Vector2((col + corner.x) / 2.0, (row + corner.y) / 8.0)
				var outline := pow(sin(uv.y * PI), 0.55 if succulent else (1.2 if narrow else 0.8))
				if elm: outline *= 1.0 + cos(uv.y * PI * 8.0) * 0.055
				var width := outline * 0.070
				var x := (uv.x * 2.0 - 1.0) * width
				var y := sin(uv.y * PI) * (0.012 + (0.026 if succulent else 0.015) * (1.0 - absf(uv.x * 2.0 - 1.0)))
				st.set_uv(uv)
				st.set_color(Color.WHITE)
				st.add_vertex(Vector3(x, y, uv.y * 0.24))
	st.index()
	st.generate_normals()
	return st.commit()

func _tube(st: SurfaceTool, points: Array[Vector3], radius: float, sides: int = 12, wound := false, tip_radius := -1.0) -> void:
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
		var t := float(i) / (points.size() - 1)
		var end_radius := tip_radius if tip_radius > 0 else radius * 0.45
		var r := lerpf(radius, end_radius, t) + radius * 0.18 * exp(-t * 12.0)
		for j in sides:
			var a := float(j) * TAU / sides
			var n := u * cos(a) + v * sin(a)
			var ridge := 1.0 + sin(a * 5.0 + points[i].y * 3.0) * 0.035
			ring.append(points[i] + n * r * ridge)
			normal_ring.append(n)
		rings.append(ring)
		normals.append(normal_ring)
	for s in range(points.size() - 1):
		for j in range(sides):
			var next := (j + 1) % sides
			for pair in [[s, j], [s + 1, j], [s, next], [s, next], [s + 1, j], [s + 1, next]]:
				var p: Vector3 = rings[pair[0]][pair[1]]
				var variation := 0.83 + 0.13 * sin(p.y * 43 + p.x * 95 + p.z * 68)
				st.set_color(Color(variation, variation, variation, 1))
				st.set_normal(normals[pair[0]][pair[1]])
				st.set_uv(Vector2(float(j + (1 if pair[1] == next else 0)) / sides, float(pair[0]) / (points.size() - 1)))
				st.add_vertex(rings[pair[0]][pair[1]])
	var end := points.size() - 1
	st.set_color(Color("e2c3a0") if wound else Color.WHITE)
	for j in sides:
		st.set_normal((points[end] - points[end - 1]).normalized())
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(points[end])
		st.add_vertex(rings[end][(j + 1) % sides])
		st.add_vertex(rings[end][j])

func rebuild(state: BonsaiTree) -> void:
	tree = state
	var profile := BonsaiCatalog.profile(state.species_id)
	var jade := profile.leaf_shape == "succulent"
	var elm := profile.leaf_shape == "serrated"
	if _leaf_species != state.species_id:
		leaf_mesh = _make_leaf(jade, elm, profile.leaf_shape in ["olive", "willow"])
		_leaf_species = state.species_id
	branches_mesh.material_override.set_shader_parameter("bark_color", profile.bark_color)
	foliage.material_override.set_shader_parameter("succulent", 1.0 if jade else 0.0)
	samples.clear()
	tip_radii.clear()
	for b: BonsaiBranch in tree.branches.values(): tip_radii[b.id] = b.thickness * 0.45
	# A continuing leader meets its parent without a pinched neck.
	for b: BonsaiBranch in tree.branches.values():
		if b.parent_id >= 0 and b.attachment >= 0.98:
			tip_radii[b.parent_id] = maxf(tip_radii[b.parent_id], b.thickness * 1.18)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for b: BonsaiBranch in tree.branches.values():
		var points: Array[Vector3] = []
		for step in range(13):
			points.append(tree.point(b.id, step / 12.0))
		samples[b.id] = points
		_tube(st, points, b.thickness, 12, b.pruned, tip_radii[b.id])
		for leaf: Dictionary in b.leaves:
			var health: float = leaf.health
			var angle: float = leaf.angle
			var tilt := -0.20 + sin(angle * 3.0) * 0.35 + (1.0 - health) * 0.9 + maxf(0, 0.3 - tree.moisture)
			var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.FORWARD, sin(angle * 7.0) * 0.35)
			var shape := profile.leaf_scale
			basis = basis.scaled(shape * float(leaf.size) * (0.86 + 0.18 * (sin(angle * 13.0) + 1.0) * 0.5))
			transforms.append(Transform3D(basis, tree.point(b.id, leaf.at)))
			var green := profile.leaf_color.lerp(profile.leaf_color.lightened(0.22), (sin(angle * 6) + 1) * 0.5)
			green = green.lerp(Color("8ba557"), clampf(1.0 - float(leaf.age) / 7.0, 0, 1) * 0.24)
			if jade: green = green.lerp(Color("60925d"), 0.5)
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
	var material := highlight.material_override as StandardMaterial3D
	material.albedo_color = Color("dfa960") if cut_fraction >= 0 else Color("b5ce9b")
	material.emission = material.albedo_color
	if cut_fraction >= 0:
		var ids := tree.descendants(selected_id) if cut_fraction == 0 else tree.cut_descendants(selected_id, cut_fraction)
		for key in ids: _tube(st, samples[key], tree.branches[key].thickness * 1.13, 12, false, tip_radii[key] * 1.13)
		if cut_fraction > 0:
			var points: Array[Vector3] = []
			for step in range(13): points.append(tree.point(selected_id, lerpf(cut_fraction, 1, step / 12.0)))
			_tube(st, points, lerpf(tree.branches[selected_id].thickness, tip_radii[selected_id], cut_fraction) * 1.13, 12, false, tip_radii[selected_id] * 1.13)
	else:
		_tube(st, samples[selected_id], tree.branches[selected_id].thickness * 1.10, 12, false, tip_radii[selected_id] * 1.10)
	highlight.mesh = st.commit()

func pick(screen: Vector2, camera: Camera3D) -> int:
	var candidates: Array = []
	for id: int in samples:
		var best_score := INF
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
		if best_score < INF: candidates.append({"id": id, "score": best_score})
	candidates.sort_custom(func(a, b): return a.score < b.score)
	if candidates.is_empty(): return -1
	_pick_index = (_pick_index + 1) % candidates.size() if screen.distance_to(_last_pick) < 18 else 0
	_last_pick = screen
	return candidates[_pick_index].id
