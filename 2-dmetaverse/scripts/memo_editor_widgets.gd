extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoStatusStyle := preload("res://scripts/memo_status_style.gd")


static func memo_input(font: Font) -> TextEdit:
	var input := UiFactory.text_edit(
		"思いついたこと、やること、あとで確認したいこと",
		Vector2(0, 300),
		font,
		19,
		Color(0.03, 0.045, 0.065),
		Color(0.34, 0.39, 0.46),
		Color(0.05, 0.24, 0.46),
		UiFactory.style(Color.WHITE, Color(0.55, 0.62, 0.70), 6),
		UiFactory.style(Color.WHITE, Color(0.20, 0.42, 0.72), 6, 2),
		TextEdit.LINE_WRAPPING_BOUNDARY
	)
	UiFactory.keep_text_caret_visible(input)
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return input


static func status_label_row(statuses: Array, font: Font, selected: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	row.add_child(status_row)
	for status in statuses:
		var status_id := str(status["id"])
		var status_button := MemoStatusStyle.choice_button(str(status["label"]), status_id, font)
		status_button.pressed.connect(func(id = status_id): selected.call(id))
		status_row.add_child(status_button)

	return {
		"root": row,
		"status_row": status_row,
	}


static func editor_layout() -> Dictionary:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var editor_column := VBoxContainer.new()
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 8)
	row.add_child(editor_column)

	var schedule_section := VBoxContainer.new()
	schedule_section.visible = false
	# 予定入力時のカレンダーを十分な大きさで表示できる幅を確保する。
	schedule_section.custom_minimum_size = Vector2(420, 0)
	schedule_section.size_flags_horizontal = Control.SIZE_SHRINK_END
	schedule_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	schedule_section.add_theme_constant_override("separation", 6)
	row.add_child(schedule_section)

	return {
		"root": row,
		"editor_column": editor_column,
		"schedule_section": schedule_section,
	}


static func primary_actions(font: Font, save_callable: Callable, delete_callable: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var save_button := UiFactory.filled_button("メモする", Vector2(150, 44), Color(0.05, 0.38, 0.64), font, 18, 6, true)
	save_button.pressed.connect(save_callable)
	row.add_child(save_button)

	var delete_button := UiFactory.filled_button("削除", Vector2(76, 36), Color(0.64, 0.18, 0.18), font, 15, 6, true)
	delete_button.disabled = true
	delete_button.pressed.connect(delete_callable)
	row.add_child(delete_button)

	return {
		"root": row,
		"save_button": save_button,
		"delete_button": delete_button,
	}


static func mode_button(text: String, color: Color, font: Font) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(74, 30)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _mode_style(color, color.darkened(0.08), 6))
	button.add_theme_stylebox_override("hover", _mode_style(color.lightened(0.10), color.lightened(0.02), 6))
	button.add_theme_stylebox_override("pressed", _mode_style(color.darkened(0.10), color.darkened(0.14), 6))
	button.add_theme_stylebox_override("disabled", _mode_style(color.lightened(0.12), color.lightened(0.04), 6))
	return button


static func _mode_style(bg: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	return UiFactory.style(bg, border, radius, border_width, Vector4(8, 4, 8, 4))
