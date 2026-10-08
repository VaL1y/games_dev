extends RefCounted
class_name BoardModel

signal changed

const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

var count: int = 24
var cells := PackedInt32Array()
var piece_count: Array[int] = []
var pieces: Array[PlacedPiece] = []
var starting_points: Array[StartingPoint] = []
var automatic_cell_indices := PackedInt32Array()
var territory_mode: int = GameRules.TerritoryMode.DIRECT
var current_offer_player: int = -1
var dice := Vector2i.ZERO
var rotated := false
var hover := Vector2i(-1, -1)
var pending := Vector2i(-1, -1)


func start(
	cell_count: int,
	player_starting_points: Array[StartingPoint],
	selected_territory_mode: int
) -> void:
	count = maxi(2, cell_count)
	starting_points = player_starting_points.duplicate()
	territory_mode = selected_territory_mode
	cells.resize(count * count)
	cells.fill(0)
	piece_count.clear()
	piece_count.resize(starting_points.size())
	piece_count.fill(0)
	pieces.clear()
	automatic_cell_indices.clear()
	clear_preview()


func offer(player_index: int, roll: Vector2i) -> bool:
	current_offer_player = player_index
	dice = roll
	rotated = false
	hover = Vector2i(-1, -1)
	pending = Vector2i(-1, -1)
	changed.emit()
	return has_legal_placement()


func dimensions() -> Vector2i:
	return Vector2i(dice.y, dice.x) if rotated else dice


func rotate_preview() -> void:
	if dice == Vector2i.ZERO:
		return
	rotated = not rotated
	if pending != Vector2i(-1, -1) and not is_legal(pending, dimensions()):
		pending = Vector2i(-1, -1)
	changed.emit()


func is_legal(at: Vector2i, extent: Vector2i) -> bool:
	if current_offer_player < 0 or current_offer_player >= piece_count.size():
		return false
	if at.x < 0 or at.y < 0 or at.x + extent.x > count or at.y + extent.y > count:
		return false
	var first_piece := piece_count[current_offer_player] == 0
	var start_point := starting_points[current_offer_player].cell
	var covers_own_start := _contains_cell(at, extent, start_point)
	if first_piece and not covers_own_start:
		return false
	for other_index in starting_points.size():
		if other_index == current_offer_player or piece_count[other_index] > 0:
			continue
		if _contains_cell(at, extent, starting_points[other_index].cell):
			return false
	var touches_own_piece := false
	for y in range(at.y, at.y + extent.y):
		for x in range(at.x, at.x + extent.x):
			if cells[y * count + x] != 0:
				return false
			for direction in NEIGHBORS:
				var neighbor := Vector2i(x, y) + direction
				if _is_inside(neighbor) and cells[neighbor.y * count + neighbor.x] == current_offer_player + 1:
					touches_own_piece = true
	return first_piece or touches_own_piece


func has_legal_placement() -> bool:
	if dice == Vector2i.ZERO:
		return false
	var orientations: Array[Vector2i] = [dice]
	if dice.x != dice.y:
		orientations.append(Vector2i(dice.y, dice.x))
	for extent in orientations:
		for y in range(count - extent.y + 1):
			for x in range(count - extent.x + 1):
				if is_legal(Vector2i(x, y), extent):
					return true
	return false


func choose_cell(cell: Vector2i) -> void:
	var next_pending := cell if dice != Vector2i.ZERO and is_legal(cell, dimensions()) else Vector2i(-1, -1)
	if hover == cell and pending == next_pending:
		return
	hover = cell
	pending = next_pending
	changed.emit()


func set_hover(cell: Vector2i) -> void:
	if hover == cell:
		return
	hover = cell
	changed.emit()


func commit() -> bool:
	var extent := dimensions()
	if pending == Vector2i(-1, -1) or not is_legal(pending, extent):
		return false
	var owner_index := current_offer_player
	for y in range(pending.y, pending.y + extent.y):
		for x in range(pending.x, pending.x + extent.x):
			cells[y * count + x] = owner_index + 1
	pieces.append(PlacedPiece.new(pending, extent, owner_index))
	piece_count[owner_index] += 1
	if territory_mode == GameRules.TerritoryMode.CLAIM_EXCLUSIVE_ACCESS:
		_claim_exclusive_cells()
	clear_preview()
	return true


