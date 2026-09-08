extends CanvasLayer

@onready var menu_button = $HamburgerButton
@onready var menu_panel = $MenuPanel
@onready var return_button = $ReturnButton
@onready var memo_button := $MemoButton
@onready var chat_button := $MenuPanel/VBoxContainer/Chat
@onready var calendar_menu_button := $MenuPanel/VBoxContainer/Calendar



var settings_instance: Control = null
var chat_instance: Control = null
var profile_instance: Control = null
var memo_instance: Control = null
var calendar_instance: Control = null
var lesson_instance: Control = null
var talk_button: Button = null
var talk_choice_panel: PanelContainer = null
var chat_quick_button: Button = null
var chat_badge: Panel = null
var input_blocker: ColorRect = null
var nearby_talk_contacts: Array = []
var unread_chat_rooms := {}
var unread_refresh_count := 0

var menu_open = false

const SettingsScene := preload("res://scenes/settings_panel.tscn")
const ChatScene := preload("res://scenes/chat.tscn")
const ProfileScene := preload("res://scenes/profile_panel.tscn")
const MemoScene := preload("res://scenes/memo_panel.tscn")
const CalendarScene := preload("res://scenes/calendar_panel.tscn")
const LessonScene := preload("res://scenes/lesson_panel.tscn")
const HudConnections := preload("res://scripts/hud_connections.gd")
const HudPanelLifecycle := preload("res://scripts/hud_panel_lifecycle.gd")
const HudTalkChoices := preload("res://scripts/hud_talk_choices.gd")
const HudUnreadState := preload("res://scripts/hud_unread_state.gd")
const HudUiState := preload("res://scripts/hud_ui_state.gd")
const HudWidgets := preload("res://scripts/hud_widgets.gd")
const UiFactory := preload("res://scripts/ui_factory.gd")
const AppNodes := preload("res://scripts/app_nodes.gd")
const ChatPolicy := preload("res://scripts/chat_policy.gd")
# 初期化
func _ready():
	LocalLog.write("HUD ready")
	add_to_group("hud")
	_build_input_blocker()
	HudConnections.connect_signals(DjangoApi, Global, Network, self)
	if not Global.ui_theme_changed.is_connected(_on_ui_theme_changed):
		Global.ui_theme_changed.connect(_on_ui_theme_changed)
	HudUiState.apply_menu_open(menu_panel, return_button, menu_button, false)
	_apply_logged_in_ui(Global.is_logged_in)
	memo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	HudWidgets.style_memo_button(memo_button)
	HudWidgets.style_menu_toggle(menu_button)
	HudWidgets.style_return_button(return_button)
	HudWidgets.style_menu_panel(menu_panel)
	for menu_item in $MenuPanel/VBoxContainer.get_children():
		if menu_item is Button:
			HudWidgets.style_menu_item(menu_item)
	call_deferred("_keep_memo_button_on_top")
	HudUiState.apply_color_filter($ColorFilter, "normal")
	chat_button.visible = false
	chat_button.disabled = true
	_build_talk_button()
	_build_chat_quick_button()

func _on_login_success(data):
	LocalLog.write("HUD login success user=%s" % str(data.get("user_id", "")))


	# チャットボタンを有効化するだけ
	_apply_logged_in_ui(true)
	_schedule_unread_refresh()
	_keep_memo_button_on_top()


func _on_global_login_done() -> void:
	_apply_logged_in_ui(true)
	if talk_button != null:
		talk_button.visible = false
	_schedule_unread_refresh()
	_keep_memo_button_on_top()

func _on_login_failed(code: int):
	LocalLog.write("HUD login failed code=%s" % code)


func _unhandled_input(event: InputEvent) -> void:
	if not Global.is_logged_in:
		return
	if event.is_action_pressed("memo_open") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2):
		_toggle_memo()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not menu_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not menu_panel.get_global_rect().has_point(event.position):
			_close_menu()
			get_viewport().set_input_as_handled()
	
