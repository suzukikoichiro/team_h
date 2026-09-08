extends RefCounted


static func build(
	parent: VBoxContainer,
	owner: Node,
	global_state: Node,
	scope_selected: Callable,
	clear_requested: Callable,
	clear_confirmed: Callable
) -> Dictionary:
	var controls := {}
	_add(parent, _title("表示設定"))
	var theme_option := OptionButton.new()
	theme_option.custom_minimum_size = Vector2(150, 34)
	theme_option.add_item("ライトモード", 0)
	theme_option.add_item("ダークモード", 1)
	theme_option.select(0 if str(global_state.get("ui_theme")) == "light" else 1)
	theme_option.item_selected.connect(func(index: int): global_state.call("set_ui_theme", "light" if index == 0 else "dark"))
	_add(parent, _row("画面テーマ :", theme_option))
	controls["theme_option"] = theme_option

	var text_size_option := OptionButton.new()
	text_size_option.custom_minimum_size = Vector2(150, 34)
	text_size_option.add_item("標準", 0)
	text_size_option.add_item("大きい", 1)
	text_size_option.add_item("とても大きい", 2)
	text_size_option.select(int(global_state.get("ui_text_scale_level")))
	text_size_option.item_selected.connect(func(index: int): global_state.call("set_ui_text_scale_level", index))
	_add(parent, _row("文字の大きさ :", text_size_option))
	controls["text_size_option"] = text_size_option

	_add(parent, _title("チャット設定"))

	var enter_check := CheckBox.new()
	enter_check.text = "Enterで送信する"
	enter_check.button_pressed = bool(global_state.get("chat_enter_to_send"))
	enter_check.toggled.connect(func(enabled: bool): global_state.set("chat_enter_to_send", enabled))
	_add(parent, _row("Enterキー :", enter_check))
	controls["enter_send_check"] = enter_check

	var nearby_check := CheckBox.new()
	nearby_check.text = "周辺の人から話しかけられない"
	nearby_check.button_pressed = not bool(global_state.get("allow_nearby_chat"))
	nearby_check.toggled.connect(func(blocked: bool):
		global_state.call("set_daily_mood", global_state.get("mood_status"), "none" if blocked else "all")
	)
	_add(parent, _row("周辺チャット :", nearby_check))
	controls["nearby_chat_block_check"] = nearby_check

	var limit_option := OptionButton.new()
	limit_option.custom_minimum_size = Vector2(150, 34)
	for value in [50, 100, 200]:
		limit_option.add_item("%d件" % value, value)
		if value == int(global_state.get("chat_history_limit")):
			limit_option.select(limit_option.item_count - 1)
	limit_option.item_selected.connect(func(index: int):
		global_state.set("chat_history_limit", limit_option.get_item_id(index))
	)
	_add(parent, _row("履歴取得件数 :", limit_option))
	controls["chat_limit_option"] = limit_option

	_add(parent, _title("チャット履歴削除"))

	var clear_row := HBoxContainer.new()
	clear_row.add_theme_constant_override("separation", 10)

	var scope_option := OptionButton.new()
	scope_option.custom_minimum_size = Vector2(130, 36)
	scope_option.add_item("個人", 1)
	scope_option.add_item("すべて", 2)
	scope_option.item_selected.connect(scope_selected)
	clear_row.add_child(scope_option)
	controls["chat_scope_option"] = scope_option

	var target_input := LineEdit.new()
	target_input.custom_minimum_size = Vector2(180, 36)
	target_input.placeholder_text = "相手のユーザーID"
	target_input.add_theme_color_override("caret_color", Color(0.05, 0.24, 0.46))
	clear_row.add_child(target_input)
	controls["chat_target_input"] = target_input

	var clear_button := Button.new()
	clear_button.custom_minimum_size = Vector2(180, 36)
	clear_button.text = "履歴を削除"
	clear_button.pressed.connect(clear_requested)
	clear_row.add_child(clear_button)
	_add(parent, clear_row)

	var status_label := Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(parent, status_label)
	controls["status_label"] = status_label

	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "チャット履歴削除"
	confirm_dialog.dialog_text = "あなたの表示から、選択したチャットの過去履歴を削除します。相手側の履歴は削除されません。"
	confirm_dialog.confirmed.connect(clear_confirmed)
	owner.add_child(confirm_dialog)
	controls["confirm_dialog"] = confirm_dialog

	return controls


static func selected_chat_room(scope_option: OptionButton, target_input: LineEdit, global_state: Node) -> String:
	var school_id := int(global_state.get("school_id"))
	if school_id <= 0:
		return ""
	var selected_id := scope_option.get_item_id(scope_option.selected)
	if selected_id == 2:
		return "__all__"
	var other_id := int(target_input.text.strip_edges())
	var self_id := int(global_state.get("user_id"))
	if other_id <= 0 or self_id <= 0 or other_id == self_id:
		return ""
	var ids := [self_id, other_id]
	ids.sort()
	return "school-%s-dm-%s-%s" % [school_id, ids[0], ids[1]]


static func _add(parent: VBoxContainer, child: Control) -> void:
	parent.add_child(child)


static func _title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.56, 0.76, 1.0))
	return title


static func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_label(label_text))
	row.add_child(control)
	return row


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = "　" + text
	label.custom_minimum_size = Vector2(130, 0)
	return label
