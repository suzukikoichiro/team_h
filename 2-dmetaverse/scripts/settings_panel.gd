extends Control

signal close_pressed

const SettingsChatOptions := preload("res://scripts/settings_chat_options.gd")
const UiFactory := preload("res://scripts/ui_factory.gd")

@onready var close_button: Button = $VBoxContainer/CloseButton
@onready var color_option_button: OptionButton = $VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox/ColorOption/ColorOptionButton
@onready var sound_button: Button = $VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox/SoundOption/SoundButton
@onready var root_box: VBoxContainer = $VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox

var color_filter: ColorRect = null
var previous_volume_db := 0.0
var sound_enabled := true
var chat_scope_option: OptionButton
var chat_target_input: LineEdit
var chat_limit_option: OptionButton
var enter_send_check: CheckBox
var nearby_chat_block_check: CheckBox
var status_label: Label
var confirm_dialog: ConfirmationDialog
var email_current_label: Label
var email_input: LineEdit
var email_otp_input: LineEdit
var email_request_button: Button
var email_verify_button: Button
var email_resend_button: Button
var email_status_label: Label

func _ready():
	color_filter = get_node_or_null("../ColorFilter")
	var master_bus := AudioServer.get_bus_index("Master")
	var current_db := AudioServer.get_bus_volume_db(master_bus)
	
	# dB → 0～100 に逆変換
	var linear := db_to_linear(current_db)
	$VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox/SoundOption/HSlider.value = linear * 100.0

	# 画面サイズに合わせて、常に余白内に収めて中央に配置する。
	_fit_to_viewport()
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)

	# ボタン類のシグナル接続
	close_button.pressed.connect(_on_close_pressed)
	color_option_button.item_selected.connect(_on_color_selected)
	_build_extra_options()
	_apply_theme()
	if not Global.ui_theme_changed.is_connected(_on_ui_theme_changed):
		Global.ui_theme_changed.connect(_on_ui_theme_changed)
	if DjangoApi.has_signal("chat_history_cleared") and not DjangoApi.chat_history_cleared.is_connected(_on_chat_history_cleared):
		DjangoApi.chat_history_cleared.connect(_on_chat_history_cleared)
	if DjangoApi.has_signal("all_chat_history_cleared") and not DjangoApi.all_chat_history_cleared.is_connected(_on_all_chat_history_cleared):
		DjangoApi.all_chat_history_cleared.connect(_on_all_chat_history_cleared)
	if DjangoApi.has_signal("request_failed") and not DjangoApi.request_failed.is_connected(_on_request_failed):
		DjangoApi.request_failed.connect(_on_request_failed)
	_connect_email_signals()
	if Global.is_teacher():
		DjangoApi.fetch_account_email()

# 色覚設定の処理
func _on_color_selected(index):
	if color_filter == null:
		return
	match index:
		0:
			color_filter.color = Color(1, 1, 1, 0)  # 通常
		1:
			color_filter.color = Color(0.6, 1.0, 1.0, 0.35)  # 赤弱
		2:
			color_filter.color = Color(1.0, 0.6, 1.0, 0.35)  # 緑弱
		3:
			color_filter.color = Color(1.0, 1.0, 0.6, 0.35)  # 青弱


func _on_ui_theme_changed(_theme: String) -> void:
	_apply_theme()


func _apply_theme() -> void:
	UiFactory.apply_mysterious_theme(self)
	var background := $ColorRect as Panel
	background.add_theme_stylebox_override(
		"panel",
		UiFactory.style(
			Color(0.055, 0.07, 0.12, 0.985) if Global.ui_theme == "dark" else Color(0.96, 0.975, 1.0, 0.99),
			Color(0.38, 0.56, 0.8, 0.85) if Global.ui_theme == "dark" else Color(0.55, 0.65, 0.78, 0.9),
			18,
			1
		)
	)
	var content_panel := $VBoxContainer/ContentPanel as PanelContainer
	content_panel.add_theme_stylebox_override(
		"panel",
		UiFactory.style(
			Color(0.08, 0.1, 0.16, 0.82) if Global.ui_theme == "dark" else Color(1.0, 1.0, 1.0, 0.9),
			Color(0.26, 0.36, 0.5, 0.72) if Global.ui_theme == "dark" else Color(0.72, 0.78, 0.86, 0.9),
			12,
			1
		)
	)


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	UiFactory.fit_centered_panel(self, viewport_size, Vector2(760, 700), 48.0)