func complete_turn(player_index: int) -> void:
	if player_index < 0 or player_index >= starting_points.size():
		return
	starting_points[player_index].complete_turn()
	changed.emit()


func area(player_index: int) -> int:
	var total := 0
	for owner in cells:
		if owner == player_index + 1:
			total += 1
	return total


func clear_preview() -> void:
	current_offer_player = -1
	dice = Vector2i.ZERO
	rotated = false
	hover = Vector2i(-1, -1)
	pending = Vector2i(-1, -1)
	changed.emit()


func _claim_exclusive_cells() -> void:
	var reachable_by_player: Array[PackedByteArray] = []
	for player_index in piece_count.size():
		reachable_by_player.append(_reachable_cells(player_index))
	var claims: Array[Vector2i] = []
	for cell_index in cells.size():
		if cells[cell_index] != 0 or _is_unclaimed_start_cell(cell_index):
			continue
		var only_reachable_player := -1
		var reachable_player_count := 0
		for player_index in reachable_by_player.size():
			if reachable_by_player[player_index][cell_index] == 0:
				continue
			only_reachable_player = player_index
			reachable_player_count += 1
			if reachable_player_count > 1:
				break
		if reachable_player_count == 1:
			claims.append(Vector2i(cell_index, only_reachable_player))
	if claims.is_empty():
		return
	# A claimed cell was unreachable to every rival already, so claiming it cannot change their paths.
	for claim in claims:
		cells[claim.x] = claim.y + 1
		automatic_cell_indices.append(claim.x)
	changed.emit()


func _reachable_cells(player_index: int) -> PackedByteArray:
	var reachable := PackedByteArray()
	reachable.resize(cells.size())
	reachable.fill(0)
	var queue: Array[int] = []
	for cell_index in cells.size():
		if cells[cell_index] == player_index + 1:
			queue.append(cell_index)
	if piece_count[player_index] == 0:
		var start_cell := starting_points[player_index].cell
		queue.append(start_cell.y * count + start_cell.x)
	var queue_index := 0
	while queue_index < queue.size():
		var cell_index := queue[queue_index]
		queue_index += 1
		if reachable[cell_index] != 0:
			continue
		var cell_owner := cells[cell_index]
		if cell_owner != 0 and cell_owner != player_index + 1:
			continue
		if _is_reserved_start_for_other(cell_index, player_index):
			continue
		reachable[cell_index] = 1
		var cell := Vector2i(cell_index % count, cell_index / count)
		for direction in NEIGHBORS:
			var neighbor := cell + direction
			if not _is_inside(neighbor):
				continue
			var neighbor_index := neighbor.y * count + neighbor.x
			if reachable[neighbor_index] == 0 and not _is_reserved_start_for_other(neighbor_index, player_index):
				queue.append(neighbor_index)
	return reachable


func _contains_cell(origin: Vector2i, extent: Vector2i, cell: Vector2i) -> bool:
	return (
		cell.x >= origin.x and cell.y >= origin.y
		and cell.x < origin.x + extent.x and cell.y < origin.y + extent.y
	)


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < count and cell.y < count


func _is_unclaimed_start_cell(cell_index: int) -> bool:
	for player_index in starting_points.size():
		if piece_count[player_index] > 0:
			continue
		var start_cell := starting_points[player_index].cell
		if cell_index == start_cell.y * count + start_cell.x:
			return true
	return false


func _is_reserved_start_for_other(cell_index: int, player_index: int) -> bool:
	for other_index in starting_points.size():
		if other_index == player_index or piece_count[other_index] > 0:
			continue
		var start_cell := starting_points[other_index].cell
		if cell_index == start_cell.y * count + start_cell.x:
			return true
	return false
