extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const MemoCard := preload("res://scripts/memo_card.gd")
const MemoFilter := preload("res://scripts/memo_filter.gd")


static func render(
	list: GridContainer,
	memos: Array,
	current_filter: String,
	selected_memo_id: int,
	font: Font,
	selected: Callable
) -> bool:
	clear(list)
	if list == null:
		return false
	var visible_memos := MemoFilter.visible_memos(memos, current_filter)
	if visible_memos.is_empty():
		list.add_child(_empty_label("表示するメモはありません", font))
		return false
	var rendered_count := 0
	for memo in visible_memos:
		if typeof(memo) != TYPE_DICTIONARY:
			continue
		list.add_child(MemoCard.build(memo, selected_memo_id, font, selected))
		rendered_count += 1
	if rendered_count == 0:
		list.add_child(_empty_label("メモの表示データを読み込めませんでした", font))
		return false
	return true


static func clear(list: GridContainer) -> void:
	UiFactory.clear_children(list)


static func _empty_label(text: String, font: Font) -> Label:
	return UiFactory.label(text, 18, Color(0.30, 0.36, 0.43), font)
