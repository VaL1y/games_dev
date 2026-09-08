class_name Die
extends Control

signal roll_finished(value: int)

const DIE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/dice/die_1.png"),
	preload("res://assets/dice/die_2.png"),
	preload("res://assets/dice/die_3.png"),
	preload("res://assets/dice/die_4.png"),
	preload("res://assets/dice/die_5.png"),
	preload("res://assets/dice/die_6.png"),
]

@onready var face: TextureRect = $Face

var _rng := RandomNumberGenerator.new()
var _roll_tween: Tween


func _ready() -> void:
	_rng.randomize()
	_update_pivot()
	resized.connect(_update_pivot)


func set_value(value: int) -> void:
	assert(value >= 1 and value <= 6, "Значение кости должно быть от 1 до 6")
	face.texture = DIE_TEXTURES[value - 1]


func roll(final_value: int, start_delay: float = 0.0) -> void:
	if _roll_tween and _roll_tween.is_valid():
		_roll_tween.kill()

	_reset_face_transform()
	_roll_tween = create_tween()

	if start_delay > 0.0:
		_roll_tween.tween_interval(start_delay)

	# Несколько коротких подскоков с меняющимися случайными гранями.
	for step in range(5):
		_roll_tween.tween_callback(_show_random_face)

		var jump_height := 30.0 - step * 3.0
		var angle := deg_to_rad(16.0 if step % 2 == 0 else -16.0)

		_roll_tween.tween_property(face, "position:y", -jump_height, 0.045) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_roll_tween.parallel().tween_property(face, "rotation", angle, 0.09) \
			.set_trans(Tween.TRANS_SINE)
		_roll_tween.tween_property(face, "position:y", 0.0, 0.045) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Финальный более заметный бросок и мягкое приземление.
	_roll_tween.tween_callback(set_value.bind(final_value))
	_roll_tween.tween_property(face, "position:y", -42.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_roll_tween.parallel().tween_property(face, "rotation", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE)
	_roll_tween.parallel().tween_property(face, "scale", Vector2(1.08, 1.08), 0.09)
	_roll_tween.tween_property(face, "position:y", 0.0, 0.16) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_roll_tween.parallel().tween_property(face, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_roll_tween.finished.connect(_finish_roll.bind(final_value))


func _show_random_face() -> void:
	set_value(_rng.randi_range(1, 6))


func _finish_roll(final_value: int) -> void:
	_reset_face_transform()
	set_value(final_value)
	roll_finished.emit(final_value)


func _reset_face_transform() -> void:
	face.position = Vector2.ZERO
	face.rotation = 0.0
	face.scale = Vector2.ONE


func _update_pivot() -> void:
	if is_instance_valid(face):
		face.pivot_offset = face.size / 2.0
