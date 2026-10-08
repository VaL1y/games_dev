extends PanelContainer
class_name PlayerCard

@onready var avatar_label: Label = $Content/Avatar
@onready var name_label: Label = $Content/PlayerName
@onready var area_label: Label = $Content/Area


func display(player: PlayerData, territory_area: int, active: bool) -> void:
	avatar_label.text = player.avatar
	avatar_label.add_theme_color_override("font_color", player.territory_color)
	name_label.text = player.display_name
	name_label.add_theme_color_override("font_color", player.territory_color)
	area_label.text = "Территория: %d клеток" % territory_area
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = player.territory_color if active else Color(0.78, 0.75, 0.83)
	style.set_border_width_all(4 if active else 1)
	add_theme_stylebox_override("panel", style)
