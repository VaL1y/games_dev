extends Node

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const SKINS: Array[Dictionary] = [
	{"id": "azure", "name": "Лазурный", "color": Color("3d8bfd")},
	{"id": "crimson", "name": "Алый", "color": Color("ef5350")},
	{"id": "emerald", "name": "Изумрудный", "color": Color("55c76a")},
	{"id": "violet", "name": "Фиолетовый", "color": Color("b56bea")},
]

var arcade_players: Array[Dictionary] = []
var story_continue := false


func start_arcade(players: Array[Dictionary]) -> void:
	arcade_players = players.duplicate(true)


func get_arcade_players() -> Array[Dictionary]:
	if arcade_players.is_empty():
		return [{"name": "Игрок 1", "skin_id": "azure"}]
	return arcade_players.duplicate(true)


func get_skin(skin_id: String) -> Dictionary:
	for skin in SKINS:
		if skin.id == skin_id:
			return skin
	return SKINS[0]


func clear_arcade() -> void:
	arcade_players.clear()
