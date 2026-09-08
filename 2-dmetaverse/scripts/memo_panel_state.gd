extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoText := preload("res://scripts/memo_text.gd")
const MemoStatusStyle := preload("res://scripts/memo_status_style.gd")


static func apply_memo_view(view: String, personal_section: Control, teacher_section: Control, self_button: Button, distribute_button: Button) -> void:
	if personal_section != null:
		personal_section.visible = view == "self"
	if teacher_section != null:
		teacher_section.visible = view == "distribute"
	if self_button != null:
		self_button.disabled = view == "self"
	if distribute_button != null:
		distribute_button.disabled = view == "distribute"


static func apply_personal_screen(screen: String, editing_memo_id: int, write_section: Control, list_section: Control, write_button: Button, list_button: Button, memo_input: TextEdit, focus_input: bool) -> void:
	if write_section != null:
		write_section.visible = screen == "write"
	if list_section != null:
		list_section.visible = screen == "list"
	if write_button != null:
		write_button.disabled = screen == "write" and editing_memo_id <= 0
	if list_button != null:
		list_button.disabled = screen == "list"
	if focus_input and screen == "write" and memo_input != null:
		memo_input.grab_focus()


static func apply_selection_controls(selected_memo: Dictionary, relabel_row: HBoxContainer, delete_button: Button, edit_button: Button, selected_detail_label: Label, list_detail_label: Label, save_button: Button) -> void:
	var has_selection := not selected_memo.is_empty()
	if relabel_row != null:
		for child in relabel_row.get_children():
			if child is Button:
				child.disabled = not has_selection
	if delete_button != null:
		delete_button.disabled = not has_selection
	if edit_button != null:
		edit_button.disabled = not has_selection
	_apply_selected_detail(selected_detail_label, selected_memo, has_selection)
	_apply_list_detail(list_detail_label, selected_memo, has_selection)
	if save_button != null and not has_selection:
		save_button.text = "メモする"


static func apply_new_editor(memo_input: TextEdit, save_button: Button, status_label: Label) -> void:
	if memo_input != null:
		memo_input.text = ""
	if save_button != null:
		save_button.text = "メモする"
	if status_label != null:
		status_label.text = ""


static func apply_edit_editor(memo: Dictionary, memo_input: TextEdit, save_button: Button, status_label: Label) -> Dictionary:
	if memo_input != null:
		memo_input.text = str(memo.get("text", ""))
	if save_button != null:
		save_button.text = "更新"
	if status_label != null:
		status_label.text = ""
	return {
		"id": int(memo.get("id", 0)),
		"status": str(memo.get("status", "none")),
		"scheduled_at": str(memo.get("scheduled_at", "")),
	}


static func clear_editor_after_selection(memo_input: TextEdit, had_selection: bool) -> void:
	if had_selection and memo_input != null:
		memo_input.text = ""


static func clear_selection_state(owner: Object, memo_input: TextEdit) -> bool:
	var had_selection := int(owner.get("selected_memo_id")) > 0
	owner.set("selected_memo_id", 0)
	owner.set("selected_memo", {})
	owner.set("editing_memo_id", 0)
	clear_editor_after_selection(memo_input, had_selection)
	return had_selection


static func normalized_status(statuses: Array, status_id: String) -> String:
	for status in statuses:
		if str(status["id"]) == status_id:
			return status_id
	return "none"


static func apply_status_buttons(status_button_row: HBoxContainer, current_status: String) -> void:
	if status_button_row == null:
		return
	for child in status_button_row.get_children():
		if child is Button:
			var id := str(child.get_meta("status_id", "none"))
			child.add_theme_stylebox_override("normal", MemoStatusStyle.button_style(id, id == current_status))
			child.add_theme_stylebox_override("hover", MemoStatusStyle.button_style(id, true))
			child.add_theme_stylebox_override("pressed", MemoStatusStyle.button_style(id, true))


static func apply_memo_input_style(memo_input: TextEdit, current_status: String) -> void:
	if memo_input == null:
		return
	var bg := MemoStatusStyle.input_color(current_status)
	var border := MemoStatusStyle.border_color(current_status)
	memo_input.add_theme_stylebox_override("normal", UiFactory.style(bg, border.lightened(0.22), 6))
	memo_input.add_theme_stylebox_override("focus", UiFactory.style(bg, border, 6, 2))


static func apply_schedule_visibility(schedule_section: Control, current_status: String, selected_schedule_date: String) -> bool:
	if schedule_section == null:
		return false
	schedule_section.visible = current_status == "planned"
	return current_status == "planned" and selected_schedule_date == ""


static func apply_status_state(
	statuses: Array,
	status_id: String,
	status_button_row: HBoxContainer,
	memo_input: TextEdit,
	schedule_section: Control,
	selected_schedule_date: String
) -> Dictionary:
	var status := normalized_status(statuses, status_id)
	apply_status_buttons(status_button_row, status)
	apply_memo_input_style(memo_input, status)
	return {
		"status": status,
		"needs_default_schedule": apply_schedule_visibility(schedule_section, status, selected_schedule_date),
	}


static func _apply_selected_detail(label: Label, selected_memo: Dictionary, has_selection: bool) -> void:
	if label == null:
		return
	label.visible = has_selection
	if has_selection:
		label.text = "最終編集: %s" % MemoText.format_time(str(selected_memo.get("updated_at", "")))
	else:
		label.text = ""


static func _apply_list_detail(label: Label, selected_memo: Dictionary, has_selection: bool) -> void:
	if label == null:
		return
	if has_selection:
		label.visible = true
		var updated := MemoText.format_time(str(selected_memo.get("updated_at", "")))
		label.text = "%s\n最終編集: %s" % [MemoText.preview(str(selected_memo.get("text", ""))), updated]
	else:
		label.text = ""
		label.visible = false
