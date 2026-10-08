extends VBoxContainer
class_name DicePair

signal rolled(result: Vector2i)

@export_range(2, 6) var sides: int = 6

@onready var first: Label = $Faces/FFrame/First
@onready var second: Label = $Faces/SFrame/Second
@onready var faces: HBoxContainer = $Faces

var _roll_locked := false
var _animating := false
var _can_roll := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for control: Control in [$Title, faces, $Faces/FFrame, first, $Faces/SFrame, second]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_roll_enabled(enabled: bool) -> void:
	_can_roll = enabled
	modulate = Color.WHITE if enabled else Color(0.9, 0.9, 0.92)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_request_roll()
		accept_event()


func request_roll() -> void:
	_request_roll()


func _request_roll() -> void:
	if not _can_roll or _roll_locked or _animating:
		return
	_roll_locked = true
	_roll()


func _roll() -> void:
	var result := DiceRoller.new(sides).roll_rectangle()
	first.text = str(result.x)
	second.text = str(result.y)
	rolled.emit(result)
	_animating = true
	var tween := create_tween()
	tween.tween_property(faces, "modulate", Color(0.6, 0.6, 1.0), 0.12)
	tween.tween_property(faces, "modulate", Color.WHITE, 0.12)
	tween.finished.connect(func() -> void: _animating = false)


func _process(_delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_key_pressed(KEY_SPACE):
		_roll_locked = false
