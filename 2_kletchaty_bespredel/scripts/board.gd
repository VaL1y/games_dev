extends Control
class_name GameBoard

signal chosen

var count := 24
var cells := PackedInt32Array()
var colors := [Color.DODGER_BLUE, Color.HOT_PINK]
var rectangles: Array[Dictionary] = []
var piece_count := [0, 0]
var player := 1
var dice := Vector2i.ZERO
var rotated := false
var hover := Vector2i(-1, -1)
var pending := Vector2i(-1, -1)


func start(size_in_cells: int, player_colors: Array) -> void:
	count = size_in_cells
	colors = player_colors
	cells.resize(count * count)
	cells.fill(0)
	rectangles.clear()
	piece_count = [0, 0]
	clear_preview()


func clear_preview() -> void:
	dice = Vector2i.ZERO
	rotated = false
	hover = Vector2i(-1, -1)
	pending = Vector2i(-1, -1)
	queue_redraw()


func offer(next_player: int, roll: Vector2i) -> bool:
	player = next_player
	dice = roll
	rotated = false
	pending = Vector2i(-1, -1)
	queue_redraw()
	return has_move()


func dimensions() -> Vector2i:
	return Vector2i(dice.y, dice.x) if rotated else dice


func rotate_preview() -> void:
	if dice == Vector2i.ZERO:
		return
	rotated = not rotated
	if pending != Vector2i(-1, -1) and not legal(pending, dimensions()):
		pending = Vector2i(-1, -1)
	queue_redraw()
	chosen.emit()


func legal(at: Vector2i, extent: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x + extent.x > count or at.y + extent.y > count:
		return false
	var first_piece: bool = piece_count[player - 1] == 0
	if first_piece and not (at == Vector2i.ZERO if player == 1 else at + extent == Vector2i(count, count)):
		return false
	var touching := false
	for y in range(at.y, at.y + extent.y):
		for x in range(at.x, at.x + extent.x):
			if cells[y * count + x] != 0:
				return false
			for neighbor in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < count and neighbor.y < count:
					touching = touching or cells[neighbor.y * count + neighbor.x] == player
	return first_piece or touching


func has_move() -> bool:
	for extent in [dice, Vector2i(dice.y, dice.x)]:
		for y in range(count - extent.y + 1):
			for x in range(count - extent.x + 1):
				if legal(Vector2i(x, y), extent):
					return true
	return false


func commit() -> bool:
	if pending == Vector2i(-1, -1) or not legal(pending, dimensions()):
		return false
	var extent := dimensions()
	for y in range(pending.y, pending.y + extent.y):
		for x in range(pending.x, pending.x + extent.x):
			cells[y * count + x] = player
	rectangles.append({"at": pending, "extent": extent, "player": player})
	piece_count[player - 1] += 1
	clear_preview()
	return true


func area(for_player: int) -> int:
	var total := 0
	for owner in cells:
		if owner == for_player:
			total += 1
	return total


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = Vector2i(floori(event.position.x * count / size.x), floori(event.position.y * count / size.y))
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and dice != Vector2i.ZERO and legal(hover, dimensions()):
			pending = hover
			chosen.emit()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_preview()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and dice != Vector2i.ZERO:
			hover = Vector2i(floori(event.position.x * count / size.x), floori(event.position.y * count / size.y))
			if legal(hover, dimensions()):
				pending = hover
				chosen.emit()
				queue_redraw()


func _draw() -> void:
	var cell := size.x / count
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.97, 0.97, 1.0))
	for i in count + 1:
		var line := i * cell
		draw_line(Vector2(line, 0), Vector2(line, size.y), Color(0.79, 0.74, 0.87), 1.0)
		draw_line(Vector2(0, line), Vector2(size.x, line), Color(0.79, 0.74, 0.87), 1.0)
	for piece in rectangles:
		var rect := Rect2(Vector2(piece.at) * cell, Vector2(piece.extent) * cell)
		var color: Color = colors[piece.player - 1]
		draw_rect(rect, Color(color.r, color.g, color.b, 0.52))
		draw_rect(rect, color, false, 3.0)
		_draw_area(rect, piece.extent.x * piece.extent.y)
	var at := pending if pending != Vector2i(-1, -1) else hover
	if dice != Vector2i.ZERO and at.x >= 0 and at.y >= 0:
		var rect := Rect2(Vector2(at) * cell, Vector2(dimensions()) * cell)
		var color: Color = colors[player - 1] if legal(at, dimensions()) else Color.RED
		draw_rect(rect, Color(color.r, color.g, color.b, 0.38))
		draw_rect(rect, color, false, 3.0)
		_draw_area(rect, dice.x * dice.y)


func _draw_area(rect: Rect2, square_count: int) -> void:
	var font := get_theme_default_font()
	var text := str(square_count)
	var font_size := clampi(int(minf(rect.size.x / (text.length() * 0.6), rect.size.y * 0.65)), 9, 28)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var point := rect.get_center() - Vector2(text_size.x / 2.0, -text_size.y * 0.3)
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.18, 0.13, 0.26))
