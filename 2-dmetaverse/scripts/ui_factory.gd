extends RefCounted

const SURFACE := Color(0.045, 0.055, 0.09, 0.97)
const SURFACE_RAISED := Color(0.085, 0.105, 0.16, 0.98)
const SURFACE_HOVER := Color(0.13, 0.18, 0.27, 0.98)
const OUTLINE := Color(0.42, 0.57, 0.78, 0.84)
const TEXT := Color(0.93, 0.96, 1.0)
const MUTED_TEXT := Color(0.68, 0.75, 0.86)


static func is_dark_theme() -> bool:
	return Global.ui_theme != "light"

static func style(
	bg: Color,
	border: Color,
	radius: int,
	border_width: int = 1,
	margins: Vector4 = Vector4(10, 8, 10, 8)
) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = SURFACE_RAISED if is_dark_theme() and bg.get_luminance() > 0.58 else bg
	style_box.border_color = OUTLINE if is_dark_theme() and border.get_luminance() > 0.48 else border
	style_box.set_border_width_all(border_width)
	style_box.set_corner_radius_all(radius)
	style_box.content_margin_left = margins.x
	style_box.content_margin_top = margins.y
	style_box.content_margin_right = margins.z
	style_box.content_margin_bottom = margins.w
	return style_box


static func label(text: String, size: int, color: Color, font: Font = null, autowrap := true) -> Label:
	var node := Label.new()
	node.text = text
	if autowrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", TEXT if is_dark_theme() and color.get_luminance() < 0.48 else color)
	return node


static func filled_button(
	text: String,
	min_size: Vector2,
	color: Color,
	font: Font = null,
	font_size: int = 17,
	radius: int = 6,
	disabled := false
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := style(color.darkened(0.38), color.lightened(0.18), radius) if is_dark_theme() else style(color, color, radius)
	var hover := style(color.darkened(0.22), Color(0.62, 0.82, 1.0), radius, 2) if is_dark_theme() else style(color.lightened(0.12), color.lightened(0.12), radius)
	var pressed := style(color.darkened(0.50), color.lightened(0.08), radius) if is_dark_theme() else style(color.darkened(0.12), color.darkened(0.12), radius)
	if is_dark_theme():
		normal.shadow_color = Color(0, 0, 0, 0.35)
		normal.shadow_size = 4
		hover.shadow_color = Color(0.42, 0.7, 1.0, 0.28)
		hover.shadow_size = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	if disabled:
		button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.68))
		button.add_theme_stylebox_override("disabled", style(color.darkened(0.18), color.darkened(0.18), radius))
	return button


static func line_edit(
	placeholder: String,
	min_size: Vector2 = Vector2(0, 38),
	font: Font = null,
	font_size: int = 16,
	font_color: Color = Color(0.05, 0.06, 0.08),
	placeholder_color: Color = Color(0.45, 0.48, 0.52),
	caret_color: Color = Color(0.05, 0.24, 0.46),
	normal_style: StyleBoxFlat = null,
	focus_style: StyleBoxFlat = null
) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = min_size
	if font != null:
		input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", font_size)
	input.add_theme_color_override("font_color", TEXT if is_dark_theme() and font_color.get_luminance() < 0.55 else font_color)
	input.add_theme_color_override("font_placeholder_color", MUTED_TEXT if is_dark_theme() else placeholder_color)
	input.add_theme_color_override("caret_color", Color(0.66, 0.84, 1.0) if is_dark_theme() else caret_color)
	if normal_style == null:
		normal_style = style(SURFACE, OUTLINE, 7) if is_dark_theme() else style(Color.WHITE, Color(0.55, 0.62, 0.70), 7)
	if focus_style == null:
		focus_style = style(SURFACE_HOVER, Color(0.64, 0.84, 1.0), 7, 2) if is_dark_theme() else normal_style
	if normal_style != null:
		input.add_theme_stylebox_override("normal", normal_style)
	if focus_style != null:
		input.add_theme_stylebox_override("focus", focus_style)
	return input


