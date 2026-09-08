extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/v2_" + name + ".png")
func run() -> void:
	var scene = load("res://scenes/story.tscn").instantiate()
	scene.save_path = "res://tests/v2_preview_save.json"
	root.add_child(scene)
	scene.dialogue.reveal()
	await capture("intro")
	scene.model.state.pending = ""
	scene._present()
	await capture("map")
	scene.model.state.cell = "c18"
	scene.model.state.roll = 6
	scene._refresh()
	await capture("move")
	scene._inventory()
	await capture("inventory")
	scene._close_popup()
	scene._pause()
	scene._popup_select(1)
	await capture("pause")
	scene._close_popup()
	scene.model.state.cell = "c02"
	scene.model.state.event_cell = "c02"
	scene.model.state.pending = "event"
	scene._present()
	scene.dialogue.page = scene.dialogue.pages.size() - 1
	scene.dialogue._show_page()
	scene.dialogue.reveal()
	await capture("event")
	scene.model.state.map = 5
	scene.model.state.cell = "c50"
	scene.model.state.pending = "exit"
	scene._present()
	scene.dialogue.page = scene.dialogue.pages.size() - 1
	scene.dialogue._show_page()
	scene.dialogue.reveal()
	await capture("final")
	print("V2 PREVIEW COMPLETE")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()
