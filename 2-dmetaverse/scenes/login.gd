extends CanvasLayer

@export var next_scene_path := "res://scenes/school_commute.tscn"

const LoginMoodPanel := preload("res://scripts/login_mood_panel.gd")

@onready var school_input: LineEdit = $Dim/LoginPanel/Margin/RootVBox/SchoolInput
@onready var user_input: LineEdit = $Dim/LoginPanel/Margin/RootVBox/UserInput
@onready var password_input: LineEdit = $Dim/LoginPanel/Margin/RootVBox/PasswordInput
@onready var email_input: LineEdit = $Dim/LoginPanel/Margin/RootVBox/EmailInput
@onready var otp_input: LineEdit = $Dim/LoginPanel/Margin/RootVBox/OtpInput
@onready var resend_otp_button: Button = $Dim/LoginPanel/Margin/RootVBox/ResendOtpButton
@onready var remember_check: CheckBox = $Dim/LoginPanel/Margin/RootVBox/RememberCheck
@onready var login_button: Button = $Dim/LoginPanel/Margin/RootVBox/LoginButton
@onready var message_label: Label = $Dim/LoginPanel/Margin/RootVBox/MessageLabel

const SAVED_LOGIN_PATH := "user://saved_login.cfg"

var logging_in := false
var placeholders := {}
var mood_panel: PanelContainer = null
var selected_mood := "fine"
var awaiting_otp := false
var enrolling_email := false
var enrollment_otp := false

func _ready() -> void:
	if Global.is_logged_in:
		_go_to_metaverse()
		return
	visible = not Global.is_logged_in
	_setup_focus_placeholders()
	_load_saved_login()
	login_button.pressed.connect(_on_login_pressed)
	password_input.text_submitted.connect(func(_text: String): _on_login_pressed())
	otp_input.text_submitted.connect(func(_text: String): _on_login_pressed())
	resend_otp_button.pressed.connect(_on_resend_otp_pressed)
	user_input.text_submitted.connect(func(_text: String): password_input.grab_focus())
	school_input.text_submitted.connect(func(_text: String): user_input.grab_focus())
	DjangoApi.login_success.connect(_on_login_success)
	DjangoApi.login_failed.connect(_on_login_failed)
	DjangoApi.login_otp_required.connect(_on_login_otp_required)
	DjangoApi.login_otp_failed.connect(_on_login_otp_failed)
	DjangoApi.login_email_registration_required.connect(_on_login_email_registration_required)
	_update_button_state()


func _on_login_pressed() -> void:
	if logging_in:
		return
	if enrolling_email:
		var email := email_input.text.strip_edges()
		if email == "" or not email.contains("@"):
			_show_message("正しいメールアドレスを入力してください。")
			return
		logging_in = true
		_update_button_state()
		_show_message("認証コードを送信しています...")
		DjangoApi.request_login_email_registration(email)
		return
	if awaiting_otp:
		var otp_code := otp_input.text.strip_edges()
		if otp_code.length() != 6 or not otp_code.is_valid_int():
			_show_message("6桁の認証コードを入力してください。")
			return
		logging_in = true
		_update_button_state()
		_show_message("認証中...")
		if enrollment_otp:
			DjangoApi.verify_login_email_registration(otp_code)
		else:
			DjangoApi.verify_login_otp(otp_code)
		return
	var school_id := school_input.text.strip_edges()
	var user_id := user_input.text.strip_edges()
	var password := password_input.text
	if school_id.is_empty() or user_id.is_empty() or password.is_empty():
		_show_message("学校ID、ユーザーID、パスワードを入力してください。")
		return
	logging_in = true
	login_button.disabled = true
	_show_message("ログイン中...")
	DjangoApi.login(school_id, user_id, password)


func _on_login_success(_data: Dictionary) -> void:
	logging_in = false
	awaiting_otp = false
	enrolling_email = false
	enrollment_otp = false
	_update_saved_login()
	_show_message("")
	if Global.is_student():
		_show_mood_panel()
		return
	_finish_login_with_mood("fine", "all")