# 閉じる処理
func _on_close_pressed():
	emit_signal("close_pressed")


func _on_h_slider_value_changed(value: float) -> void:
	var db = linear_to_db(value / 100.0)
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, db)


func _on_sound_button_pressed() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	
	if sound_enabled:
		# 今の音量を保存してミュート
		previous_volume_db = AudioServer.get_bus_volume_db(master_bus)
		AudioServer.set_bus_volume_db(master_bus, -80) # 完全ミュート
		sound_enabled = false
		sound_button.text = "音声をオン"
		
		# スライダーも 0 に（同期のため）
		$VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox/SoundOption/HSlider.value = 0

	else:
		# 保存しておいた音量に戻す
		AudioServer.set_bus_volume_db(master_bus, previous_volume_db)
		sound_enabled = true
		sound_button.text = "ミュート"
		
		# スライダーの値を反映（dB→0~100）
		$VBoxContainer/ContentPanel/ScrollContainer/ContentMargin/ContentBox/SoundOption/HSlider.value = db_to_linear(previous_volume_db) * 100.0
		
		get_node("/root/Main/BGMPlayer").play()

func _build_extra_options() -> void:
	var controls := SettingsChatOptions.build(root_box, self, Global, _on_chat_scope_selected, _confirm_clear_history, _clear_history)
	enter_send_check = controls["enter_send_check"] as CheckBox
	nearby_chat_block_check = controls["nearby_chat_block_check"] as CheckBox
	chat_limit_option = controls["chat_limit_option"] as OptionButton
	chat_scope_option = controls["chat_scope_option"] as OptionButton
	chat_target_input = controls["chat_target_input"] as LineEdit
	status_label = controls["status_label"] as Label
	confirm_dialog = controls["confirm_dialog"] as ConfirmationDialog
	if Global.is_teacher():
		_build_email_options()
	Global.apply_text_scale_to_tree()


func _build_email_options() -> void:
	var title := Label.new()
	title.text = "メールアドレス変更"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.56, 0.76, 1.0))
	root_box.add_child(title)

	email_current_label = Label.new()
	email_current_label.text = "現在のメールアドレスを取得中..."
	root_box.add_child(email_current_label)

	email_input = LineEdit.new()
	email_input.placeholder_text = "新しいメールアドレス"
	email_input.custom_minimum_size = Vector2(320, 38)
	email_request_button = Button.new()
	email_request_button.text = "認証コードを送信"
	email_request_button.custom_minimum_size = Vector2(180, 38)
	email_request_button.pressed.connect(_request_email_change)
	var request_row := HBoxContainer.new()
	request_row.add_theme_constant_override("separation", 10)
	request_row.add_child(email_input)
	request_row.add_child(email_request_button)
	root_box.add_child(request_row)

	email_otp_input = LineEdit.new()
	email_otp_input.placeholder_text = "6桁の認証コード"
	email_otp_input.max_length = 6
	email_otp_input.custom_minimum_size = Vector2(210, 38)
	email_otp_input.visible = false
	email_verify_button = Button.new()
	email_verify_button.text = "認証して変更"
	email_verify_button.custom_minimum_size = Vector2(150, 38)
	email_verify_button.visible = false
	email_verify_button.pressed.connect(_verify_email_change)
	email_resend_button = Button.new()
	email_resend_button.text = "再送信"
	email_resend_button.custom_minimum_size = Vector2(100, 38)
	email_resend_button.visible = false
	email_resend_button.pressed.connect(_resend_email_change)
	var otp_row := HBoxContainer.new()
	otp_row.add_theme_constant_override("separation", 10)
	otp_row.add_child(email_otp_input)
	otp_row.add_child(email_verify_button)
	otp_row.add_child(email_resend_button)
	root_box.add_child(otp_row)

	email_status_label = Label.new()
	email_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(email_status_label)


