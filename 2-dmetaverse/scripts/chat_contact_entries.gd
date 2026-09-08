extends RefCounted


static func build(
	room_states: Dictionary,
	known_contacts: Dictionary,
	search_results: Array,
	current_search_query: String,
	unread_by_room: Dictionary,
	private_room_for: Callable
) -> Array:
	var entries := []
	var added_rooms := {}

	for room_name in room_states.keys():
		if added_rooms.has(room_name):
			continue
		var state: Dictionary = room_states[room_name]
		var contact: Dictionary = state.get("contact", {})
		added_rooms[room_name] = true
		entries.append({
			"label": str(state.get("title", "個人チャット")),
			"sub_label": str(state.get("sub_label", "会話済み")),
			"room": str(room_name),
			"contact": contact,
			"unread_count": int(state.get("unread_count", 0)),
		})

	for user_id_key in known_contacts.keys():
		var contact: Dictionary = known_contacts[user_id_key]
		var other_id := int(contact.get("user_id", 0))
		if other_id <= 0:
			continue
		var room := str(private_room_for.call(other_id))
		if added_rooms.has(room):
			continue
		added_rooms[room] = true
		entries.append({
			"label": "%s  ID:%s" % [str(contact.get("user_name", "ユーザー")), other_id],
			"sub_label": str(contact.get("role_label", "会話済み")),
			"room": room,
			"contact": contact,
			"unread_count": int(unread_by_room.get(room, 0)),
		})

	if current_search_query == "":
		return entries

	for user in search_results:
		if typeof(user) != TYPE_DICTIONARY:
			continue
		var other_id := int(user.get("user_id", 0))
		if other_id <= 0:
			continue
		var room := str(private_room_for.call(other_id))
		if added_rooms.has(room):
			continue
		added_rooms[room] = true
		entries.append({
			"label": "%s  ID:%s" % [str(user.get("user_name", "ユーザー")), other_id],
			"sub_label": str(user.get("role_label", "ユーザー")),
			"room": room,
			"contact": user,
			"unread_count": int(unread_by_room.get(room, 0)),
		})
	return entries
