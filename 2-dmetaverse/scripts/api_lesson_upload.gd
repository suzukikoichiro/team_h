extends RefCounted

const ApiMultipart := preload("res://scripts/api_multipart.gd")
const ApiPaths := preload("res://scripts/api_paths.gd")


static func recording_request(title: String, description: String, file_path: String, lesson_id: int, auth_headers: Array) -> Dictionary:
	var file_bytes := FileAccess.get_file_as_bytes(file_path)
	if file_bytes.is_empty():
		return {
			"ok": false,
			"errors": {"video_file": "file_empty"},
		}
	var upload := ApiMultipart.lesson_recording(title, description, file_path, file_bytes, lesson_id)
	var headers: Array = upload["headers"]
	headers.append_array(auth_headers)
	return {
		"ok": true,
		"path": ApiPaths.lesson_recordings_post(),
		"headers": headers,
		"body": upload["body"],
	}
