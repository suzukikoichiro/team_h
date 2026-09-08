extends RefCounted

const UiFactory := preload("res://scripts/ui_factory.gd")
const LessonWidgets := preload("res://scripts/lesson_widgets.gd")

const INPUT_TEXT_COLOR := Color(0.03, 0.045, 0.065)
const PLACEHOLDER_COLOR := Color(0.34, 0.39, 0.46)
const CARET_COLOR := Color(0.05, 0.24, 0.46)


static func _line_edit(placeholder: String, bold_font: Font) -> LineEdit:
	return UiFactory.line_edit(placeholder, Vector2(0, 40), bold_font, 16, INPUT_TEXT_COLOR, PLACEHOLDER_COLOR, CARET_COLOR,
		UiFactory.style(Color.WHITE, Color(0.55, 0.62, 0.70), 6), UiFactory.style(Color.WHITE, Color(0.20, 0.42, 0.72), 6, 2))


static func _text_edit(placeholder: String, bold_font: Font) -> TextEdit:
	return UiFactory.text_edit(placeholder, Vector2(0, 64), bold_font, 16, INPUT_TEXT_COLOR, PLACEHOLDER_COLOR, CARET_COLOR,
		UiFactory.style(Color.WHITE, Color(0.55, 0.62, 0.70), 6), UiFactory.style(Color.WHITE, Color(0.20, 0.42, 0.72), 6, 2), TextEdit.LINE_WRAPPING_BOUNDARY)


static func build_link(parent: VBoxContainer, bold_font: Font, post_link: Callable) -> Dictionary:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", LessonWidgets.card_style())
	parent.add_child(wrap)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	wrap.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := LessonWidgets.section_label("授業映像を共有", bold_font)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var toggle := UiFactory.filled_button("⌃", Vector2(32, 28), Color(0.36, 0.43, 0.50), null, 18)
	toggle.tooltip_text = "共有フォームを閉じる"
	header.add_child(toggle)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	box.add_child(form)
	toggle.pressed.connect(func() -> void:
		form.visible = not form.visible
		toggle.text = "⌃" if form.visible else "⌄"
		toggle.tooltip_text = "共有フォームを閉じる" if form.visible else "共有フォームを開く"
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	form.add_child(row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 4)
	row.add_child(title_column)
	title_column.add_child(UiFactory.label("タイトル", 14, Color(0.22, 0.28, 0.35), bold_font))
	var title_input := _line_edit("例：第3回講義資料", bold_font)
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_child(title_input)
	var url_column := VBoxContainer.new()
	url_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_column.add_theme_constant_override("separation", 4)
	row.add_child(url_column)
	url_column.add_child(UiFactory.label("共有URL", 14, Color(0.22, 0.28, 0.35), bold_font))
	var url_input := _line_edit("https:// から始まるURL", bold_font)
	url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_column.add_child(url_input)
	var post := LessonWidgets.button("共有する", Vector2(108, 40))
	post.size_flags_vertical = Control.SIZE_SHRINK_END
	post.pressed.connect(post_link)
	row.add_child(post)

	form.add_child(UiFactory.label("説明（任意）", 14, Color(0.22, 0.28, 0.35), bold_font))
	var description_input := _text_edit("リンクの内容や確認してほしい点を入力", bold_font)
	form.add_child(description_input)
	return {"title": title_input, "url": url_input, "description": description_input}
