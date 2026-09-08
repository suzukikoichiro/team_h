extends Node

const ApiHttpRegistry := preload("res://scripts/api_http_registry.gd")
const ApiLoginState := preload("res://scripts/api_login_state.gd")
const ApiPaths := preload("res://scripts/api_paths.gd")
const ApiLessonUpload := preload("res://scripts/api_lesson_upload.gd")
const ApiRequest := preload("res://scripts/api_request.gd")
const ApiResponse := preload("res://scripts/api_response.gd")
const ApiResponseHandlers := preload("res://scripts/api_response_handlers.gd")

@onready var auth_http: HTTPRequest = HTTPRequest.new()
@onready var login_otp_http: HTTPRequest = HTTPRequest.new()
@onready var auto_login_http: HTTPRequest = HTTPRequest.new()
@onready var logout_http: HTTPRequest = HTTPRequest.new()
@onready var chat_users_http: HTTPRequest = HTTPRequest.new()
@onready var chat_rooms_http: HTTPRequest = HTTPRequest.new()
@onready var chat_messages_http: HTTPRequest = HTTPRequest.new()
@onready var chat_save_http: HTTPRequest = HTTPRequest.new()
@onready var chat_read_http: HTTPRequest = HTTPRequest.new()
@onready var chat_clear_http: HTTPRequest = HTTPRequest.new()
@onready var profile_me_http: HTTPRequest = HTTPRequest.new()
@onready var profile_save_http: HTTPRequest = HTTPRequest.new()
@onready var profile_search_http: HTTPRequest = HTTPRequest.new()
@onready var memos_http: HTTPRequest = HTTPRequest.new()
@onready var memo_create_http: HTTPRequest = HTTPRequest.new()
@onready var memo_update_http: HTTPRequest = HTTPRequest.new()
@onready var memo_delete_http: HTTPRequest = HTTPRequest.new()
@onready var teacher_memo_targets_http: HTTPRequest = HTTPRequest.new()
@onready var teacher_memo_distribute_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_streams_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_stream_start_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_stream_end_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_comments_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_comment_post_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_recordings_http: HTTPRequest = HTTPRequest.new()
@onready var lesson_recording_post_http: HTTPRequest = HTTPRequest.new()
@onready var growth_summary_http: HTTPRequest = HTTPRequest.new()
@onready var growth_event_http: HTTPRequest = HTTPRequest.new()
@onready var account_email_http: HTTPRequest = HTTPRequest.new()

const LOGIN_REQUEST_FAILED_CODE := -9001
const LOGIN_NETWORK_FAILED_CODE := -9002
const LOGIN_TIMEOUT_SECONDS := 8.0

var auto_login_requesting: bool = false
var auto_login_done: bool = false

var current_user_school_id: int = -1
var current_user_id: int = -1
var current_user_position: int = -1
var current_user_gender: int = 2
var current_avatar_key: String = "skin_01"
var current_username: String = ""
var session_cookie_header: String = ""
var chat_messages_request_room: String = ""
var lesson_comments_request_id: int = 0

signal login_success(data)
signal login_failed(code)
signal login_otp_required(masked_email, message)
signal login_otp_failed(code, message)
signal login_email_registration_required(message)
signal request_failed(code, errors)
signal logout_completed
signal chat_users_received(users)
signal chat_rooms_received(rooms)
signal chat_messages_received(room, messages, unread_start_id)
signal chat_message_saved(message)
signal chat_history_cleared(room)
signal all_chat_history_cleared(rooms)
signal profile_received(profile)
signal profile_saved(profile)
signal profile_search_received(profiles)
signal memos_received(memos)
signal memo_saved(memo)
signal memo_deleted(id)
signal teacher_memo_targets_received(classes, students)
signal teacher_memo_distributed(created_count, targets)
signal lesson_streams_received(streams)
signal lesson_stream_saved(stream)
signal lesson_comments_received(lesson_id, comments)
signal lesson_comment_saved(comment)
signal lesson_recordings_received(recordings)
signal lesson_recording_saved(recording)
signal growth_received(growth)
signal account_email_received(email, masked_email)
signal email_change_otp_required(masked_email, message)
signal account_email_changed(email, masked_email, message)
signal email_change_failed(code, message)

func api_base() -> String:
	return AppConfig.django_api_base()


