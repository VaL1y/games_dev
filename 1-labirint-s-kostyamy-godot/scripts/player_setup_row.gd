class_name PlayerSetupRow
extends HBoxContainer

@onready var player_label: Label = $PlayerLabel
@onready var name_input: LineEdit = $NameInput
@onready var skin_select: OptionButton = $SkinSelect

var player_index := 0


func _ready() -> void:
	for skin in GameSession.SKINS:
		skin_select.add_item(skin.name)


func configure(index: int) -> void:
	player_index = index
	player_label.text = "Игрок %d" % (index + 1)
	name_input.text = "Игрок %d" % (index + 1)
	skin_select.select(index % GameSession.SKINS.size())


func get_player_config() -> Dictionary:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Игрок %d" % (player_index + 1)

	return {
		"name": player_name,
		"skin_id": GameSession.SKINS[skin_select.selected].id,
	}
