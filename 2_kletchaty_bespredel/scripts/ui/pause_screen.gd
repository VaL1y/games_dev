extends Control
class_name PauseScreen

signal resume_requested
signal settings_requested
signal menu_requested


func _ready() -> void:
	$Center/Panel/Content/Resume.pressed.connect(func() -> void: resume_requested.emit())
	$Center/Panel/Content/Settings.pressed.connect(func() -> void: settings_requested.emit())
	$Center/Panel/Content/Menu.pressed.connect(func() -> void: menu_requested.emit())
	for button: Button in [$Center/Panel/Content/Resume, $Center/Panel/Content/Settings, $Center/Panel/Content/Menu]:
		UITheme.style_button(button)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.echo:
		resume_requested.emit()
		get_viewport().set_input_as_handled()
