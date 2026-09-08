class_name PlayerHud
extends Control

@onready var accent: ColorRect = $Accent
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var active_label: Label = $MarginContainer/VBoxContainer/ActiveLabel


func show_player(player: PlayerState, total_cells: int, is_active: bool) -> void:
	accent.color = player.color
	name_label.text = player.name
	status_label.text = "Клетка %d / %d" % [player.route_index + 1, total_cells]
	active_label.text = "▶ ВАШ ХОД" if is_active else ""
	modulate.a = 1.0 if is_active else 0.72
