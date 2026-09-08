extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")


static func populate(list: VBoxContainer, comments: Array) -> void:
	clear(list)
	if comments.is_empty():
		list.add_child(muted_label("まだコメントはありません"))
		return
	for comment in comments:
		if typeof(comment) == TYPE_DICTIONARY:
			list.add_child(comment_label(comment))


static func comment_label(comment: Dictionary) -> Label:
	var item := UiFactory.label(
		"%s: %s" % [str(comment.get("user_name", "匿名学生")), str(comment.get("message", ""))],
		16,
		Color(0.07, 0.09, 0.12)
	)
	return item


static func muted_label(text: String) -> Label:
	return UiFactory.label(text, 14, Color(0.38, 0.42, 0.48))


static func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
