extends Control
class_name GameBoard

signal state_changed

var _model: BoardModel
var _player_colors: Array[Color] = []
var _board_rect := Rect2()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)


func configure(model: BoardModel, player_colors: Array[Color]) -> void:
	if _model != null and _model.changed.is_connected(_on_model_changed):
		_model.changed.disconnect(_on_model_changed)
	_model = model
	_player_colors = player_colors.duplicate()
	_model.changed.connect(_on_model_changed)
	queue_redraw()


func rotate_preview() -> void:
	if _model != null:
		_model.rotate_preview()


func commit() -> bool:
	return _model != null and _model.commit()


func _gui_input(event: InputEvent) -> void:
	if _model == null:
		return
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		_model.set_hover(cell)
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _model.dice != Vector2i.ZERO:
			_model.choose_cell(cell)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_model.rotate_preview()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and _model.dice != Vector2i.ZERO:
			_model.choose_cell(_cell_at(event.position))
			accept_event()


func _cell_at(position: Vector2) -> Vector2i:
	if not _board_rect.has_point(position) or _model == null:
		return Vector2i(-1, -1)
	var cell_size := _board_rect.size.x / float(_model.count)
	return Vector2i(
		floori((position.x - _board_rect.position.x) / cell_size),
		floori((position.y - _board_rect.position.y) / cell_size)
	)


func _on_mouse_exited() -> void:
	if _model != null:
		_model.set_hover(Vector2i(-1, -1))


func _on_model_changed() -> void:
	queue_redraw()
	state_changed.emit()


func _draw() -> void:
	if _model == null or _model.count <= 0:
		return
	var side := minf(size.x, size.y)
	_board_rect = Rect2((size - Vector2.ONE * side) / 2.0, Vector2.ONE * side)
	var cell_size := side / float(_model.count)
	draw_rect(_board_rect, Color(0.97, 0.97, 1.0))
	for line_index in range(_model.count + 1):
		var offset := line_index * cell_size
		draw_line(_board_rect.position + Vector2(offset, 0), _board_rect.position + Vector2(offset, side), Color(0.79, 0.74, 0.87), 1.0)
		draw_line(_board_rect.position + Vector2(0, offset), _board_rect.position + Vector2(side, offset), Color(0.79, 0.74, 0.87), 1.0)
	_draw_automatic_cells(cell_size)
	_draw_placed_pieces(cell_size)
	_draw_preview(cell_size)
	_draw_starting_points(cell_size)
	draw_rect(_board_rect, Color(0.42, 0.34, 0.55), false, 2.0)


func _draw_automatic_cells(cell_size: float) -> void:
	for cell_index in _model.automatic_cell_indices:
		var owner_index := _model.cells[cell_index] - 1
		var cell := Vector2i(cell_index % _model.count, cell_index / _model.count)
		var rect := Rect2(_board_rect.position + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		var color: Color = _player_colors[owner_index]
		draw_rect(rect, Color(color.r, color.g, color.b, 0.40))
		draw_rect(rect, Color(color.r, color.g, color.b, 0.75), false, 1.0)


func _draw_placed_pieces(cell_size: float) -> void:
	for piece: PlacedPiece in _model.pieces:
		var color := _player_colors[piece.player_index]
		var rect := Rect2(
			_board_rect.position + Vector2(piece.origin) * cell_size,
			Vector2(piece.extent) * cell_size
		)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.52))
		draw_rect(rect, color, false, 3.0)
		_draw_area(rect, piece.extent.x * piece.extent.y)


func _draw_preview(cell_size: float) -> void:
	if _model.dice == Vector2i.ZERO or _model.current_offer_player < 0:
		return
	var at := _model.pending if _model.pending != Vector2i(-1, -1) else _model.hover
	if at.x < 0 or at.y < 0:
		return
	var extent := _model.dimensions()
	var rect := Rect2(
		_board_rect.position + Vector2(at) * cell_size,
		Vector2(extent) * cell_size
	)
	var is_legal := _model.is_legal(at, extent)
	var color := _player_colors[_model.current_offer_player]
	var visible_rect := rect.intersection(_board_rect)
	if visible_rect.has_area():
		var fill_alpha := 0.40 if is_legal else 0.12
		var border_alpha := 0.95 if is_legal else 0.25
		draw_rect(visible_rect, Color(color.r, color.g, color.b, fill_alpha))
		draw_rect(visible_rect, Color(color.r, color.g, color.b, border_alpha), false, 3.0)
	if _board_rect.encloses(rect):
		_draw_area(rect, extent.x * extent.y, 1.0 if is_legal else 0.35)


func _draw_starting_points(cell_size: float) -> void:
	for starting_point in _model.starting_points:
		if starting_point.visible_turns_remaining == 0:
			continue
		var center := _board_rect.position + (Vector2(starting_point.cell) + Vector2.ONE * 0.5) * cell_size
		var radius := cell_size * 0.22
		var color: Color = _player_colors[starting_point.player_index]
		draw_circle(center, radius * 1.45, Color.WHITE)
		draw_circle(center, radius, color)


func _draw_area(rect: Rect2, square_count: int, text_alpha: float = 1.0) -> void:
	var font := get_theme_default_font()
	var text := str(square_count)
	var font_size := clampi(int(minf(rect.size.x / (text.length() * 0.6), rect.size.y * 0.65)), 9, 28)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.get_center() - Vector2(text_size.x / 2.0, -text_size.y * 0.3)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.18, 0.13, 0.26, text_alpha))