func _on_login_failed(code: int) -> void:
	logging_in = false
	_update_button_state()
	if code == 401:
		_show_message("学校ID、ユーザーID、またはパスワードが違います。")
	elif code == 400:
		_show_message("入力内容を確認してください。")
	elif code == DjangoApi.LOGIN_REQUEST_FAILED_CODE or code == DjangoApi.LOGIN_NETWORK_FAILED_CODE or code == 0:
		_show_message("Djangoサーバーに接続できません。127.0.0.1:8000 の起動を確認してください。")
	else:
		_show_message("ログインできませんでした。Djangoサーバーを確認してください。 code=%s" % code)


func _on_login_otp_required(masked_email: String, message: String) -> void:
	logging_in = false
	awaiting_otp = true
	enrollment_otp = enrolling_email or enrollment_otp
	enrolling_email = false
	password_input.visible = false
	email_input.visible = false
	otp_input.visible = true
	resend_otp_button.visible = true
	login_button.text = "認証してログイン"
	otp_input.grab_focus()
	_show_message("%s\n送信先: %s" % [message, masked_email] if masked_email != "" else message)
	_update_button_state()


func _on_login_email_registration_required(message: String) -> void:
	logging_in = false
	enrolling_email = true
	password_input.visible = false
	email_input.visible = true
	login_button.text = "認証コードを送信"
	email_input.grab_focus()
	_show_message(message)
	_update_button_state()


func _on_login_otp_failed(_code: int, message: String) -> void:
	logging_in = false
	_show_message(message)
	_update_button_state()


func _on_resend_otp_pressed() -> void:
	if logging_in or not awaiting_otp:
		return
	logging_in = true
	_update_button_state()
	_show_message("認証コードを再送信しています...")
	DjangoApi.resend_login_otp()


func _show_message(text: String) -> void:
	message_label.text = text


func _update_button_state() -> void:
	login_button.disabled = logging_in
	resend_otp_button.disabled = logging_in


func _go_to_metaverse() -> void:
	get_tree().change_scene_to_file(next_scene_path)


func _finish_login_with_mood(mood: String, permission: String) -> void:
	Global.set_daily_mood(mood, permission)
	visible = false
	_go_to_metaverse()


func _show_mood_panel() -> void:
	if mood_panel != null and is_instance_valid(mood_panel):
		mood_panel.queue_free()
	mood_panel = LoginMoodPanel.build(_finish_login_with_mood, _show_permission_choices)
	add_child(mood_panel)


func _show_permission_choices(mood: String) -> void:
	selected_mood = mood
	LoginMoodPanel.show_permission_choices(mood_panel, selected_mood, _finish_login_with_mood)


func _setup_focus_placeholders() -> void:
	var inputs: Array[LineEdit] = [school_input, user_input, password_input, email_input, otp_input]
	for input in inputs:
		placeholders[input] = input.placeholder_text
		input.focus_entered.connect(_on_input_focus_entered.bind(input))
		input.focus_exited.connect(_on_input_focus_exited.bind(input))


func _on_input_focus_entered(input: LineEdit) -> void:
	input.placeholder_text = ""


func _on_input_focus_exited(input: LineEdit) -> void:
	if input.text.strip_edges() == "":
		input.placeholder_text = str(placeholders.get(input, ""))


func _load_saved_login() -> void:
	var config := ConfigFile.new()
	if config.load(SAVED_LOGIN_PATH) != OK:
		return
	remember_check.button_pressed = bool(config.get_value("login", "remember", false))
	# 設定が無効でも、旧版が残した秘密情報は必ず消去する。
	if config.has_section_key("login", "password"):
		config.erase_section_key("login", "password")
		config.save(SAVED_LOGIN_PATH)
	if not remember_check.button_pressed:
		return
	school_input.text = str(config.get_value("login", "school_id", ""))
	user_input.text = str(config.get_value("login", "user_id", ""))


func _update_saved_login() -> void:
	if not remember_check.button_pressed:
		if FileAccess.file_exists(SAVED_LOGIN_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_LOGIN_PATH))
		return
	var config := ConfigFile.new()
	config.set_value("login", "remember", true)
	config.set_value("login", "school_id", school_input.text.strip_edges())
	config.set_value("login", "user_id", user_input.text.strip_edges())
	if config.has_section_key("login", "password"):
		config.erase_section_key("login", "password")
	config.save(SAVED_LOGIN_PATH)
