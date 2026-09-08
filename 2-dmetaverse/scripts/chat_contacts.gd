extends RefCounted


static func normalize(contact: Dictionary, current_user_id: int, default_role_label: String = "会話済み") -> Dictionary:
	var other_id := int(contact.get("user_id", 0))
	if other_id <= 0 or other_id == current_user_id:
		return {}
	return {
		"user_id": other_id,
		"user_name": str(contact.get("user_name", "ユーザー")),
		"role": str(contact.get("role", "")),
		"role_label": str(contact.get("role_label", default_role_label)),
		"avatar_key": str(contact.get("avatar_key", "skin_01")),
	}


static func from_message(data: Dictionary, current_user_id: int) -> Dictionary:
	return normalize({
		"user_id": int(data.get("user_id", 0)),
		"user_name": str(data.get("user_name", "ユーザー")),
		"role": "",
		"role_label": "会話済み",
		"avatar_key": str(data.get("avatar_key", "skin_01")),
	}, current_user_id)


static func load(school_id: int, user_id: int) -> Dictionary:
	var path := contacts_path(school_id, user_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var contacts: Variant = parsed.get("contacts", {})
	return contacts if typeof(contacts) == TYPE_DICTIONARY else {}


static func save(school_id: int, user_id: int, contacts: Dictionary) -> void:
	var file := FileAccess.open(contacts_path(school_id, user_id), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"contacts": contacts}))


static func contacts_path(school_id: int, user_id: int) -> String:
	return "user://chat_contacts_school_%s_user_%s.json" % [school_id, user_id]


static func find_for_room(
	room: String,
	pending_contacts_by_room: Dictionary,
	room_states: Dictionary,
	known_contacts: Dictionary,
	private_room_for: Callable,
	school_id: int,
	user_id: int
) -> Dictionary:
	var pending: Variant = pending_contacts_by_room.get(room)
	if typeof(pending) == TYPE_DICTIONARY and not pending.is_empty():
		return pending
	if room_states.has(room):
		var state: Dictionary = room_states[room]
		var contact: Variant = state.get("contact", {})
		if typeof(contact) == TYPE_DICTIONARY:
			return contact
	for key in known_contacts.keys():
		var contact: Dictionary = known_contacts[key]
		if str(private_room_for.call(int(contact.get("user_id", 0)))) == room:
			return contact
	var prefix := "school-%s-dm-" % school_id
	if room.begins_with(prefix):
		var parts := room.substr(prefix.length()).split("-")
		if parts.size() == 2:
			var a := int(parts[0])
			var b := int(parts[1])
			var other_id := b if a == user_id else a
			if other_id > 0 and other_id != user_id:
				return {"user_id": other_id, "user_name": "ユーザー", "role": "", "role_label": "会話済み"}
	return {}
