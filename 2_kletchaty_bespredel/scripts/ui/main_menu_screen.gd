extends Control
class_name MainMenuScreen

signal play_requested
signal settings_requested
signal exit_requested


func _ready() -> void:
	$PlayButton.pressed.connect(func() -> void: play_requested.emit())
	$SettingsButton.pressed.connect(func() -> void: settings_requested.emit())
	$ExitButton.pressed.connect(func() -> void: exit_requested.emit())
	for button: TextureButton in [$PlayButton, $SettingsButton, $ExitButton]:
		button.mouse_entered.connect(func() -> void: button.modulate = Color(1.12, 1.12, 1.12))
		button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
