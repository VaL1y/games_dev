extends Control

@onready var main_actions: VBoxContainer = $CenterContainer/MainActions
@onready var story_panel: Control = $StoryPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var story_button: Button = $CenterContainer/MainActions/StoryButton
@onready var arcade_button: Button = $CenterContainer/MainActions/ArcadeButton
@onready var settings_button: Button = $CenterContainer/MainActions/SettingsButton
@onready var exit_button: Button = $CenterContainer/MainActions/ExitButton
@onready var story_back_button: Button = $StoryPanel/CenterContainer/PanelContainer/VBoxContainer/BackButton
@onready var settings_back_button: Button = $SettingsPanel/CenterContainer/PanelContainer/VBoxContainer/BackButton
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/CenterContainer/PanelContainer/VBoxContainer/FullscreenToggle
@onready var volume_slider: HSlider = $SettingsPanel/CenterContainer/PanelContainer/VBoxContainer/VolumeSlider
@onready var volume_label: Label = $SettingsPanel/CenterContainer/PanelContainer/VBoxContainer/VolumeLabel


func _ready() -> void:
	story_button.pressed.connect(_show_story)
	arcade_button.pressed.connect(_open_arcade)
	settings_button.pressed.connect(_show_settings)
	exit_button.pressed.connect(_exit_game)
	story_back_button.pressed.connect(_show_main)
	settings_back_button.pressed.connect(_show_main)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	volume_slider.value_changed.connect(_set_volume)

	story_panel.visible = false
	settings_panel.visible = false
	var master_bus := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus))
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_update_volume_label(volume_slider.value)
	_setup_story_menu()
	if "--verify-build" in OS.get_cmdline_user_args():
		call_deferred("_verify_build")

# Optional portable-build check: never touches the player's save.
func _verify_build() -> void:
	var scene = load("res://scenes/story.tscn").instantiate()
	scene.save_path = OS.get_executable_path().get_base_dir().path_join("verification-save.json")
	get_tree().root.add_child(scene)
	if not scene.model.content.error.is_empty():
		push_error(scene.model.content.error)
		get_tree().quit(1)
		return
	for i in range(scene.model.content.maps.size()):
		scene.model.state.map = i
		scene.model.state.cell = scene.model.current_map().start
		scene.board.refresh()
		if scene.board.texture == null or not scene.model.content.error.is_empty():
			push_error("Map image failed to load")
			get_tree().quit(1)
			return
	print("PORTABLE CHECK PASSED: external book and all six map images")
	get_tree().quit()


func _setup_story_menu() -> void:
	var box := $StoryPanel/CenterContainer/PanelContainer/VBoxContainer
	box.get_node("Title").text = "Сердце прилива"
	box.get_node("Description").text = "Глава I • Одиночная экспедиция\n6 карт, сокровище и тайна живой воды\nСвободный выбор пути"
	var start: Button = box.get_node("Story1")
	start.text = "Новая экспедиция"
	start.disabled = false
	start.pressed.connect(_new_story)
	var resume: Button = box.get_node("Story2")
	resume.text = "Продолжить экспедицию"
	var saved := StoryModel.new()
	resume.disabled = not saved.load_game()
	resume.pressed.connect(_launch_story.bind(true))
	for item in ["Story3", "Story4", "Story5"]:
		box.get_node(item).visible = false


func _new_story() -> void:
	if FileAccess.file_exists(StoryModel.SAVE_PATH):
		var confirmation := ConfirmationDialog.new()
		confirmation.title = "Новая экспедиция"
		confirmation.dialog_text = "Начать главу заново? Текущее сохранение будет заменено."
		confirmation.ok_button_text = "Начать заново"
		confirmation.cancel_button_text = "Отмена"
		add_child(confirmation)
		confirmation.confirmed.connect(_launch_story.bind(false))
		confirmation.canceled.connect(confirmation.queue_free)
		confirmation.popup_centered(Vector2i(580, 180))
	else:
		_launch_story(false)


func _launch_story(resume: bool) -> void:
	GameSession.story_continue = resume
	get_tree().change_scene_to_file("res://scenes/story.tscn")


func _open_arcade() -> void:
	get_tree().change_scene_to_file("res://scenes/arcade_setup.tscn")


func _show_story() -> void:
	main_actions.visible = false
	story_panel.visible = true


func _show_settings() -> void:
	main_actions.visible = false
	settings_panel.visible = true


func _show_main() -> void:
	story_panel.visible = false
	settings_panel.visible = false
	main_actions.visible = true


func _set_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _set_volume(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value, 0.001)))
	_update_volume_label(value)


func _update_volume_label(value: float) -> void:
	volume_label.text = "Громкость: %d%%" % roundi(value * 100.0)


func _exit_game() -> void:
	get_tree().quit()
