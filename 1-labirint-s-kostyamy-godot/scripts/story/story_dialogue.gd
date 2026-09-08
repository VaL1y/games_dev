class_name StoryDialogue
extends PanelContainer

signal continued
signal chosen(index: int)
const PORTRAIT := preload("res://assets/story/nika.png")
var heading: Label
var body: Label
var choices_box: VBoxContainer
var hint: Label
var guide: Button
var pages: Array[String] = []
var options: Array = []
var buttons: Array[Button] = []
var page := 0
var selected := 0
var letters := 0.0
var frozen := false
var sound_enabled := true
var voice: AudioStreamPlayer
var sound_cooldown := 0.0

static func frame(fill: Color = Color("080b10")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = Color("e3dfd3")
	s.set_border_width_all(3)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

func _ready() -> void:
	add_theme_stylebox_override("panel", frame())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	row.add_child(box)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("eac78e"))
	box.add_child(heading)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 27)
	body.custom_minimum_size.y = 96
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 2)
	box.add_child(choices_box)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("b5b1a8"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	guide = Button.new()
	guide.flat = true
	guide.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	guide.add_theme_font_size_override("font_size", 17)
	guide.focus_mode = Control.FOCUS_NONE
	guide.pressed.connect(step)
	box.add_child(guide)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -25
	add_child(voice)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(1000)
	for i in range(500):
		var t := float(i) / 22050.0
		bytes.encode_s16(i * 2, int(sin(t * TAU * 330) * exp(-t * 140) * 11000))
	wav.data = bytes
	voice.stream = wav
	visible = false

func present(title: String, text: String, actions: Array = []) -> void:
	heading.text = title
	pages.clear()
	# Small pages fit three lines; no scrolling in spoken dialogue.
	for paragraph in text.split("\n\n", false):
		var chunk := ""
		for word in paragraph.split(" ", false):
			if chunk.length() + word.length() > 190:
				pages.append(chunk.strip_edges())
				chunk = ""
			chunk += word + " "
		if not chunk.is_empty(): pages.append(chunk.strip_edges())
	if pages.is_empty(): pages.append("…")
	options = actions
	page = 0
	selected = 0
	visible = true
	frozen = false
	_show_page()

func _show_page() -> void:
	letters = 0
	body.text = pages[page]
	body.visible_characters = 0
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	buttons.clear()
	if page == pages.size() - 1:
		for i in range(options.size()):
			var b := Button.new()
			b.text = options[i].label
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 24)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_choose.bind(i))
			b.mouse_entered.connect(_select.bind(i))
			choices_box.add_child(b)
			buttons.append(b)
	_update_selection()
	choices_box.visible = false
	hint.visible = false
	guide.text = "Enter — показать реплику"

func reveal() -> void:
	letters = body.text.length()
	body.visible_characters = -1
	choices_box.visible = not buttons.is_empty()
	hint.visible = not buttons.is_empty()
	guide.text = "↑ ↓ — выбор · Enter — подтвердить" if not buttons.is_empty() else "Enter — дальше  ›"

func _process(delta: float) -> void:
	if not visible or frozen or body == null or body.visible_characters == -1: return
	letters += delta * 48
	body.visible_characters = int(letters)
	sound_cooldown -= delta
	if sound_enabled and sound_cooldown <= 0 and not body.text.substr(maxi(0, int(letters) - 1), 1).strip_edges().is_empty():
		voice.play()
		sound_cooldown = .075
	if int(letters) >= body.text.length(): reveal()

func _select(index: int) -> void:
	selected = index
	_update_selection()

func _update_selection() -> void:
	for i in range(buttons.size()):
		buttons[i].text = ("› " if i == selected else "  ") + str(options[i].label)
		buttons[i].add_theme_color_override("font_color", Color("ffe2a5") if i == selected else Color("e0ded6"))
		if not options[i].get("enabled", true): buttons[i].add_theme_color_override("font_color", Color("74767c"))
	hint.text = str(options[selected].get("hint", "")) if not options.is_empty() else ""

func _choose(index: int) -> void:
	if frozen or body.visible_characters != -1: return
	if options[index].get("enabled", true): chosen.emit(index)

func step() -> void:
	if frozen: return
	if body.visible_characters != -1: reveal()
	elif page < pages.size() - 1:
		page += 1
		_show_page()
	elif not options.is_empty(): _choose(selected)
	else: continued.emit()

func handle_key(key: int) -> void:
	if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: step()
	elif key in [KEY_UP, KEY_DOWN] and not buttons.is_empty() and body.visible_characters == -1:
		selected = posmod(selected + (1 if key == KEY_DOWN else -1), buttons.size())
		_update_selection()
