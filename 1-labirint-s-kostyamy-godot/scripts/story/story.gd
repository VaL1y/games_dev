extends Control

const Model = preload("res://scripts/story/story_model.gd")
const Board = preload("res://scripts/story/story_board.gd")
const Dialogue = preload("res://scripts/story/story_dialogue.gd")
const DIE_SCENE := preload("res://scenes/die.tscn")
const PORTRAIT := preload("res://assets/story/nika.png")
var model := Model.new()
var save_path := Model.SAVE_PATH
var board: StoryBoard
var dialogue: StoryDialogue
var die: Die
var roll_button: Button
var controls: HBoxContainer
var prompt: Label
var entry_title: Label
var shade: ColorRect
var popup_title: Label
var popup_body: Label
var popup_list: VBoxContainer
var popup_buttons: Array[Button] = []
var popup_options: Array = []
var popup_selected := 0
var popup_kind := ""
var journal_index := 0
var busy := false
var save_error := ""

func _ready() -> void:
	if GameSession.story_continue and not model.load_game(save_path):
		save_error = "Сохранение не удалось прочитать. Начата новая экспедиция."
	_build_ui()
	if not model.content.error.is_empty():
		_popup("error", "Не удалось загрузить главу", model.content.error, [{"label": "В меню", "action": "menu"}])
		return
	board.model = model
	board.destination_selected.connect(_move)
	board.selection_changed.connect(func(_cell): _update_prompt())
	dialogue.continued.connect(_advance)
	dialogue.chosen.connect(_choose)
	_present()
	_show_title()

