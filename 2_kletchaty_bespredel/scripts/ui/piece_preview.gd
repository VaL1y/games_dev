extends Control
class_name PiecePreview

var _extent := Vector2i.ZERO
var _piece_color := Color.WHITE


func show_piece(extent: Vector2i, piece_color: Color) -> void:
	_extent = extent
	_piece_color = piece_color
	queue_redraw()


func clear_piece() -> void:
	_extent = Vector2i.ZERO
	queue_redraw()


func _draw() -> void:
	if _extent == Vector2i.ZERO:
		return
	var cell_size := minf((size.x - 32.0) / _extent.x, (size.y - 32.0) / _extent.y)
	var piece_size := Vector2(_extent) * cell_size
	var origin := (size - piece_size) / 2.0
	var rect := Rect2(origin, piece_size)
	draw_rect(rect, Color(_piece_color.r, _piece_color.g, _piece_color.b, 0.48))
	draw_rect(rect, _piece_color, false, 3.0)
	var area := str(_extent.x * _extent.y)
	var font := get_theme_default_font()
	var font_size := clampi(int(minf(rect.size.x / (area.length() * 0.6), rect.size.y * 0.65)), 12, 38)
	var text_size := font.get_string_size(area, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.get_center() - Vector2(text_size.x / 2.0, -text_size.y * 0.3)
	draw_string(font, baseline, area, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.18, 0.13, 0.26))
