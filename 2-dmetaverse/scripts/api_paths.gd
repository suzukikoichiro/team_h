extends RefCounted


static func search_path(base_path: String, query: String) -> String:
	var trimmed := query.strip_edges()
	if trimmed == "":
		return base_path
	return "%s?q=%s" % [base_path, trimmed.uri_encode()]


static func auto_login() -> String:
	return "/api/godot_auto_login/"


static func login() -> String:
	return "/api/login/"


static func login_otp() -> String:
	return "/api/login/otp/"


static func account_email() -> String:
	return "/api/account/email/"


static func logout() -> String:
	return "/api/logout/"


static func nakama_session() -> String:
	return "/api/nakama_session/"


static func chat_users() -> String:
	return "/api/chat_users/"


static func chat_rooms() -> String:
	return "/api/chat_rooms/"


static func chat_messages(room: String, limit: int) -> String:
	return "/api/chat_messages/?room=%s&limit=%d" % [room.uri_encode(), limit]


static func chat_messages_post() -> String:
	return "/api/chat_messages/post/"


static func chat_read() -> String:
	return "/api/chat_read/"


static func chat_clear_history() -> String:
	return "/api/chat_clear_history/"


static func profile_me() -> String:
	return "/api/profile/me/"


static func profile_save() -> String:
	return "/api/profile/save/"


static func profile_search() -> String:
	return "/api/profile/search/"


static func memos(status: String = "all") -> String:
	if status == "" or status == "all":
		return "/api/memos/"
	return "/api/memos/?status=%s" % status.uri_encode()


static func calendar_memos() -> String:
	return "/api/memos/?status=planned&scheduled=1"


static func memos_create() -> String:
	return "/api/memos/create/"


static func memos_update() -> String:
	return "/api/memos/update/"


static func memos_delete() -> String:
	return "/api/memos/delete/"


static func teacher_memo_targets() -> String:
	return "/api/memos/teacher_targets/"


static func teacher_memo_distribute() -> String:
	return "/api/memos/teacher_distribute/"


static func lesson_streams() -> String:
	return "/api/lessons/streams/"


static func lesson_streams_start() -> String:
	return "/api/lessons/streams/start/"


static func lesson_streams_end() -> String:
	return "/api/lessons/streams/end/"


static func lesson_comments(lesson_id: int) -> String:
	return "/api/lessons/comments/?lesson_id=%d" % lesson_id


static func lesson_comments_post() -> String:
	return "/api/lessons/comments/post/"


static func lesson_recordings() -> String:
	return "/api/lessons/links/"


static func lesson_recordings_post() -> String:
	return "/api/lessons/links/post/"


static func growth_summary() -> String:
	return "/api/growth/summary/"


static func growth_event() -> String:
	return "/api/growth/event/"


static func memo_create_payload(text: String, status: String, scheduled_at: String = "") -> Dictionary:
	var payload := {"text": text, "status": status}
	if scheduled_at != "":
		payload["scheduled_at"] = scheduled_at
	return payload


static func login_payload(school_id: String, user_id: String, password: String) -> Dictionary:
	return {"school_id": school_id, "user_id": user_id, "password": password}


static func otp_payload(code: String) -> Dictionary:
	return {"otp_code": code}


static func id_payload(id: int) -> Dictionary:
	return {"id": id}


static func room_payload(room: String) -> Dictionary:
	return {"room": room}


static func scope_payload(scope: String) -> Dictionary:
	return {"scope": scope}


static func lesson_stream_end_payload(lesson_id: int, recording_url: String) -> Dictionary:
	return {"id": lesson_id, "recording_url": recording_url}


static func lesson_comment_payload(lesson_id: int, message: String) -> Dictionary:
	return {"lesson_id": lesson_id, "message": message}


static func growth_event_payload(event_type: String, target_id: int) -> Dictionary:
	return {"event_type": event_type, "target_id": target_id}
