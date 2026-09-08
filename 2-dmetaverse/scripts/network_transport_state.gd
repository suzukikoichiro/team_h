extends RefCounted


static func websocket_is_open(ws: WebSocketPeer) -> bool:
	return ws.get_ready_state() == WebSocketPeer.STATE_OPEN


static func websocket_is_open_or_connecting(ws: WebSocketPeer) -> bool:
	var state := ws.get_ready_state()
	return state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING


static func websocket_is_closed(ws: WebSocketPeer) -> bool:
	return ws.get_ready_state() == WebSocketPeer.STATE_CLOSED


static func close_socket(socket: Variant) -> void:
	if socket != null and socket.has_method("close"):
		socket.close()


static func close_websocket(ws: WebSocketPeer) -> void:
	if websocket_is_open_or_connecting(ws):
		ws.close()


static func close_transports(socket: Variant, ws: WebSocketPeer) -> void:
	close_socket(socket)
	close_websocket(ws)


static func send_websocket_packet(ws: WebSocketPeer, data: Dictionary) -> bool:
	if not websocket_is_open(ws):
		return false
	ws.send_text(JSON.stringify(data))
	return true


static func read_websocket_packets(ws: WebSocketPeer) -> Array:
	var packets: Array = []
	while ws.get_available_packet_count() > 0:
		var text := ws.get_packet().get_string_from_utf8()
		var packet: Variant = JSON.parse_string(text)
		if typeof(packet) == TYPE_DICTIONARY:
			packets.append(packet)
	return packets


static func prepare_fallback(owner: Object) -> void:
	owner.set("use_nakama", false)
	owner.set("nakama_ready", false)
	owner.set("active_transport", "fallback_ws")
	owner.set("chat_channel_id", "")


static func apply_fallback_connected(owner: Object) -> void:
	owner.set("connected", true)
	owner.set("connecting", false)
	owner.set("active_transport", "fallback_ws")
	owner.set("reconnect_timer", 0.0)
	owner.set("reconnect_attempt", 0)


static func apply_nakama_connected(owner: Object, channel_id: String) -> void:
	owner.set("chat_channel_id", channel_id)
	owner.set("use_nakama", true)
	owner.set("nakama_ready", true)
	owner.set("connected", true)
	owner.set("connecting", false)
	owner.set("active_transport", "nakama")
	owner.set("reconnect_timer", 0.0)
	owner.set("reconnect_attempt", 0)


static func begin_connection_attempt(owner: Object, transport_label: String) -> void:
	owner.set("connecting", true)
	owner.set("connection_attempt_started_at", Time.get_ticks_msec() / 1000.0)
	owner.set("connection_generation", int(owner.get("connection_generation")) + 1)
	owner.set("active_transport", transport_label)
	owner.set("reconnect_timer", 0.0)


static func reset_transport_flags(owner: Object) -> void:
	owner.set("connected", false)
	owner.set("connecting", false)
	owner.set("use_nakama", false)
	owner.set("nakama_ready", false)
	owner.set("active_transport", "")


static func reset_runtime_state(owner: Object, clear_state: Callable) -> void:
	reset_transport_flags(owner)
	owner.set("client", null)
	owner.set("socket", null)
	owner.set("session", null)
	owner.set("room_name", "")
	owner.set("chat_channel_id", "")
	clear_state.call()
	owner.set("reconnect_timer", 0.0)
	owner.set("reconnect_attempt", 0)
	owner.set("connection_attempt_started_at", 0.0)
	owner.set("connection_generation", int(owner.get("connection_generation")) + 1)
	owner.set("school_id", -1)
	owner.set("user_id", -1)


static func schedule_reconnect(owner: Object, socket: Variant, ws: WebSocketPeer, delay: float) -> bool:
	if int(owner.get("school_id")) <= 0 or int(owner.get("user_id")) <= 0:
		return false
	close_transports(socket, ws)
	reset_transport_flags(owner)
	owner.set("reconnect_attempt", int(owner.get("reconnect_attempt")) + 1)
	owner.set("reconnect_timer", delay)
	return true


static func timeout_connection(owner: Object, socket: Variant, ws: WebSocketPeer) -> String:
	owner.set("connection_generation", int(owner.get("connection_generation")) + 1)
	close_transports(socket, ws)
	var timed_out_transport := str(owner.get("active_transport"))
	reset_transport_flags(owner)
	return timed_out_transport
