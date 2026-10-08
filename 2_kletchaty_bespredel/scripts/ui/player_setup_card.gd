extends PanelContainer
class_name PlayerSetupCard

signal color_selection_changed(player_index: int, color_index: int)

const AVATARS: Array[Texture2D] = [
	preload("res://assets/avatars/fox.svg"),
	preload("res://assets/avatars/cat.svg"),
	preload("res://assets/avatars/owl.svg"),
	preload("res://assets/avatars/frog.svg"),
	preload("res://assets/avatars/bear.svg")
]
const AVATAR_NAMES := ["Лиса", "Кот", "Сова", "Лягушка", "Медведь"]
const COLORS: Array[Color] = [
	Color("#3488e8"), Color("#e64f81"), Color("#24a98d"),
	Color("#efaa35"), Color("#8958c8"), Color("#69a943"), Color("#e46c45")
]
const COLOR_NAMES := ["Синий", "Розовый", "Бирюзовый", "Янтарный", "Фиолетовый", "Зелёный", "Коралловый"]

@onready var _title: Label = $Content/Title
@onready var _name_input: LineEdit = $Content/Name
@onready var _avatar_buttons: Array[TextureButton] = [
	$Content/AvatarRow/AvatarOne,
	$Content/AvatarRow/AvatarTwo,
	$Content/AvatarRow/AvatarThree,
	$Content/AvatarRow/AvatarFour,
	$Content/AvatarRow/AvatarFive
]
@onready var _color_buttons: Array[Button] = [
	$Content/ColorRow/ColorOne,
	$Content/ColorRow/ColorTwo,
	$Content/ColorRow/ColorThree,
	$Content/ColorRow/ColorFour,
	$Content/ColorRow/ColorFive,
	$Content/ColorRow/ColorSix,
	$Content/ColorRow/ColorSeven
]

var player_index: int = 0
var selected_color_index: int = 0
var selected_avatar_index: int = 0


func _ready() -> void:
	var avatar_group := ButtonGroup.new()
	avatar_group.allow_unpress = false
	for index in _avatar_buttons.size():
		var button := _avatar_buttons[index]
		button.toggle_mode = true
		button.button_group = avatar_group
		button.texture_normal = AVATARS[index]
		button.tooltip_text = AVATAR_NAMES[index]
		button.pressed.connect(_select_avatar.bind(index))
	var color_group := ButtonGroup.new()
	color_group.allow_unpress = false
	for index in _color_buttons.size():
		var button := _color_buttons[index]
		button.toggle_mode = true
		button.button_group = color_group
		button.tooltip_text = COLOR_NAMES[index]
		button.pressed.connect(_select_color.bind(index))
		_set_color_style(index)
	_update_avatar_appearance()
	UITheme.style_input(_name_input)


func configure(index: int, player_name: String, avatar_index: int, color_index: int) -> void:
	player_index = index
	selected_avatar_index = clampi(avatar_index, 0, AVATARS.size() - 1)
	selected_color_index = clampi(color_index, 0, COLORS.size() - 1)
	_title.text = "Игрок %d" % (player_index + 1)
	_name_input.text = player_name
	_avatar_buttons[selected_avatar_index].set_pressed_no_signal(true)
	_color_buttons[selected_color_index].set_pressed_no_signal(true)
	_update_avatar_appearance()
	_update_color_styles()


func create_player_data() -> PlayerData:
	var player := PlayerData.new()
	player.display_name = _name_input.text.strip_edges()
	player.avatar = AVATARS[selected_avatar_index]
	player.territory_color = COLORS[selected_color_index]
	return player


func set_color_available(index: int, available: bool) -> void:
	_color_buttons[index].disabled = not available and index != selected_color_index


func _select_avatar(index: int) -> void:
	selected_avatar_index = index
	_update_avatar_appearance()


func _update_avatar_appearance() -> void:
	for index in _avatar_buttons.size():
		_avatar_buttons[index].modulate = Color.WHITE if index == selected_avatar_index else Color(0.70, 0.70, 0.76)


func _select_color(index: int) -> void:
	selected_color_index = index
	_update_color_styles()
	color_selection_changed.emit(player_index, index)


func _update_color_styles() -> void:
	for index in _color_buttons.size():
		_set_color_style(index)


func _set_color_style(index: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLORS[index]
	style.set_corner_radius_all(8)
	style.set_border_width_all(4 if index == selected_color_index else 1)
	style.border_color = Color.WHITE if index == selected_color_index else Color(0.27, 0.18, 0.4, 0.75)
	_color_buttons[index].add_theme_stylebox_override("normal", style)
	_color_buttons[index].add_theme_stylebox_override("hover", style)
	_color_buttons[index].add_theme_stylebox_override("pressed", style)
