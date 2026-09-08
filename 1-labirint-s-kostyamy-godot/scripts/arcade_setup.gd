extends Control

@onready var count_label: Label = $CenterContainer/PanelContainer/VBoxContainer/CountLabel
@onready var start_button: Button = $CenterContainer/PanelContainer/VBoxContainer/StartButton
@onready var back_button: Button = $CenterContainer/PanelContainer/VBoxContainer/BackButton
@onready var count_buttons: Array[Button] = [
	$CenterContainer/PanelContainer/VBoxContainer/CountButtons/One,
	$CenterContainer/PanelContainer/VBoxContainer/CountButtons/Two,
	$CenterContainer/PanelContainer/VBoxContainer/CountButtons/Three,
	$CenterContainer/PanelContainer/VBoxContainer/CountButtons/Four,
]
@onready var player_rows: Array[PlayerSetupRow] = [
	$CenterContainer/PanelContainer/VBoxContainer/Players/Player1,
	$CenterContainer/PanelContainer/VBoxContainer/Players/Player2,
	$CenterContainer/PanelContainer/VBoxContainer/Players/Player3,
	$CenterContainer/PanelContainer/VBoxContainer/Players/Player4,
]

var _player_count := 1


func _ready() -> void:
	for index in range(count_buttons.size()):
		count_buttons[index].pressed.connect(_select_player_count.bind(index + 1))
	start_button.pressed.connect(_start_arcade)
	back_button.pressed.connect(_back_to_menu)
	_select_player_count(1)


func _select_player_count(player_count: int) -> void:
	_player_count = player_count
	count_label.text = "Игроков в партии: %d" % player_count

	for index in range(player_rows.size()):
		var is_active := index < player_count
		player_rows[index].visible = is_active
		if is_active:
			player_rows[index].configure(index)

	for index in range(count_buttons.size()):
		count_buttons[index].disabled = index + 1 == player_count


func _start_arcade() -> void:
	var players: Array[Dictionary] = []
	for index in range(_player_count):
		players.append(player_rows[index].get_player_config())

	GameSession.start_arcade(players)
	get_tree().change_scene_to_file(GameSession.GAME_SCENE)


func _back_to_menu() -> void:
	get_tree().change_scene_to_file(GameSession.MAIN_MENU_SCENE)
