class_name BonsaiDebugPanel
extends PanelContainer

signal command(action: String, value: float)
var report: Label
var graph: TextEdit
var pause_button: Button
var _state: BonsaiTree

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_right = -24
	offset_top = 170
	offset_bottom = -260
	var scroll := ScrollContainer.new()
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var title := Label.new()
	title.text = "DEVELOPER STUDIO"
	body.add_child(title)
	_button(body, "Close", "close")
	pause_button = _button(body, "Pause simulation", "pause")
	var times := HFlowContainer.new()
	body.add_child(times)
	for entry in [["+1 hour", 1.0 / 24], ["+1 day", 1.0], ["+1 week", 7.0], ["+1 month", 30.0]]:
		_button(times, entry[0], "time", entry[1])
	var note := Label.new()
	note.text = "Time buttons advance BIOLOGICAL time.\nNormal rate: 1 real hour = 1 biological day."
	note.add_theme_font_size_override("font_size", 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	for entry in [["Soil moisture", "moisture", 1.8], ["Nutrients", "nutrients", 2.0], ["Light", "light", 1.5]]:
		var label := Label.new()
		label.text = entry[0]
		body.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(0, 60)
		slider.max_value = entry[2]
		slider.step = 0.02
		slider.value = 0.6
		body.add_child(slider)
		slider.value_changed.connect(func(value: float): command.emit(entry[1], value))
	var actions := HFlowContainer.new()
	body.add_child(actions)
	_button(actions, "Damage", "damage")
	_button(actions, "Restore", "restore")
	_button(actions, "Spawn growth", "grow")
	_button(actions, "Reset tree…", "reset")
	report = Label.new()
	report.add_theme_font_size_override("font_size", 19)
	body.add_child(report)
	graph = TextEdit.new()
	graph.editable = false
	graph.custom_minimum_size = Vector2(0, 240)
	graph.add_theme_font_size_override("font_size", 17)
	body.add_child(graph)

func _button(parent: Control, title: String, action: String, value := 0.0) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(135, 64)
	button.pressed.connect(func(): command.emit(action, value))
	parent.add_child(button)
	return button

func update_state(tree: BonsaiTree) -> void:
	_state = tree
	if not visible or report == null:
		return
	report.text = tr("Day %.2f | %d branches | %d leaves\nMoisture %.3f | nutrients %.3f\nRoots %.3f | energy %.3f | stress %.3f\nPruning stress %.3f | light %.2f") % [tree.age_days, tree.branches.size(), tree.leaf_count(), tree.moisture, tree.nutrients, tree.root_health, tree.energy, tree.stress, tree.pruning_stress, tree.environment.light]
	var lines := tr("ID ← parent | length | radius | buds\n")
	for b: BonsaiBranch in tree.branches.values():
		lines += "%d ← %d | %.3f | %.4f | %d\n" % [b.id, b.parent_id, b.length, b.thickness, b.buds]
	graph.text = lines

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _state != null:
		update_state(_state)
