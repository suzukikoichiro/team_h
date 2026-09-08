extends RefCounted


static func message_update(data: Dictionary, current_user_id: int, lobby_room: String) -> Dictionary:
	var sender_id := int(data.get("user_id", -1))
	var room := str(data.get("chat_room", ""))
	if sender_id == current_user_id or room == lobby_room:
		return {"ok": false}
	return {
		"ok": true,
		"room": room,
		"sender_id": sender_id,
	}


static func apply_message_update(unread_rooms: Dictionary, data: Dictionary, current_user_id: int, lobby_room: String) -> Dictionary:
	var update := message_update(data, current_user_id, lobby_room)
	if not bool(update.get("ok", false)):
		return update
	var room := str(update.get("room", ""))
	if room != "":
		unread_rooms[room] = true
	return update


static func collect_room_updates(rooms: Array, lobby_room: String) -> Dictionary:
	var unread_rooms := {}
	var reply_user_ids: Array[int] = []
	var ensure_rooms: Array[String] = []
	var had_unread := false

	for room in rooms:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		var room_name := str(room.get("room", ""))
		if room_name == "" or room_name == lobby_room:
			continue
		ensure_rooms.append(room_name)
		if int(room.get("unread_count", 0)) <= 0:
			continue
		unread_rooms[room_name] = true
		had_unread = true
		var contact: Variant = room.get("contact", {})
		if typeof(contact) == TYPE_DICTIONARY:
			reply_user_ids.append(int(contact.get("user_id", -1)))

	return {
		"unread_rooms": unread_rooms,
		"reply_user_ids": reply_user_ids,
		"ensure_rooms": ensure_rooms,
		"had_unread": had_unread,
	}


static func apply_room_updates(unread_rooms: Dictionary, rooms: Array, lobby_room: String) -> Dictionary:
	var update := collect_room_updates(rooms, lobby_room)
	for room_name in update.get("unread_rooms", {}).keys():
		unread_rooms[room_name] = true
	return update


static func mark_room_read(unread_rooms: Dictionary, room: String) -> void:
	if unread_rooms.has(room):
		unread_rooms.erase(room)


static func apply_badge(badge: Panel, unread_rooms: Dictionary) -> void:
	if badge != null:
		badge.visible = not unread_rooms.is_empty()
