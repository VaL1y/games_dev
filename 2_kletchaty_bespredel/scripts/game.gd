extends Control

const FIELD_SIZES := [24, 36, 60]
const SIZE_HINTS := ["Для первой партии", "Для более долгой игры", "Для большой партии"]
const AVATARS := ["●", "◆", "★", "▲", "■", "✿", "♥", "☀", "☾", "✦"]
const INK := Color(0.27, 0.18, 0.40)

var dice_roller := DiceRoller.new(6)
var pages := {}
var screen := "menu"
var settings_origin := "menu"
var player_names := ["Игрок1", "Игрок2"]
var player_colors := [Color(0.20, 0.55, 0.95), Color(0.95, 0.28, 0.55)]
var current_player := 1
var missed_turns := 0
var game_over := false
var confirm_action: Callable
var board: GameBoard
var selected_size_index := 0
var names: Array[LineEdit] = []
var avatars: Array[OptionButton] = []
var color_choices: Array[ColorPickerButton] = []
var audio_sliders := {}
var fullscreen_button: Button
var player_labels: Array[Label] = []
var avatar_labels: Array[Label] = []
var dice_faces: Array[Label] = []
var turn_label: Label
var dice_label: Label
var status_label: Label
var roll_button: Button
var confirm_button: Button
var stage: Control
var stage_piece: Panel
var stage_style: StyleBoxFlat
var stage_area: Label
var stage_hint: Label
var alert: AcceptDialog
var confirmation: ConfirmationDialog


func _ready() -> void:
	$PlayButton.pressed.connect(func() -> void: _show_screen("setup"))
	$SettingsButton.pressed.connect(_show_settings)
	$ExitButton.pressed.connect(func() -> void: _ask("Вы уверены, что хотите выйти?", get_tree().quit))
	for button: TextureButton in [$PlayButton, $SettingsButton, $ExitButton]:
		button.mouse_entered.connect(func() -> void: button.modulate = Color(1.12, 1.12, 1.12))
		button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	fullscreen_button = _button(self, "□", _toggle_fullscreen)
	fullscreen_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fullscreen_button.offset_left = -95
	fullscreen_button.offset_right = -30
	fullscreen_button.offset_top = 22
	fullscreen_button.offset_bottom = 77
	fullscreen_button.custom_minimum_size = Vector2(65, 55)
	_update_fullscreen_hint()
	_build_setup()
	_build_settings()
	_build_game()
	_build_pause()
	alert = AcceptDialog.new()
	add_child(alert)
	confirmation = ConfirmationDialog.new()
	add_child(confirmation)
	confirmation.confirmed.connect(func() -> void: confirm_action.call())
	_load_audio_settings()
	_show_screen("menu")


func _page(key: String, panel_size := Vector2(1260, 820)) -> VBoxContainer:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	pages[key] = page
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/фон2.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	return _panel(page, panel_size)


func _panel(parent: Control, dimensions: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -dimensions.x / 2
	panel.offset_right = dimensions.x / 2
	panel.offset_top = -dimensions.y / 2
	panel.offset_bottom = dimensions.y / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.88)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	return column


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	parent.add_child(row)
	return row


func _label(parent: Node, content: String, font_size := 28) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, content: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(0.43, 0.39, 0.49))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal": Color(0.72, 0.87, 1.0), "hover": Color(1.0, 0.76, 0.89), "pressed": Color(0.80, 0.66, 0.89), "disabled": Color(0.86, 0.85, 0.89)}[state]
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	button.pressed.connect(action)
	return button


