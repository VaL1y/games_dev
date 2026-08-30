extends Control

const BoardViewScript = preload("res://scripts/board_view.gd")

const WORLD_ONE_CELLS := 24
const WORLD_TWO_CELLS := 12
const MAX_LOG_LINES := 7

const BG := Color("#07111e")
const PANEL := Color("#101e2f")
const PANEL_ALT := Color("#13263a")
const BORDER := Color("#29445d")
const TEXT := Color("#eef6ff")
const MUTED := Color("#91a4b7")
const CYAN := Color("#43d9ff")
const GOLD := Color("#f8c45e")
const GREEN := Color("#63e6be")
const RED := Color("#ff6b7f")

var rng := RandomNumberGenerator.new()
var players: Array = []
var current_index := 0
var first_finisher_id := -1
var first_risk_player_id := -1
var finish_counter := 0
var waiting_choice_index := -1
var game_finished := false
var demo_mode := false
var shadow := {
	"active": false,
	"target": -1,
	"position": 0,
	"delay": 6,
}
var log_lines: Array[String] = []

var board_view
var board_title: Label
var world_badge: Label
var turn_label: Label
var dice_one: Label
var dice_two: Label
var dice_sum: Label
var roll_button: Button
var player_rows: VBoxContainer
var log_view: RichTextLabel
var objective_text: Label
var status_bar: Label
var finish_dialog: ConfirmationDialog
var result_dialog: AcceptDialog


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not roll_button.disabled:
		_on_roll_pressed()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	page.add_child(_build_header())

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	page.add_child(content)

	content.add_child(_build_left_column())
	content.add_child(_build_board_column())
	content.add_child(_build_right_column())

	status_bar = _make_label("", 12, MUTED)
	status_bar.custom_minimum_size.y = 22
	page.add_child(status_bar)

	finish_dialog = ConfirmationDialog.new()
	finish_dialog.title = "Финиш первого мира"
	finish_dialog.dialog_text = "Вы пришли к финишу. Зафиксировать обычную победу или рискнуть и перейти во второй мир?"
	finish_dialog.ok_button_text = "РИСКНУТЬ"
	finish_dialog.cancel_button_text = "ЗАБРАТЬ ПОБЕДУ"
	finish_dialog.exclusive = true
	finish_dialog.confirmed.connect(_on_risk_confirmed)
	finish_dialog.canceled.connect(_on_safe_chosen)
	add_child(finish_dialog)

	result_dialog = AcceptDialog.new()
	result_dialog.title = "Партия завершена"
	result_dialog.ok_button_text = "СМОТРЕТЬ ПОЛЕ"
	add_child(result_dialog)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 12)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var kicker := _make_label("ИГРА-ПРОТОТИП  ·  MVP 0.1", 11, GOLD)
	title_box.add_child(kicker)
	var title := _make_label("Лабиринт с костями", 26, TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title_box.add_child(title)

	world_badge = _make_label("ПЕРВЫЙ МИР", 12, CYAN)
	world_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_badge.custom_minimum_size = Vector2(135, 40)
	header.add_child(_wrap_in_panel(world_badge, PANEL_ALT, CYAN, 8))

	var demo_button := _make_button("ДЕМО РИСКА", GOLD, Color("#3a2d10"))
	demo_button.tooltip_text = "Сразу показать второй мир и тень с форой 6 ходов"
	demo_button.pressed.connect(_start_risk_demo)
	header.add_child(demo_button)

	var reset_button := _make_button("НОВАЯ ПАРТИЯ", CYAN, Color("#0d3040"))
	reset_button.pressed.connect(_new_game)
	header.add_child(reset_button)
	return header


func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 245
	column.add_theme_constant_override("separation", 12)

	var dice_content := VBoxContainer.new()
	dice_content.add_theme_constant_override("separation", 8)
	dice_content.add_child(_make_section_title("КОСТИ"))
	turn_label = _make_label("", 13, MUTED)
	dice_content.add_child(turn_label)

	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 10)
	dice_one = _make_die_label()
	dice_two = _make_die_label()
	dice_row.add_child(_wrap_in_panel(dice_one, PANEL_ALT, CYAN, 10))
	dice_row.add_child(_wrap_in_panel(dice_two, PANEL_ALT, CYAN, 10))
	dice_content.add_child(dice_row)

	dice_sum = _make_label("Сумма: —", 13, TEXT)
	dice_sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_content.add_child(dice_sum)

	roll_button = _make_button("БРОСИТЬ КОСТИ  [ПРОБЕЛ]", CYAN, Color("#0d3040"))
	roll_button.custom_minimum_size.y = 46
	roll_button.pressed.connect(_on_roll_pressed)
	dice_content.add_child(roll_button)
	column.add_child(_wrap_in_panel(dice_content, PANEL, BORDER, 12))

	var legend_content := VBoxContainer.new()
	legend_content.add_theme_constant_override("separation", 7)
	legend_content.add_child(_make_section_title("КЛЕТКИ"))
	legend_content.add_child(_legend_row(Color("#6e2c3a"), "Ловушка", "пропуск / назад"))
	legend_content.add_child(_legend_row(Color("#5b4a1f"), "Событие", "очки / движение"))
	legend_content.add_child(_legend_row(Color("#185848"), "Финиш", "выбор судьбы"))
	column.add_child(_wrap_in_panel(legend_content, PANEL, BORDER, 10))

	var log_content := VBoxContainer.new()
	log_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_content.add_child(_make_section_title("ЖУРНАЛ ПАРТИИ"))
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.fit_content = false
	log_view.scroll_active = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.add_theme_font_size_override("normal_font_size", 12)
	log_view.add_theme_color_override("default_color", MUTED)
	log_content.add_child(log_view)
	column.add_child(_wrap_in_panel(log_content, PANEL, BORDER, 10))
	return column


