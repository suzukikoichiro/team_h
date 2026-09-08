extends RefCounted


static func auth_headers(session_cookie_header: String) -> Array:
	if session_cookie_header == "":
		return []
	return ["Cookie: %s" % session_cookie_header]


static func json_auth_headers(session_cookie_header: String) -> Array:
	var headers := ["Content-Type: application/json"]
	headers.append_array(auth_headers(session_cookie_header))
	return headers


static func post_json(
	http: HTTPRequest,
	base_url: String,
	path: String,
	payload: Dictionary,
	session_cookie_header: String,
	fail: Callable,
	start_errors: Dictionary = {},
	cancel_busy := false
) -> int:
	if cancel_busy:
		cancel_if_busy(http)
	var err := http.request(
		base_url + path,
		json_auth_headers(session_cookie_header),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	_report_start_failure(err, fail, start_errors)
	return err


static func post_raw(http: HTTPRequest, base_url: String, path: String, headers: Array, body: PackedByteArray) -> int:
	return http.request_raw(base_url + path, headers, HTTPClient.METHOD_POST, body)


static func get_auth(
	http: HTTPRequest,
	base_url: String,
	path: String,
	session_cookie_header: String,
	fail: Callable,
	start_errors: Dictionary = {},
	cancel_busy := false
) -> int:
	return get_request(http, base_url, path, fail, start_errors, cancel_busy, auth_headers(session_cookie_header))


static func get_request(
	http: HTTPRequest,
	base_url: String,
	path: String,
	fail: Callable,
	start_errors: Dictionary = {},
	cancel_busy := false,
	headers: Array = []
) -> int:
	if cancel_busy:
		cancel_if_busy(http)
	var err := http.request(base_url + path, headers, HTTPClient.METHOD_GET)
	_report_start_failure(err, fail, start_errors)
	return err


static func cancel_if_busy(http: HTTPRequest) -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http.cancel_request()


static func _report_start_failure(err: int, fail: Callable, start_errors: Dictionary) -> void:
	if err != OK and not start_errors.is_empty():
		fail.call(0, start_errors)
