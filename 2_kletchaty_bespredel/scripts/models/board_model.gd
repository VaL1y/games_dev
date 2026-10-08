extends RefCounted
class_name BoardModel

signal changed
signal selection_changed

var count: int = 24
var cells := PackedInt32Array()
var piece_count: Array[int] = [0, 0]
var pieces: Array[PlacedPiece] = []
var current_player: int = 0
var dice := Vector2i.ZERO
var rotated := false
var hover := Vector2i(-1, -1)
var pending := Vector2i(-1, -1)


func start(cell_count: int) -> void:
	count = maxi(2, cell_count)
	cells.resize(count * count)
	cells.fill(0)
	piece_count.clear()
	piece_count.resize(2)
	piece_count.fill(0)
	pieces.clear()
	clear_preview()


func offer(player_index: int, roll: Vector2i) -> bool:
	current_player = player_index
	dice = roll
	rotated = false
	hover = Vector2i(-1, -1)
	pending = Vector2i(-1, -1)
	changed.emit()
	selection_changed.emit()
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
	selection_changed.emit()


func is_legal(at: Vector2i, extent: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x + extent.x > count or at.y + extent.y > count:
		return false
	var first_piece := piece_count[current_player] == 0
	if first_piece:
		var starts_at_corner := at == Vector2i.ZERO if current_player == 0 else at + extent == Vector2i(count, count)
		if not starts_at_corner:
			return false
	var touches_own_piece := false
	for y in range(at.y, at.y + extent.y):
		for x in range(at.x, at.x + extent.x):
			if cells[y * count + x] != 0:
				return false
			for neighbor in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < count and neighbor.y < count:
					touches_own_piece = touches_own_piece or cells[neighbor.y * count + neighbor.x] == current_player + 1
	return first_piece or touches_own_piece


func has_legal_placement() -> bool:
	if dice == Vector2i.ZERO:
		return false
	var orientations := [dice]
	if dice.x != dice.y:
		orientations.append(Vector2i(dice.y, dice.x))
	for extent: Vector2i in orientations:
		for y in range(count - extent.y + 1):
			for x in range(count - extent.x + 1):
				if is_legal(Vector2i(x, y), extent):
					return true
	return false


func choose_cell(cell: Vector2i) -> void:
	hover = cell
	pending = cell if dice != Vector2i.ZERO and is_legal(cell, dimensions()) else Vector2i(-1, -1)
	changed.emit()
	selection_changed.emit()


func set_hover(cell: Vector2i) -> void:
	if hover == cell:
		return
	hover = cell
	changed.emit()


func commit() -> bool:
	var extent := dimensions()
	if pending == Vector2i(-1, -1) or not is_legal(pending, extent):
		return false
	for y in range(pending.y, pending.y + extent.y):
		for x in range(pending.x, pending.x + extent.x):
			cells[y * count + x] = current_player + 1
	pieces.append(PlacedPiece.new(pending, extent, current_player))
	piece_count[current_player] += 1
	clear_preview()
	return true


func area(player_index: int) -> int:
	var total := 0
	for owner in cells:
		if owner == player_index + 1:
			total += 1
	return total


func clear_preview() -> void:
	dice = Vector2i.ZERO
	rotated = false
	hover = Vector2i(-1, -1)
	pending = Vector2i(-1, -1)
	changed.emit()
	selection_changed.emit()