func _ready() -> void:
	auth_http.timeout = LOGIN_TIMEOUT_SECONDS
	ApiHttpRegistry.setup(self, _http_registry_entries())


func _http_registry_entries() -> Array:
	return [
		[auth_http, "_on_login_completed"],
		[login_otp_http, "_on_login_otp_completed"],
		[auto_login_http, "_on_auto_login_completed"],
		[logout_http, "_on_logout_completed"],
		[chat_users_http, "_on_chat_users_completed"],
		[chat_rooms_http, "_on_chat_rooms_completed"],
		[chat_messages_http, "_on_chat_messages_completed"],
		[chat_save_http, "_on_chat_save_completed"],
		[chat_read_http, "_on_chat_read_completed"],
		[chat_clear_http, "_on_chat_clear_completed"],
		[profile_me_http, "_on_profile_me_completed"],
		[profile_save_http, "_on_profile_save_completed"],
		[profile_search_http, "_on_profile_search_completed"],
		[memos_http, "_on_memos_completed"],
		[memo_create_http, "_on_memo_saved_completed"],
		[memo_update_http, "_on_memo_saved_completed"],
		[memo_delete_http, "_on_memo_delete_completed"],
		[teacher_memo_targets_http, "_on_teacher_memo_targets_completed"],
		[teacher_memo_distribute_http, "_on_teacher_memo_distribute_completed"],
		[lesson_streams_http, "_on_lesson_streams_completed"],
		[lesson_stream_start_http, "_on_lesson_stream_saved_completed"],
		[lesson_stream_end_http, "_on_lesson_stream_end_completed"],
		[lesson_comments_http, "_on_lesson_comments_completed"],
		[lesson_comment_post_http, "_on_lesson_comment_post_completed"],
		[lesson_recordings_http, "_on_lesson_recordings_completed"],
		[lesson_recording_post_http, "_on_lesson_recording_post_completed"],
		[growth_summary_http, "_on_growth_completed"],
		[growth_event_http, "_on_growth_completed"],
		[account_email_http, "_on_account_email_completed"],
	]

# =====================
# Auth
# =====================
func login(school_id: String, user_id: String, password: String) -> void:
	var path := ApiPaths.login()
	var url := api_base() + path
	LocalLog.write("DjangoApi login request url=%s school=%s user=%s" % [url, school_id, user_id])
	var err := _post_json(auth_http, path, ApiPaths.login_payload(school_id, user_id, password), {}, true)
	if err != OK:
		LocalLog.write("DjangoApi login request start failed err=%s url=%s" % [err, url])
		emit_signal("login_failed", LOGIN_REQUEST_FAILED_CODE)

func _on_login_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	var response := ApiLoginState.apply_login_response(self, result, code, headers, body, LOGIN_NETWORK_FAILED_CODE)
	if bool(response.get("email_registration_required", false)):
		var registration_data := response.get("data", {}) as Dictionary
		emit_signal("login_email_registration_required", str(registration_data.get("message", "メールアドレスを登録してください。")))
		return
	if bool(response.get("otp_required", false)):
		var data := response.get("data", {}) as Dictionary
		emit_signal("login_otp_required", str(data.get("masked_email", "")), str(data.get("message", "認証コードを入力してください。")))
		return
	if not bool(response.get("ok", false)):
		emit_signal("login_failed", int(response.get("code", -1)))
		return

	emit_signal("login_success", response.get("data", {}))


func verify_login_otp(code: String) -> void:
	_post_json(login_otp_http, ApiPaths.login_otp(), ApiPaths.otp_payload(code), {}, true)


func request_login_email_registration(email: String) -> void:
	_post_json(login_otp_http, ApiPaths.login_otp(), {"action": "register_email", "email": email}, {}, true)


func verify_login_email_registration(code: String) -> void:
	_post_json(login_otp_http, ApiPaths.login_otp(), {"action": "verify_enrollment", "otp_code": code}, {}, true)


func resend_login_otp() -> void:
	var payload := {"resend": true}
	if bool(get_meta("login_email_enrollment", false)):
		payload = {"action": "resend_enrollment"}
	_post_json(login_otp_http, ApiPaths.login_otp(), payload, {}, true)


