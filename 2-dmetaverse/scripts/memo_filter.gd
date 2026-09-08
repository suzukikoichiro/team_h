extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoStatusStyle := preload("res://scripts/memo_status_style.gd")


static func toolbar(statuses: Array, font: Font, filter_selected: Callable, relabel_selected: Callable, edit_selected: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var filter_label := UiFactory.label("表示", 17, Color(0.20, 0.27, 0.34), font)
	filter_label.custom_minimum_size = Vector2(46, 36)
	filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(filter_label)

	var filter_option := OptionButton.new()
	filter_option.custom_minimum_size = Vector2(132, 36)
	filter_option.add_item("未完了")
	filter_option.add_item("すべて")
	for status in statuses:
		filter_option.add_item(status["label"])
	filter_option.item_selected.connect(filter_selected)
	row.add_child(filter_option)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var relabel_row := HBoxContainer.new()
	relabel_row.add_theme_constant_override("separation", 6)
	row.add_child(relabel_row)
	for status in statuses:
		var status_id := str(status["id"])
		var relabel := MemoStatusStyle.choice_button(str(status["label"]), status_id, font)
		relabel.disabled = true
		relabel.pressed.connect(func(id = status_id): relabel_selected.call(id))
		relabel_row.add_child(relabel)

	var edit_button := UiFactory.filled_button("編集", Vector2(70, 34), Color(0.38, 0.48, 0.58), font, 14, 6, true)
	edit_button.disabled = true
	edit_button.pressed.connect(edit_selected)
	row.add_child(edit_button)

	var detail_label := UiFactory.label("", 15, Color(0.32, 0.38, 0.45), font)
	detail_label.visible = false

	return {
		"root": row,
		"filter_option": filter_option,
		"relabel_row": relabel_row,
		"edit_button": edit_button,
		"detail_label": detail_label,
	}


static func selected_filter(index: int, statuses: Array) -> String:
	if index == 0:
		return "active"
	if index == 1:
		return "all"
	return str(statuses[index - 2]["id"])


static func request_status(current_filter: String) -> String:
	return "all" if current_filter == "active" else current_filter


static func visible_memos(memos: Array, current_filter: String) -> Array:
	var results: Array = []
	for memo in memos:
		if typeof(memo) != TYPE_DICTIONARY:
			continue
		var memo_status := str(memo.get("status", "none"))
		if current_filter == "active" and memo_status == "done":
			continue
		if current_filter != "active" and current_filter != "all" and memo_status != current_filter:
			continue
		results.append(memo)
	return results


static func apply_filter_style(filter_option: OptionButton, current_filter: String, font: Font) -> void:
	if filter_option == null:
		return
	var status := current_filter
	if status == "all" or status == "active":
		status = "none"
	filter_option.add_theme_font_override("font", font)
	filter_option.add_theme_font_size_override("font_size", 14)
	filter_option.add_theme_color_override("font_color", UiFactory.TEXT if UiFactory.is_dark_theme() else Color(0.06, 0.09, 0.13))
	filter_option.add_theme_stylebox_override("normal", MemoStatusStyle.button_style(status, current_filter != "all" and current_filter != "active"))
	filter_option.add_theme_stylebox_override("hover", MemoStatusStyle.button_style(status, true))
	filter_option.add_theme_stylebox_override("pressed", MemoStatusStyle.button_style(status, true))
