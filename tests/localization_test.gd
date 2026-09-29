extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud.language_picker.item_selected.emit(0)
	await process_frame
	check(game.settings.language == "he", "Language picker must select Hebrew")
	check(game.hud.root.is_layout_rtl(), "Hebrew interface must mirror to RTL")
	check(TranslationServer.translate("Water") == "השקיה", "Hebrew catalog must be loaded")
	check(game.hud.status.text.contains("אדמה"), "Dynamic condition must be Hebrew")
	game._tool("prune")
	game.renderer.select(3)
	game._selection()
	check(game.hud.action.text.contains("לגזום"), "Pruning action with counts must be translated")
	var before: Dictionary = game.tree.to_data()
	game.hud.language_picker.item_selected.emit(1)
	await process_frame
	check(not game.hud.root.is_layout_rtl(), "English interface must return to LTR")
	check(game.hud.action.text.begins_with("Cut branch"), "Existing dynamic action must update immediately")
	check(game.tree.to_data() == before, "Language changes must not alter the tree")
	game._tool("inspect")
	game._selection(true)
	game.hud.language_picker.item_selected.emit(0)
	await process_frame
	check(game.hud.detail.text.contains("ענף") and game.hud.detail.text.contains("בריא"), "Branch details and nested condition must retranslate")
	game._toggle_debug()
	check(game.debug_panel.report.text.contains("לחות"), "Developer values must be Hebrew")
	check(game.debug_panel.graph.text.contains("ניצנים"), "Graph headings must be Hebrew")
	game.hud.message("Could not write save file (%d).", [7])
	check(game.hud.detail.text.contains("קוד 7"), "Save error codes must survive formatting")
	game.hud.language_picker.item_selected.emit(1)
	await process_frame
	check(game.hud.detail.text == "Could not write save file (7).", "Errors must update without losing parameters")
	var saves := BonsaiSave.new()
	var document := saves.make_document([game.tree], game.tree.id, game.settings, 1000, 0)
	check(saves.valid(document), "Language setting must be valid save data")
	document.settings.erase("language")
	check(saves.valid(document), "Older saves without a language must remain valid")
	document.settings.language = "unknown"
	check(not saves.valid(document), "Unsupported saved language must be rejected")
	print("Localization tests: %d failures" % failures)
	quit(1 if failures else 0)
