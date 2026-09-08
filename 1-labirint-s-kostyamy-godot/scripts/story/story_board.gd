class_name StoryBoard
extends Control

signal destination_selected(cell: String)
signal selection_changed(cell: String)
var model: StoryModel
var texture: ImageTexture
var loaded_map := ""
var destinations: Dictionary = {}
var selected := ""
var token_cell := ""
var token_position := Vector2.ZERO
var moving := false
var overlays: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func picture_rect() -> Rect2:
	var original: Array = model.current_map().image_size
	var source := Vector2(float(original[0]), float(original[1]))
	var ratio := minf(size.x / source.x, size.y / source.y)
	return Rect2((size - source * ratio) * .5, source * ratio)

func point(cell: String) -> Vector2:
	var p: Array = model.current_map().index[cell].position
	return source_point(Vector2(float(p[0]), float(p[1])))

func source_point(p: Vector2) -> Vector2:
	var rect := picture_rect()
	return rect.position + p * rect.size.x / float(model.current_map().image_size[0])

func radius() -> float:
	return float(model.current_map().get("hit_radius", 34)) * picture_rect().size.x / float(model.current_map().image_size[0])

func refresh() -> void:
	var m := model.current_map()
	if loaded_map != m.id:
		loaded_map = m.id
		# Raw PNG/JPEG: replacing image + JSON does not require a Godot import step.
		var img := _image(m.image_path)
		if img == null or img.is_empty():
			model.content.error = "Не удалось открыть изображение: " + str(m.image_path)
		else:
			texture = ImageTexture.create_from_image(img)
		overlays.clear()
		for layer in m.get("overlays", []):
			var layer_image := _image(str(m.image_path).get_base_dir().path_join(layer.image))
			if layer_image != null and not layer_image.is_empty():
				var entry: Dictionary = layer.duplicate()
				entry.texture = ImageTexture.create_from_image(layer_image)
				overlays.append(entry)
	destinations = model.routes()
	if not destinations.has(selected):
		selected = str(destinations.keys()[0]) if not destinations.is_empty() else ""
	token_cell = model.state.cell
	if not moving: token_position = point(token_cell)
	queue_redraw()

func _image(path: String) -> Image:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	if path.get_extension().to_lower() in ["jpg", "jpeg"]: image.load_jpg_from_buffer(bytes)
	else: image.load_png_from_buffer(bytes)
	return image

func revealed(cell: String) -> bool:
	if not model.current_map().get("dark", false) or model.state.flags.get("lit", false): return true
	return cell == model.state.cell or cell in model.neighbors(model.state.cell) or model.state.seen.has(model.key_for(cell))

func select_direction(direction: Vector2) -> void:
	if destinations.is_empty(): return
	var origin := point(selected if selected != "" else str(model.state.cell))
	var best := ""
	var score := INF
	for cell in destinations:
		var delta := point(cell) - origin
		var dot := delta.normalized().dot(direction)
		if dot > .2:
			var candidate := delta.length() / dot
			if candidate < score:
				score = candidate
				best = cell
	if best != "":
		selected = best
		selection_changed.emit(selected)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if model == null or moving: return
	if event is InputEventMouseMotion:
		var hit := hit_cell(event.position)
		tooltip_text = ""
		if hit != "":
			tooltip_text = str(model.event_at(hit).get("title", "Тихое место")) if revealed(hit) else "За пределами света"
			if destinations.has(hit):
				selected = hit
				selection_changed.emit(hit)
				queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := hit_cell(event.position)
		if destinations.has(hit):
			destination_selected.emit(hit)
			accept_event()

func hit_cell(at: Vector2) -> String:
	for cell in model.current_map().cells:
		if at.distance_to(point(cell.id)) <= radius(): return cell.id
	return ""

func animate_path(path: Array) -> void:
	moving = true
	destinations.clear()
	token_position = point(token_cell)
	for cell in path:
		var tween := create_tween()
		tween.tween_property(self, "token_position", point(cell), .12)
		await tween.finished
	moving = false
	refresh()

func _process(_delta: float) -> void:
	if moving: queue_redraw()

func _draw() -> void:
	if model == null or texture == null: return
	var rect := picture_rect()
	# The entire board, including tiles and paths, is supplied as an image.
	draw_texture_rect(texture, rect, false)
	for layer in overlays:
		if model.state.flags.get(layer.get("flag", ""), false):
			var at: Array = layer.get("position", [0, 0])
			var dimensions: Array = layer.get("size", model.current_map().image_size)
			var a := source_point(Vector2(at[0], at[1]))
			var b := source_point(Vector2(at[0] + dimensions[0], at[1] + dimensions[1]))
			draw_texture_rect(layer.texture, Rect2(a, b - a), false)
	if model.current_map().get("dark", false) and not model.state.flags.get("lit", false):
		draw_rect(rect, Color(0, 0, .025, .48))
	var r := radius()
	for cell in destinations:
		draw_arc(point(cell), r + 3, 0, TAU, 40, Color(1, .9, .7, .65), 2)
	if selected != "" and destinations.has(selected):
		var previous := point(model.state.cell)
		for step in destinations[selected]:
			var next := point(step)
			draw_line(previous, next, Color(1, .95, .8, .65), 3, true)
			previous = next
		draw_arc(point(selected), r + 7, 0, TAU, 40, Color.WHITE, 3)
	var token := token_position if moving else point(model.state.cell)
	draw_circle(token, r * .45, Color("172d33"))
	draw_arc(token, r * .45, 0, TAU, 32, Color("ffe2a5"), 3)
	draw_circle(token, r * .26, Color("68d7d5"))
