extends RefCounted

const SURFACE := Color(0.045, 0.055, 0.09, 0.96)
const SURFACE_HOVER := Color(0.095, 0.11, 0.17, 0.98)
const OUTLINE := Color(0.42, 0.57, 0.78, 0.82)
const GLOW := Color(0.53, 0.78, 0.94, 0.38)
const TEXT := Color(0.93, 0.96, 1.0)


static func _is_dark() -> bool:
	return Global.ui_theme != "light"


static func talk_button() -> Button:
	var button := Button.new()
	button.visible = false
	button.custom_minimum_size = Vector2(176, 52)
	button.anchor_left = 0.5
	button.anchor_top = 1.0
	button.anchor_right = 0.5
	button.anchor_bottom = 1.0
	button.offset_left = -88
	button.offset_top = -86
	button.offset_right = 88
	button.offset_bottom = -34
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.38, 0.64)
	normal.border_color = Color(0.04, 0.28, 0.48)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.07, 0.45, 0.74)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	return button


static func quick_button(text: String, offset: Vector2, tooltip: String, font_size := 26) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(56, 56)
	button.anchor_left = 0.0
	button.anchor_top = 1.0
	button.anchor_right = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + 56
	button.offset_bottom = offset.y + 56
	button.add_theme_font_size_override("font_size", font_size)
	apply_quick_button_style(button)
	return button


static func style_memo_button(button: Button) -> void:
	button.text = "✎"
	button.tooltip_text = "メモ"
	button.anchor_left = 0.0
	button.anchor_top = 1.0
	button.anchor_right = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = 76
	button.offset_top = -74
	button.offset_right = 132
	button.offset_bottom = -18
	button.add_theme_font_size_override("font_size", 28)
	apply_quick_button_style(button)


static func style_menu_toggle(button: Button) -> void:
	button.icon = null
	button.text = "☰"
	button.tooltip_text = "メニュー"
	button.anchor_left = 1.0
	button.anchor_top = 0.0
	button.anchor_right = 1.0
	button.anchor_bottom = 0.0
	button.offset_left = -74
	button.offset_top = 18
	button.offset_right = -18
	button.offset_bottom = 74
	button.add_theme_font_size_override("font_size", 27)
	apply_quick_button_style(button)


static func style_return_button(button: Button) -> void:
	button.icon = null
	button.text = "×"
	button.tooltip_text = "メニューを閉じる"
	button.anchor_left = 1.0
	button.anchor_top = 0.0
	button.anchor_right = 1.0
	button.anchor_bottom = 0.0
	button.offset_left = -74
	button.offset_top = 18
	button.offset_right = -18
	button.offset_bottom = 74
	button.add_theme_font_size_override("font_size", 32)
	apply_quick_button_style(button)


static func style_menu_panel(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.06, 0.97) if _is_dark() else Color(0.97, 0.98, 1.0, 0.98)
	style.border_color = Color(0.34, 0.47, 0.69, 0.78) if _is_dark() else Color(0.55, 0.63, 0.73, 0.88)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	style.content_margin_left = 20
	style.content_margin_top = 86
	style.content_margin_right = 20
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)


static func style_menu_item(button: Button) -> void:
	var text_color := TEXT if _is_dark() else Color(0.08, 0.11, 0.15)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", TEXT if _is_dark() else Color(0.03, 0.07, 0.12))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 0.88, 1.0) if _is_dark() else Color(0.03, 0.07, 0.12))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.105, 0.16, 0.72) if _is_dark() else Color(1, 1, 1, 0.92)
	normal.border_color = Color(0.25, 0.32, 0.46, 0.6) if _is_dark() else Color(0.65, 0.71, 0.79, 0.8)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 18
	var hover := normal.duplicate()
	hover.bg_color = Color(0.15, 0.21, 0.3, 0.96) if _is_dark() else Color(0.90, 0.95, 1.0, 1.0)
	hover.border_color = OUTLINE if _is_dark() else Color(0.20, 0.42, 0.72)
	if _is_dark():
		hover.shadow_color = GLOW
		hover.shadow_size = 7
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.07, 0.11, 0.18, 1.0) if _is_dark() else Color(0.84, 0.91, 0.99, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


static func unread_badge() -> Panel:
	var badge := Panel.new()
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.offset_left = 0
	badge.offset_top = 42
	badge.offset_right = 56
	badge.offset_bottom = 56
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.91, 0.32, 0.42)
	badge_style.corner_radius_bottom_left = 6
	badge_style.corner_radius_bottom_right = 6
	badge.add_theme_stylebox_override("panel", badge_style)
	return badge


static func apply_quick_button_style(button: Button) -> void:
	var text_color := TEXT if _is_dark() else Color(0.08, 0.11, 0.15)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", TEXT if _is_dark() else Color(0.03, 0.07, 0.12))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 0.88, 1.0) if _is_dark() else Color(0.03, 0.07, 0.12))
	button.add_theme_color_override("font_focus_color", text_color)
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE if _is_dark() else Color(1, 1, 1, 0.96)
	style.border_color = OUTLINE if _is_dark() else Color(0.28, 0.34, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	if _is_dark():
		style.shadow_color = Color(0, 0, 0, 0.38)
		style.shadow_size = 6
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = SURFACE_HOVER if _is_dark() else Color(0.91, 0.95, 1.0, 1.0)
	hover.border_color = Color(0.64, 0.84, 1.0, 0.95) if _is_dark() else Color(0.20, 0.42, 0.72)
	if _is_dark():
		hover.shadow_color = GLOW
		hover.shadow_size = 10
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.02, 0.03, 0.06, 1.0) if _is_dark() else Color(0.82, 0.89, 0.98, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