func _style_input(control: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0.72, 0.65, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(10)
	control.add_theme_stylebox_override("normal", style)
	control.add_theme_color_override("font_color", INK)


func _build_setup() -> void:
	var column := _page("setup", Vector2(1360, 980))
	_label(column, "Новая партия", 42)
	_label(column, "Сначала выберите поле, затем настройте игроков.", 25)
	_label(column, "Размер поля", 30)
	var sizes := _row(column)
	var group := ButtonGroup.new()
	for i in FIELD_SIZES.size():
		var n: int = FIELD_SIZES[i]
		var card := _button(sizes, "%d × %d\n%s" % [n, n, SIZE_HINTS[i]], func() -> void: selected_size_index = i)
		card.custom_minimum_size.y = 112
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true
		card.button_group = group
		card.button_pressed = i == selected_size_index
	_label(column, "Игроки", 30)
	var players := _row(column)
	for index in 2:
		var player_column := VBoxContainer.new()
		player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_column.add_theme_constant_override("separation", 10)
		players.add_child(player_column)
		_label(player_column, "Игрок %d" % (index + 1), 31)
		var name_input := LineEdit.new()
		name_input.text = player_names[index]
		name_input.placeholder_text = "Имя без пробелов"
		name_input.tooltip_text = "Имя не должно совпадать с именем другого игрока."
		name_input.custom_minimum_size.y = 55
		_style_input(name_input)
		player_column.add_child(name_input)
		names.append(name_input)
		_label(player_column, "Аватар", 23)
		var avatar := OptionButton.new()
		for i in AVATARS.size():
			avatar.add_item("%s  Аватар %d" % [AVATARS[i], i + 1])
		avatar.custom_minimum_size.y = 55
		_style_input(avatar)
		player_column.add_child(avatar)
		avatars.append(avatar)
		_label(player_column, "Цвет территории", 23)
		var color_choice := ColorPickerButton.new()
		color_choice.color = player_colors[index]
		color_choice.edit_alpha = false
		color_choice.tooltip_text = "Выберите цвет. Слишком похожие цвета использовать нельзя."
		color_choice.custom_minimum_size.y = 55
		player_column.add_child(color_choice)
		color_choices.append(color_choice)
		var sample_row := _row(player_column)
		_label(sample_row, "Пример\nна поле", 22)
		var sample := ColorPreview.new()
		sample.sample_color = color_choice.color
		sample.custom_minimum_size = Vector2(220, 130)
		sample_row.add_child(sample)
		color_choice.color_changed.connect(func(color: Color) -> void: sample.sample_color = color)
	var actions := _row(column)
	actions.alignment = BoxContainer.ALIGNMENT_END
	_button(actions, "Назад", func() -> void: _show_screen("menu")).custom_minimum_size.x = 210
	_button(actions, "Начать игру", _start_game).custom_minimum_size.x = 240


func _build_settings() -> void:
	var column := _page("settings", Vector2(900, 540))
	_label(column, "Настройки", 40)
	for bus_name in ["Music", "Effects"]:
		_label(column, "Громкость музыки" if bus_name == "Music" else "Громкость эффектов")
		var slider := HSlider.new()
		slider.max_value = 100
		slider.value = 50
		slider.custom_minimum_size = Vector2(0, 50)
		column.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void: _save_volume(bus_name, value))
		audio_sliders[bus_name] = slider
	_button(column, "Назад", func() -> void: _show_screen(settings_origin))


func _build_game() -> void:
	var page := _page("game", Vector2(1880, 1040))
	var toolbar := _row(page)
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_button(toolbar, "⏸  Пауза", func() -> void: _show_screen("pause"))
	_button(toolbar, "⚙  Настройки", _show_settings)
	turn_label = _label(toolbar, "", 29)
	turn_label.custom_minimum_size.x = 390
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button(toolbar, "↻  Начать сначала", func() -> void: _ask("Удалить текущий прогресс и начать сначала?", _start_game))
	_button(toolbar, "▦  Сменить поле", func() -> void: _ask("Удалить прогресс и выбрать новый размер?", func() -> void: _show_screen("setup")))
	var body := _row(page)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 390
	left.add_theme_constant_override("separation", 18)
	body.add_child(left)
	_player_card(left)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_label(left, "Кубики", 28)
	var faces := _row(left)
	for i in 2:
		var frame := PanelContainer.new()
		var face_style := StyleBoxFlat.new()
		face_style.bg_color = Color.WHITE
		face_style.set_corner_radius_all(14)
		face_style.set_content_margin_all(8)
		frame.add_theme_stylebox_override("panel", face_style)
		faces.add_child(frame)
		var face := _label(frame, "?", 52)
		face.custom_minimum_size = Vector2(95, 95)
		face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dice_faces.append(face)
	dice_label = _label(left, "", 24)
	roll_button = _button(left, "Бросить кости", _roll)
	var center := VBoxContainer.new()
	center.custom_minimum_size.x = 790
	body.add_child(center)
	status_label = _label(center, "", 23)
	status_label.custom_minimum_size.y = 43
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board = GameBoard.new()
	board.custom_minimum_size = Vector2(790, 790)
	board.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.chosen.connect(_refresh_game)
	center.add_child(board)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 390
	right.add_theme_constant_override("separation", 18)
	body.add_child(right)
	_player_card(right)
	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_spacer)
	_label(right, "Полученная фигура", 28)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(390, 260)
	right.add_child(stage)
	var stage_frame := Panel.new()
	stage_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 0.85)
	frame_style.border_color = Color(0.70, 0.64, 0.80)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(15)
	stage_frame.add_theme_stylebox_override("panel", frame_style)
	stage.add_child(stage_frame)
	stage_hint = _label(stage, "", 22)
	stage_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_piece = Panel.new()
	stage.add_child(stage_piece)
	stage_style = StyleBoxFlat.new()
	stage_style.set_border_width_all(4)
	stage_piece.add_theme_stylebox_override("panel", stage_style)
	stage_area = _label(stage_piece, "", 38)
	stage_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_area.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_button = _button(right, "Подтвердить ход", _confirm_move)
	_label(right, "Перемещайте фигуру мышью.\nКолесо или Q — повернуть.", 21)


func _player_card(parent: Node) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.82)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	var icon := _label(column, "", 86)
	icon.custom_minimum_size.y = 126
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_labels.append(icon)
	player_labels.append(_label(column, "", 26))


func _build_pause() -> void:
	var column := _page("pause", Vector2(760, 450))
	_label(column, "Пауза", 40)
	_button(column, "Продолжить игру", func() -> void: _show_screen("game"))
	_button(column, "В главное меню", func() -> void: _show_screen("menu"))
	_button(column, "Выйти из игры", func() -> void: _ask("Вы уверены, что хотите выйти?", get_tree().quit))


