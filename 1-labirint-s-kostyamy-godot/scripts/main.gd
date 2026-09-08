extends Control

const ROUTE_PATH := "res://data/route.json"
const PLAYER_TOKEN_SCENE := preload("res://scenes/player_token.tscn")
const TOKEN_OFFSETS := [
	Vector2(-24.0, -24.0), Vector2(24.0, -24.0),
	Vector2(-24.0, 24.0), Vector2(24.0, 24.0),
]

@onready var die: Die = $DiceOverlay/VBoxContainer/DiceRow/Die
@onready var result_label: Label = $DiceOverlay/VBoxContainer/ResultLabel
@onready var dice_overlay: CenterContainer = $DiceOverlay
@onready var roll_button: Button = $HUD/RollButton
@onready var status_label: Label = $HUD/StatusLabel
@onready var background: TextureRect = $Background
@onready var token_layer: Node2D = $TokenLayer
@onready var event_popup: EventPopup = $EventPopup
@onready var victory_overlay: Control = $VictoryOverlay
@onready var victory_label: Label = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/VictoryLabel
@onready var restart_button: Button = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var victory_menu_button: Button = $VictoryOverlay/CenterContainer/PanelContainer/VBoxContainer/MenuButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var pause_restart_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var pause_menu_button: Button = $PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/MenuButton
@onready var pause_button: Button = $HUD/PauseButton
@onready var roll_sound: AudioStreamPlayer = $RollSound
@onready var player_huds: Array[PlayerHud] = [
	$HUD/PlayerTopLeft,
	$HUD/PlayerTopRight,
	$HUD/PlayerBottomLeft,
	$HUD/PlayerBottomRight,
]

var rng := RandomNumberGenerator.new()
var players: Array[PlayerState] = []
var player_tokens: Array[PlayerToken] = []
var _route_source_size := Vector2.ONE
var _route_points: Array[Vector2] = []
var _route_events: Array[Dictionary] = []
var _current_player_index := 0
var _turn_in_progress := false
var _game_started := false
var _game_finished := false
var _is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	roll_button.pressed.connect(_start_turn)
	pause_button.pressed.connect(_toggle_pause)
	restart_button.pressed.connect(_restart_match)
	victory_menu_button.pressed.connect(_return_to_menu)
	resume_button.pressed.connect(_resume_game)
	pause_restart_button.pressed.connect(_restart_match)
	pause_menu_button.pressed.connect(_return_to_menu)
	roll_sound.stream = _create_roll_sound()
	die.set_value(1)

	_load_route()
	resized.connect(_place_all_tokens)
	dice_overlay.visible = false
	victory_overlay.visible = false
	pause_overlay.visible = false
	roll_button.disabled = true
	for player_hud in player_huds:
		player_hud.visible = false

	_start_game(GameSession.get_arcade_players())


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if not _game_started or _is_paused:
		return

	if event.keycode == KEY_SPACE:
		_start_turn()


func _start_game(player_configs: Array[Dictionary]) -> void:
	players.clear()
	for token in player_tokens:
		token.queue_free()
	player_tokens.clear()

	for player_id in range(player_configs.size()):
		var config := player_configs[player_id]
		var skin := GameSession.get_skin(String(config.get("skin_id", "azure")))
		var player := PlayerState.new(
			player_id,
			String(config.get("name", "Игрок %d" % (player_id + 1))),
			skin.color
		)
		players.append(player)

		var token := PLAYER_TOKEN_SCENE.instantiate() as PlayerToken
		token.set_player_color(player.color)
		token_layer.add_child(token)
		player_tokens.append(token)

	_current_player_index = 0
	_game_started = true
	_game_finished = false
	_turn_in_progress = false
	roll_button.disabled = false
	_place_all_tokens()
	_update_interface()


func _start_turn() -> void:
	if not _game_started or _turn_in_progress or _game_finished or _is_paused:
		return
	_play_turn()


func _play_turn() -> void:
	_turn_in_progress = true
	roll_button.disabled = true
	var active_player := players[_current_player_index]
	var turn_start_index := active_player.route_index

	dice_overlay.visible = true
	dice_overlay.modulate.a = 0.0
	create_tween().tween_property(dice_overlay, "modulate:a", 1.0, 0.12)
	result_label.text = "Бросаем..."

	var roll_result := rng.randi_range(1, 6)
	roll_sound.play()
	die.roll(roll_result)
	await die.roll_finished

	result_label.text = "Выпало: %d" % roll_result
	await get_tree().create_timer(0.45).timeout

	var hide_tween := create_tween()
	hide_tween.tween_property(dice_overlay, "modulate:a", 0.0, 0.16)
	await hide_tween.finished
	dice_overlay.visible = false

	var target_index := mini(turn_start_index + roll_result, _route_points.size() - 1)
	active_player.route_index = target_index
	var movement_points := _build_forward_movement(turn_start_index, target_index, active_player)
	await player_tokens[_current_player_index].move_along(movement_points)
	_place_all_tokens()
	_update_interface()

	var event_success := await _run_landing_event(_route_events[target_index])
	if not event_success:
		await _apply_event_failure(active_player, turn_start_index)
		_advance_turn()
		return

	if active_player.route_index == _route_points.size() - 1:
		active_player.finished = true
		_show_victory(active_player)
		return

	_advance_turn()


