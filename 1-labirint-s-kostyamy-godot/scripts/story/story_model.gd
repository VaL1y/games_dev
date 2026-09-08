class_name StoryModel
extends RefCounted

const Content = preload("res://scripts/story/story_content.gd")
const SAVE_PATH := "user://heart_of_tide_v2.json"
const ITEMS := {"rope": "Верёвка", "torch": "Факел", "tool": "Отмычка"}
var content := Content.new()
var state: Dictionary
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	new_game()

func new_game() -> void:
	state = {"version": 2, "map": 0, "cell": "c01", "inventory": {"rope": 1, "torch": 2, "tool": 1},
		"turns": 0, "roll": 0, "visited": {}, "seen": {}, "flags": {}, "beats_done": {},
		"pending": "intro", "result": "", "result_for": "", "event_cell": "", "path": [],
		"journal": [], "completed": false, "ending": "", "elapsed": 0.0, "sound": true}
	if not content.maps.is_empty(): state.cell = current_map().start

func current_map() -> Dictionary:
	return content.maps[int(state.map)]

func key_for(cell: String) -> String:
	return str(current_map().id) + ":" + cell

func event_at(cell: String) -> Dictionary:
	var id: String = current_map().index[cell].get("event", "")
	return content.get_scene(id) if id != "" else {}

func neighbors(cell: String) -> Array[String]:
	var result: Array[String] = []
	var m := current_map()
	for n in m.index[cell].links:
		if not result.has(str(n)): result.append(str(n))
	# An artist may list each edge once; movement is bidirectional.
	for other in m.cells:
		if cell in other.links and not result.has(str(other.id)): result.append(str(other.id))
	for edge in m.get("connections", []):
		if edge.get("flag", "") != "" and not state.flags.get(edge.flag, false): continue
		if edge.a == cell and not result.has(str(edge.b)): result.append(str(edge.b))
		if edge.b == cell and not result.has(str(edge.a)): result.append(str(edge.a))
	return result

func routes() -> Dictionary:
	var found := {}
	if state.pending != "" or int(state.roll) < 1 or state.completed: return found
	var queue: Array[String] = [str(state.cell)]
	var paths := {str(state.cell): []}
	while not queue.is_empty():
		var cell: String = queue.pop_front()
		var path: Array = paths[cell]
		if path.size() >= int(state.roll): continue
		for next_cell in neighbors(cell):
			if paths.has(next_cell): continue
			var next_path := path.duplicate()
			next_path.append(next_cell)
			paths[next_cell] = next_path
			found[next_cell] = next_path
			queue.append(next_cell)
	return found

func roll_die() -> int:
	if state.pending != "" or int(state.roll) > 0 or state.completed: return 0
	state.roll = rng.randi_range(1, 6)
	state.turns += 1
	return int(state.roll)

func move_to(cell: String) -> Array:
	var available := routes()
	if not available.has(cell): return []
	var path: Array = available[cell]
	state.path = [state.cell] + path
	for step in state.path: state.seen[key_for(step)] = true
	state.cell = cell
	state.event_cell = cell
	state.roll = 0
	state.flags.erase("lit")
	state.pending = "event" if not event_at(cell).is_empty() and not state.visited.has(key_for(cell)) else "quiet"
	return path

func active_scene() -> Dictionary:
	match str(state.pending):
		"intro": return content.get_scene(current_map().intro)
		"event": return event_at(state.event_cell)
		"quiet": return content.get_scene("revisit" if state.visited.has(key_for(state.event_cell)) else "quiet")
		"result": return {"id": "result", "title": "Ника", "text": state.result, "choices": []}
		"exit": return content.get_scene(current_map().outro)
		"ending": return content.get_scene("ending_" + str(state.ending))
		_:
			if str(state.pending).begins_with("beat:"): return content.get_scene(str(state.pending).trim_prefix("beat:"))
	return {}

func finish_landing() -> void:
	if state.event_cell != "": state.visited[key_for(state.event_cell)] = true
	# Scenes run AFTER the landing action. No graph node truncates a roll.
	var progress := int(current_map().index[state.cell].get("progress", 0))
	for id in current_map().beats:
		if not state.beats_done.has(id) and progress >= int(content.scenes[id].not_before):
			state.pending = "beat:" + str(id)
			return
	state.pending = "exit" if state.cell == current_map().exit else ""

func advance() -> void:
	var pending := str(state.pending)
	if pending == "intro":
		log_line(active_scene().text)
		state.pending = ""
	elif pending == "result":
		if str(state.result_for).begins_with("beat:"): state.beats_done[str(state.result_for).trim_prefix("beat:")] = true
		finish_landing()
	elif pending in ["quiet", "event"]: finish_landing()
	elif pending.begins_with("beat:"):
		state.beats_done[pending.trim_prefix("beat:")] = true
		finish_landing()

