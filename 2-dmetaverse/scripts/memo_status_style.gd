extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func card_color(status: String) -> Color:
	match status:
		"important":
			return Color(1.0, 0.96, 0.82)
		"done":
			return Color(0.88, 0.95, 0.89)
		"planned":
			return Color(0.90, 0.95, 1.0)
		_:
			return Color(1, 1, 1)


static func input_color(status: String) -> Color:
	match status:
		"important":
			return Color(1.0, 0.985, 0.90)
		"done":
			return Color(0.94, 0.98, 0.945)
		"planned":
			return Color(0.94, 0.975, 1.0)
		_:
			return Color(1, 1, 1)


static func border_color(status: String) -> Color:
	match status:
		"important":
			return Color(0.90, 0.62, 0.10)
		"done":
			return Color(0.20, 0.56, 0.28)
		"planned":
			return Color(0.18, 0.48, 0.78)
		_:
			return Color(0.64, 0.69, 0.75)


static func compact_style(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	return UiFactory.style(bg, border, radius, border_width, Vector4(8, 2, 8, 2))


static func button_style(status: String, active: bool = false) -> StyleBoxFlat:
	var bg := card_color(status)
	var border := border_color(status)
	if active:
		bg = bg.darkened(0.10)
	return compact_style(bg, border, 6, 2 if active else 1)


static func choice_button(text: String, status: String, font: Font = null) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("status_id", status)
	button.custom_minimum_size = Vector2(70, 34)
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 14)
	var text_color := UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.06, 0.09, 0.13)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", UiFactory.MUTED_TEXT if UiFactory.is_dark_theme() else Color(0.20, 0.24, 0.28, 0.55))
	button.add_theme_stylebox_override("normal", button_style(status, false))
	button.add_theme_stylebox_override("hover", button_style(status, true))
	button.add_theme_stylebox_override("pressed", button_style(status, true))
	button.add_theme_stylebox_override("disabled", button_style(status, false))
	return button
