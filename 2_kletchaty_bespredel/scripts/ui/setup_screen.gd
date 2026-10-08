extends Control
class_name SetupScreen

signal back_requested
signal start_requested(board_size: int, players: Array[PlayerData], territory_mode: int)

const PLAYER_SETUP_CARD := preload("res://player_setup_card.tscn")
const BOARD_SIZES := [24, 36, 60]
const PLAYER_COUNTS := [2, 3, 4]

@onready var board_size_option: OptionButton = $Center/Panel/Content/SettingsRow/BoardSizeGroup/BoardSize
@onready var player_count_option: OptionButton = $Center/Panel/Content/SettingsRow/PlayerCountGroup/PlayerCount
@onready var rule_mode_option: OptionButton = $Center/Panel/Content/SettingsRow/RuleGroup/RuleMode
@onready var players_grid: GridContainer = $Center/Panel/Content/PlayersScroll/PlayersGrid
@onready var message: Label = $Center/Panel/Content/Message

var _player_cards: Array[PlayerSetupCard] = []


func _ready() -> void:
	for board_size: int in BOARD_SIZES:
		board_size_option.add_item("%d × %d" % [board_size, board_size], board_size)
	for player_count: int in PLAYER_COUNTS:
		player_count_option.add_item("%d игрока" % player_count, player_count)
	rule_mode_option.add_item("Занимать фигурами", GameRules.TerritoryMode.DIRECT)
	rule_mode_option.add_item("Автозахват недоступных клеток", GameRules.TerritoryMode.CLAIM_EXCLUSIVE_ACCESS)
	player_count_option.select(0)
	board_size_option.select(0)
	rule_mode_option.select(0)
	_create_player_cards()
	player_count_option.item_selected.connect(_on_player_count_selected)
	$Center/Panel/Content/Actions/Back.pressed.connect(func() -> void: back_requested.emit())
	$Center/Panel/Content/Actions/Start.pressed.connect(_start_game)
	for option: OptionButton in [board_size_option, player_count_option, rule_mode_option]:
		UITheme.style_input(option)
	for button: Button in [$Center/Panel/Content/Actions/Back, $Center/Panel/Content/Actions/Start]:
		UITheme.style_button(button)
	message.text = ""
	_update_player_count()


func _create_player_cards() -> void:
	for index in 4:
		var card := PLAYER_SETUP_CARD.instantiate() as PlayerSetupCard
		players_grid.add_child(card)
		card.configure(index, "Игрок %d" % (index + 1), index % PlayerSetupCard.AVATARS.size(), index)
		card.color_selection_changed.connect(_on_color_selection_changed)
		_player_cards.append(card)


func _on_player_count_selected(_option_index: int) -> void:
	_update_player_count()


func _update_player_count() -> void:
	var active_count := player_count_option.get_selected_id()
	$Center/Panel/Content/PlayersScroll.custom_minimum_size.y = 206.0 if active_count <= 2 else 396.0
	for index in _player_cards.size():
		_player_cards[index].visible = index < active_count
	_update_color_availability()


func _on_color_selection_changed(_player_index: int, _color_index: int) -> void:
	message.text = ""
	_update_color_availability()


func _update_color_availability() -> void:
	var active_count := player_count_option.get_selected_id()
	for player_index in active_count:
		for color_index in PlayerSetupCard.COLORS.size():
			var available := true
			for other_index in active_count:
				if other_index != player_index and _player_cards[other_index].selected_color_index == color_index:
					available = false
					break
			_player_cards[player_index].set_color_available(color_index, available)


func _start_game() -> void:
	var active_count := player_count_option.get_selected_id()
	var players: Array[PlayerData] = []
	var used_names: Array[String] = []
	var used_colors: Array[int] = []
	for index in active_count:
		var card := _player_cards[index]
		var player := card.create_player_data()
		var normalized_name := player.display_name.to_lower()
		if player.display_name.is_empty() or normalized_name in used_names:
			message.text = "Введите непустые и разные имена игроков."
			return
		if card.selected_color_index in used_colors:
			message.text = "Выберите для игроков разные цвета."
			return
		used_names.append(normalized_name)
		used_colors.append(card.selected_color_index)
		players.append(player)
	start_requested.emit(
		board_size_option.get_selected_id(),
		players,
		rule_mode_option.get_selected_id()
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and not event.echo:
		back_requested.emit()
		get_viewport().set_input_as_handled()
