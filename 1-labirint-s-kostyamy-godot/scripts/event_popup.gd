class_name EventPopup
extends Control

signal event_resolved(success: bool)

const LATIN_KEYS: Array[Key] = [
	KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G,
	KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M, KEY_N,
	KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U,
	KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
]

@onready var prompt_label: Label = $CenterContainer/PanelContainer/VBoxContainer/PromptLabel
@onready var key_label: Label = $CenterContainer/PanelContainer/VBoxContainer/KeyLabel
@onready var time_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TimeLabel
@onready var progress_bar: ProgressBar = $CenterContainer/PanelContainer/VBoxContainer/ProgressBar
@onready var timer: Timer = $EventTimer

var _rng := RandomNumberGenerator.new()
var _active := false
var _target_key: Key = KEY_NONE
var _time_limit := 0.0


func _ready() -> void:
	_rng.randomize()
	timer.timeout.connect(_on_timeout)
	visible = false
	set_process(false)


func start_event(event_data: Dictionary) -> void:
	if _active:
		push_warning("Попытка запустить новое событие до завершения текущего")
		return

	var event_type := String(event_data.get("type", ""))
	match event_type:
		"press_key":
			_start_press_key_event(event_data)
		_:
			push_warning("Неизвестный тип события: %s" % event_type)
			call_deferred("_resolve_unknown_event")


func _start_press_key_event(event_data: Dictionary) -> void:
	_active = true
	_target_key = LATIN_KEYS[_rng.randi_range(0, LATIN_KEYS.size() - 1)]
	_time_limit = maxf(float(event_data.get("time_limit", 30.0)), 0.1)

	prompt_label.text = "Нажмите латинскую клавишу"
	key_label.text = OS.get_keycode_string(_target_key)
	progress_bar.max_value = _time_limit
	progress_bar.value = _time_limit
	_update_time_display(_time_limit)

	visible = true
	set_process(true)
	timer.start(_time_limit)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# Пока окно активно, ни одна клавиша не должна дойти до управления броском.
	get_viewport().set_input_as_handled()
	if event.physical_keycode == _target_key:
		_finish_event(true)


func _process(_delta: float) -> void:
	if not _active:
		return
	progress_bar.value = timer.time_left
	_update_time_display(timer.time_left)


func _on_timeout() -> void:
	_finish_event(false)


func _finish_event(success: bool) -> void:
	if not _active:
		return
	_active = false
	timer.stop()
	set_process(false)
	visible = false
	event_resolved.emit(success)


func _resolve_unknown_event() -> void:
	event_resolved.emit(true)


func _update_time_display(time_left: float) -> void:
	time_label.text = "Осталось: %.1f сек." % time_left