# メニュー開閉
func _open_menu():
	menu_open = true
	HudUiState.apply_menu_open(menu_panel, return_button, menu_button, true)
	_suppress_talk_prompt()

func _close_menu():
	menu_open = false
	HudUiState.apply_menu_open(menu_panel, return_button, menu_button, false)
	_refresh_nearby_talk_prompt()

func _on_hamburger_button_pressed():
	if menu_open:
		_close_menu()
	else:
		_open_menu()

func _on_return_button_pressed():
	_close_menu()


func _on_memo_pressed() -> void:
	_toggle_memo()


func _toggle_memo() -> void:
	if not _login_ready_or_log("memo"):
		return
	if memo_instance != null and is_instance_valid(memo_instance):
		HudPanelLifecycle.focus_panel(self, memo_instance, true, false)
		return
	memo_instance = MemoScene.instantiate()
	HudPanelLifecycle.attach_panel(self, memo_instance, true, false)
	HudPanelLifecycle.connect_panel_exit(self, memo_instance, "memo_instance", false, false, true, true, true)


func _on_calendar_pressed() -> void:
	if not _login_ready_or_log("calendar"):
		return
	if HudPanelLifecycle.focus_if_open(self, calendar_instance, true, false):
		return

	calendar_instance = HudPanelLifecycle.open_panel(self, CalendarScene, "calendar_instance", true, false, true, false, true)
	calendar_instance.close_pressed.connect(func():
		menu_button.visible = true
	)


# オプションが押されたら
func _on_option_pressed():
	if settings_instance:
		return
	settings_instance = HudPanelLifecycle.open_settings_panel(self, SettingsScene, "settings_instance", _on_settings_close_pressed)

# チャットが押されたら
func _on_chat_pressed():
	if not _login_ready_or_log("chat"):
		return
	if HudPanelLifecycle.focus_if_open(self, chat_instance, false, true):
		return

	chat_instance = HudPanelLifecycle.open_panel(self, ChatScene, "chat_instance", false, true, true)
	

func _on_profile_pressed():
	if not _login_ready_or_log("profile"):
		return
	if HudPanelLifecycle.focus_if_open(self, profile_instance, true, false):
		return

	profile_instance = HudPanelLifecycle.open_panel(self, ProfileScene, "profile_instance", true, false, true, false, true)
	profile_instance.close_pressed.connect(func():
		menu_button.visible = true
	)
	profile_instance.locate_user.connect(_on_profile_locate_user)


func _on_lesson_pressed() -> void:
	if not _login_ready_or_log("lesson"):
		return
	if HudPanelLifecycle.focus_if_open(self, lesson_instance, false, true):
		return

	lesson_instance = HudPanelLifecycle.open_panel(self, LessonScene, "lesson_instance", false, true, true)
	lesson_instance.close_pressed.connect(func():
		menu_button.visible = true
	)


func _on_profile_locate_user(contact: Dictionary) -> void:
	if profile_instance != null and is_instance_valid(profile_instance):
		profile_instance.queue_free()
	profile_instance = null
	var world := AppNodes.world(self)
	if world != null and world.has_method("guide_to_user"):
		world.call("guide_to_user", contact)
	menu_button.visible = true
	_refresh_nearby_talk_prompt()


func set_nearby_talk_target(contact: Dictionary) -> void:
	set_nearby_talk_targets([] if contact.is_empty() else [contact])


func set_nearby_talk_targets(contacts: Array) -> void:
	nearby_talk_contacts = contacts
	var state := HudTalkChoices.apply_button_state(talk_button, contacts, Global.is_logged_in, _is_user_operating_ui())
	if not bool(state.get("can_show", false)):
		_hide_talk_choices()


func _on_talk_pressed() -> void:
	if nearby_talk_contacts.is_empty():
		return
	if nearby_talk_contacts.size() == 1:
		_open_chat_with_contact(nearby_talk_contacts[0])
		return
	_show_talk_choices()


