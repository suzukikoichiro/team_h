extends RefCounted


static func data_event(event_name: String, data: Dictionary) -> Dictionary:
	return {
		"event": event_name,
		"data": data,
	}


static func id_event(event_name: String, id: String) -> Dictionary:
	return {
		"event": event_name,
		"id": id,
	}


static func user_event(event_name: String, user_id: int) -> Dictionary:
	return {
		"event": event_name,
		"user_id": user_id,
	}


static func event_name(content: Dictionary, fallback: String = "chat_message") -> String:
	return str(content.get("event", fallback))


static func data(content: Dictionary) -> Variant:
	return content.get("data", {})


static func data_dictionary(content: Dictionary) -> Dictionary:
	var result: Variant = data(content)
	return result if typeof(result) == TYPE_DICTIONARY else {}


static func id(content: Dictionary) -> String:
	return str(content.get("id", ""))


static func user_id(content: Dictionary, fallback: int = -1) -> int:
	return int(content.get("user_id", fallback))


static func chat_data(content: Dictionary, fallback_room: String, fallback_id: String = "") -> Variant:
	var result: Variant = content.get("data", content)
	if typeof(result) != TYPE_DICTIONARY:
		return result
	if not result.has("id") and fallback_id != "":
		result["id"] = fallback_id
	if not result.has("chat_room"):
		result["chat_room"] = fallback_room
	return result


static func chat_data_dictionary(content: Dictionary, fallback_room: String, fallback_id: String = "") -> Dictionary:
	var result: Variant = chat_data(content, fallback_room, fallback_id)
	return result if typeof(result) == TYPE_DICTIONARY else {}


static func channel_message_context(message, channel_rooms: Dictionary, default_room: String) -> Dictionary:
	var content: Variant = JSON.parse_string(message.content)
	if typeof(content) != TYPE_DICTIONARY:
		return {}
	var source_room := str(channel_rooms.get(str(message.channel_id), default_room))
	return {
		"content": content,
		"event": event_name(content),
		"source_room": source_room,
		"message_id": str(message.message_id),
	}


static func channel_payload(context: Dictionary) -> Dictionary:
	var content: Dictionary = context.get("content", {})
	var event := str(context.get("event", ""))
	match event:
		"move", "stamp", "chat_notify":
			var event_data := data_dictionary(content)
			if event_data.is_empty():
				return {}
			return {"event": event, "data": event_data}
		"chat_delete":
			return {"event": event, "id": id(content)}
		"state_request":
			return {"event": event, "user_id": user_id(content)}
		_:
			var chat_data := chat_data_dictionary(content, str(context.get("source_room", "")), str(context.get("message_id", "")))
			if chat_data.is_empty():
				return {}
			return {"event": "chat_message", "data": chat_data}


static func channel_action(payload: Dictionary, current_user_id: int) -> Dictionary:
	match str(payload.get("event", "")):
		"move":
			var move_data: Dictionary = payload["data"]
			return {
				"signal": "ws_message",
				"data": move_data,
				"remember_sender": true,
				"cache_world": true,
				"log": "received channel move user=%s" % str(move_data.get("user_id", "")),
			}
		"stamp":
			var stamp_data: Dictionary = payload["data"]
			return {
				"signal": "ws_message",
				"data": stamp_data,
				"remember_sender": true,
				"log": "received channel stamp user=%s index=%s" % [str(stamp_data.get("user_id", "")), str(stamp_data.get("stamp_index", ""))],
			}
		"chat_delete":
			return {
				"signal": "chat_delete",
				"data": id(payload),
			}
		"chat_notify":
			var notify_data: Dictionary = payload["data"]
			return {
				"signal": "chat_message",
				"data": notify_data,
				"allow_reply": true,
				"log": "received channel chat notify id=%s" % str(notify_data.get("id", "")),
			}
		"state_request":
			var requester_id := user_id(payload)
			if requester_id == current_user_id:
				return {}
			return {
				"signal": "state_sync_requested",
				"log": "received state request from user=%s" % requester_id,
			}
		_:
			var data: Dictionary = payload["data"]
			return {
				"signal": "chat_message",
				"data": data,
				"allow_reply": true,
				"log": "received channel chat id=%s" % str(data.get("id", "")),
			}
