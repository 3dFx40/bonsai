class_name BonsaiHUD
extends CanvasLayer

signal tool_selected(tool: String)
signal action_requested
signal undo_requested
signal debug_requested
signal sound_requested
signal quality_requested
signal language_requested(language: String)
signal preview_changed
signal name_requested(value: String)
signal tutorial_finished
signal backup_requested(importing: bool)
signal restore_confirmed
signal recovery_requested
signal portrait_requested
signal memory_selected(index: int)
signal comparison_requested
signal overlay_changed(open: bool)
signal creation_requested
signal tree_selected(id: String)
signal quit_requested

var root: Control
var date_label: Label
var title: Label
var brand: Label
var status: Label
var detail: Label
var advice: Label
var hint: Label
var action: Button
var undo: Button
var buttons: Dictionary = {}
var top: MarginContainer
var bottom: MarginContainer
var view_exit: Button
var sound_button: Button
var quality_button: Button
var language_picker: OptionButton
var name_edit: LineEdit
var prune_controls: VBoxContainer
var cut_mode := 0
var cut_buttons: Array[Button] = []
var cut_slider: HSlider
var cut_label: Label
var modal: ColorRect
var modal_body: VBoxContainer
var modal_title: Label
var settings_body: VBoxContainer
var guide_body: VBoxContainer
var journal_body: VBoxContainer
var restore_body: VBoxContainer
var journal_list: VBoxContainer
var collection_body: VBoxContainer
var collection_list: VBoxContainer
var collection_create: Button
var _trees: Array = []
var _active_tree := ""
var welcome_label: Label
var comparison: Button
var creation_button: Button
var quit_button: Button
var version_label: Label
var _state: BonsaiTree
var _message_key := "A little attention, every day."
var _message_args: Array = []
var _action_key := "Tap a branch to look closer"
var _action_args: Array = []
var _mode := "inspect"
var _welcome_key := ""
var _welcome_args: Array = []
var _first_guide := false

static func style(color: Color, radius := 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func studio_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_placeholder_color", "LineEdit", Color("778273"))
	for type in ["Label", "Button", "OptionButton", "LineEdit"]:
		theme.set_color("font_color", type, Color("293d34"))
	for type in ["Button", "OptionButton", "LineEdit"]:
		var normal := style(Color("e7e9df"), 14)
		normal.border_color = Color("d7dccf")
		normal.set_border_width_all(1)
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, style(Color("dce3d5"), 14))
		theme.set_stylebox("pressed", type, style(Color("395346"), 14))
		theme.set_color("font_pressed_color", type, Color("faf7ef"))
		theme.set_color("font_hover_pressed_color", type, Color("faf7ef"))
		theme.set_color("font_disabled_color", type, Color("939d90"))
		var focus := style(Color(0, 0, 0, 0), 14)
		focus.border_color = Color("9aa974")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, focus)
		var disabled := style(Color("eeeee6"), 14)
		theme.set_stylebox("disabled", type, disabled)
	theme.set_color("icon_normal_color", "Button", Color("395346"))
	theme.set_color("icon_hover_color", "Button", Color("395346"))
	theme.set_color("icon_pressed_color", "Button", Color("faf7ef"))
	theme.set_color("icon_hover_pressed_color", "Button", Color("faf7ef"))
	var panel := style(Color("f7f5ec"), 26)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	panel.shadow_color = Color(0.12, 0.18, 0.13, 0.14)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 5)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme

static func button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(80, 68)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

static func name_field(height: float = 68) -> LineEdit:
	var field := LineEdit.new()
	field.max_length = 40
	field.custom_minimum_size.y = height
	field.placeholder_text = "Your tree's name (optional)"
	# LineEdit expects mouse input for focus, but this app uses native touch.
	# Enter editing locally so focus and the native keyboard work
	# without enabling mouse emulation for camera and pruning gestures.
	field.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and event.pressed:
			field.grab_focus()
			field.edit()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(field.text, field.get_global_rect(), DisplayServer.KEYBOARD_TYPE_DEFAULT, field.max_length, field.caret_column)
			field.accept_event())
	return field

