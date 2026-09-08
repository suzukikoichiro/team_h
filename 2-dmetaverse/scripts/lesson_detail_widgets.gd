extends RefCounted

const LessonWidgets := preload("res://scripts/lesson_widgets.gd")


static func build(parent: HBoxContainer, bold_font: Font, open_url: Callable) -> Dictionary:
	var detail_panel := VBoxContainer.new()
	detail_panel.custom_minimum_size = Vector2(300, 0)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 8)
	var wrap := PanelContainer.new()
	wrap.visible = false
	wrap.custom_minimum_size = Vector2(300, 0)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel", LessonWidgets.card_style())
	parent.add_child(wrap)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	wrap.add_child(margin)
	margin.add_child(detail_panel)
	var open_button := LessonWidgets.button("リンクを開く", Vector2(0, 40))
	open_button.pressed.connect(open_url)
	detail_panel.add_child(open_button)
	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)
	var selected_title_label := LessonWidgets.section_label("リンクを選択してください", bold_font)
	details.add_child(selected_title_label)
	var selected_meta_label := LessonWidgets.muted_label("")
	details.add_child(selected_meta_label)
	var selected_description_label := LessonWidgets.muted_label("")
	selected_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(selected_description_label)
	return {"root": wrap, "title_label": selected_title_label, "meta_label": selected_meta_label, "description_label": selected_description_label, "open_button": open_button}
