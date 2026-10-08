extends Control
class_name SettingsScreen

signal back_requested

const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const RENDER_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360), Vector2i(960, 540), Vector2i(1280, 720),
	Vector2i(1600, 900), Vector2i(1920, 1080)
]

@onready var window_size_option: OptionButton = $Center/Panel/Scroll/Content/WindowSize
@onready var apply_window_size_button: Button = $Center/Panel/Scroll/Content/ApplyWindowSize
@onready var render_resolution_option: OptionButton = $Center/Panel/Scroll/Content/RenderResolution
@onready var apply_render_resolution_button: Button = $Center/Panel/Scroll/Content/ApplyRenderResolution
@onready var fullscreen_toggle: CheckBox = $Center/Panel/Scroll/Content/Fullscreen
@onready var music_slider: HSlider = $Center/Panel/Scroll/Content/MusicSlider
@onready var effects_slider: HSlider = $Center/Panel/Scroll/Content/EffectsSlider

var _settings := ConfigFile.new()
var _available_window_sizes: Array[Vector2i] = []
var _applying_window_size := false


func _ready() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("Effects")
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	for size: Vector2i in WINDOW_SIZES:
		if size.x <= screen_size.x and size.y <= screen_size.y:
			_available_window_sizes.append(size)
	if _available_window_sizes.is_empty():
		_available_window_sizes.append(Vector2i(1280, 720))
	for index in _available_window_sizes.size():
		window_size_option.add_item(_format_size(_available_window_sizes[index]), index)
	for index in RENDER_RESOLUTIONS.size():
		render_resolution_option.add_item(_format_size(RENDER_RESOLUTIONS[index]), index)
	if _settings.load("user://settings.cfg") != OK:
		_settings = ConfigFile.new()
	var saved_width := int(_settings.get_value("window", "width", 1280))
	var saved_height := int(_settings.get_value("window", "height", 720))
	window_size_option.select(_window_size_index(Vector2i(saved_width, saved_height)))
	var saved_render_resolution := Vector2i(
		int(_settings.get_value("display", "render_width", 1280)),
		int(_settings.get_value("display", "render_height", 720))
	)
	render_resolution_option.select(_render_resolution_index(saved_render_resolution))
	fullscreen_toggle.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	window_size_option.disabled = fullscreen_toggle.button_pressed
	apply_window_size_button.disabled = fullscreen_toggle.button_pressed
	music_slider.value = float(_settings.get_value("audio", "Music", 50.0))
	effects_slider.value = float(_settings.get_value("audio", "Effects", 50.0))
	_apply_audio("Music", music_slider.value)
	_apply_audio("Effects", effects_slider.value)
	music_slider.value_changed.connect(func(value: float) -> void: _save_audio("Music", value))
	effects_slider.value_changed.connect(func(value: float) -> void: _save_audio("Effects", value))
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	apply_window_size_button.pressed.connect(_apply_window_size)
	apply_render_resolution_button.pressed.connect(_apply_render_resolution)
	$Center/Panel/Scroll/Content/Back.pressed.connect(func() -> void: back_requested.emit())
	UITheme.style_button(apply_window_size_button)
	UITheme.style_button(apply_render_resolution_button)
	UITheme.style_button($Center/Panel/Scroll/Content/Back)


func _format_size(size: Vector2i) -> String:
	return "%d × %d" % [size.x, size.y]


func _window_size_index(size: Vector2i) -> int:
	for index in _available_window_sizes.size():
		if _available_window_sizes[index] == size:
			return index
	return 0


func _render_resolution_index(size: Vector2i) -> int:
	for index in RENDER_RESOLUTIONS.size():
		if RENDER_RESOLUTIONS[index] == size:
			return index
	return 2


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_audio(bus_name: String, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_linear(bus_index, percent / 100.0)


func _save_audio(bus_name: String, percent: float) -> void:
	_apply_audio(bus_name, percent)
	_settings.set_value("audio", bus_name, percent)
	_settings.save("user://settings.cfg")


func _set_fullscreen(enabled: bool) -> void:
	window_size_option.disabled = enabled
	apply_window_size_button.disabled = enabled
	_settings.set_value("window", "fullscreen", enabled)
	_settings.save("user://settings.cfg")
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_apply_window_size")


func _apply_window_size() -> void:
	if fullscreen_toggle.button_pressed or _applying_window_size:
		return
	_applying_window_size = true
	apply_window_size_button.disabled = true
	var window_size := _available_window_sizes[window_size_option.get_selected_id()]
	var window := get_window()
	var screen := window.current_screen
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	if usable_rect.size == Vector2i.ZERO:
		usable_rect = Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
		for _frame in range(8):
			await get_tree().process_frame
			if window.mode == Window.MODE_WINDOWED:
				break
	# Move the normal window away from the Windows snap edge before resizing it.
	window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	window.position = usable_rect.position + Vector2i(40, 40)
	await get_tree().process_frame
	window.size = window_size
	var target_position := usable_rect.position + (usable_rect.size - window_size) / 2
	var min_position := usable_rect.position + Vector2i(16, 16)
	var max_position := usable_rect.end - window_size - Vector2i(16, 16)
	max_position.x = maxi(max_position.x, min_position.x)
	max_position.y = maxi(max_position.y, min_position.y)
	window.position = Vector2i(
		clampi(target_position.x, min_position.x, max_position.x),
		clampi(target_position.y, min_position.y, max_position.y)
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_settings.set_value("window", "width", window_size.x)
	_settings.set_value("window", "height", window_size.y)
	_settings.save("user://settings.cfg")
	_applying_window_size = false
	apply_window_size_button.disabled = fullscreen_toggle.button_pressed


func _apply_render_resolution() -> void:
	var render_resolution := RENDER_RESOLUTIONS[render_resolution_option.get_selected_id()]
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = render_resolution
	_settings.set_value("display", "render_width", render_resolution.x)
	_settings.set_value("display", "render_height", render_resolution.y)
	_settings.save("user://settings.cfg")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.echo:
		back_requested.emit()
		get_viewport().set_input_as_handled()
