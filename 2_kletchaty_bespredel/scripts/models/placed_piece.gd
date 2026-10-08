extends RefCounted
class_name PlacedPiece

var origin: Vector2i
var extent: Vector2i
var player_index: int


func _init(piece_origin: Vector2i, piece_extent: Vector2i, owner_index: int) -> void:
	origin = piece_origin
	extent = piece_extent
	player_index = owner_index
