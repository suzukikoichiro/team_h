extends RefCounted


static func collect_rooms(rooms: Array, lobby_room: String) -> Dictionary:
	var room_states := {}
	var unread_by_room := {}
	var contacts := []
	for room in rooms:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		var room_name := str(room.get("room", ""))
		if room_name == "" or room_name == lobby_room:
			continue
		room_states[room_name] = room
		unread_by_room[room_name] = int(room.get("unread_count", 0))
		var contact: Variant = room.get("contact")
		if typeof(contact) == TYPE_DICTIONARY and int(contact.get("user_id", 0)) > 0:
			contacts.append(contact)
	return {
		"room_states": room_states,
		"unread_by_room": unread_by_room,
		"contacts": contacts,
	}


static func latest_unread_room(rooms: Array, lobby_room: String) -> Dictionary:
	var latest_unread: Dictionary = {}
	var latest_at := ""
	for room in rooms:
		if typeof(room) != TYPE_DICTIONARY:
			continue
		var room_name := str(room.get("room", ""))
		if room_name == "" or room_name == lobby_room:
			continue
		if int(room.get("unread_count", 0)) <= 0:
			continue
		var last_at := str(room.get("last_at", ""))
		if latest_unread.is_empty() or last_at > latest_at:
			latest_unread = room
			latest_at = last_at
	return latest_unread


static func auto_open_latest_unread_room(rooms: Array, lobby_room: String, already_opened: bool, current_room: String) -> Dictionary:
	if already_opened or current_room != "":
		return {}
	var latest_unread := latest_unread_room(rooms, lobby_room)
	if latest_unread.is_empty():
		return {}
	return {
		"room": str(latest_unread.get("room", "")),
		"title": str(latest_unread.get("title", "個人チャット")),
		"contact": latest_unread.get("contact", {}),
	}


static func merge_messages(cached_messages: Array, next_messages: Array) -> Array:
	var by_id := {}
	for cached in cached_messages:
		if typeof(cached) == TYPE_DICTIONARY:
			by_id[str(cached.get("id", ""))] = cached
	for message in next_messages:
		if typeof(message) == TYPE_DICTIONARY:
			by_id[str(message.get("id", ""))] = message

	var merged := []
	for message in cached_messages:
		if typeof(message) == TYPE_DICTIONARY:
			var message_id := str(message.get("id", ""))
			if by_id.has(message_id):
				merged.append(by_id[message_id])
				by_id.erase(message_id)
	for message in next_messages:
		if typeof(message) == TYPE_DICTIONARY:
			var message_id := str(message.get("id", ""))
			if by_id.has(message_id):
				merged.append(by_id[message_id])
				by_id.erase(message_id)
	return merged


static func merge_room_messages(messages_by_room: Dictionary, room: String, messages: Array) -> void:
	if not messages_by_room.has(room):
		messages_by_room[room] = []
	messages_by_room[room] = merge_messages(messages_by_room.get(room, []), messages)


static func has_message(messages: Array, message_id: String) -> bool:
	if message_id == "":
		return false
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and str(message.get("id", "")) == message_id:
			return true
	return false


static func append_if_new(messages_by_room: Dictionary, room: String, message: Dictionary) -> bool:
	if not messages_by_room.has(room):
		messages_by_room[room] = []
	if has_message(messages_by_room.get(room, []), str(message.get("id", ""))):
		return false
	messages_by_room[room].append(message)
	return true


static func ensure_room_state(room_states: Dictionary, room: String, title: String, current_room: String) -> void:
	if room_states.has(room):
		return
	room_states[room] = {
		"room": room,
		"title": title if room == current_room else "個人チャット",
		"sub_label": "会話済み",
		"contact": {},
		"unread_count": 0,
	}


static func mark_room_read(unread_by_room: Dictionary, room_states: Dictionary, room: String) -> void:
	unread_by_room[room] = 0
	if room_states.has(room):
		room_states[room]["unread_count"] = 0


static func increment_unread(unread_by_room: Dictionary, room_states: Dictionary, room: String) -> void:
	unread_by_room[room] = int(unread_by_room.get(room, 0)) + 1
	if room_states.has(room):
		room_states[room]["unread_count"] = int(unread_by_room.get(room, 0))


static func apply_incoming_message(
	messages_by_room: Dictionary,
	room_states: Dictionary,
	unread_by_room: Dictionary,
	message: Dictionary,
	lobby_room: String,
	current_room: String,
	current_title: String,
	current_user_id: int
) -> Dictionary:
	var room := str(message.get("chat_room", lobby_room))
	if is_lobby_room(room, lobby_room):
		return {"accepted": false, "room": room}
	if not append_if_new(messages_by_room, room, message):
		return {"accepted": false, "room": room}
	ensure_room_state(room_states, room, current_title, current_room)
	var sender_id := int(message.get("user_id", -1))
	var is_current := room == current_room
	var is_me := sender_id == current_user_id
	if not is_current and not is_me:
		increment_unread(unread_by_room, room_states, room)
	return {
		"accepted": true,
		"room": room,
		"sender_id": sender_id,
		"is_current_room": is_current,
		"is_me": is_me,
	}


static func clear_room_history(messages_by_room: Dictionary, unread_by_room: Dictionary, unread_start_by_room: Dictionary, room_states: Dictionary, room: String) -> void:
	messages_by_room[room] = []
	unread_by_room[room] = 0
	unread_start_by_room[room] = ""
	if room_states.has(room):
		room_states[room]["unread_count"] = 0
		room_states[room]["last_message"] = null


static func clear_rooms_history(messages_by_room: Dictionary, unread_by_room: Dictionary, unread_start_by_room: Dictionary, room_states: Dictionary, rooms: Array) -> void:
	for room in rooms:
		clear_room_history(messages_by_room, unread_by_room, unread_start_by_room, room_states, str(room))


static func is_lobby_room(room: String, lobby_room: String) -> bool:
	return room == lobby_room


static func private_room(school_id: int, my_id: int, other_user_id: int) -> String:
	var a: int = min(my_id, other_user_id)
	var b: int = max(my_id, other_user_id)
	return "school-%s-dm-%s-%s" % [school_id, a, b]


static func other_user_id_from_room(room: String, my_id: int) -> int:
	var marker := "-dm-"
	var marker_index := room.find(marker)
	if marker_index < 0:
		return 0
	var parts := room.substr(marker_index + marker.length()).split("-")
	if parts.size() != 2:
		return 0
	var a := int(parts[0])
	var b := int(parts[1])
	if a == my_id:
		return b
	if b == my_id:
		return a
	return 0


static func unread_sender_ids(messages: Array, unread_start_id: String, current_user_id: int) -> Array[int]:
	var sender_ids: Array[int] = []
	if unread_start_id == "":
		return sender_ids
	var in_unread := false
	for message in messages:
		if typeof(message) != TYPE_DICTIONARY:
			continue
		if not in_unread and str(message.get("id", "")) == unread_start_id:
			in_unread = true
		if not in_unread:
			continue
		var sender_id := int(message.get("user_id", -1))
		if sender_id != current_user_id and not sender_ids.has(sender_id):
			sender_ids.append(sender_id)
	return sender_ids
