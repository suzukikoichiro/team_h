extends Control

const BOLD_FONT := preload("res://assets/fonts/Noto_Sans_JP/static/NotoSansJP-Bold.ttf")
const ChatConnections := preload("res://scripts/chat_connections.gd")
const ChatApi := preload("res://scripts/chat_api.gd")
const ChatContacts := preload("res://scripts/chat_contacts.gd")
const ChatContactEntries := preload("res://scripts/chat_contact_entries.gd")
const ChatMessageActions := preload("res://scripts/chat_message_actions.gd")
const ChatPolicy := preload("res://scripts/chat_policy.gd")
const ChatRealtime := preload("res://scripts/chat_realtime.gd")
const ChatRoomState := preload("res://scripts/chat_room_state.gd")
const ChatWidgets := preload("res://scripts/chat_widgets.gd")
const UiFactory := preload("res://scripts/ui_factory.gd")
const AppNodes := preload("res://scripts/app_nodes.gd")

@onready var message_input: TextEdit = $ChatPanel/RootHBox/ChatArea/RootVBox/InputContainer/MessageInput
@onready var send_button: Button = $ChatPanel/RootHBox/ChatArea/RootVBox/InputContainer/SendButton
@onready var input_container: HBoxContainer = $ChatPanel/RootHBox/ChatArea/RootVBox/InputContainer
@onready var message_list: VBoxContainer = $ChatPanel/RootHBox/ChatArea/RootVBox/ChatScroll/MessageList
@onready var chat_scroll: ScrollContainer = $ChatPanel/RootHBox/ChatArea/RootVBox/ChatScroll
@onready var back_button: Button = $ChatPanel/RootHBox/Sidebar/SidebarMargin/SidebarVBox/BackButton
@onready var status_label: Label = $ChatPanel/RootHBox/ChatArea/RootVBox/TopBar/TitleBox/StatusLabel
@onready var title_label: Label = $ChatPanel/RootHBox/ChatArea/RootVBox/TopBar/TitleBox/Title
@onready var search_input: LineEdit = $ChatPanel/RootHBox/Sidebar/SidebarMargin/SidebarVBox/SearchInput
@onready var contact_list: VBoxContainer = $ChatPanel/RootHBox/Sidebar/SidebarMargin/SidebarVBox/ContactScroll/ContactList
@onready var network_node: Node = get_node_or_null("/root/Network")
@onready var global_state: Node = get_node_or_null("/root/Global")
@onready var django_api: Node = get_node_or_null("/root/DjangoApi")

const MAX_LENGTH := 255
const CHAT_PANEL_MAX_WIDTH := 1040.0
const CHAT_PANEL_MAX_HEIGHT := 660.0
const CHAT_PANEL_MARGIN := 28.0

var is_connected := false
var ws_connecting := false
var current_room := ""
var current_title := "個人チャット"
var messages_by_room := {}
var known_contacts := {}
var pending_contacts_by_room := {}
var current_search_query := ""
var room_states := {}
var unread_by_room := {}
var unread_start_by_room := {}
var auto_opened_unread_room := false

func _ready() -> void:
	AppNodes.write_log(self, "Chat ready")
	UiFactory.apply_mysterious_theme(self)
	UiFactory.fit_centered_panel($ChatPanel, get_viewport_rect().size, Vector2(CHAT_PANEL_MAX_WIDTH, CHAT_PANEL_MAX_HEIGHT), CHAT_PANEL_MARGIN)
	send_button.disabled = true
	ChatConnections.connect_ui(self, send_button, back_button, search_input, message_input)
	message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	message_input.scroll_fit_content_height = true
	ChatWidgets.apply_strong_fonts([
		back_button,
		status_label,
		title_label,
		search_input,
		message_input,
		send_button,
	], BOLD_FONT)

	ChatConnections.connect_network(network_node, self)
	ChatConnections.connect_api(django_api, self)

	UiFactory.clear_children(contact_list)
	_set_empty_state()
	if bool(AppNodes.value(global_state, "is_logged_in", false)):
		_on_login_done()
	else:
		ChatConnections.connect_global_login(global_state, self)