func _on_login_otp_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	var response := ApiLoginState.apply_login_response(self, result, code, headers, body, LOGIN_NETWORK_FAILED_CODE)
	if bool(response.get("otp_required", false)):
		var pending_data := response.get("data", {}) as Dictionary
		set_meta("login_email_enrollment", bool(pending_data.get("email_enrollment", get_meta("login_email_enrollment", false))))
		emit_signal("login_otp_required", str(pending_data.get("masked_email", "")), str(pending_data.get("message", "認証コードを再送信しました。")))
		return
	if not bool(response.get("ok", false)):
		var error_data := ApiResponse.json_dictionary(body)
		emit_signal("login_otp_failed", int(response.get("code", -1)), str(error_data.get("message", "認証コードを確認してください。")))
		return
	set_meta("login_email_enrollment", false)
	emit_signal("login_success", response.get("data", {}))


func fetch_account_email() -> void:
	_get_auth(account_email_http, ApiPaths.account_email(), {}, true)


func request_account_email_change(email: String) -> void:
	_post_json(account_email_http, ApiPaths.account_email(), {"action": "request", "email": email}, {}, true)


func verify_account_email_change(code: String) -> void:
	_post_json(account_email_http, ApiPaths.account_email(), {"action": "verify", "otp_code": code}, {}, true)


func resend_account_email_change_otp() -> void:
	_post_json(account_email_http, ApiPaths.account_email(), {"action": "resend"}, {}, true)


func _on_account_email_completed(_result: int, code: int, _headers: Array, body: PackedByteArray) -> void:
	var data := ApiResponse.json_dictionary(body)
	if code < 200 or code >= 300:
		emit_signal("email_change_failed", code, str(data.get("message", "メールアドレスの処理に失敗しました。")))
		return
	if bool(data.get("otp_required", false)):
		emit_signal("email_change_otp_required", str(data.get("masked_email", "")), str(data.get("message", "認証コードを入力してください。")))
		return
	if data.has("message"):
		emit_signal("account_email_changed", str(data.get("email", "")), str(data.get("masked_email", "")), str(data.get("message", "")))
	else:
		emit_signal("account_email_received", str(data.get("email", "")), str(data.get("masked_email", "")))

# =====================
# Auto Login
# =====================
func auto_login():
	if auto_login_requesting or auto_login_done:
		LocalLog.write("DjangoApi auto_login skipped requesting=%s done=%s" % [auto_login_requesting, auto_login_done])
		return
	if AppConfig.is_local() and AppConfig.ENABLE_LOCAL_GUEST:
		auto_login_done = true
		_try_local_guest_login()
		return
	auto_login_requesting = true
	LocalLog.write("DjangoApi auto_login request %s" % api_base())
	_get_request(auto_login_http, ApiPaths.auto_login())

func _on_auto_login_completed(_result: int, code: int, _headers: Array, body: PackedByteArray) -> void:
	var response := ApiLoginState.apply_auto_login_response(self, code, body)
	if bool(response.get("ok", false)):
		emit_signal("login_success", response.get("data", {}))
		return
	if _try_local_guest_login():
		return
	emit_signal("login_failed", int(response.get("code", -1)))


func _try_local_guest_login() -> bool:
	if not AppConfig.is_local() or not AppConfig.ENABLE_LOCAL_GUEST:
		return false

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var guest_id: int = 100000 + rng.randi_range(1, 899999)
	var data := ApiLoginState.apply_local_guest(self, guest_id)
	emit_signal("login_success", data)
	return true


# =====================
# Logout
# =====================
func logout() -> void:
	_post_json(logout_http, ApiPaths.logout(), {})

func _on_logout_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	LocalLog.write("DjangoApi logout completed code=%s" % code)

	# 成否に関わらずローカル状態は破棄する
	_reset_login_state()

	emit_signal("logout_completed")

func _reset_login_state() -> void:
	ApiLoginState.reset_client(self, get_node_or_null("/root/Network"), get_node_or_null("/root/Global"))


func auth_headers() -> Array:
	return ApiRequest.auth_headers(session_cookie_header)


func _post_json(http: HTTPRequest, path: String, payload: Dictionary, start_errors: Dictionary = {}, cancel_busy := false) -> int:
	return ApiRequest.post_json(http, api_base(), path, payload, session_cookie_header, Callable(self, "_request_failed"), start_errors, cancel_busy)


