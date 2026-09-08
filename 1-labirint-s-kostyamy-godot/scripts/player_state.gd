class_name PlayerState
extends RefCounted

var id: int
var name: String
var color: Color
var route_index := 0
var finished := false


func _init(player_id: int, player_name: String, player_color: Color) -> void:
	id = player_id
	name = player_name
	color = player_color
