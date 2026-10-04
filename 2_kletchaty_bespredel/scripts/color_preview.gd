extends Control
class_name ColorPreview

var sample_color := Color.DODGER_BLUE:
	set(value):
		sample_color = value
		queue_redraw()


func _draw() -> void:
	var cell := minf(size.x, size.y) / 7.0
	var origin := (size - Vector2.ONE * cell * 7.0) / 2.0
	draw_rect(Rect2(origin, Vector2.ONE * cell * 7.0), Color.WHITE)
	for i in 8:
		var line := i * cell
		draw_line(origin + Vector2(line, 0), origin + Vector2(line, cell * 7), Color(0.74, 0.70, 0.84), 1.0)
		draw_line(origin + Vector2(0, line), origin + Vector2(cell * 7, line), Color(0.74, 0.70, 0.84), 1.0)
	var rect := Rect2(origin + Vector2(2, 1) * cell, Vector2(3, 4) * cell)
	draw_rect(rect, Color(sample_color.r, sample_color.g, sample_color.b, 0.52))
	draw_rect(rect, sample_color, false, 3.0)
