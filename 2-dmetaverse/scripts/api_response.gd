extends RefCounted


static func json_dictionary(body: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func dictionary_or_fail(code: int, body: PackedByteArray, fail: Callable, errors: Dictionary = {}) -> Dictionary:
	if code != 200:
		fail.call(code, errors)
		return {}
	return json_dictionary(body)


static func dictionary_or_fail_with_body(code: int, body: PackedByteArray, fail: Callable) -> Dictionary:
	var data := json_dictionary(body)
	if code != 200:
		fail.call(code, data)
		return {}
	return data


static func emit_field(owner: Object, code: int, body: PackedByteArray, fail: Callable, signal_name: String, field_name: String, fallback: Variant, include_body_errors := false) -> Dictionary:
	var data := dictionary_or_fail_with_body(code, body, fail) if include_body_errors else dictionary_or_fail(code, body, fail)
	if not data.is_empty():
		owner.emit_signal(signal_name, data.get(field_name, fallback))
	return data


static func emit_signal_fields(owner: Object, code: int, body: PackedByteArray, fail: Callable, signal_name: String, specs: Array, include_body_errors := false) -> Dictionary:
	var data := dictionary_or_fail_with_body(code, body, fail) if include_body_errors else dictionary_or_fail(code, body, fail)
	if data.is_empty():
		return data
	var args: Array = [signal_name]
	for spec in specs:
		var value: Variant = data.get(spec[0], spec[1])
		if spec.size() >= 3:
			match str(spec[2]):
				"int":
					value = int(value)
				"string":
					value = str(value)
		args.append(value)
	Callable(owner, "emit_signal").callv(args)
	return data


static func emit_chat_messages(owner: Object, data: Dictionary, requested_room: String) -> void:
	if data.is_empty():
		return
	var response_room := str(data.get("room", requested_room))
	if requested_room != "" and response_room != requested_room:
		return
	owner.emit_signal(
		"chat_messages_received",
		response_room,
		data.get("messages", []),
		str(data.get("unread_start_id", ""))
	)


static func emit_chat_clear(owner: Object, data: Dictionary) -> void:
	if data.is_empty():
		return
	if str(data.get("scope", "")) == "all":
		owner.emit_signal("all_chat_history_cleared", data.get("rooms", []))
		return
	owner.emit_signal("chat_history_cleared", str(data.get("room", "")))


static func emit_chat_saved(owner: Object, data: Dictionary, growth_follow_up: Callable) -> void:
	if data.is_empty():
		return
	owner.emit_signal("chat_message_saved", data.get("message", {}))
	if Global.is_student():
		growth_follow_up.call()


static func emit_profile(owner: Object, data: Dictionary, signal_name: String, apply_avatar: Callable, force_avatar_emit := false) -> void:
	if data.is_empty():
		return
	var profile: Dictionary = data.get("profile", {})
	apply_avatar.call(profile, force_avatar_emit)
	owner.emit_signal(signal_name, profile)


static func emit_lesson_stream_end(owner: Object, data: Dictionary) -> void:
	if data.is_empty():
		return
	owner.emit_signal("lesson_stream_saved", data.get("stream", {}))
	if data.get("recording", null) != null:
		owner.emit_signal("lesson_recording_saved", data.get("recording", {}))


static func profile_or_fail(code: int, body: PackedByteArray, fail: Callable, source: String, include_body_errors := false) -> Dictionary:
	var data := json_dictionary(body)
	if code != 200:
		LocalLog.write("%s failed code=%s body=%s" % [source, code, body.get_string_from_utf8().left(300)])
		var errors: Dictionary = data if include_body_errors else {}
		errors["source"] = source
		fail.call(code, errors)
		return {}
	return data
