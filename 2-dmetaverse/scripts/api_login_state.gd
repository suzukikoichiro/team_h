extends RefCounted

const ApiResponse := preload("res://scripts/api_response.gd")
const LOGIN_INVALID_RESPONSE_CODE := -1
const LOGIN_NOT_LOGGED_IN_CODE := 401


static func apply_to_client(client: Object, data: Dictionary) -> Dictionary:
	var state := normalized(data)
	client.set("current_user_school_id", int(state["school_id"]))
	client.set("current_user_id", int(state["user_id"]))
	client.set("current_user_position", int(state["user_position"]))
	client.set("current_user_gender", int(state["gender"]))
	client.set("current_avatar_key", str(state["avatar_key"]))
	client.set("current_username", str(state["username"]))
	Global.set_login_info(
		int(state["user_id"]),
		str(state["username"]),
		int(state["school_id"]),
		int(state["user_position"]),
		int(state["gender"]),
		str(state["avatar_key"])
	)
	return state


static func apply_login_response(
	client: Object,
	result: int,
	code: int,
	headers: Array,
	body: PackedByteArray,
	network_failed_code: int
) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		LocalLog.write("DjangoApi login network failed result=%s code=%s body=%s" % [result, code, body.get_string_from_utf8().left(300)])
		return {"ok": false, "code": network_failed_code}
	if code != 200 and code != 202 and code != 428:
		LocalLog.write("DjangoApi login failed code=%s body=%s" % [code, body.get_string_from_utf8().left(300)])
		return {"ok": false, "code": code}
	var data := ApiResponse.json_dictionary(body)
	if data.is_empty():
		LocalLog.write("DjangoApi login invalid response body=%s" % body.get_string_from_utf8().left(300))
		return {"ok": false, "code": LOGIN_INVALID_RESPONSE_CODE}

	var response_cookie := cookie_header(headers)
	if response_cookie != "":
		client.set("session_cookie_header", response_cookie)
	if code == 428 or bool(data.get("email_registration_required", false)):
		return {"ok": false, "email_registration_required": true, "data": data, "code": code}
	if code == 202 or bool(data.get("otp_required", false)):
		return {"ok": false, "otp_required": true, "data": data, "code": code}
	var state := apply_to_client(client, data)
	client.set("auto_login_done", true)
	LocalLog.write("DjangoApi login OK user=%s school=%s" % [state["user_id"], state["school_id"]])
	return {"ok": true, "data": data}


static func apply_auto_login_response(client: Object, code: int, body: PackedByteArray) -> Dictionary:
	client.set("auto_login_requesting", false)
	client.set("auto_login_done", true)

	if code != 200:
		LocalLog.write("DjangoApi auto_login failed code=%s" % code)
		return {"ok": false, "code": code}

	var data := ApiResponse.json_dictionary(body)
	if data.is_empty():
		LocalLog.write("DjangoApi auto_login invalid response")
		return {"ok": false, "code": LOGIN_INVALID_RESPONSE_CODE}

	if not data.get("logged_in", false):
		LocalLog.write("DjangoApi auto_login not logged in")
		return {"ok": false, "code": LOGIN_NOT_LOGGED_IN_CODE}

	var state := apply_to_client(client, data)
	LocalLog.write("DjangoApi auto_login OK user=%s school=%s" % [state["user_id"], state["school_id"]])
	return {"ok": true, "data": data}


static func apply_local_guest(client: Object, guest_id: int) -> Dictionary:
	var data := local_guest_data(guest_id)
	var state := apply_to_client(client, data)
	LocalLog.write("DjangoApi local guest login user=%s school=%s" % [state["user_id"], state["school_id"]])
	return data


static func reset_client(client: Object, network: Node, global_state: Node) -> void:
	client.set("auto_login_done", false)
	client.set("auto_login_requesting", false)
	client.set("session_cookie_header", "")
	client.set("current_user_school_id", -1)
	client.set("current_user_id", -1)
	client.set("current_user_position", -1)
	client.set("current_user_gender", 2)
	client.set("current_avatar_key", "skin_01")
	client.set("current_username", "")

	if network != null and network.has_method("disconnect_world"):
		network.call("disconnect_world")
	if global_state != null and global_state.has_method("clear_login_info"):
		global_state.call("clear_login_info")


static func normalized(data: Dictionary) -> Dictionary:
	var gender := int(data.get("gender", 2))
	return {
		"school_id": int(data.get("school_id", -1)),
		"user_id": int(data.get("user_id", -1)),
		"user_position": int(data.get("user_position", -1)),
		"gender": gender,
		"avatar_key": str(data.get("avatar_key", Global.default_avatar_for_gender(gender))),
		"username": str(data.get("username", "ユーザー")),
	}


static func local_guest_data(guest_id: int) -> Dictionary:
	return {
		"logged_in": true,
		"local_guest": true,
		"school_id": 1,
		"user_id": guest_id,
		"user_position": 2,
		"gender": 2,
		"avatar_key": "skin_01",
		"username": "LocalUser%s" % guest_id,
	}


static func cookie_header(headers: Array) -> String:
	var cookies: Array[String] = []
	for header in headers:
		var text := str(header)
		if text.to_lower().begins_with("set-cookie:"):
			var cookie := text.substr(text.find(":") + 1).strip_edges()
			var semicolon := cookie.find(";")
			if semicolon >= 0:
				cookie = cookie.substr(0, semicolon)
			if cookie != "":
				cookies.append(cookie)
	return "; ".join(cookies)
