extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoSchedule := preload("res://scripts/memo_schedule.gd")


static func event_card(event: Dictionary, font: Font, delete_callback: Callable) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var source := str(event.get("source", "personal"))
	var border := Color(0.18, 0.48, 0.78) if source == "personal" else Color(0.76, 0.48, 0.16)
	card.add_theme_stylebox_override("panel", UiFactory.style(Color(1, 1, 1), border, 7, 2))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var meta := UiFactory.label("%s  %s" % [event_time(event), str(event.get("source_label", "自分"))], 14, border, font)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(meta)
	var delete_button := UiFactory.filled_button("削除", Vector2(58, 28), Color(0.64, 0.18, 0.18), font, 12)
	delete_button.pressed.connect(func(): delete_callback.call(int(event.get("id", 0))))
	header.add_child(delete_button)
	box.add_child(UiFactory.label(str(event.get("text", "")), 18, Color(0.06, 0.09, 0.13), font))
	return card


static func event_time(event: Dictionary) -> String:
	var value := MemoSchedule.jst_iso_string(str(event.get("scheduled_at", "")))
	return value.substr(11, 5) if value.length() >= 16 else "--:--"


static func day_button(text: String, active: bool, has_events: bool, font: Font) -> Button:
	var bg := Color(0.16, 0.43, 0.72) if active else Color(1, 1, 1)
	if has_events and not active:
		bg = Color(0.91, 0.96, 1.0)
	var font_color := Color.WHITE if active else (UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.07, 0.11, 0.16))
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(54, 50)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_stylebox_override("normal", UiFactory.style(bg, Color(0.50, 0.62, 0.76), 6))
	button.add_theme_stylebox_override("hover", UiFactory.style(bg.lightened(0.08), Color(0.22, 0.44, 0.72), 6))
	button.add_theme_stylebox_override("pressed", UiFactory.style(bg.darkened(0.08), Color(0.22, 0.44, 0.72), 6))
	return button


static func time_option(min_value: int, max_value: int, step_value: int, width: int, font: Font) -> LimitedOptionButton:
	var option := LimitedOptionButton.new()
	option.custom_minimum_size = Vector2(width, 34)
	option.configure_popup(width, 34)
	option.add_theme_font_override("font", font)
	option.add_theme_font_size_override("font_size", 14)
	var font_color := UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.06, 0.09, 0.13)
	option.add_theme_color_override("font_color", font_color)
	option.add_theme_color_override("font_hover_color", font_color)
	option.add_theme_color_override("font_pressed_color", font_color)
	option.add_theme_color_override("font_hover_pressed_color", font_color)
	option.add_theme_color_override("font_focus_color", font_color)
	option.add_theme_stylebox_override("normal", UiFactory.style(Color.WHITE, Color(0.55, 0.62, 0.70), 5))
	option.add_theme_stylebox_override("hover", UiFactory.style(Color(0.94, 0.97, 1.0), Color(0.35, 0.52, 0.72), 5))
	option.add_theme_stylebox_override("pressed", UiFactory.style(Color(0.90, 0.95, 1.0), Color(0.25, 0.45, 0.70), 5))
	for value in range(min_value, max_value + 1, step_value):
		option.add_item("%02d" % value, value)
	return option
