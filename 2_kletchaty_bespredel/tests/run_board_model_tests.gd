extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_each_player_has_a_distinct_corner()
	_test_a_piece_must_cover_its_start_point()
	_test_pieces_touch_by_side_not_diagonal()
	_test_four_missed_turns_end_a_four_player_game()
	_test_start_markers_and_hints_last_two_turns_per_player()
	_test_direct_rule_leaves_exclusive_empty_cells_unowned()
	_test_exclusive_access_rule_claims_cells_reachable_by_one_player()
	if _failures == 0:
		print("All board-model checks passed.")
		quit(0)
	else:
		push_error("%d board-model check(s) failed." % _failures)
		quit(1)


func _test_each_player_has_a_distinct_corner() -> void:
	var state := _new_game(4)
	var expected_corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(11, 11), Vector2i(11, 0), Vector2i(0, 11)
	]
	for player_index in expected_corners.size():
		_expect(
			state.board.starting_points[player_index].cell == expected_corners[player_index],
			"player %d starts in a unique corner" % (player_index + 1)
		)


func _test_a_piece_must_cover_its_start_point() -> void:
	var state := _new_game(2)
	state.start(6, state.players, GameRules.TerritoryMode.DIRECT)
	var board := state.board
	board.offer(0, Vector2i.ONE)
	_expect(board.is_legal(Vector2i.ZERO, Vector2i.ONE), "first piece may cover the top-left start point")
	_expect(not board.is_legal(Vector2i(2, 2), Vector2i.ONE), "first piece cannot start away from its point")
	_expect(not board.is_legal(Vector2i.ZERO, Vector2i(6, 6)), "first piece cannot cover another player's reserved start point")


func _test_pieces_touch_by_side_not_diagonal() -> void:
	var board := _new_game(2).board
	board.offer(0, Vector2i.ONE)
	board.choose_cell(Vector2i.ZERO)
	_expect(board.commit(), "first 1 × 1 piece can be committed at the start point")
	board.offer(0, Vector2i.ONE)
	_expect(board.is_legal(Vector2i(1, 0), Vector2i.ONE), "a new piece may touch the player's piece by a side")
	_expect(not board.is_legal(Vector2i(1, 1), Vector2i.ONE), "diagonal contact alone is not enough")
	_expect(not board.is_legal(Vector2i.ZERO, Vector2i.ONE), "an occupied cell cannot be reused")
	_expect(not board.is_legal(Vector2i(-1, 0), Vector2i.ONE), "a piece cannot extend beyond the board edge")


func _test_four_missed_turns_end_a_four_player_game() -> void:
	var state := _new_game(4)
	for player_index in 3:
		_expect(not state.register_missed_turn(), "one missed turn does not end the whole round")
		_expect(state.current_player == player_index + 1, "a missed turn advances to the next player")
	_expect(state.register_missed_turn(), "the game ends after all four players miss consecutively")
	_expect(state.finished, "GameState records that the game has ended")
	_expect(state.winners().size() == 4, "equal territory is a four-way tie")


func _test_start_markers_and_hints_last_two_turns_per_player() -> void:
	var state := _new_game(2)
	_expect(state.introductory_hint_visible(0), "player 1 sees the opening hint")
	_expect(state.board.starting_points[0].visible_turns_remaining == 2, "start marker begins with two visible turns")
	state.advance_after_move()
	state.advance_after_move()
	_expect(state.introductory_hint_visible(0), "player 1 still sees the hint before their second move")
	_expect(state.board.starting_points[0].visible_turns_remaining == 1, "start marker remains after the first turn")
	state.advance_after_move()
	_expect(not state.introductory_hint_visible(0), "player 1's hint hides after their second turn")
	_expect(state.board.starting_points[0].visible_turns_remaining == 0, "start marker hides after the second turn")
	_expect(state.introductory_hint_visible(1), "player 2 gets their own two opening hints")


func _test_direct_rule_leaves_exclusive_empty_cells_unowned() -> void:
	var board := _make_divided_board(GameRules.TerritoryMode.DIRECT)
	_expect(board.cells[board.count + 1] == 0, "direct rule leaves an empty cell unclaimed")
	_expect(board.automatic_cell_indices.is_empty(), "direct rule does not create automatic claims")


func _test_exclusive_access_rule_claims_cells_reachable_by_one_player() -> void:
	var board := _make_divided_board(GameRules.TerritoryMode.CLAIM_EXCLUSIVE_ACCESS)
	_expect(board.cells[board.count + 1] == 1, "only player 1 can reach the isolated left region")
	_expect(board.automatic_cell_indices.has(board.count + 1), "automatically awarded cells are recorded for drawing")
	_expect(board.cells[4] == 0, "cells reachable by both players remain neutral")


func _make_divided_board(territory_mode: int) -> BoardModel:
	var board := _new_game(2, territory_mode).board
	# A full-height player-1 wall splits this fixture into two regions.
	# Player 1 owns the wall and can reach both sides; player 2 can reach only the right side.
	for y in board.count:
		board.cells[y * board.count + 3] = 1
	board.piece_count[0] = 1
	board.offer(0, Vector2i.ONE)
	board.choose_cell(Vector2i(2, 0))
	_expect(board.commit(), "fixture placement beside the dividing wall is legal")
	return board


func _new_game(player_count: int, territory_mode: int = GameRules.TerritoryMode.DIRECT) -> GameState:
	var players: Array[PlayerData] = []
	for _index in player_count:
		players.append(PlayerData.new())
	var state := GameState.new()
	state.start(12, players, territory_mode)
	return state


func _expect(condition: bool, explanation: String) -> void:
	if condition:
		print("PASS: " + explanation)
	else:
		_failures += 1
		push_error("FAIL: " + explanation)