func _build_board_column() -> Control:
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	board_title = _make_label("", 14, TEXT)
	content.add_child(board_title)
	board_view = BoardViewScript.new()
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board_view)
	return _wrap_in_panel(content, PANEL, BORDER, 12)


func _build_right_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	column.add_theme_constant_override("separation", 12)

	var objective := VBoxContainer.new()
	objective.add_theme_constant_override("separation", 8)
	objective.add_child(_make_section_title("ЦЕЛЬ"))
	objective_text = _make_label("", 13, TEXT)
	objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(objective_text)
	var formula := _make_label("Очки хода = клетка × сумма костей", 11, GOLD)
	formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(formula)
	column.add_child(_wrap_in_panel(objective, PANEL, BORDER, 11))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var player_content := VBoxContainer.new()
	player_content.add_theme_constant_override("separation", 7)
	player_content.add_child(_make_section_title("ИГРОКИ"))
	player_rows = VBoxContainer.new()
	player_rows.add_theme_constant_override("separation", 6)
	player_content.add_child(player_rows)
	column.add_child(_wrap_in_panel(player_content, PANEL, BORDER, 10))
	return column


func _new_game() -> void:
	demo_mode = false
	game_finished = false
	waiting_choice_index = -1
	current_index = 0
	first_finisher_id = -1
	first_risk_player_id = -1
	finish_counter = 0
	shadow = {"active": false, "target": -1, "position": 0, "delay": 6}
	log_lines.clear()
	players = [
		_make_player(0, "Валерий", false, Color("#43d9ff")),
		_make_player(1, "Лиса-бот", true, Color("#f8c45e")),
		_make_player(2, "Ворон-бот", true, Color("#b78cff")),
		_make_player(3, "Мох-бот", true, Color("#63e6be")),
	]
	_set_dice(0, 0)
	_add_log("Новая партия началась. Ваш ход — бросайте кости.", CYAN)
	_refresh_ui()
	call_deferred("_maybe_run_bot")


func _start_risk_demo() -> void:
	_new_game()
	demo_mode = true
	for player in players:
		if int(player["id"]) == 0:
			player["world"] = 2
			player["position"] = 0
			player["status"] = "Второй мир"
		else:
			player["status"] = "Безопасный финиш"
			player["finish_order"] = int(player["id"])
	first_risk_player_id = 0
	shadow = {"active": true, "target": 0, "position": 0, "delay": 6}
	current_index = 0
	log_lines.clear()
	_add_log("Демо: вы рискнули. Тень начнет движение через 6 ваших ходов.", RED)
	_add_log("Во втором мире движение равно меньшей кости — путь опаснее.", GOLD)
	_refresh_ui()


func _make_player(id: int, player_name: String, is_bot: bool, color: Color) -> Dictionary:
	return {
		"id": id,
		"name": player_name,
		"is_bot": is_bot,
		"color": color,
		"world": 1,
		"position": 0,
		"score": 0,
		"skip": 0,
		"status": "В игре",
		"finish_order": 999,
	}


