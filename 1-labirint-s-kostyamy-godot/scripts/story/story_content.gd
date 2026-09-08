class_name StoryContent
extends RefCounted

# The book is loaded directly: no generated duplicate of narrative text.
const MANIFEST := "res://story/chapter.json"
var scenes: Dictionary = {}
var maps: Array[Dictionary] = []
var error := ""

func _init() -> void:
	var manifest_path := MANIFEST if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("story/chapter.json")
	var manifest := _json(manifest_path)
	if manifest.is_empty(): return
	_read_book(manifest_path.get_base_dir().path_join(manifest.book))
	for relative in manifest.maps:
		var path := manifest_path.get_base_dir().path_join(relative)
		var m := _json(path)
		if m.is_empty(): return
		m.image_path = path.get_base_dir().path_join(m.image)
		m.index = {}
		m.beats = []
		for cell in m.cells:
			if m.index.has(cell.id): error = "Повторяется клетка " + str(cell.id)
			m.index[cell.id] = cell
			if cell.get("event", "") != "" and not scenes.has(cell.event):
				error = "В книге нет события: " + str(cell.event)
		for cell in m.cells:
			for link in cell.links:
				if not m.index.has(link): error = "Не найдена клетка " + str(link)
		for key in ["start", "exit"]:
			if not m.index.has(m[key]): error = "В карте нет " + key
		for key in ["intro", "goal", "outro"]:
			if not scenes.has(m[key]): error = "В книге нет сцены: " + str(m[key])
		for id in scenes:
			var scene: Dictionary = scenes[id]
			if scene.get("type") == "beat" and scene.get("map") == m.id: m.beats.append(id)
		m.beats.sort_custom(func(a, b): return int(scenes[a].not_before) < int(scenes[b].not_before))
		maps.append(m)

func _json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		error = "Не удалось прочитать " + path
		return {}
	return json.data

func _read_book(path: String) -> void:
	if not FileAccess.file_exists(path):
		error = "Не найдена книга: " + path
		return
	var current: Dictionary = {}
	var selected: Dictionary = {}
	var part := "text"
	for line in FileAccess.get_file_as_string(path).split("\n"):
		line = line.trim_suffix("\r")
		if line.begins_with("## "):
			current = {"id": "", "title": line.substr(3), "text": "", "choices": []}
			selected = {}
			part = "text"
		elif line.begins_with("### ") and not current.is_empty():
			selected = {"label": line.substr(4), "text": ""}
			current.choices.append(selected)
			part = "text"
		elif line.begins_with("<!-- ") and not current.is_empty():
			var parsed = JSON.parse_string(line.trim_prefix("<!-- ").trim_suffix(" -->"))
			if not parsed is Dictionary:
				error = "Некорректная настройка в сцене " + str(current.id)
				return
			if selected.is_empty():
				current.merge(parsed, true)
				if current.id == "" or scenes.has(current.id):
					error = "Пропущен или повторяется идентификатор сцены: " + str(current.title)
					return
				scenes[current.id] = current
			else: selected.merge(parsed, true)
		elif line == "**Если получилось:**": part = "win_text"
		elif line == "**Если не получилось:**": part = "lose_text"
		elif not current.is_empty():
			var target: Dictionary = current if selected.is_empty() else selected
			target[part] = str(target.get(part, "")) + line + "\n"
	for scene in scenes.values():
		scene.text = str(scene.text).strip_edges()
		for c in scene.choices:
			for key in ["text", "win_text", "lose_text"]:
				if c.has(key): c[key] = str(c[key]).strip_edges()

func get_scene(id: String) -> Dictionary:
	return scenes.get(id, {"id": id, "title": "Запись не найдена", "text": id, "choices": []})
