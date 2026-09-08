extends RefCounted


static func connect_signals(api: Node, global_state: Node, network: Node, owner: Object) -> void:
	_connect_signal(api, "login_success", owner, "_on_login_success")
	_connect_signal(api, "login_failed", owner, "_on_login_failed")
	_connect_signal(api, "chat_rooms_received", owner, "_on_hud_chat_rooms_received")
	_connect_signal(global_state, "login_done", owner, "_on_global_login_done")
	_connect_signal(network, "chat_message", owner, "_on_hud_chat_message")


static func _connect_signal(source: Object, signal_name: String, owner: Object, method_name: String) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	var callback := Callable(owner, method_name)
	if not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)