func can_choose(choice: Dictionary) -> bool:
	for field in ["require", "take"]:
		for item in choice.get(field, {}):
			if int(state.inventory.get(item, 0)) < int(choice[field][item]): return false
	return true

func choice_hint(choice: Dictionary) -> String:
	var hints: Array[String] = []
	for field in ["require", "take", "give"]:
		for item in choice.get(field, {}):
			hints.append("%s: %s ×%d" % [{"require": "Нужно", "take": "Расход", "give": "Получить"}[field], ITEMS.get(item, item), choice[field][item]])
	if choice.has("chance"):
		hints.append("Успех %d%%; иначе — отступление до %d шагов" % [int(float(choice.chance) * 100), choice.get("failure", {}).get("back", 0)])
	return " · ".join(hints)

func _effects(effects: Dictionary) -> void:
	for item in effects.get("take", {}): state.inventory[item] = maxi(0, int(state.inventory.get(item, 0)) - int(effects.take[item]))
	for item in effects.get("give", {}): state.inventory[item] = int(state.inventory.get(item, 0)) + int(effects.give[item])
	state.flags.merge(effects.get("flags", {}), true)
	if int(effects.get("back", 0)) > 0 and state.path.size() > 1:
		state.cell = state.path[maxi(0, state.path.size() - 1 - int(effects.back))]

func resolve(index: int) -> void:
	var scene := active_scene()
	if index < 0 or index >= scene.get("choices", []).size(): return
	var c: Dictionary = scene.choices[index]
	if not can_choose(c): return
	state.result_for = state.pending
	_effects(c)
	var result: String = c.text
	if c.has("chance"):
		var success := rng.randf() < float(c.chance)
		_effects(c.get("success" if success else "failure", {}))
		result += "\n\n" + str(c.get("win_text" if success else "lose_text", ""))
	state.result = result
	state.pending = "result"
	log_line(str(scene.title) + "\n" + str(scene.text) + "\n\n" + str(c.label) + "\n" + result)

func log_line(line: String) -> void:
	state.journal.append(line)

func use_torch() -> bool:
	if not current_map().get("dark", false) or state.flags.get("lit", false) or int(state.inventory.get("torch", 0)) < 1 or state.pending != "": return false
	state.inventory.torch -= 1
	state.flags.lit = true
	return true

func next_map() -> void:
	if int(state.map) >= content.maps.size() - 1: return
	state.map += 1
	state.cell = current_map().start
	state.event_cell = ""
	state.path = []
	state.roll = 0
	state.flags.erase("lit")
	state.pending = "intro"

func finish(ending: String) -> void:
	if not ending in ["restore", "take", "leave"]: return
	state.ending = ending
	state.completed = true
	state.pending = "ending"

func save_game(path: String = SAVE_PATH) -> Error:
	state.rng_state = str(rng.state)
	state.map_id = current_map().id
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path) or content.maps.is_empty(): return false
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not loaded is Dictionary or loaded.get("version") != 2: return false
	for field in state:
		if not loaded.has(field): return false
	var map_index := -1
	for i in range(content.maps.size()):
		if content.maps[i].id == loaded.get("map_id"): map_index = i
	if map_index < 0 or not content.maps[map_index].index.has(loaded.cell): return false
	for key in ["inventory", "visited", "seen", "flags", "beats_done"]:
		if not loaded[key] is Dictionary: return false
	for key in ["turns", "roll", "elapsed"]:
		if not (loaded[key] is float or loaded[key] is int) or float(loaded[key]) < 0: return false
	if int(loaded.roll) > 6 or not loaded.journal is Array or not loaded.path is Array or not loaded.pending is String: return false
	for item in loaded.inventory:
		if not (loaded.inventory[item] is float or loaded.inventory[item] is int) or float(loaded.inventory[item]) < 0: return false
		loaded.inventory[item] = int(loaded.inventory[item])
	if loaded.event_cell != "" and not content.maps[map_index].index.has(loaded.event_cell): return false
	for cell in loaded.path:
		if not content.maps[map_index].index.has(cell): return false
	if not loaded.pending in ["", "intro", "event", "quiet", "result", "exit", "ending"]:
		if not loaded.pending.begins_with("beat:") or not content.scenes.has(loaded.pending.trim_prefix("beat:")): return false
	loaded.map = map_index
	loaded.version = 2
	loaded.roll = int(loaded.roll)
	loaded.turns = int(loaded.turns)
	state = loaded
	rng.state = int(state.get("rng_state", str(rng.state)))
	return true
