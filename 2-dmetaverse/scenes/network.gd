extends Node

const NetworkRooms := preload("res://scripts/network_rooms.gd")
const NetworkStateCache := preload("res://scripts/network_state_cache.gd")
const NetworkEvents := preload("res://scripts/network_events.gd")
const NetworkNakamaChannels := preload("res://scripts/network_nakama_channels.gd")
const NetworkProcessState := preload("res://scripts/network_process_state.gd")
const NetworkTransportState := preload("res://scripts/network_transport_state.gd")
const ApiPaths := preload("res://scripts/api_paths.gd")
const AppNodes := preload("res://scripts/app_nodes.gd")
const ChatPolicy := preload("res://scripts/chat_policy.gd")

signal ws_message(packet)
signal chat_message(data)
signal chat_delete(message_id)
signal realtime_connected
signal realtime_connection_failed(reason)
signal state_sync_requested

const RECONNECT_DELAY := 5.0
const CONNECT_ATTEMPT_TIMEOUT := 10.0
const STATE_SYNC_BURST_DELAYS := [0.25, 0.75, 1.5, 3.0]

var ws := WebSocketPeer.new()
var connected := false
var connecting := false
var school_id: int = -1
var user_id := -1
var use_nakama := false
var nakama_ready := false
var client = null
var socket = null
var session = null
var room_name := ""
var chat_channel_id := ""
var chat_channels := {}
var chat_rooms := {}
var nakama_user_to_app_user := {}
var latest_player_states := {}
var reconnect_timer := 0.0
var reconnect_attempt := 0
var connection_attempt_started_at := 0.0
var connection_generation := 0
var active_transport := ""

func _ready():
	LocalLog.write("Network singleton READY")


func connect_world(_school_id: int, _user_id: int) -> void:
	if connected or connecting:
		return
	school_id = _school_id
	user_id = _user_id
	NetworkTransportState.begin_connection_attempt(self, "starting")
	set_process(true)
	LocalLog.write("connect_world school=%s user=%s" % [school_id, user_id])
	_connect_nakama_or_fallback(connection_generation)


func disconnect_world() -> void:
	NetworkTransportState.close_transports(socket, ws)
	NetworkTransportState.reset_runtime_state(self, Callable(self, "_clear_runtime_caches"))
	set_process(false)
	LocalLog.write("Network disconnected and reset")


