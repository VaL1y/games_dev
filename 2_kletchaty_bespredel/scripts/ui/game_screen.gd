extends Control
class_name GameScreen

signal pause_requested
signal settings_requested
signal setup_requested

@onready var board_view: GameBoard = $Margin/MainColumn/Body/BoardAspect/GameBoard
@onready var dice: DicePair = $Margin/MainColumn/Body/LeftColumn/DicePair
@onready var player_one_card: PlayerCard = $Margin/MainColumn/Body/LeftColumn/PlayerOne
@onready var player_two_card: PlayerCard = $Margin/MainColumn/Body/RightColumn/PlayerTwo
@onready var turn_label: Label = $Margin/MainColumn/Header/Turn
@onready var status_label: Label = $Margin/MainColumn/Body/LeftColumn/Status
@onready var piece_preview: PiecePreview = $Margin/MainColumn/Body/RightColumn/PiecePreview
@onready var preview_hint: Label = $Margin/MainColumn/Body/RightColumn/PreviewHint
@onready var confirm_button: Button = $Margin/MainColumn/Body/RightColumn/Confirm
@onready var rotate_button: Button = $Margin/MainColumn/Body/RightColumn/Rotate

var _session := GameState.new()
var _board_size: int = 24
var _players: Array[PlayerData] = []
var _result_dialog: AcceptDialog


func _ready() -> void:
	board_view.placement_changed.connect(_refresh)
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


func start_game(board_size: int, players: Array[PlayerData]) -> void:
	_board_size = board_size
	_players = players.duplicate()
	_session = GameState.new()
	_session.start(_board_size, _players)
	var player_colors: Array[Color] = [
		_players[0].territory_color,
		_players[1].territory_color
	]
	board_view.configure(_session.board, player_colors)
	status_label.text = "Бросьте кости, чтобы получить фигуру."
	_refresh()


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
			status_label.text = "%s пропускает ход: фигуру некуда поставить." % _players[rolling_player].display_name
	_refresh()


func _confirm_move() -> void:
	if not board_view.commit():
		return
	_session.advance_after_move()
	status_label.text = "Ход принят. Бросьте кости."
	_refresh()


func _restart_game() -> void:
	start_game(_board_size, _players)


func _finish_game() -> void:
	var winner_index := _session.winner()
	var result_text := "Ничья!" if winner_index == -1 else "Победил %s!" % _players[winner_index].display_name
	status_label.text = "Игра окончена. " + result_text
	_result_dialog.dialog_text = "%s\nТерритория: %d — %d клеток" % [
		result_text,
		_session.board.area(0),
		_session.board.area(1)
	]
	_result_dialog.popup_centered()


func _refresh() -> void:
	if _players.size() != 2:
		return
	var board_model := _session.board
	player_one_card.display(_players[0], board_model.area(0), _session.current_player == 0)
	player_two_card.display(_players[1], board_model.area(1), _session.current_player == 1)
	turn_label.text = "Ход: %s" % _players[_session.current_player].display_name
	var has_piece := board_model.dice != Vector2i.ZERO
	dice.set_roll_enabled(not has_piece and not _session.finished)
	confirm_button.disabled = _session.finished or board_model.pending == Vector2i(-1, -1)
	rotate_button.disabled = _session.finished or not has_piece
	preview_hint.visible = true
	if has_piece:
		piece_preview.show_piece(board_model.dimensions(), _players[_session.current_player].territory_color)
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
		piece_preview.clear_piece()


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_SPACE:
		return
	if _session.board.dice == Vector2i.ZERO:
		dice.request_roll()
	elif _session.board.pending != Vector2i(-1, -1):
		_confirm_move()
	get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
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
