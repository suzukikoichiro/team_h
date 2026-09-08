extends RefCounted

const INPUT_LINE_HEIGHT := 32
const INPUT_MIN_LINES := 1
const INPUT_MAX_LINES := 5


static func contact_button(label: String, sub_label: String, room: String, contact: Dictionary, unread_count: int, font: Font) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unread_text := "  未読:%d" % unread_count if unread_count > 0 else ""
	var skin_text := "スキン:%s" % str(contact.get("avatar_key", "skin_01"))
	button.text = "%s%s\n%s / %s" % [label, unread_text, sub_label, skin_text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.76, 0.88, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.93, 0.96, 1.0))
	button.add_theme_stylebox_override("normal", _contact_style(unread_count))
	var hover_style := _contact_style(unread_count)
	hover_style.bg_color = Color(0.14, 0.20, 0.30)
	hover_style.border_color = Color(0.62, 0.82, 1.0)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := _contact_style(unread_count)
	pressed_style.bg_color = Color(0.05, 0.08, 0.14)
	pressed_style.border_color = Color(0.42, 0.57, 0.78)
	button.add_theme_stylebox_override("pressed", pressed_style)
	var focus_style := hover_style.duplicate()
	focus_style.border_color = Color(0.20, 0.42, 0.72)
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus_style)
	button.set_meta("room", room)
	button.set_meta("title", label)
	button.set_meta("contact", contact)
	return button


static func message_row(data: Dictionary, is_me: bool, viewport_width: float, font: Font, fallback_name: String) -> HBoxContainer:
	var message_id: String = str(data.get("id", ""))
	var row := HBoxContainer.new()
	row.name = message_id if message_id != "" else fallback_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if is_me else BoxContainer.ALIGNMENT_BEGIN

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size.x = min(viewport_width * 0.42, 520.0)
	var bubble_box := VBoxContainer.new()
	bubble_box.add_theme_constant_override("separation", 4)

	if not is_me:
		var name_label := Label.new()
		name_label.text = str(data.get("user_name", "？"))
		name_label.add_theme_font_override("font", font)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
		bubble_box.add_child(name_label)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = str(data.get("message", ""))
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 21)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	bubble_box.add_child(label)
	pad.add_child(bubble_box)
	bubble.add_child(pad)
	bubble.add_theme_stylebox_override("panel", _message_style(is_me, label))
	row.add_child(bubble)
	return row


static func unread_divider(name_suffix: int, font: Font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "unread_divider_%s" % name_suffix
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = "ここから未読"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.72, 0.13, 0.13))
	row.add_child(label)
	return row


static func render_messages(message_list: Node, messages: Array, unread_start_id: String, current_user_id: int, viewport_width: float, font: Font) -> void:
	var divider_added := false
	for message in messages:
		if typeof(message) != TYPE_DICTIONARY:
			continue
		var message_id := str(message.get("id", ""))
		if not divider_added and unread_start_id != "" and message_id == unread_start_id:
			message_list.add_child(unread_divider(message_list.get_child_count(), font))
			divider_added = true
		message_list.add_child(message_row(
			message,
			int(message.get("user_id", -1)) == current_user_id,
			viewport_width,
			font,
			"msg_%s" % message_list.get_child_count()
		))


static func add_message_if_new(message_list: Node, data: Dictionary, is_me: bool, viewport_width: float, font: Font) -> bool:
	var message_id := str(data.get("id", ""))
	if message_id != "" and message_list.has_node(message_id):
		return false
	message_list.add_child(message_row(data, is_me, viewport_width, font, "msg_%s" % message_list.get_child_count()))
	return true


static func remove_message(message_list: Node, message_id: String) -> bool:
	for child in message_list.get_children():
		if child.name == message_id:
			child.queue_free()
			return true
	return false


static func apply_input_height(message_input: TextEdit) -> void:
	var lines: int = clamp(message_input.get_line_count(), INPUT_MIN_LINES, INPUT_MAX_LINES)
	message_input.custom_minimum_size.y = max(54, lines * INPUT_LINE_HEIGHT)


static func handle_enter_key(event: InputEvent, message_input: TextEdit, enter_to_send: bool, send_callable: Callable) -> bool:
	if not message_input.has_focus():
		return false
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER):
		return false
	if event.shift_pressed or not enter_to_send:
		message_input.insert_text_at_caret("\n")
		apply_input_height(message_input)
	else:
		send_callable.call()
	return true


static func apply_inbox_empty_state(title_label: Label, status_label: Label, send_button: Button, input_container: Control, message_list: Node, font: Font) -> void:
	if title_label != null:
		title_label.text = "会話一覧"
	if status_label != null:
		status_label.text = "会話の履歴と未読メッセージを確認できます"
	if send_button != null:
		send_button.disabled = true
	if input_container != null:
		input_container.visible = false
	if message_list != null:
		for child in message_list.get_children():
			child.queue_free()
		var guide := Label.new()
		guide.text = "まだ開いている会話はありません\n\nマップ上で相手に近づき、「話しかける」から相手を選んで会話を始めてください。"
		guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
		guide.add_theme_font_override("font", font)
		guide.add_theme_font_size_override("font_size", 21)
		guide.add_theme_color_override("font_color", Color(0.25, 0.32, 0.40))
		message_list.add_child(guide)


static func apply_strong_fonts(controls: Array, font: Font) -> void:
	for control in controls:
		if control is Control:
			control.add_theme_font_override("font", font)


static func _contact_style(unread_count: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.15, 0.23) if unread_count > 0 else Color(0.065, 0.08, 0.13)
	style.border_color = Color(0.46, 0.68, 0.92) if unread_count > 0 else Color(0.29, 0.38, 0.53)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func _message_style(is_me: bool, label: Label) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if is_me:
		style.bg_color = Color(0.13, 0.35, 0.55)
		style.border_color = Color(0.47, 0.75, 0.95)
		style.set_border_width_all(1)
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.08, 0.10, 0.16)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.30, 0.40, 0.56)
		label.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	return style
