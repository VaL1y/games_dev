extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model := StoryModel.new()
	assert(model.content.error == "", model.content.error)
	assert(model.content.maps.size() == 6)
	assert(model.content.scenes.values().filter(func(s): return s.get("type") == "event").size() == 252)
	model.state.pending = ""
	model.state.cell = "c18"
	model.state.roll = 6
	var routes := model.routes()
	assert(routes.has("c12") and routes.has("c24") and routes.has("c19"))
	assert(routes["c24"].size() == 6) # The old forced stop was cell 19.
	model.move_to("c24")
	assert(model.state.pending == "event")
	model.resolve(0)
	assert(model.state.pending == "result")
	model.advance()
	assert(model.state.pending == "beat:beat_1_1")
	model.resolve(0)
	model.advance()
	assert(model.state.pending == "" and model.state.beats_done.has("beat_1_1"))
	model.state.roll = 1
	model.move_to("c23")
	if model.state.pending == "event":
		model.resolve(0)
		model.advance()
	else: model.advance()
	model.state.roll = 1
	model.move_to("c24")
	assert(model.state.pending == "quiet") # Returning cannot farm the event.
	model.advance()
	assert(model.state.pending == "")
	model.state.roll = 4
	assert(model.save_game("res://tests/v2_save.json") == OK)
	var loaded := StoryModel.new()
	assert(loaded.load_game("res://tests/v2_save.json"))
	assert(loaded.state.cell == model.state.cell and loaded.routes() == model.routes())
	assert(loaded.rng.randi() == model.rng.randi())
	# Conditional edges are bidirectional too.
	model.state.map = 4
	assert(not "c29" in model.neighbors("c23"))
	model.state.flags.bridge = true
	assert("c29" in model.neighbors("c23") and "c23" in model.neighbors("c29"))
	# Source book parsed into final choices; no hidden stat gate.
	assert(model.content.scenes.exit_6.choices.size() == 4)
	assert(not model.state.has("hp") and not model.state.has("insight"))
	# Exercise the actual controller keyboard paths and modal preservation.
	var scene = load("res://scenes/story.tscn").instantiate()
	scene.save_path = "res://tests/v2_ui_save.json"
	root.add_child(scene)
	await process_frame
	var page: int = scene.dialogue.page
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	scene._input(event)
	assert(scene.popup_kind == "pause")
	event.keycode = KEY_DOWN
	scene._input(event)
	assert(scene.popup_selected == 1)
	event.keycode = KEY_ENTER
	scene._input(event)
	assert(scene.popup_kind == "help")
	event.keycode = KEY_ESCAPE
	scene._input(event)
	scene._input(event)
	assert(scene.popup_kind == "" and scene.dialogue.page == page)
	scene.model.state.pending = ""
	scene._present()
	scene._roll()
	await create_timer(1.1).timeout
	assert(not scene.busy and scene.board.destinations.size() > 0)
	var dest: String = scene.board.destinations.keys()[0]
	scene._move(dest)
	await create_timer(.9).timeout
	assert(not scene.busy and scene.dialogue.visible)
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute("res://tests/v2_save.json")
	DirAccess.remove_absolute("res://tests/v2_ui_save.json")
	print("V2 CHECKS PASSED: book, movement, threshold ordering, no farming, save, keyboard and live turn")
	quit()
