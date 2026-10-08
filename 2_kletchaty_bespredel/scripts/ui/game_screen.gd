extends Control
class_name GameScreen

signal pause_requested
signal settings_requested
signal setup_requested

@onready var board_view: GameBoard = $Margin/MainColumn/Body/BoardAspect/GameBoard
@onready var dice: DicePair = $Margin/MainColumn/Body/LeftColumn/DicePair
@onready var player_cards: Array[PlayerCard] = [
	$Margin/MainColumn/Body/LeftColumn/PlayerOne,
	$Margin/MainColumn/Body/RightColumn/PlayerTwo,
	$Margin/MainColumn/Body/LeftColumn/PlayerThree,
	$Margin/MainColumn/Body/RightColumn/PlayerFour
]
@onready var turn_label: Label = $Margin/MainColumn/Header/Turn
@onready var status_label: Label = $Margin/MainColumn/Body/LeftColumn/Status
@onready var preview_hint: Label = $Margin/MainColumn/Body/RightColumn/PreviewHint
@onready var confirm_button: Button = $Margin/MainColumn/Body/RightColumn/Confirm
@onready var rotate_button: Button = $Margin/MainColumn/Body/RightColumn/Rotate

var _session := GameState.new()
var _result_dialog: AcceptDialog


func _ready() -> void:
	board_view.state_changed.connect(_refresh_placement_controls)
	dice.rolled.connect(_on_dice_rolled)
	$Margin/MainColumn/Header/Pause.pressed.connect(func() -> void: pause_requested.emit())
	$Margin/MainColumn/Header/Settings.pressed.connect(func() -> void: settings_requested.emit())
	$Margin/MainColumn/Header/Restart.pressed.connect(_restart_game)
	$Margin/MainColumn/Header/ChangeBoard.pressed.connect(func() -> void: setup_requested.emit())
	confirm_button.pressed.connect(_confirm_move)
	rotate_button.pressed.connect(board_view.rotate_preview)
	for button: Button in [
		$Margin/MainColumn/Header/Pause,
		$Margin/MainColumn/Header/Settings,
		$Margin/MainColumn/Header/Restart,
		$Margin/MainColumn/Header/ChangeBoard,
		confirm_button,
		rotate_button
	]:
		UITheme.style_button(button)
	_result_dialog = AcceptDialog.new()
	add_child(_result_dialog)


func start_game(board_size: int, players: Array[PlayerData], territory_mode: int) -> void:
	_session.start(board_size, players, territory_mode)
	_configure_board()
	status_label.text = "Бросьте кости, чтобы получить фигуру."
	_refresh()


func _configure_board() -> void:
	var player_colors: Array[Color] = []
	for player in _session.players:
		player_colors.append(player.territory_color)
	board_view.configure(_session.board, player_colors)


func _on_dice_rolled(result: Vector2i) -> void:
	if _session.finished:
		return
	var rolling_player := _session.current_player
	if _session.board.offer(rolling_player, result):
		status_label.text = "Разместите фигуру на поле и подтвердите ход."
	else:
		_session.board.clear_preview()
		if _session.register_missed_turn():
			_finish_game()
		else:
			status_label.text = "%s пропускает ход: фигуру некуда поставить." % _session.players[rolling_player].display_name
	_refresh()


func _confirm_move() -> void:
	if not board_view.commit():
		return
	_session.advance_after_move()
	status_label.text = "Ход принят. Бросьте кости."
	_refresh()


func _restart_game() -> void:
	_session.restart()
	_configure_board()
	status_label.text = "Бросьте кости, чтобы получить фигуру."
	_refresh()


func _finish_game() -> void:
	var winning_players := _session.winners()
	var result_text := "Ничья!"
	if winning_players.size() == 1:
		result_text = "Победил %s!" % _session.players[winning_players[0]].display_name
	elif winning_players.size() < _session.players.size():
		var tied_names: Array[String] = []
		for player_index in winning_players:
			tied_names.append(_session.players[player_index].display_name)
		result_text = "Ничья между игроками: %s" % ", ".join(tied_names)
	var scores: Array[String] = []
	for player_index in _session.players.size():
		scores.append("%s — %d" % [
			_session.players[player_index].display_name,
			_session.board.area(player_index)
		])
	status_label.text = "Игра окончена. " + result_text
	_result_dialog.dialog_text = "%s\nТерритория: %s клеток" % [result_text, " · ".join(scores)]
	_result_dialog.popup_centered()


func _refresh() -> void:
	if _session.players.is_empty():
		return
	_refresh_player_cards()
	var current_player := _session.current_player
	var board_model := _session.board
	turn_label.text = "Ход: %s" % _session.players[current_player].display_name
	dice.set_roll_enabled(board_model.dice == Vector2i.ZERO and not _session.finished)
	_refresh_placement_controls()


func _refresh_player_cards() -> void:
	for player_index in player_cards.size():
		var has_player := player_index < _session.players.size()
		player_cards[player_index].visible = has_player
		if has_player:
			player_cards[player_index].display(
				_session.players[player_index],
				_session.board.area(player_index),
				_session.current_player == player_index
			)


func _refresh_placement_controls() -> void:
	if _session.players.is_empty():
		return
	var current_player := _session.current_player
	var board_model := _session.board
	var has_piece := board_model.dice != Vector2i.ZERO
	confirm_button.disabled = _session.finished or board_model.pending == Vector2i(-1, -1)
	rotate_button.disabled = _session.finished or not has_piece
	preview_hint.visible = _session.introductory_hint_visible(current_player)
	if not preview_hint.visible:
		return
	if has_piece:
		if board_model.pending != Vector2i(-1, -1):
			preview_hint.text = "Место выбрано · пробел или Enter — ход"
		elif (
			board_model.hover != Vector2i(-1, -1)
			and not board_model.is_legal(board_model.hover, board_model.dimensions())
		):
			preview_hint.text = "Так поставить нельзя · попробуйте сместить или повернуть"
		else:
			preview_hint.text = "Кликните по полю · Q или колесо — повернуть"
	else:
		preview_hint.text = "Пробел или клик по кубикам — бросить"


func _input(event: InputEvent) -> void:
	if _session.players.is_empty():
		return
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return
	if _session.board.dice == Vector2i.ZERO:
		dice.request_roll()
	elif _session.board.pending != Vector2i(-1, -1):
		_confirm_move()
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _session.players.is_empty() or event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_Q and _session.board.dice != Vector2i.ZERO:
		board_view.rotate_preview()
		get_viewport().set_input_as_handled()
	elif (
		(event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
		and _session.board.pending != Vector2i(-1, -1)
	):
		_confirm_move()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
