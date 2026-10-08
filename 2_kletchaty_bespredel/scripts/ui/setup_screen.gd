extends Control
class_name SetupScreen

signal back_requested
signal start_requested(board_size: int, players: Array[PlayerData])

const AVATARS := ["●", "◆", "★", "▲", "■", "✿", "♥", "☀", "☾", "✦"]

@onready var board_size_option: OptionButton = $Center/Panel/Content/BoardSize
@onready var first_name: LineEdit = $Center/Panel/Content/Players/PlayerOne/Name
@onready var first_avatar: OptionButton = $Center/Panel/Content/Players/PlayerOne/Avatar
@onready var first_color: ColorPickerButton = $Center/Panel/Content/Players/PlayerOne/Color
@onready var first_preview: ColorPreview = $Center/Panel/Content/Players/PlayerOne/ColorPreview
@onready var second_name: LineEdit = $Center/Panel/Content/Players/PlayerTwo/Name
@onready var second_avatar: OptionButton = $Center/Panel/Content/Players/PlayerTwo/Avatar
@onready var second_color: ColorPickerButton = $Center/Panel/Content/Players/PlayerTwo/Color
@onready var second_preview: ColorPreview = $Center/Panel/Content/Players/PlayerTwo/ColorPreview
@onready var message: Label = $Center/Panel/Content/Message


func _ready() -> void:
	for board_size: int in [24, 36, 60]:
		board_size_option.add_item("%d × %d" % [board_size, board_size], board_size)
	board_size_option.select(0)
	_populate_avatars(first_avatar)
	_populate_avatars(second_avatar)
	first_name.text = "Игрок 1"
	second_name.text = "Игрок 2"
	first_color.color = Color(0.20, 0.55, 0.95)
	second_color.color = Color(0.95, 0.28, 0.55)
	first_preview.sample_color = first_color.color
	second_preview.sample_color = second_color.color
	first_color.color_changed.connect(func(color: Color) -> void: first_preview.sample_color = color)
	second_color.color_changed.connect(func(color: Color) -> void: second_preview.sample_color = color)
	$Center/Panel/Content/Actions/Back.pressed.connect(func() -> void: back_requested.emit())
	$Center/Panel/Content/Actions/Start.pressed.connect(_start_game)
	for button: Button in [$Center/Panel/Content/Actions/Back, $Center/Panel/Content/Actions/Start]:
		UITheme.style_button(button)
	for input: Control in [first_name, second_name, first_avatar, second_avatar]:
		UITheme.style_input(input)
	UITheme.style_input(board_size_option)
	message.text = ""


func _populate_avatars(option: OptionButton) -> void:
	for index in AVATARS.size():
		option.add_item("%s  Аватар %d" % [AVATARS[index], index + 1], index)
	option.select(0)


func _start_game() -> void:
	var name_one := first_name.text.strip_edges()
	var name_two := second_name.text.strip_edges()
	if name_one.is_empty() or name_two.is_empty() or name_one.to_lower() == name_two.to_lower():
		message.text = "Введите разные имена игроков."
		return
	if _color_distance(first_color.color, second_color.color) < 0.45:
		message.text = "Выберите более разные цвета игроков."
		return
	var players: Array[PlayerData] = [
		_create_player(name_one, first_avatar, first_color),
		_create_player(name_two, second_avatar, second_color)
	]
	start_requested.emit(board_size_option.get_selected_id(), players)


func _create_player(player_name: String, avatar_option: OptionButton, color_option: ColorPickerButton) -> PlayerData:
	var player := PlayerData.new()
	player.display_name = player_name
	player.avatar = AVATARS[avatar_option.get_selected_id()]
	player.territory_color = color_option.color
	player.territory_color.a = 1.0
	return player


func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(Vector3(second.r, second.g, second.b))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.echo:
		back_requested.emit()
		get_viewport().set_input_as_handled()
