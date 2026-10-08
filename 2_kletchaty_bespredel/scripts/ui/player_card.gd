extends PanelContainer
class_name PlayerCard

@onready var avatar_texture: TextureRect = $Content/Avatar
@onready var name_label: Label = $Content/PlayerName
@onready var area_label: Label = $Content/Area

var _panel_style: StyleBoxFlat
var _last_avatar: Texture2D
var _last_name := ""
var _last_color := Color.TRANSPARENT
var _last_area := -1
var _last_active := false


func _ready() -> void:
	_panel_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _panel_style)


func display(player: PlayerData, territory_area: int, active: bool) -> void:
	if _last_avatar != player.avatar:
		avatar_texture.texture = player.avatar
		_last_avatar = player.avatar
	if _last_name != player.display_name:
		name_label.text = player.display_name
		_last_name = player.display_name
	var color_changed := _last_color != player.territory_color
	if color_changed:
		name_label.add_theme_color_override("font_color", player.territory_color)
		_last_color = player.territory_color
	if _last_area != territory_area:
		area_label.text = "Территория: %d клеток" % territory_area
		_last_area = territory_area
	if _last_active != active or color_changed:
		_panel_style.border_color = player.territory_color if active else Color(0.78, 0.75, 0.83)
		_panel_style.set_border_width_all(4 if active else 1)
		_last_active = active
