class_name BonsaiHUD
extends CanvasLayer

signal tool_selected(tool: String)
signal action_requested
signal undo_requested
signal debug_requested
signal sound_requested
signal quality_requested
signal language_requested(language: String)
var root: Control
var date_label: Label
var status: Label
var detail: Label
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
var _state: BonsaiTree
var _message_key := "A little attention, every day."
var _message_args: Array = []
var _action_key := "Tap a branch to look closer"
var _action_args: Array = []

static func style(color: Color, radius := 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func button(text: String) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(96, 78)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

func _ready() -> void:
	root = Control.new()
	root.layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 22
	for type in ["Label", "Button"]:
		theme.set_color("font_color", type, Color("ebe8da"))
	theme.set_stylebox("normal", "Button", style(Color("2b332d")))
	theme.set_stylebox("hover", "Button", style(Color("414d3e")))
	theme.set_stylebox("pressed", "Button", style(Color("657553")))
	theme.set_stylebox("focus", "Button", style(Color(0.5, 0.6, 0.4, 0.2)))
	theme.set_stylebox("panel", "PanelContainer", style(Color("222b25"), 22))
	root.theme = theme
	top = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 38
	top.offset_right = -38
	top.offset_top = 46
	top.offset_bottom = 164
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(header_row)
	var header := VBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(header)
	var language_box := VBoxContainer.new()
	header_row.add_child(language_box)
	var language_label := Label.new()
	language_label.text = "Language"
	language_label.add_theme_font_size_override("font_size", 18)
	language_label.add_theme_color_override("font_color", Color("283725"))
	language_box.add_child(language_label)
	language_picker = OptionButton.new()
	language_picker.custom_minimum_size = Vector2(132, 70)
	language_picker.add_item("עברית")
	language_picker.add_item("English")
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.item_selected.connect(func(index: int): language_requested.emit("he" if index == 0 else "en"))
	language_box.add_child(language_picker)
	var eyebrow := Label.new()
	eyebrow.text = "B O N S A I   /   A LIVING PRACTICE"
	eyebrow.add_theme_font_size_override("font_size", 19)
	eyebrow.add_theme_color_override("font_color", Color("424b38"))
	header.add_child(eyebrow)
	var title := Label.new()
	title.text = "Ficus microcarpa"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("283725"))
	header.add_child(title)
	date_label = Label.new()
	date_label.add_theme_font_size_override("font_size", 20)
	date_label.add_theme_color_override("font_color", Color("526044"))
	header.add_child(date_label)
	bottom = MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -370
	bottom.offset_bottom = -28
	root.add_child(bottom)
	var panel := PanelContainer.new()
	bottom.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var line := HBoxContainer.new()
	body.add_child(line)
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 21)
	line.add_child(status)
	var dev := button("Dev")
	dev.custom_minimum_size = Vector2(80, 64)
	dev.size_flags_horizontal = Control.SIZE_SHRINK_END
	dev.visible = OS.is_debug_build() and ProjectSettings.get_setting("bonsai/developer_tools", false)
	dev.pressed.connect(func(): debug_requested.emit())
	line.add_child(dev)
	detail = Label.new()
	detail.text = "A little attention, every day."
	detail.add_theme_font_size_override("font_size", 19)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 7)
	body.add_child(toolbar)
	for entry in [["inspect", "Observe"], ["water", "Water"], ["fertilize", "Feed"], ["prune", "Prune"], ["camera", "View"]]:
		var b := button(entry[1])
		b.toggle_mode = true
		b.pressed.connect(func(): tool_selected.emit(entry[0]))
		toolbar.add_child(b)
		buttons[entry[0]] = b
	var actions := HBoxContainer.new()
	body.add_child(actions)
	action = button("Tap a branch to look closer")
	action.custom_minimum_size.y = 66
	action.disabled = true
	action.pressed.connect(func(): action_requested.emit())
	actions.add_child(action)
	undo = button("Undo cut")
	undo.visible = false
	undo.pressed.connect(func(): undo_requested.emit())
	actions.add_child(undo)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	hint = Label.new()
	hint.text = "DRAG TO ORBIT  ·  PINCH TO ZOOM"
	hint.add_theme_font_size_override("font_size", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	sound_button = button("Sound off")
	sound_button.custom_minimum_size = Vector2(106, 56)
	sound_button.add_theme_font_size_override("font_size", 16)
	sound_button.pressed.connect(func(): sound_requested.emit())
	footer.add_child(sound_button)
	quality_button = button("Medium")
	quality_button.tooltip_text = "Graphics quality"
	quality_button.custom_minimum_size = Vector2(96, 56)
	quality_button.add_theme_font_size_override("font_size", 16)
	quality_button.pressed.connect(func(): quality_requested.emit())
	footer.add_child(quality_button)
	view_exit = button("Back to care")
	view_exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	view_exit.offset_left = -205
	view_exit.offset_top = -110
	view_exit.offset_right = -28
	view_exit.offset_bottom = -32
	view_exit.visible = false
	view_exit.pressed.connect(func(): tool_selected.emit("inspect"))
	root.add_child(view_exit)
	set_tool("inspect")
	_retranslate()

func set_tool(tool: String) -> void:
	for key in buttons:
		buttons[key].set_pressed_no_signal(key == tool)
	top.visible = tool != "camera"
	bottom.visible = tool != "camera"
	view_exit.visible = tool == "camera"
	action.disabled = tool == "inspect" or tool == "prune"
	match tool:
		"water": set_action("Water the soil")
		"fertilize": set_action("Add a small dose")
		"prune": set_action("Select a branch to cut")
		_: set_action("Tap a branch to look closer")

func update_state(tree: BonsaiTree) -> void:
	_state = tree
	date_label.text = tr("DAY %03d   ·   YOUR WINDOW STUDIO") % (int(tree.age_days) + 1)
	var soil := "Moist"
	if tree.moisture < 0.28: soil = "Dry"
	elif tree.moisture > 0.95: soil = "Waterlogged"
	var health := "Settling" if tree.pruning_stress > 0.15 else ("Needs care" if tree.stress > 0.4 else "Vigorous")
	status.text = tr("Soil: %s   ·   %s") % [tr(soil), tr(health)]

func message(key: String, args: Array = []) -> void:
	_message_key = key
	_message_args = args.duplicate()
	detail.text = _format(key, args)

func set_action(key: String, args: Array = []) -> void:
	_action_key = key
	_action_args = args.duplicate()
	action.text = _format(key, args)

func _format(key: String, args: Array) -> String:
	var translated: Array = args.map(func(value): return tr(value) if value is String else value)
	return tr(key) if args.is_empty() else tr(key) % translated

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()

func _retranslate() -> void:
	language_picker.select(0 if TranslationServer.get_locale().begins_with("he") else 1)
	if _state != null: update_state(_state)
	message(_message_key, _message_args)
	set_action(_action_key, _action_args)