func _on_login_done() -> void:
	_load_known_contacts()
	if current_room == "":
		_set_empty_state()
	if ws_connecting or is_connected:
		ChatApi.fetch_rooms(django_api)
		_rebuild_contacts()
		return
	var user_id := int(AppNodes.value(global_state, "user_id", 0))
	if user_id <= 0:
		status_label.text = "未接続"
		return
	ws_connecting = true
	status_label.text = "接続中..."
	ChatRealtime.connect_world(network_node, int(AppNodes.value(global_state, "school_id", 1)), user_id)
	if ChatRealtime.network_connected(network_node):
		_on_realtime_connected()
	ChatApi.fetch_rooms(django_api)
	_rebuild_contacts()


func _process(_delta: float) -> void:
	UiFactory.fit_centered_panel($ChatPanel, get_viewport_rect().size, Vector2(CHAT_PANEL_MAX_WIDTH, CHAT_PANEL_MAX_HEIGHT), CHAT_PANEL_MARGIN)
	_update_composer_visibility()


func _on_realtime_connected() -> void:
	is_connected = true
	ws_connecting = false
	_update_composer_visibility()
	status_label.text = "接続済み"
	AppNodes.write_log(self, "Chat realtime connected")


func _on_search_changed(text: String) -> void:
	current_search_query = text.strip_edges()
	if current_search_query == "":
		_rebuild_contacts()
		return
	ChatApi.fetch_users(django_api, current_search_query)


func _set_empty_state() -> void:
	current_room = ""
	current_title = "会話一覧"
	ChatWidgets.apply_inbox_empty_state(title_label, status_label, send_button, input_container, message_list, BOLD_FONT)


func _on_chat_users_received(users: Array) -> void:
	_rebuild_contacts(users)


func _on_chat_rooms_received(rooms: Array) -> void:
	var collected := ChatRoomState.collect_rooms(rooms, AppNodes.lobby_room(int(AppNodes.value(global_state, "school_id", 1))))
	room_states = collected.get("room_states", {})
	unread_by_room = collected.get("unread_by_room", {})
	for contact in collected.get("contacts", []):
		if typeof(contact) == TYPE_DICTIONARY:
			_remember_contact(contact, false)
	_rebuild_contacts()
	_auto_open_latest_unread_room(rooms)


# チャットを通知から開いた場合、最も新しい未読がある会話を最初に表示する。
# 一度ユーザーが会話を選んだ後は、定期的なルーム一覧更新で表示を切り替えない。
func _auto_open_latest_unread_room(rooms: Array) -> void:
	var selected := ChatRoomState.auto_open_latest_unread_room(rooms, AppNodes.lobby_room(int(AppNodes.value(global_state, "school_id", 1))), auto_opened_unread_room, current_room)
	if selected.is_empty():
		return

	auto_opened_unread_room = true
	var selected_room := str(selected.get("room", ""))
	var contact: Variant = selected.get("contact", {})
	if typeof(contact) == TYPE_DICTIONARY and not contact.is_empty():
		pending_contacts_by_room[selected_room] = contact
	_select_room(selected_room, str(selected.get("title", "個人チャット")))


func _rebuild_contacts(search_results: Array = []) -> void:
	UiFactory.clear_children(contact_list)
	var entries := ChatContactEntries.build(
		room_states,
		known_contacts,
		search_results,
		current_search_query,
		unread_by_room,
		_private_room_for
	)
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var contact: Dictionary = entry.get("contact", {})
		_add_contact_button(
			str(entry.get("label", "個人チャット")),
			str(entry.get("sub_label", "会話済み")),
			str(entry.get("room", "")),
			false,
			contact,
			int(entry.get("unread_count", 0))
		)


func _add_contact_button(label: String, sub_label: String, room: String, _is_lobby: bool, contact: Dictionary = {}, unread_count: int = 0) -> void:
	var button := ChatWidgets.contact_button(label, sub_label, room, contact, unread_count, BOLD_FONT)
	button.pressed.connect(func():
		if not _can_open_private_chat(contact):
			status_label.text = "学生同士のチャットは、近づいて「話しかける」から開始してください"
			return
		if not contact.is_empty():
			pending_contacts_by_room[room] = contact
		_select_room(room, label)
	)
	contact_list.add_child(button)


