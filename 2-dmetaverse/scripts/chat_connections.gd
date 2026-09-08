extends RefCounted


static func connect_ui(owner: Object, send_button: Button, back_button: Button, search_input: LineEdit, message_input: TextEdit) -> void:
	_connect_signal(send_button, "pressed", owner, "_on_send_pressed")
	_connect_signal(back_button, "pressed", owner, "_on_back_pressed")
	_connect_signal(search_input, "text_changed", owner, "_on_search_changed")
	_connect_signal(message_input, "text_changed", owner, "_on_text_changed")


static func connect_network(network_node: Node, owner: Object) -> void:
	if network_node == null:
		return
	_connect_signal(network_node, "realtime_connected", owner, "_on_realtime_connected")
	_connect_signal(network_node, "chat_message", owner, "_on_chat_message")
	_connect_signal(network_node, "chat_delete", owner, "_remove_message_view")


static func connect_api(api: Node, owner: Object) -> void:
	if api == null:
		return
	_connect_signal(api, "chat_users_received", owner, "_on_chat_users_received")
	_connect_signal(api, "chat_rooms_received", owner, "_on_chat_rooms_received")
	_connect_signal(api, "chat_messages_received", owner, "_on_chat_messages_received")
	_connect_signal(api, "chat_history_cleared", owner, "_on_chat_history_cleared")
	_connect_signal(api, "all_chat_history_cleared", owner, "_on_all_chat_history_cleared")
	_connect_signal(api, "request_failed", owner, "_on_request_failed")


static func connect_global_login(global_state: Node, owner: Object) -> void:
	if global_state == null:
		return
	_connect_signal(global_state, "login_done", owner, "_on_login_done")


static func _connect_signal(source: Object, signal_name: String, owner: Object, method_name: String) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	var callback := Callable(owner, method_name)
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)
