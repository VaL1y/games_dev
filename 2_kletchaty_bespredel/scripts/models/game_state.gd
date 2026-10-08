extends RefCounted
class_name GameState

const START_CORNERS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)
]

var board := BoardModel.new()
var players: Array[PlayerData] = []
var board_size: int = 24
var territory_mode: int = GameRules.TerritoryMode.DIRECT
var current_player: int = 0
var missed_turns: int = 0
var finished: bool = false


func start(
	cell_count: int,
	player_data: Array[PlayerData],
	selected_territory_mode: int
) -> void:
	board_size = maxi(2, cell_count)
	players = player_data.duplicate()
	territory_mode = selected_territory_mode
	current_player = 0
	missed_turns = 0
	finished = false
	var starting_points: Array[StartingPoint] = []
	for player_index in players.size():
		var corner_offset := START_CORNERS[player_index]
		var cell := Vector2i(corner_offset.x * (board_size - 1), corner_offset.y * (board_size - 1))
		starting_points.append(StartingPoint.new(player_index, cell))
	board = BoardModel.new()
	board.start(board_size, starting_points, territory_mode)


func restart() -> void:
	start(board_size, players, territory_mode)


func advance_after_move() -> void:
	missed_turns = 0
	_complete_current_turn()
	_advance_player()


func register_missed_turn() -> bool:
	missed_turns += 1
	_complete_current_turn()
	if missed_turns >= players.size():
		finished = true
		return true
	_advance_player()
	return false


func introductory_hint_visible(player_index: int) -> bool:
	return (
		player_index >= 0
		and player_index < board.starting_points.size()
		and board.starting_points[player_index].visible_turns_remaining > 0
	)


func winners() -> Array[int]:
	var highest_area := -1
	var winning_players: Array[int] = []
	for player_index in players.size():
		var player_area := board.area(player_index)
		if player_area > highest_area:
			highest_area = player_area
			winning_players.clear()
			winning_players.append(player_index)
		elif player_area == highest_area:
			winning_players.append(player_index)
	return winning_players


func _complete_current_turn() -> void:
	board.complete_turn(current_player)


func _advance_player() -> void:
	current_player = (current_player + 1) % players.size()
