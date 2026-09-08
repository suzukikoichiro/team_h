extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func heading(text: String, bold_font: Font) -> Label:
	return UiFactory.label(text, 26, Color(0.08, 0.11, 0.15), bold_font, false)


static func section_label(text: String, bold_font: Font) -> Label:
	return UiFactory.label(text, 17, Color(0.22, 0.28, 0.35), bold_font, false)


static func button(text: String, size: Vector2) -> Button:
	return UiFactory.filled_button(text, size, Color(0.05, 0.38, 0.64), null, 16)


static func icon_button(text: String, tooltip: String) -> Button:
	var node := UiFactory.filled_button(text, Vector2(44, 40), Color(0.36, 0.43, 0.50), null, 20)
	node.tooltip_text = tooltip
	node.add_theme_font_size_override("font_size", 24)
	return node


static func muted_label(text: String) -> Label:
	return UiFactory.label(text, 14, Color(0.38, 0.42, 0.48))


static func panel_style() -> StyleBoxFlat:
	return UiFactory.style(Color(0.972, 0.977, 0.984), Color(0.70, 0.75, 0.80), 8)


static func card_style() -> StyleBoxFlat:
	return UiFactory.style(Color(1, 1, 1, 0.96), Color(0.74, 0.78, 0.83), 6, 1, Vector4(8, 8, 8, 8))