func _label(text: String, parent: Node, font_size := 22) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var b := button(text)
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := studio_theme()
	root.theme = theme
	# Separate layer keeps the app close control available above every screen.
	var close_layer := CanvasLayer.new()
	close_layer.layer = 5
	add_child(close_layer)
	var close_root := Control.new()
	close_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	close_root.theme = theme
	close_layer.add_child(close_root)
	quit_button = Button.new()
	quit_button.text = "×"
	quit_button.tooltip_text = "Close app"
	quit_button.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "focus"]:
		var compact := style(Color("e7e9df") if state == "normal" else Color("dce3d5"), 12)
		compact.content_margin_left = 4
		compact.content_margin_right = 4
		compact.content_margin_top = 2
		compact.content_margin_bottom = 2
		quit_button.add_theme_stylebox_override(state, compact)
	close_root.add_child(quit_button)
	quit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quit_button.offset_left = -68
	quit_button.offset_right = -16
	quit_button.pressed.connect(func(): quit_requested.emit())
	top = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 32
	root.add_child(top)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	top.add_child(header)
	var nav := HBoxContainer.new()
	header.add_child(nav)
	brand = _label("B O N S A I", nav, 18)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_color_override("font_color", Color("304737"))
	for b in [_button("Collection", nav, func(): open_panel("collection")), _button("Journal", nav, func(): open_panel("journal")), _button("Settings", nav, func(): open_panel("settings"))]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(124, 56)
		b.add_theme_font_size_override("font_size", 20)
	title = _label("Ficus microcarpa", header, 36)
	title.add_theme_color_override("font_color", Color("243a2b"))
	date_label = _label("", header, 20)
	date_label.add_theme_color_override("font_color", Color("41543f"))
	welcome_label = _label("", header, 20)
	welcome_label.add_theme_color_override("font_color", Color("304737"))
	welcome_label.hide()
	bottom = MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 22
	bottom.offset_right = -22
	bottom.offset_top = -360
	bottom.offset_bottom = -24
	root.add_child(bottom)
	var panel := PanelContainer.new()
	bottom.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var line := HBoxContainer.new()
	body.add_child(line)
	status = _label("", line, 20)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var view := _button("View", line, func(): tool_selected.emit("camera"))
	view.size_flags_horizontal = Control.SIZE_SHRINK_END
	view.custom_minimum_size.x = 110
	view.custom_minimum_size.y = 48
	advice = _label("", body, 21)
	advice.add_theme_color_override("font_color", Color("647452"))
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	body.add_child(toolbar)
	for entry in [["inspect", "Observe"], ["water", "Water"], ["fertilize", "Feed"], ["prune", "Prune"]]:
		var b := _button(entry[1], toolbar, func(): tool_selected.emit(entry[0]))
		var icons := {"inspect": "observe", "water": "water", "fertilize": "feed", "prune": "prune"}
		b.icon = load("res://assets/icons/%s.svg" % icons[entry[0]])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		b.add_theme_font_size_override("font_size", 20)
		b.toggle_mode = true
		buttons[entry[0]] = b
	detail = _label("A little attention, every day.", body, 19)
	detail.add_theme_color_override("font_color", Color("68736a"))
	prune_controls = VBoxContainer.new()
	body.add_child(prune_controls)
	var cut_choices := HBoxContainer.new()
	cut_choices.add_theme_constant_override("separation", 10)
	prune_controls.add_child(cut_choices)
	for index in 2:
		var choice := _button("Whole branch" if index == 0 else "Branch segment", cut_choices, set_cut_mode.bind(index))
		choice.toggle_mode = true
		choice.set_pressed_no_signal(index == cut_mode)
		cut_buttons.append(choice)
	cut_label = _label("", prune_controls, 19)
	cut_slider = _slider(prune_controls, 20, 90, 65)
	cut_slider.value_changed.connect(func(_value): _cut_options(); preview_changed.emit())
	var actions := HBoxContainer.new()
	body.add_child(actions)
	action = _button("Tap a branch to look closer", actions, func(): action_requested.emit())
	action.add_theme_stylebox_override("normal", style(Color("395346"), 14))
	action.add_theme_color_override("font_color", Color("faf7ef"))
	action.add_theme_stylebox_override("hover", style(Color("4b6656"), 14))
	action.add_theme_color_override("font_hover_color", Color("faf7ef"))
	undo = _button("Undo change", actions, func(): undo_requested.emit())
	undo.hide()
	hint = _label("DRAG TO ORBIT  ·  PINCH TO ZOOM", body, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("7b8475"))
	view_exit = _button("Back to care", root, func(): tool_selected.emit("inspect"))
	view_exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	view_exit.offset_left = 100
	view_exit.offset_right = -100
	view_exit.offset_top = -100
	view_exit.offset_bottom = -28
	view_exit.hide()
	comparison = _button("Show today's tree", root, func(): comparison_requested.emit())
	comparison.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	comparison.offset_left = 80
	comparison.offset_right = -80
	comparison.offset_top = -190
	comparison.offset_bottom = -115
	comparison.hide()
	_build_modal()
	get_viewport().size_changed.connect(_safe_layout)
	_safe_layout()
	set_tool("inspect")
	_retranslate()

