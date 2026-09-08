extends RefCounted


static func lesson_recording(title: String, description: String, file_path: String, file_bytes: PackedByteArray, lesson_id: int = 0) -> Dictionary:
	var boundary := "----GodotLessonBoundary%s" % Time.get_ticks_msec()
	var body := PackedByteArray()
	append_text(body, boundary, "title", title)
	append_text(body, boundary, "description", description)
	if lesson_id > 0:
		append_text(body, boundary, "lesson_id", str(lesson_id))
	append_file(body, boundary, "video_file", file_path.get_file(), file_bytes)
	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())
	return {
		"headers": ["Content-Type: multipart/form-data; boundary=%s" % boundary],
		"body": body,
	}


static func append_text(body: PackedByteArray, boundary: String, field_name: String, value: String) -> void:
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"%s\"\r\n\r\n" % field_name).to_utf8_buffer())
	body.append_array(("%s\r\n" % value).to_utf8_buffer())


static func append_file(body: PackedByteArray, boundary: String, field_name: String, filename: String, file_bytes: PackedByteArray) -> void:
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n" % [field_name, filename]).to_utf8_buffer())
	body.append_array("Content-Type: video/mp4\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
