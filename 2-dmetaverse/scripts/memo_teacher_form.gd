extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoScheduleWidgets := preload("res://scripts/memo_schedule_widgets.gd")


static func build(statuses: Array, font: Font) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiFactory.style(Color(0.94, 0.965, 0.99), Color(0.62, 0.72, 0.84), 8))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var title := UiFactory.label("担当クラスへメモ配布", 18, Color(0.07, 0.12, 0.18), font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh := UiFactory.filled_button("対象更新", Vector2(82, 30), Color(0.34, 0.48, 0.62), font, 13, 6, true)
	header.add_child(refresh)

	var text_input := _text_input(font)
	box.add_child(text_input)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	var status_option := OptionButton.new()
	status_option.custom_minimum_size = Vector2(116, 32)
	for status in statuses:
		status_option.add_item(status["label"])
	action_row.add_child(status_option)

	var class_send := UiFactory.filled_button("選択クラスへ一斉", Vector2(132, 32), Color(0.05, 0.38, 0.64), font, 13, 6, true)
	action_row.add_child(class_send)

	var student_send := UiFactory.filled_button("選択学生へ個別", Vector2(132, 32), Color(0.18, 0.48, 0.40), font, 13, 6, true)
	action_row.add_child(student_send)

	var schedule_controls := _schedule_row(box, font)
	var target_lists := _targets(box, font)

	return {
		"root": card,
		"refresh": refresh,
		"text_input": text_input,
		"status_option": status_option,
		"class_send": class_send,
		"student_send": student_send,
		"schedule_year": schedule_controls["year"],
		"schedule_month": schedule_controls["month"],
		"schedule_day": schedule_controls["day"],
		"schedule_hour": schedule_controls["hour"],
		"schedule_minute": schedule_controls["minute"],
		"target_class_list": target_lists["classes"],
		"target_student_list": target_lists["students"],
	}


static func _text_input(font: Font) -> TextEdit:
	var input := TextEdit.new()
	input.custom_minimum_size = Vector2(0, 64)
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.placeholder_text = "学生に配るメモ内容"
	input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.03, 0.045, 0.065))
	input.add_theme_color_override("font_placeholder_color", UiFactory.MUTED_TEXT if UiFactory.is_dark_theme() else Color(0.34, 0.39, 0.46))
	input.add_theme_color_override("caret_color", Color(0.66, 0.84, 1.0) if UiFactory.is_dark_theme() else Color(0.05, 0.24, 0.46))
	input.add_theme_stylebox_override("normal", UiFactory.style(Color.WHITE, Color(0.55, 0.62, 0.70), 6))
	UiFactory.keep_text_caret_visible(input)
	return input


static func _schedule_row(parent: VBoxContainer, font: Font) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var title := UiFactory.label("予定日時", 12, Color(0.18, 0.25, 0.32), font)
	title.custom_minimum_size = Vector2(54, 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var year := MemoScheduleWidgets.date_option(74, font)
	row.add_child(year)
	row.add_child(_compact_text_label("年", font))

	var month := MemoScheduleWidgets.date_option(54, font)
	row.add_child(month)
	row.add_child(_compact_text_label("月", font))

	var day := MemoScheduleWidgets.date_option(54, font)
	row.add_child(day)
	row.add_child(_compact_text_label("日", font))

	var hour := MemoScheduleWidgets.time_option(0, 23, 1, 54, font)
	row.add_child(hour)
	row.add_child(_compact_text_label("時", font))

	var minute := MemoScheduleWidgets.time_option(0, 55, 5, 54, font)
	row.add_child(minute)
	row.add_child(_compact_text_label("分", font))

	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute}


static func _targets(parent: VBoxContainer, font: Font) -> Dictionary:
	var targets := HBoxContainer.new()
	targets.add_theme_constant_override("separation", 10)
	parent.add_child(targets)

	var class_box := VBoxContainer.new()
	class_box.custom_minimum_size = Vector2(230, 90)
	class_box.add_theme_constant_override("separation", 3)
	targets.add_child(class_box)
	class_box.add_child(UiFactory.label("担当クラス", 14, Color(0.18, 0.25, 0.32), font))
	var class_list := VBoxContainer.new()
	class_list.add_theme_constant_override("separation", 2)
	class_box.add_child(class_list)

	var student_box := VBoxContainer.new()
	student_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	student_box.add_theme_constant_override("separation", 3)
	targets.add_child(student_box)
	student_box.add_child(UiFactory.label("個別学生", 14, Color(0.18, 0.25, 0.32), font))
	var student_list := VBoxContainer.new()
	student_list.add_theme_constant_override("separation", 2)
	student_box.add_child(student_list)

	return {"classes": class_list, "students": student_list}


static func _compact_text_label(text: String, font: Font) -> Label:
	var label := UiFactory.label(text, 12, Color(0.18, 0.25, 0.32), font)
	label.custom_minimum_size = Vector2(14, 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