static func text_edit(
	placeholder: String,
	min_size: Vector2,
	font: Font = null,
	font_size: int = 15,
	font_color: Color = Color(0.05, 0.06, 0.08),
	placeholder_color: Color = Color(0.45, 0.48, 0.52),
	caret_color: Color = Color(0.05, 0.24, 0.46),
	normal_style: StyleBoxFlat = null,
	focus_style: StyleBoxFlat = null,
	wrap_mode: int = TextEdit.LINE_WRAPPING_NONE
) -> TextEdit:
	var input := TextEdit.new()
	input.placeholder_text = placeholder
	input.custom_minimum_size = min_size
	input.wrap_mode = wrap_mode
	if font != null:
		input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", font_size)
	input.add_theme_color_override("font_color", TEXT if is_dark_theme() and font_color.get_luminance() < 0.55 else font_color)
	input.add_theme_color_override("font_placeholder_color", MUTED_TEXT if is_dark_theme() else placeholder_color)
	input.add_theme_color_override("caret_color", Color(0.66, 0.84, 1.0) if is_dark_theme() else caret_color)
	if normal_style == null:
		normal_style = style(SURFACE, OUTLINE, 7) if is_dark_theme() else style(Color.WHITE, Color(0.55, 0.62, 0.70), 7)
	if focus_style == null:
		focus_style = style(SURFACE_HOVER, Color(0.64, 0.84, 1.0), 7, 2) if is_dark_theme() else normal_style
	if normal_style != null:
		input.add_theme_stylebox_override("normal", normal_style)
	if focus_style != null:
		input.add_theme_stylebox_override("focus", focus_style)
	return input


static func limit_option_popup(option: OptionButton, width: int, row_height: int = 30, visible_rows: int = 5) -> void:
	if option == null:
		return
	var popup := option.get_popup()
	if popup == null:
		return
	_apply_option_popup_limit(option, width, row_height, visible_rows)
	var callback := func():
		_apply_option_popup_limit(option, width, row_height, visible_rows)
	if not popup.about_to_popup.is_connected(callback):
		popup.about_to_popup.connect(callback)


static func _apply_option_popup_limit(option: OptionButton, width: int, row_height: int, visible_rows: int) -> void:
	if option == null:
		return
	var popup := option.get_popup()
	if popup == null:
		return
	var height := row_height * visible_rows + 4
	var popup_size := Vector2i(max(width, 72), height)
	popup.max_size = popup_size
	if option.item_count > visible_rows:
		popup.size = popup_size
		popup.set_deferred("size", popup_size)


static func selected_item_id(option: Object) -> int:
	if option == null or int(option.get("item_count")) == 0:
		return 0
	return int(option.call("get_item_id", int(option.get("selected"))))


static func select_item_by_id(option: Object, value: int) -> void:
	if option == null:
		return
	for index in range(int(option.get("item_count"))):
		if int(option.call("get_item_id", index)) == value:
			option.call("select", index)
			return


static func clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func move_text_caret_to_end(text_edit: TextEdit) -> void:
	if text_edit == null:
		return
	var line_index: int = max(text_edit.get_line_count() - 1, 0)
	var column: int = text_edit.get_line(line_index).length()
	text_edit.set_caret_line(line_index)
	text_edit.set_caret_column(column)


static func keep_text_caret_visible(text_edit: TextEdit) -> void:
	if text_edit == null:
		return
	# TextEdit renders its placeholder over the caret at the start of an empty line.
	# Hide it while focused so the insertion point is visible from the first click.
	var placeholder := text_edit.placeholder_text
	text_edit.caret_blink = false
	text_edit.focus_entered.connect(func(): text_edit.placeholder_text = "")
	text_edit.focus_exited.connect(func():
		if text_edit.text.is_empty():
			text_edit.placeholder_text = placeholder
	)