func _on_roll_pressed() -> void:
	if game_finished or waiting_choice_index >= 0:
		return
	if bool(players[current_index]["is_bot"]):
		return
	_take_turn(current_index)


func _take_turn(player_index: int) -> void:
	if game_finished or waiting_choice_index >= 0:
		return
	var player: Dictionary = players[player_index]
	if int(player["skip"]) > 0:
		player["skip"] = int(player["skip"]) - 1
		_add_log("%s пропускает ход из-за ловушки." % player["name"], RED)
		_finish_turn()
		return

	var first_die := rng.randi_range(1, 6)
	var second_die := rng.randi_range(1, 6)
	_set_dice(first_die, second_die)
	var dice_total := first_die + second_die
	var movement := dice_total if int(player["world"]) == 1 else mini(first_die, second_die)
	var world_limit := WORLD_ONE_CELLS if int(player["world"]) == 1 else WORLD_TWO_CELLS
	var old_position := int(player["position"])
	player["position"] = mini(world_limit, old_position + movement)
	var gained := int(player["position"]) * dice_total
	player["score"] = int(player["score"]) + gained
	_add_log("%s: %d + %d, ход на %d, +%d очков." % [player["name"], first_die, second_die, movement, gained], player["color"])

	if int(player["position"]) >= world_limit:
		if int(player["world"]) == 1:
			_reach_first_finish(player_index)
		else:
			_win_second_world(player_index)
		return

	_resolve_cell(player_index)
	if int(player["position"]) >= world_limit:
		if int(player["world"]) == 1:
			_reach_first_finish(player_index)
		else:
			_win_second_world(player_index)
		return

	if int(player["world"]) == 2 and bool(shadow["active"]) and int(shadow["target"]) == int(player["id"]):
		_advance_shadow(player_index)
		if game_finished:
			return
	_finish_turn()


