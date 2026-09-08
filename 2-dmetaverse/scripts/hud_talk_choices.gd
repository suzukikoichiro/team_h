extends RefCounted


static func apply_button_state(button: Button, contacts: Array, is_logged_in: bool, is_user_operating_ui: bool) -> Dictionary:
	var primary_contact: Dictionary = contacts[0] if not contacts.is_empty() and typeof(contacts[0]) == TYPE_DICTIONARY else {}
	if button == null:
		return {"primary_contact": primary_contact, "can_show": false}

	var can_show := is_logged_in and not contacts.is_empty() and not is_user_operating_ui
	button.visible = can_show
	if can_show:
		button.text = "話しかける" if contacts.size() == 1 else "話しかける (%d)" % contacts.size()
		button.tooltip_text = "近くの相手を選ぶ" if contacts.size() > 1 else "%s に話しかける" % str(primary_contact.get("user_name", "相手"))
		button.move_to_front()
	return {"primary_contact": primary_contact, "can_show": can_show}


static func build(contacts: Array, selected: Callable, closed: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -190
	panel.offset_top = -330
	panel.offset_right = 190
	panel.offset_bottom = -96

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.98, 0.99, 0.96)
	style.border_color = Color(0.48, 0.56, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)

	var title := Label.new()
	title.text = "話しかける相手を選ぶ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	list.add_child(title)

	var guide := Label.new()
	guide.text = "近くにいる相手を選ぶと、その人との会話を開きます"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 14)
	list.add_child(guide)

	for contact in contacts:
		if typeof(contact) == TYPE_DICTIONARY:
			list.add_child(_contact_button(contact, selected))

	var cancel := Button.new()
	cancel.text = "キャンセル"
	cancel.custom_minimum_size = Vector2(360, 38)
	cancel.pressed.connect(closed)
	list.add_child(cancel)
	return panel


static func _contact_button(contact: Dictionary, selected: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(360, 48)
	button.text = "%s\n%s ・ 約%dm" % [
		str(contact.get("user_name", "ユーザー")),
		str(contact.get("role_label", "ユーザー")),
		int(round(float(contact.get("distance", 0.0)))),
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	var contact_copy: Dictionary = contact.duplicate()
	button.pressed.connect(func():
		selected.call(contact_copy)
	)
	return button
