extends RefCounted

const MemoFilter := preload("res://scripts/memo_filter.gd")
const MemoList := preload("res://scripts/memo_list.gd")


static func fetch_memos(api: Node, is_teacher: bool, current_view: String, current_filter: String) -> String:
	api.fetch_memos(MemoFilter.request_status(current_filter))
	if is_teacher and current_view == "distribute" and api.has_method("fetch_teacher_memo_targets"):
		api.fetch_teacher_memo_targets()
	return "読み込み中..."


static func fetch_teacher_targets(api: Node, memo_list: GridContainer) -> String:
	MemoList.clear(memo_list)
	api.fetch_teacher_memo_targets()
	return "配布先を読み込み中..."
