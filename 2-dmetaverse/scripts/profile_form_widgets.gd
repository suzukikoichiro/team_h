extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const INPUT_CARET_COLOR := Color(0.05, 0.24, 0.46)


static func field(label_text: String, field_control: Control, bold_font: Font) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UiFactory.label(label_text, 16, Color(0.22, 0.28, 0.35), bold_font))
	box.add_child(field_control)
	return box


static func line_edit(placeholder: String, bold_font: Font) -> LineEdit:
	return UiFactory.line_edit(
		placeholder,
		Vector2(0, 38),
		bold_font,
		16,
		Color(0.03, 0.045, 0.065),
		Color(0.34, 0.39, 0.46),
		INPUT_CARET_COLOR,
		UiFactory.style(Color(1, 1, 1), Color(0.55, 0.62, 0.70), 6),
		UiFactory.style(Color(1, 1, 1), Color(0.20, 0.42, 0.72), 6, 2)
	)


static func text_edit(placeholder: String, bold_font: Font) -> TextEdit:
	return UiFactory.text_edit(
		placeholder,
		Vector2(0, 62),
		bold_font,
		16,
		Color(0.03, 0.045, 0.065),
		Color(0.34, 0.39, 0.46),
		INPUT_CARET_COLOR,
		UiFactory.style(Color(1, 1, 1), Color(0.55, 0.62, 0.70), 6),
		UiFactory.style(Color(1, 1, 1), Color(0.20, 0.42, 0.72), 6, 2),
		TextEdit.LINE_WRAPPING_BOUNDARY
	)


static func primary_button(text: String, min_size: Vector2, bold_font: Font) -> Button:
	return UiFactory.filled_button(text, min_size, Color(0.05, 0.38, 0.64), bold_font, 16)


static func search_launcher_button(bold_font: Font) -> Button:
	var button := Button.new()
	button.text = "プロフィールを検索"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", bold_font)
	button.add_theme_font_size_override("font_size", 16)
	var normal_text := UiFactory.MUTED_TEXT if UiFactory.is_dark_theme() else Color(0.34, 0.39, 0.46)
	var active_text := UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.20, 0.24, 0.30)
	button.add_theme_color_override("font_color", normal_text)
	button.add_theme_color_override("font_hover_color", active_text)
	button.add_theme_color_override("font_pressed_color", active_text)
	button.add_theme_color_override("font_focus_color", active_text)
	button.add_theme_stylebox_override("normal", UiFactory.style(Color(1, 1, 1), Color(0.55, 0.62, 0.70), 6))
	button.add_theme_stylebox_override("hover", UiFactory.style(Color(0.96, 0.98, 1.0), Color(0.20, 0.42, 0.72), 6, 2))
	button.add_theme_stylebox_override("pressed", UiFactory.style(Color(0.92, 0.95, 0.99), Color(0.20, 0.42, 0.72), 6, 2))
	return button
