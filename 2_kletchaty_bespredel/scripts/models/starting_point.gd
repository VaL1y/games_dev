extends RefCounted
class_name StartingPoint

var player_index: int
var cell: Vector2i
var visible_turns_remaining: int = 2


func _init(owner_index: int, start_cell: Vector2i) -> void:
	player_index = owner_index
	cell = start_cell


func complete_turn() -> void:
	visible_turns_remaining = maxi(0, visible_turns_remaining - 1)