func _label(text: String, size_value: int, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	parent.add_child(label)
	return label

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 43
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", Dialogue.frame(Color("10151a")))
	b.add_theme_stylebox_override("hover", Dialogue.frame(Color("243239")))
	b.add_theme_stylebox_override("pressed", Dialogue.frame(Color("334049")))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("070a0d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	board = Board.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	# A compact corner card; the other corners remain free for future players.
	var card := PanelContainer.new()
	card.position = Vector2(24, 24)
	card.add_theme_stylebox_override("panel", Dialogue.frame())
	add_child(card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	card.add_child(card_row)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2(52, 52)
	card_row.add_child(portrait)
	_label("НИКА", 23, card_row)
	var top := HBoxContainer.new()
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -350
	top.offset_right = -24
	top.offset_top = 24
	top.offset_bottom = 80
	top.add_theme_constant_override("separation", 10)
	_button("Рюкзак [I]", top, _inventory)
	_button("Дневник [J]", top, _journal)
	_button("Esc", top, _pause)
	entry_title = _label("", 32, self)
	entry_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_title.anchor_left = .25
	entry_title.anchor_right = .75
	entry_title.offset_top = 32
	entry_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := VBoxContainer.new()
	bottom.anchor_left = .2
	bottom.anchor_right = .8
	bottom.anchor_top = 1
	bottom.anchor_bottom = 1
	bottom.offset_top = -116
	bottom.offset_bottom = -16
	add_child(bottom)
	prompt = _label("", 21, bottom)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	controls = HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	bottom.add_child(controls)
	die = DIE_SCENE.instantiate()
	die.custom_minimum_size = Vector2(58, 58)
	controls.add_child(die)
	die.set_value(1)
	roll_button = _button("Бросить кубик [Пробел]", controls, _roll)
	dialogue = Dialogue.new()
	dialogue.anchor_left = .055
	dialogue.anchor_right = .945
	dialogue.anchor_top = .625
	dialogue.anchor_bottom = .975
	add_child(dialogue)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, .72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = .25
	panel.anchor_right = .75
	panel.anchor_top = .17
	panel.anchor_bottom = .83
	panel.add_theme_stylebox_override("panel", Dialogue.frame())
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	panel.add_child(box)
	popup_title = _label("", 32, box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	popup_body = _label("", 24, scroll)
	popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_list = VBoxContainer.new()
	popup_list.add_theme_constant_override("separation", 8)
	box.add_child(popup_list)
	_label("↑ ↓ — выбрать   Enter — подтвердить   Esc — назад", 18, box)

func _process(delta: float) -> void:
	if popup_kind == "" and not model.state.completed: model.state.elapsed += delta

func _refresh() -> void:
	board.refresh()
	if not model.content.error.is_empty():
		_popup("error", "Ошибка карты", model.content.error, [{"label": "В меню", "action": "menu"}])
	controls.visible = model.state.pending == ""
	prompt.visible = model.state.pending == ""
	roll_button.disabled = busy or int(model.state.roll) > 0
	roll_button.text = "Подтвердить путь [Enter]" if int(model.state.roll) > 0 else "Бросить кубик [Пробел]"
	# This button stays actionable as a mouse confirmation after rolling.
	if int(model.state.roll) > 0 and not busy: roll_button.disabled = false
	if int(model.state.roll) > 0 and not busy: die.set_value(int(model.state.roll))
	dialogue.sound_enabled = model.state.sound
	_update_prompt()

func _update_prompt() -> void:
	if int(model.state.roll) > 0:
		var length: int = board.destinations.get(board.selected, []).size()
		prompt.text = "До %d шагов в любую сторону · выбрано %d · стрелки или мышь" % [model.state.roll, length]
	else: prompt.text = ""

func _show_title() -> void:
	entry_title.text = model.content.get_scene(model.current_map().intro).title
	entry_title.modulate.a = 1
	var tween := create_tween()
	tween.tween_interval(3)
	tween.tween_property(entry_title, "modulate:a", 0, 1)

func _present() -> void:
	_refresh()
	if model.state.pending == "":
		dialogue.visible = false
	else:
		var scene := model.active_scene()
		var options: Array = []
		for c in scene.get("choices", []):
			options.append({"label": c.label, "hint": model.choice_hint(c), "enabled": model.can_choose(c)})
		if model.state.pending == "ending":
			options = [{"label": "В главное меню"}, {"label": "Прочитать дневник"}]
		dialogue.present(str(scene.get("title", "Ника")), str(scene.get("text", "")), options)
	_save()

func _save() -> void:
	if not model.content.error.is_empty(): return
	var result := model.save_game(save_path)
	if result != OK: save_error = "Не удалось сохранить: " + error_string(result)

func _advance() -> void:
	model.advance()
	_present()

func _choose(index: int) -> void:
	if model.state.pending == "ending":
		if index == 0: _menu()
		else: _journal()
		return
	if model.state.pending == "exit":
		var c: Dictionary = model.active_scene().choices[index]
		match str(c.get("action", "")):
			"next":
				model.next_map()
				_show_title()
			"return": model.state.pending = ""
			"restore", "take", "leave": model.finish(c.action)
	else: model.resolve(index)
	_present()

func _roll() -> void:
	if busy or popup_kind != "" or model.state.pending != "": return
	if int(model.state.roll) > 0:
		if board.selected != "": _move(board.selected)
		return
	var value := model.roll_die()
	if value == 0: return
	busy = true
	_refresh()
	_save()
	die.roll(value)
	await die.roll_finished
	busy = false
	_refresh()

func _move(cell: String) -> void:
	if busy or popup_kind != "" or model.state.pending != "": return
	var path := model.move_to(cell)
	if path.is_empty(): return
	busy = true
	controls.visible = false
	prompt.visible = false
	_save()
	await board.animate_path(path)
	busy = false
	_present()

func _popup(kind: String, title: String, text: String, options: Array) -> void:
	popup_kind = kind
	popup_title.text = title
	popup_body.text = text
	popup_options = options
	popup_selected = 0
	shade.visible = true
	dialogue.frozen = true
	for child in popup_list.get_children():
		popup_list.remove_child(child)
		child.queue_free()
	popup_buttons.clear()
	for i in range(options.size()):
		var b := _button(options[i].label, popup_list, _popup_action.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(_popup_select.bind(i))
		popup_buttons.append(b)
	_popup_select(0)

func _popup_select(index: int) -> void:
	popup_selected = index
	for i in range(popup_buttons.size()):
		popup_buttons[i].text = ("› " if index == i else "  ") + str(popup_options[i].label)
		popup_buttons[i].add_theme_color_override("font_color", Color("ffe2a5") if index == i else Color("dddcd5"))
	if popup_kind == "inventory": popup_body.text = str(popup_options[index].get("description", "Вернуться к карте или текущей реплике."))

func _close_popup() -> void:
	popup_kind = ""
	shade.visible = false
	dialogue.frozen = false
	_refresh()
	_save()

func _pause() -> void:
	if busy: return
	_save()
	_popup("pause", "Пауза", save_error if save_error != "" else "Путь сохранён. Можно перевести дыхание.", [
		{"label": "Продолжить", "action": "close"}, {"label": "Правила", "action": "help"},
		{"label": "Звук реплик: " + ("вкл." if model.state.sound else "выкл."), "action": "sound"},
		{"label": "Сохранить и выйти", "action": "menu"}])

func _inventory() -> void:
	if busy: return
	var options: Array = []
	for item in Model.ITEMS:
		var description: String = {"rope": "Многоразовая страховка. Используется при выборе действия в событии.", "torch": "Освещает тёмную карту до следующего перемещения. Можно зажечь после броска. В событиях расходуется отдельно.", "tool": "Тонкая бронзовая пластина. Открывает замки и фиксирует ловушки; обычно расходуется."}[item]
		options.append({"label": "%s ×%d" % [Model.ITEMS[item], model.state.inventory.get(item, 0)], "action": "torch" if item == "torch" else "inspect", "description": description})
	options.append({"label": "Назад", "action": "close"})
	_popup("inventory", "Рюкзак", "", options)

func _journal() -> void:
	if busy: return
	journal_index = clampi(journal_index, 0, maxi(0, model.state.journal.size() - 1))
	var text: String = model.content.get_scene(model.current_map().goal).text
	if not model.state.journal.is_empty(): text += "\n\n" + str(model.state.journal[journal_index])
	_popup("journal", "Дневник · запись %d / %d" % [journal_index + 1, maxi(1, model.state.journal.size())], text, [
		{"label": "Предыдущая запись", "action": "prev"}, {"label": "Следующая запись", "action": "next_entry"}, {"label": "Назад", "action": "close"}])

func _popup_action(index: int) -> void:
	match str(popup_options[index].get("action", "")):
		"close": _close_popup()
		"menu": _menu()
		"sound":
			model.state.sound = not model.state.sound
			_save()
			_pause()
		"help": _popup("help", "Как идти", "Кубик задаёт максимум шагов. Можно выбрать любую достижимую клетку: вперёд, назад или по другой ветви.\n\nEnter подтверждает путь. Обычное событие происходит только на выбранной клетке и только один раз. Сюжетные реплики появляются после него, когда достигнут их порог.\n\nI — рюкзак. J — дневник. В диалоге Enter сначала раскрывает текст, затем продолжает реплику. Стрелки выбирают ответ.", [{"label": "Назад", "action": "pause"}])
		"pause": _pause()
		"torch":
			if model.use_torch():
				_close_popup()
			else: popup_body.text = "Факел можно зажечь на тёмной карте, когда не идёт событие. Нужен хотя бы один факел; второй свет не усиливает."
		"prev":
			journal_index = maxi(0, journal_index - 1)
			_journal()
		"next_entry":
			journal_index += 1
			_journal()

func _menu() -> void:
	_save()
	get_tree().change_scene_to_file(GameSession.MAIN_MENU_SCENE)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if busy:
		get_viewport().set_input_as_handled()
		return
	var key: int = event.keycode
	if popup_kind != "":
		if key == KEY_ESCAPE:
			if popup_kind == "help": _pause()
			elif popup_kind != "error": _close_popup()
		elif key in [KEY_UP, KEY_DOWN]: _popup_select(posmod(popup_selected + (1 if key == KEY_DOWN else -1), popup_buttons.size()))
		elif key in [KEY_ENTER, KEY_KP_ENTER]: _popup_action(popup_selected)
	elif key == KEY_ESCAPE: _pause()
	elif event.physical_keycode == KEY_I: _inventory()
	elif event.physical_keycode == KEY_J: _journal()
	elif dialogue.visible: dialogue.handle_key(key)
	elif key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: _roll()
	elif key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		board.select_direction({KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[key])
	else: return
	get_viewport().set_input_as_handled()