func _build_forward_movement(from_index: int, to_index: int, player: PlayerState) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for route_index in range(from_index + 1, to_index + 1):
		var point := _route_to_screen(_route_points[route_index])
		if route_index == to_index:
			point = _token_position(player)
		points.append(point)
	return points


func _run_landing_event(event_data: Dictionary) -> bool:
	if event_data.is_empty():
		return true

	event_popup.start_event(event_data)
	var success: bool = await event_popup.event_resolved
	return success


func _apply_event_failure(player: PlayerState, turn_start_index: int) -> void:
	var event_data := _route_events[player.route_index]
	if String(event_data.get("on_timeout", "")) != "rollback_move":
		return

	status_label.text = "Время вышло — %s возвращается назад..." % player.name
	var failed_index := player.route_index
	player.route_index = turn_start_index

	var rollback_points: Array[Vector2] = []
	for route_index in range(failed_index - 1, turn_start_index - 1, -1):
		var point := _route_to_screen(_route_points[route_index])
		if route_index == turn_start_index:
			point = _token_position(player)
		rollback_points.append(point)

	await player_tokens[player.id].move_along(rollback_points)
	_place_all_tokens()
	_update_interface()


func _advance_turn() -> void:
	_current_player_index = (_current_player_index + 1) % players.size()
	_turn_in_progress = false
	roll_button.disabled = false
	_update_interface()


func _load_route() -> void:
	var file := FileAccess.open(ROUTE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть маршрут: %s" % ROUTE_PATH)
		return

	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.has("image_size") or not data.has("cells"):
		push_error("Некорректный формат route.json")
		return

	_route_source_size = Vector2(data.image_size[0], data.image_size[1])
	for cell in data.cells:
		var point = cell.position
		_route_points.append(Vector2(point[0], point[1]))

		var event_data = cell.get("event")
		if event_data is Dictionary:
			_route_events.append(event_data)
		else:
			_route_events.append({})


func _route_to_screen(source_point: Vector2) -> Vector2:
	var scale_factor := background.size / _route_source_size
	return background.position + source_point * scale_factor


func _place_all_tokens() -> void:
	if players.is_empty() or _route_points.is_empty():
		return

	for player in players:
		player_tokens[player.id].position = _token_position(player)


func _token_position(player: PlayerState) -> Vector2:
	var players_on_cell: Array[PlayerState] = []
	for candidate in players:
		if candidate.route_index == player.route_index:
			players_on_cell.append(candidate)

	var offset := Vector2.ZERO
	if players_on_cell.size() > 1:
		offset = TOKEN_OFFSETS[players_on_cell.find(player)]

	return _route_to_screen(_route_points[player.route_index]) + offset


func _update_interface() -> void:
	if not _game_started:
		return

	var active_player := players[_current_player_index]
	status_label.text = "%s ходит  •  Клетка %d / %d  •  Пробел — бросить кость" % [
		active_player.name,
		active_player.route_index + 1,
		_route_points.size(),
	]

	for player_id in range(player_huds.size()):
		var player_hud := player_huds[player_id]
		player_hud.visible = player_id < players.size()
		if player_id < players.size():
			player_hud.show_player(players[player_id], _route_points.size(), player_id == _current_player_index)


func _show_victory(winner: PlayerState) -> void:
	_game_finished = true
	_turn_in_progress = false
	roll_button.disabled = true
	victory_label.text = "%s победил!" % winner.name
	victory_label.add_theme_color_override("font_color", winner.color.lightened(0.35))
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	create_tween().tween_property(victory_overlay, "modulate:a", 1.0, 0.25)
	restart_button.grab_focus()


func _toggle_pause() -> void:
	if _game_finished:
		return
	if _is_paused:
		_resume_game()
		return

	_is_paused = true
	pause_overlay.visible = true
	pause_overlay.modulate.a = 0.0
	create_tween().tween_property(pause_overlay, "modulate:a", 1.0, 0.15)
	get_tree().paused = true
	resume_button.grab_focus()


func _resume_game() -> void:
	if not _is_paused:
		return
	get_tree().paused = false
	_is_paused = false
	pause_overlay.visible = false


func _restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	GameSession.clear_arcade()
	get_tree().change_scene_to_file(GameSession.MAIN_MENU_SCENE)


func _create_roll_sound() -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	const DURATION := 0.62
	const HIT_TIMES := [0.0, 0.09, 0.18, 0.28, 0.39, 0.51]

	var sample_count := int(SAMPLE_RATE * DURATION)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	var sound_rng := RandomNumberGenerator.new()
	sound_rng.seed = 0xD1CE

	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		var value := 0.0

		for hit_time in HIT_TIMES:
			var age: float = time - hit_time
			if age >= 0.0 and age < 0.075:
				var envelope := exp(-age * 44.0)
				var noise := sound_rng.randf_range(-1.0, 1.0)
				var body := sin(TAU * 185.0 * age)
				value += (noise * 0.48 + body * 0.18) * envelope

		value = clampf(value, -1.0, 1.0)
		pcm.encode_s16(sample_index * 2, int(value * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream
