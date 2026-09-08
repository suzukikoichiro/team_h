extends RefCounted


static func primary_ready(nakama_ready: bool, socket: Variant, chat_channel_id: String) -> bool:
	return nakama_ready and socket != null and chat_channel_id != ""


static func socket_ready(nakama_ready: bool, socket: Variant) -> bool:
	return nakama_ready and socket != null


static func has_room(chat_channels: Dictionary, target_room: String) -> bool:
	return target_room != "" and chat_channels.has(target_room)


static func channel_id_for_room(chat_channels: Dictionary, target_room: String) -> String:
	return str(chat_channels.get(target_room, ""))


static func remember_room(chat_channels: Dictionary, chat_rooms: Dictionary, target_room: String, channel_id: String) -> void:
	if target_room == "" or channel_id == "":
		return
	chat_channels[target_room] = channel_id
	chat_rooms[channel_id] = target_room


static func join_room(socket: Variant, target_room: String, channel_type: int) -> Dictionary:
	if socket == null or target_room == "":
		return {"ok": false, "channel_id": "", "error": "invalid_room"}
	var channel: Variant = await socket.join_chat_async(target_room, channel_type, false, false)
	if channel.is_exception():
		return {"ok": false, "channel_id": "", "error": str(channel)}
	return {"ok": true, "channel_id": str(channel.id), "error": ""}
