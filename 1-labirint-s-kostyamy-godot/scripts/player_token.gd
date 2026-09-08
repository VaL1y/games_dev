class_name PlayerToken
extends Node2D

const STEP_DURATION := 0.24

var player_color := Color("3d8bfd")


func _ready() -> void:
	queue_redraw()


func set_player_color(value: Color) -> void:
	player_color = value
	queue_redraw()


func _draw() -> void:
	# Временная фишка: тень, корпус пешки и светлая окантовка.
	_draw_shadow_ellipse(Vector2(0.0, 28.0), Vector2(29.0, 10.0), Color(0.02, 0.03, 0.04, 0.45))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-25.0, 25.0),
			Vector2(-14.0, -2.0),
			Vector2(14.0, -2.0),
			Vector2(25.0, 25.0),
		]),
		player_color
	)
	draw_circle(Vector2(0.0, -16.0), 17.0, player_color.lightened(0.7))
	draw_circle(Vector2(0.0, -16.0), 12.0, player_color)
	draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 32, player_color.lightened(0.72), 4.0, true)


func move_along(points: Array[Vector2]) -> void:
	for point_index in range(points.size()):
		var direction := 1.0 if point_index % 2 == 0 else -1.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "position", points[point_index], STEP_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "rotation", deg_to_rad(7.0) * direction, STEP_DURATION * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.08, 0.94), STEP_DURATION * 0.5) \
			.set_trans(Tween.TRANS_SINE)
		await tween.finished

		var settle := create_tween().set_parallel(true)
		settle.tween_property(self, "rotation", 0.0, STEP_DURATION * 0.35)
		settle.tween_property(self, "scale", Vector2.ONE, STEP_DURATION * 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await settle.finished


func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * index / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
