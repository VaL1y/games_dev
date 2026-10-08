extends RefCounted
class_name UITheme

const INK := Color(0.27, 0.18, 0.40)


static func style_button(button: Button) -> void:
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {
			"normal": Color(0.72, 0.87, 1.0),
			"hover": Color(1.0, 0.76, 0.89),
			"pressed": Color(0.80, 0.66, 0.89),
			"disabled": Color(0.86, 0.85, 0.89)
		}[state]
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)


static func style_input(control: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.border_color = Color(0.72, 0.65, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(10)
	control.add_theme_stylebox_override("normal", style)
	control.add_theme_color_override("font_color", INK)