func _connect_nakama_or_fallback(generation: int) -> void:
	if AppConfig.is_local() and AppNodes.nakama(self) != null:
		LocalLog.write("Local mode: connect authenticated user directly to Nakama")
		await _connect_nakama(AppConfig.nakama_info_for_user(user_id, Global.username, school_id), generation)
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_nakama_session_completed.bind(http, generation))
	var err := http.request(DjangoApi.api_base() + ApiPaths.nakama_session(), DjangoApi.auth_headers(), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		_connect_local_nakama_or_fallback(generation)


func _on_nakama_session_completed(result: int, code: int, headers: Array, body: PackedByteArray, http: HTTPRequest, generation: int) -> void:
	http.queue_free()
	if generation != connection_generation:
		return

	if code != 200:
		LocalLog.write("Django Nakama session unavailable code=%s; trying local Nakama" % code)
		_connect_local_nakama_or_fallback(generation)
		return

	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("nakama"):
		_connect_local_nakama_or_fallback(generation)
		return

	var nakama_info: Dictionary = data["nakama"]
	if AppNodes.nakama(self) == null:
		push_warning("Nakama SDK is not installed. Falling back to Django WebSocket.")
		LocalLog.write("Nakama SDK missing; fallback websocket")
		_connect_fallback_ws()
		return

	await _connect_nakama(nakama_info, generation)


func _connect_local_nakama_or_fallback(generation: int) -> void:
	if generation != connection_generation:
		return
	if AppConfig.is_local() and AppNodes.nakama(self) != null:
		await _connect_nakama(AppConfig.nakama_info_for_user(user_id, Global.username, school_id), generation)
		return

	_connect_fallback_ws()


func _connect_nakama(info: Dictionary, generation: int) -> void:
	if generation != connection_generation:
		return
	active_transport = "nakama"
	var nakama: Node = AppNodes.nakama(self)
	client = nakama.create_client(
		str(info.get("server_key", "defaultkey")),
		str(info.get("host", "127.0.0.1")),
		int(info.get("port", 7350)),
		str(info.get("scheme", "http"))
	)

	var vars: Dictionary = info.get("vars", {})
	session = await client.authenticate_custom_async(
		str(info.get("custom_id", "")),
		str(info.get("username", "user_%s" % user_id)),
		bool(info.get("create", true)),
		vars
	)
	if generation != connection_generation:
		return
	if session.is_exception():
		push_error("Nakama auth failed: %s" % session)
		LocalLog.write("Nakama auth failed: %s" % session)
		connecting = false
		_connect_fallback_ws()
		return

	socket = nakama.create_socket_from(client)
	var connected_result: Variant = await socket.connect_async(session)
	if generation != connection_generation:
		return
	if connected_result.is_exception():
		push_error("Nakama socket failed: %s" % connected_result)
		LocalLog.write("Nakama socket failed: %s" % connected_result)
		connecting = false
		_connect_fallback_ws()
		return

	socket.received_channel_presence.connect(_on_nakama_channel_presence)
	socket.received_channel_message.connect(_on_nakama_channel_message)

	room_name = str(info.get("room_name", NetworkRooms.school_room(school_id)))
	var joined := await NetworkNakamaChannels.join_room(socket, room_name, NakamaRTMessage.ChannelJoin.ChannelType.Room)
	if generation != connection_generation:
		return
	if not bool(joined["ok"]):
		push_error("Nakama chat channel join failed: %s" % str(joined["error"]))
		LocalLog.write("Nakama chat channel join failed: %s" % str(joined["error"]))
		connecting = false
		_schedule_reconnect("nakama_chat_join_failed")
		return

	var channel_id := str(joined["channel_id"])
	NetworkNakamaChannels.remember_room(chat_channels, chat_rooms, room_name, channel_id)
	# Nakama を採用した時点で、以前のフォールバック接続試行を止める。
	# 両方を監視すると、閉じたフォールバックWSを切断と誤判定して
	# 正常なNakama接続まで再接続ループに入ってしまう。
	if NetworkTransportState.websocket_is_open_or_connecting(ws):
		ws.close()
	NetworkTransportState.apply_nakama_connected(self, channel_id)
	set_process(true)
	LocalLog.write("Nakama connected room=%s channel=%s" % [room_name, chat_channel_id])
	emit_signal("realtime_connected")
	emit_signal("state_sync_requested")
	_send_nakama_chat(NetworkEvents.user_event("state_request", user_id))
	_request_state_sync_burst()


func _connect_fallback_ws() -> void:
	NetworkTransportState.prepare_fallback(self)

	var url := AppConfig.fallback_world_ws_url(school_id)
	var err = ws.connect_to_url(url)
	if err != OK:
		push_error("WS connect failed")
		LocalLog.write("Fallback websocket connect failed url=%s" % url)
		connecting = false
		_schedule_reconnect("fallback_ws_request_failed")
		return

	set_process(true)
	LocalLog.write("Fallback websocket connecting url=%s" % url)

func _process(_delta):
	if NetworkProcessState.connection_timed_out(connecting, connection_attempt_started_at, CONNECT_ATTEMPT_TIMEOUT):
		_timeout_current_connection("connect_timeout_%s" % active_transport)
		return

	if reconnect_timer > 0.0:
		reconnect_timer -= _delta
		if NetworkProcessState.ready_to_reconnect(reconnect_timer, connected, connecting, school_id, user_id):
			NetworkTransportState.begin_connection_attempt(self, "starting")
			set_process(true)
			LocalLog.write("Realtime reconnect attempt=%s school=%s user=%s" % [reconnect_attempt, school_id, user_id])
			_connect_nakama_or_fallback(connection_generation)
		return

	if NetworkProcessState.nakama_disconnected(use_nakama, socket):
		LocalLog.write("Nakama socket disconnected; scheduling reconnect")
		_schedule_reconnect("nakama_socket_disconnected")
		return

	# フォールバックWSはフォールバックを選択した時だけ監視する。
	# Nakama接続中に閉じたWSを poll / 判定すると、接続失敗として扱われて
	# Nakamaソケットが閉じられ、入室・移動同期が数秒ごとに途切れていた。
	if active_transport == "fallback_ws":
		ws.poll()
		NetworkProcessState.apply_fallback_transition(self, NetworkProcessState.fallback_transition(ws, connected, connecting))

		for packet in NetworkTransportState.read_websocket_packets(ws):
			NetworkStateCache.apply_packet(latest_player_states, packet)
			emit_signal("ws_message", packet)

func send_move(data: Dictionary) -> void:
	_send_world_event("move", data)


func send_stamp(data: Dictionary) -> void:
	_send_world_event("stamp", data)


func _send_world_event(event_name: String, data: Dictionary) -> void:
	if not use_nakama:
		NetworkTransportState.send_websocket_packet(ws, data)
		return

	_send_nakama_chat(NetworkEvents.data_event(event_name, data))


func send_chat_message(data: Dictionary) -> void:
	if use_nakama:
		emit_signal("chat_message", data)
		LocalLog.write("send chat message id=%s" % str(data.get("id", "")))
		var target_room := str(data.get("chat_room", room_name))
		await ensure_chat_room(target_room)
		_send_nakama_chat_to_room(target_room, NetworkEvents.data_event("chat_message", data))
		if target_room != room_name:
			_send_nakama_chat(NetworkEvents.data_event("chat_notify", data))
		return

	emit_signal("chat_message", data)
	LocalLog.write("local chat message id=%s" % str(data.get("id", "")))


func send_chat_delete(message_id: String) -> void:
	if use_nakama:
		emit_signal("chat_delete", message_id)
		LocalLog.write("send chat delete id=%s" % message_id)
		_send_nakama_chat_to_room(room_name, NetworkEvents.id_event("chat_delete", message_id))
		return

	emit_signal("chat_delete", message_id)


func _send_nakama_chat(content: Dictionary) -> void:
	if not NetworkNakamaChannels.primary_ready(nakama_ready, socket, chat_channel_id):
		return

	socket.write_chat_message_async(chat_channel_id, content)


func ensure_chat_room(target_room: String) -> bool:
	if target_room == "":
		return false
	if NetworkNakamaChannels.has_room(chat_channels, target_room):
		return true
	if not NetworkNakamaChannels.socket_ready(nakama_ready, socket):
		return false
	var joined: Dictionary = await NetworkNakamaChannels.join_room(socket, target_room, NakamaRTMessage.ChannelJoin.ChannelType.Room)
	if not bool(joined["ok"]):
		LocalLog.write("Nakama extra chat channel join failed room=%s error=%s" % [target_room, str(joined["error"])])
		return false
	var channel_id := str(joined["channel_id"])
	NetworkNakamaChannels.remember_room(chat_channels, chat_rooms, target_room, channel_id)
	LocalLog.write("Nakama joined chat room=%s channel=%s" % [target_room, channel_id])
	return true


func private_room_for(other_user_id: int) -> String:
	return NetworkRooms.private_room(school_id, user_id, other_user_id)


func _send_nakama_chat_to_room(target_room: String, content: Dictionary) -> void:
	if not NetworkNakamaChannels.socket_ready(nakama_ready, socket):
		return
	var channel_id := NetworkNakamaChannels.channel_id_for_room(chat_channels, target_room)
	if channel_id == "":
		return
	socket.write_chat_message_async(channel_id, content)


func _on_nakama_channel_message(message) -> void:
	var context := NetworkEvents.channel_message_context(message, chat_rooms, room_name)
	if context.is_empty():
		return
	var payload := NetworkEvents.channel_payload(context)
	if payload.is_empty():
		return
	_apply_channel_action(message, NetworkEvents.channel_action(payload, user_id))


func _apply_channel_action(message, action: Dictionary) -> void:
	if action.is_empty():
		return
	var data: Variant = action.get("data", {})
	if bool(action.get("remember_sender", false)) and typeof(data) == TYPE_DICTIONARY:
		NetworkStateCache.remember_nakama_sender(nakama_user_to_app_user, str(message.sender_id), data as Dictionary)
	if bool(action.get("cache_world", false)) and typeof(data) == TYPE_DICTIONARY:
		NetworkStateCache.apply_packet(latest_player_states, data as Dictionary)
	if bool(action.get("allow_reply", false)) and typeof(data) == TYPE_DICTIONARY:
		var sender_id := int((data as Dictionary).get("user_id", -1))
		if sender_id > 0 and sender_id != user_id:
			ChatPolicy.allow_temporary_reply_to_user(Global, AppNodes.world(self), sender_id)
	var log_message := str(action.get("log", ""))
	if log_message != "":
		LocalLog.write(log_message)
	var signal_name := str(action.get("signal", ""))
	if signal_name == "state_sync_requested":
		emit_signal(signal_name)
	else:
		emit_signal(signal_name, data)


func _on_nakama_channel_presence(presence_event) -> void:
	# A Nakama Room Channel has one deterministic ID for each school lobby.
	# Unlike relayed matches, it cannot split users into independently-created rooms.
	if str(presence_event.channel_id) != chat_channel_id:
		return

	for presence in presence_event.joins:
		LocalLog.write("Nakama lobby presence joined user=%s username=%s" % [str(presence.user_id), str(presence.username)])
		# Existing clients republish their current state when someone enters.
		emit_signal("state_sync_requested")

	for presence in presence_event.leaves:
		var nakama_user_id := str(presence.user_id)
		var leave := NetworkStateCache.apply_nakama_leave(nakama_user_to_app_user, latest_player_states, nakama_user_id)
		if leave.is_empty():
			continue
		var app_user_id := int(leave.get("app_user_id", -1))
		LocalLog.write("Nakama lobby presence left app_user=%s nakama_user=%s" % [app_user_id, nakama_user_id])
		emit_signal("ws_message", leave.get("packet", {}))


func _request_state_sync_burst() -> void:
	var expected_channel_id := chat_channel_id
	for delay in STATE_SYNC_BURST_DELAYS:
		await get_tree().create_timer(float(delay)).timeout
		# Covers two clients entering at nearly the same instant, before either
		# has processed the other's channel-presence event or state request.
		if not connected or not nakama_ready or chat_channel_id != expected_channel_id:
			return
		emit_signal("state_sync_requested")
		_send_nakama_chat(NetworkEvents.user_event("state_request", user_id))


func cached_remote_players() -> Dictionary:
	return NetworkStateCache.remote_players(latest_player_states, user_id)


func _schedule_reconnect(reason: String) -> void:
	if not NetworkTransportState.schedule_reconnect(self, socket, ws, RECONNECT_DELAY):
		return
	LocalLog.write("Realtime reconnect scheduled reason=%s delay=%ss attempt=%s" % [reason, RECONNECT_DELAY, reconnect_attempt])
	emit_signal("realtime_connection_failed", reason)
	set_process(true)


func _timeout_current_connection(reason: String) -> void:
	LocalLog.write("Realtime connection timed out reason=%s school=%s user=%s" % [reason, school_id, user_id])
	var timed_out_transport := NetworkTransportState.timeout_connection(self, socket, ws)
	emit_signal("realtime_connection_failed", reason)
	if timed_out_transport == "nakama":
		NetworkTransportState.begin_connection_attempt(self, "fallback_ws")
		set_process(true)
		LocalLog.write("Nakama timed out; trying fallback websocket")
		_connect_fallback_ws()
	else:
		_schedule_reconnect(reason)


func _clear_runtime_caches() -> void:
	room_name = ""
	chat_channel_id = ""
	chat_channels.clear()
	chat_rooms.clear()
	nakama_user_to_app_user.clear()
	latest_player_states.clear()