func _post_raw(http: HTTPRequest, path: String, headers: Array, body: PackedByteArray) -> int:
	return ApiRequest.post_raw(http, api_base(), path, headers, body)


func _get_auth(http: HTTPRequest, path: String, start_errors: Dictionary = {}, cancel_busy: bool = false) -> int:
	return ApiRequest.get_auth(http, api_base(), path, session_cookie_header, Callable(self, "_request_failed"), start_errors, cancel_busy)


func _get_request(http: HTTPRequest, path: String, start_errors: Dictionary = {}, cancel_busy: bool = false, headers: Array = []) -> int:
	return ApiRequest.get_request(http, api_base(), path, Callable(self, "_request_failed"), start_errors, cancel_busy, headers)


func _request_failed(code: int, errors: Dictionary = {}) -> void:
	emit_signal("request_failed", code, errors)


func _apply_profile_avatar(profile: Dictionary, force_emit := false) -> void:
	if profile.has("avatar_key"):
		current_avatar_key = str(profile.get("avatar_key", current_avatar_key))
		Global.set_avatar_key(current_avatar_key, force_emit)


# =====================
# Chat Endpoints
# =====================
func fetch_chat_users(query: String = "") -> void:
	_get_auth(chat_users_http, ApiPaths.search_path(ApiPaths.chat_users(), query))


func fetch_chat_rooms() -> void:
	_get_auth(chat_rooms_http, ApiPaths.chat_rooms(), {"chat_rooms": "request_failed"}, true)


func fetch_chat_messages(room: String, limit: int = 100) -> void:
	chat_messages_request_room = room
	var err := _get_auth(chat_messages_http, ApiPaths.chat_messages(room, limit), {}, true)
	if err != OK:
		chat_messages_request_room = ""
		_request_failed(0, {"chat_messages": "request_failed"})


func save_chat_message(payload: Dictionary) -> void:
	_post_json(chat_save_http, ApiPaths.chat_messages_post(), payload)


func mark_chat_read(room: String) -> void:
	_post_json(chat_read_http, ApiPaths.chat_read(), ApiPaths.room_payload(room))


func clear_chat_history(room: String) -> void:
	_post_json(chat_clear_http, ApiPaths.chat_clear_history(), ApiPaths.room_payload(room))


func clear_all_chat_history() -> void:
	_post_json(chat_clear_http, ApiPaths.chat_clear_history(), ApiPaths.scope_payload("all"))


# =====================
# Profile Endpoints
# =====================
func fetch_my_profile() -> void:
	_get_auth(profile_me_http, ApiPaths.profile_me(), {"source": "profile_me", "error": "request_failed"}, true)


func save_profile(payload: Dictionary) -> void:
	_post_json(profile_save_http, ApiPaths.profile_save(), payload, {"source": "profile_save", "error": "request_failed"}, true)


func search_profiles(query: String) -> void:
	_get_auth(profile_search_http, ApiPaths.search_path(ApiPaths.profile_search(), query))


# =====================
# Memo Endpoints
# =====================
func fetch_memos(status: String = "all") -> void:
	_get_auth(memos_http, ApiPaths.memos(status))


func fetch_calendar_memos() -> void:
	_get_auth(memos_http, ApiPaths.calendar_memos())


func create_memo(text: String, status: String, scheduled_at: String = "") -> void:
	_post_json(memo_create_http, ApiPaths.memos_create(), ApiPaths.memo_create_payload(text, status, scheduled_at))


func update_memo(id: int, payload: Dictionary) -> void:
	payload["id"] = id
	_post_json(memo_update_http, ApiPaths.memos_update(), payload)


func delete_memo(id: int) -> void:
	_post_json(memo_delete_http, ApiPaths.memos_delete(), ApiPaths.id_payload(id))


func fetch_teacher_memo_targets() -> void:
	_get_auth(teacher_memo_targets_http, ApiPaths.teacher_memo_targets())


func distribute_teacher_memo(payload: Dictionary) -> void:
	_post_json(teacher_memo_distribute_http, ApiPaths.teacher_memo_distribute(), payload)


# =====================
# Lesson Endpoints
# =====================
func fetch_lesson_streams() -> void:
	_get_auth(lesson_streams_http, ApiPaths.lesson_streams())


