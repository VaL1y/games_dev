extends RefCounted
class_name GameState

var board := BoardModel.new()
var players: Array[PlayerData] = []
var current_player: int = 0
var missed_turns: int = 0
var finished: bool = false


func start(cell_count: int, player_data: Array[PlayerData]) -> void:
	players = player_data.duplicate()
	current_player = 0
	missed_turns = 0
	finished = false
	board.start(cell_count)


func advance_after_move() -> void:
	missed_turns = 0
	_advance_player()


func register_missed_turn() -> bool:
	missed_turns += 1
	if missed_turns >= 2:
		finished = true
		return true
	_advance_player()
	return false


func winner() -> int:
	var first_area := board.area(0)
	var second_area := board.area(1)
	if first_area == second_area:
		return -1
	return 0 if first_area > second_area else 1


func _advance_player() -> void:
	current_player = 1 - current_player
