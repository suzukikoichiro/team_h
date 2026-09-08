extends RefCounted

const ChatApi := preload("res://scripts/chat_api.gd")
const ChatWidgets := preload("res://scripts/chat_widgets.gd")


static func send_payload(
	is_connected: bool,
	current_room: String,
	can_send: bool,
	text: String,
	max_length: int,
	user_id: int,
	username: String
) -> Dictionary:
	if not is_connected:
		return {"ok": false, "message": ""}
	if current_room == "":
		return {"ok": false, "message": "相手を選んでから送信してください"}
	if not can_send:
		return {"ok": false, "message": "相手に近づくと送信できます"}

	var msg := text.strip_edges()
	if msg.is_empty() or msg.length() > max_length:
		return {"ok": false, "message": ""}
	return {
		"ok": true,
		"message": "",
		"payload": {
			"id": str(Time.get_ticks_usec()),
			"user_id": user_id,
			"user_name": username,
			"message": msg,
			"time": Time.get_unix_time_from_system(),
			"chat_room": current_room,
			"avatar_key": "skin_01",
		},
	}


static func apply_sent_payload(
	current_room: String,
	pending_contacts_by_room: Dictionary,
	payload: Dictionary,
	network_node: Node,
	django_api: Node,
	message_input: TextEdit,
	remember_contact: Callable
) -> void:
	var pending: Variant = pending_contacts_by_room.get(current_room)
	if typeof(pending) == TYPE_DICTIONARY:
		remember_contact.call(pending)
	if network_node != null and network_node.has_method("send_chat_message"):
		network_node.call("send_chat_message", payload)
	ChatApi.save_message(django_api, payload)
	message_input.text = ""
	ChatWidgets.apply_input_height(message_input)
	message_input.grab_focus()