func _open_chat_with_contact(contact: Dictionary) -> void:
	if chat_instance == null or not is_instance_valid(chat_instance):
		chat_instance = HudPanelLifecycle.open_panel(self, ChatScene, "chat_instance", false, true, true)
	else:
		HudPanelLifecycle.focus_panel(self, chat_instance, false, true)
	# open_panel() は add_child() 内で _ready() まで完了する。ready を待つと、
	# すでに発火済みのシグナルを待ち続け、会話一覧だけが表示されてしまう。
	if chat_instance != null and not chat_instance.is_node_ready():
		await chat_instance.ready
	if chat_instance != null and chat_instance.has_method("open_private_chat"):
		chat_instance.call("open_private_chat", contact)


func _login_ready_or_log(panel_name: String) -> bool:
	if DjangoApi.auto_login_done:
		return true
	LocalLog.write("HUD blocked %s: login not completed" % panel_name)
	return false


func _keep_memo_button_on_top() -> void:
	HudUiState.move_children_to_front(self, [memo_button, chat_quick_button, talk_choice_panel])


func _build_input_blocker() -> void:
	input_blocker = ColorRect.new()
	input_blocker.name = "InputBlocker"
	input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_blocker.color = Color.TRANSPARENT
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	input_blocker.visible = false
	add_child(input_blocker)


func refresh_ui_input_policy() -> void:
	var foreground_panel := _frontmost_panel()
	if foreground_panel == null:
		if input_blocker != null:
			input_blocker.visible = false
		_keep_memo_button_on_top()
		return

	foreground_panel.move_to_front()
	if input_blocker != null:
		input_blocker.visible = true
		move_child(input_blocker, get_child_count() - 2)
	for always_available_control in [memo_button, chat_quick_button]:
		if always_available_control != null and is_instance_valid(always_available_control):
			always_available_control.move_to_front()
	_keep_memo_button_on_top()
	var selection_wheel := get_node_or_null("SelectionWheel")
	if selection_wheel != null and selection_wheel.has_method("close"):
		selection_wheel.call("close")


func blocks_background_input() -> bool:
	return menu_open or _frontmost_panel() != null


func _frontmost_panel() -> Control:
	var foreground_panel: Control = null
	for panel in [settings_instance, chat_instance, profile_instance, memo_instance, calendar_instance, lesson_instance]:
		if panel is Control and is_instance_valid(panel):
			if foreground_panel == null or panel.get_index() > foreground_panel.get_index():
				foreground_panel = panel
	return foreground_panel


func _build_talk_button() -> void:
	talk_button = HudWidgets.talk_button()
	talk_button.pressed.connect(_on_talk_pressed)
	add_child(talk_button)


func _build_chat_quick_button() -> void:
	chat_quick_button = HudWidgets.quick_button("💬", Vector2(18, -74), "チャット")
	chat_quick_button.visible = Global.is_logged_in
	chat_quick_button.pressed.connect(_on_chat_pressed)
	add_child(chat_quick_button)

	chat_badge = HudWidgets.unread_badge()
	chat_quick_button.add_child(chat_badge)


func _show_talk_choices() -> void:
	_hide_talk_choices()
	talk_choice_panel = HudTalkChoices.build(nearby_talk_contacts, func(contact: Dictionary):
		_hide_talk_choices()
		_open_chat_with_contact(contact), _hide_talk_choices)
	add_child(talk_choice_panel)
	talk_choice_panel.move_to_front()


func _hide_talk_choices() -> void:
	if talk_choice_panel != null and is_instance_valid(talk_choice_panel):
		talk_choice_panel.queue_free()
	talk_choice_panel = null


func _suppress_talk_prompt() -> void:
	if talk_button != null:
		talk_button.visible = false
	_hide_talk_choices()


func _refresh_nearby_talk_prompt() -> void:
	if talk_button == null:
		return
	set_nearby_talk_targets(nearby_talk_contacts)


func _is_user_operating_ui() -> bool:
	return HudUiState.is_user_operating_ui(
		menu_open,
		Global.chat_is_open,
		[settings_instance, chat_instance, profile_instance, memo_instance, calendar_instance, lesson_instance, talk_choice_panel]
	)