func _show_screen(target: String) -> void:
	screen = target
	for key in pages:
		pages[key].visible = key == target
	for item in [$Logo, $PlayButton, $SettingsButton, $ExitButton, fullscreen_button]:
		item.visible = target == "menu"
	$Background.visible = target == "menu"
	if target == "game":
		_refresh_game()


func _show_settings() -> void:
	settings_origin = screen
	_show_screen("settings")


func _start_game() -> void:
	var first := names[0].text.strip_edges()
	var second := names[1].text.strip_edges()
	if first.is_empty() or second.is_empty() or " " in first or " " in second or first.to_lower() == second.to_lower():
		_notice("Имена должны быть непустыми, без пробелов и различаться.")
		return
	var c1 := color_choices[0].color
	var c2 := color_choices[1].color
	c1.a = 1.0
	c2.a = 1.0
	if Vector3(c1.r, c1.g, c1.b).distance_to(Vector3(c2.r, c2.g, c2.b)) < 0.45:
		_notice("Выберите более разные цвета игроков.")
		return
	player_names = [first, second]
	player_colors = [c1, c2]
	current_player = 1
	missed_turns = 0
	game_over = false
	board.start(FIELD_SIZES[selected_size_index], player_colors)
	status_label.text = "Бросьте кости, чтобы получить прямоугольник."
	_show_screen("game")


func _roll() -> void:
	var roll := dice_roller.roll_rectangle()
	if board.offer(current_player, roll):
		status_label.text = "Разместите фигуру, затем подтвердите ход."
	else:
		missed_turns += 1
		board.clear_preview()
		if missed_turns == 2:
			_finish_game()
		else:
			_next_player()
			_notice("Прямоугольник %d × %d разместить невозможно. Ход пропущен." % [roll.x, roll.y])
	_refresh_game()


func _confirm_move() -> void:
	if not board.commit():
		return
	missed_turns = 0
	_next_player()
	status_label.text = "Ход подтверждён. Бросьте кости."
	_refresh_game()


func _next_player() -> void:
	current_player = 3 - current_player


func _finish_game() -> void:
	game_over = true
	var first := board.area(1)
	var second := board.area(2)
	status_label.text = "Ничья!" if first == second else "Победил %s!" % player_names[0 if first > second else 1]
	_notice("Игра окончена. " + status_label.text)


func _refresh_game() -> void:
	if board == null:
		return
	for i in 2:
		avatar_labels[i].text = AVATARS[avatars[i].selected]
		avatar_labels[i].add_theme_color_override("font_color", player_colors[i])
		player_labels[i].text = "%s\nПлощадь: %d клеток" % [player_names[i], board.area(i + 1)]
		player_labels[i].add_theme_color_override("font_color", player_colors[i])
	turn_label.text = "Ход: %s" % player_names[current_player - 1]
	dice_label.text = "Кости: —" if board.dice == Vector2i.ZERO else "Кости: %d × %d" % [board.dice.x, board.dice.y]
	for i in 2:
		dice_faces[i].text = "?" if board.dice == Vector2i.ZERO else str([board.dice.x, board.dice.y][i])
	var has_figure := board.dice != Vector2i.ZERO
	stage_piece.visible = has_figure
	stage_hint.visible = not has_figure
	stage_hint.text = "Бросьте кости, чтобы получить фигуру"
	if has_figure:
		var extent := board.dimensions()
		var unit := minf((stage.size.x - 48) / extent.x, (stage.size.y - 48) / extent.y)
		stage_piece.size = Vector2(extent) * unit
		stage_piece.position = (stage.size - stage_piece.size) / 2.0
		stage_style.bg_color = Color(player_colors[current_player - 1].r, player_colors[current_player - 1].g, player_colors[current_player - 1].b, 0.52)
		stage_style.border_color = player_colors[current_player - 1]
		stage_area.text = str(extent.x * extent.y)
	roll_button.disabled = game_over or board.dice != Vector2i.ZERO
	confirm_button.disabled = game_over or board.pending == Vector2i(-1, -1)


func _ask(message: String, action: Callable) -> void:
	confirm_action = action
	confirmation.dialog_text = message
	confirmation.popup_centered()


func _notice(message: String) -> void:
	alert.dialog_text = message
	alert.popup_centered()


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_update_fullscreen_hint()


func _update_fullscreen_hint() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.text = "▣" if full else "□"
	fullscreen_button.tooltip_text = "Оконный режим" if full else "Полноэкранный режим"


func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for bus_name in audio_sliders:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		var value := float(config.get_value("audio", bus_name, 50.0))
		audio_sliders[bus_name].set_value_no_signal(value)
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus_name), value / 100.0)


func _save_volume(bus_name: String, value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus_name), value / 100.0)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", bus_name, value)
	config.save("user://settings.cfg")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q and screen == "game":
		board.rotate_preview()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		match screen:
			"game": _show_screen("pause")
			"settings": _show_screen(settings_origin)
			"setup", "pause": _show_screen("menu" if screen == "setup" else "game")
