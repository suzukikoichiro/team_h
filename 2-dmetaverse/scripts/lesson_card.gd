extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func build(data: Dictionary, bold_font: Font, selected: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(156, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "クリックしてリンクを開く"
	card.add_theme_stylebox_override("panel", UiFactory.style(Color(1, 1, 1, 0.96), Color(0.74, 0.78, 0.83), 6, 1, Vector4(8, 8, 8, 8)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	box.add_child(UiFactory.label(str(data.get("title", "共有リンク")), 17, Color(0.05, 0.07, 0.10), bold_font))
	box.add_child(_muted_label("共有リンク"))
	box.add_child(_muted_label("投稿者: %s" % str(data.get("teacher_user_name", "教職員"))))
	var description := str(data.get("description", ""))
	if description != "":
		box.add_child(_muted_label(description))
	var copy: Dictionary = data.duplicate()
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			selected.call(copy)
	)
	return card


static func _muted_label(text: String) -> Label:
	var label := UiFactory.label(text, 14, Color(0.38, 0.42, 0.48))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