func _select_room(room: String, title: String) -> void:
	current_room = room
	current_title = title
	title_label.text = title
	message_input.text = ""
	_update_composer_visibility()
	UiFactory.clear_children(message_list)
	ChatApi.fetch_messages(django_api, current_room, int(AppNodes.value(global_state, "chat_history_limit", 100)))
	_render_current_room_messages()
	if network_node != null and network_node.has_method("ensure_chat_room"):
		network_node.call("ensure_chat_room", current_room)


func open_private_chat(contact: Dictionary) -> void:
	if contact.is_empty():
		return
	var other_id := int(contact.get("user_id", 0))
	if other_id <= 0:
		return
	if not _can_open_private_chat(contact):
		status_label.text = "学生同士のチャットは、近づいて「話しかける」から開始してください"
		return
	var room := _private_room_for(other_id)
	pending_contacts_by_room[room] = contact
	var label := "%s  ID:%s" % [str(contact.get("user_name", "ユーザー")), other_id]
	_select_room(room, label)


func _on_chat_messages_received(room: String, messages: Array, unread_start_id: String) -> void:
	if ChatRoomState.is_lobby_room(room, AppNodes.lobby_room(int(AppNodes.value(global_state, "school_id", 1)))):
		return
	ChatPolicy.allow_temporary_replies_from_unread(messages, unread_start_id, int(AppNodes.value(global_state, "user_id", 0)), global_state, AppNodes.world(self))
	ChatRoomState.merge_room_messages(messages_by_room, room, messages)
	unread_start_by_room[room] = unread_start_id
	if room == current_room:
		UiFactory.clear_children(message_list)
		_render_current_room_messages()
		_mark_room_read(room)
		_rebuild_contacts()


func _on_chat_history_cleared(room: String) -> void:
	ChatRoomState.clear_room_history(messages_by_room, unread_by_room, unread_start_by_room, room_states, room)
	if room == current_room:
		UiFactory.clear_children(message_list)
	_rebuild_contacts()


func _on_all_chat_history_cleared(rooms: Array) -> void:
	ChatRoomState.clear_rooms_history(messages_by_room, unread_by_room, unread_start_by_room, room_states, rooms)
	if rooms.has(current_room):
		UiFactory.clear_children(message_list)
	_rebuild_contacts()


func _render_current_room_messages() -> void:
	ChatWidgets.render_messages(
		message_list,
		messages_by_room.get(current_room, []),
		str(unread_start_by_room.get(current_room, "")),
		int(AppNodes.value(global_state, "user_id", 0)),
		get_viewport_rect().size.x,
		BOLD_FONT
	)
	_scroll_messages_to_bottom()


func _on_chat_message(data: Dictionary) -> void:
	var lobby_room := AppNodes.lobby_room(int(AppNodes.value(global_state, "school_id", 1)))
	var room_candidate := str(data.get("chat_room", lobby_room))
	if ChatRoomState.is_lobby_room(room_candidate, lobby_room):
		return
	var current_user_id := int(AppNodes.value(global_state, "user_id", 0))
	var sender_id: int = int(data.get("user_id", -1))
	if sender_id != current_user_id:
		ChatPolicy.allow_temporary_reply_to_user(global_state, AppNodes.world(self), sender_id)
	var incoming := ChatRoomState.apply_incoming_message(messages_by_room, room_states, unread_by_room, data, lobby_room, current_room, current_title, current_user_id)
	if not bool(incoming["accepted"]):
		return
	var room := str(incoming["room"])
	if not bool(incoming["is_current_room"]):
		_remember_contact_from_message(data)
		if not bool(incoming["is_me"]):
			_rebuild_contacts()
		return
	if not bool(incoming["is_me"]):
		_remember_contact_from_message(data)
		_mark_room_read(room)
	_add_message_view(data, bool(incoming["is_me"]))


func _on_send_pressed() -> void:
	var can_send := true
	if is_connected and current_room != "":
		can_send = _can_send_current_room()
	var request := ChatMessageActions.send_payload(
		is_connected,
		current_room,
		can_send,
		message_input.text,
		MAX_LENGTH,
		int(AppNodes.value(global_state, "user_id", 0)),
		str(AppNodes.value(global_state, "username", "User"))
	)
	if not bool(request["ok"]):
		var message := str(request.get("message", ""))
		if message != "":
			status_label.text = message
		return
	ChatMessageActions.apply_sent_payload(
		current_room,
		pending_contacts_by_room,
		request.get("payload", {}),
		network_node,
		django_api,
		message_input,
		_remember_contact
	)


