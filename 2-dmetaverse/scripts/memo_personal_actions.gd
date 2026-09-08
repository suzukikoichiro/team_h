extends RefCounted

const MemoPayload := preload("res://scripts/memo_payload.gd")


static func save_request(text: String, editing_memo_id: int, status: String, scheduled_at: String) -> Dictionary:
	if text == "":
		return {"ok": false, "message": "メモ内容を入力してください"}
	var action := "update" if editing_memo_id > 0 else "create"
	return {
		"ok": true,
		"message": "",
		"action": action,
		"id": editing_memo_id,
		"payload": MemoPayload.personal_save(text, status, scheduled_at),
	}


static func has_autosave_text(text: String, autosave_performed: bool) -> bool:
	return not autosave_performed and text != ""


static func submit(api: Node, request: Dictionary) -> void:
	var payload: Dictionary = request.get("payload", {})
	if str(request.get("action", "")) == "update":
		api.update_memo(int(request.get("id", 0)), payload)
	else:
		api.create_memo(str(payload.get("text", "")), str(payload.get("status", "none")), str(payload.get("scheduled_at", "")))
