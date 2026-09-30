class_name BonsaiCreator
extends CanvasLayer

signal preview_requested(species: String, pot: String)
signal confirmed(species: String, pot: String, tree_name: String)
signal canceled

var root: Control
var species_id := ""
var pot_id := ""
var step := 0
var heading: Label
var description: Label
var choices: GridContainer
var name_edit: LineEdit
var next_button: Button
var back_button: Button
var can_cancel := false

func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 76
	root.add_child(top)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	top.add_child(header)
	_label("A tree of your own", header, 38, Color("243a2b"))
	_label("Choose a plant and a planter. Make it yours.", header, 22, Color("41543f"))
	var lower := MarginContainer.new()
	lower.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lower.offset_left = 22
	lower.offset_right = -22
	lower.offset_top = -460
	lower.offset_bottom = -24
	root.add_child(lower)
	var panel := PanelContainer.new()
	lower.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	heading = _label("", body, 28)
	choices = GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 10)
	choices.add_theme_constant_override("v_separation", 10)
	body.add_child(choices)
	description = _label("", body, 20)
	name_edit = LineEdit.new()
	name_edit.max_length = 40
	name_edit.placeholder_text = "Your tree's name (optional)"
	name_edit.custom_minimum_size.y = 64
	body.add_child(name_edit)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	back_button = BonsaiHUD.button("Back")
	actions.add_child(back_button)
	back_button.pressed.connect(go_back)
	next_button = BonsaiHUD.button("Choose a planter")
	actions.add_child(next_button)
	next_button.pressed.connect(_next)
	get_viewport().size_changed.connect(func(): lower.offset_top = -minf(460, get_viewport().get_visible_rect().size.y * 0.48))
	_rebuild()
	hide()

func _label(text: String, parent: Node, size: int, color := Color("f3efe3")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func open(theme: Theme, allow_cancel: bool) -> void:
	root.theme = theme
	can_cancel = allow_cancel
	species_id = ""
	pot_id = ""
	step = 0
	name_edit.clear()
	_rebuild()
	show()

func choose(id: String) -> void:
	if step == 0 and id in BonsaiCatalog.SPECIES:
		species_id = id
	elif step == 1 and id in BonsaiCatalog.POTS:
		pot_id = id
	else: return
	preview_requested.emit(species_id, pot_id if not pot_id.is_empty() else "slate_rectangle")
	_rebuild()

func _rebuild() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	heading.text = "1 / 2 · Choose your plant" if step == 0 else "2 / 2 · Choose your planter"
	var selected := species_id if step == 0 else pot_id
	var ids: Array = BonsaiCatalog.SPECIES if step == 0 else BonsaiCatalog.POTS
	for id: String in ids:
		var button := BonsaiHUD.button(BonsaiCatalog.NAMES[id])
		button.toggle_mode = true
		button.set_pressed_no_signal(id == selected)
		button.custom_minimum_size.y = 76
		if step == 1:
			var swatch := ColorRect.new()
			swatch.color = BonsaiCatalog.POT_COLORS[id]
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			swatch.offset_left = 18
			swatch.offset_right = -18
			swatch.offset_top = -8
			swatch.offset_bottom = -5
			button.add_child(swatch)
		choices.add_child(button)
		button.pressed.connect(choose.bind(id))
	description.text = tr(BonsaiCatalog.DESCRIPTIONS[species_id]) if not species_id.is_empty() else tr("Select a plant to see a preview.")
	description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_edit.visible = step == 1
	next_button.text = "Choose a planter" if step == 0 else "Start growing"
	next_button.disabled = selected.is_empty()
	back_button.visible = step == 1 or can_cancel
	back_button.text = "Back" if step == 1 else "Cancel"

func _next() -> void:
	if next_button.disabled: return
	if step == 0:
		step = 1
		_rebuild()
	else:
		confirmed.emit(species_id, pot_id, name_edit.text.strip_edges())

func go_back() -> void:
	if step == 1:
		step = 0
		_rebuild()
	elif can_cancel:
		canceled.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _rebuild()
