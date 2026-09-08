extends RefCounted


static func fetch_users(api: Node, query: String) -> void:
	if api != null and api.has_method("fetch_chat_users"):
		api.call("fetch_chat_users", query)


static func fetch_rooms(api: Node) -> void:
	if api != null and api.has_method("fetch_chat_rooms"):
		api.call("fetch_chat_rooms")


static func fetch_messages(api: Node, room: String, limit: int) -> void:
	if api != null and api.has_method("fetch_chat_messages"):
		api.call("fetch_chat_messages", room, limit)


static func mark_read(api: Node, room: String) -> void:
	if api != null and api.has_method("mark_chat_read"):
		api.call("mark_chat_read", room)


static func save_message(api: Node, payload: Dictionary) -> void:
	if api != null and api.has_method("save_chat_message"):
		api.call("save_chat_message", payload)