func _slider(parent: Node, minimum: float, maximum: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.value = value
	slider.custom_minimum_size.y = 48
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)
	slider.gui_input.connect(_slider_touch.bind(slider))
	return slider

func _slider_touch(event: InputEvent, slider: HSlider) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed:
			if slider.get_meta("touch_index", -1) == event.index: slider.set_meta("touch_index", -1)
			return
		if slider.get_meta("touch_index", -1) != -1: return
		slider.set_meta("touch_index", event.index)
	elif event is InputEventScreenDrag:
		if slider.get_meta("touch_index", -1) != event.index: return
	else: return
	var margin := slider.get_theme_icon("grabber").get_width() * 0.5
	var fraction := clampf((event.position.x - margin) / maxf(1, slider.size.x - 2 * margin), 0, 1)
	if slider.is_layout_rtl(): fraction = 1 - fraction
	slider.value = lerpf(slider.min_value, slider.max_value, fraction)
	slider.accept_event()

func _build_modal() -> void:
	modal = ColorRect.new()
	modal.color = Color(0.08, 0.13, 0.10, 0.56)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 60
	panel.offset_bottom = -60
	modal.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	modal_title = _label("Settings", heading, 32)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("Close", heading, close_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_body)
	settings_body = _section()
	creation_button = _button("Create a new tree", settings_body, func(): creation_requested.emit())
	version_label = _label("", settings_body, 18)
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label("Your tree's name", settings_body)
	name_edit = name_field()
	settings_body.add_child(name_edit)
	name_edit.text_submitted.connect(func(value: String): name_requested.emit(value.strip_edges()))
	_button("Save name", settings_body, func(): name_requested.emit(name_edit.text.strip_edges()))
	_label("Language", settings_body)
	language_picker = OptionButton.new()
	language_picker.custom_minimum_size.y = 68
	language_picker.add_item("עברית")
	language_picker.add_item("English")
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.item_selected.connect(func(index): language_requested.emit("he" if index == 0 else "en"))
	settings_body.add_child(language_picker)
	sound_button = _button("Sound off", settings_body, func(): sound_requested.emit())
	quality_button = _button("Medium", settings_body, func(): quality_requested.emit())
	_label("Graphics quality", settings_body, 18)
	_button("Care guide", settings_body, func(): open_panel("guide"))
	_label("Keep a copy of your tree outside the app. Restore it on another device or after reinstalling.", settings_body, 20)
	_button("Export backup", settings_body, func(): backup_requested.emit(false))
	_button("Restore backup", settings_body, func(): backup_requested.emit(true))
	_button("Recover tree from before last restore", settings_body, func(): recovery_requested.emit())
	var dev := _button("Dev", settings_body, func(): close_panel(); debug_requested.emit())
	dev.visible = OS.is_debug_build() and ProjectSettings.get_setting("bonsai/developer_tools", false)
	guide_body = _section()
	_label("A tree of your own", guide_body, 30)
	_label("Start by looking. Drag to turn the tree and pinch to get closer. Tap a branch to inspect it.", guide_body)
	_label("Water when the soil is dry. Fertilizer is occasional; adding more does not mean faster growth.", guide_body)
	_label("Prune to make space. Amber branches show what will be removed.", guide_body)
	_label("Your tree grows between visits. Changes accumulate over hours. Long absences are protected, and the tree can recover.", guide_body)
	_label("The journal keeps the first portrait and your recent ones. Compare them to see your work over time.", guide_body)
	_button("Start caring", guide_body, close_panel)
	journal_body = _section()
	_button("Save a portrait", journal_body, func(): portrait_requested.emit())
	_label("Choose a portrait to compare with your tree today.", journal_body, 20)
	journal_list = VBoxContainer.new()
	journal_list.add_theme_constant_override("separation", 12)
	journal_body.add_child(journal_list)
	collection_body = _section()
	_label("All your trees keep growing between visits.", collection_body, 20)
	collection_create = _button("Create a new tree", collection_body, func(): creation_requested.emit())
	collection_list = VBoxContainer.new()
	collection_list.add_theme_constant_override("separation", 14)
	collection_body.add_child(collection_list)
	restore_body = _section()
	_label("Restore this backup? It replaces your current tree and settings. The previous save is kept as the local recovery copy.", restore_body)
	_button("Restore this tree", restore_body, func(): restore_confirmed.emit())
	_button("Cancel", restore_body, close_panel)
	modal.hide()

