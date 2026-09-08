extends RefCounted

const ChatRoomState := preload("res://scripts/chat_room_state.gd")


static func can_open_private_chat(contact: Dictionary, global_state: Node, world: Node, user_position: int) -> bool:
	if contact.is_empty():
		return true
	var contact_id := int(contact.get("user_id", 0))
	if can_temporary_reply_to_user(global_state, world, contact_id):
		return true
	if world != null and world.has_method("has_player") and bool(world.call("has_player", contact_id)) and world.has_method("can_chat_with_user"):
		return bool(world.call("can_chat_with_user", contact_id))
	if user_position == 1:
		return true
	if contact_is_teacher(contact):
		return true
	if world != null and world.has_method("can_chat_with_user"):
		return bool(world.call("can_chat_with_user", contact_id))
	return false


static func contact_is_teacher(contact: Dictionary) -> bool:
	if str(contact.get("role", "")) == "teacher":
		return true
	if int(contact.get("user_position", -1)) == 1:
		return true
	return str(contact.get("role_label", "")).find("教") >= 0


static func can_send_room(
	room: String,
	lobby_room: String,
	contact: Dictionary,
	other_user_id: int,
	global_state: Node,
	world: Node,
	user_position: int
) -> bool:
	if room == "" or ChatRoomState.is_lobby_room(room, lobby_room):
		return false
	if can_temporary_reply_to_user(global_state, world, other_user_id):
		return true
	return can_open_private_chat(contact, global_state, world, user_position)


static func allow_temporary_reply_to_user(global_state: Node, world: Node, user_id: int) -> void:
	if global_state != null and global_state.has_method("allow_temporary_reply_to_user"):
		global_state.call("allow_temporary_reply_to_user", user_id)
	if world != null and world.has_method("allow_temporary_reply_to_user"):
		world.call("allow_temporary_reply_to_user", user_id)


static func can_temporary_reply_to_user(global_state: Node, world: Node, user_id: int) -> bool:
	if user_id <= 0:
		return false
	if global_state != null and global_state.has_method("can_temporary_reply_to_user"):
		return bool(global_state.call("can_temporary_reply_to_user", user_id))
	if world != null and world.has_method("can_chat_with_user"):
		return bool(world.call("can_chat_with_user", user_id))
	return false


static func allow_temporary_replies_from_unread(messages: Array, unread_start_id: String, current_user_id: int, global_state: Node, world: Node) -> void:
	for sender_id in ChatRoomState.unread_sender_ids(messages, unread_start_id, current_user_id):
		allow_temporary_reply_to_user(global_state, world, sender_id)
