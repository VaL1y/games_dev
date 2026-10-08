extends Control

const MAIN_MENU_SCENE := preload("res://main_menu.tscn")
const SETUP_SCENE := preload("res://setup_screen.tscn")
const SETTINGS_SCENE := preload("res://settings_screen.tscn")
const GAME_SCENE := preload("res://game_screen.tscn")
const PAUSE_SCENE := preload("res://pause_screen.tscn")

@onready var screen_host: Control = $ScreenHost

var _current_screen: Control
var _screen_stack: Array[Control] = []


func _ready() -> void:
	_apply_saved_window_settings()
	_show_root(MAIN_MENU_SCENE)


func _apply_saved_window_settings() -> void:
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	var render_width := int(settings.get_value("display", "render_width", 1280))
	var render_height := int(settings.get_value("display", "render_height", 720))
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = Vector2i(render_width, render_height)
	var width := int(settings.get_value("window", "width", 1280))
	var height := int(settings.get_value("window", "height", 720))
	if bool(settings.get_value("window", "fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var screen_size := DisplayServer.screen_get_size()
		if width > screen_size.x or height > screen_size.y:
			width = mini(1280, screen_size.x)
			height = mini(720, screen_size.y)
		get_window().size = Vector2i(width, height)


func _show_root(scene: PackedScene) -> Control:
	for child in screen_host.get_children():
		screen_host.remove_child(child)
		child.queue_free()
	_screen_stack.clear()
	_current_screen = _mount(scene)
	_connect_screen(_current_screen)
	return _current_screen


func _push_screen(scene: PackedScene) -> Control:
	if _current_screen != null:
		_current_screen.visible = false
		_current_screen.process_mode = Node.PROCESS_MODE_DISABLED
		_screen_stack.append(_current_screen)
	_current_screen = _mount(scene)
	_connect_screen(_current_screen)
	return _current_screen


func _pop_screen() -> void:
	if _screen_stack.is_empty():
		return
	var closing := _current_screen
	screen_host.remove_child(closing)
	closing.queue_free()
	_current_screen = _screen_stack.pop_back()
	_current_screen.process_mode = Node.PROCESS_MODE_INHERIT
	_current_screen.visible = true


func _mount(scene: PackedScene) -> Control:
	var instance := scene.instantiate() as Control
	screen_host.add_child(instance)
	return instance


func _connect_screen(screen: Control) -> void:
	if screen is MainMenuScreen:
		screen.play_requested.connect(_open_setup)
		screen.settings_requested.connect(_open_settings)
		screen.exit_requested.connect(_exit_game)
	elif screen is SetupScreen:
		screen.back_requested.connect(_pop_screen)
		screen.start_requested.connect(_start_game)
	elif screen is SettingsScreen:
		screen.back_requested.connect(_pop_screen)
	elif screen is GameScreen:
		screen.pause_requested.connect(_open_pause)
		screen.settings_requested.connect(_open_settings)
		screen.setup_requested.connect(_open_setup)
	elif screen is PauseScreen:
		screen.resume_requested.connect(_pop_screen)
		screen.settings_requested.connect(_open_settings)
		screen.menu_requested.connect(_open_main_menu)


func _open_setup() -> void:
	_push_screen(SETUP_SCENE)


func _open_settings() -> void:
	_push_screen(SETTINGS_SCENE)


func _open_pause() -> void:
	_push_screen(PAUSE_SCENE)


func _start_game(board_size: int, players: Array[PlayerData]) -> void:
	var game_screen := _show_root(GAME_SCENE) as GameScreen
	game_screen.start_game(board_size, players)


func _open_main_menu() -> void:
	_show_root(MAIN_MENU_SCENE)


func _exit_game() -> void:
	get_tree().quit()