func _section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 20)
	modal_body.add_child(section)
	section.hide()
	return section

func open_panel(kind: String, first := false) -> void:
	_first_guide = first
	for section in [settings_body, guide_body, journal_body, restore_body, collection_body]: section.hide()
	match kind:
		"settings":
			if _state != null: name_edit.text = _state.display_name
			settings_body.show()
			modal_title.text = "Settings"
		"guide": guide_body.show(); modal_title.text = "Care guide"
		"journal": journal_body.show(); modal_title.text = "Journal"; update_journal()
		"collection": collection_body.show(); modal_title.text = tr("Collection"); update_collection()
		"restore": restore_body.show(); modal_title.text = "Restore backup"
	modal.show()
	overlay_changed.emit(true)

func close_panel() -> void:
	modal.hide()
	if _first_guide: tutorial_finished.emit()
	_first_guide = false
	overlay_changed.emit(false)

func set_collection(trees: Array, active: String, protected: bool) -> void:
	_trees = trees
	_active_tree = active
	collection_create.disabled = protected or trees.size() >= 32
	collection_list.set_meta("protected", protected)
	if collection_body.visible: update_collection()

func update_collection() -> void:
	for node in collection_list.get_children():
		collection_list.remove_child(node)
		node.queue_free()
	for i in _trees.size():
		var specimen: BonsaiTree = _trees[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", style(Color("e9ecdf"), 16))
		collection_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var preview := preload("res://scripts/ui/portrait_preview.gd").new()
		preview.portrait = specimen.to_data()
		row.add_child(preview)
		var caption := VBoxContainer.new()
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var species_name := tr(BonsaiCatalog.NAMES[specimen.species_id])
		var name := specimen.display_name if not specimen.display_name.is_empty() else tr("Tree %d") % (i + 1)
		var name_label := _label(name, caption, 24)
		name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_label(species_name, caption, 20)
		_label(tr("Day %d · %d leaves") % [int(specimen.age_days) + 1, specimen.leaf_count()], caption, 18)
		var active := specimen.id == _active_tree
		var select := _button("Current tree" if active else "Care for this tree", caption, func(): tree_selected.emit(specimen.id))
		select.disabled = active or collection_list.get_meta("protected", false)

func update_journal() -> void:
	for node in journal_list.get_children():
		journal_list.remove_child(node)
		node.queue_free()
	if _state == null: return
	for i in range(_state.memories.size() - 1, -1, -1):
		var memory: Dictionary = _state.memories[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", style(Color("e9ecdf"), 16))
		journal_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var preview := preload("res://scripts/ui/portrait_preview.gd").new()
		preview.portrait = memory.tree
		row.add_child(preview)
		var caption := VBoxContainer.new()
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(caption)
		_label(tr("Day %d · %d branches") % [int(memory.day) + 1, memory.tree.branches.size()], caption, 23)
		_button("Compare portrait", caption, func(): memory_selected.emit(i))
	_label("Recent care", journal_list, 26)
	for i in range(_state.history.size() - 1, maxi(-1, _state.history.size() - 11), -1):
		var event: Dictionary = _state.history[i]
		var labels := {"water": "Water", "feed": "Feed", "prune": "Prune", "trim": "Shorten branch", "shape": "Shape"}
		_label(tr("Day %d · %s") % [int(event.day) + 1, tr(labels.get(event.action, event.action))], journal_list, 20)

func _safe_layout() -> void:
	var inset_top := 0.0
	var inset_bottom := 0.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if safe.size.y > 0 and screen.y > 0:
			var ratio := get_viewport().get_visible_rect().size.y / screen.y
			inset_top = safe.position.y * ratio
			inset_bottom = maxf(0, screen.y - safe.end.y) * ratio
	top.offset_top = 76 + inset_top
	quit_button.offset_top = 8 + inset_top
	quit_button.offset_bottom = 60 + inset_top
	bottom.offset_bottom = -20 - inset_bottom
	var height := 540.0 if _mode == "prune" else (430.0 if _mode in ["water", "fertilize"] else (370.0 if detail.visible else 300.0))
	bottom.offset_top = -minf(height, get_viewport().get_visible_rect().size.y * 0.49) - inset_bottom
	view_exit.offset_bottom = -28 - inset_bottom
	view_exit.offset_top = -100 - inset_bottom
	comparison.offset_bottom = -115 - inset_bottom
	comparison.offset_top = -190 - inset_bottom
	var panel := modal.get_child(0) as Control
	panel.offset_top = 76 + inset_top
	panel.offset_bottom = -40 - inset_bottom

func set_tool(tool: String) -> void:
	_mode = tool
	for key in buttons: buttons[key].set_pressed_no_signal(key == tool)
	top.visible = tool != "camera"
	bottom.visible = tool != "camera"
	view_exit.visible = tool == "camera"
	prune_controls.visible = tool == "prune"
	advice.visible = tool in ["inspect", "water", "fertilize"]
	hint.visible = tool == "inspect"
	action.visible = tool != "inspect"
	action.disabled = tool in ["inspect", "prune"]
	match tool:
		"water": set_action("Water the soil")
		"fertilize": set_action("Add a small dose")
		"prune": set_action("Select a branch to cut")
		_: set_action("Tap a branch to look closer")
	_cut_options()
	_safe_layout()

func set_cut_mode(index: int) -> void:
	if index not in [0, 1]: return
	cut_mode = index
	for i in cut_buttons.size(): cut_buttons[i].set_pressed_no_signal(i == index)
	_cut_options()
	preview_changed.emit()

func _cut_options() -> void:
	cut_slider.visible = cut_mode == 1
	cut_label.visible = cut_mode == 1
	cut_label.text = tr("Keep %d%% of the branch") % int(cut_slider.value)

func update_state(tree: BonsaiTree) -> void:
	_state = tree
	title.text = tree.display_name if not tree.display_name.is_empty() else tr(BonsaiCatalog.NAMES.get(tree.species_id, "Ficus microcarpa"))
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	date_label.text = tr("DAY %03d   ·   YOUR WINDOW STUDIO") % (int(tree.age_days) + 1)
	var profile := BonsaiCatalog.profile(tree.species_id)
	var soil := "Dry" if tree.moisture < (profile.moisture_min if profile != null else 0.28) else ("Waterlogged" if tree.moisture > 0.95 else "Moist")
	var health := "Settling" if tree.pruning_stress > 0.15 else ("Needs care" if tree.stress > 0.4 else "Vigorous")
	status.text = tr("Soil: %s   ·   %s") % [tr(soil), tr(health)]
	advice.text = tr(tree.care_advice())
	# Keep an unsaved draft even after the keyboard closes or Save gains focus.
	if not settings_body.is_visible_in_tree(): name_edit.text = tree.display_name

func update_room_contrast(daylight: float) -> void:
	title.add_theme_color_override("font_color", Color("f2ead8").lerp(Color("243a2b"), daylight))
	date_label.add_theme_color_override("font_color", Color("dedccb").lerp(Color("41543f"), daylight))
	for label in [brand, welcome_label]:
		label.add_theme_color_override("font_color", Color("e4e4d4").lerp(Color("304737"), daylight))

func welcome(key: String, args: Array = []) -> void:
	_welcome_key = key
	_welcome_args = args
	welcome_label.text = _format(key, args)
	welcome_label.visible = not key.is_empty()

func message(key: String, args: Array = []) -> void:
	_message_key = key
	_message_args = args.duplicate()
	detail.text = _format(key, args)
	detail.visible = key not in ["A little attention, every day.", "Hold a branch to inspect. Drag to turn your tree."]
	if modal != null: _safe_layout()

func set_action(key: String, args: Array = []) -> void:
	_action_key = key
	_action_args = args.duplicate()
	action.text = _format(key, args)

func _format(key: String, args: Array) -> String:
	var translated: Array = args.map(func(value): return tr(value) if value is String else value)
	return tr(key) if args.is_empty() else tr(key) % translated

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _retranslate()

func _retranslate() -> void:
	version_label.text = tr("Version %s") % ProjectSettings.get_setting("application/config/version", "")
	language_picker.select(0 if TranslationServer.get_locale().begins_with("he") else 1)
	if _state != null: update_state(_state)
	message(_message_key, _message_args)
	set_action(_action_key, _action_args)
	welcome(_welcome_key, _welcome_args)
	_cut_options()
	if journal_body.visible: update_journal()
	if collection_body.visible:
		modal_title.text = tr("Collection")
		update_collection()
