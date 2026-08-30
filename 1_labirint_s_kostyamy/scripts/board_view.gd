extends Control

const COLS := 6
const COLOR_BOARD := Color("#0b1726")
const COLOR_CELL := Color("#14283b")
const COLOR_CELL_ALT := Color("#193149")
const COLOR_TRAP := Color("#6e2c3a")
const COLOR_RANDOM := Color("#5b4a1f")
const COLOR_FINISH := Color("#185848")
const COLOR_GRID := Color("#34506b")
const COLOR_TEXT := Color("#dce9f5")
const COLOR_MUTED := Color("#7f98ad")
const COLOR_CURRENT := Color("#ffffff")
const COLOR_SHADOW := Color("#ff5577")

var shown_world := 1
var players: Array = []
var current_player_id := -1
var shadow: Dictionary = {}
var cell_rects: Array[Rect2] = []


func _ready() -> void:
	custom_minimum_size = Vector2(560, 440)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_game_state(world_id: int, player_list: Array, active_id: int, shadow_state: Dictionary) -> void:
	shown_world = world_id
	players = player_list
	current_player_id = active_id
	shadow = shadow_state
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BOARD, true)
	var count := 24 if shown_world == 1 else 12
	var rows := int(ceil(float(count) / float(COLS)))
	var padding := 24.0
	var gap := 10.0
	var usable := size - Vector2(padding * 2.0, padding * 2.0)
	var cell_w := (usable.x - gap * float(COLS - 1)) / float(COLS)
	var cell_h := (usable.y - gap * float(rows - 1)) / float(rows)
	cell_rects.clear()

	for index in range(count):
		var row := index / COLS
		var logical_col := index % COLS
		var col := logical_col if row % 2 == 0 else COLS - 1 - logical_col
		var rect := Rect2(
			Vector2(padding + float(col) * (cell_w + gap), padding + float(rows - 1 - row) * (cell_h + gap)),
			Vector2(cell_w, cell_h)
		)
		cell_rects.append(rect)
		var cell_number := index + 1
		var fill := _cell_color(cell_number)
		draw_rect(rect, fill, true)
		draw_rect(rect, COLOR_GRID, false, 2.0)
		_draw_cell_label(rect, cell_number, count)

	_draw_players()
	if shown_world == 2 and bool(shadow.get("active", false)):
		_draw_shadow()


func _cell_color(cell_number: int) -> Color:
	var traps: Array = [5, 10, 17, 21] if shown_world == 1 else [2, 5, 8, 11]
	var random_cells: Array = [4, 9, 15] if shown_world == 1 else [3, 7, 10]
	var count := 24 if shown_world == 1 else 12
	if cell_number == count:
		return COLOR_FINISH
	if cell_number in traps:
		return COLOR_TRAP
	if cell_number in random_cells:
		return COLOR_RANDOM
	return COLOR_CELL if cell_number % 2 == 0 else COLOR_CELL_ALT


func _draw_cell_label(rect: Rect2, cell_number: int, count: int) -> void:
	var font := get_theme_default_font()
	var font_size := 15
	draw_string(font, rect.position + Vector2(9, 21), str(cell_number), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)
	var caption := ""
	if cell_number == count:
		caption = "ФИНИШ"
	elif _cell_color(cell_number) == COLOR_TRAP:
		caption = "ЛОВУШКА"
	elif _cell_color(cell_number) == COLOR_RANDOM:
		caption = "? СОБЫТИЕ"
	if not caption.is_empty():
		draw_string(font, rect.position + Vector2(9, rect.size.y - 10), caption, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 18, 11, COLOR_MUTED)


func _draw_players() -> void:
	var occupants: Dictionary = {}
	for player in players:
		if int(player.get("world", 1)) != shown_world:
			continue
		if str(player.get("status", "")) not in ["В игре", "Второй мир", "Победитель"]:
			continue
		var position := int(player.get("position", 0))
		var cell_index := clampi(maxi(position, 1) - 1, 0, cell_rects.size() - 1)
		if not occupants.has(cell_index):
			occupants[cell_index] = []
		occupants[cell_index].append(player)

	for cell_index in occupants:
		var rect: Rect2 = cell_rects[int(cell_index)]
		var cell_players: Array = occupants[cell_index]
		for token_index in range(cell_players.size()):
			var player: Dictionary = cell_players[token_index]
			var col := token_index % 2
			var row := token_index / 2
			var center := rect.get_center() + Vector2(-10 + col * 20, -8 + row * 20)
			var color: Color = player.get("color", Color.WHITE)
			draw_circle(center, 9.0, color)
			var outline := COLOR_CURRENT if int(player.get("id", -1)) == current_player_id else COLOR_BOARD
			draw_arc(center, 10.5, 0.0, TAU, 24, outline, 2.5)


func _draw_shadow() -> void:
	if cell_rects.is_empty():
		return
	var position := int(shadow.get("position", 0))
	var cell_index := clampi(maxi(position, 1) - 1, 0, cell_rects.size() - 1)
	var rect: Rect2 = cell_rects[cell_index]
	var center := rect.position + Vector2(rect.size.x - 17, 17)
	draw_circle(center, 9.0, COLOR_SHADOW)
	draw_arc(center, 12.0, 0.0, TAU, 24, Color("#35141d"), 3.0)
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(-4, 5), "Т", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