func _add_message_view(data: Dictionary, is_me: bool) -> void:
	if not ChatWidgets.add_message_if_new(message_list, data, is_me, get_viewport_rect().size.x, BOLD_FONT):
		return
	_scroll_messages_to_bottom()


func _scroll_messages_to_bottom() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value


func _remove_message_view(message_id: String) -> void:
	ChatWidgets.remove_message(message_list, message_id)


func _input(event) -> void:
	if ChatWidgets.handle_enter_key(event, message_input, bool(AppNodes.value(global_state, "chat_enter_to_send", true)), _on_send_pressed):
		get_viewport().set_input_as_handled()


func _on_text_changed() -> void:
	ChatWidgets.apply_input_height(message_input)


# 相手を選択していない会話一覧と、送信条件を満たさない履歴には入力欄を出さない。
func _update_composer_visibility() -> void:
	if current_room == "":
		input_container.visible = false
		send_button.disabled = true
		return
	var can_send := is_connected and _can_send_current_room()
	input_container.visible = can_send
	send_button.disabled = not can_send
	if not can_send and status_label.text == "接続済み":
		status_label.text = "この会話に送るには、近くで「話しかける」を押してください"


func _on_back_pressed() -> void:
	queue_free()


func _private_room_for(other_user_id: int) -> String:
	if network_node != null and network_node.has_method("private_room_for"):
		return str(network_node.call("private_room_for", other_user_id))
	return ChatRoomState.private_room(int(AppNodes.value(global_state, "school_id", 1)), int(AppNodes.value(global_state, "user_id", 0)), other_user_id)


func _mark_room_read(room: String) -> void:
	ChatRoomState.mark_room_read(unread_by_room, room_states, room)
	ChatApi.mark_read(django_api, room)
	var hud := AppNodes.hud(self)
	if hud != null and hud.has_method("mark_chat_room_read"):
		hud.call("mark_chat_room_read", room)


func _remember_contact(contact: Dictionary, save_file: bool = true) -> void:
	var normalized := ChatContacts.normalize(contact, int(AppNodes.value(global_state, "user_id", 0)))
	if normalized.is_empty():
		return
	known_contacts[str(normalized.get("user_id", 0))] = normalized
	if save_file:
		_save_known_contacts()


func _remember_contact_from_message(data: Dictionary) -> void:
	var contact := ChatContacts.from_message(data, int(AppNodes.value(global_state, "user_id", 0)))
	if contact.is_empty():
		return
	_remember_contact(contact)


func _load_known_contacts() -> void:
	known_contacts = ChatContacts.load(int(AppNodes.value(global_state, "school_id", 1)), int(AppNodes.value(global_state, "user_id", 0)))


func _save_known_contacts() -> void:
	ChatContacts.save(int(AppNodes.value(global_state, "school_id", 1)), int(AppNodes.value(global_state, "user_id", 0)), known_contacts)


func _on_request_failed(_code: int, _errors := {}) -> void:
	pass


func _can_open_private_chat(contact: Dictionary) -> bool:
	return ChatPolicy.can_open_private_chat(contact, global_state, AppNodes.world(self), int(AppNodes.value(global_state, "user_position", -1)))


func _can_send_current_room() -> bool:
	return ChatPolicy.can_send_room(
		current_room,
		AppNodes.lobby_room(int(AppNodes.value(global_state, "school_id", 1))),
		_contact_for_room(current_room),
		ChatRoomState.other_user_id_from_room(current_room, int(AppNodes.value(global_state, "user_id", 0))),
		global_state,
		AppNodes.world(self),
		int(AppNodes.value(global_state, "user_position", -1))
	)


func _contact_for_room(room: String) -> Dictionary:
	return ChatContacts.find_for_room(
		room,
		pending_contacts_by_room,
		room_states,
		known_contacts,
		Callable(self, "_private_room_for"),
		int(AppNodes.value(global_state, "school_id", 1)),
		int(AppNodes.value(global_state, "user_id", 0))
	)
