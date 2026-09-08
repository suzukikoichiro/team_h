extends RefCounted


static func connect_signals(api: Node, owner: Object) -> void:
	_connect_signal(api, "memos_received", owner, "_on_memos_received")
	_connect_signal(api, "memo_saved", owner, "_on_memo_saved")
	_connect_signal(api, "memo_deleted", owner, "_on_memo_deleted")
	_connect_signal(api, "teacher_memo_targets_received", owner, "_on_teacher_memo_targets_received")
	_connect_signal(api, "teacher_memo_distributed", owner, "_on_teacher_memo_distributed")
	_connect_signal(api, "request_failed", owner, "_on_request_failed")


static func _connect_signal(api: Node, signal_name: String, owner: Object, method_name: String) -> void:
	if not api.has_signal(signal_name):
		return
	var callback := Callable(owner, method_name)
	if not api.is_connected(signal_name, callback):
		api.connect(signal_name, callback)