func _on_hud_chat_message(data: Dictionary) -> void:
	var update := HudUnreadState.apply_message_update(unread_chat_rooms, data, int(Global.user_id), AppNodes.lobby_room(int(Global.school_id)))
	if not bool(update.get("ok", false)):
		return
	ChatPolicy.allow_temporary_reply_to_user(Global, AppNodes.world(self), int(update.get("sender_id", -1)))
	HudUnreadState.apply_badge(chat_badge, unread_chat_rooms)
	var world := AppNodes.world(self)
	if world != null and world.has_method("show_chat_bubble_for_message"):
		world.call("show_chat_bubble_for_message", data)


func _on_hud_chat_rooms_received(rooms: Array) -> void:
	var update := HudUnreadState.apply_room_updates(unread_chat_rooms, rooms, AppNodes.lobby_room(int(Global.school_id)))
	for user_id in update.get("reply_user_ids", []):
		ChatPolicy.allow_temporary_reply_to_user(Global, AppNodes.world(self), int(user_id))
	if Network != null and Network.has_method("ensure_chat_room"):
		for room_name in update.get("ensure_rooms", []):
			Network.call("ensure_chat_room", str(room_name))
	if bool(update.get("had_unread", false)):
		LocalLog.write("HUD unread chat rooms=%s" % unread_chat_rooms.keys())
	HudUnreadState.apply_badge(chat_badge, unread_chat_rooms)


func _schedule_unread_refresh() -> void:
	unread_refresh_count += 1
	var refresh_id := unread_refresh_count
	_fetch_unread_rooms_deferred(refresh_id, 0.15)
	_fetch_unread_rooms_deferred(refresh_id, 0.8)
	_fetch_unread_rooms_deferred(refresh_id, 2.0)


func _fetch_unread_rooms_deferred(refresh_id: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if refresh_id != unread_refresh_count:
		return
	if not Global.is_logged_in or not DjangoApi.auto_login_done:
		return
	if DjangoApi.has_method("fetch_chat_rooms"):
		DjangoApi.fetch_chat_rooms()


func mark_chat_room_read(room: String) -> void:
	HudUnreadState.mark_room_read(unread_chat_rooms, room)
	HudUnreadState.apply_badge(chat_badge, unread_chat_rooms)


func _apply_logged_in_ui(is_logged_in: bool) -> void:
	HudUiState.apply_logged_in(is_logged_in, chat_button, calendar_menu_button, menu_button, memo_button, chat_quick_button)


func _on_ui_theme_changed(_theme: String) -> void:
	HudWidgets.style_memo_button(memo_button)
	HudWidgets.style_menu_toggle(menu_button)
	HudWidgets.style_return_button(return_button)
	HudWidgets.style_menu_panel(menu_panel)
	for menu_item in $MenuPanel/VBoxContainer.get_children():
		if menu_item is Button:
			HudWidgets.style_menu_item(menu_item)
	if chat_quick_button != null:
		HudWidgets.apply_quick_button_style(chat_quick_button)
	for panel_instance in [settings_instance, chat_instance, profile_instance, memo_instance, calendar_instance, lesson_instance]:
		if panel_instance != null and is_instance_valid(panel_instance):
			UiFactory.apply_mysterious_theme(panel_instance)


# オプションの閉じるボタンが押されたら
func _on_settings_close_pressed():
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null

	menu_button.visible = true
	_refresh_nearby_talk_prompt()
	call_deferred("refresh_ui_input_policy")


func set_color_filter(mode: String):
	HudUiState.apply_color_filter($ColorFilter, mode)


func _on_logout_pressed():
	memo_button.visible = false
	if chat_quick_button != null:
		chat_quick_button.visible = false
	DjangoApi.logout_completed.connect(func():
		get_tree().change_scene_to_file("res://scenes/login.tscn")
	, CONNECT_ONE_SHOT)
	DjangoApi.logout()
