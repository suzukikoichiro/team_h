extends RefCounted


static func focus_if_open(owner: Object, panel: Variant, suppress_talk: bool, chat_mode: bool) -> bool:
	if panel == null or not is_instance_valid(panel):
		return false
	focus_panel(owner, panel, suppress_talk, chat_mode)
	set_menu_button_for_panel(owner, false)
	return true


static func open_panel(
	owner: Object,
	scene: PackedScene,
	instance_property: String,
	suppress_talk: bool,
	chat_mode: bool,
	restore_menu: bool,
	restore_memo: bool = false,
	refresh_talk: bool = false,
	keep_memo_on_top: bool = false
) -> Control:
	var panel := scene.instantiate() as Control
	if panel == null:
		return null
	owner.set(instance_property, panel)
	attach_panel(owner, panel, suppress_talk, chat_mode)
	connect_panel_exit(
		owner,
		panel,
		instance_property,
		restore_menu,
		chat_mode,
		restore_memo,
		refresh_talk,
		keep_memo_on_top
	)
	set_menu_button_for_panel(owner, false)
	return panel


static func open_settings_panel(owner: Object, scene: PackedScene, instance_property: String, close_callable: Callable) -> Control:
	var panel := scene.instantiate() as Control
	if panel == null:
		return null
	owner.set(instance_property, panel)
	attach_panel(owner, panel, true, false)
	if panel.has_signal("close_pressed"):
		panel.connect("close_pressed", close_callable)
	set_menu_button_for_panel(owner, true)
	return panel


static func attach_panel(owner: Object, panel: Control, suppress_talk: bool, chat_mode: bool) -> void:
	owner.add_child(panel)
	focus_panel(owner, panel, suppress_talk, chat_mode)


static func focus_panel(owner: Object, panel: Control, suppress_talk: bool, chat_mode: bool) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if chat_mode:
		Global.chat_is_open = true
	panel.move_to_front()
	owner.call("refresh_ui_input_policy")
	if suppress_talk:
		owner.call("_suppress_talk_prompt")
	else:
		var talk_button: Button = owner.get("talk_button")
		if talk_button != null:
			talk_button.visible = false
		owner.call("_hide_talk_choices")


static func connect_panel_exit(
	owner: Object,
	panel: Control,
	instance_property: String,
	restore_menu: bool,
	chat_mode: bool,
	restore_memo: bool = false,
	refresh_talk: bool = false,
	keep_memo_on_top: bool = false
) -> void:
	panel.tree_exited.connect(func():
		owner.set(instance_property, null)
		if chat_mode:
			Global.chat_is_open = false
		if restore_menu:
			var menu_button: Button = owner.get("menu_button")
			if menu_button != null:
				menu_button.visible = true
		if restore_memo:
			var memo_button: Button = owner.get("memo_button")
			if memo_button != null:
				memo_button.visible = true
		if keep_memo_on_top:
			owner.call("_keep_memo_button_on_top")
		if refresh_talk:
			owner.call("_refresh_nearby_talk_prompt")
		owner.call_deferred("refresh_ui_input_policy")
	)


static func set_menu_button_for_panel(owner: Object, visible: bool) -> void:
	owner.call("_close_menu")
	var menu_button: Button = owner.get("menu_button")
	if menu_button != null:
		menu_button.visible = visible
