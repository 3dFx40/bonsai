extends Node3D

var tree := BonsaiTree.starter()
var renderer: BonsaiTreeRenderer

func _ready() -> void:
	add_child(BonsaiStudio.new())
	renderer = BonsaiTreeRenderer.new()
	add_child(renderer)
	renderer.rebuild(tree)
	add_child(BonsaiCamera.new())
	if "--capture" in OS.get_cmdline_user_args():
		for i in range(30):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/studio.png")
		get_tree().quit()