func _resolve_cell(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	var world := int(player["world"])
	var position := int(player["position"])
	var traps: Array = [5, 10, 17, 21] if world == 1 else [2, 5, 8, 11]
	var random_cells: Array = [4, 9, 15] if world == 1 else [3, 7, 10]

	if position in traps:
		if rng.randi_range(0, 1) == 0:
			player["skip"] = int(player["skip"]) + 1
			_add_log("Ловушка! %s пропустит следующий ход." % player["name"], RED)
		else:
			var back := 3 if world == 1 else 2
			player["position"] = maxi(0, position - back)
			_add_log("Ловушка! %s возвращается на %d клетки." % [player["name"], back], RED)
	elif position in random_cells:
		var event_roll := rng.randi_range(0, 3)
		match event_roll:
			0:
				player["score"] = int(player["score"]) + 200
				_add_log("Событие: найден тайник, +200 очков.", GOLD)
			1:
				player["score"] = maxi(0, int(player["score"]) - 200)
				_add_log("Событие: потеря припасов, -200 очков.", RED)
			2:
				player["position"] = mini(WORLD_ONE_CELLS if world == 1 else WORLD_TWO_CELLS, position + 2)
				_add_log("Событие: короткий путь, вперед на 2 клетки.", GREEN)
			3:
				player["position"] = maxi(0, position - 2)
				_add_log("Событие: обвал, назад на 2 клетки.", RED)


func _reach_first_finish(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	finish_counter += 1
	player["finish_order"] = finish_counter
	if first_finisher_id == -1:
		first_finisher_id = int(player["id"])
		player["score"] = int(player["score"]) + 2000
		_add_log("%s первым достиг финиша: +2 000 очков!" % player["name"], GOLD)
	else:
		_add_log("%s достиг финиша первого мира." % player["name"], player["color"])

	if first_risk_player_id != -1 and not bool(shadow["active"]) and int(player["id"]) != first_risk_player_id:
		shadow["active"] = true
		shadow["target"] = first_risk_player_id
		shadow["position"] = 0
		shadow["delay"] = 6
		_add_log("Во втором мире появилась тень. Фора цели: 6 ходов.", RED)

	if bool(player["is_bot"]):
		_choose_finish(player_index, rng.randf() < 0.5)
	else:
		waiting_choice_index = player_index
		roll_button.disabled = true
		finish_dialog.popup_centered(Vector2i(520, 230))
		_refresh_ui()


func _on_risk_confirmed() -> void:
	if waiting_choice_index < 0:
		return
	var index := waiting_choice_index
	waiting_choice_index = -1
	_choose_finish(index, true)


func _on_safe_chosen() -> void:
	if waiting_choice_index < 0:
		return
	var index := waiting_choice_index
	waiting_choice_index = -1
	_choose_finish(index, false)


func _choose_finish(player_index: int, risk: bool) -> void:
	if finish_dialog.visible:
		finish_dialog.hide()
	var player: Dictionary = players[player_index]
	if risk:
		player["world"] = 2
		player["position"] = 0
		player["status"] = "Второй мир"
		if first_risk_player_id == -1:
			first_risk_player_id = int(player["id"])
		_add_log("%s выбирает РИСК и входит во второй мир." % player["name"], RED)
	else:
		player["status"] = "Безопасный финиш"
		_add_log("%s фиксирует безопасную победу." % player["name"], GREEN)
	_finish_turn()


func _advance_shadow(target_index: int) -> void:
	var target: Dictionary = players[target_index]
	if int(shadow["delay"]) > 0:
		shadow["delay"] = int(shadow["delay"]) - 1
		_add_log("Фора тени: осталось %d ходов." % int(shadow["delay"]), RED)
		return
	var shadow_roll := rng.randi_range(1, 6)
	shadow["position"] = mini(WORLD_TWO_CELLS, int(shadow["position"]) + shadow_roll)
	_add_log("Тень движется на %d. Ее позиция: %d." % [shadow_roll, int(shadow["position"])], RED)
	if int(shadow["position"]) >= int(target["position"]):
		target["status"] = "Пойман"
		_add_log("Тень поймала %s. Риск-маршрут провален." % target["name"], RED)
		shadow["active"] = false
		if demo_mode:
			_end_without_second_world_winner()


func _win_second_world(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	player["status"] = "Победитель"
	player["score"] = int(player["score"]) + 5000
	game_finished = true
	_add_log("%s выжил во втором мире: +5 000!" % player["name"], GOLD)
	_refresh_ui()
	_show_result("Абсолютная победа: %s\nИтоговый счет: %s" % [player["name"], _format_score(int(player["score"]))])


func _finish_turn() -> void:
	if game_finished:
		_refresh_ui()
		return
	if not _advance_to_next_active_player():
		_end_without_second_world_winner()
		return
	_refresh_ui()
	call_deferred("_maybe_run_bot")


func _advance_to_next_active_player() -> bool:
	for offset in range(1, players.size() + 1):
		var candidate := (current_index + offset) % players.size()
		if str(players[candidate]["status"]) in ["В игре", "Второй мир"]:
			current_index = candidate
			return true
	return false


func _end_without_second_world_winner() -> void:
	game_finished = true
	var candidates: Array = []
	for player in players:
		if str(player["status"]) == "Безопасный финиш":
			candidates.append(player)
	if candidates.is_empty():
		candidates = players.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["finish_order"]) != int(b["finish_order"]):
			return int(a["finish_order"]) < int(b["finish_order"])
		return int(a["score"]) > int(b["score"])
	)
	var winner: Dictionary = candidates[0]
	_add_log("Партия завершена. Запасной победитель: %s." % winner["name"], GREEN)
	_refresh_ui()
	_show_result("Второй мир никто не прошел.\nПобедитель первого мира: %s\nСчет: %s" % [winner["name"], _format_score(int(winner["score"]))])


func _maybe_run_bot() -> void:
	if game_finished or waiting_choice_index >= 0:
		return
	var player: Dictionary = players[current_index]
	if not bool(player["is_bot"]):
		return
	roll_button.disabled = true
	await get_tree().create_timer(0.65).timeout
	if game_finished or waiting_choice_index >= 0:
		return
	if bool(players[current_index]["is_bot"]):
		_take_turn(current_index)


func _refresh_ui() -> void:
	if players.is_empty():
		return
	var current: Dictionary = players[current_index]
	var shown_world := int(current["world"])
	if str(current["status"]) not in ["В игре", "Второй мир", "Победитель"]:
		shown_world = 2 if first_risk_player_id != -1 else 1
	world_badge.text = "ВТОРОЙ МИР" if shown_world == 2 else "ПЕРВЫЙ МИР"
	world_badge.add_theme_color_override("font_color", RED if shown_world == 2 else CYAN)
	turn_label.text = "Ход: %s" % current["name"]
	var shadow_suffix := ""
	if shown_world == 2 and bool(shadow["active"]):
		shadow_suffix = "  ·  Тень: %d  ·  Фора: %d" % [int(shadow["position"]), int(shadow["delay"])]
	board_title.text = ("ВТОРОЙ МИР  ·  движение по меньшей кости" if shown_world == 2 else "ПЕРВЫЙ МИР  ·  путь к точке Б") + shadow_suffix
	objective_text.text = "Дойдите до клетки 24 и решите: забрать победу или рискнуть." if shown_world == 1 else "Дойдите до клетки 12 раньше тени. За выживание: +5 000."
	roll_button.disabled = game_finished or waiting_choice_index >= 0 or bool(current["is_bot"])
	status_bar.text = "ПРОБЕЛ — бросить кости  ·  Голубая обводка фишки — текущий игрок  ·  Кнопка «Демо риска» показывает второй мир сразу"
	board_view.set_game_state(shown_world, players, int(current["id"]), shadow)
	_rebuild_player_rows()
	_update_log_view()


func _rebuild_player_rows() -> void:
	for child in player_rows.get_children():
		child.queue_free()
	for player in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var marker := ColorRect.new()
		marker.color = player["color"]
		marker.custom_minimum_size = Vector2(5, 44)
		row.add_child(marker)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var name_label := _make_label(str(player["name"]), 13, TEXT)
		if int(player["id"]) == int(players[current_index]["id"]):
			name_label.text += "  ◀"
			name_label.add_theme_color_override("font_color", CYAN)
		info.add_child(name_label)
		var detail := "%s · кл. %d" % [player["status"], int(player["position"])]
		info.add_child(_make_label(detail, 10, MUTED))
		row.add_child(info)
		var score := _make_label(_format_score(int(player["score"])), 13, GOLD)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score.custom_minimum_size.x = 62
		row.add_child(score)
		player_rows.add_child(_wrap_in_panel(row, PANEL_ALT, BORDER, 7))


func _set_dice(first_die: int, second_die: int) -> void:
	dice_one.text = "–" if first_die == 0 else str(first_die)
	dice_two.text = "–" if second_die == 0 else str(second_die)
	dice_sum.text = "Сумма: —" if first_die == 0 else "Сумма: %d" % (first_die + second_die)


func _add_log(message: String, color: Color = MUTED) -> void:
	var hex := color.to_html(false)
	log_lines.push_front("[color=#%s]› %s[/color]" % [hex, message])
	if log_lines.size() > MAX_LOG_LINES:
		log_lines.resize(MAX_LOG_LINES)
	_update_log_view()


func _update_log_view() -> void:
	if log_view == null:
		return
	log_view.text = "\n\n".join(log_lines)


func _show_result(message: String) -> void:
	result_dialog.dialog_text = message + "\n\nНажмите «Новая партия», чтобы сыграть еще раз."
	result_dialog.popup_centered(Vector2i(470, 240))


func _format_score(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = " " + raw.right(3) + result
		raw = raw.left(raw.length() - 3)
	return raw + result


func _make_section_title(text: String) -> Label:
	var label := _make_label(text, 11, MUTED)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	return label


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_die_label() -> Label:
	var label := _make_label("–", 30, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(72, 72)
	return label


func _make_button(text: String, accent: Color, fill: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(148, 40)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_stylebox_override("normal", _make_style(fill, accent, 7, 1))
	button.add_theme_stylebox_override("hover", _make_style(fill.lightened(0.10), accent, 7, 2))
	button.add_theme_stylebox_override("pressed", _make_style(fill.darkened(0.10), accent, 7, 2))
	button.add_theme_stylebox_override("disabled", _make_style(Color("#17222e"), Color("#3b4d5e"), 7, 1))
	return button


func _legend_row(color: Color, title: String, detail: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(13, 13)
	row.add_child(swatch)
	var title_label := _make_label(title, 11, TEXT)
	title_label.custom_minimum_size.x = 69
	row.add_child(title_label)
	row.add_child(_make_label(detail, 10, MUTED))
	return row


func _wrap_in_panel(content: Control, fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(fill, border, padding, 1))
	panel.add_child(content)
	return panel


func _make_style(fill: Color, border: Color, padding: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(9)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
