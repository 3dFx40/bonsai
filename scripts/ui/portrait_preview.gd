extends SubViewportContainer

var portrait: Dictionary = {}

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(156, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 240)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = true
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var studio := BonsaiStudio.new()
	stage.add_child(studio)
	studio.sun.shadow_enabled = false
	var state := BonsaiTree.from_data(portrait)
	studio.set_pot(state.pot_id)
	studio.set_moisture(state.moisture)
	var renderer := BonsaiTreeRenderer.new()
	stage.add_child(renderer)
	renderer.rebuild(state)
	renderer.foliage.material_override.set_shader_parameter("wind_strength", 0.0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.7, 1.9, 5.0)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.fov = 34
	camera.current = true
	# Freeze each portrait after one real render; no simulation or ongoing GPU work.
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