func start_lesson_stream(payload: Dictionary) -> void:
	_post_json(lesson_stream_start_http, ApiPaths.lesson_streams_start(), payload)


func end_lesson_stream(lesson_id: int, recording_url: String) -> void:
	_post_json(lesson_stream_end_http, ApiPaths.lesson_streams_end(), ApiPaths.lesson_stream_end_payload(lesson_id, recording_url))


func fetch_lesson_comments(lesson_id: int) -> void:
	lesson_comments_request_id = lesson_id
	_get_auth(lesson_comments_http, ApiPaths.lesson_comments(lesson_id))


func post_lesson_comment(lesson_id: int, message: String) -> void:
	_post_json(lesson_comment_post_http, ApiPaths.lesson_comments_post(), ApiPaths.lesson_comment_payload(lesson_id, message))


func fetch_lesson_recordings() -> void:
	_get_auth(lesson_recordings_http, ApiPaths.lesson_recordings())


func post_lesson_recording(payload: Dictionary) -> void:
	_post_json(lesson_recording_post_http, ApiPaths.lesson_recordings_post(), payload)


func upload_lesson_recording_file(title: String, description: String, file_path: String, lesson_id: int = 0) -> void:
	var upload := ApiLessonUpload.recording_request(title, description, file_path, lesson_id, auth_headers())
	if not bool(upload["ok"]):
		_request_failed(0, upload.get("errors", {}))
		return
	var headers: Array = upload["headers"]
	var body: PackedByteArray = upload["body"]
	_post_raw(lesson_recording_post_http, str(upload["path"]), headers, body)


# =====================
# Growth Endpoints
# =====================
func fetch_growth_summary() -> void:
	_get_auth(growth_summary_http, ApiPaths.growth_summary(), {}, true)


func record_growth_event(event_type: String, target_id: int) -> void:
	_post_json(growth_event_http, ApiPaths.growth_event(), ApiPaths.growth_event_payload(event_type, target_id))

func _on_chat_users_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "chat_users_received", "users", [])


func _on_chat_rooms_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "chat_rooms_received", "rooms", [])


func _on_chat_messages_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	var requested_room := chat_messages_request_room
	chat_messages_request_room = ""
	ApiResponseHandlers.chat_messages(self, code, body, requested_room)


func _on_chat_save_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.chat_saved(self, code, body, Callable(self, "fetch_growth_summary"))


func _on_chat_read_completed(_result: int, _code: int, _headers: Array, _body: PackedByteArray) -> void:
	pass


func _on_chat_clear_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.chat_clear(self, code, body)


func _on_profile_me_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.profile(self, code, body, "profile_me", "profile_received", Callable(self, "_apply_profile_avatar"))


func _on_profile_save_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.profile(self, code, body, "profile_save", "profile_saved", Callable(self, "_apply_profile_avatar"), true, true)


func _on_profile_search_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "profile_search_received", "profiles", [])


func _on_memos_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "memos_received", "memos", [])


func _on_memo_saved_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "memo_saved", "memo", {})


func _on_memo_delete_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_fields(self, code, body, "memo_deleted", [["id", 0, "int"]])


func _on_teacher_memo_targets_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_fields(self, code, body, "teacher_memo_targets_received", [["classes", []], ["students", []]])


func _on_teacher_memo_distribute_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_fields(self, code, body, "teacher_memo_distributed", [["created_count", 0, "int"], ["targets", []]], true)


func _on_lesson_streams_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "lesson_streams_received", "streams", [])


func _on_lesson_stream_saved_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "lesson_stream_saved", "stream", {}, true)


func _on_lesson_stream_end_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.lesson_stream_end(self, code, body)


func _on_lesson_comments_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	var requested_id := lesson_comments_request_id
	ApiResponseHandlers.emit_fields(self, code, body, "lesson_comments_received", [["lesson_id", requested_id, "int"], ["comments", []]])


func _on_lesson_comment_post_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "lesson_comment_saved", "comment", {}, true)


func _on_lesson_recordings_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "lesson_recordings_received", "links", [])


func _on_lesson_recording_post_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "lesson_recording_saved", "link", {}, true)


func _on_growth_completed(result: int, code: int, headers: Array, body: PackedByteArray) -> void:
	ApiResponseHandlers.emit_field(self, code, body, "growth_received", "growth", {})
