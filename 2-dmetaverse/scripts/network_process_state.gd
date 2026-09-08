extends RefCounted

const NetworkTransportState := preload("res://scripts/network_transport_state.gd")


static func connection_timed_out(connecting: bool, started_at: float, timeout_seconds: float) -> bool:
	if not connecting or started_at <= 0.0:
		return false
	var connecting_for := (Time.get_ticks_msec() / 1000.0) - started_at
	return connecting_for >= timeout_seconds


static func ready_to_reconnect(reconnect_timer: float, connected: bool, connecting: bool, school_id: int, user_id: int) -> bool:
	return reconnect_timer <= 0.0 and not connected and not connecting and school_id > 0 and user_id > 0


static func fallback_opened(ws: WebSocketPeer, connected: bool) -> bool:
	return not connected and NetworkTransportState.websocket_is_open(ws)


static func fallback_disconnected(ws: WebSocketPeer, connected: bool) -> bool:
	return connected and not NetworkTransportState.websocket_is_open(ws)


static func fallback_closed_before_connect(ws: WebSocketPeer, connected: bool, connecting: bool) -> bool:
	return not connected and connecting and NetworkTransportState.websocket_is_closed(ws)


static func nakama_disconnected(use_nakama: bool, socket: Variant) -> bool:
	return use_nakama and socket != null and socket.has_method("is_connected_to_host") and not socket.is_connected_to_host()


static func fallback_transition(ws: WebSocketPeer, connected: bool, connecting: bool) -> String:
	if fallback_opened(ws, connected):
		return "opened"
	if fallback_disconnected(ws, connected):
		return "disconnected"
	if fallback_closed_before_connect(ws, connected, connecting):
		return "closed_before_connect"
	return ""


static func apply_fallback_transition(owner: Object, transition: String) -> void:
	match transition:
		"opened":
			NetworkTransportState.apply_fallback_connected(owner)
			LocalLog.write("Fallback websocket connected")
			owner.emit_signal("realtime_connected")
			owner.emit_signal("state_sync_requested")
		"disconnected":
			owner.set("connected", false)
			LocalLog.write("Fallback websocket disconnected")
			owner.call("_schedule_reconnect", "fallback_ws_disconnected")
		"closed_before_connect":
			owner.set("connecting", false)
			LocalLog.write("Fallback websocket closed before connect; scheduling reconnect")
			owner.call("_schedule_reconnect", "fallback_ws_closed_before_connect")
