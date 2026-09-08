extends RefCounted

const MENU_OPEN_X := 880
const MENU_CLOSED_X := 1280


static func apply_logged_in(is_logged_in: bool, chat_button: Button, calendar_button: Button, menu_button: Button, memo_button: Button, chat_quick_button: Button) -> void:
	if chat_button != null:
		chat_button.disabled = not is_logged_in
	if calendar_button != null:
		calendar_button.disabled = not is_logged_in
	if menu_button != null:
		menu_button.visible = is_logged_in
	if memo_button != null:
		memo_button.visible = is_logged_in
	if chat_quick_button != null:
		chat_quick_button.visible = is_logged_in


static func apply_menu_open(menu_panel: Control, return_button: Button, menu_button: Button, is_open: bool) -> void:
	if menu_panel != null:
		menu_panel.position.x = MENU_OPEN_X if is_open else MENU_CLOSED_X
	if return_button != null:
		return_button.visible = is_open
	if menu_button != null:
		menu_button.visible = not is_open


static func is_user_operating_ui(menu_open: bool, chat_is_open: bool, panels: Array) -> bool:
	if menu_open or chat_is_open:
		return true
	for panel in panels:
		if panel != null and is_instance_valid(panel):
			return true
	return false


static func apply_color_filter(filter: ColorRect, mode: String) -> void:
	if filter == null:
		return
	filter.color = color_filter_value(mode)


static func move_children_to_front(owner: Node, nodes: Array) -> void:
	for node in nodes:
		move_child_to_front(owner, node)


static func move_child_to_front(owner: Node, node: Node) -> void:
	if owner == null or node == null or not is_instance_valid(node) or node.get_parent() != owner:
		return
	_move_child_to_front_deferred(owner, node)


static func _move_child_to_front_deferred(owner: Node, node: Node) -> void:
	await owner.get_tree().process_frame
	if owner == null or node == null or not is_instance_valid(owner) or not is_instance_valid(node) or node.get_parent() != owner:
		return
	owner.move_child(node, owner.get_child_count() - 1)


static func color_filter_value(mode: String) -> Color:
	match mode:
		"red_weak":
			return Color(0.6, 1.0, 1.0, 0.35)
		"green_weak":
			return Color(1.0, 0.6, 1.0, 0.35)
		"blue_weak":
			return Color(1.0, 1.0, 0.6, 0.35)
		_:
			return Color(1, 1, 1, 0)