func _connect_email_signals() -> void:
	if DjangoApi.has_signal("account_email_received") and not DjangoApi.account_email_received.is_connected(_on_account_email_received):
		DjangoApi.account_email_received.connect(_on_account_email_received)
	if DjangoApi.has_signal("email_change_otp_required") and not DjangoApi.email_change_otp_required.is_connected(_on_email_change_otp_required):
		DjangoApi.email_change_otp_required.connect(_on_email_change_otp_required)
	if DjangoApi.has_signal("account_email_changed") and not DjangoApi.account_email_changed.is_connected(_on_account_email_changed):
		DjangoApi.account_email_changed.connect(_on_account_email_changed)
	if DjangoApi.has_signal("email_change_failed") and not DjangoApi.email_change_failed.is_connected(_on_email_change_failed):
		DjangoApi.email_change_failed.connect(_on_email_change_failed)


func _request_email_change() -> void:
	var email := email_input.text.strip_edges()
	if email == "" or not email.contains("@"):
		email_status_label.text = "正しいメールアドレスを入力してください。"
		return
	_set_email_controls_disabled(true)
	email_status_label.text = "認証コードを送信しています..."
	DjangoApi.request_account_email_change(email)


func _verify_email_change() -> void:
	var code := email_otp_input.text.strip_edges()
	if code.length() != 6 or not code.is_valid_int():
		email_status_label.text = "6桁の認証コードを入力してください。"
		return
	_set_email_controls_disabled(true)
	email_status_label.text = "認証中..."
	DjangoApi.verify_account_email_change(code)


func _resend_email_change() -> void:
	_set_email_controls_disabled(true)
	email_status_label.text = "認証コードを再送信しています..."
	DjangoApi.resend_account_email_change_otp()


func _on_account_email_received(email: String, _masked_email: String) -> void:
	if email_current_label != null:
		email_current_label.text = "現在: %s" % email


func _on_email_change_otp_required(masked_email: String, message: String) -> void:
	if email_otp_input == null:
		return
	email_otp_input.visible = true
	email_verify_button.visible = true
	email_resend_button.visible = true
	email_status_label.text = "%s 送信先: %s" % [message, masked_email]
	_set_email_controls_disabled(false)
	email_otp_input.grab_focus()


func _on_account_email_changed(email: String, _masked_email: String, message: String) -> void:
	if email_current_label == null:
		return
	email_current_label.text = "現在: %s" % email
	email_input.text = ""
	email_otp_input.text = ""
	email_otp_input.visible = false
	email_verify_button.visible = false
	email_resend_button.visible = false
	email_status_label.text = message
	_set_email_controls_disabled(false)


func _on_email_change_failed(_code: int, message: String) -> void:
	if email_status_label != null:
		email_status_label.text = message
		_set_email_controls_disabled(false)


func _set_email_controls_disabled(disabled: bool) -> void:
	if email_input != null:
		email_input.editable = not disabled
	if email_request_button != null:
		email_request_button.disabled = disabled
	if email_otp_input != null:
		email_otp_input.editable = not disabled
	if email_verify_button != null:
		email_verify_button.disabled = disabled
	if email_resend_button != null:
		email_resend_button.disabled = disabled


func _on_chat_scope_selected(index: int) -> void:
	chat_target_input.visible = chat_scope_option.get_item_id(index) == 1


func _confirm_clear_history() -> void:
	var room := _selected_chat_room()
	if room == "":
		status_label.text = "個人チャットは相手のユーザーIDを入力してください"
		return
	confirm_dialog.popup_centered()


func _clear_history() -> void:
	var selected_id := chat_scope_option.get_item_id(chat_scope_option.selected)
	if selected_id == 2:
		status_label.text = "すべての履歴を削除中..."
		if DjangoApi.has_method("clear_all_chat_history"):
			DjangoApi.clear_all_chat_history()
		return
	var room := _selected_chat_room()
	if room == "":
		status_label.text = "削除対象を選択してください"
		return
	status_label.text = "履歴を削除中..."
	if DjangoApi.has_method("clear_chat_history"):
		DjangoApi.clear_chat_history(room)


func _selected_chat_room() -> String:
	return SettingsChatOptions.selected_chat_room(chat_scope_option, chat_target_input, Global)


func _on_chat_history_cleared(room: String) -> void:
	status_label.text = "履歴を削除しました"


func _on_all_chat_history_cleared(rooms: Array) -> void:
	status_label.text = "すべての履歴を削除しました"


func _on_request_failed(code: int, errors = {}) -> void:
	status_label.text = "通信に失敗しました: %s" % code
