extends RefCounted


static func build(mood_selected: Callable, permission_requested: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310
	panel.offset_top = -210
	panel.offset_right = 310
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.97, 0.98, 0.99), Color(0.42, 0.50, 0.58), 10))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label("今日の状態を教えてね", 28, Color(0.05, 0.08, 0.12)))
	box.add_child(_label("入室前に、周りから話しかけられても大丈夫か確認します。", 15, Color(0.28, 0.34, 0.40)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_mood_button("元気", "fine", "all", Color(0.20, 0.55, 0.34), mood_selected, permission_requested))
	row.add_child(_mood_button("疲れている", "tired", "", Color(0.42, 0.50, 0.62), mood_selected, permission_requested))
	row.add_child(_mood_button("不安", "anxious", "", Color(0.62, 0.40, 0.70), mood_selected, permission_requested))
	return panel


static func show_permission_choices(panel: PanelContainer, selected_mood: String, mood_selected: Callable) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var box := panel.get_child(0) as VBoxContainer
	if box == null:
		return
	var remove_list := []
	for i in range(2, box.get_child_count()):
		remove_list.append(box.get_child(i))
	for child in remove_list:
		box.remove_child(child)
		child.queue_free()
	box.add_child(_label("お友達、先生から話しかけられても大丈夫かな？", 21, Color(0.05, 0.08, 0.12)))
	box.add_child(_permission_button("話しかけられても大丈夫", selected_mood, "all", Color(0.20, 0.55, 0.34), mood_selected))
	box.add_child(_permission_button("友達になら話しかけられても大丈夫", selected_mood, "students", Color(0.16, 0.42, 0.66), mood_selected))
	box.add_child(_permission_button("先生になら話しかけられても大丈夫", selected_mood, "teachers", Color(0.50, 0.38, 0.68), mood_selected))
	box.add_child(_permission_button("今日は一人でいたい", selected_mood, "none", Color(0.34, 0.38, 0.44), mood_selected))


static func _mood_button(
	text: String,
	mood: String,
	permission: String,
	color: Color,
	mood_selected: Callable,
	permission_requested: Callable
) -> Button:
	var button := _choice_button(_mood_icon(mood) + "  " + text, color)
	button.pressed.connect(func():
		if permission == "":
			permission_requested.call(mood)
		else:
			mood_selected.call(mood, permission)
	)
	return button


static func _permission_button(text: String, mood: String, permission: String, color: Color, mood_selected: Callable) -> Button:
	var button := _choice_button(text, color)
	button.pressed.connect(func(): mood_selected.call(mood, permission))
	return button


static func _choice_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(color, color.darkened(0.08), 7))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.10), color, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.10), color.darkened(0.16), 7))
	return button


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func _mood_icon(mood: String) -> String:
	match mood:
		"tired":
			return "◑"
		"anxious":
			return "△"
		_:
			return "○"


static func _panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(14)
	return style