static func apply_mysterious_theme(root: Node) -> void:
	if root == null:
		return
	for node in root.get_children():
		if node is Label:
			node.add_theme_color_override("font_color", TEXT if is_dark_theme() else Color(0.08, 0.11, 0.15))
		elif node is LineEdit or node is TextEdit:
			node.add_theme_color_override("font_color", TEXT if is_dark_theme() else Color(0.05, 0.06, 0.08))
			node.add_theme_color_override("font_placeholder_color", MUTED_TEXT if is_dark_theme() else Color(0.45, 0.48, 0.52))
			node.add_theme_color_override("caret_color", Color(0.66, 0.84, 1.0) if is_dark_theme() else Color(0.05, 0.24, 0.46))
			node.add_theme_stylebox_override("normal", style(SURFACE, OUTLINE, 7) if is_dark_theme() else style(Color.WHITE, Color(0.55, 0.62, 0.70), 7))
			node.add_theme_stylebox_override("focus", style(SURFACE_HOVER, Color(0.64, 0.84, 1.0), 7, 2) if is_dark_theme() else style(Color.WHITE, Color(0.20, 0.42, 0.72), 7, 2))
		elif node is Button or node is OptionButton:
			_apply_dark_button_style(node)
		elif node is Panel or node is PanelContainer:
			node.add_theme_stylebox_override("panel", style(SURFACE, OUTLINE, 10) if is_dark_theme() else style(Color(0.972, 0.977, 0.984), Color(0.70, 0.75, 0.80), 10))
		elif node is CheckBox:
			_apply_check_box_colors(node)
		apply_mysterious_theme(node)


static func _apply_dark_button_style(button: BaseButton) -> void:
	var text_color := TEXT if is_dark_theme() else Color(0.08, 0.11, 0.15)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_hover_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", MUTED_TEXT if is_dark_theme() else Color(0.43, 0.48, 0.55))
	var normal := style(SURFACE_RAISED, OUTLINE, 7) if is_dark_theme() else style(Color.WHITE, Color(0.55, 0.62, 0.70), 7)
	var hover := style(SURFACE_HOVER, Color(0.64, 0.84, 1.0), 7, 2) if is_dark_theme() else style(Color(0.96, 0.98, 1.0), Color(0.20, 0.42, 0.72), 7, 2)
	if is_dark_theme():
		hover.shadow_color = Color(0.42, 0.7, 1.0, 0.25)
		hover.shadow_size = 7
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style(SURFACE, OUTLINE, 7) if is_dark_theme() else style(Color(0.92, 0.95, 0.99), Color(0.20, 0.42, 0.72), 7, 2))
	button.add_theme_stylebox_override("focus", hover)


static func _apply_check_box_colors(check_box: CheckBox) -> void:
	var text_color := TEXT if is_dark_theme() else Color(0.08, 0.11, 0.15)
	check_box.add_theme_color_override("font_color", text_color)
	check_box.add_theme_color_override("font_hover_color", text_color)
	check_box.add_theme_color_override("font_pressed_color", text_color)
	check_box.add_theme_color_override("font_focus_color", text_color)
	check_box.add_theme_color_override("font_disabled_color", MUTED_TEXT if is_dark_theme() else Color(0.43, 0.48, 0.55))


static func localize_text_edit_menu(text_edit: TextEdit) -> void:
	if text_edit == null:
		return
	var menu := text_edit.get_menu()
	if menu == null:
		return
	var labels := {
		TextEdit.MENU_CUT: "切り取り",
		TextEdit.MENU_COPY: "コピー",
		TextEdit.MENU_PASTE: "貼り付け",
		TextEdit.MENU_CLEAR: "削除",
		TextEdit.MENU_SELECT_ALL: "すべて選択",
		TextEdit.MENU_UNDO: "元に戻す",
		TextEdit.MENU_REDO: "やり直し",
	}
	for i in range(menu.item_count):
		var id := menu.get_item_id(i)
		if labels.has(id):
			menu.set_item_text(i, labels[id])


static func fit_grid_columns(grid: GridContainer, visible_guard: Control, min_column_width: float = 270.0, max_columns: int = 4) -> void:
	if grid == null or visible_guard == null or not visible_guard.visible:
		return
	var available_width: float = max(1.0, grid.get_parent_area_size().x)
	var columns := int(clamp(floor(available_width / min_column_width), 1.0, float(max_columns)))
	if grid.columns != columns:
		grid.columns = columns


static func fit_centered_panel(panel: Control, viewport_size: Vector2, max_size: Vector2, margin: float) -> void:
	if panel == null:
		return
	var width: float = min(max_size.x, viewport_size.x - margin)
	var height: float = min(max_size.y, viewport_size.y - margin)
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
