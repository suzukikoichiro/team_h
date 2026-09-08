extends RefCounted

const ApiResponse := preload("res://scripts/api_response.gd")


static func emit_field(client: Object, code: int, body: PackedByteArray, signal_name: String, field_name: String, fallback: Variant, include_body_errors := false) -> void:
	ApiResponse.emit_field(client, code, body, Callable(client, "_request_failed"), signal_name, field_name, fallback, include_body_errors)


static func emit_fields(client: Object, code: int, body: PackedByteArray, signal_name: String, specs: Array, include_body_errors := false) -> void:
	ApiResponse.emit_signal_fields(client, code, body, Callable(client, "_request_failed"), signal_name, specs, include_body_errors)


static func chat_messages(client: Object, code: int, body: PackedByteArray, requested_room: String) -> void:
	var data := ApiResponse.dictionary_or_fail(code, body, Callable(client, "_request_failed"))
	ApiResponse.emit_chat_messages(client, data, requested_room)


static func chat_saved(client: Object, code: int, body: PackedByteArray, growth_follow_up: Callable) -> void:
	var data := ApiResponse.dictionary_or_fail(code, body, Callable(client, "_request_failed"))
	ApiResponse.emit_chat_saved(client, data, growth_follow_up)


static func chat_clear(client: Object, code: int, body: PackedByteArray) -> void:
	var data := ApiResponse.dictionary_or_fail(code, body, Callable(client, "_request_failed"))
	ApiResponse.emit_chat_clear(client, data)


static func profile(client: Object, code: int, body: PackedByteArray, source: String, signal_name: String, apply_avatar: Callable, force_avatar_emit := false, include_body_errors := false) -> void:
	var data := ApiResponse.profile_or_fail(code, body, Callable(client, "_request_failed"), source, include_body_errors)
	ApiResponse.emit_profile(client, data, signal_name, apply_avatar, force_avatar_emit)


static func lesson_stream_end(client: Object, code: int, body: PackedByteArray) -> void:
	var data := ApiResponse.dictionary_or_fail_with_body(code, body, Callable(client, "_request_failed"))
	ApiResponse.emit_lesson_stream_end(client, data)
