extends RefCounted

const MemoPayload := preload("res://scripts/memo_payload.gd")


static func request_payload(
	scope: String,
	class_ids: Array,
	student_ids: Array,
	text: String,
	statuses: Array,
	status_index: int,
	scheduled_at: String
) -> Dictionary:
	if text == "":
		return {"ok": false, "message": "配布するメモ内容を入力してください"}
	if scope == "classes" and class_ids.is_empty():
		return {"ok": false, "message": "配布先クラスを選択してください"}
	if scope == "students" and student_ids.is_empty():
		return {"ok": false, "message": "配布先学生を選択してください"}
	var status := _status_id(statuses, status_index)
	return {
		"ok": true,
		"message": "",
		"payload": MemoPayload.teacher_distribution(scope, class_ids, student_ids, text, status, scheduled_at),
	}


static func submit(api: Node, request: Dictionary) -> void:
	api.distribute_teacher_memo(request.get("payload", {}))


static func apply_success(created_count: int, text_input: TextEdit) -> String:
	if created_count > 0 and text_input != null:
		text_input.text = ""
	return "%d人にメモを配布しました" % created_count


static func _status_id(statuses: Array, status_index: int) -> String:
	if status_index < 0 or status_index >= statuses.size():
		return "none"
	return str(statuses[status_index]["id"])
