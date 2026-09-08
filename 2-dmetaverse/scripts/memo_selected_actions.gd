extends RefCounted

const MemoPayload := preload("res://scripts/memo_payload.gd")


static func apply_status(api: Node, selected_memo_id: int, selected_memo: Dictionary, status: String) -> Dictionary:
	if selected_memo_id <= 0:
		return {"ok": false, "message": "ラベルを変更するメモを選択してください"}
	api.update_memo(selected_memo_id, MemoPayload.status_update(status, str(selected_memo.get("scheduled_at", ""))))
	return {"ok": true, "message": "ラベルを変更中..."}


static func delete(api: Node, selected_memo_id: int) -> Dictionary:
	if selected_memo_id <= 0:
		return {"ok": false, "message": "削除するメモを選択してください"}
	api.delete_memo(selected_memo_id)
	return {"ok": true, "message": "削除中..."}


static func edit_request(selected_memo_id: int, selected_memo: Dictionary) -> Dictionary:
	if selected_memo_id <= 0 or selected_memo.is_empty():
		return {"ok": false, "message": "編集するメモを選択してください"}
	return {
		"ok": true,
		"message": "",
		"memo": selected_memo,
	}


static func selection_state(memo: Dictionary, selected_memo_id: int) -> Dictionary:
	var memo_id := int(memo.get("id", 0))
	if memo_id > 0 and memo_id == selected_memo_id:
		return {
			"same_selection": true,
			"memo_id": memo_id,
			"memo": {},
		}
	return {
		"same_selection": false,
		"memo_id": memo_id,
		"memo": memo.duplicate(),
	}
