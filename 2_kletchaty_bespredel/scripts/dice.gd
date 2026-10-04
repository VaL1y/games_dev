extends RefCounted
class_name DiceRoller

var sides: int


func _init(face_count := 6) -> void:
	sides = maxi(2, face_count)


func roll_rectangle() -> Vector2i:
	return Vector2i(randi_range(1, sides), randi_range(1, sides))
